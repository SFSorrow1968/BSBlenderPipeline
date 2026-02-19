# Agent Instructions

## 1. Central Plan

1. Read `SCRATCHPAD.md` first.
2. For each touched pipeline feature, maintain companion docs:
   - `_visions/<Feature>_VISION.md`
   - `_quirks/<Feature>_QUIRKS.md`
   - `_resources/<Feature>_RESOURCES.md`
3. If companions are missing, run:
   - `./_agent/bootstrap-context.ps1`
   - `./_agent/bootstrap-context.ps1 -Feature "<FeatureName>"`

## 2. Required Workflow

1. `./_agent/test.ps1 -Strict`
2. `./_agent/publish.ps1 -Force`
3. `./_agent/snapshot.ps1 -Message "snapshot: <topic>"`

## 3. Git Rules

- Before commit/push/tag, read `_docs/GIT_WORKFLOW.md`.
- Never force-update old snapshot tags/branches.

## 4. Sync Rule

- If `AGENTS.md` changes, sync the same content to `GEMINI.md` and `CLAUDE.md`.

## 5. Session Handoff

- Update `SCRATCHPAD.md` before ending:
  - Current status
  - What was changed
  - Exact next actions

