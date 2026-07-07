# UI Implementation Order

## Purpose

This document turns the form/feedback contract into an implementation path for
the production planner UI.

The system-design docs define the model. This document defines the order and
the control-layer boundaries that should keep the UI from recreating the old
row-template architecture.

The production UI should be a thin editor over explicit route data:

```text
draft form -> complete snapshot -> history -> validation -> feedback
```

It should not be a route engine.

## Production UI Responsibilities

The UI layer owns:

- editable draft state;
- local form completeness;
- stable option and candidate provider tables;
- explicit reset behavior when parent choices change;
- visual application of feedback markers;
- low-allocation draw behavior.

The UI layer does not own:

- route legality;
- room eligibility at a generated depth;
- force pressure;
- reward legality;
- reward bag depletion;
- runtime execution-plan interpretation.

If a control needs route context to decide whether a value is legal, that
answer should come from validation feedback, not from local draw code.

## Lib And Control Constraints

The planner UI is a hot path. Draw code should assume it may be called often
and should avoid table creation, option reshaping, or route validation during
draw.

Control rules:

- candidate value arrays and labels are stable objects owned by the form
  participant;
- hidden, color, and message arrays are mutable draw-state owned by the same
  participant;
- feedback mutates draw-state arrays during rebuild, not during draw;
- draw helpers read prepared state and call explicit mutators for user edits;
- mutators mark the smallest practical dirty scope;
- widget labels and IDs are stable and scoped so repeated leaf instances do not
  collide;
- tests can render text or no-imgui fallbacks without route validation.

Draw helpers may be shared, but they should not hide route state mutation. A
helper that changes draft data should do so through an explicit mutator passed
by the owning form.

## Folder Shape

The exact names can change, but the split should stay close to this:

```text
src/mods/ui/planner/
  state.lua          -- draft state, dirty flags, cached evaluation
  options.lua        -- shared stable option/catalog helpers
  widgets.lua        -- low-level dropdown/checkbox/status wrappers
  route_editor.lua   -- top-level route editor composition

src/mods/ui/forms/
  route.lua
  biome.lua
  room.lua
  generated_door.lua
  offer_point.lua
  reward_offer.lua
  payload/
    boon.lua
    devotion.lua
```

Form files own domain draft shape and local completion. Planner files own
application state, rebuild scheduling, and top-level composition.

Avoid rebuilding biome-sized route templates. Biomes should compose room,
generated-door, offer-point, and payload leaves.

## Dirty Rebuild Lifecycle

The draw loop should read the previous evaluation cache:

```text
draw cached form state
-> user mutates draft through explicit mutator
-> mutator marks dirty scope
-> next rebuild materializes complete snapshots if possible
-> pipeline builds history and validation feedback once
-> feedback updates provider draw-state arrays
-> draw reads updated provider state
```

No dropdown should run route validation for itself.

No incomplete form should be materialized into fake history. If completion
fails, the rebuild produces local completion feedback and stops before history.

## Candidate Provider Interface

Every candidate-owning form participant should expose the same kind of
provider:

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

The provider represents a stable candidate list. The validator evaluates the
candidate semantics while walking history. Feedback maps those results back to
the owning provider and mutates `hidden`, `colors`, and `messages`.

Use stable arrays whenever the domain does not change. Increment `version` only
when `values` or `labels` change, such as when a parent room kind changes the
valid child payload type.

## Parent-Child Reset Policy

Parent choices own child shape.

When a parent value changes, the parent form must reset children that no longer
match the selected shape:

- room key changes reset room-kind local state;
- exit count changes reset generated-door children;
- reward store changes reset reward candidates and payloads;
- reward type changes reset reward payload leaf state;
- N selected-pylon changes reset side-room children for unselected pylons.

Resetting should write explicit draft state. It should not rely on validation
or materialization to replace stale child data later.

## Debug Harness Boundary

The debug harness is a proof surface, not the production UI architecture.

It may exercise declarations, materialization, history, validation, and
feedback. It should not become the source of production layout patterns unless
the pattern also satisfies the form and hot-path constraints in this document.

The production UI can use the same domain services, but should own its own
planner state and candidate-provider objects.

## Implementation Slices

### Slice 1: Freeze The Debug Harness Role

Document and test the harness as a system exerciser. Do not add production
layout responsibilities to it.

Success check:

- harness can still create sample drafts and display validation output;
- no production widget code depends on harness-only state shape.

### Slice 2: Extract Catalog And Label Helpers

Create shared helpers for stable room, reward, route, and label lookup.

Success check:

- labels are resolved in one path;
- form participants do not build ad hoc option tables during draw.

### Slice 3: Build Low-Level Widgets

Add dropdown, checkbox, section, status, and marker wrappers that consume
candidate providers.

Success check:

- widgets support hidden values, invalid/warning colors, and hover/detail
  messages without route-specific code;
- repeated controls use stable scoped IDs.

### Slice 4: Add Planner State And Evaluation Cache

Create the production draft state container, dirty flags, and cached evaluation
result.

Success check:

- draw can run without rebuilding;
- mutation marks dirty state;
- rebuild can stop at form completion before history.

### Slice 5: Port One Linear Biome Editor

Start with F / Erebus. Render current room, generated next doors, selected
door, and reward offers through form participants.

Success check:

- F can emit a complete canonical snapshot;
- incomplete F produces local completion feedback;
- invalid F choices are colored by validation feedback.

### Slice 6: Add Generated-Door Offers

Make generated-door reward offers first-class UI children.

Success check:

- every generated door can carry an explicit offer point;
- selected door state stays on the generated door and acquired state stays on
  the reward offer;
- unselected door offers remain materialized for bag simulation.

### Slice 7: Add Room-Local Offer Points

Add shop, preboss, O wheel, and other room-local offer-point leaves after the
generated-door path is stable.

Success check:

- shop offers can be offered without being acquired;
- preboss shop/free-reward choice is represented as one room-local surface;
- O encounter reward offers do not require fake room rows.

### Slice 8: Add Payload Leaves

Implement payload forms for reward types that need structured detail, such as
Boon and Devotion.

Success check:

- reward type changes reset incompatible payload state;
- payload completion is local;
- reward legality remains validator-owned.

### Slice 9: Add Route Status And Error Horizon

Render route-level status from feedback, then grey or inactive downstream
content after the first blocking invalid.

Success check:

- route status uses feedback messages and translated locations;
- downstream inactive presentation does not hide the original error;
- enrichment colors appear only for valid configured scope.

### Slice 10: Add Performance Tests

Add allocation and draw-budget tests around the production editor surfaces.

Success check:

- opening dropdowns does not rebuild candidate arrays every frame;
- common draw paths stay within the same budget class as the old tested panels;
- dirty rebuild tests catch accidental validation inside draw.

### Slice 11: Expand Beyond F

Only after the F production editor proves the loop, add the other biome forms
in dependency order:

1. G/P/Q shared linear variants;
2. H generated-door batch and `FieldsCombat` leaf;
3. O room/encounter split and wheel offers;
4. I Clockwork generated-door batch;
5. N hub/pylon form.

Each addition should plug into the same form, provider, history, validation,
and feedback contracts.

## Explicit Non-Goals

Do not add these while building the first production UI:

- compact picked/other-door storage;
- Auto/Vanilla canonical values;
- route legality checks inside widgets;
- runtime execution-plan work;
- NPC/features;
- Chaos detours;
- reward bag simulation;
- compatibility shims for old row-template storage.

Convenience can come later as UI sugar, but the stored draft and canonical
snapshot should remain explicit.

## First Production Checkpoint

The first useful UI checkpoint is:

```text
F route prefix
+ production route editor state
+ generated-door form controls
+ generated-door reward offer controls
+ candidate feedback coloring
+ route status
+ draw/allocation tests
```

That checkpoint proves the control layer without broadening the model too
early.

## Supporting Docs

- `FORM_FEEDBACK_CONTRACT.md` owns form, leaf, address, and feedback contracts.
- `FORM_STORAGE_ROUNDTRIP.md` owns form-to-draft-to-storage serialization
  boundaries.
- `../validation/VALIDATION_MODEL.md` owns candidate evaluation and
  presentation policy.
- `../migration/IMPLEMENTATION_SEQUENCE.md` owns the full implementation order.
- `../model/CANONICAL_PLAN.md` owns the canonical route data shape.
