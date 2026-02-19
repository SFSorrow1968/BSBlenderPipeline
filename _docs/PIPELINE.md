# Pipeline Map

This repository orchestrates a three-stage content workflow.

## Stage 1: Blender Authoring

- Source blend: `work/Death_Male_A_3s.blend`
- Export script: `tools/bs_death_pipeline.ps1`
- Validation script: `tools/bs_death_validate.ps1`
- Default FBX output: `exports/Death_Male_A_3s.fbx`

## Stage 2: Unity Content Build

- Unity project: `../SDK/BasSDK`
- Builder script asset:
  - `Assets/Personal/Editor/CustomDeathAnimationContentBuilder.cs`
- Execute method:
  - `CustomDeathAnimationMod.EditorTools.CustomDeathAnimationContentBuilder.BuildAndExportAll`
- Workflow default editor split:
  - PCVR: `C:\Program Files\Unity 2021.3.38f1\Editor\Unity.exe`
  - Nomad: `D:\UnityHubEditors\2021.3.38f1\Editor\Unity.exe`
- Expected outputs:
  - `../Mods/CustomDeathAnimationMod/bin/PCVR/CustomDeathAnimationMod/*`
  - `../Mods/CustomDeathAnimationMod/bin/Nomad/CustomDeathAnimationMod/*`

## Stage 3: Mod Packaging

- Mod repo: `../Mods/CustomDeathAnimationMod`
- Publish script:
  - `../Mods/CustomDeathAnimationMod/_agent/publish.ps1 -Force`
- Expected zip artifacts:
  - `CustomDeathAnimationMod_PCVR_v<version>.zip`
  - `CustomDeathAnimationMod_Nomad_v<version>.zip`

## Required Nomad Bundle Contents

- `manifest.json`
- `CustomDeathAnimationMod.dll`
- `catalog_CustomDeathAnimationMod.json`
- `catalog_CustomDeathAnimationMod.hash`
- `cdam_deathanimations_assets_all.bundle`
