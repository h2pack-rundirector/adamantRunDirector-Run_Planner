# `OlympusCombat` Room Control

## Coverage

| Biome step | Rooms | Reward surface | Encounter profile |
| --- | --- | --- | --- |
| `Surface_P` | `P_Combat01..19` | `RunProgressMinorMajor` | `OlympusCombat` |

## Owned State

The authored state and persistence are the same concrete incoming
`RunProgress`/`MetaProgress` reward shape as `StandardCombat`:

```lua
{
    kind = "OlympusCombat",
    generatedReward = {
        storeKey = "RunProgress",
        rewardType = "Boon",
        payload = { source = "ApolloUpgrade" },
    },
}
```

Logical fields are `storeKey`, `rewardType`, `source1`, and `source2`.

The separate template exists because its fixed room spine contains a
non-counting `Intro` followed by counting `Combat`. Indoor/outdoor tags and
typed physical exits remain immutable declaration and topology facts.

## Completeness and Addressing

Only the incoming reward is authored. Completeness and candidates use
`aspect = "generatedReward"`; the two encounter phases have no authored
presence or reward slots.
