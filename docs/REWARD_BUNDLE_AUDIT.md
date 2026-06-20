# Reward Bundle Audit

Run Planner reward bundles should describe what a vanilla room or shop surface
can offer. They should not encode route-history legality such as whether
`TalentDrop` is currently legal. That second layer belongs in route reward
validation/runtime resolution.

This audit compares `src/mods/rewards/definitions.lua` against vanilla data in:

- `Scripts/LootData.lua`
- `Scripts/RewardData.lua`
- `Scripts/RoomDataF/G/H/I/N/O/P/Q.lua`
- `Scripts/StoreData.lua`

## Audit Rules

- Collapse duplicate weighted vanilla entries to one planner choice.
- Apply structural room filters such as `IneligibleRewards` when a bundle is
  specifically modeling that room surface.
- Keep dynamic run-state requirements out of bundle composition. Examples:
  `TalentLegal`, `SpellDropRequirements`, `StackUpgradeLegal`,
  `HammerLootRequirements`, and first-half/second-half shop requirements.
- Keep Dream Run / Dream Dive reward replacements out of normal-route bundles
  unless a later Dream Run pass explicitly models them.
- Keep `Devotion` in vanilla-derived broad reward bundles, then expose or
  filter it at the room/reward-context layer. F/G/I combat maps can opt into it;
  unrelated room surfaces should filter it out.

## Findings

### `RunProgress`

Vanilla source: `RewardStoreData.RunProgress`.

Vanilla unique rewards:

- `Boon`
- `HermesUpgrade`
- `Devotion`
- `WeaponUpgrade`
- `MaxHealthDrop`
- `MaxManaDrop`
- `RoomMoneyDrop`
- `StackUpgrade`
- `Devotion`
- `SpellDrop`
- `TalentDrop`

Planner bundle:

- `Boon`
- `HermesUpgrade`
- `Devotion`
- `WeaponUpgrade`
- `MaxHealthDrop`
- `MaxManaDrop`
- `RoomMoneyDrop`
- `StackUpgrade`
- `SpellDrop`
- `TalentDrop`

Status: aligned.

`Devotion` is present in the broad bundle, but normal room contexts filter it
unless the selected combat map is devotion-capable. `TalentDrop` should stay
because it is part of vanilla `RunProgress`; its `TalentLegal` dependency should
be handled by route reward validation, not by removing it from the bundle.

### `OpeningRunProgress`

Vanilla source: F/N opening and pre-hub rooms use `RunProgress` with
`RewardSets.OpeningRoomBans`.

Structural bans:

- `Devotion`
- `RoomMoneyDrop`
- `MaxHealthDrop`
- `MaxManaDrop`

Normal-route effective choices:

- `Boon`
- `HermesUpgrade`
- `WeaponUpgrade`
- `StackUpgrade`
- `SpellDrop`

Planner bundle:

- `Boon`
- `HermesUpgrade`
- `WeaponUpgrade`
- `StackUpgrade`
- `SpellDrop`

Status: aligned after the current correction.

`TalentDrop` is not included here because first-biome normal route openings do
not satisfy the `EnteredBiomes > 1` part of vanilla `RunProgress.TalentDrop`.

### `PreBossRunProgress`

Vanilla source: F/G/P preboss non-shop branches use `RunProgress` with
`IneligibleRewards = { "Devotion", "RoomMoneyDrop" }`.

Normal-route effective choices:

- `Boon`
- `HermesUpgrade`
- `WeaponUpgrade`
- `MaxHealthDrop`
- `MaxManaDrop`
- `StackUpgrade`
- `SpellDrop`
- `TalentDrop`

Planner bundle:

- `Boon`
- `HermesUpgrade`
- `WeaponUpgrade`
- `MaxHealthDrop`
- `MaxManaDrop`
- `StackUpgrade`
- `SpellDrop`
- `TalentDrop`

Status: aligned.

`TalentDrop` should stay, with `TalentLegal` handled by the dependency layer.

### `MetaProgress`

Vanilla source: `RewardStoreData.MetaProgress`.

Planner usage: the `majorMinor` control uses this as the player-facing minor
reward branch for ordinary combat/fountain rows.

Planner bundle:

- `GiftDrop`
- `MetaCurrencyDrop`
- `MetaCurrencyBigDrop`
- `MetaCardPointsCommonDrop`
- `MetaCardPointsCommonBigDrop`

Status: intentional simplification.

The vanilla store has many run-progress and progression gates. The planner
keeps a curated normal-route minor reward surface and does not currently model
Dream Run elemental replacements here.

### `HubRewards`

Vanilla source: `RewardStoreData.HubRewards`.

Vanilla unique rewards:

- `Boon`
- `HermesUpgrade`
- `WeaponUpgrade`
- `MaxHealthDropBig`
- `MaxManaDropBig`
- `SpellDrop`

Planner bundle:

- `Boon`
- `HermesUpgrade`
- `WeaponUpgrade`
- `MaxHealthDropBig`
- `MaxManaDropBig`
- `SpellDrop`

Status: aligned.

The vanilla Devotion entry in this store is commented out, so it is not modeled.

### `EasyHubRewards`

Vanilla source: N combat rooms with `RewardSets.HubCombatRoomEasyBans` applied
to `HubRewards`.

Structural bans remove:

- `Devotion`
- `WeaponUpgrade`
- `HermesUpgrade`
- `HephaestusUpgrade`

Planner bundle:

- `Boon`
- `MaxHealthDropBig`
- `MaxManaDropBig`
- `SpellDrop`

Status: aligned.

### `SubRoomRewards`

Vanilla source: `RewardStoreData.SubRoomRewards`.

Vanilla unique rewards:

- `MaxManaDropSmall`
- `MaxHealthDropSmall`
- `EmptyMaxHealthSmallDrop`
- `RoomMoneyTinyDrop`
- `AirBoost`
- `EarthBoost`
- `FireBoost`
- `WaterBoost`
- `GiftDrop`
- `MetaCurrencyDrop`
- `MetaCardPointsCommonDrop`
- `MaxHealthDrop`
- `MaxManaDrop`
- `StackUpgrade`
- `RoomMoneyDrop`
- `MinorTalentDrop`

Planner bundle matches these unique rewards.

Status: aligned.

This is the concrete case where `MinorTalentDrop` is a valid bundle member but
`SpellDrop` is not part of the vanilla surface. Do not add `SpellDrop` here to
solve `TalentLegal`; model that dependency separately.

### `SubRoomRewardsHard`

Vanilla source: `RewardStoreData.SubRoomRewardsHard`.

Vanilla unique rewards:

- `MaxHealthDrop`
- `MaxManaDrop`
- `StackUpgrade`
- `RoomMoneyDrop`

Planner bundle matches these unique rewards.

Status: aligned.

### `TartarusRewards`

Vanilla source: `RewardStoreData.TartarusRewards`.

Vanilla unique rewards:

- `Boon`
- `WeaponUpgrade`
- `Devotion`
- `StackUpgradeTriple`
- `TalentBigDrop`
- `RoomMoneyTripleDrop`
- `Devotion`

Planner bundle:

- `Boon`
- `WeaponUpgrade`
- `StackUpgradeTriple`
- `TalentBigDrop`
- `RoomMoneyTripleDrop`

Status: aligned with planner model.

`Devotion` is present for Tartarus extension combat, while non-combat Tartarus
surfaces filter it out. `TalentBigDrop` depends on `TalentLegal`; that should be
a route reward dependency, not a bundle edit.

### `ClockworkExtensionRewards`

Vanilla source: I combat rooms use `TartarusRewards` and inherit
`I_BaseCombat`, which applies `IneligibleRewards = { "Boon" }` and
`ForcedFirstReward = "ClockworkGoal"`.

Planner bundle:

- `WeaponUpgrade`
- `Devotion`
- `StackUpgradeTriple`
- `TalentBigDrop`
- `RoomMoneyTripleDrop`

Status: aligned with planner model.

This bundle is planner-specific rather than a direct vanilla store name. It
models Tartarus extension combat, not fountains or the preboss room. `Boon` is
excluded by `I_BaseCombat`; `Devotion` remains available as the Trial reward
choice for extension combat.

### `TyphonBossRewards`

Vanilla source: `RewardStoreData.TyphonBossRewards`.

Vanilla unique rewards:

- `Boon`
- `TalentBigDrop`
- `StackUpgradeTriple`
- `WeaponUpgrade`

Planner bundle matches these unique rewards.

Status: aligned.

`TalentBigDrop` depends on `TalentLegal`; keep that dependency outside bundle
composition.

## Shop Bundles

### `WorldShop`

Vanilla source: `StoreData.WorldShop`.

Planner mapping:

- `WorldShopBoon`: `RandomLoot`, `BlindBoxLoot`, `ShopHermesUpgrade`
- `WorldShopNonBoon`: `WeaponUpgradeDrop`, `RoomRewardHealDrop`,
  `MaxHealthDrop`, `ArmorBoost`, `MetaCardPointsCommonDrop`,
  `MetaCurrencyDrop`, `GiftDrop`
- `WorldShopMinor`: `MaxManaDrop`, `StackUpgrade`,
  `StoreRewardRandomStack`, `SpellDrop`, `TalentDrop`

Status: aligned for normal routes.

Dream Run elemental replacements in the non-boon slot are intentionally out of
scope for this pass.

### `I_WorldShop`

Vanilla source: `StoreData.I_WorldShop`.

Planner mapping:

- `TartarusShopPriorityPower`: `RandomLoot`, `BoostedRandomLoot`,
  `StackUpgradeBig`
- `TartarusShopMixedReward`: `RandomLoot`, `BlindBoxLoot`,
  `MaxHealthDrop`, `MaxManaDrop`, `StackUpgrade`, `TalentDrop`, `SpellDrop`
- `TartarusShopSurvival`: `RoomRewardHealDrop`, `ArmorBoost`,
  `HealBigDrop`, `ArmorBigBoost`, `LastStandDrop`
- `TartarusShopMajorPower`: `WeaponUpgradeDrop`, `RandomLoot`,
  `BlindBoxLoot`, `ShopHermesUpgrade`, `ChaosWeaponUpgrade`,
  `BoostedRandomLoot`, `MaxHealthDropBig`, `MaxManaDropBig`
- `EndShopResource`: `WeaponPointsRareDrop`, `CardUpgradePointsDrop`,
  `CharonPointsDrop`

Status: aligned for normal routes.

Dream Run `ElementalBoost` in the resource group is intentionally out of scope.

### `Q_WorldShop`

Vanilla source: `StoreData.Q_WorldShop`.

Planner mapping:

- Group 1 has two offers from `EndShopPrimaryPower`.
- Group 2 maps to `EndShopSecondaryReward`.
- Group 3 maps to `TartarusShopSurvival`.
- Group 4 maps to `EndShopMajorPower`.
- Group 5 maps to `EndShopResource`.

Status: aligned for normal routes.

The existing duplicate-offer invalidation for Q group 1 is correct because
vanilla draws two offers from the same group.

## Reward Dependency Notes

These are not bundle corrections:

- `TalentDrop` requires `TalentLegal`, including prior current-run
  `SpellDrop`.
- `MinorTalentDrop` requires `TalentLegal`.
- `TalentBigDrop` requires `TalentLegal`.
- `SpellDrop` has its own `SpellDropRequirements` and current-run exclusions.

The route reward dependency layer should simulate reward order and mark or
resolve illegal `Talent*` picks based on earlier planned `SpellDrop` picks. It
should not add `SpellDrop` to bundles that vanilla cannot offer, such as
`SubRoomRewards`.

## Correction Queue

1. Keep the current `OpeningRunProgress` correction: use `SpellDrop`, not
   `TalentDrop`.
2. Implement reward dependency validation separately from bundle definitions.
