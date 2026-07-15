# `FixedIntro` Room Control

## Coverage

| Biome steps | Rooms | Reward surface | Encounter profile |
| --- | --- | --- | --- |
| `Underworld_G/H/I`, `Surface_O/P` | `G_Intro`, `H_Intro`, `I_Intro`, `O_Intro`, `P_Intro` | `None` | `FixedIntro` |
| `Surface_Q` | `Q_Intro` | `OpeningReward` | `FixedIntro` |

The Q variant is intentionally stateful even though the other five instances
are storage-free. The template must therefore select its reward component from
the resolved surface rather than assuming every intro is empty.

## Owned State

For `None`:

```lua
{ kind = "FixedIntro", generatedReward = nil }
```

For `Q_Intro` logical persistence is:

```lua
{
    rewardType = "",
    source = "",
}
```

and the typed read is:

```lua
{
    kind = "FixedIntro",
    generatedReward = {
        storeKey = "RunProgress",
        rewardType = "Boon",
        payload = { source = "ApolloUpgrade" },
    },
}
```

## Completeness and Addressing

The `None` instances are locally complete without persistence. `Q_Intro` is
complete only when its opening reward is concrete. The control owns no root
selection, outgoing topology, or intro counter effects.
