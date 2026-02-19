param(
    [string]$BlendPath = ".\Untitled.blend"
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$blenderWrapper = Join-Path $scriptDir "blender.ps1"
$sceneInfoScript = Join-Path $scriptDir "scene_info.py"

if (-not (Test-Path $BlendPath)) {
    Write-Error "Blend file not found: $BlendPath"
}

$absoluteBlendPath = (Resolve-Path $BlendPath).Path

Write-Host "== Blender version =="
& $blenderWrapper -BlenderArgs @("--version")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "== Scene metadata =="
& $blenderWrapper -BlenderArgs @("-b", $absoluteBlendPath, "--python", $sceneInfoScript)
exit $LASTEXITCODE
