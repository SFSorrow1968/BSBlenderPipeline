param(
    [switch]$Force,
    [switch]$IncludePcvr,
    [switch]$SkipBlender,
    [switch]$SkipUnity,
    [switch]$SkipModPublish,
    [string]$BlendPath = "work/Death_Male_A_3s.blend",
    [string]$OutputFbx = "exports/Death_Male_A_3s.fbx",
    [string]$OutputBlend = "",
    [string]$ClipName = "Death_Male_A_3s",
    [string]$RootBone = "Hips",
    [int]$Fps = 60,
    [double]$DurationSec = 3.0,
    [int]$StartFrame = 1,
    [double]$DriftThreshold = 0.03,
    [double]$MinDurationSec = 0.5,
    [double]$MaxDurationSec = 4.0
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$bsRoot = (Resolve-Path (Join-Path $repoRoot "..")).Path
$modRoot = Join-Path $bsRoot "Mods\CustomDeathAnimationMod"
$modPublishScript = Join-Path $modRoot "_agent\publish.ps1"

Set-Location $repoRoot

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
$resolvedOutputBlend = if ($OutputBlend) { Resolve-RepoPath -RelativePath $OutputBlend } else { $resolvedBlend }

$fbxDir = Split-Path -Parent $resolvedOutputFbx
if (-not (Test-Path $fbxDir)) { New-Item -ItemType Directory -Path $fbxDir -Force | Out-Null }
if ($OutputBlend) {
    $blendDir = Split-Path -Parent $resolvedOutputBlend
    if (-not (Test-Path $blendDir)) { New-Item -ItemType Directory -Path $blendDir -Force | Out-Null }
}

$frameCount = [Math]::Ceiling($DurationSec * $Fps)
$endFrame = $StartFrame + [int]$frameCount - 1

if (-not $SkipBlender) {
    Write-Host "2. Blender export + validation..." -ForegroundColor Cyan

    $pipelineScript = Join-Path $repoRoot "tools\bs_death_pipeline.ps1"
    $validateScript = Join-Path $repoRoot "tools\bs_death_validate.ps1"

    $pipelineArgs = @{
        BlendPath = $resolvedBlend
        UseCurrentScene = $true
        OutputFbx = $OutputFbx
        ClipName = $ClipName
        RootBone = $RootBone
        Fps = $Fps
        DurationSec = $DurationSec
        MinDurationSec = $MinDurationSec
        MaxDurationSec = $MaxDurationSec
        StartFrame = $StartFrame
        DriftThreshold = $DriftThreshold
    }
    if ($OutputBlend) {
        $pipelineArgs.OutputBlend = $OutputBlend
    }

    & $pipelineScript @pipelineArgs
    if ($LASTEXITCODE -ne 0) {
        throw "Blender pipeline failed (exit code $LASTEXITCODE)."
    }

    & $validateScript `
        -BlendPath $resolvedOutputBlend `
        -Action $ClipName `
        -RootBone $RootBone `
        -Fps $Fps `
        -StartFrame $StartFrame `
        -EndFrame $endFrame `
        -MinDurationSec $MinDurationSec `
        -MaxDurationSec $MaxDurationSec `
        -DriftThreshold $DriftThreshold
    if ($LASTEXITCODE -ne 0) {
        throw "Blender validation failed (exit code $LASTEXITCODE)."
    }
}
else {
    Write-Host "2. Blender stage skipped." -ForegroundColor DarkYellow
}

if (-not $SkipUnity) {
    Write-Host "3. Unity content build..." -ForegroundColor Cyan
    $unityBuildScript = Join-Path $PSScriptRoot "build-unity-content.ps1"
    $pcvrUnity = "C:\Program Files\Unity 2021.3.38f1\Editor\Unity.exe"
    $nomadUnity = "D:\UnityHubEditors\2021.3.38f1\Editor\Unity.exe"

    if ($IncludePcvr) {
        $pcvrLog = Join-Path $repoRoot "builds\logs\unity-content-build-pcvr.log"
        if (Test-Path $pcvrUnity) {
            & $unityBuildScript `
                -UnityExe $pcvrUnity `
                -ExecuteMethod "CustomDeathAnimationMod.EditorTools.CustomDeathAnimationContentBuilder.BuildAndExportPcvr" `
                -LogPath $pcvrLog
        }
        else {
            & $unityBuildScript `
                -ExecuteMethod "CustomDeathAnimationMod.EditorTools.CustomDeathAnimationContentBuilder.BuildAndExportPcvr" `
                -LogPath $pcvrLog
        }
        if ($LASTEXITCODE -ne 0) {
            throw "Unity PCVR content stage failed (exit code $LASTEXITCODE)."
        }
    }
    else {
        Write-Host "3a. PCVR content build skipped (pass -IncludePcvr to enable)." -ForegroundColor DarkYellow
    }

    $nomadLog = Join-Path $repoRoot "builds\logs\unity-content-build-nomad.log"
    if (Test-Path $nomadUnity) {
        & $unityBuildScript `
            -UnityExe $nomadUnity `
            -ExecuteMethod "CustomDeathAnimationMod.EditorTools.CustomDeathAnimationContentBuilder.BuildAndExportNomad" `
            -LogPath $nomadLog
    }
    else {
        & $unityBuildScript `
            -ExecuteMethod "CustomDeathAnimationMod.EditorTools.CustomDeathAnimationContentBuilder.BuildAndExportNomad" `
            -LogPath $nomadLog
    }
    if ($LASTEXITCODE -ne 0) {
        throw "Unity Nomad content stage failed (exit code $LASTEXITCODE)."
    }
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
