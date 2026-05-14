[CmdletBinding()]
param(
    [string]$Reference = "HEAD",

    [ValidateSet("All", "Local", "Remote", "LegacySource")]
    [string]$Target = "All",

    [string[]]$TargetPath,

    [switch]$IncludeLegacySource,

    [switch]$FullOutput
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (& git rev-parse --show-toplevel).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($repoRoot)) {
    throw "Run this script from inside the EVEBot git repository."
}

$compareScript = Join-Path $repoRoot "tools\Compare-EVEBotTree.ps1"
if (-not (Test-Path -LiteralPath $compareScript -PathType Leaf)) {
    throw "Missing compare script: $compareScript"
}

$defaultTargets = @(
    [pscustomobject]@{ Name = "Local"; Path = "C:\InnerSpace\Scripts\EVEBot" },
    [pscustomobject]@{ Name = "Remote"; Path = "V:\Scripts\EVEBot" }
)

if ($IncludeLegacySource -or $Target -eq "LegacySource") {
    $defaultTargets += [pscustomobject]@{ Name = "LegacySource"; Path = "V:\scripts\evebot" }
}

if ($TargetPath -and $TargetPath.Count -gt 0) {
    $targets = @(
        $TargetPath | ForEach-Object {
            [pscustomobject]@{ Name = "Custom"; Path = $_ }
        }
    )
}
else {
    if ($Target -eq "All") {
        $targets = $defaultTargets
    }
    else {
        $targets = @($defaultTargets | Where-Object { $_.Name -eq $Target })
    }
}

if (-not $targets -or $targets.Count -eq 0) {
    throw "No targets selected."
}

Write-Host "EVEBot target drift"
Write-Host "Reference: $Reference"
Write-Host "Mode     : StableOnly + IgnoreCrAtEol"
Write-Host ""

$summaries = @()

foreach ($targetInfo in $targets) {
    $path = $targetInfo.Path
    if (-not (Test-Path -LiteralPath $path -PathType Container)) {
        $summaries += [pscustomobject]@{
            Target = $targetInfo.Name
            Path = $path
            Added = "missing"
            Removed = "missing"
            Modified = "missing"
        }
        Write-Host "==> $($targetInfo.Name): $path"
        Write-Host "Missing target path"
        Write-Host ""
        continue
    }

    $output = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $compareScript -OtherPath $path -Reference $Reference -StableOnly -IgnoreCrAtEol)
    if ($LASTEXITCODE -ne 0) {
        throw "Compare failed for $($targetInfo.Name): $path"
    }

    $added = (($output | Select-String -Pattern "^Added\s*:").Line -replace "^Added\s*:\s*", "").Trim()
    $removed = (($output | Select-String -Pattern "^Removed\s*:").Line -replace "^Removed\s*:\s*", "").Trim()
    $modified = (($output | Select-String -Pattern "^Modified\s*:").Line -replace "^Modified\s*:\s*", "").Trim()

    $summaries += [pscustomobject]@{
        Target = $targetInfo.Name
        Path = (Resolve-Path -LiteralPath $path).Path
        Added = $added
        Removed = $removed
        Modified = $modified
    }

    if ($FullOutput) {
        Write-Host "==> $($targetInfo.Name): $path"
        $output | ForEach-Object { Write-Host $_ }
        Write-Host ""
    }
}

$summaries | Format-Table -AutoSize

$hasDrift = $false
foreach ($summary in $summaries) {
    if ($summary.Added -ne "0" -or $summary.Removed -ne "0" -or $summary.Modified -ne "0") {
        $hasDrift = $true
        break
    }
}

if ($hasDrift) {
    Write-Host ""
    Write-Host "Drift detected. Run with -FullOutput to list files."
}
else {
    Write-Host ""
    Write-Host "No Stable drift detected."
}
