<#
.SYNOPSIS
    The live per-sport Google Sheet: what a run writes into it, and what it must not touch.

.DESCRIPTION
    Run-Query.ps1 dot-sources this file. It holds no network code and sends nothing: given
    what a run produced and what the document already contains, it computes the list of
    operations that would bring the document up to date. Turning that list into API calls is
    the transport's job, and it is deliberately separate - the merge is where the defects
    live, and a merge that needs a login to test is a merge nobody tests.

    The document is permanent and one per sport. Every earlier design wrote a new file per
    run, which is why reviewer comments died with each one; the point of this file is that
    they do not, so every rule below is about leaving somebody else's cells alone.

    This file stays pure ASCII, as the other TOOLS scripts do: Windows PowerShell 5.1 reads a
    .ps1 without a BOM as ANSI, so a literal em dash would arrive mojibaked and fail to parse.
#>

$SheetsApiRoot = 'https://sheets.googleapis.com/v4/spreadsheets'
$SheetsTokenUrl = 'https://oauth2.googleapis.com/token'
$SheetsScope = 'https://www.googleapis.com/auth/spreadsheets'

# The title Google gives a spreadsheet nobody has named. The runner names the document while
# it still reads exactly this, and never over a title somebody chose: a colleague who renames
# it has decided something, and an instrument that quietly puts its own name back every week
# is the same defect as one that overwrites a comment.
$SheetsUntitled = 'Untitled spreadsheet'

# Titles this runner has given documents in the past. A document still carrying one of these
# is wearing a name nobody chose, so a change to the naming pattern reaches it. Add the old
# pattern here whenever the pattern changes; nothing else may go in this list.
$SheetsFormerTitles = @('Enetpulse DQ - *')

# Rows per write request. A single 20 000-row block is megabytes of JSON in one body, which is
# slow to build, slow to send and all-or-nothing if it fails.
$SheetsWriteChunk = 2000

# How many ranges one batchGet asks for. Each is a query parameter, so the whole read is one
# URL, and a board of a hundred tabs now asks for two ranges per tab - its Check ID and its
# result header. Sixty keeps the URL comfortably inside what a GET is served at.
$SheetsReadChunk = 60

# Table declarations per batchUpdate. Not a size limit - a batch of two hundred is accepted
# when every request in it is good. It is a blast radius: batchUpdate is atomic, so one
# request Google refuses discards the whole call, and a refusal it answers with 500 names
# neither the request nor the reason. In one call a single bad table costs every table on the
# board and says nothing; in twenties it costs twenty and the output says which twenty.
$SheetsTableChunk = 20

$script:SheetsAccessToken = ''
$script:SheetsTokenExpiry = [datetime]::MinValue

# How far the last document update got. The phases have to be sent in order - a tab before a
# range names it, a clear before the rows that replace it - so a failure in a later one leaves
# the earlier ones applied. Without this the run reports "the document was not updated" for a
# document that was, which is the wrong thing to tell somebody deciding whether to look at it.
$script:SheetsStage = ''

function Set-SheetsAddressFamily {
    <#
        Refuse IPv6 for a host whose IPv6 is dead.

        sheets.googleapis.com resolves to eight IPv6 addresses before its first IPv4 one, and
        on a network that cannot route 2001:4860::/32 every one of them has to time out before
        .NET Framework tries IPv4. It has no Happy Eyeballs: the addresses are walked in order,
        each waiting out its own connect timeout. Measured here, the first request to the host
        took 168 seconds and every request after it 207 milliseconds, because by then the
        connection was established and pooled.

        The fix is the bind delegate, and which of its two forms is used matters. Returning a
        mismatched local endpoint for an IPv6 remote reads as a failed bind and .NET retries the
        same address, which is slower than doing nothing - it ran past seven minutes. Throwing
        makes it abandon that address and move to the next, and the same first request then
        takes three seconds.

        This is a workaround for a network fault rather than a fix for one. If the IPv6 route
        starts working, or IPv6 is disabled on the adapter, this becomes a no-op that costs
        nothing.
    #>
    param([string]$Uri)

    $point = [Net.ServicePointManager]::FindServicePoint([Uri]$Uri)
    if ($point.BindIPEndPointDelegate) { return }
    $point.BindIPEndPointDelegate = {
        param($servicePoint, $remoteEndPoint, $retryCount)
        if ($remoteEndPoint.AddressFamily -eq [Net.Sockets.AddressFamily]::InterNetworkV6) {
            throw (New-Object InvalidOperationException 'IPv6 refused for this host')
        }
        return $null
    }
}

# How many result rows one check may put in the live document. The hard limit is Google's, at
# 10 million cells per spreadsheet, and it is a document budget rather than a per-tab one: a
# sport is around fifty checks in one permanent file, so a single six-figure check can take a
# sixth of the document by itself. Sheets also becomes slow to open and scroll well before
# the limit, and writing that many cells over the API costs minutes per run.
#
# Re-derived from a run of all six documented sports on 2026-08-08 - 496 checks, no failures -
# rather than left at the 20 000 first guessed here. What that measured:
#
#   largest single check   Curling-DQ-041, 17 626 rows
#   largest sport in total Curling, 79 523 rows over 105 checks, about 636 000 cells
#   six-figure results     none, under each sport's documented scope
#
# So the first guess was tight in the wrong place. Three Curling checks sat within 12% of it,
# where one heavier import would have started truncating a legitimate result - while the
# document it was protecting was at 6.4% of Google's limit, with room to spare by an order of
# magnitude.
#
# 50 000 is roughly three times the largest count seen and still only about 4% of a document
# for one check, so the guard against a genuinely pathological result survives without
# threatening anything real. Worth re-deriving again if a sport is ever run outside its
# documented scope: Soccer sport-wide is the known six-figure case, and it does not arise
# under the 28 client templates SPORTS/Soccer.md scopes it to.
$SheetsMaxRowsPerCheck = 50000

# When the whole document would pass this, the run says so. A warning rather than a truncation
# because the answer is a decision - drop a check from the document, tighten a scope, split
# the sport - and none of those is the runner's to make silently.
$SheetsCellBudgetWarning = 8000000

# The columns on the live Overview, in order, matching the workbook so the two read alike.
#
# Findings, Prev findings, Change, Verdict and Trends all read what is still open: the rows
# the reviewers marked No Issue / Change come off every one of them, as they already came off
# Rows. A settled finding stays in the result for good, because nothing about the database is
# going to change - so counting it forever made a finished check read as a busy one, and the
# board disagreed with its own Rows column about how much work was left.
#
# All findings is the one column that does not subtract. It is what the statement returned,
# and it is here because the reviewers' decisions are a reading of the data rather than a
# change to it: the day somebody asks how many rows the check actually matches, that number
# has to be on the board rather than reconstructed from the tab.
# Time Spent (minutes) is the reviewer's, and unlike Comment it is theirs on both boards
# separately. Comment is written once beside the rows that provoked it and mirrored onto
# Overview by a formula; this one is not, by decision of 2026-08-17. How long a check took to
# work through and how long it took to read the board about it are two different numbers, and
# a mirror would force them to be one - so each side holds its own and nothing links them.
$SheetsOverviewColumns = @(
    'Sport', 'CheckID', 'Object', 'Check Name', 'Priority', 'Category', 'What it does',
    'Rows', 'Status', 'Check By', 'Comment', 'Time Spent (minutes)', 'Signal', 'Signal reason',
    'Expected', 'Findings', 'All findings', 'Eligible', 'Prev findings', 'Prev eligible',
    'Change', 'Verdict', 'Last run', 'Trends', 'Data types')

# Row 1 of a check tab. Without it D2 and E2 hold "1 Structure" and "NO_RELATED_RECORDS" over
# nothing, and a reader has to go back to Overview to learn what they are.
#
# Priority is gone: it is derived from Category and exists to sort the board, and by the time
# a tab is open the sorting has done its work. Category keeps a place further out. The six
# after Check By are the ones a person wants while looking at the rows themselves - whether
# this was ever supposed to reach zero, out of how large a population, and whether the last
# fix moved it.
#
# Signal and Signal reason are gone from here as well. They are the runner's own
# classification of the check, settled before the statement was sent and unchanged by reading
# what it returned, so on a tab opened to look at findings they are two columns of noise
# between the identity and the reviewer's own cells. Overview still carries both, hidden.
#
# All findings sits beside Findings here for the same reason it does on Overview, and it
# matters more on a tab than on the board: this is the page where somebody is looking at the
# rows themselves, and the difference between the two numbers is exactly how many of the rows
# below them have already been decided about.
#
# Time Spent (minutes) joins the reviewer's own cells here rather than sitting out at the end,
# because the three belong together: who read it, what they concluded, and what it cost them.
# It holds no relation to Overview's column of the same name - see the note there.
$SheetsCheckTabColumns = @(
    'Check ID', 'Check Name', 'SQL Used', 'What it does',
    'Comment', 'Check By', 'Time Spent (minutes)',
    'Expected', 'Findings', 'All findings', 'Eligible', 'Prev findings', 'Change', 'Verdict',
    'Trends', 'Category', 'Parameters')

# Who owns what. The runner writes around these and never through them: they hold the only
# thing in the document that cannot be regenerated, which is what a person concluded from
# reading it. Everything else the runner can rebuild from the run.
#
# Overview's are Status, Check By, Comment and Time Spent (minutes); a check tab's are the same
# fields for one check. Note that a check tab's Comment is the source and Overview's is a
# formula reading it - so overwriting either would cost the text, and the runner writes neither.
# Time Spent is not mirrored either way and is simply never written.
#
# Found by name rather than written as numbers. They were 7 and 8 on a check tab and moved to
# 5 and 6 when Signal and Signal reason came out, and a comment at the old literal 7 would
# have been the reviewer's text sitting in what is now Expected while Comment was overwritten
# every run. Nothing here needs to know a position that the column list already states - which
# is why Overview's list is derived here too, rather than being the literal 9, 10, 11 it was
# when Time Spent arrived between Comment and Signal.
$SheetsOverviewReviewerColumns = @(
    @('Status', 'Check By', 'Comment', 'Time Spent (minutes)') |
        ForEach-Object { [array]::IndexOf($SheetsOverviewColumns, $_) + 1 })
$SheetsCheckTabReviewerColumns = @(
    @('Comment', 'Check By', 'Time Spent (minutes)') |
        ForEach-Object { [array]::IndexOf($SheetsCheckTabColumns, $_) + 1 })

# Columns Overview ships hidden. Signal and Signal reason are the runner's classification,
# settled before the run and unchanged by reading it. Both stay in the sheet and in
# _summary.csv; unhiding brings back every value.
#
# Parameters used to sit here and no longer exists on the board. It was empty for every check
# of a sport that takes none and identical for every check of one that does, so it was a
# column of repetition beside the two things a reviewer navigates by - and column C is the
# one place on the board worth spending on. Object took it on 2026-08-19 at the reviewers'
# asking, and Object is not hidden: it is what says which layer to repair first.
#
# Hidden on the run that creates Overview and on every run that covers the whole sport.
# Contiguous runs are hidden together and gaps are not bridged, so hiding C does not take D
# through K with it.
#
# Eligible, Prev findings and Prev eligible joined the list on 2026-08-17 at the reviewers'
# asking. All three are context for a number rather than the number: how large the population
# was, and what the run before said. Change and Verdict already answer "did this move, and
# which way", so the two counts they were computed from are a reader's second question and not
# their first. Unhiding brings every value back, and _summary.csv carries them regardless.
#
# Derived rather than written as numbers, for the reason the reviewer columns above now are:
# these were the literal 3, 12 and 13 until a column arrived to the left of Signal, and a
# literal here would have hidden Signal reason and Expected instead.
$SheetsOverviewHiddenColumns = @(
    @('Signal', 'Signal reason', 'Eligible', 'Prev findings', 'Prev eligible') |
        ForEach-Object { [array]::IndexOf($SheetsOverviewColumns, $_) + 1 })

# How Overview colours its Rows column, and what each band means.
#
# Rows is the raw row count of the result, so a clean check returns exactly one - the COVERAGE
# branch and nothing else. One is therefore the good case, and zero is not: a statement that
# returned nothing at all did not run the coverage contract and is a defect in the check.
#
# Above that the bands are a size judgement rather than a severity one. Severity is Priority,
# which comes from the category and does not move; this says how much work is in front of
# whoever opens the tab, which is the question the board is scanned for.
#
# Rewritten every run rather than set once, and only over rules that cover exactly this
# column: a threshold changed here has to reach a document created before the change, and the
# alternative - adding three more rules each week - fills the sheet with duplicates. A rule
# somebody adds themselves on the Rows column will not survive the next run. Any other column
# is theirs.
$SheetsRowsBands = @(
    [pscustomobject]@{ Type = 'NUMBER_EQ'; Values = @('1'); Colour = '#188038' }
    [pscustomobject]@{ Type = 'NUMBER_BETWEEN'; Values = @('2', '100'); Colour = '#B06000' }
    [pscustomobject]@{ Type = 'NUMBER_GREATER'; Values = @('100'); Colour = '#C5221F' }
)

# The outcomes a reviewer may record, and the only ones. Status was free text until now, and
# free text drifted: six boards between them held nine spellings of five ideas, because the
# workbook offered one vocabulary, the seeding code wrote a second, and whoever typed into the
# live board was constrained by neither.
#
# Closed rather than open on purpose. The column is read across sports to answer how much of
# the catalogue has been through review, and a synonym nobody declared is invisible to that
# question while looking perfectly reasonable in its own cell.
#
# The order is the order the dropdown offers, which is roughly the order a check moves
# through: unseen, judged harmless, judged worth watching, being looked at, paused, dealt with,
# handed on, handed elsewhere, put aside. Colour carries the same reading at a glance, and is
# why each carries a background rather than only a text colour - a chip is what the reviewer
# sees, not a word.
#
# Three were added on 2026-08-21 and each says something the six could not. On Hold is a review
# that started and stopped, which Reviewing claimed was still moving. Other Team is the second
# direction a check can be handed in - IT Fix was the only one, and a check somebody else owns
# was reaching the board as either that or Not reviewed. Skipped is a deliberate decision not to
# work a check now, which nothing said before: leaving it Not reviewed made a settled decision
# look like an untouched row.
#
# Their colours are chosen against the reading groups rather than one by one. IT Fix and Other
# Team are two ambers because they mean the same kind of thing and differ only in who received
# it - the same reason Clean and Completed are two greens. On Hold is orange, the attention
# family, beside the red of Not reviewed and not in it. Skipped is teal rather than the third
# green it was first asked to be: Clean and Completed are already green, and three green chips
# in a column of ten would cost the glance the colour exists to give.
#
# Skipped is also the one word here that means something else elsewhere on the same row. The
# runner writes SKIPPED into the Rows cell for a statement it did not execute, and this is a
# person saying they executed it and put it aside. Two columns, one word, two meanings, decided
# knowingly on 2026-08-21 because it is the word the reviewers use.
#
# The last of them is not a stage of review but the end of one, and grey because a chip saying
# "nothing to do here" should not compete with the nine that ask for something. It is also the
# one value in this column the runner writes rather than a person, and it writes it only when
# POWERBI_REGISTRY.md says Deprecated. Without it the retirement left a row saying Deprecated in
# Signal and Verdict while Status still read Not reviewed - a row asking to be reviewed and
# answering that there is nothing to review, which a filter on Not reviewed kept serving up.
#
# Being in the dropdown as well is a compromise rather than a preference: the validation is one
# closed list for the whole column and cannot offer a value for writing while withholding it
# from typing. A person setting it by hand does not withdraw the check - the registry does, and
# the next run puts the cell back to what the registry says.
$SheetsRetiredStatus = 'Deprecated'

# The word a row carries before anybody has answered it. Named because two places have to
# agree on it: the seed that writes it onto a row being added, and the retired-check rule that
# treats it as "nobody has decided yet" and will write over it.
$SheetsUnreviewedStatus = 'Not reviewed'

# The two statuses that are claims about a state rather than about a check, and the word the run
# writes when its own result refutes one.
#
# `Clean` says the check returns nothing. `Completed` says the findings were dealt with. Both are
# answers to what a run found, and a later run can contradict either by simply returning rows -
# which it did, silently, for as long as this column was the reviewer's alone. Colleagues cleared
# a check, marked it Completed, and ten days later it came back with new findings under a green
# chip nobody had reason to look at twice. A board is scanned and filtered by this column, so a
# stale word there is not a cosmetic problem: it is work that has become invisible.
#
# The other eight say nothing a result can refute. `Monitor Only` expects a count forever.
# `Reviewing`, `On Hold` and `Skipped` are where the reading got to. `IT Fix` and `Other Team`
# are who is holding it. `Not reviewed` is the seed and `Deprecated` is the registry's. None of
# them is touched here, and the count beside them moving means nothing about any of them.
#
# `Reopened` is written rather than `Not reviewed` because the two are different facts. Nobody
# has looked is not the same as somebody looked, closed it, and it came back - and the second is
# the one worth a reviewer's attention first. It sits after `Completed` because that is where it
# happens in a check's life, and it is red because it belongs with `Not reviewed` in the reading:
# both mean this row has not been answered as it now stands. The same argument the file already
# makes for IT Fix and Other Team being two ambers.
#
# The run writes it and never writes it back. A check that returns to zero stays `Reopened` until
# a person says otherwise: a run may contradict a conclusion, but forming one is not its to do.
$SheetsReopenedStatus = 'Reopened'
$SheetsStatusClosedByFinding = @('Clean', 'Completed')

# The one expectation under which a returned row contradicts a closed status.
#
# `Zero` is carried by `Actionable` and by `Sentinel`, and both mean the same thing here: every
# row this check returns is a defect, so a board saying Clean or Completed while it returns rows
# is saying something the run has just disproved.
#
# The other three do not. `Non-zero` belongs to `Monitor`, where the proportion is the finding
# and the count will never be nothing; `Residual` is a remainder somebody agreed to leave; and an
# empty expectation belongs to `Blocked`, `Not applicable` and `Out of client scope`, which are
# not counts anybody is waiting on. `Completed` on any of those means the reviewer read it, not
# that it came back empty, and reopening it would ask them the same question every run for ever.
$SheetsExpectationReopenable = 'Zero'

$SheetsStatusBands = @(
    [pscustomobject]@{ Value = 'Not reviewed'; Background = '#FCE8E6'; Colour = '#C5221F' }
    [pscustomobject]@{ Value = 'Clean'; Background = '#E6F4EA'; Colour = '#137333' }
    [pscustomobject]@{ Value = 'Monitor Only'; Background = '#F3E8FD'; Colour = '#7627BB' }
    [pscustomobject]@{ Value = 'Reviewing'; Background = '#E8F0FE'; Colour = '#1967D2' }
    [pscustomobject]@{ Value = 'On Hold'; Background = '#FEEFE3'; Colour = '#E8710A' }
    [pscustomobject]@{ Value = 'Completed'; Background = '#CEEAD6'; Colour = '#0B6B3A' }
    [pscustomobject]@{ Value = $SheetsReopenedStatus; Background = '#FAD2CF'; Colour = '#B31412' }
    [pscustomobject]@{ Value = 'IT Fix'; Background = '#FEF7E0'; Colour = '#B06000' }
    [pscustomobject]@{ Value = 'Other Team'; Background = '#FEEFC3'; Colour = '#7A4F01' }
    [pscustomobject]@{ Value = 'Skipped'; Background = '#E0F2F1'; Colour = '#00796B' }
    [pscustomobject]@{ Value = $SheetsRetiredStatus; Background = '#F1F3F4'; Colour = '#5F6368' }
)

# What each superseded spelling meant, so that adopting the vocabulary above does not throw
# away a conclusion somebody already reached. Applied once per cell, when a run finds one of
# these still on a board; a cell already holding a current value is never touched.
#
# This is the single exception to Status being the reviewer's alone, and it is narrow by
# construction: it renames a conclusion, it never forms one. Every mapping below is between
# two words for the same finding, and a spelling not listed here is left exactly as typed
# rather than guessed at.
#
# 'Monitor Olnly' is in the list because it was in the data, five times on one board. A
# typo is a spelling of an idea like any other, and correcting it silently on the next run is
# better than a dropdown that rejects five cells nobody can now explain.
$SheetsStatusLegacy = @{
    'No issue'         = 'Clean'
    'No Changes'       = 'Clean'
    'No action needed' = 'Monitor Only'
    'Monitor Olnly'    = 'Monitor Only'
    'Fixed'            = 'Completed'
    'For IT'           = 'IT Fix'
    'Reported to IT'   = 'IT Fix'
}
#
# 'On hold' was in this map from 2026-08-10, when Status offered six outcomes and it was a
# spelling reviewers reached for because the word they wanted did not exist. On 2026-08-21 it
# became one: On Hold is a review that started and stopped, which is exactly what Reviewing
# could not say. The map entry was not removed with it, and a PowerShell hashtable does not
# distinguish case, so every run since renamed a reviewer's On Hold back to Reviewing and
# undid the distinction the status was added to make. Removed 2026-08-25.
# The rule the entry broke is the one this map exists under: a key here is a spelling of
# something the vocabulary does not offer. A key that is itself a valid status does not rename
# a conclusion, it overwrites one, and Test-Tools.ps1 now fails on any such key.

# The tab holding every statement the run sent, and the name of the token a link to it uses.
# A link needs the target tab's numeric id, which is not known until the tab has been created,
# so the plan writes the token and the transport resolves it once the ids come back.
$SheetsSqlTabName = 'SQL'

# The two blues a link is drawn in. The way back out of a tab is the brighter one, because it
# is the control somebody is looking for; the jump to the statement is the darker, because it
# sits inside a row of identity and should not outshout the check's own name beside it.
$SheetsLinkColour = '#1A73E8'
$SheetsSqlLinkColour = '#1155CC'

# The two header colours a document uses, and why there are two.
#
# The split is between a block that names a check and a block that holds rows. A check tab
# carries one of each: rows 1 to 3 say which check this is, and everything from row 5 down is
# what it returned. The identity recedes into grey, because it is a label and the rows under
# it are what the eye came for; every block holding rows takes the red, the board included, so
# that a heading over data looks the same wherever data appears.
#
# Both are from Sheets' own table palette rather than mixed by hand. The first red was picked
# blind off a screenshot and read as too bright beside the green the palette gives by default.
$SheetsIdentityHeaderColour = '#626E7A'
$SheetsDataHeaderColour = '#CA1744'

# Which way the count moved, in the colour a reader already expects it in. Down is the check
# improving, so green; up is it getting worse, so red; level is neither and stays black rather
# than being given a third meaning. Bold throughout, because the numbers are what the column is
# for and the timestamps beside them are context.
$SheetsTrendColours = @{
    'down'  = '#137333'
    'up'    = '#C5221F'
    'level' = '#000000'
}

# Comment and Check By are the reviewer's, on a header row that is otherwise the runner's.
# Bold and white against the header's own colour: the weight is enough to separate them, and
# the yellow that did it first fought the header rather than sitting on it.
$SheetsReviewerHeaderColour = '#FFFFFF'

# Wide enough for 'Return to Overview' to be read whole. Column A of a check tab holds the
# link in row 3 and a result value below it, and at the default width the link was clipped by
# whatever sat in B - a control nobody can read is not a control.
$SheetsCheckTabFirstColumnWidth = 175

# Wide enough for the heading to be read rather than guessed at. 'Time Spent (minutes)' is
# twenty characters against a default column of about eleven, so at the default it arrives as
# 'Time Spent (m' on both boards - and a column somebody is meant to type into has to say what
# it wants first.
$SheetsTimeSpentColumnWidth = 150

# Wide enough for the whole series. $TrendRunCount keeps five recorded runs and this run makes
# six, and a point renders as '2789 (17.08 13:47)' - about eighteen characters, with three more
# for the arrow between them. Six points is therefore around 123 characters, and this is what
# that measures at the sheet's own size. The column exists to be read across, so sizing it to
# anything less makes it a cell somebody has to click into to use.
$SheetsTrendsColumnWidth = 900

# Wide enough for a few types with their names, not for the longest list on the board.
# Ice-Hockey-DQ-104 reads seven of them and renders at about 110 characters, which nothing
# short of the Trends width would hold; sizing for that would push every other column off a
# screen for the sake of one row. This fits three or four - '4 Final Result, 6 Running score'
# - which is what most checks carry, and the rest is one click away like any other cell.
$SheetsDataTypesColumnWidth = 260

# A result column is sized from its own header, and the header row wraps.
#
# The names a statement projects are the long text on a check tab - 'missing_participants',
# 'distinct_countries', 'deprecated_duration_participant_count' at thirty-seven characters - and
# every column of the tab is centred. A name too wide for its column is therefore clipped at
# both ends, which does not read as a truncated name but as a different word: 'first_appearance'
# showed as 'est_appearai'. Sizing to the header alone is deliberate. Sizing to the values would
# put a GROUP_CONCAT of forty participant names in one column and push the rest of the table off
# the screen, and the values were legible before this and stay as they were.
#
# Roughly the width of a bold Arial 10 character, plus room for the filter button the table
# header draws in every cell. The cap is what a name may claim before it wraps instead: without
# one the longest names alone would take a third of the visible width.
$SheetsResultColumnCharWidth = 8
$SheetsResultColumnPadding = 30
$SheetsResultColumnMinWidth = 90
$SheetsResultColumnMaxWidth = 200

$SheetsGidToken = '{{GID:%NAME%}}'

# Where a check tab's result block starts. Rows 1 and 2 are the identity, row 3 the link back
# to Overview and any truncation note, row 4 blank so the results below stay a self-contained
# block for sorting and filtering.
$SheetsCheckTabResultRow = 5

# What a withdrawn check reads as on the board. The word is the registry's own Status value, so
# a reviewer meeting it here and in POWERBI_REGISTRY.md meets the same word for the same fact.
#
# It goes in Signal and Verdict rather than in Status, because Status is the reviewer's column
# and holds what a person concluded. Those two are the run's own, and a run may say a check did
# not run - that is the only thing it is asserting here.
$SheetsRetiredMarker = 'Deprecated'
$SheetsRetiredReason = 'Withdrawn in POWERBI_REGISTRY.md. The check no longer runs for this ' +
'sport, so the counts that stood here belonged to the last run before it was withdrawn and ' +
'have been cleared rather than left to read as current. The CheckID is permanent and the row ' +
'and tab stay for good; the reviewer columns are untouched.'

# The two columns a reviewer owns inside a result block, appended to the right of whatever the
# statement returned.
#
# They exist because there was nowhere else. The runner protects Comment and Check By, but both
# are about the check - one pair for a tab holding a thousand findings - and somebody working
# through those findings one at a time needs to mark the one in front of them. On Triathlon
# they used eligible_count, which is the coverage column and is overwritten every run: 388
# cells of real review sitting in the one place guaranteed to be destroyed.
#
$SheetsRowReviewColumns = @('Review Status', 'Review Note')

# What a reviewer may conclude about one finding, and the only values Review Status offers.
#
# Three, drawn from what was actually written rather than from what a vocabulary ought to
# contain. 610 cells across one board held five spellings of four ideas, and two of them turned
# out to be one: no issue appeared only on the stray-participant check and no change only on the
# year-gap check, never side by side, so they were two checks' words for the same outcome rather
# than two outcomes. The value carries both words so neither reviewer's reading is overwritten.
#
# For IT was considered and left out: the check-level Status already has IT Fix, and nobody has
# yet needed to say it about a single row. A fourth value costs one line here and the migration
# makes adding one harmless, so the list stays as small as the evidence supports.
#
# Review Note is deliberately not constrained. It holds a sentence.
$SheetsRowReviewBands = @(
    [pscustomobject]@{ Value = 'Fixed'; Background = '#E6F4EA'; Colour = '#137333' }
    [pscustomobject]@{ Value = 'No Issue / Change'; Background = '#F1F3F4'; Colour = '#5F6368' }
    [pscustomobject]@{ Value = 'In Progress'; Background = '#E8F0FE'; Colour = '#1967D2' }
)

# The one of the three that closes a finding without changing the data, and the reason Overview
# needs to know about it at all.
#
# The other two settle themselves. A row marked Fixed usually leaves the result the next time the
# check runs, because the thing it described is no longer there - the count falls on its own and
# needs no help. Usually, not always, and the exception cost a reviewer's conclusion until
# 2026-08-25: see $SheetsRowReviewCarriedOnPayload for what happens when the row stays and reads
# differently. A row marked In Progress is still open work and belongs in the count for exactly as
# long as it says so. No Issue / Change is different in kind: the reviewer has decided the row is
# the sport rather than a defect, so the row stays in the result for good, and Overview's Rows
# goes on reporting work that nobody is ever going to do. On Golf-DQ-048 that was 251 of 283.
#
# So Rows counts what is still open and the dismissed rows come out of it. Findings, Eligible and
# Change are untouched: they are the run's own measurement of the database, and a reviewer's
# conclusion is not allowed to edit what a statement returned. The tab still holds every row.
$SheetsRowReviewDismissed = 'No Issue / Change'

# The one of the three that is about a state rather than about an object, and the only one that
# a changed row invalidates.
#
# `No Issue / Change` and `In Progress` are judgements about the thing the finding is about: this
# organization is a neutral entry, this stage is being corrected. The counts beside them moving
# does not touch either conclusion, and clearing them would ask the reviewer the same question
# every run until they stopped answering.
#
# `Fixed` says something different: that what was found is not there any more. The comment above
# used to assume the row would leave the result on its own and need no help, and that assumption
# does not hold. A row can leave and another take its place under the same key within one run,
# and a row can stay and hold a different reading - a country corrected from one wrong value to
# another. Either way the conclusion was reached about a reading nobody is looking at any more,
# and a green cell against a finding nobody has seen is worse than an empty one.
#
# So `Fixed` is carried over only against an identical row, and where the row differs the note
# goes to the Review log saying so. That log then answers a question nothing else can: which
# repairs were reported done and came back changed.
$SheetsRowReviewCarriedOnPayload = 'Fixed'

# What each spelling written before the list existed meant. Applied wherever a note passes
# through, so a cell reaches its new column already reading as one of the values above rather
# than being flagged by the dropdown the same run that introduced it.
#
# Keyed in lower case and matched that way, because the whole of the existing 610 was typed in
# lower case. A spelling not listed is left exactly as written - 'not found' is the one such
# cell, and guessing which of the three the reviewer meant would be inventing their conclusion
# rather than recording it. Sheets will flag it, which is the right way for them to be asked.
$SheetsRowReviewLegacy = @{
    'fixed'       = 'Fixed'
    'no issue'    = 'No Issue / Change'
    'no change'   = 'No Issue / Change'
    'in progress' = 'In Progress'
    'in prog'     = 'In Progress'
}

# What the first of them used to be called. A tab is found by its heading, so a rename would
# otherwise make every existing column invisible to the run that follows it - and invisible
# here means overwritten. Kept for the same reason $SheetsStatusLegacy is: a heading is a name
# for something, and renaming the name must not throw away the thing.
$SheetsRowReviewFormerColumns = @('Review')

# Where a note goes when the finding it belonged to is no longer in the result. Not the bin: a
# check that returned 1130 rows and now returns 800 has to be explainable, and "which 330 went
# and what had they been marked" is the question that answers it. Appended to, never rewritten.
$SheetsReviewLogTabName = 'Review log'
$SheetsReviewLogColumns = @('CheckID', 'Check tab', 'Finding key', 'Review Status', 'Review Note',
    'Dropped on', 'Why')

# What every recorded run of every check returned, on one tab, so a number that surprises
# somebody can be followed back through the runs that produced it.
#
# Overview's Trends column already carries five points per check and answers "is this moving".
# This answers the next question, which that cell cannot: moving since when, out of how large
# a population, and across which runs. Nothing here is new information - the ledger under
# RUNS/<Sport>.json has held all of it since the first run - it is the ledger made readable by
# somebody who will never open a JSON file.
#
# Long form, one row per check per run, rather than a run to a column. The obvious pivot is
# wrong for this ledger: most entries in it are single-check re-runs made while a statement was
# being written, and each would arrive as a column holding one number and a hundred and twenty
# blanks. A re-run costs one row here and reads as what it was.
#
# Every row is generated and none of it is anybody's, so the tab is rewritten whole each run
# for the reason the Review log is - a failed run must not leave half a block behind.
$SheetsHistoryTabName = 'History'
$SheetsHistoryColumns = @('CheckID', 'Check Name', 'Parameters', 'Run', 'Run date',
    'Findings', 'Eligible', 'Rate', 'Change', 'Verdict', 'Status')

# What a note is tied to. Not the row number - a fix removes a row and everything under it
# moves up, which would slide every note one finding along - and not the whole row either,
# because a name corrected elsewhere in the same row would orphan a note that is still about
# the same finding.
#
# The id columns, then. A result carries its audited object's id by the coverage contract, and
# ids are the part of a row that does not change while the row means the same thing; the names,
# counts and values beside them are the payload. Plural forms are deliberately not id columns:
# participant_ids on GLOBAL-DQ-030 is a list that grows and shrinks as people are corrected.
$SheetsFindingIdColumn = '_id$'

function ConvertTo-SheetsColumnName {
    # 1 -> A, 26 -> Z, 27 -> AA. The API takes A1 notation and the planner works in numbers,
    # because the reviewer-owned columns are easier to reason about as indices.
    param([int]$Index)

    $name = ''
    $n = $Index
    while ($n -gt 0) {
        $remainder = ($n - 1) % 26
        $name = [char](65 + $remainder) + $name
        $n = [int][math]::Floor(($n - 1) / 26)
    }
    return $name
}

function New-SheetsRange {
    param([int]$FromColumn, [int]$FromRow, [int]$ToColumn, [int]$ToRow)
    return '{0}{1}:{2}{3}' -f (ConvertTo-SheetsColumnName -Index $FromColumn), $FromRow,
        (ConvertTo-SheetsColumnName -Index $ToColumn), $ToRow
}

function Split-SheetsWritableSpans {
    # The contiguous column spans a run may write, given the ones a reviewer owns. Returned as
    # spans rather than as one range per cell because the API charges per range, and a sport's
    # Overview is fifty rows of twenty-one columns: two spans a row instead of eighteen.
    param([int]$Width, [int[]]$Reserved)

    $spans = @()
    $start = 0
    for ($column = 1; $column -le $Width; $column++) {
        if ($Reserved -contains $column) {
            if ($start -gt 0) { $spans += [pscustomobject]@{ From = $start; To = $column - 1 } }
            $start = 0
        }
        elseif ($start -eq 0) { $start = $column }
    }
    if ($start -gt 0) { $spans += [pscustomobject]@{ From = $start; To = $Width } }

    # Returned unwrapped. A leading comma would have preserved a one-element result and cost
    # the caller the multi-element one: @(...) around the call then sees a single item holding
    # the array rather than the spans themselves.
    return $spans
}

function Split-SheetsColumnRuns {
    # A set of column indices as contiguous spans, ascending. The API hides a range rather than
    # a list, so a scattered set is several ranges and collapsing it to one min..max would hide
    # everything in between.
    param([int[]]$Columns)

    $runs = @()
    $current = $null
    foreach ($column in @($Columns | Sort-Object -Unique)) {
        if ($null -ne $current -and $column -eq ($current.To + 1)) { $current.To = $column; continue }
        if ($null -ne $current) { $runs += $current }
        $current = [pscustomobject]@{ From = $column; To = $column }
    }
    if ($null -ne $current) { $runs += $current }
    return $runs
}

function Get-SheetsResultColumnWidths {
    # The column spans of a result block, each sized from its own header name and merged with
    # the neighbour where the two agree. Merged because the API sets a width over a range: a
    # twelve-column table asking one request per column costs twelve, and most of the widths a
    # table wants are the same handful of numbers sitting next to each other.
    param(
        [string[]]$Header,
        # Column A also carries the way back to Overview and was widened for that alone. Its
        # header must not shrink it back under the link.
        [int]$FirstColumnWidth = 0
    )

    $widths = @()
    for ($index = 0; $index -lt @($Header).Count; $index++) {
        $want = ([string]$Header[$index]).Length * $SheetsResultColumnCharWidth + $SheetsResultColumnPadding
        if ($want -lt $SheetsResultColumnMinWidth) { $want = $SheetsResultColumnMinWidth }
        if ($want -gt $SheetsResultColumnMaxWidth) { $want = $SheetsResultColumnMaxWidth }
        if ($index -eq 0 -and $want -lt $FirstColumnWidth) { $want = $FirstColumnWidth }
        $widths += [int]$want
    }

    $spans = @()
    $start = 0
    for ($index = 1; $index -le $widths.Count; $index++) {
        if ($index -eq $widths.Count -or $widths[$index] -ne $widths[$start]) {
            $spans += [pscustomobject]@{ From = $start + 1; To = $index; Width = $widths[$start] }
            $start = $index
        }
    }
    return $spans
}

function ConvertTo-SheetsColour {
    # #RRGGBB as the API wants it: three channels from zero to one, not from zero to 255.
    param([string]$Hex)

    $value = $Hex.TrimStart('#')
    return @{
        red   = [int]::Parse($value.Substring(0, 2), 'HexNumber') / 255
        green = [int]::Parse($value.Substring(2, 2), 'HexNumber') / 255
        blue  = [int]::Parse($value.Substring(4, 2), 'HexNumber') / 255
    }
}

function ConvertTo-SheetsTableName {
    # A table name has to be usable inside a formula, so Sheets allows letters, digits and
    # underscores and refuses to start on a digit. A CheckID is full of hyphens, which is why
    # the first live run of this came back with "The table name is invalid" - the probe that
    # went before it was called "probe" and proved only that a legal name is legal.
    param([string]$Name)

    $safe = [regex]::Replace([string]$Name, '[^A-Za-z0-9_]', '_')
    if ($safe -notmatch '^[A-Za-z_]') { $safe = '_' + $safe }
    return $safe
}

function Get-SheetsFindingKeyColumns {
    # Which of a result's columns identify the finding, as indices into its header. The id
    # columns, and every one of them rather than the first: a Comp.Rank row naming a statistic
    # and a participant is one finding about that pair, and keying on the statistic alone would
    # give two of its rows the same key.
    #
    # A result with no id column at all falls back to every column, which keys on the whole row.
    # That is conservative rather than clever - it parks a note whenever anything in the row
    # changed - and it is the right failure for a statement whose findings have no id to be
    # about.
    param($Header)

    $columns = @($Header)
    if ($columns.Count -eq 0) { return @() }

    # Column 0 is check_type by the coverage contract, and it always leads: a statement emitting
    # two of them is making two different assertions, and the same object can appear under both.
    $ids = @(0)
    for ($i = 1; $i -lt $columns.Count; $i++) {
        if ([string]$columns[$i] -match $SheetsFindingIdColumn) { $ids += $i }
    }
    if ($ids.Count -gt 1) { return $ids }
    return @(0..($columns.Count - 1))
}

function Get-SheetsFindingKey {
    # One finding's identity: what it is a finding of, and about which objects. The check type
    # leads because a statement emitting two of them is making two different assertions, and the
    # same object can legitimately appear under both.
    param($Row, $Columns)

    $parts = @()
    foreach ($index in @($Columns)) {
        $value = $(if ($index -lt @($Row).Count) { [string]@($Row)[$index] } else { '' })
        $parts += $value.Trim()
    }
    return ($parts -join "`u{001F}")
}

function Get-SheetsRowFingerprint {
    # What was actually found, as against what the finding is about. The key answers the second
    # question and deliberately leaves out the payload - the counts, the values, the samples -
    # because those move while the row goes on meaning the same thing. This is the other half:
    # every data column of one row, so two rows can be asked whether they are the same reading.
    #
    # Only `Fixed` needs it, and only because `Fixed` is the one conclusion that is about a state
    # rather than about an object. See $SheetsRowReviewCarriedOnPayload.
    #
    # A number is compared as a number. The cells come back from Sheets as they were rendered and
    # the new row's values come from the query, so 4 on one side can be 4.0 on the other; a
    # difference of formatting is not a difference of finding. Everything else is compared
    # trimmed and literally.
    #
    # Both cultures are tried, invariant first, and thousands separators are not allowed in
    # either. The machine this runs on writes decimals with a comma and the sheet may render them
    # either way, so one culture alone would fail to read one side of the pair and report a
    # change that is only a rendering. Allowing thousands would go the other way and make 1,234
    # and 1234 the same reading, which is the direction that matters: failing to see a change is
    # what leaves a green cell on a finding nobody has looked at.
    param($Values)

    $style = [globalization.numberstyles]::Float
    $parts = @()
    foreach ($value in @($Values)) {
        $text = ([string]$value).Trim()
        $number = 0.0
        if ([double]::TryParse($text, $style, [cultureinfo]::InvariantCulture, [ref]$number) -or
            [double]::TryParse($text, $style, [cultureinfo]::CurrentCulture, [ref]$number)) {
            $parts += $number.ToString('R', [cultureinfo]::InvariantCulture)
        } else {
            $parts += $text
        }
    }
    return ($parts -join "`u{001F}")
}

function Get-SheetsReviewColumnIndex {
    # Where the reviewer's block starts in a result header, under its current heading or any it
    # has had before. Only the first of the two columns is looked for, because they are adjacent
    # and the second follows from it.
    #
    # The former names matter more than they look. A tab is found by its heading, so renaming a
    # column makes every existing one invisible to the next run - and invisible here means
    # cleared and rewritten empty, which is exactly the loss these columns were added to stop.
    param($Header)

    foreach ($name in (@($SheetsRowReviewColumns[0]) + $SheetsRowReviewFormerColumns)) {
        $at = [array]::IndexOf(@($Header), $name)
        if ($at -ge 0) { return $at }
    }
    return -1
}

function ConvertTo-SheetsReviewStatus {
    # One reviewer's word, in the spelling the column now offers. A value already current is
    # returned untouched, and one nobody has declared is returned exactly as it was written:
    # this renames a conclusion, it never forms one.
    param([string]$Value)

    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) { return $text }

    $trimmed = $text.Trim()
    foreach ($band in $SheetsRowReviewBands) {
        if ($trimmed -eq $band.Value) { return $band.Value }
    }

    $key = $trimmed.ToLowerInvariant()
    if ($SheetsRowReviewLegacy.ContainsKey($key)) { return $SheetsRowReviewLegacy[$key] }
    return $text
}

function New-SheetsCarriedReview {
    <#
        Last run's notes matched to this run's findings, and what could not be matched.

        Returns two columns the length of the result - the review and the note for each row,
        empty where there was nothing - and the list of notes with nowhere to go. Nothing is
        guessed: a note goes back only against a finding with the same key, and everything else
        is reported so it can be logged rather than quietly dropped.

        A check whose shape changed is the case worth naming. When the columns a key is built
        from are not the ones it was built from last time, the old keys cannot match the new
        ones however similar the findings are - GLOBAL-DQ-030 went from one row per stray
        participant to one row per statistic on 2026-08-11 and its 310 notes were keyed on a
        column the new result does not emit. That is not a fix and must not read like one, so
        those notes are dropped with the reason spelled out.
    #>
    param($Header, $Rows, $Was, $Notes)

    $review = @()
    $note = @()
    foreach ($row in @($Rows)) { $review += ''; $note += '' }

    # Filtered rather than taken as given. An empty array reaching an untyped parameter arrives
    # as $null, and @($null) is one element rather than none - which read as a single nameless
    # note and had every first run announcing that the check had been re-shaped.
    # Renamed on the way in, so both destinations agree: a note put back beside its finding and
    # one written to the log read the same, and a cell reaches the column already spelled the
    # way the dropdown offers rather than being flagged by the run that introduced it.
    $held = @(@($Notes) | Where-Object { $_ } | ForEach-Object {
            [pscustomobject]@{
                Key         = $_.Key
                Review      = (ConvertTo-SheetsReviewStatus -Value $_.Review)
                Note        = $_.Note
                Fingerprint = [string]$_.Fingerprint
            }
        })
    if ($held.Count -eq 0) {
        return [pscustomobject]@{ Review = $review; Note = $note; Dropped = @() }
    }

    # Both keyed the same way or not comparable at all. The old header is what the notes were
    # keyed against when they were read; the new one is what this run will key against.
    $wasHeader = @(@($Was) | Where-Object { $null -ne $_ })
    $now = @(Get-SheetsFindingKeyColumns -Header $Header)
    $before = @(Get-SheetsFindingKeyColumns -Header $wasHeader)
    $sameShape = (($wasHeader.Count -gt 0) -and
        ((@($now | ForEach-Object { [string]@($Header)[$_] }) -join '|') -eq
         (@($before | ForEach-Object { [string]$wasHeader[$_] }) -join '|')))

    if (-not $sameShape) {
        $dropped = @($held | ForEach-Object {
                [pscustomobject]@{
                    Key = $_.Key; Review = $_.Review; Note = $_.Note
                    Why = 'the check was re-shaped, so the columns a note is tied to are not the ones it was written against'
                }
            })
        return [pscustomobject]@{ Review = $review; Note = $note; Dropped = $dropped }
    }

    # A key that two findings share is not a key, and the run has to say so rather than pick one.
    #
    # Before 2026-08-25 the first row won and every later note with that key was written over it:
    # two notes landed on one row, the second overwrote the first, the rows below came back blank,
    # and because the key had been found nothing reached the Review log. A reviewer's conclusion
    # was erased without a trace, and the row returned reading as though nobody had looked at it.
    # Measured on Artistic-Gymnastics-DQ-111, which returns two findings about organization
    # 1611294 under two different templates: `GLOBAL-DQ-136` projects `template_name` and no
    # `template_id`, so the id key is `check_type` plus `organization_id` and both rows carry it.
    #
    # The keys that repeat are collected first and their notes are logged rather than placed. Not
    # widened to the whole row on the spot, because the widening would depend on the data: a run
    # whose rows happen not to collide would narrow the key again and orphan every note the wide
    # run had written. A key has to mean the same thing from one run to the next, so the shape
    # stays fixed and the ambiguity is reported. The repair is to give the statement the id its
    # name already implies, which is the rule DATABASE.md states for the database and this file
    # depends on: an id travels with the name of the thing it identifies.
    $rowOfKey = @{}
    $ambiguous = @{}
    $printOfRow = @()
    for ($r = 0; $r -lt @($Rows).Count; $r++) {
        $values = @($Header | ForEach-Object { @($Rows)[$r].$_ })
        $printOfRow += (Get-SheetsRowFingerprint -Values $values)
        $key = Get-SheetsFindingKey -Row $values -Columns $now
        if ($rowOfKey.ContainsKey($key)) { $ambiguous[$key] = $true; continue }
        $rowOfKey[$key] = $r
    }

    $dropped = @()
    foreach ($one in $held) {
        if ($ambiguous.ContainsKey($one.Key)) {
            $dropped += [pscustomobject]@{
                Key = $one.Key; Review = $one.Review; Note = $one.Note
                Why = 'more than one finding in this result carries this key, so the note cannot be told which of them it is about'
            }
            continue
        }
        if ($rowOfKey.ContainsKey($one.Key)) {
            $at = $rowOfKey[$one.Key]

            # `Fixed` is the one conclusion about a state rather than about an object, so it
            # holds only against the row it was reached about. Anything else in the row having
            # moved means the reviewer is looking at a reading they have not seen.
            if ($one.Review -eq $SheetsRowReviewCarriedOnPayload -and
                $one.Fingerprint -ne $printOfRow[$at]) {
                $dropped += [pscustomobject]@{
                    Key = $one.Key; Review = $one.Review; Note = $one.Note
                    Why = 'it was marked ' + $SheetsRowReviewCarriedOnPayload +
                          ' and the finding under that key came back reading differently'
                }
                continue
            }

            $review[$at] = [string]$one.Review
            $note[$at] = [string]$one.Note
            continue
        }
        $dropped += [pscustomobject]@{
            Key = $one.Key; Review = $one.Review; Note = $one.Note
            Why = 'the finding is no longer in the result'
        }
    }

    return [pscustomobject]@{ Review = $review; Note = $note; Dropped = $dropped }
}

function ConvertTo-SheetsIdentityTableName {
    # The name of a check tab's identity table: the whole CheckID and what the block is.
    #
    # The prefix used to be dropped here, on the reasoning that every tab belongs to one sport
    # and so the sport distinguishes nothing. That is false, and the document it broke says how:
    # a sport board carries the sport's own checks beside the GLOBAL templates it runs, and the
    # two number themselves independently, so Cycling-DQ-019 and GLOBAL-DQ-019 both arrived here
    # as DQ_019_Overview. A table name has to be unique across the whole spreadsheet, and Google
    # answers a duplicate with 500 Internal error rather than a message naming the clash - so a
    # single colliding request took the whole atomic batch with it and the document went 92 tabs
    # without a table, with nothing in the output saying which request was at fault.
    #
    # The result table below it never had the defect: it is named for the CheckID in full, which
    # is why GLOBAL_DQ_019 and Cycling_DQ_019 have always coexisted on the same board.
    param([string]$CheckId)

    return (ConvertTo-SheetsTableName -Name ([string]$CheckId + '_Overview'))
}

function New-SheetsCommentMirror {
    # The formula Overview's Comment holds: a reference to the Comment cell of that check's own
    # tab. Derived from the column list rather than written as a literal, for the reason given
    # beside $SheetsCheckTabReviewerColumns - the cell was G2, is E2, and the two places that
    # emit this must not be able to disagree with the layout or with each other.
    param([string]$Sheet)

    $cell = (ConvertTo-SheetsColumnName -Index ([array]::IndexOf($SheetsCheckTabColumns, 'Comment') + 1)) + '2'
    return "='" + ($Sheet -replace "'", "''") + "'!" + $cell
}

function New-SheetsGidLink {
    # A link to another tab of the same document, and optionally to a cell in it. The tab is
    # named rather than numbered because a tab this run is creating has no number yet;
    # Invoke-SheetsPlan substitutes the real one once the structure batch has answered.
    param([string]$Sheet, $Text, [string]$Cell)

    $target = '#gid=' + ($SheetsGidToken -replace '%NAME%', $Sheet)
    if ($Cell) { $target += '&range=' + $Cell }

    # A number goes in unquoted, so the cell holds a number. Overview's Rows is the only caller
    # that passes one, and the difference is not cosmetic: quoted, it is text that sorts
    # 1, 10, 2 and that a conditional format comparing against 100 never matches. Formatted
    # under the invariant culture, because a machine set to bg-BG writes a decimal comma and
    # Sheets would read the formula as two arguments.
    $label = $(if ($Text -is [string] -or $null -eq $Text) {
            '"' + ([string]$Text -replace '"', '""') + '"'
        }
        else { [string]::Format([Globalization.CultureInfo]::InvariantCulture, '{0}', $Text) })
    return '=HYPERLINK("{0}",{1})' -f $target, $label
}

# What the board's Object column says, from the value POWERBI_REGISTRY.md records.
#
# The registry distinguishes a check on an event from one on that event's results, and a check
# on a Comp.Rank from one on its results. That distinction is real and it stays where it is
# written; it is not what the board is navigated by. A reviewer working through a sport needs
# to know which layer to repair first, because a Comp.Rank is generated from the events beneath
# it and fixing the ranking before the events is work that gets undone. Six words answer that
# and nine do not, so the board collapses the pairs and the registry keeps them.
#
# A value nobody has mapped is passed through rather than blanked. The column is visible and a
# word that looks out of place is a question somebody asks; an empty cell is one nobody sees.
$SheetsBoardObject = @{
    'EVENT'               = 'Event'
    'EVENT_RESULTS'       = 'Event'
    'COMP.RANK'           = 'Comp Rank'
    'COMP.RANK_RESULTS'   = 'Comp Rank'
    'TOURNAMENT_STAGE'    = 'Stage'
    'TOURNAMENT'          = 'Tournament'
    'TEMPLATE'            = 'Template'
    'TOURNAMENT_TEMPLATE' = 'Template'
    'PARTICIPANT'         = 'Participant'
}

function ConvertTo-SheetsObjectName {
    # One registry Object as the board says it. Empty in, empty out: a discovery statement and
    # a template run by hand have no registry row and so no object, and inventing one for them
    # would put a word on the board that nothing authored.
    param([string]$Value)

    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) { return '' }

    $key = $text.Trim().ToUpperInvariant()
    if ($SheetsBoardObject.ContainsKey($key)) { return $SheetsBoardObject[$key] }
    return $text.Trim()
}

function New-SheetsOverviewRow {
    # One Overview row in column order, from the summary entry the run already built. The
    # reviewer's three columns are placed as $null: the planner writes around them on a row
    # that exists, and seeds them only on a row it is adding.
    param($Entry, [string]$SeededStatus)

    return @(
        [string]$Entry.Sport
        [string]$Entry.CheckId
        (ConvertTo-SheetsObjectName -Value ([string]$Entry.Object))
        [string]$Entry.Name
        [string]$Entry.Priority
        [string]$Entry.Category
        [string]$Entry.What
        $Entry.RowsCell
        $SeededStatus
        ''
        ''
        # Time Spent (minutes). Blank on a row being added and never touched again: the run has
        # nothing to say about how long a check took somebody, and no formula puts a number here.
        ''
        [string]$Entry.Signal
        [string]$Entry.SignalReason
        [string]$Entry.Expected
        # Findings and All findings both leave here as the raw count. What the reviewers have
        # settled is not known to the run - it is read off the live document - so the
        # subtraction belongs to the merge, which is the only place that has both numbers.
        # Set-SheetsOpenCounts does it, to this array, before anything is written.
        $Entry.Findings
        $Entry.Findings
        $Entry.Eligible
        $Entry.PrevFindings
        $Entry.PrevEligible
        $Entry.Change
        [string]$Entry.Verdict
        [string]$Entry.PrevRunId
        [string]$Entry.Trend
        # Last, and outside the Signal-to-Trends span the planner writes as one block, because
        # it is the only column here that describes the statement rather than what the run
        # returned. See TOOLS/README.md "Narrowing a run to one kind of stored value".
        [string]$Entry.DataTypes
    )
}

function Get-SheetsColumnInsertions {
    <#
        Where a column has been added since a tab was last written, as indices into the current
        column list.

        A run rewrites the rows it produced and leaves every other row exactly as it found it -
        which is right, because those rows hold the last full run's numbers and nobody else's
        run is entitled to guess at them. But a column added in the middle of the list changes
        what each position means, and a row nobody rewrote then reads one column to the left of
        itself: on the board this was found on, a retired check showed its Eligible under All
        findings, its Trends under Last run, and a Change cell reading "Not in this run".

        Nothing was corrupted and nothing could be seen to be wrong from the cell alone, which
        is the part worth fixing. The answer is to make room before writing rather than to
        rewrite rows this run has no business rewriting: an inserted column pushes what is
        already there to the right, so every untouched row lands back under its own headings.

        Only insertion is reported. A column removed or moved is not migrated and deliberately
        so - both would mean deleting or reordering cells that hold somebody's data, and that is
        a decision rather than a repair. A board whose header cannot be reconciled by insertion
        alone is left as it is and rewritten by the run, which is the behaviour that was there
        before this existed.
    #>
    param($Was, $Now)

    $old = @($Was | ForEach-Object { [string]$_ })
    $new = @($Now | ForEach-Object { [string]$_ })
    if ($old.Count -eq 0) { return @() }

    $insertions = @()
    $at = 0
    for ($i = 0; $i -lt $new.Count; $i++) {
        $name = [string]$new[$i]
        if ($at -lt $old.Count -and [string]$old[$at] -eq $name) { $at++; continue }
        # Present in the old header but not here: moved or the two have gone out of step, which
        # is not something an insertion can put right. Nothing is emitted for it.
        if ($old -contains $name) { continue }
        $insertions += $i
    }

    # Every old column has to be accounted for, or this is not a pure insertion and the indices
    # would push somebody's cells somewhere arbitrary. Better to leave the board alone.
    if ($at -ne $old.Count) { return @() }
    return $insertions
}

function Get-SheetsOpenCounts {
    <#
        One check's numbers with the reviewers' settled rows taken out of them.

        A row marked No Issue / Change is one somebody has already read and decided about, and
        it stays in the result for good, because the decision is a reading of the data rather
        than a change to it. Counting it forever made a finished check read as a busy one -
        and only Rows had the subtraction, so the board disagreed with the five columns beside
        it about how much work was left.

        What comes off here: Findings, Prev findings, Change, Verdict, and every point of the
        trend. What does not: All findings, which is the statement's own result, and Eligible
        and Prev eligible, which count the population a finding came out of. Dismissing a
        finding does not shrink the population it was found in.

        The count is today's, and it comes off the historical points as well, because nobody
        recorded a per-run figure to use instead. That is the honest reading rather than a
        convenient one: a reduced present against a raw past would invent a drop on the day the
        reviewers worked, and the trend exists to answer which way the open work is moving. It
        also leaves Change alone, since the same figure comes off both ends of it.

        Returns the pieces rather than writing them, so the Overview row and the check tab's
        identity row take the same numbers from one calculation instead of each doing it.
    #>
    param($Entry, [int]$Dismissed)

    $open = $Entry.Findings
    $prev = $Entry.PrevFindings
    $change = $Entry.Change
    $verdict = [string]$Entry.Verdict
    $trend = [string]$Entry.Trend
    $trendRuns = $Entry.TrendRuns

    if ($Dismissed -gt 0) {
        if ($null -ne $open) { $open = [math]::Max(0, [int]$open - $Dismissed) }
        if ($null -ne $prev) { $prev = [math]::Max(0, [int]$prev - $Dismissed) }
        if ($null -ne $open -and $null -ne $prev) { $change = [int]$open - [int]$prev }

        # Re-judged rather than adjusted. The verdict is not a number to subtract from: whether
        # a check is Clean, Resolved or Above residual is decided by rules that read the count
        # against an expectation, and the count they have to read is the open one.
        $previous = $null
        if ($null -ne $prev) {
            $previous = [pscustomobject]@{ Findings = $prev; Eligible = $Entry.PrevEligible }
        }
        $ran = -not ([string]$Entry.Status -like 'ERROR*' -or [string]$Entry.Status -like 'SKIPPED*')
        $verdict = Get-CheckVerdict -Expected ([string]$Entry.Expected) `
            -Residual $Entry.ExpectedResidual -Findings $open -Eligible $Entry.Eligible `
            -Previous $previous -Ran $ran -Signal ([string]$Entry.Signal)

        # The series is rebuilt from its points rather than edited as a string: the colouring
        # is per point and comes from the direction between neighbours, and a point that reads
        # ERR is not a measurement and must stay the word it is.
        $points = @($Entry.TrendPoints)
        if ($points.Count -gt 1) {
            $shifted = @()
            foreach ($point in $points) {
                $value = [string]$point.Value
                $number = 0
                if ([int]::TryParse($value, [ref]$number)) {
                    $value = [string][math]::Max(0, $number - $Dismissed)
                }
                $shifted += [pscustomobject]@{ Value = $value; Stamp = $point.Stamp }
            }
            $series = New-TrendSeries -Points $shifted
            $trend = $series.Text
            $trendRuns = $series.Runs
        }
    }

    return [pscustomobject]@{
        Findings     = $open
        AllFindings  = $Entry.Findings
        PrevFindings = $prev
        Change       = $change
        Verdict      = $verdict
        Trend        = $trend
        TrendRuns    = $trendRuns
    }
}

function New-SheetsMergePlan {
    <#
        What to send, given what the run produced and what the document already holds.

        Two rules shape all of it, and both exist because the document outlives the run.

        A row is found by its CheckID, never by its position. Writing the Overview as a
        positional block is the obvious implementation and it is wrong: adding one check in
        the middle shifts every row below it, and each reviewer comment then describes the
        check above the one it was written for. So an existing check is updated in the row it
        already occupies, wherever the reviewer has since moved or sorted it to, and a new
        check is appended at the bottom rather than slotted into CheckID order. Sorting is
        the reviewer's to do, and theirs to keep.

        A tab is never deleted. A check that stopped running - deprecated, dropped from the
        registry, no longer approved - keeps its tab and its comments, and is marked instead.
        Deleting it would throw away the one thing in the document nobody can regenerate.
    #>
    param(
        $Summary,
        $Collected,
        $Existing,
        [string]$OutputFolder,
        [int]$MaxRows = $SheetsMaxRowsPerCheck,
        [string]$Stamp = '',
        $History = @(),
        [string[]]$Retired = @(),
        [switch]$Complete
    )

    $plan = @()
    # Notes this run could not put back beside a finding, gathered across every tab and written
    # to the log in one block at the end.
    $dropped = @()
    $width = $SheetsOverviewColumns.Count
    $overviewSpans = Split-SheetsWritableSpans -Width $width -Reserved $SheetsOverviewReviewerColumns

    # Room for a column the package has added since this document was last written, made before
    # anything is written into it. Both boards get it: Overview, and each check tab's own
    # identity row, which carries the same set of counts and grew the same way.
    #
    # It has to happen first, and it does - Invoke-SheetsPlan sends the structure batch before
    # any values - so a row this run does rewrite lands in the layout the insertion just made,
    # and a row it does not is pushed along with it. The alternative was rewriting rows the run
    # did not produce, which would have replaced somebody's last full run with a guess.
    if ($Existing -and $Existing.OverviewHeader) {
        foreach ($at in @(Get-SheetsColumnInsertions -Was $Existing.OverviewHeader -Now $SheetsOverviewColumns)) {
            $plan += [pscustomobject]@{ Kind = 'InsertColumn'; Sheet = 'Overview'; At = [int]$at }
        }
    }
    # A check tab is migrated by moving two rows, never by inserting a column. Overview is a
    # board where every row has the same columns, so making room in the sheet is exactly right
    # there. A check tab is not: rows 1 and 2 are the identity, row 5 down is the result, and
    # the two have nothing to do with each other. insertDimension does not know that - it takes
    # the whole column - so the first version of this pushed a column through every result table
    # on the board. The tables were rebuilt at their proper width straight afterwards and no
    # value moved, but Sheets had already named the column it briefly saw, and 107 tabs came
    # back with the words "Column 11" sitting beside their result headers.
    #
    # So the values are placed by name instead. Only a tab this run does not produce can need
    # it - anything it does produce has both rows rewritten below - and a name that has no old
    # column simply arrives empty.
    if ($Existing -and $Existing.CheckTabHeaderOf) {
        foreach ($title in @($Existing.CheckTabHeaderOf.Keys)) {
            $was = @($Existing.CheckTabHeaderOf[$title])
            if ($was.Count -eq 0) { continue }
            if (@(Get-SheetsColumnInsertions -Was $was -Now $SheetsCheckTabColumns).Count -eq 0) { continue }

            $had = @()
            if ($Existing.CheckTabIdentityOf -and $Existing.CheckTabIdentityOf.ContainsKey($title)) {
                $had = @($Existing.CheckTabIdentityOf[$title])
            }
            $moved = @()
            foreach ($name in $SheetsCheckTabColumns) {
                $from = [array]::IndexOf($was, [string]$name)
                $moved += $(if ($from -ge 0 -and $from -lt $had.Count) { $had[$from] } else { '' })
            }

            # Both rows in one write, the names above the values they name. The reviewer's own
            # cells travel with everything else: they are being carried to where they now
            # belong, not overwritten, and their content is what was just read off this tab.
            $plan += [pscustomobject]@{
                Kind   = 'Write'
                Sheet  = [string]$title
                Range  = (New-SheetsRange -FromColumn 1 -FromRow 1 `
                        -ToColumn $SheetsCheckTabColumns.Count -ToRow 2)
                Values = @($SheetsCheckTabColumns, $moved)
            }
        }
    }

    $rowOf = @{}
    if ($Existing -and $Existing.OverviewRowOf) {
        foreach ($key in $Existing.OverviewRowOf.Keys) { $rowOf[$key] = [int]$Existing.OverviewRowOf[$key] }
    }
    $tabOf = @{}
    if ($Existing -and $Existing.TabOf) {
        foreach ($key in $Existing.TabOf.Keys) { $tabOf[$key] = [string]$Existing.TabOf[$key] }
    }

    # Every title already in the document, plus the ones this plan is about to mint. Two check
    # names can abbreviate to the same string, and addSheet fails outright on a duplicate
    # title - which would take the whole run's document update with it. Sheets allows 100
    # characters where Excel allows 31, so nothing is truncated here; only collisions are
    # resolved, the same way the workbook resolves them.
    $usedTitles = @{}
    if ($Existing -and $Existing.Titles) {
        foreach ($title in @($Existing.Titles)) { $usedTitles[[string]$title] = $true }
    }
    $usedTitles['Overview'] = $true

    # Copied rather than used in place: adoption removes from it, and mutating the caller's
    # state object would leave a second call on the same state seeing a different document.
    $emptyTabs = @{}
    if ($Existing -and $Existing.EmptyTabs) {
        foreach ($title in @($Existing.EmptyTabs.Keys)) { $emptyTabs[[string]$title] = $true }
    }
    $emptyTabs.Remove('Overview')

    # A new document has one tab called Sheet1 and no Overview. The tab has to exist before
    # anything names it in a range - Google rejects the whole batch with "Unable to parse
    # range" otherwise - and Invoke-SheetsPlan sends every AddSheet before any write.
    if (-not $Existing -or -not $Existing.HasOverviewSheet) {
        $plan += [pscustomobject]@{ Kind = 'AddSheet'; Sheet = 'Overview' }
    }

    # The columns the board ships closed, on a new document and on every run that covers the
    # whole sport. Creation alone was the rule until 2026-08-17, on the reasoning that somebody
    # who unhides one has decided something and putting it back weekly is the same defect as
    # overwriting a comment. The reviewers asked for the opposite and it is their board: a full
    # sport pass is the moment the document is remade for reading, and these are the columns
    # that are noise while reading it.
    #
    # The cost is real and is theirs to accept - a column unhidden between two full passes
    # closes again on the next one. A partial run still leaves them exactly as it found them,
    # so re-running one check after a fix does not repaint the board.
    #
    # One operation per contiguous run, not one spanning the lowest to the highest. That
    # shortcut held while the hidden columns were the adjacent L and M; adding C to the list
    # would have hidden C through M and taken Check Name, Rows and Status with it.
    #
    # Stated in full rather than added to: the six are hidden and every other column the board
    # writes is shown. Hiding alone was what this did, and it made the board's layout a function
    # of its own history rather than of this file. Three documents went through one run on
    # 2026-08-17 and came out with three different answers - BMX with the six, Cycling with four
    # of them, and Triathlon with twelve, including Findings, Change, Verdict and Trends. A
    # column inserted in the middle carries its neighbour's hidden flag and moves everybody
    # else's along the row, and nothing ever put any of it back.
    if (-not $Existing -or -not $Existing.HasOverviewSheet -or $Complete) {
        $shown = @(1..$width | Where-Object { $SheetsOverviewHiddenColumns -notcontains $_ })
        foreach ($state in @(
                @{ Columns = $SheetsOverviewHiddenColumns; Hidden = $true }
                @{ Columns = $shown; Hidden = $false })) {
            foreach ($span in @(Split-SheetsColumnRuns -Columns $state.Columns)) {
                $plan += [pscustomobject]@{
                    Kind = 'HideColumns'; Sheet = 'Overview'
                    From = $span.From; To = $span.To; Hidden = [bool]$state.Hidden
                }
            }
        }
    }

    # The colour bands on Rows, replacing whatever this run finds on that one column. Emitted
    # on every run and not only at creation: a band changed in the source has to reach the
    # documents that already exist, which is the defect that left one board with a column
    # Sheets had to name for itself.
    $rowsColumnIndex = [array]::IndexOf($SheetsOverviewColumns, 'Rows') + 1
    $statusColumnIndex = [array]::IndexOf($SheetsOverviewColumns, 'Status') + 1
    $changeColumnIndex = [array]::IndexOf($SheetsOverviewColumns, 'Change') + 1
    $verdictColumnIndex = [array]::IndexOf($SheetsOverviewColumns, 'Verdict') + 1
    $existingRules = @()
    if ($Existing -and $Existing.ConditionalFormatsOf -and $Existing.ConditionalFormatsOf.ContainsKey('Overview')) {
        $existingRules = @($Existing.ConditionalFormatsOf['Overview'])
    }

    # Every column's rules are dropped in one pass. Deleting by index renumbers what follows,
    # so two planner entries each computing its own indexes against the same original list
    # would have the second one delete a rule the first had already shifted.
    $ruled = @($rowsColumnIndex, $statusColumnIndex, $changeColumnIndex, $verdictColumnIndex)
    $dropOf = @{}
    foreach ($column in $ruled) { $dropOf[$column] = @() }
    for ($index = 0; $index -lt $existingRules.Count; $index++) {
        # Only a rule covering exactly one of these columns. One drawn across the whole board,
        # or over any other column, was somebody's and is left where it is.
        $ranges = @($existingRules[$index].ranges)
        if ($ranges.Count -eq 0) { continue }
        foreach ($column in $ruled) {
            $mine = @($ranges | Where-Object {
                    [int]$_.startColumnIndex -eq ($column - 1) -and
                    [int]$_.endColumnIndex -eq $column })
            if ($mine.Count -eq $ranges.Count) { $dropOf[$column] += $index }
        }
    }

    # Change and Verdict read the way Trends does: down is the check improving, up is it getting
    # worse, and level is neither. The reviewers asked for it and the reason is the same one the
    # trend colouring already answers - which way is this moving - except that a trend is read
    # per check and these two are read down a column of a hundred.
    #
    # Change carries the numbers, so it takes plain numeric rules. Verdict carries a word, and a
    # word cannot be compared to zero - so its rule reads the Change cell on its own row through
    # a custom formula. The column is addressed absolutely and the row relatively, against a
    # range that starts on row 2, which is what makes one rule follow every row down.
    $changeCell = '$' + (ConvertTo-SheetsColumnName -Index $changeColumnIndex) + '2'
    $movementBands = @(
        @{ Down = @{ Type = 'NUMBER_LESS'; Values = @('0') }
            Up = @{ Type = 'NUMBER_GREATER'; Values = @('0') }
            Level = @{ Type = 'NUMBER_EQ'; Values = @('0') }
            Column = $changeColumnIndex }
        @{ Down = @{ Type = 'CUSTOM_FORMULA'; Values = @("=AND($changeCell<>`"`", $changeCell<0)") }
            Up = @{ Type = 'CUSTOM_FORMULA'; Values = @("=AND($changeCell<>`"`", $changeCell>0)") }
            Level = @{ Type = 'CUSTOM_FORMULA'; Values = @("=AND($changeCell<>`"`", $changeCell=0)") }
            Column = $verdictColumnIndex }
    )
    foreach ($band in $movementBands) {
        $plan += [pscustomobject]@{
            Kind   = 'FormatRules'
            Sheet  = 'Overview'
            Column = [int]$band.Column
            Drop   = $dropOf[[int]$band.Column]
            # The trend's own three colours, read from the same map rather than repeated here.
            # These two columns and that series answer one question between them, and a green
            # that drifted apart from the green beside it would be worse than no colour at all.
            Rules  = @(
                [pscustomobject]@{ Type = $band.Down.Type; Values = $band.Down.Values; Colour = $SheetsTrendColours['down'] }
                [pscustomobject]@{ Type = $band.Up.Type; Values = $band.Up.Values; Colour = $SheetsTrendColours['up'] }
                [pscustomobject]@{ Type = $band.Level.Type; Values = $band.Level.Values; Colour = $SheetsTrendColours['level'] }
            )
        }
    }
    $plan += [pscustomobject]@{
        Kind   = 'FormatRules'
        Sheet  = 'Overview'
        Column = $rowsColumnIndex
        Drop   = $dropOf[$rowsColumnIndex]
        Rules  = $SheetsRowsBands
    }

    $plan += [pscustomobject]@{
        Kind   = 'Validation'
        Sheet  = 'Overview'
        Column = $statusColumnIndex
        Name   = 'Status'
        Values = @($SheetsStatusBands | ForEach-Object { $_.Value })
    }

    # The whole board centred, header and rows alike, and following the sheet down rather than
    # stopping where this run's rows did.
    $plan += [pscustomobject]@{
        Kind    = 'Format'; Sheet = 'Overview'
        FromRow = 0; ToRow = $null; FromCol = 0; ToCol = $width; Align = 'CENTER'
    }

    # The three columns the default width does not fit: a heading nobody can read at eleven
    # characters, a series meant to be read across, and a list of types meant to be scanned.
    # Set on every run rather than at creation, because a board that already exists is the one
    # that needs them.
    foreach ($sized in @(
            @{ Name = 'Time Spent (minutes)'; Width = $SheetsTimeSpentColumnWidth }
            @{ Name = 'Trends'; Width = $SheetsTrendsColumnWidth }
            @{ Name = 'Data types'; Width = $SheetsDataTypesColumnWidth })) {
        $at = [array]::IndexOf($SheetsOverviewColumns, [string]$sized.Name)
        if ($at -lt 0) { continue }
        $plan += [pscustomobject]@{
            Kind = 'ColumnWidth'; Sheet = 'Overview'
            From = ($at + 1); To = ($at + 1); Width = [int]$sized.Width
        }
    }

    # The three headings that name the reviewer's own columns. Status is one of them even
    # though the runner seeds it: what the seed says is a starting point, and the column is
    # theirs to move.
    foreach ($own in @('Status', 'Check By', 'Comment', 'Time Spent (minutes)')) {
        $at = [array]::IndexOf($SheetsOverviewColumns, $own)
        if ($at -lt 0) { continue }
        $plan += [pscustomobject]@{
            Kind    = 'Format'; Sheet = 'Overview'
            FromRow = 0; ToRow = 1; FromCol = $at; ToCol = ($at + 1)
            Bold    = $true; Colour = $SheetsReviewerHeaderColour; Align = 'CENTER'
        }
    }

    # A superseded spelling still on the board, renamed to the word that now means it. This is
    # the one place the runner writes into a reviewer's column, and it is why the map is a
    # closed list of synonyms rather than anything that reads a result: no conclusion is
    # formed here, only respelled. A value already current, or one nobody declared, is left.
    foreach ($checkId in @($rowOf.Keys)) {
        if (-not $Existing.StatusOf -or -not $Existing.StatusOf.ContainsKey($checkId)) { continue }
        $was = [string]$Existing.StatusOf[$checkId]
        if (-not $SheetsStatusLegacy.ContainsKey($was)) { continue }
        $plan += [pscustomobject]@{
            Kind   = 'Write'
            Sheet  = 'Overview'
            Range  = ((ConvertTo-SheetsColumnName -Index $statusColumnIndex) + [string]$rowOf[$checkId])
            Values = @(, @([string]$SheetsStatusLegacy[$was]))
        }
        $statusRenames += [pscustomobject]@{
            CheckId = $checkId; From = $was; To = [string]$SheetsStatusLegacy[$was]
            Why = 'a superseded spelling of the same conclusion'
        }
    }

    # Google gives a new spreadsheet one tab called Sheet1, and it is nobody's: it exists
    # because the document does. Removed once, on the run that first writes here, and only
    # while it is still untouched - the moment somebody puts anything in it, it stops being
    # the default and becomes theirs, which is the same line every other rule here draws.
    #
    # This is the one exception to a tab never being deleted, and it is narrow on purpose: it
    # names one title, and only when empty. Nothing else in this file removes a tab.
    if ($Existing -and $Existing.EmptyTabs -and $Existing.EmptyTabs.ContainsKey('Sheet1') -and
        $Existing.SheetIdOf -and $Existing.SheetIdOf.ContainsKey('Sheet1')) {
        $plan += [pscustomobject]@{
            Kind    = 'DeleteSheet'
            Sheet   = 'Sheet1'
            SheetId = [int]$Existing.SheetIdOf['Sheet1']
        }
        $emptyTabs.Remove('Sheet1')
        $usedTitles.Remove('Sheet1')
    }

    # Overview is the board and belongs at the front. It is created after Sheet1 exists, so
    # without this it opens second on a new document and stays there.
    if ($Existing -and $Existing.SheetIndexOf -and $Existing.SheetIdOf -and
        $Existing.SheetIndexOf.ContainsKey('Overview') -and
        [int]$Existing.SheetIndexOf['Overview'] -ne 0) {
        $plan += [pscustomobject]@{
            Kind    = 'MoveSheet'
            Sheet   = 'Overview'
            SheetId = [int]$Existing.SheetIdOf['Overview']
            Index   = 0
        }
    }

    # Written every run, like a check tab's. It used to be written once, on the reasoning that
    # row 1 was already right on every later run and rewriting it would be a call that changes
    # nothing - which held exactly as long as the board never gained a column. Trend was added,
    # the header of a document created before it stayed twenty-one cells wide, and Sheets
    # filled the twenty-second with a placeholder of its own the moment the table reached it.
    #
    # One saved range was not worth a board that cannot describe its own newest column. Nothing
    # in row 1 is anybody's: the reviewer's cells on Overview are I, J and K, one row below.
    $plan += [pscustomobject]@{
        Kind   = 'Write'
        Sheet  = 'Overview'
        Range  = (New-SheetsRange -FromColumn 1 -FromRow 1 -ToColumn $width -ToRow 1)
        Values = @(, $SheetsOverviewColumns)
    }

    $nextRow = 2
    if ($rowOf.Count -gt 0) {
        $nextRow = ([int](($rowOf.Values | Measure-Object -Maximum).Maximum)) + 1
    }

    # Tab titles are settled before the Overview rows rather than while writing the tabs
    # themselves, because a new Overview row carries a formula pointing at its check's tab and
    # cannot be written before that tab has a name. Resolving them in one pass also puts every
    # collision check in one place.
    # The same pass sizes the grid. A tab is created with 1000 rows and Google will not grow
    # one to meet a range that starts past its end: a 5 000-row result writes its first chunk,
    # which stretches the grid to exactly that chunk, and the second chunk is then rejected
    # for beginning beyond it - taking the whole batch, and so the whole document update, with
    # it. Observed on the first full run of a sport, where nothing under the 2 000-row chunk
    # size had ever reached it.
    $titleOf = @{}
    $capacityOf = @{}
    if ($Existing -and $Existing.RowCapacityOf) {
        foreach ($key in $Existing.RowCapacityOf.Keys) { $capacityOf[[string]$key] = [int]$Existing.RowCapacityOf[$key] }
    }

    foreach ($item in $Collected) {
        $runKey = Get-JobRunKey -Job $item.Job
        $needed = $SheetsCheckTabResultRow + [math]::Min(@($item.Rows).Count, $MaxRows) + 1

        if ($tabOf.ContainsKey($runKey)) {
            $title = $tabOf[$runKey]
            $titleOf[$runKey] = $title

            # Grown, never shrunk. Lowering rowCount deletes the rows below it, and on a tab
            # somebody may have annotated that is not a decision this code gets to make.
            $have = $(if ($capacityOf.ContainsKey($title)) { $capacityOf[$title] } else { 1000 })
            $sheetId = $(if ($Existing -and $Existing.SheetIdOf -and $Existing.SheetIdOf.ContainsKey($title)) {
                    [int]$Existing.SheetIdOf[$title]
                }
                else { $null })

            if ($needed -gt $have -and $null -ne $sheetId) {
                $plan += [pscustomobject]@{ Kind = 'Resize'; Sheet = $title; SheetId = $sheetId; Rows = $needed }
                $capacityOf[$title] = $needed
            }
            continue
        }

        # A title already in the document blocks a new tab - except when the tab wearing it is
        # empty. That is this code's own leftover: the tabs and the values travel in separate
        # batches, so an update that fails on the second leaves a set of nameless tabs behind,
        # and the next run cannot recognise them because a tab is matched by the Check ID in
        # its own A2. Minting a second set beside them is what happened the first time a full
        # sport was written: 99 empty tabs, then 99 more carrying a ~2.
        $wanted = Get-ShortSheetName -Name $(if ($item.Job.Name) { $item.Job.Name } else { $runKey })
        $title = $wanted
        $suffix = 2
        while ($usedTitles.ContainsKey($title) -and -not $emptyTabs.ContainsKey($title)) {
            $title = "$wanted~$suffix"
            $suffix++
        }

        $adopted = $emptyTabs.ContainsKey($title)
        # Claimed, so a second check cannot adopt the same leftover.
        $emptyTabs.Remove($title)
        $usedTitles[$title] = $true

        if ($adopted) {
            $have = $(if ($capacityOf.ContainsKey($title)) { $capacityOf[$title] } else { 1000 })
            $sheetId = $(if ($Existing -and $Existing.SheetIdOf -and $Existing.SheetIdOf.ContainsKey($title)) {
                    [int]$Existing.SheetIdOf[$title]
                }
                else { $null })
            if ($needed -gt $have -and $null -ne $sheetId) {
                $plan += [pscustomobject]@{ Kind = 'Resize'; Sheet = $title; SheetId = $sheetId; Rows = $needed }
                $capacityOf[$title] = $needed
            }
        }
        else {
            $plan += [pscustomobject]@{
                Kind  = 'AddSheet'
                Sheet = $title
                Rows  = [math]::Max($needed, 1000)
            }
            $capacityOf[$title] = [math]::Max($needed, 1000)
        }

        $tabOf[$runKey] = $title
        $titleOf[$runKey] = $title
    }

    # What the reviewers already concluded about this run's findings, matched once and kept.
    #
    # It is done here, between the pass that settles the tab titles and the one that plans
    # Overview, because Overview is written first and its Rows cell needs to know how many of
    # these rows have been dismissed. Running the match twice would be the obvious alternative
    # and is the wrong one: the two passes would each decide for themselves which note belongs
    # to which finding, and the day they disagreed the board would report a number no tab
    # supports. One result, two readers.
    $carriedOf = @{}
    $dismissedOf = @{}
    # One check's numbers after the dismissals come off, computed while Overview is planned and
    # read again when its tab is written. Two calculations of the same thing is how the board
    # and the tab end up disagreeing, which is the defect this whole column set exists to close.
    $openOf = @{}
    foreach ($item in $Collected) {
        $runKey = Get-JobRunKey -Job $item.Job
        $written = @(@($item.Rows) | Select-Object -First $MaxRows)
        if ($written.Count -eq 0) { continue }

        $title = $titleOf[$runKey]
        $carried = New-SheetsCarriedReview -Header @($written[0].PSObject.Properties.Name) -Rows $written `
            -Was $(if ($Existing -and $Existing.ResultHeaderOf -and $Existing.ResultHeaderOf.ContainsKey($title)) {
                    $Existing.ResultHeaderOf[$title]
                } else { @() }) `
            -Notes $(if ($Existing -and $Existing.ReviewNotesOf -and $Existing.ReviewNotesOf.ContainsKey($title)) {
                    $Existing.ReviewNotesOf[$title]
                } else { @() })

        $carriedOf[$runKey] = $carried
        $dismissedOf[$runKey] = @(@($carried.Review) |
            Where-Object { [string]$_ -eq $SheetsRowReviewDismissed }).Count
    }

    $cells = 0
    $seen = @{}

    # Every write this run makes into the reviewer's Status column, and every one it declined
    # to make. Reported by the caller: a column that is theirs should not change without the
    # run saying so, and finding out afterwards means reading a cell's history one cell at a time.
    $statusRenames = @()
    $statusKept = @()

    foreach ($entry in $Summary) {
        $runKey = [string]$entry.RunKey
        if (-not $runKey) { $runKey = [string]$entry.CheckId }
        $seen[$runKey] = $true

        $values = New-SheetsOverviewRow -Entry $entry -SeededStatus ([string]$entry.SeededStatus)

        # Rows doubles as the way in to the check's own tab, as it does in the workbook. It is
        # written as a plain number first and replaced by the link afterwards, so a check with
        # no tab - one that failed or was skipped - simply keeps the number and reads ERROR or
        # SKIPPED rather than offering a link to nowhere.
        #
        # The numeric columns a reviewer sorts and filters on are Findings, Eligible and
        # Change, and all three stay plain. Rows is the one that can afford to be a formula.
        #
        # And what it counts is what is still open. A row the reviewers marked No Issue /
        # Change is a row they have already decided about, and it stays in the result for good
        # because nothing about the database is going to change - so leaving it in the count
        # makes a settled check read as a busy one forever. Those come out here: the number
        # written into the cell is the one in $values, so the plain-number fallback for a check
        # with no tab carries the same subtraction as the link.
        $dismissed = $(if ($dismissedOf.ContainsKey($runKey)) { [int]$dismissedOf[$runKey] } else { 0 })
        $rowsColumn = [array]::IndexOf($SheetsOverviewColumns, 'Rows') + 1
        if (($entry.RowsCell -isnot [string]) -and $dismissed -gt 0) {
            $values[$rowsColumn - 1] = [math]::Max(0, [int]$entry.RowsCell - $dismissed)
        }

        # The same subtraction on every other column that counts findings, so the board agrees
        # with itself. Rows used to have it alone, which is how a check could read 0 open rows
        # beside a Findings of 40 and a verdict of Above residual. Kept for the check tab too,
        # which takes these same numbers rather than recomputing them.
        $open = Get-SheetsOpenCounts -Entry $entry -Dismissed $dismissed
        $openOf[$runKey] = $open
        foreach ($pair in @(
                @{ Column = 'Findings'; Value = $open.Findings }
                @{ Column = 'All findings'; Value = $open.AllFindings }
                @{ Column = 'Prev findings'; Value = $open.PrevFindings }
                @{ Column = 'Change'; Value = $open.Change }
                @{ Column = 'Verdict'; Value = [string]$open.Verdict })) {
            $at = [array]::IndexOf($SheetsOverviewColumns, [string]$pair.Column)
            if ($at -ge 0) { $values[$at] = $pair.Value }
        }

        $rowsLink = $null
        if ($titleOf.ContainsKey($runKey)) {
            $rowsLink = New-SheetsGidLink -Sheet $titleOf[$runKey] -Text $values[$rowsColumn - 1]
        }

        if ($rowOf.ContainsKey($runKey)) {
            # The row exists, so the reviewer's three columns are theirs and the run writes
            # around them - two spans rather than one, and never through I, J or K.
            $row = $rowOf[$runKey]
            foreach ($span in $overviewSpans) {
                $slice = @($values[($span.From - 1)..($span.To - 1)])
                $plan += [pscustomobject]@{
                    Kind   = 'Write'
                    Sheet  = 'Overview'
                    Range  = (New-SheetsRange -FromColumn $span.From -FromRow $row -ToColumn $span.To -ToRow $row)
                    Values = @(, $slice)
                }
                $cells += $slice.Count
            }

            # An empty Comment cell holds nothing of anyone's, so seeding the mirror into it
            # costs nothing and is the only way a row written before the mirror existed - or
            # one whose cell was cleared - ever gets one. A cell with anything in it, formula
            # or text, is left alone.
            $rich = New-SheetsTrendRichText -Sheet 'Overview' -Row $row `
                -Column ([array]::IndexOf($SheetsOverviewColumns, 'Trends') + 1) `
                -Text ([string]$open.Trend) -Runs $open.TrendRuns
            if ($rich) { $plan += $rich }

            # A closed conclusion this run has just contradicted. Status is the reviewer's
            # column and stays theirs; this is the second value the run may write into it, and
            # like the first - the registry's Deprecated - it is narrow by construction. It fires
            # only from `Clean` or `Completed`, only when the run returns open findings, and it
            # never writes a closing word of its own. See $SheetsReopenedStatus.
            #
            # Open findings, not raw rows: a row the reviewers marked No Issue / Change is one
            # they have already decided about and it stays in the result for good, so a check
            # whose remaining rows are all dismissed is still finished and keeps its word.
            #
            # **And only where the check was ever supposed to reach zero.** Corrected 2026-08-26,
            # after the first eleven boards run under this rule moved 99 checks and eight of them
            # should not have been. `Expected` is the field that answers it and the only one that
            # does: a check expecting `Non-zero` is one whose proportion is the finding and whose
            # count will never be nothing, so `Completed` on it never meant "returns nothing" and
            # a run contradicts nothing by returning rows - it would have reopened every such row
            # on every run for ever, which is the nagging the dismissal rule above exists to
            # avoid. `Residual` is a remainder somebody agreed to leave, and an empty expectation
            # belongs to `Blocked`, `Not applicable` and `Out of client scope`, none of which is a
            # count anybody is waiting on.
            #
            # `Zero` keeps both the checks that carry it: `Actionable`, and `Sentinel`, whose
            # population has not arrived but whose every row is a defect on the day it does.
            #
            # A superseded spelling is mapped first so the two rules agree within one run. Left
            # unmapped, a cell reading `Fixed` would be renamed to `Completed` by the loop above
            # and only reopened on the run after this one.
            $statusNow = ''
            if ($Existing -and $Existing.StatusOf -and $Existing.StatusOf.ContainsKey($runKey)) {
                $statusNow = ([string]$Existing.StatusOf[$runKey]).Trim()
            }
            $statusMeans = $(if ($SheetsStatusLegacy.ContainsKey($statusNow)) {
                    [string]$SheetsStatusLegacy[$statusNow]
                } else { $statusNow })
            $openNow = 0
            if (($SheetsStatusClosedByFinding -contains $statusMeans) -and
                ([string]$entry.Expected -eq $SheetsExpectationReopenable) -and
                [int]::TryParse([string]$open.Findings, [ref]$openNow) -and $openNow -gt 0) {
                $statusColumn = [array]::IndexOf($SheetsOverviewColumns, 'Status') + 1
                $plan += [pscustomobject]@{
                    Kind   = 'Write'
                    Sheet  = 'Overview'
                    Range  = (New-SheetsRange -FromColumn $statusColumn -FromRow $row `
                            -ToColumn $statusColumn -ToRow $row)
                    Values = @(, @($SheetsReopenedStatus))
                }
                $cells += 1
                $statusRenames += [pscustomobject]@{
                    CheckId = $runKey; From = $statusNow; To = $SheetsReopenedStatus
                    Why = ('it was {0} and this run returned {1} open finding(s)' -f $statusMeans, $openNow)
                }
            }

            $wanted = $(if ($Existing -and $Existing.EmptyCommentOf) { [bool]$Existing.EmptyCommentOf[$runKey] } else { $false })
            if ($wanted -and $titleOf.ContainsKey($runKey)) {
                $commentColumn = [array]::IndexOf($SheetsOverviewColumns, 'Comment') + 1
                $plan += [pscustomobject]@{
                    Kind   = 'Write'
                    Raw    = $false
                    Sheet  = 'Overview'
                    Range  = (New-SheetsRange -FromColumn $commentColumn -FromRow $row `
                            -ToColumn $commentColumn -ToRow $row)
                    Values = @(, @((New-SheetsCommentMirror -Sheet $titleOf[$runKey])))
                }
                $cells += 1
            }
        }
        else {
            # A check the document has never held. This is the one time the run writes the
            # reviewer's columns, because there is nothing of theirs to overwrite and the
            # seeded Status is what tells them the row needs no reading.
            $plan += [pscustomobject]@{
                Kind   = 'Write'
                Sheet  = 'Overview'
                Range  = (New-SheetsRange -FromColumn 1 -FromRow $nextRow -ToColumn $width -ToRow $nextRow)
                Values = @(, $values)
            }
            $cells += $values.Count

            $rich = New-SheetsTrendRichText -Sheet 'Overview' -Row $nextRow `
                -Column ([array]::IndexOf($SheetsOverviewColumns, 'Trends') + 1) `
                -Text ([string]$open.Trend) -Runs $open.TrendRuns
            if ($rich) { $plan += $rich }

            # Comment mirrors the check tab's G2, so a comment is written once beside the rows
            # that provoked it and read from the board that lists every check. Seeded on a new
            # row only: on every later run the cell is the reviewer's, whether it still holds
            # this formula or the text they typed over it.
            #
            # The mirror is one way and cannot be two. A cell holds a value or a formula and
            # never both, so two cells cannot each feed the other. This is the safer
            # direction: typing over the mirror costs a mirror, while a mirror on the check
            # tab would have put the words somebody wrote at the same risk.
            #
            # Raw = $false because a formula sent as RAW arrives as the literal text of one.
            # It is emitted after the row write above, and Invoke-SheetsPlan sends the RAW
            # batch first, so it lands on top of the empty cell that write leaves at K.
            if ($titleOf.ContainsKey($runKey)) {
                $commentColumn = [array]::IndexOf($SheetsOverviewColumns, 'Comment') + 1
                $plan += [pscustomobject]@{
                    Kind   = 'Write'
                    Raw    = $false
                    Sheet  = 'Overview'
                    Range  = (New-SheetsRange -FromColumn $commentColumn -FromRow $nextRow `
                            -ToColumn $commentColumn -ToRow $nextRow)
                    Values = @(, @((New-SheetsCommentMirror -Sheet $titleOf[$runKey])))
                }
                $cells += 1
            }

            $rowOf[$runKey] = $nextRow
            $nextRow++
        }

        # Written for both an existing row and a new one, and after either, so it lands on top
        # of the plain number the row write left there.
        if ($rowsLink) {
            $plan += [pscustomobject]@{
                Kind   = 'Write'
                Raw    = $false
                Sheet  = 'Overview'
                Range  = (New-SheetsRange -FromColumn $rowsColumn -FromRow $rowOf[$runKey] `
                        -ToColumn $rowsColumn -ToRow $rowOf[$runKey])
                Values = @(, @($rowsLink))
            }
            $cells += 1
        }
    }

    # A check the document holds and this run did not produce. Not deleted and not left
    # looking current: the Verdict column says it did not run, so a reviewer reading the board
    # is not told last run's number as though it were this one's.
    #
    # Only a run that was meant to cover the sport may say this, which is what -Complete
    # carries. A partial run - one CheckID after a reported fix, a wildcard, a capped batch -
    # did not fail to produce the other ninety checks; it was never asked for them, and
    # marking them would repaint the whole board every time somebody re-ran one thing. The
    # rows it leaves alone keep the last full run's numbers, which is what they are.
    $retiredSet = @{}
    foreach ($id in @($Retired)) {
        if (-not [string]::IsNullOrWhiteSpace($id)) { $retiredSet[[string]$id] = $true }
    }

    foreach ($runKey in @($rowOf.Keys)) {
        if (-not $Complete) { break }
        if ($seen.ContainsKey($runKey)) { continue }
        if ($retiredSet.ContainsKey($runKey)) { continue }
        $verdictColumn = [array]::IndexOf($SheetsOverviewColumns, 'Verdict') + 1
        $plan += [pscustomobject]@{
            Kind   = 'Write'
            Sheet  = 'Overview'
            Range  = (New-SheetsRange -FromColumn $verdictColumn -FromRow $rowOf[$runKey] `
                    -ToColumn $verdictColumn -ToRow $rowOf[$runKey])
            Values = @(, @('Not in this run'))
        }
        $cells += 1
    }

    # A check the registry has withdrawn. Deprecation is a fact this run can read rather than
    # an inference it has to earn, so unlike "Not in this run" it is written by every run and
    # not only by a complete one: a CheckID is permanent and its row stays for good, but the
    # numbers beside it stop being true the moment the check stops running, and a board that
    # keeps showing them is worse than one showing nothing. Golf-DQ-044 stood at 3286 findings
    # for half a day after it was replaced, and was read as current.
    #
    # The reviewer's three columns are not touched. What somebody concluded while the check was
    # running is still what they concluded, and a run that erased it would be destroying the one
    # thing in the document it cannot rebuild. The tab is not deleted for the same reason.
    foreach ($runKey in @($rowOf.Keys)) {
        if (-not $retiredSet.ContainsKey($runKey)) { continue }
        # It ran anyway - the registry and the selection disagree - so this run's own numbers
        # are real and stand. Marking the row would replace a measurement with an assertion.
        if ($seen.ContainsKey($runKey)) { continue }

        $row = $rowOf[$runKey]
        $rowsColumn = [array]::IndexOf($SheetsOverviewColumns, 'Rows') + 1
        $rowsRange = (New-SheetsRange -FromColumn $rowsColumn -FromRow $row -ToColumn $rowsColumn -ToRow $row)

        # The plain number first and the link on top of it, in that order and as two writes,
        # which is how the rest of this planner does it and for a reason worth repeating here.
        # A link is a formula and a formula sent RAW arrives as the literal text of one, so it
        # needs the USER_ENTERED side; and that side drops any write whose tab token did not
        # resolve, on the grounds that a broken link is worse than a missing one. One write
        # carrying only the link would therefore leave the stale count standing on exactly the
        # row this exists to clear. Written as one on 2026-08-13, which put {{GID:...}} in the
        # cell as text.
        $plan += [pscustomobject]@{
            Kind   = 'Write'
            Sheet  = 'Overview'
            Range  = $rowsRange
            Values = @(, @(0))
        }
        if ($tabOf.ContainsKey($runKey)) {
            # Still a link, because the tab is where the note explaining the withdrawal is.
            $plan += [pscustomobject]@{
                Kind   = 'Write'
                Raw    = $false
                Sheet  = 'Overview'
                Range  = $rowsRange
                Values = @(, @((New-SheetsGidLink -Sheet $tabOf[$runKey] -Text 0)))
            }
        }

        # Signal to the end of the board in one span: every column after the reviewer's own
        # belongs to the run, and they are contiguous, so it is one write rather than twelve.
        # Built by walking the column list rather than by position, so All findings arriving in
        # the middle of it was cleared by the default arm without this needing to know.
        #
        # The end is the last column and not a column named here. Naming Trends was the one
        # positional assumption left in this block, and Data types arriving after it in August
        # 2026 made the span stop one short - the retirement wrote every marker correctly and
        # left a withdrawn check showing the data types of the run that dropped it.
        $from = [array]::IndexOf($SheetsOverviewColumns, 'Signal') + 1
        $to = $SheetsOverviewColumns.Count
        $values = @()
        foreach ($column in $SheetsOverviewColumns[($from - 1)..($to - 1)]) {
            $values += switch ($column) {
                'Signal' { $SheetsRetiredMarker }
                'Signal reason' { $SheetsRetiredReason }
                'Verdict' { $SheetsRetiredMarker }
                default { '' }
            }
        }
        $plan += [pscustomobject]@{
            Kind   = 'Write'
            Sheet  = 'Overview'
            Range  = (New-SheetsRange -FromColumn $from -FromRow $row -ToColumn $to -ToRow $row)
            Values = @(, $values)
        }
        $cells += 1 + $values.Count

        # And the reviewer's own Status. Left alone, the row said Deprecated in Signal and
        # Verdict while Status still read Not reviewed: a row asking to be reviewed and
        # answering that there is nothing to review, and one that a filter on Not reviewed kept
        # serving up. The registry withdrew the check, so the registry's word belongs there -
        # but only where nobody has put their own.
        #
        # It used to be written every run over whatever was in the cell, on the reasoning that
        # a person who typed something since the last run typed it about a check that no longer
        # runs. That reasoning covers a stale word and not a considered one, and the cell cannot
        # tell them apart: a reviewer who marked the row Completed or Other Team said something
        # about work they did, and a run that erases it is deciding for them. Narrowed 2026-08-25
        # to a cell nobody has answered - blank, or still on the seeded Not reviewed, or already
        # Deprecated. Anything else stays, and the row still reads Deprecated in Signal and
        # Verdict, which is where the registry's word cannot be typed over.
        $statusColumn = [array]::IndexOf($SheetsOverviewColumns, 'Status') + 1
        $statusNow = ''
        if ($Existing.StatusOf -and $Existing.StatusOf.ContainsKey($runKey)) {
            $statusNow = ([string]$Existing.StatusOf[$runKey]).Trim()
        }
        if ([string]::IsNullOrWhiteSpace($statusNow) -or $statusNow -eq $SheetsUnreviewedStatus) {
            $plan += [pscustomobject]@{
                Kind   = 'Write'
                Sheet  = 'Overview'
                Range  = (New-SheetsRange -FromColumn $statusColumn -FromRow $row -ToColumn $statusColumn -ToRow $row)
                Values = @(, @($SheetsRetiredStatus))
            }
            $cells += 1
            $statusRenames += [pscustomobject]@{
                CheckId = $runKey; From = $statusNow; To = $SheetsRetiredStatus
                Why = 'the registry withdrew the check and nobody had answered the row'
            }
        }
        elseif ($statusNow -ne $SheetsRetiredStatus) {
            $statusKept += [pscustomobject]@{ CheckId = $runKey; Status = $statusNow }
        }

        # The tab keeps its identity block and its comments and loses its findings, which is
        # the same shape a check returning nothing leaves behind. C3 already carries whatever
        # this tab has to say about itself, so the reason goes there.
        if ($tabOf.ContainsKey($runKey)) {
            $title = $tabOf[$runKey]
            $plan += [pscustomobject]@{
                Kind  = 'Clear'
                Sheet = $title
                Range = '{0}{1}:AZ' -f (ConvertTo-SheetsColumnName -Index 1), $SheetsCheckTabResultRow
            }
            $plan += [pscustomobject]@{
                Kind   = 'Write'
                Sheet  = $title
                Range  = 'C3'
                Values = @(, @($SheetsRetiredReason))
            }
            $cells += 1
        }
    }

    # Overview is a table like every result block, and for the same reasons: the styled header
    # stays put while scrolling, and the filter buttons are how a hundred rows get read.
    #
    # It used to be created only by hand and merely maintained here, on the reasoning that a
    # table on the board was the reviewer's own decision. That held until the document was
    # rebuilt from empty and the hand-made one went with it - leaving a rule that would never
    # restore what it had helped lose, and five more sports each needing somebody to remember.
    #
    # An existing one keeps its name rather than being replaced. Its extent does not: both
    # ends of it go stale, and for different reasons.
    #
    # Rows, because a table covers the checks that existed when it was made and the next run
    # appends below it. Columns, because the board gains one now and then - and unlike a
    # comment, no column here is anybody's choice to preserve. Every one of the 22 is written
    # by this code. Keeping a remembered width was the wrong caution: Trend was added, the
    # table still ended at the column before it, and the new column sat outside the table with
    # no header of its own for as long as nobody looked.
    $board = $(if ($Existing -and $Existing.TableOf -and $Existing.TableOf.ContainsKey('Overview')) {
            @($Existing.TableOf['Overview'])[0]
        }
        else { $null })
    $lastRow = $nextRow - 1

    # Status: the same treatment as Rows, plus the dropdown that makes the column a closed
    # vocabulary. Colour without the list would be decoration - a chip appears only for a value
    # somebody happened to spell the way the rule expects - so neither is useful alone.
    #
    # Bounded to the board's last row, where Rows is left unbounded, and the difference is the
    # whole point of it. A dropdown has no colour field of its own anywhere in the API: what
    # Sheets shows as a swatch beside each item in the dropdown editor is a conditional format
    # rule it has matched to that item, and it matches on the rule covering the same range the
    # validation does. A validation that belongs to a table covers the table, so a rule running
    # to the bottom of the sheet colours the cells correctly and still leaves every swatch in
    # the editor blank - which is what a board looked like on 2026-08-10.
    if ($lastRow -gt 1) {
        $plan += [pscustomobject]@{
            Kind   = 'FormatRules'
            Sheet  = 'Overview'
            Column = $statusColumnIndex
            EndRow = $lastRow
            Drop   = $dropOf[$statusColumnIndex]
            Rules  = @($SheetsStatusBands | ForEach-Object {
                    [pscustomobject]@{
                        Type       = 'TEXT_EQ'
                        Values     = @($_.Value)
                        Colour     = $_.Colour
                        Background = $_.Background
                    }
                })
        }
    }

    # The board sorted by Priority at the end of every run.
    #
    # This is a deliberate exception to the rule stated at the top of this function - that
    # sorting is the reviewer's to do and theirs to keep - and it is safe only because of the
    # other rule beside it: a row is found by its CheckID and never by its position, so moving
    # rows costs nothing that a run depends on. What it does cost is a reviewer's own ordering,
    # which is why it is stated here rather than left to be discovered. Asked for on
    # 2026-08-10: the band is what says what to work through first, and a board that does not
    # open in that order makes everybody sort it by hand every week.
    #
    # Priority carries a numeric prefix precisely so that a plain text sort produces the band
    # order, and CheckID second so that the order inside a band is stable rather than whatever
    # the previous sort happened to leave.
    if ($lastRow -gt 1) {
        $plan += [pscustomobject]@{
            Kind    = 'Sort'
            Sheet   = 'Overview'
            FromRow = 1
            ToRow   = $lastRow
            FromCol = 0
            ToCol   = $width
            By      = @(
                ([array]::IndexOf($SheetsOverviewColumns, 'Priority'))
                ([array]::IndexOf($SheetsOverviewColumns, 'CheckID'))
            )
        }
    }

    # Emitted whenever there is a board, not only when its extent moved. The extent is one of
    # the things this declaration carries and the header colour is another, and a colour
    # changed in the source has to reach a document whose row count happens to be unchanged.
    if ($lastRow -gt 1) {
        $plan += [pscustomobject]@{
            Kind    = 'Table'
            Sheet   = 'Overview'
            # One board to a document, so the plain name is free and stays readable in a
            # formula. An existing table keeps whatever it was called.
            Name    = $(if ($board) { $board.Name } else { 'Overview' })
            FromRow = 0
            ToRow   = $lastRow
            FromCol = 0
            ToCol   = $width
            HeaderColour = $SheetsDataHeaderColour
        }
    }

    # Then the check tabs, and the SQL tab built alongside them.
    #
    # One tab holding every statement, rather than the statement in each check tab's own C2.
    # A cell of a few thousand characters displays as nothing and pushes the result table out
    # of shape, and the statement keeps the line breaks it was written with here. Each block
    # links back to the results it produced, and each check's C2 links forward to its block.
    # The SQL tab is shared, and this run may hold only part of the catalogue. Its blocks are
    # therefore merged into what the tab already carries rather than written over it: a narrow
    # run used to clear the whole column and leave behind its own single statement, which took
    # every other check's statement with it and left their C2 links pointing at blank rows.
    #
    # The order the tab already has is kept, and a check new to it is appended. That keeps
    # most row numbers still, so most C2 links need no rewrite at all.
    $sqlOrder = @()
    $sqlOf = @{}
    $sqlTitleOf = @{}
    $sqlWasRow = @{}
    $sqlWarning = ''
    foreach ($block in @($(if ($Existing) { $Existing.SqlBlocks } else { @() }))) {
        if (-not $block -or -not $block.CheckId) { continue }
        $sqlOrder += [string]$block.CheckId
        $sqlOf[[string]$block.CheckId] = @($block.Lines)
        $sqlWasRow[[string]$block.CheckId] = [int]$block.Row
    }

    foreach ($item in $Collected) {
        $runKey = Get-JobRunKey -Job $item.Job
        $rows = @($item.Rows)
        $entry = @($Summary | Where-Object {
                ([string]$_.RunKey -eq $runKey) -or ([string]$_.CheckId -eq $runKey) })
        $entry = $(if ($entry.Count -gt 0) { $entry[0] } else { $null })

        # Settled in the pass above, along with any AddSheet it needed.
        $title = $titleOf[$runKey]

        # This check's block on the SQL tab: a heading row that links back to these results,
        # then the statement one line per row, then a blank row. The heading row's number is
        # what C2 above links forward to.
        $sqlKey = [string]$item.Job.CheckId
        if (-not $sqlKey) { $sqlKey = $runKey }
        if (-not $sqlOf.ContainsKey($sqlKey)) { $sqlOrder += $sqlKey }
        $sqlOf[$sqlKey] = @(@([string]$item.Job.Sql -split "`r?`n") + @(''))
        $sqlTitleOf[$sqlKey] = $title

        # Row 1 names the columns. Unlike Overview's header it is rewritten every run rather
        # than seeded once, because none of it is anybody's: the reviewer's cells on a check
        # tab are one row below their headings.
        $plan += [pscustomobject]@{
            Kind   = 'Write'
            Sheet  = $title
            Range  = (New-SheetsRange -FromColumn 1 -FromRow 1 -ToColumn $SheetsCheckTabColumns.Count -ToRow 1)
            Values = @(, $SheetsCheckTabColumns)
        }
        $cells += $SheetsCheckTabColumns.Count

        # Row 2 holds the identity, and Comment and Check By in the middle of it belong to the
        # reviewer, so the same two-span treatment applies as on Overview.
        #
        # The finding counts come from what Overview already worked out for this check, never
        # from the entry directly. The tab and the board have to say the same thing about the
        # rows immediately below this row, and the surest way to make two numbers agree is for
        # there to be one number.
        $open = $(if ($openOf.ContainsKey($runKey)) { $openOf[$runKey] } else { $null })
        $identity = @(
            [string]$item.Job.CheckId
            [string]$item.Job.Name
            'SQL'
            [string]$item.Job.What
            ''
            ''
            # Time Spent (minutes), the third of the reviewer's own cells. Written blank only on
            # a tab being created, like the two above it, and never afterwards.
            ''
            [string]$(if ($entry) { $entry.Expected } else { '' })
            $(if ($open) { $open.Findings } else { $null })
            $(if ($open) { $open.AllFindings } else { $null })
            $(if ($entry) { $entry.Eligible } else { $null })
            $(if ($open) { $open.PrevFindings } else { $null })
            $(if ($open) { $open.Change } else { $null })
            [string]$(if ($open) { $open.Verdict } else { '' })
            [string]$(if ($open) { $open.Trend } else { '' })
            [string]$(if ($entry) { $entry.Category } else { '' })
            [string]$(if ($entry) { $entry.Parameters } else { '' })
        )
        $identitySpans = Split-SheetsWritableSpans -Width $identity.Count -Reserved $SheetsCheckTabReviewerColumns
        foreach ($span in $identitySpans) {
            $slice = @($identity[($span.From - 1)..($span.To - 1)])
            $plan += [pscustomobject]@{
                Kind   = 'Write'
                Sheet  = $title
                Range  = (New-SheetsRange -FromColumn $span.From -FromRow 2 -ToColumn $span.To -ToRow 2)
                Values = @(, $slice)
            }
            $cells += $slice.Count
        }

        # The same two columns the board widens, for the same two reasons. A check tab carries
        # its own copy of the series and its own cell for what the check cost, and a heading
        # clipped to 'Time Spent (m' is no more readable here than it is there.
        foreach ($sized in @(
                @{ Name = 'Time Spent (minutes)'; Width = $SheetsTimeSpentColumnWidth }
                @{ Name = 'Trends'; Width = $SheetsTrendsColumnWidth })) {
            $at = [array]::IndexOf($SheetsCheckTabColumns, [string]$sized.Name)
            if ($at -lt 0) { continue }
            $plan += [pscustomobject]@{
                Kind = 'ColumnWidth'; Sheet = $title
                From = ($at + 1); To = ($at + 1); Width = [int]$sized.Width
            }
        }

        # The same colouring on the tab's own copy of the series. Written after the identity
        # row above, which put the plain string there first: if the rich write is ever refused,
        # the cell still reads correctly and only loses its colour.
        if ($open) {
            $rich = New-SheetsTrendRichText -Sheet $title -Row 2 `
                -Column ([array]::IndexOf($SheetsCheckTabColumns, 'Trends') + 1) `
                -Text ([string]$open.Trend) -Runs $open.TrendRuns
            if ($rich) { $plan += $rich }
        }

        # A3, the way back. A formula, so it goes in the USER_ENTERED batch and lands after the
        # row that wrote plain text over it. C2 is the other link a check tab carries and is
        # written further down, once the SQL tab's rows are settled: its target is a row number
        # on a tab this run only partly owns, and that number is not known until the merge.
        #
        # A3 rather than row 2, and row 4 left blank below it, so the result table starting at
        # row 5 stays a self-contained block that sorts and filters on its own.
        $plan += [pscustomobject]@{
            Kind   = 'Write'
            Raw    = $false
            Sheet  = $title
            Range  = 'A3'
            Values = @(, @((New-SheetsGidLink -Sheet 'Overview' -Text 'Return to Overview')))
        }

        # The way back is the one control on the tab, sitting under a header row and above a
        # result table that both draw the eye harder than it does. Sheets already underlines a
        # formula link; bold and an explicit blue are what make it read as the control rather
        # than as a line of the identity block above it.
        $plan += [pscustomobject]@{
            Kind    = 'Format'; Sheet = $title
            FromRow = 2; ToRow = 3; FromCol = 0; ToCol = 1
            Bold    = $true; Colour = $SheetsLinkColour; Align = 'LEFT'
        }

        # Left, alone on the tab. Everything else is centred, but a link reads as a control
        # only if it starts where the eye already is, and centring it inside a widened column
        # puts it somewhere nobody looks.
        $plan += [pscustomobject]@{
            Kind = 'ColumnWidth'; Sheet = $title
            From = 1; To = 1; Width = $SheetsCheckTabFirstColumnWidth
        }

        # Everything above the results held still while they scroll. Sheets makes a table's own
        # header sticky, and with two tables on the tab the one it picked was the identity at
        # the top - so scrolling a result of a thousand rows kept the check's name in view and
        # took the column names away, which are the labels somebody scrolling actually needs.
        #
        # Five rows rather than one: the identity block is three rows and row 4 is the gap, so
        # freezing to the result header keeps both, and the block below starts under it.
        $plan += [pscustomobject]@{
            Kind = 'Freeze'; Sheet = $title; Rows = $SheetsCheckTabResultRow
        }

        # C2, the jump to the statement. Darker than the way back, and bold, because it sits
        # inside the identity row rather than alone on a line of its own.
        $plan += [pscustomobject]@{
            Kind    = 'Format'; Sheet = $title
            FromRow = 1; ToRow = 2
            FromCol = ([array]::IndexOf($SheetsCheckTabColumns, 'SQL Used'))
            ToCol   = ([array]::IndexOf($SheetsCheckTabColumns, 'SQL Used') + 1)
            Bold    = $true; Colour = $SheetsSqlLinkColour
        }

        # Everything on the tab centred, header and data alike, except the column the way back
        # sits in. Without an end row it follows the tab down, so a result that grows next week
        # is centred too.
        $plan += [pscustomobject]@{
            Kind    = 'Format'; Sheet = $title
            FromRow = 0; ToRow = $null; FromCol = 1; ToCol = 40; Align = 'CENTER'
        }

        # Column A in two pieces, above and below the way back, rather than skipped whole.
        # Skipping it left every check_type in the result block below ranged left on a board
        # that is centred everywhere else - the link needed one cell left alone, not a column.
        #
        # The upper piece is the identity block, and it ranges left with the two columns beside
        # it; the lower piece is the result and stays centred with the rest of the tab.
        $plan += [pscustomobject]@{
            Kind    = 'Format'; Sheet = $title
            FromRow = 3; ToRow = $null; FromCol = 0; ToCol = 1; Align = 'CENTER'
        }

        # The three columns that read as sentences rather than as values: the check's ID, its
        # name and the line saying what it does. Centring a sentence puts its first word
        # somewhere different on every tab, so the eye has to find the start before it can read
        # - and What it does is long enough to be clipped, which centring hides in the middle
        # instead of at the end. Header and value together, so the column reads as one thing.
        #
        # After the sweep that centres the tab, because these are its exceptions. SQL Used
        # stays centred: it is a one-word control, not a sentence.
        foreach ($ranged in @('Check ID', 'Check Name', 'What it does')) {
            $at = [array]::IndexOf($SheetsCheckTabColumns, $ranged)
            if ($at -lt 0) { continue }
            $plan += [pscustomobject]@{
                Kind    = 'Format'; Sheet = $title
                FromRow = 0; ToRow = 2; FromCol = $at; ToCol = ($at + 1); Align = 'LEFT'
            }
        }

        # The two headings that name the reviewer's own columns, on a header row that is
        # otherwise the runner's.
        foreach ($own in @('Comment', 'Check By', 'Time Spent (minutes)')) {
            $at = [array]::IndexOf($SheetsCheckTabColumns, $own)
            if ($at -lt 0) { continue }
            $plan += [pscustomobject]@{
                Kind    = 'Format'; Sheet = $title
                FromRow = 0; ToRow = 1; FromCol = $at; ToCol = ($at + 1)
                Bold    = $true; Colour = $SheetsReviewerHeaderColour; Align = 'CENTER'
            }
        }

        # Rows 1 to 3 as a table of their own: the header, the identity, and the way back. It
        # is what the result table below already is - a named block that Sheets will not let a
        # sort or a filter run past - and without it a filter set on the results reaches up
        # into the identity and hides it.
        #
        # Named for the check rather than for the sport and the check, because inside a
        # document that is one sport the prefix is the same on every tab and says nothing. A
        # table name is a formula identifier, so it carries underscores where the heading in
        # A1 carries spaces; the two are the same words.
        $plan += [pscustomobject]@{
            Kind         = 'Table'
            Sheet        = $title
            Name         = (ConvertTo-SheetsIdentityTableName -CheckId ([string]$item.Job.CheckId))
            FromRow      = 0
            ToRow        = 3
            FromCol      = 0
            ToCol        = $SheetsCheckTabColumns.Count
            HeaderColour = $SheetsIdentityHeaderColour
        }

        # What was written, and what was not. A truncated tab says so on its own face rather
        # than in the run log, because the person who reads it a week later has only the tab.
        $written = @($rows | Select-Object -First $MaxRows)
        $note = ''
        if ($rows.Count -gt $MaxRows) {
            $note = '{0:n0} of {1:n0} rows. The full result is in {2}' -f $MaxRows, $rows.Count, $OutputFolder
        }
        $plan += [pscustomobject]@{
            Kind   = 'Write'
            Sheet  = $title
            Range  = 'C3'
            Values = @(, @($note))
        }

        # Cleared before it is written, and to the end of the tab rather than to a remembered
        # depth. A check that found forty rows last run and three this one would otherwise
        # leave thirty-seven stale rows under the three new ones, which reads as forty
        # findings.
        #
        # Open-ended on purpose. Clearing to a depth this code believes the tab has is only
        # right while that belief is: a run recorded with -TestRun, an edit somebody made by
        # hand, a failed write halfway through - any of those and the remembered number is
        # short, which leaves exactly the stale rows this exists to remove. The end of the
        # tab is a fact rather than a belief, and costs the same one request.
        # Through AZ rather than Z: the reviewer columns sit to the right of whatever the
        # statement returned, and a clear that stops short of them leaves last week's notes
        # standing beside this week's rows, which is the one failure this whole mechanism
        # exists to prevent. They are written back below, from the notes read off the board.
        $plan += [pscustomobject]@{
            Kind  = 'Clear'
            Sheet = $title
            Range = '{0}{1}:AZ' -f (ConvertTo-SheetsColumnName -Index 1), $SheetsCheckTabResultRow
        }

        if ($written.Count -gt 0) {
            $dataHeader = @($written[0].PSObject.Properties.Name)

            # What the reviewer wrote against these findings last time, put back beside the
            # findings themselves rather than beside the row numbers they used to occupy. A
            # correction removes rows and everything under them moves up, so a note left where
            # it was would end up against somebody else's finding - which reads exactly like a
            # judgement somebody made.
            # Matched in the pass that ran before Overview was planned, and taken from there
            # rather than done again. Overview's Rows already subtracted the dismissed rows this
            # answer names, so a second match reaching a different answer would leave the board
            # reporting a count its own tab does not support.
            $carried = $carriedOf[$runKey]

            foreach ($lost in @($carried.Dropped)) {
                $dropped += [pscustomobject]@{
                    CheckId = [string]$item.Job.CheckId
                    Tab     = $title
                    Key     = $lost.Key
                    Review  = $lost.Review
                    Note    = $lost.Note
                    Why     = $lost.Why
                }
            }

            $header = @($dataHeader) + $SheetsRowReviewColumns
            $table = @(, $header)
            for ($r = 0; $r -lt $written.Count; $r++) {
                $row = $written[$r]
                $line = @($dataHeader | ForEach-Object { $row.$_ })
                $table += , ($line + @($carried.Review[$r], $carried.Note[$r]))
            }
            $plan += [pscustomobject]@{
                Kind   = 'Write'
                Sheet  = $title
                Range  = (New-SheetsRange -FromColumn 1 -FromRow $SheetsCheckTabResultRow `
                        -ToColumn $header.Count -ToRow ($SheetsCheckTabResultRow + $written.Count))
                Values = $table
            }
            $cells += $header.Count * ($written.Count + 1)

            # The result block as a table: a styled header, filter buttons and banded rows,
            # without any of it being written as formatting. The range has to be maintained
            # rather than set once, because every run replaces a different number of rows and
            # a table left at last week's extent either cuts the result short or trails empty
            # rows past its end.
            #
            # No column types are declared. Left to guess, Sheets reads a value like 2019-03
            # as a date and shows an error over data that is exactly what the database
            # returned.
            $plan += [pscustomobject]@{
                Kind         = 'Table'
                Sheet        = $title
                Name         = (ConvertTo-SheetsTableName -Name ([string]$item.Job.CheckId))
                FromRow      = $SheetsCheckTabResultRow - 1
                ToRow        = $SheetsCheckTabResultRow + $written.Count
                FromCol      = 0
                ToCol        = $header.Count
                HeaderColour = $SheetsDataHeaderColour
            }

            # The names the statement projected, made readable. Both halves are needed: the
            # width carries a name of ordinary length, and the wrap carries the rest onto a
            # second line rather than letting the cap clip them. Only the header row wraps -
            # a wrapped value would make one tall row of every finding holding a long string.
            #
            # A check tab stacks two tables in one set of columns - the identity on rows 1 and 2,
            # the result from row 5 - so one width has to serve both, and the wider of the two
            # wins. Narrowing to the result would clip 'Time Spent (minutes)' back to the
            # heading nobody could read; widening past it never hides anything, it only leaves
            # air in a result column. Raised rather than overwritten, so a projected name longer
            # than either of these still gets the room it asked for.
            $identityWidthOf = @{}
            foreach ($sized in @(
                    @{ Name = 'Time Spent (minutes)'; Width = $SheetsTimeSpentColumnWidth }
                    @{ Name = 'Trends'; Width = $SheetsTrendsColumnWidth })) {
                $at = [array]::IndexOf($SheetsCheckTabColumns, [string]$sized.Name)
                if ($at -ge 0) { $identityWidthOf[($at + 1)] = [int]$sized.Width }
            }
            foreach ($span in (Get-SheetsResultColumnWidths -Header $header `
                        -FirstColumnWidth $SheetsCheckTabFirstColumnWidth)) {
                for ($column = [int]$span.From; $column -le [int]$span.To; $column++) {
                    $wide = [int]$span.Width
                    if ($identityWidthOf.ContainsKey($column) -and $identityWidthOf[$column] -gt $wide) {
                        $wide = [int]$identityWidthOf[$column]
                    }
                    $identityWidthOf.Remove($column)
                    $plan += [pscustomobject]@{
                        Kind = 'ColumnWidth'; Sheet = $title
                        From = $column; To = $column; Width = $wide
                    }
                }
            }
            # Whatever the result never reached. A narrow result stops well before Trends, and
            # that column still has to be read across.
            foreach ($column in @($identityWidthOf.Keys)) {
                $plan += [pscustomobject]@{
                    Kind = 'ColumnWidth'; Sheet = $title
                    From = [int]$column; To = [int]$column; Width = [int]$identityWidthOf[$column]
                }
            }

            $plan += [pscustomobject]@{
                Kind    = 'Format'; Sheet = $title
                FromRow = $SheetsCheckTabResultRow - 1; ToRow = $SheetsCheckTabResultRow
                FromCol = 0; ToCol = $header.Count
                Wrap    = 'WRAP'
            }

            # Review Status as a closed list, and coloured like the chip it is meant to read
            # as. The column is the reviewer's, and constraining it is not a way of taking it
            # back: what a closed list buys is that "how many of these findings are closed" has
            # an answer, which a column holding five spellings of four ideas does not.
            #
            # Rewritten every run for the reason Overview's bands are: a value added to the
            # list has to reach the documents that already exist, and the alternative - adding
            # three more rules a week - fills the tab with duplicates.
            # Row as well as column, because the tab has two tables and both span every column
            # index the result uses. The header row of the result block identifies it.
            $reviewColumn = $dataHeader.Count + 1
            $plan += [pscustomobject]@{
                Kind   = 'Validation'
                Sheet  = $title
                Column = $reviewColumn
                Row    = $SheetsCheckTabResultRow - 1
                Name   = $SheetsRowReviewColumns[0]
                Values = @($SheetsRowReviewBands | ForEach-Object { $_.Value })
            }

            # And take the type off the identity block, where a run made before the row was
            # part of the match put it. It landed on whatever column sat at the same index -
            # 'Category', 'Prev findings', 'Trends' - offering a reviewer's vocabulary over a
            # number. Emitted every run rather than once: the boards that need it cannot be
            # named from here, and clearing a type that is not set costs one field in a request
            # that is being sent anyway.
            #
            # ToRow as well, and it clears the cells rather than a column type: the same
            # dropdown also reached the identity block the other way, as a plain rule drawn up
            # the column by the run that first created the tab. Taking a type off a table does
            # not touch a rule on a cell, so a board carrying the older defect keeps it until
            # the rows themselves are cleared. Everything above the result header, every column
            # of it: no column of the identity block is a reviewer's, so nothing there is
            # supposed to offer a choice.
            $plan += [pscustomobject]@{
                Kind    = 'ValidationClear'
                Sheet   = $title
                Row     = 0
                FromRow = 0
                ToRow   = $SheetsCheckTabResultRow - 1
            }

            # Only rules covering exactly this column are dropped. One somebody drew across the
            # result themselves is theirs and stays. From row 5 rather than row 1: the identity
            # block above is a different table, and a band drawn from the top would colour
            # cells belonging to neither.
            $tabRules = @()
            if ($Existing -and $Existing.ConditionalFormatsOf -and
                $Existing.ConditionalFormatsOf.ContainsKey($title)) {
                $tabRules = @($Existing.ConditionalFormatsOf[$title])
            }
            $tabDrop = @()
            for ($index = 0; $index -lt $tabRules.Count; $index++) {
                $ranges = @($tabRules[$index].ranges)
                if ($ranges.Count -eq 0) { continue }
                $mine = @($ranges | Where-Object {
                        [int]$_.startColumnIndex -eq ($reviewColumn - 1) -and
                        [int]$_.endColumnIndex -eq $reviewColumn })
                if ($mine.Count -eq $ranges.Count) { $tabDrop += $index }
            }
            $plan += [pscustomobject]@{
                Kind     = 'FormatRules'
                Sheet    = $title
                Column   = $reviewColumn
                StartRow = $SheetsCheckTabResultRow
                Drop     = $tabDrop
                Rules    = @($SheetsRowReviewBands | ForEach-Object {
                        [pscustomobject]@{
                            Type       = 'TEXT_EQ'
                            Values     = @($_.Value)
                            Colour     = $_.Colour
                            Background = $_.Background
                        }
                    })
            }
        }
    }

    # The SQL tab, once the blocks are known. The column is rewritten whole - nothing on it is
    # anybody's, and a statement can change between runs - but from the merge rather than from
    # this run, which is the distinction the tab lost and had to be given back.
    #
    # The merged column, and where each block's heading lands in it. Built here rather than as
    # the checks were collected, because a block belonging to a check this run did not hold
    # still occupies rows and still shifts everything under it.
    $sqlLines = @()
    $sqlBackLinks = @()
    $sqlRowOf = @{}
    foreach ($key in $sqlOrder) {
        $sqlRowOf[$key] = $sqlLines.Count + 1
        $sqlLines += , @('', '')
        foreach ($line in @($sqlOf[$key])) { $sqlLines += , @([string]$line, '') }
    }

    # Padded out to whatever the tab already held, and written over it without a clear first.
    #
    # The clear used to be its own request, sent in the phase before the values. Every other
    # thing this run clears it can also regenerate - an Overview row, a check tab's results -
    # so a run that stops between the two phases loses nothing that is not about to be sent
    # again. This tab is the exception: the statements of the checks the run did not hold exist
    # nowhere but here, and they reach the merge by being read back off it. Clearing first put
    # them in a window where a cancelled run, or a write that was refused, left the tab empty -
    # and the next narrow run then read no blocks, merged against nothing, and wrote its own
    # single statement over a catalogue. That is not a hypothetical: Golf lost 105 statements
    # to it on 2026-08-20 and the loss looked exactly like correct behaviour.
    # Overwriting in place cannot open that window. If the write never lands, what stands is
    # the previous column, entire.
    $sqlFloor = $(if ($Existing -and $Existing.PSObject.Properties.Name -contains 'SqlRowCount') {
            [int]$Existing.SqlRowCount
        }
        else { 0 })
    while ($sqlLines.Count -lt $sqlFloor) { $sqlLines += , @('', '') }

    # The other way the same catalogue can be lost: not a write that failed, but a read that
    # came back empty. Overwriting in place is no protection there - a run that believes the
    # tab held nothing writes its own statement over rows 1 to n and blanks the rest, which is
    # the same outcome by a different route.
    #
    # A tab carrying rows that yield no block is not an empty tab. It is a tab this run could
    # not read, and the honest response is to leave it exactly as it stands and say so. The
    # cost of skipping is that a statement changed this run is not refreshed until the next
    # one; the cost of not skipping is every other statement on the board.
    $sqlBlocksRead = @($(if ($Existing) { $Existing.SqlBlocks } else { @() })).Count
    $sqlUnreadable = ($sqlFloor -gt 0 -and $sqlBlocksRead -eq 0)
    if ($sqlUnreadable) {
        $sqlLines = @()
        $sqlWarning = ("The SQL tab holds {0:n0} rows that parse as no statement at all. " +
            'It has been left untouched rather than rewritten from this run alone - run the ' +
            "sport's whole catalogue to rebuild it.") -f $sqlFloor
    }

    # Every heading, not only this run's. The label is a link back to the check's own tab, and
    # for a check this run did not hold that tab is whatever the document already calls it.
    # Skipped entirely when the tab could not be read: the rows these point at are the rows the
    # rewrite would have made, and the rewrite is not happening.
    foreach ($key in $(if ($sqlUnreadable) { @() } else { $sqlOrder })) {
        $target = $(if ($sqlTitleOf.ContainsKey($key)) { $sqlTitleOf[$key] }
            elseif ($tabOf.ContainsKey($key)) { $tabOf[$key] } else { '' })
        $sqlBackLinks += [pscustomobject]@{
            Row   = $sqlRowOf[$key]
            Value = $(if ($target) { New-SheetsGidLink -Sheet $target -Text $key } else { $key })
        }
    }

    # C2 on each check tab, pointing at its block. Written for a check this run held, and for
    # one it did not whose block moved - a link to a row that now holds somebody else's SQL is
    # worse than a stale count, because it looks right. Which is exactly why an unreadable tab
    # writes none of them: every row number here would be a guess at a tab nobody rewrote.
    foreach ($key in $(if ($sqlUnreadable) { @() } else { $sqlOrder })) {
        $moved = (-not $sqlWasRow.ContainsKey($key)) -or ($sqlWasRow[$key] -ne $sqlRowOf[$key])
        $mine = $sqlTitleOf.ContainsKey($key)
        if (-not $moved -and -not $mine) { continue }
        $target = $(if ($mine) { $sqlTitleOf[$key] } elseif ($tabOf.ContainsKey($key)) { $tabOf[$key] } else { '' })
        if (-not $target) { continue }
        $plan += [pscustomobject]@{
            Kind   = 'Write'
            Raw    = $false
            Sheet  = $target
            Range  = ((ConvertTo-SheetsColumnName -Index ([array]::IndexOf($SheetsCheckTabColumns, 'SQL Used') + 1)) + '2')
            Values = @(, @((New-SheetsGidLink -Sheet $SheetsSqlTabName -Text 'SQL' -Cell ('A' + $sqlRowOf[$key]))))
        }
    }

    if ($sqlLines.Count -gt 0) {
        $sqlNeeded = $sqlLines.Count + 10
        if ($usedTitles.ContainsKey($SheetsSqlTabName)) {
            $have = $(if ($capacityOf.ContainsKey($SheetsSqlTabName)) { $capacityOf[$SheetsSqlTabName] } else { 1000 })
            $sqlId = $(if ($Existing -and $Existing.SheetIdOf -and $Existing.SheetIdOf.ContainsKey($SheetsSqlTabName)) {
                    [int]$Existing.SheetIdOf[$SheetsSqlTabName]
                }
                else { $null })
            if ($sqlNeeded -gt $have -and $null -ne $sqlId) {
                $plan += [pscustomobject]@{
                    Kind = 'Resize'; Sheet = $SheetsSqlTabName; SheetId = $sqlId; Rows = $sqlNeeded
                }
            }
        }
        else {
            $plan += [pscustomobject]@{
                Kind  = 'AddSheet'
                Sheet = $SheetsSqlTabName
                Rows  = [math]::Max($sqlNeeded, 1000)
            }
            $usedTitles[$SheetsSqlTabName] = $true
        }

        $plan += [pscustomobject]@{
            Kind   = 'Write'
            Sheet  = $SheetsSqlTabName
            Range  = (New-SheetsRange -FromColumn 1 -FromRow 1 -ToColumn 2 -ToRow $sqlLines.Count)
            Values = $sqlLines
        }
        $cells += $sqlLines.Count

        # The heading rows are links, so they go in the USER_ENTERED batch and land on top of
        # the blank cells the block write leaves for them.
        foreach ($back in $sqlBackLinks) {
            $plan += [pscustomobject]@{
                Kind   = 'Write'
                Raw    = $false
                Sheet  = $SheetsSqlTabName
                Range  = ('A{0}' -f $back.Row)
                Values = @(, @($back.Value))
            }
        }
        $cells += $sqlBackLinks.Count
    }

    # The log of notes with nowhere left to go.
    #
    # This is the tab that answers "why are three hundred rows still here". A check that
    # returned 1130 findings and now returns 800 says nothing about the 330 that went, and the
    # reviewer who marked half of them has no way to tell a correction from a scope that moved
    # under their feet. Each dropped note is written down with the reason it could not be put
    # back, and the tab accumulates: it is read backwards, from a count that surprises somebody
    # to the run that changed it.
    #
    # Rewritten whole from what was read plus what this run dropped, rather than appended to in
    # place. Nothing on it is anybody's - every row was generated - and rewriting is what keeps
    # a failed run from leaving a half-written block behind.
    $logRows = @()
    $logSeen = @{}
    $logStatusAt = [array]::IndexOf($SheetsReviewLogColumns, $SheetsRowReviewColumns[0])
    foreach ($was in @($(if ($Existing) { $Existing.ReviewLog } else { @() }))) {
        if (-not $was) { continue }
        $line = @($SheetsReviewLogColumns | ForEach-Object { [string]$was.$_ })
        if ([string]::IsNullOrWhiteSpace(($line -join ''))) { continue }

        # Renamed here too, and not only where a note is put back beside its finding. A row
        # logged before the vocabulary existed keeps the spelling of its own run otherwise, so
        # the same conclusion reads two ways depending on when it was dropped and a filter on
        # Fixed misses every row logged earlier - which is the drift the closed list exists to
        # stop, reappearing in the one place nobody would look for it.
        if ($logStatusAt -ge 0) {
            $line[$logStatusAt] = ConvertTo-SheetsReviewStatus -Value $line[$logStatusAt]
        }
        $logSeen[($line[0] + "`u{001F}" + $line[2] + "`u{001F}" + $line[3] + "`u{001F}" + $line[4])] = $true
        $logRows += , $line
    }
    foreach ($lost in $dropped) {
        $signature = ([string]$lost.CheckId + "`u{001F}" + [string]$lost.Key + "`u{001F}" +
            [string]$lost.Review + "`u{001F}" + [string]$lost.Note)
        if ($logSeen.ContainsKey($signature)) { continue }
        $logSeen[$signature] = $true
        # The key is joined by a unit separator, which no cell should display. Spelled out with
        # a visible separator instead, so somebody reading the log can match it against the
        # finding's own columns by eye.
        $logRows += , @(
            [string]$lost.CheckId
            [string]$lost.Tab
            (([string]$lost.Key) -replace "`u{001F}", ' | ')
            [string]$lost.Review
            [string]$lost.Note
            [string]$Stamp
            [string]$lost.Why
        )
    }

    if ($logRows.Count -gt 0) {
        if (-not $usedTitles.ContainsKey($SheetsReviewLogTabName)) {
            $plan += [pscustomobject]@{
                Kind  = 'AddSheet'
                Sheet = $SheetsReviewLogTabName
                Rows  = [math]::Max($logRows.Count + 100, 1000)
            }
            $usedTitles[$SheetsReviewLogTabName] = $true
        }
        else {
            $have = $(if ($capacityOf.ContainsKey($SheetsReviewLogTabName)) {
                    $capacityOf[$SheetsReviewLogTabName]
                } else { 1000 })
            $logId = $(if ($Existing -and $Existing.SheetIdOf -and
                    $Existing.SheetIdOf.ContainsKey($SheetsReviewLogTabName)) {
                    [int]$Existing.SheetIdOf[$SheetsReviewLogTabName]
                } else { $null })
            if (($logRows.Count + 10) -gt $have -and $null -ne $logId) {
                $plan += [pscustomobject]@{
                    Kind = 'Resize'; Sheet = $SheetsReviewLogTabName; SheetId = $logId
                    Rows = $logRows.Count + 100
                }
            }
        }

        $lastColumn = ConvertTo-SheetsColumnName -Index $SheetsReviewLogColumns.Count
        $plan += [pscustomobject]@{
            Kind = 'Clear'; Sheet = $SheetsReviewLogTabName; Range = ('A1:' + $lastColumn)
        }
        $plan += [pscustomobject]@{
            Kind   = 'Write'
            Sheet  = $SheetsReviewLogTabName
            Range  = (New-SheetsRange -FromColumn 1 -FromRow 1 `
                    -ToColumn $SheetsReviewLogColumns.Count -ToRow ($logRows.Count + 1))
            Values = @(, $SheetsReviewLogColumns) + $logRows
        }
        $cells += $SheetsReviewLogColumns.Count * ($logRows.Count + 1)

        $plan += [pscustomobject]@{
            Kind         = 'Table'
            Sheet        = $SheetsReviewLogTabName
            Name         = (ConvertTo-SheetsTableName -Name 'Review_log')
            FromRow      = 0
            ToRow        = $logRows.Count + 1
            FromCol      = 0
            ToCol        = $SheetsReviewLogColumns.Count
            HeaderColour = $SheetsDataHeaderColour
        }
        $plan += [pscustomobject]@{
            Kind = 'Freeze'; Sheet = $SheetsReviewLogTabName; Rows = 1
        }
    }

    # Every run of every check, oldest first within a check.
    #
    # Oldest first because Trends reads that way and ends on today. Newest first would put this
    # run at the top of each block, which is what a log wants, but then the same series runs
    # left-to-right in one column of the board and top-to-bottom against it in another, and a
    # reader has no way to know the two are the same numbers.
    #
    # The caller decides how many runs reach here and drops the oldest to make room, so this
    # writes what it is given and does not window anything itself. That keeps the one place
    # that reads the ledger the one place that decides what is kept.
    $historyRows = @($History | Where-Object { $_ })
    if ($historyRows.Count -gt 0) {
        $historyNeeded = $historyRows.Count + 1
        if (-not $usedTitles.ContainsKey($SheetsHistoryTabName)) {
            $plan += [pscustomobject]@{
                Kind  = 'AddSheet'
                Sheet = $SheetsHistoryTabName
                Rows  = [math]::Max($historyNeeded + 100, 1000)
            }
            $usedTitles[$SheetsHistoryTabName] = $true
        }
        else {
            $have = $(if ($capacityOf.ContainsKey($SheetsHistoryTabName)) {
                    $capacityOf[$SheetsHistoryTabName]
                } else { 1000 })
            $historyId = $(if ($Existing -and $Existing.SheetIdOf -and
                    $Existing.SheetIdOf.ContainsKey($SheetsHistoryTabName)) {
                    [int]$Existing.SheetIdOf[$SheetsHistoryTabName]
                } else { $null })
            if (($historyNeeded + 10) -gt $have -and $null -ne $historyId) {
                $plan += [pscustomobject]@{
                    Kind = 'Resize'; Sheet = $SheetsHistoryTabName; SheetId = $historyId
                    Rows = $historyNeeded + 100
                }
            }
        }

        # Cleared before it is written because the window shrinks as well as grows: a sport
        # whose oldest runs have just fallen off the end would otherwise keep them below the
        # new block, undated by anything on the tab and indistinguishable from current rows.
        $lastColumn = ConvertTo-SheetsColumnName -Index $SheetsHistoryColumns.Count
        $plan += [pscustomobject]@{
            Kind = 'Clear'; Sheet = $SheetsHistoryTabName; Range = ('A1:' + $lastColumn)
        }

        # Into a list, and over an index rather than through ForEach-Object. This is the one
        # block on the board whose height grows with every run rather than with the findings,
        # so the two costs that are noise on a fifty-row tab are the whole of it here.
        $historyValues = New-Object 'Collections.Generic.List[object]'
        foreach ($row in $historyRows) {
            $line = New-Object 'object[]' $SheetsHistoryColumns.Count
            for ($c = 0; $c -lt $SheetsHistoryColumns.Count; $c++) {
                $value = $row.($SheetsHistoryColumns[$c])
                $line[$c] = $(if ($null -eq $value) { '' } else { $value })
            }
            $historyValues.Add($line)
        }
        $plan += [pscustomobject]@{
            Kind   = 'Write'
            Sheet  = $SheetsHistoryTabName
            Range  = (New-SheetsRange -FromColumn 1 -FromRow 1 `
                    -ToColumn $SheetsHistoryColumns.Count -ToRow $historyNeeded)
            Values = @(, $SheetsHistoryColumns) + $historyValues.ToArray()
        }
        $cells += $SheetsHistoryColumns.Count * $historyNeeded

        $plan += [pscustomobject]@{
            Kind         = 'Table'
            Sheet        = $SheetsHistoryTabName
            Name         = (ConvertTo-SheetsTableName -Name 'History')
            FromRow      = 0
            ToRow        = $historyNeeded
            FromCol      = 0
            ToCol        = $SheetsHistoryColumns.Count
            HeaderColour = $SheetsDataHeaderColour
        }
        $plan += [pscustomobject]@{
            Kind = 'Freeze'; Sheet = $SheetsHistoryTabName; Rows = 1
        }
    }

    # A run rewrites essentially every cell it owns, so what this plan writes is a fair proxy
    # for what the document will hold. Reported rather than acted on: the answers are to drop
    # a check from the document, tighten a scope or split the sport, and none of those is the
    # runner's to choose silently.
    $warning = ''
    if ($sqlWarning) { $warning = $sqlWarning }
    if ($cells -gt $SheetsCellBudgetWarning) {
        $warning = ('This run writes {0:n0} cells. Google caps a spreadsheet at 10 000 000, ' +
            'and Sheets is slow well below that.') -f $cells
    }

    $known = @{}
    if ($Existing -and $Existing.SheetIdOf) {
        foreach ($key in $Existing.SheetIdOf.Keys) { $known[[string]$key] = [int]$Existing.SheetIdOf[$key] }
    }

    $tables = @{}
    if ($Existing -and $Existing.TableOf) {
        foreach ($key in $Existing.TableOf.Keys) { $tables[[string]$key] = $Existing.TableOf[$key] }
    }

    return [pscustomobject]@{
        Operations    = $plan
        Cells         = $cells
        StatusRenames = $statusRenames
        StatusKept    = $statusKept
        Warning       = $warning
        RowOf         = $rowOf
        TabOf         = $tabOf
        KnownSheetIds = $known
        KnownTables   = $tables
    }
}

# ----- transport -------------------------------------------------------------------------
#
# Everything above computes; everything below sends. The split is what lets the merge be
# tested without a login, and nothing below decides anything the merge has not already
# decided.

function Get-SheetsAccessToken {
    # The refresh token is long-lived and recorded once by Connect-Sheets.ps1; an access token
    # lasts an hour. Cached for the process with a minute of margin, because a run that takes
    # fifty minutes must not fail on the last check for a token that expired mid-request.
    param([switch]$Force)

    if (-not $Force -and $script:SheetsAccessToken -and (Get-Date) -lt $script:SheetsTokenExpiry) {
        return $script:SheetsAccessToken
    }

    foreach ($name in @('EP_SHEETS_CLIENT_ID', 'EP_SHEETS_CLIENT_SECRET', 'EP_SHEETS_REFRESH_TOKEN')) {
        if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($name))) {
            throw ("$name is not set. Run TOOLS\Connect-Sheets.ps1 once to authorise the " +
                'Google account; TOOLS\README.md has the console steps that come before it.')
        }
    }

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Set-SheetsAddressFamily -Uri $SheetsTokenUrl

    try {
        $response = Invoke-RestMethod -Method Post -Uri $SheetsTokenUrl -TimeoutSec 60 -Body @{
            client_id     = $env:EP_SHEETS_CLIENT_ID
            client_secret = $env:EP_SHEETS_CLIENT_SECRET
            refresh_token = $env:EP_SHEETS_REFRESH_TOKEN
            grant_type    = 'refresh_token'
        }
    }
    catch {
        # invalid_grant is the one worth naming, because its cause is never in this code and
        # the message Google returns does not say what to do about it.
        $detail = $_.Exception.Message
        if ($detail -like '*400*') {
            $detail += ("`n  The refresh token was rejected. It is revoked by a password change, by " +
                'removing the app from the account, or after seven days if the OAuth consent screen ' +
                'is External and still in Testing. Re-run TOOLS\Connect-Sheets.ps1 -Force.')
        }
        throw "Google refused the refresh token: $detail"
    }

    $script:SheetsAccessToken = [string]$response.access_token
    $script:SheetsTokenExpiry = (Get-Date).AddSeconds([int]$response.expires_in - 60)
    return $script:SheetsAccessToken
}

function Invoke-SheetsApi {
    param(
        [string]$Method,
        [string]$Path,
        $Body
    )

    $uri = "$SheetsApiRoot/$Path"
    Set-SheetsAddressFamily -Uri $uri
    $headers = @{ Authorization = 'Bearer ' + (Get-SheetsAccessToken) }

    $arguments = @{
        Method     = $Method
        Uri        = $uri
        Headers    = $headers
        TimeoutSec = 180
    }
    if ($null -ne $Body) {
        $arguments['Body'] = ($Body | ConvertTo-Json -Depth 12 -Compress)
        $arguments['ContentType'] = 'application/json; charset=utf-8'
    }

    try { return Invoke-RestMethod @arguments }
    catch {
        # Google's own message is in the body and says far more than the status line does -
        # which range was malformed, which sheet does not exist, which scope is missing.
        $detail = $_.Exception.Message
        if ($_.Exception.Response) {
            try {
                $reader = New-Object IO.StreamReader($_.Exception.Response.GetResponseStream())
                $detail = $reader.ReadToEnd()
            }
            catch { }
        }
        throw "Sheets API $Method $Path failed: $detail"
    }
}

function Read-SheetReviewNotes {
    <#
        Every row-level note the document holds, keyed the way the next run will look for it.

        Two reads at most, and usually one of them touches nothing. A board can carry a hundred
        tabs and tens of thousands of result rows, so reading the blocks whole to find a handful
        of notes would cost more than the run that follows it. Instead:

          - the reviewer columns alone are asked for first. Google stops a range at its last
            non-empty cell, so a tab where nobody has written anything comes back empty and is
            done with in one row of JSON;
          - only the tabs that came back with something are asked for their id columns, which
            are what a note is tied to.

        Called with the header row already in hand, because that is what says where those
        columns are on each tab. A tab whose header has no reviewer columns is not read at all -
        it has never been through a run that could have written a note.
    #>
    param([string]$SpreadsheetId, $HeaderOf, [int]$ChunkSize = 40)

    $notesOf = @{}
    if (-not $HeaderOf) { return $notesOf }

    $candidates = @()
    foreach ($title in @($HeaderOf.Keys)) {
        $header = @($HeaderOf[$title])

        $at = Get-SheetsReviewColumnIndex -Header $header
        if ($at -ge 0) {
            $candidates += [pscustomobject]@{
                Title  = [string]$title
                Header = $header
                From   = $at
                To     = $at + $SheetsRowReviewColumns.Count - 1
                Legacy = $false
            }
            continue
        }

        # A tab that has never had the reviewer columns, but may have been written on anyway.
        # Before they existed there was nowhere to put a per-row conclusion, and on Triathlon
        # 388 of them went into eligible_count - the coverage column, which every run
        # overwrites. Read once, on the run that gives the tab somewhere better, after which
        # the column is empty again and this finds nothing.
        #
        # A number is not a note: eligible_count holds the coverage count on its own row, and
        # that row is the runner's.
        $legacy = [array]::IndexOf($header, 'eligible_count')
        if ($legacy -lt 0) { continue }
        $candidates += [pscustomobject]@{
            Title  = [string]$title
            Header = $header
            From   = $legacy
            To     = $legacy
            Legacy = $true
        }
    }
    if ($candidates.Count -eq 0) { return $notesOf }

    $written = @()
    for ($i = 0; $i -lt $candidates.Count; $i += $ChunkSize) {
        $slice = @($candidates[$i..([math]::Min($i + $ChunkSize - 1, $candidates.Count - 1))])
        $query = ($slice | ForEach-Object {
                'ranges=' + [uri]::EscapeDataString(("'{0}'!{1}{2}:{3}" -f
                        ($_.Title -replace "'", "''"),
                    (ConvertTo-SheetsColumnName -Index ($_.From + 1)),
                    ($SheetsCheckTabResultRow + 1),
                    (ConvertTo-SheetsColumnName -Index ($_.To + 1))))
            }) -join '&'
        $answer = Invoke-SheetsApi -Method Get -Path "$SpreadsheetId/values:batchGet`?$query&majorDimension=ROWS"
        $ranges = @($answer.valueRanges)

        for ($j = 0; $j -lt $slice.Count; $j++) {
            if ($j -ge $ranges.Count) { break }
            $rows = @($ranges[$j].values)
            $marked = @()
            for ($r = 0; $r -lt $rows.Count; $r++) {
                $cells = @($rows[$r])
                $review = $(if ($cells.Count -gt 0) { [string]$cells[0] } else { '' })
                $note = $(if ($cells.Count -gt 1) { [string]$cells[1] } else { '' })
                if ([string]::IsNullOrWhiteSpace($review) -and [string]::IsNullOrWhiteSpace($note)) { continue }
                if ($slice[$j].Legacy) {
                    $number = 0.0
                    if ([double]::TryParse($review.Trim(), [ref]$number)) { continue }
                    $note = ''
                }
                $marked += [pscustomobject]@{
                    Offset = $r
                    Review = $review
                    Note   = $note
                }
            }
            if ($marked.Count -gt 0) {
                $written += [pscustomobject]@{ Tab = $slice[$j]; Marked = $marked }
            }
        }
    }
    if ($written.Count -eq 0) { return $notesOf }

    # The id columns of the tabs that turned out to hold something. Asked for from column A
    # through the last of them rather than one range each: they sit at the front of a result and
    # a single span is one range instead of five.
    #
    # A tab holding a `Fixed` mark is read wider - through its last data column instead of its
    # last id column - because that conclusion is carried over only against an identical row and
    # the comparison needs the row. The width is paid for by the tabs that need it and by no
    # others, which on a board where `Fixed` is rare is most of them.
    for ($i = 0; $i -lt $written.Count; $i += $ChunkSize) {
        $slice = @($written[$i..([math]::Min($i + $ChunkSize - 1, $written.Count - 1))])
        $spans = @()
        $wide = @()
        foreach ($one in $slice) {
            $keyColumns = @(Get-SheetsFindingKeyColumns -Header $one.Tab.Header)
            $last = 0
            foreach ($index in $keyColumns) { if ($index -gt $last) { $last = $index } }

            $needsRow = $false
            foreach ($mark in @($one.Marked)) {
                if ((ConvertTo-SheetsReviewStatus -Value $mark.Review) -eq $SheetsRowReviewCarriedOnPayload) {
                    $needsRow = $true
                    break
                }
            }
            if ($needsRow -and $one.Tab.From -gt 0 -and ($one.Tab.From - 1) -gt $last) {
                $last = $one.Tab.From - 1
            }
            $wide += $needsRow
            $spans += $last
        }

        $query = @()
        for ($j = 0; $j -lt $slice.Count; $j++) {
            $query += 'ranges=' + [uri]::EscapeDataString(("'{0}'!A{1}:{2}" -f
                    ($slice[$j].Tab.Title -replace "'", "''"),
                ($SheetsCheckTabResultRow + 1),
                (ConvertTo-SheetsColumnName -Index ($spans[$j] + 1))))
        }
        $answer = Invoke-SheetsApi -Method Get -Path ("$SpreadsheetId/values:batchGet`?" +
            ($query -join '&') + '&majorDimension=ROWS')
        $ranges = @($answer.valueRanges)

        for ($j = 0; $j -lt $slice.Count; $j++) {
            if ($j -ge $ranges.Count) { break }
            $rows = @($ranges[$j].values)
            $keyColumns = @(Get-SheetsFindingKeyColumns -Header $slice[$j].Tab.Header)

            $kept = @()
            foreach ($mark in @($slice[$j].Marked)) {
                if ($mark.Offset -ge $rows.Count) { continue }
                # Only where the whole row was asked for. A fingerprint built from a short read
                # would be a fingerprint of the id columns, which every matching key already
                # shares, and would carry `Fixed` over exactly where it should not.
                $print = ''
                if ($wide[$j]) {
                    $width = [math]::Max(0, $slice[$j].Tab.From)
                    $cells = @($rows[$mark.Offset])
                    $line = @()
                    for ($c = 0; $c -lt $width; $c++) {
                        $line += $(if ($c -lt $cells.Count) { $cells[$c] } else { '' })
                    }
                    $print = Get-SheetsRowFingerprint -Values $line
                }
                $kept += [pscustomobject]@{
                    Key         = (Get-SheetsFindingKey -Row @($rows[$mark.Offset]) -Columns $keyColumns)
                    Review      = $mark.Review
                    Note        = $mark.Note
                    Fingerprint = $print
                }
            }
            if ($kept.Count -gt 0) { $notesOf[$slice[$j].Tab.Title] = $kept }
        }
    }

    return $notesOf
}

function Read-SheetState {
    <#
        What the document already holds, in the shape New-SheetsMergePlan expects.

        Two reads, not more. The tab list and the Overview CheckID column are enough: an
        existing check is found by its CheckID and updated in the row it occupies, and a tab
        is found by the Check ID its own A2 carries rather than by guessing at the title,
        because the title is an abbreviation of the check name and the name can change.
    #>
    param([string]$SpreadsheetId)

    $meta = Invoke-SheetsApi -Method Get -Path ("$SpreadsheetId" +
        '?fields=properties.title,sheets.properties.title,sheets.properties.sheetId' +
        ',sheets.properties.gridProperties.rowCount,sheets.tables' +
        ',sheets.conditionalFormats.ranges')
    $titles = @($meta.sheets | ForEach-Object { [string]$_.properties.title })
    $hasOverview = ($titles -contains 'Overview')

    # How many rows each tab's grid currently holds, and the id that identifies it. A write
    # past the end of the grid is rejected outright - Google does not grow a sheet to meet a
    # range that starts beyond it - so the plan has to know the capacity before it can decide
    # to raise it, and updateSheetProperties names a sheet by id rather than by title.
    $capacityOf = @{}
    $idOf = @{}
    $indexOf = @{}
    $tableOf = @{}
    $formatsOf = @{}
    $position = 0
    foreach ($sheet in @($meta.sheets)) {
        $title = [string]$sheet.properties.title
        $capacityOf[$title] = [int]$sheet.properties.gridProperties.rowCount
        $idOf[$title] = [int]$sheet.properties.sheetId
        $indexOf[$title] = $position
        $position++

        # Ranges only. A conditional format rule is identified for replacement by what it
        # covers and nothing else, so the condition and the colours are weight the read does
        # not need to carry - and the ranges come back in the order the rules are indexed in,
        # which is what deleting one depends on.
        $formatsOf[$title] = @($sheet.conditionalFormats)

        # Every table on the tab, not the first of them. A check tab carries two - the identity
        # block at the top and the results below it - and reading only one made the planner
        # hand the identity block's range to whichever table happened to come back first,
        # which on an established board is the result table.
        #
        # A table somebody made themselves is kept and its extent corrected rather than
        # replaced: the range is what goes stale as a result grows or shrinks, and correcting
        # it is the whole of what maintenance means here.
        $tableOf[$title] = @(@($sheet.tables) | Where-Object { $_ } | ForEach-Object {
                [pscustomobject]@{
                    Id      = [string]$_.tableId
                    Name    = [string]$_.name
                    FromRow = [int]$_.range.startRowIndex
                    ToRow   = [int]$_.range.endRowIndex
                    FromCol = [int]$_.range.startColumnIndex
                    ToCol   = [int]$_.range.endColumnIndex
                    # Carried because a table's column may hold a type, and a typed column
                    # refuses setDataValidation outright: its dropdown belongs to the table.
                    # Updating them means resending the whole list, so the whole list is read.
                    Columns = @($_.columnProperties)
                }
            })
    }

    # Only tabs that exist may be named in a range. Google rejects the whole batch with
    # "Unable to parse range" for one that does not, so a brand new document - which has a
    # single Sheet1 and no Overview - would fail on the read before anything could be written.
    # Through K rather than through B, because the merge needs to know which Comment cells are
    # empty as well as which checks are on the board.
    $reads = @()
    # Out to the last column the board writes, computed rather than lettered: this used to stop
    # at K, which was everything the merge then needed - the CheckIDs, the Status and which
    # Comment cells are empty. It now also has to see row 1 whole, because a header narrower
    # than the current column list is how a board says it predates a column the package has
    # since added, and the columns added since have all come after K. A hundred rows of a
    # twenty-three column board is one small range; stopping short of it is what cost the
    # information.
    if ($hasOverview) {
        $reads += ('Overview!A1:' + (ConvertTo-SheetsColumnName -Index $SheetsOverviewColumns.Count))
    }
    # The SQL tab whole, because a run that holds only some of the checks still has to leave
    # the blocks belonging to the others where they were. Column A is all of it.
    $hasSql = ($titles -contains $SheetsSqlTabName)
    if ($hasSql) { $reads += ($SheetsSqlTabName + '!A1:A') }
    $hasReviewLog = ($titles -contains $SheetsReviewLogTabName)
    if ($hasReviewLog) {
        $reads += ("'" + ($SheetsReviewLogTabName -replace "'", "''") + "'!A2:" +
            (ConvertTo-SheetsColumnName -Index $SheetsReviewLogColumns.Count))
    }
    $checkTabs = @($titles | Where-Object {
            $_ -ne 'Overview' -and $_ -ne $SheetsSqlTabName -and
            $_ -ne $SheetsReviewLogTabName -and $_ -ne $SheetsHistoryTabName
        })
    # Rows 1 and 2 of every check tab, in one range rather than the single A2 cell this used to
    # ask for. Row 2 is the identity the tab is matched by; row 1 is the column names it was
    # last written with, and the merge needs those to see that the tab predates a column the
    # package has since added. It costs no extra range, which is what the read is chunked by.
    foreach ($title in $checkTabs) { $reads += "'" + ($title -replace "'", "''") + "'!1:2" }

    # Row 5 of every check tab: the result's own column names, which say both where the reviewer
    # columns are and which columns identify a finding. Cheap - one row per tab - and it is what
    # makes the two reads below ask for a few columns instead of a whole block.
    foreach ($title in $checkTabs) { $reads += "'" + ($title -replace "'", "''") + "'!5:5" }

    $rowOf = @{}
    $tabOf = @{}
    $emptyComment = @{}
    $statusOf = @{}
    # A tab holding no Check ID in its own A2. Almost always this run's predecessor: the tabs
    # go in one batch and the values in another, so a document update that fails on the second
    # leaves the first behind. Naming them lets the next run adopt its own leftovers instead
    # of minting a second set beside them.
    $emptyTabs = @{}
    $hasHeader = $false
    $overviewHeader = @()
    $checkTabHeaderOf = @{}
    $checkTabIdentityOf = @{}
    $sqlBlocks = @()
    $sqlRowCount = 0
    $resultHeaderOf = @{}
    $reviewNotesOf = @{}
    $reviewLog = @()

    if ($reads.Count -gt 0) {
        # Sent in chunks and stitched back together in order, because every range is a query
        # parameter and the whole read is one URL. A board of a hundred tabs asks for a hundred
        # A2 cells and a hundred header rows, and past a few kilobytes a GET stops being served
        # rather than being answered slowly. The order is what the offsets below depend on, so
        # the chunks are concatenated exactly as they were asked for.
        $ranges = @()
        for ($i = 0; $i -lt $reads.Count; $i += $SheetsReadChunk) {
            $slice = @($reads[$i..([math]::Min($i + $SheetsReadChunk - 1, $reads.Count - 1))])
            $query = ($slice | ForEach-Object { 'ranges=' + [uri]::EscapeDataString($_) }) -join '&'
            $values = Invoke-SheetsApi -Method Get -Path "$SpreadsheetId/values:batchGet`?$query&majorDimension=ROWS"
            $ranges += @($values.valueRanges)
        }

        $offset = 0
        if ($hasOverview -and $ranges.Count -gt 0) {
            $rows = @($ranges[0].values)
            # Row 1 is the header when there is one at all; CheckID is column B.
            $hasHeader = ($rows.Count -gt 0 -and @($rows[0]).Count -gt 0 -and
                -not [string]::IsNullOrWhiteSpace([string]@($rows[0])[0]))
            # And the names it holds, so the merge can see which columns the board was last
            # written with and place any that have been added since.
            if ($hasHeader) { $overviewHeader = @(@($rows[0]) | ForEach-Object { [string]$_ }) }
            for ($r = 1; $r -lt $rows.Count; $r++) {
                $cells = @($rows[$r])
                if ($cells.Count -lt 2) { continue }
                $checkId = [string]$cells[1]
                if ([string]::IsNullOrWhiteSpace($checkId)) { continue }
                $rowOf[$checkId] = $r + 1

                # K is column index 10. A short row means the API stopped at the last
                # non-empty cell, so anything short of K has an empty Comment.
                if ($cells.Count -lt 11 -or [string]::IsNullOrWhiteSpace([string]$cells[10])) {
                    $emptyComment[$checkId] = $true
                }

                # The Status as it stands, so the merge can tell a superseded spelling from a
                # current one. Read and not written back here: what to do with it is the
                # planner's decision, and this function only reports the document.
                $statusIndex = [array]::IndexOf($SheetsOverviewColumns, 'Status')
                if ($cells.Count -gt $statusIndex) {
                    $statusOf[$checkId] = [string]$cells[$statusIndex]
                }
            }
            $offset = 1
        }

        # The SQL tab as blocks. A heading row carries a link whose label is the CheckID and
        # nothing else, which is what separates it from the statement lines under it; a line
        # of SQL never has that shape.
        if ($hasSql -and $ranges.Count -gt $offset) {
            $lines = @(@($ranges[$offset].values) | ForEach-Object { [string]@($_)[0] })
            $offset++
            $current = $null
            for ($r = 0; $r -lt $lines.Count; $r++) {
                $text = [string]$lines[$r]
                if ($text -match '^[A-Za-z][A-Za-z0-9-]*-(DQ|DISCOVERY)-[0-9]+$') {
                    if ($current) { $sqlBlocks += $current }
                    $current = [pscustomobject]@{ CheckId = $text; Row = $r + 1; Lines = @() }
                    continue
                }
                if ($current) { $current.Lines += $text }
            }
            if ($current) { $sqlBlocks += $current }
            # How far the tab's content reached, so the rewrite can blank whatever it does not
            # cover instead of clearing the tab first. See the write side for why that matters.
            $sqlRowCount = $lines.Count
        }

        # Whatever has already been logged, so this run appends to it rather than over it. Read
        # before the tabs because the ranges come back in the order they were asked for.
        if ($hasReviewLog -and $ranges.Count -gt $offset) {
            foreach ($line in @(@($ranges[$offset].values))) {
                $cells = @($line)
                if ($cells.Count -eq 0) { continue }
                $entry = [ordered]@{}
                for ($c = 0; $c -lt $SheetsReviewLogColumns.Count; $c++) {
                    $entry[$SheetsReviewLogColumns[$c]] = $(if ($c -lt $cells.Count) { [string]$cells[$c] } else { '' })
                }
                $reviewLog += [pscustomobject]$entry
            }
            $offset++
        }

        # A tab is matched to its check by the Check ID its own A2 carries, never by its
        # title: the title is an abbreviation of the check name, and a name can change without
        # the check becoming a different one.
        #
        # The range is rows 1 and 2 together, so row 1 arrives first and the identity second.
        # A tab whose row 1 is blank still returns two entries, the first of them empty, so the
        # identity is read from index 1 and never from whichever row happened to have content.
        for ($i = 0; $i -lt $checkTabs.Count; $i++) {
            $index = $i + $offset
            if ($index -ge $ranges.Count) { break }
            $rows = @($ranges[$index].values)

            if ($rows.Count -gt 0) {
                $checkTabHeaderOf[$checkTabs[$i]] = @(@($rows[0]) | ForEach-Object { [string]$_ })
            }
            # The identity row whole, not just the Check ID out of it. A tab this run does not
            # produce is the only thing that can carry a layout the package has moved on from,
            # and moving its values to where they now belong needs the values.
            if ($rows.Count -gt 1) {
                $checkTabIdentityOf[$checkTabs[$i]] = @(@($rows[1]) | ForEach-Object { [string]$_ })
            }

            $checkId = ''
            if ($rows.Count -gt 1 -and @($rows[1]).Count -gt 0) { $checkId = [string]@($rows[1])[0] }

            if (-not [string]::IsNullOrWhiteSpace($checkId)) { $tabOf[$checkId] = $checkTabs[$i] }
            else { $emptyTabs[$checkTabs[$i]] = $true }
        }

        # Row 5 of each tab, in the same order, straight after the identity block.
        $headerAt = $offset + $checkTabs.Count
        for ($i = 0; $i -lt $checkTabs.Count; $i++) {
            $index = $i + $headerAt
            if ($index -ge $ranges.Count) { break }
            $rows = @($ranges[$index].values)
            if ($rows.Count -eq 0) { continue }
            $resultHeaderOf[$checkTabs[$i]] = @(@($rows[0]) | ForEach-Object { [string]$_ })
        }
    }

    $reviewNotesOf = Read-SheetReviewNotes -SpreadsheetId $SpreadsheetId -HeaderOf $resultHeaderOf

    return [pscustomobject]@{
        Title             = [string]$meta.properties.title
        Titles            = $titles
        HasOverviewSheet  = $hasOverview
        HasOverviewHeader = $hasHeader
        OverviewHeader    = $overviewHeader
        CheckTabHeaderOf  = $checkTabHeaderOf
        CheckTabIdentityOf = $checkTabIdentityOf
        OverviewRowOf     = $rowOf
        EmptyCommentOf    = $emptyComment
        StatusOf          = $statusOf
        TabOf             = $tabOf
        EmptyTabs         = $emptyTabs
        RowCapacityOf     = $capacityOf
        SheetIdOf         = $idOf
        SheetIndexOf      = $indexOf
        TableOf           = $tableOf
        ResultHeaderOf    = $resultHeaderOf
        ReviewNotesOf     = $reviewNotesOf
        ReviewLog         = $reviewLog
        SqlBlocks         = $sqlBlocks
        SqlRowCount       = $sqlRowCount
        ConditionalFormatsOf = $formatsOf
    }
}

function Split-SheetsWriteChunks {
    # One write operation into as many as its row count needs. A 20 000-row block is megabytes
    # of JSON in a single body: slow to build, slow to send, and lost entirely if it fails.
    param($Operation, [int]$ChunkSize = $SheetsWriteChunk)

    $values = @($Operation.Values)
    if ($values.Count -le $ChunkSize) { return @($Operation) }

    # Only a range anchored at a known first row can be split, which every result block is.
    if ($Operation.Range -notmatch '^([A-Z]+)(\d+):([A-Z]+)(\d+)$') { return @($Operation) }
    $fromColumn = $matches[1]
    $fromRow = [int]$matches[2]
    $toColumn = $matches[3]

    $chunks = @()
    $offset = 0
    while ($offset -lt $values.Count) {
        $slice = @($values | Select-Object -Skip $offset -First $ChunkSize)
        $start = $fromRow + $offset
        $chunks += [pscustomobject]@{
            Kind   = 'Write'
            Sheet  = $Operation.Sheet
            Range  = '{0}{1}:{2}{3}' -f $fromColumn, $start, $toColumn, ($start + $slice.Count - 1)
            Values = $slice
        }
        $offset += $ChunkSize
    }
    return $chunks
}

function ConvertTo-SheetsCellValue {
    # Sheets takes strings, numbers and booleans. A $null becomes an empty string rather than
    # a JSON null, which the API rejects inside a value range.
    param($Value)

    if ($null -eq $Value) { return '' }
    if ($Value -is [bool]) { return $Value }
    if ($Value -is [int] -or $Value -is [long] -or $Value -is [double] -or $Value -is [decimal]) { return $Value }
    return [string]$Value
}

function Invoke-SheetsPlan {
    # Send a plan. Ordered rather than batched into one call: tabs have to exist before
    # anything is written into them, and stale rows have to be gone before new ones land on
    # top of them. Within each of those three phases the requests are batched.
    param([string]$SpreadsheetId, $Plan)

    $operations = @($Plan.Operations)

    # Every table the document already has, keyed by tab. Built here rather than in the table
    # stage because the dropdown needs it too: a column inside a table carries its validation
    # on the table, and the two stages must not disagree about which tables exist.
    $knownTables = @{}
    if ($Plan.PSObject.Properties.Name -contains 'KnownTables' -and $Plan.KnownTables) {
        foreach ($key in $Plan.KnownTables.Keys) { $knownTables[[string]$key] = $Plan.KnownTables[$key] }
    }

    $script:SheetsStage = 'adding and sizing tabs'
    # Structure first, and in one call: a tab has to exist before a range names it, and a grid
    # has to be big enough before a range reaches past its end. Both are rejected the same
    # way, and a rejection takes the whole batch it travelled in.
    $adds = @($operations | Where-Object { $_.Kind -eq 'AddSheet' })
    $resizes = @($operations | Where-Object { $_.Kind -eq 'Resize' })
    $structure = @()

    foreach ($add in $adds) {
        $rows = $(if ($add.PSObject.Properties.Name -contains 'Rows' -and $add.Rows) { [int]$add.Rows } else { 1000 })
        $structure += @{
            addSheet = @{
                properties = @{
                    title          = $add.Sheet
                    gridProperties = @{ rowCount = $rows; columnCount = 26 }
                }
            }
        }
    }
    foreach ($resize in $resizes) {
        # By sheetId: updateSheetProperties identifies a sheet by id and not by title, and
        # setting title here would rename the tab rather than find it. A tab this run is
        # adding needs no resize, because it is created at the size it needs.
        $structure += @{
            updateSheetProperties = @{
                properties = @{
                    sheetId        = [int]$resize.SheetId
                    gridProperties = @{ rowCount = [int]$resize.Rows }
                }
                fields     = 'gridProperties.rowCount'
            }
        }
    }

    # Room for a column added since the tab was last written, made here so that every write
    # below it lands in the layout it expects. Only a tab the document already has can need it,
    # so a tab this run is adding is never in the list - it is created at today's width.
    #
    # Ascending, and the indices are positions in the finished layout, which is what makes
    # applying them in order correct: an insertion at 15 does not move anything at 9, so a
    # second insertion further right still finds its own place. inheritFromBefore is false
    # because the column to the left is a numeric result column and the new one is a heading
    # this run is about to write - borrowing its formatting is how a header cell arrives
    # right-aligned and bold for no reason anybody can trace.
    # The ids come from what the document already had, never from $gidOf: that map is not built
    # until the structure batch has been sent and answered, and a tab this batch is minting
    # cannot need an insertion anyway.
    $existingIdOf = @{}
    if ($Plan.PSObject.Properties.Name -contains 'KnownSheetIds' -and $Plan.KnownSheetIds) {
        foreach ($key in $Plan.KnownSheetIds.Keys) { $existingIdOf[[string]$key] = [int]$Plan.KnownSheetIds[$key] }
    }
    foreach ($insert in @($operations | Where-Object { $_.Kind -eq 'InsertColumn' } |
                Sort-Object -Property Sheet, At)) {
        if (-not $existingIdOf.ContainsKey([string]$insert.Sheet)) { continue }
        $structure += @{
            insertDimension = @{
                range             = @{
                    sheetId    = [int]$existingIdOf[[string]$insert.Sheet]
                    dimension  = 'COLUMNS'
                    startIndex = [int]$insert.At
                    endIndex   = ([int]$insert.At + 1)
                }
                inheritFromBefore = $false
            }
        }
    }

    # Requests apply in order, so the removal goes before the move: deleting a sheet shifts
    # every index after it, and Overview's target of 0 has to be read against the document as
    # it will be, not as it was.
    foreach ($drop in @($operations | Where-Object { $_.Kind -eq 'DeleteSheet' })) {
        $structure += @{ deleteSheet = @{ sheetId = [int]$drop.SheetId } }
    }
    foreach ($move in @($operations | Where-Object { $_.Kind -eq 'MoveSheet' })) {
        $structure += @{
            updateSheetProperties = @{
                properties = @{ sheetId = [int]$move.SheetId; index = [int]$move.Index }
                fields     = 'index'
            }
        }
    }

    # Every tab id this run can name: the ones the document already had, plus the ones the
    # structure batch has just minted. A link carries the target's numeric id and nothing
    # knows a new tab's id until Google answers, which is why the plan writes a token.
    $gidOf = @{}
    if ($Plan.PSObject.Properties.Name -contains 'KnownSheetIds' -and $Plan.KnownSheetIds) {
        foreach ($key in $Plan.KnownSheetIds.Keys) { $gidOf[[string]$key] = [int]$Plan.KnownSheetIds[$key] }
    }

    if ($structure.Count -gt 0) {
        $answer = Invoke-SheetsApi -Method Post -Path "$SpreadsheetId`:batchUpdate" -Body @{ requests = $structure }
        foreach ($reply in @($answer.replies)) {
            if ($reply.addSheet) {
                $gidOf[[string]$reply.addSheet.properties.title] = [int]$reply.addSheet.properties.sheetId
            }
        }
    }

    $script:SheetsStage = 'hiding columns and colouring Rows'
    # Both need a tab id, so they wait for the batch that creates the tab.
    #
    # The operation carries which way it is setting the flag. It used to set only true, which
    # is how a board ended up hiding whatever it had ever hidden - and the planner now states
    # the whole row either way, so a column the package does not hide is opened rather than
    # left as it was found.
    $hides = @($operations | Where-Object { $_.Kind -eq 'HideColumns' })
    $second = @()
    foreach ($hide in $hides) {
        if (-not $gidOf.ContainsKey($hide.Sheet)) { continue }
        $hiddenByUser = $true
        if ($hide.PSObject.Properties.Name -contains 'Hidden') { $hiddenByUser = [bool]$hide.Hidden }
        $second += @{
            updateDimensionProperties = @{
                range      = @{
                    sheetId    = [int]$gidOf[$hide.Sheet]
                    dimension  = 'COLUMNS'
                    startIndex = [int]$hide.From - 1
                    endIndex   = [int]$hide.To
                }
                properties = @{ hiddenByUser = $hiddenByUser }
                fields     = 'hiddenByUser'
            }
        }
    }

    # Every deletion first, across every column, highest index first - then the additions.
    #
    # Each deletion renumbers the rules after it, which is why they descend. The reason they
    # are gathered across operations rather than done a column at a time is the same rule one
    # level up: two columns each deleting by indexes read off the same original list will have
    # the second delete whatever the first has already shifted into those positions. That cost
    # a board its entire Rows colouring and left three stale Status rules behind it, and
    # computing both index lists in a single pass - which the planner does - is not enough on
    # its own to prevent it.
    $ruleOps = @($operations | Where-Object { $_.Kind -eq 'FormatRules' -and $gidOf.ContainsKey($_.Sheet) })
    $second += @(Get-SheetsRuleDeletions -RuleOps $ruleOps -GidOf $gidOf)

    foreach ($rules in $ruleOps) {
        $sheetId = [int]$gidOf[$rules.Sheet]
        $at = 0
        foreach ($band in @($rules.Rules)) {
            $second += @{
                addConditionalFormatRule = @{
                    index = $at
                    rule  = @{
                        # No endRowIndex, so the band covers the column however far the board
                        # grows. startRowIndex 1 keeps it off the header.
                        ranges     = @($(
                                # Row 1 by default, which is the row under Overview's header.
                                # A check tab's result header is on row 5 and the identity
                                # block above it is a different table, so a band drawn from
                                # row 1 there would colour cells belonging to neither.
                                $band_range = @{
                                    sheetId          = $sheetId
                                    startRowIndex    = $(if ($rules.PSObject.Properties.Name -contains 'StartRow' -and
                                            $null -ne $rules.StartRow) { [int]$rules.StartRow } else { 1 })
                                    startColumnIndex = [int]$rules.Column - 1
                                    endColumnIndex   = [int]$rules.Column
                                }
                                if ($rules.PSObject.Properties.Name -contains 'EndRow' -and $rules.EndRow) {
                                    $band_range['endRowIndex'] = [int]$rules.EndRow
                                }
                                $band_range
                            ))
                        booleanRule = @{
                            condition = @{
                                type   = [string]$band.Type
                                values = @(@($band.Values) | ForEach-Object { @{ userEnteredValue = [string]$_ } })
                            }
                            # A band may carry a fill as well as a text colour. Rows does not:
                            # a column of numbers reads better coloured than blocked out. A
                            # Status does, because what it wants to look like is a chip.
                            format    = $(
                                $format = @{
                                    textFormat = @{
                                        bold                 = $true
                                        foregroundColorStyle = @{ rgbColor = (ConvertTo-SheetsColour -Hex $band.Colour) }
                                    }
                                }
                                if ($band.PSObject.Properties.Name -contains 'Background' -and $band.Background) {
                                    $format['backgroundColorStyle'] = @{
                                        rgbColor = (ConvertTo-SheetsColour -Hex $band.Background)
                                    }
                                }
                                $format
                            )
                        }
                    }
                }
            }
            $at++
        }
    }

    # The dropdown, and it goes before anything that formats the same cells. Giving a table
    # column a type clears the formats of the cells under it, so an alignment applied first
    # simply vanishes - which is what left one column of an otherwise centred board stubbornly
    # not centred. Rewritten every run for the reason the colour bands are: a vocabulary
    # changed in the source has to reach a document that already exists.
    # Cleared before it is set, so a column that has to move from one table to the other does
    # not spend a moment typed in both.
    foreach ($clear in @($operations | Where-Object { $_.Kind -eq 'ValidationClear' })) {
        if (-not $gidOf.ContainsKey($clear.Sheet)) { continue }
        $request = New-SheetsValidationClearRequest -Tables @($knownTables[$clear.Sheet]) -Row $clear.Row
        if ($request) { $second += $request }

        # The cell rule the table clear above cannot see. Sent whether or not one is there, for
        # the reason the type clear is: the tabs that carry it cannot be named from here.
        if ($clear.PSObject.Properties.Name -contains 'ToRow' -and $null -ne $clear.ToRow) {
            $second += @{
                setDataValidation = @{
                    range = @{
                        sheetId       = [int]$gidOf[$clear.Sheet]
                        startRowIndex = [int]$clear.FromRow
                        endRowIndex   = [int]$clear.ToRow
                    }
                }
            }
        }
    }

    foreach ($validation in @($operations | Where-Object { $_.Kind -eq 'Validation' })) {
        if (-not $gidOf.ContainsKey($validation.Sheet)) { continue }
        $row = $(if ($validation.PSObject.Properties.Name -contains 'Row') { $validation.Row } else { $null })
        $second += (New-SheetsValidationRequest -Validation $validation `
                -Tables @($knownTables[$validation.Sheet]) -SheetId ([int]$gidOf[$validation.Sheet]) -Row $row)
    }

    # In the second batch rather than the structural one: a tab this run creates has no id
    # until Google answers the first batch, and freezing is a property of a sheet that has to
    # be named by id.
    foreach ($freeze in @($operations | Where-Object { $_.Kind -eq 'Freeze' })) {
        if (-not $gidOf.ContainsKey($freeze.Sheet)) { continue }
        $second += @{
            updateSheetProperties = @{
                properties = @{
                    sheetId        = [int]$gidOf[$freeze.Sheet]
                    gridProperties = @{ frozenRowCount = [int]$freeze.Rows }
                }
                fields     = 'gridProperties.frozenRowCount'
            }
        }
    }

    foreach ($wide in @($operations | Where-Object { $_.Kind -eq 'ColumnWidth' })) {
        if (-not $gidOf.ContainsKey($wide.Sheet)) { continue }
        $second += @{
            updateDimensionProperties = @{
                range      = @{
                    sheetId    = [int]$gidOf[$wide.Sheet]
                    dimension  = 'COLUMNS'
                    startIndex = [int]$wide.From - 1
                    endIndex   = [int]$wide.To
                }
                properties = @{ pixelSize = [int]$wide.Width }
                fields     = 'pixelSize'
            }
        }
    }

    foreach ($format in @($operations | Where-Object { $_.Kind -eq 'Format' })) {
        if (-not $gidOf.ContainsKey($format.Sheet)) { continue }
        $textFormat = @{}
        $fields = @()
        if ($format.PSObject.Properties.Name -contains 'Bold') {
            $textFormat['bold'] = [bool]$format.Bold
            $fields += 'userEnteredFormat.textFormat.bold'
        }
        if ($format.PSObject.Properties.Name -contains 'Colour' -and $format.Colour) {
            $textFormat['foregroundColorStyle'] = @{ rgbColor = (ConvertTo-SheetsColour -Hex $format.Colour) }
            $fields += 'userEnteredFormat.textFormat.foregroundColorStyle'
        }
        $cell = @{}
        if ($textFormat.Count -gt 0) { $cell['textFormat'] = $textFormat }
        if ($format.PSObject.Properties.Name -contains 'Align' -and $format.Align) {
            $cell['horizontalAlignment'] = [string]$format.Align
            $fields += 'userEnteredFormat.horizontalAlignment'
        }
        # Named explicitly, never blanket. A cell's wrap is the reviewer's everywhere except the
        # one row the runner writes the column names into, which is where this is asked for.
        if ($format.PSObject.Properties.Name -contains 'Wrap' -and $format.Wrap) {
            $cell['wrapStrategy'] = [string]$format.Wrap
            $fields += 'userEnteredFormat.wrapStrategy'
        }
        if ($fields.Count -eq 0) { continue }

        $range = @{
            sheetId          = [int]$gidOf[$format.Sheet]
            startRowIndex    = [int]$format.FromRow
            startColumnIndex = [int]$format.FromCol
            endColumnIndex   = [int]$format.ToCol
        }
        # No endRowIndex means to the bottom of the tab, which is what a column-wide rule
        # wants: the board grows and the alignment should not stop where this run's rows did.
        if ($format.PSObject.Properties.Name -contains 'ToRow' -and $null -ne $format.ToRow) {
            $range['endRowIndex'] = [int]$format.ToRow
        }
        $second += @{
            repeatCell = @{
                range  = $range
                cell   = @{ userEnteredFormat = $cell }
                # Only the properties named. A cell's wrap and fill are the reviewer's, and a
                # blanket userEnteredFormat would reset every one of them.
                fields = ($fields -join ',')
            }
        }
    }

    if ($second.Count -gt 0) {
        Invoke-SheetsApi -Method Post -Path "$SpreadsheetId`:batchUpdate" -Body @{ requests = $second } | Out-Null
    }

    $script:SheetsStage = 'clearing stale rows'
    $clears = @($operations | Where-Object { $_.Kind -eq 'Clear' })
    if ($clears.Count -gt 0) {
        $ranges = @($clears | ForEach-Object { "'" + ($_.Sheet -replace "'", "''") + "'!" + $_.Range })
        Invoke-SheetsApi -Method Post -Path "$SpreadsheetId/values:batchClear" -Body @{ ranges = $ranges } | Out-Null
    }

    $writes = @()
    foreach ($operation in @($operations | Where-Object { $_.Kind -eq 'Write' })) {
        $writes += Split-SheetsWriteChunks -Operation $operation
    }

    $raw = @()
    $entered = @()
    foreach ($write in $writes) {
        $rows = @()
        foreach ($row in @($write.Values)) {
            $rows += , @(@($row) | ForEach-Object { ConvertTo-SheetsCellValue -Value $_ })
        }
        $range = @{
            range  = "'" + ($write.Sheet -replace "'", "''") + "'!" + $write.Range
            values = $rows
        }

        # Raw is the default and is what almost everything wants. A finding is data: a name
        # beginning with a hyphen, or a value Sheets would read as a date, has to arrive as
        # what the database returned. Only the Comment mirror opts out, because a formula
        # sent as RAW arrives as the literal text of one.
        $isRaw = $true
        if ($write.PSObject.Properties.Name -contains 'Raw' -and $write.Raw -eq $false) { $isRaw = $false }

        # Only a formula carries a link, so only the USER_ENTERED side needs resolving. A
        # token whose tab does not exist would leave a literal in the cell, so it is dropped
        # rather than written: a broken link is worse than a missing one, because it reads as
        # something that ought to work.
        if (-not $isRaw) {
            # A plain loop, not ForEach-Object: a pipeline block runs in a child scope, so a
            # flag set inside one never reaches the variable being tested out here.
            $unresolved = $false
            $resolved = @()
            foreach ($row in $rows) {
                $cells = @()
                foreach ($cell in @($row)) {
                    $text = [string]$cell
                    foreach ($name in @($gidOf.Keys)) {
                        $text = $text.Replace(($SheetsGidToken -replace '%NAME%', $name), [string]$gidOf[$name])
                    }
                    if ($text -like '*{{GID:*') { $unresolved = $true }
                    $cells += $text
                }
                $resolved += , $cells
            }
            if ($unresolved) { continue }
            $range['values'] = $resolved
        }

        if ($isRaw) { $raw += $range } else { $entered += $range }
    }

    $script:SheetsStage = 'writing values'
    # RAW first. The whole-row write of a new Overview row leaves K empty and the mirror lands
    # on top of it, so the order of these two calls is what decides which value survives.
    if ($raw.Count -gt 0) {
        Invoke-SheetsApi -Method Post -Path "$SpreadsheetId/values:batchUpdate" -Body @{
            valueInputOption = 'RAW'
            data             = $raw
        } | Out-Null
    }
    if ($entered.Count -gt 0) {
        Invoke-SheetsApi -Method Post -Path "$SpreadsheetId/values:batchUpdate" -Body @{
            valueInputOption = 'USER_ENTERED'
            data             = $entered
        } | Out-Null
    }

    $script:SheetsStage = 'colouring the trend'
    # After the values, because the plain string goes in with the row and this replaces it.
    # updateCells rather than a value write: a cell's runs are structure, not content, and the
    # values endpoint has no way to carry them.
    $richOps = @($operations | Where-Object { $_.Kind -eq 'RichText' -and $gidOf.ContainsKey($_.Sheet) })
    if ($richOps.Count -gt 0) {
        $richRequests = @()
        foreach ($rich in $richOps) {
            $richRequests += @{
                updateCells = @{
                    range  = @{
                        sheetId          = [int]$gidOf[$rich.Sheet]
                        startRowIndex    = [int]$rich.Row - 1
                        endRowIndex      = [int]$rich.Row
                        startColumnIndex = [int]$rich.Column - 1
                        endColumnIndex   = [int]$rich.Column
                    }
                    rows   = @(@{
                            values = @(@{
                                    userEnteredValue = @{ stringValue = [string]$rich.Text }
                                    textFormatRuns   = @(@($rich.Runs) | ForEach-Object {
                                            $format = @{ bold = [bool]$_.Bold }
                                            if ($_.Colour) {
                                                $format['foregroundColorStyle'] = @{
                                                    rgbColor = (ConvertTo-SheetsColour -Hex $_.Colour)
                                                }
                                            }
                                            # startIndex is omitted at zero, which is what the
                                            # API expects for a run beginning at the first
                                            # character; sending 0 explicitly is rejected.
                                            $run = @{ format = $format }
                                            if ([int]$_.Start -gt 0) { $run['startIndex'] = [int]$_.Start }
                                            $run
                                        })
                                })
                        })
                    # The value and its runs, and nothing else. The cell's alignment and fill
                    # were settled earlier and are not this write's business.
                    fields = 'userEnteredValue,textFormatRuns'
                }
            }
        }
        foreach ($chunk in @(0..[math]::Floor(($richRequests.Count - 1) / 200))) {
            $slice = @($richRequests | Select-Object -Skip ($chunk * 200) -First 200)
            if ($slice.Count -gt 0) {
                Invoke-SheetsApi -Method Post -Path "$SpreadsheetId`:batchUpdate" -Body @{ requests = $slice } | Out-Null
            }
        }
    }

    $script:SheetsStage = 'sorting the board'
    # After the values, never before them: sorting rows the run has not written yet orders
    # last week's board and then overwrites it in this week's order.
    $sortRequests = @()
    foreach ($sort in @($operations | Where-Object { $_.Kind -eq 'Sort' })) {
        if (-not $gidOf.ContainsKey($sort.Sheet)) { continue }
        $sortRequests += @{
            sortRange = @{
                range     = @{
                    sheetId          = [int]$gidOf[$sort.Sheet]
                    startRowIndex    = [int]$sort.FromRow
                    endRowIndex      = [int]$sort.ToRow
                    startColumnIndex = [int]$sort.FromCol
                    endColumnIndex   = [int]$sort.ToCol
                }
                sortSpecs = @(@($sort.By) | ForEach-Object {
                        @{ dimensionIndex = [int]$_; sortOrder = 'ASCENDING' }
                    })
            }
        }
    }
    if ($sortRequests.Count -gt 0) {
        Invoke-SheetsApi -Method Post -Path "$SpreadsheetId`:batchUpdate" -Body @{ requests = $sortRequests } | Out-Null
    }

    $script:SheetsStage = 'declaring the result tables'
    # Tables last: the tab has to exist and its rows have to be in place before a range is
    # declared over them. A tab that already carries one is updated rather than given a
    # second - the range is the part that goes stale, not the table.
    $tableOps = @($operations | Where-Object { $_.Kind -eq 'Table' })
    $tableRequests = @()
    $known = $knownTables

    $claimed = @{}
    foreach ($table in $tableOps) {
        if (-not $gidOf.ContainsKey($table.Sheet)) { continue }
        $range = @{
            sheetId          = [int]$gidOf[$table.Sheet]
            startRowIndex    = [int]$table.FromRow
            endRowIndex      = [int]$table.ToRow
            startColumnIndex = [int]$table.FromCol
            endColumnIndex   = [int]$table.ToCol
        }

        # Which of the tab's existing tables this one is. By name first, because that is the
        # identity a table keeps across runs. By overlap second, because the first run after
        # this feature finds a block that was already a table under another name - one Sheets
        # named for itself, or one somebody made by hand - and two tables may not cover the
        # same cells. Claimed, so two planned tables cannot both adopt the same existing one.
        $match = $null
        foreach ($candidate in @($known[$table.Sheet])) {
            if (-not $candidate) { continue }
            if ($claimed.ContainsKey([string]$candidate.Id)) { continue }
            $overlaps = ([int]$candidate.FromRow -lt [int]$table.ToRow -and
                [int]$candidate.ToRow -gt [int]$table.FromRow)
            if (([string]$candidate.Name -eq [string]$table.Name) -or $overlaps) {
                $match = $candidate
                break
            }
        }

        $body = @{ name = [string]$table.Name; range = $range }
        $fields = 'range,name'
        if ($table.PSObject.Properties.Name -contains 'HeaderColour' -and $table.HeaderColour) {
            $body['rowsProperties'] = @{
                headerColorStyle = @{ rgbColor = (ConvertTo-SheetsColour -Hex $table.HeaderColour) }
            }
            $fields += ',rowsProperties.headerColorStyle'
        }

        if ($match) {
            $claimed[[string]$match.Id] = $true
            $body['tableId'] = [string]$match.Id
            $tableRequests += @{ updateTable = @{ table = $body; fields = $fields } }
        }
        else {
            $tableRequests += @{ addTable = @{ table = $body } }
        }
    }

    # In chunks, and every chunk is attempted even after one has failed. The board is worth more
    # with the tables that can be declared than with none of them, and what could not be
    # declared has to be named rather than inferred: Google answers a refused table with 500 and
    # no detail, so the names in this chunk are the only description of the failure anybody gets.
    $tablesApplied = 0
    $tableFailures = @()
    for ($start = 0; $start -lt $tableRequests.Count; $start += $SheetsTableChunk) {
        $end = [math]::Min($start + $SheetsTableChunk, $tableRequests.Count) - 1
        $chunk = @($tableRequests[$start..$end])
        try {
            Invoke-SheetsApi -Method Post -Path "$SpreadsheetId`:batchUpdate" -Body @{ requests = $chunk } | Out-Null
            $tablesApplied += $chunk.Count
        }
        catch {
            $names = @($chunk | ForEach-Object {
                    $t = $(if ($_.addTable) { $_.addTable.table } else { $_.updateTable.table })
                    [string]$t.name
                })
            $tableFailures += ("tables {0}-{1} of {2} were refused ({3}): {4}" -f
                ($start + 1), ($end + 1), $tableRequests.Count,
                ($_.Exception.Message -replace '\s+', ' '), ($names -join ', '))
        }
    }

    if ($tableFailures.Count -gt 0) {
        throw ("{0} of {1} table declaration(s) applied. " -f $tablesApplied, $tableRequests.Count) +
        ($tableFailures -join ' | ')
    }

    return [pscustomobject]@{
        Added   = $adds.Count
        Cleared = $clears.Count
        Written = $writes.Count
        Tables  = $tablesApplied
    }
}

function New-SheetsTrendRichText {
    <#
        The Trends cell as rich text: the counts coloured by which way they moved, the
        timestamps between them left alone.

        A cell holds one string, so the colouring has to be textFormatRuns - a list of offsets
        into that string, each one applying until the next begins. Which means every coloured
        number needs a plain run immediately after it, or the colour bleeds through the date
        and into the arrow.

        Returns nothing when there is one point or none: a series of one is not a trend, and
        colouring it would assert a direction nobody measured.
    #>
    param([string]$Sheet, [int]$Row, [int]$Column, [string]$Text, $Runs)

    if ([string]::IsNullOrEmpty($Text) -or @($Runs).Count -lt 2) { return $null }

    $formatted = @()
    foreach ($run in @($Runs)) {
        $colour = $(if ($SheetsTrendColours.ContainsKey([string]$run.Direction)) {
                $SheetsTrendColours[[string]$run.Direction]
            }
            else { $SheetsTrendColours['level'] })
        $formatted += [pscustomobject]@{ Start = [int]$run.Start; Bold = $true; Colour = $colour }
        $formatted += [pscustomobject]@{ Start = ([int]$run.Start + [int]$run.Length); Bold = $false; Colour = $null }
    }

    return [pscustomobject]@{
        Kind   = 'RichText'
        Sheet  = $Sheet
        Row    = $Row
        Column = $Column
        Text   = $Text
        Runs   = @($formatted | Sort-Object -Property Start)
    }
}

function Get-SheetsRuleDeletions {
    <#
        Every conditional-rule deletion a run makes, in the order they have to be sent.

        Highest index first, because each deletion renumbers the rules after it. Gathered
        across all the operations rather than done a column at a time, because that is the same
        rule one level up: two columns each deleting by indexes read off the same original list
        will have the second delete whatever the first has already shifted into those
        positions. That cost a board its entire Rows colouring and left three stale Status
        rules behind, and computing both index lists in a single pass - which the planner
        already does - is not enough on its own to prevent it.

        Separated for the reason Test-SheetsTitleIsOurs is: the ordering is worth pinning and a
        login is not.
    #>
    param($RuleOps, $GidOf)

    $drops = @()
    foreach ($rules in @($RuleOps)) {
        foreach ($index in @($rules.Drop)) {
            $drops += [pscustomobject]@{ SheetId = [int]$GidOf[$rules.Sheet]; Index = [int]$index }
        }
    }
    return @(@($drops | Sort-Object -Property Index -Descending) | ForEach-Object {
            @{ deleteConditionalFormatRule = @{ sheetId = $_.SheetId; index = $_.Index } }
        })
}

function New-SheetsValidationClearRequest {
    # Take the column type off every column of one table, or return nothing if none carries one.
    #
    # This exists to undo a defect rather than to express an intention: for one round of runs
    # the dropdown was matched to a table by column alone, and a check tab's identity block
    # spans the same columns as its result, so it landed there on whichever tab the API listed
    # the identity first. A reviewer's three words were offered over Prev findings and over
    # Category.
    #
    # A column entry sent without columnType clears it, and the list is resent whole for the
    # reason the dropdown's is: a partial list replaces rather than merges, so anything left out
    # loses the name Sheets holds for it.
    param($Tables, $Row)

    $board = $null
    foreach ($candidate in @($Tables)) {
        if (-not $candidate) { continue }
        if ($null -ne $Row -and
            ([int]$candidate.FromRow -gt [int]$Row -or [int]$candidate.ToRow -le [int]$Row)) { continue }
        $board = $candidate
        break
    }
    if (-not $board) { return $null }

    $typed = @(@($board.Columns) | Where-Object { $_ -and $_.columnType })
    if ($typed.Count -eq 0) { return $null }

    $columns = @(@($board.Columns) | Where-Object { $_ } | ForEach-Object {
            @{ columnIndex = [int]$_.columnIndex; columnName = [string]$_.columnName }
        })
    return @{
        updateTable = @{
            table  = @{ tableId = [string]$board.Id; columnProperties = $columns }
            fields = 'columnProperties'
        }
    }
}

function New-SheetsValidationRequest {
    <#
        The one request that puts a dropdown on a column, and which of the two forms it takes.

        A column inside a table may carry a type of its own, and Sheets then refuses
        setDataValidation on it outright - "This operation is not allowed on cells in typed
        columns", because the dropdown belongs to the table rather than to the cells. Two
        boards were already in that state, put there by hand, and the rejection took the whole
        batch down with it: no colours, no values written, and the SQL tab left exactly as the
        run before had broken it.

        So a table covering the column is asked first, and only a column outside one is given
        validation directly. Separated from the transport for the reason Test-SheetsTitleIsOurs
        is: the decision is worth testing and a login is not.

        The table's column list is resent whole. A partial one replaces it, so sending only the
        column being changed would drop the names Sheets holds for all the others - which is
        why Read-SheetState carries every column rather than the one in question.

        The table is chosen by row as well as by column. A check tab carries two - the identity
        block on rows 1 to 3 and the result below it - and both span the same column indices, so
        matching on columns alone picked whichever the API happened to list first. That put the
        Review Status dropdown on 'Category' and on 'Prev findings' in the identity block, on a
        board where the same code had put it in the right place: the order Google returns tables
        in is not part of the contract, so the same run produced different results per tab.
    #>
    param($Validation, $Tables, [int]$SheetId, $Row = $null)

    $index = [int]$Validation.Column - 1
    $condition = @{
        type   = 'ONE_OF_LIST'
        values = @(@($Validation.Values) | ForEach-Object { @{ userEnteredValue = [string]$_ } })
    }

    $board = $null
    foreach ($candidate in @($Tables)) {
        if (-not $candidate) { continue }
        if ([int]$candidate.FromCol -gt $index -or [int]$candidate.ToCol -le $index) { continue }
        if ($null -ne $Row -and
            ([int]$candidate.FromRow -gt [int]$Row -or [int]$candidate.ToRow -le [int]$Row)) { continue }
        $board = $candidate
        break
    }

    if (-not $board) {
        # From the row under the header the planner named, not from row 2. A check tab's tables
        # are declared after this batch is sent, so the first run that creates a tab finds none
        # and lands here - and a range starting at row 2 runs up the column through the identity
        # block above the result. On a check whose result is seven columns wide that is column H
        # in both, so Findings and the cell under it were offered a reviewer's three words. The
        # table-typed branch cannot do this; only the fallback ever reaches those rows.
        # Unbounded below still, so the dropdown is there for rows a later run appends.
        return @{
            setDataValidation = @{
                range = @{
                    sheetId          = $SheetId
                    startRowIndex    = $(if ($null -ne $Row) { [int]$Row + 1 } else { 1 })
                    startColumnIndex = $index
                    endColumnIndex   = [int]$Validation.Column
                }
                rule  = @{
                    condition    = $condition
                    showCustomUi = $true
                    strict       = $true
                }
            }
        }
    }

    $columns = @()
    $replaced = $false
    foreach ($column in @($board.Columns)) {
        if (-not $column) { continue }
        if ([int]$column.columnIndex -eq $index) {
            $columns += @{
                columnIndex        = $index
                columnName         = [string]$column.columnName
                columnType         = 'DROPDOWN'
                dataValidationRule = @{ condition = $condition }
            }
            $replaced = $true
        }
        else { $columns += $column }
    }
    if (-not $replaced) {
        $columns += @{
            columnIndex        = $index
            columnName         = [string]$Validation.Name
            columnType         = 'DROPDOWN'
            dataValidationRule = @{ condition = $condition }
        }
    }

    return @{
        updateTable = @{
            table  = @{ tableId = [string]$board.Id; columnProperties = $columns }
            fields = 'columnProperties'
        }
    }
}

function Test-SheetsTitleIsOurs {
    # Whether the document's current title is one the runner may replace. Separated from the
    # call that replaces it so the decision can be tested without a login, which is the same
    # split the merge and the transport are on.
    #
    # Google's placeholder counts, and so does any name this runner has given a document: a
    # name we produced ourselves is nobody's decision, which is why changing the naming pattern
    # does not strand the documents named under the old one. Everything else is somebody's.
    param([string]$CurrentTitle, [string]$Title)

    if ([string]::IsNullOrWhiteSpace($Title)) { return $false }
    if ($CurrentTitle -eq $Title) { return $false }
    if ([string]::IsNullOrWhiteSpace($CurrentTitle) -or $CurrentTitle -eq $SheetsUntitled) { return $true }

    foreach ($pattern in $SheetsFormerTitles) {
        if ($CurrentTitle -like $pattern) { return $true }
    }
    return $false
}

function Set-SheetTitleIfUnnamed {
    # Named while Google's own placeholder is still there, or while the title is one this
    # runner gave it, and never over a title somebody chose. A colleague who renames the
    # document has decided something, and putting the runner's name back every week is the
    # same defect as overwriting a comment.
    param([string]$SpreadsheetId, [string]$CurrentTitle, [string]$Title)

    if (-not (Test-SheetsTitleIsOurs -CurrentTitle $CurrentTitle -Title $Title)) { return $false }

    Invoke-SheetsApi -Method Post -Path "$SpreadsheetId`:batchUpdate" -Body @{
        requests = @(@{
                updateSpreadsheetProperties = @{
                    properties = @{ title = $Title }
                    fields     = 'title'
                }
            })
    } | Out-Null
    return $true
}
