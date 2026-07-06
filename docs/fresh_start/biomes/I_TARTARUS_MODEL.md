# I / Tartarus Model

## Purpose

I should use the same plan, history, validation, and feedback pipeline as the
other non-N biomes. Its special behavior belongs in generated-door reward
offers and a Clockwork-specific generated-door batch rule.

The important distinction is:

```text
I_CombatXX is the real room.
ClockworkGoal is the game-domain reward offer that makes a door a goal door.
```

Do not invent planner room keys such as `I_GoalCombatXX` or
`I_RewardCombatXX`.

## Game Shape

The game models Clockwork progression with reward state:

- I intro initializes `RemainingClockworkGoals = 5`.
- I intro initializes `MaxClockworkNonGoalRewards` from a random range.
- I combat rooms use `ForcedFirstReward = "ClockworkGoal"`.
- I combat and preboss rooms can force `ClockworkGoal` after enough non-goal
  rewards have spawned.
- `ClockworkGoal` decrements `RemainingClockworkGoals` when spawned.
- I combat encounter variants can require or exclude `ClockworkGoal`.

The planner should mirror those concepts directly.

## Room Catalog

The I room catalog should define concrete game rooms:

- intro/opening room;
- `I_CombatXX` rooms;
- `I_Story01`;
- `I_Reprieve01`;
- `I_MiniBossXX`;
- `I_Shop01` if modeled;
- `I_PreBossXX`;
- boss/postboss rooms where needed.

Combat rooms remain real combat rooms:

```lua
I_Combat03 = {
    kind = "Combat",
    roomTemplate = "ClockworkCombat",
    tags = { "Combat" },
    exits = {
        { tags = { "Standard" } },
        { tags = { "Standard" } },
    },
    eligibility = { ... },
    rewardProfile = "TartarusRewards",
}
```

Goal versus non-goal is not encoded in the room key.

## Biome State

I needs explicit biome state because the game initializes random Clockwork
state in the intro:

```lua
biomeState = {
    remainingClockworkGoals = 5,
    maxClockworkNonGoalRewards = 4,
}
```

`maxClockworkNonGoalRewards` must be authored explicitly in the completed
plan. The planner should not keep it random or implicit, because later
generation legality depends on the value.

## ClockworkDoorBatch

Every current room produces one generated-door batch. I activates a
Clockwork-specific batch rule:

```lua
generatedDoors = {
    batchRule = "ClockworkDoorBatch",
    selectedDoorIndex = 1,
    doors = {
        {
            exitIndex = 1,
            targetRoomKey = "I_Combat03",
            offerPoint = {
                kind = "clockworkGoal",
                rewardType = "ClockworkGoal",
                acquired = true,
            },
        },
        {
            exitIndex = 2,
            targetRoomKey = "I_Combat08",
            offerPoint = {
                kind = "generatedDoorRewards",
                store = "TartarusRewards",
                rewardType = "Boon",
                acquired = false,
            },
        },
    },
}
```

The batch rule owns Clockwork-specific generated-door constraints. It should
inspect concrete offer points, not an invented `Goal` / `NonGoal` room role.

## ClockworkGoal Offer

`ClockworkGoal` is a structural reward offer:

```lua
offerPoint = {
    kind = "clockworkGoal",
    rewardType = "ClockworkGoal",
    acquired = true,
}
```

It is still an offer point, but it is not configured like a normal reward bag
choice:

- it has no normal reward store picker;
- it does not use RunProgress / MetaProgress bag choice;
- it drives Clockwork progression;
- it selects Clockwork-specific encounter behavior.

The UI may expose a convenience control that looks like:

```text
Tartarus Door Reward: Goal / Reward
```

That is UI sugar only. The materialized plan stores either a
`clockworkGoal` offer point or a concrete `generatedDoorRewards` offer point.

## Batch Rules

Before all Clockwork goals are complete:

```text
generated doors must include exactly one ClockworkGoal offer
```

After Clockwork goals are complete:

```text
generated doors must include the preboss door when the game would force it
```

Goal progress is based on the selected/acquired offer:

```text
selected door offerPoint.rewardType == "ClockworkGoal"
and acquired == true
=> remainingClockworkGoals -= 1
```

Non-goal progression uses acquired non-goal rewards:

```text
selected acquired generated-door reward is not ClockworkGoal
=> biomeRewardsSpawned += 1
```

The validator should use these counters to enforce the same forced-first and
forced-later behavior the game expresses through `ForcedFirstReward` and
`ForcedRewards`.

## Combat Leaf

`ClockworkCombat` owns local combat-room form and encounter materialization.
It can derive encounter profile from the selected room's reward offer:

```text
ClockworkGoal offer => goal reward encounter profile
normal reward offer => normal I combat encounter profile
```

The combat leaf does not own goal counting. Goal counting belongs to history
and validation because it depends on selected/acquired generated-door offers.

## Special Rooms

I story, reprieve, shop, and miniboss rooms should remain ordinary concrete
rooms with game-like eligibility and force metadata.

Several of these rooms require another generated door in the same batch that
leads to room set I. The game expresses this with
`RequiredOfferedDoorWitRoomSetName`. In the planner, this is a
ClockworkDoorBatch validation rule over generated peer doors.

## Preboss

Preboss is a concrete terminal room:

```lua
I_PreBoss01 = {
    kind = "Preboss",
    terminal = true,
    eligibility = {
        remainingClockworkGoals = { max = 0 },
    },
    rewardProfile = "I_WorldShop",
}
```

The game also forces preboss once enough non-goal rewards have spawned. The
planner should model that through ClockworkDoorBatch validation and room force
metadata, not through hardcoded terminal rows.

Selecting a valid preboss terminates the biome.

## Configured Biome Completeness

I depends on reward offer metadata for structure. Therefore the fresh planner
should require full reward configuration for every configured biome.

There is no valid structure-only I plan:

```text
configured I = rooms + generated doors + offer points + acquired flags
```

Partial planning should happen by route scope, not by disabling rewards inside
a configured biome.

## Boundary

I needs:

- concrete room catalog using real `I_*` room keys;
- explicit Clockwork biome state;
- `ClockworkDoorBatch` generated-door batch rule;
- `ClockworkGoal` structural reward offers;
- `ClockworkCombat` leaf for encounter/form materialization;
- normal force/eligibility/preboss validation.

I does not need:

- fake goal/reward combat room keys;
- a separate goal room type;
- reward-optional biome configuration;
- hardcoded row-state termination;
- runtime re-solving of Clockwork goal decisions.
