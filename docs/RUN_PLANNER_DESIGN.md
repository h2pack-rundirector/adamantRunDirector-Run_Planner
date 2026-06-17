# Run Planner Design Notes

Run Planner models a biome using vanilla `BiomeDepthCache` coordinates. A
planner depth is the same depth value vanilla room selection sees.

The first implementation should focus on the linear biomes where this model is
mostly true: `F`, `G`, `P`, and `Q`, plus route-level declarations for fields
cage routing `H`, clockwork `I`, hub-pylon `N`, and multi-encounter `O`.
Other biomes need separate adapters.

## Depth Standard

Planner depths use vanilla `BiomeDepthCache` directly:

- The boss room is excluded.
- The preboss room is included at its vanilla force depth.
- Post-boss transition rooms are excluded. Boss rooms link to them, and they
  hand off to the next biome with `NextRoomSet`.
- Non-starter biome intros are locked entry rooms outside the planned row list.
  They can still lead to a first planned door room at `BiomeDepthCache == 1`.
- `F` is special: its opening room is locked depth `0` because vanilla
  explicitly sets `BiomeDepthCache = 0` for the starter room.
- Normal planned route depths are the depths between the locked entry/opening
  and the preboss.

Current working depths:

| Biome | Route | Depth range | Planned route depths | Notes |
| --- | --- | --- | --- | --- |
| `F` | Erebus | `0..10` | `1..9` | Starter biome. Depth `0` is one of `F_Opening01/02/03`. Preboss offers shop and non-shop major reward branches. |
| `G` | Oceanus | `1..8` | `1..7` | `G_Intro` is a locked entry before the planned row list. Preboss offers shop and non-shop major reward branches. |
| `H` | Fields | Route picks | Picks `1..4` | `H_Intro`, then four preboss picks, then `H_PreBoss01`. Combat maps expose reward cages rather than a single room reward. |
| `I` | Tartarus | Clockwork | Rows `1..11` | `I_Intro` initializes five required `ClockworkGoal` rewards and a vanilla non-goal reward budget of `3..6`. |
| `N` | Ephyra | Hub pylon | Picks `1..6` | Fixed `N_Opening01` into `N_PreHub01`, then hub pylon picks from `N_Hub`. Preboss is shop-only after six pylons. |
| `O` | Thessaly | `1..7` | `1..6` | `O_Intro` is a locked entry before the planned row list. Combat route depths use ship multi-encounter policy. Preboss is shop-only. |
| `P` | Olympus | `1..9` | `1..8` | `P_Intro` is a locked entry before the planned row list. Preboss offers shop and non-shop major reward branches. |
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
- `I_TwoExits` marks maps that can offer an extension path, but the extension
  room itself can be a combat map, fountain, story room, or miniboss. The first offered
  `I_BaseCombat` reward is forced to `ClockworkGoal`; additional offered
  I-room doors can be non-goal rewards or special rooms.
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

The unplanned alternate branch defaults to `VanillaSafe`:

```lua
{
    alternate = "VanillaSafe",
}
```

`VanillaSafe` means vanilla/random selection, excluding rooms reserved for later
planned depths.

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
- At the reserved depth, the reserved room may be forced or preferred based on
  plan mode.
- After the reserved depth:
  - `Strict` should stop chasing a missed room.
  - `Prefer` may allow the room later if it remains valid.

Initial reservation should include explicitly planned rooms that are dangerous
if pre-created:

- rooms with `MaxCreationsThisRun`
- rooms with `MaxCreationsPerRoom`
- exact special-room selections such as story, fountain, shop, trial, and
  miniboss rooms

Reward reservation is a separate later layer. The first implementation should
solve room identity collisions first.

## Depth Roles

The depth role controls which additional fields are valid.

| Role | Map selection | Reward selection | Notes |
| --- | --- | --- | --- |
| `Vanilla` | None | None | Leave depth to vanilla, except reservations still protect future planned rooms. |
| `Combat` | Optional combat room map | Store-defined reward primitive when the room has rewards | Standard generated combat room. Some biomes, such as `Q`, have no combat reward. |
| `Story` | Fixed story room | None | Story rooms are one-time/special and should be reserved when planned. |
| `Fountain` | Fixed fountain room | Store-defined reward primitive when eligible | Must preserve room-specific reward rules. |
| `Midshop` | Fixed shop room | Shop inventory control | This is shop option control, not normal `ForcedReward`. |
| `Trial` | Optional trial-capable combat map | `Devotion` | Trial/devotion rewards are a special path. |
| `Miniboss` | Specific miniboss room | Store-defined reward primitive | Most minibosses restrict `RunProgress` to `Boon`; `Q` uses `TyphonBossRewards`. |

In F/G/I, vanilla can represent Devotion through reward data on normal maps,
but the planner exposes it as the `Trial` role. Planner-facing reward-store
surfaces do not include `Devotion`, so the same user choice is not exposed in
two languages. O is different because vanilla declares an actual
`O_Devotion01` room, so that room is the Trial option.

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

Reward declarations use vanilla reward contexts instead of invented planner
categories:

```lua
reward = { kind = "none" }
reward = { kind = "roomStore", rewardStore = "RunProgress" }
reward = {
    kind = "roomStore",
    rewardStore = "RunProgress",
    eligibleRewardTypes = { "Boon" },
    ineligibleRewardTypes = { "RoomMoneyDrop" },
}
reward = { kind = "roomStore", rewardStore = "HubRewards" }
reward = { kind = "forcedReward", rewardType = "Devotion", rewardStore = "RunProgress" }
reward = { kind = "shop", shopProfile = "WorldShop" }
reward = { kind = "shipWheel", storeSource = "ChooseNextRewardStore" }
```

The context tells UI/runtime which vanilla mechanism owns the reward. The
player-facing choice should be the actual primitive inside that context, such
as `Boon`, `WeaponUpgrade`, `TalentBigDrop`, or `StackUpgradeTriple`.
Room-store contexts can also carry `eligibleRewardTypes` and
`ineligibleRewardTypes`; those mirror vanilla room-level `EligibleRewards` and
`IneligibleRewards` filtering after the broad reward store is selected.

Reward rendering is shared infrastructure, not owned by one route control
template:

- `mods/rewards/surfaces.lua` owns the curated planner-facing reward surfaces.
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
`Devotion` `CountOf` requirement list used to decide whether Trial is pickable.
They are intentionally separate because the live data can differ. In current
vanilla data, Ares can be picked as a boon/devotion source but does not count
toward the two prior gods required to make `Devotion` eligible.

## Route Rules

`route_rules.lua` owns cross-biome rules that are not concrete room catalogue
facts:

- F/G midshop roles require a previous room with at least two exits.
- `Trial` roles require a previous room with at least two exits and two prior
  devotion-counted gods.
- Miniboss roles allow at most one miniboss selection per biome.

Biome layout files should not repeat these as per-room conditions. They should
only declare room-local facts such as depth windows, exit counts, one-time room
limits, and adapter-specific metadata.

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
    majorReward = {
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
`IneligibleRewards` so `RoomMoneyDrop` is not exposed. `Devotion` is absent
from planner reward stores and is exposed only through the `Trial` role.

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
`mods/rewards/surfaces.lua`:

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
    preboss = "shopAndReward",
}

G = {
    kind = "fixedLinear",
    coordinate = "BiomeDepthCache",
    depthRange = { min = 1, max = 8 },
    routeStartDepth = 1,
    routeEndDepth = 7,
    preboss = "shopAndReward",
}

P = {
    kind = "fixedLinear",
    coordinate = "BiomeDepthCache",
    depthRange = { min = 1, max = 9 },
    routeStartDepth = 1,
    routeEndDepth = 8,
    preboss = "shopAndReward",
}

Q = {
    kind = "scriptedFixedLinear",
    coordinate = "BiomeDepthCache",
    depthRange = { min = 1, max = 7 },
    routeStartDepth = 1,
    routeEndDepth = 6,
    preboss = "shopOnly",
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
    routeEndRow = 11,
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
  route depths. Locked intro/opening and preboss depths sit outside this range.
- `slotLayout.default`: default depth behavior, currently `VanillaSafe`
  alternate generation.
- `slotLayout.special`: per-depth overrides such as intro/opening and preboss
  branch shape.
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
  Current fields include `biomeDepth`, `biomeEncounterDepth`,
  `requiresGeneratedIntroEncounters`, and `requiresMultipleOfferedDoors`.
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
`3 Combats`. `3 Combats` is only valid for room-entry encounter depth `2..5`;
outside that range, `Prefer` should fall back to vanilla behavior and `Strict`
should warn rather than fabricating an invalid room state.

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
tape of up to 11 rows:

```text
Row 1: Goal
Row 2: Extension or Goal
Row 3: Extension or Goal
...
Row 11: Extension or Goal
```

Rows below the fifth planned goal are inactive because the preboss follows once
`RemainingClockworkGoals` reaches zero.

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

The extension budget is vanilla-random by default. The data records the
vanilla range, but the UI should treat promises beyond the active budget as
`Prefer` fallback until the runtime adapter intentionally owns and sets
`MaxClockworkNonGoalRewards`.

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
rooms and can be overridden by strict route planning or missed if prerequisites
are not satisfied. It can resolve to shop, Echo story, or a later Nemesis
event; the first declaration keeps that as a bridge reward mode rather than a
normal room reward surface.

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
to take. Runtime should therefore force or prefer the planned selected hub exit
while allowing vanilla to fill the other available hub doors, except for rooms
reserved for future planned picks.

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
5. Force or prefer the primary room at the planned depth.
6. Add reward forcing per role.
7. Add preboss branch controls.
8. Add warnings for unsatisfiable plans.

## Open Questions

- Decide whether `Prefer` should release a missed reserved room immediately
  after its depth or keep it protected for the rest of the biome.
- Decide how much reward reservation belongs in this module versus God Pool or
  Boon Bans interactions.
- Decide whether the UI should ever expose alternate branch planning. The first
  version should not; `VanillaSafe` is the simpler default.
