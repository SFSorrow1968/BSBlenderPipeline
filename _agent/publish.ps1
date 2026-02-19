param(
    [switch]$Force,
    [switch]$SkipBlender,
    [switch]$SkipUnity,
    [switch]$SkipModPublish,
    [string]$BlendPath = "work/Death_Male_A_3s.blend",
    [string]$OutputFbx = "exports/Death_Male_A_3s.fbx",
    [string]$OutputBlend = "work/Death_Male_A_3s.blend",
    [string]$ClipName = "Death_Male_A_3s",
    [string]$RootBone = "Hips",
    [int]$Fps = 60,
    [double]$DurationSec = 3.0,
    [int]$StartFrame = 1,
    [double]$DriftThreshold = 0.03
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$bsRoot = (Resolve-Path (Join-Path $repoRoot "..")).Path
$modRoot = Join-Path $bsRoot "Mods\CustomDeathAnimationMod"
$modPublishScript = Join-Path $modRoot "_agent\publish.ps1"

Set-Location $repoRoot

function Invoke-ScriptOrThrow {
    param(
        [string]$ScriptPath,
        [string[]]$Arguments = @()
    )
    & $ScriptPath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Script failed: $ScriptPath (exit code $LASTEXITCODE)"
    }
}

function Resolve-RepoPath {
    param([string]$RelativePath)
    return [System.IO.Path]::GetFullPath((Join-Path $repoRoot $RelativePath))
}

function Assert-ZipContainsRequiredEntries {
    param([string]$ZipPath)

    if (-not (Test-Path $ZipPath)) {
        throw "Zip file not found: $ZipPath"
    }

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $required = @(
        "manifest.json",
        "CustomDeathAnimationMod.dll",
        "catalog_CustomDeathAnimationMod.json",
        "catalog_CustomDeathAnimationMod.hash",
        "cdam_deathanimations_assets_all.bundle"
    )

    $zip = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
    try {
        $entryNames = @($zip.Entries | ForEach-Object { $_.FullName })
        foreach ($name in $required) {
            if (-not ($entryNames -contains $name)) {
                throw "Zip missing required entry '$name': $ZipPath"
            }
        }
    }
    finally {
        $zip.Dispose()
    }
}

if (Test-Path ".git") {
    Write-Host "1. Checking Git Status..." -ForegroundColor Cyan
    $status = git status --porcelain -uno
    if ($status) {
        if ($Force) {
            Write-Warning "Working tree is dirty. Continuing because -Force was specified."
        }
        else {
            throw "Working tree is dirty. Commit/stash changes or pass -Force."
        }
    }
}

if (-not $Force) {
    $answer = Read-Host "Proceed with publish pipeline? (y/n)"
    if ($answer -ne "y") {
        Write-Warning "Aborted by user."
        exit 0
    }
}

$resolvedBlend = Resolve-RepoPath -RelativePath $BlendPath
$resolvedOutputFbx = Resolve-RepoPath -RelativePath $OutputFbx
$resolvedOutputBlend = Resolve-RepoPath -RelativePath $OutputBlend

$blendDir = Split-Path -Parent $resolvedOutputBlend
$fbxDir = Split-Path -Parent $resolvedOutputFbx
if (-not (Test-Path $blendDir)) { New-Item -ItemType Directory -Path $blendDir -Force | Out-Null }
if (-not (Test-Path $fbxDir)) { New-Item -ItemType Directory -Path $fbxDir -Force | Out-Null }

$frameCount = [Math]::Ceiling($DurationSec * $Fps)
$endFrame = $StartFrame + [int]$frameCount - 1

if (-not $SkipBlender) {
    Write-Host "2. Blender export + validation..." -ForegroundColor Cyan

    $pipelineScript = Join-Path $repoRoot "tools\bs_death_pipeline.ps1"
    $validateScript = Join-Path $repoRoot "tools\bs_death_validate.ps1"

    Invoke-ScriptOrThrow -ScriptPath $pipelineScript -Arguments @(
        "-BlendPath", $resolvedBlend,
        "-UseCurrentScene",
        "-OutputFbx", $resolvedOutputFbx,
        "-OutputBlend", $resolvedOutputBlend,
        "-ClipName", $ClipName,
        "-RootBone", $RootBone,
        "-Fps", "$Fps",
        "-DurationSec", "$DurationSec",
        "-StartFrame", "$StartFrame",
        "-DriftThreshold", "$DriftThreshold"
    )

    Invoke-ScriptOrThrow -ScriptPath $validateScript -Arguments @(
        "-BlendPath", $resolvedOutputBlend,
        "-Action", $ClipName,
        "-RootBone", $RootBone,
        "-Fps", "$Fps",
        "-StartFrame", "$StartFrame",
        "-EndFrame", "$endFrame",
        "-DriftThreshold", "$DriftThreshold"
    )
}
else {
    Write-Host "2. Blender stage skipped." -ForegroundColor DarkYellow
}

if (-not $SkipUnity) {
    Write-Host "3. Unity content build..." -ForegroundColor Cyan
    $unityBuildScript = Join-Path $PSScriptRoot "build-unity-content.ps1"
    Invoke-ScriptOrThrow -ScriptPath $unityBuildScript
}
else {
    Write-Host "3. Unity stage skipped." -ForegroundColor DarkYellow
}

if (-not $SkipModPublish) {
    Write-Host "4. Mod publish/package..." -ForegroundColor Cyan
    if (-not (Test-Path $modPublishScript)) {
        throw "Missing mod publish script: $modPublishScript"
    }
    & $modPublishScript -Force
    if ($LASTEXITCODE -ne 0) {
        throw "Script failed: $modPublishScript (exit code $LASTEXITCODE)"
    }
}
else {
    Write-Host "4. Mod publish stage skipped." -ForegroundColor DarkYellow
}

Write-Host "5. Verify packaged zips..." -ForegroundColor Cyan
$manifestPath = Join-Path $modRoot "manifest.json"
if (-not (Test-Path $manifestPath)) {
    throw "Mod manifest not found: $manifestPath"
}
$manifest = Get-Content $manifestPath | ConvertFrom-Json
$version = $manifest.ModVersion

$nomadZip = Join-Path $modRoot ("CustomDeathAnimationMod_Nomad_v{0}.zip" -f $version)
$pcvrZip = Join-Path $modRoot ("CustomDeathAnimationMod_PCVR_v{0}.zip" -f $version)

Assert-ZipContainsRequiredEntries -ZipPath $nomadZip
Assert-ZipContainsRequiredEntries -ZipPath $pcvrZip

Write-Host "Publish pipeline complete." -ForegroundColor Green
Write-Host "Nomad zip: $nomadZip"
Write-Host "PCVR zip:  $pcvrZip"
