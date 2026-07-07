# Form Storage Roundtrip Contract

## Purpose

Forms are editable object views over draft nodes. They are not independent Lib
control instances and they do not write storage rows directly.

The persistence path is:

```text
form participant
-> planner-state mutator
-> mutable draft node
-> PlannerDraft:writeDraft(...)
-> normalized flat storage rows
```

The load path is the reverse:

```text
PlannerDraft:readDraft(...)
-> mutable draft node
-> form participant
```

Every production form must have a clear draft node, owning mutator surface, and
storage representation. Derived UI/validation data rebuilds from the draft and
must not be serialized.

## Storage Boundary

`PlannerDraft` is the serialization boundary for the editable route draft.

It owns normalized storage tables and exposes:

```lua
control:readDraft() -> draft
control:writeDraft(draft) -> changed
control:revision() -> integer
```

Production draw code binds planner state to `ui.controls.get("PlannerDraft")`.
After binding, existing planner-state mutators remain the only write path. Forms
must not call `PlannerDraft:writeDraft(...)` directly.

This keeps parent-child consistency in one mutable draft object before the draft
is serialized.

`revision()` is adapter metadata, not route draft data. It lets planner state
detect that an already-bound control was externally reset or rewritten and then
reload the editable draft from storage on the next bind pass.

## Current F Roundtrip Map

| Form participant | Draft node | Owning mutators | Storage rows |
| --- | --- | --- | --- |
| route shell active route | public UI state, not route draft | route-shell storage helpers | `SelectedRoute` |
| route shell active biome | public UI state, not route draft | route-shell storage helpers | `SelectedUnderworldBiome`, `SelectedSurfaceBiome` |
| F biome panel | `draft.biomes[1]` | current F panel composition | `Rooms.BiomeIndex`, `Rooms.BiomeKey`, plus child rows |
| room unit | `draft.biomes[1].rooms[roomIndex]` | `setRoomKey`, `appendSelectedTarget`, `removeLastRoom` | `Rooms` |
| generated door batch | `room.generatedDoors` | `setSelectedDoor`, room-key reset materialization | `Rooms.SelectedDoorIndex`, `Rooms.BatchRule` |
| generated door | `room.generatedDoors.doors[doorIndex]` | `setDoorTarget` | `GeneratedDoors` |
| generated-door offer point | `door.offerPoint` | generated reward mutators and defaults | `GeneratedDoorOffers.OfferPointKind`, `GeneratedDoorOffers.BatchKey` |
| generated reward offer | `door.offerPoint.offers[offerIndex]` | `setRewardStore`, `setRewardType`, `setRewardAcquired` | `GeneratedDoorOffers.Store`, `GeneratedDoorOffers.RewardType`, `GeneratedDoorOffers.Acquired` |
| generated reward payload | `door.offerPoint.offers[offerIndex].payload` | `setBoonSource`, `setDevotionSource` | `GeneratedDoorOffers.PayloadSource`, `GeneratedDoorOffers.PayloadSourceA`, `GeneratedDoorOffers.PayloadSourceB` |
| room-local offer point | `room.offerPoints[offerPointIndex]` | room-key reset materialization, room-local offer mutators | `RoomOffers.OfferPointIndex`, `RoomOffers.OfferPointKind`, `RoomOffers.BatchKey` |
| room-local offer | `room.offerPoints[offerPointIndex].offers[offerIndex]` | `setRoomOfferStore`, `setRoomOfferType`, `setRoomOfferAcquired` | `RoomOffers.Store`, `RoomOffers.RewardType`, `RoomOffers.Acquired` |
| room-local payload | `room.offerPoints[offerPointIndex].offers[offerIndex].payload` | deferred until room-local payload leaves need UI | `RoomOffers.PayloadSource`, `RoomOffers.PayloadSourceA`, `RoomOffers.PayloadSourceB` |

Current implementation scope is F/Erebus. Other biome panels are placeholders and
do not emit route draft rows yet.

## Non-Serialized State

The following are derived and must not be serialized:

- candidate providers and their mutable `hidden`, `colors`, and `messages`;
- validation findings, first-issue status, and route status summaries;
- history ledgers and reward bag state;
- option labels and catalog-derived candidate arrays;
- UI caches such as selected-door option caches and route-shell tab caches;
- no-imgui fallback text output;
- inactive/downstream presentation state.

These values rebuild from:

```text
stored draft + declarations + route pipeline
```

## Parent-Child Reset Rule

Parent mutators own child shape.

Examples:

- changing a room key rematerializes room-local offer points and generated doors;
- changing a reward store resets reward type and payload to a valid shape for the
  new store;
- changing a reward type resets payload to that reward type's default payload;
- append/remove updates the room list before serializing the draft.

After a parent-child reset, the updated draft must be written through
`PlannerDraft:writeDraft(...)` as a coherent document. Storage should not receive
only one leaf row while stale child rows remain.

## Form Rules

Production forms must follow these rules:

- draw from a draft node, not from storage rows;
- mutate through planner-state methods, not direct table writes in widgets;
- expose structured form addresses for feedback;
- keep completion checks local and leave route/game legality to validators;
- use stable candidate providers for dropdown-like values;
- treat `PlannerDraft` rows as serialization output, not as UI layout state.

## Roundtrip Test Expectations

Each new form participant should have focused tests that prove:

- default/empty storage can materialize an editable draft;
- representative edits write back through `PlannerDraft:writeDraft(...)`;
- storage rows can read back into the same draft shape;
- parent changes clear or rematerialize incompatible child state;
- derived feedback/candidate/history data is absent from stored rows and rebuilds
  after evaluation.

For F/Erebus, representative cases are:

- room identity changes;
- selected door changes;
- generated target changes;
- generated reward store/type/acquired changes;
- Boon and Devotion payload changes;
- room-local shop/preboss offer changes;
- append/remove room;
- terminal rooms with no generated doors.

## Supporting Docs

- `FORM_FEEDBACK_CONTRACT.md` owns participant, address, feedback, and
  completeness boundaries.
- `UI_IMPLEMENTATION_ORDER.md` owns implementation sequencing and draw-path
  constraints.
- `../model/CANONICAL_PLAN.md` owns canonical route snapshot shape.
