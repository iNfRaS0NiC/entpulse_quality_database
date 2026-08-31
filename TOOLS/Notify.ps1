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

function Format-ReopenDigest {
    <#
        Subject, and both bodies, for one message covering these events.

        A list rather than a paragraph each. The first version wrote four lines of prose per
        check, which reads well for one and badly for twenty - and twenty is the case this
        exists for. What a reader wants at the moment the message arrives is which sport, which
        check, what it asserts and how big it is; the reasoning belongs on the board.

        Two bodies, because the link has to be discreet. A plain-text mail can only carry a
        naked URL, and a Google tab link is ninety characters that push the row off the screen
        and bury the four columns that matter. HTML gives the row a word to hang the link on.
        The text alternative is sent as well and is not decoration: it is what a client that
        refuses HTML shows, and what a reader searching their mail matches against.

        Several reopens go in one message. A run that moves twenty checks would otherwise
        arrive as twenty mails, and the second one is where somebody starts filtering the
        sender into a folder - which is the failure this whole file exists to avoid, arriving
        by a different door.
    #>
    param($Events)

    $items = @(ConvertTo-NotifyList -Value $Events)
    if ($items.Count -eq 0) { return $null }

    $sports = @($items | ForEach-Object { [string]$_.sport } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
    $where = $(if ($sports.Count -eq 1) { $sports[0] } else { ('{0} sports' -f $sports.Count) })

    if ($items.Count -eq 1) {
        $subject = ('DQ reopened: {0} {1}' -f [string]$items[0].checkId, [string]$items[0].name).Trim()
    }
    else {
        $subject = ('DQ reopened: {0} checks on {1}' -f $items.Count, $where)
    }

    $opening = $(if ($items.Count -eq 1) {
            'One check that a reviewer had closed has returned findings.'
        }
        else {
            '{0} checks that reviewers had closed have returned findings.' -f $items.Count
        })

    # ----- the text alternative
    $lines = @($opening, '')
    $widths = @{ Sport = 5; Check = 5; Name = 4 }
    foreach ($item in $items) {
        $widths.Sport = [math]::Max($widths.Sport, ([string]$item.sport).Length)
        $widths.Check = [math]::Max($widths.Check, ([string]$item.checkId).Length)
        $widths.Name = [math]::Max($widths.Name, ([string]$item.name).Length)
    }
    $format = '{0,-' + $widths.Sport + '}  {1,-' + $widths.Check + '}  {2,-' + $widths.Name + '}  {3,6}'
    $lines += ($format -f 'Sport', 'Check', 'Name', 'Rows')
    $lines += ($format -f ('-' * $widths.Sport), ('-' * $widths.Check), ('-' * $widths.Name), '------')
    foreach ($item in $items) {
        $lines += ($format -f [string]$item.sport, [string]$item.checkId, [string]$item.name,
            [string]$item.currentFindings)
    }
    $lines += ''

    # One Overview address per board. Plain text cannot hang a link on a word, so the HTML puts
    # it on the sport's name and this puts it here, once per sport rather than once per row.
    $seen = @{}
    foreach ($item in $items) {
        $sport = [string]$item.sport
        if ($seen.ContainsKey($sport)) { continue }
        $seen[$sport] = $true
        $board = Get-NotifyTabLink -SheetId ([string]$item.sheetId) -Gid $item.overviewGid
        if (-not [string]::IsNullOrWhiteSpace($board)) {
            $lines += ('{0}: {1}' -f $sport, $board)
        }
    }
    if ($seen.Count -gt 0) { $lines += '' }
    $lines += 'Rows are open findings: rows already marked No Issue / Change are not in them.'

    # ----- the HTML body
    $rows = @()
    foreach ($item in $items) {
        $link = Get-NotifyTabLink -SheetId ([string]$item.sheetId) -Gid $item.tabGid
        $open = $(if ([string]::IsNullOrWhiteSpace($link)) { '' }
            else {
                '<a href="{0}" style="color:#5f6368;text-decoration:none">open</a>' -f (ConvertTo-NotifyHtmlText -Text $link)
            })

        # Two links on one row, each on the thing it names. The sport is the board, so it goes
        # to that board's Overview; the row is one check, so its trailing word goes to that
        # check's own tab. A reader who wants the sport and a reader who wants the finding are
        # two different readers and neither should have to hunt for the other's target.
        $overview = Get-NotifyTabLink -SheetId ([string]$item.sheetId) -Gid $item.overviewGid
        $sportCell = ConvertTo-NotifyHtmlText -Text ([string]$item.sport)
        if (-not [string]::IsNullOrWhiteSpace($overview)) {
            $sportCell = '<a href="{0}" style="color:#202124">{1}</a>' -f `
                (ConvertTo-NotifyHtmlText -Text $overview), $sportCell
        }
        $what = $(if ([string]::IsNullOrWhiteSpace([string]$item.what)) { '' }
            else {
                '<div style="color:#5f6368;font-size:12px">{0}</div>' -f (ConvertTo-NotifyHtmlText -Text ([string]$item.what))
            })
        $rows += ('<tr>' +
            '<td style="padding:6px 14px 6px 0;white-space:nowrap">{0}</td>' +
            '<td style="padding:6px 14px 6px 0;white-space:nowrap">{1}</td>' +
            '<td style="padding:6px 14px 6px 0">{2}{3}</td>' +
            '<td style="padding:6px 14px 6px 0;text-align:right;white-space:nowrap">{4}</td>' +
            '<td style="padding:6px 0;white-space:nowrap">{5}</td>' +
            '</tr>') -f
            $sportCell,
            (ConvertTo-NotifyHtmlText -Text ([string]$item.checkId)),
            (ConvertTo-NotifyHtmlText -Text ([string]$item.name)),
            $what,
            (ConvertTo-NotifyHtmlText -Text ([string]$item.currentFindings)),
            $open
    }

    $html = ('<div style="font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;font-size:14px;color:#202124">' +
        '<p style="margin:0 0 14px 0">{0}</p>' +
        '<table cellspacing="0" cellpadding="0" style="border-collapse:collapse;font-size:13px">' +
        '<tr style="text-align:left;color:#5f6368;border-bottom:1px solid #dadce0">' +
        '<th style="padding:0 14px 6px 0;font-weight:600">Sport</th>' +
        '<th style="padding:0 14px 6px 0;font-weight:600">Check</th>' +
        '<th style="padding:0 14px 6px 0;font-weight:600">Name</th>' +
        '<th style="padding:0 14px 6px 0;font-weight:600;text-align:right">Rows</th>' +
        '<th style="padding:0 0 6px 0;font-weight:600"></th>' +
        '</tr>{1}</table>' +
        '<p style="margin:16px 0 0 0;color:#5f6368;font-size:12px">' +
        'Rows are open findings: rows already marked No Issue / Change are not in them.</p>' +
        '</div>') -f (ConvertTo-NotifyHtmlText -Text $opening), ($rows -join '')

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
