# 2026-07-13 Biome Plan UI Redesign

## Status

The dynamic UI architecture is locked and documented. Production UI
implementation has not started under this model.

The current row-oriented/global-draft UI is to be deleted and replaced. It is
not an ABI or migration source.

## Locked Decisions

- Route declarations own ordered biome sequences.
- One module-declared Lib control owns each route-biome occurrence.
- Each Biome Plan persists a decision tree of generated room occurrences.
- Stable `nodeId` identifies an occurrence; game room key identifies a
  declaration and may repeat.
- A selected parent occurrence owns one outgoing batch, all peer doors,
  selection semantics, batch rules, and batch-authored state.
- Generated unselected peers are fully modeled dead leaves.
- Registered room templates own occurrence-local schema, controls,
  completeness, candidates, feedback translation, and canonical fragments.
- Dynamic node/batch controls are cached logical children backed by their
  Biome Plan's physical storage.
- The route aggregate is a non-persistent coordinator, not a root serializer.
- Validation uses game-language source plus topology location.
- Ordinary generated-door/N acquisition is derived from selection; independent
  shop and wheel choices persist acquisition.
- Profile/reset changes invalidate derived state through the Lib commit
  lifecycle; explicit resync must provide the same signal.

## Verified Game Semantics

- Ordinary combat room keys are not universally unique.
- The same game room key can be created repeatedly and can occupy multiple
  offered doors.
- `MaxCreationsThisRun` is an explicit room declaration cap.
- Room creation count advances when each offered target room is created,
  including unselected peers.

Therefore occurrence-local authored state cannot be keyed globally by game
room key.

## Rewrite Entry Point

Start with Slice 1 of `../system_design/ui/UI_IMPLEMENTATION_ORDER.md`:

1. preserve only tests that express desired user-visible behavior;
2. remove production dependencies on the row-based UI and global
   `PlannerDraft`;
3. establish route-biome Lib controls and reload invalidation;
4. implement topology storage before rebuilding the full UI surface.

The first proof is F with topology, `StandardCombat`, profile roundtrip,
canonical materialization, and repeated-room-key coverage.

## Remaining Implementation Decisions

These are concrete design details, not open ownership questions:

- exact normalized Lib table/field declarations;
- node id allocation representation;
- exact Biome Plan and nested-control method names;
- whether Lib gains a general staged-state revision or a narrower explicit
  resync callback;
- exact module/file decomposition within the documented boundaries;
- which old UI interaction tests remain useful after the surface is removed.

## Authorities

- `../system_design/ui/BIOME_PLAN_CONTROL_MODEL.md`
- `../system_design/ui/FORM_STORAGE_ROUNDTRIP.md`
- `../system_design/ui/FORM_FEEDBACK_CONTRACT.md`
- `../system_design/ui/UI_IMPLEMENTATION_ORDER.md`
- `../system_design/model/CANONICAL_PLAN.md`
- `../system_design/validation/VALIDATION_MODEL.md`
