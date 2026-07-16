# `Fountain` Room Control

## Coverage

| Biome step | Room | Counted stores | Ineligible | Encounter profile |
| --- | --- | --- | --- | --- |
| `Underworld_F` | `F_Reprieve01` | RunProgress, MetaProgress | Devotion | `HealthRestore` |
| `Underworld_G` | `G_Reprieve01` | RunProgress, MetaProgress | Devotion | `HealthRestore` |
| `Underworld_I` | `I_Reprieve01` | TartarusRewards | Devotion | `HealthRestore` |
| `Surface_O` | `O_Reprieve01` | RunProgress, MetaProgress | Devotion | `HealthRestore` |
| `Surface_P` | `P_Reprieve01` | RunProgress, MetaProgress | Devotion | `HealthRestore` |

## Owned State

The control owns the incoming reward; the health-restoration encounter remains
a fixed profile fact.

For the common two-store binding:

```lua
{
    kind = "Fountain",
    generatedReward = {
        storeKey = "MetaProgress",
        rewardType = "GiftDrop",
    },
}
```

Each common fountain explicitly or by biome inheritance excludes Devotion.
Logical fields are `storeKey`, `rewardType`, and one conditional Boon
`source1`.

The I binding fixes `storeKey = "TartarusRewards"` and declares the same
Devotion exclusion. It therefore also needs only `rewardType` and one
conditional Boon source field.

## Completeness and Addressing

Only the injected compiled binding participates. Completeness and candidates
use `aspect = "generatedReward"`. The template rejects any unsupported
producer/profile combination.
