# `Preboss` Room Control

## Coverage

Every supported biome has exactly one terminal preboss control:

| Biome steps | Rooms | Entry offers | Shop profile |
| --- | --- | --- | --- |
| `Underworld_F/G/H`, `Surface_P` | `F_PreBoss01`, `G_PreBoss01`, `H_PreBoss01`, `P_PreBoss01` | Shop plus zero, one, or two free rewards | `WorldShop` |
| `Underworld_I` | `I_PreBoss01` | Shop only | `I_WorldShop` |
| `Surface_N/O` | `N_PreBoss01`, `O_PreBoss01` | Shop only | `WorldShop` |
| `Surface_Q` | `Q_PreBoss01` | Shop only | `Q_WorldShop` |

`I_PreBoss02` is a post-true-ending save-progression variant. The planner does
not model save progression and therefore excludes it from the supported room
catalog and terminal set.

`PrebossShopOrFreeReward` is not a reward surface. The F/G/H/P behavior is a
preboss-level offer set that composes one shop inventory with bounded ordinary
room rewards.

## Shop-Only Variants

Shop-only controls have no entry-mode persistence. Their entry is statically
Shop and they author the declaration-selected inventory profile:

- `WorldShop`: `Boon`, `MajorNonBoon`, and `Minor`;
- `I_WorldShop`: five `GroupNOffer1` slots;
- `Q_WorldShop`: six slots, including two primary offers.

Every slot owns a concrete option and a `purchased` boolean. Q primary
uniqueness remains a validator constraint rather than a storage-layout rule.
The fixed `ClockworkGoal` door marker used by `I_PreBoss01` is execution
metadata; it does not turn the control into a Clockwork combat or free-reward
variant.

## Shop-Plus-Reward Variants

F/G/H/P prebosses reserve maximum storage for the shop and two free rewards:

```lua
{
    kind = "Preboss",
    entryMode = "Reward1", -- "" | Shop | Reward1 | Reward2
    shop = {
        profileKey = "WorldShop",
        slots = { ... },
    },
    freeRewards = {
        [1] = {
            storeKey = "RunProgress",
            rewardType = "Boon",
            payload = { source = "ApolloUpgrade" },
        },
        [2] = {
            storeKey = "RunProgress",
            rewardType = "MaxHealthDrop",
        },
    },
}
```

The incoming physical exit count determines active offers and is never copied
into persistence:

```text
one exit   -> Shop
two exits  -> Shop + Reward1
three exits -> Shop + Reward1 + Reward2
```

The two free slots are a bounded maximum. F/H/P cannot activate `Reward2`; G
can activate it when the concrete source room has three exits. Declaration-
impossible values may be hidden. A generally possible but context-inactive
value remains visible and invalid under the common UI rules.

The game implements these offers by assigning the same forced `X_PreBoss01`
room to each exit. `ForcedFirstReward = "Shop"` supplies the Shop offer; later
copies fall through to the eligible `RunProgress` reward picker. The selected
door's `ChosenRewardType` determines which physical realization of the one map
is entered.

## Completeness, Acquisition, and Dormancy

All active offers must be completely authored because reward simulation uses
picked and unpicked offers. `entryMode` must select one active offer.

Only the selected entry contributes acquisitions:

- Shop acquires shop slots whose `purchased` value is true;
- Reward1 acquires only `freeRewards[1]`;
- Reward2 acquires only `freeRewards[2]`.

Unselected offers remain part of the offered-reward simulation but contribute
no acquisition. Inactive bounded slots and shop purchase state while a free
entry is selected remain persistent and dormant. The execution-plan compiler
derives acquisition; no second acquired-reward field is persisted.

Addresses use the preboss room owner plus semantic `shop` or `freeRewardN`
local keys. Terminal topology, source exit count, and boss linkage remain
biome-owned facts supplied to the control as immutable context.
