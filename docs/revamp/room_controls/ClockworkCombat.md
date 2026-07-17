# `ClockworkCombat` Room Control

## Coverage

All 24 `Underworld_I` rooms `I_Combat01..24` use:

- an `incomingKind` reward producer whose Goal branch is fixed ClockworkGoal
  and whose NonGoal branch uses TartarusRewards with Boon excluded;
- encounter profile `ClockworkCombat`;
- no local child slots.

No other producer/profile combination is valid.

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
    incomingKind = "NonGoal", -- Goal | NonGoal
    nonGoalRewardType = "StackUpgradeTriple",
}
```

The Goal branch is fixed and consumes no branch-local storage. Non-goal state
remains persisted but dormant while Goal is selected.

## Completeness and Ownership

The I declaration must make its initial incoming kind explicit before this
template becomes active; `NonGoal` is the planned default because it does not
pre-author every dormant combat room as a Clockwork Goal. Goal is locally
complete immediately. NonGoal requires a complete reward from its compiled
TartarusRewards binding and starts from that binding's declared
`StackUpgradeTriple` default.
`I_BaseCombat` supplies the Boon exclusion for every supported I combat room;
Devotion remains valid and retains its two-source payload.

`ClockworkDoorBatch` enforces exactly one Goal offer when required and owns
peer constraints. Goal acquisition counters are derived from picked topology;
the control owns no remaining-goal or non-goal-acquired counter.

After all goals are acquired, the batch rule may derive a declined preboss
offer beside the selected ordinary target. That offer is structural Clockwork
batch output, not state or another instance of this Room Control.

## Candidates and Feedback

The room exports one semantic incoming-reward provider whose candidates carry
both `incomingKind` and the concrete reward. Applying a candidate updates the
kind and active payload atomically. Feedback returns to
`aspect = "generatedReward"`; it does not encode a concrete room name in the
reason code.
