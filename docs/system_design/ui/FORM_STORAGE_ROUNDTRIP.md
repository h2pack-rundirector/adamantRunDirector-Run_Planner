# Biome Plan Storage Roundtrip Contract

## Purpose

This document defines how the dynamic biome decision tree is stored through
ModpackLib's static control surface.

The persistence path is:

```text
nested node or batch control
-> Biome Plan mutation method
-> Biome Plan-owned normalized storage
-> normal Lib commit/profile lifecycle
```

The load path is:

```text
Lib staged storage
-> Biome Plan storage decoder
-> topology and typed occurrence views
-> cached nested node and batch controls
```

There is no global `PlannerDraft` document and no separately registered Lib
control for each dynamic room occurrence.

## Physical Control Boundary

Lib sees one persistent control per declared route-biome occurrence, such as
`Underworld_F` or `Surface_N`.

That Biome Plan control is the physical owner of:

- biome-scoped authored fields;
- topology nodes and the root id;
- outgoing batches, peer doors, and selections;
- occurrence-local typed state keyed by stable `nodeId`;
- storage decoding, invariant checks, and reset behavior.

Nested node and batch controls are logical owners. They expose typed operations
over rows owned by their Biome Plan. They are cached objects, not module-level
Lib controls, independent profile roots, or detached mutable draft tables.

The route aggregate composes Biome Plan controls in route order. It does not
own another serialized copy of their state.

## Normalized Storage Shape

The semantic value is a tree. The physical storage can remain normalized and
static so every table/field is declared before module activation:

```text
BiomeState
Nodes
OutgoingBatches
Doors
StandardCombatState
FieldsCombatState
ShipCombatState
EphyraCombatState
ShopState
...
```

Representative ownership:

| Storage | Key | Semantic owner |
| --- | --- | --- |
| `BiomeState` | control singleton | Biome Plan |
| `Nodes` | `nodeId` | topology occurrence |
| `OutgoingBatches` | parent `nodeId` | parent occurrence |
| `Doors` | parent `nodeId`, `doorIndex` | outgoing batch |
| typed state table | `nodeId` | nested room-template control |

Topology rows persist occurrence identity and references. Declaration-derived
facts such as room template, room kind, exits, tags, and labels are not copied
into storage.

The storage schema may use implementation-specific row ids, but those row ids
must not become planner identity. All semantic joins use stable `nodeId` and
explicit parent/door references.

## Codec Ownership

The Biome Plan control orchestrates the codec but does not hand-code every
room payload.

- the topology codec owns nodes, outgoing batches, doors, and selection;
- biome-specific codecs own biome-scoped and batch-specific fields;
- each registered room template owns its occurrence-state fragment;
- reusable reward, payload, shop, encounter, and side-room components own
  their subfragments.

Reading a node resolves its room declaration, then dispatches to the registered
room-template codec. Unknown templates, orphan typed rows, broken references,
and incompatible state must fail at the storage/materialization boundary.

## Mutation And Atomicity

Biome Plan methods are the only write boundary. Inner widgets may call a nested
control, but the nested control delegates coherent writes to its owner.

Examples:

- replacing a door target creates or replaces the target occurrence and its
  template state together;
- removing a door removes the downstream branch and all typed rows owned by
  that branch;
- changing a reward store resets incompatible reward type and payload fields;
- changing a batch rule resets incompatible selection and batch state;
- replacing a room key preserves the `nodeId` only when the operation can
  reinitialize the occurrence coherently.

Storage must never observe a topology edit without its corresponding typed
state cleanup, or a typed-state edit addressed to a removed occurrence.

## Profile, Commit, And Reset Semantics

Profile load and reset use Lib's normal staged-storage and commit lifecycle.
Cached nested controls remain valid because they resolve through the same
Biome Plan owner rather than retaining copied values.

The planner maintains a non-persisted change epoch. A committed configuration
change invalidates materialization, history, validation, candidates, and
feedback once. There is no persisted `Revision` field.

Any explicit reload/resync API that bypasses the normal commit callback must
still advance the same invalidation signal. This is a host contract to confirm
during implementation, not a reason to poll or compare the entire tree during
draw.

Reset operations are deliberately scoped:

```lua
ui.controls.reset("Underworld_F") -- whole biome plan
biomePlan:resetNode(nodeId)        -- one occurrence and owned descendants/state
```

A node reset dispatches through the room template. It must not reset another
occurrence merely because both reference the same game room key.

## Persisted And Derived State

Persist authored decisions required to reproduce the plan:

- topology node identity and game room key;
- outgoing peer doors and exit indexes;
- selection mode and selected/ordered doors;
- batch-authored decisions;
- biome-scoped authored decisions;
- typed occurrence-local room, reward, payload, encounter, shop, and side-room
  state.

Do not persist:

- room declaration facts or resolved room-template names;
- canonical plan copies;
- materialized history, counters, ledgers, or reward bags;
- validation findings and first-error summaries;
- candidate hidden/color/message arrays;
- catalog-derived labels and stable option values;
- navigation caches, cached node objects, or ImGui ids;
- dirty epochs or provider versions.

All derived values rebuild from stored Biome Plan state plus declarations.

## Dormant State

Generated but unselected nodes are part of the tree and are persisted exactly
like selected nodes. Their state may be edited and profiled, but they are dead
leaves and cannot own outgoing batches.

State rows not referenced by the current tree are not dormant plan data; they
are malformed/orphan storage and should be rejected or removed by the owning
mutation before commit.

## Roundtrip Tests

Each topology and template slice needs focused tests proving:

- empty staged storage creates the declared default biome plan;
- node ids survive a write/read roundtrip;
- two occurrences of the same game room key keep independent typed state;
- generated unselected peers roundtrip and remain dead leaves;
- selected and ordered-subset batch state roundtrips;
- branch removal removes only that branch's typed rows;
- parent changes clear incompatible child state atomically;
- whole-biome and single-node resets have distinct scope;
- profile load preserves cached control usability and invalidates derived data;
- canonical/history/feedback caches are absent from persistence and rebuild;
- malformed references and orphan typed rows fail at the boundary.

## Supporting Docs

- `BIOME_PLAN_CONTROL_MODEL.md` owns the semantic tree and control boundaries.
- `FORM_FEEDBACK_CONTRACT.md` owns completeness, candidates, addresses, and
  feedback.
- `UI_IMPLEMENTATION_ORDER.md` owns the rewrite sequence.
- `../model/CANONICAL_PLAN.md` owns materialized output.
