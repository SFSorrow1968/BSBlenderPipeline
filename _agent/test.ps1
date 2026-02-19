param(
    [switch]$Strict
)

$ErrorActionPreference = "Stop"

$ciScript = Join-Path $PSScriptRoot "ci-smoke.ps1"
if (-not (Test-Path $ciScript)) {
    throw "Missing script: $ciScript"
}

if ($Strict) {
    & $ciScript -Strict
}
else {
    & $ciScript
}

if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

Write-Host "[test] Smoke checks completed."

