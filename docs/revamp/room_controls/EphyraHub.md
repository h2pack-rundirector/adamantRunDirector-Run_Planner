# `EphyraHub` Room Control

## Coverage

| Biome step | Room | Reward binding | Encounter profile |
| --- | --- | --- | --- |
| `Surface_N` | `N_Hub` | none | `None` |

## Owned State

`EphyraHub` has no room-local authored persistence:

```lua
{
    kind = "EphyraHub",
    generatedReward = nil,
}
```

It remains a real Room Control because it is a stable top-level room identity
and canonical room fragment.

The `EphyraHubBatch` owns physical hub doors, nine-or-ten generated targets,
and ordered six-room visitation. Hub-return history entries are derived and do
not create repeated Hub controls.

## Completeness and Addressing

The local fragment is always complete. Structural completeness belongs to the
Hub batch. The control exports no reward or local-child candidates.
