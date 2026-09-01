<#
.SYNOPSIS
    Register the Sheets run-request worker as a scheduled task on this machine.

.DESCRIPTION
    TOOLS/Watch-SheetRequests.ps1 has to be running for a reviewer's click to do anything.
    This registers it as a Task Scheduler task so it comes back after a logon without anybody
    remembering to start it.

    At logon and not at boot, deliberately. The worker needs the database over the VPN and a
    Google refresh token from TOOLS/secrets.local.ps1, both of which belong to a logged-in
    session; a task that starts at boot would spend its first minutes failing to reach either
    and would write those failures into request rows. The three tasks already on this machine
    are logon tasks for the same reason.

    It does not guarantee one worker. The task refuses to start a second instance of itself,
    but a second worker started by hand is outside Task Scheduler's knowledge - the machine-
    wide run lock in Run-Query.ps1 is what actually keeps two runs apart, and it is the
    guarantee to rely on.

    Nothing is registered unless this script is run. Writing it changes nothing.

    This file stays pure ASCII, as the other TOOLS scripts do: Windows PowerShell 5.1 reads a
    .ps1 without a BOM as ANSI, so a literal em dash would arrive mojibaked and fail to parse.

.PARAMETER TaskName
    The name to register under. Defaults to "EP DQ sheet run requests", which is the family
    the three tasks already on this machine belong to.

.PARAMETER Remove
    Unregister the task and stop.

.PARAMETER Show
    Print what is registered - this task and any other Enetpulse DQ task on the machine - and
    stop. Safe to run at any time.

.PARAMETER WhatIf
    Say what would be registered, register nothing.

.EXAMPLE
    .\TOOLS\Register-WorkerTask.ps1 -Show

.EXAMPLE
    .\TOOLS\Register-WorkerTask.ps1 -WhatIf

.EXAMPLE
    .\TOOLS\Register-WorkerTask.ps1
#>
[CmdletBinding()]
param(
    [string]$TaskName = 'EP DQ sheet run requests',
    [switch]$Remove,
    [switch]$Show,
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'

$Worker = Join-Path $PSScriptRoot 'Watch-SheetRequests.ps1'
if (-not (Test-Path -LiteralPath $Worker)) {
    throw "Watch-SheetRequests.ps1 is not beside this script at $Worker."
}

function Show-EnetpulseTasks {
    # Everything this package has put on the machine, so the family is visible rather than
    # remembered. The three that were registered by hand are found by the same pattern.
    $tasks = @(Get-ScheduledTask -ErrorAction SilentlyContinue |
        Where-Object { $_.TaskName -like '*Enetpulse*' -or $_.TaskName -like '*DQ*' })

    if ($tasks.Count -eq 0) {
        Write-Host '  no Enetpulse DQ task is registered on this machine' -ForegroundColor Yellow
        return
    }

    foreach ($task in ($tasks | Sort-Object TaskName)) {
        $info = Get-ScheduledTaskInfo -TaskName $task.TaskName -TaskPath $task.TaskPath -ErrorAction SilentlyContinue
        $last = if ($info -and $info.LastRunTime -gt [datetime]'1900-01-01') {
            $info.LastRunTime.ToString('dd.MM.yyyy HH:mm')
        }
        else { 'never' }
        Write-Host ('  {0,-42} {1,-10} last run {2}' -f $task.TaskName, $task.State, $last) -ForegroundColor DarkGray
    }
}

Write-Host ''

if ($Show) {
    Write-Host 'Scheduled tasks this package has put on the machine:' -ForegroundColor Cyan
    Show-EnetpulseTasks
    Write-Host ''
    return
}

$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

if ($Remove) {
    if (-not $existing) {
        Write-Host ("'{0}' is not registered, so there was nothing to remove." -f $TaskName) -ForegroundColor Yellow
        Write-Host ''
        return
    }
    if ($WhatIf) {
        Write-Host ("would unregister '{0}'" -f $TaskName) -ForegroundColor DarkGray
        Write-Host ''
        return
    }
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Host ("Unregistered '{0}'. Any worker already running is left alone; stop it yourself." -f $TaskName) -ForegroundColor Green
    Write-Host ''
    return
}

# ----- what would be registered ----------------------------------------------------------

$action = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument ('-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}"' -f $Worker) `
    -WorkingDirectory (Split-Path -Parent $PSScriptRoot)

$trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME

# StartWhenAvailable catches a logon the machine slept through. The restart pair is what makes
# it a service rather than a one-shot: a worker that dies on a transport failure is back in a
# minute, and the run lock keeps the returning one from colliding with anything still going.
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RestartCount 999 `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Seconds 0)

# Interactive, under the logged-in account. The worker reads TOOLS/secrets.local.ps1 and needs
# the VPN, so it is that session's task and not the machine's.
$principal = New-ScheduledTaskPrincipal -UserId ("{0}\{1}" -f $env:USERDOMAIN, $env:USERNAME) `
    -LogonType Interactive -RunLevel Limited

Write-Host ("Task           {0}" -f $TaskName) -ForegroundColor Cyan
Write-Host ("  runs         powershell.exe -NoProfile -File {0}" -f $Worker) -ForegroundColor DarkGray
Write-Host ("  as           {0}\{1}, interactive" -f $env:USERDOMAIN, $env:USERNAME) -ForegroundColor DarkGray
Write-Host  '  when         at logon, and again a minute after any failure' -ForegroundColor DarkGray
Write-Host  '  second copy  refused by the task; two runs are kept apart by the run lock' -ForegroundColor DarkGray
Write-Host  '  time limit   none, because it is meant to keep running' -ForegroundColor DarkGray
Write-Host  '  log          TOOLS/worker.local.log' -ForegroundColor DarkGray

if ($existing) {
    Write-Host ''
    Write-Host ("  '{0}' is already registered and will be replaced." -f $TaskName) -ForegroundColor Yellow
}

if ($WhatIf) {
    Write-Host ''
    Write-Host '-WhatIf: nothing was registered.' -ForegroundColor Yellow
    Write-Host ''
    return
}

# ----- register --------------------------------------------------------------------------

[void](Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger `
        -Settings $settings -Principal $principal -Force `
        -Description ('Runs the DQ checks reviewers ask for from their boards. ' +
        'Source: TOOLS/Watch-SheetRequests.ps1 in the entpulse_quality_database repository.'))

Write-Host ''
Write-Host ("Registered '{0}'." -f $TaskName) -ForegroundColor Green
Write-Host '  It starts at the next logon. To start it now without waiting:' -ForegroundColor DarkGray
Write-Host ("    Start-ScheduledTask -TaskName '{0}'" -f $TaskName) -ForegroundColor DarkGray
Write-Host '  It polls only the documents whose registry row has runRequests = true, so it' -ForegroundColor DarkGray
Write-Host '  costs nothing until a board is actually set up.' -ForegroundColor DarkGray
Write-Host ''
