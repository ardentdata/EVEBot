[CmdletBinding()]
param(
    [switch]$Merge,
    [switch]$AllowMergeCommit
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (& git rev-parse --show-toplevel).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($repoRoot)) {
    throw "Run this script from inside the EVEBot git repository."
}

$upstreamUrl = (& git -C $repoRoot remote get-url upstream 2>$null).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($upstreamUrl)) {
    throw "Missing upstream remote. Expected: git remote add upstream git@github.com:CyberTech/EVEBot.git"
}

& git -C $repoRoot fetch upstream --prune
if ($LASTEXITCODE -ne 0) {
    throw "Failed to fetch upstream."
}

$branch = (& git -C $repoRoot branch --show-current).Trim()
$status = (& git -C $repoRoot status --short)
$counts = (& git -C $repoRoot rev-list --left-right --count HEAD...upstream/master).Trim() -split "\s+"
$ahead = [int]$counts[0]
$behind = [int]$counts[1]

Write-Host "Branch  : $branch"
Write-Host "Upstream: $upstreamUrl"
Write-Host "Ahead   : $ahead"
Write-Host "Behind  : $behind"

if ($behind -gt 0) {
    Write-Host ""
    Write-Host "Incoming upstream commits"
    & git -C $repoRoot log --oneline HEAD..upstream/master
}

if (-not $Merge) {
    if ($behind -gt 0) {
        Write-Host ""
        Write-Host "Run with -Merge to apply upstream/master to the current branch."
    }
    return
}

if ($status) {
    Write-Host ""
    Write-Host "Working tree has local changes:"
    $status | ForEach-Object { Write-Host $_ }
    throw "Commit or stash local changes before merging upstream."
}

if ($AllowMergeCommit) {
    & git -C $repoRoot merge upstream/master
} else {
    & git -C $repoRoot merge --ff-only upstream/master
}

if ($LASTEXITCODE -ne 0) {
    throw "Upstream merge failed."
}
