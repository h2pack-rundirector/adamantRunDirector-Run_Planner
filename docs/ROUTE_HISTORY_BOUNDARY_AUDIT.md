# Route History Builder Boundary Audit

This note audits the current route-history builder, adapter, step, validator,
and feedback boundary. It complements `ROUTE_HISTORY_MODEL.md`,
`ROUTE_HISTORY_COORDINATE_CONTRACT.md`, and `ROUTE_TIMING_MODEL.md`.

The goal is to make the next implementation pass mechanical: adapters can stay
biome-specific, but the route-history timing and validation contract should be
shared.

## Target Contract

### Template / Form

Templates own storage, rendering, and local form completeness. A template may
know enough local structure to decide which controls exist and whether required
inputs were filled. It should not decide route legality.

Template snapshots should:

- preserve selected keys and blanks;
- include `formAddress` for row and child controls that can receive feedback;
- omit resolved declaration objects;
- omit resolved reward surfaces/items except as local form checks;
- omit depth counters, force-pressure decisions, and invalid rows.

If the form is incomplete, history should not treat defaulted rows as facts.
The incomplete state should return as completion feedback instead.

### History Builder

`src/mods/route/history/builder.lua` is the route orchestrator. It should:

- walk route biomes in route order;
- retrieve the selected snapshot for each biome;
- look up the biome declaration;
- dispatch to the adapter named by the declaration;
- run common post-processing, such as loot emission over emitted room entries;
- append declaration timeline entries after a successfully built biome.

It should not walk template rows itself, infer UI semantics, or validate route
legality.

### Adapter

Adapters translate template row language plus biome declaration facts into the
shared history language.

Adapters own biome-specific traversal shape:

- fixed-linear body rows;
- H cage structure;
- I goal/preboss structure;
- O ship encounter structure;
- N hub/pylon/side-room traversal.

Adapters may be custom, but custom traversal is not a license to fork the
common timing contract. Any emitted physical room should use the shared step
phase semantics for counters and generated candidates.

### Step

`src/mods/route/history/step.lua` is the shared room lifecycle owner.

The canonical sequence is:

1. `enterRoom`: increment BED/run encounter depth for the entered room.
2. `emitRoom`: emit the current room entry and stamp `phases`.
3. attach current-room candidates using generated/entry phase.
4. attach picked-door candidates using offer phase.
5. attach sibling candidates using offer phase.
6. attach reward candidates and topology.
7. set the next generated phase.
8. `advanceAfterRoom`: commit room-history and BDC costs.

Candidate phase policy:

- selected/current room candidates use `entry.phases.generated` when present,
  otherwise `entry.phases.entry`;
- picked next-door candidates use `entry.phases.offer`;
- other-door/sibling candidates use `entry.phases.offer`;
- any candidate with availability rules must carry an explicit
  `availabilityContext`.

The validator currently has a fallback from candidate context to entry context.
That should be treated as a migration fallback, not a production contract.

### Validator

Validators consume history, declarations, and candidates. They speak game
facts, not template layout.

Validators should:

- validate selected entries and generated candidates from the history ledger;
- use `formAddress` and target metadata only as source coordinates;
- emit game-domain findings;
- not read template storage directly;
- not infer timing from UI row numbers.

### Feedback

Feedback is the reverse adapter. It translates findings into template value
states, route markers, inactive metadata, and route-status payloads.

Feedback may translate coordinates, such as picked-next findings rendered on
the previous/current UI row. Feedback should not solve route legality or
rebuild game timing.

## Current Implementation Map

### Builder

`builder.lua` already matches the dispatcher shape:

- creates a history ledger;
- keeps route-level state;
- dispatches each biome to `adapters[biome.adapter].build`;
- runs `routeLoot.emitForRoomEntries` over the entries emitted by that adapter;
- appends `timeline.afterBiome` entries.

This is a good boundary. The builder is not currently the source of the bug
class.

### Shared Step

`step.lua` contains the intended phase machinery:

- `enterRoom`
- `emitRoom`
- `offerPhase`
- `attachCurrentRoomCandidates`
- `attachPickedDoorCandidates`
- `attachSiblingCandidates`
- `attachRewardCandidates`
- `advanceAfterRoom`
- `stepRoom`

`fixed_linear`, `fields_cage`, `clockwork_goal`, and
`multi_encounter_fixed` use `routeStep.stepRoom(...)`.

### HubPylon Adapter

`hub_pylon.lua` is intentionally custom because N is not a linear row walk. It
emits:

- fixed opening/prehub/hub/preboss entries;
- pylon entry;
- entered side rooms;
- pylon restore entries;
- hub return entries.

That custom traversal is valid. `emitPhysical` now delegates each physical entry
to `routeStep.stepRoom(...)`, with explicit attachment flags for entries that do
not own visible controls. This keeps the N traversal custom while reusing the
shared candidate/reward/topology timing contract.

### Candidate Validator

`validator/candidates/common.lua` evaluates availability against:

```lua
availabilityEntry or candidate.availabilityContext or entry
```

This is useful during migration, but it hides boundary mistakes. A candidate
without `availabilityContext` silently becomes entry-timed.

For ordinary templates this is mostly avoided because `stepRoom` stamps the
contexts. For HubPylon, direct candidate construction currently means the
fallback is part of live behavior.

### Form Address

`form_address.lua` is the right identity carrier for this migration:

- row controls use `formAddress.row(rowIndex)`;
- child controls use `formAddress.child(rowIndex, childKind, childIndex)`;
- validators and feedback can map findings without collapsing every entry to
  `(biomeKey, rowIndex)`.

This fixed the one-row-many-entries problem for HubPylon. Future work should
prefer `formAddress` over raw `rowIndex` whenever a control can be a child of a
row.

## Findings

### P1: HubPylon Uses Shared Candidate Timing

HubPylon keeps custom traversal but uses shared `stepRoom(...)` emission for each
physical room. This means pylon room candidates receive explicit phase context,
side-room rewards receive normal reward candidates, and physical-only restore
and hub-return entries do not receive visible candidate state.

Policy:

- keep HubPylon's custom traversal;
- keep shared step ownership for physical entry emission and candidate timing;
- do not reintroduce direct calls to room/reward candidate builders in the
  adapter.

### P2: Candidate Timing Contract Is Not Enforced

The validator accepts candidates without `availabilityContext`. That makes it
hard to notice when an adapter bypasses the step contract.

Recommended fix:

- add tests that production room/sibling candidates carry explicit
  `availabilityContext`;
- only then consider tightening validator fallback or documenting it as test-only
  compatibility.

### P3: N Hub Batch Timing Belongs To Rewards

N pylon choices are generated from hub topology, while the selected pylons are
entered later as physical room entries. Main pylon room legality should stay
structural and history-based: selected doors must be valid hub doors, pylon
rooms should not duplicate each other, only one miniboss variant should be
available, and side rooms must belong to their parent combat room.

The same-time concern is reward generation. Vanilla creates the hub door rooms
from `N_Hub` and chooses their rewards while still in the hub, then persists
those door rewards across hub revisits. The selected pylon reward is acquired
later, but it was offered as part of the hub batch.

Required model:

- the first `N_Hub` history entry owns the modeled generated hub doors;
- later pylon entries remain the physical traversal/acquired-loot entries;
- reward/bag validation should evaluate the generated hub-door rewards as one
  batch owned by the hub entry;
- room candidate validation should not use a special pylon generation context.

Current implementation:

- the first `N_Hub` entry carries `topology.generatedDoors` for the modeled
  pylon doors;
- route loot emission turns those generated-door rewards into `loot` events with
  `timing = "generatedOffer"` and `eventSourceKind = "hubGeneratedDoor"`;
- `generatedOffer` events are validation/offer facts and are not indexed as
  acquired loot;
- the later pylon loot event remains the acquired fact and carries
  `legalityValidatedBy = "hubGeneratedOffer"` so selected-legality rules do not
  re-run at the wrong physical-entry timing.

### P4: Side Rooms Are Entries, Not Siblings

N side rooms are entered branches and should remain separate physical entries
with child form addresses. They are not room-topology siblings.

Recommended policy:

- side-room `entered` controls decide whether the side-room entry exists;
- side-room rewards use reward addresses like `side:1`;
- side-room room candidates should only exist if we intentionally add a
  side-room candidate surface;
- side-room feedback should use child `formAddress`, not row-only lookup.

### P5: Feedback Boundary Is Mostly Correct

Feedback already groups findings, applies route render records, and delegates
to adapter feedback translators. The boundary should stay this way.

Do not fix HubPylon candidate timing by adding special legality logic to
feedback. The fix belongs in adapter/step candidate stamping.

## Actionable Spec For The Next Slice

### 1. Shared Physical Entry Attachment Helper

`step.lua` exposes `routeStep.stepRoom(...)` with explicit attachment flags.
Adapters that need custom traversal should still use this helper for physical
entry emission whenever possible.

### 2. HubPylon Shared Attachment

`hub_pylon.lua` keeps `emitPhysical` as the physical traversal helper. It now
passes policy flags into `routeStep.stepRoom(...)` instead of assigning
candidates manually.

Suggested policy fields:

```lua
{
    currentRoomCandidates = true,
    pickedDoorCandidates = false,
    siblingCandidates = false,
    rewardCandidates = rewardContextValue,
    rewardCandidateOpts = {
        address = "side:1",
    },
}
```

Initial HubPylon policy:

- fixed opening/prehub/hub/preboss entries: current-room candidates only when
  the UI has a corresponding room control;
- first hub entry: owns generated hub-door batch metadata for modeled pylon
  doors and their generated rewards;
- pylon entries: current-room candidates use ordinary entry/structural context;
  acquired reward metadata remains on the pylon entry;
- side-room entries: reward candidates for `side:N`; no sibling candidates;
- pylon restore/hub return: no room/reward candidates unless a visible control
  owns that entry.

### 3. Make Candidate Context Explicit

After HubPylon uses shared attachment, add focused tests:

- every room candidate emitted for production history has `availabilityContext`;
- every sibling candidate emitted for production history has
  `availabilityContext`;
- HubPylon side-room reward candidates keep `address = "side:N"`;
- HubPylon child form addresses survive candidate findings and feedback.

### 4. Keep Validator Pure

Do not move HubPylon timing into `validator/candidates/*`.

The validator should only ask:

- what candidates were generated;
- what availability context was stamped on each candidate;
- whether that candidate is available or selected-invalid.

If reward validation needs to know that a pylon reward was hub-generated, the
adapter should expose that fact as hub-batch metadata on the `N_Hub` entry.
Room candidate validation should not infer N hub timing from row identity.

## Non-Goals For This Slice

- Do not implement reward bag simulation.
- Do not make HubPylon linear.
- Do not move side rooms back to a separate data stream.
- Do not add template route-legality checks.
- Do not make feedback infer route timing.
- Do not rebuild runtime execution planning.

## Review Checklist

Before the next implementation commit is accepted:

- `hub_pylon.lua` should still own N traversal shape.
- `hub_pylon.lua` should not manually construct ordinary room candidates
  without explicit phase context.
- candidates that can be availability-validated should have
  `availabilityContext`.
- validator candidate code should stay adapter-agnostic.
- feedback should only translate findings to UI state.
- tests should prove child `formAddress` survives side-room validation and
  decoration.
