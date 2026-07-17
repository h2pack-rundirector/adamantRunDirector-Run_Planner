# Biome Rules

## Purpose

This document defines the structural extensions by which F through Q specialize
the common Route Plan, Biome Plan, Room Control, and Generated Batch model.

It does not duplicate complete room declarations. Concrete eligibility, force,
caps, physical exits, incoming-reward bindings, and encounter profiles remain
catalog data. This document owns only the rules needed to interpret those
declarations as biome topology and typed room-local state.

The common rule is:

```text
use LinearBiome with Standard batches by default
add a biome rule only when several owners must coordinate
keep room-internal structure inside the owning Room Control
```

## Requirement Scope

Biome declarations contain only route-derived predicates with registered
evaluators. External save/profile predicates are omitted from production data.
A route-relevant requirement without an evaluator prevents catalog
construction, and external-state uncertainty must not weaken modeled
current-run structure.

## Shared Structural Rules

### Biome Layout Declarations

Every biome declares one `layout` record. The layout owns structural roles and
relationships; Room Declarations continue to own intrinsic room facts. Raw
Room Declarations therefore do not independently author generic `fixed` or
`terminal` booleans.

The supported layout kinds are:

- `LinearBiome` for F, G, H, I, O, P, and Q;
- `HubBiome` for N.

Every layout declaration names its start or fixed entry sequence, continuation
rules, one terminal room and transition rule, and finite topology bounds. Those
bounds cover layout batches and top-level targets only. Room-local child bounds
remain on the applicable Room Declarations and templates.

Top-level target bounds include ordinary generated-batch targets and any
ordinary companion targets stored inside a terminal transition. Multiple
reward realizations of the same terminal Room Control do not consume duplicate
top-level target identities.

### `LinearBiome`

A linear biome has one declared start followed by a selected chain of
continuations:

```text
start
-> generated batch
-> selected target
-> generated batch
-> ...
-> PrebossEntry
```

At every selected source, the authored continuation is either one generated
batch or one terminal transition, never both. A Standard batch contains one
target per active physical exit and exactly one picked target. Every target
reward is offered. Only the picked target continues the selected path;
unpicked targets are dead leaves.

The continuation declaration supplies one default batch rule and an ordered
list of explicit structural overrides. H and I use their specialized rule as
the default. Q uses `Standard` by default and declares its deterministic
miniboss points as overrides. O and P remain linear while specializing
room-local encounters or physical-exit validation.

An override selector uses only topology-visible structural facts such as an
explicit predecessor-room set. It never dispatches from lifecycle counters,
reward history, or concrete-biome conditionals in the generic layout code. The
layout parser rejects overlapping overrides whose precedence would be
ambiguous. Batch and transition rule keys are derived during normalization;
they are not persisted authored choices.

### `HubBiome`

`HubBiome` declares a fixed entry sequence, one persistent hub batch, an
ordered visited subset, derived returns to the same physical hub, and a
separate post-visit terminal transition. The persistent hub batch and terminal
transition occupy distinct structural slots and may coexist. Hub returns do
not create repeated controls or topology cycles.

### `PrebossEntry`

Every supported biome closes through the one registered `PrebossEntry`
terminal transition. It is structurally separate from an ordinary generated
batch and:

- derives the single terminal Room Control from the layout declaration;
- reads the selected predecessor's declared physical exit count;
- applies the layout's declared terminal exit policy;
- supplies immutable predecessor context to terminal materialization;
- ends layout traversal without duplicate terminal-control links.

The terminal layout declaration owns one exit policy:

| Exit policy | Biomes | Physical realization |
| --- | --- | --- |
| `allExitsTerminal` | F, G, H, P | every predecessor exit realizes the same terminal Room Control through a distinct entry offer |
| `singleTerminal` | N, O, Q | the structural terminal point has one shop-only terminal realization and no companion target |
| `terminalWithCompanions` | I entered-preboss outcome | the first active predecessor exit realizes the selected terminal; every remaining exit is an ordinary unpicked companion target |

For `terminalWithCompanions`, the terminal declaration also names the batch
rule governing companion generation. Companion targets are part of the one
terminal transition, use distinct Room Controls, own complete concrete reward
state, and are dead leaves. The terminal transition remains mutually exclusive
with an ordinary continuing batch.

This table describes terminal-transition exit population. I may instead select
an ordinary continuation from a two-exit Clockwork batch after the preboss is
eligible. That batch derives the declined preboss offer from committed prefix
facts; it does not create another terminal exit policy or Room Control
occurrence.

The terminal Room Declaration owns its `entryOfferPolicy`:

| Policy | Biomes | Realization |
| --- | --- | --- |
| `shopThenFillRemainingExits` | F, G, H, P | one shop realization plus one free RunProgress offer for every remaining predecessor exit |
| `shopOnly` | I, N, O, Q | one direct shop realization |

For the forked policy, the one terminal Room Control owns bounded free-reward
slots and an authored entry mode. The predecessor exit count determines how
many slots are active: F, H, and P can activate one; G can activate up to two.
The selected entry mode acquires exactly one realization and enters the same
single concrete terminal room. No layout code switches on a biome, terminal
template, or room name to implement these reward surfaces.

Terminal eligibility and force remain Room Declaration predicates. They can
make an explicit terminal transition required or invalid, but never create,
remove, or replace authored topology.

### Canonical Room Uniqueness

Top-level target links remain injective by Room Control key. Ordinary combat
duplicates permitted by vanilla are replaced with unused compatible controls
under the policy in `DOMAIN_MODEL.md`.

Biome rules may classify another bounded family as canonicalizable when:

- the picked concrete game-room identity is preserved;
- the replaced target is an unpicked dead leaf;
- the replacement has the same planner-relevant template and compiled reward binding;
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
top-level biome layout. Examples include H cages, O reward wheels,
and N side rooms.

H cages and N side rooms are explicit room-local child declarations. O wheels
are phase-owned offer points derived from the room's `ShipCombat` encounter
profile. Both forms become statically bounded semantic slots inside their
owning Room Control. Their stable address is:

```text
parent room-control key + declared local slot key
```

The child may retain a concrete game room or reward key as data. A phase-owned
slot also retains its phase key. Repeated child game keys do not create
duplicate top-level Room Controls or dynamic occurrence IDs.

## Structural Summary

| Biome | Layout kind | Default batch rule | Terminal exit / offer policy | Bounds: batches / targets |
| --- | --- | --- | --- | --- |
| F | `LinearBiome` | `Standard` | `allExitsTerminal` / `shopThenFillRemainingExits` | 10 / 20 |
| G | `LinearBiome` | `Standard` | `allExitsTerminal` / `shopThenFillRemainingExits` | 8 / 21 |
| H | `LinearBiome` | `FieldsCageBatch` | `allExitsTerminal` / `shopThenFillRemainingExits` | 5 / 10 |
| I | `LinearBiome` | `ClockworkDoorBatch` | declined forced offer or `terminalWithCompanions` / `shopOnly` | 12 / 24 |
| N | `HubBiome` | `EphyraHubBatch` | `singleTerminal` / `shopOnly` | 1 / 10 |
| O | `LinearBiome` | `Standard` | `singleTerminal` / `shopOnly` | 7 / 7 |
| P | `LinearBiome` | `Standard` | `allExitsTerminal` / `shopThenFillRemainingExits` | 9 / 18 |
| Q | `LinearBiome` | `Standard` with `QMinibossBatch` overrides | `singleTerminal` / `shopOnly` | 7 / 10 |

## F: Erebus

### Layout Declaration

```lua
layout = {
    kind = "LinearBiome",
    start = {
        mode = "oneOf",
        roomKeys = { "F_Opening01", "F_Opening02", "F_Opening03" },
    },
    continuation = {
        defaultBatchRuleKey = "Standard",
        overrides = {},
    },
    terminal = {
        roomKey = "F_PreBoss01",
        transitionRuleKey = "PrebossEntry",
        exitPolicy = { kind = "allExitsTerminal" },
    },
    bounds = { maxBatches = 10, maxTargets = 20 },
}
```

F begins with one selected opening control. Openings are start-only and cannot
be ordinary generated targets later in the biome. The production profile uses
counting `OpeningGeneratedF`, the normal post-tutorial encounter.
Progression-controlled `OpeningEmpty` and
`FCastTutorialFight` are game-data reference facts, not authored planner
choices or production requirements.

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

### Layout Declaration

```lua
layout = {
    kind = "LinearBiome",
    start = { mode = "fixed", roomKeys = { "G_Intro" } },
    continuation = {
        defaultBatchRuleKey = "Standard",
        overrides = {},
    },
    terminal = {
        roomKey = "G_PreBoss01",
        transitionRuleKey = "PrebossEntry",
        exitPolicy = { kind = "allExitsTerminal" },
    },
    bounds = { maxBatches = 8, maxTargets = 21 },
}
```

`G_Intro` is the fixed start. `G_PreBoss01` is forced at
`biomeDepthCache = 8` by its Room Declaration.

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

### Layout Declaration

```lua
layout = {
    kind = "LinearBiome",
    start = { mode = "fixed", roomKeys = { "H_Intro" } },
    continuation = {
        defaultBatchRuleKey = "FieldsCageBatch",
        overrides = {},
    },
    terminal = {
        roomKey = "H_PreBoss01",
        transitionRuleKey = "PrebossEntry",
        exitPolicy = { kind = "allExitsTerminal" },
    },
    bounds = { maxBatches = 5, maxTargets = 10 },
}
```

### Entered Structure

`H_Intro` is the fixed start. H then follows a selected linear continuation
whose room legality is driven by entered-room counts.

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

Lifecycle history derives a counter matching `FieldsMaxDoorsRolled`:

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

### Layout Declaration

```lua
layout = {
    kind = "LinearBiome",
    start = { mode = "fixed", roomKeys = { "I_Intro" } },
    continuation = {
        defaultBatchRuleKey = "ClockworkDoorBatch",
        overrides = {},
    },
    terminal = {
        roomKey = "I_PreBoss02",
        transitionRuleKey = "PrebossEntry",
        exitPolicy = {
            kind = "terminalWithCompanions",
            companionBatchRuleKey = "ClockworkDoorBatch",
        },
    },
    bounds = { maxBatches = 12, maxTargets = 24 },
}
```

### Biome State

`I_Intro` is the fixed start and initializes Clockwork progression. A completed
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

Goal versus non-goal is an incoming reward property, not a room kind. Authored
batch targets remain concrete `I_CombatXX`, story, reprieve, or miniboss Room
Controls. `I_PreBoss02` remains the singleton terminal control and is never
allocated as an ordinary generated target.

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

The preboss becomes eligible after remaining goals reaches zero. While
eligible, inherited `AlwaysForceOncePerRoom` forces one preboss offer into the
current predecessor's door batch; reaching `maxNonGoalRewards` supplies its
additional force condition. `I_PreBoss02` is the single declared terminal
room. Its inherited run-local Clockwork and shop rules remain modeled, while
its post-true-ending
save requirement is intentionally omitted. `I_PreBoss01` is excluded. Save
progression does not enter the production requirement registry; the selected
plan must satisfy the requirements the planner declares.

`I_PreBoss02` inherits both `AlwaysForceOncePerRoom` and
`MaxCreationsPerRoom = 1`. On a two-exit predecessor, it therefore occupies the
first active exit in physical generation order and the second exit generates
one ordinary I room. The authored continuation form records which outcome the
player selected:

- `Go to Preboss` creates a `PrebossEntry` terminal transition. The preboss is
  selected and entered, while the ordinary room is an authored unpicked
  companion governed by `ClockworkDoorBatch`.
- `Add Next Decision` selects the ordinary room and continues the spine. Once
  the preboss is eligible, the committed Clockwork batch projection derives the
  fixed unpicked preboss offer on the first exit and exposes only the remaining
  ordinary exit for Room Control configuration.

The declined preboss is not persisted as a target, does not claim the terminal
Room Control, and does not expose the preboss shop configuration. Its concrete
room name, Shop door offer, physical exit, and creation event are derived from
the terminal declaration and the committed prefix context. The ordinary room
retains its normal Room Control, incoming reward, and picked state.

On a one-exit predecessor, `Add Next Decision` can still author a structurally
complete ordinary continuation. Contextual validation rejects that history
because the eligible forced preboss must occupy the sole exit. This keeps game
legality in the validator rather than making draw mutate the continuation
form.

Because `MaxCreationsPerRoom` is predecessor-local, a later room may derive
another declined preboss offer. Repeated offers remain topology/history facts;
they never create repeated terminal controls or weaken injective Room Control
allocation.

Every authored ordinary I target still includes its offer kind and concrete
reward state. The entered terminal includes its shop state. A declined derived
preboss contributes only its fixed Shop door offer because no shop inventory
was entered or purchased from.

## N: Ephyra

### Layout Declaration

```lua
layout = {
    kind = "HubBiome",
    entry = {
        mode = "fixedSequence",
        roomKeys = { "N_Opening01", "N_PreHub01", "N_Hub" },
    },
    hub = {
        roomKey = "N_Hub",
        batchRuleKey = "EphyraHubBatch",
        doorCountStateKey = "hubDoorCount",
        visitedTargetCount = 6,
    },
    terminal = {
        roomKey = "N_PreBoss01",
        transitionRuleKey = "PrebossEntry",
        exitPolicy = { kind = "singleTerminal" },
    },
    bounds = { maxBatches = 1, maxTargets = 10 },
}
```

### Fixed Intro and Hub

N begins with a fixed linked sequence:

```text
N_Opening01 -> N_PreHub01 -> N_Hub
```

`N_Opening01` uses counting `OpeningGeneratedN`, the normal progressed-save
encounter. Progression-controlled `OpeningEmpty` is not an authored planner
choice. `N_PreHub01` uses `PreHubGeneratedN`, which is explicitly non-counting.
These encounter effects belong to encounter profiles, not room counter fields.

The `HubBiome` layout owns one persistent batch governed by
`EphyraHubBatch`; `N_Hub` is its declared physical hub room and owns no
outgoing topology. The game catalog maps physical hub door IDs to 23 combat
rooms, two miniboss rooms, and one story room. On the first hub visit the batch
exposes nine or ten pylon doors, preserves forced eligible doors, and disables
one of the two miniboss doors.

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

### Layout Declaration

```lua
layout = {
    kind = "LinearBiome",
    start = { mode = "fixed", roomKeys = { "O_Intro" } },
    continuation = {
        defaultBatchRuleKey = "Standard",
        overrides = {},
    },
    terminal = {
        roomKey = "O_PreBoss01",
        transitionRuleKey = "PrebossEntry",
        exitPolicy = { kind = "singleTerminal" },
    },
    bounds = { maxBatches = 7, maxTargets = 7 },
}
```

### Top-Level Shape

`O_Intro` is the fixed start. Every supported O source has one physical ship
exit, so every generated batch has one target and that target is necessarily
picked. `O_PreBoss01` is forced at `biomeDepthCache = 7` by its Room
Declaration.

O has no sibling target-choice UI and no biome-specific top-level batch state.
Its special behavior is entirely room-local.

### `ShipCombat`

An O combat control represents one physical room containing:

1. `Intro`, with baseline `GeneratedO_Intro01`, which does not count;
2. `Combat1`, with baseline `GeneratedO`, which counts;
3. optional `Combat2`, also with baseline `GeneratedO`, which counts.

The raw game encounter sets also contain progression-only and NPC outcomes, so
they are provenance rather than planner baseline domains. Each phase keeps its
stable `roomControlKey + phaseKey` address. A future enabled persistent NPC
assignment may replace the baseline encounter and its counter effect before
history is built; a disabled NPC layer contributes nothing and its natural
encounters are suppressed within the configured planner prefix.

The game prepares the complete sequence before starting any of these phases.
At the planner's corresponding `room.prepare_encounters` lifecycle point,
`Combat2` is authorable only when the pre-room `BiomeEncounterDepth` is in
`[2, 5]`.
The game also gives that phase a nonzero chance. The planner does not simulate
that probability: completed room state explicitly authors whether the optional
phase is present.

Each counting phase owns one `ShipWheel` offer point. The offer point authors
one shared RunProgress-or-MetaProgress store selection, one or two concrete
rewards from that store, and exactly one picked reward. Its lifecycle is:

```text
encounter.start and increment BiomeEncounterDepth
wheel rewards offer and one is selected
combat completes
selected wheel reward spawns and is acquired
encounter completes
```

Only then may the next encounter begin. Separate wheels are not merged into a
room-wide batch and may select different stores. `Combat2`'s `wheel2` slot is
dormant when that phase is absent. O's one-exit room context makes the
RunProgress Devotion entry ineligible, while fixed `O_Devotion01` remains a
separate forced-reward producer.

Every wheel refreshes the game's pending next-store value. Consequently the
final active wheel supplies the initial base store for the room's outgoing
generated batch: `wheel1` when Combat2 is absent, otherwise `wheel2`. The
ShipCombat canonical fragment exports that store; outgoing-batch
materialization applies ordinary target-store override resolution, including
any forced target that replaces the working default, and validates the
outgoing targets. This dependency does not move outgoing topology or target
rewards into the Room Control.

O combat room declarations therefore use
`incomingReward = { kind = "none" }`. Their encounter profile, rather than
duplicated room-local declarations, owns
`wheel1` and `wheel2`. Story, shop, devotion/trial, miniboss, reprieve, and
direct-preboss controls use their concrete declaration-owned reward bindings;
the direct preboss has the `shopOnly` entry policy.

Room commit advances `BiomeDepthCache` once regardless of encounter count.
Resolved counting encounters advance `BiomeEncounterDepth` independently.

## P: Mount Olympus

### Layout Declaration

```lua
layout = {
    kind = "LinearBiome",
    start = { mode = "fixed", roomKeys = { "P_Intro" } },
    continuation = {
        defaultBatchRuleKey = "Standard",
        overrides = {},
    },
    terminal = {
        roomKey = "P_PreBoss01",
        transitionRuleKey = "PrebossEntry",
        exitPolicy = { kind = "allExitsTerminal" },
    },
    bounds = { maxBatches = 9, maxTargets = 18 },
}
```

`P_Intro` is the fixed start and has two physical exits. `P_PreBoss01` is
forced at `biomeDepthCache = 9` by its Room Declaration.

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

### Layout Declaration

```lua
layout = {
    kind = "LinearBiome",
    start = { mode = "fixed", roomKeys = { "Q_Intro" } },
    continuation = {
        defaultBatchRuleKey = "Standard",
        overrides = {
            {
                key = "Q_Depth3Minibosses",
                when = {
                    parentRoomKeys = {
                        "Q_Combat03",
                        "Q_Combat05",
                        "Q_Combat15",
                    },
                },
                batchRuleKey = "QMinibossBatch",
                targetRoomKeys = { "Q_MiniBoss02", "Q_MiniBoss05" },
            },
            {
                key = "Q_Depth6Minibosses",
                when = {
                    parentRoomKeys = {
                        "Q_Combat12",
                        "Q_Combat13",
                        "Q_Combat14",
                    },
                },
                batchRuleKey = "QMinibossBatch",
                targetRoomKeys = { "Q_MiniBoss03", "Q_MiniBoss04" },
            },
        },
    },
    terminal = {
        roomKey = "Q_PreBoss01",
        transitionRuleKey = "PrebossEntry",
        exitPolicy = { kind = "singleTerminal" },
    },
    bounds = { maxBatches = 7, maxTargets = 10 },
}
```

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

The layout selects these rules from the explicit predecessor-room sets above,
not by reading `biomeDepthCache`. Depth remains game-history evidence for room
force and eligibility validation.

The generic vanilla picker processes physical doors independently and does not
generally guarantee sampling without replacement. The planner deliberately
canonicalizes these batches to the two distinct compatible controls. This is
the same unpicked-identity simplification used for ordinary combat targets,
not a claim about vanilla picker probability.

`Q_MiniBoss04` has a prior-save encounter-completion requirement in raw game
data. Save progression does not enter the production requirement registry.
Both depth-6 miniboss controls participate in planner topology and modeled
current-run validation.

Q combat rooms do not gain reward slots merely because they have two exits.
Reward ownership follows each concrete target declaration. Forced miniboss
pairing is topology; physical exit count and reward binding remain separate
facts.

## Declaration and Test Obligations

Every biome declaration must prove:

- it declares exactly one registered layout kind;
- every start, fixed-entry, hub, and terminal Room Control exists;
- every default, override, hub-batch, and transition rule is registered;
- override selectors use only admitted topology-visible structural facts and
  cannot overlap ambiguously;
- `PrebossEntry` resolves one terminal control whose terminal exit policy,
  `entryOfferPolicy`, companion rule, and predecessor exit bound are mutually
  compatible;
- every physical exit index and type matches extracted map data;
- every local child slot has a finite declaration-derived bound;
- every canonicalized target family has sufficient compatible controls;
- modeled requirements have evaluators;
- every other route-relevant requirement fails catalog construction;
- the declared layout bounds contain the maximum authored batches and
  top-level targets;
- raw Room Declarations do not duplicate layout roles through generic `fixed`
  or `terminal` flags;
- authored persistence does not contain batch or transition dispatch rule
  keys.

Focused structural tests must cover:

- layout-kind parsing, role derivation, bounds, and `PrebossEntry` policy
  compatibility;
- linear batch/terminal mutual exclusion and HubBiome batch/terminal
  coexistence;
- both I preboss outcomes for one- and two-exit predecessors, including an
  invalid one-exit `Add Next Decision`, a two-exit declined derived offer, and an
  entered terminal with an ordinary companion;
- F/G variable exit counts and force pressure;
- H cage roll ambiguity, ceiling, and bridge offer/skip behavior;
- I acquisition-driven Clockwork counters and special peer requirements;
- N 9/10 hub doors, ordered six visits, repeated subroom keys, and restores;
- O sequential wheels and encounter-depth changes;
- P exit-type compatibility;
- Q both forced miniboss pairs and canonical distinct-control allocation.

No biome rule may fall back to dynamic control creation, copied room payloads
in authored topology, hidden dispatch by lifecycle counter, or runtime
reinterpretation of incomplete authored state.
