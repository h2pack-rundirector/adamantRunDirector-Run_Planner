# `StandardCombat` Room Control

## Coverage

| Biome step | Rooms | Reward surface | Encounter profile |
| --- | --- | --- | --- |
| `Underworld_F` | `F_Combat01..22` | `RunProgressMinorMajor` | `StandardCombat` |
| `Underworld_G` | `G_Combat01..20` | `RunProgressMinorMajor` | `StandardCombat` |
| `Surface_Q` | `Q_Combat01..09`, `Q_Combat12..16` | `RunProgressMinorMajor` | `StandardCombat` |

These 56 rooms are the complete current coverage. Other surfaces, profiles,
local children, or room kinds are assembly errors.

## Owned State

The control owns one concrete incoming reward selected from `RunProgress` or
`MetaProgress`:

```lua
{
    kind = "StandardCombat",
    generatedReward = {
        storeKey = "RunProgress",
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
    storeKey = "",
    rewardType = "",
    source1 = "",
    source2 = "",
}
```

Payload fields are active only for the selected primitive. Two source fields
are necessary because `RunProgress` can produce Devotion. No combat room owns
its exits, next-room candidates, picked state, eligibility, or canonical
combat-family remapping.

## Completeness and Addressing

The generated reward must be concrete and payload-complete. The semantic owner
address uses `aspect = "generatedReward"`. Encounter phase `Combat` is a fixed
profile fact and carries no authored choice.
