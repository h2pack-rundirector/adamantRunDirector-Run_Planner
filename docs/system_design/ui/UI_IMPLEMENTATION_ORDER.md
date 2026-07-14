# Biome Plan UI Rewrite Order

## Purpose

This document defines the implementation sequence for replacing the current
planner UI with the Biome Plan control model.

The rewrite is intentionally clean. Existing row-oriented panels, a global
`PlannerDraft`, and detached form-participant state are reference material for
visible behavior only. They are not compatibility contracts.

```text
static route-biome controls
-> dynamic occurrence tree inside each control
-> canonical materialization
-> history and validation
-> semantic feedback
-> low-allocation draw
```

## Preconditions

Before production UI work begins, lock these contracts:

- occurrence identity is `nodeId`, not game room key;
- one Biome Plan Lib control exists per declared route-biome occurrence;
- the selected parent owns one outgoing batch and all peer doors;
- generated unselected peers are complete dead leaves;
- room templates own occurrence-local schema and behavior;
- batch decisions live on the parent batch;
- route order lives outside Biome Plan persistence;
- canonical plans contain concrete game decisions, not UI roles;
- validation uses semantic source plus topology location;
- Lib profile/reset/resync paths produce one derived-state invalidation signal.

Game-data gaps should be recorded explicitly. They must not be filled with a
convenient uniqueness or fallback rule.

## Production Boundaries

ModpackLib remains the host for module registration, storage, controls,
profiles, navigation, commits, and trusted ImGui context.

Planner boundaries are:

```text
route shell
  -> route aggregate
      -> Biome Plan controls
          -> topology and outgoing batch controls
          -> registered nested room-template controls
              -> reusable reward/payload/encounter/shop components
```

Dynamic node and batch controls are cached logical objects backed by the parent
Biome Plan's storage. They are not registered independently with Lib.

The host surface is trusted after construction. Missing RoM, Lib, ImGui, game
APIs, declarations, or registered templates fail at their contact boundary.
Do not scatter `pcall`, method probes, or fallback draw paths through the hot
path.

## Suggested Folder Shape

Exact filenames may change, but ownership should remain visible:

```text
src/mods/controls/
  biome_plan.lua
  topology.lua
  outgoing_batch.lua
  room_templates/
    registry.lua
    standard_combat.lua
    fields_combat.lua
    ship_combat.lua
    ephyra_combat.lua
    shop.lua

src/mods/ui/planner/
  state.lua
  options.lua
  widgets.lua
  route_selection.lua
  route_nav.lua
  route_shell.lua

src/mods/ui/biomes/
  registry.lua
  biome_plan_panel.lua
  fields_extensions.lua
  ephyra_extensions.lua
  tartarus_extensions.lua
```

The generic biome panel draws topology and dispatches to registered node/batch
owners. Biome extension modules contribute true biome-scoped or batch behavior;
they do not copy general room/reward editors.

## Composition And Dependency Policy

Use explicit construction for orchestrators that retain collaborators:

```text
ui.create(...)
-> route_shell.create(...)
-> route_aggregate.create(...)
-> biome_plan_registry.create(...)
-> room_template_registry.create(...)
```

Passed dependency tables remain caller-owned and read-only. A constructor that
needs additional services returns a new object; it does not mutate the passed
table.

Leaf template modules receive only declared collaborators and the occurrence
view supplied by their Biome Plan. They do not reach upward into route-shell
state or sideways into another node's storage.

## Dirty Rebuild Lifecycle

Draw never validates or reconstructs the route.

```text
user edit / profile commit / reset / resync
-> advance non-persisted change epoch
-> verify local construction invariants
-> check completeness
-> materialize complete biome prefix
-> build history and validate
-> evaluate exported candidates
-> apply feedback to semantic owners
-> draw prepared state until the next change
```

One dirty rebuild produces route status, first blocking issue, downstream
inactive state, and provider presentation arrays. Candidate feedback does not
trigger independent route walks per widget.

## Draw And Allocation Rules

- Cache Biome Plan, node, batch, provider, and storage-handle objects by stable
  identity.
- Keep option values and labels stable.
- Mutate hidden/color/message arrays only during dirty rebuilds.
- Do not deep-copy a biome tree after every edit.
- Do not allocate addresses, candidate records, or decoration tables per frame.
- Use stable ImGui ids derived from control id, `nodeId`, semantic component,
  and local slot—not game room key alone.
- Keep caller-owned draw option tables read-only.
- Fix shared control/template contract problems at the contract boundary.

## Parent-Child Reset Policy

The semantic parent owns incompatible-child reset:

- room-key replacement reinitializes the occurrence through the new template;
- batch-rule changes reset incompatible selection and batch state;
- door-target removal deletes the entire downstream branch;
- reward-store changes reset incompatible reward type and payload;
- reward-type changes reset incompatible payload;
- H cage-roll changes do not erase per-occurrence maximum reward slots;
- N visit-order changes do not erase unvisited pylon-local state;
- profile/reset operations use the same control methods as ordinary edits.

These mutations must be coherent before commit. Widgets never clean storage
rows manually.

## Implementation Slices

### Slice 1: Freeze And Remove The Old UI Surface

- preserve tests or screenshots that express desired user-visible behavior;
- remove production dependencies on the row-based planner state and panels;
- remove the global `PlannerDraft` control and its row ABI;
- keep the module loadable with an explicit planner placeholder if necessary;
- do not add migration or dual-write adapters.

Checkpoint: no production code assumes room index is topology identity.

### Slice 2: Establish Lib Control And Reload Contracts

- register one empty/default Biome Plan control per route-biome occurrence;
- confirm whole-control profile and reset roundtrips;
- add one non-persisted commit invalidation epoch;
- confirm or extend the explicit reload/resync notification path;
- test cached nested-object behavior across staged-state reload.

Checkpoint: profile/reset/resync invalidation is explicit before dynamic state
is layered on top.

### Slice 3: Implement Topology Storage And Mutation

- implement stable node id allocation;
- implement root, nodes, outgoing batches, doors, and selection codecs;
- implement branch insertion, target replacement, selection, and removal;
- enforce tree/dead-leaf/terminal invariants at mutation and decode boundaries;
- support repeated game room keys, including repeated same-batch peers.

Checkpoint: a topology-only F tree roundtrips without typed room state.

### Slice 4: Implement Template Registry And Nested Controls

- define the registered template contract;
- cache nested node controls by Biome Plan plus `nodeId`;
- implement a no-local-state opening/terminal template;
- implement `StandardCombat` with its occurrence reward surface;
- verify two occurrences of one room key remain independent;
- reject unknown or incompatible templates at construction.

Checkpoint: topology dispatch is generic and contains no template-name switch.

### Slice 5: Materialize F End To End

- implement standard outgoing batches;
- materialize every generated peer plus the selected continuation;
- attach semantic source and topology location to emitted facts;
- compile a canonical F biome and route prefix;
- reuse the existing history/validation pipeline only where its contract
  matches the new canonical plan.

Checkpoint: a complete F tree produces concrete canonical output with repeated
room-key support.

### Slice 6: Add Candidate And Feedback Routing

- add provider ownership to nested controls and batches;
- export candidates during the normal materialization/history walk;
- apply candidate results through `biomeControlId` and `nodeId`;
- enforce provider versions and stale-feedback rebuild behavior;
- apply route status, blocking horizon, and downstream inactive decoration.

Checkpoint: validation never performs row arithmetic or widget lookup.

### Slice 7: Build The Generic Immediate-Mode Editor

- draw the selected topology path and peer doors;
- draw nested template content through cached controls;
- make topology edits call Biome Plan mutation methods;
- keep navigation separate from persisted biome state;
- retain debug harnesses only as explicit test hosts.

Checkpoint: prepared state can be drawn repeatedly without materialization or
candidate allocation.

### Slice 8: Add H, O, N, And I Typed Surfaces

Implement special structure only at its owner:

- H: `FieldsCombat` occurrence reward slots plus parent batch cage roll;
- O: `ShipCombat` occurrence encounters and wheel offers;
- N: `EphyraCombat` pylon/side-room state plus hub ordered-subset batch;
- I: Biome Plan-scoped structure, target occurrence state, and peer batch
  constraints.

Add one biome at a time with storage, materialization, validation, feedback,
and allocation tests before proceeding.

### Slice 9: Complete Remaining Templates And Routes

- add remaining room templates and reusable components;
- add G, P, Q, and any declared variant route-biome controls;
- verify cross-biome route-prefix history and feedback;
- reject unimplemented templates explicitly rather than silently falling back.

### Slice 10: Performance And Hardening

- assert zero steady-state candidate/option reshaping during draw;
- measure dirty rebuild and steady draw allocation separately;
- fuzz malformed storage references at the decode boundary;
- exercise profile switching, resets, explicit resync, and repeated room keys;
- run full module tests, lint, and assembled pack validation.

## First Production Checkpoint

The first useful checkpoint is deliberately narrow:

```text
Biome Plan registration and profile lifecycle
+ topology storage and mutation
+ StandardCombat occurrence state
+ complete F materialization
```

It does not require every biome, polished navigation, or all feedback colors.
It must prove the ownership and occurrence model before the UI surface grows.

## Explicit Non-Goals

- preserving the old `PlannerDraft` storage ABI;
- keeping old panels alive through compatibility adapters;
- making every topology node a Lib-registered control;
- globally materializing one control per game room key;
- allowing draw code to interpret game legality;
- hiding incomplete declaration/template support behind defaults.

## Supporting Docs

- `BIOME_PLAN_CONTROL_MODEL.md` owns semantic architecture.
- `FORM_STORAGE_ROUNDTRIP.md` owns persistence, profiles, and reset.
- `FORM_FEEDBACK_CONTRACT.md` owns completeness and feedback routing.
- `../model/CANONICAL_PLAN.md` owns materialized output.
- `../validation/VALIDATION_MODEL.md` owns legality evaluation.
