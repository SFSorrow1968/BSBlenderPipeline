param(
    [string]$InputFbx = "",

    [Parameter(Mandatory = $true)]
    [string]$OutputFbx,
    [string]$OutputBlend = "",

    [string]$ClipName = "Death_Generic_A",
    [string]$ArmatureName = "",
    [int]$Fps = 60,
    [double]$DurationSec = 0.8,
    [double]$MinDurationSec = 0.5,
    [double]$MaxDurationSec = 1.0,
    [int]$StartFrame = 1,
    [string]$RootBone = "",
    [double]$DriftThreshold = 0.03,
    [switch]$AutoBlock,
    [switch]$ForceExport,
    [switch]$KeepScene,
    [switch]$UseCurrentScene,
    [string]$BlendPath = ""
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$blenderWrapper = Join-Path $scriptDir "blender.ps1"
$pipelineScript = Join-Path $scriptDir "bs_death_pipeline.py"

$resolvedOutput = [System.IO.Path]::GetFullPath((Join-Path (Get-Location).Path $OutputFbx))

$args = @()
if ($BlendPath) {
    $resolvedBlendInput = (Resolve-Path $BlendPath).Path
    $args += @("-b", $resolvedBlendInput)
} else {
    $args += "-b"
}

$args += @(
    "--python", $pipelineScript,
    "--",
    "--output-fbx", $resolvedOutput,
    "--clip-name", $ClipName,
    "--fps", "$Fps",
    "--duration-sec", "$DurationSec",
    "--min-duration-sec", "$MinDurationSec",
    "--max-duration-sec", "$MaxDurationSec",
    "--start-frame", "$StartFrame",
    "--drift-threshold", "$DriftThreshold"
)

if ($UseCurrentScene) {
    $args += "--use-current-scene"
} else {
    if (-not $InputFbx) {
        throw "InputFbx is required unless -UseCurrentScene is set."
    }
    $resolvedInput = (Resolve-Path $InputFbx).Path
    $args += @("--input-fbx", $resolvedInput)
}

if ($OutputBlend) {
    $resolvedBlend = [System.IO.Path]::GetFullPath((Join-Path (Get-Location).Path $OutputBlend))
    $args += @("--output-blend", $resolvedBlend)
}
if ($ArmatureName) { $args += @("--armature-name", $ArmatureName) }
if ($RootBone) { $args += @("--root-bone", $RootBone) }
if ($AutoBlock) { $args += "--auto-block" }
if ($ForceExport) { $args += "--force-export" }
if ($KeepScene) { $args += "--keep-scene" }

& $blenderWrapper -BlenderArgs $args
exit $LASTEXITCODE
