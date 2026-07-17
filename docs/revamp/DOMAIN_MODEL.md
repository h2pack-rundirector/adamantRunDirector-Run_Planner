# Run Planner Domain Model

## Purpose

This document defines the semantic model of the revamp. It deliberately avoids
ModpackLib APIs, storage aliases, ImGui composition, and runtime hook details.

The model is built around a finite, statically known room universe and a small
dynamic topology:

```text
Route Plan
  -> ordered Biome Plans
      -> one declared Biome Layout per route-biome step
          -> authored topology in that layout's structural language
              -> unique concrete Room Controls
                  -> room-local authored state and rewards
```

The planner is prescriptive. It constructs one concrete legal route and all
reward offers generated beside that route. It is not a probability simulator
or an exact recorder of every vanilla room-picker outcome.

## Planner Validity Domain

Production requirements are hand-authored only when the route plan and its
derived history contain the state needed to evaluate them. Every production
predicate has a registered evaluator and participates in eligibility or
validation.

Requirement expressions are phase-free. Their room, reward, encounter, or
other semantic contact supplies the evaluation phase for the complete tree,
and the code-owned kind registry defines which contacts each predicate kind
supports. Reusable reason codes classify failures; semantic origin descriptors
identify the affected route, biome step, room, reward, or local slot.

Dependencies on prior-run/save story progression, unlocks and world upgrades,
active bounty overrides, current trait/aspect/familiar state, and prior-run
encounter completion are deliberately absent from production declarations.
They may be recorded in game-data reference material or a future development-
time conformance audit, but they are not catalog data, validator results, or
feedback states.

A route-relevant predicate without a registered evaluator or an unknown
predicate is a declaration contract failure and prevents catalog construction.
External-state omission must never become a fallback for unfinished support of
a current-run fact.

Current-run facts emitted by the configured route remain modeled even when the
game expresses them through a generic path. Room entry, reward acquisition,
biome counters, creation history, and encounter history are not save-state
exceptions.

## Core Terms

`Route Declaration`
: A stable route key and its ordered biome-step declarations. Current routes
  are Underworld (`F -> G -> H -> I`) and Surface (`N -> O -> P -> Q`).

`Route Plan`
: The authored state for one route. It owns route-global choices, configured
  route-prefix scope, and ordered access to its Biome Plans.

`Biome Step`
: One occurrence of a biome declaration inside a route. It has a stable key
  such as `Underworld_F`. The step key, not only the biome letter, scopes
  authored controls and state.

`Biome Plan`
: The planner-owned decision-tree object for one route-biome step. It owns the
  bounded persistence descriptor and reversible codec for authored topology
  and biome-global state, delegates structural interpretation to the step's
  declared layout kind, and is the only owner of structural choices such as
  generated batches, target links, picked state, ordered visits, and
  terminal-transition presence. It is not a Lib control.

`Biome Layout Declaration`
: The immutable structural contract for one biome. It selects a registered
  layout kind and declares relationships and roles such as starts, fixed entry
  sequences, continuation rules, specialized structural overrides, the
  terminal room, and topology bounds. It does not copy intrinsic Room
  Declaration facts such as eligibility, force, or physical exits.

`Biome Layout Kind`
: A registered structural language that defines the bounded authored topology,
  structural completeness, semantic mutations, and traversal contract for a
  family of biomes. The current domain requires `LinearBiome` and `HubBiome`.

`Authored Biome Topology`
: The route-biome step's committed structural choices interpreted under its
  Biome Layout Declaration. It contains domain relationships such as batches,
  targets, selected continuations, visits, and terminal transitions. It is not
  a UI row model, canonical snapshot, or lifecycle history.

`Room Declaration`
: Verified game data for one concrete game room key such as `F_Combat04`. It
  owns type, tags, eligibility, force, caps, exits, its encounter-profile key,
  and concrete incoming-reward binding. It does not duplicate encounter phases or their
  counter effects.

`Encounter Profile`
: A finite fixed or authored baseline sequence of encounter phases. It owns
  stable phase keys, order, kind, optional presence, baseline encounter
  identity and `biomeEncounterDepth` effect, and any reward offer point attached
  to that phase. Optional presence is decided at an explicitly named lifecycle
  point, not recomputed while later phases execute. Concrete baseline keys
  remain leaf facts on the profile phase; there is no parallel registry of
  empty encounter-name records.

`Resolved Room Spine`
: The effective ordered room phases after active persistent route entities have
  been merged into the baseline profile. With no such layer enabled, it equals
  the baseline. A future NPC assignment may replace a phase's encounter and
  counter effect without changing its stable phase address. History consumes
  only the resolved spine, never the unmerged profile plus side-channel data.

`Room Template`
: Reusable typed behavior such as `StandardCombat`, `FieldsCombat`,
  `ShipCombat`, `ClockworkCombat`, `Story`, `Shop`, `DirectPreboss`, or
  `ForkedPreboss`. A template defines the authored schema and semantic
  interface shared by room controls of that type. A contextual template may
  receive immutable Biome Plan context without owning or persisting the source
  topology.

`Room Control`
: One statically materialized instance for one top-level concrete room
  declaration in one biome step. It owns room-local authored persistence,
  completeness, candidate translation, feedback translation, and canonical
  fragments.

`Local Child Slot`
: One statically bounded semantic child inside a Room Control, identified by
  its parent control and slot key. A slot is either declared directly by the
  room or derived from its encounter profile. It models room-internal
  structures such as H cages, O reward wheels, and N side doors.

`Generated Batch`
: The complete set of rooms generated together from a source room. It owns
  physical exit association, peer membership, picked state or selection order,
  and batch-authored state. Its governing rule is derived from the validated
  Biome Layout Declaration and structural context rather than authored as an
  independent topology choice.

`Terminal Transition`
: A structural continuation that closes a biome at its one declared terminal
  room. Every supported biome uses `PrebossEntry`. The layout's terminal exit
  policy determines how the predecessor's physical exits are populated, while
  the terminal Room Control's entry-offer policy determines only its local
  shop/free-reward realization. A terminal transition may therefore contain
  bounded unpicked companion targets without becoming an ordinary continuing
  batch.

`Derived Terminal Offer`
: A deterministic unpicked physical-door offer produced by a registered batch
  rule from the declared terminal room and committed prefix facts. It is not
  authored persistence, an ordinary generated target, or another Room Control
  occurrence. I uses this fact when an eligible preboss is offered beside an
  ordinary room and the ordinary room is selected. Selecting and entering the
  preboss is represented instead by the terminal transition.

`Dormant Room Control`
: A declared room control that is not referenced by the current topology. Its
  state may persist, but it does not participate in completeness,
  materialization, history, validation, or runtime.

## Identity

### Game and Control Identity

A game room key identifies a game declaration:

```text
F_Combat04
```

A top-level room-control key scopes that declaration to one route-biome step:

```text
Underworld_F_Combat04
```

Conceptually:

```text
roomControlKey = biomeStepKey + concrete game room key
```

If a future route contains the same biome more than once, its biome-step keys
must remain distinct. Control identity must never be reconstructed from a
mutable visual position.

Room-control keys are used consistently for:

- static control registration;
- topology links;
- local persistence ownership;
- candidate application;
- feedback resolution;
- dormant-state lookup.

There is no planner occurrence ID in the revamp model.

Injective top-level Room Control use makes the unique Room Control key the
occurrence identity shared by topology, UI projection, materialization, and
leaf feedback. A structural slot that does not yet contain a room is identified
by its semantic parent and physical exit or door index instead.

### Local Child Identity

A bounded room-internal child or phase-owned offer point is addressed through
its owning control:

```text
parentRoomControlKey + localSlotKey
```

The slot may carry a concrete game room or reward key as data. Explicit room
children come from the room declaration; encounter offer points come from the
room's referenced encounter profile. The Room Control manifest flattens both
sources into one stable local-slot list. It does not create nested controls.

The same child game room key may appear in slots owned by different parent
controls. This is required for N side rooms, where one `N_SubXX` declaration
can be predetermined behind physical doors in several different pylon maps.

Child slots do not participate in the top-level control registry or Biome Plan
link table. Their parent template owns their storage, completeness, candidates,
feedback translation, and materialization.

### Encounter Phase Identity

Every encounter phase has a stable room-local address:

```text
roomControlKey + phaseKey
```

The address survives baseline encounter replacement. Persistent route-level
entities such as a future NPC assignment target this semantic address, not a UI
row or encounter-set position. The resolved phase remains part of the owning
Room Control's canonical fragment.

### Injective Topology References

Within one Biome Plan, one top-level Room Control represents at most one room
occurrence in the authored topology. It may occupy a declared start or fixed
entry role, a generated target role, or the terminal role. A control already
occupying one occurrence cannot be introduced as a second generated target or
second terminal occurrence. Generated-target allocation is therefore
injective:

```text
one generated target -> one room control
one room control      -> zero or one generated targets
```

This rule has three sources:

1. structural rooms such as openings and terminals are singletons;
2. rooms with `MaxCreationsThisRun = 1` are creation-unique in the game;
3. ordinary combat rooms are made creation-unique by planner policy even
   though vanilla permits repeated generation before entry.

A derived terminal offer does not weaken this invariant. It carries the fixed
game room, physical exit, creation, and incoming-offer facts needed by history,
but it does not allocate or materialize a top-level Room Control occurrence.
Several predecessors may therefore derive declined offers of the same
terminal declaration while the singleton terminal control remains unclaimed
until one terminal transition enters it.

Injectivity is a planner invariant for every supported top-level target, not an
inferred vanilla invariant. A noncombat declaration that can legally be
generated more than once must be classified by its biome rules as structurally
singleton or canonicalizable to distinct compatible controls. Otherwise the
catalog does not support that route surface. It must not quietly acquire a
second logical instance.

The combat rule is a deliberate canonicalization. When vanilla could generate
an unpicked `F_Combat04` and later generate the picked `F_Combat04`, the
planner assigns the earlier dead target another unused eligible
standard-combat room key. The selected rooms and all offered rewards remain
representable.

Replacement is allowed only between semantically compatible declarations. A
replacement must preserve the template, compiled reward binding, physical-exit and
room-internal structure relevant to the plan, and eligibility at that target.
For example, a specialized N combat room with side-room behavior is not spare
capacity for a plain combat target merely because both declarations are tagged
`Combat`.

Every supported biome must prove that each compatible eligible room pool can
satisfy this injective allocation. Failure is a declaration/capacity error.
The planner must not silently create dynamic duplicate controls.

## Route and Biome Composition

A route declaration owns biome order:

```lua
routes = {
    Underworld = { "F", "G", "H", "I" },
    Surface = { "N", "O", "P", "Q" },
}
```

A Route Plan composes the corresponding Biome Plans in that order. Configured
scope is an ordered prefix of zero through all declared biomes:

```text
Underworld_F
Underworld_G
Underworld_H
Underworld_I
```

If a biome step is inside configured scope, it must be complete. Biomes after
the configured prefix are absent from the canonical plan; they are not emitted
as `Vanilla`, `Auto`, or placeholder states.

An empty prefix is valid and leaves that route entirely under vanilla control.
It is the persisted default for every Route Plan, including a fresh profile and
Lib reset to defaults. The Route Plan is already identified by its route key.
Active UI route/biome selection is transient navigation, while runtime route
identity comes from live game context.

The configured prefix is authored scope, not proof that every downstream
planner subsystem is already active. Composition exposes only the contiguous
prefix backed by an `authoredEditor`; configured editor-only state may exist
before canonical materialization or the headless pipeline. Full semantic
planner activation is a separate capability boundary.

The Route Plan owns:

- stable route identity and configured prefix;
- route-global authored inputs;
- ordered Biome Plan composition;
- cross-biome materialization and validation orchestration;
- route-wide derived caches.

It does not own room-local payloads or duplicate biome topology inside one root
document.

After a meaningful committed configuration lifecycle event, route orchestration
reads one coherent committed authored state and rebuilds into unpublished local
state. Success atomically replaces the canonical biome snapshots, history,
validation result, one prepared view per configured biome, and execution plan
as one derived result. A contract failure clears the previously published
result before surfacing the error, so no old execution plan remains active for
changed configuration. None of this derived state is persisted.

## Room Catalog and Templates

Each supported top-level concrete game room has one declaration. Declarations
own game facts:

```lua
F_Combat04 = {
    kind = "Combat",
    template = "StandardCombat",
    eligibility = { ... },
    force = nil,
    caps = {
        maxAppearancesThisBiome = 1,
    },
    exits = {
        {},
        {},
    },
    encounterProfile = "StandardCombat",
    incomingReward = {
        kind = "countedChoice",
        storeKeys = { "RunProgress", "MetaProgress" },
        eligibleRewardTypes = {},
        ineligibleRewardTypes = {},
    },
}
```

Declarations must not own authored values, UI grouping, topology links, picked
state, or copied reward choices.

Templates own reusable behavior. Each concrete declaration produces a distinct
room-control instance from its template:

```text
StandardCombat template
  -> Underworld_F_Combat01 control
  -> Underworld_F_Combat02 control
  -> ...
  -> Underworld_F_Combat22 control
```

The template removes repeated implementation code without sharing authored
state between concrete rooms.

## Biome Topology

The raw biome declaration field is `layout`. `Topology` is reserved for the
authored or normalized structural state interpreted under that declaration.
The common Biome Plan delegates structural reads, completeness, mutation, and
traversal to the registered implementation for its layout kind. It does not
switch on concrete biome or room names.

`LinearBiome` models a declared start followed by a selected chain of
continuations. A continuation is either:

- one generated batch whose selection identifies the next entered target; or
- one terminal transition to the declared terminal Room Control.

These continuation forms are mutually exclusive at every selected source,
including while the topology is incomplete. A declared terminal exit policy
may place ordinary unpicked companion targets on physical exits beside the
selected terminal room; those targets are owned inside the terminal transition
and never continue traversal. All other unpicked generated targets are likewise
dead leaves. There is no independent entered-room list that can disagree with
the selected path.

I preserves these same two continuation forms. Once the preboss is eligible,
a two-exit generated batch means the ordinary room was selected and the batch
rule derives an unpicked terminal offer on the other physical exit. A terminal
transition means the preboss was selected and entered, with the ordinary exit
represented as an unpicked companion. On a one-exit predecessor, a generated
batch remains structurally authorable but is invalid because the forced
preboss must occupy the sole exit.

`HubBiome` models a fixed entry sequence, one persistent hub batch, ordered
visits selected from that batch, derived returns to the same physical hub, and
a separate post-visit terminal transition. Its persistent batch and terminal
transition occupy different structural slots and may coexist. Repeated hub
visits never create repeated `N_Hub` controls or cyclic control links.

Every generated target references an existing Room Control, a declared
physical exit, and a unique topology occurrence. The applicable batch rule is
derived from the layout's default continuation rule and any explicit ordered
structural override. Override selectors may inspect topology-visible
structural context, but never lifecycle counters or history. Batch and
transition rule keys are normalized declaration facts, not persisted authored
choices.

Raw topology normalization remains independent of lifecycle history. A
registered contextual batch realization may additionally consume committed
prefix facts to derive non-authored physical offers and the active authored
slots presented by UI and materialization. Draw never performs that
resolution. For I, the shared Clockwork realization is the sole authority for
whether a two-exit continuing batch contains a declined preboss offer.

Contextual realization never overwrites, hides, or silently deactivates an
authored target link. If an upstream edit makes the preboss eligible while an
ordinary target already occupies its forced exit, that target remains visible
and addressable and the batch receives a blocking force finding. The derived
preboss offer appears only when the forced exit has no authored target. This
keeps topology mutation explicit and preserves the rule that eligibility and
force do not rewrite authored choices.

Every supported layout closes through one `PrebossEntry` terminal transition.
That transition references the single terminal Room Control declared by the
layout and interprets the layout's declared terminal exit policy. It may derive
immutable predecessor context such as physical exit count, materialize several
reward realizations of the same terminal room, or carry bounded ordinary
companion targets. It never manufactures duplicate terminal controls.

Room eligibility, force, and caps never mutate topology. They determine the
legality of explicit authored choices and the feedback attached to them.
Context-invalid choices remain representable; only declaration-impossible or
structurally malformed choices are absent or rejected.

## State Ownership

### Biome Plan

The Biome Plan owns:

- its one declared layout association;
- its layout-derived bounded persistence descriptor and reversible
  authored-state codec;
- layout-specific authored topology;
- start selection where the declaration provides alternatives;
- generated batches and parent-to-target links;
- picked flags or ordered visits;
- physical exit indexes;
- batch-authored state;
- terminal-transition presence, structural predecessor relationship, and
  policy-admitted companion target links;
- biome-global authored state;
- topology mutation, structural completeness, and semantic spine addresses.

Outgoing topology never belongs to a target room control.

### Biome Layout Declaration

The Biome Layout Declaration owns immutable structure:

- layout kind;
- start alternatives or fixed entry sequence;
- default continuation rule and explicit structural overrides;
- persistent hub structure where applicable;
- terminal-room membership, terminal-transition rule, and terminal exit
  policy;
- declaration-proven topology bounds.

Start, fixed-entry, and terminal roles are not independently authored booleans
on Room Declarations. A normalized catalog may expose derived role annotations
for efficient lookup, but the layout declaration remains their only authority.

### Room Control

A Room Control owns only facts local to its concrete room:

- its template-specific authored fields;
- its `incomingReward` binding and concrete incoming reward choices;
- phase-owned offer points and their concrete rewards when its encounter
  profile produces rewards inside the room;
- room-local encounter structure when the room type requires it;
- bounded local child slots declared by its template;
- room-local completeness;
- semantic candidates and feedback translation;
- materialization of its room-local canonical fragment.

A control does not know which room generated it, whether another peer was
picked, or which room follows it. The Biome Plan supplies topology context when
calling the control.

### Batch

A batch owns facts that require seeing peers simultaneously:

- peer selection or visit-order state governed by its derived rule;
- duplicate restrictions;
- peer generation order;
- force-pressure occupancy;
- H cage roll or other peer-wide state;
- batch completeness and validation candidates.

Batch state and behavior must not be copied into each child room. The rule key
that selects that behavior comes from the validated layout declaration and
normalized structural context, not authored persistence.

### Terminal Transition

The terminal transition owns the structural fact that a selected continuation
closes at the layout's declared terminal. Its declared exit policy also owns
the association between predecessor exits, the one selected terminal
realization, and any bounded unpicked companion targets. It does not own the
terminal room's shop, free-reward choices, entry mode, or other local authored
state. Those remain on the one terminal Room Control, which receives immutable
predecessor context when materialized. Companion target rewards and local state
remain owned by their referenced Room Controls.

An I generated batch after terminal eligibility is the opposite selected
outcome, not a second terminal-transition shape. Its ordinary target continues
the spine, while the registered Clockwork realization derives the declined
preboss offer. That derived offer owns no terminal shop state and never becomes
a Room Control leaf address.

## Reward Ownership and Timing

The target Room Control owns the authored incoming reward value because the
target room declaration owns `incomingReward`. This lets heterogeneous peers
expose different typed reward interfaces:

```text
F_Story01 / F_Combat06
F_Combat04 / F_MiniBoss02
F_Combat05 / F_Combat11
```

`incomingReward` means the reward contract attached to entering or realizing
the target room. It is not an inventory of every reward the room can produce.
Encounter-generated rewards remain on explicit phase `offerPoint` records.
Consequently O combat rooms declare `incomingReward.kind = "none"` while their
shared `ShipCombat` encounter profile owns both reward wheels.

The Biome Plan does not need to inspect or rewrite internal reward widgets. It
asks each referenced room control for its concrete generated reward fragment.

The reward primitive is the sole owner of its payload domain and normalized
acquisition identity. A producer binding selects behavior, counted stores or a
shop profile, and positive/negative reward filters; it does not redeclare a
fixed primitive's payload domain. Filters may only include concrete reward
types exposed by their referenced stores, and eligible/ineligible filters
cannot overlap. Filtered store combinations do not become new producer kinds.

Domain ownership does not change game timing:

```text
parent room generates batch
  -> every target room reward is offered
  -> every offer affects reward-bag simulation

picked target is entered
  -> its selected offer is acquired when the game acquires it
  -> unpicked target offers are not acquired
```

Independent room-internal choices, such as shops and O wheels, persist their
own offer and acquisition state. An optional encounter's inactive offer point
is dormant and contributes nothing to completeness, materialization, or
history. I Clockwork Goals are acquired and decrement their goal counter when
acquired, not merely when a containing door is generated.

## Dormant Controls

Every supported room control exists whether or not the current topology uses
it. Dormant state is allowed and intentional.

- Linking a dormant control activates its state in the plan.
- Unlinking a control does not automatically erase its local state.
- Dormant controls do not affect completeness or validation.
- Reusing a dormant control restores its previous compatible local state.
- Lib's full module reset determines when dormant persisted state is erased.

This keeps topology editing separate from destructive data reset.

## Completeness, Materialization, and Validation

Completeness and legality are separate and are applied one biome at a time in
route order. Before that semantic walk begins, every configured Biome Plan is
normalized at its topology contact boundary. A malformed configured topology
is an invariant failure even when an earlier biome would later block semantic
processing.

Local completeness asks whether every referenced owner has enough authored
state to materialize:

- the layout-specific topology is structurally closed;
- referenced room controls are complete for their template;
- generated batches have complete peers, exits, selection or visit order, and
  batch state;
- the declared terminal transition is present and structurally complete,
  including every active companion target required by its exit policy;
- biome-global required state is complete;
- every selected continuation reaches the declared terminal under that
  layout's traversal contract.

Only referenced controls participate. A complete biome may still be illegal
under game rules.

Derived physical offers do not add Room Control completeness requirements. A
two-exit I batch with one complete picked ordinary target may be structurally
complete because the shared Clockwork realization fills the other exit with
the fixed declined preboss offer. A one-exit ordinary continuation may also be
structurally complete, then fail semantic force validation because no physical
exit remains for the eligible preboss. A two-exit batch whose forced exit still
contains an authored ordinary target is likewise complete but invalid; the
realization does not replace that target behind the user's back.

An incomplete biome produces completeness feedback but no canonical biome
snapshot and is not validated. A complete biome materializes one canonical
snapshot, appends its lifecycle events to route history, and is then
validated. Only a valid biome allows the next configured biome to be
processed. No execution plan is compiled unless every configured biome passes
this sequence.

Prepared UI structure has a wider horizon than semantic processing. Every
configured biome whose topology normalized successfully receives a prepared
view. Biomes after the first incomplete or invalid one are marked
`blockedByEarlierBiome`; their authored structure remains visible and inactive,
but they produce no local completeness, history, validation, contextual
candidate, or enrichment result.

A narrow committed-prefix projection may run inside the current biome before
full biome completeness. It walks only the complete selected prefix needed to
resolve declaration-deterministic batch shape, stops when required prefix facts
are unknown, and produces no canonical snapshot, validation result, or
downstream-biome history. I uses this projection to decide whether a two-exit
Clockwork decision has one authored ordinary slot plus one derived declined
preboss offer. The same registered realization consumes equivalent prefix facts
during canonical materialization, preventing UI/history rule duplication.

Materialization produces concrete canonical facts:

- the layout kind and concrete structural roles needed for traversal;
- selected physical room sequence;
- every generated peer target;
- every declaration-derived physical offer that does not allocate a Room
  Control occurrence;
- the concrete terminal entry, immutable predecessor context, and any unpicked
  terminal companion targets;
- every generated reward offer;
- selected acquisitions;
- typed room and batch state;
- typed parent-local child state;
- semantic source addresses for feedback.

Validation then checks eligibility, creation and appearance caps, force
pressure, physical exits, counters, reward domains, reward bags, and route
history. It never reaches into storage fields or widgets.

## Lifecycle and Counter Axes

The history model must preserve the game lifecycle:

```text
room.enter
room.prepare_encounters
room.sequence
room.generate_next
room.commit
biome.complete
```

`room.prepare_encounters` resolves the complete phase sequence, including
optional-phase presence and any enabled persistent encounter replacement,
against the pre-sequence counter state. The sequence then emits each
effective phase's events in order. A counting combat phase may therefore emit:

```text
encounter.start and biomeEncounterDepth increment
reward offers and selection at the declared offer timing
combat.complete
selected reward acquisition at the declared acquisition timing
encounter.complete
```

The exact offer and acquisition points belong to the encounter profile. They
must not be recovered later from a room-wide aggregate phase.

The current room generates the next rooms. Every generated target counts as a
creation, including unpicked peers. Only entered rooms count as appearances.

Counters remain distinct:

- `biomeDepthCache` advances with committed room history;
- `biomeEncounterDepth` advances only from resolved encounter phases whose
  effective behavior counts;
- route-wide room-history ordinal supports spacing rules;
- generated-room creation history includes every target;
- reward-offer history includes every offer;
- loot history includes acquired rewards only.

No generic UI row coordinate may substitute for these axes.

## Canonical Plan Boundary

Persisted UI state is not the canonical plan. The canonical plan is rebuilt
from complete controls and topology.

The canonical plan stores concrete game choices, not UI helpers:

- concrete game room keys;
- physical exit indexes;
- concrete effective encounter identities and counter effects;
- concrete reward types and payloads;
- concrete acquisition choices;
- typed room and batch fragments.

It does not store unresolved UI values such as `Major`, `Minor`, `Auto`, or
`Vanilla`. It does not copy declaration facts such as labels, eligibility,
force windows, or exit counts.

Semantic feedback metadata uses stable domain addresses such as route key,
biome-step key, room-control key, parent room-control key, exit index, and
aspect. A local child address adds its parent room-control key and local slot
key. Runtime compilation may discard UI-only return addresses after validation.

## Explicit Non-Goals

The revamp does not model:

- vanilla room-selection probabilities;
- exact identity of a canonicalized unpicked combat map;
- duplicate dynamic control instances for one game room key;
- a retained UI tree separate from the domain topology;
- incomplete canonical plans filled with defaults;
- runtime hooks that reinterpret unresolved authored choices;
- compatibility with the current row/draft persistence shape.
