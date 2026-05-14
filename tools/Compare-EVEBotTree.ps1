[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$OtherPath,

    [string]$Reference = "HEAD",

    [switch]$Fetch,

    [string[]]$Exclude = @(
        ".git/**",
        ".vs/**",
        ".idea/**",
        "*.log",
        "_ActiveModules.iss",
        "Branches/Dev/External/isxGamesCommon/**",
        "Branches/*/Behaviors/**/_includes.iss",
        "Branches/*/Behaviors/**/_variables.iss",
        "Branches/Stable/config/*Blacklist.xml",
        "Branches/Stable/config/*Config.xml",
        "Branches/Stable/config/*Mission Cache.xml",
        "Branches/Stable/config/*Training.txt",
        "Branches/Stable/config/*Whitelist.xml",
        "Branches/Dev/config/**",
        "Testcases/**/lstypes*.txt"
    )
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-RepoRoot {
    $root = (& git rev-parse --show-toplevel).Trim()
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($root)) {
        throw "Run this script from inside the EVEBot git repository."
    }

    return $root
}

function Convert-ToRelativePath {
    param(
        [string]$Root,
        [string]$FullName
    )

    $rootPath = [System.IO.Path]::GetFullPath($Root).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    $fullPath = [System.IO.Path]::GetFullPath($FullName)
    $rootUri = New-Object System.Uri($rootPath)
    $fileUri = New-Object System.Uri($fullPath)
    $relative = $rootUri.MakeRelativeUri($fileUri).ToString()
    return [System.Uri]::UnescapeDataString($relative).Replace('\', '/')
}

function Test-Excluded {
    param(
        [string]$RelativePath,
        [string[]]$Patterns
    )

    foreach ($pattern in $Patterns) {
        if ($RelativePath -like $pattern) {
            return $true
        }
    }

    return $false
}

function Get-TreeInventory {
    param(
        [string]$Root,
        [string[]]$ExcludePatterns
    )

    $files = @{}
    Get-ChildItem -LiteralPath $Root -Recurse -File -Force | ForEach-Object {
        $relative = Convert-ToRelativePath -Root $Root -FullName $_.FullName
        if (Test-Excluded -RelativePath $relative -Patterns $ExcludePatterns) {
            return
        }

        $files[$relative] = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
    }

    return $files
}

$repoRoot = Get-RepoRoot
$resolvedOther = (Resolve-Path -LiteralPath $OtherPath).Path
if (-not (Test-Path -LiteralPath $resolvedOther -PathType Container)) {
    throw "OtherPath must be a directory: $OtherPath"
}

if ($Fetch) {
    & git -C $repoRoot fetch upstream --prune
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to fetch upstream."
    }
}

& git -C $repoRoot rev-parse --verify "$Reference^{commit}" | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "Reference does not resolve to a commit: $Reference"
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("evebot-ref-" + [System.Guid]::NewGuid().ToString("N"))
$archivePath = Join-Path ([System.IO.Path]::GetTempPath()) ("evebot-ref-" + [System.Guid]::NewGuid().ToString("N") + ".tar")
New-Item -ItemType Directory -Path $tempRoot | Out-Null

try {
    & git -C $repoRoot archive --format=tar --output=$archivePath $Reference
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to export reference: $Reference"
    }

    & tar -xf $archivePath -C $tempRoot
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to extract reference archive: $Reference"
    }

    $baseFiles = Get-TreeInventory -Root $tempRoot -ExcludePatterns $Exclude
    $otherFiles = Get-TreeInventory -Root $resolvedOther -ExcludePatterns $Exclude

    $baseKeys = @($baseFiles.Keys)
    $otherKeys = @($otherFiles.Keys)

    $added = @($otherKeys | Where-Object { -not $baseFiles.ContainsKey($_) } | Sort-Object)
    $removed = @($baseKeys | Where-Object { -not $otherFiles.ContainsKey($_) } | Sort-Object)
    $modified = @($otherKeys | Where-Object {
        $baseFiles.ContainsKey($_) -and $baseFiles[$_] -ne $otherFiles[$_]
    } | Sort-Object)

    Write-Host "Reference : $Reference"
    Write-Host "Other tree: $resolvedOther"
    Write-Host "Added     : $($added.Count)"
    Write-Host "Removed   : $($removed.Count)"
    Write-Host "Modified  : $($modified.Count)"

    if ($added.Count -gt 0) {
        Write-Host ""
        Write-Host "Added files"
        $added | ForEach-Object { Write-Host "  + $_" }
    }

    if ($removed.Count -gt 0) {
        Write-Host ""
        Write-Host "Removed files"
        $removed | ForEach-Object { Write-Host "  - $_" }
    }

    if ($modified.Count -gt 0) {
        Write-Host ""
        Write-Host "Modified files"
        $modified | ForEach-Object { Write-Host "  M $_" }
    }
}
finally {
    if (Test-Path -LiteralPath $archivePath) {
        Remove-Item -LiteralPath $archivePath -Force
    }

    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
