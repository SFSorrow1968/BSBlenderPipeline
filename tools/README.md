# Blender Automation Helpers

This folder includes CLI tooling for authoring Blade & Sorcery-compatible humanoid death clips.

## Environment checks

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\check_blender.ps1 -BlendPath .\Untitled.blend
```

## Blade & Sorcery death clip pipeline

Run this to import a humanoid FBX, create a death clip action, validate constraints, and export an FBX Unity can import as Humanoid:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\bs_death_pipeline.ps1 `
  -InputFbx .\assets\HumanMale_Complete_Model.fbx `
  -OutputFbx .\exports\Death_Generic_A.fbx `
  -OutputBlend .\work\Death_Generic_A.blend `
  -ClipName Death_Generic_A `
  -Fps 60 `
  -DurationSec 0.8 `
  -StartFrame 1 `
  -DriftThreshold 0.03 `
  -AutoBlock
```

If the humanoid is already in a `.blend`, run on the current scene instead of importing:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\bs_death_pipeline.ps1 `
  -BlendPath .\Untitled.blend `
  -UseCurrentScene `
  -OutputFbx .\exports\Death_Male_A.fbx `
  -OutputBlend .\work\Death_Male_A.blend `
  -ClipName Death_Male_A `
  -RootBone Hips `
  -Fps 60 `
  -DurationSec 0.8 `
  -StartFrame 1 `
  -DriftThreshold 0.03 `
  -AutoBlock
```

### Important flags

- `-AutoBlock`: generates a baseline impact/collapse/limp block automatically.
- `-OutputBlend`: saves a `.blend` for manual polish before final export.
- `-ForceExport`: exports even if validation flags issues.
- `-ArmatureName`: explicitly selects the armature object when import creates multiple rigs.
- `-RootBone`: explicit root/pelvis bone for drift locking and checks.

### Validation criteria enforced

- Clip duration in recommended range `0.5s` to `1.0s`.
- Timeline markers exist: `impact`, `collapse`, `limp`.
- Root XY drift stays below threshold (default `0.03`).

## Validate an authored clip in an existing blend

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\bs_death_validate.ps1 `
  -BlendPath .\your_scene.blend `
  -Action Death_Generic_A `
  -Fps 60 `
  -StartFrame 1 `
  -EndFrame 49 `
  -DriftThreshold 0.03
```

## Lower-level helpers

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\blender.ps1 -BlenderArgs @("--version")
```

## Render framed MP4 preview

This auto-frames the camera to the character (important for tiny imported rigs):

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\render_death_preview.ps1 `
  -BlendPath .\work\Death_Male_A.blend `
  -OutputMp4 .\renders\Death_Male_A_preview.mp4 `
  -StartFrame 1 `
  -EndFrame 49 `
  -Fps 60
```

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\render_animation.ps1 `
  -BlendPath .\Untitled.blend `
  -OutputPath .\renders\frame_#### `
  -FileFormat PNG `
  -StartFrame 1 `
  -EndFrame 120
```

## Notes

- `BLENDER_EXE` can force a specific `blender.exe`.
- Default expected install path: `C:\Program Files\Blender Foundation\Blender 5.0\blender.exe`.
- For Unity import, set rig to `Humanoid` and ensure clip is non-looping (`Loop Time` off).
