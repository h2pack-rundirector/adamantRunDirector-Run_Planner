# `ClockworkCombat` Room Control

## Coverage

All 24 `Underworld_I` rooms `I_Combat01..24` use:

- reward surface `ClockworkGoalOrTartarus`;
- encounter profile `ClockworkCombat`;
- no local child slots.

No other surface/profile combination is valid.

## Owned State

The target authors whether its incoming offer is the fixed Clockwork Goal or a
concrete non-goal Tartarus reward:

```lua
-- Goal
{
    kind = "ClockworkCombat",
    incomingKind = "Goal",
    generatedReward = { rewardType = "ClockworkGoal" },
}

-- Non-goal
{
    kind = "ClockworkCombat",
    incomingKind = "NonGoal",
    generatedReward = {
        storeKey = "TartarusRewards",
        rewardType = "Devotion",
        payload = {
            sources = { "ApolloUpgrade", "ZeusUpgrade" },
        },
    },
}
```

Logical persistence:

```lua
{
    incomingKind = "", -- Goal | NonGoal | ""
    nonGoalRewardType = "",
    nonGoalSource1 = "",
    nonGoalSource2 = "",
}
```

The Goal branch is fixed and consumes no branch-local storage. Non-goal state
remains persisted but dormant while Goal is selected.

## Completeness and Ownership

An empty incoming kind is incomplete. Goal is locally complete immediately.
NonGoal requires a complete Tartarus reward and payload.

`ClockworkDoorBatch` enforces exactly one Goal offer when required and owns
peer constraints. Goal acquisition counters are derived from picked topology;
the control owns no remaining-goal or non-goal-acquired counter.

## Candidates and Feedback

The room exports one semantic incoming-reward provider whose candidates carry
both `incomingKind` and the concrete reward. Applying a candidate updates the
kind and active payload atomically. Feedback returns to
`aspect = "generatedReward"`; it does not encode a concrete room name in the
reason code.
