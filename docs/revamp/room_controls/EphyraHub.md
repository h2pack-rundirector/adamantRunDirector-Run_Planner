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
and canonical room fragment. It owns no outgoing topology.

The `HubBiome` layout owns the fixed entry sequence, one persistent hub batch,
its physical door targets, the ordered six-room visited subset, derived hub
returns, and the post-visit terminal transition. `EphyraHubBatch` governs only
the persistent peer batch's composition and peer-wide state. Hub-return history
entries do not create repeated Hub controls.

## Completeness and Addressing

The local fragment is always complete. Structural completeness belongs to the
`HubBiome` topology, including its persistent batch and terminal transition.
The control exports no reward or local-child candidates.
