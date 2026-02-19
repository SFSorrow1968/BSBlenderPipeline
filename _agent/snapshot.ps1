param(
    [string]$Message,
    [switch]$Zip,
    [string]$TagPrefix = "snapshot"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

git rev-parse --show-toplevel | Out-Null

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
if (-not $Message -or $Message.Trim().Length -eq 0) {
    $Message = "snapshot: $timestamp"
}

git add -A
git diff --cached --quiet
if ($LASTEXITCODE -eq 0) {
    Write-Host "No staged changes. Snapshot not created."
    exit 0
}

git commit -m $Message

$tagName = "$TagPrefix-$timestamp"
git tag $tagName

if ($Zip) {
    $outDir = Join-Path $repoRoot "builds\snapshots"
    if (-not (Test-Path $outDir)) {
        New-Item -ItemType Directory -Path $outDir | Out-Null
    }
    $zipPath = Join-Path $outDir "$tagName.zip"
    git archive --format=zip -o $zipPath HEAD
    Write-Host "Wrote $zipPath"
}

Write-Host "Snapshot commit and tag created: $tagName"

