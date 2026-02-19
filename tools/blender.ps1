param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$BlenderArgs
)

$candidates = @()

if ($env:BLENDER_EXE -and (Test-Path $env:BLENDER_EXE)) {
    $candidates += $env:BLENDER_EXE
}

$knownPath = "C:\Program Files\Blender Foundation\Blender 5.0\blender.exe"
if (Test-Path $knownPath) {
    $candidates += $knownPath
}

$fromPath = Get-Command blender -ErrorAction SilentlyContinue
if ($fromPath -and $fromPath.Source -and (Test-Path $fromPath.Source)) {
    $candidates += $fromPath.Source
}

$exe = $candidates | Select-Object -Unique | Select-Object -First 1

if (-not $exe) {
    Write-Error "Unable to find blender.exe. Set BLENDER_EXE or install Blender."
    exit 1
}

& $exe @BlenderArgs
exit $LASTEXITCODE
