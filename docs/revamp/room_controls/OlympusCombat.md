# `OlympusCombat` Room Control

## Coverage

| Biome step | Rooms | Counted stores | Ineligible | Encounter profile |
| --- | --- | --- | --- | --- |
| `Surface_P` | `P_Combat01..19` | RunProgress, MetaProgress | Devotion | `OlympusCombat` |

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

BaseP excludes Devotion. Logical fields are therefore `storeKey`,
`rewardType`, and one conditional Boon `source1`; the component does not
reserve a second source that no valid P combat reward can use.

The separate template exists because its fixed room spine contains a
non-counting `Intro` followed by counting `Combat`. Indoor/outdoor tags and
typed physical exits remain immutable declaration and topology facts.

## Completeness and Addressing

Only the incoming reward is authored. Completeness and candidates use
`aspect = "generatedReward"`; the two encounter phases have no authored
presence or reward slots.
