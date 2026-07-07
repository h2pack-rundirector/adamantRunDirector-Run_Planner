# 2026-07-07 UI Implementation Plan

## Progress Log

Newest entries should be added at the top of this section.

### 2026-07-07 - Integrated F Room Unit Mounted

The fourth UI implementation slice now reshapes the F panel into an integrated
room-unit editor while keeping the same in-memory draft owner.

Implemented behavior:

- each F room renders as one unit with room identity, generated door batch,
  generated door targets, generated reward offer, acquired flag, payload leaves,
  and feedback;
- room-local offers render inside the owning room unit instead of in a separate
  reward surface;
- terminal rooms have an explicit generated-door batch state;
- generated door batch metadata and selected door state are shown together;
- route/editor tests now pin the integrated composition without changing route
  validation or history behavior.

Still deferred:

- production state still reads/writes the in-memory planner state, not the
  `PlannerDraft` storage adapter;
- route/biome/room feedback coloring beyond candidate dropdown colors remains
  in the route-status polish slice.

Validation run:

- `lua tests/all.lua` - 129 passed.
- `luacheck src tests` - 0 warnings / 0 errors.
- `git diff --check` - passed.

### 2026-07-07 - Route Shell Implemented

The third UI implementation slice now wraps the F editor in the production
route shell.

Implemented behavior:

- top-level planner status renders before route content;
- route tabs expose Underworld and Surface through the declared route catalog;
- each route has a biome navigation rail using `draw.nav.verticalTabs(...)`
  when available and a text fallback in tests/no-imgui contexts;
- F/Erebus renders the current integrated editor under Underworld;
- G/H/I and N/O/P/Q render explicit placeholder panels that do not emit planner
  snapshots;
- active route and active route-biome selections read/write the public UI
  storage fields added in the previous slice;
- biome navigation tab lists are cached on planner state instead of rebuilt every
  draw.

Validation run:

- `lua tests/all.lua` - 126 passed.
- `luacheck src tests` - 0 warnings / 0 errors.
- `git diff --check` - passed.

### 2026-07-07 - Storage And Control Registration Implemented

The second UI implementation slice now adds the first production storage/control
contract without replacing the current F editor state.

Implemented behavior:

- `module.data.define(...)` is wired through `moduleSystems.storage`;
- public UI storage declares active route and active route-biome selections;
- `data.buildControlTemplates()` and `data.buildControls()` register one
  `PlannerDraft` control;
- `PlannerDraft` owns flat normalized draft tables for rooms, generated doors,
  generated-door offers, and room-local offers;
- empty planner draft storage materializes the current minimal F sample through
  the control adapter;
- the existing in-memory F debug editor still runs unchanged;
- the default F sample lives in `mods/forms/defaults.lua` so the debug editor
  and storage adapter share one source.

Validation run:

- `lua tests/all.lua` - 122 passed;
- `luacheck src tests` - 0 warnings / 0 errors.
- focused ModpackLib activation harness - passed.

### 2026-07-07 - Dropdown Primitive Fix Implemented

The first UI implementation slice now fixes the planner dropdown wrapper.

The bug matched an ImGui binding shape where `Selectable(label, selected)`
returns both selected state and activation/change state. The old wrapper treated
the first return as activation, so the currently selected item could overwrite a
click on an option listed above it. The wrapper now normalizes the return shape,
uses stable per-option selectable IDs, closes the combo after an activated
selection when the binding supports it, and marks the selected item as the
default focus when available.

Validation run:

- `lua tests/all.lua` - 118 passed;
- `luacheck src tests` - 0 warnings / 0 errors.

### 2026-07-07 - Plan Created

No production UI code has been changed in this checkpoint.

This note records the agreed UI implementation direction after re-reading the
fresh planner UI docs, the current F debug harness, Biome Control, God Pool,
ModpackLib storage constraints, and the old `main` branch Run Planner UI.

The next implementation slice should start with the dropdown primitive fix, then
move into storage/control registration and the route shell.

## Purpose

This is a progress-lane working plan for building the production Run Planner UI.
It does not redefine the architecture. Stable contracts remain in:

- `docs/system_design/ui/FORM_FEEDBACK_CONTRACT.md`
- `docs/system_design/ui/UI_IMPLEMENTATION_ORDER.md`
- `docs/system_design/model/CONFIGURED_SCOPE.md`
- `docs/system_design/model/CANONICAL_PLAN.md`
- `docs/system_design/validation/VALIDATION_MODEL.md`

Use this file to track implementation order, slice boundaries, and practical
decisions made while moving from the current F debug harness to the production
route editor.

## Current Position

The branch currently has a working F/Erebus data loop:

```text
editable draft
-> form completion
-> canonical materialization
-> history ledger
-> validation
-> candidate feedback
-> raw debug UI display
```

The loop is valuable and should stay active while the production UI is built.

Current gaps:

- no production storage declaration for planner drafts;
- no production planner control template;
- no route shell with Underworld/Surface and biome panels;
- no persistence across reloads;
- only F has a real editable data surface;
- G/H/I and N/O/P/Q should be placeholder panels for now;
- current dropdown wrapper has an in-game selection bug;
- the current F surface is a debug harness, not the final presentation.

## Reference Findings

### Fresh Planner UI Docs

The production UI should stay a thin editor over explicit route data:

```text
draft form -> complete snapshot -> history -> validation -> feedback
```

The UI owns draft state, form completeness, stable provider tables, resets after
parent changes, feedback presentation, and low-allocation draw behavior.

The UI does not own route legality, force pressure, reward legality, reward bag
simulation, or runtime interpretation.

### Biome Control

Biome Control is the closest Lib registration reference:

```lua
module.data.define(data.buildStorage())
module.controls.defineTemplates(data.buildControlTemplates())
module.controls.define(data.buildControls())
```

It uses custom control templates where runtime/UI behavior needs richer access
than plain scalar settings. This is the right registration shape for Run
Planner, but not the right internal route model.

### God Pool

God Pool is the simple scalar-storage reference. It draws directly from
`uiContext.data` fields and does not need custom control templates.

Run Planner is too nested for this pattern alone.

### ModpackLib Storage

ModpackLib supports table storage, but table rows cannot contain nested table
storage. Planner persistence should therefore be normalized into explicit flat
tables and scalar fields, not a nested route blob.

### Old Run Planner On `main`

The old UI is useful as presentation reference only.

Useful ideas:

- route status appears before route tabs;
- top route tabs split Underworld and Surface;
- each route has a left biome navigation rail;
- invalid and inactive tabs/rows are colored;
- rows have a stable visual rhythm and fixed control columns.

Do not copy:

- centralized biome templates;
- route-context-owned tab visibility as the source of truth;
- whole-biome control templates such as `FixedLinearRoute`;
- row role/option engines as canonical route data;
- control-owned read passes;
- split `Rooms` and `Rewards` biome tabs.

## Agreed UI Direction

The production editor should compose leaf forms, not biome route templates.

Target composition:

```text
Run Planner tab
  Route status
  Underworld / Surface tabs
    Biome nav
      F / G / H / I
      N / O / P / Q
    Active biome panel
      Integrated room list
        room identity
        generated door batch
        selected door
        generated door targets
        generated door reward offers
        acquired flags
        payload leaves
        room-local offer points
        participant feedback
```

Rooms and rewards must not be split into separate biome tabs. The new model
treats room structure and reward offers as one materialized room unit because
both feed history, validation, force pressure, reward legality, and bag state.

## Route Scope Behavior

The UI should expose the declared route order:

```text
Underworld: F, G, H, I
Surface:    N, O, P, Q
```

Configured scope is an ordered complete-biome prefix. For the first production
checkpoint:

- F is editable and can emit a complete snapshot;
- G/H/I and N/O/P/Q are visible placeholders;
- placeholders do not emit canonical snapshots;
- incomplete biomes do not feed history;
- the game takes over after the last complete configured biome.

## Storage And Control Shape

Add Run Planner data/control registration through the existing system slots:

```lua
module.data.define(moduleSystems.storage)
module.controls.defineTemplates(moduleSystems.controlTemplates)
module.controls.define(moduleSystems.routeControls)
```

Expected additions:

- `mods/data.lua`
  - `buildStorage()`
  - `buildControlTemplates()`
  - `buildControls()`
- `mods/controls/templates.lua`
- one planner draft control/template at first;
- a storage adapter that reads/writes normalized draft data;
- UI state for active route and active biome tabs.

Persistence should favor explicit normalized tables, for example:

- scalar active UI fields:
  - selected route;
  - selected Underworld biome;
  - selected Surface biome;
- room rows:
  - route key;
  - biome key;
  - room index;
  - room key;
  - selected door index;
- generated-door rows:
  - route key;
  - biome key;
  - room index;
  - door index;
  - exit index;
  - target room key;
- generated-door offer rows:
  - route key;
  - biome key;
  - room index;
  - door index;
  - offer index;
  - store;
  - reward type;
  - acquired flag;
  - payload fields as flat columns or typed auxiliary rows;
- room-local offer rows:
  - route key;
  - biome key;
  - room index;
  - offer point index;
  - offer index;
  - store/profile;
  - reward type;
  - acquired flag;
  - payload fields as flat columns or typed auxiliary rows.

The exact aliases can change during implementation, but the stored shape should
remain explicit route data. Do not store old row-template roles as the canonical
draft.

## Candidate Provider Policy

Candidate providers should remain stable objects owned by form participants:

```lua
{
    values = values,
    labels = labels,
    hidden = hidden,
    colors = colors,
    messages = messages,
    version = version,
}
```

Draw code reads prepared providers. Rebuild code mutates `hidden`, `colors`, and
`messages` after validation. Widgets should not run route validation.

## Implementation Slices

### Slice 1: Fix Dropdown Primitive

Goal:

- fix the current in-game bug where options above the current selection cannot
  be selected;
- keep no-imgui fallback behavior working;
- keep provider-driven labels, hidden values, colors, and messages.

Success checks:

- selecting any visible option updates the draft;
- selected value focus/default behavior is stable;
- repeated dropdown labels do not collide when scoped by callers;
- focused tests cover selecting values before and after the current index.

### Slice 2: Add Storage And Control Registration

Goal:

- register planner storage through `module.data.define`;
- register planner control templates and route controls through the existing
  system slots;
- keep the current debug F loop behavior intact while storage is introduced.

Success checks:

- module activation has a real planner storage definition;
- storage defaults materialize the current F sample or a minimal valid F draft;
- tests can construct systems with storage/control definitions;
- no runtime hook consumes the plan yet.

### Slice 3: Add Route Shell

Goal:

- build the production route shell around the current editor;
- route status appears before route tabs;
- top tabs are Underworld and Surface;
- each route has a biome nav list;
- only F renders the real editor at first.

Success checks:

- F panel is reachable under Underworld;
- G/H/I and N/O/P/Q render clear placeholders;
- placeholders do not emit snapshots or validation history;
- active route and biome UI state persists.

### Slice 4: Mount Integrated F Room Editor

Goal:

- move the current F debug editor into the production F panel;
- present each room as one integrated unit;
- do not split Rooms and Rewards into separate tabs.

Each room unit should include:

- room selector/identity;
- selected generated door;
- generated door target controls;
- generated door reward offer controls;
- acquired flags and reward payload leaves;
- room-local offer points where declared;
- local feedback decoration from validation results.

Success checks:

- F can still emit a complete canonical snapshot;
- incomplete F stops before history and shows form feedback;
- invalid selected values and candidates are colored through feedback;
- downstream rooms after the first blocking invalid are inactive/greyed.

### Slice 5: Replace Debug-State Ownership With Stored Draft Ownership

Goal:

- make the production planner state read/write through the planner control or
  storage adapter;
- keep explicit mutators as the only way draw code changes route data;
- preserve dirty rebuild behavior.

Success checks:

- reload preserves authored F draft;
- reset writes explicit draft defaults;
- append/remove room behavior updates storage-backed draft data;
- no direct widget writes bypass form mutators.

### Slice 6: Route Status And Feedback Polish

Goal:

- show route-level valid/invalid state before route tabs;
- color route tabs, biome nav entries, room units, and candidate values using
  feedback;
- keep inline invalid text limited to status/marker surfaces, not every widget.

Success checks:

- first issue is visible at route level;
- related findings can be shown without hiding the primary blocker;
- inactive downstream content does not hide the original error;
- enrichment colors are gated on a valid configured scope.

### Slice 7: Production UI Tests And Allocation Checks

Goal:

- add focused tests around the production UI services and storage adapter;
- add draw-path/allocation checks where practical.

Success checks:

- storage defaults and roundtrip tests pass;
- route shell placeholder behavior is tested;
- F room editor still drives the real pipeline;
- dropdown selection regression is covered;
- `lua tests/all.lua`, `luacheck src tests`, and `rtk git diff --check` pass.

## First Production Checkpoint

The first useful checkpoint is:

```text
dropdown fixed
+ planner storage/control registration
+ Underworld/Surface route shell
+ F real integrated room editor
+ G/H/I/N/O/P/Q placeholders
+ route status
+ candidate feedback coloring
+ storage-backed F draft
+ focused tests
```

That checkpoint should make in-game UI/data-model testing practical without
waiting for G/H/I/N/O/P/Q data completion.

## Explicit Non-Goals For This Pass

Do not add these during the first UI pass:

- G/H/I/N/O/P/Q production editors;
- runtime execution-plan compiler;
- runtime hooks that consume fresh history;
- reward bag simulation;
- Chaos detours;
- NPC and feature routing;
- old row-template compatibility shims;
- compact picked/other-door storage;
- Auto/Vanilla canonical values;
- route legality checks inside widgets.

## Open Decisions

These should be resolved during implementation, not guessed too early:

- exact normalized storage aliases and table split;
- whether payload fields become flat columns or typed auxiliary rows;
- whether selected route/biome UI state belongs in public persisted storage or
  transient control state;
- exact room-unit visual layout once F is mounted under the shell;
- how much of the current debug reset/append/remove tooling remains visible in
  production.
