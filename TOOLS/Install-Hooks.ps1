<#
.SYNOPSIS
    Point this clone's git hooks at TOOLS/hooks, so the package validator runs before a commit.

.DESCRIPTION
    Git hooks live in .git/hooks, which is not version-controlled: a hook committed to the
    repository does nothing until somebody installs it, and a hook installed by hand is one
    machine's arrangement that no clone inherits. `core.hooksPath` is the way out of both - the
    hook itself is in git, in TOOLS/hooks, and this sets one config value so git looks there.

    Run once per clone. Nothing else in the package creates, checks or repairs it, in the same
    way nothing here creates the scheduled tasks: TOOLS/README.md is the only record that either
    exists.

    What it installs today is `pre-commit`, which runs TOOLS/Test-Package.ps1 and refuses the
    commit if the validator finds anything. About 23 seconds a commit. TOOLS/Test-Tools.ps1 is
    deliberately not in it at roughly six and a half minutes; that one stays a thing a person
    runs after changing a script, which is what CLAUDE.md already asks for.

.PARAMETER Remove
    Put the clone back to git's own .git/hooks, uninstalling nothing else.

.PARAMETER WhatIf
    Say what would change and change nothing.

.EXAMPLE
    .\TOOLS\Install-Hooks.ps1

.EXAMPLE
    .\TOOLS\Install-Hooks.ps1 -Remove
#>
[CmdletBinding()]
param(
    [switch]$Remove,
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $RepoRoot
try {
    $inside = (& git rev-parse --is-inside-work-tree 2>$null)
    if ($LASTEXITCODE -ne 0 -or [string]$inside -ne 'true') {
        Write-Host "$RepoRoot is not a git working tree, so there are no hooks to point anywhere." -ForegroundColor Yellow
        exit 1
    }

    $current = (& git config --local --get core.hooksPath 2>$null)
    if ($LASTEXITCODE -ne 0) { $current = '' }

    if ($Remove) {
        if ([string]::IsNullOrWhiteSpace($current)) {
            Write-Host 'core.hooksPath is not set on this clone; nothing to remove.' -ForegroundColor DarkGray
            exit 0
        }
        if ($WhatIf) {
            Write-Host ("would unset core.hooksPath, which is '{0}'" -f $current) -ForegroundColor DarkGray
            exit 0
        }
        & git config --local --unset core.hooksPath
        Write-Host 'core.hooksPath unset. Git is back to .git/hooks, which holds nothing.' -ForegroundColor Cyan
        exit 0
    }

    # Relative, so the value is the same on every machine and survives the folder being moved.
    $wanted = 'TOOLS/hooks'
    $hook = Join-Path $PSScriptRoot 'hooks\pre-commit'
    if (-not (Test-Path -LiteralPath $hook)) {
        Write-Host "TOOLS/hooks/pre-commit is missing, so pointing git at the folder would install nothing." -ForegroundColor Yellow
        exit 1
    }

    if ($current -eq $wanted) {
        Write-Host ("core.hooksPath is already '{0}'. The validator runs before every commit." -f $wanted) -ForegroundColor DarkGray
        exit 0
    }

    if ($WhatIf) {
        Write-Host ("would set core.hooksPath to '{0}'{1}" -f $wanted,
            $(if ($current) { " (it is '$current' now)" } else { '' })) -ForegroundColor DarkGray
        exit 0
    }

    & git config --local core.hooksPath $wanted
    Write-Host ("core.hooksPath set to '{0}'." -f $wanted) -ForegroundColor Cyan
    Write-Host '  TOOLS/Test-Package.ps1 now runs before every commit and refuses one that fails.' -ForegroundColor DarkGray
    Write-Host '  git commit --no-verify skips it.' -ForegroundColor DarkGray
    exit 0
}
finally {
    Pop-Location
}
