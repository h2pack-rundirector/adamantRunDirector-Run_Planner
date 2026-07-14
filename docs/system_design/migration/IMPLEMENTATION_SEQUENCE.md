# Implementation Sequence

## Purpose

This document orders the fresh-start implementation work by dependency, not by
surface area. The goal is to build one coherent route spine first, then add
biome-specific leaves and reward-bag precision without reintroducing the old
row-based architecture.

This is not a release plan. It is the order that should keep the data model,
controls, history, validation, feedback, and runtime boundaries aligned while the
fresh implementation is built.

## Ordering Rules

Use these rules when deciding whether a slice is ready:

- declarations define game facts before controls render them;
- Biome Plan controls produce complete canonical snapshots before history
  consumes them;
- history materializes game events before validation evaluates legality;
- validation owns game legality and candidate policy;
- feedback translates validator output back to semantic control owners;
- runtime consumes validated execution plans only;
- no layer should invent fallback rooms, fallback rewards, or guessed defaults.

If a slice needs a fallback to compensate for missing upstream data, the
upstream contract is not ready.

## Phase 0: Fresh Skeleton And Guardrails

Create the fresh-start module skeleton and test harness before porting behavior.

Deliverables:

- fresh module entry points separated from the old row-based route engine;
- test fixtures for declaration parsing, Biome Plan snapshots, history output, and
  validation output;
- invariant helpers that fail loudly for malformed internal contracts;
- docs linked from the implementation work area.

Do not implement runtime hooks in this phase.

Success check:

- an empty fresh route can load, run tests, and report unsupported/incomplete
  scope without touching the old execution path.

## Phase 1: Declaration Foundation

Build the declaration layer that all later phases consume.

Deliverables:

- route order declarations for Underworld and Surface;
- concrete room catalogs keyed by real game room keys;
- room metadata for eligibility, force windows, terminal/preboss state,
  encounter sequence, reward surfaces, and structured exits;
- reward primitives, stores, shop profiles, and counted bag definitions;
- explicit requirement declarations using the fresh requirements DSL shape.

Start with enough declarations for one simple linear biome, then expand. The
schema must support the full target model before every biome is authored.

Do not build UI grouping as storage truth. Grouping is derived from room
metadata and labels.

Success check:

- declaration tests can load the route order, room catalogs, reward catalogs,
  and requirements without consulting controls or history.

## Phase 2: Biome Plan Controls And Canonical Snapshots

Build the occurrence/control contract before building the history walker.

Deliverables:

- one Lib control per declared route-biome occurrence;
- normalized topology storage with stable `nodeId` occurrence identity;
- cached nested node and outgoing-batch control interfaces;
- common candidate-provider interface with stable values and mutable
  hidden/color/message arrays;
- semantic source plus topology location for rooms, generated doors, reward
  offers, payloads, and room-template local state;
- canonical snapshot emission only after local completion succeeds;
- no Auto/Vanilla/unknown values in complete snapshots.

This phase should not decide whether a completed choice is legal in the game.
It only decides whether the controls have enough concrete data to build history.

Success check:

- an incomplete nested control stops at local completion feedback;
- a complete Biome Plan emits concrete room, door, reward, and payload keys
  without
  defaulting blanks to the first option.

## Phase 3: First Vertical Slice: One Linear Biome

Use one simple linear biome, preferably F / Erebus, to prove the full spine.

Deliverables:

- concrete F room declarations sufficient for a configured prefix of one biome;
- Biome Plan UI for current room, generated next doors, selected door, and reward
  offers;
- history builder for physical rooms, generated doors, reward offer points,
  acquired loot, lifecycle counters, and source addresses;
- structural validator for room existence, room eligibility, force pressure,
  max creations, structured exits, and terminal/preboss legality;
- feedback routing that colors room and reward candidates and emits route
  status messages.

Keep rewards at store/domain legality first. Do not implement full bag
depletion in this phase.

Success check:

- F can be configured as a complete route prefix;
- invalid room choices are reported by validation, not by control heuristics;
- candidate colors come from validator feedback;
- golden history tests show the expected room lifecycle phases.

## Phase 4: Common Linear Engine

Generalize the F slice across linear biomes before adding special combat leaves.

Deliverables:

- shared linear stream builder for F/G/P/Q style biomes;
- preboss modeled as a concrete terminal room with validation requirements;
- structured exit constraints, including P indoor/outdoor exit tags;
- Q deterministic door structure represented as data, not a special engine;
- force and max-creation validation shared across all linear biomes.

Do not add biome-specific route engines for these biomes. Use the generic
topology walker and registered room-template interpreters.

Success check:

- F/G/P/Q use the same room stream, history builder, validator, and feedback
  shape;
- P indoor/outdoor failures are explained through exit constraints;
- Q does not need hand-coded topology UI to be valid.

## Phase 5: Reward Offer Legality Baseline

Make reward offers first-class before simulating bags.

Deliverables:

- generated-door offer points;
- room-local offer points such as shops and future wheel offers;
- offer versus acquired loot separation;
- shop offers as non-bag domains;
- preboss shop/free-reward mutual exclusion as one reward surface;
- source-specific entry requirement validation for selected rewards.

This phase ports only true legality. Do not preserve old selected-legality rules
that were only masking missing bag simulation.

Success check:

- every configured reward resolves to a concrete store/profile and reward type;
- selected reward legality uses the source's own requirements;
- bought shop offers become acquired loot at the correct phase while skipped
  shop offers remain offers only.

## Phase 6: Special Room Leaves And Batch Rules

Add special biome mechanics as room-kind leaves or generated-door batches, not
as new route engines.

Recommended order:

1. H / Fields: `FieldsCombat`, `FieldsCageBatch`, `FieldsMaxDoorsRolled`.
2. O / Oceanus: `ShipCombat`, encounter sequence, wheel offer points.
3. I / Tartarus: `ClockworkDoorBatch`, `ClockworkGoal` structural offers,
   Clockwork preboss requirement.

H and I need generated-door batch rules. O needs room/encounter separation but
not a generated-door batch rule.

Success check:

- H cage roll validity is derived from batch state, not per-row sibling hacks;
- O increments encounter depth through encounter events, not room entry
  approximations;
- I uses real `I_*` room keys and Clockwork reward offers instead of fake goal
  room keys.

## Phase 7: Reward Bag Simulation

Implement bag depletion after offer timing and source legality are stable.

Deliverables:

- counted bag state per bag source;
- eligible-entry filtering at each offer point;
- refill behavior when the eligible subset is empty;
- ineligible entries preserved in the bag;
- batch depletion for generated doors and H cage rewards;
- sequential depletion for O wheel offers;
- diagnostics that distinguish "not in this store" from "not available from
  the bag yet."

The simulator walks offers, not acquisitions. Unselected generated-door offers
still deplete bags when the game generated them.

Success check:

- a configured reward can be rejected because the bag cannot produce it at that
  offer point;
- miniboss boon-only filtering uses the same bag machinery as normal
  RunProgress offers;
- bag tests include duplicate reward entries with different requirements.

## Phase 8: N / Ephyra

Add N after the common history, reward, and batch concepts exist.

Deliverables:

- fixed intro: `N_Opening`, `N_PreHub`, `N_Hub`;
- hub generated-door count of 9 or 10;
- explicit selected pylon order, exactly six selected pylons;
- pylon materializers for combat, miniboss, and story rooms;
- occurrence-local pylon and side-room state for all generated pylons;
- hub reward batch generated at hub entry;
- physical history entries for hub returns, side rooms, and pylon restores.

N is graph-shaped in history, but it should still consume the same canonical
generated-door and reward-offer model.

Success check:

- N validation walks the same history and candidate feedback architecture;
- hub reward generation is one batch at hub entry;
- side-room controls do not require a separate control pipeline.

## Phase 9: Route Scope And Multi-Biome History

Once individual biomes work, connect them through configured route prefixes.

Deliverables:

- configured scope selector for ordered biome prefixes;
- route-wide history across one to four configured biomes;
- cross-biome counters and cleared-biome ledgers;
- outside-scope behavior that stops history and validation cleanly;
- route-level status aggregation and error horizon.

Success check:

- `{F}`, `{F,G}`, `{F,G,H}`, and `{F,G,H,I}` are valid Underworld scopes when
  their configured biomes are complete and legal;
- `{G}` without F is not a valid configured scope;
- unconfigured biomes do not appear as random/vanilla placeholder history.

## Phase 10: Runtime Compiler

Build runtime only after validated history is stable.

Deliverables:

- execution-plan compiler from validated history;
- concrete room-generation instructions;
- concrete reward-generation instructions;
- selected-door and generated-offer instructions;
- runtime diagnostics for missing or unknown instructions;
- vanilla handoff outside configured scope.

Runtime must not run eligibility, force pressure, candidate evaluation, or bag
simulation.

Success check:

- runtime hooks apply the execution plan without re-solving planner decisions;
- missing instructions inside configured scope fail loudly;
- outside configured scope returns to vanilla behavior.

## Phase 11: NPCs And Non-Chaos Features

Add NPCs, shops, harvest points, and challenge switches after room/reward
history is authoritative.

Deliverables:

- NPC/feature declarations using the same requirement DSL;
- semantic controls with completion and candidate-provider contracts;
- history events for spawned/entered/used feature facts;
- validation through route history, not separate row lists.

Success check:

- NPC/feature timing checks use the same event-distance queries as reward and
  room validation;
- feature controls do not mutate room history directly.

## Phase 12: Chaos Detours

Keep Chaos deferred until the room spine and reward bags are stable.

Deliverables:

- explicit detour/insertion model;
- generated Chaos exit as structural route data;
- Chaos room history insertion and return target;
- bag/timing behavior for skipped normal rooms;
- clear UI contract for choosing Chaos versus normal path.

Do not model Chaos as an ordinary non-route-altering feature.

Success check:

- taking Chaos changes physical room history and depth counters intentionally;
- skipped normal-room reward generation is modeled according to the game rule,
  not guessed from feature flags.

## Phase 13: Polish And Convenience

Only after the explicit model works, add compact UI affordances.

Allowed polish:

- grouping room candidates by label;
- copy-forward helpers;
- optional compact generated-door display;
- default-fill commands that produce explicit data;
- richer route-status wording.

Not allowed:

- storing compact UI concepts as domain truth;
- reintroducing picked/other-door storage;
- making Auto/Vanilla valid canonical choices;
- runtime fallbacks for incomplete planning data.

## Minimal First Checkpoint

The smallest useful checkpoint is not a full route. It is:

```text
F declarations
+ complete F Biome Plan snapshot
+ F history ledger
+ structural validation
+ candidate feedback
```

That proves the architecture loop:

```text
declarations -> controls -> canonical snapshot -> history -> validation -> feedback
```

Reward bags, N, NPCs, features, Chaos, and runtime should wait until this loop
is stable enough that new mechanics plug into it instead of reshaping it.

## Supporting Docs

- `../model/CANONICAL_PLAN.md` owns canonical data shape.
- `../model/CONFIGURED_SCOPE.md` owns route-prefix scope.
- `../model/DECLARATION_OWNERSHIP.md` owns declaration boundaries.
- `../pipeline/TIMELINE_EVENTS.md` owns lifecycle phases and counters.
- `../ui/FORM_FEEDBACK_CONTRACT.md` owns completeness and feedback contracts.
- `../ui/UI_IMPLEMENTATION_ORDER.md` owns production UI build order.
- `../validation/VALIDATION_MODEL.md` owns validation and candidate flow.
- `../validation/REQUIREMENTS_DSL.md` owns predicate language.
- `../model/REWARD_MODEL.md` owns reward offer and bag concepts.
- `../runtime/RUNTIME_BOUNDARY.md` owns execution-plan and runtime limits.
- `../biomes/LINEAR_BIOMES_MODEL.md` owns F/G/P/Q modeling.
- `../biomes/H_FIELDS_MODEL.md` owns H cage batch modeling.
- `../biomes/O_OCEANUS_MODEL.md` owns O ship combat modeling.
- `../biomes/I_TARTARUS_MODEL.md` owns Clockwork modeling.
- `../biomes/N_EPHYRA_MODEL.md` owns Ephyra hub modeling.
