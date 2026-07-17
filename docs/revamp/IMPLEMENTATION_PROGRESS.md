# Implementation Progress

## Purpose

This document records completed Run Planner revamp work and the current
implementation frontier. It is descriptive status, not a design authority or
a second implementation plan. The remaining work, checkpoint contracts, and
acceptance gates live in `IMPLEMENTATION_GUIDE.md`.

Update this file only when a coherent implementation slice has passed its
focused validation. Do not describe intended behavior here as implemented.

## Branch Boundary

The pre-revamp implementation and documents are archived on
`codex/fresh-planner-spine`. The clean implementation lives on
`codex/planner-revamp`. Git history remains the archive; no compatibility
bridge, persisted-draft migration, or live legacy implementation was carried
into the revamp branch.

## Completed Checkpoints

Completion below is scoped to each checkpoint's retained outputs. The later
layout review deliberately superseded the topology-facing declaration and
storage scaffolds from Checkpoints 1 and 2. Their accepted catalog facts,
controls, Room Control persistence, state-access boundary, and reset behavior
remain complete; the final layout authority is an entry gate of Checkpoint 3,
not a retroactive claim about the earlier implementations.

### Checkpoint 0: Archive and Green Reset

Completed by `733eb58 refactor!: reset planner for revamp`.

- removed the legacy planner implementation and behavior tests;
- established the minimal managed-module entry point and clean test harness;
- made `docs/revamp/` authoritative and removed superseded live design trees;
- retained packaging, module identity, assets, and shell integration;
- preserved the old implementation on `codex/fresh-planner-spine` and in Git.

### Checkpoint 1: Complete Catalog Foundation

Completed by the catalog and declaration sequence beginning with
`7a3ad21 feat(catalog): add planner foundation` and hardened by later
declaration commits.

- declared both routes and the complete F-Q room universe explicitly;
- normalized rooms, encounters, reward producers, requirements, batch rules,
  counters, caps, force windows, and the game facts used to derive finite
  topology bounds;
- established strict parsing, coverage, capacity, and game-data audits;
- embedded reward bindings as the single declaration authority;
- kept save-progression predicates and unfinished requirements out of
  production declarations.

The room, encounter, reward, requirement, counter, and structural game facts
established here remain the catalog foundation. The original topology-facing
declaration shape is the bounded superseded artifact; it is replaced at the
start of Checkpoint 3 as described below.

### Checkpoint 2: Static Controls and Managed Storage

Completed by the managed-state, composition, reward-component, and focused
Room Control sequence through
`5357f6d feat(planner): build focused room controls`.

- generated static Route and Room Control manifests from the catalog;
- bounded persistent storage for every route, biome, room, and local control
  slot;
- added managed UI/runtime state access and reset-to-defaults behavior;
- centralized composition in `systems.lua` with subsystem-local dependency
  injection;
- implemented the bottom-up reward component hierarchy;
- replaced transitional adapters with focused semantic controls for every F
  and G room;
- retained dormant bounded adapters for H, I, N, O, P, and Q;
- added implementation-support evidence without claiming topology,
  authored-editor, materialization, headless-pipeline, or planner-active
  support.

The focused Room Controls, reward components, managed-state boundary, and
composition root remain valid. The biome topology descriptors and their
persisted dispatch columns are the bounded superseded Checkpoint 2 artifact;
they are not the final Biome Plan storage model.

## Delivered Ahead of the Plan

Some Checkpoint 4B prerequisites were implemented while completing the static
control layer because they define the focused F/G control contracts:

- payload domains, reward primitives, counted bags, fixed and counted choices,
  shop profiles, forked-preboss composition, and persistence components;
- semantic snapshots and candidate-application ownership inside focused Room
  Controls;
- room-control specification and reward-consumer audit documents.

This does not complete Checkpoint 4B. Canonical materialization still depends
on the remaining materializer contracts after the Checkpoint 4A editor
foundation.

## Current Frontier

Checkpoint 3, Layout Topology and the F/G Structural Slice, is complete. Its
atomic declaration, catalog, and storage reconciliation is implemented:

- replaced raw `root`, `terminalRoomKeys`, top-level `batchRuleKey`,
  specialized-rule lists, deterministic-pair side tables, and room-level
  `fixed`/`terminal` flags with validated biome `layout` declarations;
- derived start, terminal, batch-rule, transition-rule, bounds, and persistent
  topology descriptors, including terminal exit policies and bounded companion
  links, from the selected layout kind instead of persisting dispatch keys;
- renamed authored encounter phase data to `decisionPhase` at the same authority
  switch, leaving no competing legacy field;
- kept verified room-local eligibility, force, exit, reward, encounter, and
  counter facts unchanged.

The production catalog now derives room roles and layout-specific persistence
from those declarations. Linear and hub authored state have separate bounded
descriptors; terminal companion capacity is declaration-derived; no persisted
batch, override, terminal-room, or transition dispatch key remains. The
completed Checkpoint 3 implementation currently centralizes physical authored
shape reads and writes in UI/runtime state access. Checkpoint 4A will
consolidate that accepted persistence behavior into plan-owned descriptors and
reversible codecs before the editor consumes it; the current adapter shape is
the explicitly superseded artifact, not a second authority to retain.

The first read-only topology slice is also implemented. Executable topology,
batch, and terminal-transition registries now compose a common long-lived
Biome Plan. `LinearBiome` reads layout-authored state through either runtime or
UI state access, derives Standard batches and `PrebossEntry`, walks the picked
spine, preserves unpicked peers, and rejects malformed ownership, identity,
exit, bound, selection, and continuation state. Incomplete but well-formed F
and G states remain readable, and normalized topology contains no Room Control
payload or presentation state. Plans are constructed only where every
declaration-selected executable dependency is registered. Plan availability
alone does not claim topology capability.

The second read-only topology slice is also implemented. Biome Plans now
delegate structural checks, ordered traversal, and semantic addressing to the
registered layout implementation. Standard batches require one target per
physical exit and one picked continuation; a selected linear source must close
through another batch or `PrebossEntry`. F and G structural gaps return ordered
findings for the start, physical target, picked continuation, or missing
continuation against the same semantic owner addresses traversal emits.
Complete F and G topologies traverse each start, batch, and generated peer,
including unpicked dead leaves, and their terminal transitions without ImGui,
canonical assembly, or history work. Traversal rejects incomplete topology.

Missing terminal companion links are likewise structural incompleteness;
illegal companion exits remain contact-boundary failures. This establishes the
contract needed by I without claiming I topology support. This read-only slice
did not yet publish topology capability evidence.

The writable topology slice is also implemented. The Biome Plan accepts the
complete LinearBiome command set only through `UiStateAccess`; runtime state
access remains read-only. Each command reads staged authored state, constructs
an unpublished full replacement, normalizes that proposal through the same
contact boundary as ordinary reads, and only then stages one bounded semantic
replacement. Invalid commands and malformed proposals therefore leave staged
state untouched.

Changing a selected start, picked target, or picked target link removes only
the incompatible downstream batches, targets, terminal transition, and
terminal companions. Explicit `ReplaceWithBatch` and
`ReplaceWithTerminalTransition` commands own continuation-form changes.
Unlinked Room Control persistence is never reset. Terminal-companion commands
are restricted to the policy that admits them, while `ClearTopology` clears
only layout-owned authored state.

G additionally proves fixed-start clearing and three-exit Standard batches;
its force, eligibility, and room-local differences remain outside topology.
Route composition now publishes validated `topology = true` evidence for F and
G, and biome support accepts exactly those two claims. This closes Checkpoint
3.

Checkpoint 4A is now in progress. Its first production slice consolidates
Biome Plan persistence ownership and mounts the thin authored editor:

- layout codecs own LinearBiome and HubBiome storage descriptors, reads, and
  replacements; the module manifest only collects their roots and generic
  state access no longer interprets either physical layout;
- short-lived runtime and UI plan refs expose the same semantic authored model;
- control preparation now precedes support composition, while Route Control
  instances derive their configured-prefix domains afterward from
  `maximumEditablePrefix`;
- F earns `authoredEditor = true`, making Underworld configurable as empty or
  F while Surface remains empty and G remains topology-only;
- the permanent horizontal route shell and vertical route/biome navigation
  expose Route and Erebus panels plus Settings;
- the LinearBiome projector and drawer expose start, batches, physical targets,
  picked continuations, one active continuation frontier, terminal
  replacement/removal, clearing, and referenced picked and unpicked Room
  Controls through semantic Biome Plan commands; repeated `Next Step`
  selectors and their transient storage have been removed;
- target selection is monotonic from unspecified to specified: the two-stage
  category selector browses atomic replacements without emptying an existing
  target, while decision removal owns target deletion;
- focused F Room Controls now draw their integrated reward, payload, shop,
  purchase, and forked-preboss state through prepared stable option domains;
- focused reward leaves now start from validated declaration-owned defaults:
  reward primitives own complete payload defaults, bags own primitive defaults, multi-store
  bindings own their initial store and required override, shop slots own their
  primitive defaults, and forked prebosses default to Shop;
- focused reward and entry-mode widgets are replacement-only. Store and
  primitive changes install complete subordinate defaults atomically, active
  reads reject empty persisted targets, and unused bounded payload capacity is
  retained only as dormant state. The bounded transitional manifests for later
  biomes inherit the same reward defaults without claiming that their deferred
  structural modes, phase counts, or side-room state are implemented;
- activation, meaningful commit, and setting-changing reload rebuild and
  atomically publish the committed authored view outside draw.

Focused fake-ImGui coverage proves semantic command translation, committed F
publication, picked and unpicked projection, and shared LinearBiome projection
against G. The remaining Checkpoint 4A work is structural and local-completeness
presentation, lifecycle/reset round-trip coverage, unchanged-draw allocation
coverage, and the in-game interaction probe. No canonical biome snapshot,
route validator, execution compiler, runtime hook, or planner-active claim is
active.

The lifecycle design has also been simplified before its Checkpoint 5
implementation: activation, meaningful commit, and meaningful reload will call
one synchronous rebuild. A successful rebuild atomically replaces the complete
published derived result; a contract failure clears the previous result before
surfacing. No configuration-revision or provider-version service remains.
