# Publish Workflow

## Purpose

Produce deployable `CustomDeathAnimationMod` PCVR + Nomad packages that include:

- animation DLL
- addressable catalog/hash
- death animation bundle

## Command

From `BS/Blender`:

```powershell
powershell -ExecutionPolicy Bypass -File .\_agent\publish.ps1 -Force
```

To include PCVR content rebuild in the same run:

```powershell
powershell -ExecutionPolicy Bypass -File .\_agent\publish.ps1 -Force -IncludePcvr
```

## What Publish Does

1. Validates/exports the death clip from Blender.
   - Default clip duration target in this workflow is `3.0s` (validation range `0.5s` to `4.0s`).
2. Validates clip timing/drift markers.
3. Runs Unity batch content build for Nomad (and PCVR when `-IncludePcvr` is set).
4. Runs `CustomDeathAnimationMod` publish script.
5. Verifies resulting zip files contain required catalog/bundle entries.

## Optional Deployment

```powershell
powershell -ExecutionPolicy Bypass -File .\_agent\deploy-quest.ps1
```
