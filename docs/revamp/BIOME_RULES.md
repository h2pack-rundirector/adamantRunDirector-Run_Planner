# Biome Rules

## Purpose

This document defines the structural extensions by which F through Q specialize
the common Route Plan, Biome Plan, Room Control, and Generated Batch model.

It does not duplicate complete room declarations. Concrete eligibility, force,
caps, physical exits, reward surfaces, and encounter profiles remain catalog
data. This document owns only the rules needed to interpret those declarations
as biome topology and typed room-local state.

The common rule is:

```text
use Standard topology by default
add a biome rule only when several owners must coordinate
keep room-internal structure inside the owning Room Control
```

## Requirement Scope

`DOMAIN_MODEL.md` owns the `modeled` and `outOfScope` classification. This
document applies that boundary when a biome declaration mixes route-derived
predicates with external save/profile predicates. A route-relevant requirement
without a modeled evaluator prevents catalog construction; it does not become
a production biome state.

Biome rules must name each out-of-scope source they discard. They must not use
external-state uncertainty to weaken modeled current-run structure.

## Shared Structural Rules

### Standard Linear Topology

F, G, H, I, O, P, and Q expose one selected continuation through generated
door batches:

```text
root room
-> generated batch
-> picked target
-> generated batch
-> ...
-> terminal preboss
```

A Standard batch contains one target per declared active physical exit and
exactly one picked target. Every target reward is offered. Only the picked
target enters history and may produce the next top-level batch.

H, I, and Q replace Standard with a specialized batch rule at defined points.
O and P retain Standard top-level topology while specializing room-internal
encounter materialization. N uses a hub-shaped Biome Plan.

### Canonical Room Uniqueness

Top-level target links remain injective by Room Control key. Ordinary combat
duplicates permitted by vanilla are replaced with unused compatible controls
under the policy in `DOMAIN_MODEL.md`.

Biome rules may classify another bounded family as canonicalizable when:

- the picked concrete game-room identity is preserved;
- the replaced target is an unpicked dead leaf;
- the replacement has the same planner-relevant template and reward surface;
- room-internal structure relevant to offered rewards is preserved;
- the compatible control pool is declaration-proven sufficient.

Q forced miniboss peers use this policy. They do not require duplicate control
instances.

### Probabilities

The planner does not model random weights or odds.

- a zero-chance branch is impossible;
- a nonzero-chance branch is authorable when all modeled predicates pass;
- a branch made mandatory by a ceiling, deadline, or structural rule is
  forced;
- a random value needed by later legality is authored explicitly.

### Local Child Slots

Some concrete rooms contain bounded child structure that is not part of the
top-level generated-room tree. Examples include H cages, O wheel encounters,
and N side rooms.

These are statically declared semantic slots inside their owning Room Control.
Their stable address is:

```text
parent room-control key + declared local slot key
```

The child may retain a concrete game room or reward key as data. Repeated child
game keys do not create duplicate top-level Room Controls or dynamic occurrence
IDs.

## Structural Summary

| Biome | Top-level shape | Specialized owner |
| --- | --- | --- |
| F | Linear, variable exits | Standard batches |
| G | Linear, two or three exits | Standard batches |
| H | Linear with a bridge offer window | `FieldsCageBatch` and Fields room controls |
| I | Linear Clockwork progression | `ClockworkDoorBatch` and biome state |
| N | Persistent hub with ordered subset | `EphyraHubBatch` and pylon controls |
| O | Linear, one exit | `ShipCombat` room controls |
| P | Linear with typed physical exits | Exit constraints and Olympus room controls |
| Q | Linear with forced paired miniboss batches | `QMinibossBatch` |

## F: Erebus

### Root and Termination

F begins with one selected opening control from:

```text
F_Opening01
F_Opening02
F_Opening03
```

Openings are root-only and cannot be ordinary generated targets later in the
biome. Opening save-progression requirements are out of scope; the authored
plan selects the concrete opening.

`F_PreBoss01` is the terminal room and is forced at
`biomeDepthCache = 10`.

### Topology

F uses Standard batches. Physical exits belong to the source declaration:

- every opening has one exit;
- `F_Combat01`, `F_Combat09`, and `F_Combat10` have one exit;
- the other supported F combat maps have two;
- story, reprieve, and shop have two;
- miniboss rooms have one.

F has no biome-specific batch state. Shop and miniboss force windows, shop
exit-count requirements, miniboss mutual exclusion, and creation caps remain
ordinary room declaration predicates.

### Control Policy

F ordinary combat targets use canonical room uniqueness. All room-local reward
state belongs to the target Room Control. No F-specific topology is stored in
a combat control.

## G: Oceanus

### Root and Termination

`G_Intro` is the fixed root. `G_PreBoss01` is terminal and forced at
`biomeDepthCache = 8`.

### Topology

G uses Standard batches and is the largest physical peer set in the supported
routes:

- G combat rooms expose two or three exits;
- `G_Story01` has one;
- reprieve and shop have two;
- miniboss rooms expose one or two according to their concrete declaration.

The Biome Plan must preserve exit indexes and generation order. It does not
normalize a three-exit source into primary/secondary rows.

`G_Shop01` has a force window, a real upper eligibility bound, and a minimum
two-exit requirement. G miniboss force persists past its deadline while a
variant remains eligible. Variant exclusion is derived from entered-room
history rather than a planner-only group.

### Control Policy

G ordinary combat targets use canonical room uniqueness. The declaration
capacity proof must account for direct combat depth predicates as well as the
mandatory shop and miniboss target slots.

## H: Mourning Fields

### Entered Structure

`H_Intro` is the fixed root. H then follows a selected linear continuation
driven by entered-room counts.

`H_Bridge01` is force-offered after exactly two entered combat/miniboss rooms
and becomes ineligible once three combat/miniboss rooms have been entered. It
has `MaxCreationsThisRun = 1`, so at most one peer target in that offer window
can be the bridge.

The bridge is not unconditionally entered. With multiple physical exits, the
player may pick another peer and leave the generated bridge as a dead leaf. If
the bridge is picked, it contributes to the terminal count. If it is skipped,
the third entered combat/miniboss room closes its eligibility window.

`H_PreBoss01` is always forced after four entered rooms counted across combat,
miniboss, and bridge rooms. Consequently, the selected H path can reach four
as:

```text
three combat/miniboss + bridge
or
four combat/miniboss without bridge
```

The bridge's concrete encounter/reward variant is room-local. Story/save
requirements selecting an Echo or later variant are classified through the
requirement-scope policy rather than encoded as topology.

### `FieldsCageBatch`

Every H source that generates top-level exits uses a Fields cage batch. The
batch owns one authored roll:

```text
cageRoll = Min | Max
```

Generated Fields combat targets declare `maxCageRewards` values from two
through five. The source room's `MaxDoorCageRewards` initializes the effective
batch maximum to three. The batch then folds only its Fields combat targets in
generation order:

```text
batchCapacity = 3
for each Fields combat target in generation order:
    batchCapacity = min(batchCapacity, target.maxCageRewards)

Min -> visible cage count = 2
Max -> visible cage count = batchCapacity
```

The same roll and derived count apply to every Fields combat target in the
batch. Non-Fields targets do not receive cage slots. A batch with no Fields
combat target retains capacity three for roll history and
`FieldsMaxDoorsRolled` semantics, but emits no active cage slots because there
is no Fields target to own them.

The target Fields Room Control owns three statically declared cage reward
slots. The batch determines how many are active. Inactive slots remain dormant
and do not emit reward offers.

Physical exits and cage rewards are different structures: H has one or two
physical exits, while one Fields combat target may contain two or three cage
rewards.

### `fieldsMaxDoorsRolled`

The Biome Plan materializer exposes a derived counter matching
`FieldsMaxDoorsRolled`:

- it begins at zero;
- a successful Max roll increments it even when capacity clamps the visible
  result to two;
- Max is impossible after the counter reaches two;
- at biome depths 1 through 3, Min and Max are both possible while below the
  ceiling;
- at biome depths 4 and 5, Max is forced while below the ceiling because the
  game performs its ceiling check;
- later depths cannot produce Max under the current chance table.

The UI therefore authors the roll, not only the visible cage count. A visible
count of two does not reveal whether a capacity-two batch took Min or Max.

## I: Tartarus

### Biome State

`I_Intro` is the fixed root and initializes Clockwork progression. A completed
I plan explicitly authors only the randomized limit needed by later rules:

```lua
clockwork = {
    maxNonGoalRewards = 3, -- one of 3, 4, 5, 6
}
```

The initial goal count of five is declaration-fixed and initializes derived
history; it is not persisted authored state. `maxNonGoalRewards` is authored
because the game randomizes it and later force/eligibility depends on it.

### `ClockworkDoorBatch`

Goal versus non-goal is an incoming reward property, not a room kind. Targets
remain concrete `I_CombatXX`, story, reprieve, miniboss, or preboss controls.

Before all goals are acquired, each generated Clockwork batch contains exactly
one `ClockworkGoal` offer. Other target offers use concrete Tartarus reward
surfaces. The picked target determines which offer is acquired.

History updates are acquisition-driven:

- picking and entering a goal target decrements remaining goals;
- merely generating an unpicked goal door does not decrement them;
- acquiring a non-goal room reward increments the non-goal reward counter;
- generated but unpicked normal rewards affect offer/bag history, not the
  acquired counter.

The incoming offer also selects the target combat control's encounter profile.
Goal counting remains derived history, not mutable state owned by combat
controls.

### Special Peers and Termination

I story and miniboss declarations can require another offered I door in the
same batch. `ClockworkDoorBatch` validates that peer condition directly.

Preboss controls become eligible after remaining goals reaches zero. Once the
acquired non-goal count reaches `maxNonGoalRewards`, preboss force pressure is
active. Preboss layout selection conditions based on prior save progression
are out of scope; the plan may select any supported concrete preboss control
whose modeled requirements pass.

Every configured I plan includes its offer kind and concrete reward state.
There is no reward-optional or structure-only I mode.

## N: Ephyra

### Fixed Intro and Hub

N begins with a fixed linked sequence:

```text
N_Opening01 -> N_PreHub01 -> N_Hub
```

`N_Hub` owns one persistent `EphyraHubBatch`. The game catalog maps physical
hub door IDs to 23 combat rooms, two miniboss rooms, and one story room. On the
first hub visit it exposes nine or ten pylon doors, preserves forced eligible
doors, and disables one of the two miniboss doors.

The planner authors:

- `hubDoorCount` of nine or ten;
- that many distinct generated top-level Room Controls;
- one reward offer for every generated hub target;
- an ordered subset of exactly six visited targets.

Door index is persistent physical hub-door identity. Visit order is separate
authored state and must be exactly `1..6` with no repeated target.

All hub target rewards generate together. Unvisited targets remain complete
dead leaves whose offers affect reward bags. A visited target acquires its hub
offer when entered.

### Pylon Stream and Return

The entered history is derived as:

```text
fixed intro
-> hub
-> visited pylon 1
-> hub return
-> ...
-> visited pylon 6
-> hub return
-> N_PreBoss01
```

Hub returns are derived physical history entries, not repeated `N_Hub` controls
or topology cycles. After six Soul Pylons are cleared, pylon exits close and
the preboss gate becomes the selected continuation.

### Combat-Pylon Side Rooms

Each N combat declaration contains zero to three predetermined physical side
doors. Side-room keys are not unique across parent maps: for example,
`N_Sub01` is reachable from more than one concrete combat room and
`BaseN_SubRooms` permits repeated appearances.

Therefore side rooms are not top-level Room Controls. An `EphyraCombat`
control statically declares one child slot per physical side door:

```lua
sideDoorSlot = {
    key = "sideDoor1",
    gameRoomKey = "N_Sub01",
    generated = true,
    enteredOrder = 1,
    reward = { ... },
}
```

Side-door state is active only when the owning pylon is in the ordered six-room
visited subset. An unvisited hub target never loads its map, so its side doors
are not generated; those local slots remain dormant and do not participate in
completeness, offers, or history. The hub target's incoming reward is still
required because that reward was generated with the full hub batch.

`generated` records whether the probabilistic availability check exposed that
physical door. The planner does not model the probability. The exact
sequential minimum-availability rule is deliberately deferred to the N
implementation checkpoint and must be reverified against current game data
before N is accepted as implemented. Only generated slots emit side-room
offers.

`enteredOrder` is optional and unique within the pylon. Generated but unentered
side rooms remain local dead leaves. Entered side rooms materialize as:

```text
N_CombatXX
-> N_SubXX
-> N_CombatXX restore
```

Multiple entered side rooms repeat the child/restore sequence in authored
order before the main return to `N_Hub`.

The pylon control owns child completeness, candidate translation, feedback,
and reward state. Child feedback addresses the parent Room Control plus local
side-door slot key. No dynamic child control or repeated `N_SubXX` control is
created.

## O: Thessaly

### Top-Level Shape

`O_Intro` is the fixed root. Every supported O room has one physical ship exit,
so every top-level batch has one target and that target is necessarily picked.
`O_PreBoss01` is terminal and forced at `biomeDepthCache = 7`.

O has no sibling target-choice UI and no biome-specific top-level batch state.
Its special behavior is entirely room-local.

### `ShipCombat`

An O combat control represents one physical room containing:

1. a non-counting intro encounter;
2. one counting combat encounter;
3. an optional second counting combat encounter.

The second combat is possible with nonzero game chance only while the modeled
`BiomeEncounterDepth` predicates pass. The completed room state explicitly
authors whether it occurred; the planner does not simulate the probability.

Each counting ship encounter owns a sequential wheel offer point. A wheel
contains one or two concrete rewards and exactly one acquired choice. The first
wheel fully offers and acquires before the next encounter's wheel is generated,
so separate wheels are not merged into a room-wide batch.

O combat rooms use these wheel offers instead of an ordinary incoming
generated-door reward. Story, shop, devotion/trial, miniboss, reprieve, and
preboss controls use their concrete declaration-owned reward surfaces.

Room commit advances `BiomeDepthCache` once regardless of encounter count.
Counting encounters advance `BiomeEncounterDepth` independently.

## P: Mount Olympus

### Root and Termination

`P_Intro` is the fixed root and has two physical exits. `P_PreBoss01` is
terminal and forced at `biomeDepthCache = 9`.

P otherwise uses Standard batches. Supported P combat rooms have two physical
exits; special rooms retain their concrete one- or two-exit declarations.

### Typed Physical Exits

P rooms carry `Indoor` or `Outdoor` tags. Exit constraints come from the
physical exit-door type, not a target room's generic next-room list.

An `OlympusIndoorExitDoor` applies the game's
`OutdoorRequiresIndoorTag` rule: when the source room is Outdoor, its target
must carry the Indoor tag. An `OlympusOutdoorExitDoor` has no equivalent target
tag requirement.

Each source declaration therefore preserves exit type and index. Validation
checks the selected target against that exit's constraint. It does not infer
compatibility from visual ordering or flatten both exits to an untyped count.

### Room-Internal Encounters

P combat declarations use a non-counting pre-combat encounter followed by a
counting combat encounter. The `OlympusCombat` materializer emits both phases
from declaration data so `BiomeEncounterDepth` is correct. This structure does
not require an extra authored batch or child control unless a future feature
adds a room-local choice.

Miniboss force windows, entered-variant exclusion, two-exit requirements, and
creation caps remain normal declaration predicates.

## Q: Summit

### Forced Skeleton

Q is a linear biome with a mostly forced depth skeleton:

```text
depth 1  Q_Intro
depth 2  one of Q_Combat03 / Q_Combat05 / Q_Combat15
depth 3  Q_MiniBoss02 + Q_MiniBoss05 batch; pick one
depth 4  eligible Q combat
depth 5  one of Q_Combat12 / Q_Combat13 / Q_Combat14
depth 6  Q_MiniBoss03 + Q_MiniBoss04 batch; pick one
depth 7  Q_PreBoss01
```

The forced depth-2 and depth-5 combat rooms each expose two physical exits.
The minibosses themselves have one exit. The preboss is concrete and terminal.

### `QMinibossBatch`

At depths 3 and 6 the source's two exits form a specialized batch:

- both targets are miniboss controls from that depth's declared pair;
- the two Room Control keys are distinct;
- both concrete rewards are authored and offered;
- exactly one target is picked;
- the picked target is the next entered room;
- the unpicked target is a dead leaf.

The generic vanilla picker processes physical doors independently and does not
generally guarantee sampling without replacement. The planner deliberately
canonicalizes these batches to the two distinct compatible controls. This is
the same unpicked-identity simplification used for ordinary combat targets,
not a claim about vanilla picker probability.

`Q_MiniBoss04` has a prior-save encounter-completion requirement in raw game
data. That predicate is explicitly out of scope. Both depth-6 miniboss controls
participate in planner topology and modeled current-run validation.

Q combat rooms do not gain reward slots merely because they have two exits.
Reward ownership follows each concrete target declaration. Forced miniboss
pairing is topology; physical exit count and reward surface remain separate
facts.

## Declaration and Test Obligations

Every biome declaration must prove:

- its root and terminal controls exist;
- every physical exit index and type matches extracted map data;
- every specialized batch references a registered rule;
- every local child slot has a finite declaration-derived bound;
- every canonicalized target family has sufficient compatible controls;
- modeled requirements have evaluators;
- out-of-scope requirements are individually classified with their source;
- every other route-relevant requirement fails catalog construction;
- the maximum persisted topology fits its declared Lib table bounds.

Focused structural tests must cover:

- F/G variable exit counts and force pressure;
- H cage roll ambiguity, ceiling, and bridge offer/skip behavior;
- I acquisition-driven Clockwork counters and special peer requirements;
- N 9/10 hub doors, ordered six visits, repeated subroom keys, and restores;
- O sequential wheels and encounter-depth changes;
- P exit-type compatibility;
- Q both forced miniboss pairs and canonical distinct-control allocation.

No biome rule may fall back to dynamic control creation, copied room payloads
in topology rows, or runtime reinterpretation of incomplete authored state.
