# Run Planner Revamp

## Status

This directory defines the target architecture for a clean Run Planner
rewrite. It is forward-looking design guidance, not a description of the
current implementation.

The superseded `docs/system_design/` and `docs/progress/` trees are archived on
`codex/fresh-planner-spine`. The remaining `docs/gameinfo/` files are
non-authoritative audit evidence. Neither can override documents in this
directory.

The legacy implementation is archived on `codex/fresh-planner-spine`. The live
rewrite branch now implements the managed-module skeleton, headless catalog,
and the static-control and managed-persistence foundation of Checkpoint 2. The
first specialized prototype implements typed `StandardCombat` controls with a
generic bag-selection component; the reward-hierarchy review below will
replace that component before the slice is finalized. The remaining room
templates still use an explicit transitional adapter. System-wide composition
and subsystem-local dependency injection are in place. The production UI
remains the explicit unavailable-status shell.

The six-document set completed coherent design review and was locked on
2026-07-14. Questions deliberately assigned to a later biome implementation
checkpoint are not open architecture blockers.

Locked means implementation proceeds from these authorities without another
speculative redesign pass. It does not prohibit evidence-driven corrections:
when implementation or game-data verification contradicts a contract, update
the owning authority and resume from the earliest affected checkpoint rather
than adding a workaround.

## Reading Order

1. `DOMAIN_MODEL.md`
   defines the planner concepts and ownership boundaries without UI or storage
   details.
2. `GAME_DATA_REFERENCE.md`
   records the verified vanilla facts, biome bounds, and deliberate planner
   simplifications on which the domain depends.
3. `UI_PERSISTENCE_MODEL.md`
   maps the domain to ModpackLib controls, managed storage, profiles, reset,
   candidates, feedback, and immediate-mode drawing.
4. `BIOME_RULES.md`
   defines only the structural extensions for F through Q.
5. `MATERIALIZATION_AND_VALIDATION.md`
   defines lifecycle history, counter views, force pressure, reward bags,
   validation, and canonical/execution-plan compilation.
6. `IMPLEMENTATION_GUIDE.md`
   defines the clean-reset sequence, checkpoints, tests, and removal
   criteria for the current code.

These six documents are the complete, locked revamp design and
implementation-guidance set. Implementation follows
`IMPLEMENTATION_GUIDE.md`.

The supplemental `room_controls/` specification set expands the locked Room
Control direction into one reviewable contract per registered room template.
It is subordinate to the six authority documents above, but it is the
implementation contract for Checkpoints 2 and 4. Template implementation must
not begin until the corresponding specification has been reviewed.

The review-draft
[`REWARD_HIERARCHY.md`](room_controls/REWARD_HIERARCHY.md) defines the proposed
bottom-up reward-component graph. Reward-control implementation is paused at
the current prototype until that hierarchy is reviewed and locked.

[`REWARD_CONSUMER_AUDIT.md`](room_controls/REWARD_CONSUMER_AUDIT.md) verifies
the concrete store, inherited filter, and forced-reward provenance for every
supported reward producer. Its listed declaration reconciliations precede the
hierarchy implementation.

[`ROOM_CONTROL_HANDOFF.md`](ROOM_CONTROL_HANDOFF.md) records the reviewed Room
Control design state, verified game-data findings, and the sequencing context
for the remaining template implementations.

## Authority Boundaries

Each fact has one home:

| Concern | Authority |
| --- | --- |
| Planner concepts and semantic ownership | `DOMAIN_MODEL.md` |
| Vanilla behavior and planner divergences | `GAME_DATA_REFERENCE.md` |
| Lib controls, storage, profiles, reset, and draw lifecycle | `UI_PERSISTENCE_MODEL.md` |
| Biome-specific topology and reward extensions | `BIOME_RULES.md` |
| History, validation, and compilation | `MATERIALIZATION_AND_VALIDATION.md` |
| Rewrite order and acceptance checks | `IMPLEMENTATION_GUIDE.md` |

Documents should reference an authority instead of copying its rules. Biome
documents must not redefine the general room model. UI documents must not
invent game facts. Implementation guidance must not become a second design
authority.

## Architectural Spine

The revamp preserves one declarative-to-derived planning spine. Static module
construction establishes the immutable vocabulary:

```text
raw declarations
  -> normalized catalog
  -> templates, batch rules, and static control/storage manifests
```

Each committed Route Plan revision then processes its configured biomes in
route order through one pure derived pipeline:

```text
catalog + committed Route Controls, Biome Plans, and Room Controls
  -> for each configured biome in route order:
       check biome completeness
       -> materialize one canonical biome snapshot
       -> append lifecycle events to game-language history
       -> validate that biome against prior and current history
       -> stop on incomplete or invalid; otherwise continue
  -> prepared presentation state for the processed prefix
  -> execution-plan compilation when every configured biome is complete and valid
  -> atomically publish one derived revision
```

The short form is:

```text
declaration -> catalog -> materialization -> history -> validation -> feedback
```

Materialization is an essential boundary: the catalog alone cannot produce
history because history depends on the concrete topology and room-local state
authored for each biome. An incomplete biome produces completeness feedback
but no canonical biome snapshot and no validator result. A complete invalid
biome is validated, produces feedback, and prevents later biomes from being
processed.

The derived pipeline never writes authored state. Feedback is translated into
non-persisted presentation state during the commit rebuild. Draw only consumes
that published state and stages the next authored edit:

```text
authored edit
  -> commit
  -> materialization/history/validation
  -> prepare and atomically publish presentation/execution state
  -> dumb draw of current authored and prepared state
  -> authored edit
```

Compilation is the successful runtime branch of validation, not part of the
feedback mutation path. Runtime consumes compiled instructions and never
re-solves declaration, history, eligibility, or UI decisions.

## Locked Direction

The revamp starts from these decisions:

- Route declarations own ordered biome sequences.
- Each Route Plan is identified by its route key; it does not persist an
  independently selected route.
- Active UI route and biome are transient navigation. Runtime route comes from
  live game context.
- The configured scope is an ordered route prefix of zero through all declared
  biomes. The persisted default is an empty prefix for both routes, leaving
  both routes entirely vanilla after profile creation or reset.
- The universe of routes, route-biome steps, game rooms, room templates, and
  room controls is known before module activation.
- Each route-biome step has one statically materialized control instance for
  every supported top-level concrete game room.
- Bounded room-internal children use stable parent-local slots rather than
  dynamic or duplicate top-level controls.
- A Biome Plan owns generated batches, room links, and picked state.
- A room control owns the authored state and reward-producer binding local to
  that room.
- Outgoing topology belongs to the Biome Plan, never to a target room control.
- Picked and unpicked generated rooms use the same room-control representation.
- Unpicked rooms are dead leaves. Their offered rewards remain materialized.
- The planner requires injective room-control use within a biome plan.
- For ordinary combat rooms this is deliberately stricter than vanilla:
  repeated unentered combat-map creation is canonicalized to distinct eligible
  combat room keys.
- Game creation caps, appearance caps, force windows, and eligibility remain
  separate declaration facts.
- Validation uses game-domain facts and semantic control addresses; it does
  not inspect widget or storage internals.
- Runtime consumes a compiled execution plan and does not re-solve authored UI
  decisions.
- Every published result is tied to its source authored revision; committed
  changes make older execution plans unusable before rebuilding.
- A configured prefix outside the currently active contiguous domain is
  rejected rather than clamped or allowed to expose a headless biome.
- The current implementation and its persisted draft shape are not migration
  contracts.

## Rewrite Policy

The legacy documents are harvested, not edited into the new shape. Useful
facts must be reverified against current code or game data before entering this
set.

At rewrite start:

1. update `docs/README.md` to make this directory authoritative;
2. remove superseded design and progress documents rather than keeping a
   permanent in-tree legacy archive;
3. reset the implementation in place and rebuild in dependency order;
4. preserve only external contracts and tests that the revamp explicitly
   adopts.

Git history is the archive for the removed design and implementation.
