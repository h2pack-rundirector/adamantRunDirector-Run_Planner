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
  counters, caps, force windows, and finite topology bounds;
- established strict parsing, coverage, capacity, and game-data audits;
- embedded reward bindings as the single declaration authority;
- kept save-progression predicates and unfinished requirements out of
  production declarations.

### Checkpoint 2: Static Controls and Managed Storage

Completed by the managed-state, composition, reward-component, and focused
Room Control sequence through
`5357f6d feat(planner): build focused room controls`.

- generated static Route and Room Control manifests from the catalog;
- bounded persistent storage for every route, biome, room, and local slot;
- added managed UI/runtime state access and reset-to-defaults behavior;
- centralized composition in `systems.lua` with subsystem-local dependency
  injection;
- implemented the bottom-up reward component hierarchy;
- replaced transitional adapters with focused semantic controls for every F
  and G room;
- retained dormant bounded adapters for H, I, N, O, P, and Q;
- added implementation-support evidence without claiming topology,
  materialization, headless-pipeline, or planner-active support.

## Delivered Ahead of the Plan

Some Checkpoint 4 prerequisites were implemented while completing the static
control layer because they define the focused F/G control contracts:

- payload domains, reward primitives, counted bags, fixed and counted choices,
  shop profiles, forked-preboss composition, and persistence components;
- semantic snapshots and candidate-application ownership inside focused Room
  Controls;
- room-control specification and reward-consumer audit documents.

This does not complete Checkpoint 4. Canonical materialization still depends on
Checkpoint 3 topology and the remaining Checkpoint 4 materializer contracts.

## Current Frontier

Checkpoint 3, Biome Plan and Standard Topology, is the next implementation
checkpoint. No production route editor, canonical biome snapshot, validator,
execution compiler, or runtime hook is active.

The lifecycle design has also been simplified before its Checkpoint 5
implementation: activation, meaningful commit, and meaningful reload will call
one synchronous rebuild. A successful rebuild atomically replaces the complete
published derived result; a contract failure clears the previous result before
surfacing. No configuration-revision or provider-version service remains.
