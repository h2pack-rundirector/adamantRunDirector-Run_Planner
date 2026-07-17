# UI Editor Model

## Purpose

This document defines the authored Run Planner editor and the boundary between
Biome Plan persistence, layout projection, Room Control views, and semantic
feedback. It is the focused implementation authority for Checkpoint 4A.

`UI_PERSISTENCE_MODEL.md` remains authoritative for the broader ModpackLib,
profile, reset, state-access, and final derived-publication lifecycle. This
document owns the concrete editor object model and the rules needed to mount a
useful authored-state editor before canonical materialization, history, and
validation are implemented.

The editor is one consumer of authored planner state. It is not the authored
state itself:

```text
Route Control + Biome Plan persistence + Room Control persistence
  -> normalized Biome Plan topology
      -> UI layout projector
      -> common canonical materializer
          -> history
          -> validation
          -> feedback presentation returned to the UI projector
```

History is downstream of canonical materialization. It never reads persisted
topology or Room Control storage directly.

## Editor Scope

Checkpoint 4A mounts a thin authored editor. It provides:

- a Route Control prefix dropdown whose Underworld domain is empty or F and
  whose Surface domain remains empty;
- transient route and biome navigation;
- layout-projected start, batch, target, continuation, and terminal sections;
- semantic Biome Plan mutation commands;
- Room Control views for referenced picked and unpicked rooms;
- stable declaration-derived option domains;
- structural and local-completeness presentation;
- profile, reload, commit, and reset round trips;
- an explicit editor-only state while no execution plan exists.

It does not provide:

- canonical materialization;
- game-language history;
- eligibility, force, cap, counted-bag, or acquisition validation;
- contextual candidate validity;
- execution-plan compilation or runtime generation hooks;
- final invalid, muted, blocking, or enrichment presentation;
- a `plannerActive = true` capability claim.

Checkpoint 4B adds canonical materialization as the second consumer of the
same Biome Plan and Room Control state. Checkpoint 5 adds the headless semantic
pipeline. Checkpoint 6 feeds hardened candidate and feedback results into the
existing editor and earns planner-active support.

## Persistent Ownership

### Route Control

One Route Control owns the configured contiguous biome prefix and any future
route-global authored settings. It does not contain biome topology or Room
Control persistence.

The prefix is persistent authored scope, not transient navigation. Its default
remains empty. Checkpoint 4A supplies this bounded domain:

```text
Underworld    "", "Underworld_F"
Surface       ""
```

The widget may label those values as `0 / 1` or `Vanilla / F`, but persistence
keeps the semantic terminal biome-step key. The implementation-support route
view derives the domain from `maximumEditablePrefix`; draw does not hard-code
the bound.

Static control manifests and view implementations are prepared before support
validation. Route Control instances are constructed afterward from the
validated support route view. Production composition has no second
`activePrefixEnds` override or caller-selected domain beside that authority.

Transient route and biome navigation only selects among views already prepared
for the committed configured scope. It does not change authored scope, dirty
configuration, or determine what the committed rebuild publishes.

Shrinking the configured prefix makes excluded Biome Plans dormant. It does
not clear their topology or reset their Room Controls. Re-expanding the prefix
restores the prior authored state through the normal committed rebuild.

### Biome Plan

One planner-owned Biome Plan object exists for each route-biome step. It is a
decision-tree aggregate, not a Lib control and not a renderer.

The Biome Plan owns:

- its immutable biome and layout identity;
- its layout-derived bounded persistence descriptor;
- the reversible codec between physical Lib roots and semantic authored
  choices;
- normalization into one layout-typed topology;
- structural completeness;
- semantic topology addresses;
- atomic mutation commands;
- traversal used by downstream consumers.

The selected topology-layout implementation supplies the layout-specific
storage and codec behavior. `LinearBiome` and `HubBiome` persistence must not
remain conditional branches in a global state-access adapter.

The Biome Plan declares finite storage during system composition. It does not
dynamically create variables after module activation. The module storage
manifest is a collector of the roots declared by every Biome Plan plus other
module-owned roots.

Representative construction is:

```lua
local plan = BiomePlan.create({
    biome = biomeDeclaration,
    topologyLayout = topologyLayouts[biomeDeclaration.layout.kind],
})

local storageDescriptor = plan:storage()
```

The long-lived object never captures callback-owned UI or runtime refs. A
short-lived bound reference supplies the current surface:

```lua
local runtimePlan = plan:bind(runtimeStateAccess)
local uiPlan = plan:bind(uiStateAccess)

local authored = runtimePlan:readAuthored()
local topology = runtimePlan:readTopology()
uiPlan:apply(command)
```

Exact method names may change. The ownership and callback-lifetime split may
not.

### `LinearBiome` Persistence Codec

The `LinearBiome` implementation derives its storage capacity from the biome
layout declaration:

```text
selected start                         scalar when start mode is oneOf
batches[maxBatches]                    parent Room Control key
targets[maxTargets]                    parent key, exit index, target key, picked
terminal transition                    predecessor Room Control key
terminal companions[maxCompanions]     exit index, target Room Control key
authored biome globals                 declared bounded scalar roots
```

Bounded table capacity is declared up front; unused rows are not populated.
Fixed starts, terminal Room Control keys, batch-rule keys, continuation
overrides, transition-rule keys, and terminal exit policy are derived and are
never persisted.

The codec must round-trip one semantic authored state exactly:

```text
physical Lib roots
  -> readAuthored
      -> LinearBiomeAuthoredState
  -> replaceAuthored
      -> physical Lib roots
```

`replaceAuthored` validates and prepares the complete bounded replacement
before staging writes. Callers never edit physical batch or target rows
directly.

### Room Controls

Every concrete room has one static Room Control. It owns its private persistent
leaf state, local completeness, draw view, candidate application, feedback
translation, and canonical fragment.

The Biome Plan persists only stable Room Control keys. It does not copy leaf
payloads or contain Room Controls. The editor and materializer resolve those
keys through their current UI or runtime control surface.

## Unique Room Identity Invariant

A Room Control may appear at most once as a top-level room in one Biome Plan.
This injectivity rule is an architectural identity invariant, not merely a
validation convenience.

It provides:

- one persistent leaf state per room identity;
- one rendered top-level occurrence per referenced Room Control;
- one outgoing batch per parent Room Control;
- direct leaf candidate and feedback routing;
- direct materializer resolution;
- dormant-state preservation after unlinking;
- stable identity independent of persisted-table or UI-row order.

Vanilla may create the same unentered combat map on different door offers.
The planner deliberately canonicalizes those offers to distinct eligible
combat Room Control keys. Unpicked combat-map identity is irrelevant to the
reward simulation, while a map that is actually entered is already prevented
from reappearing in the biome. This bounded mismatch preserves the facts the
planner consumes and avoids occurrence IDs throughout persistence, UI,
materialization, history, and feedback.

If a future supported mechanic requires one top-level Room Control to occur
more than once, this invariant must be reopened explicitly. The replacement
would require persisted occurrence identity and is not an invisible extension
of the current model.

## Published Authored View

The Biome Plan codec and topology projector allocate Lua records. Draw must not
decode and reproject the plan every ImGui frame.

Activation, a meaningful configuration commit, and a setting-changing reload
run the authored preparation path:

```text
read committed Route Controls
  -> reject any prefix beyond maximumEditablePrefix
  -> bind and decode every configured Biome Plan
  -> normalize every configured topology
  -> calculate structural and referenced-control completeness
  -> project one authored view per configured biome
  -> atomically publish the complete authored result
```

The Checkpoint 4A publication contains no canonical snapshot, history,
validator result, contextual candidate validity, or execution plan. Those
fields are added to the same atomic route result by later checkpoints. A
configured F prefix is therefore editable authored intent at this checkpoint;
configuration alone does not claim headless or planner-active support.

One draw consumes one published authored view. If the user stages an edit, the
edit frame may display the previous committed projection. Lib commits after
draw, the lifecycle rebuild publishes a replacement, and the next draw sees
the new topology. Same-frame projection or feedback is not a contract.

## UI Layout Projection

UI projectors are registered by layout kind and consume normalized topology,
not physical storage:

```text
uiLayouts["LinearBiome"]
uiLayouts["HubBiome"]
```

The `LinearBiome` projector produces presentation records for:

- the start choice or fixed start;
- one decision batch per selected-spine parent;
- every authored target slot in physical exit order;
- any read-only physical offer derived by the registered contextual batch
  realization;
- the picked continuation;
- every unpicked dead leaf;
- the one active continuation frontier or the selected terminal outcome;
- the terminal transition;
- terminal companions admitted by the exit policy;
- the one terminal Room Control and its immutable predecessor context.

The projector must handle incomplete but well-formed topology. It cannot use a
traversal operation that correctly requires structural completion.

I uses the existing batch/terminal outcome split rather than making the
preboss an ordinary selectable target. Once committed prefix facts make the
preboss eligible:

- `Go to Preboss` projects the terminal Room Control because it was selected
  and entered, plus one ordinary unpicked companion on a two-exit predecessor;
- `Add Next Decision` on a two-exit predecessor projects a read-only derived
  preboss offer on the first exit and exactly one configurable picked ordinary
  target on the remaining exit;
- `Add Next Decision` on a one-exit predecessor continues to expose one
  ordinary picked target, allowing the validator to report that the forced
  preboss should have occupied the sole exit.

The contextual batch realization is prepared during committed publication and
shared with canonical materialization. Draw does not count Clockwork Goals or
infer active exits. A declined preboss has no Room Control view, persistent
target, transient selector, or local shop configuration.

Context changes never cause projection to conceal an authored target. If an
upstream edit makes the preboss eligible while exit 1 already contains an
ordinary target, the existing target row remains visible with its structural
finding and no derived offer is projected into that occupied slot. Removing
the target through the normal semantic command allows the next committed view
to replace the now-empty slot with the read-only preboss offer.

Switching between `Add Next Decision` and `Go to Preboss` is an explicit
outcome replacement. For a clean two-exit I decision, the ordinary room stays
on its physical exit while its role changes between picked continuation and
unpicked terminal companion. The replacement clears only downstream topology
that depended on the former picked continuation; Room Control persistence is
unchanged.

Rows, cards, columns, and display ordinals are presentation only. They are not
persisted identities, semantic addresses, or gameplay counters.

## Drawing Referenced Leaves

Each projected room occurrence contains a stable Room Control key and the
immutable context required by its view:

```lua
targetView = {
    roomControlKey = "Underworld_F_Combat04",
    address = targetAddress,
    picked = false,
    roomContext = roomContext,
}
```

Draw resolves the current callback-owned ref and delegates:

```lua
local room = ui.controls.get(targetView.roomControlKey)
ui.draw.control(room, "default", targetView.roomContext)
```

Both picked and unpicked generated targets are drawn. Dormant unreferenced Room
Controls are not drawn and do not contribute to completeness.

Reward and payload UI is composed bottom-up inside Room Control views. The
layout projector never reads or writes private Room Control fields.

## Topology Editing

All topology edits are semantic Biome Plan commands. Draw never writes the
Biome Plan's bounded table fields directly.

The UI-bound plan performs:

```text
read current authored choices
  -> construct unpublished proposed replacement
  -> normalize and validate the complete proposal
  -> encode and stage the bounded replacement
```

Dynamic target dropdowns use bounded transient selector fields declared with
`persist = false` and `hash = false`. They are UI-only adapters between Lib's
field-backed widgets and semantic Biome Plan commands. They may use positional
presentation slots because they do not survive the UI session and never enter
the authored or derived domain.

When a selector changes, draw translates the selected semantic value into one
command during the same draw call. It does not persist the selector as a
second topology authority.

Continuation form is not a dropdown and allocates no transient selector. The
projected editor exposes structural commands only where they are actionable:

- each existing decision header offers `Remove From Here`, which removes that
  batch and every dependent downstream batch or terminal transition;
- the single active frontier offers `Add Next Decision` and `Go to Preboss`;
- `Add Next Decision` is absent when the declared batch bound is exhausted;
- an entered terminal replaces the frontier and offers `Continue With Rooms`
  and `Remove`, translating to the existing atomic replacement/removal
  commands.

These are direct semantic buttons with projection-prepared unique ImGui labels.
They do not mirror topology into another field. After one stages a structural
command, draw stops consuming the stale published topology for that frame; the
next committed publication supplies the replacement view.

Picked continuation is rendered as one inline radio per populated physical
target. These radios read the projected batch selection and issue `SetPicked`
directly; they do not allocate transient fields or persist per-radio booleans.
Their unique ImGui labels are prepared during authored publication. A newly
selected target from a single-exit parent is picked in the same interaction,
so completed single-exit rows need no redundant radio. An older incomplete
single-exit row remains explicitly repairable rather than being mutated during
an unchanged draw.

Generated target selection uses a two-stage UI adapter over the same semantic
room command:

```text
Exit N Type [Combat / Miniboss / Story / Fountain / Shop]
       Room [category-filtered Room Control keys]
```

The category field is bounded transient state only. The persisted target
remains one `roomControlKey`; normalized topology, snapshots, and history do
not contain the category. A referenced room derives its category during
projection. An empty target may retain a transient category for the current UI
session while the user chooses a room. Changing the category of an existing
target issues `RemoveTarget`, allowing the Biome Plan to clear incompatible
downstream topology, and choosing the second dropdown value issues
`SetTarget`.

Category labels are UI language over room kinds: `Reprieve` is presented as
`Fountain`, and `Bridge` shares the `Story` category. Start and terminal roles
remain declaration-impossible target values. Category-specific room arrays are
prepared during authored publication and reused during draw; the selector does
not filter or allocate option arrays per frame.

Constructed room descriptors keep three identities separate:

```text
key       stable route-qualified Room Control identity
gameName  game RoomData name
label     player-facing UI name
```

Biome topology persists `key`, runtime translation consumes `gameName`, and UI
projection renders `label`. Exit counts and similar context are presentation
decoration composed around the label rather than stored inside it. The authored
catalog requires an explicit label for every room declaration, and UI consumers
never derive display text from either internal identifier.

Room Control widgets use their template-owned private fields and semantic
component operations. Store, reward-type, and payload changes must clear or
normalize incompatible subordinate state before the draw call returns.

## Candidate Boundaries

Checkpoint 4A exposes stable declaration-derived domains needed to author the
tree. It does not claim game-context legality.

- Declaration-impossible values are absent.
- Values that would violate the Biome Plan's structural contact boundary are
  not offered by the corresponding structural command surface.
- Eligibility, force, cap, reward-history, and route-context choices remain
  undecorated until the headless pipeline exists.
- Once contextual validation exists, context-invalid values remain visible
  and receive prepared invalid presentation.

Option arrays, labels, and structural lookup tables are prepared outside draw
and reused. Draw does not rebuild candidate domains.

## Semantic Spine Identity

Feedback is never keyed by persisted table row or rendered row. The Biome Plan
assigns semantic addresses to decision-tree subjects.

The injective room invariant provides the anchors:

```text
biome                         route key + biome-step key
start                         biome + layout-start aspect
batch                         biome + parent Room Control key
physical target slot          biome + parent Room Control key + exit index
picked continuation           biome + parent Room Control key + continuation aspect
terminal transition           biome + predecessor Room Control key
terminal companion            biome + predecessor Room Control key + exit index
room leaf                     Room Control key + optional local slot
```

A target Room Control key directly identifies an existing leaf occurrence. A
missing target has no leaf identity, so its parent key plus physical exit index
identifies the empty decision slot.

A derived I preboss offer reuses that physical-slot address for structural
presentation and findings. It never receives a `room leaf` address because it
does not allocate or draw the terminal Room Control. Entering the preboss
changes the continuation form, after which the ordinary terminal-transition
and terminal-control addresses apply.

Representative target address:

```lua
{
    routeKey = "Underworld",
    biomeStepKey = "Underworld_F",
    ownerKind = "batchTarget",
    parentRoomControlKey = "Underworld_F_Combat02",
    exitIndex = 2,
    aspect = "targetRoom",
}
```

Finding codes remain generic. Instance identity lives in the origin payload:

```lua
{
    code = "target_room_ineligible",
    origin = targetAddress,
    evidence = {
        requirementCode = "biome_encounter_depth_out_of_range",
    },
}
```

## Feedback Resolution

Materialization copies semantic return addresses onto canonical facts. History
preserves them on relevant game-language events. Validators return generic
findings with those origins.

During unpublished presentation preparation:

```text
finding origin
  -> Room Control or local-slot translator for leaf ownership
  -> layout structural translator for spine ownership
  -> owner-keyed presentation
  -> layout-specific prepared view
```

The UI projector builds a non-persisted owner index from the same semantic
addresses carried by its projected elements. Resolution is a direct owner
lookup, not a search for a game-room name, bounded storage row, or UI display
ordinal.

Representative ownership is:

| Finding | Semantic owner | Presentation destination |
| --- | --- | --- |
| Missing start | Layout start | Start selector marker |
| Missing target | Parent plus exit index | Physical exit selector |
| Missing picked target | Parent batch continuation | Picked-choice surface |
| Batch-wide conflict | Parent batch | Batch marker or route status |
| Missing continuation | Current selected parent | Continuation controls |
| Terminal problem | Terminal predecessor | Terminal section |
| Companion problem | Predecessor plus exit index | Companion selector |
| Reward or payload problem | Room Control plus local slot | Room Control view |
| Biome incomplete | Biome Plan | Biome-level route status |

Completeness is a biome-level processing result. Owner addresses may localize
missing authored state, but an incomplete biome produces no canonical snapshot
and is not sent to contextual validation.

Published topology, owner presentation, and findings come from the same
committed rebuild and are swapped atomically. If an edit removes an address,
the old view and its old finding disappear together. No persisted revision,
stale-feedback repair, or row-hunting pass is required.

## Draw Contract

Draw may:

- consume the currently published authored/prepared view;
- read and edit current staged Room Control state;
- update transient route/biome navigation and selector fields;
- issue semantic Biome Plan commands;
- invoke Lib reset-to-defaults.

Draw must not:

- decode or normalize the full Biome Plan;
- project topology rows;
- materialize canonical fragments;
- build history or run validation;
- translate findings;
- mutate the published presentation result;
- flush configuration;
- retain callback-owned UI refs after the callback returns.

Static option arrays and draw option tables are reused. Dynamic validity and
color tables introduced later are mutated only in unpublished preparation
buffers.

## Checkpoint 4A Acceptance

Checkpoint 4A is complete when:

- the Underworld Route Control offers exactly empty and F configured prefixes,
  the Surface Route Control offers only empty, and both default to empty;
- an empty F plan can be authored through start, batches, targets, picked
  continuations, and one terminal transition;
- every referenced picked and unpicked F Room Control can edit its local
  persistent state;
- replacing a selected continuation clears only incompatible downstream
  topology and preserves unlinked Room Control persistence;
- continuation form is edited only at the active frontier or terminal header;
  existing decisions contain no repeated `Next Step` selector;
- terminal presentation derives active free-reward capacity from immutable
  predecessor exit context;
- profile load, hash reload, commit, and Lib reset reproduce the same authored
  model through the Biome Plan codec;
- changing the configured prefix commits and publishes exactly the views in
  that prefix, while transient navigation only selects an existing view;
- shrinking to empty and restoring F preserves F topology and Room Control
  persistence;
- one UI-layout implementation projects both F and focused G structural
  fixtures without claiming G materialization or planner-active support;
- unchanged draw frames perform no topology normalization, projection,
  materialization, history, validation, or feedback translation;
- option arrays and published view records are not rebuilt during unchanged
  draw frames;
- fake-ImGui tests cover planner command wiring without retesting Lib widget
  internals;
- an in-game probe covers dropdown opening, selection, commit publication,
  profile reload, and reset-to-defaults;
- the module exposes no execution plan and clearly presents its editor-only
  state.

F is the only configurable editor biome in this slice and earns
`authoredEditor = true`, but not materialization, headless-pipeline, or
planner-active support. G may exercise the shared projector and views in
focused fixtures, but it remains outside the configured-prefix domain until
its rollout checkpoint.

## Rejected Editor Shapes

Do not introduce:

- a second serialized planner document;
- a second editor-visible scope independent of the configured Route Control
  prefix;
- a Biome Plan Lib control;
- dynamic nested Room Controls;
- persisted UI rows, batch ordinals, or occurrence IDs;
- topology links inside Room Controls;
- direct widget writes to bounded topology rows;
- a planner-owned raw ImGui dropdown implementation when Lib's field-backed
  widget can be used through transient selector state;
- same-frame topology reprojection;
- feedback lookup by game-room scan, storage position, or rendered row;
- canonical, history, validation, or execution work during draw.
