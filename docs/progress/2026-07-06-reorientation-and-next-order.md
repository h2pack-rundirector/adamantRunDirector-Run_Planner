# 2026-07-06 Reorientation And Next Order

## Purpose

This note reorients the fresh planner work after the first route spine,
feedback, timing, force-pressure rebuild, reward-offer validation, and reward
entry requirement query slices.

The stable design lane remains `docs/system_design/`. This file is a mutable
progress checkpoint: it records what the branch actually does now, how that
maps onto the intended implementation sequence, and the safest next order.

## Design Docs Re-Read

The current direction was checked against:

- `docs/system_design/migration/IMPLEMENTATION_SEQUENCE.md`
- `docs/system_design/model/CANONICAL_PLAN.md`
- `docs/system_design/model/CONFIGURED_SCOPE.md`
- `docs/system_design/model/DECLARATION_OWNERSHIP.md`
- `docs/system_design/model/REWARD_MODEL.md`
- `docs/system_design/model/REWARD_OFFERS.md`
- `docs/system_design/model/REWARD_LEGALITY_AND_BAGS.md`
- `docs/system_design/pipeline/TIMELINE_EVENTS.md`
- `docs/system_design/validation/VALIDATION_MODEL.md`
- `docs/system_design/validation/REQUIREMENTS_DSL.md`
- `docs/system_design/ui/FORM_FEEDBACK_CONTRACT.md`
- `docs/system_design/runtime/RUNTIME_BOUNDARY.md`
- `docs/system_design/biomes/LINEAR_BIOMES_MODEL.md`
- `docs/system_design/biomes/H_FIELDS_MODEL.md`
- `docs/system_design/biomes/O_OCEANUS_MODEL.md`
- `docs/system_design/biomes/I_TARTARUS_MODEL.md`
- `docs/system_design/biomes/N_EPHYRA_MODEL.md`

The important repeated constraints are:

- declarations own game facts;
- forms only decide local completeness;
- history materializes complete canonical facts;
- validation owns game legality and candidate policy;
- feedback maps validator output back to form participants;
- runtime consumes validated execution instructions only;
- incomplete or malformed upstream data should fail at the boundary, not be
  repaired downstream.

## Current Commit Position

Recent child commits:

- `382a6ce feat(declarations): add catalog foundation`
- `4c3eac6 feat(declarations): add profile validation`
- `17f8694 feat(forms): add route materialization`
- `02d4fb9 feat(history): build route ledger`
- `42b8dab feat(validation): add structural checks`
- `f1594e3 feat(pipeline): wire route evaluation`
- `56cfe9c feat(pipeline): add candidate feedback`
- `ed4ffd4 feat(feedback): apply candidate results`
- `f973a51 feat(validation): add timing eligibility`
- `602878e feat(validation): add room legality checks`
- `91cf02f feat(validation): add force pressure`
- `d03d212 feat(validation): validate reward offers`
- `4cc75c7 docs(validation): define force pressure model`
- `3e319dd fix(validation): bound cap checks by history time`
- `029b8c7 refactor(validation): remove legacy force pressure`
- `4c1fad6 feat(validation): rebuild force pressure`
- `70f4b4b feat(validation): add reward entry queries`

Recent shell pointer commits:

- `37be6be chore: point planner to route pipeline`
- `1d843cc chore: point planner to candidate feedback`
- `60d1379 chore: point planner to feedback bridge`
- `c41db94 chore: point planner to timing eligibility`
- `82c1ea2 chore: point planner to room legality`
- `b0d6103 chore: point planner to force pressure`
- `d973210 chore: point planner to reward offers`
- `15f8a1c chore: point planner to force cleanup`
- `d4af051 chore: point planner to force rebuild`
- `a71cede chore: point planner to reward queries`

## What Is Implemented

The branch has a working fresh planning spine for the F/Erebus test surface:

```text
declarations
-> form completion
-> canonical materialization
-> history ledger
-> route validation
-> selected findings and candidate results
-> candidate feedback application
```

Implemented declaration behavior:

- route order declarations for Underworld and Surface;
- implemented-biome reporting, currently only F;
- minimal concrete F room catalog;
- explicit `BiomeDepthWindow` force metadata for F forced rooms;
- room templates;
- reward primitives, counted bags, derived stores, shop profiles, and offer
  profiles;
- named requirement declaration validation.

Implemented form/materialization behavior:

- route drafts are checked for completion before canonical materialization;
- canonical plans use concrete room keys, generated doors, offer points,
  reward stores, reward types, acquisition flags, and payload tables;
- unresolved values such as `Auto`, `Vanilla`, `Major`, and `Minor` remain
  incomplete form state, not canonical history.

Implemented history behavior:

- physical room events;
- generated-door events;
- offer-point events;
- reward-offer events;
- selected reward acquisition events;
- terminal-biome completion events for `ClearedBiomes`;
- room/encounter/reward ledgers;
- normalized acquired loot types for loot-history queries;
- typed counters for run encounter depth, biome encounter depth, biome depth
  cache, room-history ordinal, and cleared biomes;
- event-bound history query helpers for acquired loot counts, cleared biomes,
  and pending store offers.

Implemented validation behavior:

- declared room existence;
- generated-door exit references;
- generated-door target existence;
- generated-door count versus declared exits;
- selected generated door continuity into the next entered room;
- terminal room placement and door suppression;
- generated target eligibility using `BiomeDepthCache` and
  `BiomeEncounterDepth`;
- per-run creation caps;
- exit-tag compatibility;
- batch-level force-pressure checks using unresolved force candidates, force
  starts, and force deadlines;
- generated-door reward offer domain checks:
  - offer point kind;
  - declared reward store or shop profile;
  - reward type membership in that store/profile;
  - generated target room offer-profile compatibility.
- generated-door reward entry requirement checks against counted bag entries;
- requirement evaluation for `LootTypeHistory`, `ClearedBiomes`, and the
  current empty pending-store form of `RequiredNotInStore`.

Implemented feedback behavior:

- `nextRoom` candidate records can be exported by providers;
- selected `nextRoom` and candidate `nextRoom` checks share the same local
  target legality functions, excluding force-as-local-legality;
- `nextRoom` candidate feedback can project force-pressure conflicts for the
  edited generated-door batch;
- candidate feedback can be applied back to matching provider versions;
- stale candidate results and missing providers are counted rather than
  silently applied.

## Current Phase Alignment

The branch has mostly satisfied the minimal Phase 3 spine from
`IMPLEMENTATION_SEQUENCE.md`:

```text
F declarations
+ complete F form snapshot
+ F history ledger
+ structural validation
+ candidate feedback
```

However, Phase 3 is not completely done because reward candidates are not yet
exported/evaluated, and the UI route controls are still skeletal rather than a
real route authoring surface.

Phase 4 has not started in substance. The generic linear model exists in docs,
but G/P/Q declarations and any shared linear builder abstraction are not yet
implemented.

Phase 5 has started across the first two layers. Generated-door reward offers
now validate the offer domain and selected RunProgress-style counted bag entry
requirements. Payload legality, reward candidates, shop acquisition timing,
room-local offer points, and batch rules are still deferred.

Phase 6 and later should remain blocked for now. H/O/I/N docs should guide
schema decisions, but their special mechanics depend on a more complete common
reward and room spine.

## Important Gaps

Requirement evaluation is still intentionally small. It now covers the timing
predicates and the first reward-history predicates needed by Hammer:

- `All`;
- `Any`;
- `Not`;
- `BiomeDepthCache`;
- `BiomeEncounterDepth`;
- `LootTypeHistory`;
- `ClearedBiomes`;
- `RequiredNotInStore` against the current empty pending-store ledger.

The next requirement expansions should be demand-driven. `UseRecord`,
`BiomeUseRecord`, `LootBiomeRecord`, spacing requirements, minimum exits, and
prior distinct god loot are still deferred.

Reward validation checks whether a source can ever offer a reward type and
whether a generated-door bag offer has at least one matching counted bag entry
whose requirements pass. This is still not bag depletion/refill simulation.

Reward candidate policy is not implemented. The only semantic candidate kind
is `nextRoom`.

Room-local offer points are not implemented. Current reward validation is
limited to generated-door offer points at `room.generate_next`, and selected
entry requirement validation is limited to reward bags rather than shop option
requirements.

Force pressure has been rebuilt for the current F surface from
`docs/system_design/validation/FORCE_PRESSURE_MODEL.md`. The generic physical
exit compatibility rule is implemented as "at least one compatible generated
exit." A future biome with mutually exclusive forced candidates may require an
exit matching pass.

The branch still has no execution-plan compiler and no runtime consumption of
the fresh history. This is correct for now.

## Recommended Next Order

### 1. Add Reward Payload Validation

Entry requirements can now query acquired loot history, so the next narrow
Phase 5 slice is payload legality for reward types that need it.

Likely first payload targets:

- Devotion source pair uniqueness;
- selected Devotion sources must have prior acquired god loot;
- Boon source payload completeness if the form starts materializing boon
  sources.

Payload completeness remains a form concern. Payload legality is validation.

### 2. Add Reward Candidate Export And Evaluation

After selected reward legality works, add candidate semantics for reward forms:

- `rewardType`;
- payload candidates such as devotion source;
- eventually `shopOption`.

Candidates should reuse the same rule functions as selected reward findings.
They should not trigger a separate validator walk per control.

### 3. Decide Whether To Complete Phase 3 UI Or Continue Model Work

At this point there will be a choice:

- build the real F route controls around the current form/candidate contracts;
- or continue deeper into Phase 5 source legality and Phase 4 linear
  declarations.

The safer default is to build enough UI to prove that feedback application and
candidate arrays are ergonomic before expanding many more declarations. The
reason is not visual polish; it is contract pressure on the form/feedback
boundary.

### 4. Generalize Linear Biomes

After reward legality and feedback semantics are stable on F, expand the
generic linear model:

- add more F room declarations if needed for coverage;
- then G/P/Q declarations;
- keep P indoor/outdoor as exit tags, not row groups;
- keep Q deterministic choices as structure metadata and generated doors, not
  a special route engine.

### 5. Extend The Reward Requirement Surface

Add more requirement predicates only when a selected validation or candidate
slice needs them.

Likely next predicates:

- `UseRecord`;
- `BiomeUseRecord`;
- `LootBiomeRecord`;
- `RequiredMinRoomsSinceEvent`;
- `RequiredMinExits`;
- prior distinct god loot sources for Devotion.

Keep `RequiredNotInStore` on the explicit pending-store ledger. It should start
blocking only when shop offer intervals are materialized into history.

### 6. Defer Reward Bag Simulation

Do not implement Phase 7 bag simulation until source-specific entry
requirements, offer timing, reward candidates, and at least one real linear
biome path are stable.

Bag simulation depends on:

- full offer timing;
- counted bag entries;
- eligibility filtering;
- batch grouping;
- acquisition history;
- refill behavior.

Implementing it too early would risk baking incomplete history semantics into
the simulator.

### 7. Defer Special Biomes And Runtime

H/O/I/N should remain design references until the common pieces exist:

- H needs `FieldsCageBatch` and a validator-visible
  `FieldsMaxDoorsRolled` counter;
- O needs `ShipCombat` room-local encounter and wheel offer points;
- I needs `ClockworkDoorBatch`, explicit Clockwork biome state, and
  `ClockworkGoal` structural reward offers;
- N needs hub selection mode, pylon materializers, and hub reward batches.

Runtime should wait until validated history can compile into concrete room and
reward instructions without runtime re-solving legality.

## Completed Reward Query Slice

Implemented in the current working checkpoint:

- acquired reward events carry normalized `acquiredLootType`;
- terminal biomes emit `biome.complete`;
- history query helpers expose event-bound acquired loot counts,
  `ClearedBiomes`, and pending store offers;
- `requirements.evaluate` handles `LootTypeHistory`, `ClearedBiomes`, and
  `RequiredNotInStore`;
- generated-door reward validation checks matching counted bag entry
  requirements;
- Hammer tests cover first Hammer, blocked second Hammer before cleared biomes,
  and allowed late Hammer with one prior Hammer plus cleared biomes.

## Immediate Next Slice Recommendation

The next implementation slice should be:

```text
Reward payload validation
```

Concrete scope:

- define the first payload contract for reward offers that need payload;
- validate Devotion source pair uniqueness;
- validate selected Devotion sources against prior acquired god loot once the
  god loot-source representation is declared;
- keep payload completeness in forms and payload legality in validation.

This keeps Phase 5 moving on selected reward legality before broadening into
reward candidates or bag simulation.

## Validation Baseline

Latest known clean baseline for this checkpoint:

```text
lua tests/all.lua
luacheck src tests
git diff --check
lua tests/smoke.lua
```

Observed results:

- child tests: 67 passed;
- child luacheck: 0 warnings / 0 errors;
- child diff check: passed;
- shell smoke: passed.
