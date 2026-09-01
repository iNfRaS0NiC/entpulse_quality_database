# Reopened notifications.
#
# One thing happens on a board that nobody is watching for: a check a reviewer closed comes
# back with findings. The board says so - the Status cell turns red and reads `Reopened` - but
# a board is a place people go, and the whole point of the word is that the check has stopped
# being somewhere they were going to look. This file turns that transition into a message.
#
# It sends nothing by itself and holds no credentials. Everything here is a pure function over
# what a run already produced, which is what makes it testable without a login, and it is the
# reason the queue is a file rather than a call: a mail that fails is retried on its own, and
# a DQ run is never failed, re-run or altered because a message could not be delivered.
#
# The event source is `New-SheetsMergePlan` in Sheets.ps1, which returns `StatusRenames`. That
# list carries more than reopens - the close-on-clean transitions and the legacy status
# renames are in it too - so it is filtered by `To`, never consumed whole. See
# $SheetsReopenedStatus for why the word exists and $SheetsExpectationReopenable for the one
# expectation under which it may be written: a check expecting `Non-zero`, `Residual` or
# nothing never reopens and therefore never mails. That is correct, and it will be reported as
# a fault by somebody unless it is written down, so it is written down here as well.

# Where the queue lives, and why it is not in git.
#
# The queue is a record of what has been said to whom, which is machine state on the machine
# that says it - not evidence, not a finding, and not something a second clone of this
# repository should replay. It sits beside the credentials for that reason and is ignored by
# the same kind of rule. A run that cannot read it starts from empty and says so: losing the
# record costs a duplicate message, and stopping a board update over one would cost the run.
$NotifyQueueFileName = 'notifications.local.json'
$NotifyQueueVersion = 1

# The three words a queued message can be in. `QUEUED` is waiting, `SENT` is delivered, and
# `FAILED` is a message that has run out of attempts and will not be tried again without
# somebody looking. A message is never deleted on delivery: the record of having said a thing
# is the only defence against saying it twice, and it is small.
$NotifyStatusQueued = 'QUEUED'
$NotifyStatusSent = 'SENT'
$NotifyStatusFailed = 'FAILED'
$NotifyMaxAttempts = 5

function ConvertTo-NotifyList {
    <#
        A list with the nothings taken out, whatever shape "nothing" arrived in.

        PowerShell has two of them and they do not behave alike. A function that returns @()
        hands back AutomationNull, which an @() around it treats as empty - but bind that same
        value to a parameter and it becomes a plain $null, and @($null) is an array of one
        element that happens to be nothing. Every call here that reads a collection out of a
        parameter goes through this, because the version that does not is the one that wrote a
        literal `null` into the queue file on 2026-08-31 and then composed a message about it:
        an empty line where a check's name goes, and "was blank with no recorded count".

        **Callers still wrap the result in @().** A function returning a one-element array
        hands back the element, so a count taken straight off this would be a count taken off
        a PSCustomObject - which is how the same afternoon produced a subject line reading
        " checks on the Soccer board" with the number missing. The wrap is not decoration.
    #>
    param($Value)

    if ($null -eq $Value) { return @() }
    return @(@($Value) | Where-Object { $null -ne $_ })
}

function Get-NotifyQueuePath {
    # Beside this script, so it follows the tools rather than the working directory. A run
    # started from anywhere writes and reads the same file.
    param([string]$Root = $PSScriptRoot)
    if ([string]::IsNullOrWhiteSpace($Root)) { $Root = '.' }
    return (Join-Path $Root $NotifyQueueFileName)
}

function Read-NotifyQueue {
    <#
        Everything the queue holds, oldest first, or an empty array.

        A missing file is the normal first run and is not a fault. A file that will not parse
        is: it is reported and treated as empty rather than thrown, because the alternative is
        a corrupted local file ending a board update that has already been applied. The cost of
        being wrong here is one duplicate message.
    #>
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) { $Path = Get-NotifyQueuePath }
    if (-not (Test-Path -LiteralPath $Path)) { return @() }

    try {
        $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
        if ([string]::IsNullOrWhiteSpace($raw)) { return @() }
        $parsed = $raw | ConvertFrom-Json
    }
    catch {
        Write-Host ("  the notification queue at {0} could not be read and is being treated as empty: {1}" -f `
                $Path, $_.Exception.Message) -ForegroundColor Yellow
        return @()
    }

    # Through the same filter as everything else, so a file written by the version that had
    # this defect - one that holds a literal `null` beside real messages - comes back clean and
    # is rewritten clean by the next save, rather than composing a message about nothing.
    if ($null -eq $parsed) { return @() }
    if ($parsed.PSObject.Properties.Name -contains 'notifications') {
        return (ConvertTo-NotifyList -Value $parsed.notifications)
    }
    return (ConvertTo-NotifyList -Value $parsed)
}

function Save-NotifyQueue {
    # Written whole, in the shape Read-NotifyQueue expects, with the version that says what
    # shape that is. Depth is generous because a notification is flat but its list is not.
    param($Queue, [string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) { $Path = Get-NotifyQueuePath }
    $document = [pscustomobject]@{
        queueVersion  = $NotifyQueueVersion
        notifications = @(ConvertTo-NotifyList -Value $Queue)
    }
    $json = $document | ConvertTo-Json -Depth 8
    Set-Content -LiteralPath $Path -Value $json -Encoding UTF8
    return $Path
}

function ConvertTo-NotifyStamp {
    # The compact stamp that identifies a run inside a notification id. Taken from the run's
    # own start rather than from now, so the same run producing the same transition twice - a
    # board update repeated after a transport failure - produces the same id and not a second
    # message.
    param($When)

    $moment = $null
    if ($When -is [datetime]) { $moment = $When }
    elseif (-not [string]::IsNullOrWhiteSpace([string]$When)) {
        $parsed = [datetime]::MinValue
        $styles = [Globalization.DateTimeStyles]::AssumeUniversal -bor `
            [Globalization.DateTimeStyles]::AdjustToUniversal
        if ([datetime]::TryParse([string]$When, [Globalization.CultureInfo]::InvariantCulture,
                $styles, [ref]$parsed)) {
            $moment = $parsed
        }
    }
    if ($null -eq $moment) { $moment = (Get-Date).ToUniversalTime() }
    return $moment.ToString('yyyyMMdd-HHmmss', [Globalization.CultureInfo]::InvariantCulture)
}

function New-ReopenNotification {
    <#
        One event per check this run moved to `Reopened`, in the order the plan named them.

        Filtered by `To` rather than by anything about the entry, because StatusRenames is the
        list of every status the run wrote and the other kinds say nothing anybody needs a mail
        about: a check closing on its own is good news arriving on a board somebody will read
        anyway, and a legacy spelling being brought up to date is not news at all.

        The numbers come with the transition. They are the open counts the reopen rule fired
        on - the reviewers' dismissed rows already subtracted - so the message and the board it
        points at agree. See the comment beside $SheetsReopenedStatus in Sheets.ps1.
    #>
    param(
        $Renames,
        [string]$RunId,
        $StartedUtc,
        [string]$Sport,
        [string]$SheetId,
        [string]$ReopenedWord = 'Reopened',
        $GidOf
    )

    $stamp = ConvertTo-NotifyStamp -When $StartedUtc

    # Tab title to tab id. Only Invoke-SheetsPlan knows the ids, because a tab created on this
    # run has none until Google answers, so the map arrives from there rather than being looked
    # up here. A check whose tab is not in it still gets a message; it links to the board.
    #
    # Named $tabIds and not $gidOf, which is what it was called for an hour on 2026-08-31.
    # PowerShell variable names do not distinguish case, so a local $gidOf **is** the $GidOf
    # parameter: the first line emptied the map it was about to read, and every link in every
    # message quietly fell back to the board. Nothing failed and nothing said anything.
    $tabIds = @{}
    if ($null -ne $GidOf) {
        foreach ($key in @($GidOf.Keys)) { $tabIds[[string]$key] = $GidOf[$key] }
    }
    $events = @()

    foreach ($change in @(ConvertTo-NotifyList -Value $Renames)) {
        if ([string]$change.To -ne $ReopenedWord) { continue }

        $where = [string]$change.Sport
        if ([string]::IsNullOrWhiteSpace($where)) { $where = $Sport }

        $events += [pscustomobject]@{
            notificationId   = ('{0}:{1}:{2}' -f $stamp, [string]$change.CheckId, [string]$change.To)
            checkId          = [string]$change.CheckId
            sport            = $where
            name             = [string]$change.Name
            what             = [string]$change.What
            previousStatus   = [string]$change.From
            newStatus        = [string]$change.To
            previousFindings = $change.PreviousFindings
            currentFindings  = $change.CurrentFindings
            verdict          = [string]$change.Verdict
            runId            = $RunId
            sheetId          = $SheetId
            tabGid           = $(if ($tabIds.ContainsKey([string]$change.TabTitle)) {
                    $tabIds[[string]$change.TabTitle]
                } else { $null })
            # The board's own front page, so a reader who wants the sport rather than the one
            # check has somewhere to land. The live document names this tab literally
            # 'Overview' - New-SheetsMergePlan writes to it by that name - so it is looked up
            # by that name and not by anything cleverer.
            overviewGid      = $(if ($tabIds.ContainsKey('Overview')) { $tabIds['Overview'] } else { $null })
            queuedUtc        = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
            status           = $NotifyStatusQueued
            attempts         = 0
        }
    }
    return @($events)
}

function Add-NotifyEvent {
    <#
        The queue with these events added, and a count of how many were new.

        The notification id is what makes one transition one message. A board update that is
        run twice against the same results - which happens, because a transport failure is
        retried and the second attempt writes the same Status cell - produces the same ids, and
        the second time round they are already here. Nothing is compared but the id: a message
        already sent is not re-examined, because the only question being asked is whether this
        has been said.
    #>
    param($Queue, $Events)

    $existing = @{}
    foreach ($item in @(ConvertTo-NotifyList -Value $Queue)) {
        $id = [string]$item.notificationId
        if (-not [string]::IsNullOrWhiteSpace($id)) { $existing[$id] = $true }
    }

    $kept = @(ConvertTo-NotifyList -Value $Queue)
    $added = 0
    foreach ($item in @(ConvertTo-NotifyList -Value $Events)) {
        $id = [string]$item.notificationId
        if ([string]::IsNullOrWhiteSpace($id)) { continue }
        if ($existing.ContainsKey($id)) { continue }
        $existing[$id] = $true
        $kept += $item
        $added += 1
    }

    return [pscustomobject]@{ Queue = @($kept); Added = $added }
}

function Get-NotifyTabLink {
    # A link to the check's own tab, or to the board when the tab cannot be named.
    #
    # A tab id is a number Google assigns, and a link without it opens whichever tab the
    # document happens to be on - which for a fifty-tab sport is the wrong one. So a missing
    # id degrades to the board rather than pretending: the reader still lands somewhere useful
    # and does not follow a link that claims to know where it is going.
    param([string]$SheetId, $Gid)

    if ([string]::IsNullOrWhiteSpace($SheetId)) { return '' }
    $link = 'https://docs.google.com/spreadsheets/d/{0}/edit' -f $SheetId
    $number = 0
    if ($null -ne $Gid -and [int]::TryParse([string]$Gid, [ref]$number)) {
        $link += '#gid={0}' -f $number
    }
    return $link
}

function ConvertTo-NotifyHtmlText {
    # Text going into HTML. A check name is ASCII and a sport name is ASCII, but What is a
    # sentence somebody wrote and an ampersand in it would end the message halfway.
    param([string]$Text)

    return ([string]$Text).Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;').Replace('"', '&quot;')
}

# The company's own palette, read off enetpulse.com on 2026-08-31.
#
# --bs-primary is #CA1744 and the theme carries #a21236 as its pressed variant, #0f0f0f as
# body text, #646464 as secondary and #f8f8f8 as the light ground. Taken whole rather than
# borrowing the red alone: a brand colour dropped into somebody else's greys looks like a
# mistake, and these five were chosen to sit together.
#
# The status word does NOT use them - see Get-NotifyStatusColour. The chrome of the message
# belongs to the company; the word `Reopened` belongs to the board, and a reader who follows
# this message should meet the same chip they just saw in it.
$NotifyBrandRed = '#CA1744'
$NotifyBrandRedDark = '#a21236'
$NotifyBrandInk = '#0f0f0f'
$NotifyBrandGrey = '#646464'
$NotifyBrandLight = '#f8f8f8'
$NotifyBrandRule = '#dee2e6'
$NotifyBrandTint = '#fdeaef'

function Get-NotifyStamp {
    <#
        When this message was composed, in Central European time and labelled with the zone
        actually in force.

        Not UTC, because nobody reading it works in UTC and a reader who has to add two hours
        before knowing whether a report is fresh is a reader who stops checking. Not the
        sending machine's local time either: the scheduled task may one day run somewhere else,
        and a timestamp whose meaning depends on which machine sent it is worse than no
        timestamp.

        The label follows the date. Central Europe is CET for part of the year and CEST for the
        rest, and writing one of them all year round is wrong for half of it - by exactly the
        hour somebody would be trying to reconcile.

        Falls back to the machine's own offset where the zone is not installed, which is what a
        non-Windows host would hit.
    #>
    param([datetime]$MomentUtc = (Get-Date).ToUniversalTime())

    $format = 'yyyy-MM-dd HH:mm:ss'
    $culture = [Globalization.CultureInfo]::InvariantCulture

    $zone = $null
    foreach ($id in @('Central European Standard Time', 'Europe/Berlin')) {
        try { $zone = [TimeZoneInfo]::FindSystemTimeZoneById($id); break } catch { $zone = $null }
    }

    if ($null -eq $zone) {
        $local = $MomentUtc.ToLocalTime()
        $offset = [TimeZoneInfo]::Local.GetUtcOffset($local)
        return ('{0} UTC{1}{2:00}:{3:00}' -f $local.ToString($format, $culture),
            $(if ($offset.Ticks -lt 0) { '-' } else { '+' }),
            [math]::Abs($offset.Hours), [math]::Abs($offset.Minutes))
    }

    $moment = [TimeZoneInfo]::ConvertTimeFromUtc([datetime]::SpecifyKind($MomentUtc, [DateTimeKind]::Utc), $zone)
    $label = $(if ($zone.IsDaylightSavingTime($moment)) { 'CEST' } else { 'CET' })
    return ('{0} {1}' -f $moment.ToString($format, $culture), $label)
}

function Get-NotifyStatusColour {
    <#
        The colours the board gives the word this message is about.

        Read from $SheetsStatusBands rather than copied, so the mail and the chip cannot drift
        apart. A reviewer opening the board from this message should meet the same red they
        just saw in it; two reds that were once the same and are now nearly the same is worse
        than either, because it reads as two different things.

        Falls back to the values that band holds today, so Notify.ps1 dot-sourced on its own -
        which is how half the tests take it - still has colours.
    #>
    param([string]$Status = 'Reopened')

    $background = '#FAD2CF'
    $foreground = '#B31412'

    $bands = $null
    try { $bands = Get-Variable -Name 'SheetsStatusBands' -ValueOnly -ErrorAction Stop } catch { $bands = $null }
    foreach ($band in @($bands)) {
        if ($null -eq $band) { continue }
        if ([string]$band.Value -ne $Status) { continue }
        if (-not [string]::IsNullOrWhiteSpace([string]$band.Background)) { $background = [string]$band.Background }
        if (-not [string]::IsNullOrWhiteSpace([string]$band.Colour)) { $foreground = [string]$band.Colour }
        break
    }

    return [pscustomobject]@{ Background = $background; Foreground = $foreground }
}

function Format-ReopenDigest {
    <#
        Subject, and both bodies, for one message covering these events.

        A list rather than a paragraph each. The first version wrote four lines of prose per
        check, which reads well for one and badly for twenty - and twenty is the case this
        exists for. What a reader wants at the moment the message arrives is which sport, which
        check, what it asserts and how big it is; the reasoning belongs on the board.

        Grouped by board rather than repeating the sport down a column. One message can cover
        four sports, and a Sport cell repeated eleven times is eleven readings of a word the
        reader already has. The sport becomes a heading instead, and the heading is the link to
        that board's Overview - which leaves the rows carrying only what differs between them.

        Two bodies. HTML is what nearly everyone sees and is where the links can sit on words
        rather than sprawl as ninety characters of URL. The text alternative is not decoration:
        it is what a client refusing HTML shows, what a preview line quotes, and what a search
        over somebody's mail matches. Both say the same things in the same order.
    #>
    param($Events)

    $items = @(ConvertTo-NotifyList -Value $Events)
    if ($items.Count -eq 0) { return $null }

    # Board by board, in the order the boards first appear, and the checks inside a board in
    # the order the run named them. Nothing is sorted: a run reports its checks in CheckID
    # order already, and re-sorting here would make two messages about the same board disagree
    # about where a row is.
    $boards = @()
    $index = @{}
    foreach ($item in $items) {
        $sport = [string]$item.sport
        if (-not $index.ContainsKey($sport)) {
            $index[$sport] = $boards.Count
            $boards += [pscustomobject]@{
                Sport    = $sport
                Overview = (Get-NotifyTabLink -SheetId ([string]$item.sheetId) -Gid $item.overviewGid)
                Items    = @()
            }
        }
        $boards[$index[$sport]].Items += $item
    }

    # The subject says what happened and how much of it, in that order. Written out rather than
    # abbreviated: this is the one thing the package sends to somebody who is not reading a
    # board, and "DQ" is a word only the people already inside this work use.
    #
    # The count is what follows, not a check name. One check's name would fit and four would
    # not, and a subject whose shape changes with the number is a subject a reader cannot scan
    # in a list of thirty. The name is the first thing in the body instead.
    $sportCount = $boards.Count
    $noun = $(if ($items.Count -eq 1) { 'check' } else { 'checks' })
    if ($sportCount -eq 1) {
        $subject = ('Data Quality Issues - Reopened: {0} {1} on {2}' -f $items.Count, $noun, $boards[0].Sport)
    }
    else {
        $subject = ('Data Quality Issues - Reopened: {0} {1} on {2} sports' -f $items.Count, $noun, $sportCount)
    }

    $opening = $(if ($items.Count -eq 1) {
            'check that a reviewer had closed has returned findings'
        }
        else {
            'checks that reviewers had closed have returned findings'
        })

    # ----- the text alternative
    #
    # The same things in the same order as the HTML, in the one shape plain text can hold. The
    # count is a word here rather than a badge, and the banner is a line rather than a block,
    # but nothing is said in one body that is not said in the other.
    $lines = @(
        'DATA QUALITY'
        'Reopened Checks'
        ('Generated: {0}' -f (Get-NotifyStamp))
        ''
        ('{0} {1}' -f $items.Count, $opening)
    )
    foreach ($board in $boards) {
        $lines += ''
        $lines += ('{0}  ({1} check{2})' -f $board.Sport, @($board.Items).Count,
            $(if (@($board.Items).Count -eq 1) { '' } else { 's' }))
        if (-not [string]::IsNullOrWhiteSpace($board.Overview)) { $lines += ('  {0}' -f $board.Overview) }

        $checkWidth = 5
        $nameWidth = 4
        foreach ($item in @($board.Items)) {
            $checkWidth = [math]::Max($checkWidth, ([string]$item.checkId).Length)
            $nameWidth = [math]::Max($nameWidth, ([string]$item.name).Length)
        }
        $format = '  {0,-' + $checkWidth + '}  {1,-' + $nameWidth + '}  {2,6}'
        $lines += ($format -f 'Check', 'Name', 'Rows')
        foreach ($item in @($board.Items)) {
            $lines += ($format -f [string]$item.checkId, [string]$item.name, [string]$item.currentFindings)
        }
    }
    $lines += ''
    $lines += 'Rows are open findings: rows already marked No Issue / Change are not in them.'

    # ----- the HTML body
    #
    # Inline styles only, and tables for structure. A mail client is not a browser: a <style>
    # block is stripped by several of them and flexbox is laid out by none, so a design that
    # needs either arrives as a stack of unstyled lines. Everything here degrades to something
    # readable when a rule is ignored.
    #
    # The gradient is written over a solid background-color rather than instead of one. Outlook
    # on the desktop renders with Word, which ignores CSS gradients entirely - given only the
    # gradient it paints nothing and the banner arrives as white text on white. The solid brand
    # red underneath is what it falls back to, and every other client paints over it.
    $band = Get-NotifyStatusColour -Status 'Reopened'
    $generated = Get-NotifyStamp

    $sections = @()
    foreach ($board in $boards) {
        # The sport is a band across the table rather than a heading above it, so the columns
        # stay one set for the whole message and a reader compares rows down the page instead
        # of re-reading a header per board.
        $heading = ConvertTo-NotifyHtmlText -Text $board.Sport
        if (-not [string]::IsNullOrWhiteSpace($board.Overview)) {
            $heading = '<a href="{0}" style="color:{1};text-decoration:none">{2} &rsaquo;</a>' -f `
                (ConvertTo-NotifyHtmlText -Text $board.Overview), $NotifyBrandRed, $heading
        }
        $sections += ('<tr><td colspan="4" style="background:{0};padding:9px 14px;' +
            'border-top:1px solid {1};border-bottom:1px solid {1};' +
            'font-size:13px;font-weight:700;letter-spacing:.4px;color:{2}">{3}' +
            '<span style="float:right;font-weight:400;font-size:12px;color:{4}">{5}</span>' +
            '</td></tr>') -f
            $NotifyBrandTint, $NotifyBrandRule, $NotifyBrandRed, $heading, $NotifyBrandGrey,
            ('{0} check{1}' -f @($board.Items).Count, $(if (@($board.Items).Count -eq 1) { '' } else { 's' }))

        $stripe = $false
        foreach ($item in @($board.Items)) {
            $stripe = -not $stripe
            $shade = $(if ($stripe) { '#ffffff' } else { $NotifyBrandLight })
            $link = Get-NotifyTabLink -SheetId ([string]$item.sheetId) -Gid $item.tabGid
            $open = $(if ([string]::IsNullOrWhiteSpace($link)) { '' }
                else {
                    ('<a href="{0}" style="display:inline-block;padding:3px 10px;border-radius:11px;' +
                     'background:#eceff1;color:{1};font-size:11px;font-weight:700;letter-spacing:.4px;' +
                     'text-decoration:none;white-space:nowrap">OPEN</a>') -f `
                        (ConvertTo-NotifyHtmlText -Text $link), $NotifyBrandInk
                })
            $what = $(if ([string]::IsNullOrWhiteSpace([string]$item.what)) { '' }
                else {
                    '<div style="color:{0};font-size:12px;line-height:16px;padding-top:3px">{1}</div>' -f `
                        $NotifyBrandGrey, (ConvertTo-NotifyHtmlText -Text ([string]$item.what))
                })

            $sections += ('<tr style="background:{0}">' +
                '<td style="padding:11px 14px;vertical-align:top;white-space:nowrap">' +
                '<span style="display:inline-block;padding:3px 10px;border-radius:11px;background:#eceff1;' +
                'color:{1};font-family:Consolas,Menlo,monospace;font-size:12px">{2}</span></td>' +
                '<td style="padding:11px 14px 11px 0;vertical-align:top">' +
                '<div style="font-weight:600;color:{1};font-size:13px">{3}</div>{4}</td>' +
                '<td style="padding:11px 14px 11px 0;vertical-align:top;text-align:right;white-space:nowrap">' +
                '<span style="display:inline-block;min-width:26px;padding:3px 10px;border-radius:11px;' +
                'background:{5};color:{6};font-size:13px;font-weight:700;text-align:center">{7}</span></td>' +
                '<td style="padding:11px 14px 11px 0;vertical-align:top;text-align:right;white-space:nowrap">{8}</td>' +
                '</tr>') -f
                $shade,
                $NotifyBrandInk,
                (ConvertTo-NotifyHtmlText -Text ([string]$item.checkId)),
                (ConvertTo-NotifyHtmlText -Text ([string]$item.name)),
                $what,
                $NotifyBrandTint,
                $NotifyBrandRed,
                (ConvertTo-NotifyHtmlText -Text ([string]$item.currentFindings)),
                $open
        }
    }

    $html = ('<div style="font-family:Poppins,-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,Helvetica,Arial,sans-serif;' +
        'font-size:14px;color:' + $NotifyBrandInk + ';max-width:820px">' +

        # the banner
        '<table cellspacing="0" cellpadding="0" border="0" width="100%" style="border-collapse:collapse">' +
        '<tr><td style="background-color:' + $NotifyBrandRed + ';' +
        'background-image:linear-gradient(120deg,' + $NotifyBrandRed + ' 0%,' + $NotifyBrandRedDark + ' 55%,#6f0b23 100%);' +
        'border-radius:10px;padding:22px 24px;color:#ffffff">' +
        '<div style="font-size:11px;font-weight:700;letter-spacing:1.6px;color:#f6c3ce">DATA QUALITY</div>' +
        '<div style="font-size:23px;font-weight:700;padding:6px 0 4px 0">Reopened Checks</div>' +
        '<div style="font-size:12px;color:#fbe4ea">Generated: {3}</div>' +
        '</td></tr></table>' +

        # the count, in the board's own colours for the word this is about
        '<table cellspacing="0" cellpadding="0" border="0" width="100%" ' +
        'style="border-collapse:collapse;margin:18px 0 0 0"><tr>' +
        '<td style="padding:0 10px 0 0;vertical-align:middle;white-space:nowrap">' +
        '<span style="display:inline-block;min-width:22px;padding:4px 11px;border-radius:12px;' +
        'background:{4};color:{5};font-size:14px;font-weight:700;text-align:center">{0}</span></td>' +
        '<td style="vertical-align:middle;font-size:16px;color:' + $NotifyBrandInk + '">{1}</td>' +
        '</tr></table>' +
        '<div style="border-bottom:1px solid ' + $NotifyBrandRule + ';margin:14px 0 0 0"></div>' +

        # the table
        '<table cellspacing="0" cellpadding="0" border="0" width="100%" ' +
        'style="border-collapse:collapse;margin:0 0 18px 0;font-size:13px">' +
        '<tr style="background:#f1f3f4;color:' + $NotifyBrandGrey + ';text-align:left">' +
        '<th style="padding:9px 14px;font-weight:700;font-size:11px;letter-spacing:.6px">CHECK</th>' +
        '<th style="padding:9px 14px 9px 0;font-weight:700;font-size:11px;letter-spacing:.6px">NAME</th>' +
        '<th style="padding:9px 14px 9px 0;font-weight:700;font-size:11px;letter-spacing:.6px;text-align:right">ROWS</th>' +
        '<th style="padding:9px 14px 9px 0"></th>' +
        '</tr>{2}</table>' +

        '<div style="color:' + $NotifyBrandGrey + ';font-size:12px;border-top:1px solid ' + $NotifyBrandRule + ';padding-top:12px">' +
        'Rows are open findings &mdash; rows already marked No Issue / Change are not counted.</div>' +
        '</div>') -f
        $items.Count,
        (ConvertTo-NotifyHtmlText -Text $opening),
        ($sections -join ''),
        $generated,
        $band.Background,
        $band.Foreground

    return [pscustomobject]@{
        Subject  = $subject
        Body     = ($lines -join "`n")
        BodyHtml = $html
    }
}

# ----- sending ----------------------------------------------------------------------------
#
# Everything above composes; everything below sends. The same split Sheets.ps1 makes, for the
# same reason: the wording and the queue are where the defects live and they have to be
# exercisable without a login.
#
# The transport is the Gmail API on the credentials the boards already use. A refresh grant
# does not carry a scope - the access token inherits whatever the refresh token was granted -
# so one authorisation serves both, and there is no second client, no second secret and no
# second thing to renew. What it costs is one re-consent: $SheetsScope asks for gmail.send as
# well, and a refresh token issued before that does not have it.
#
# The Gmail API must also be enabled in the same Google Cloud project as the Sheets API. That
# is a different thing from the scope and fails the same way, with a 403; they are told apart
# by the reason Google returns, and Get-NotifyApiError is what reads it.
#
# The mail goes out as the authorised account. That is a consequence of the choice rather than
# a decision inside it: a reader will see it from a person, not from an instrument.
$NotifyGmailSendUrl = 'https://gmail.googleapis.com/gmail/v1/users/me/messages/send'

function ConvertTo-NotifyBase64Url {
    # What the Gmail API takes: base64 with the URL alphabet and no padding.
    param([string]$Text)

    $bytes = [Text.Encoding]::UTF8.GetBytes($Text)
    return ([Convert]::ToBase64String($bytes)).Replace('+', '-').Replace('/', '_').TrimEnd('=')
}

function ConvertFrom-NotifyApiErrorBody {
    <#
        The message and the machine-readable reason out of a Google API error body.

        Split from the reading of the stream so it can be tested against a real response, which
        is the half that was wrong: the first version never looked at a body at all.
    #>
    param([string]$Text)

    $message = ''
    $reason = ''
    if (-not [string]::IsNullOrWhiteSpace($Text)) {
        try {
            $parsed = $Text | ConvertFrom-Json
            if ($parsed.error) {
                $message = [string]$parsed.error.message
                foreach ($item in @($parsed.error.errors)) {
                    if (-not [string]::IsNullOrWhiteSpace([string]$item.reason)) { $reason = [string]$item.reason; break }
                }
                if ([string]::IsNullOrWhiteSpace($reason)) {
                    foreach ($item in @($parsed.error.details)) {
                        if (-not [string]::IsNullOrWhiteSpace([string]$item.reason)) { $reason = [string]$item.reason; break }
                    }
                }
            }
        }
        catch { $message = ($Text -replace '\s+', ' ') }
    }

    return [pscustomobject]@{ Message = $message; Reason = $reason }
}

function Test-NotifyScopeProblem {
    <#
        Whether a failure is the one cause whose fix lives in this repository.

        A refresh token minted before gmail.send was added to $SheetsScope is a working token
        for everything else, so nothing else in the package will ever complain about it and the
        API's own message does not mention this repository. Every other cause is Google's to
        explain and ours to pass through unaltered.

        Narrow on purpose. On 2026-08-31 the first version treated any 403 as this, and the
        second live attempt was a 403 for an entirely different reason - the Gmail API was not
        enabled in the project. Advice invented from a status code would have sent somebody to
        re-run the consent and replace a working refresh token for nothing.
    #>
    param([string]$Reason, [string]$Message)

    if ($Reason -in @('ACCESS_TOKEN_SCOPE_INSUFFICIENT', 'insufficientPermissions')) { return $true }
    return ($Message -like '*insufficient authentication scopes*')
}

function Get-NotifyApiError {
    # What Google actually said, rather than what the status code lets us guess.
    # Invoke-RestMethod throws a WebException whose Message is only "The remote server returned
    # an error: (403) Forbidden"; the reason is in the body, and reading it is the difference
    # between a message somebody can act on and a message that sends them somewhere wrong.
    param($ErrorRecord)

    $text = ''
    try {
        $response = $ErrorRecord.Exception.Response
        if ($response) {
            $stream = $response.GetResponseStream()
            $reader = New-Object IO.StreamReader($stream)
            $text = $reader.ReadToEnd()
            $reader.Close()
        }
    }
    catch { $text = '' }

    $failure = ConvertFrom-NotifyApiErrorBody -Text $text
    if ([string]::IsNullOrWhiteSpace($failure.Message)) {
        return [pscustomobject]@{ Message = [string]$ErrorRecord.Exception.Message; Reason = '' }
    }
    return $failure
}

function ConvertTo-NotifyBase64Body {
    # One body part's bytes, base64 in the 76-character lines RFC 2045 asks for.
    param([string]$Text)

    $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Text))
    $wrapped = @()
    for ($at = 0; $at -lt $encoded.Length; $at += 76) {
        $wrapped += $encoded.Substring($at, [math]::Min(76, $encoded.Length - $at))
    }
    return ($wrapped -join "`r`n")
}

function New-NotifyMimeMessage {
    <#
        One RFC 2822 message: headers, and either one body or both.

        Every body is sent base64 under a declared UTF-8 charset rather than as bare text. A
        check name is ASCII and a sport name is ASCII, but What is a sentence somebody wrote,
        and a message that mangles one character is a message whose numbers a reader then has
        to doubt.

        With an HTML body it becomes multipart/alternative, text first. The order is the
        specification's and it is not cosmetic: a client shows the last part it can render, so
        text first and HTML second is what makes the HTML win where it is wanted and the text
        appear where it is not. The text alternative is not decoration - it is what a client
        refusing HTML shows, what a preview line quotes, and what a search over somebody's
        mail actually matches.
    #>
    param([string[]]$To, [string]$Subject, [string]$Body, [string]$From, [string]$BodyHtml)

    $headers = @()
    if (-not [string]::IsNullOrWhiteSpace($From)) { $headers += ('From: {0}' -f $From) }
    $headers += ('To: {0}' -f (@(ConvertTo-NotifyList -Value $To) -join ', '))
    $headers += ('Subject: {0}' -f $Subject)
    $headers += 'MIME-Version: 1.0'

    if ([string]::IsNullOrWhiteSpace($BodyHtml)) {
        $headers += 'Content-Type: text/plain; charset="UTF-8"'
        $headers += 'Content-Transfer-Encoding: base64'
        return (($headers -join "`r`n") + "`r`n`r`n" + (ConvertTo-NotifyBase64Body -Text $Body))
    }

    # Random rather than fixed. A boundary that appeared inside a body would end the part
    # early, and a body here carries whatever a reviewer typed into a spreadsheet.
    $boundary = 'dq-' + ([guid]::NewGuid().ToString('N'))
    $headers += ('Content-Type: multipart/alternative; boundary="{0}"' -f $boundary)

    $parts = @()
    $parts += ('--{0}' -f $boundary)
    $parts += 'Content-Type: text/plain; charset="UTF-8"'
    $parts += 'Content-Transfer-Encoding: base64'
    $parts += ''
    $parts += (ConvertTo-NotifyBase64Body -Text $Body)
    $parts += ('--{0}' -f $boundary)
    $parts += 'Content-Type: text/html; charset="UTF-8"'
    $parts += 'Content-Transfer-Encoding: base64'
    $parts += ''
    $parts += (ConvertTo-NotifyBase64Body -Text $BodyHtml)
    $parts += ('--{0}--' -f $boundary)

    return (($headers -join "`r`n") + "`r`n`r`n" + ($parts -join "`r`n"))
}

function Get-NotifyRecipients {
    <#
        Who gets told, or nothing.

        Nothing is the default, and it is the whole of the safety here. A board update is run
        by whoever is working on a sport, and a feature that starts mailing a list the moment
        it is merged is a feature that mails a list nobody agreed to. EP_NOTIFY_TO in
        TOOLS/secrets.local.ps1 is the opt-in, one address or several separated by commas or
        semicolons; without it the run queues the message, names the check on screen, and
        sends nothing.
    #>
    param([string]$Value = $env:EP_NOTIFY_TO)

    if ([string]::IsNullOrWhiteSpace($Value)) { return @() }
    return @($Value -split '[;,]' | ForEach-Object { $_.Trim() } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

function Send-NotifyMail {
    <#
        One message, through the Gmail API, on the token the boards already use.

        -DryRun composes and reports without sending, which is what a first run should do and
        what the tests do always.
    #>
    param(
        [string[]]$To,
        [string]$Subject,
        [string]$Body,
        [string]$From,
        [string]$BodyHtml,
        [switch]$DryRun
    )

    $recipients = @(ConvertTo-NotifyList -Value $To)
    if ($recipients.Count -eq 0) { throw 'no recipient' }
    $raw = New-NotifyMimeMessage -To $recipients -Subject $Subject -Body $Body -From $From -BodyHtml $BodyHtml
    if ($DryRun) {
        return [pscustomobject]@{ Sent = $false; DryRun = $true; Bytes = $raw.Length }
    }

    $token = Get-SheetsAccessToken
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Set-SheetsAddressFamily -Uri $NotifyGmailSendUrl

    $payload = @{ raw = (ConvertTo-NotifyBase64Url -Text $raw) } | ConvertTo-Json -Compress
    try {
        $response = Invoke-RestMethod -Method Post -Uri $NotifyGmailSendUrl -TimeoutSec 60 `
            -Headers @{ Authorization = "Bearer $token" } `
            -ContentType 'application/json; charset=utf-8' -Body $payload
    }
    catch {
        # Google's own words first, and a sentence of ours only where we know something its
        # message does not say. See Get-NotifyApiError for why this reads the body rather than
        # reasoning from the status code.
        $failure = Get-NotifyApiError -ErrorRecord $_
        $detail = $failure.Message

        # The one cause whose fix is in this repository; see Test-NotifyScopeProblem.
        if (Test-NotifyScopeProblem -Reason $failure.Reason -Message $detail) {
            $detail += ("`n  The Google authorisation does not include gmail.send. Run " +
                'TOOLS\Connect-Sheets.ps1 -Force once to approve the wider scope; the ' +
                'refresh token is replaced only if the new consent succeeds.')
        }
        throw $detail
    }

    return [pscustomobject]@{ Sent = $true; DryRun = $false; MessageId = [string]$response.id }
}

function Invoke-NotifyDrain {
    <#
        Send what is queued and write down that it was sent.

        Grouped by run, so a board that reopens twenty checks sends one message and not
        twenty. Two runs that both reopened something send two, because they happened at
        different times and folding them together would date the second one wrongly.

        A message that fails keeps its place and its attempt count, and is retried by the next
        run. At $NotifyMaxAttempts it becomes FAILED and stops: a queue that retries for ever
        is a queue that hides a broken credential behind a line nobody reads.

        Nothing here throws into a run. The caller has already updated a board and written a
        workbook, and neither is worth an undelivered message.
    #>
    param(
        [string]$Path,
        [string[]]$To = (Get-NotifyRecipients),
        [string]$From = $env:EP_NOTIFY_FROM,
        [switch]$DryRun
    )

    if ([string]::IsNullOrWhiteSpace($Path)) { $Path = Get-NotifyQueuePath }
    $queue = @(ConvertTo-NotifyList -Value (Read-NotifyQueue -Path $Path))
    $waiting = @($queue | Where-Object { [string]$_.status -eq $NotifyStatusQueued })
    if ($waiting.Count -eq 0) {
        return [pscustomobject]@{ Sent = 0; Failed = 0; Waiting = 0; Skipped = $false }
    }

    $recipients = @(ConvertTo-NotifyList -Value $To)
    if ($recipients.Count -eq 0) {
        # Not a fault and not silent. The messages stay QUEUED and go out on the first run
        # after somebody sets the address, which is the behaviour that makes the opt-in safe.
        Write-Host ("  {0} reopen notification(s) are queued and unsent: EP_NOTIFY_TO is not set in TOOLS\secrets.local.ps1" -f `
                $waiting.Count) -ForegroundColor DarkGray
        return [pscustomobject]@{ Sent = 0; Failed = 0; Waiting = $waiting.Count; Skipped = $true }
    }

    $sent = 0
    $failed = 0
    $byRun = $waiting | Group-Object { [string]$_.runId }
    foreach ($group in $byRun) {
        $items = @($group.Group)
        $mail = Format-ReopenDigest -Events $items
        if ($null -eq $mail) { continue }

        try {
            $result = Send-NotifyMail -To $recipients -Subject $mail.Subject -Body $mail.Body `
                -BodyHtml $mail.BodyHtml -From $From -DryRun:$DryRun
            foreach ($item in $items) {
                if ($DryRun) { continue }
                $item.status = $NotifyStatusSent
                $item | Add-Member -NotePropertyName sentUtc `
                    -NotePropertyValue ((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')) -Force
                if ($result.PSObject.Properties.Name -contains 'MessageId') {
                    $item | Add-Member -NotePropertyName messageId -NotePropertyValue $result.MessageId -Force
                }
            }
            $sent += $items.Count
            $verb = $(if ($DryRun) { 'would be sent' } else { 'sent' })
            Write-Host ("  Reopen notification {0} to {1}: {2}" -f `
                    $verb, ($recipients -join ', '), $mail.Subject) -ForegroundColor DarkGray
        }
        catch {
            foreach ($item in $items) {
                $attempts = 0
                [void][int]::TryParse([string]$item.attempts, [ref]$attempts)
                $item.attempts = $attempts + 1
                if ($item.attempts -ge $NotifyMaxAttempts) { $item.status = $NotifyStatusFailed }
                $item | Add-Member -NotePropertyName lastError -NotePropertyValue $_.Exception.Message -Force
            }
            $failed += $items.Count
            Write-Host ("  the reopen notification for {0} could not be sent and stays queued: {1}" -f `
                    $group.Name, $_.Exception.Message) -ForegroundColor Yellow
        }
    }

    if (-not $DryRun) { [void](Save-NotifyQueue -Queue $queue -Path $Path) }

    return [pscustomobject]@{
        Sent    = $sent
        Failed  = $failed
        Waiting = @($queue | Where-Object { [string]$_.status -eq $NotifyStatusQueued }).Count
        Skipped = $false
    }
}
