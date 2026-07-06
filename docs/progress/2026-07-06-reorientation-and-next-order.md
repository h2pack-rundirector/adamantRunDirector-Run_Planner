# 2026-07-06 Reorientation And Next Order

## Purpose

This note reorients the fresh planner work after the first route spine,
feedback, timing, force-pressure rebuild, and reward-offer validation slices.

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

Recent shell pointer commits:

- `37be6be chore: point planner to route pipeline`
- `1d843cc chore: point planner to candidate feedback`
- `60d1379 chore: point planner to feedback bridge`
- `c41db94 chore: point planner to timing eligibility`
- `82c1ea2 chore: point planner to room legality`
- `b0d6103 chore: point planner to force pressure`
- `d973210 chore: point planner to reward offers`
- `15f8a1c chore: point planner to force cleanup`

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
- room/encounter/reward ledgers;
- typed counters for run encounter depth, biome encounter depth, biome depth
  cache, and room-history ordinal.

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

Phase 5 has started but only at the first layer. Generated-door reward offers
now validate the offer domain. Source-specific reward entry requirements,
payload legality, shop acquisition timing, room-local offer points, and batch
rules are still deferred.

Phase 6 and later should remain blocked for now. H/O/I/N docs should guide
schema decisions, but their special mechanics depend on a more complete common
reward and room spine.

## Important Gaps

Requirement evaluation is intentionally small today. The declaration catalog
already contains named Hammer requirements using predicates such as
`RequiredNotInStore`, `LootTypeHistory`, and `ClearedBiomes`, but
`src/mods/validation/requirements.lua` currently evaluates only:

- `All`;
- `Any`;
- `Not`;
- `BiomeDepthCache`;
- `BiomeEncounterDepth`.

That means the next reward legality step must add real query support before
entry requirements can honestly run.

Reward validation currently checks whether a source can ever offer a reward
type. It does not yet check whether a counted bag entry with satisfied
requirements exists at that offer point.

Reward candidate policy is not implemented. The only semantic candidate kind
is `nextRoom`.

Room-local offer points are not implemented. Current reward validation is
limited to generated-door offer points at `room.generate_next`.

Force pressure has been rebuilt for the current F surface from
`docs/system_design/validation/FORCE_PRESSURE_MODEL.md`. The generic physical
exit compatibility rule is implemented as "at least one compatible generated
exit." A future biome with mutually exclusive forced candidates may require an
exit matching pass.

The branch still has no execution-plan compiler and no runtime consumption of
the fresh history. This is correct for now.

## Recommended Next Order

### 1. Finish The Reward Legality Substrate

Build the history query support needed by source-specific reward entry
requirements before adding bag simulation.

Suggested first predicates:

- `LootTypeHistory`;
- `ClearedBiomes`;
- `RequiredNotInStore` as an explicit unsupported or empty-state query until
  shop offer intervals exist;
- possibly `UseRecord` and `BiomeUseRecord` only if needed by the first test
  reward declarations.

Keep the first slice focused on generated-door reward offers and existing
`RunProgress` entries. Do not broaden into shops, O wheels, H cages, or N hub
rewards yet.

### 2. Add Selected Reward Entry Requirement Validation

Once query support exists, validate that a configured generated-door offer has
at least one matching counted bag/shop entry whose requirements pass at that
offer point.

This should distinguish:

- `reward_type_not_in_store`: domain failure;
- entry requirement failure such as `early_hammer_requires_no_prior_hammer`;
- unsupported/profile-dependent requirement failure;
- future bag-unavailable failure.

This is Phase 5 source legality, not Phase 7 bag simulation.

### 3. Add Reward Payload Validation

After entry requirements can query acquired loot, add payload legality for
reward types that need it.

Likely first payload targets:

- Devotion source pair uniqueness;
- selected Devotion sources must have prior acquired god loot;
- Boon source payload completeness if the form starts materializing boon
  sources.

Payload completeness remains a form concern. Payload legality is validation.

### 4. Add Reward Candidate Export And Evaluation

After selected reward legality works, add candidate semantics for reward forms:

- `rewardType`;
- payload candidates such as devotion source;
- eventually `shopOption`.

Candidates should reuse the same rule functions as selected reward findings.
They should not trigger a separate validator walk per control.

### 5. Decide Whether To Complete Phase 3 UI Or Continue Model Work

At this point there will be a choice:

- build the real F route controls around the current form/candidate contracts;
- or continue deeper into Phase 5 source legality and Phase 4 linear
  declarations.

The safer default is to build enough UI to prove that feedback application and
candidate arrays are ergonomic before expanding many more declarations. The
reason is not visual polish; it is contract pressure on the form/feedback
boundary.

### 6. Generalize Linear Biomes

After reward legality and feedback semantics are stable on F, expand the
generic linear model:

- add more F room declarations if needed for coverage;
- then G/P/Q declarations;
- keep P indoor/outdoor as exit tags, not row groups;
- keep Q deterministic choices as structure metadata and generated doors, not
  a special route engine.

### 7. Defer Reward Bag Simulation

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

### 8. Defer Special Biomes And Runtime

H/O/I/N should remain design references until the common pieces exist:

- H needs `FieldsCageBatch` and a validator-visible
  `FieldsMaxDoorsRolled` counter;
- O needs `ShipCombat` room-local encounter and wheel offer points;
- I needs `ClockworkDoorBatch`, explicit Clockwork biome state, and
  `ClockworkGoal` structural reward offers;
- N needs hub selection mode, pylon materializers, and hub reward batches.

Runtime should wait until validated history can compile into concrete room and
reward instructions without runtime re-solving legality.

## Immediate Next Slice Recommendation

The next implementation slice should be:

```text
Reward entry requirement query substrate
```

Concrete scope:

- add history query helpers for acquired loot counts and route counters;
- extend requirement evaluation beyond timing counters with at least
  `LootTypeHistory` and `ClearedBiomes`;
- add tests proving early/late Hammer requirements fail/pass from selected
  generated-door reward offers;
- keep `RequiredNotInStore` explicit and honest if shop pending-offer
  intervals are not implemented yet.

This is the narrowest slice that moves Phase 5 forward without jumping to bag
simulation.

## Validation Baseline

Latest known clean baseline for this checkpoint:

```text
lua tests/all.lua
luacheck src tests
git diff --check
lua tests/smoke.lua
```

Observed results:

- child tests: 64 passed;
- child luacheck: 0 warnings / 0 errors;
- child diff check: passed;
- shell smoke: not rerun for this child-only checkpoint.
