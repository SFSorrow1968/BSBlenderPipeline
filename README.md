# BS Blender Death Pipeline

Automation-first workflow for building Blade & Sorcery custom death animation content:

1. Author/validate clip in Blender.
2. Build Unity addressable content for PCVR + Nomad.
3. Publish `CustomDeathAnimationMod` packages with catalog + bundle + DLL.

## Quick Start

From `BS/Blender`:

```powershell
powershell -ExecutionPolicy Bypass -File .\_agent\test.ps1 -Strict
powershell -ExecutionPolicy Bypass -File .\_agent\publish.ps1 -Force
```

Optional Quest deployment:

```powershell
powershell -ExecutionPolicy Bypass -File .\_agent\deploy-quest.ps1
```

## Canonical Inputs/Outputs

- Blend source: `work/Death_Male_A_3s.blend`
- FBX export: `exports/Death_Male_A_3s.fbx`
- Unity project: `../SDK/BasSDK`
- Mod publish target: `../Mods/CustomDeathAnimationMod`

## Workflow Docs

- Human flow: `WORKFLOW.txt`
- Git policy: `_docs/GIT_WORKFLOW.md`
- Publish flow: `_docs/PUBLISH.md`
- Tooling: `_docs/TOOLS.md`
- Pipeline map: `_docs/PIPELINE.md`

