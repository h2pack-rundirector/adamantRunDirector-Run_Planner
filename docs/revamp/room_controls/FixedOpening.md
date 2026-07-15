# `FixedOpening` Room Control

## Coverage

| Biome step | Rooms | Reward surface | Encounter profile |
| --- | --- | --- | --- |
| `Underworld_F` | `F_Opening01..03` | `OpeningReward` | `F_Opening` |
| `Surface_N` | `N_Opening01` | `OpeningReward` | `N_Opening` |

No other surface or encounter profile is valid for this template.

## Owned State

The control owns the concrete incoming opening reward. `OpeningReward` fixes
the store to `RunProgress` and excludes Devotion, gold, max-health, and
max-magick rewards.

Logical persistence:

```lua
{
    rewardType = "",
    source = "", -- active only for a Boon payload
}
```

Typed read:

```lua
{
    kind = "FixedOpening",
    generatedReward = {
        storeKey = "RunProgress",
        rewardType = "Boon",
        payload = { source = "ApolloUpgrade" },
    },
}
```

The encounter profile is immutable declaration data and is emitted later as
the room spine. The control does not author which opening room is selected or
what follows it.

## Completeness and Addressing

The referenced control is complete when the reward type and any required
payload are concrete. Its reward address uses
`aspect = "generatedReward"`. Fixed opening encounter identity has no
candidate or persisted field.
