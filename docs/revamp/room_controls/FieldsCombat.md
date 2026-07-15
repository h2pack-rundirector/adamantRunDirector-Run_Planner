# `FieldsCombat` Room Control

## Coverage

All 15 `Underworld_H` rooms `H_Combat01..15` use:

- reward surface `FieldsCages`;
- encounter profile `FieldsCombat`;
- local slots `cage1`, `cage2`, and `cage3`.

The room metadata affecting batch capacity is:

| Rooms | Effective maximum | Raw room maximum |
| --- | ---: | ---: |
| `H_Combat01`, `05`, `06`, `10`, `11` | 3 | 5 |
| `H_Combat04` | 3 | 4 |
| `H_Combat02`, `03`, `07`, `08`, `12`, `15` | 3 | 3 |
| `H_Combat09`, `13`, `14` | 2 | 2 |

These metadata values are immutable inputs to `FieldsCageBatch`; they are not
persisted Room Control choices.

## Owned State

The control owns three bounded cage reward selections:

```lua
{
    kind = "FieldsCombat",
    cages = {
        cage1 = {
            reward = {
                storeKey = "RunProgress",
                rewardType = "Boon",
                payload = { source = "ApolloUpgrade" },
            },
        },
        cage2 = { reward = { ... } },
        cage3 = { reward = { ... } },
    },
}
```

Each slot fixes the store to `RunProgress` and persists `rewardType`,
`source1`, and `source2`; Devotion requires the second source. The physical
room declaration supplies the three stable slot keys.

The control does not persist an active cage count. `FieldsCageBatch` owns the
Min/Max roll and derives whether two or three slots are active for this target.

## Dormancy and Completeness

Only the batch-derived active prefix of cage slots participates:

- active count two: `cage1` and `cage2` are required; `cage3` is dormant;
- active count three: all three are required;
- an unreferenced room control: all slots are dormant;
- a non-Fields target in the same batch activates no cage slots.

Changing batch state does not reset a newly dormant cage reward.

## Candidates and Feedback

Each active cage exports one reward provider addressed by the parent
`roomControlKey`, its `localSlotKey`, and `aspect = "generatedReward"`.
Batch-wide uniqueness constraints validate the complete active set; the
control does not filter peers by reading sibling controls during draw.
