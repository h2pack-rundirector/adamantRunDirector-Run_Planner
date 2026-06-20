# Run Planner Design Notes

Run Planner keeps route coordinates separate from vanilla depth counters. A
route coordinate identifies the planned row or pick the user sees, while room
eligibility can depend on either vanilla `BiomeDepthCache` or vanilla
`BiomeEncounterDepth`.

The first implementation should focus on the linear biomes where this model is
mostly true: `F`, `G`, `P`, and `Q`, plus route-level declarations for fields
cage routing `H`, clockwork `I`, hub-pylon `N`, and multi-encounter `O`.
Other biomes need separate adapters.

## Depth Standard

Planner rows expose explicit depth context:

- `coordinate`: stable planner row identity.
- `biomeDepthCache`: vanilla `CurrentRun.BiomeDepthCache` semantics.
- `biomeEncounterDepth`: vanilla `CurrentRun.BiomeEncounterDepth` semantics.
- `biomeEncounterDepthCost`: how the selected row advances encounter depth for
  later rows.

Layout requirements should declare which vanilla axis they came from. Do not
shift raw vanilla values in the room catalogue; biome adapters/context builders
own any coordinate translation. Encounter-depth context is computed from prior
row costs; the current row's cost is exported for snapshots but does not make
that row eligible for its own encounter-depth gates.

Encounter depth is intentionally unknown after an unresolved row such as
Vanilla/Auto or a mixed-cost role without a concrete option. Options with
`availability.biomeEncounterDepth` fail closed while encounter depth is unknown;
the user must make prior rows concrete enough for the planner to prove the
counter.

- The boss room is excluded.
- The preboss room is included at its vanilla force depth.
- Post-boss transition rooms are excluded. Boss rooms link to them, and they
  hand off to the next biome with `NextRoomSet`.
- Non-starter biome intros are locked entry rooms outside the planned row list.
  They can still lead to a first planned door room at `BiomeDepthCache == 1`.
- Dream Run / Dream Dive intro reward overrides are intentionally out of scope
  for the first route planner pass. Non-starter intros are modeled as no-reward
  entries unless the normal run route uses that room as an actual reward surface.
- `F` is special: its opening room is routeable depth `0` because vanilla
  explicitly sets `BiomeDepthCache = 0` for the starter room. Normal runs use
  `RunProgress` with `OpeningRoomBans` there. F route rows use a
  `selectionBiomeDepthOffset` of `-1` so `BiomeDepthCache` availability checks
  model the room the player is standing in while the next room is selected.
- Normal planned route depths are the depths between the locked entry/opening
  and the preboss.

Current working depths:

| Biome | Route | Depth range | Planned route depths | Notes |
| --- | --- | --- | --- | --- |
| `F` | Erebus | `0..10` | `0, 1..9` | Starter biome. Depth `0` is one of `F_Opening01/02/03` with `RunProgress` reward controls. Preboss offers shop and non-shop `RunProgress` branches. |
| `G` | Oceanus | `1..8` | `1..7` | `G_Intro` is a locked entry before the planned row list. Preboss offers shop and non-shop `RunProgress` branches. |
| `H` | Fields | Route picks | Picks `1..4` | `H_Intro`, then four preboss picks, then `H_PreBoss01`. Combat maps expose reward cages rather than a single room reward. |
| `I` | Tartarus | Clockwork | Rows `1..12` | `I_Intro` initializes five required `ClockworkGoal` rewards and a vanilla non-goal reward budget of `3..6`; story can consume a route row without advancing either counter. Post-goal extensions remain possible only behind a planned room that can offer an I exit. |
| `N` | Ephyra | Hub pylon | Picks `1..6` | Fixed `N_Opening01` into `N_PreHub01`, then hub pylon picks from `N_Hub`. Preboss is shop-only after six pylons. |
| `O` | Thessaly | `1..7` | `1..6` | `O_Intro` is a locked entry before the planned row list. Combat route depths use ship multi-encounter policy. Preboss is shop-only. |
| `P` | Olympus | `1..9` | `1..8` | `P_Intro` is a locked entry before the planned row list. Preboss offers shop and non-shop `RunProgress` branches. |
| `Q` | Summit | `1..7` | `1..6` | `Q_Intro` is a locked entry before the planned row list. Scripted fixed route. Preboss is shop-only. |

## Vanilla Facts To Preserve

Vanilla room selection creates offered door rooms before the player chooses a
door. Creating an offered room increments `CurrentRun.RoomCreations` for that
room. A room with `MaxCreationsThisRun` can therefore be consumed by an
unpicked door offer before the player reaches the planned depth.

The planner must not allow a future planned one-time room to appear early as an
alternate door offer.

Relevant vanilla behavior:

- `ChooseNextRoomData(...)` builds eligible and forced room pools for each
  offered door.
- `CreateRoom(...)` increments `CurrentRun.RoomCreations[room.Name]`.
- `IsRoomEligible(...)` rejects rooms whose `MaxCreationsThisRun` has already
  been reached.
- `F/G/O/P/Q` preboss rooms are selected by vanilla depth gates. The planner
  should use those same depth values as its stable route identity.
- F/G room maps can expose one, two, or three offered exit doors. A planned
  target can therefore be valid by depth but invalid from the previous room if
  vanilla requires multiple offered exits.
- `F_Shop01`, `G_Shop01`, and `Devotion` rewards require at least two offered
  exits from the previous room. Planner metadata represents this as source-room
  `exitCount` plus shared route-rule requirements.

Confirmed source notes:

- `F_PreBoss01` forces at biome depth `10`, has `ForcedFirstReward = "Shop"`,
  and links to `F_Boss01/F_Boss02`.
- `G_PreBoss01` forces at biome depth `8`, has `ForcedFirstReward = "Shop"`,
  and links to `G_Boss01/G_Boss02`.
- `P_PreBoss01` forces at biome depth `9`, has `ForcedFirstReward = "Shop"`,
  and links to `P_Boss01`.
- `Q_PreBoss01` forces at biome depth `7`, has `ForcedFirstReward = "Shop"`,
  uses `Q_WorldShop`, and links to `Q_Boss01/Q_Boss02`.
- `I_Intro` initializes `GoalRewards = 5`, `MinNonGoalRewards = 3`, and
  `MaxNonGoalRewards = 6`. `ClockworkGoal` decrements
  `RemainingClockworkGoals`; the preboss becomes eligible when that reaches
  zero.
- `I_TwoExits` marks maps that can offer an extension path and is only eligible
  while `BiomeRewardsSpawned < MaxClockworkNonGoalRewards - 1`. The extension
  room itself can be a combat map, fountain, story room, or miniboss. The first
  offered `I_BaseCombat` reward is forced to `ClockworkGoal`; additional
  offered I-room doors can be non-goal rewards or special rooms.
- `O_CombatData` uses `MultipleEncountersData`: pre-spawned intro encounter,
  first encounter, and a conditional second encounter.
- `N_Hub` chooses 9 or 10 available doors from a fixed `PredeterminedDoorRooms`
  map. The boss route opens after six `SoulPylon` clears.
- `N_MiniBoss01` and `N_MiniBoss02` are mutually exclusive in vanilla hub-door
  setup; one is removed by coin flip before the hub door set is trimmed.
- N combat rooms can have fixed subroom doors. The same `N_SubXX` room can
  appear behind different parent combat-room doors, so side-room identity is
  the parent combat room plus door id.

## Core User Model

The user plans the path they intend to take. They do not have to micromanage
every alternate door.

Each normal route depth has one primary plan:

```lua
{
    role = "Combat",
    roomKey = "F_Combat05",
    rewardPick = {
        rewardType = "Boon",
        lootName = "ZeusUpgrade",
    },
}
```

Unplanned alternate branches are currently deferred to vanilla/runtime
reservation policy. They should not contribute encounter-depth cost until the
runtime implementation can prove what room was selected.

## Run-Start Plan Snapshot

The choice set should be treated as locked for the run. UI edits during an
active run should affect the next run, not mutate the current route plan after
doors have already been generated.

At run start, or at latest biome entry before the first door generation, take a
snapshot of the active plan and build all reservations from that snapshot.

## Reservation Bundle

Build a reservation bundle from the explicit room keys in the route plan.

Example:

```lua
{
    F_Story01 = 7,
    F_MiniBoss02 = 5,
}
```

Reservation rules:

- Before the reserved depth, the reserved room is ineligible.
- At the reserved depth, the reserved room may be forced if the current run
  state still makes that room valid.
- After the reserved depth, the runtime should not chase a missed room. It
  should release the reservation, fall back to vanilla, and surface status if
  that missed room makes the active snapshot invalid.

Initial reservation should include explicitly planned rooms that are dangerous
if pre-created:

- rooms with `MaxCreationsThisRun`
- rooms with `MaxCreationsPerRoom`
- exact special-room selections such as story, fountain, shop, trial, and
  miniboss rooms

Reward reservation is a separate later layer. The first implementation should
solve room identity collisions first.

## NPC Encounters

Field NPC encounters are route-level assignments derived from biome row plans.
They are not room roles and they are not reward primitives. Vanilla chooses
them in `ChooseEncounter(...)` after a room has been selected and after
`ChosenRewardType` is known, so planner validation must see the resolved row
role, room/map, and reward pick.

NPC/route-encounter definitions live in `src/mods/npcs/definitions.lua`. The
definition layer owns:

- the route-major NPCs: Artemis, Nemesis, Heracles, Icarus, and Athena
- Arachne cocoon combat as a separate normal-combat encounter replacement
- which biomes can host each NPC
- the vanilla encounter variants for each biome
- vanilla depth gates such as `BiomeDepthCache >= 4`
- reward incompatibilities from `RequireNotRoomReward`
- encounter-leg hints for multi-encounter biomes such as O/P

First-ever intro encounter variants and duplicate chance-booster variants are
treated as meta-progression/probability plumbing, so planner definitions omit
them and keep only canonical force targets.

Modeled route-major field NPCs share one route group, `FieldNpc`, for the
vanilla six-room spacing rule. Each modeled field NPC has its own
`maxSelectionsPerRun = 1`; the group itself does not mean only one field NPC
total can be planned. Personal vanilla cooldowns such as
`NoRecentNemesisEncounter` and `NoRecentHeraclesEncounter` include shop,
bridge, previous-run, and relationship state outside first-pass route planning,
so they are treated as vanilla provenance rather than separate planner groups.

Arachne cocoon combat is modeled on the same declaration surface but not in
`FieldNpc`. Vanilla places `ArachneCombatF`/`ArachneCombatG` in the normal F/G
encounter pools, replacing the combat encounter with cocoons while keeping the
planned room reward. It has its own `ArachneCombat` group with
`NoRecentArachneEncounter` provenance and per-biome uniqueness, but no
per-run cap because F and G can both be valid in one route when spacing allows.

Vanilla also has save/global progression gates for Arachne: G requires
`ArachneCombatF` in `GameState.EncountersCompletedCache`, and F requires prior
completed run / early Erebus encounter state. Those gates are meta progression,
so the planner declaration does not model them. The route-relevant pieces kept
in the declaration are F's depth cache window, per-biome uniqueness, and the
`NoRecentArachneEncounter` previous-room spacing provenance.

Nemesis is the first special NPC shape. In F/G, she has two routeable
combat-slot variants:

- `Combat`: forces `NemesisCombatF`/`NemesisCombatG` and keeps the normal
  planned room reward relevant.
- `Random`: forces `NemesisRandomEvent`, which occupies a combat slot but uses
  a `NonCombat` encounter and lets Nemesis' vanilla random-event text-line
  system choose the outcome. Planner should treat its reward as opaque
  `nemesisRandomEvent` behavior on the first pass, not as a normal reward
  bundle or picker.

H passive `NemesisRandomEvent`, H bridge `BridgeNemesisRandomEvent`, shop
Nemesis, and relationship-specific random events are outside the first-pass NPC
target model.

The Global tab owns route-wide configuration policy and pre-setup inputs such
as god pool filtering. Route rows are always the base planner surface; there is
no separate room-routing toggle. Optional layers are:

- `Configure Rewards`: shows reward tabs and lets runtime/validation consume
  planned reward choices.
- `Configure NPC Encounters`: shows the NPC tab and lets runtime/validation
  consume NPC targets. This is effective only when rewards are also configured,
  because NPC eligibility can depend on concrete planned rewards.
- `Configure Route Features`: shows the route-feature tab and lets
  runtime/validation consume Chaos Gate, Stygian Well, and Hermes Shrine
  targets.

Disabled layers keep their stored choices, but are hidden from the planner UI
and ignored by target generation, route validation, and runtime snapshots.

The NPC tab is a route-level post-setup tab rendered after the biome tabs. It
should consume normalized encounter-slot candidates exposed by biome snapshots
rather than reaching into individual adapter internals.

Planner NPC targets should be precise:

```lua
{
    npcKey = "Artemis",
    target = {
        routeKey = "Underworld",
        biomeKey = "F",
        controlName = "RouteF",
        rowIndex = 5,
        coordinate = 4,
    },
}
```

If a target row changes and is no longer valid for that NPC, the NPC assignment
should become invalid instead of silently moving to another row. Runtime should
apply room/reward routing first, then use the NPC assignment snapshot to force
or prefer the matching encounter at the selected target.

## Depth Roles

The depth role controls which additional fields are valid.

| Role | Map selection | Reward selection | Notes |
| --- | --- | --- | --- |
| `Vanilla` | None | None | Leave depth to vanilla, except reservations still protect future planned rooms. |
| `Combat` | Optional combat room map | Major/Minor reward split when the room uses `ChooseNextRewardStore`; special stores otherwise | Standard generated combat room. F/G/I devotion-capable combat maps can expose `Devotion` as a reward. Some biomes, such as `Q`, have no combat reward. |
| `Story` | Fixed story room | None | Story rooms are one-time/special and should be reserved when planned. |
| `Fountain` | Fixed fountain room | Major/Minor reward split when the room uses `ChooseNextRewardStore`; special stores otherwise | Must preserve room-specific reward rules. |
| `Midshop` | Fixed shop room | Shop inventory control | This is shop option control, not normal `ForcedReward`. |
| `Devotion` | Fixed devotion room | `Devotion` | O declares a real `O_Devotion01` room, so it stays a special room role. |
| `Miniboss` | Specific miniboss room | Store-defined reward primitive | Most minibosses restrict `RunProgress` to `Boon`; `Q` uses `TyphonBossRewards`. |

In F/G/I, vanilla represents Devotion through reward data on normal combat maps,
so the planner exposes `Devotion` as a reward on devotion-capable combat maps.
O is different because vanilla declares an actual `O_Devotion01` room, so that
room remains a special Devotion role.

Target-side availability can depend on shared route rules. For example, F/G
midshops and devotion rewards require the previous room to have at least two
offered exits. The room option owns `exitCount`; the role or reward owns the
shared route requirement.

The UI should reveal only the fields supported by the selected role. Avoid
allowing arbitrary combinations that vanilla cannot satisfy.

Planner snapshots fail closed. The UI should prevent obvious invalid choices,
but runtime snapshot construction must not silently replace an invalid row with
`Vanilla` or a different room. If a configured row is out of range, duplicates a
one-shot role, or violates another planner-owned route rule, the snapshot is
marked invalid and route application is disabled for that run until the user
fixes the plan.

The first supported route requirement is `previousRoomExitCount`. It only
passes when the previous planned row is valid and resolves to a concrete room
option with enough exits. `Vanilla` and unresolved `Auto` rows do not satisfy
the requirement because the planner cannot prove the previous room shape.

Biome Q also uses forced-depth role gates for miniboss depths. At depths 3 and
6, vanilla can have broadly eligible combat rooms, but forced miniboss rooms win
the room selection pass. The planner keeps `Vanilla` available as an opt-out,
but explicit planned roles at those depths must be `Miniboss`.

Reward declarations use vanilla reward contexts, plus narrow planner adapters
for vanilla mechanisms that need player-facing language:

```lua
reward = { kind = "none" }
reward = { kind = "majorMinor", majorRewardStore = "RunProgress", minorRewardStore = "MetaProgress" }
reward = { kind = "roomStore", rewardStore = "RunProgress" }
reward = {
    kind = "roomStore",
    rewardStore = "RunProgress",
    eligibleRewardTypes = { "Boon" },
    ineligibleRewardTypes = { "RoomMoneyDrop" },
}
reward = { kind = "roomStore", rewardStore = "HubRewards" }
reward = { kind = "forcedReward", rewardType = "Devotion" }
reward = { kind = "shop", shopProfile = "WorldShop" }
reward = { kind = "shipWheel", storeSource = "ChooseNextRewardStore" }
```

The context tells UI/runtime which vanilla mechanism owns the reward. The
player-facing choice should be the actual primitive inside that context, such
as `Boon`, `WeaponUpgrade`, `TalentBigDrop`, or `StackUpgradeTriple`.
Contexts using vanilla `ChooseNextRewardStore` are exposed as the community
language of `Major` and `Minor`: `Major` maps to `RunProgress`, while `Minor`
maps to `MetaProgress`. This applies to ordinary F/G/P combat and fountain
routes, O fountain routes, and O ship-wheel combat rewards. It does not apply
to preboss non-shop rewards, minibosses, Tartarus extension rewards, Ephyra hub
rewards, Fields cages, shops, or trials.
Room-store contexts can also carry `eligibleRewardTypes` and
`ineligibleRewardTypes`; those mirror vanilla room-level `EligibleRewards` and
`IneligibleRewards` filtering after the broad reward store is selected.

Reward rendering is shared infrastructure, not owned by one route control
template:

- `mods/rewards/definitions.lua` owns the curated planner-facing reward surfaces.
  These surfaces are intentionally explicit instead of pretending to fully
  evaluate vanilla `RewardStoreData`/`StoreData` requirements.
- `mods/rewards/catalog.lua` translates planner reward contexts plus curated
  reward surfaces into normalized picker surfaces.
- `mods/rewards/runtime.lua` reads normalized reward picks through a generic
  field adapter.
- `mods/rewards/ui.lua` renders normalized reward controls through the same
  adapter. Route templates decide where picks are stored; they do not duplicate
  reward-surface rules.

If reward selection later needs stronger live-data guarantees, that can be a
separate data-layer pass. The current catalog should stay honest: it normalizes
planner-owned surfaces, with vanilla data used as source reference rather than
runtime truth.

## Runtime Dependency Tree

Runtime should apply planned values as a dependency tree, not as one flat chain.
A `Vanilla` value stops only the dependent subtree below that value; sibling
branches remain usable when vanilla rules allow them.

Planner-facing tree:

```text
Slot
  Role
    Room option / map
    Encounter variant
      Encounter reward legs
    Reward
      Reward class
        Major reward type
          Boon god
        Minor reward type
```

Runtime invariants:

- `Role = Vanilla` disables all room, map, encounter, and reward planning for
  that slot.
- `Combat` with a vanilla room/map option can still have a planned reward. The
  user may mean "any valid combat room, but force this reward."
- `Reward class = Vanilla` disables reward type and reward-specific descendants
  such as boon god.
- `Major reward type = Boon` with `God = Vanilla` means force a boon while
  leaving the god source to vanilla/random selection, if that route supports
  that partial override.
- For O multi-encounter combat rows, `Encounter variant = Vanilla` disables
  encounter reward legs. `TwoCombats` enables the first reward-bearing combat
  leg, and `ThreeCombats` enables the first and second reward-bearing combat
  legs.
- Hidden or stale stored descendant values are ignored whenever their parent is
  vanilla or otherwise inactive. Runtime should not require inactive storage to
  be empty.

`Boon` needs a second selection layer for Olympian god source. The
player-facing picker should show the god source, not stop at the generic
reward type:

```lua
rewardPick = {
    kind = "boonSource",
    rewardType = "Boon",
    lootName = "ZeusUpgrade",
}
```

God boons apply as `ChosenRewardType = "Boon"` plus
`room.ForceLootName = "<God>Upgrade"`. Hermes is intentionally separate:
vanilla stores and spawns it as `ChosenRewardType = "HermesUpgrade"`, and
`HermesUpgrade` declares `GodLoot = false` while normal gods declare
`GodLoot = true`. Planner UI should therefore expose Hermes as its own reward
primitive, not as a member of the normal boon-source picker.

`Devotion` is also not a complete single-value pick. Vanilla sets up two boon
loot sources on the encounter:

```lua
rewardPick = {
    kind = "devotionPair",
    lootAName = "ZeusUpgrade",
    lootBName = "PoseidonUpgrade",
}
```

Runtime maps those to `room.Encounter.LootAName` and
`room.Encounter.LootBName`. Vanilla chooses these from gods already interacted
with this run first, using `GetInteractedGodThisRun(...)`, and the devotion
reward itself is gated behind prior god history. After the player chooses one,
vanilla records `ChosenGodName` and `SpurnedGodName` and later grants the
spurned god's boon. The devotion picker should therefore use devotion-capable
interacted god loot names, not the full reward or Hermes surfaces.

The planner keeps two related sets in `route_rules.lua`: the god loot names that
can be picked for boon/devotion source fields, and the current vanilla
`Devotion` `CountOf` requirement list used to decide whether Devotion is legal.
They are intentionally separate because the live data can differ. In current
vanilla data, Ares can be picked as a boon/devotion source but does not count
toward the two prior gods required to make `Devotion` eligible.

## Route Rules

`route_rules.lua` owns cross-biome rules that are not concrete room catalogue
facts:

- F/G midshop roles require a previous room with at least two exits.
- Devotion rewards require a previous planned room with at least two exits and
  two prior devotion-counted gods.
- Miniboss roles usually allow at most one miniboss selection per biome, with
  biome-specific overrides where vanilla allows more than one planned miniboss
  gate, such as Summit.

Biome layout files should not repeat these as per-room conditions. They should
only declare room-local facts such as depth windows, exit counts, one-time room
limits, and adapter-specific metadata.

## Run Routes

`mods/data/routes.lua` owns the normal run route order:

- `Underworld`: `F`, `G`, `H`, `I`
- `Surface`: `N`, `O`, `P`, `Q`

Route controls remain biome-owned, but run-level conditions use a per-draw route
context. The context can snapshot earlier biomes in the same route and expose
facts such as prior devotion-counted god rewards. Biome templates should not
hard-code route order; they should ask the requirement layer for run-level
facts. Future Dream Dive handling can add another route provider without
rewriting the biome adapters.

## Preboss Depths

Preboss should be treated as a special depth type, not just another normal room
role.

For `F/G/P`, the preboss depth has two branches:

```lua
{
    shop = {
        kind = "PrebossShop",
        shopOptions = {
            Boon = "ZeusUpgrade",
            MajorNonBoon = "WeaponUpgradeDrop",
            Minor = "MaxManaDrop",
        },
    },
    runProgressReward = {
        kind = "PrebossNoShop",
        rewardPick = {
            rewardType = "StackUpgrade",
        },
    },
}
```

For `Q` and `O`, the preboss depth only has the shop branch:

```lua
{
    shop = {
        kind = "PrebossShop",
        shopOptions = {
            Group1Offer1 = "ZeusUpgrade",
            Group1Offer2 = "BlindBoxLoot",
            Group2Offer1 = "HealBigDrop",
            Group3Offer1 = "RoomRewardHealDrop",
            Group4Offer1 = "WeaponUpgradeDrop",
            Group5Offer1 = "CharonPointsDrop",
        },
    },
}
```

`PrebossShop` is shop inventory control. `PrebossNoShop` is normal
`RunProgress` reward control on the non-shop branch, narrowed by the room's
`IneligibleRewards` so `RoomMoneyDrop` and `Devotion` are not exposed there.

Fixed-linear route controls render each declared preboss branch as its own
terminal row instead of rendering one depth with a branch selector. In the UI,
`Shop` is labeled `Preboss Shop`; `MajorReward` is labeled `Preboss Room`.
The row snapshot keeps the mechanical `branchKey` so runtime logic does not
depend on the display label.

## Shop Surfaces

Shop control should model all store options, not only the boon option.

Implemented shop surfaces live in `src/mods/rewards/surfaces.lua`:

| Surface | Vanilla store | Options | Notes |
| --- | --- | ---: | --- |
| `WorldShop` | `WorldShop` | 3 | `Boon`, `MajorNonBoon`, `Minor`. Used by `F/G/P/O` shops. |
| `I_WorldShop` | `I_WorldShop` | 5 | Tartarus preboss shop profile. Slots use `GroupNOffer1` keys. |
| `Q_WorldShop` | `Q_WorldShop` | 6 | Summit preboss shop profile. Group 1 contributes `Group1Offer1` and `Group1Offer2`. |

Biome definitions reference these surfaces with `reward = { kind = "shop",
shopProfile = "..." }`. Runtime/shop UI should render option controls from the
reward catalog surface instead of hard-coding a single boon field.

Biome files should not duplicate shop internals. They only select the shop
surface that applies to a route depth. Store-specific shape belongs inside
`mods/rewards/definitions.lua`:

- `key`: stable route/storage identity, matching the source group/offer shape
  such as `Group4Offer1`.
- `label`: player-facing description such as `Major Power` or `Resource`.
- `options`: curated planner-facing choices for that slot.

`I_WorldShop` and `Q_WorldShop` intentionally use source-shaped keys rather
than anonymous `Option1` names because their vanilla stores are mixed grouped
stores. The label may be semantic, but the key should remain mechanical so the
route schema does not drift when a group contains different rewards in
different run halves.

## Biome Adapter Shape

The planner should use biome adapters instead of deriving all behavior from one
global formula.

Rough shape:

```lua
F = {
    kind = "fixedLinear",
    coordinate = "BiomeDepthCache",
    depthRange = { min = 0, max = 10 },
    routeStartDepth = 1,
    routeEndDepth = 9,
    special = {
        [0] = { kind = "opening", roomOptions = { "F_Opening01", "F_Opening02", "F_Opening03" } },
        [10] = { kind = "preboss", branches = { "Shop", "MajorReward" } },
    },
}

G = {
    kind = "fixedLinear",
    coordinate = "BiomeDepthCache",
    depthRange = { min = 1, max = 8 },
    routeStartDepth = 1,
    routeEndDepth = 7,
    special = {
        [8] = { kind = "preboss", branches = { "Shop", "MajorReward" } },
    },
}

P = {
    kind = "fixedLinear",
    coordinate = "BiomeDepthCache",
    depthRange = { min = 1, max = 9 },
    routeStartDepth = 1,
    routeEndDepth = 8,
    special = {
        [9] = { kind = "preboss", branches = { "Shop", "MajorReward" } },
    },
}

Q = {
    kind = "scriptedFixedLinear",
    coordinate = "BiomeDepthCache",
    depthRange = { min = 1, max = 7 },
    routeStartDepth = 1,
    routeEndDepth = 6,
    special = {
        [7] = { kind = "preboss", branches = { "Shop" } },
    },
}
```

Later adapters:

```lua
H = {
    kind = "fieldsCageRoute",
    fixedBeforeRoute = { "H_Intro" },
    routeStartPick = 1,
    routeEndPick = 4,
    preboss = "shopOnly",
}

I = {
    kind = "clockworkGoal",
    fixedBeforeRoute = { "I_Intro" },
    routeStartRow = 1,
    routeEndRow = 12,
    requiredGoalRewards = 5,
    extensionRewardBudget = { min = 3, max = 6 },
}

O = {
    kind = "multiEncounterFixed",
    coordinate = "BiomeDepthCache",
    depthRange = { min = 1, max = 7 },
    routeStartDepth = 1,
    routeEndDepth = 6,
    combatEncounterPolicy = "O_CombatData",
}

N = {
    kind = "hubPylon",
    coordinate = "SoulPylon",
    fixedBeforeHub = { "N_Opening01", "N_PreHub01", "N_Hub" },
    routeStartPick = 1,
    routeEndPick = 6,
    requiredPylons = 6,
    preboss = "shopOnly",
}
```

Implemented definition files live under `src/mods/data/biomes/`. Each biome
has a main declaration file, and most biomes also have a layout file.

The main declaration file is the source of truth for route and role semantics:

- `slotLayout.coordinate`: currently `BiomeDepthCache`.
- `slotLayout.depthRange`: inclusive vanilla depth range modeled by the biome.
- `slotLayout.routeStartDepth` and `slotLayout.routeEndDepth`: normal planned
  route depths. Locked intros and preboss depths sit outside this range. The
  `F` opening is also outside this range, but is rendered as a fixed special row.
- `slotLayout.special`: per-depth overrides such as intro/opening and preboss
  branch shape.
- `biomeEncounterDepthCost`: known encounter-depth cost on fixed slots,
  concrete room options, or roles whose every selectable option shares the same
  cost. Vanilla/Auto rows do not declare a cost; they make later encounter-depth
  availability unknown until the user selects concrete prior rows.
- `requiresConcreteOption`: option-bearing roles such as Miniboss can disable
  Auto and require a concrete vanilla room selection. Miniboss costs live on the
  leaf options because later availability can depend on the selected variant.
- `slotLayout.fixedBeforeHub` and `slotLayout.fixedAfterHub`: hub-adapter
  fixed rooms that do not use normal depth coordinates.
- `slotLayout.fixedBeforeRoute` and `slotLayout.fixedAfterGoals`:
  clockwork-adapter fixed rooms that sit before and after the goal route.
- `roles`: ordered role definitions for UI rendering and runtime capability
  checks.
- `mapOptions` or `roomOptions`: references to layout-owned room groups that
  are valid for a role.
- `reward`: which vanilla reward context applies to the role or special depth.
  Room-store and shop contexts are resolved through curated reward surfaces;
  no-reward contexts intentionally expose no reward picker. A concrete
  `mapOptions`/`roomOptions` entry can override the role reward when a vanilla
  room has narrower reward filters than the rest of the role.

The layout file is the source of truth for concrete vanilla room catalogues:

- combat maps, story rooms, fountain rooms, shops, trials, minibosses, intros,
  and preboss rooms.
- `availability`: planner-owned vanilla eligibility metadata for a role option.
  Current fields include `biomeDepthCache`, `biomeEncounterDepth`,
  `requiresGeneratedIntroEncounters`, and `requiresMultipleOfferedDoors`.
- `biomeEncounterDepthCost`: optional concrete room override for
  `CountsForRoomEncounterDepth` exceptions such as Talos, Charybdis, or Typhon
  Eye.
- `maxCreationsThisRun` and `maxAppearancesThisBiome`: reservation metadata for
  one-time or one-per-biome room creation behavior.

When a combat map participates in multiple roles, such as normal combat and
trial/devotion, the layout should create the room record once and derive role
groups from that shared record. Do not duplicate room availability metadata in
the main declaration file.

The initial files are:

- `f_erebus.lua`
- `f_erebus_layout.lua`
- `g_oceanus.lua`
- `g_oceanus_layout.lua`
- `i_tartarus.lua`
- `i_tartarus_layout.lua`
- `n_ephyra.lua`
- `n_ephyra_layout.lua`
- `o_thessaly.lua`
- `o_thessaly_layout.lua`
- `p_olympus.lua`
- `p_olympus_layout.lua`
- `q_summit.lua`
- `q_summit_layout.lua`

These definitions are loaded and indexed by `mods/data/biomes.lua`. Storage,
UI, snapshots, and route hooks should derive from this loader instead of
duplicating biome facts.

## Thessaly Ship Combat

`O` combat rooms are not normal one-reward combat rooms. All `O_CombatNN`
rooms inherit `O_CombatData`, which owns `MultipleEncountersData`.

The route model should treat the selected combat room map as independent from
the encounter-count policy:

```lua
combatEncounterPolicy = {
    key = "O_CombatData",
    countControl = "CombatCount",
    legs = {
        { key = "Intro", reward = { kind = "none" } },
        { key = "Combat1", reward = { kind = "shipWheel" } },
        { key = "Combat2", reward = { kind = "shipWheel" } },
    },
}
```

The intro leg is the pre-spawned ship encounter. It does not spawn a reward and
does not count for room encounter depth. `Combat1` is always present and gets a
ship-wheel reward selection. `Combat2` is vanilla-optional: it appears with a
60% chance when room-entry `BiomeEncounterDepth` is between `2` and `5`.

Planner UI should therefore expose combat count as `Vanilla`, `2 Combats`, or
`3 Combats`. `3 Combats` is only valid for room-entry encounter depth `2..5`.
If the stored route selects it outside that range, snapshot validation should
mark the row invalid instead of fabricating a replacement.

## Tartarus Clockwork Route

`I` is not a fixed-depth biome. It is a goal route with optional extension
paths. `I_Intro` initializes:

```lua
{
    requiredGoalRewards = 5,
    extensionRewardBudget = { min = 3, max = 6 },
}
```

The player must take five `ClockworkGoal` rewards before `I_PreBoss01` or
`I_PreBoss02` can appear. The planner should therefore render a flat route
tape of up to 12 storage rows:

```text
Row 1: Goal (forced by the biome declaration)
Row 2: Extension or Goal
Row 3: Extension or Goal
...
Row 12: Story, Extension, or Goal
```

Rows below the fifth planned goal are active only when the previous planned
room can still offer an I exit. Once the previous planned row is a one-exit
room, the route terminates and later rows are treated as inactive vanilla rows.
Additional `ClockworkGoal` rows are invalid after the fifth planned goal.
The first route row is not user-selectable as Vanilla or an extension: Tartarus
forces the first offered combat reward to `ClockworkGoal`.

The UI should not use nested extension controls. A selected room/map has
`supportsExtensionChoice`; if true, the next route row may be an extension. If
false, the next route row must be the next goal.

Goal rows use `I_Combat01..I_Combat24` and force the `ClockworkGoal` reward.
Extension rows can be:

- extension combat: `I_Combat01..I_Combat24` using `TartarusRewards`;
- fountain: `I_Reprieve01`, also using `TartarusRewards`;
- story: `I_Story01`;
- miniboss: `I_MiniBoss01` or `I_MiniBoss02`, restricting `RunProgress` to
  `Boon`.

`I_Shop01` is not modeled as a reachable extension shop. It declares
`DebugOnly = true` directly, and `IsRoomEligible(...)` rejects debug-only rooms
after inheritance is processed. The reachable Tartarus shop surface is the
preboss shop using `I_PreBoss01/I_PreBoss02` and the `I_WorldShop` profile.

The extension budget is vanilla-random by default. The data records the vanilla
range and plans against the maximum budget. Two-exit room maps become invalid
when only the final non-goal reward remains, matching vanilla `I_TwoExits`;
the final extension, if used, must be a one-exit room.

## Fields Cage Route

`H` is not a normal linear reward route. The planner should model four
preboss route picks after `H_Intro`, followed by `H_PreBoss01`.

The common vanilla shape is:

```text
Pick 1: Combat or Miniboss
Pick 2: Combat or Miniboss
Pick 3: Bridge, Combat, or Miniboss
Pick 4: Combat or Miniboss
Preboss: H_PreBoss01
```

`H_Bridge01` is a forced vanilla candidate once its requirements are met, but
it is not an absolute third slot. It requires exactly two prior combat/miniboss
rooms and can be overridden by explicit route planning or missed if
prerequisites are not satisfied. It can resolve to shop, Echo story, or a later
Nemesis event; the first declaration keeps that as a bridge reward mode rather
than a normal room reward surface.

Normal H combat rooms use reward cages. The combat room itself has `NoReward`;
the door room receives `CageRewards`, and `SpawnRewardCages(...)` randomly
places those rewards into the room's fixed `LootPoint`s. Physical cage
coordinates are intentionally a second-pass concern. The first pass records:

- per-map cage capacity from `MaxCageRewards`;
- vanilla count control of `2` or `3` cage rewards;
- the fact that `3` rewards requires all relevant offered rooms to support at
  least three cages;
- reward store `RunProgress`.

Miniboss rooms are `H_MiniBoss01` / Vampire and `H_MiniBoss02` / Lamia. They
are mutually exclusive, available at biome depth `2..4`, and restrict
`RunProgress` to `Boon`.

## Ephyra Hub Pylons

`N` is not a linear depth route. It is a fixed opening sequence into a hub:

```lua
fixedBeforeHub = {
    "N_Opening01",
    "N_PreHub01",
    "N_Hub",
}
```

The planner should then model six pylon picks. A pylon pick can be:

- `Combat`: one of `N_Combat01..N_Combat23`, using `HubRewards`.
- `Story`: `N_Story01` / Medea.
- `Miniboss`: either `N_MiniBoss01` / Satyr Crossbow or `N_MiniBoss02` / Boar,
  restricting `RunProgress` to `Boon`.
- `Vanilla`: let vanilla choose, while still respecting reservations for
  future planned hub rooms.

The hub offers many doors, but the user is planning only the path they intend
to take. Runtime should therefore force the planned selected hub exit when it
is still valid, while allowing vanilla to fill the other available hub doors,
except for rooms reserved for future planned picks.

`N_Hub` has two important special cases:

- Vanilla removes one of the two miniboss doors by coin flip. If the user plans
  a specific miniboss, the adapter must treat that choice as the desired member
  of a one-of group instead of allowing the vanilla coin flip to discard it.
- Normal combat rooms can contain fixed side-room doors. These side rooms are
  children of the selected combat map, not additional pylon picks.

Side-room identity is `parent combat room + door id`, not only `N_SubXX`,
because the same subroom template can appear behind multiple parent rooms.
Side-room controls should default to `Vanilla`; later UI can opt into `Force`
or `Block` per side door and optionally force the side-room reward. The reward
store comes from the subroom declaration: most use `SubRoomRewards`, while
`N_Sub09`, `N_Sub10`, `N_Sub11`, and `N_Sub14` use `SubRoomRewardsHard`.

## Implementation Phases

1. Add static biome adapter data for `F/G/H/I/N/O/P/Q`.
2. Add route-depth storage and UI for one primary plan per depth.
3. Build the run-start reservation bundle from explicit planned rooms.
4. Patch room eligibility so future reserved rooms cannot appear early.
5. Force the primary room at the planned depth when it remains valid.
6. Add reward forcing per role.
7. Add preboss branch controls.
8. Add warnings for unsatisfiable plans.

## Open Questions

- Decide whether a missed reserved room should always release immediately after
  its depth or keep protection for the rest of the biome in some cases.
- Decide how much reward reservation belongs in this module versus God Pool or
  Boon Bans interactions.
- Decide whether the UI should ever expose alternate branch planning. The first
  version should not; alternate branches stay vanilla/runtime-owned.
