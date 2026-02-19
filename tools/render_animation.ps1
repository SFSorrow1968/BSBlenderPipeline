param(
    [string]$BlendPath = ".\Untitled.blend",
    [string]$OutputPath = ".\renders\frame_####",
    [string]$FileFormat = "PNG",
    [int]$StartFrame = -1,
    [int]$EndFrame = -1
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$blenderWrapper = Join-Path $scriptDir "blender.ps1"

if (-not (Test-Path $BlendPath)) {
    Write-Error "Blend file not found: $BlendPath"
}

$absoluteBlendPath = (Resolve-Path $BlendPath).Path
$absoluteOutputPath = [System.IO.Path]::GetFullPath((Join-Path (Get-Location).Path $OutputPath))
$outputDir = Split-Path -Parent $absoluteOutputPath
if ($outputDir -and -not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$renderArgs = @(
    "-b", $absoluteBlendPath,
    "-o", $absoluteOutputPath,
    "-F", $FileFormat
)

if ($StartFrame -ge 0) {
    $renderArgs += @("-s", "$StartFrame")
}

if ($EndFrame -ge 0) {
    $renderArgs += @("-e", "$EndFrame")
}

$renderArgs += "-a"

& $blenderWrapper -BlenderArgs $renderArgs
exit $LASTEXITCODE
