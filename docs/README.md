# Run Planner Docs

This folder separates stable system design from implementation progress and
raw game-data references.

## System Design

`system_design/` is the durable architecture source of truth for the fresh
planner model.

Edit these docs only when the intended system model changes. Do not use them as
a running implementation log.

Notable model authorities:

- `system_design/validation/FORCE_PRESSURE_MODEL.md`: force-pressure
  declaration and generated-door batch validation semantics.
- `system_design/ui/UI_IMPLEMENTATION_ORDER.md`: production UI build order,
  draw-state constraints, and control-layer rollout.
- `system_design/ui/FORM_STORAGE_ROUNDTRIP.md`: form-to-draft-to-storage
  serialization boundaries for production UI forms.

## Progress

`progress/` records implementation checkpoints, validation runs, known gaps,
and next slices.

Progress docs may point back to system design docs. System design docs should
only point to progress docs through intentional appendices or stable tracker
links.

## Game Data References

- `gameinfo/FORCE_AT_BIOME_DEPTH_AUDIT.md`: vanilla force-depth behavior.
- `gameinfo/PHYSICAL_EXIT_TOPOLOGY_AUDIT.md`: physical exit counts by biome.
- `gameinfo/rewardbag.txt`: community reward-bag reference notes.

Historical migration notes were culled from the docs tree. Use git history for
provenance when needed; do not keep stale design plans as live documentation.
