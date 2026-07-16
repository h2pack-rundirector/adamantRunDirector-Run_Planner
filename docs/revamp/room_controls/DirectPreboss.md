# `DirectPreboss` Room Control

## Coverage

| Biome steps | Room | Shop profile |
| --- | --- | --- |
| `Underworld_I` | `I_PreBoss02` | `I_WorldShop` |
| `Surface_N/O` | `N_PreBoss01`, `O_PreBoss01` | `WorldShop` |
| `Surface_Q` | `Q_PreBoss01` | `Q_WorldShop` |

Vanilla selects `I_PreBoss01` before the true ending or during a dream run and
selects `I_PreBoss02` after the true ending. Save progression is outside the
planner model, so the planner canonically selects the later `I_PreBoss02`
layout and excludes `I_PreBoss01`. Every supported biome therefore has one
terminal preboss control.

## Contract

A direct preboss is always entered as its shop realization. It has no
entry-mode persistence and no dependency on the selected predecessor's exit
count:

```lua
{
    templateKey = "DirectPreboss",
    reward = { kind = "shop", shopProfileKey = "I_WorldShop" },
    entryOfferPolicy = { kind = "shopOnly" },
}
```

The catalog validates that `reward` is a shop binding and that the direct
policy has no alternate-offer fields. The control's authored value then has
this shape:

```lua
{
    kind = "DirectPreboss",
    shop = {
        profileKey = "I_WorldShop",
        slots = { ... },
    },
}
```

The template injects the shared profile-parameterized shop component:

- `WorldShop` authors three semantic slots;
- `I_WorldShop` authors five semantic slots;
- `Q_WorldShop` authors six semantic slots.

Every slot owns a concrete option and a `purchased` boolean. Q primary
uniqueness remains a validator constraint rather than a storage-layout rule.
The inherited fixed `ClockworkGoal` door marker used by `I_PreBoss02` is
execution metadata; it does not create an alternate entry realization.

## Completeness and Acquisition

Every profile slot requires a complete option. Slots with `purchased = true`
emit acquisitions; other offered slots do not. There is no dormant entry
branch or entry selection to validate.

Terminal topology and boss linkage remain biome-owned. Addresses use the
preboss room owner plus the shop profile's semantic slot key.
