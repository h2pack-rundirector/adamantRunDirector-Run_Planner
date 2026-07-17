# `ForkedPreboss` Room Control

## Coverage

| Biome steps | Rooms | Shop profile | Free reward store | Maximum free rewards |
| --- | --- | --- | --- | --- |
| `Underworld_F/H`, `Surface_P` | `F_PreBoss01`, `H_PreBoss01`, `P_PreBoss01` | `WorldShop` | `RunProgress` | 1 |
| `Underworld_G` | `G_PreBoss01` | `WorldShop` | `RunProgress` | 2 |

These rooms use one shop realization and fill every other physical door of the
selected predecessor with a free reward. Devotion and `RoomMoneyDrop` are
ineligible free rewards.

Their biome terminal declarations use the `allExitsTerminal` exit policy. The
layout therefore maps every predecessor exit to a realization of this same one
terminal Room Control; none of those exits contains an ordinary companion room.

`PrebossShopOrFreeReward` is not a reward surface. The behavior is a
preboss-level offer policy combining a shop component with bounded ordinary
bag-backed reward choices.

Every covered room declares that composition explicitly:

```lua
{
    templateKey = "ForkedPreboss",
    incomingReward = { kind = "shop", shopProfileKey = "WorldShop" },
    entryOfferPolicy = {
        kind = "shopThenFillRemainingExits",
        freeReward = {
            kind = "countedChoice",
            storeKeys = { "RunProgress" },
            ineligibleRewardTypes = { "Devotion", "RoomMoneyDrop" },
        },
        maxFreeRewards = 1, -- F/H/P; G declares 2
    },
}
```

Each free slot receives the compiled counted binding shown above. The shared
template supports two slots, while the catalog requires each instance bound
to match its biome's maximum declared predecessor exits minus one.

## Bounded Authored State

Every instance reserves maximum storage for one complete World Shop and its
topology-bounded free rewards. The following is the two-slot G shape; F/H/P
only contain `freeRewards[1]` and do not persist an impossible Reward2:

```lua
{
    kind = "ForkedPreboss",
    entryMode = "Reward1", -- Shop | Reward1 | Reward2
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

Fresh and reset state uses `entryMode = "Shop"`; every shop and free-reward
slot is also initialized from its declaration defaults. Mode and reward editors
replace concrete values and never return them to empty.

The per-instance maximum is storage capacity, not a declaration that every
predecessor has that many exits. Inactive values within that bound remain
persisted and dormant.

## Incoming Topology Context

This template is intentionally contextual. The selected predecessor's
physical exit count determines the active offer set:

```text
one exit    -> Shop
two exits   -> Shop + Reward1
three exits -> Shop + Reward1 + Reward2
```

During normalized topology construction, the registered `PrebossEntry`
structural rule validates `allExitsTerminal` and derives this immutable context
from the selected predecessor and its Room Declaration:

```lua
{
    leadingRoomControlKey = "Underworld_G_Combat04",
    incomingExitCount = 3,
    activeFreeRewardCount = 2,
}
```

The control never queries the leading Room Control and never persists any of
these derived facts. Its ordinary read returns the complete bounded authored
state. The committed rebuild passes the derived transition context to local
completeness, the terminal materializer, candidates, and feedback preparation.
The LinearBiome UI projector places their prepared owner-keyed state into the
published terminal view. The long-lived Biome Plan does not cache the context,
and draw only consumes the published projection.

This preserves one-way ownership:

```text
selected topology
  -> leading room declaration
  -> PrebossEntry context
  -> active ForkedPreboss offers
```

Changing the selected predecessor recomputes context without clearing
persistence. A newly inactive reward slot remains dormant. An `entryMode` that
no longer names an active offer becomes invalid and is not silently coerced.

## Offer and Acquisition Semantics

All active offers must be completely authored because reward simulation uses
picked and unpicked offers. `entryMode` must select exactly one active offer.

The values belong to the ForkedPreboss control. The `PrebossEntry` terminal
materializer places their concrete offers into the canonical terminal entry in
physical order, and `historyLayouts["LinearBiome"]` emits their offer events
while the leading room generates its physical exits:

```text
offer Shop
offer Reward1, when active
offer Reward2, when active
pick one realization
enter the single X_PreBoss01 room control
```

Only the selected realization contributes acquisitions:

- Shop acquires shop slots whose `purchased` value is true;
- Reward1 acquires only `freeRewards[1]`;
- Reward2, available only to G, acquires only `freeRewards[2]`.

Unselected offers remain in offered-reward history but do not contribute
acquisition. The execution-plan compiler derives acquisition; no second
acquired-reward field is persisted.

Addresses use the preboss room owner plus semantic `shop` or `freeRewardN`
local keys. Physical exits, the leading room selection, offer-event timing,
and boss linkage remain layout/transition-owned.
