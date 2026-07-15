# `Miniboss` Room Control

## Coverage

| Biome steps | Rooms | Reward surface | Encounter profiles |
| --- | --- | --- | --- |
| `Underworld_F` | `F_MiniBoss01..03` | `RunProgressBoonOnly` | matching `F_MiniBossXX` |
| `Underworld_G` | `G_MiniBoss01..03` | `RunProgressBoonOnly` | matching `G_MiniBossXX` |
| `Underworld_H` | `H_MiniBoss01..02` | `RunProgressBoonOnly` | matching `H_MiniBossXX` |
| `Underworld_I` | `I_MiniBoss01..02` | `RunProgressBoonOnly` | matching `I_MiniBossXX` |
| `Surface_N` | `N_MiniBoss01`, `N_MiniBoss02` | `RunProgressBoonOnly` | `MiniBossSatyrCrossbow`, `MiniBossBoar` |
| `Surface_O` | `O_MiniBoss01..02` | `RunProgressBoonOnly` | matching `O_MiniBossXX` |
| `Surface_P` | `P_MiniBoss01..02` | `RunProgressBoonOnly` | matching `P_MiniBossXX` |
| `Surface_Q` | `Q_MiniBoss02..05` | `TyphonBossReward` | `MiniBossBrute`, `Q_MiniBoss03..05` as declared |

The Q range means the concrete set `02`, `03`, `04`, and `05`; there is no
`Q_MiniBoss01` control.

## Owned State

`RunProgressBoonOnly` declaration-proves both the `RunProgress` store and
`Boon` reward type. Those instances persist only the concrete Boon source:

```lua
{
    kind = "Miniboss",
    generatedReward = {
        storeKey = "RunProgress",
        rewardType = "Boon",
        payload = { source = "ApolloUpgrade" },
    },
}
```

Q uses `TyphonBossRewards`, whose allowed concrete reward types include Boon,
Path, Pom, and Hammer outcomes. Q instances persist `rewardType` and one
conditional Boon source field; the store key is fixed.

Encounter profile identity is immutable per concrete room. The template does
not author which miniboss is entered or Q peer pairing.

## Completeness and Addressing

The incoming reward and active payload must be concrete. Candidates and
feedback use `aspect = "generatedReward"`.
