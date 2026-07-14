# Run Planner Domain Model

## Purpose

This document defines the semantic model of the revamp. It deliberately avoids
ModpackLib APIs, storage aliases, ImGui composition, and runtime hook details.

The model is built around a finite, statically known room universe and a small
dynamic topology:

```text
Route Plan
  -> ordered Biome Plans
      -> generated batches owned by entered rooms
          -> unique concrete Room Controls
              -> room-local authored state and rewards
```

The planner is prescriptive. It constructs one concrete legal route and all
reward offers generated beside that route. It is not a probability simulator
or an exact recorder of every vanilla room-picker outcome.

## Planner Validity Domain

Production requirements are hand-authored and classified before entering
planner validation:

`modeled`
: The route plan and its derived history contain the state needed to evaluate
  the predicate. It participates in eligibility and validation.

`outOfScope`
: The predicate is a known dependency on save progression or another system
  the planner deliberately does not model. It is retained as audit metadata
  but has no effect on planner validity.

A route-relevant predicate without a registered evaluator, an unknown
predicate, or an unclassified predicate is a declaration contract failure and
prevents catalog construction. `unsupported` may appear in design notes or
implementation tracking, but it is not a production catalog classification,
validator status, or feedback state. `outOfScope` is never an implicit
fallback for unfinished planner support.

Current out-of-scope families include prior-run/save story progression,
unlocks and world upgrades, active bounty overrides, current trait/aspect/
familiar state, and prior-run encounter completion.

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
: The topology and biome-global authored state for one route-biome step. It is
  the only owner of generated batches, target links, picked state, and
  biome-specific structural decisions.

`Room Declaration`
: Verified game data for one concrete game room key such as `F_Combat04`. It
  owns type, tags, eligibility, force, caps, exits, encounter profile, and
  reward surface facts.

`Room Template`
: Reusable typed behavior such as `StandardCombat`, `FieldsCombat`,
  `ShipCombat`, `ClockworkCombat`, `Story`, `Shop`, or `Preboss`. A template
  defines the authored schema and semantic interface shared by room controls
  of that type.

`Room Control`
: One statically materialized instance for one top-level concrete room
  declaration in one biome step. It owns room-local authored persistence,
  completeness, candidate translation, feedback translation, and canonical
  fragments.

`Local Child Slot`
: One statically declared semantic child inside a Room Control, identified by
  its parent control and declaration-local slot key. It models bounded
  room-internal structures such as H cages, O encounters, and N side doors.

`Generated Batch`
: The complete set of rooms generated together from a source room. It owns
  physical exit association, peer membership, picked state, batch rules, and
  batch-authored state.

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

### Local Child Identity

A bounded room-internal child is addressed through its owning control:

```text
parentRoomControlKey + localSlotKey
```

The slot may carry a concrete game room or reward key as data. The same child
game room key may appear in slots owned by different parent controls. This is
required for N side rooms, where one `N_SubXX` declaration can be predetermined
behind physical doors in several different pylon maps.

Child slots do not participate in the top-level control registry or Biome Plan
link table. Their parent template owns their storage, completeness, candidates,
feedback translation, and materialization.

### Injective Topology References

Within one Biome Plan, one top-level room control may be referenced by at most
one generated target. The topology-to-control mapping is injective:

```text
one generated target -> one room control
one room control      -> zero or one generated targets
```

This rule has three sources:

1. structural rooms such as openings and terminals are singletons;
2. rooms with `MaxCreationsThisRun = 1` are creation-unique in the game;
3. ordinary combat rooms are made creation-unique by planner policy even
   though vanilla permits repeated generation before entry.

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
replacement must preserve the template, reward surface, physical-exit and
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

The Route Plan owns:

- stable route identity and configured prefix;
- route-global authored inputs;
- ordered Biome Plan composition;
- cross-biome materialization and validation orchestration;
- route-wide derived caches.

It does not own room-local payloads or duplicate biome topology inside one root
document.

After committed authored state changes, route orchestration derives and
atomically publishes one coherent revision containing the processed biome
snapshots, history, validation result, prepared presentation state, and either
a complete execution plan or no execution plan. None of that derived revision
is persisted authored state.

Every derived revision records the authored configuration revision from which
it was built. Runtime may consume an execution plan only while that source
revision still matches the current committed authored revision. A committed
change therefore makes the previous execution plan unusable before the
replacement rebuild succeeds or fails.

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
    rewardSurface = "RunProgressMinorMajor",
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

The Biome Plan stores links between room controls. A representative ordinary
shape is:

```lua
biomePlan = {
    biomeStepKey = "Underworld_F",
    rootRoomControlKey = "Underworld_F_Opening02",
    batches = {
        {
            parentRoomControlKey = "Underworld_F_Opening02",
            rule = "Standard",
            targets = {
                {
                    exitIndex = 1,
                    roomControlKey = "Underworld_F_Combat03",
                    picked = true,
                },
                {
                    exitIndex = 2,
                    roomControlKey = "Underworld_F_Combat06",
                    picked = false,
                },
            },
        },
    },
}
```

For an ordinary batch:

- every target references one existing room control;
- target room controls are distinct within the entire Biome Plan;
- targets reference declared physical exits by index;
- exactly one target is picked;
- the picked target is the next entered room;
- only the picked target may own the next outgoing batch;
- unpicked targets are dead leaves;
- terminal rooms own no outgoing batch.

The selected biome path is derived by starting at the root and repeatedly
following the picked target. There is no independent entered-room list that
can disagree with batch selection.

Biome-specific batch rules may replace `exactly one picked` with a richer
selection rule, but they must retain explicit ownership and deterministic
materialization. N hub visit order, H cage batches, and Q deterministic sets
are extensions, not exceptions hidden in the generic walker.

Cycles are not represented by linking a room control to itself. A biome such
as N that revisits a physical hub models hub traversal as biome-owned structure
and ordered visits. It does not create repeated `N_Hub` controls.

## State Ownership

### Biome Plan

The Biome Plan owns:

- root selection;
- outgoing batches;
- parent-to-target links;
- picked flags or specialized selection order;
- physical exit indexes;
- peer-level batch rules;
- batch-authored state;
- biome-global authored state;
- topology mutation and structural completeness.

Outgoing topology never belongs to a target room control.

### Room Control

A Room Control owns only facts local to its concrete room:

- its template-specific authored fields;
- its generated/entered reward surface and concrete reward choices;
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

- selection rule;
- duplicate restrictions;
- peer generation order;
- force-pressure occupancy;
- H cage roll or other peer-wide state;
- batch completeness and validation candidates.

Batch rules must not be copied into each child room.

## Reward Ownership and Timing

The target Room Control owns the authored reward value because the target room
declaration owns the reward surface. This lets heterogeneous peers expose
different typed reward interfaces:

```text
F_Story01 / F_Combat06
F_Combat04 / F_MiniBoss02
F_Combat05 / F_Combat11
```

The Biome Plan does not need to inspect or rewrite internal reward widgets. It
asks each referenced room control for its concrete generated reward fragment.

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
own acquisition state. I Clockwork Goals are acquired and decrement their goal
counter when acquired, not merely when a containing door is generated.

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
route order.

Local completeness asks whether every referenced owner has enough authored
state to materialize:

- referenced room controls are complete for their template;
- batches have complete peers, exits, selection, and batch state;
- biome-global required state is complete;
- the selected continuation reaches a declared terminal.

Only referenced controls participate. A complete biome may still be illegal
under game rules.

An incomplete biome produces completeness feedback but no canonical biome
snapshot and is not validated. A complete biome materializes one canonical
snapshot, appends its lifecycle events to route history, and is then
validated. Only a valid biome allows the next configured biome to be
processed. No execution plan is compiled unless every configured biome passes
this sequence.

Materialization produces concrete canonical facts:

- selected physical room sequence;
- every generated peer target;
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
room.encounters
room.offer_points
room.generate_next
room.commit
biome.complete
```

The current room generates the next rooms. Every generated target counts as a
creation, including unpicked peers. Only entered rooms count as appearances.

Counters remain distinct:

- `biomeDepthCache` advances with committed room history;
- `biomeEncounterDepth` advances with counting encounters;
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
