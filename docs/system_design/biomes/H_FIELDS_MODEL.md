# H / Fields Model

## Purpose

H should use the same generic linear biome model as F/G/P/Q. Its special
behavior does not require a biome-specific route engine, but it does require a
batch-level generated-door abstraction.

The important distinction is:

```text
FieldsCombat owns target-room capacity.
FieldsCageBatch owns the 2-vs-3 cage roll for all generated next doors.
```

H is special at the generated-door batch level, not only inside individual
combat rooms.

## Linear Shape

H is authored as concrete room nodes:

```text
fixed intro/opening
-> authored room nodes
-> generated preboss room
```

Preboss is a concrete terminal room in the room catalog. It is not a hardcoded
terminal row.

## Room Catalog

The H room catalog should define concrete game rooms:

- intro/opening room;
- Fields combat rooms;
- miniboss rooms;
- Echo/bridge room;
- preboss room.

Combat rooms own their target-room facts:

```lua
H_Combat04 = {
    kind = "Combat",
    roomTemplate = "FieldsCombat",
    tags = { "Combat" },
    maxCageRewards = 3,
    exits = {
        { tags = { "Standard" } },
        { tags = { "Standard" } },
    },
    eligibility = { ... },
}
```

`maxCageRewards` is map capacity. It says how many cage rewards that target
combat map can support. It does not say which 2-vs-3 door roll happened for
the current generated-door batch.

Miniboss and Echo/bridge rooms are ordinary concrete rooms with eligibility
and force metadata from game data:

```lua
H_MiniBoss01 = {
    kind = "Miniboss",
    eligibility = { ... },
    force = {
        biomeDepthCache = { min = 2, max = 4 },
    },
}
```

```lua
H_Echo = {
    kind = "Story",
    eligibility = { ... },
    force = { ... },
}
```

Exact room keys and conditions should come from game data.

## Generated Door Batch

Every current room produces one generated-door batch. Most biomes use a
standard batch with no extra state. H activates a Fields-specific batch rule:

```lua
generatedDoors = {
    batchRule = "FieldsCageBatch",
    batchState = {
        cageRoll = "min", -- or "max"
    },
    selectedDoorIndex = 1,
    doors = {
        { exitIndex = 1, targetRoomKey = "H_Combat04" },
        { exitIndex = 2, targetRoomKey = "H_MiniBoss01" },
    },
}
```

This state belongs to the current room's next-door generation. It is not a
property of either generated target room by itself.

## Fields Cage Derivation

The builder derives cage reward counts from the batch:

```lua
batchCapacity = min(3, generated FieldsCombat target maxCageRewards...)

if cageRoll == "min" then
    visibleCageCount = 2
else
    visibleCageCount = batchCapacity
    fieldsMaxDoorsRolled = fieldsMaxDoorsRolled + 1
end
```

Every generated door that targets a `FieldsCombat` room receives a cage offer
point with the same derived `visibleCageCount`:

```lua
{
    exitIndex = 1,
    targetRoomKey = "H_Combat04",
    offerPoint = {
        kind = "fieldsCage",
        derivedCageRewardCount = 3,
        offers = {
            { store = "RunProgress", rewardType = "Boon", acquired = true },
            { store = "RunProgress", rewardType = "MaxHealthDrop", acquired = false },
            { store = "RunProgress", rewardType = "RoomMoneyDrop", acquired = false },
        },
    },
}
```

If a batch contains multiple Fields combat doors, they match because they were
constructed from one batch roll. Matching is a construction invariant, not a
separate validator rule.

## FieldsMaxDoorsRolled

H has a biome-scoped generated-door counter equivalent to the game's
`FieldsMaxDoorsRolled`.

The planner should model it as a validator-visible batch counter:

- it starts at 0 for the biome;
- it increments when a `FieldsCageBatch` takes the max branch;
- it is capped by the game's ceiling;
- it affects whether future max cage rolls are possible or forced.

Probabilities are not modeled as odds. The planner only models
impossibilities and forced states:

```text
nonzero chance = possible
zero chance = impossible
ceiling/deadline condition = forced when the game forces it
```

## Visible 2 Is Ambiguous

Visible cage count is not enough to reconstruct the game state.

If batch capacity is 3:

```text
visible 2 => min branch, counter does not increment
visible 3 => max branch, counter increments
```

If batch capacity is 2:

```text
visible 2 may be min branch or max branch clamped by capacity
```

Because the fresh model aims to avoid hidden guessing, the form should expose
the batch's door roll directly:

```text
Door Roll: Min / Max
```

The rendered combat doors can then show the derived cage reward count.

## Force And Eligibility

Echo and miniboss behavior should be handled by normal room eligibility and
force metadata:

- force pressure considers currently eligible forced rooms;
- Echo is a forced room whose own eligibility can expire;
- minibosses use game-like eligibility conditions, not planner-only exclusive
  groups.

The force-pressure validator walks generated-door batches. It should see the
same batch facts used by reward offer derivation.

## Boundary

H needs:

- concrete room catalog;
- `FieldsCombat` target-room capacity;
- generic `GeneratedDoorBatch`;
- `FieldsCageBatch` batch rule and batch state;
- a validator-visible `FieldsMaxDoorsRolled` counter;
- normal force/eligibility/preboss validation.

H does not need:

- a biome-specific route engine;
- row/sibling topology machinery;
- per-combat cage-count matching validation;
- Echo-specific UI special casing.
