# `Story` Room Control

## Coverage

| Biome steps | Rooms | Reward surface | Encounter profile |
| --- | --- | --- | --- |
| `Underworld_F/G/I`, `Surface_N/O/P` | `F_Story01`, `G_Story01`, `I_Story01`, `N_Story01`, `O_Story01`, `P_Story01` | `FixedStory` | `Story` |
| `Underworld_H` | `H_Bridge01` | `FixedStory` | `FieldsBridge` |

## Owned State

The incoming reward is declaration-fixed and has no payload:

```lua
{
    kind = "Story",
    generatedReward = { rewardType = "Story" },
}
```

The control has no persisted fields. It must reject reward replacement rather
than storing a redundant `Story` string.

Story encounter identity and all eligibility/force differences remain in the
concrete room declarations. `H_Bridge01` uses this same control template: its
baseline supported realization is the fixed Echo story, while bridge topology
and any deferred NPC variants are outside the control.

## Completeness and Addressing

The local fragment is always complete. The fixed generated reward can still
carry `aspect = "generatedReward"` as a canonical return address, but it has no
editable candidate provider unless a future feature makes the reward authored.
