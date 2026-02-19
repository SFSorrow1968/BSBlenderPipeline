# Tools

## Blender Helpers

- `tools/blender.ps1`
- `tools/check_blender.ps1`
- `tools/bs_death_pipeline.ps1`
- `tools/bs_death_validate.ps1`
- `tools/render_death_preview.ps1`

## Agent Entrypoints

- `_agent/bootstrap-context.ps1`
- `_agent/test.ps1`
- `_agent/publish.ps1`
- `_agent/build-unity-content.ps1`
- `_agent/deploy-quest.ps1`
- `_agent/snapshot.ps1`
- `_agent/configure-remote.ps1`

## External Requirements

- Blender CLI (`blender.exe`)
- Unity 2021.3.38f1 editor with Android support for Nomad build
- .NET SDK for mod packaging (`dotnet`)
- Git + GitHub CLI (`gh`) for remote workflow
- Optional: `adb` for Quest deployment

