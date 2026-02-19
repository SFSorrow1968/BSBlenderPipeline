# Git Workflow

## 1. Source Of Truth

- Before `git commit`, `git push`, or `git tag`, read this file.
- Do not improvise snapshot naming.

## 2. Branch Strategy

- Do not commit directly to long-lived release branches.
- Work on feature branches (example: `agent/<topic>`).
- For each stable pipeline milestone, create a new immutable snapshot branch:
  - `agent/snapshot-<YYYYMMDD-HHMMSS>-<topic>`

## 3. Snapshot Workflow

1. Run `_agent/test.ps1 -Strict`.
2. Run `_agent/publish.ps1 -Force`.
3. Commit on your working branch.
4. Push working branch.
5. Create and push a new snapshot branch from that commit.
6. Create and push a new snapshot tag:
   - `snapshot-<YYYYMMDD-HHMMSS>`

## 4. Forbidden Actions

- No force-pushing over older snapshot branches.
- No force-updating old snapshot tags.
- No reusing snapshot tag names.

