# Linear Biomes Model

## Purpose

F, G, P, and Q should use the same generic linear biome model wherever
possible. The fresh planner should not preserve old template-specific terminal
rows, miniboss groups, or preboss hacks when the game model can be represented
directly.

The guiding rule is:

```text
If the game models it, mirror it.
Invent planner abstractions only when the game model is unavailable,
unknowable, or too expensive to represent.
```

## Generic Linear Shape

Linear biomes are authored as concrete room nodes:

```text
start-kind room
-> authored room nodes
-> generated preboss room
```

The form only requires complete concrete data. It does not decide whether the
route is legal.

A preboss target at room 2 can be a complete snapshot if all fields are filled.
The builder can materialize that history. The validator rejects it if preboss
eligibility/force/terminal rules do not allow it at that point.

## Start Is A Room Kind

Biome starts should be declared by role when the game permits multiple concrete
opening variants:

```lua
structure = {
    kind = "linear",
    start = {
        roomKind = "Opening",
    },
}
```

For F, `F_Opening01`, `F_Opening02`, and `F_Opening03` are all concrete
`Opening` rooms. The validator requires the first room to be an `Opening` and
rejects `Opening` rooms anywhere after room 1. Generated doors cannot target
opening rooms because openings are start-only rooms, not ordinary generated
room candidates.

## Preboss Is A Room

Preboss should be a concrete room in the room catalog:

```lua
F_PreBoss = {
    kind = "Preboss",
    roomTemplate = "Preboss",
    terminal = true,
    eligibility = {
        biomeDepthCache = { min = 12 },
    },
    force = {
        kind = "BiomeDepthWindow",
        axis = "BiomeDepthCache",
        start = 12,
        deadline = 12,
    },
    exits = {},
    offerProfile = "PrebossShopOrFreeReward",
}
```

The exact conditions are biome/game-data specific. The important model is that
preboss is not a hardcoded row or template state.

Generic rules:

- generated-room candidates include preboss when eligible;
- preboss is invalid before eligible;
- selected preboss terminates the biome;
- preboss reward surface is handled by its room/offer profile.

This also applies outside F/G/P/Q:

```lua
I_PreBoss = {
    kind = "Preboss",
    terminal = true,
    eligibility = { clockworkGoalCount = 5 },
}
```

```lua
N_PreBoss = {
    kind = "Preboss",
    terminal = true,
    eligibility = { clearedPylonCount = 6 },
}
```

## Force Is Room Metadata

Force windows belong to room declarations when the game declares them on rooms:

```lua
F_Shop01 = {
    kind = "Shop",
    eligibility = { ... },
    force = {
        kind = "BiomeDepthWindow",
        axis = "BiomeDepthCache",
        start = 4,
        deadline = 6,
    },
}
```

Force pressure is interpreted over generated-door batches, not as local
selected-room legality. See
`../validation/FORCE_PRESSURE_MODEL.md` for the validation contract.

Do not introduce planner-only deadline groups unless the game data has an
equivalent concept that cannot be represented as room force metadata plus
eligibility.

## Miniboss Exclusivity Is Eligibility

F/G/P miniboss variants should not use a planner-only exclusive group.

The game model can be represented as room eligibility:

```lua
F_MiniBoss02 = {
    kind = "Miniboss",
    eligibility = {
        notInRoomHistory = { "F_MiniBoss01", "F_MiniBoss03" },
    },
    force = {
        kind = "BiomeDepthWindow",
        axis = "BiomeDepthCache",
        start = 4,
        deadline = 6,
    },
}
```

Then the normal eligibility engine handles the behavior:

- entering one miniboss makes the other variants ineligible;
- force pressure only considers currently eligible candidates;
- no separate `exclusiveGroup` or `closesGroupOnEnter` abstraction is needed.

## Generated Door Rewards

Normal generated doors from one room form a generated-door offer batch.

All generated doors are explicit peers. All generated-door offer points
participate in reward bag depletion, including unselected doors.

The selected door's reward offers become acquired when the selected next room
is entered.

## P Indoor / Outdoor Exits

P should model indoor/outdoor as room tags plus structured exit constraints,
not as `nextRoomTags` on rooms.

Target room:

```lua
P_Combat03 = {
    tags = { "Indoor" },
}
```

Source room exits:

```lua
P_Combat04 = {
    exits = {
        { tags = { "Indoor" } },
        { tags = { "Outdoor" } },
    },
}
```

Generated door:

```lua
{
    exitIndex = 1,
    targetRoomKey = "P_Combat03",
    offerPoint = { ... },
}
```

The builder reads `P_Combat04.exits[1]` and validator checks that
`P_Combat03` satisfies the exit constraints.

Mega-Dracon and similar rooms do not need bespoke validators:

```lua
P_MiniBoss01 = {
    tags = { "Miniboss", "Indoor" },
    exits = {
        { tags = { "Outdoor" } },
    },
}
```

## Q Deterministic Structure

Q can still use the same model even though it is more deterministic:

- intro/opening is fixed by layout;
- combat rooms can generate doors with no reward offer points;
- deterministic miniboss choice points are structure metadata;
- generated miniboss doors are still explicit generated doors;
- preboss is a concrete terminal room;
- Q preboss shop is a preboss offer profile, not a different architecture.

Example deterministic generated set:

```lua
generation = {
    {
        when = { biomeDepthCache = 3 },
        doors = {
            { targetRoomKey = "Q_MiniBoss02" },
            { targetRoomKey = "Q_MiniBoss05" },
        },
    },
}
```

The exact Q data should come from game data, but the architecture does not need
a special Q template.

## Boundary

F/G/P/Q do not need biome-specific route engines.

They need:

- concrete room catalogs;
- structured exits;
- room eligibility and force metadata;
- preboss rooms with terminal metadata;
- room-kind modules for local combat/reward behavior;
- structure metadata for deterministic or biome-level generation rules.
