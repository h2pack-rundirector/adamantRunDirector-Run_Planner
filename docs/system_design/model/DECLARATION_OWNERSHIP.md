# Declaration Ownership

## Purpose

Declarations should mimic game data closely while keeping ownership boundaries
clear. A fresh planner should not rebuild row/group abstractions as source
truth. It should define concrete rooms, structured exits, biome framing, and
generation rules.

The guiding rule is:

```text
Rooms describe what exists.
Exits describe what a room can generate.
Structure describes biome-level generation and termination rules.
UI groups are derived.
```

## Room Catalog

The room catalog owns concrete game room facts. Each real game room key should
have one room declaration:

```lua
P_Combat03 = {
    label = "C03",
    kind = "Combat",
    roomTemplate = "StandardCombat",
    tags = { "Indoor" },

    eligibility = { ... },
    force = nil,
    caps = {},

    exits = {
        { tags = { "Indoor" } },
        { tags = { "Outdoor" } },
    },

    encounterProfile = "StandardCombat",
    offerProfile = "RunProgressMajorMinor",
}
```

Room declarations own:

- game room key and label;
- room kind/template;
- self tags such as `Combat`, `Miniboss`, `Indoor`, or `Outdoor`;
- eligibility conditions that belong to that room;
- force metadata if the game declares it on that room;
- creation/appearance caps;
- structured exits;
- encounter profile;
- offer profile used when the room is generated or entered.

Room declarations must not own:

- UI grouping as storage truth;
- row positions;
- generated peer-door relationships;
- transition rules expressed as `nextRoomTags`;
- duplicated topology or reward-bag rules.

## Room Tags

Room tags describe the target room itself:

```lua
P_Combat03 = {
    tags = { "Indoor" },
}

P_Combat08 = {
    tags = { "Outdoor" },
}
```

Tags are not encoded into invented room keys. The plan references real game
room keys such as `P_Combat03`; indoor/outdoor is declaration metadata on that
room.

## Structured Exits

Rooms own exits as structured gateways, not just a numeric `exitCount`:

```lua
P_Combat04 = {
    exits = {
        { tags = { "Indoor" } },
        { tags = { "Outdoor" } },
    },
}
```

`exitCount` is derived from `#room.exits`.

Generated doors in the canonical plan reference declared exits by index:

```lua
roomNode = {
    roomKey = "P_Combat04",
    generatedDoors = {
        selectedDoorIndex = 2,
        doors = {
            { exitIndex = 1, targetRoomKey = "P_Combat03", offerPoint = { ... } },
            { exitIndex = 2, targetRoomKey = "P_Combat08", offerPoint = { ... } },
        },
    },
}
```

The builder reads `P_Combat04.exits[1]` and validates that `P_Combat03`
satisfies that exit's constraints. The plan does not restate exit tags.

## Exit Constraints

Exit tags constrain what can be generated through that exit.

For P, most rooms can be modeled as one indoor gateway and one outdoor gateway:

```lua
exits = {
    { tags = { "Indoor" } },
    { tags = { "Outdoor" } },
}
```

A room such as Mega-Dracon can be modeled without a bespoke validator:

```lua
P_MiniBoss01 = {
    tags = { "Miniboss", "Indoor" },
    exits = {
        { tags = { "Outdoor" } },
    },
}
```

The generic validation rule is:

```text
generated door references exit N
target room must satisfy exit N constraints
```

Normal exits can use a neutral tag or an empty constraint:

```lua
exits = {
    { tags = { "Standard" } },
    { tags = { "Standard" } },
}
```

or:

```lua
exits = {
    {},
    {},
}
```

The exact neutral representation can be decided during implementation.

## Biome Structure

Biome structure owns biome-level framing and generated-door rules:

```lua
structure = {
    start = {
        roomKind = "Opening",
    },
    terminal = {
        prebossRoomKey = "F_PreBoss",
        bossRoomKey = "F_Boss",
    },
    generation = {
        ...
    },
}
```

Structure owns:

- start room role;
- terminal/preboss/boss framing;
- biome-local counter starts;
- force-pressure interpretation across generated doors;
- deterministic generated sets;
- generated-door batch rules;
- biome-specific generation rules such as H cage batches, I goal/preboss
  generated-door rules, Q deterministic miniboss pairs, and N hub batches.

Structure must not copy room facts from the room catalog. If it needs a room's
label, eligibility, force window, reward profile, or tags, it should reference
the room catalog by key.

## Room-Kind Modules

Room-kind modules are reusable local interpreters/renderers. They are not biome
declarations.

Examples:

- `StandardCombat`;
- `FieldsCombat`;
- `ShipCombat`;
- `ClockworkCombat`;
- `Story`;
- `Fountain`;
- `Shop`;
- `Preboss`.

They own:

- local form schema;
- typed room-state materialization;
- local encounter event emission;
- local offer-point emission.

The room declaration points at the module:

```lua
H_Combat04 = {
    kind = "Combat",
    roomTemplate = "FieldsCombat",
    exits = {
        { tags = { "Standard" } },
        { tags = { "Standard" } },
    },
}
```

The plan stores the typed state expected by that template:

```lua
roomState = {
    kind = "ShipCombat",
    encounters = { ... },
}
```

Not every biome-specific choice belongs to room state. If the game makes a
decision over all generated next doors at once, that state belongs to the
generated-door batch. H Fields cage rolls are the canonical example:

```lua
generatedDoors = {
    batchRule = "FieldsCageBatch",
    batchState = {
        cageRoll = "max",
    },
    doors = { ... },
}
```

## Main Biome File

The main biome file is composition only:

```lua
local rooms = import("mods/biomes/declarations/p_rooms.lua")(...)
local structure = import("mods/biomes/declarations/p_structure.lua")({
    rooms = rooms,
})

return assembleBiome({
    key = "P",
    label = "Olympus",
    rooms = rooms,
    structure = structure,
})
```

Compatibility assembly may derive legacy shapes during migration, but the
source truth should be `rooms + structure`.

## UI Grouping

Groups such as Combat, Miniboss, Story, or Fountain are UI/query projections
over concrete rooms. They are not storage truth.

The UI may render grouped pickers for convenience, but completed plans store
concrete room keys and generated doors.
