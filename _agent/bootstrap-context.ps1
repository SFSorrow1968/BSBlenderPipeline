param(
    [string]$Feature
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$visionsDir = Join-Path $repoRoot "_visions"
$quirksDir = Join-Path $repoRoot "_quirks"
$resourcesDir = Join-Path $repoRoot "_resources"

foreach ($dir in @($visionsDir, $quirksDir, $resourcesDir)) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir | Out-Null
        Write-Host "[bootstrap] Created $dir"
    }
}

$scratchpadPath = Join-Path $repoRoot "SCRATCHPAD.md"
if (-not (Test-Path $scratchpadPath)) {
    @"
# Agent Scratchpad

## Current Focus
- Goal:
- Status:

## Context Stack
- Key files:
- Notes:

## Next Steps / Handoff
1. [ ]
2. [ ]

### Last Updated
- Agent:
- Date:
"@ | Set-Content -Path $scratchpadPath -Encoding ascii
    Write-Host "[bootstrap] Created $scratchpadPath"
}

if ($Feature -and $Feature.Trim().Length -gt 0) {
    $safe = [System.IO.Path]::GetFileNameWithoutExtension($Feature).Trim()
    if ($safe.Length -eq 0) {
        throw "Feature name is empty after normalization."
    }

    $files = @(
        @{ Path = (Join-Path $visionsDir   ("{0}_VISION.md" -f $safe));   Title = "Vision" },
        @{ Path = (Join-Path $quirksDir    ("{0}_QUIRKS.md" -f $safe));   Title = "Quirks" },
        @{ Path = (Join-Path $resourcesDir ("{0}_RESOURCES.md" -f $safe)); Title = "Resources" }
    )

    foreach ($file in $files) {
        if (-not (Test-Path $file.Path)) {
            @"
# $safe $($file.Title)

## Purpose

## Constraints

## Notes
"@ | Set-Content -Path $file.Path -Encoding ascii
            Write-Host "[bootstrap] Created $($file.Path)"
        }
    }
}

Write-Host "[bootstrap] Context scaffold complete."

