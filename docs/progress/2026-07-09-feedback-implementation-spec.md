# 2026-07-09 Feedback Implementation Spec

## Progress Log

Newest entries should be added at the top of this section.

### 2026-07-09 - Slice 5 Completion Feedback Pass Started

Incomplete local form feedback now stays local instead of being labeled as a
route blocker or driving the downstream inactive horizon.

Implemented behavior:

- `mods/ui/forms/feedback.lua` exposes route-blocker lookups that ignore
  `severity = "incomplete"` findings;
- room, generated-door, generated-offer, and room-offer forms continue to draw
  incomplete findings through their local participant feedback labels;
- F panel downstream inactive presentation keys off the first non-incomplete
  route blocker, not any completion finding;
- F panel tests cover unresolved reward type and Devotion source completion
  feedback, no history for incomplete state, and no candidate results.

### 2026-07-09 - Slice 4 Downstream Inactive Presentation Started

Downstream inactive presentation is now explicit at the F panel boundary, where
the first-route-issue room already determines whether later room forms should
be inactive.

Implemented behavior:

- `mods/ui/biomes/f_erebus_panel.lua` emits one muted marker before the first
  downstream disabled room;
- inactive scoping still begins strictly after `status.firstIssue.address.roomIndex`,
  so the participant that owns the first issue remains active and visible;
- F panel tests assert no disabled scope exists for the valid default route;
- F panel tests assert the blocker text renders before the inactive marker and
  that the disabled scope begins before the downstream room.

### 2026-07-09 - Slice 3 Candidate Feedback Regression Tests Started

Candidate feedback behavior is being locked with regression tests around the
existing provider and widget boundaries rather than changing the validation
or draw model.

Implemented behavior:

- widget coverage now asserts that a selected invalid dropdown value uses its
  provider color and hover message in the closed preview;
- existing widget coverage continues to prove hidden candidates are omitted
  while visible invalid candidates remain colored and tooltip-backed;
- F panel coverage opens real rebuilt participant dropdowns and verifies
  candidate feedback messages reach the UI after `state.ensureEvaluation()`;
- debug-harness tests remain the end-to-end route/candidate feedback coverage.

### 2026-07-09 - Slice 2 Route Status Presentation Started

Route-level status presentation now keeps the existing `widgets.status(...)`
entry point but uses the same shared presentation color vocabulary as local
form feedback.

Implemented behavior:

- `mods/ui/planner/presentation_colors.lua` centralizes invalid, incomplete,
  warning, muted, blocker, and valid colors for planner feedback presentation;
- `mods/ui/forms/feedback_presentation.lua` now reads those shared colors
  instead of owning duplicate constants;
- route status colors the state line and first issue line while preserving the
  existing summary strings and translated location labels;
- focused widget tests cover color style scopes, translated first-issue
  locations, and valid status without enrichment coloring.

### 2026-07-09 - Slice 1 Feedback Presentation Started

Feedback rendering is moving behind a planner-owned presentation helper while
keeping validation, candidate feedback application, and provider ownership
unchanged.

Implemented behavior:

- `mods/ui/forms/feedback_presentation.lua` owns local feedback text formatting
  and severity colors;
- `mods/ui/planner/widgets.lua` exposes a generic colored text helper for
  presentation modules;
- room, generated-door, generated-offer, and room-offer leaves route their
  existing feedback findings through the centralized presentation helper;
- focused fake-ImGui tests cover colored blocker rendering and incomplete field
  formatting.

### 2026-07-09 - Spec Created From Live Code Review

Current code already has the validation and candidate-feedback spine needed for
UI feedback coloring. The next work should focus on presentation and tests, not
on rebuilding validation or provider ownership.

Observed current state:

- `mods/ui/planner/evaluation.lua` already materializes the draft, prepares
  participant providers, evaluates the route pipeline, and applies candidate
  feedback during rebuild;
- `mods/forms/candidate_provider.lua` already owns stable values, labels,
  hidden, colors, and messages arrays;
- `mods/ui/planner/widgets.lua` already renders dropdown option colors,
  hidden choices, preview colors, and hover messages;
- room, generated-door, generated-offer, and room-offer leaves already query
  participant addresses and display route blocker text;
- presentation is still rough and scattered through leaves, mostly as plain
  `widgets.feedback(...)` text.

## Goal

Make route, candidate, and participant feedback readable in the F/Erebus UI
without moving legality decisions into draw code.

The UI should answer:

- which route choice is blocking the current plan;
- which local participant has feedback;
- which dropdown candidates are invalid, hidden, or warning-colored;
- which downstream rooms are inactive because an earlier route blocker exists.

The UI should not answer route legality locally. Validation and candidate
feedback remain the source of truth.

## Current Code Map

Core rebuild path:

- `mods/ui/planner/state.lua` owns draft mutation, dirty state, and cached
  evaluation access.
- `mods/ui/planner/evaluation.lua` rebuilds materialization, provider
  preparation, validation, and candidate feedback.
- `mods/ui/planner/provider_preparation.lua` binds candidate providers to form
  participants.
- `mods/feedback/candidates.lua` maps route candidate results back to
  participant providers.

Presentation path:

- `mods/ui/planner/widgets.lua` owns low-level planner widgets.
- `mods/ui/forms/feedback.lua` looks up feedback by participant address.
- `mods/ui/forms/room.lua` draws room identity and room-level feedback.
- `mods/ui/forms/generated_door.lua` draws generated-door target feedback.
- `mods/ui/forms/reward_offer.lua` draws generated-door reward feedback.
- `mods/ui/forms/room_offer.lua` draws room-local reward feedback.
- `mods/ui/biomes/f_erebus_panel.lua` draws F rooms and disables downstream
  rooms after the first blocking issue.
- `mods/ui/planner/route_shell.lua` draws top-level route status.

Existing tests:

- `tests/feedback/TestCandidateFeedback.lua` proves candidate feedback mutates
  providers and participant providers can replace draft bridges.
- `tests/ui/TestPlannerWidgets.lua` proves dropdown colors, hidden values,
  hover messages, disabled scopes, and status text.
- `tests/ui/TestFErebusPanel.lua` proves F panel route blockers, downstream
  inactive scope, form composition, and participant provider reads.
- `tests/ui/TestDebugHarness.lua` proves the end-to-end debug surface receives
  candidate messages from validation.

## Design Rules

Keep these rules intact while implementing feedback presentation:

- Draw code reads prepared evaluation/provider state; it does not run route
  validation.
- Candidate providers own mutable draw-state arrays for hidden, colors, and
  messages.
- Feedback addresses target form participants, not inner widget aliases.
- Leaf forms decide how participant feedback appears near their local controls.
- Downstream inactive presentation should not hide the original blocking issue.
- Incomplete local fields are completion feedback, not route-legality feedback.
- Enrichment colors are deferred until the configured scope is valid.
- `PlannerDraft` storage must not serialize feedback, candidate, or history
  data.

## Feedback Presentation Model

Use one small planner-owned presentation helper rather than repeating string and
color policy in every leaf.

Target module:

```text
src/mods/ui/forms/feedback_presentation.lua
```

Responsibilities:

- classify findings as route blocker, local feedback, or secondary feedback;
- expose stable presentation colors for invalid, incomplete, warning, muted,
  and normal text;
- format compact feedback text from `code`, `message`, `field`, and translated
  location when available;
- render a local marker using planner widgets without knowing route legality;
- return no-op output when feedback is absent.

Non-responsibilities:

- candidate result application;
- dropdown candidate coloring;
- route validation;
- history building;
- storage persistence.

## Implementation Slices

### Slice 1: Centralize Feedback Presentation

Create a small presentation helper and replace direct `widgets.feedback(...)`
calls in leaves with it.

Expected changes:

- add `mods/ui/forms/feedback_presentation.lua`;
- add widget support for colored inline feedback if the existing widget helpers
  are too primitive;
- keep route blocker and local feedback labels stable enough for tests;
- preserve the current address lookup through `mods/ui/forms/feedback.lua`.

Acceptance checks:

- room, generated-door, generated-offer, and room-offer feedback still render;
- the first blocker is visually distinct from secondary local feedback;
- no form starts computing validation locally.

### Slice 2: Route Status Presentation

Tighten top-level route status so it surfaces the most useful invalid state
without flooding the panel.

Expected changes:

- keep `widgets.status(...)` as the route-status entry point;
- add consistent invalid/incomplete/valid text coloring;
- keep translated location labels through `state.feedbackLocationLabel`;
- keep summary counts for feedback and candidate results.

Acceptance checks:

- route shell and F panel status remain stable in fake-ImGui tests;
- invalid route status highlights `status.firstIssue`;
- valid status does not show enrichment colors yet.

### Slice 3: Candidate Feedback Regression Tests

The candidate path already works; this slice should lock it against regressions
while presentation code changes.

Expected changes:

- add/extend widget tests for selected invalid dropdown preview color and
  tooltip;
- add F panel tests proving participant provider messages remain visible after
  a route rebuild;
- keep debug-harness candidate feedback tests as end-to-end coverage.

Acceptance checks:

- hidden candidates remain hidden;
- invalid visible candidates are colored and tooltip-backed;
- selected invalid values show invalid preview state.

### Slice 4: Downstream Inactive Presentation

Downstream rooms are already disabled after the first blocking issue. This slice
should make that behavior intentional and test-visible.

Expected changes:

- keep `f_erebus_panel.lua` as the owner of downstream room inactive scope;
- optionally add a muted marker before the first disabled downstream room;
- avoid disabling or hiding the room that owns the first issue.

Acceptance checks:

- exactly the downstream rooms after `firstIssue.address.roomIndex` are
  disabled;
- the first issue remains visible at the owning participant;
- no disabled scope is emitted for a valid route.

### Slice 5: Completion Feedback Pass

Only after route feedback presentation is stable, make incomplete local form
feedback more readable.

Expected changes:

- use existing completion findings from the pipeline;
- show incomplete field feedback near the relevant participant;
- do not materialize incomplete rooms into history for feedback.

Acceptance checks:

- incomplete reward type/source choices render local feedback;
- history remains absent for incomplete biome state;
- candidate coloring still comes only from candidate results.

## First Commit Recommendation

Start with Slice 1 only.

The first commit should not change validation, provider preparation, or route
pipeline behavior. It should be a UI presentation refactor with focused widget
and F panel tests.

Suggested commit scope:

```text
refactor(ui): centralize feedback presentation
```

Files likely touched:

- `src/mods/ui/forms/feedback_presentation.lua`
- `src/mods/ui/planner/widgets.lua`
- `src/mods/ui/forms/room.lua`
- `src/mods/ui/forms/generated_door.lua`
- `src/mods/ui/forms/reward_offer.lua`
- `src/mods/ui/forms/room_offer.lua`
- `tests/ui/TestPlannerWidgets.lua`
- `tests/ui/TestFErebusPanel.lua`
- this progress spec

## Validation

For each slice, run:

```text
lua tests/all.lua
luacheck src tests
git diff --check
```

Add allocation/performance checks before broadening feedback work beyond
presentation if a slice starts rebuilding provider arrays or allocating new
tables during draw.

## Open Questions

- Whether feedback colors should live in `widgets.lua` or a separate
  `feedback_presentation.lua` palette. Prefer the presentation helper unless
  the color is generic widget behavior.
- Whether completion feedback should use the same visual marker as invalid
  route feedback. Prefer different severity labels/colors so incomplete local
  shape does not look like route illegality.
- Whether downstream inactive text should be visible as an explicit marker.
  Prefer one concise marker if tests show users cannot tell why rooms are
  disabled.
