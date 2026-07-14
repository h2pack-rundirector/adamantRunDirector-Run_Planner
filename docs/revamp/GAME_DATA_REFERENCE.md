# Game Data Reference

## Purpose and Status

This document records the game-data facts on which the revamp depends and the
places where Run Planner intentionally narrows vanilla behavior.

It is a verified reference, not a copy of the game files. Room declarations in
code remain the executable catalog. Biome-specific structural interpretation
will live in `BIOME_RULES.md`.

Verification date: 2026-07-14.

Primary extracted sources:

```text
/home/ayyatma/wsl-projects/modding/1GameData/Scripts/RoomSets.lua
/home/ayyatma/wsl-projects/modding/1GameData/Scripts/RoomDataF.lua
/home/ayyatma/wsl-projects/modding/1GameData/Scripts/RoomDataG.lua
/home/ayyatma/wsl-projects/modding/1GameData/Scripts/RoomDataH.lua
/home/ayyatma/wsl-projects/modding/1GameData/Scripts/RoomDataI.lua
/home/ayyatma/wsl-projects/modding/1GameData/Scripts/RoomDataN.lua
/home/ayyatma/wsl-projects/modding/1GameData/Scripts/RoomDataO.lua
/home/ayyatma/wsl-projects/modding/1GameData/Scripts/RoomDataP.lua
/home/ayyatma/wsl-projects/modding/1GameData/Scripts/RoomDataQ.lua
/home/ayyatma/wsl-projects/modding/1GameData/Scripts/RunLogic.lua
/home/ayyatma/wsl-projects/modding/1GameData/Scripts/RoomLogic.lua
/home/ayyatma/wsl-projects/modding/1GameData/Scripts/RewardLogic.lua
```

Physical exits were cross-checked against extracted map files under
`1GameData/Maps/bin/`; the legacy
`docs/gameinfo/PHYSICAL_EXIT_TOPOLOGY_AUDIT.md` records the probe details.

## Route Order

`RoomSets.lua` declares the current route progression:

```text
Underworld: F -> G -> H -> I
Surface:    N -> O -> P -> Q
```

The planner treats route order as declaration data. It must not hard-code
biome letters into generic walkers.

## Vanilla Room Generation

`ChooseNextRoomData` filters room-set entries by eligibility, builds a forced
pool, and selects from the forced pool when it is non-empty. Otherwise it
selects from the eligible pool.

Room-set multiplicity is base weight. For example, `F_Combat01` through
`F_Combat22` each appear once in the F room set, while some I combat rooms
appear multiple times.

Physical doors are processed sequentially. Each chosen target is passed to
`CreateRoom`, and creation counters advance immediately. Ordinary eligibility
does not generally exclude a room merely because another door in the same
batch already chose that room.

Consequences:

- the same combat map can be generated for multiple peer doors;
- an unentered combat map can be generated again in a later batch;
- generated peers are real room creations with independent reward state;
- an unpicked generated room still contributes to room-creation history.

## Creation and Appearance Caps

These are separate game concepts:

`MaxCreationsThisRun`
: Rejects a room after that concrete room key has been created the declared
  number of times. Unpicked peer targets count.

`MaxAppearancesThisBiome`
: Rejects a room after it has been entered/committed the declared number of
  times in the biome.

`MaxCreationsPerRoom`
: Restricts creation relative to the current source room. It is not a general
  same-batch uniqueness rule.

All supported ordinary `F/G/H/I/N/O/P/Q_CombatXX` declarations inherit or
declare `MaxAppearancesThisBiome = 1`. None declares
`MaxCreationsThisRun`.

Special rooms commonly declare `MaxCreationsThisRun = 1`, including shops,
stories, reprieves, and miniboss variants. Exact ownership must be copied from
the concrete room declaration rather than inferred from room kind.

## Requirement Scope Boundary

The raw catalog contains both current-run predicates and external save/profile
predicates. `DOMAIN_MODEL.md` owns their semantic classification. Applied to
the extracted game data:

- current-run room, reward, encounter, creation, and counter history is
  modeled;
- explicitly identified save progression, story completion, unlocks, world
  upgrades, bounty state, and prior-run encounter completion are out of scope;
- a route-relevant predicate without a registered evaluator is a declaration
  failure;
- an unknown or unclassified predicate is also a declaration failure.

Out-of-scope predicates remain audit metadata. They are deliberately excluded
from planner eligibility rather than silently treated as satisfied.

## Planner Canonicalization

Run Planner intentionally narrows the combat rule:

| Concern | Vanilla | Revamp planner |
| --- | --- | --- |
| Same combat key on peer doors | Permitted when eligible | Replaced by distinct eligible combat keys |
| Unpicked combat key generated again later | Permitted | Earlier dead target is canonicalized to another unused eligible key |
| Enter same combat map twice in a biome | Blocked by appearance cap | Blocked |
| Reward on every generated peer | Generated and independently simulated | Preserved |
| Concrete selected room identity | Exact | Exact |
| Vanilla room-picker probability | Random weighted picker | Not modeled |

The planner therefore represents a canonical legal route, not the exact random
identity of every unentered combat map.

The injective-control rule applies to every supported top-level target. Combat
remapping is the capacity-sensitive vanilla divergence established here. Each
noncombat family must be classified by `BIOME_RULES.md`; a game-permitted
repeat cannot be represented by duplicating a top-level control instance.

Combat remapping is safe only while each biome can injectively assign distinct,
semantically compatible, eligible combat rooms to all combat target slots.
Compatibility includes template, reward surface, relevant room-internal
structure, and target-time eligibility. Capacity is a declaration invariant
and must be tested per compatible pool.

## Combat Pools and Termination Pressure

Unique combat-map counts:

| Biome | Unique combat maps | Termination / structure | Physical exit pressure |
| --- | ---: | --- | --- |
| F | 22 | Preboss forced at `biomeDepthCache = 10` | Combat maps have 1 or 2 exits |
| G | 20 | Preboss forced at `biomeDepthCache = 8` | Combat maps have 2 or 3 exits |
| H | 15 | Preboss forced after 4 entered combat/miniboss/bridge rooms | Relevant maps have 1 or 2 exits |
| I | 24 | 5 Clockwork Goals and 3-6 non-goal rewards | Combat maps have 1 or 2 exits |
| N | 23 | Hub exposes 9-10 persistent pylon doors; 6 pylons are selected | Hub topology is special |
| O | 15 | Preboss forced at `biomeDepthCache = 7` | All modeled O rooms have 1 exit |
| P | 19 | Preboss forced at `biomeDepthCache = 9` | Most rooms have 2 exits; some structural rooms have 1 |
| Q | 16 | Preboss forced at `biomeDepthCache = 7` | Combat maps have 1 or 2 exits; deterministic sets are special topology |

I has 34 weighted combat entries but only 24 unique concrete combat keys.
Control capacity uses unique keys, not room-set weight.

### Q Forced Miniboss Pairs

Q forces two-exit combat maps at biome depths 2 and 5. Their outgoing targets
at depths 3 and 6 are miniboss families:

```text
depth 3: Q_MiniBoss02 / Q_MiniBoss05
depth 6: Q_MiniBoss03 / Q_MiniBoss04
```

The generic picker processes the two physical exits independently and does not
generally sample without replacement. The planner canonicalizes each of these
batches to the two distinct compatible miniboss controls while preserving the
picked concrete identity and both reward offers.

`Q_MiniBoss04` has a raw requirement on prior `GameState` encounter
completion. Prior-save encounter completion is out of scope, so both depth-6
miniboss controls participate in planner topology.

### G Capacity Check

G is the tight variable-exit case.

- At most seven preterminal depths can generate ordinary targets.
- A pessimistic three targets at every depth gives 21 target slots.
- `G_Shop01` must be created during its force window and consumes one
  noncombat target slot.
- At least one eligible G miniboss must be created/entered during the grouped
  miniboss force window and consumes one noncombat target slot.
- The maximum combat pressure is therefore 19 targets.
- All 19 target slots can be matched to distinct combat rooms while respecting
  the direct combat depth predicates.
- G provides 20 unique combat rooms.

If no miniboss is picked early, additional miniboss variants can be created and
consume more noncombat slots, reducing combat pressure further.

### O Capacity Check

O has one physical exit per modeled room. With preboss forced at depth 7, at
most six preterminal ordinary targets can be combat rooms. O provides 15
unique combat maps.

### Capacity Rule

The correct capacity bound is not `termination depth * 2`.

It must account for:

- actual physical exit count of each possible source room;
- deterministic generated sets;
- terminal batches;
- mandatory forced noncombat creations;
- mutual exclusion and eligibility;
- depth-local combat eligibility;
- biome-specific structures such as N hub doors.

The implementation should validate the maximum legal topology through the
same declaration model used by materialization. It must match target demand to
compatible concrete controls, not merely count all rooms tagged `Combat`. A raw
total-room count is only a sanity check.

## Physical Exit Facts

Physical exits belong to the current/source room declaration.

- F combat rooms have one or two exits.
- G combat rooms have two or three exits.
- H uses one or two physical exits; Fields cage count is separate reward
  topology.
- I uses one or two exits; only declared two-exit rooms expose two.
- N pylon rooms have one main return-to-hub exit. Side-room doors and hub doors
  are separate topology.
- O rooms have one ship exit. Wheel offers do not increase exit count.
- P exits carry indoor/outdoor structure and have one or two exits.
- Q uses one- and two-exit combat maps plus deterministic generated-room
  structures.

N side-room declarations intentionally permit repeated appearances, and the
same `N_SubXX` key is predetermined by physical side doors in more than one
combat map. These rooms are parent-local child slots in the planner, not
top-level controls subject to biome-wide injectivity.

The planner must never derive physical exit count from reward count, encounter
count, or number of deterministic alternatives.

## Force Semantics

`ForceAtBiomeDepth = N` is exact-depth forcing and exact-depth eligibility from
that axis.

`ForceAtBiomeDepthMin/Max` is a force window with a deadline. The max is not a
general eligibility upper bound. A separate `GameStateRequirements` predicate
provides a real upper bound when one exists.

Examples:

- `F_Shop01` has a force window and a real biome-depth eligibility cap.
- F miniboss force persists beyond its deadline while the candidate remains
  eligible.
- `G_Shop01` is forced within its window but separately requires at least two
  physical exits and has a real upper eligibility bound.
- G miniboss variants share a force window and become mutually exclusive after
  one is entered.
- H and P miniboss groups use the same distinction between force deadline and
  eligibility.

Force pressure is evaluated across all peer targets generated in the batch.
Forced special rooms relieve combat-control demand because they occupy real
target slots.

## Reward and Acquisition Timing

The current room generates its next rooms and their rewards while it is still
current. Every generated peer reward is offered and affects reward-bag state.

The picked target later acquires its incoming reward. Unpicked peers do not
acquire their rewards.

Offer and acquisition must remain separate history facts:

```text
room.generate_next
  -> reward.offer for every target

selected target entry/acquisition
  -> reward.acquire for the picked target
```

Exceptions are modeled explicitly:

- shops own independent purchase choices;
- O wheel rewards are sequential inside one physical ship room;
- H cage rewards are one peer batch with cage-specific rules;
- N hub rewards generate together and acquire in selected pylon order;
- I Clockwork Goals decrement on acquisition, not merely on door generation.

## Counter Axes

The game exposes distinct axes that declarations and validation must preserve:

`BiomeDepthCache`
: Biome-local committed-room progression.

`BiomeEncounterDepth`
: Biome-local counting encounters. One physical room may contribute zero, one,
  or several increments.

`RoomHistory`
: Committed physical room sequence used for appearance and route-spacing
  predicates.

`RoomCreations`
: Concrete room targets created for doors, including unpicked peers.

`RewardOfferHistory`
: Every generated reward offer.

`LootHistory`
: Acquired rewards only.

No generic planner row index may stand in for these counters.

## Required Reverification

Re-run the relevant audit when any of these change:

- game version or extracted `RoomData` / `RoomSets` files;
- supported routes or biome termination rules;
- physical exit declarations;
- force or eligibility translation;
- room-control uniqueness policy;
- maximum topology supported by the UI;
- reward surfaces or acquisition timing.

A capacity failure must block the declaration update. It must not fall back to
sharing one room control between generated targets.
