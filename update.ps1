<#
.SYNOPSIS
    Brings the fork up to date with upstream and advances plugin submodules.

.PARAMETER Rebase
    Rebase onto upstream/master instead of merging.

.PARAMETER NoPush
    Skip pushing to origin.

.PARAMETER NoGenerate
    Skip running gen_solution.ps1.
#>
param(
    [switch]$Rebase,
    [switch]$NoPush,
    [switch]$NoGenerate
)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

function Invoke-Git {
    git @args
    if ($LASTEXITCODE -ne 0) { throw "git $($args -join ' ') failed with exit code $LASTEXITCODE" }
}

if (git status --porcelain --ignore-submodules=all) {
    throw "Working tree has uncommitted changes. Commit or stash them first."
}

Write-Host "==> Fetching upstream" -ForegroundColor Cyan
Invoke-Git fetch upstream

if ($Rebase) {
    Write-Host "==> Rebasing onto upstream/master" -ForegroundColor Cyan
    Invoke-Git rebase upstream/master
} else {
    Write-Host "==> Merging upstream/master" -ForegroundColor Cyan
    Invoke-Git merge --no-edit upstream/master
}

Write-Host "==> Syncing submodules to recorded commits" -ForegroundColor Cyan
Invoke-Git submodule sync --recursive
Invoke-Git submodule update --init --recursive

Write-Host "==> Advancing plugin submodules to latest remote" -ForegroundColor Cyan
Invoke-Git submodule update --remote plugins

Invoke-Git add plugins src/eqlib
git diff --cached --quiet
if ($LASTEXITCODE -ne 0) {
    Write-Host "==> Committing submodule updates" -ForegroundColor Cyan
    git diff --cached --name-only
    Invoke-Git commit -m "Update submodules"
} else {
    Write-Host "==> Submodules already up to date" -ForegroundColor Green
}

if (-not $NoPush) {
    Write-Host "==> Pushing to origin" -ForegroundColor Cyan
    if ($Rebase) { Invoke-Git push --force-with-lease origin HEAD } else { Invoke-Git push origin HEAD }
}

if (-not $NoGenerate) {
    Write-Host "==> Regenerating solution" -ForegroundColor Cyan
    & "$PSScriptRoot\gen_solution.ps1"
}

Write-Host "==> Done" -ForegroundColor Green
