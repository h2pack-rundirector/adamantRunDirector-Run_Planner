# `Miniboss` Room Control

## Coverage

| Biome steps | Rooms | Counted stores | Eligible | Encounter profiles |
| --- | --- | --- | --- | --- |
| `Underworld_F` | `F_MiniBoss01..03` | RunProgress | Boon | matching `F_MiniBossXX` |
| `Underworld_G` | `G_MiniBoss01..03` | RunProgress | Boon | matching `G_MiniBossXX` |
| `Underworld_H` | `H_MiniBoss01..02` | RunProgress | Boon | matching `H_MiniBossXX` |
| `Underworld_I` | `I_MiniBoss01..02` | TartarusRewards | Boon | matching `I_MiniBossXX` |
| `Surface_N` | `N_MiniBoss01`, `N_MiniBoss02` | RunProgress | Boon | `MiniBossSatyrCrossbow`, `MiniBossBoar` |
| `Surface_O` | `O_MiniBoss01..02` | RunProgress | Boon | matching `O_MiniBossXX` |
| `Surface_P` | `P_MiniBoss01..02` | RunProgress | Boon | matching `P_MiniBossXX` |
| `Surface_Q` | `Q_MiniBoss02..05` | TyphonBossRewards | -- | `MiniBossBrute`, `Q_MiniBoss03..05` as declared |

The Q range means the concrete set `02`, `03`, `04`, and `05`; there is no
`Q_MiniBoss01` control.

## Owned State

The concrete bindings declaration-prove both their counted bag and positive
Boon filter. F/G/H/N/O/P use RunProgress; I inherits TartarusRewards. Every
such instance persists only the concrete Boon source:

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

The I typed value differs only in
`storeKey = "TartarusRewards"`. Keeping that provenance is necessary for
correct bag history even though the visible payload shape is identical.

Q uses `TyphonBossRewards`, whose allowed concrete reward types include Boon,
Path, Pom, and Hammer outcomes. Q instances persist `rewardType` and one
conditional Boon source field; the store key is fixed.

Encounter profile identity is immutable per concrete room. The template does
not author which miniboss is entered or Q peer pairing.

## Completeness and Addressing

The incoming reward and active payload must be concrete. Candidates and
feedback use `aspect = "generatedReward"`.
