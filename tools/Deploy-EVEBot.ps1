[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateSet("All", "Local", "Remote")]
    [string]$Target = "All",

    [string[]]$TargetPath,

    [switch]$AllowDirty,

    [switch]$IncludeDev,

    [switch]$ExcludePrivateConfig
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (& git rev-parse --show-toplevel).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($repoRoot)) {
    throw "Run this script from inside the EVEBot git repository."
}

$status = @(& git -C $repoRoot status --short)
if ($status.Count -gt 0 -and -not $AllowDirty) {
    Write-Host "Working tree has local changes:"
    $status | ForEach-Object { Write-Host $_ }
    throw "Commit or stash changes before deploying, or pass -AllowDirty."
}

$defaultTargets = @{
    Local = "C:\InnerSpace\Scripts\EVEBot"
    Remote = "V:\Scripts\EVEBot"
}

if (-not $TargetPath -or $TargetPath.Count -eq 0) {
    switch ($Target) {
        "Local" { $TargetPath = @($defaultTargets.Local) }
        "Remote" { $TargetPath = @($defaultTargets.Remote) }
        default { $TargetPath = @($defaultTargets.Local, $defaultTargets.Remote) }
    }
}

function Convert-ToRepoRelativePath {
    param([string]$Path)

    return $Path.Replace('\', '/')
}

function Test-DeployPath {
    param([string]$RelativePath)

    if ($RelativePath -like ".git/*" -or
        $RelativePath -like ".analysis/*" -or
        $RelativePath -like ".claude/*" -or
        $RelativePath -like "docs/*" -or
        $RelativePath -like "tools/*" -or
        $RelativePath -like "Testcases/*") {
        return $false
    }

    if (-not $IncludeDev -and $RelativePath -like "Branches/Dev/*") {
        return $false
    }

    if ($RelativePath -like "Branches/*/Behaviors/_includes.iss" -or
        $RelativePath -like "Branches/*/Behaviors/_variables.iss" -or
        $RelativePath -like "Branches/*/_ActiveModules.iss" -or
        $RelativePath -like "*.backup" -or
        $RelativePath -like "*.backup-*" -or
        $RelativePath -like "*.log" -or
        $RelativePath -like "Branches/Stable/config/Logs/*") {
        return $false
    }

    if ($ExcludePrivateConfig -and $RelativePath -eq "Config/Launcher.xml") {
        return $false
    }

    if ($RelativePath -like "Branches/Stable/*") {
        return $true
    }

    if ($IncludeDev -and $RelativePath -like "Branches/Dev/*") {
        return $true
    }

    $sharedFiles = @(
        "EVEBot.iss",
        "EVECallback.iss",
        "EVEWatcher.iss",
        "Launcher.iss",
        "README.md",
        "Config/Launcher.xml",
        "Config/Config_Templates/Launcher.xml",
        "External/isxScripts/obj_LSQuery.iss",
        "External/isxScripts/obj_LSTypeIterator.iss",
        "External/isxScripts/obj_PulseTimer.iss",
        "Support/TestAPI.iss",
        "Support/obj_Configuration.iss",
        "Support/obj_LoginHandler.iss"
    )

    return $sharedFiles -contains $RelativePath
}

function Get-DeployFiles {
    $tracked = @(& git -C $repoRoot ls-files)
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to list tracked files."
    }

    return @(
        $tracked |
            ForEach-Object { Convert-ToRepoRelativePath -Path $_ } |
            Where-Object { Test-DeployPath -RelativePath $_ } |
            Sort-Object -Unique
    )
}

function Test-SameFile {
    param(
        [string]$Source,
        [string]$Destination
    )

    if (-not (Test-Path -LiteralPath $Destination -PathType Leaf)) {
        return $false
    }

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $sourceStream = [System.IO.File]::OpenRead($Source)
        try {
            $sourceHash = [System.BitConverter]::ToString($sha.ComputeHash($sourceStream))
        }
        finally {
            $sourceStream.Dispose()
        }

        $destStream = [System.IO.File]::OpenRead($Destination)
        try {
            $destHash = [System.BitConverter]::ToString($sha.ComputeHash($destStream))
        }
        finally {
            $destStream.Dispose()
        }
    }
    finally {
        $sha.Dispose()
    }

    return $sourceHash -eq $destHash
}

$deployFiles = Get-DeployFiles
$commit = (& git -C $repoRoot rev-parse --short HEAD).Trim()
$branch = (& git -C $repoRoot branch --show-current).Trim()

Write-Host "Deploying EVEBot"
Write-Host "Repo   : $repoRoot"
Write-Host "Branch : $branch"
Write-Host "Commit : $commit"
Write-Host "Files  : $($deployFiles.Count)"
Write-Host "Target : $Target"
Write-Host ""

foreach ($destinationRoot in $TargetPath) {
    $resolvedDestination = $destinationRoot
    if (Test-Path -LiteralPath $destinationRoot) {
        $resolvedDestination = (Resolve-Path -LiteralPath $destinationRoot).Path
    }

    if ([System.IO.Path]::GetFullPath($resolvedDestination).TrimEnd('\') -eq [System.IO.Path]::GetFullPath($repoRoot).TrimEnd('\')) {
        throw "Refusing to deploy into the repository root: $resolvedDestination"
    }

    Write-Host "==> $resolvedDestination"

    $created = 0
    $updated = 0
    $unchanged = 0

    foreach ($relativePath in $deployFiles) {
        $source = Join-Path $repoRoot ($relativePath -replace '/', '\')
        $destination = Join-Path $resolvedDestination ($relativePath -replace '/', '\')
        $exists = Test-Path -LiteralPath $destination -PathType Leaf
        $same = $exists -and (Test-SameFile -Source $source -Destination $destination)

        if ($same) {
            $unchanged++
            continue
        }

        $action = if ($exists) { "Update" } else { "Create" }
        if ($PSCmdlet.ShouldProcess($destination, "$action from $relativePath")) {
            New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
            Copy-Item -LiteralPath $source -Destination $destination -Force
        }

        if ($exists) {
            $updated++
        }
        else {
            $created++
        }

        Write-Host ("  {0,-6} {1}" -f $action, $relativePath)
    }

    Write-Host "  Summary: $created created, $updated updated, $unchanged unchanged"
    Write-Host ""
}
