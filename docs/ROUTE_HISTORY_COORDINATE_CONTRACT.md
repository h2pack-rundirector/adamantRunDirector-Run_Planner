# Route History Coordinate Contract

This document defines the coordinate model for route history, generated doors,
template UI, validation findings, and feedback decoration.

It exists because the route-history migration changes the meaning of a row. The
old row-stream system made every concept row-local. The history system separates
what happened from what the current room generated next. Code that mixes those
coordinates tends to create the same bug repeatedly: current room, picked next
room, and other door get counted or decorated as if they were the same thing.

## Policy

A history entry is the room the player is currently in. Any doors and rewards
generated from that room hang off that current entry as topology. The picked
generated door later becomes the next history entry.

For row `i`:

```text
entry i = current room actually entered
entry i.topology.selected = picked next room, row i + 1
entry i.topology.sibling(s) = unpicked generated doors from row i
entry i + 1 = the room actually entered next
```

This is the default for every biome template. Any exception must be explicit in
this document and covered by tests.

Layer ownership:

| Layer | Owns | Must not own |
| --- | --- | --- |
| Biome template | Storage, rendering, local form completeness, render gates, selected-row snapshots. | Route legality, force pressure, depth/encounter validation, reward legality, sibling interpretation beyond storing input. |
| Step | Shared room lifecycle and timing: enter room, increment encounter depth, emit current entry, attach current/picked/sibling/reward candidates, attach topology, leave room, commit BDC/room-history. | Biome-specific topology policy, UI storage, validation decisions. |
| Builder / adapter | Translation from template row language plus biome declarations into history/game language. Resolves keys, emits entered room entries, generated topology, rewards, loot, and adapter-specific traversal. | Valid/invalid decisions, coloring, route-status wording. |
| Validator | Legality. Reads history/declarations/candidates and emits game-domain findings for selected current room, picked next door, other door, reward, force/deadline, and route completion issues. | Template storage reads, UI layout, coloring. |
| Feedback | Translation from validator findings to UI state: value states, tab/row markers, route-status markers, inactive horizon. | Legality decisions, topology inference, route interpretation. |

Validation policy:

- selected/current-room validity targets the entered room entry;
- picked-next validity targets the generated selected door and includes render
  coordinates for the current row `i`;
- other-door validity targets sibling candidates on current row `i`;
- reward validity targets the reward address on the entered room unless the
  reward is a generated branch;
- force/deadline validity targets the current room that generated or failed to
  generate the needed doors.

The goal is one coordinate language. Template-specific behavior belongs at the
adapter boundary and should be documented as a named exception, not rediscovered
inside validators or feedback.

## Canonical Terms

### Current Room

The current room is the room represented by history entry `entry.rowIndex = i`.

It is the room the player actually entered. It owns:

- `entry.roomKey`
- `entry.roleKey`
- `entry.optionKey`
- current-room rewards and loot events
- current-room entry and offer phases
- generated next-door topology

### Picked Door

The picked door is the generated next choice the player takes from the current
room.

In the UI row for current room `i`, the Picked Door control edits the selected
row `i + 1`.

In history, the picked door has two representations:

- as generated topology on current room entry `i`;
- as the entered room entry at row `i + 1`.

This duplication is intentional. The current room records what the game
generated next. The next room records what the player actually entered.

### Other Door

The other door is a generated next choice from the current room that the player
does not enter.

In template storage, this is a sibling structure field on current row `i`, such
as `SiblingStructureKey`.

In history, it belongs to `entry.topology` on current room entry `i`.

### Generated Topology

Generated topology is always attached to the current room that generated it.

For ordinary next-choice route templates:

```lua
entry.rowIndex = i
entry.topology = {
    kind = "...",
    selected = pickedDoorForRowIPlusOne,
    sibling = otherDoorFromRowI,
    siblings = { otherDoorFromRowI },
}
```

or, when multiple generated choices need branch metadata:

```lua
entry.topology = {
    kind = "...",
    exits = {
        { branch = "picked", ... },
        { branch = "sibling", siblingIndex = 1, ... },
    },
}
```

The validator must not infer generated doors from the current room itself unless
the template explicitly models the current room as the generated branch.

### Render Row

Validation findings may refer to a stored row that is not the visible row where
the control is drawn.

Example: invalid picked-next Preboss.

- selected row: `i + 1`
- visible control: Picked Door on current UI row `i`
- route-status location: current room `i`, because that is where the bad
  generated choice is offered
- value-state decoration: control rendered on row `i`

Findings that need this translation should carry `renderRowIndex` /
`renderRouteOrdinal` or a control target. Feedback is allowed to use those
render coordinates for decoration. Validators should still keep game/source
coordinates on the invalid itself.

## Timing Contract

Route history follows the phase model in `ROUTE_TIMING_MODEL.md`.

For current room `i`:

1. Enter room.
2. Increment BED/run encounter depth for the current encounter.
3. Emit current room entry.
4. Apply current room reward.
5. Evaluate generated next doors and next rewards using offer phase:
   - BED/run encounter depth after current encounter;
   - current reward already visible;
   - BDC before current room leave;
   - room-history ordinal before current room leave.
6. Attach generated topology to current room entry.
7. Leave room and commit BDC/room-history costs.

## Template Contract

Templates own storage and presentation. They do not own route legality.

Each room UI row should render:

```text
Row i
  Current Room    selected row i
  Next Choices
    Picked Door   selected row i + 1
    Other Door    sibling fields on row i
```

Entry rows are allowed to render their fixed/current room directly because
nothing before them generated them. Terminal visible rows should render the next
fixed preboss/boss transition as text when there is no editable generated choice.

Form completeness belongs to templates. Context validity belongs to route
history validation.

## Builder Adapter Contract

Builder adapters consume selected snapshots plus biome declarations and emit the
history ledger.

For each emitted current room entry:

- current entry fields describe selected row `i`;
- current reward describes selected row `i`;
- picked-door candidates describe selected row `i + 1`;
- sibling candidates describe sibling fields on row `i`;
- generated topology describes the next choices generated by row `i`.

Adapters should not ask validators to reconstruct topology from template
storage. If a generated choice matters, the adapter should emit it explicitly.

## Validator Contract

Validators speak game logic, not UI layout.

Use these ownership rules:

- selected/current-room validity: target the entered room entry;
- picked-next validity: target the generated selected door and include render
  coordinates for current row `i`;
- other-door validity: target the sibling candidate on current row `i`;
- reward validity: target the reward address on the entered room entry unless
  the reward is a generated branch;
- topology pressure/deadline validity: target the current room that generated or
  failed to generate the needed doors.

The first blocking invalid should be ordered by route biome, route ordinal, and
row index. Candidate findings may color many controls, but route status should
report the first selected invalid.

## Feedback Contract

Feedback translates validator findings back to template controls.

Feedback may use:

- `rowIndex` for same-row controls;
- `renderRowIndex` for picked-next controls rendered on the previous/current UI
  row;
- `siblingIndex` and `structureKey` for other-door controls;
- reward `address` and `controlAlias` for reward controls;
- `controlTargets` for selected blank controls that do not have a meaningful
  option value.

Feedback should not reinterpret route validity. It should only map validator
findings to value states, inactive row metadata, tab markers, and route-status
markers.

## Per-Template Contract And Audit

### FixedLinearRoute

Biomes: F, G, P, Q fixed-linear rows.

Expected model:

- current entry row `i` is selected row `i`;
- Picked Door on UI row `i` edits selected row `i + 1`;
- Other Door controls on UI row `i` edit sibling fields on selected row `i`;
- adapter topology on entry `i` uses selected row `i + 1` as the picked generated
  door;
- adapter topology also includes all active sibling fields from row `i`;
- preboss shop/free reward branches are generated topology branches on the room
  before preboss, while the preboss entry records what was actually taken.

Current audit:

| Boundary | Status | Notes |
| --- | --- | --- |
| UI | Pass | Rooms tab renders current row plus next choices through `next_choice_view`. |
| Runtime snapshot | Pass | Snapshot exports active sibling fields only. |
| Adapter | Pass | `fixed_linear.lua` attaches topology from `nextRow` plus current-row siblings. |
| Validator | Pass | Candidate validation can evaluate picked-next and sibling candidates separately. |
| Feedback | Pass | Picked-next findings can use render row coordinates. |

### FieldsCageRoute

Biome: H.

Expected model:

- current entry row `i` is selected row `i`;
- UI uses the same current-room/next-choice language as fixed-linear;
- Picked Door on UI row `i` edits selected row `i + 1`;
- Other Door on UI row `i` edits sibling structure on selected row `i`;
- cage reward count and same-exit rewards belong to the entered room row;
- generated next-door topology should be attached to the current room that
  generated it.

Current audit:

| Boundary | Status | Notes |
| --- | --- | --- |
| UI | Pass | Rooms tab renders current row plus next choices. |
| Runtime snapshot | Pass | Snapshot exports active sibling fields only. |
| Adapter | Needs review | `fields_cage.lua` still attaches topology from current selected row plus current sibling, not picked row `i + 1` plus current sibling. This may be valid only if H intentionally models each visible row as the generated cage pair itself. The contract should be made explicit or the adapter should be moved to next-choice topology. |
| Validator | Partial | `fields_cage` rule assumes selected and sibling live together on the same topology object. This matches the current adapter, but not the generic next-choice contract. |
| Feedback | Pass | Other-door findings can decorate sibling controls. Picked-next field-specific findings need a test before relying on them. |

### ClockworkGoalRoute

Biome: I.

Expected model:

- current entry row `i` is selected row `i`;
- Picked Door on UI row `i` edits selected row `i + 1`;
- Other Door on UI row `i` edits sibling structure on selected row `i`;
- topology selected exit is selected row `i + 1`;
- topology sibling exit is current row `i` sibling;
- the current entered Goal increments goal count before validating generated next
  doors;
- picked Preboss ends the visible biome from the template/form boundary, while
  validator decides whether that Preboss is legal.

Current audit:

| Boundary | Status | Notes |
| --- | --- | --- |
| UI | Pass | Rooms tab renders current row plus next choices and hides rows after picked Preboss. |
| Runtime snapshot | Pass | Snapshot emits all rows up to local inactive-after-Preboss boundary and ignores hidden siblings. |
| Adapter | Pass | `clockwork_goal.lua` attaches topology from picked next row plus current-row sibling. |
| Validator | Pass | Clockwork rule counts entered current Goal before generated-door checks and differentiates picked-next vs sibling findings. |
| Feedback | Pass | Picked-next findings carry render coordinates so the visible Picked Door control is colored. |

### MultiEncounterFixedRoute

Biome: O.

Expected model:

- current entry row `i` is selected row `i`;
- O has one physical next ship door, so ordinary sibling topology is not a room
  structure concern;
- ship combat encounter legs are current-room internal reward-generation
  topology;
- wheel-offer count belongs to encounter reward topology, not room sibling
  topology;
- generated ship next room is represented by selected row `i + 1` through normal
  room candidates, but no extra other-door room control is expected.

Current audit:

| Boundary | Status | Notes |
| --- | --- | --- |
| UI | Pass | Room UI has no sibling door controls. Reward UI owns wheel count controls. |
| Runtime snapshot | Pass | Encounter reward legs are emitted as current-row reward metadata. |
| Adapter | Pass | `multi_encounter_fixed.lua` attaches `shipCombat` encounter topology to the current room. |
| Validator | Pass | Variant/candidate validation handles three-combat availability; wheel controls are reward/topology metadata. |
| Feedback | Pass | Encounter reward findings can target reward controls by address. |

### HubPylonRoute

Biome: N.

Expected model:

- N is not a simple row-local next-choice template;
- the deterministic path is Opening -> PreHub -> Hub -> Pylon N -> optional side
  rooms/restores -> Hub return -> next pylon;
- hub topology is generated hub-door topology, not scalar `exitCount`;
- pylon side rooms are entered side branches, not sibling next-room topology;
- side-room `entered` controls determine whether those side room entries exist in
  history.

Current audit:

| Boundary | Status | Notes |
| --- | --- | --- |
| UI | Pass | Side rooms have their own controls and are not rendered as other doors. |
| Runtime snapshot | Pass | Side-room entered state and reward selections are preserved. |
| Adapter | Pass | `hub_pylon.lua` emits physical hub/pylon/side/restore traversal entries. |
| Validator | Partial | Current route structure validation can consume emitted entries, but N reward-bag simultaneous hub generation is intentionally deferred. |
| Feedback | Pass | Side-room feedback has a separate tab/control path. |

### RouteNpcs

Expected model:

- NPCs are not room topology;
- NPC controls target entries produced by route history;
- NPC validation should use history/query, not template-local row context.

Current audit:

| Boundary | Status | Notes |
| --- | --- | --- |
| UI | Partial | NPC controls have been reintroduced but should remain a layer over route history entries. |
| Adapter/history | Partial | NPCs are candidates/targets over history, not part of biome adapters. |
| Validator | Partial | NPC validator is separate from biome-structure validation. |
| Feedback | Partial | NPC feedback has its own adapter and should not share room sibling semantics. |

## Validation Policy Summary

| Finding target | Source coordinate | Render coordinate | Feedback target |
| --- | --- | --- | --- |
| Current room role/option invalid | entered row `i` | row `i` | `RoleKey` / `OptionKey` |
| Picked next room invalid | generated by row `i`, selected row `i + 1` | row `i` | picked-door role/option controls |
| Other door invalid | generated by row `i` | row `i` | `SiblingStructureKey` or indexed sibling alias |
| Current reward invalid | entered row `i` | reward tab row `i` | reward address/control alias |
| Generated reward branch invalid | generated by row `i` | reward tab row `i` | branch reward control or control target |
| Side room invalid | parent pylon row plus side index | side-room tab row/side index | side-room control alias |
| Incomplete form selection | template row/control | same template row/control | warning control target |

## Required Tests For This Contract

Every template with generated choices should have tests for:

1. Builder topology uses current row as topology owner.
2. Picked generated door describes row `i + 1`, not row `i`.
3. Other generated door describes current row sibling storage.
4. Validator targets picked-next and other-door errors differently.
5. Feedback colors the visible row where the control is rendered.
6. Hidden/inactive sibling storage is not exported to history.

Current test coverage:

| Template | Coverage |
| --- | --- |
| FixedLinearRoute | Strong for next-choice depth, sibling candidate findings, and hidden sibling storage. |
| FieldsCageRoute | Needs a dedicated next-choice topology test if H should follow the generic next-choice contract. |
| ClockworkGoalRoute | Strong for picked-next topology, hidden sibling storage, picked Preboss inactivity, and Clockwork generated-door policy. |
| MultiEncounterFixedRoute | Strong for O variant and encounter reward feedback, but no room sibling contract is needed. |
| HubPylonRoute | Strong for traversal shape, side rooms, and pylon history; reward-bag hub simultaneity remains deferred. |

## Open Audit Items

1. Decide whether FieldsCageRoute is an intentional exception or should be
   converted to next-choice topology like FixedLinearRoute and ClockworkGoalRoute.
2. Add a FieldsCageRoute test that states the chosen answer explicitly.
3. Keep route-status location and value-state decoration aligned through
   `renderRowIndex` for picked-next findings.
4. Avoid adding validation logic to templates beyond local form completeness and
   render gates.
5. When reward bags are added, generated branch bag effects must attach to the
   current room that generated them, not only to the branch that was entered.
