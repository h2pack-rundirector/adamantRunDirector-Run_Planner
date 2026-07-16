# `Devotion` Room Control

## Coverage

| Biome step | Room | Reward binding | Encounter profile |
| --- | --- | --- | --- |
| `Surface_O` | `O_Devotion01` | fixed Devotion | `Devotion` |

## Owned State

The reward type is fixed to `Devotion`; the control authors its two distinct
Boon sources:

```lua
{
    kind = "Devotion",
    generatedReward = {
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
    source1 = "",
    source2 = "",
}
```

There is no reward-type or store selector. The UI operation is semantic, such
as `setDevotionSources(first, second)`, and rejects equal or unknown sources.

## Completeness and Addressing

Both sources must be concrete and distinct. The pair is one generated reward
candidate owned at `aspect = "generatedReward"`; it is not two independent
reward controls.
