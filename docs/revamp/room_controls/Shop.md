# `Shop` Room Control

## Coverage

| Biome steps | Rooms | Reward surface | Encounter profile |
| --- | --- | --- | --- |
| `Underworld_F/G`, `Surface_O/P` | `F_Shop01`, `G_Shop01`, `O_Shop01`, `P_Shop01` | `WorldShop` | `Shop` |

## Owned State

Every instance owns the three declaration-fixed World Shop slots:

```lua
{
    kind = "Shop",
    shop = {
        profileKey = "WorldShop",
        slots = {
            Boon = {
                reward = {
                    rewardType = "RandomLoot",
                    payload = { source = "ApolloUpgrade" },
                },
                purchased = true,
            },
            MajorNonBoon = {
                reward = { rewardType = "MaxHealthDrop" },
                purchased = false,
            },
            Minor = {
                reward = { rewardType = "StackUpgrade" },
                purchased = true,
            },
        },
    },
}
```

Each slot persists a concrete reward type, any required source payload, and a
`purchased` boolean. `false` means the offer was not acquired; the reward
selection itself carries completeness.

The template does not consume counted reward bags for shop offers.

## Completeness and Addressing

All three slots require a valid option-set reward. Addresses append
`localSlotKey` equal to the shop slot key and use
`aspect = "offeredReward"` or `aspect = "purchased"`.
