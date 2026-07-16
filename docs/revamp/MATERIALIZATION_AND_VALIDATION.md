# Materialization and Validation

## Purpose

This document defines the derived pipeline between committed planner state and
runtime execution:

```text
committed Route Controls, Biome Plans, and Room Controls
  -> normalize every configured biome topology
  -> for each normalized biome in route order:
       completeness gate
       -> canonical biome snapshot
       -> append ordered lifecycle history and game-language ledgers
       -> selected-plan and candidate validation
       -> stop unless the biome is complete and valid
  -> semantic findings and prepared UI presentation for every configured biome
  -> runtime execution plan when the configured prefix fully passes
  -> atomically publish one derived result
```

This is the authority for canonical shape, history timing, requirement
evaluation, force pressure, reward bags, candidate projection, and execution
plan compilation. `DOMAIN_MODEL.md` owns semantic concepts,
`UI_PERSISTENCE_MODEL.md` owns authored persistence, and `BIOME_RULES.md` owns
biome-specific topology.

The pipeline is pure with respect to authored state. It reads one coherent
committed authored state and produces replaceable derived caches. It never
writes defaults, repairs malformed topology, or reaches into widget/storage
internals.

## Pipeline Contract

One commit-triggered rebuild performs these stages in order:

1. read one coherent committed authored state and its configured route prefix,
   rejecting a prefix outside the active composition domain;
2. normalize the authored topology of every configured biome through its
   registered layout kind into an unpublished route-local table;
3. reject any malformed topology, unknown dispatch key, out-of-bound link, or
   other contact-boundary contract failure found anywhere in that configured
   prefix;
4. begin with empty route history;
5. process normalized configured biomes in route order:
   1. check structural and referenced-owner completeness;
   2. if incomplete, record owner-keyed completeness findings and stop;
   3. drive layout traversal through the common canonical materializer to
      produce one concrete canonical biome snapshot;
   4. pass that snapshot to the registered history-layout translator and append
      its ordered lifecycle events to route history;
   5. validate the biome's selected facts and independently evaluate exported
      candidate projections against the accumulated history;
   6. record blocking selected-plan findings and non-blocking candidate results
      separately;
   7. if the selected plan is invalid, stop; otherwise admit the biome to the
      validated prefix and continue;
6. translate findings through semantic owner descriptors into fresh owner-keyed
   presentation state;
7. ask the registered UI-layout projectors to combine each configured biome's
   normalized topology, owner presentation, and derived `processingState` into
   one fresh prepared biome view;
8. compile a runtime execution plan only if every configured biome completed
   and validated successfully; otherwise explicitly produce no execution plan;
9. atomically publish the canonical snapshots, history, validation result,
   prepared presentation, and execution result as one derived result.

Topology normalization is a contact-boundary operation, not semantic biome
processing. Every biome in the configured prefix must pass it because prepared
UI projection depends on trusted normalized structure. Completeness,
materialization, history, selected-plan validation, and contextual candidate
validation still stop at the first incomplete or invalid biome. Dormant biomes
outside the configured prefix are neither normalized nor processed.

Every configured prepared view carries one derived, non-persisted
`processingState`:

- `validated`: the biome completed and validated successfully;
- `invalid`: the biome completed, materialized, and produced a blocking
  selected-plan finding;
- `incomplete`: the biome was the first semantic blocker and did not produce a
  canonical snapshot;
- `blockedByEarlierBiome`: trusted normalized topology is available, but the
  biome was not semantically processed because an earlier biome blocked it.

The last state is not a finding about that biome. It exists so the UI can show
the authored downstream structure as inactive without pretending it was
checked against history that does not exist.

An empty configured prefix is valid and produces no planner instructions for
that route. Runtime remains vanilla for the entire route.

The output belongs to one immutable published result. Draw may read the
prepared canonical status, feedback, and candidate decoration until committed
configuration changes again. No intermediate result is visible to draw or
runtime consumers.

There is no partially valid execution plan. Earlier valid biome snapshots and
history may remain prepared for UI feedback, but an incomplete or invalid
configured biome clears or withholds the entire prior runtime plan rather than
leaving stale instructions active.

Every meaningful configuration lifecycle event rebuilds synchronously into
unpublished local state. Success atomically replaces the published result. If
the rebuild encounters a contract failure, the coordinator clears the previous
published result before surfacing the error, so no execution plan remains
available. Contract failure is not an `Invalid` planner finding.

## Inputs and Declaration Boundary

Materialization receives:

- one route declaration and its ordered biome-step keys;
- the Route Control's committed configured-prefix state;
- the corresponding committed Biome Plans;
- the statically declared Room Control registry;
- immutable biome-layout, room, reward, requirement, encounter-profile, exit,
  batch, and transition declarations;
- registered topology-layout, history-layout, UI-layout, room-template,
  batch-rule, and terminal-transition implementations;
- stable candidate providers exported by semantic owners.

Declarations contain possible game facts:

- room identity and template;
- physical exits and exit constraints;
- room eligibility, creation caps, appearance caps, and force metadata;
- baseline encounter phases, presence-decision phases, counter effects, and
  phase-owned offer points;
- reward-producer kinds and concrete bindings, stores, counted bags, and shop
  profiles;
- normalized requirements with registered evaluators.

The canonical plan contains only the concrete choices made from those facts.
It must not copy labels, option lists, eligibility predicates, force windows,
physical-exit declarations, or reward-store declarations.

Before history is built, materialization resolves each referenced Room
Control's baseline encounter profile into one effective room spine. At the
current checkpoint this is the baseline itself. A future enabled persistent
NPC layer may replace an addressed phase during this step; a disabled layer is
dormant. No validator or runtime hook may combine baseline history with a
separate NPC side channel after the walk has begun.

## Completeness Gate

Completeness answers whether committed authored state can produce concrete
facts. It does not answer whether those facts are legal.

For each configured biome, completeness requires:

- a known layout kind and well-formed normalized topology within its declared
  bounds;
- layout-specific structural closure from the declared start or entry sequence
  through one declared terminal transition;
- complete generated-batch state, physical target links, and picked or visit
  order state;
- complete terminal-companion links for every predecessor exit required by the
  declared terminal exit policy;
- linear batch/terminal mutual exclusion or the declared HubBiome separation
  between its persistent hub batch and post-visit terminal transition;
- one distinct Room Control key for every referenced top-level room occurrence,
  including starts, fixed entries, generated targets, and the terminal;
- a complete local fragment from every referenced Room Control;
- complete active explicit local-child and phase-derived offer-point slots,
  with inactive optional-phase slots ignored;
- concrete reward types, payloads, purchases, wheel picks, and other local
  choices required by the selected topology;
- a complete terminal Room Control under the immutable context derived by
  `PrebossEntry`.

Every missing value is reported against the smallest semantic owner that can
resolve it: layout start, batch, target, visit, terminal transition, Room
Control, or local slot. Completeness findings use the same stable address
domain as validation findings. An incomplete biome produces no canonical
snapshot and no authoritative contextual candidate validity.

Generated but unpicked targets participate because the game created them and
their rewards were offered. Unreferenced dormant controls do not participate.

Completeness rejects unresolved authoring helpers such as `Auto`, `Vanilla`,
`Major`, `Minor`, blank reward values, partial Devotion source pairs, or an
incomplete active shop offer. A shop's `purchased = false` value is a complete
negative acquisition decision; it does not make a missing reward complete.

Route scope is atomic by biome. If the configured prefix is `F, G, H`, F is
complete and valid, and G is incomplete, F retains its validated snapshot and
history for prepared UI state. G produces completeness feedback but no
snapshot, H is not processed semantically, and no execution plan is compiled.
H still receives an inactive prepared view from its normalized topology. A
complete invalid G produces a G snapshot and validation feedback; H again has
only its `blockedByEarlierBiome` prepared view.

Malformed persisted topology is not ordinary incompleteness. Duplicate
top-level Room Control links, unknown control keys, invalid table indexes, and
storage shapes outside declaration bounds are construction contract failures.
Normalization checks every configured biome before this sequential example, so
the same malformed H state fails loudly instead of being hidden by G.

## Canonical Biome Snapshots and Route Plan

### Canonical Principles

Each complete processed biome produces one non-persisted concrete canonical
snapshot rebuilt from committed state. Ordered biome snapshots compose the
derived route plan. Both are independent of ImGui layout and Lib storage
shape. A snapshot may be complete but invalid; only valid snapshots allow
processing to advance to the next biome.

The composed derived route plan preserves:

- the configured route and ordered biome prefix;
- every entered top-level room;
- every generated peer, including unpicked dead leaves;
- physical exit identity and generation order;
- concrete room-local and batch-local typed state;
- every reward offer and every explicit acquisition choice;
- parent-local child facts;
- semantic return addresses for validation and feedback.

It does not contain dynamic occurrence IDs. Top-level facts are addressed by
the stable Room Control keys already made injective by the Biome Plan. Local
children are addressed by parent Room Control key plus local slot key. Derived
hub returns or room restores use typed lifecycle addresses rather than fake
controls.

### Representative Shape

The exact Lua record names may change, but canonical biomes have explicit
layout variants. A representative linear route result is:

```lua
canonicalRoutePlan = {
    routeKey = "Underworld",
    biomeSnapshots = {
        {
            biomeStepKey = "Underworld_F",
            layoutKind = "LinearBiome",
            startRoom = {
                roomControlKey = "Underworld_F_Opening02",
                gameRoomKey = "F_Opening02",
                roomState = { kind = "Opening" },
                source = { ... },
            },
            biomeState = {},
            batches = {
                {
                    parentRoomControlKey = "Underworld_F_Opening02",
                    batchKey = "nextDoors",
                    batchRuleKey = "Standard",
                    state = {},
                    targets = {
                        {
                            exitIndex = 1,
                            roomControlKey = "Underworld_F_Combat03",
                            gameRoomKey = "F_Combat03",
                            picked = true,
                            roomState = { kind = "StandardCombat" },
                            incomingOffer = {
                                storeKey = "RunProgress",
                                rewardType = "Boon",
                                payload = { source = "ApolloUpgrade" },
                            },
                            source = { ... },
                        },
                    },
                    source = { ... },
                },
            },
            terminalEntry = {
                parentRoomControlKey = "Underworld_F_Combat17",
                transitionRuleKey = "PrebossEntry",
                exitPolicyKind = "allExitsTerminal",
                room = {
                    roomControlKey = "Underworld_F_PreBoss01",
                    gameRoomKey = "F_PreBoss01",
                    roomState = { kind = "ForkedPreboss" },
                    source = { ... },
                },
                offers = { ... },
                entryMode = "Shop",
                companionTargets = {},
                source = { ... },
            },
        },
    },
}
```

A representative hub biome snapshot is:

```lua
{
    biomeStepKey = "Surface_N",
    layoutKind = "HubBiome",
    entrySequence = {
        { roomControlKey = "Surface_N_Opening01", roomState = { ... } },
        { roomControlKey = "Surface_N_PreHub01", roomState = { ... } },
        { roomControlKey = "Surface_N_Hub", roomState = { ... } },
    },
    hubBatch = {
        batchKey = "hubDoors",
        batchRuleKey = "EphyraHubBatch",
        targets = { ... },
    },
    visits = {
        {
            order = 1,
            doorIndex = 4,
            pylonRoom = { ... },
            sideRooms = { ... },
        },
    },
    terminalEntry = {
        transitionRuleKey = "PrebossEntry",
        room = { ... },
    },
}
```

`layoutKind` is the stable translation key used to select the history-layout
translator. The canonical snapshot does not embed layout implementations or
UI projection behavior. Derived `batchRuleKey` and `transitionRuleKey` values
may appear for typed dispatch, but they never become authored persistence.

For I, `terminalEntry.exitPolicyKind = "terminalWithCompanions"` and
`companionTargets` contains every ordinary room generated on predecessor exits
after the selected `I_PreBoss02` exit. These records have the same concrete
room, incoming-offer, source-address, creation, and offer semantics as ordinary
generated targets, but are always unpicked dead leaves and never continue the
canonical path.

`gameRoomKey` is the concrete runtime room name. `roomControlKey` is the
semantic authored owner. They remain separate even when the current naming
scheme makes their relationship obvious.

For ordinary generated doors, acquisition is derived from the batch's picked
target. The incoming offer does not persist or materialize a second editable
`acquired` flag that could disagree with topology. Independent room-local
offers such as shop purchases, O wheel choices, and entered N side rooms carry
their own concrete acquisition state. A phase-owned offer point is addressed
by its parent Room Control and offer-point key; it is not a nested control or a
second room declaration.

### Semantic Addresses

Every authored canonical fact carries the smallest stable address that returns
feedback to its owner.

Room-local fact:

```lua
{
    routeKey = "Underworld",
    biomeStepKey = "Underworld_F",
    roomControlKey = "Underworld_F_Combat03",
    aspect = "generatedReward",
}
```

Batch target fact:

```lua
{
    routeKey = "Underworld",
    biomeStepKey = "Underworld_F",
    parentRoomControlKey = "Underworld_F_Opening02",
    batchKey = "nextDoors",
    exitIndex = 1,
    aspect = "targetRoom",
}
```

Hub target or visit fact:

```lua
{
    routeKey = "Surface",
    biomeStepKey = "Surface_N",
    batchKey = "hubDoors",
    doorIndex = 4,
    aspect = "visitOrder",
}
```

Terminal-transition fact:

```lua
{
    routeKey = "Underworld",
    biomeStepKey = "Underworld_F",
    parentRoomControlKey = "Underworld_F_Combat17",
    transitionKey = "prebossEntry",
    aspect = "continuation",
}
```

A terminal companion fact adds its physical `exitIndex`, referenced
`roomControlKey`, and `aspect = "companionTargetRoom"` under the same terminal
transition owner.

Local child fact adds `roomControlKey`, `localSlotKey`, and its semantic
aspect. Addresses never contain storage positions, generated aliases, widget
IDs, or a lookup by game room key alone.

## Materialization Walk

After all configured topology has normalized successfully, the route
coordinator semantically processes biome steps in declaration order and stops
at the first incomplete or invalid biome. Once completeness succeeds, one
common canonical materializer owns canonical assembly:

1. receive the complete normalized topology and its `layoutKind`;
2. ask the Biome Plan to traverse through
   `topologyLayouts[layoutKind]`;
3. handle each structural visit through a common visitor contract;
4. resolve referenced Room Controls and registered batch or transition rules;
5. assemble exactly one layout-typed canonical biome snapshot.

Layout traversal exposes structure; it does not emit lifecycle history.
`LinearBiome` exposes the start, every generated peer batch on the selected
path, selected continuations, and the terminal transition including any
terminal companion targets. `HubBiome` exposes
the fixed entry sequence, one persistent hub batch, ordered visits, and the
separate post-visit terminal transition.

For a Standard generated batch, the canonical visitor:

1. resolves the entered parent Room Control and its declared active physical
   exits;
2. receives the ordered target links from layout traversal;
3. asks every target Room Control for its concrete incoming reward and typed
   local fragment;
4. records every generated target in physical generation order;
5. records the picked target as the selected continuation;
6. verifies that unpicked targets remain dead leaves.

Registered batch rules interpret only the peer-wide behavior they own:

- `FieldsCageBatch` derives active cage slots from one batch-authored roll;
- `ClockworkDoorBatch` associates one concrete incoming offer kind with each
  target;
- `EphyraHubBatch` materializes the one persistent hub peer set, while
  `HubBiome` traversal owns visit order and returns;
- `QMinibossBatch` materializes the exact distinct pair supplied by the
  resolved layout override.

`PrebossEntry` interprets the terminal transition. It derives the one terminal
Room Control, immutable predecessor context, and terminal exit policy from the
layout. `allExitsTerminal` delegates all physical entry realizations and
entry-mode state to the terminal control's declared `entryOfferPolicy`.
`singleTerminal` admits no companion. `terminalWithCompanions` materializes the
selected terminal on the first active physical exit and delegates every
remaining ordinary target to its declared companion batch rule and referenced
Room Control. None of these policies creates duplicate terminal controls.

Room-template materializers remain local. `ShipCombat` derives wheel slots
from its encounter phases, while Olympus controls emit their declared phases
and typed exit facts. Neither becomes a topology-layout or batch rule.

All interpretation is registry-driven. The common canonical materializer must
not switch on a concrete biome, room name, or UI layout and must not inspect
template storage.

Canonical combat remapping has already been resolved by authored topology. The
materializer verifies injectivity and compatibility; it does not silently pick
a replacement combat control.

## History Layout Translation

Only a complete canonical biome snapshot enters history. The history
coordinator resolves `historyLayouts[snapshot.layoutKind]` and asks that
translator to emit the ordered common lifecycle stream. A history translator
never reads authored persistence, normalized topology, Room Control refs, or
UI projection state.

`historyLayouts["LinearBiome"]` follows the canonical start, generated
batches, selected continuations, and terminal entry.
`historyLayouts["HubBiome"]` emits the fixed entry sequence, hub generation
batch, six visits, derived hub returns, active side-room/restore sequences, and
terminal entry. Both use the same game-language event vocabulary below.

The common canonical materializer does not also emit history, and a history
translator does not rebuild or amend canonical structure.

## Lifecycle Event Stream

### Ordered Phases

History is built from events, not inferred from UI row position. The normal
top-level room order is:

```text
biome.enter

room.enter
incoming_reward.acquire
room.prepare_encounters
room encounter phases and room-local offer points in declared order
room.generate_next
generated target creation and incoming reward offers in exit order
room.commit

biome.complete
```

The event vocabulary is typed rather than restricted to one event per line.
Representative events are:

```text
biome.enter
room.enter
room.restore
encounter.start
combat.complete
encounter.complete
offer_point.begin
reward.offer
reward.acquire
shop.pending.begin
shop.pending.end
room.generate_next.begin
room.create
room.generate_next.end
room.commit
biome.complete
```

Encounter events retain their semantic `roomControlKey`, encounter-profile
key, and phase key in addition to the effective concrete encounter identity.
This lets requirements address stable room-spine phases even when a future
persistent layer replaces the baseline encounter.

The target room is created and its incoming reward is offered by the current
room at `room.generate_next`. If picked, that reward is acquired when the
target is later entered. An unpicked target emits creation and offer events but
no entry or acquisition event.

Room-local event order comes from the registered room template and the resolved
spine based on its encounter profile. This is necessary for O. Its complete
phase sequence is prepared first against the pre-room counter state. The
baseline then emits:

```text
Intro start -> Intro complete
Combat1 start/count -> wheel1 offer/select -> combat complete -> acquire -> encounter complete
Combat2 start/count -> wheel2 offer/select -> combat complete -> acquire -> encounter complete
```

The final line exists only when `Combat2` was authored present. In particular,
the wheel is offered at encounter start, before its combat, while acquisition
completes after combat and before the encounter completes. A single aggregate
`room.encounters -> room.offer_points` phase would be wrong.

Normal shop offers become pending during the shop room. The current room
generates its next doors before a bought shop reward is acquired when that is
the game timing declared for the shop surface. The pending interval ends at
the declared acquisition/exit phase.

### Biome-Specific History

Special structures emit ordinary typed facts in their real order:

- H emits Fields cage offer points only for active slots on generated Fields
  targets; the roll event still updates `FieldsMaxDoorsRolled` when capacity
  clamps visible slots or when a no-Fields-target batch emits no cage slots;
- I decrements remaining Clockwork Goals only on `reward.acquire` and counts
  acquired non-goal rewards separately; its selected preboss terminal emits
  the shop creation/offer first and then every unpicked ordinary companion
  creation/offer in physical exit order;
- N emits the hub reward batch once, then ordered pylon entries, parent-local
  side-room creation/entry, parent restores, and hub returns;
- O resolves optional phase presence at `room.prepare_encounters`, then emits
  each active phase-owned wheel as a distinct sequential offer batch;
- P emits its non-counting and counting encounter phases separately;
- Q emits both forced miniboss creations and offers before following one.

Derived N hub returns and combat-room restores participate in physical history
where the game does, but never create additional Room Controls or violate the
top-level injective-link rule.

## History Ledgers and Counter Views

The history fold exposes named game-language views. Validators ask for the
specific view they need; no generic planner depth or row coordinate exists.

| View | Update point | Included facts |
| --- | --- | --- |
| room creation count | `room.create` | every generated target, picked or not |
| room appearance/history | `room.commit` | entered rooms only, plus declared derived physical entries |
| `biomeDepthCache` | `room.commit` | declaration-defined committed room history |
| `biomeEncounterDepth` | counting encounter event | counting encounters only |
| route encounter depth | counting encounter event | route-wide counting encounters |
| room-history ordinal | declared history event | route-wide spacing axis |
| reward offer history | `reward.offer` | every generated/displayed offer |
| loot type history | `reward.acquire` | normalized acquired loot types only |
| use record | declared use/acquire event | game-equivalent `UseRecord` names |
| biome use record | declared use/acquire event | game-equivalent `BiomeUseRecord` names |
| loot biome record | `reward.acquire` | acquired normalized loot per biome |
| cleared biomes | `biome.complete` | completed biome count |
| unresolved force set | batch resolution | force declarations not yet generated |
| pending shop offers | shop interval events | current bounded shop offer context |

Each event is evaluated against an explicit pre-event or post-event history
view.
Requirement declarations or their evaluator registration name that phase. A
validator must not guess whether a count includes the current fact.

Important distinctions:

- `MaxCreationsThisRun` reads creation history and therefore sees earlier peer
  targets in the same sequentially generated batch;
- `MaxAppearancesThisBiome` reads entered/committed room history, not offers;
- reward bags deplete on `reward.offer`, not acquisition;
- loot/use requirements see only prior `reward.acquire` events;
- one physical room commit advances `biomeDepthCache` once even when it has
  multiple encounters;
- `biomeEncounterDepth` changes only for resolved encounter phases whose
  effective behavior counts;
- Clockwork progress changes on acquisition, not door creation.

## Requirement Model

### Normalization and Evaluator Registration

Hand-authored game requirements are normalized at catalog construction. Each
production predicate has:

- a registered kind or named requirement expression;
- typed arguments;
- a contact-supplied evaluation phase supported by its kind;
- a policy for selected facts and candidates.

Requirement nodes do not store their evaluation phase. The semantic contact
supplies one phase for the complete tree: room eligibility and requirement-
based force use `room.generate_next`, counted reward entries use
`reward.offer`, and authored encounter presence uses its declared
`decisionPhase`. The code-owned kind registry declares which contacts
each kind supports. One requirement tree cannot mix contact phases.

Named requirements are reusable typed expressions, not independent evaluators.
Their payload and references validate at catalog construction, and every use
must be legal at the phase supplied by its contact.

Boolean composition uses explicit `all`, `any`, and `not` nodes. Generic game
paths are translated into typed ledger queries where the fact is current-run
state. Runtime string paths are not the planner's internal query interface.

Modeled predicate families include:

- exact/min/max queries over room creation, room appearance, loot, use,
  biome-use, and cleared-biome ledgers;
- `biomeDepthCache`, `biomeEncounterDepth`, route encounter depth, and
  room-history spacing;
- generated-door counts, exit tags, target peers, and previous-room exits;
- creation and appearance caps;
- force windows and force pressure;
- reward-store membership, counted bag-entry requirements, pending shop
  offers, payload integrity, and same-batch uniqueness;
- named game requirements registered to one of these typed queries.

External save/profile predicates are absent from production declarations. An
unknown predicate kind, unknown named expression, missing evaluator, or
malformed payload is a declaration contract failure that prevents catalog
construction. None becomes a production validator result or defaults to valid.

### Evaluation API

The logical contract is:

```lua
evaluateRequirement(requirement, historyView, contactPhase, evaluationContext)
  -> {
      status = "valid" | "invalid",
      failures = {
          {
              code = "...",
              kind = "...",
              requirementPath = { ... },
              evidence = { ... },
          },
      },
  }
```

Evaluators are pure. They receive the exact history view, source/target
facts, batch peers, exit context, and offer context required by the supplied
contact phase. They do not read controls, persistence, current ImGui state, or
runtime game globals.

Selected-plan validation and candidate projection call the same evaluators.
There is not a permissive candidate rule and a stricter selected rule.

## Structural and Eligibility Validation

Validation runs over one complete canonical biome snapshot in lifecycle order,
with history accumulated from earlier valid biome snapshots. It separates
invariant failures from authored illegality.

Construction/invariant checks include:

- every key resolves through the immutable catalogs;
- the canonical `layoutKind` resolves through the topology and history
  registries required by the headless pipeline;
- control/game-room/template relationships match declarations;
- top-level Room Control references are injective;
- parent-local slots exist and respect declaration bounds;
- every derived batch rule, terminal transition, and room materializer is
  registered;
- selected traversal and generated peers agree;
- no unpicked dead leaf owns downstream top-level topology;
- semantic addresses resolve to exactly one owner.

UI-layout registry coverage is not a game-legality check. Composition support
validates it separately before a biome may claim `plannerActive`; the headless
validator does not import or depend on UI projection services.

Authored structural and timing validation checks:

- declared start or fixed-entry roles and terminal membership;
- resolved continuation overrides and their exact structural configuration;
- linear batch/terminal mutual exclusion and HubBiome persistent-batch/
  terminal-slot separation;
- `PrebossEntry` predecessor context, terminal exit policy,
  `entryOfferPolicy`, and any companion target set;
- physical exit count, index, type, and target compatibility;
- target room eligibility at the source's `room.generate_next` history view;
- creation and appearance caps on their separate ledgers;
- force pressure over the complete peer batch;
- encounter profiles and all named counter gates;
- selected-room sequence and specialized visit order;
- room-local child generation, entry order, and restore rules.

Every target in a generated batch is processed in physical generation order.
After each target, its creation event updates the scratch history used by the
next target. This is required for creation caps and same-batch behavior.

A `terminalWithCompanions` physical set follows the same sequential rule. The
terminal creation occupies the first active exit, then each companion creation
and offer updates scratch history in exit order. Force pressure, peer
requirements, creation caps, and reward validation see the complete physical
set even though only the terminal continues traversal.

## Force Pressure

Force metadata is not local target eligibility. A locally legal target may
still form an invalid batch because the batch failed to spend available exits
on forced work.

At biome entry, build the unresolved set of declared force candidates. At each
`room.generate_next` batch, filter it to candidates that:

- remain unresolved;
- pass normal eligibility against this batch's pre-generation history view;
- have reached their force-window start;
- have remaining creation capacity;
- are compatible with at least one active physical exit.

An exact force depth is both start and deadline. A min/max force window starts
probabilistic force eligibility and becomes hard pressure at its deadline. The
deadline is not an upper eligibility bound. After it, pressure persists while
normal eligibility remains true.

Before any eligible candidate reaches deadline, the planner permits either
forced or ordinary targets because both correspond to nonzero vanilla
outcomes. Once at least one eligible unresolved candidate reaches deadline,
the batch must perform the maximum compatible unresolved force work its exits
can represent.

The required count is a maximum bipartite matching, not simply
`min(forceCandidates, exits)`:

```text
left side:  active physical exits
right side: distinct eligible unresolved force candidates
edge:       that exit can generate that candidate
```

The generated batch is valid when its distinct unresolved force targets can be
matched to the same maximum cardinality. Distinctness is by force declaration
target; duplicate peer creation of one force room resolves only one candidate.

Generation resolves generic force work after the batch is validated. Picking
or entering the target is not required unless a biome-specific declaration
explicitly says otherwise. Creation counters are then advanced in target
generation order.

Candidate target evaluation projects the candidate into its peer batch and
reruns this same matching rule. It does not color a room invalid merely because
that room's own force window is inactive.

## Reward Materialization and Validation

### Reward Concepts

The pipeline keeps these game concepts separate:

`Reward primitive`
: Stable reward identity and normalized acquisition metadata.

`Reward store`
: A unique option domain used for authoring and domain validation.

`Reward bag`
: A counted ordered multiset copied from a game reward store.

`Bag entry requirement`
: Source-specific eligibility attached to one counted entry. Duplicate reward
  names may have different requirements.

`Offer point`
: One game moment that generates one or more concrete offers.

`Reward offer`
: A concrete store, reward type, payload, and source fact.

`Reward acquisition`
: A picked/entered/purchased reward normalized into loot and use ledgers.

`Shop profile`
: A shop option domain. Shops are not reward bags.

Room and local-child materializers emit concrete offer points. Generated-door
offers belong to target Room Controls semantically but emit during the parent
batch. Offer/acquisition timing is derived from topology except where the room
surface owns an independent purchase or selection.

### Generated-Door Store Resolution

An ordinary generated-door batch owns one working default store. The default
normally comes from the source room's prepared next-store choice. The batch
creates all targets and resolves stores in two stages:

1. scan targets in declared door order; every valid `ForcedRewardStore`
   replaces the working default, so the final such override becomes the
   default for otherwise ordinary peers;
2. resolve each target to its `IndividualRewardStore`, otherwise its own valid
   `ForcedRewardStore`, otherwise the final working default.

The canonical batch record derives the effective default and resolved target
stores from its targets; it does not persist another copy of a store choice.
When there is no forced override, ordinary peer target tags must agree and
that shared tag witnesses the authorable default. When a forced override
exists, the last one in door order determines the default for ordinary peers.
If every target has an individual or forced store, the unobserved base default
has no materialized effect. Target Room Controls own their concrete tagged
reward values but do not inspect peers.

O specializes only the source of the initial default: every Ship wheel
refreshes it, so the final active wheel's store supplies the outgoing batch
default when no later target forced-store prepass replaces it. Target override
resolution remains the common algorithm.

### Validation Order

Each offer point is checked in event order:

1. **Offer domain**: the concrete reward belongs to the declared counted
   binding or shop profile and passes positive/negative reward filters.
2. **Payload integrity**: source gods, Devotion pairs, random-loot resolution,
   branch selection, and other typed payload are complete and internally
   legal.
3. **Source entry requirement**: for a bag-backed or shop-backed offer, at
   least one matching counted bag entry or shop option has satisfied
   source-specific requirements at this event. Fixed and forced primitives do
   not borrow requirements from a same-named counted bag entry.
4. **Batch constraints**: peers obey `AllowDuplicates`, the selected shared
   store for ordinary door batches subject to explicit target-store overrides,
   the one shared store within each Ship wheel, H cage duplicate behavior,
   shop group rules, and other same-generation restrictions.
5. **Bag simulation**: match and remove the exact counted entry selected by the
   configured offer.
6. **Acquisition fold**: only an acquisition event updates normalized loot and
   use history.

Reward-type-global shortcuts must not replace source-specific entry
requirements. For example, early and late Hammer entries remain distinct
counted entries even though both offer `WeaponUpgrade`.

### Counted Bag Algorithm

Each bag starts as an ordered copy of its declaration. This algorithm runs
only for values whose producer provenance is that counted bag. For one
concrete offer:

1. evaluate every remaining entry against the current history, room filters,
   batch duplicate set, and entry requirements;
2. collect eligible entries whose concrete reward type and payload domain can
   produce the authored offer;
3. if no entry in the entire current bag is eligible for generation, append
   one full declaration copy and evaluate again;
4. if the appended copy still has no eligible entry, report the store as
   unavailable instead of attempting another refill;
5. if eligible entries exist but none can produce the authored offer, report
   the offer invalid; do not refill merely to obtain a preferred type;
6. deterministically match one compatible eligible entry and remove only that
   counted entry;
7. preserve every ineligible or unmatched entry already in the bag.

The deterministic match rule must be declaration-defined when duplicate
compatible entries differ in downstream meaning. It may not depend on Lua
table iteration order.

Every offered generated peer depletes its bag, including unpicked doors. O
wheels deplete sequentially. N hub rewards deplete as one generated hub batch
before visit acquisitions. Shop offers never remove reward-bag entries, though
their bounded pending interval can affect `RequiredNotInStore` queries.

### Unmodeled Reward Inputs

Save/unlock facts are absent from production reward declarations. Route-
relevant facts not yet derivable, such as an exact current-run trait count
needed by a supported reward source, prevent catalog construction until an
evaluator is implemented or the source is deliberately removed from the
supported surface. They are not approximated, silently accepted, or weakened
to warnings.

## Candidate Projection

Each semantic owner exports its candidate providers once per prepared rebuild.
A candidate record contains:

- its stable semantic owner address;
- provider key;
- stable candidate key and optional cached index;
- a game-language projection operation.

Contextual candidate validation runs only after the current biome is complete
and has produced a canonical snapshot. Before that point, controls expose
their stable declaration-derived domains and completeness presentation, but no
contextual valid/invalid candidate coloring is authoritative.

A `blockedByEarlierBiome` prepared view also exposes only stable
declaration-derived candidate domains. Its topology is normalized for trusted
projection, but it has no local completeness result, contextual candidate
validity, enrichment, or selected-plan findings because semantic processing
never reached it. The projector marks the entire view inactive from its
`processingState`; it does not manufacture local failures to explain the
upstream blocker.

Candidate evaluation uses the history view immediately before the authored
fact and a bounded scratch projection:

1. replace only the candidate-owned semantic value;
2. rematerialize the smallest affected room, child, peer batch, visit, or
   terminal fragment;
3. replay the shared validators from that fact through the necessary local
   horizon;
4. return the failed condition's presentation policy and evidence;
5. discard scratch state without mutating authored or cached canonical state.

Layout-owned candidates project the complete structural owner they affect.
Examples include a target room, picked exit, H cage roll, Q miniboss peer, N
visit order, terminal transition, or terminal companion target. Room-owned
candidates project their
concrete reward, payload, wheel choice, shop choice, entry mode, or local child
state.

Declaration-time impossible values may be absent from a provider's stable
domain. Once the current biome is complete and contextual validation exists,
context-invalid values remain present and receive invalid presentation. No
requirement may hide a value that belongs to the declaration-derived domain.

Selected facts and candidate values use the same rule functions and evidence.
An invalid selected value creates both selected-plan feedback and the matching
candidate result. An invalid unselected candidate creates candidate
presentation only; it does not change `processingState`, block the route, or
withhold an otherwise valid execution plan.

## Findings and Feedback

A finding contains:

```lua
{
    code = "biome_depth_out_of_range",
    severity = "invalid",
    phase = "room.generate_next",
    origin = {
        routeKey = "Underworld",
        biomeStepKey = "Underworld_F",
        ownerKind = "room",
        ownerKey = "F_Story01",
        aspect = "eligibility",
        requirementPath = {},
    },
    providerKey = "targetRoom",
    candidateKey = "Underworld_F_Story01",
    evidence = {
        requiredBiomeDepthMin = 4,
        actualBiomeDepth = 3,
    },
}
```

Codes are reusable reason classifications, not finding identities. They do not
contain route, biome, room, reward, NPC, provider, or candidate identity and
may repeat across declarations. The semantic origin, provider/candidate
address, and local requirement path identify where a failure belongs. Typed
evidence carries expected and actual facts. Human messages are presentation
derived from the reason code and evidence.

Leaf predicates own reason codes. `all` propagates its failed children and has
no aggregate code. `any` owns an aggregate code when no alternative passes,
and `not` owns a code for the case where its child succeeds.

Completeness findings use the same envelope with `severity = "incomplete"`
and the semantic address of the missing start, batch, target, visit, terminal
transition, Room Control field, or local slot. They do not require a canonical
snapshot to exist and do not masquerade as failed game requirements.

Feedback resolution is direct:

```text
routeKey
  -> biomeStepKey
      -> Room Control or local slot
      or layout start, batch, visit, or terminal transition
          -> semantic aspect/provider
```

During the committed rebuild, semantic owner descriptors translate findings
into prepared provider validity, color, message, marker, and status tables.
Those tables belong to the coordinator's non-persisted route presentation
cache, not to persisted controls or callback-owned refs. Translation must not
mutate authored state.

The registered UI-layout projector places owner-keyed presentation into its
linear or hub prepared view. Feedback translation does not know UI row,
physical storage, widget, or callback-ref identity.

Findings and provider presentation are produced inside the same unpublished
rebuild. Feedback resolves by stable semantic owner, provider, and candidate
keys; it is never queued for a later rebuild or applied by a cached candidate
index.

The first incomplete or blocking selected-plan finding defines the semantic
processing horizon. Later configured biomes are not processed, but their
already normalized authored topology is projected into prepared views with
`processingState = "blockedByEarlierBiome"`. That downstream content is
inactive, exposes stable domains only, and suppresses contextual validity and
enrichment. The current complete biome's canonical snapshot and history are
not truncated or rewritten. Route status and markers are the common
invalid-reporting surface; controls do not invent a second inline error
language.

## Execution-Plan Compilation

Compilation accepts only a configured route prefix for which every biome is
complete and has no blocking validation findings.

The execution plan is an ordered, callback-oriented instruction stream. It
contains concrete runtime decisions such as:

- expected route, biome, current room, and lifecycle phase;
- physical exit-to-target room assignments in generation order;
- concrete effective encounter assignments and suppression policy for
  unplanned natural encounter replacements;
- concrete generated reward and payload assignments;
- selected/entered continuation;
- room-local encounter, wheel, cage, shop, and child instructions;
- biome-global authored values needed by runtime hooks;
- explicit end-of-configured-prefix behavior.

Instructions have compiler-owned sequential IDs or cursors for runtime
diagnostics. These are runtime identities, not UI occurrence identities and
are never persisted back into authored topology.

Runtime hooks retrieve the coordinator's currently published execution plan and
consume the next instruction matching their declared callback boundary. Plan
replacement also resets its instruction cursor; hooks do not retain instructions
from a previous plan. They may translate live game objects into stable keys and
verify the expected context, but they do not:

- rerun room eligibility, force pressure, reward bags, or candidate logic;
- choose among unresolved rooms, rewards, or payloads;
- repair a missing instruction with a guessed/default value;
- mutate planner controls or topology;
- force behavior after the configured route prefix.

A context mismatch is a runtime diagnostic and fail-closed planner condition.
Outside the configured prefix, vanilla generation remains authoritative.

UI-only semantic return addresses may be dropped after compilation, while
diagnostic source codes and expected stable game keys may be retained.

## Dirty Rebuild, Caching, and Performance

Committed configuration change, profile load/reset, hash import, explicit
configuration reload, module initialization, or declaration rebuild runs the
same derived route rebuild and atomic publication path.

A rebuild allocates and prepares canonical/history/validation/presentation
data once after commit or the equivalent configuration lifecycle event. Normal
draw then reads cached state. Required implementation properties are:

- one route history walk per commit-triggered rebuild;
- stable provider values and labels between domain changes;
- reused mutable candidate validity/color/message arrays;
- mutation only of unpublished build buffers followed by an atomic reference
  swap; the currently published result is immutable;
- indexed semantic owner lookup for feedback;
- no callback-owned UI refs required for feedback translation;
- bounded scratch state for candidate projection;
- no history, requirement, bag, or compilation work in immediate-mode draw;
- no repeated reads of nested control internals by validators;
- no use of mutable caller-owned draw option tables by builders.

The initial implementation may favor clear immutable rebuild records. Before
the draw path is accepted, allocation tests must prove that cached drawing does
not rebuild or allocate candidate and history structures per frame.

## Failure Classes

The pipeline distinguishes:

`Incomplete`
: Authored referenced state lacks a concrete required choice. Produces local
  completeness feedback, prevents that biome's canonical snapshot, and blocks
  route execution compilation.

`Invalid`
: A complete authored fact violates a modeled game/planner rule. Produces a
  blocking selected-plan finding.

`Contract failure`
: Catalog, storage, registration, address, or internal shape contradicts a
  construction invariant. Fails loudly at its boundary and is not converted
  into a user-invalid candidate. An inactive configured prefix loaded through
  persistence/import is one such configuration contract failure.

`blockedByEarlierBiome` is not a fourth failure class. It is derived UI
processing state for a configured biome whose normalized topology is trusted
but whose semantic evaluation was deliberately not reached.

Runtime mismatches form a separate execution diagnostic. They must not be
hidden as planner incompleteness.

## Required Tests

The pipeline test suite must cover:

- topology normalization of the entire configured prefix before semantic
  processing, including a malformed downstream biome behind an earlier
  incomplete or invalid biome;
- sequential biome completeness/validation gates and refusal to process later
  biomes after the first incomplete or invalid biome;
- one prepared view per configured biome, with downstream views marked
  `blockedByEarlierBiome` and limited to stable declaration-derived domains;
- owner-keyed completeness findings without canonical materialization or
  contextual candidate validity;
- common canonical materialization driven by registered topology-layout
  traversal;
- distinct `LinearBiome` and `HubBiome` canonical variants;
- history-layout translators consuming complete canonical snapshots only and
  never rebuilding canonical structure;
- linear generated-batch/terminal mutual exclusion and HubBiome persistent
  hub-batch/terminal coexistence;
- I terminal transitions with zero or one unpicked ordinary companion target;
- injective top-level links and local-child repeated keys;
- selected linear continuation with complete unpicked dead leaves;
- target creation and offer events for every generated peer;
- acquisition only for picked/entered/purchased facts;
- sequential peer creation caps and appearance-cap separation;
- exact counter timing for `biomeDepthCache`, `biomeEncounterDepth`, encounter
  depth, room-history ordinal, and cleared biomes;
- force start/deadline persistence and structured-exit maximum matching;
- reward domain, payload, source-entry, same-batch, counted depletion, and
  append-on-empty refill behavior;
- N hub batch timing, side rooms, restores, and returns;
- O interleaved encounters and wheel offers;
- H cage roll history and I acquisition-driven goal history;
- P typed exits and Q deterministic paired batches;
- modeled requirement handling and catalog rejection of unknown or evaluator-
  less requirements;
- selected and candidate use of the same rule functions;
- invalid unselected candidates producing prepared candidate presentation
  without blocking an otherwise valid selected plan;
- context-invalid declaration values remaining present with invalid
  presentation;
- finding resolution by stable semantic owner/provider/candidate keys inside
  the same rebuild;
- one published prepared route result per draw, containing one view per
  configured biome, and replacement publication before the draw following a
  commit;
- rejection of inactive configured-prefix imports without clamping;
- atomic published-result replacement after a successful rebuild and
  previous-result clearing after a failed rebuild;
- compilation refusal for incomplete or invalid configured prefixes;
- runtime instruction order, context mismatch, and vanilla suffix handoff;
- zero materialization/history/validation work on unchanged draw frames.

Declaration fixtures must test the maximum compatible-control demand used by
canonical room uniqueness. Tests may not replace that proof with a raw count
of rooms tagged `Combat`.

## Explicit Non-Goals

This pipeline does not:

- reproduce vanilla room-picker probabilities;
- recover the exact vanilla identity of canonicalized unpicked combat rooms;
- validate incomplete plans by inventing defaults;
- store canonical/history/validation documents as a second profile format;
- introduce dynamic occurrence or node IDs;
- let validators inspect widgets, storage positions, or private control aliases;
- collapse offers and acquisitions or reward stores and counted bags;
- treat force deadlines as eligibility maxima;
- let runtime hooks reinterpret planner intent.
