param(
    [string]$SourceFolder = "",
    [string]$TargetModName = "CustomDeathAnimationMod",
    [string]$AdbExe = ""
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$bsRoot = (Resolve-Path (Join-Path $repoRoot "..")).Path

if (-not $SourceFolder) {
    $SourceFolder = Join-Path $bsRoot "Mods\CustomDeathAnimationMod\bin\Nomad\CustomDeathAnimationMod"
}

function Resolve-Adb {
    param([string]$Provided)
    $candidates = @()
    if ($Provided -and (Test-Path $Provided)) { $candidates += $Provided }
    if ($env:ADB_EXE -and (Test-Path $env:ADB_EXE)) { $candidates += $env:ADB_EXE }
    if ($env:ANDROID_SDK_ROOT) {
        $sdkAdb = Join-Path $env:ANDROID_SDK_ROOT "platform-tools\adb.exe"
        if (Test-Path $sdkAdb) { $candidates += $sdkAdb }
    }
    $candidates += @(
        (Join-Path $env:LOCALAPPDATA "Android\Sdk\platform-tools\adb.exe"),
        "D:\UnityHubEditors\2021.3.38f1\Editor\Data\PlaybackEngines\AndroidPlayer\SDK\platform-tools\adb.exe"
    )
    $cmd = Get-Command adb.exe -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source -and (Test-Path $cmd.Source)) {
        $candidates += $cmd.Source
    }
    return ($candidates | Select-Object -Unique | Where-Object { Test-Path $_ } | Select-Object -First 1)
}

if (-not (Test-Path $SourceFolder)) {
    throw "Source folder not found: $SourceFolder"
}

$resolvedAdb = Resolve-Adb -Provided $AdbExe
if (-not $resolvedAdb) {
    throw "adb.exe not found. Install Android platform-tools or set ADB_EXE."
}

Write-Host "[deploy] adb: $resolvedAdb"
Write-Host "[deploy] source: $SourceFolder"

& $resolvedAdb start-server | Out-Host
$devices = & $resolvedAdb devices
$online = @($devices | Select-String "device$" | ForEach-Object { $_.Line.Split("`t")[0] })
if ($online.Count -eq 0) {
    throw "No online adb devices found."
}

$target = "/sdcard/Android/data/com.Warpfrog.BladeAndSorcery/files/Mods/$TargetModName"
Write-Host "[deploy] target: $target"

& $resolvedAdb shell "rm -rf '$target' && mkdir -p '$target'" | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "Failed to create target folder on device."
}

& $resolvedAdb push "$SourceFolder/." "$target/" | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "adb push failed."
}

Write-Host "[deploy] Complete. Launch game and verify Player.log contains [CDAM] entries."

