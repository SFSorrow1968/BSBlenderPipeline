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

## What Publish Does

1. Validates/exports the death clip from Blender.
2. Validates clip timing/drift markers.
3. Runs Unity batch content build for PCVR + Nomad.
4. Runs `CustomDeathAnimationMod` publish script.
5. Verifies resulting zip files contain required catalog/bundle entries.

## Optional Deployment

```powershell
powershell -ExecutionPolicy Bypass -File .\_agent\deploy-quest.ps1
```

