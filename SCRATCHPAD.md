# Agent Scratchpad

## Current Focus
- Goal: Stabilize Blender -> Unity -> CDAM publish workflow with one-command automation.
- Status: Bootstrap complete.

## Context Stack
- Source blend: `work/Death_Male_A_3s.blend`
- Unity build method: `CustomDeathAnimationMod.EditorTools.CustomDeathAnimationContentBuilder.BuildAndExportAll`
- Mod output root: `../Mods/CustomDeathAnimationMod/bin`

## Next Steps / Handoff
1. [ ] Run `_agent/test.ps1 -Strict` and resolve any environment misses.
2. [ ] Run `_agent/publish.ps1 -Force`.
3. [ ] Optional: run `_agent/deploy-quest.ps1` to test on headset.

### Last Updated
- Agent: Codex
- Date: 2026-02-19

