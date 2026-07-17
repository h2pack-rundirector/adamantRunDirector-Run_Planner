# Implementation Guide

## Purpose and Status

This document defines the complete plan for implementing the Run Planner
architecture in this directory. It owns implementation order, checkpoint
scope, test gates, reset boundaries, and completion criteria. Completed work
and the current implementation frontier are recorded separately in
`IMPLEMENTATION_PROGRESS.md`; status never changes the checkpoint contracts in
this guide.

This document does not redefine the domain, game facts, persistence ownership,
biome rules, or validation semantics owned by the preceding revamp documents.

The rewrite is a total implementation reset. Existing pre-revamp source remains
available through Git as reference material, but no old planner implementation
file, test, persisted shape, or internal API is a compatibility contract.

The implementation rule is:

```text
reverify facts
-> implement the smallest upstream contract
-> add only the consumer admitted by the current checkpoint
-> prove the boundary headlessly and probe live surfaces explicitly
-> remove any temporary scaffold before advancing
```

If a checkpoint needs guessed data, a fallback value, or an adapter to the old
draft, the upstream checkpoint is not complete.

## Authority and Reading Order

Implementation work must read the revamp set in this order:

1. `DOMAIN_MODEL.md` for identity and semantic ownership;
2. `GAME_DATA_REFERENCE.md` for verified vanilla behavior and deliberate
   planner divergences;
3. `UI_PERSISTENCE_MODEL.md` for controls, storage, profiles, reset, and draw;
4. `UI_EDITOR_MODEL.md` for the authored editor, Biome Plan persistence codec,
   decision-tree identity, and UI feedback addressing;
5. `BIOME_RULES.md` for specialized F-Q topology;
6. `MATERIALIZATION_AND_VALIDATION.md` for canonical history, requirements,
   rewards, feedback, and compilation;
7. this document for the complete execution order;
8. `IMPLEMENTATION_PROGRESS.md` for completed work and the current frontier.

The old branch and removed documents may answer historical questions. They
cannot override this set. A disagreement is resolved by game-data
reverification and an update to the appropriate revamp authority before code
continues.

## Reset Strategy

### Git Boundary

Use these branch roles:

```text
codex/fresh-planner-spine  pre-revamp implementation and document archive
codex/planner-revamp       clean implementation branch
```

Before creating the revamp branch:

1. commit the current pending UI work on `codex/fresh-planner-spine`;
2. commit the completed revamp documents and pending legacy design work as a
   pre-revamp documentation checkpoint;
3. run the current focused tests and lint so the archive has a known state;
4. push `codex/fresh-planner-spine`;
5. create `codex/planner-revamp` from that committed checkpoint.

Do not carry untracked or unstaged work across the branch boundary. A stash is
not the archive.

The old implementation remains accessible with ordinary Git operations:

```bash
git show codex/fresh-planner-spine:src/mods/history/builder.lua
git log codex/fresh-planner-spine -- src/mods/validation
git diff codex/fresh-planner-spine...codex/planner-revamp
```

Do not cherry-pick planner implementation commits into the revamp branch. Copy
only reverified facts or deliberately reimplement an algorithm against the new
interfaces.

### Source Reset Boundary

No current planner implementation file is retained by default.

The first revamp commit should:

- remove the current `src/mods/` implementation;
- rewrite `src/main.lua` as a minimal revamp composition entry point;
- remove planner behavior tests that encode `PlannerDraft`, positional rooms,
  form addresses, or the old UI;
- rebuild `tests/all.lua` around the new checkpoint suite;
- retain only contract-neutral packaging, assets, licenses, smoke metadata,
  and test/import infrastructure;
- keep the complete `docs/revamp/` set;
- update `docs/README.md` to make the revamp set authoritative;
- remove superseded `docs/system_design/` and `docs/progress/` material from
  the new branch.

`docs/gameinfo/` may remain temporarily as non-authoritative audit evidence.
Each file must either be cited by the new executable catalog work or removed
once its facts are harvested. Git remains the permanent archive.

The reset commit must still load a minimal managed module and run a minimal
test suite. It must not leave broken imports as an intermediate checkpoint.

### External Contracts Retained

The reset preserves only:

- plugin, modpack, and module identity;
- manifest/package metadata and dependency declarations;
- the public fact that Run Planner is a managed ModpackLib module;
- source licensing and assets;
- shell-repo submodule/release integration;
- any external shared-data or runtime-hook contract explicitly rediscovered
  and adopted by a later checkpoint.

The old profile schema is not retained. No `PlannerDraft` migration, storage
alias compatibility, occurrence ID translation, or hot-reload bridge is
implemented.

## Target Dependency Shape

### Package Boundaries

Exact filenames may evolve, but the source must preserve these dependency
lanes:

```text
src/mods/
  biomes/        room facts, layout declarations, structural rules, catalog
  controls/      Route and Room Control templates and static instance manifest
  rewards/       primitives, stores, bags, producer bindings, payloads, simulation
  route/         Biome Plan, topology layouts, batches, transitions, state access
  materialize/   common canonical visitor and layout-typed canonical records
  history/       layout translators, lifecycle events, ledgers, counter views
  validation/    requirements, structural/game legality, force, reward checks
  candidates/    stable providers, projection records, presentation preparation
  compiler/      validated canonical/history to execution instructions
  logic/         game hook registration, translation, instruction consumption
  ui/            immediate-mode route/biome composition and visual helpers
  composition/   immutable registries, coordinator construction, module wiring
```

The boundaries matter more than the directory spelling:

- declarations import no UI, storage ref, history, validation, or runtime
  code;
- Room Controls own local state and do not import Biome Plan topology;
- Biome Plans know control keys and semantic control interfaces, never private
  storage aliases;
- the common materializer drives registered topology traversal and combines
  Room Control fragments into canonical snapshots;
- history translators consume canonical snapshots only and never rebuild
  topology or canonical structure;
- validation consumes canonical snapshots and game-language history, not draw
  objects;
- candidate projection calls shared validators and does not fork game rules;
- the compiler accepts only successful validation output;
- runtime imports execution-plan types and translation helpers, not UI,
  candidate, bag, or eligibility solvers;
- UI stages authored changes and renders prepared results, but does not compile
  or validate during draw.

### Composition Root

One composition root constructs immutable services in dependency order:

```text
raw declarations
  -> normalized catalog and validated layout declarations
  -> template, batch, transition, topology-layout, and UI-layout registries
  -> static control manifests and Biome Plan objects
  -> common canonical materializer
  -> history-layout, validator, candidate, and compiler services
  -> validated biome implementation support from assembled subsystem evidence
  -> Route and Room Control instances bounded by that support view
  -> collected static control storage and plan-owned layout storage
  -> planner coordinator
  -> UI and runtime adapters
```

Constructors receive named dependencies. Do not mutate a caller-provided
service table, publish partially built services, or hide missing dependencies
behind module globals.

`systems.lua` is the system-wide composition root. It composes major subsystem
results in dependency order and delegates each subtree to one subsystem-local
assembly layer. Those assembly modules may import concrete implementations and
inject them into their leaves; domain leaves do not discover collaborators with
`import(...)`. Static declaration aggregators may import declaration files
because aggregation is their explicit composition responsibility.

The coordinator may retain:

- immutable catalog and registries;
- stable route, biome-step, room-control, and storage descriptor keys;
- non-persisted canonical/history/validation/presentation/execution caches;
- dirty/rebuild status.

It must not retain callback-owned `ui.data`, `runtime.data`, writable fields,
`ui.controls`, `runtime.controls`, `ui.draw`, or an ImGui object.

### Biome Implementation Support

Catalog validity and implementation progress are separate contracts. The
catalog continues to validate the complete F-Q game-data universe even when a
biome is dormant. An explicit implementation-support declaration records these
capabilities for every route-biome step:

```text
focusedRoomControls
-> topology
   -> authoredEditor
   -> materialization
      -> headlessPipeline

authoredEditor + headlessPipeline
-> plannerActive
```

Every capability is an explicit boolean. The support validator rejects missing
or unknown biomes, missing fields, broken capability dependencies, claims that
do not match assembled subsystem evidence, and non-contiguous editable or
planner-active route prefixes. A biome can benefit from a globally shared
focused template without claiming `focusedRoomControls`; that capability means
every Room Control needed by the biome has left the transitional adapter.

Evidence remains subsystem-specific even when the public support record stays
compact. `topology` requires the declared layout kind, its topology
implementation, every referenced batch/transition rule, and its storage
descriptor. `authoredEditor` requires the plan-owned persistence codec,
permanent Route and Room Control views, the applicable UI-layout projector,
and a focused authored-editor probe. `materialization` requires the common
materializer plus all referenced Room Control and rule materializers.
`headlessPipeline` additionally requires history-layout, validation, candidate,
and compiler coverage.
`plannerActive` requires both `authoredEditor` and `headlessPipeline`, plus
contextual candidate/feedback integration and a successful contiguous-prefix
probe. No subsystem may infer another subsystem's coverage from a single biome
boolean.

Implementation support derives two route bounds. `maximumEditablePrefix`
limits the persistent Route Control option domain. `maximumActivePrefix`
records the contiguous prefix with full planner-active integration. Checkpoint
4A may therefore admit F as configured authored intent without claiming that
its semantic pipeline is active.

Checkpoint 4A's authored-only coordinator is the sole phase in which an
editable biome may lack `headlessPipeline`. Before Checkpoint 5 installs the
full semantic coordinator, support composition must prove that every biome
through `maximumEditablePrefix` has headless coverage. Later rollout phases
therefore establish headless support before expanding the editable domain.

## State-Access Threading

The rewrite uses explicit state access rather than one global draft.

### Shared Semantic Interface

Biome Plans and the common canonical materializer receive a narrow semantic
access surface capable of:

- reading Route Control state by route key;
- resolving a Room Control by stable control key;
- reading a Room Control's semantic authored state or canonical fragment
  through its public interface.

The current surface also supplies generic module-data access used internally
by a bound Biome Plan's layout codec. State access does not interpret
`LinearBiome` or `HubBiome` physical records or expose those aliases to
callers.

The semantic code must not ask the adapter for storage aliases or bounded
storage positions.
This common surface is read-only. `UiStateAccess` adds a separate mutation
capability used only by semantic editor operations; `RuntimeStateAccess` does
not implement mutation methods that merely fail when called.

### UI Adapter

`UiStateAccess` wraps the current draw callback's staged data and UI control
registry. It may:

- read staged authored values;
- stage semantic topology writes through Biome Plan operations;
- retrieve UI Room Control refs;
- invoke Lib's full reset-to-defaults operation;
- draw through the current callback surface.

It does not flush configuration or expose its refs to runtime or long-lived
objects.

### Runtime Adapter

`RuntimeStateAccess` wraps the committed runtime data and runtime control
registry supplied to `module.onCommit(...)` or runtime callbacks. It is
read-only and exposes the semantic reads needed for canonical materialization
and coordinator rebuilds. The compiler consumes validated canonical/history
output rather than rereading authored state.

Runtime hooks normally consume the compiled execution cache rather than reread
the authored model.

### Descriptor Rule

A long-lived Biome Plan stores its immutable layout declaration, plan-owned
layout storage descriptor and codec, stable scoped keys, declaration bounds,
and registered topology implementation. Batch and transition implementations
arrive through that topology composition. Each operation uses a short-lived
ref bound to the current state-access surface. The plan never caches
callback-owned data or control refs.

This is the accepted threading cost. Replacing it with a global mutable service
table or serialized root draft is not an optimization.

## Checkpoint Discipline

Every checkpoint must be independently reviewable and green. Checkpoint
completion is recorded in `IMPLEMENTATION_PROGRESS.md`. If a later design
review replaces one bounded authority established by an earlier checkpoint,
the progress record must name the retained outputs and the superseded artifact,
and the next checkpoint must own one atomic replacement. A completed checkpoint
is not retroactively required to satisfy a contract that did not yet exist.

Required properties:

- it adds one upstream contract and its focused tests;
- downstream placeholders do not pretend to implement missing behavior;
- every production requirement has a modeled evaluator contract;
- no temporary fallback enters canonical or runtime output;
- tests assert semantic contracts, not current table layout;
- the worktree has no accidental generated or deployed-profile changes;
- docs describe only behavior actually present at that checkpoint.

Focused module validation for implementation checkpoints:

```bash
lua tests/all.lua
luacheck src tests
rtk git diff --check
```

Use native `git diff --check` when `rtk` is unavailable. Add the shell-repo
smoke, dependency, assembled-test, and deploy checks only at the integration
checkpoints named below.

Do not use a passing unit suite as proof of in-game ImGui or hook behavior.
Those surfaces require explicit runtime probes.

## Checkpoint 0: Archive and Green Reset

### Deliverables

- pre-revamp branch committed and pushed;
- `codex/planner-revamp` created;
- old implementation and behavior tests removed;
- minimal managed-module activation rewritten without old imports;
- minimal test runner and import harness working;
- revamp docs authoritative on the new branch;
- no compatibility or migration code.

The module may expose a clearly labeled unavailable/under-construction tab or
no planner tab, depending on the current Lib module contract. It must not show
the old planner UI.

### Acceptance

- module source imports cleanly in the test harness;
- module activation smoke succeeds with no planner behavior registered;
- lint and diff checks pass;
- repository search finds no `PlannerDraft`, positional form address, or old
  planner package import in live source;
- the old branch can retrieve every removed file.

## Checkpoint 1: Complete Catalog Foundation

The full supported universe must exist before static controls are generated.
This checkpoint is declaration-only.

### Deliverables

- Underworld and Surface route declarations with ordered biome-step keys;
- complete F, G, H, I, N, O, P, and Q concrete room catalogs;
- verified biome structural inputs, including candidate starts or fixed
  entries, terminal identities, specialized peer sets, and finite-capacity
  proof inputs; these are game facts, not the final layout schema;
- room kinds, template keys, physical exits/types, reward surfaces, fixed and
  sequenced baseline encounter profiles, optional phase-presence declarations
  and their decision phases,
  canonical baseline encounter keys where required, phase-owned offer points,
  counters, caps, force metadata, and modeled eligibility;
- explicit per-room records with no generated room ranges, semantic defaults,
  or implicit counter/cap/profile/reward facts;
- reward primitives, normalized acquisition names, unique stores, counted
  bags, shop profiles, offer profiles, payload domains, and batch constraints;
- code-owned requirement-kind registry with supported contact phases, payload
  schemas, evaluator contracts, and static/dynamic capacity classification;
- batch-rule and room-template declaration registries;
- finite local-child bounds and topology-capacity proof inputs;
- mechanically generated stable Route and Room Control keys;
- a static control manifest descriptor, without Lib control implementation.

### Requirement Gate

Every production requirement must have a registered evaluator contract.
Missing evaluators, unknown kinds, unknown named predicates, and malformed
payloads fail catalog construction. External save/profile predicates and
unfinished requirements do not enter production declarations.

### Game-Data Gate

Tests and generated audits must prove:

- route and room keys are unique in their declared scope;
- each room's template accepts its room kind;
- every room explicitly declares tags, exits, its complete incoming-reward
  binding, encounter-profile key, structural counter effects, caps, and local
  children, including empty and false values;
- every encounter profile explicitly declares its phases, including each
  phase's baseline encounter identity and encounter-depth effect where the
  concrete identity affects planner semantics;
- creation caps and appearance caps remain separate fields;
- ordinary combat canonicalization is not encoded as
  `MaxCreationsThisRun = 1`;
- physical exits match extracted map data;
- Q forced-predecessor and exact-pair facts, H cage metadata, I/N biome state,
  and N physical hub-door mappings are closed, typed, and internally
  consistent;
- each canonicalized family has sufficient compatible controls under maximum
  topology demand, and every declared canonical family has exactly one proof;
- all declared force windows preserve start, deadline, and independent
  eligibility bounds;
- every reward binding, including nested slots, branches, and offer points,
  resolves to a known producer kind, declared stores/profile, valid
  positive/negative filters, and reward/payload types.

NPC catalogs, persistence, targeting, and validation are not Checkpoint 1
deliverables. The foundation reserves stable `roomControlKey + phaseKey`
addresses and resolves history from an effective room spine so those entities
can later merge before history without changing Room Control identity. Mixed
vanilla encounter sets containing progression and NPC variants are not
production baseline declarations.

### Acceptance

- the catalog loads without UI, Lib refs, history, or runtime state;
- every F-Q declaration passes the coverage audit;
- capacity tests use compatible matching, not raw room counts, and report every
  dynamic predicate excluded from the static proof;
- changing one malformed fixture fails at the catalog boundary with a precise
  invariant message;
- no placeholder biome or reward declaration is counted as implemented.

## Checkpoint 2: Static Controls and Managed Storage

This checkpoint proves static control persistence and finite managed storage
before the final topology authority or UI is built.

Before specializing a Room Control template, review its contract in
`room_controls/` together with `room_controls/REWARD_COMPONENTS.md`. If that
review changes domain ownership, biome behavior, or canonical semantics,
correct the owning authority document first. Do not implement a generic
producer/template combination that the corresponding specification has not
admitted.

### Deliverables

- one statically declared Route Control instance per route, produced through
  the registered Route Control template;
- complete declared Room Control template taxonomy and bounded storage schema;
- one statically declared Room Control per top-level concrete room in every
  route-biome step;
- parent-local bounded child storage inside the appropriate Room Control
  templates;
- bounded biome topology-support storage generated from the then-current
  catalog, sufficient to prove that all managed persistence is finite without
  making that descriptor the final layout authority;
- static control and storage manifests generated from the validated catalog;
- focused UI and runtime control refs exposing semantic reads, not private
  aliases, for every F and G room;
- explicit dormant transitional adapters for biome-specific H, I, N, O, P,
  and Q templates, used only to prove bounded storage before those biomes are
  implemented;
- an evidence-backed implementation-support record for every route-biome step;
- `UiStateAccess` and `RuntimeStateAccess` adapters;
- Lib full reset-to-defaults integration for all persisted module and control
  state.

Both Route Controls default their configured prefix to empty. Fresh profiles
and Lib reset to defaults therefore persist no configured planner biome for
either route. Once compilation exists, that default publishes no execution
plan and leaves both routes vanilla.

Every Room Control must declare its complete intended storage schema at this
checkpoint, including bounded special slots. The transitional adapter may own
that physical schema for a dormant non-F/G template, but it is not a semantic
Room Control implementation and cannot be used by materialization. Adding H,
I, N, O, P, or Q later must replace the corresponding adapter without adding
dynamic controls or migrating storage.

### Acceptance

- expected Route and Room Control counts match the catalog-generated manifest;
- every control name satisfies Lib stable-identifier rules;
- every F/G Room Control is focused and no F/G instance uses the transitional
  adapter;
- UI and runtime refs for focused controls read the same committed semantic
  values;
- UI-only writes cannot be reached from runtime refs;
- implementation-support claims match assembled evidence and cannot activate
  a biome with transitional controls;
- fresh profile creation and Lib reset to defaults restore an empty configured
  prefix for both routes;
- Lib reset to defaults resets all module and control persistence, including
  dormant leaves;
- no test or source accesses a generated private control alias;
- topology-support storage stays within the declaration-proven capacity
  without folding Room Control local-child capacity into topology; final
  layout-specific descriptors remain a Checkpoint 3 acceptance gate.

There is still no production route editor in this checkpoint. Focused semantic
Room Controls for non-F/G biomes are intentionally deferred to Checkpoint 7.

## Checkpoint 3: Layout Topology and F/G Structural Slice

Build the dynamic topology boundary without ImGui, canonical materialization,
history, or game legality.

The checkpoint begins with one atomic declaration/catalog/storage authority
switch. Replace legacy `root`, `terminalRoomKeys`, top-level `batchRuleKey`,
specialized-rule lists, deterministic-pair side tables, room-level
`fixed`/`terminal` flags, and persisted dispatch columns with the validated
`layout` declarations and layout-derived storage descriptors. Do not leave old
and new fields as competing sources of truth.

This is the accepted reconciliation boundary for the completed foundation.
Checkpoint 1's room, encounter, reward, requirement, counter, and structural
game facts remain authoritative. Checkpoint 2's controls, Room Control storage,
state-access adapters, and reset behavior remain authoritative. Only their
topology-facing declaration and storage scaffolds are superseded here.

### Deliverables

- one explicit `layout` declaration per biome, including layout kind, start or
  fixed entry sequence, continuation defaults and overrides, terminal,
  `PrebossEntry`, terminal exit policy, and topology bounds;
- catalog parsing and validation for `layout`, derived room-role indexes,
  ordered topology-only override selectors, and layout-specific topology
  bounds;
- executable implementation registries for topology layouts and terminal
  transitions, kept separate from declarative batch rules and assembled
  through system composition; do not add metadata-only registries for the
  currently closed discriminator sets;
- separate bounded `LinearBiome` and `HubBiome` authored-state descriptors,
  including only the terminal-companion link capacity admitted by each
  declaration;
- regenerated storage manifests with continuation, batch, terminal, and
  transition dispatch derived during normalization rather than persisted;
- one common long-lived Biome Plan wrapper that delegates by `layoutKind`;
- `LinearBiome` normalized topology, structural checks, traversal, semantic
  addresses, and mutation-command implementation;
- Standard generated-batch implementation;
- structural `PrebossEntry` implementation deriving the one terminal Room
  Control, terminal exit policy, predecessor context, and bounded companion
  links without materializing reward surfaces yet;
- F start selection, G fixed-start behavior, generated targets, picked
  continuation, downstream structure, and terminal-transition state;
- explicit `ReplaceWithBatch` and `ReplaceWithTerminalTransition` atomic
  operations plus the remaining LinearBiome commands;
- injective top-level Room Control use and dormant-control preservation;
- declaration-derived `continuationOverrideKey`, `batchRuleKey`, and
  `transitionRuleKey` during normalization, never authored persistence;
- owner-keyed structural completeness findings for F and G;
- validated `topology = true` subsystem evidence for F and G only.

### Acceptance

- topology reads, structural checks, traversal, and semantic addressing run
  against both UI and runtime state-access test adapters;
- every biome declares exactly one known layout kind; all start, entry, hub,
  terminal, batch, transition, and override references resolve;
- override selectors use only topology-visible structural facts, are ordered,
  and cannot overlap ambiguously;
- layout roles derive catalog indexes without raw Room Declarations duplicating
  generic `fixed` or `terminal` flags;
- each `PrebossEntry` resolves one compatible terminal exit policy,
  `entryOfferPolicy`, companion rule where applicable, and predecessor-exit
  bound;
- layout storage bounds match each declaration's maximum batches and top-level
  targets, and no persisted batch-rule, continuation-override, terminal-room,
  or transition-rule dispatch column remains;
- mutation commands require `UiStateAccess` and are absent from
  `RuntimeStateAccess`;
- commands validate a complete proposed replacement before staging bounded
  writes;
- duplicate or cross-biome top-level control use fails at the topology contact
  boundary;
- changing the selected start or picked target removes incompatible downstream
  topology while preserving Room Control persistence;
- a selected LinearBiome source has one generated batch or one terminal
  transition, never both; companion targets owned inside a terminal transition
  do not form a second continuing batch;
- force, eligibility, normalization, and validation never mutate continuation
  form;
- unpicked targets remain dead leaves;
- complete F and G topologies close through one `PrebossEntry` and traverse
  without ImGui or canonical/history work;
- normalized topology contains no copied room-local reward/payload state or UI
  row identity;
- malformed persisted state fails at the Biome Plan boundary while incomplete
  but well-formed state remains readable.

## Checkpoint 4A: Authored F Editor Foundation

Mount the permanent authored editor before the semantic pipeline, using only
the topology, persistence, and Room Control boundaries already established.
This is an earlier consumer of the authored model, not a temporary debug form
and not a planner-active claim.

The checkpoint begins with one biome-persistence ownership consolidation. A
Biome Plan must own the layout-derived storage descriptor and reversible codec
for its decision tree. The module storage manifest becomes a collector of
plan-owned roots, and generic state access stops interpreting physical
`LinearBiome` or `HubBiome` records. Do not leave the current global storage
reader/writer and the plan-owned codec as competing authorities.

### Deliverables

- one plan-owned bounded storage descriptor and reversible authored-state
  codec per constructed Biome Plan;
- storage capacity derived from layout `maxBatches`, `maxTargets`, start mode,
  terminal companion bounds, and authored biome globals;
- short-lived UI/runtime plan refs bound to generic state-access surfaces;
- module storage collection over all Route Control, Room Control, and Biome
  Plan roots without layout-kind persistence branches in state access;
- a permanent Route Control prefix view whose Underworld domain is exactly
  empty or F, whose Surface domain is empty, and whose values come from the
  support route view's `maximumEditablePrefix`;
- control assembly split between static manifest/template preparation and
  instance construction so implementation support is composed before Route
  Control option domains; production composition has no independent
  `activePrefixEnds` authority;
- transient route/biome navigation and bounded semantic-selector fields with
  `persist = false` and `hash = false`;
- stable declaration-derived room, reward, payload, entry-mode, and structural
  option domains prepared outside draw;
- bottom-up reward/payload draw collaborators for one-of payloads, distinct
  pairs, primitive choices, counted choices, shops, and purchase state;
- permanent Route and focused F Room Control views, including topology-context
  handling for the forked preboss;
- `uiLayouts["LinearBiome"]` authored projection for incomplete and complete F
  topology, with F/G focused fixtures proving the layout implementation is not
  F-specific;
- route shell and transient navigation over the committed configured views;
- start, Standard batch, physical target, picked continuation, continuation
  replacement, terminal, and topology-clearing interactions through semantic
  Biome Plan commands;
- referenced picked and unpicked Room Control drawing by stable control key;
- owner-keyed structural and local-completeness presentation without
  contextual legality;
- one authored-result coordinator that reads the committed Route Control,
  normalizes and projects every configured plan on activation, meaningful
  commit, and setting-changing reload, then atomically publishes the complete
  authored view;
- validated `authoredEditor = true` subsystem evidence for F only, deriving
  `maximumEditablePrefix = "Underworld_F"` while both routes retain an empty
  default and `maximumActivePrefix` remains absent;
- explicit editor-only status while no canonical snapshot or execution plan
  exists.

The UI and feedback details are authoritative in `UI_EDITOR_MODEL.md`. This
checkpoint must use final ownership interfaces. It cannot introduce a mutable
route document, positional participant registry, raw topology-table editor,
or planner-owned replacement for Lib dropdown widgets.

### Acceptance

- every Biome Plan can round-trip its semantic authored state through its own
  codec using both UI and runtime state-access test adapters;
- the Underworld Route Control offers exactly empty and F, Surface offers only
  empty, and neither draw nor control construction hard-codes that domain;
- the module storage manifest merely collects the exact roots declared by the
  plans and has no independent layout persistence interpretation;
- malformed persisted topology still fails at the Biome Plan contact boundary,
  while incomplete but well-formed topology remains projectable;
- draw consumes one published authored view and never decodes, normalizes, or
  projects topology;
- dynamic topology selectors write transient fields and translate changes into
  semantic Biome Plan commands during the same draw call;
- structural widgets cannot stage a proposal that violates the Biome Plan
  contact boundary;
- an empty F plan can be authored through one selected start, complete Standard
  batches, picked continuations, and one `PrebossEntry` terminal transition;
- all physical peers are visible and editable, including unpicked dead leaves;
- changing the selected start, picked target, or continuation form clears only
  incompatible downstream topology and preserves Room Control persistence;
- forked-preboss presentation exposes only the free-reward capacity admitted
  by immutable predecessor exit context;
- dormant unreferenced Room Controls are neither drawn nor included in
  completeness;
- completeness remains a biome-level blocker while semantic owner addresses
  localize missing leaf or spine state;
- no UI address contains a persisted table row, rendered row, display ordinal,
  widget ID, or occurrence ID;
- unchanged draw frames perform no normalization, projection,
  materialization, history, validation, provider-domain rebuild, or feedback
  translation;
- route and room draw paths reuse stable option and option-state tables;
- profile load, hash reload, commit, and Lib reset reproduce the authored tree
  through the same codec and publication path;
- the authored result contains one view per configured biome, while transient
  navigation only selects among those published views;
- fake-ImGui tests cover planner projection and command wiring without
  retesting Lib widget internals;
- an in-game probe proves dropdown opening, selection, next-frame commit
  publication, profile reload, and reset-to-defaults;
- F is configurable and claims authored-editor support without claiming
  materialization, headless-pipeline, or planner-active support; G remains
  outside the configurable and planner-active domains.

## Checkpoint 4B: Common Canonical Materializer and F Fragments

This checkpoint completes canonical materialization for F. Shared component
implementations may already serve G or later room kinds, but no other biome
claims materialization until its Checkpoint 7 headless slice is complete.

### Deliverables

- composed semantic materialization interface for Route and Room Controls over
  the completeness predicates and typed storage contracts already exercised by
  Checkpoint 4A;
- reusable reward/payload components inside Room Control templates;
- concrete generated-target reward fragments owned by target Room Controls;
- active/inactive local-child slot materialization;
- one common canonical materializer that drives
  `topologyLayouts["LinearBiome"]` traversal and combines Room Control and
  batch fragments;
- `PrebossEntry` terminal materialization delegating F shop/free-reward
  realization and `entryMode` to the terminal Room Control;
- the canonical `LinearBiome` snapshot variant and composed route-plan shape
  with stable semantic return addresses;
- reuse of Checkpoint 4A owner-keyed completeness findings before canonical
  materialization;
- stable candidate-provider semantic export from Room Controls and layout
  structural owners, extending rather than replacing the editor's prepared
  domains;
- configured-prefix completeness horizon;
- validated `materialization = true` support evidence for F only.

Materialization must be read-only. It cannot create payload containers, select
the first option, mutate a control, or repair topology.

### Acceptance

- an incomplete referenced control produces local completeness feedback and no
  canonical biome snapshot;
- dormant controls do not affect completeness;
- all generated peers materialize, including unpicked dead leaves;
- acquisition for ordinary generated doors derives from picked topology;
- no canonical fact contains `Auto`, `Vanilla`, `Major`, `Minor`, a storage
  position, UI row, or widget identity;
- semantic addresses resolve directly to a Route Control, Room Control,
  parent-local slot, layout batch/target, or terminal transition;
- incomplete F state produces owner-keyed completeness findings, no canonical
  snapshot, and no contextual candidate validity;
- F terminal materialization applies `allExitsTerminal` and emits one terminal
  room plus the bounded offers activated by predecessor exit count, never
  duplicate terminal controls or companion room targets;
- the common materializer owns canonical assembly while topology traversal
  emits no history;
- canonical materialization works through both UI and runtime read adapters;
- canonical materialization runs only from an explicit headless invocation at
  this checkpoint and never during draw. The authored editor continues to
  operate without invoking it. Checkpoint 5 wires it to the
  synchronous configuration lifecycle rebuild.

## Checkpoint 5: F Headless Vertical Slice

F proves the complete planning pipeline before its semantic results are joined
to the authored editor introduced in Checkpoint 4A.

### Deliverables

- complete F start, Standard batches, `PrebossEntry`, terminal behavior, and
  control fragments;
- `historyLayouts["LinearBiome"]` consuming the complete canonical snapshot;
- ordered common lifecycle event builder and named event vocabulary;
- named counter/history ledgers;
- normalized requirement evaluator;
- structural, exit, cap, eligibility, and force-pressure validation;
- exact reward domain, payload, entry, batch, counted-bag, and acquisition
  validation;
- stable candidate providers and bounded scratch projection;
- direct feedback resolution by semantic owner;
- execution compiler producing concrete headless F instructions;
- expansion of the Checkpoint 4A authored-result coordinator so it first
  normalizes every configured topology, then owns completeness, canonical,
  history, validation, owner-keyed presentation, per-biome `processingState`,
  and compilation;
- one synchronous rebuild path called directly by activation, meaningful
  commit, and meaningful reload lifecycle callbacks;
- atomic replacement with the complete derived result on success, and clearing
  of the previous published result before surfacing a contract failure;
- unpublished presentation build buffers swapped atomically into the published
  route result;
- validated `headlessPipeline = true` subsystem evidence for F only.

Do not defer counted bag simulation. The F slice is not complete if rewards are
validated only by store membership or selected-entry requirements.

### Acceptance

- a complete legal F prefix reaches `valid` and compiles;
- the installed semantic coordinator proves that every value admitted through
  `maximumEditablePrefix` has contiguous headless-pipeline support;
- incomplete and modeled-invalid configured prefixes do not compile;
- the Linear history translator accepts canonical snapshots only and never
  reads authored topology or rebuilds canonical structure;
- every generated peer advances creation and reward-offer history;
- only picked/entered/purchased rewards advance acquisition ledgers;
- peer creation is sequential for cap evaluation;
- `biomeDepthCache`, `biomeEncounterDepth`, room-history ordinal, and force
  state update at the documented phases;
- force pressure uses structured-exit maximum matching;
- counted bags preserve ineligible entries and refill only under the declared
  append-on-no-eligible rule;
- selected values and candidate projections call the same validators;
- no partial canonical, presentation, or execution result becomes visible
  during a rebuild;
- a contract failure fails loudly, clears the previous published result, and
  leaves no execution plan available;
- malformed topology in any configured biome fails at normalization before
  semantic processing or publication;
- rebuilding never mutates the currently published presentation arrays;
- repeated rebuild of unchanged committed state is avoided.

Golden tests must compare the full ordered event stream for representative F
plans, not only final counters.

## Checkpoint 6: F Semantic UI Integration and Production Hardening

Join the authoritative F headless pipeline to the authored editor already
mounted in Checkpoint 4A. This checkpoint adds semantic presentation and
production activation; it does not replace the editor's persistence, layout,
or Room Control view boundaries.

### Deliverables

- implementation support updated to claim `plannerActive = true` and derive
  `maximumActivePrefix = "Underworld_F"` without changing the already-live
  Route Control option domain;
- enrichment of the existing `uiLayouts["LinearBiome"]` authored projector
  with owner-keyed candidate, feedback, and derived `processingState` data;
- candidate-aware dropdown/value presentation;
- common route status, markers, and first-blocking horizon;
- prepared invalid/muted/enrichment state;
- atomic publication of the prepared editor view and execution state already
  built by the Checkpoint 5 coordinator;
- performance hardening of the existing dumb draw path;
- validated `plannerActive = true` subsystem evidence for F only.

The UI must not contain a mutable route document, duplicate canonical plan,
positional form participant registry, or direct reward-table editor.

### Acceptance

- draw stages semantic edits and never flushes configuration;
- Room Controls translate candidate application into their private state;
- the UI-layout projector never reads a Room Control's private fields;
- UI rows and display ordinals remain presentation-only and never become
  topology addresses or gameplay counters;
- declaration-impossible values are absent while context-invalid values remain
  visible and invalid after F is complete;
- contextual candidate validity is prepared only after F is complete; before
  completeness, providers expose stable domains and completeness presentation;
- every configured biome receives one fresh prepared view, while a biome with
  `blockedByEarlierBiome` exposes normalized authored structure and stable
  domains but no local findings, contextual validity, or enrichment;
- downstream content is inactive only after the first incomplete or blocking
  selected-plan finding;
- one draw uses one published prepared view; an edit frame may display that
  prior committed presentation, and `onCommit` publishes the replacement before
  the next draw;
- the Checkpoint 4A authored editor behaves identically when semantic
  presentation is absent, incomplete, invalid, or enriched;
- draw never translates findings, mutates prepared presentation, or applies a
  deferred feedback pass;
- unchanged draw frames perform no materialization, history, validation,
  provider-domain, or execution-plan rebuild;
- allocation tests cover route draw, batch draw, Room Control views, candidate
  decoration, and dropdown option iteration;
- an in-game probe proves candidate dropdown opening, selection, preview color,
  tooltip, Lib reset to defaults, profile reload, and commit publication;
- a profile/hash prefix beyond `maximumEditablePrefix` is rejected without
  clamping, and no configured prefix beyond `maximumActivePrefix` can publish
  a production-active semantic result.

Unit tests with fake ImGui are necessary but not sufficient for this
checkpoint.

## Checkpoint 7: Controlled Biome Rollout

Biome implementation and planner exposure are separate gates.

`headless implemented`
: Its catalog and static schema have been audited and its
  topology-layout traversal, canonical materialization, history-layout
  translation, validation, candidate projection, and focused fixtures exist.
  The biome is absent from the configured-prefix option domain and has no
  production editor surface.

`authored-editor`
: The biome has permanent authored Route/Room Control views, its UI-layout
  projection and persistence round trips are proven, and it is available as
  the next contiguous value in the Route Control domain. This capability does
  not imply canonical materialization, contextual validation, or compilation.

`planner-active`
: The authored editor and headless pipeline are joined into contextual
  candidate/feedback presentation for the real contiguous route prefix and
  have passed an in-game integration probe. Planner activation does not mean
  runtime-hook activation; runtime remains deferred to Checkpoint 9.

The Route Control option domain is bounded by the validated implementation-
support route view's `maximumEditablePrefix`. The separately derived
`maximumActivePrefix` records the fully integrated semantic prefix. The full
catalog and static controls may already exist, but dormant headless biomes
beyond the editable bound cannot be selected or exposed as implemented UI.

Each headless slice follows:

```text
focused Room Control replacement and static-schema audit
-> topology layout plus batch/transition coverage
-> common canonical materialization
-> canonical-only history-layout translation
-> shared validation and bags
-> candidates and prepared presentation
-> focused headless fixtures
```

Activation adds the applicable authored UI projection, integration with the
real prior route prefix, editable- and active-prefix expansion, and a focused
in-game probe.
The phase updates implementation support only after the assembled focused
controls and downstream subsystem registries prove the claimed capability.

### 7A: G Implementation and Activation

Reuse `LinearBiome`, `Standard`, and `PrebossEntry`; prove two- and three-exit
batches, direct combat-depth predicates, shop exit-count requirements,
persistent force pressure, the tight compatible-control capacity bound, and
`allExitsTerminal` / `shopThenFillRemainingExits` with up to two active
free-reward slots. Add G production UI, validate it after a real F canonical
snapshot/history, and expand both the Underworld editable and planner-active
prefixes to `F/G`.

### 7B: P Headless and Dormant

Reuse `LinearBiome`, `Standard`, and `PrebossEntry`; prove typed physical exits,
Indoor/Outdoor target compatibility, and declared non-counting/counting
encounter phases without a separate topology engine. Prove P's
`allExitsTerminal` / `shopThenFillRemainingExits` terminal with at most one
active free-reward slot.
Prior-route inputs use explicit declaration-grounded history fixtures; they do
not claim N/O integration. P remains absent from the Surface prefix domain and
production UI.

### 7C: Q Headless and Dormant

Reuse `LinearBiome`, `Standard`, and `PrebossEntry`; prove the fixed depth
skeleton, both explicit predecessor-selected `QMinibossBatch` overrides, their
exact distinct pairs, and canonicalized unpicked identity. Override dispatch
must use the declared predecessor-room sets rather than lifecycle depth. The
prior-save condition on `Q_MiniBoss04` is not production planner data.
Prove Q's `singleTerminal` / `shopOnly` terminal. Prior-route inputs use
explicit fixtures, and Q
remains absent from the Surface prefix domain and production UI.

### 7D: H Implementation and Activation

Reuse `LinearBiome` and `PrebossEntry` with `FieldsCageBatch` as the declared
default. Prove bridge offer/skip history, terminal entered-count logic, shared
Min/Max roll state, active cage slots, the three-starting capacity fold
including a no-Fields-target batch, `FieldsMaxDoorsRolled` ceiling behavior,
and one active `allExitsTerminal` forked-preboss free-reward slot when
applicable. Add H production UI, validate it after the real F/G prefix, and
expand both Underworld bounds to `F/G/H`.

### 7E: I Implementation and Underworld Activation

Reuse `LinearBiome` and `PrebossEntry` with `ClockworkDoorBatch` as the declared
default. Prove concrete incoming goal/non-goal offers, special peer
requirements, acquisition-driven goal/non-goal counters, authored
`maxNonGoalRewards`, preboss eligibility/pressure, and the
`terminalWithCompanions` / `shopOnly` entered terminal. Implement one shared
committed-prefix Clockwork realization consumed by UI preparation and canonical
materialization; draw must not count goals or infer active exits.

Prove both selected outcomes after the preboss becomes eligible:

- `Go to Preboss` creates the entered terminal on the first physical exit and,
  for a two-exit predecessor, one ordinary unpicked companion governed by
  `ClockworkDoorBatch`;
- `Add Next Decision` on a two-exit predecessor derives the unpicked preboss
  creation and fixed Shop door offer on the first exit, authors only the picked
  ordinary target on the second exit, and continues through that target;
- `Add Next Decision` on a one-exit predecessor remains structurally complete
  but receives a blocking force finding because the eligible preboss must
  occupy the sole exit.

The declined offer must add no persistence field, duplicate target link,
terminal Room Control claim, shop-local configuration, or new room-leaf
feedback identity. Prove repeated declined offers on later predecessors while
preserving injective Room Control allocation. Also prove that an upstream edit
which makes a previously occupied exit the forced preboss slot retains the
authored target visibly, reports the collision, and never clears or hides it
during projection. Prove that explicit replacement between the two clean
two-exit outcomes preserves the ordinary exit link while changing it between
picked target and unpicked companion and clearing only its dependent
downstream topology. Add I production UI, validate it after the real F/G/H
prefix, and expand both Underworld bounds to all four biomes.

### 7F: N Implementation and Activation

Implement `topologyLayouts["HubBiome"]`, its canonical variant,
`historyLayouts["HubBiome"]`, and `uiLayouts["HubBiome"]`. Prove the persistent
9/10-door hub batch, exactly six ordered visits, one-time hub reward generation,
derived hub returns, parent-local side-room slots,
repeated side-room game keys, side-room entry order, combat restores, and final
`singleTerminal` / `shopOnly` preboss transition. Reverify and implement the
exact sequential side-door minimum-availability rule at this checkpoint; it is
not an earlier catalog foundation requirement. Add N production UI and expand
both Surface bounds to N.

### 7G: O Implementation and Activation

Reuse `LinearBiome`, `Standard`, and `PrebossEntry`; prove one-target top-level
topology and `ShipCombat` room-local sequencing:
the complete sequence is prepared against pre-room history; the intro does not
count; one or two combat phases count; and each combat phase owns a wheel that
offers/selects at encounter start and acquires after combat. Derive stable
wheel storage slots from the profile instead of duplicating them in every O
room declaration, and prove O's `singleTerminal` / `shopOnly` terminal. Add O
production UI, validate it after the real N canonical snapshot/history, and
expand both Surface bounds to `N/O`.

### 7H: P/Q Surface Activation

Mount the already headless-proven P and Q production UI, replace fixture-only
prior history with real N/O/P route progression, and rerun their integration
and candidate suites against the composed Surface route. Expand both Surface
bounds first to `N/O/P` and then to all four biomes only after each contiguous
prefix passes its focused in-game probe.

### Per-Phase Acceptance

- no new route engine is introduced;
- specialized behavior is owned by a declared layout/override, registered
  batch or transition rule, Room Control template, or biome state rule named in
  `BIOME_RULES.md`;
- all new requirements resolve to registered evaluators;
- all local slots and topology remain declaration-bounded;
- no biome claiming focused controls retains a transitional Room Control;
- capability claims match separate assembled topology, authored-editor,
  materialization, history, validation/candidate/compiler, and contextual UI
  evidence;
- compatible-control capacity is reproven;
- event order and counter timing have golden fixtures;
- rewards use the common offer/acquisition/bag pipeline;
- candidate and selected validation remain the same functions;
- a headless dormant biome is absent from the configured-prefix option domain
  and production UI;
- profiles and hashes cannot configure a biome beyond
  `maximumEditablePrefix`, and planner-active publication cannot exceed
  `maximumActivePrefix`;
- fixture prior history proves the biome contract, not cross-biome integration;
- activation expands only the next contiguous route prefix and requires the
  real prior prefix to materialize and validate;
- cached draw for every active biome remains allocation-safe;
- no phase installs runtime hooks before Checkpoint 9.

## Checkpoint 8: Full Route Prefix Hardening

Checkpoint 7 activates prefixes incrementally. This checkpoint proves the
resulting full route composition as one production planner surface before any
runtime hook consumes it.

### Deliverables

- Route Control configured-prefix state for zero through four ordered biomes,
  with both `maximumEditablePrefix` and `maximumActivePrefix` bounds now four;
- sequential biome completeness, canonical snapshot, history, and validation
  progression across biome boundaries;
- cleared-biome, encounter, loot, use, creation, and spacing ledgers across the
  configured prefix;
- atomic completeness boundary at each biome;
- route-wide error horizon and status aggregation;
- all-configured topology normalization and one prepared view with derived
  `processingState` per configured biome;
- Underworld and Surface integration fixtures;
- execution-plan concatenation with explicit prefix termination;
- atomic publication of each complete derived route result after commit.

### Acceptance

- `{F}`, `{F,G}`, `{F,G,H}`, and `{F,G,H,I}` behave as ordered Underworld
  prefixes;
- an empty prefix produces no planner instructions and leaves that route
  entirely vanilla, and remains the fresh-profile/reset default;
- non-empty Surface prefixes begin with N and cannot skip ahead to O/P/Q;
- an incomplete biome produces no canonical snapshot and prevents later biomes
  from being processed;
- a complete invalid biome produces its canonical snapshot and feedback but
  prevents later biomes from being processed;
- malformed topology in any configured biome fails the rebuild even when an
  earlier biome would block semantic processing;
- every later configured biome beyond the first blocker has a trusted inactive
  prepared view with `blockedByEarlierBiome`, stable declaration domains, and
  no local completeness, contextual-validity, or enrichment result;
- out-of-prefix biomes contribute no rooms, rewards, counters, or validation;
- cross-biome reward and cleared-biome requirements see the correct prior
  events;
- changing the configured prefix rebuilds and atomically publishes once after
  commit;
- every meaningful configuration change synchronously rebuilds once, atomically
  replaces the published result on success, and clears it on failure;
- all editable and planner-active prefix values and production biome editors
  are available, while runtime hooks are still absent.

## Checkpoint 9: Runtime Hook Audit and Execution

The compiler exists before this checkpoint; game integration does not.

### Runtime Audit

Before writing hooks, produce and verify a callback matrix containing:

| Boundary | Live game inputs | Stable context translation | Instruction consumed | Failure behavior |
| --- | --- | --- | --- | --- |
| Next-room generation | current room and physical exits | route/biome/source/exit keys | target assignments | fail closed in scope |
| Reward generation | room/door/offer context | instruction and offer-point key | reward and payload | fail closed in scope |
| Room-local mechanics | room and lifecycle phase | control/local-slot key | wheels/cages/children | fail closed in scope |
| Room entry/commit | current room/history state | expected cursor context | continuation/cursor | diagnostic on mismatch |
| Prefix completion | route and biome boundary | configured terminal | vanilla handoff | vanilla outside scope |

The matrix must be grounded in current game code or an in-game probe. An old
branch hook name is not evidence that the callback is still correct.

### Deliverables

- hook registration through the module's supported Lib surface;
- live-to-stable context translators at hook boundaries;
- ordered instruction cursor/state;
- current-plan lookup before instruction consumption;
- concrete target, reward, payload, and room-local instruction consumers;
- explicit configured-prefix activation and vanilla suffix handoff;
- stable runtime mismatch diagnostics;
- plan replacement/clearing on committed configuration change.

### Acceptance

- hooks consume instructions without importing validators or candidate code;
- runtime never chooses a fallback target/reward inside configured scope;
- an unexpected room, exit, offer point, or cursor produces a clear diagnostic
  and disables current plan use;
- changing profiles or resetting configuration cannot leave the prior plan
  active;
- a rebuild contract failure cannot leave the previous execution plan active;
- unconfigured route suffixes use vanilla behavior;
- focused in-game probes cover each callback row before full deploy testing.

## Checkpoint 10: Hardening and Cleanup

### Correctness

- full declaration coverage and compatible-capacity audit;
- full lifecycle, validation, bag, candidate, compiler, and runtime suites;
- profile switch, reset, hash import/export, and configuration reload tests;
- malformed catalog/storage/runtime-boundary fixtures;
- no evaluator-less or unclassified requirement enters the production catalog;
- no stale runtime plan after any invalidation source;
- published presentation arrays are never mutated in place.

### Performance

- zero route rebuilds on unchanged draw frames;
- zero provider-domain rebuilds when only presentation changes;
- bounded candidate projection scratch state;
- no per-frame topology deep copy;
- no repeated control-registry scan in room/batch draw loops;
- allocation measurements for the largest G batch, all N hub targets, H cages,
  O wheels, and full four-biome prefixes.

### Documentation

- `docs/README.md` points to the revamp set;
- all revamp status language matches implemented behavior;
- retained gameinfo audits are marked evidence rather than authority;
- no deleted architecture is described as live;
- runtime callback matrix and any unresolved in-game probes are recorded near
  the implementation they govern.

### Integration Validation

Run the module checks first:

```bash
lua tests/all.lua
luacheck src tests
rtk git diff --check
```

Then from the shell repo run, as appropriate:

```bash
lua tests/smoke.lua
ModpackTools/run ModpackTools/validate_platform_versions.py
ModpackTools/run ModpackTools/local_test/all.py
ModpackTools/run ModpackTools/local_deploy/deploy_all.py --fast
```

Use the overwrite deploy only when relink/regeneration is actually required.
Never edit deployed profile copies directly.

### Git Closeout

For every publishable child checkpoint:

1. validate the Run Planner child repo;
2. commit with a Conventional Commit message;
3. push `codex/planner-revamp`;
4. verify the child worktree and branch status;
5. only then stage the Run Planner submodule pointer in the shell repo;
6. run the appropriate shell validation;
7. commit and push the shell pointer.

The shell must never point to an unpushed child revision.

## Test Migration Policy

Old tests are evidence of scenarios, not suites to preserve.

Retain a scenario only when it asserts a revamp contract. Rewrite it with:

- stable route/biome/control/local-slot identities;
- layout-specific semantic commands instead of storage-position writes;
- full canonical/history evidence where timing matters;
- exact declaration facts instead of sample defaults;
- shared selected/candidate rule functions;
- explicit completeness, invalid, and contract-failure expectations;

Delete tests whose subject is:

- `PlannerDraft` roundtrip or revision counters;
- positional room/door/offer codecs;
- form participant or form-address lookup;
- default materialization into an incomplete draft;
- UI rendering of the old F sample document;
- placeholder biome panels treated as implemented behavior;
- validation rules that encode incorrect creation/appearance semantics;
- passing fake-ImGui behavior as proof of runtime interaction.

Keep or recreate only contract-neutral harness utilities after reviewing that
they contain no old semantic assumptions.

## Stop Conditions

Stop the current checkpoint and return to its authority document when:

- a concrete game fact is missing or contradicts the catalog;
- a requirement cannot be classified;
- a needed control or local slot was not statically bounded;
- a declared layout kind lacks topology, history, or UI registry coverage at
  the capability being claimed;
- generic layout code needs a switch on a concrete biome or room name;
- a continuation override needs a lifecycle counter rather than
  topology-visible structural context;
- topology needs a duplicate top-level control;
- a consumer needs private storage aliases;
- materialization needs to mutate authored state;
- selected and candidate legality begin to diverge;
- runtime needs to re-evaluate eligibility, force, or rewards;
- draw requires per-frame rebuild/allocation to remain correct;
- a profile/reset flow cannot invalidate derived state coherently.

Do not resolve these by adding a fallback or local exception. Update the owning
design contract, then resume from the earliest affected checkpoint.

## Completion Definition

The revamp implementation is complete only when:

- both routes and all F-Q biomes use the new static-control/Biome-Plan model;
- F/G/H/I/O/P/Q use `LinearBiome`, N uses `HubBiome`, and both layout kinds
  share the common canonical materializer without sharing history/UI behavior;
- authored state survives topology editing and profiles, while Lib reset to
  defaults clears all persisted planner state;
- complete plans materialize every generated peer and local child correctly;
- lifecycle history and validation cover every supported room/reward rule;
- candidate feedback is semantic, directly resolved, and allocation-stable;
- valid configured prefixes compile to concrete runtime instructions;
- runtime consumes those instructions and hands unconfigured suffixes to
  vanilla;
- the old implementation and superseded documents exist only in Git history;
- module, shell, deployment, and in-game acceptance checks pass.

There is no completion state in which the old and new planners coexist behind
a compatibility switch.
