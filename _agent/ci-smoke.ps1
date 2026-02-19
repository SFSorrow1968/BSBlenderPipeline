param(
    [switch]$Strict
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$bsRoot = (Resolve-Path (Join-Path $repoRoot "..")).Path

$blendPath = Join-Path $repoRoot "work\Death_Male_A_3s.blend"
$builderScript = Join-Path $bsRoot "SDK\BasSDK\Assets\Personal\Editor\CustomDeathAnimationContentBuilder.cs"
$clipPath = Join-Path $bsRoot "SDK\BasSDK\Assets\SDK\Examples\Characters\Sources\Animations\Death\Clips\Death_Male_A_3s.anim"
$modPublishScript = Join-Path $bsRoot "Mods\CustomDeathAnimationMod\_agent\publish.ps1"
$blenderCheckScript = Join-Path $repoRoot "tools\check_blender.ps1"

$issues = New-Object System.Collections.Generic.List[string]

function Register-Issue {
    param([string]$Message)
    $issues.Add($Message) | Out-Null
    if ($Strict) {
        Write-Error $Message
    }
    else {
        Write-Warning $Message
    }
}

function Require-Path {
    param(
        [string]$PathValue,
        [string]$Label
    )
    if (-not (Test-Path $PathValue)) {
        Register-Issue "[CI] Missing $Label at $PathValue"
    }
    else {
        Write-Host "[CI] Found $Label"
    }
}

function Resolve-UnityExe {
    $candidates = @()
    if ($env:UNITY_EXE -and (Test-Path $env:UNITY_EXE)) { $candidates += $env:UNITY_EXE }

    $candidates += @(
        "D:\UnityHubEditors\2021.3.38f1\Editor\Unity.exe",
        "C:\Program Files\Unity 2021.3.38f1\Editor\Unity.exe"
    )

    $cmd = Get-Command Unity.exe -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source -and (Test-Path $cmd.Source)) {
        $candidates += $cmd.Source
    }

    return ($candidates | Select-Object -Unique | Where-Object { Test-Path $_ } | Select-Object -First 1)
}

Write-Host "[CI] Running Blender/Unity smoke checks..."

Require-Path -PathValue $blendPath -Label "source blend"
Require-Path -PathValue $builderScript -Label "Unity content builder script"
Require-Path -PathValue $clipPath -Label "Unity animation clip asset"
Require-Path -PathValue $modPublishScript -Label "CDAM mod publish script"
Require-Path -PathValue $blenderCheckScript -Label "Blender check script"

$unityExe = Resolve-UnityExe
if (-not $unityExe) {
    Register-Issue "[CI] Unity editor not found. Set UNITY_EXE or install Unity 2021.3.38f1."
}
else {
    Write-Host "[CI] Unity editor: $unityExe"
}

if ((Test-Path $blenderCheckScript) -and (Test-Path $blendPath)) {
    & powershell -ExecutionPolicy Bypass -File $blenderCheckScript -BlendPath $blendPath
    if ($LASTEXITCODE -ne 0) {
        Register-Issue "[CI] Blender environment check failed with exit code $LASTEXITCODE"
    }
}

if ($Strict -and $issues.Count -gt 0) {
    throw "[CI] Strict smoke checks failed with $($issues.Count) issue(s)."
}

if ($issues.Count -eq 0) {
    Write-Host "[CI] Smoke checks complete: PASS"
}
else {
    Write-Warning "[CI] Smoke checks complete with warnings: $($issues.Count)"
}

exit 0
