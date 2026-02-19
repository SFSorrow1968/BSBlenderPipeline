param(
    [Parameter(Mandatory = $true)]
    [string]$BlendPath,
    [string]$Action = "",
    [int]$Fps = 60,
    [int]$StartFrame = 1,
    [int]$EndFrame = 49,
    [double]$DriftThreshold = 0.03,
    [string]$RootBone = ""
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$blenderWrapper = Join-Path $scriptDir "blender.ps1"
$validatorScript = Join-Path $scriptDir "bs_death_validate.py"

$resolvedBlend = (Resolve-Path $BlendPath).Path

$args = @(
    "-b", $resolvedBlend,
    "--python", $validatorScript,
    "--",
    "--fps", "$Fps",
    "--start-frame", "$StartFrame",
    "--end-frame", "$EndFrame",
    "--drift-threshold", "$DriftThreshold"
)

if ($Action) { $args += @("--action", $Action) }
if ($RootBone) { $args += @("--root-bone", $RootBone) }

& $blenderWrapper -BlenderArgs $args
exit $LASTEXITCODE
