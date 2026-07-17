# Run Planner Revamp

## Status

This directory defines the target architecture for a clean Run Planner
rewrite. It is forward-looking design guidance, not a description of the
current implementation.

The superseded `docs/system_design/` and `docs/progress/` trees are archived on
`codex/fresh-planner-spine`. The remaining `docs/gameinfo/` files are
non-authoritative audit evidence. Neither can override documents in this
directory.

The legacy implementation is archived on `codex/fresh-planner-spine`.
Completed implementation work and the current frontier are recorded in
`IMPLEMENTATION_PROGRESS.md`; the complete checkpoint plan remains in
`IMPLEMENTATION_GUIDE.md`.

The original six-document set completed its initial coherent design review on
2026-07-14. The accepted biome-layout boundary was subsequently reconciled
through those same authorities, and the set was relocked on 2026-07-16. The
focused authored-editor contract was added afterward as
`UI_EDITOR_MODEL.md`; it refines the UI boundary without replacing the broader
domain or persistence authorities.
Questions deliberately assigned to a later biome implementation checkpoint
are not open architecture blockers.

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
4. `UI_EDITOR_MODEL.md`
   defines the concrete authored editor, Biome Plan persistence codec,
   decision-tree identity, semantic command binding, and spine-feedback
   resolution used by Checkpoint 4A.
5. `BIOME_RULES.md`
   defines only the structural extensions for F through Q.
6. `MATERIALIZATION_AND_VALIDATION.md`
   defines lifecycle history, counter views, force pressure, reward bags,
   validation, and canonical/execution-plan compilation.
7. `IMPLEMENTATION_GUIDE.md`
   defines all checkpoints, tests, and completion criteria.

These seven documents are the complete, locked revamp design and
implementation-guidance set. Implementation follows
`IMPLEMENTATION_GUIDE.md`. `IMPLEMENTATION_PROGRESS.md` is a separate mutable
status ledger and is not a design authority.

## Supplemental Implementation Contracts

The supplemental `room_controls/` specification set expands the locked Room
Control direction into one reviewable contract per registered room template.
It is subordinate to the seven authority documents above, but it is the
implementation contract for Checkpoints 2, 4A, and 4B. Template implementation
must not begin until the corresponding specification has been reviewed.

The locked
[`REWARD_HIERARCHY.md`](room_controls/REWARD_HIERARCHY.md) defines the bottom-up
reward-component graph and the order in which its primitives, bundles,
surfaces, and consuming Room Controls are composed.

[`REWARD_CONSUMER_AUDIT.md`](room_controls/REWARD_CONSUMER_AUDIT.md) verifies
the concrete store, inherited filter, and forced-reward provenance for every
supported reward producer.

## Authority Boundaries

Each fact has one home:

| Concern | Authority |
| --- | --- |
| Planner concepts and semantic ownership | `DOMAIN_MODEL.md` |
| Vanilla behavior and planner divergences | `GAME_DATA_REFERENCE.md` |
| Lib controls, storage, profiles, reset, and draw lifecycle | `UI_PERSISTENCE_MODEL.md` |
| Authored editor composition, Biome Plan codec, and UI feedback addressing | `UI_EDITOR_MODEL.md` |
| Biome-specific topology and reward extensions | `BIOME_RULES.md` |
| History, validation, and compilation | `MATERIALIZATION_AND_VALIDATION.md` |
| Rewrite order and acceptance checks | `IMPLEMENTATION_GUIDE.md` |

Current implementation status is intentionally absent from this authority
table; it lives in `IMPLEMENTATION_PROGRESS.md`.

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
  -> templates, batch rules, static controls, and plan-owned storage codecs
  -> collected module storage manifest
```

Each meaningful configuration lifecycle rebuild processes the committed Route
Plan snapshot through one pure derived pipeline:

```text
catalog + committed Route Controls, Biome Plans, and Room Controls
  -> normalize topology for every configured biome
  -> for each normalized biome in route order:
       check biome completeness
       -> materialize one canonical biome snapshot
       -> append lifecycle events to game-language history
       -> validate that biome against prior and current history
       -> stop on incomplete or invalid; otherwise continue
  -> prepared presentation state for every configured biome
  -> execution-plan compilation when every configured biome is complete and valid
  -> atomically publish one derived result
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

Configured biomes beyond that semantic horizon still receive inactive prepared
views from their already normalized topology; they are not treated as locally
checked or valid.

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
- The Route Control domain is capped by the contiguous
  `maximumEditablePrefix`; configuration expresses authored scope and does not
  by itself claim materialization, headless processing, or planner activation.
- The universe of routes, route-biome steps, game rooms, room templates, and
  room controls is known before module activation.
- Each route-biome step has one statically materialized control instance for
  every supported top-level concrete game room.
- Bounded room-internal children use stable parent-local slots rather than
  dynamic or duplicate top-level controls.
- A Biome Plan is a decision-tree object, not a Lib control. It owns its
  layout-derived bounded storage descriptor, reversible authored-state codec,
  generated batches, terminal transitions, companion links, room links, and
  picked state.
- A room control owns its authored `incomingReward` and any rewards produced
  by explicit room-local children or encounter offer points.
- Outgoing topology belongs to the Biome Plan, never to a target room control.
- Terminal exit population is layout-owned and remains separate from the
  terminal Room Control's local entry-offer policy.
- Picked and unpicked authored generated rooms use the same room-control
  representation. Unpicked authored rooms are dead leaves and their offered
  rewards remain materialized.
- The planner requires injective room-control use within a biome plan.
- That injectivity makes the unique Room Control key the top-level occurrence
  identity used by persistence, UI projection, materialization, and feedback;
  no separate occurrence ID exists.
- For ordinary combat rooms this is deliberately stricter than vanilla:
  repeated unentered combat-map creation is canonicalized to distinct eligible
  combat room keys.
- I's repeatedly offerable preboss does not relax that rule. A declined
  eligible preboss is a batch-derived physical offer with fixed creation and
  Shop door facts, not another Room Control occurrence. The singleton terminal
  control is referenced only by the entered terminal transition.
- Game creation caps, appearance caps, force windows, and eligibility remain
  separate declaration facts.
- Validation uses game-domain facts and semantic control addresses; it does
  not inspect widget or storage internals.
- Runtime consumes a compiled execution plan and does not re-solve authored UI
  decisions.
- Every meaningful configuration lifecycle event synchronously rebuilds one
  committed snapshot. Success atomically replaces the published result; failure
  clears it before surfacing the error.
- A configured prefix outside the currently editable contiguous domain is
  rejected rather than clamped. `maximumActivePrefix` separately bounds full
  planner-active semantic integration.
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
