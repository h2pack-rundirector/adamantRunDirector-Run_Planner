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
room as I's declared terminal and excludes `I_PreBoss01`. Every supported
biome therefore has one terminal preboss control.

## Contract

A direct preboss is always entered as its shop realization. The Room Control
has no entry-mode persistence and its local shop state has no dependency on the
selected predecessor's exit count:

```lua
{
    templateKey = "DirectPreboss",
    incomingReward = { kind = "shop", shopProfileKey = "I_WorldShop" },
    entryOfferPolicy = { kind = "shopOnly" },
}
```

The catalog validates that `incomingReward` is a shop binding and that the direct
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
execution metadata; it does not create an alternate Room Control entry
surface.

## Structural Context

Direct local reward behavior does not imply one universal terminal topology.
The biome layout supplies the terminal exit policy to `PrebossEntry`:

- N/O/Q use `singleTerminal` and have no ordinary companion target;
- I uses `terminalWithCompanions`; on a two-exit predecessor the selected
  `I_PreBoss02` shop occupies the first active physical exit and the remaining
  exit contains one ordinary unpicked I target.

The I companion is not state inside this control. Its link belongs to the
terminal transition, while its reward and local fragment belong to its own Room
Control. This DirectPreboss instance remains exactly the same shop-only local
surface in both one- and two-exit contexts.

This control exists in the active topology only when `I_PreBoss02` is selected
and entered through `Go to Preboss`. If an eligible two-exit Clockwork batch
selects the ordinary room instead, the batch realization derives an unpicked
preboss creation and fixed Shop door offer without referencing this control or
exposing its shop slots. A later predecessor may derive the offer again because
`MaxCreationsPerRoom` is predecessor-local; those offers never become repeated
DirectPreboss instances.

## Completeness and Acquisition

Every profile slot requires a complete option. Slots with `purchased = true`
emit acquisitions; other offered slots do not. There is no dormant entry
branch or entry selection to validate.

The biome layout owns terminal membership, and `PrebossEntry` owns the
structural transition, terminal exit policy, companion links where admitted,
and boss linkage. The DirectPreboss control owns only its shop realization.
Addresses use the preboss room owner plus the shop profile's semantic slot key.
