# 2026-07-06 Fresh Spine Checkpoint

## Status

The fresh planner branch now has a clean active skeleton.

Completed child commits:

- `a019143 docs: add fresh planner model`
- `e3cd445 refactor!: reset planner skeleton`

Completed shell commit:

- `6cd69fb chore: point planner to fresh spine`

## What Changed

- Fresh system docs were authored under `docs/system_design/`.
- Old `docs/system/` and `docs/wip/` notes were removed from the live docs
  tree because they described the old implementation or transient migration
  work.
- Legacy planner source and old tests were removed from the active branch.
- The Run Planner module now exposes a minimal loadable skeleton:
  - empty control templates;
  - empty route controls;
  - no-op logic attach;
  - a simple tab message pointing to `docs/system_design/`.

## Validation

Child repo:

```text
lua tests/all.lua
luacheck src tests
git diff --cached --check
```

Shell repo:

```text
lua tests/smoke.lua
```

All checks passed at the skeleton checkpoint.

## Current Boundary

The branch intentionally has no planner behavior yet. The old row-based route,
reward, biome, NPC, feature, and validation machinery is not wired.

The next implementation work should start from
`docs/system_design/migration/IMPLEMENTATION_SEQUENCE.md`, beginning with the
fresh skeleton and declaration foundation phases.
