# Run Planner Docs

This folder separates stable system contracts from active work-in-progress
notes and raw game-data references.

## Stable System Design

- `system/ROUTE_HISTORY_PIPELINE.md`: route-history ownership boundary and hard
  invariants.
- `system/ROUTE_TIMING_MODEL.md`: vanilla timing and counter phase authority.
- `system/BIOME_DEPTH_AUDIT.md`: per-biome counter and room-cost reference.

## Work In Progress

- `wip/REWARD_GENERATION_MODEL.md`: reward bag, topology, and deferred Chaos
  design notes.
- `wip/VALIDATION_MESSAGE_AUDIT.md`: route-status and validation-message
  cleanup.
- `wip/REWARD_BUNDLE_AUDIT.md`: reward primitive/bundle/shop declaration audit.
- `wip/REWARD_CONDITION_AUDIT.md`: route-visible reward legality requirements.

## Game Data References

- `gameinfo/FORCE_AT_BIOME_DEPTH_AUDIT.md`: vanilla force-depth behavior.
- `gameinfo/PHYSICAL_EXIT_TOPOLOGY_AUDIT.md`: physical exit counts by biome.
- `gameinfo/rewardbag.txt`: community reward-bag reference notes.

Historical migration notes were culled from the docs tree. Use git history for
provenance when needed; do not keep stale design plans as live documentation.
