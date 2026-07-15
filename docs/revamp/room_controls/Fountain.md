# `Fountain` Room Control

## Coverage

| Biome step | Room | Reward surface | Encounter profile |
| --- | --- | --- | --- |
| `Underworld_F` | `F_Reprieve01` | `RunProgressMinorMajor` | `HealthRestore` |
| `Underworld_G` | `G_Reprieve01` | `RunProgressMinorMajor` | `HealthRestore` |
| `Underworld_I` | `I_Reprieve01` | `TartarusNoDevotion` | `HealthRestore` |
| `Surface_O` | `O_Reprieve01` | `RunProgressMinorMajor` | `HealthRestore` |
| `Surface_P` | `P_Reprieve01` | `RunProgressMinorMajor` | `HealthRestore` |

## Owned State

The control owns the incoming reward; the health-restoration encounter remains
a fixed profile fact.

For the common surface:

```lua
{
    kind = "Fountain",
    generatedReward = {
        storeKey = "MetaProgress",
        rewardType = "GiftDrop",
    },
}
```

Logical fields are `storeKey`, `rewardType`, `source1`, and `source2` because
the common `RunProgress` domain includes Devotion.

The I variant fixes `storeKey = "TartarusRewards"`, disallows Devotion, and
therefore needs only `rewardType` and one conditional Boon source field.

## Completeness and Addressing

Only the concrete active surface participates. Completeness and candidates use
`aspect = "generatedReward"`. The template rejects any other surface/profile
combination.
