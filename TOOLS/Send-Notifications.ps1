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
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'

# Sheets.ps1 for the token and the address-family workaround; Notify.ps1 for everything else.
# Neither is run, both are dot-sourced, exactly as Run-Query.ps1 takes them.
. (Join-Path $PSScriptRoot 'Sheets.ps1')
. (Join-Path $PSScriptRoot 'Notify.ps1')

$SecretsPath = Join-Path $PSScriptRoot 'secrets.local.ps1'
if (Test-Path -LiteralPath $SecretsPath) { . $SecretsPath }

$queuePath = Get-NotifyQueuePath
$waiting = @(Read-NotifyQueue -Path $queuePath |
        Where-Object { [string]$_.status -eq $NotifyStatusQueued })

if ($waiting.Count -eq 0) {
    if (-not $Quiet) { Write-Host 'Nothing is waiting to be sent.' -ForegroundColor DarkGray }
    exit 0
}

$recipients = @(ConvertTo-NotifyList -Value $To)
if ($recipients.Count -eq 0) { $recipients = @(Get-NotifyRecipients) }

$result = Invoke-NotifyDrain -Path $queuePath -To $recipients -DryRun:$DryRun

# A failure here is worth an exit code, because this runs unattended and a scheduled task that
# always reports success is a scheduled task nobody looks at. A message that merely stayed
# queued for want of an address is not a failure: it is the opt-in working.
if ($result.Failed -gt 0) { exit 1 }
exit 0
