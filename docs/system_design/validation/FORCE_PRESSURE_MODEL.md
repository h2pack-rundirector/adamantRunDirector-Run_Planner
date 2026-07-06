# Force Pressure Model

## Purpose

Force pressure is the batch-level rule that decides when generated next-room
doors must spend available generated-room slots on rooms with game force
metadata.

It is not selected-room legality. A generated target is locally legal when it
exists, satisfies the source exit, passes normal room eligibility, and has
creation capacity. Force pressure then validates the generated-door batch as a
whole.

The live-game data reference for biome-depth force behavior is
`../../gameinfo/FORCE_AT_BIOME_DEPTH_AUDIT.md`.

## Declaration Boundary

Force metadata belongs to room declarations when the game declares force on
that room:

```lua
F_Shop01 = {
    eligibility = { ... },
    force = {
        kind = "BiomeDepthWindow",
        axis = "BiomeDepthCache",
        start = 4,
        deadline = 6,
    },
}
```

Force metadata must not duplicate hard eligibility. If a room has a real upper
eligibility bound, model that in `eligibility`; do not encode it as the force
deadline.

For biome-depth min/max force data:

- `start` is when the room enters the force pool;
- `deadline` is when the room becomes hard pressure;
- after `deadline`, the room remains hard pressure while normal eligibility
  still allows it.

For exact-depth force data:

- `start` and `deadline` are the exact force depth;
- any exact-depth eligibility restriction should still be represented as normal
  room eligibility when the game applies it.

Do not model force windows as generic `All(>= start, <= deadline)` validation.
That shape turns the deadline into an upper bound and loses the persistent
pressure semantics.

## Unresolved Force Set

At the start of a biome validation walk, collect every room declaration in that
biome that has force metadata. This is the biome's unresolved force set.

At each `room.generate_next` event, unresolved force rooms are filtered for the
current batch:

- the room is still unresolved;
- the room passes normal room eligibility at this `room.generate_next`;
- the room's force window has started;
- the room has remaining creation capacity before this generated batch;
- at least one current generated exit can physically generate the room.

Rooms that fail this filter do not participate in pressure for the current
batch. They remain unresolved unless they were already generated.

Normal eligibility and force-window start are separate gates. A room with force
metadata does not count as force work before its force window starts, even if
its normal room eligibility would otherwise allow it.

When a generated door targets an unresolved force room, that room is removed
from the unresolved force set after the current batch is evaluated. Generation
is enough to satisfy generic force pressure; selection or entry is not required
unless a future game-specific rule explicitly says otherwise.

## Batch Pressure Algorithm

For each `room.generate_next` batch:

1. Build the eligible unresolved force candidates for this batch.
2. If none of those candidates have reached deadline, stop. The batch has no
   force-pressure finding.
3. If at least one eligible unresolved force candidate has reached deadline,
   the batch must spend available generated-room slots on eligible unresolved
   force candidates.
4. Compute:

```text
requiredForcedCount =
min(uniqueEligibleUnresolvedForceCandidateCount, generatedDoorCount)
```

5. Count unique generated door targets in the batch that are eligible unresolved
   force candidates for this same batch.
6. The batch is valid when:

```text
generatedForcedCount >= requiredForcedCount
```

This means a deadline room can be deferred only when the current batch is
already doing the maximum forced-room work the batch can represent. It can be
deferred by other eligible force candidates even if those other candidates have
not reached their own deadlines yet.

Duplicate generated doors for the same force room satisfy one unresolved force
candidate. They do not count as multiple forced rooms unless a future
declaration explicitly models a multi-creation force target.

## Local Target Legality

Selected generated-door targets and `nextRoom` candidate targets do not fail
only because their force metadata is inactive or outside its deadline.

Local target legality checks:

- target room exists;
- source exit exists;
- target room satisfies source exit tags;
- target room passes normal eligibility;
- target room has creation capacity.

Force pressure is evaluated against the complete generated-door batch. Candidate
validation projects the candidate target into the batch, then runs the same
batch-pressure rule.

## Candidate Feedback

A `nextRoom` candidate can create or resolve a force-pressure conflict.

Candidate evaluation should:

- project the candidate target over the current generated door;
- re-evaluate the batch's force-pressure result;
- emit candidate feedback only for conflicts introduced or preserved by that
  projected value.

This keeps force pressure visible in option feedback without treating force as
local target eligibility.

## Physical Exit Compatibility

The generic rule only counts force candidates that can be generated by at least
one exit in the current batch.

If a future biome has multiple forced candidates that can only fit mutually
exclusive structured exits, the validator should refine the count with an exit
matching pass. Until that case exists in the implemented surface, the generic
contract is:

```text
eligible for pressure = eligible room + capacity + at least one compatible exit
```

## Presentation

Selected-route pressure failures should be blocking findings on the
`room.generate_next` source address.

Candidate pressure failures should use an invalid presentation policy and
return through the candidate provider address. Suggested stable codes:

- `force_pressure_missing_room` for selected-route batches;
- `force_pressure_conflict` for projected candidate batches.

Finding payloads should include:

- source room key;
- deadline force room keys;
- eligible unresolved force room keys;
- generated forced room keys;
- required forced count;
- generated door count.
