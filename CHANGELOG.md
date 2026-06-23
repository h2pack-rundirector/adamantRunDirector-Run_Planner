# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [0.2.0] - 2026-06-23

### Added

- run-planner: add route-safe room colors (
c0cc10)
- run-planner: compact combat labels (
f66f07)
- run-planner: route feature spawns (
f43d98)
- run-planner: route npc encounters (
33527a)
- run-planner: route preboss shop rewards (
05d28e)
- run-planner: route preboss free rewards (
fac710)
- run-planner: model preboss reward offers (
964f11)
- run-planner: route planned rewards (
92b37b)
- run-planner: trace reward routing (
995efb)
- run-planner: route ephyra hub doors (
fa4d4c)
- run-planner: route fields and tartarus (
2d37f7)
- run-planner: route thessaly combat counts (
a1e2d5)

### Fixed

- run-planner: preserve room swap rewards (46d176c)
- run-planner: simplyfing H bridge room modeling (
009950)
- run-planner: stabilize route depth and inactive ordering (
da475a)

## [0.1.0] - 2026-06-23

### Added

- run-planner: improve route feedback (
3c296a)
- run-planner: dim invalid route tail (
672b50)
- rewards: track conflict provenance (
cc9407)
- run-planner: add reward row groups (
572ab0)
- run-planner: model O wheel rewards (
92243a)
- run-planner: model reward offer timing (
8031a9)
- run-planner: model encounter depth bounds (
df4973)
- planner: unify reward surfaces (
c4de23)
- run-planner: refine Tartarus route flow (
2b3349)
- route-ui: color invalid choices (
4e7d79)
- model trial route timing (
db564f)
- run-planner: model route rewards (
7f0245)
- run-planner: add reward legality (
53f19f)
- run-planner: add NPC disable mode (
350ec5)
- run-planner: model biome depth costs (
d5d77f)
- run-planner: add primitive room routing (
082724)
- run-planner: add route execution plan (
b4e69a)
- run-planner: clarify route layer toggles (
57a971)
- run-planner: add route layer toggles (
55c66b)
- run-planner: add route features (
f50da7)
- planner: add route feature planning (
450929)
- planner: add route NPC planning (
864d30)
- npcs: add route encounter declarations (
396287)
- run-planner: centralize rewards (
423241)
- run-planner: add route god source (
374fc4)
- run-planner: cache route status (
4c842b)
- run-planner: add route validation rules (
aedd4a)
- run-planner: add Tartarus route control (
ae6d4d)
- run-planner: add Fields route control (
bc8703)
- run-planner: add Thessaly route control (
d12796)
- run-planner: add ephyra route planning (
e93d43)
- run-planner: add route planner controls (
0ebf9d)
- run-planner: wire route rewards (
b141df)
- run-planner: add route reward controls (
7609d2)
- add route planner controls (
113224)
- model biome route data (
786a97)
- add planner scaffold (
350bf8)

### Fixed

- run-planner: gate target invalid decoration (
70582a)
- run-planner: mark related reward conflicts (
321a35)
- run-planner: color all invalid tabs (
4a9f4a)
- run-planner: clear reward constraint scratch (
913fac)
- run-planner: refresh reward invalidation (
cc94bd)
- run-planner: stop after first invalid (
a4bb54)
- rewards: align run progress bundles (
38d71c)
- run-planner: align F depth checks (
9f41a7)
- run-planner: require known encounter depth (
22709d)
- run-planner: refine Tartarus route completion (
da9b7d)
- run-planner: correct opening rewards (
3167b2)
- run-planner: add Thessaly deadline rule (
ef3603)

### Performance

- run-planner: cache room eligibility state (
5549d5)

### Changed

- rewards: store provenance occurrences (
f37cec)
- ui: centralize decorations (
3f85a3)
- run-planner: centralize reward legality (
b592a1)
- run-planner: simplify O rewards (
63bec7)
- run-planner: add reward route context (
8cc765)
- run-planner: add value state policy (
06498e)
- run-planner: unify dropdown states (
f20b1b)
- run-planner: thread reward states (
f30a7e)
- run-planner: trust internal assembly (
079e1b)
- route: add row subsystem facade (
439dcb)
- route: organize route internals (
83c8b1)
- route: organize reward assembly (
5c8631)
- run-planner: organize reward structure (
301d0c)
- run-planner: organize biome parser (
8a1232)
- run-planner: simplify module wiring (
dd6b6e)
- run-planner: split route control views (
e11566)
- run-planner: remove inline invalid UI (
ad5a2e)
- run-planner: centralize invalid labels (
aff246)
- run-planner: normalize reward items (
9827a8)
- route: centralize timeline counters (
2da881)
- run-planner: compute room history cost (
020fd7)
- run-planner: split route row counters (
42c73c)
- run-planner: model route depths (
aa779a)

### Changed

- Ported the template to the current ModpackLib module host, draw, state, action, and fallback UI APIs.
- Removed module-local Chalk/config scaffolding and legacy Setup deployment scripts.
