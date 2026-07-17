# UI and Persistence Model

## Purpose

This document maps the revamp domain to ModpackLib managed state and
immediate-mode ImGui composition.

`UI_EDITOR_MODEL.md` is the focused authority for the authored editor built on
these contracts. It defines the Biome Plan persistence codec, published
authored view, semantic topology widgets, unique-room identity invariant, and
spine-feedback resolution. This document retains authority over the broader
Lib, profile, reset, state-access, and final derived-publication lifecycle.

The central split is:

```text
Static semantic leaves -> Lib controls
Authored topology      -> layout-specific state behind common Biome Plans
Prepared layout views  -> layout-specific UI projectors
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

Implementation support supplies the Route Control's current contiguous prefix
domain through `maximumEditablePrefix`. A persisted or imported prefix outside
that domain is rejected at the Route Control semantic boundary. It is never
clamped or silently shortened.

Editability and full planner activation are separate. An `authoredEditor`
biome may enter the configured prefix before materialization or the headless
pipeline exists; its authored view is useful but it produces no execution
plan. `maximumActivePrefix` separately records the contiguous prefix whose
authored editor and headless semantic pipeline have been integrated and probed.

Shrinking configured scope never clears excluded Biome Plan or Room Control
persistence. Those values become dormant and return unchanged if the prefix is
expanded again.

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

- the immutable biome layout declaration and room declarations;
- the route-biome room-control registry;
- the registered topology-layout implementation;
- registered batch-rule implementations;

It owns the layout-derived bounded persistence descriptor, the reversible
codec between physical Lib roots and semantic authored choices, and the
semantic topology methods. It hides physical storage details from draw,
validation, and room controls.

The registered topology-layout implementation derives the finite topology
storage roots and codec from the validated layout bounds. The Biome Plan
declares those roots during system composition, and the module manifest merely
collects them before activation. The plan never dynamically declares storage.

Each semantic operation uses a short-lived plan ref bound to the current UI or
runtime state-access surface. The long-lived Biome Plan never caches
callback-owned data refs, control refs, draw services, or ImGui objects.

Topology, history, and UI behavior are registered separately under the shared
layout-kind key:

```text
topologyLayouts[layoutKind]
historyLayouts[layoutKind]
uiLayouts[layoutKind]
```

The Biome Plan receives only its topology implementation. The common canonical
materializer, history coordinator, and UI preparation coordinator receive their
own registries through system composition; the Biome Plan is not a shared
behavior container for all three layers.

## Persisted Shape

There is no universal physical topology schema. Each registered layout kind
provides the finite descriptor and reversible authored-state codec used by its
Biome Plan before module activation. The module-level storage manifest collects
those plan-owned roots; state access does not interpret `LinearBiome` or
`HubBiome` physical layouts. Each plan translates its authored state into a
normalized semantic topology.

### `LinearBiome` Authored State

Representative semantic state:

```lua
LinearBiomeAuthoredState = {
    selectedStartRoomControlKey = "Underworld_F_Opening02",

    batches = {
        {
            parentRoomControlKey = "Underworld_F_Opening02",
        },
    },

    targets = {
        {
            parentRoomControlKey = "Underworld_F_Opening02",
            exitIndex = 1,
            roomControlKey = "Underworld_F_Combat03",
            picked = true,
        },
    },

    terminalTransition = {
        parentRoomControlKey = "Underworld_F_Combat17",
    },
}
```

A fixed start is declaration-derived and consumes no persisted choice. A
`oneOf` start persists the selected Room Control key and defaults to
unselected. Authored state persists batch and transition presence, structural
links, selection, and batch-authored values. It does not persist batch-rule,
continuation-override, terminal-room, or transition-rule keys; normalization
derives them from the validated layout declaration.

The terminal-transition semantic state above is fixed. Its physical Lib
encoding may be a dedicated bounded root or a tagged bounded continuation
record, provided the layout reader returns the same semantic topology and no
consumer can observe the encoding.

When the declared terminal exit policy is `terminalWithCompanions`, the same
transition record additionally owns bounded ordinary target links for every
nonterminal predecessor exit:

```lua
terminalTransition = {
    parentRoomControlKey = "Underworld_I_Combat12",
    companionTargets = {
        {
            exitIndex = 2,
            roomControlKey = "Underworld_I_Combat17",
        },
    },
}
```

The terminal exit is the first active physical exit in declaration generation
order and is derived rather than persisted. Companion links carry no `picked`
field: the terminal is selected and every companion is an unpicked dead leaf.
I predecessors admit at most one companion. Layout target bounds include these
links even though they do not belong to an ordinary continuing batch.

This terminal record represents I's entered-preboss outcome only. When an
eligible preboss is declined on a two-exit predecessor, authored persistence
uses an ordinary generated batch with the remaining ordinary target selected:

```lua
batches = {
    { parentRoomControlKey = "Underworld_I_Combat12" },
}

targets = {
    {
        parentRoomControlKey = "Underworld_I_Combat12",
        exitIndex = 2,
        roomControlKey = "Underworld_I_Combat17",
        picked = true,
    },
}
```

There is no persisted terminal-offer flag, duplicate terminal target, or
second preboss control reference. The registered Clockwork batch realization
uses committed prefix facts and the terminal declaration to derive the
unpicked `I_PreBoss02` offer on exit 1. On a one-exit predecessor, an ordinary
batch target may remain structurally authored and picked, but validation
rejects it once the forced preboss is eligible because both outcomes cannot
occupy the sole physical exit. Derived offers do not consume authored target
capacity even though canonical history processes their physical creation and
incoming offer.

An upstream edit may make the preboss eligible after an ordinary target was
already persisted on exit 1. The committed projection must retain and display
that target as a context-invalid authored link; it must not hide, clear, or
reinterpret it as dormant capacity. The validator reports the missing forced
preboss at the physical slot. Once the user explicitly removes the conflicting
target, the same empty exit projects the derived read-only preboss offer. Room
Control persistence survives either topology edit.

### `HubBiome` Authored State

Representative semantic state:

```lua
HubBiomeAuthoredState = {
    hubDoorCount = 10,

    hubTargets = {
        {
            doorIndex = 1,
            roomControlKey = "Surface_N_Combat01",
            visitOrder = 3,
        },
        {
            doorIndex = 2,
            roomControlKey = "Surface_N_Combat02",
            visitOrder = 0,
        },
    },

    terminalTransition = true,
}
```

`visitOrder = 0` means generated but unvisited. Positive values are unique and
form `1..6` in a complete N topology. The fixed entry sequence, hub room,
batch rule, visited-target count, and terminal room are declaration-derived.
Hub returns are derived and never persisted as repeated rooms or cycles.

### Normalized Topology Boundary

A state-bound Biome Plan ref decodes the relevant authored state and returns
one normalized variant:

```text
LinearBiomeTopology
HubBiomeTopology
```

This is not a canonical snapshot. It contains structural references, authored
layout state, and declaration-derived dispatch facts, but no materialized Room
Control fragments, history counters, findings, widgets, or presentation.

Normalization may attach `continuationOverrideKey`, `batchRuleKey`, immutable
rule configuration, `transitionRuleKey`, terminal exit policy, and companion
batch-rule configuration for downstream dispatch. Those facts never become raw
persistence.

The topology contact boundary rejects malformed persisted state such as:

- unknown, cross-route, or cross-biome Room Control keys;
- duplicate control use where the layout requires injectivity;
- duplicate physical exit or hub-door indexes;
- target or batch counts outside declared bounds;
- contradictory batch selection or visit-order state;
- downstream structure owned by an unselected dead leaf;
- a terminal transition with an unknown or unselected predecessor;
- missing, excess, picked, or exit-incompatible terminal companion targets;
- a selected linear source with both a generated batch and terminal
  transition;
- state not admitted by the registered layout kind.

Incomplete but well-formed authored state remains readable. Examples include
an unselected `oneOf` start, a missing target, a batch without a picked target,
fewer than six N visits, or a selected nonterminal continuation with no next
batch or terminal transition.

Every physical descriptor must preserve stable Room Control keys, physical
exit or hub-door order, parent-owned batch state, and declaration-proven finite
bounds. It must not duplicate Room Control payloads or canonical materialized
data.

There is no persisted global `PlannerDraft`, occurrence ID allocator, revision
counter, dynamic control schema, or copied canonical document.

## Ownership Matrix

| State | Semantic owner | Physical persistence |
| --- | --- | --- |
| Route prefix and route globals | Route Control | Route-control storage |
| Layout kind and structural roles | Biome Layout Declaration | Immutable catalog data; not persisted |
| Biome globals | Biome Plan | Layout-specific module roots scoped to biome step |
| Generated batches, terminal transitions, companion targets, and links | Biome Plan | Layout-specific bounded module storage |
| Picked state / visit order | Biome Plan | Layout-specific bounded module storage |
| Batch and transition dispatch keys | Biome Layout Declaration and normalized topology | Derived; not persisted |
| Context-forced declined terminal offer | Biome Layout Declaration plus registered batch realization | Derived; not persisted and no Room Control claim |
| Room-local fields | Room Control | Room-control private storage |
| Bounded room-internal child state | Parent Room Control | Parent-control private storage |
| Optional encounter presence and phase offers | Parent Room Control | Parent-control private storage |
| Generated target reward | Target Room Control | Room-control private storage |
| Terminal entry mode, shop state, and free-reward slots | Terminal Room Control | Room-control private storage |
| Peer-wide authored batch state | Generated batch governed by its batch rule | Layout-specific batch storage |
| Selected tab/filter/view state | UI composition | Transient module data |
| Materialized canonical plan | Route derived cache | Non-persisted Lua state |
| History and validation result | Route derived cache | Non-persisted Lua state |
| Prepared provider decoration, markers, and status | Route derived cache | Non-persisted Lua state |
| Runtime execution plan | Planner coordinator, read by runtime | Non-persisted published route result |

## Biome Plan Interface

Representative semantic operations:

```lua
biomePlan:storage()
runtimePlan = biomePlan:bind(runtimeStateAccess)
uiPlan = biomePlan:bind(uiStateAccess)
runtimePlan:readAuthored()
runtimePlan:readTopology()
biomePlan:checkStructure(topology)
uiPlan:apply(command)
biomePlan:traverse(topology, visitor)
biomePlan:semanticAddress(subject)
uiPlan:clearTopology()
```

Exact names may change. The invariants do not:

- the Biome Plan is the only topology write boundary;
- its selected layout implementation owns one reversible persistence codec;
- its declared storage capacity derives from the validated layout bounds;
- the registered topology-layout implementation interprets every operation;
- it validates the complete mutation before staging writes;
- it maintains injective room-control references;
- changing a start, selected continuation, or continuation form removes the
  incompatible downstream topology;
- topology removal does not reset the unlinked room control;
- room controls never write parent/peer topology.

The Biome Plan does not materialize canonical snapshots, build history, or
prepare UI views. The common materializer and registered history/UI consumers
use its normalized traversal and semantic addresses through their own
composition roots.

Multi-field edits are semantic commands performed during one draw call. A
command reads current topology, constructs and validates the full proposed
replacement in unpublished Lua state, and only then stages every required Lib
write. Callers never manipulate bounded storage records directly.

Read-only plan refs can bind either the UI or runtime state-access surface.
Topology mutation operations exist only on the UI-bound ref and are absent
from the runtime-bound ref.

### `LinearBiome` Commands

Representative commands are:

```lua
{ kind = "SelectStart", roomControlKey = ... }
{ kind = "CreateBatch", parentRoomControlKey = ... }
{ kind = "SetTarget", parentRoomControlKey = ..., exitIndex = ..., roomControlKey = ... }
{ kind = "SetPicked", parentRoomControlKey = ..., exitIndex = ... }
{ kind = "RemoveBatch", parentRoomControlKey = ... }
{ kind = "CreateTerminalTransition", parentRoomControlKey = ... }
{ kind = "SetTerminalCompanion", exitIndex = ..., roomControlKey = ... }
{ kind = "RemoveTerminalTransition" }
{ kind = "ReplaceWithBatch", parentRoomControlKey = ... }
{ kind = "ReplaceWithTerminalTransition", parentRoomControlKey = ... }
{ kind = "ClearTopology" }
```

`SetTarget` and `SetTerminalCompanion` own both the initial
`unspecified -> specified` transition and atomic replacement. Once specified,
a physical target cannot return to an empty authored value. It can only be
replaced by another Room Control or removed as part of deleting/replacing its
complete decision or topology. Selector sentinels never become target-deletion
commands.

Changing a selected start clears topology under the previous start. Changing
the picked target clears topology under the former selected continuation and
leaves the new continuation incomplete. Room Control persistence remains
untouched.

`CreateBatch` and `CreateTerminalTransition` reject a source that already owns
the opposite continuation form. The two `ReplaceWith...` commands are the
explicit atomic operations that remove one form and install the other. Force,
eligibility, normalization, and validation never invoke these mutations.

For I, these existing continuation commands also encode the selected outcome.
`CreateTerminalTransition` means the offered preboss was selected and entered;
a completed `CreateBatch` outcome means an ordinary room was selected. Once
the preboss is eligible, the two-exit batch projection derives its unpicked
offer without a third command or persisted topology record. The one-exit batch
alternative is allowed through the structural command boundary and rejected
later by game validation.

The explicit `ReplaceWith...` operations preserve the compatible ordinary
exit when switching a clean two-exit I outcome. Replacing the generated batch
with the terminal transition converts the picked ordinary target into the
unpicked companion and clears downstream topology from it. Replacing the
terminal transition with a generated batch converts that companion into the
picked continuing target and derives the declined preboss offer. Any authored
target occupying the terminal exit is removed only as part of this explicit
replacement command, never by publication or validation.

Terminal-companion commands exist only when the layout declaration admits
them. They specify or replace links inside the terminal transition, never
create a second continuing batch, and reject the derived terminal exit.
Removing the terminal transition removes its companion links but does not
reset their Room Control persistence.

### `HubBiome` Commands

Representative commands are:

```lua
{ kind = "SetHubDoorCount", count = 9 }
{ kind = "SetHubTarget", doorIndex = ..., roomControlKey = ... }
{ kind = "SetVisitOrder", doorIndex = ..., visitOrder = ... }
{ kind = "ClearHubTarget", doorIndex = ... }
{ kind = "CreateTerminalTransition" }
{ kind = "RemoveTerminalTransition" }
{ kind = "ClearTopology" }
```

These are commands of the `HubBiome` implementation, not conditional cases in
the linear command handler. Its persistent hub batch and separate post-visit
terminal transition may coexist.

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

### Structural and leaf lifecycles

Topology and leaf state intentionally use different edit lifecycles:

```text
topology target
  unspecified -> specified -> replaced
                           -> removed with its owning decision or topology

active leaf value
  declaration default -> replaced -> replaced ...
```

An unused bounded topology slot represents absent structure and therefore
cannot receive a meaningful static default. Creating a decision does not pick
the first currently eligible room: eligibility and candidate availability are
route-context facts, and creation must not perform hidden planning.

A Room Control leaf has a declaration-bounded value domain. Every focused
template therefore supplies a complete deterministic default for each active
leaf value. Defaults compose from the semantic authority that owns the choice:
reward primitives own complete payload defaults, bags own their default primitive,
multi-store bindings own their default store and any required primitive
override, shop slots own their default primitive, and structural wrappers own
their mode defaults. Option ordering is never default authority.

Leaf editors expose atomic replacement, not clearing. Replacing a counted
store also selects that store's declared default primitive; replacing a
primitive also installs its declared complete payload. Payload fields reserved
for another primitive and reward slots outside active capacity remain persisted
and dormant. No intermediate empty reward is committed. Removing topology does
not reset a Room Control, while Lib reset restores every leaf's declaration
defaults.

## UI Composition

`UI_EDITOR_MODEL.md` owns the concrete authored projection, transient selector,
semantic-command, and referenced-leaf draw contracts summarized here.

UI projectors are registered separately from topology implementations. During
the committed rebuild, `uiLayouts[layoutKind]` combines normalized topology,
committed-prefix structural facts, owner-keyed candidate state, owner-keyed
feedback, and `processingState` into a prepared biome view. One view is
prepared for every configured biome after all configured topology has passed
normalization, including inactive views beyond the semantic processing
horizon. Draw is then ordinary immediate-mode Lua composition:

```text
draw route shell
  -> draw selected biome navigation
  -> consume the published prepared biome view
  -> draw layout-owned structure
  -> draw referenced Room Controls through current UI refs
  -> stage semantic commands for user edits
```

The draw code threads the current `ui` callback surface through calls. It does
not cache `ui.data`, `ui.controls`, `ui.draw`, or writable refs for runtime use.

The `LinearBiome` projector may present a starting section, one decision row
per generated batch on the selected path, and a terminal section. That
terminal section also presents any layout-owned unpicked companion targets and
their Room Controls. For I, committed prefix facts also shape a generated
batch's presentation after the preboss becomes eligible. A two-exit `Add Next
Decision` view presents the derived preboss exit as read-only and exposes only
the picked ordinary room for configuration; `Go to Preboss` presents the
entered terminal control and any ordinary companion. A one-exit `Add Next
Decision` retains its ordinary target editor so a complete but invalid outcome
can reach the validator. No declined preboss view draws the terminal Room
Control. The
`HubBiome` projector may present a fixed-entry summary, physical hub-door grid,
ordered visit list, visited pylon panels, and terminal section. UI rows, cards,
columns, and display ordinals are transient presentation only and never become
topology identity or gameplay counters.

Room Controls render their own local state. The layout projector owns
structural grouping, peer/visit affordances, and placement of owner-keyed
presentation. The Biome Plan itself is not a renderer. Draw never builds
canonical snapshots, history, validation, or topology projection.

Declaration-time impossible room options may be omitted. Once the current
biome is complete and contextual validation exists, context-invalid options
remain visible and receive invalid presentation. Before completeness, the
stable declaration-derived domain and completeness presentation are the only
authoritative validity state.

Context-dependent batch shape is separate from contextual validity. During
committed publication, a narrow prefix projection may resolve deterministic
physical slots from the complete selected prefix even while the biome remains
incomplete. If required prefix facts are incomplete, the projector retains the
declaration-bounded ordinary slots and completeness blocks progress; draw never
guesses. I uses this mechanism to reserve the first exit of an eligible
two-exit Clockwork batch for the derived declined preboss offer when that exit
has no conflicting authored target. A conflicting target remains visible and
invalid until an explicit semantic command removes or replaces the surrounding
topology. Downstream
content after the first incomplete or blocking invalid biome is grey/inactive
and marked `blockedByEarlierBiome` rather than receiving invented local
findings. Route status and markers are the common
invalid-reporting path; inline invalid labels are not a second feedback
language.

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

Hub target address:

```lua
{
    routeKey = "Surface",
    biomeStepKey = "Surface_N",
    batchKey = "hubDoors",
    doorIndex = 4,
    aspect = "targetRoom",
}
```

Terminal-transition address:

```lua
{
    routeKey = "Underworld",
    biomeStepKey = "Underworld_F",
    parentRoomControlKey = "Underworld_F_Combat17",
    transitionKey = "prebossEntry",
    aspect = "continuation",
}
```

Terminal companion address:

```lua
{
    routeKey = "Underworld",
    biomeStepKey = "Underworld_I",
    parentRoomControlKey = "Underworld_I_Combat12",
    transitionKey = "prebossEntry",
    exitIndex = 2,
    aspect = "companionTargetRoom",
}
```

Terminal Room Control entry-mode address:

```lua
{
    routeKey = "Underworld",
    biomeStepKey = "Underworld_F",
    roomControlKey = "Underworld_F_PreBoss01",
    aspect = "entryMode",
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
  -> semantic owner address
      -> Room Control/local-slot translator
      or layout batch/visit/terminal translator
          -> owner-keyed presentation
              -> layout-specific prepared UI view
```

There is no mapping from game room keys to dynamic occurrence rows. The Room
Control template, local-slot descriptor, or layout-owned structural descriptor
is already the semantic translator for its owner address. The UI projector
decides where that translated state appears without changing the address.

Injective top-level Room Control use makes the Room Control key the occurrence
identity for every existing leaf. A batch is identified by its unique parent
Room Control key, while an empty or populated physical target slot is
identified by parent key plus exit index. The prepared UI owner index uses
those semantic addresses directly; it never scans persisted or rendered rows
to recover a finding destination.

Providers use stable declaration-derived candidate arrays. Context-invalid
values remain present and receive mutable validity, color, and message state;
only declaration-impossible values are absent. Before biome completeness,
providers expose the stable domain and owner-keyed completeness presentation,
not authoritative contextual validity. The coordinator stores translated
per-owner views in the route-derived cache; feedback preparation never
requires a live UI ref, widget alias lookup, or storage-position arithmetic.

Applying a structural candidate produces a semantic Biome Plan command.
Applying a room-local candidate calls the owning Room Control's semantic
interface. Neither path writes dropdown indexes, private aliases, or bounded
table records directly.

## Profiles, Commit, and Derived State

Lib profiles and hashes include normal module data and control storage. The
revamp does not serialize a second planner document.

One commit publication cycle is:

1. draw reads staged authored values and the last published prepared view;
2. draw stages semantic edits through UI-only refs and returns;
3. Lib commits dirty state;
4. `module.onCommit(...)` observes `hadConfigChanges()` and reads one coherent
   committed authored state;
5. the planner normalizes every configured biome topology, failing loudly if
   any configured structure violates its contact-boundary contract;
6. the planner walks those normalized biomes in order through completeness,
   materialization, history, and validation until the first blocker;
7. semantic findings are translated by their Room Control, local-slot, or
   layout-structural descriptors into owner-keyed presentation;
8. `uiLayouts[layoutKind]` projects normalized topology, owner presentation,
   and derived `processingState` into one fresh non-persisted view for every
   configured biome;
9. the planner compiles a complete execution plan or leaves it absent;
10. prepared views, canonical/history/validation, and execution results are
   atomically published as one derived result.

Configured biomes after the first incomplete or invalid biome receive
`processingState = "blockedByEarlierBiome"`. Their normalized authored rows
remain visible but inactive, with stable declaration-derived value domains and
without local completeness findings, contextual candidate validity, or
enrichment. `processingState` is presentation-only and is never persisted.

Draw must not flush config, rebuild derived state, apply feedback, or publish
half-edited canonical plans. One draw call consumes one published prepared view
without trying to revise feedback after a widget stages an edit. The edit frame
may therefore display the prior committed presentation. `onCommit` rebuilds and
publishes before the next draw, so same-frame feedback is not a contract.

If rebuilding the committed authored state hits a contract failure, the failure
remains loud and the coordinator clears the previously published result before
surfacing it. The planner must not retain or reactivate the previous plan, clamp
malformed input, or translate the failure into ordinary user-invalid feedback.

Profile load, profile reset, hash import, and explicit configuration reload
must all run the same rebuild-and-publication lifecycle as a normal committed
change. Module initialization publishes the default empty-prefix result by the
same path. Derived state is not persisted.

Before the headless coordinator exists, Checkpoint 4A runs the authored subset
of that lifecycle for every configured biome: normalization, structural and
local completeness, UI projection, and atomic publication. Once the headless
coordinator exists, every biome through `maximumEditablePrefix` must also have
headless support before the full semantic lifecycle processes configured
state.

Lib commit and reload remain distinct lifecycle events. The coordinator calls
the same synchronous rebuild function directly from `onActivate`, a
configuration-changing `onCommit`, and a setting-changing `onReload`. A no-op
commit or reload, including the follow-up reload after a hash/profile commit,
does not rebuild.

## Topology Clearing and Reset

Topology editing and full persisted reset are different operations.

`remove or replace a continuation`
: Uses the applicable layout command to remove the target, batch, terminal
  transition, visit, or incompatible downstream structure. It preserves every
  now-dormant Room Control's local state.

`clear biome topology`
: Uses the layout's `ClearTopology` command to clear that Biome Plan's authored
  structure and biome-global state. Room Controls are preserved and become
  dormant when no longer referenced.

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
  -> normalize topology for every configured biome
  -> process complete biomes in route order
  -> materialize, append history, and validate each biome once
  -> stop at the first incomplete or invalid biome
  -> translate findings and project every configured biome into a fresh cache
  -> compile or clear the execution plan
  -> atomically publish one derived result
  -> draw authored values plus that prepared view until next commit
```

Required practices:

- cache immutable room-control descriptors and stable keys, then resolve the
  current callback's refs through its state-access surface;
- cache declaration-derived topology keys and index metadata;
- pass the current callback state-access surface into semantic operations;
- reuse option/value/label arrays;
- mutate prepared validity/color/message arrays only in an unpublished build
  buffer;
- never mutate the currently published presentation result; reusable buffers
  become writable again only after they are no longer published;
- keep static draw option tables module-local and caller-owned;
- avoid string concatenation and inline tables in room/batch draw loops;
- do not deep-copy the full topology each frame;
- do not run history or validation during draw;
- do not apply findings or mutate prepared presentation during draw;
- do not introduce a retained UI layer for layout.

## Explicitly Rejected Designs

Do not rebuild:

- one global root draft that owns every route, topology record, and payload;
- occurrence IDs separate from room controls;
- multiple logical control instances for one concrete room control;
- reward vessels for unpicked combat rooms;
- dynamic nested Lib controls;
- topology stored inside target Room Controls;
- direct writes to private control storage aliases;
- validation that knows widget IDs or table-row positions;
- custom persistence, profile, commit, or config-flush machinery;
- permanent compatibility adapters for the current implementation.
