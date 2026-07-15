# `FixedPreHub` Room Control

## Coverage

| Biome step | Room | Reward surface | Encounter profile |
| --- | --- | --- | --- |
| `Surface_N` | `N_PreHub01` | `OpeningReward` | `FixedPreHub` |

This is the only valid template combination.

## Owned State

The control owns one concrete `RunProgress` opening reward:

```lua
{
    kind = "FixedPreHub",
    generatedReward = {
        storeKey = "RunProgress",
        rewardType = "Boon",
        payload = { source = "ApolloUpgrade" },
    },
}
```

Logical persistence is `rewardType` plus the conditional Boon `source`.
Opening filters are inherited from `OpeningReward`.

The fixed `PreHubGeneratedN` encounter profile and fixed link into `N_Hub`
are declaration/topology facts, not authored control state.

## Completeness and Addressing

Completeness and candidate ownership use `aspect = "generatedReward"`. The
control has no local child slots.
