param(
    [string]$UnityExe = "",
    [string]$ProjectPath = "",
    [string]$ExecuteMethod = "CustomDeathAnimationMod.EditorTools.CustomDeathAnimationContentBuilder.BuildAndExportAll",
    [string]$LogPath = ""
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$bsRoot = (Resolve-Path (Join-Path $repoRoot "..")).Path

if (-not $ProjectPath) {
    $ProjectPath = Join-Path $bsRoot "SDK\BasSDK"
}

if (-not $LogPath) {
    $logDir = Join-Path $repoRoot "builds\logs"
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    $LogPath = Join-Path $logDir "unity-content-build.log"
}

function Resolve-UnityExe {
    param([string]$Provided)
    $candidates = @()
    if ($Provided -and (Test-Path $Provided)) { $candidates += $Provided }
    if ($env:UNITY_EXE -and (Test-Path $env:UNITY_EXE)) { $candidates += $env:UNITY_EXE }
    $candidates += @(
        "C:\Program Files\Unity 2021.3.38f1\Editor\Unity.exe",
        "D:\UnityHubEditors\2021.3.38f1\Editor\Unity.exe"
    )
    $cmd = Get-Command Unity.exe -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source -and (Test-Path $cmd.Source)) {
        $candidates += $cmd.Source
    }
    return ($candidates | Select-Object -Unique | Where-Object { Test-Path $_ } | Select-Object -First 1)
}

function Assert-RequiredFiles {
    param([string]$FolderPath)
    $required = @(
        "manifest.json",
        "CustomDeathAnimationMod.dll",
        "catalog_CustomDeathAnimationMod.json",
        "catalog_CustomDeathAnimationMod.hash",
        "cdam_deathanimations_assets_all.bundle"
    )
    foreach ($name in $required) {
        $full = Join-Path $FolderPath $name
        if (-not (Test-Path $full)) {
            throw "Required content artifact missing: $full"
        }
    }
}

$resolvedUnity = Resolve-UnityExe -Provided $UnityExe
if (-not $resolvedUnity) {
    throw "Unity editor not found. Set UNITY_EXE or install Unity 2021.3.38f1."
}

if (-not (Test-Path $ProjectPath)) {
    throw "Unity project path not found: $ProjectPath"
}

Write-Host "[unity] Editor: $resolvedUnity"
Write-Host "[unity] Project: $ProjectPath"
Write-Host "[unity] Method: $ExecuteMethod"
Write-Host "[unity] Log: $LogPath"

if (Test-Path $LogPath) {
    Remove-Item $LogPath -Force
}

$args = @(
    "-batchmode",
    "-nographics",
    "-quit",
    "-projectPath", $ProjectPath,
    "-executeMethod", $ExecuteMethod,
    "-logFile", $LogPath
)

$process = Start-Process -FilePath $resolvedUnity -ArgumentList $args -PassThru -Wait
if ($process.ExitCode -ne 0) {
    if (Test-Path $LogPath) {
        Write-Host "[unity] Tail of failed log:"
        Get-Content $LogPath -Tail 100 | Out-Host
    }
    throw "Unity content build failed with exit code $($process.ExitCode)."
}

if (-not (Test-Path $LogPath)) {
    throw "Unity log file was not created: $LogPath"
}

$success = Select-String -Path $LogPath -Pattern "\[CDAM-Content\] Build/export completed successfully\." -SimpleMatch:$false
if (-not $success) {
    throw "Unity log does not contain CDAM success marker: $LogPath"
}

$modRoot = Join-Path $bsRoot "Mods\CustomDeathAnimationMod\bin"
$pcvrFolder = Join-Path $modRoot "PCVR\CustomDeathAnimationMod"
$nomadFolder = Join-Path $modRoot "Nomad\CustomDeathAnimationMod"

$mode = "all"
if ($ExecuteMethod -match "BuildAndExportNomad") {
    $mode = "nomad"
}
elseif ($ExecuteMethod -match "BuildAndExportPcvr") {
    $mode = "pcvr"
}

if ($mode -eq "all" -or $mode -eq "pcvr") {
    Assert-RequiredFiles -FolderPath $pcvrFolder
}
if ($mode -eq "all" -or $mode -eq "nomad") {
    Assert-RequiredFiles -FolderPath $nomadFolder
}

switch ($mode) {
    "pcvr"  { Write-Host "[unity] Content build complete. Artifacts verified for PCVR." }
    "nomad" { Write-Host "[unity] Content build complete. Artifacts verified for Nomad." }
    default { Write-Host "[unity] Content build complete. Artifacts verified for PCVR + Nomad." }
}
