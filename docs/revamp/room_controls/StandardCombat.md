# `StandardCombat` Room Control

## Coverage

| Biome step | Rooms | Counted stores | Ineligible | Encounter profile |
| --- | --- | --- | --- | --- |
| `Underworld_F` | `F_Combat01` | RunProgress | Devotion | `StandardCombat` |
| `Underworld_F` | `F_Combat02..22` | RunProgress, MetaProgress | -- | `StandardCombat` |
| `Underworld_G` | `G_Combat04`, `05`, `07`, `08` | RunProgress, MetaProgress | Devotion | `StandardCombat` |
| `Underworld_G` | all other `G_Combat01..20` | RunProgress, MetaProgress | -- | `StandardCombat` |
| `Surface_Q` | `Q_Combat01..09`, `Q_Combat12..16` | RunProgress, MetaProgress | Devotion | `StandardCombat` |

These 56 rooms are the complete current coverage. Other producer kinds, profiles,
local children, or room kinds are assembly errors.

## Owned State

The control owns one concrete incoming reward selected from `RunProgress` or
`MetaProgress`:

```lua
{
    kind = "StandardCombat",
    generatedReward = {
        storeKey = "RunProgress",
        rewardType = "Devotion",
        payload = {
            sources = { "ApolloUpgrade", "ZeusUpgrade" },
        },
    },
}
```

Logical persistence:

```lua
{
    storeKey = "",
    rewardType = "",
    source1 = "",
    source2 = "",
}
```

Payload fields are active only for the selected primitive. Assembly compiles
each room's stores and negative filter. Unfiltered instances reserve two
source fields because RunProgress can produce Devotion; rooms excluding
Devotion reserve only one Boon source. `F_Combat01` fixes RunProgress and also
reserves only one source. No combat room owns its exits, next-room candidates,
picked state, eligibility, or canonical combat-family remapping.

## Completeness and Addressing

The generated reward must be concrete and payload-complete. The semantic owner
address uses `aspect = "generatedReward"`. Encounter phase `Combat` is a fixed
profile fact and carries no authored choice.
