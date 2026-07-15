# UI and Persistence Model

## Purpose

This document maps the revamp domain to ModpackLib managed state and
immediate-mode ImGui composition.

The central split is:

```text
Static semantic leaves -> Lib controls
Dynamic topology       -> planner-owned Biome Plan objects over Lib storage
Derived route state    -> non-persisted caches rebuilt after commit
```

The UI must not recreate a retained widget tree or a dynamic nested-control
system.

## Lib Contracts

The design relies on these current ModpackLib guarantees:

- control templates and instances are declared before module activation;
- one control bundles a predictable storage schema and typed UI/runtime refs;
- control-generated storage aliases are private;
- controls do not contain independently declared nested controls;
- controls are not layout builders;
- module `data` supports persisted scalar and bounded table storage;
- draw edits staged UI-owned state and Lib commits it after draw;
- runtime reads only committed state;
- normal data and control storage participate in profiles and hashes;
- `ui.resetAll()` resets module data, transient data, control storage, and
  queued status according to Lib lifecycle;
- `module.onCommit(...)` reports whether committed configuration changed.

The revamp should use those contracts directly. It must not access generated
control aliases, flush config during draw, or invent a parallel profile system.

## Physical Composition

### Route Controls

One statically declared Route Control exists per route. It owns stable
route-level authored settings such as configured biome-prefix scope and other
route-global planner inputs. Its configured prefix defaults to empty, which
leaves that route entirely vanilla after fresh profile creation or Lib reset
to defaults.

The active composition supplies the Route Control's current contiguous prefix
domain. A persisted or imported prefix outside that domain is rejected at the
Route Control semantic boundary. It is never clamped, silently shortened, or
allowed to activate a headless biome.

Representative keys:

```text
Underworld
Surface
```

The exact storage fields are defined by the route template. A Route Control
does not serialize all room controls or topology into a private document.

### Room Controls

Every supported top-level concrete room in every route-biome step has one
statically declared Room Control:

```text
Underworld_F_Opening01
Underworld_F_Combat01
Underworld_F_Combat02
...
Surface_Q_PreBoss01
```

The declaration chooses a reusable template. Each instance receives distinct
private Lib storage.

Room controls are the stable semantic interface for:

- local completeness;
- local draw views;
- canonical room/reward fragments;
- candidate export and application;
- feedback translation.

No second logical control instance is created when topology references the
room. The Biome Plan retrieves the already declared control by its stable key.

Encounter phases are addressed through their owning Room Control as
`roomControlKey + phaseKey`. The Room Control materializes the effective phase
into its canonical fragment even when a future route-level persistent entity
selects the replacement. This does not make that cross-room entity private
Room Control storage.

### Local Child Slots

Bounded room-internal children are fields or bounded tables inside the owning
Room Control template. They are not independently declared nested Lib controls.

Examples include:

- H cage reward slots;
- O phase-presence state and phase-derived wheel offer slots;
- N combat-pylon side-door slots.

Explicit children come from the room declaration. Phase-owned offer points
come from the referenced encounter profile and are flattened into the same
Room Control manifest. Each slot has a stable template-local key. The owning
control translates candidate, feedback, and materialization operations for
that slot. No slot becomes an independently registered nested control.

For `ShipCombat`, the Room Control persists the authored presence of optional
`Combat2` plus the offered reward values and picked value for each active
wheel. The declaration bounds each wheel to two offers. `wheel2` state may
remain persisted while `Combat2` is absent, but it is dormant and ignored.
A concrete child game room key may repeat under different parents without
colliding because persistence is scoped by the parent Room Control.

Future NPC assignments are separate persistent route entities because their
identity, uniqueness, spacing, and target movement cross Room Controls. Their
target is a stable encounter-phase address. Disabled assignments remain stored
but dormant; enabled assignments merge into the targeted Room Control fragment
before history is produced. NPC controls and storage are intentionally deferred
and are not part of the current manifest.

### Biome Plans

A Biome Plan is a planner-owned Lua object, not a Lib control.

It is constructed once for one route-biome step with targeted dependencies:

- immutable biome and room declarations;
- the route-biome room-control registry;
- immutable topology and biome-global storage descriptors;
- registered batch-rule implementations;
- materialization/candidate/feedback collaborators.

It owns semantic topology methods and hides storage row details from draw,
validation, and room controls.

The module declares the finite topology storage roots before activation. The
Biome Plan wraps those roots rather than dynamically declaring storage.
Each semantic operation receives the current UI or runtime state-access
surface. The long-lived Biome Plan never caches callback-owned data refs,
control refs, draw services, or ImGui objects.

## Persisted Shape

The semantic topology is a selected tree/spine with dead peer leaves. Physical
storage may normalize it into bounded tables.

Representative semantic roots for one biome step:

```text
BiomeState
Batches
Targets
BatchRuleState
```

Representative rows:

```lua
Batch = {
    parentRoomControlKey = "Underworld_F_Opening02",
    rule = "Standard",
}

Target = {
    parentRoomControlKey = "Underworld_F_Opening02",
    exitIndex = 1,
    roomControlKey = "Underworld_F_Combat03",
    picked = true,
}
```

The exact Lib table schema is an implementation detail, but it must preserve
these contracts:

- topology links use stable room-control keys;
- rows do not duplicate room-local payloads;
- one room-control key appears in at most one target row;
- target ordering or explicit exit index preserves game generation order;
- batch state belongs to its parent/batch key;
- storage has a declaration-proven finite maximum;
- malformed profile rows fail at the Biome Plan construction/materialization
  boundary.

There is no persisted global `PlannerDraft`, occurrence ID allocator, revision
counter, dynamic control schema, or copied canonical document.

## Ownership Matrix

| State | Semantic owner | Physical persistence |
| --- | --- | --- |
| Route prefix and route globals | Route Control | Route-control storage |
| Biome globals | Biome Plan | Module data roots scoped to biome step |
| Generated batches and links | Biome Plan | Module table roots scoped to biome step |
| Picked state / visit order | Biome Plan or batch rule | Module table roots scoped to biome step |
| Room-local fields | Room Control | Room-control private storage |
| Bounded room-internal child state | Parent Room Control | Parent-control private storage |
| Optional encounter presence and phase offers | Parent Room Control | Parent-control private storage |
| Generated target reward | Target Room Control | Room-control private storage |
| Peer-wide batch state | Batch rule | Biome Plan batch-state storage |
| Selected tab/filter/view state | UI composition | Transient module data |
| Materialized canonical plan | Route derived cache | Non-persisted Lua state |
| History and validation result | Route derived cache | Non-persisted Lua state |
| Prepared provider decoration, markers, and status | Route derived cache | Non-persisted Lua state |
| Runtime execution plan | Planner coordinator, read by runtime | Non-persisted published route revision |

## Biome Plan Interface

Representative semantic operations:

```lua
biomePlan:rootRoomControlKey()
biomePlan:batch(parentRoomControlKey)
biomePlan:linkTarget(parentRoomControlKey, exitIndex, roomControlKey)
biomePlan:unlinkTarget(parentRoomControlKey, exitIndex)
biomePlan:setPicked(parentRoomControlKey, exitIndex)
biomePlan:removeDownstream(parentRoomControlKey)
biomePlan:clearTopology()
biomePlan:isComplete(context)
biomePlan:materialize(context)
biomePlan:exportCandidates(out, context)
biomePlan:preparePresentation(findings, out, context)
```

Exact names may change. The invariants do not:

- the Biome Plan is the only topology write boundary;
- it validates the complete mutation before staging writes;
- it maintains injective room-control references;
- replacing or removing a picked link removes downstream topology;
- topology removal does not reset the unlinked room control;
- room controls never write parent/peer topology.

Multi-field edits are semantic operations performed during one draw call. They
must validate their intended final state first and then stage all required Lib
writes before returning.

Read-only traversal, completeness, and materialization operations accept both
UI and runtime state-access surfaces. Topology mutation operations require the
writable UI surface and are not present on `RuntimeStateAccess`.

## Room Control Interface

Templates should expose a small domain-shaped interface split across the
immutable control-instance descriptor and the current Lib UI/runtime refs.
Representative semantic operations are:

```lua
roomControl:isComplete(context)
roomControl:draw(view, context)
roomControl:materialize(context)
roomControl:exportCandidates(out, context)
roomControl:applyCandidate(candidate, context)
roomControl:preparePresentation(findings, out, context)
```

Runtime refs expose committed semantic reads needed for execution-plan
compilation or runtime consumption. They must not expose writable draw refs.
`draw` and `applyCandidate` require the current UI ref. Completeness and
materialization read through the supplied state-access surface, while
`preparePresentation` runs on the immutable descriptor and writes only to its
provided non-persisted output view.

The template owns internal storage-field names. Callers send game-domain
meaning, such as a concrete reward or semantic candidate. They do not select
inner dropdown indexes or write private storage aliases. Presentation
translation is likewise template-owned, but its output is written to the
coordinator's non-persisted route presentation cache rather than into a
callback-owned control ref or persisted control state.

## UI Composition

The draw surface is ordinary immediate-mode Lua composition:

```text
draw route shell
  -> draw selected biome navigation
  -> ask Biome Plan for selected topology
  -> draw parent batch
  -> draw each referenced Room Control
  -> follow picked continuation
```

The draw code threads the current `ui` callback surface through calls. It does
not cache `ui.data`, `ui.controls`, `ui.draw`, or writable refs for runtime use.

Room controls render their own local state. The Biome Plan renderer owns batch
layout, peer grouping, picked affordances, and branch mutation controls.

Declaration-time impossible room options may be omitted. Once the current
biome is complete and contextual validation exists, context-invalid options
remain visible and receive invalid presentation. Before completeness, the
stable declaration-derived domain and completeness presentation are the only
authoritative state. Downstream content after the first blocking invalid may
be grey/inactive. Route status and markers are the common invalid-reporting
path; inline invalid labels are not a second feedback language.

## Candidates and Feedback

Candidate semantics remain in game language.

Room-local candidate address:

```lua
{
    routeKey = "Underworld",
    biomeStepKey = "Underworld_F",
    roomControlKey = "Underworld_F_Combat04",
    aspect = "generatedReward",
}
```

Batch candidate address:

```lua
{
    routeKey = "Underworld",
    biomeStepKey = "Underworld_F",
    parentRoomControlKey = "Underworld_F_Combat02",
    exitIndex = 2,
    aspect = "targetRoom",
}
```

Room-local child address:

```lua
{
    routeKey = "Surface",
    biomeStepKey = "Surface_N",
    roomControlKey = "Surface_N_Combat02",
    localSlotKey = "sideDoor1",
    aspect = "generatedReward",
}
```

Phase-owned offer-point address:

```lua
{
    routeKey = "Surface",
    biomeStepKey = "Surface_O",
    roomControlKey = "Surface_O_Combat04",
    localSlotKey = "wheel2",
    aspect = "pickedReward",
}
```

The profile's phase key remains descriptor metadata used for lifecycle
materialization; persisted and presentation ownership still resolves through
the parent Room Control and stable offer-point key.

Feedback resolution during the committed rebuild is direct:

```text
biomeStepKey
  -> Biome Plan
      -> roomControlKey or parent batch
          -> semantic provider/component
```

There is no mapping from game room keys to dynamic occurrence rows. The room
template, local-slot descriptor, or batch descriptor is already the semantic
presentation translator for its owner address.

Providers use stable candidate arrays. Validation rebuilds mutable visibility,
color, and message arrays only when committed route state changes. The
coordinator stores the translated per-owner views in the route-derived cache;
feedback preparation never requires a live UI ref, widget alias lookup, or
storage-row arithmetic.

## Profiles, Commit, and Derived State

Lib profiles and hashes include normal module data and control storage. The
revamp does not serialize a second planner document.

One commit publication cycle is:

1. draw reads staged authored values and the last published prepared view;
2. draw stages semantic edits through UI-only refs and returns;
3. Lib commits dirty state;
4. `module.onCommit(...)` observes `hadConfigChanges()`, advances the
   coordinator's non-persisted authored revision, and reads that one coherent
   committed revision; the prior execution plan is now ineligible by revision;
5. the planner walks configured biomes in order through completeness,
   materialization, history, and validation;
6. semantic findings are translated by their room-template, local-slot, or
   batch descriptors into a fresh non-persisted presentation cache;
7. the planner compiles a complete execution plan or explicitly clears it;
8. presentation, canonical/history/validation, and execution results are
   atomically published as one derived revision tagged with its source authored
   revision.

Draw must not flush config, rebuild derived state, apply feedback, or publish
half-edited canonical plans. One draw call consumes one published prepared view
without trying to revise feedback after a widget stages an edit. The edit frame
may therefore display the prior committed presentation. `onCommit` rebuilds and
publishes before the next draw, so same-frame feedback is not a contract.

If rebuilding the new authored revision hits a contract failure, the failure
remains loud and no execution plan matches the current authored revision. The
planner must not retain or reactivate the previous plan, clamp malformed input,
or translate the failure into ordinary user-invalid feedback.

Profile load, profile reset, hash import, and explicit configuration reload
must all run the same rebuild-and-publication lifecycle as a normal committed
change. Module initialization publishes the default empty-prefix revision by
the same path. The lifecycle signal and derived revision are not persisted.

## Topology Clearing and Reset

Topology editing and full persisted reset are different operations.

`unlink target`
: Removes the topology link and downstream branch. It preserves the now-dormant
  room control's local state.

`clear biome topology`
: Clears that Biome Plan's topology and biome-global state. Room controls are
  preserved and become dormant when no longer referenced.

`reset to defaults`
: Uses Lib's full module reset lifecycle. It resets all persisted module data
  and every control instance, including dormant Room Controls.

The planner does not recursively reset leaf controls when topology is unlinked
or cleared. Dormant leaf state has no derived effect, and preserving it keeps
topology editing non-destructive. There are no separate room, biome, or route
leaf-reset contracts for planner composition to implement.

## Draw and Rebuild Performance

Draw is a hot path. The revamp uses one commit-rebuild boundary:

```text
committed authored change
  -> process complete biomes in route order
  -> materialize, append history, and validate each biome once
  -> stop at the first incomplete or invalid biome
  -> translate findings into a fresh prepared presentation cache
  -> compile or clear the execution plan
  -> atomically publish one derived revision
  -> draw authored values plus that prepared view until next commit
```

Required practices:

- cache immutable room-control descriptors and stable keys, then resolve the
  current callback's refs through its state-access surface;
- cache declaration-derived topology keys and index metadata;
- pass the current callback state-access surface into semantic operations;
- reuse option/value/label arrays;
- mutate prepared color/visibility/message arrays only in an unpublished build
  buffer;
- never mutate the currently published presentation revision; reusable buffers
  become writable again only after they are no longer published;
- keep static draw option tables module-local and caller-owned;
- avoid string concatenation and inline tables in room/batch draw loops;
- do not deep-copy the full topology each frame;
- do not run history or validation during draw;
- do not apply findings or mutate prepared presentation during draw;
- do not introduce a retained UI layer for layout.

## Explicitly Rejected Designs

Do not rebuild:

- one global root draft that owns every route, topology row, and payload;
- occurrence IDs separate from room controls;
- multiple logical control instances for one concrete room control;
- reward vessels for unpicked combat rooms;
- dynamic nested Lib controls;
- topology stored inside target Room Controls;
- direct writes to private control storage aliases;
- validation that knows widget IDs or table-row positions;
- custom persistence, profile, commit, or config-flush machinery;
- permanent compatibility adapters for the current implementation.
