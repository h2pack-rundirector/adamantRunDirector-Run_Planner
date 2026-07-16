# `FixedPreHub` Room Control

## Coverage

| Biome step | Room | Counted store | Ineligible | Encounter profile |
| --- | --- | --- | --- | --- |
| `Surface_N` | `N_PreHub01` | RunProgress | Devotion, gold, max health, max magick | `FixedPreHub` |

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

Logical persistence is `rewardType` plus the conditional Boon `source`. The
opening exclusions are explicit facts on the normalized room binding.

The fixed `PreHubGeneratedN` encounter profile is a Room Declaration fact. The
`N_PreHub01 -> N_Hub` link is part of the `HubBiome` fixed entry sequence.
Neither is authored control state.

## Completeness and Addressing

Completeness and candidate ownership use `aspect = "generatedReward"`. The
control has no local child slots.
