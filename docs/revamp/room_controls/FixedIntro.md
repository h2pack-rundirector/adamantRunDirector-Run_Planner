# `FixedIntro` Room Control

## Coverage

| Biome steps | Rooms | Reward binding | Encounter profile |
| --- | --- | --- | --- |
| `Underworld_G/H/I`, `Surface_O/P` | `G_Intro`, `H_Intro`, `I_Intro`, `O_Intro`, `P_Intro` | none | `FixedIntro` |
| `Surface_Q` | `Q_Intro` | RunProgress; exclude Devotion, gold, max health, max magick | `FixedIntro` |

The Q variant is intentionally stateful even though the other five instances
are storage-free. The template must therefore consume its injected compiled
reward binding rather than assuming every intro is empty.

## Owned State

For `none`:

```lua
{ kind = "FixedIntro", generatedReward = nil }
```

For `Q_Intro` logical persistence is:

```lua
{
    rewardType = "Boon",
    source = "ApolloUpgrade",
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

The `none` instances are locally complete without persistence. `Q_Intro`
starts from its complete opening-reward default. The control owns no root
selection, outgoing topology, or intro counter effects.
