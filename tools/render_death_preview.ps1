param(
    [Parameter(Mandatory = $true)]
    [string]$BlendPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputMp4,

    [int]$StartFrame = -1,
    [int]$EndFrame = -1,
    [int]$Fps = 60,
    [int]$ResolutionX = 1280,
    [int]$ResolutionY = 720
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$blenderWrapper = Join-Path $scriptDir "blender.ps1"
$previewScript = Join-Path $scriptDir "render_death_preview.py"

$resolvedBlend = (Resolve-Path $BlendPath).Path
$resolvedOutput = [System.IO.Path]::GetFullPath((Join-Path (Get-Location).Path $OutputMp4))
$outputDir = Split-Path -Parent $resolvedOutput
$baseName = [System.IO.Path]::GetFileNameWithoutExtension($resolvedOutput)
$tmpFramesDir = Join-Path $outputDir ($baseName + "_frames")
$tmpPattern = Join-Path $tmpFramesDir "frame_####"

if (-not (Test-Path $tmpFramesDir)) {
    New-Item -ItemType Directory -Path $tmpFramesDir -Force | Out-Null
}

$args = @(
    "-b", $resolvedBlend,
    "--python", $previewScript,
    "--",
    "--output-pattern", $tmpPattern,
    "--fps", "$Fps",
    "--resolution-x", "$ResolutionX",
    "--resolution-y", "$ResolutionY"
)

if ($StartFrame -ge 0) { $args += @("--start-frame", "$StartFrame") }
if ($EndFrame -ge 0) { $args += @("--end-frame", "$EndFrame") }

& $blenderWrapper -BlenderArgs $args
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$ffmpegInput = Join-Path $tmpFramesDir "frame_%04d.png"
ffmpeg -y -framerate $Fps -i $ffmpegInput -c:v libx264 -pix_fmt yuv420p $resolvedOutput | Out-Null
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# Cleanup temporary image sequence.
Remove-Item -Path $tmpFramesDir -Recurse -Force
exit 0
