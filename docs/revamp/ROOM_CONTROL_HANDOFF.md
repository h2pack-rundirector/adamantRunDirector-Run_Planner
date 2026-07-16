# Room Control Design Handoff

Started: 2026-07-15

Last updated: 2026-07-16

## Starting Point

The last implementation commit before this design pass is
`1e8307b refactor(planner): centralize system wiring` on
`codex/planner-revamp`. The committed implementation has the Checkpoint 2
managed-state foundation and the preferred Systems -> DI -> subsystem
composition direction. At the time of this design handoff, real specialized
Room Control templates had not been implemented yet.

This pass deliberately stopped before implementation and produced the
supplemental [`room_controls/`](room_controls/) contract set. Review each
template specification before building that template. The six parent revamp
documents remain authoritative if a supplemental specification conflicts with
them.

## Locked Control Shape

- Every supported top-level room has one statically named Lib control instance.
- Catalog assembly resolves an immutable descriptor and injects dependencies;
  template modules do not leaf-import catalogs.
- Templates are handwritten and explicit. Each concrete room remains readable
  at its declaration point; catalog generation only performs assembly.
- Reward components are ordinary injected Lua collaborators, not nested Lib
  controls.
- Each control owns its bounded room-local persistence, typed runtime/UI read,
  semantic UI mutation operations, and later candidate/feedback translation.
- Biome plans own outgoing topology, source exit batches, picks, counters, and
  route validation. Controls may receive immutable topology context needed to
  activate bounded local state.
- Maximum-capacity persistence is preferred when the game has a small static
  bound. Context activates a prefix or named subset; inactive state stays
  persisted and dormant.
- Fixed facts do not consume persistence merely to make a control nonempty.

## Decisions Made During This Pass

### Shop

Every authored shop slot stores its concrete reward, required payload, and a
`purchased` boolean. `false` is the complete semantic answer "not purchased";
there is no empty/Purchased/Skipped tri-state. Reward selection independently
determines slot completeness.

World Shop has three semantic slots. `I_WorldShop` has five offers and
`Q_WorldShop` has six. The shared component is profile-parameterized and
returns semantic profile slot keys rather than exposing private storage
indexes.

### O combat rooms

An O combat control reserves both reward-wheel surfaces. Its UI exposes an
encounter-count dropdown:

- 2 = Intro plus Combat1;
- 3 = Intro plus Combat1 plus optional Combat2.

Combat1 and its wheel are always active. Selecting 2 makes Combat2 and wheel2
dormant; selecting 3 activates them. Each active wheel authors one or two
offers and exactly one picked offer. The pre-room `biomeEncounterDepth` window
still validates whether the third encounter is legal.

### N combat rooms

Each N combat instance reserves its declaration-known side-room slots, with a
global maximum of three. Repeated `N_SubXX` room names are not identities;
identity is the parent control plus `sideDoorN` slot.

Each side slot distinguishes not generated, generated but unentered, and
entered. The current specification represents that with generation state plus
`enteredOrder`; this also preserves the order needed when several side rooms
are entered. Hub target visitation remains batch-owned.

### H Bridge

`H_Bridge01` does not justify a bespoke control template. The supported
non-progression realization is the Echo story, so it uses the ordinary Story
control with a fixed Story reward. Its bridge encounter profile and topology
remain declaration facts. NPC/event variants are deferred.

### Persistent NPC entities

NPCs such as Heracles cannot remain addon data if enabling them changes the
room spine. The future model is a persistent entity that is disabled when not
configured and merged into complete history when enabled. This is intentionally
deferred: the current checkpoint should establish the room spine without
inventing partial NPC production behavior.

## Preboss Findings and Model

### One terminal room per biome

`I_PreBoss02` is the later post-true-ending layout. It inherits the run-local
Clockwork and shop behavior of `I_PreBoss01`, then replaces the save-gated
presentation/layout variant. Because save progression is outside the planner
baseline, the planner canonically supports `I_PreBoss02` and excludes
`I_PreBoss01`. The resulting catalog has one terminal preboss room in every
biome.

### How vanilla creates Shop and free offers

F/G/H/P do not declare separate shop and reward room IDs. At the terminal
fork, vanilla processes physical doors independently and may assign the same
forced `X_PreBoss01` room to every door. These preboss rooms have no
`MaxCreationsPerRoom` cap.

`ChooseRoomReward` implements `ForcedFirstReward = "Shop"` by scanning the
source room's already-created `OfferedRewards`. The first preboss copy receives
Shop. Later copies fall through to the ordinary eligible `RunProgress` picker,
with Devotion and `RoomMoneyDrop` excluded. Entering any door loads the same
map ID; its `ChosenRewardType` determines whether the map initializes the
World Shop or spawns the selected free reward.

`AutocompleteSurfaceShopDelivery` is unrelated to this split and must not be
used as its model.

### Planner representation

`PrebossShopOrFreeReward` should be deleted. It incorrectly turns a room-level
offer set into a generic named component.

Preboss uses two explicit templates with a shared profile-parameterized shop
component:

- `DirectPreboss` covers N/O/I/Q and is always a shop;
- `ForkedPreboss` covers F/G/H/P and combines a shop with free rewards derived
  from its incoming fork.

This split follows the entry contract rather than the shop profile. It keeps
the direct template free of entry-mode, free-reward, and predecessor-context
branches while avoiding duplicated shop implementation.

Every ForkedPreboss control reserves maximum storage for:

- one complete World Shop inventory;
- `freeRewards[1..maxFreeRewards]`;
- an entry mode restricted to the instance's shop and declared reward slots.

The shared template has a two-slot ceiling. F/H/P declare one free-reward slot
because their predecessor topology has at most two exits. G declares two
because its topology can have three. The catalog cross-checks those instance
bounds against the biome declarations.

The selected leading room's concrete physical exit count is immutable context
and activates:

```text
1 exit  -> Shop
2 exits -> Shop + Reward1
3 exits -> Shop + Reward1 + Reward2
```

F/H/P cannot activate Reward2. G can activate it when the concrete leading
room has three exits. All active offers must be authored because reward
simulation uses picked and unpicked offers. Exactly one active entry mode is
selected.

The Biome Plan derives `leadingRoomControlKey`, `incomingExitCount`, and
`activeFreeRewardCount` on commit. ForkedPreboss neither queries the leading
Room Control nor persists those facts. Its bounded authored read is combined
with the cached context for completeness, materialization, candidates,
feedback, and UI projection. Draw consumes that committed projection.

Changing the selected predecessor recomputes context without clearing dormant
storage or coercing `entryMode`. An entry mode that no longer names an active
offer becomes a normal contextual validation error.

Acquisition is derived, never persisted twice:

- Shop entry acquires only shop slots with `purchased = true`;
- Reward1 entry acquires only free reward 1;
- Reward2 entry acquires only free reward 2;
- unselected offers affect offered-reward simulation but not acquisition.

DirectPreboss controls need no entry dropdown or predecessor context. I uses
`I_WorldShop`, Q uses `Q_WorldShop`, and N/O use `WorldShop`. I's fixed
Clockwork Goal door marker remains execution metadata; it does not create an
alternate realization.

## Declaration Reconciliation

The declaration and catalog layer now reflects the reviewed model:

- `I_PreBoss02` is the sole I terminal room and `I_PreBoss01` is excluded;
- `DirectPreboss` and `ForkedPreboss` replace the generic Preboss template;
- every forked preboss policy embeds an ordinary RunProgress counted binding
  with Devotion and gold excluded;
- the catalog rejects missing or mismatched preboss policies and producer
  bindings;
- `H_Bridge01` uses the Story control template while retaining its bridge
  encounter profile and topology facts.

The next production work is deliberately narrower:

1. reconcile reward producer bindings against
   [`REWARD_CONSUMER_AUDIT.md`](room_controls/REWARD_CONSUMER_AUDIT.md);
2. replace the generic reward prototype with the bottom-up hierarchy;
3. continue real control templates through the existing control subsystem DI
   layer in F/G, H/I, N/O, and P/Q order;
4. add storage-manifest, typed read/write, dormancy, and profile-capacity tests
   before proceeding to Checkpoint 4 materialization.

Do not add NPC support, runtime fallback interpretation, or candidate/feedback
production code merely to complete Checkpoint 2. Those remain later explicit
checkpoints.

## Implementation Progress

The first specialized production prototype now covers all 56 `StandardCombat`
instances across F, G, and Q. It introduces typed whole-control runtime
snapshots and a semantic UI mutation operation. Its initial generic reward
component is deliberately not final:
[`REWARD_HIERARCHY.md`](room_controls/REWARD_HIERARCHY.md) defines the
bottom-up replacement being reviewed. The companion
[`REWARD_CONSUMER_AUDIT.md`](room_controls/REWARD_CONSUMER_AUDIT.md) found
store and filter corrections that must land before that replacement:
no-Devotion minor/major contexts, Tartarus-backed I minibosses, and the
no-Boon Clockwork NonGoal branch. These are explicit producer bindings, not
new named reward components. Every other room template is named explicitly in
the control registry and remains on the transitional address-based adapter;
there is no implicit generic fallback.

This slice intentionally does not add draw views, completeness,
materialization, candidates, feedback, or execution behavior. The next Room
Control slice should continue replacing registry entries with focused template
modules and reuse the reward component contracts rather than extending the
transitional adapter.

## Verification Sources

Relevant live game-data locations used during the design review:

- `Scripts/RewardLogic.lua`: `ChooseRoomReward` and `ForcedFirstReward`;
- `Scripts/RoomLogic.lua`: per-door room/reward construction;
- `Scripts/RunLogic.lua`: room creation caps and forced-room selection;
- `Scripts/StoreLogic.lua`: Shop reward defaulting to `WorldShop`;
- `Scripts/RoomDataF.lua`, `RoomDataG.lua`, `RoomDataH.lua`, and
  `RoomDataP.lua`: multi-offer preboss declarations;
- `Scripts/RoomDataI.lua`: the inherited I shop/Clockwork behavior and the two
  save-progression layout variants; the planner canonically keeps
  `I_PreBoss02`.
