# Route History Builder / Validator Boundary

## Progress

- Slice 1 complete: builder-side selected room materialization now lives in
  `history/materialize_room.lua`.
- `history/step.lua` has been removed so "step" can be reclaimed by the
  validator walker.
- Slice 2 complete: `history/validator/walker.lua` reconstructs validation
  steps from the completed ledger, including room, sibling, variant, and reward
  candidates. Tests compare its output against the temporary builder-stamped
  candidate tables before live validators switch over.
- Slice 3 complete: `validator/candidates.lua` and its room/sibling/variant/
  reward subvalidators now consume walker steps instead of raw history entries.
  Builder tests no longer assert candidate tables on materialized entries.
- Slice 4 complete: builder-stamped `roomCandidates`, `siblingCandidates`,
  `variantCandidates`, and `rewardCandidates` have been removed from history
  entries. O/Thessaly multi-encounter reward candidates are now derived by the
  walker from topology policy plus selected encounter facts.
- Slice 5 complete: picked-entry, route-requirement, deadline, force-pressure,
  and template-specific structure validators consume validator walker steps.
  Materialized history entries no longer carry `entry.phases`; the walker is
  the phase authority.
- Slice 6 complete: force pressure now computes active legal force candidates
  from walker offer contexts. Missed exact/deadline force candidates are only
  allowed when generated exits are saturated by other active forced candidates,
  covering H/Echo crowding and fixed-linear force-group deferral.

## Contract

This document is the contract for the route-history pipeline. It replaces the
earlier hybrid model where `history/step.lua` built history entries and stamped
candidate timing at the same time.

The chosen policy is:

```text
template form
  -> builder/materializer
      emits selected history facts only
  -> validator walker
      computes timing phases, candidates, and legality
  -> feedback
      translates findings back to template/form coordinates
```

The builder and validator should not cooperate mid-build. The builder creates a
complete selected-route ledger. Validation then walks that ledger as a separate
pass.

## Why This Boundary

The route history system is replacing the older row-stream context model. The
main goal is to make one stable fact artifact, the history ledger, then have all
route rules read the same artifact.

The hybrid builder-step model made ownership unclear:

- the builder emitted selected entries;
- `history/step.lua` also stamped `phases`, room candidates, sibling
  candidates, and reward candidates;
- candidate validators consumed those stamped candidate tables later;
- structure validators still did their own history walks;
- force pressure needed a second validator-side projection because the existing
  "step" was tied to build-time mutation.

That shape works mechanically but creates the same class of bugs repeatedly:
"current room", "picked next room", "other door", and "availability timing" are
defined in more than one place.

The new boundary makes timing a validator concern. A generated candidate is not
a selected history fact; it is a validation question asked at a point in the
history walk.

## Ownership

### Template / Form

Templates own storage, rendering, local form completion, and render gates.

Templates may know enough local structure to decide:

- which controls exist;
- whether required user inputs are filled;
- how many visible sibling/other-door controls should render;
- when a locally selected terminal row hides later rows.

Templates must not decide route legality. They should not enforce force
pressure, depth eligibility, reward legality, NPC spacing, or route-wide caps.

Template snapshots should:

- preserve selected keys and blanks;
- include `formAddress` for row and child controls that can receive feedback;
- include the selected route shape in template row language;
- omit resolved declaration objects;
- omit generated candidates;
- omit invalid rows and value-state decoration.

If the form is incomplete, the route context should return completion feedback
and should not ask the builder to materialize fake default rows.

### Builder

`src/mods/route/history/builder.lua` is the route materializer.

It should:

- walk route biomes in route order;
- retrieve one complete snapshot per configured biome;
- look up the biome declaration;
- dispatch to the adapter named by the declaration;
- maintain route-level selected counters such as room-history ordinal and run
  encounter depth;
- append declaration timeline entries after a successfully built biome;
- run selected-loot emission over emitted room entries.

It should not:

- validate route legality;
- compute candidate lists;
- color/drop options;
- decide force pressure;
- decide reward legality;
- attach room/sibling/reward candidates to history entries.

The builder can compute selected-path counters because those are facts of the
selected ledger. Candidate timing contexts are not builder output in the target
model.

### Adapter

Adapters translate template row language plus biome declaration facts into the
shared selected-history language.

Adapters own biome-specific traversal shape:

- fixed linear biomes;
- H cage choices;
- I goal/preboss choices;
- O multi-encounter ships;
- N hub/pylon/side-room traversal.

Adapters should emit selected entries and selected topology facts only:

- selected room key, role key, option key;
- selected topology exits that were generated at that point;
- selected reward metadata;
- form/source addresses for feedback;
- structural costs needed to materialize selected counters.

Adapters should not generate candidate tables. If an adapter needs a helper for
entry emission, that helper should be builder-facing and named as materializing
selected entries, not as a validator step.

### History Ledger

The history ledger is the selected fact record. It should be enough to replay
route timing and selected outcomes.

Room entries may contain:

- `kind = "room"`;
- route/biome identity;
- selected room identity;
- selected role/option keys;
- selected topology exits;
- selected reward summary;
- selected costs and counters;
- source/form coordinates.

Loot entries may contain:

- acquired loot;
- pending shop offers;
- generated offer facts when needed to represent a selected model such as
  Ephyra hub generated doors.

The ledger should not need to contain:

- all possible room candidates;
- all possible sibling candidates;
- all possible reward candidates;
- candidate availability contexts.

Those belong to the validator walker.

### Validator Walker

The validator walker is the canonical route lifecycle reader.

It walks the completed history ledger and declarations in route order and
computes, for each validation point:

- selected entry facts;
- entry phase facts;
- offer/generation phase facts;
- current room candidates;
- picked-door candidates;
- sibling/other-door candidates;
- reward candidates;
- force-pressure active candidates;
- route-wide query state needed by validators.

This is where `step` language belongs in the target model. A validator step is a
read-only interpretation of the already-built ledger, not a builder mutation.

The walker should expose a small stable shape, for example:

```lua
{
    history = history,
    biome = biome,
    entry = entry,
    index = index,
    selected = {
        role = role,
        option = option,
    },
    phases = {
        generated = generatedContext,
        entry = entryContext,
        offer = offerContext,
    },
    topology = {
        exits = generatedExits,
        generatedExitCount = generatedExitCount,
    },
    candidates = {
        rooms = roomCandidates,
        siblings = siblingCandidates,
        rewards = rewardCandidates,
    },
}
```

Exact field names can change during implementation, but the ownership should
not.

### Validators

Validators consume walker steps and declarations. They speak game facts, not
template layout.

Structure validators should cover:

- selected picked-entry legality;
- previous room requirements;
- route caps and max creation;
- next-room tag rules;
- force pressure;
- deadline requirements;
- template-specific structural rules that are still game-domain rules.

Candidate validators should cover:

- room candidate availability and caps;
- sibling candidate availability and conflicts;
- variant candidate availability;
- reward candidate legality.

Reward, NPC, and feature validators should use the same history/query/walker
facts where possible. They should not revive row-stream context.

Validators should emit findings/invalids with game-domain codes and payloads.
They may include source coordinates carried by the ledger or candidates, but
they should not read template storage directly.

### Feedback

Feedback is the reverse adapter.

It translates validation findings into:

- route status messages;
- row/control value states;
- reward value states;
- related markers;
- inactive-row metadata;
- topology control metadata.

Feedback may translate coordinates, such as a picked-next invalid that renders
on the current room's "Picked Door" control. Feedback should not solve route
legality or rebuild timing.

## Resolved Mismatch

The original hybrid model has been removed:

- `builder.lua` dispatches adapters and emits selected history only.
- `history/step.lua` has been removed.
- materialized history entries no longer carry `entry.phases` or candidate
  tables.
- candidate and biome-structure validators consume validator walker steps.
- builder tests no longer assert candidate tables on built history entries.

Force-pressure work can now build on the validator walker as the lifecycle
authority.

## Target File Roles

Recommended file direction:

- `history/builder.lua`: route-level materializer.
- `history/adapters/*.lua`: biome-specific selected ledger adapters.
- `history/materialize_room.lua` or similar: builder-side selected-entry helper,
  replacing the builder-facing parts of `history/step.lua`.
- `history/validator/walker.lua` or similar: validator-side route step walker.
- `history/candidates/*.lua`: pure candidate factories used by the validator
  walker, not the builder.
- `history/validator/candidates/*.lua`: candidate legality checks over walker
  output.
- `history/validator/biome_structure/*.lua`: selected structure validators over
  walker output.

The name `step.lua` should not remain ambiguous. If kept, it should belong to
the validator walker, not the builder materializer.

## Migration Plan

### Slice 1: Split Builder Materialization From Candidate Stamping

Create a builder-facing materialization helper by extracting from
`history/step.lua` only:

- selected room entry emission;
- selected counter updates;
- selected phase/cost values needed to keep history counters correct;
- topology/reward attachment supplied by adapters.

Adapters should call this helper instead of `routeStep.stepRoom`.

At the end of this slice, builder output may still carry `phases` temporarily,
but candidate tables should be optional or clearly marked migration-only.

### Slice 2: Add Validator Walker

Add the validator walker that reads built history and declarations and produces
validation steps.

It should compute:

- selected declaration role/option;
- generated/entry/offer contexts;
- room candidates;
- sibling candidates;
- variant candidates;
- reward candidates;
- generated topology exits.

Candidate factories move under this walker call path. They should receive
explicit availability context from the walker.

### Slice 3: Move Candidate Validation To Walker Output

Change `validator/candidates.lua` so it iterates validator steps, not raw history
entries.

Candidate validators should consume `step.candidates.*` rather than
`entry.roomCandidates`, `entry.siblingCandidates`, `entry.variantCandidates`,
and `entry.rewardCandidates`.

After this slice, builder tests should stop asserting candidates on history
entries. New validator/walker tests should assert candidate timing.

### Slice 4: Remove Builder-Stamped Candidates

Delete builder-side candidate stamping from the materialization path.

Remove from history entries:

- `roomCandidates`;
- `siblingCandidates`;
- `variantCandidates`;
- `rewardCandidates`.

Keep selected facts and topology only.

### Slice 5: Move Structure Validators To Walker Output

Move picked-entry, route-requirement, deadline, and template-specific structural
validators to consume validator steps.

This unifies selected-entry legality and candidate legality around the same
timing contexts.

### Slice 6: Reapply Force Pressure

Reapply the stashed force-pressure work on top of the validator walker.

Force pressure should:

- walk the same step stream as room eligibility;
- compute active legal force candidates from current step facts;
- track satisfied/closed candidates and groups;
- permit missed deadline/exact-force candidates only when generated doors are
  saturated by other active force candidates;
- emit the first invalid at the generated-door step.

The stashed work is named:

```text
wip-force-pressure-step-boundary
```

It should be mined for tests and behavior, not replayed blindly.

## Force Pressure Policy To Preserve

Force pressure is not an after-the-fact deadline-only check. It is a stateful
walk over generated doors.

At each validator step:

- gather force candidates whose force window is active;
- require normal availability to be satisfied before the candidate can count as
  active pressure;
- ignore grouped candidates if their group was already closed by a picked
  candidate;
- count generated doors occupied by active force candidates;
- if a hard/exact/deadline candidate is missing, the row is valid only if every
  generated door is occupied by another active force candidate;
- exact-force candidates can expire after their exact row if legally crowded
  out;
- min/max force candidates can persist past max while still eligible and not
  satisfied/closed.

For H Echo:

- Echo is exact force at BDC 3 and availability exact BDC 3;
- Echo + ordinary combat is valid;
- two miniboss doors can crowd Echo out;
- one miniboss plus ordinary combat is invalid because ordinary combat consumed
  a door while Echo was active.

## Audit Checklist

Before a boundary cleanup commit is accepted:

- builder does not attach candidate tables;
- validators do not depend on candidate tables stored in history;
- builder tests do not assert candidate tables on history entries;
- validator/walker tests assert candidate timing and value-state findings;
- candidate availability always uses explicit walker-provided context;
- feedback only translates findings and route metadata;
- force pressure consumes the same walker steps as room eligibility;
- no new template route-legality checks are introduced.

## Non-Goals

- Do not implement reward bags in this pass.
- Do not rewrite runtime execution planning in this pass.
- Do not make HubPylon linear.
- Do not move side rooms back to a separate data stream.
- Do not make feedback infer route timing.
- Do not add compatibility shims for old snapshots unless a released persisted
  state requires it.
