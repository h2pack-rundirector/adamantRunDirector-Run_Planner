# Declaration And Topology Boundary

## Progress

- 2026-07-04: Slice 7 is implemented for FixedLinear. FixedLinear now exposes
  `selectedNodes.v1` and its history adapter can consume node snapshots while
  keeping `selectedRows.v1` as temporary compatibility. Clockwork now follows
  the same node snapshot path.
- 2026-07-04: Slice 7 now covers MultiEncounter/O as well. O exposes
  `selectedNodes.v1`; its adapter consumes current-room nodes while keeping
  ship combat/wheel topology as current-room data rather than generated-door
  topology.
- 2026-07-03: Slice 6 is implemented. Candidate findings now carry generated
  picked-door and other-door form addresses through feedback, and the old
  adapter `nextChoiceRenderRecord` row-shift hook has been removed.
- 2026-07-03: Slice 5 is implemented. Generated picked-door candidate
  stamping now comes from canonical topology exits carrying picked-door target
  metadata, so Fixed/Fields/Clockwork use the same validator walker path.
- 2026-07-03: Slice 4 is implemented for H/Fields. Route context now prefers
  `selectedNodes.v1` when a control exposes it, and the Fields history adapter
  consumes node snapshots directly while preserving `selectedRows.v1` as
  temporary compatibility for unmigrated tests and templates.
- 2026-07-03: Slice 3 first pass is implemented for H/Fields. The Fields
  runtime now exposes `selectedNodes.v1` beside `selectedRows.v1`; nodes carry
  current-room keys/rewards, picked next-door keys, active other-door keys, and
  form addresses without changing the existing builder path.
- 2026-07-03: Slice 2 is implemented. Generated-door aliases now sit beside
  the existing sibling storage names: declarations expose
  `generatedDoorControl`, snapshots/history expose `picked` and `otherDoors`,
  and shared history readers prefer those aliases while preserving legacy
  `sibling*` compatibility.
- 2026-07-03: Slice 1 first pass is implemented for H/Fields. H now has a
  canonical room catalog, layout references that catalog for biome framing, and
  the main declaration derives the legacy `roles`, `slotLayout`, and
  `roomTopology` shape from the split sources. Topology still emits the legacy
  generated-door option shape while downstream templates consume it.

This is the target design for biome declarations, topology, templates, and
selected snapshots. It exists because the current code still blends room facts,
layout rows, generated-door topology, and UI sibling controls. That blending is
the source of recurring current-row / next-row bugs.

## Goal

The planner should model a biome as a sequence of entered rooms. Each entered
room can generate the next set of doors:

```text
Current Room N     -> Picked Next Room / Other Doors
Current Room N + 1 -> Picked Next Room / Other Doors
```

The current room is the owner of generated-door topology. The next room is the
room the player actually entered from the current room's generated doors.

The route-history ledger may duplicate information intentionally:

- current room entry records what doors were generated;
- next room entry records what was entered.

No layer should have to infer this relationship by manually stitching "current
row" and "next row" together.

## File Roles

### Rooms Catalog

The rooms catalog owns canonical game-room facts. It should answer "what rooms
exist in this biome and what are their game rules?"

Owned facts:

- room key, label, and role/type;
- room options such as `F_Combat02`, `H_MiniBoss01`, `I_Story01`;
- availability and force metadata from the game;
- counter costs: `biomeDepthCacheCost`, `biomeEncounterDepthCost`,
  `roomHistoryCost`;
- caps, tags, next-room tags, reserve behavior;
- reward surface for entering the room;
- room-local structural facts such as physical `exitCount` when the fact
  belongs to the entered room itself.

The rooms catalog must not own:

- route row count;
- UI storage aliases;
- generated other-door controls;
- duplicated topology choices.

Current declarations usually keep this data in `*_layout.lua` and in the main
biome file's `roles`. The target shape is a dedicated room catalog per biome,
or an equivalent assembly step that produces the same single canonical room
registry.

### Layout

Layout owns biome lifecycle and fixed route framing. It should answer "how does
this biome start and end?"

Owned facts:

- entry/opening rooms;
- terminal/preboss/boss/postboss structure;
- route start/end ordinals;
- route row labels;
- counter starts;
- fixed before/after route entries;
- route-level depth range if the biome has one.

Layout must not own:

- all ordinary room options;
- generated-door choices;
- force groups;
- reward-bag topology.

Layout may reference rooms from the rooms catalog, but should not duplicate
their facts.

### Topology

Topology owns generated-door structure. It should answer "from this current
room, what doors can the game generate?"

Owned facts:

- generated-door count policy;
- topology windows;
- deterministic generated pairs or batches;
- force/deadline groups over generated doors;
- generated-door placeholders that are not concrete rooms;
- biome-specific generation rules such as H cage pairing, I clockwork goal
  doors, Q deterministic miniboss pairs, N hub batches, and O ship combat
  wheel structure.

Topology should refer to canonical rooms by stable references:

```lua
{ roleKey = "Miniboss", optionKey = "H_MiniBoss01" }
```

Topology may own structural placeholders that are not real room declarations:

```lua
{ key = "CombatCage3", structure = "CombatCage", sameExitRewardCount = 3 }
```

Topology must not copy room facts that already belong to the rooms catalog:

- availability;
- force windows;
- reward stores;
- labels;
- room costs.

Those should be resolved from the room reference. Copying them creates drift.

### Main Biome Declaration

The main biome declaration should be composition, not reinterpretation.

Target shape:

```lua
local rooms = import("mods/biomes/declarations/h_fields_rooms.lua")(...)
local layout = import("mods/biomes/declarations/h_fields_layout.lua")({
    rooms = rooms,
})
local topology = import("mods/biomes/declarations/h_fields_topology.lua")({
    rooms = rooms,
    layout = layout,
})

return assembleBiome({
    key = "H",
    label = "Fields",
    adapter = "fieldsCageRoute",
    rooms = rooms,
    layout = layout,
    topology = topology,
})
```

The assembly step can still produce today's `roles`, `slotLayout`, and
`roomTopology` fields while migration is in progress. The important contract is
that those fields are derived from the three source concepts above.

## Template Role

Templates own presentation and form state. They may know enough room structure
to render the form:

- how many rows exist;
- what current room label to show;
- whether a generated-door control is visible;
- how many generated other-door controls to draw;
- whether the user filled the required local form fields.

Templates must not own route legality:

- availability at current depth;
- force pressure;
- duplicate generated rooms;
- reward legality;
- NPC/feature legality.

Those belong to history validation.

## Snapshot Contract

The next snapshot format should be node-based instead of row-stitch based.

Current problem:

```lua
rowN = {
    roleKey = "...",
    topology = {
        siblings = { ... },
    },
}

rowNPlus1 = {
    roleKey = "...",
}
```

Adapters then manually combine `rowN` and `rowNPlus1` to reconstruct what the
current room generated. That is the ambiguity.

Target:

```lua
node = {
    rowIndex = 2,
    currentRoom = {
        roleKey = "Combat",
        optionKey = "H_Combat04",
        variantKey = "ThreeRewards",
        formAddress = { rowIndex = 2 },
    },
    nextChoices = {
        picked = {
            targetRowIndex = 3,
            roleKey = "Combat",
            optionKey = "H_Combat05",
            variantKey = "ThreeRewards",
            formAddress = { rowIndex = 3 },
        },
        otherDoors = {
            {
                doorIndex = 1,
                structureKey = "H_MiniBoss01",
                formAddress = { rowIndex = 2, childKind = "otherDoor", childIndex = 1 },
            },
        },
    },
    rewards = {
        row = {
            -- reward fields for the current room that was entered
        },
    },
}
```

The template may produce this by reading row `N` and row `N + 1`, but that
relationship must not leak past the template boundary.

Snapshots should:

- preserve user keys and blanks;
- carry form addresses for all controls that can receive feedback;
- include active rows and active generated-door controls only;
- use keys, not resolved declaration objects;
- keep current-room rewards on the current room.

Snapshots should not contain:

- labels;
- resolved room declaration tables;
- computed availability;
- candidate tables;
- value states;
- fallback default rooms for incomplete editable choices.

## Builder Role

The builder consumes complete node snapshots plus declarations. It translates
template language into game-fact history.

For each node:

1. materialize the current room entry;
2. attach generated-door topology from `node.nextChoices`;
3. emit current-room loot facts;
4. advance counters according to the current room.

The builder should not stitch raw rows. It should not decide whether a generated
door is legal. It should not create fake selected rooms for incomplete data.

## Validator Role

The validator walks history entries and declarations.

It owns:

- selected room validity;
- generated picked-door candidate validity;
- generated other-door candidate validity;
- route requirements;
- force pressure and deadlines;
- reward legality;
- NPC and feature legality.

With node snapshots, picked-next and other-door validation become the same
concept: generated-door candidate validation. They differ only by form address.

## Feedback Role

Feedback translates game-domain findings into form-language markers.

It should target the form address carried by the history/generated-door fact.
It should not decrement row indexes to guess where a picked-next control is
rendered.

This lets route status and dropdown decoration talk about:

- current room controls;
- picked next room controls;
- other door controls;
- reward controls;
- side-room child controls.

without knowing the row-stitching rules of any template.

## Current Violations To Remove

These are the main places where the current code violates the target boundary:

- `*_topology.lua` files duplicate room facts such as availability, force,
  reward store, and labels from layout/role declarations.
- `topology.siblingStructureControl` is UI-control language inside topology.
  Topology should define generated-door options; templates should decide how to
  render controls for them.
- `FixedLinearRoute/data/topology.lua`,
  `FieldsCageRoute/data/topology.lua`, and
  `ClockworkGoalRoute/data/topology.lua` rebuild selected-room topology from
  form rows. This makes topology both a data resolver and a UI helper.
- Runtime snapshots export `topology.siblings`, which forces adapters to stitch
  current row other doors with next row picked room.
- History adapters use `selectedRow`, `nextRow`, and `nextResolved` to
  reconstruct generated topology.
- Names like `sibling` and `SiblingStructureKey` remain domain language even
  though the intended model is "other generated door."

## Migration Plan

### Slice 1: Add Room Catalog Shape For One Biome

Start with H because it exposes the ambiguity most clearly.

- Introduce `h_fields_rooms.lua` or an equivalent room-catalog section.
- Move canonical room facts for combat, miniboss, bridge, intro, and preboss
  into that catalog.
- Make layout reference catalog rooms for intro/preboss.
- Make topology reference catalog rooms by `roleKey` / `optionKey`.
- Keep produced `roles`, `slotLayout`, and `roomTopology` compatible.

### Slice 2: Rename Topology Concepts Internally

Add generated-door aliases without changing storage yet:

- `generatedDoorControl` beside `siblingStructureControl`;
- `otherDoors` beside `siblings`;
- `picked` remains the selected generated door;
- `sibling` stays as compatibility only inside adapters/tests.

### Slice 3: Add Node Snapshot

Add `buildSelectedNodesSnapshot()` beside `buildSelectedRowsSnapshot()`.

Use it first for H:

- `currentRoom` from row `N`;
- `nextChoices.picked` from row `N + 1`;
- `nextChoices.otherDoors` from row `N`;
- current-room rewards from row `N`.

### Slice 4: Convert H Builder Adapter

Make the H adapter consume nodes and emit the same history facts as today.
Remove H-specific raw row stitching from the adapter.

### Slice 5: Convert Validator Candidate Generation

Make walker candidate generation read generated doors from entry topology.
Remove `adapterUsesPickedDoorCandidates`.

### Slice 6: Convert Feedback Targeting

Use generated-door form addresses directly.
Remove `nextChoiceRenderRecord` once Fixed, Fields, and Clockwork have node
snapshots.

### Slice 7: Expand To Fixed And Clockwork

Convert F/G/P/Q and I after H proves the boundary.

### Slice 8: Remove Compatibility Names

After all templates use nodes:

- remove `topology.sibling`;
- remove `topology.siblings`;
- remove `SiblingStructureKey` naming where migration is not needed;
- rename tests and helper APIs to generated-door / other-door language.

## Review Checklist

For each migration slice, check:

- Does this file own game room facts, layout, generated topology, UI form state,
  history materialization, validation, or feedback?
- Is any room fact duplicated between rooms and topology?
- Does any code infer current/next row relationship outside the template?
- Does any validator finding need row arithmetic to find the rendered control?
- Can the builder still run only after form completion succeeds?
- Does the history entry say "current room generated these next choices" without
  consulting the next entry?
