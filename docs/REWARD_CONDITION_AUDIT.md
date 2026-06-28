# Reward Condition Audit

Run Planner reward bundles describe what a room surface can offer. They do not
yet model whether a selected reward is legal at a specific point in the planned
run. Vanilla puts that second layer in `RewardLogic.lua`, `LootData.lua`, and
`RequirementsData.lua`.

This note audits the reward conditions that should become planner-visible
route rules, and separates them from metaprogression/save-state conditions that
should stay out of the normal route model.

## Sources

- `/home/ayyatma/wsl-projects/modding/1GameData/Scripts/RewardLogic.lua`
- `/home/ayyatma/wsl-projects/modding/1GameData/Scripts/LootData.lua`
- `/home/ayyatma/wsl-projects/modding/1GameData/Scripts/RequirementsData.lua`
- `/home/ayyatma/wsl-projects/modding/1GameData/Scripts/RequirementsLogic.lua`
- `/home/ayyatma/wsl-projects/modding/1GameData/Scripts/RunLogic.lua`

Key vanilla flow:

- `IsRoomRewardEligible(...)` rejects duplicate reward names in the same offer,
  room `EligibleRewards` / `IneligibleRewards`, and reward
  `GameStateRequirements`.
- `ChooseRoomReward(...)` chooses from `run.RewardStores[storeName]`, removes
  the chosen entry, and only refills the store when no eligible rewards remain.
- `SetupRoomReward(...)` resolves `Boon` into a concrete god and resolves
  `Devotion` into two gods.
- `GetEligibleLootNames(...)` switches to already-seen gods after the max-gods
  limit is reached.

## Model Boundaries

Model route-visible conditions:

- Planned reward order within a route.
- Planned gods from `Boon`, shop boon sources, and `Devotion`.
- Planned room history / run depth / biome encounter depth where already
  available from route snapshots.
- Planned room exit count where already modeled.
- Planned same-biome and same-run reward counts.
- Planned shop offers that can block normal reward eligibility.

Do not model normal-route metaprogression conditions:

- `GameState.TextLinesRecord` unlocks.
- `GameState.CompletedRunsCache`.
- `GameState.LifetimeResourcesGained`.
- `GameState.WorldUpgrades`.
- `GameState.UseRecord` unlock thresholds.
- Dream Run / Dream Dive replacements until Dream Run is explicitly modeled.
- Save-specific states such as fully invested Selene upgrades, unless the user
  later wants an explicit profile-state input.

## Vanilla Mechanics To Represent

### Room Surface Filters

Room fields still matter before reward-specific rules:

- `EligibleRewards` acts as an allow-list.
- `IneligibleRewards` acts as a deny-list.
- `previouslyChosenRewards` blocks duplicate reward names unless the reward
  entry has `AllowDuplicates = true`.

Planner status: partially represented in bundles and reward row groups.

Recommended model: keep structural filters in bundle/surface declarations, then
run a route reward validator over the selected rewards. Dynamic reward legality
belongs in `src/mods/rewards/declarations/conditions.lua`; interpretation belongs in
`src/mods/route/reward_planning/legality.lua`.

### Reward Store Entries And Depletion

Vanilla stores are finite ordered bags. When a reward is chosen, the store entry
is removed. Duplicate reward entries are how vanilla allows repeated picks
before store refill.

Examples from `RunProgress`:

- `MaxHealthDrop`: 2 entries.
- `MaxManaDrop`: 2 entries.
- `RoomMoneyDrop`: 2 entries.
- `StackUpgrade`: 2 entries.
- `WeaponUpgrade`: 2 entries, split into early and late hammer requirements.
- `HermesUpgrade`: 1 entry.
- `Devotion`: 1 entry.
- `SpellDrop`: 1 entry.
- `TalentDrop`: 1 entry.
- `Boon`: 4 duplicate entries with `AllowDuplicates = true`.

Vanilla refills a store only when no eligible entries remain, and after two
refills falls back to `RoomRewardHealDrop`.

Planner status: first-pass route legality is modeled for normal room/shop
selections. A planned second hammer is invalid before the third biome, and a
third planned hammer is invalid.

Recommended model: start with a conservative route-visible store counter per
store name and reward name. Treat store exhaustion as invalid only for clearly
finite singleton rewards such as Hermes, Spell, Talent, Devotion, and hammer
phases. Avoid exact refill simulation until runtime reward forcing is clearer.

### Boon God Cap

`GetEligibleLootNames(...)` uses all god loot until `ReachedMaxGods(...)` is
true, then restricts choices to already-seen gods. `ReachedMaxGods(...)` counts
current-run interacted gods plus any excluded gods against
`CurrentRun.MaxGodsPerRun` or `HeroData.MaxGodsPerRun`.

Planner status: route global god pool limits dropdown visibility, but route
reward legality does not yet enforce vanilla max-gods behavior.

Recommended model: for route legality, count planned non-Hermes god sources in
timeline order. If the selected god would introduce a fifth god under the normal
four-god rule, mark it invalid unless the planner later exposes an explicit
max-gods policy.

### Devotion / Trial

RunProgress `Devotion` requirements include:

- `CurrentRun.EncounterDepth >= 7`.
- `CurrentRun.BiomeEncounterDepth >= 2`.
- At least two non-Ares, non-Hermes gods in `CurrentRun.LootTypeHistory`.
- `RequiredMinRoomsSinceEvent({ Event = "Devotion", Count = 15 })`.
- `RequiredMinExits({ Count = 2 })`.

Tartarus `Devotion` requirements include:

- At least two non-Ares, non-Hermes gods in `CurrentRun.LootTypeHistory`.
- The same 15-room devotion spacing.
- The same 2-exit requirement.

Planner status: Devotion is modeled as a selectable reward on F/G/I
devotion-capable combat maps, while O keeps its special `O_Devotion01` room.
Route reward legality enforces the prior-god requirement, previous-room exit
requirement, 15-room spacing, current-run encounter depth, and one planned
Devotion reward per biome. Biome encounter-depth gating for Devotion is still
missing.

Encounter depth note: `runEncounterDepth` and `biomeEncounterDepth` are known
scalar route values now. The old bounded encounter-depth model has been
removed. Conditions should read the exact scalar from `route.query` and apply
their predicate at the condition site.

Route query surface:

- `CurrentRun.EncounterDepth` maps to exact scalar
  `route.query.runEncounterDepth`.
- `CurrentRun.BiomeEncounterDepth` maps to exact scalar
  `route.query.biomeEncounterDepth`.
- `CurrentRun.EnteredBiomes` maps to exact scalar
  `route.query.enteredBiomes`.
- `RequiredMinExits` maps to `route.query.requiredMinExits`, which reads
  topology `exitCount` first, then row-level `exitCount`, then option
  `exitCount`.
- `RequiredMinRoomsSinceEvent` maps to `route.query.minRoomsSinceDepth` over
  `CurrentRun.RunDepthCache`-style depths. Vanilla `SumPrevRooms` is a
  backwards room-history window operator, not an absolute run counter.

Recommended model:

- Keep `Devotion` in vanilla-derived reward bundles and filter it at the
  room/reward-context layer.
- Keep Devotion legality in route reward validation rather than duplicating it
  in every biome template.
- Count Ares as a possible chosen devotion god, but do not let Ares satisfy the
  vanilla "two prior gods" requirement because vanilla's requirement list
  excludes Ares.
- Reuse the same room-history spacing engine as NPC/Chaos/features with count
  15.

### Hammers

`HammerLootRequirements` route-visible parts:

- Not currently offered in the shop as `WeaponUpgradeDrop`.
- No prior current-run `WeaponUpgrade`.

`LateHammerLootRequirements` route-visible parts:

- Not currently offered in the shop as `WeaponUpgradeDrop`.
- `CurrentRun.EnteredBiomes > 2`.
- Exactly one prior current-run `WeaponUpgrade`.

Planner status: first-pass route legality is modeled for normal room/shop
selections. A planned second hammer is invalid before the third biome, a third
planned hammer is invalid, and a planned shop hammer blocks a room hammer on the
next route row.

Recommended model:

- Treat the first hammer as legal only while planned hammer count is 0.
- Treat the second hammer as legal only after entering the third biome and only
  when planned hammer count is 1.
- Treat shop `WeaponUpgradeDrop` as blocking a room reward hammer on the next
  route row.

### Hermes

`HermesUpgradeRequirements` route-visible parts:

- Not currently offered in the shop as `ShopHermesUpgrade`.
- Current biome has not already used `HermesUpgrade` or `ShopHermesUpgrade`.
- `CurrentRun.LootTypeHistory.HermesUpgrade <= 1`.

Planner status: not modeled.

Recommended model:

- Track Hermes/ShopHermes per biome and mark a second Hermes in the same biome
  invalid.
- Track total Hermes count and mark a third Hermes invalid.
- Treat planned shop Hermes as blocking room reward Hermes at the same decision
  point.

### Spell And Talent

`SpellDropRequirements` route-visible parts:

- Not currently offered in the shop as `SpellDrop`.
- Current room is not already `SpellDrop`.
- No prior current-run `SpellDrop`.
- No pending spell drop.

`TalentLegal` route-visible parts:

- Not currently offered in the shop as `TalentDrop`.
- Current run has already used `SpellDrop`.

Metaprogression parts:

- Spell unlock text-line requirements.
- Talent global `GameState.UseRecord.SpellDrop >= 4`.
- `CurrentRun.AllSpellInvestedCache`.
- Surface lock named requirement.

Planner status: first-pass route legality is modeled for normal room/shop
selections. `Talent*` stays in bundles where vanilla offers it, while route
legality requires an earlier planned `SpellDrop` and blocks `Talent*` rewards
after a shop `TalentDrop` offer.

Recommended model:

- Mark `SpellDrop` invalid after a prior planned `SpellDrop`.
- Mark `TalentDrop`, `MinorTalentDrop`, and `TalentBigDrop` invalid until a
  prior planned `SpellDrop` exists earlier in the route timeline.
- Mark `TalentDrop`, `MinorTalentDrop`, and `TalentBigDrop` invalid on the route
  row after a planned shop `TalentDrop`.
- Do not add `SpellDrop` to bundles where vanilla cannot offer it just to make
  Talent legal.

### Pom / StackUpgrade

`StackUpgradeLegal` requires `CurrentRun.Hero.UpgradableTraitCount >= 1`.

Planner status: not modeled.

Recommended model: treat this as a soft route-visible rule. The planner can
infer that no planned upgradable boon before a Pom is suspicious, but exact
validity depends on real boon choices and player state. Initial pass should
either warn, or only invalidate Poms before any planned boon/Hermes/Chaos boon
source exists.

### MetaProgress

`MetaProgress` contains many `GameState.LifetimeResourcesGained` gates and
`CurrentRun.EnteredBiomes` splits. Most are save progression and economy state,
not route structure.

Planner status: intentionally simplified as the "Minor" branch.

Recommended model:

- Keep most MetaProgress gates out of normal-route legality.
- Consider only the `EnteredBiomes` split if later exact minor reward
  distribution matters.
- Do not model resource-count gates unless the UI gains profile-state inputs.

### Priority Rewards

`ChooseRoomReward(...)` checks `CurrentRun.RewardPriorities` before random
selection. If a priority reward is eligible, it is forced and removed from the
priority list.

Planner status: not modeled.

Recommended model: out of scope for this pass. It is external run state unless
Run Planner deliberately creates priorities during runtime.

## Suggested Planner Shape

Add a reward legality layer beside existing route validators:

- Input: route snapshot, route global settings, reward catalog definitions, and
  configured feature/NPC/shop snapshots.
- Output: per reward row validity plus a compact planned reward timeline.
- Internal state while walking the timeline:
  - `seenGods`
  - `godCount`
  - `rewardUseCountByType`
  - `rewardUseCountByBiome`
  - `lastDevotionRoomHistoryOrdinal`
  - `storeCountsByStoreAndReward`
  - `plannedShopOffersAtDecisionPoint`

Keep the first implementation conservative:

1. Validate Spell before Talent.
2. Validate Devotion god count, exit count, and 15-room spacing.
3. Validate Hermes per-biome and total count.
4. Validate first/second hammer order and third-biome gate.
5. Add soft warnings for Pom-before-boon rather than hard invalidation.
6. Defer exact store refill simulation.

Runtime should still re-check at run snapshot creation. If the route is invalid,
disable the plan for that run rather than inventing a replacement reward.

## Open Questions

- Should route global max gods stay hardcoded to 4, or become an explicit
  planner policy?
- Should the UI hide illegal reward choices after previous route rows, or show
  all bundle choices and mark invalid? Initial recommendation: mark invalid to
  avoid dropdown churn.
- Should runtime reward forcing consume a mirrored planner store, or set forced
  reward types directly and bypass vanilla store depletion? This determines how
  exact store-count modeling should become.
- Should shop rewards participate in the same reward timeline immediately, or
  wait until shop content forcing is implemented?
