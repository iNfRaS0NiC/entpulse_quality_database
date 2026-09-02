<#
.SYNOPSIS
    Send the reopen notifications a board run has queued.

.DESCRIPTION
    A board run queues one event per check it moved to Reopened and sends nothing. This sends
    what has accumulated, as one message per drain rather than one per run.

    The split is the point. A board run covers one sport, so sending from inside it means one
    mail per sport, and a night across sixteen sports is sixteen mails - which is where
    somebody starts filtering the sender into a folder, and that is the failure the whole
    notification exists to avoid, arriving by a different door. Held and drained on a schedule,
    the same findings arrive as one list a person reads once.

    Nothing here decides anything. The transition was decided by the run that wrote it, the
    wording is fixed, and this only chooses the moment.

    Run it twice a day from Task Scheduler. Each drain covers everything queued since the last
    one, so the morning message carries the night's runs and the afternoon one carries the
    morning's - no window has to be configured, because the queue is the window.

.PARAMETER To
    Who to tell. Defaults to EP_NOTIFY_TO in TOOLS/secrets.local.ps1, one address or several
    separated by commas or semicolons. With none set, nothing is sent and the queue is left as
    it is, which is what makes the schedule safe to register before the address is agreed.

.PARAMETER DryRun
    Compose and report without sending, and without marking anything sent. What a first run
    should do.

.PARAMETER Quiet
    Say nothing when there was nothing to send. For the scheduled runs, where a line a day
    saying "nothing happened" is a line nobody reads.

.EXAMPLE
    .\TOOLS\Send-Notifications.ps1 -DryRun

.EXAMPLE
    .\TOOLS\Send-Notifications.ps1
#>
[CmdletBinding()]
param(
    [string[]]$To,
    [switch]$DryRun,
    [switch]$Quiet,

    # Read every board and report what it currently calls Reopened, instead of draining
    # the queue of what runs changed. The afternoon pass; see the block below for why the
    # two exist side by side.
    [switch]$Sweep
)

$ErrorActionPreference = 'Stop'

# Sheets.ps1 for the token and the address-family workaround; Notify.ps1 for everything else.
# Neither is run, both are dot-sourced, exactly as Run-Query.ps1 takes them.
. (Join-Path $PSScriptRoot 'Sheets.ps1')
. (Join-Path $PSScriptRoot 'Notify.ps1')

$SecretsPath = Join-Path $PSScriptRoot 'secrets.local.ps1'
if (Test-Path -LiteralPath $SecretsPath) { . $SecretsPath }

$recipients = @(ConvertTo-NotifyList -Value $To)
if ($recipients.Count -eq 0) { $recipients = @(Get-NotifyRecipients) }

if ($Sweep) {
    # Every board, and what it says right now. The queue answers "what changed"; this answers
    # "what is still open", and the two fail in different ways - a transition can be written to
    # a board and never reach the queue, and then only a sweep finds it. Read rather than
    # remembered, so the afternoon message does not depend on anything having gone right at the
    # moment the word was written.
    $boards = @(Get-NotifySweepBoards)
    $found = @()
    $unreadable = @()
    foreach ($board in $boards) {
        try { $found += @(Get-NotifyBoardReopened -SheetId $board.SheetId -Sport $board.Sport) }
        catch { $unreadable += ('{0}: {1}' -f $board.Sport, $_.Exception.Message) }
    }

    # A board that could not be read is said out loud and does not silently become "nothing is
    # reopened there". The same argument Get-NotifyBoardStatus makes: a network fault that
    # silences an alarm looks exactly like a quiet afternoon.
    foreach ($problem in $unreadable) {
        Write-Host ('  could not be read, so nothing is reported for it: {0}' -f $problem) -ForegroundColor Yellow
    }

    if ($found.Count -eq 0) {
        if (-not $Quiet) {
            Write-Host ('Nothing is Reopened on any of the {0} board(s) read.' -f `
                ($boards.Count - $unreadable.Count)) -ForegroundColor DarkGray
        }
        exit $(if ($unreadable.Count -gt 0) { 1 } else { 0 })
    }

    $noun = $(if ($found.Count -eq 1) { 'check' } else { 'checks' })
    $sports = @($found | ForEach-Object { [string]$_.sport } | Sort-Object -Unique).Count
    $message = Format-ReopenDigest -Events $found `
        -Headline ('Data Quality Issues - Open: {0} {1} on {2} sport(s)' -f $found.Count, $noun, $sports) `
        -OpeningLine $(if ($found.Count -eq 1) {
                'check is marked Reopened and is waiting to be looked at'
            } else {
                'checks are marked Reopened and are waiting to be looked at'
            })

    if ($DryRun) {
        Write-Host $message.Subject -ForegroundColor Cyan
        Write-Host $message.Body
        exit 0
    }
    if ($recipients.Count -eq 0) {
        Write-Host 'EP_NOTIFY_TO is not set in TOOLS\secrets.local.ps1, so nothing was sent.' -ForegroundColor Yellow
        exit 0
    }
    $sent = Send-NotifyMail -To $recipients -Subject $message.Subject `
        -Body $message.Body -BodyHtml $message.BodyHtml
    if (-not $sent.Sent) {
        Write-Host ('The sweep could not be sent: {0}' -f $sent.Error) -ForegroundColor Yellow
        exit 1
    }
    if (-not $Quiet) {
        Write-Host ('Sent: {0}' -f $message.Subject) -ForegroundColor DarkGray
    }
    exit $(if ($unreadable.Count -gt 0) { 1 } else { 0 })
}

$queuePath = Get-NotifyQueuePath
$waiting = @(Read-NotifyQueue -Path $queuePath |
        Where-Object { [string]$_.status -eq $NotifyStatusQueued })

if ($waiting.Count -eq 0) {
    if (-not $Quiet) { Write-Host 'Nothing is waiting to be sent.' -ForegroundColor DarkGray }
    exit 0
}

$result = Invoke-NotifyDrain -Path $queuePath -To $recipients -DryRun:$DryRun

# A failure here is worth an exit code, because this runs unattended and a scheduled task that
# always reports success is a scheduled task nobody looks at. A message that merely stayed
# queued for want of an address is not a failure: it is the opt-in working.
if ($result.Failed -gt 0) { exit 1 }
exit 0
