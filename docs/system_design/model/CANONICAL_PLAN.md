# Canonical Plan

## Purpose

The canonical plan is the complete user-authored route shape before it is
expanded into game history. It is materialized from complete Biome Plan
controls and stores concrete game decisions only.

It does not store copied game facts such as room eligibility, force windows,
counter costs, exit counts, labels, or reward bag contents. Those belong to
declarations and are joined in by the history builder.

The guiding rule is:

```text
Plan stores concrete choices.
Declarations store game facts.
History stores derived game events and counters.
```

## Top Level

Runs are route-shaped. Route order is data-driven:

```lua
routes = {
    Underworld = { "F", "G", "H", "I" },
    Surface = { "N", "O", "P", "Q" },
}
```

The canonical plan follows that route order:

```lua
plan = {
    routeKey = "Underworld",
    biomes = {
        { biomeKey = "F", rooms = { ... } },
        { biomeKey = "G", rooms = { ... } },
        { biomeKey = "H", rooms = { ... } },
        { biomeKey = "I", rooms = { ... } },
    },
}
```

Partial route planning is an ordered route-prefix scope. If a biome is inside
configured scope, it must be complete. Unconfigured biomes are absent from the
canonical plan rather than represented as vanilla/random placeholders.

## Biome Plan

A biome plan is a sequence of entered physical rooms:

```lua
biomePlan = {
    biomeKey = "F",
    rooms = {
        roomNode,
        roomNode,
        roomNode,
    },
}
```

The biome plan is not row-shaped and not encounter-shaped. Rooms are physical
transition points. A room may contain zero, one, or many encounters.

This sequence is the selected/visited projection of the persisted topology
tree. Each visited room retains all generated peer doors, including unselected
target occurrences, on its outgoing batch. The same game room key may appear
in multiple room nodes or peer doors; occurrence identity belongs to the
authoring topology, not the room key.

The history builder expands room nodes into room entries, encounter entries,
generated door events, reward offer events, loot acquisition events, and
counter views.

Runtime does not consume Biome Plan storage directly. It consumes an execution plan
compiled from validated history; see `../runtime/RUNTIME_BOUNDARY.md`.

## Room Node

A room node stores the concrete room the player entered plus local authored
state when the room kind needs it:

```lua
roomNode = {
    roomKey = "F_Combat04",

    roomState = nil,

    generatedDoors = {
        selectedDoorIndex = 1,
        doors = {
            {
                exitIndex = 1,
                targetRoomKey = "F_Combat07",
                offerPoint = { ... },
            },
            {
                exitIndex = 2,
                targetRoomKey = "F_MiniBoss02",
                offerPoint = { ... },
            },
        },
    },
}
```

The plan does not store `exitCount`. The builder reads `F_Combat04` from the
biome declarations and validates that the plan supplied the expected generated
doors.

Terminal rooms may omit `generatedDoors` or provide an empty generated-door
set, depending on the final materialization contract.

## Generated Doors

Generated doors are equal peers. There is no domain distinction between
"picked door" and "other door." The selected door is just one generated door
marked by index:

```lua
generatedDoors = {
    batchRule = "Standard",
    selectedDoorIndex = 1,
    doors = {
        { exitIndex = 1, targetRoomKey = "F_Combat07", offerPoint = { ... } },
        { exitIndex = 2, targetRoomKey = "F_MiniBoss02", offerPoint = { ... } },
    },
}
```

For non-N biomes, a complete plan must satisfy:

```text
selectedDoorIndex exists
generatedDoors.doors are concrete and fully materialized
generatedDoors.doors reference declared exits by index
generatedDoors.doors[selectedDoorIndex].targetRoomKey == next roomNode.roomKey
```

Unselected doors are fully materialized because reward offers and bag depletion
depend on all generated doors, not only the selected path.

Two doors may have the same `targetRoomKey`. They still represent distinct
generated occurrences with independent typed state and reward offers.

Generated doors do not copy exit tags or exit constraints into the plan. They
reference the source room's declared exits by `exitIndex`. The builder reads
the declared exit and validates that the target room satisfies that exit's
constraints.

Completed canonical plans do not allow placeholder target rooms or compact
domain states such as "Combat Major." UI may provide compact authoring helpers,
but the materialized plan stores concrete target room keys.

Most generated-door batches are standard. Biomes can activate a specialized
batch rule when the game treats all generated next doors as one decision.
For example, H uses a Fields cage batch:

```lua
generatedDoors = {
    batchRule = "FieldsCageBatch",
    batchState = {
        cageRoll = "max",
    },
    selectedDoorIndex = 1,
    doors = {
        { exitIndex = 1, targetRoomKey = "H_Combat04", offerPoint = { ... } },
        { exitIndex = 2, targetRoomKey = "H_MiniBoss01" },
    },
}
```

The batch rule owns peer-level generation state. Individual target rooms still
own their own room facts.

## Reward Offers

Reward offers live inside offer points. Rooms, encounters, generated doors,
shops, hubs, and cages may all contain offer points:

```lua
offerPoint = {
    kind = "generatedDoorRewards",
    batchKey = "nextDoors",
    offers = {
        {
            store = "RunProgress",
            rewardType = "WeaponUpgrade",
            acquired = true,
            payload = {},
        },
    },
}
```

Most route rewards are generated by next-room doors, so they live on generated
door offer points. O wheels are encounter-local offer points. Shop items are
shop-domain offer points.

A reward offer is concrete:

```lua
rewardOffer = {
    store = "RunProgress",
    rewardType = "WeaponUpgrade",
    acquired = true,
    payload = {},
}
```

Presence of a reward offer means the game generated or displayed it.
`acquired = true` means the player actually got it.

Acquisition is derived when topology decides it: an ordinary generated-door
offer is acquired exactly when its door is selected, and an N hub-door offer is
acquired exactly when its door appears in the ordered visit subset. Those
authoring controls do not persist a second acquired toggle.

Acquisition remains explicit for independent choices inside an entered room,
such as shop purchases and O wheel selections. Their typed occurrence state
materializes the concrete `acquired` value.

Reward UI templates may be convenient, but completed offers must resolve to a
concrete store and reward type. Completed canonical plans do not allow
unresolved values such as Auto, Vanilla, Major, Minor, or incomplete Devotion
god selections.

## Typed Room State

Room-kind-specific data lives in typed room state payloads:

H Fields combat capacity is a room declaration fact, while the 2-vs-3 cage
roll is generated-door batch state. Do not store the cage roll as
`FieldsCombat` room state.

```lua
roomState = {
    kind = "ShipCombat",
    encounterCount = 3,
    encounters = {
        {
            kind = "intro",
            encounterDepthCost = 0,
        },
        {
            kind = "combat",
            encounterDepthCost = 1,
            offerPoint = { ... },
        },
        {
            kind = "combat",
            encounterDepthCost = 1,
            offerPoint = { ... },
        },
    },
}
```

```lua
roomState = {
    kind = "ClockworkCombat",
    clockworkGoal = true,
}
```

The room key and declarations determine which state type is expected. The room
template materializer should fail completion if the state is missing or has
the wrong shape.

## Source Metadata

During materialization, canonical facts carry planner source metadata so
history findings can return to their semantic owner:

```lua
source = {
    routeKey = "Underworld",
    biomeKey = "F",
    gameRoomKey = "F_Combat04",
    aspect = "generatedTargetReward",
}

location = {
    biomeControlId = "Underworld_F",
    nodeId = 17,
    parentNodeId = 12,
    doorIndex = 2,
}
```

Planner-only `nodeId` values are not runtime game identities. They may be
dropped after execution-plan compilation once no feedback path needs them.

## Biome Plan Versus Canonical Plan

Biome Plan controls may hold blanks or incomplete nested controls. The
canonical plan exists only after local control and topology completeness
succeeds.

The history builder consumes canonical plans, not persisted control storage. It
should not invent default rooms or fake rewards for incomplete choices.
