# O / Oceanus Model

## Purpose

O should use the same route, control, history, validation, and feedback pipeline
as other non-N biomes. Its special behavior belongs inside the combat room
nested control because O combat occurrences contain multiple encounters inside
one physical room.

The important distinction is:

```text
O special case = ShipCombat encounter sequence
not a generated-door batch rule
```

Unlike H, O does not need to inspect all generated next doors as a peer group
to decide its special state.

## Linear Shape

O is authored as concrete room nodes:

```text
fixed intro/opening
-> authored ship rooms
-> generated preboss room
```

Preboss is a concrete terminal room in the room catalog. It is not a hardcoded
terminal row.

## Room Catalog

The O room catalog should define concrete game rooms:

- intro/opening room;
- ship combat rooms;
- story room;
- shop room;
- fountain/trial/miniboss rooms where applicable;
- preboss room.

Combat rooms point at a ship-specific room template:

```lua
O_Combat03 = {
    kind = "Combat",
    roomTemplate = "ShipCombat",
    tags = { "Combat" },
    exits = {
        { tags = { "Standard" } },
    },
    eligibility = { ... },
}
```

The room declaration owns room eligibility and exits. Each `ShipCombat`
occurrence control owns its room-internal encounter sequence and wheel offer
points.

## ShipCombat Occurrence Control

An O combat room is one physical room with an encounter sequence:

```lua
roomState = {
    kind = "ShipCombat",
    encounters = {
        {
            kind = "intro",
            encounterDepthCost = 0,
        },
        {
            kind = "combat",
            encounterDepthCost = 1,
            offerPoint = {
                kind = "shipWheel",
                offerCount = 2,
                offers = { ... },
            },
        },
        {
            kind = "combat",
            encounterDepthCost = 1,
            offerPoint = {
                kind = "shipWheel",
                offerCount = 1,
                offers = { ... },
            },
        },
    },
}
```

The third encounter is optional and is controlled by game conditions such as
`BiomeEncounterDepth`. Because that condition observes a normal timeline
counter, it belongs in the template interpreter's encounter-sequence rules.

## Room And Encounter Timing

O is the main reason room timing and encounter timing must be separate.

One O combat room can contain:

```text
room.enter O_Combat03
encounter.start intro       BED +0
encounter.start combat1     BED +1
offerPoint.emit wheel1
encounter.start combat2     BED +1
offerPoint.emit wheel2
room.generate_next
room.commit                 BDC +1
```

The planner must not collapse this to "one room means one encounter-depth
increment." Doing so validates story/shop/miniboss timing against the wrong
counter phase.

## Wheel Offer Points

Wheel rewards are encounter-local offer points:

```lua
offerPoint = {
    kind = "shipWheel",
    offerCount = 2,
    offers = {
        { store = "RunProgress", rewardType = "MaxHealthDrop", acquired = true },
        { store = "RunProgress", rewardType = "RoomMoneyDrop", acquired = false },
    },
}
```

`offerCount` is structural state for the wheel offer point. It is mostly used
for reward bag simulation, but it lives with the encounter because the wheel is
created by the encounter, not by the next-door batch.

Completed plans should materialize each wheel offer concretely:

- one-offer wheel: one concrete offer, acquired by the player;
- two-offer wheel: two concrete offers, exactly one acquired.

## O Is Sequential, Not Batch

O wheel offers are sequential:

```text
wheel 1 can affect reward bags before wheel 2 is generated
```

They are not one room-wide reward batch.

This differs from:

- H cage rewards, which are generated from one Fields cage batch;
- N hub pylon rewards, which are generated together on hub entry;
- normal next-door rewards, which are generated together by the current room.

## Generated Next Doors

O generated next doors use the standard generated-door batch:

```lua
generatedDoors = {
    batchRule = "Standard",
    selectedDoorIndex = 1,
    doors = {
        { exitIndex = 1, targetRoomKey = "O_Combat04", offerPoint = { ... } },
    },
}
```

The special O state is inside the current room's `ShipCombat` encounters, not
inside `generatedDoors.batchState`.

## Story, Shop, And Preboss

O story/shop/preboss timing should be modeled as ordinary room eligibility and
force metadata from game data.

Examples of the intended ownership:

- story/shop requirements read `BiomeDepthCache` and `BiomeEncounterDepth`;
- force behavior belongs to the room declaration;
- preboss is a concrete terminal room;
- room legality is rejected by validation, not by control completeness.

The occurrence control can author a complete but illegal O state. The history builder should
materialize it, and the validator should reject it with game-domain findings.

## Boundary

O needs:

- concrete room catalog;
- `ShipCombat` occurrence template/control;
- room/encounter timeline separation;
- wheel offer-point state;
- normal force/eligibility/preboss validation.

O does not need:

- generated-door batch state;
- a biome-specific route engine;
- row/sibling topology machinery;
- shop/story deadline hacks outside room eligibility and force validation.
