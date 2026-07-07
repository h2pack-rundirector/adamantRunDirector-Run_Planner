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
- `ce98f2a feat(planner): evaluate reward candidates`
- `0953223 feat(validation): expand reward requirements`

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
- `ef3c539 chore: point planner to reward candidates`
- `639a074 chore: point planner to reward requirements`

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
- room-local reward offer domain checks against the current room's offer
  profile;
- room-local shop option entry requirement checks;
- requirement evaluation for `LootTypeHistory`, `ClearedBiomes`, and bounded
  pending-store `RequiredNotInStore`.

Implemented feedback behavior:

- `nextRoom` candidate records can be exported by providers;
- selected `nextRoom` and candidate `nextRoom` checks share the same local
  target legality functions, excluding force-as-local-legality;
- `nextRoom` candidate feedback can project force-pressure conflicts for the
  edited generated-door batch;
- candidate feedback can be applied back to matching provider versions;
- stale candidate results and missing providers are counted rather than
  silently applied.

Implemented UI/model loop behavior:

- `mods/ui.lua` now creates a minimal F debug harness when the module system
  builds UI services;
- the harness exposes editable room, selected-door, generated-door target, and
  first generated-door reward offer fields;
- every harness evaluation attaches real `nextRoom` candidate providers,
  evaluates the mutable draft through `mods/pipeline/route.lua`, and applies
  candidate feedback back to those providers;
- the harness is deliberately raw and temporary. It exists to test the
  draft/history/validation/feedback loop in game, not to settle final planner
  layout, biome tabs, or control templates.

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

Phase 3 is complete enough for the current F/data-loop purpose: selected
validation and candidate feedback are both wired. The route authoring surface
is still only a minimal debug harness rather than final route controls.

Phase 4 has not started in substance. The generic linear model exists in docs,
but G/P/Q declarations and any shared linear builder abstraction are not yet
implemented.

Phase 5 has started across selected legality, payload legality, and reward
candidate evaluation. Generated-door reward offers validate offer domain,
selected RunProgress-style counted bag entry requirements, Devotion payloads,
the first source-specific Devotion entry requirements, and room-local shop
offer timing. Batch rules and bag simulation are still deferred.

Phase 6 and later should remain blocked for now. H/O/I/N docs should guide
schema decisions, but their special mechanics depend on a more complete common
reward and room spine.

## Important Gaps

Requirement evaluation is still intentionally small. It now covers the timing
predicates and the first reward-history predicates needed by Hammer and
Devotion source history:

- `All`;
- `Any`;
- `Not`;
- `EncounterDepth`;
- `BiomeDepthCache`;
- `BiomeEncounterDepth`;
- `LootTypeHistory`;
- `ClearedBiomes`;
- `PriorDistinctLootSources`;
- `CurrentLootSourcesSeen`;
- `UniquePayloadValues`;
- `RequiredNotInStore` against bounded pending shop offers;
- `RequiredMinRoomsSinceEvent`;
- `RequiredMinExits`.

The next requirement expansions should be demand-driven. `UseRecord`,
`BiomeUseRecord`, `LootBiomeRecord`, and broader source/use-history predicates
are still deferred.

Reward validation checks whether a source can ever offer a reward type and
whether a generated-door bag offer has at least one matching counted bag entry
whose requirements pass. It also validates the first payload rules:

- declared boon source keys when a Boon offer carries a source payload;
- Devotion source pairs are declared, distinct, and present in prior acquired
  loot source history;
- Devotion entry requirements for run encounter depth, biome encounter depth,
  rooms since prior Devotion acquisition on `RoomHistoryOrdinal`, and minimum
  generated exits;
- room-local shop option requirements and generated reward blocking through
  bounded pending shop offers.

This is still not bag depletion/refill simulation.

Reward candidate policy is implemented for `nextRoom`, offer `rewardType`, and
Devotion payload source options. Additional reward candidate kinds remain
demand-driven.

Room-local offer points are implemented in the canonical form, history builder,
candidate feedback addressing, and reward validation. They emit at
`room.offer_points`; bought room-local offers acquire after `room.generate_next`
so same-room generated rewards cannot see the bought loot too early. The
minimal debug harness does not yet expose room-local offer point controls.

Force pressure has been rebuilt for the current F surface from
`docs/system_design/validation/FORCE_PRESSURE_MODEL.md`. The generic physical
exit compatibility rule is implemented as "at least one compatible generated
exit." A future biome with mutually exclusive forced candidates may require an
exit matching pass.

The branch still has no execution-plan compiler and no runtime consumption of
the fresh history. This is correct for now.

## Recommended Next Order

### 1. Reward Payload Validation Completed

Entry requirements can now query acquired loot-source history, and the first
Phase 5 payload legality slice is implemented.

Completed payload targets:

- Devotion source pair uniqueness;
- selected Devotion sources must have prior acquired god loot;
- declared Boon source keys when the form materializes a Boon source payload.

Payload completeness remains a form concern. Payload legality is validation.

### 2. Reward Candidate Export And Evaluation Completed

Reward candidate semantics now cover:

- offer-owned `rewardType`;
- Devotion source payload choices;
- structural `nextRoom` candidates in the structural validator.

Candidates reuse selected-rule helpers by projecting the edited offer/payload
through selected legality and translating findings back to provider results.

### 3. Keep The Minimal UI Harness Active While Continuing Model Work

The chosen near-term path is a minimal UI harness before the dedicated UI pass:

- keep the debug harness wired to the real pipeline;
- use it for in-game route/model testing as more selected legality is added;
- avoid investing in final biome panels and control templates until the F
  reward legality surface is less volatile.

The reason is contract pressure on the form/feedback boundary, not visual
polish. Any issue found in the harness should be fixed in the data/model
contract first unless it is clearly a drawing-only problem.

### 4. Generalize Linear Biomes

After reward legality and feedback semantics are stable on F, expand the
generic linear model:

- add more F room declarations if needed for coverage;
- then G/P/Q declarations;
- keep P indoor/outdoor as exit tags, not row groups;
- keep Q deterministic choices as structure metadata and generated doors, not
  a special route engine.

### 5. Reward Requirement Surface Expanded

This checkpoint adds the next predicates needed by Devotion selected legality
and reward candidates:

- `EncounterDepth`;
- `RequiredMinRoomsSinceEvent`;
- `RequiredMinExits`.

Continue adding more requirement predicates only when a selected validation or
candidate slice needs them. Likely deferred predicates:

- `UseRecord`;
- `BiomeUseRecord`;
- `LootBiomeRecord`.

`RequiredNotInStore` now reads bounded pending shop offers. Future predicates
should keep following that pattern: explicit game-language ledgers first,
reward-type shortcuts last.

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

## Completed Reward Payload Slice

Implemented in the current working checkpoint:

- declared Olympian boon source keys/labels under the reward catalog;
- RunProgress Devotion is present as a counted bag entry with
  `DevotionLootRequirements`;
- form completion requires Devotion payloads to provide exactly two concrete
  source keys;
- reward validation rejects unknown Boon/Devotion payload sources;
- reward validation rejects duplicate Devotion source pairs;
- reward validation rejects Devotion source pairs whose selected sources were
  not acquired earlier in loot history;
- the minimal debug harness exposes Boon and Devotion source controls so the
  payload loop can be tested in game.

## Completed Reward Candidate Slice

Implemented in the current working checkpoint:

- form export now includes offer-owned candidate providers using structured
  reward offer addresses;
- candidate feedback application can route results back to offer-owned
  providers, not only generated-door providers;
- reward validation evaluates `rewardType` candidate semantics by projecting
  the candidate offer through selected reward-domain, entry-requirement, and
  payload-legality rules;
- reward validation evaluates `devotionSource` candidate semantics by
  projecting the selected Devotion payload source pair through payload legality;
- structural validation owns `nextRoom` candidates while reward validation
  owns reward candidate kinds, keeping unknown reward candidate semantics as
  contract failures;
- the minimal debug harness attaches reward-type candidate providers and
  Devotion source candidate providers so advisory reward feedback can be tested
  in game.

## Completed Reward Requirement Surface Slice

Implemented in the current working checkpoint:

- Devotion entry requirements are now an `All` block covering run encounter
  depth, biome encounter depth, prior distinct god sources, rooms since prior
  Devotion acquisition, and minimum generated exits;
- reward validation passes event-bound counters into requirement evaluation;
- history query helpers expose event-bound generated-door counts and
  `RoomHistoryOrdinal` event-distance checks;
- reward offer and acquisition events now carry the counter snapshot needed by
  entry requirements and spacing checks;
- tests cover early Devotion encounter-depth failure, recent-Devotion spacing
  failure, one-exit Devotion failure, and a valid fully qualified Devotion.

## Completed Room-Local Reward Timing Slice

Implemented in the current working checkpoint:

- canonical room nodes can carry `offerPoints` in addition to generated-door
  offer points;
- room-local offer addresses use `offerPointIndex` and participate in
  candidate export/feedback;
- history emits room-local `offer_point.emit` and `reward.offer` events at
  `room.offer_points`;
- bought room-local offers emit `reward.acquire` after `room.generate_next`
  and before `room.commit`, preserving same-room next-reward timing;
- shop offers populate bounded pending-store records that expire after the
  current room's next-door generation;
- reward validation checks room-local offer domains against the current room's
  offer profile and validates matching shop option requirements;
- `RequiredNotInStore` now observes active pending shop offers instead of an
  always-empty placeholder ledger.

## Completed Minimal Room-Offer Harness Slice

Implemented in the current working checkpoint:

- the debug harness automatically creates one raw room-local offer point when
  a mutable room becomes an F shop or preboss room;
- room-local offers use the same store, reward-type, acquired-state, and
  candidate-provider path as generated-door reward offers;
- room-local reward-type candidate feedback is attached before each real
  pipeline evaluation;
- the draw fallback shows the room-offer surface so it is visible in the
  current in-game debug loop;
- tests cover shop-room offer control creation and pending-store feedback from
  a shop offer blocking a same-room generated Hammer reward.

## Completed UI Foundation Extraction Slice

Implemented in the current working checkpoint:

- `src/mods/ui/planner/options.lua` now owns catalog-derived option lists,
  reward/store/source labels, default payloads, default offers, and simple
  room materializers used by editable F draft state;
- `src/mods/ui/planner/state.lua` now owns the mutable F draft, dirty
  evaluation cache, candidate-provider attachment, provider-version handling,
  and draft mutators;
- the debug harness now delegates planner state and provider setup to the
  production-facing state module and keeps only debug-specific drawing/status
  output;
- focused state coverage verifies that cached evaluation is reused until a
  mutator marks the draft dirty.

Current boundary:

- this is still an F-only authoring state and rough debug layout;
- generated selected-door options are still built by the harness draw helper;
- production widgets and final biome panels have not started.

## Immediate Next Slice Recommendation

The next implementation slice should be:

```text
Build low-level planner widgets
```

Concrete scope:

- add dropdown, checkbox, section/status, and marker wrappers that consume
  stable candidate provider state;
- keep route validation out of draw helpers;
- preserve text/no-imgui fallback rendering for tests and in-game debug use;
- keep the debug harness active as the proof surface while production F editor
  pieces come online.

After the widgets exist, port the F room/generated-door/reward controls onto
those widgets before expanding the linear declaration surface to G/P/Q.

## Validation Baseline

Latest known clean baseline for this checkpoint:

```text
lua tests/all.lua
luacheck src tests
git diff --check
lua tests/smoke.lua
```

Observed results:

- child tests: 98 passed;
- child luacheck: 0 warnings / 0 errors;
- child diff check: passed;
- shell smoke: passed.
