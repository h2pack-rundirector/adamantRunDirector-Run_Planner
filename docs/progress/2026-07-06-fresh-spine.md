# 2026-07-06 Fresh Spine Checkpoint

## Status

The fresh planner branch now has a clean active planning spine through route
evaluation, candidate feedback export/application, and first-pass generated
room legality checks.

Completed child commits:

- `a019143 docs: add fresh planner model`
- `e3cd445 refactor!: reset planner skeleton`
- `be59fb7 docs: organize fresh planner docs`
- `382a6ce feat(declarations): add catalog foundation`
- `4c3eac6 feat(declarations): add profile validation`
- `17f8694 feat(forms): add route materialization`
- `02d4fb9 feat(history): build route ledger`
- `42b8dab feat(validation): add structural checks`
- `f1594e3 feat(pipeline): wire route evaluation`
- `56cfe9c feat(pipeline): add candidate feedback`
- `ed4ffd4 feat(feedback): apply candidate results`

Completed shell commits:

- `6cd69fb chore: point planner to fresh spine`
- `63b0c3b chore: advance planner doc layout`
- `d6a2858 chore: point planner to form foundation`
- `760e232 chore: point planner to history ledger`
- `6b1a842 chore: point planner to structural validation`
- `37be6be chore: point planner to route pipeline`
- `1d843cc chore: point planner to candidate feedback`
- `60d1379 chore: point planner to feedback bridge`

## What Changed

- Fresh system docs were authored under `docs/system_design/`.
- Old `docs/system/` and `docs/wip/` notes were removed from the live docs
  tree because they described the old implementation or transient migration
  work.
- Legacy planner source and old tests were removed from the active branch.
- The Run Planner module now exposes a minimal loadable skeleton:
  - empty control templates;
  - empty route controls;
  - no-op logic attach;
  - a simple tab message pointing to `docs/system_design/`.
- Declaration loading now builds a structured catalog for routes, biome
  declarations, room templates, rewards, offer profiles, and requirements.
- Profile validation catches malformed reward/offer declarations at the
  declaration boundary.
- Route forms now distinguish incomplete draft data from complete canonical
  route plans.
- Complete route drafts can materialize into canonical plans without carrying
  form-only fields into history.
- Candidate providers own stable value/label arrays plus mutable hidden,
  color, and message arrays.
- Door candidate providers can export semantic candidate records with form
  return addresses, provider keys, provider versions, candidate keys, and
  candidate indexes.
- History construction now walks complete route plans into ordered lifecycle
  events and ledgers:
  - room history;
  - encounter history;
  - generated-door history;
  - reward-offer history;
  - loot history;
  - route counters for run encounter depth, biome encounter depth, biome depth
    cache, and room-history ordinal.
- Structural validation now checks selected route facts for:
  - declared room existence;
  - generated-door exit references;
  - generated-door target rooms;
  - generated-door count versus declared exits;
  - selected-door continuity into the next room node;
  - terminal room placement and generated-door suppression.
- The route pipeline now evaluates draft routes into one of three states:
  `incomplete`, `invalid`, or `valid`.
- Pipeline results now carry completion feedback, canonical plans, history,
  validation findings, candidate records, and candidate presentation results.
- Candidate feedback currently covers generated next-room target candidates for
  structural exit/target failures.
- Candidate feedback application now clears provider-owned feedback arrays and
  applies validator candidate results back to matching provider versions.
- Stale candidate results and missing providers are skipped with an explicit
  summary so route-context rebuild code can decide how to respond.
- History `room.generate_next` events now carry the timing counter snapshot
  used for generated next-room validation.
- Requirement-backed room eligibility now evaluates generated room targets at
  `room.generate_next` using explicit timing axes:
  - `BiomeDepthCache`;
  - `BiomeEncounterDepth`.
- Requirement composition supports `All`, `Any`, `Not`, and named requirement
  lookup at the validation boundary.
- Selected generated-door targets and next-room candidate records share the
  same room eligibility evaluation path.
- Generated room targets now also validate:
  - force windows after eligibility passes;
  - per-run room creation caps;
  - declared exit tag constraints against target room tags.
- Candidate `nextRoom` results use the same force-window, cap, and exit-tag
  checks as selected generated doors.

## Validation

Child repo:

```text
lua tests/all.lua
luacheck src tests
git diff --check
```

Shell repo:

```text
lua tests/smoke.lua
```

Latest observed results:

- `lua tests/all.lua`: 50 tests passed.
- `luacheck src tests`: 0 warnings, 0 errors.
- `git diff --check`: passed.
- `lua tests/smoke.lua`: smoke passed for 4 module entrypoints and 1
  coordinator pipeline.

## Current Boundary

The branch intentionally remains data/planning first. The old row-based route,
reward, biome, NPC, feature, and validation machinery is not wired.

Current implemented behavior is limited to the fresh declaration/form/history/
validation/pipeline path. Runtime hooks still do not consume an execution plan.

The active planning spine supports complete route drafts over the current
declaration catalog and the F/Erebus test surface. It does not yet implement
the full room eligibility model, force windows, reward bag simulation,
multi-biome scope, NPC/feature planning, Chaos detours, or runtime compilation.

Candidate feedback is present as a validator output lane and a provider
application bridge, but the only implemented semantic candidate kind is
generated next-room target validation. Reward candidate policies and broader
timing/eligibility candidate policies are still deferred.

Room eligibility currently supports only the explicit timing predicates needed
by the F/Erebus declarations: `BiomeDepthCache` and `BiomeEncounterDepth`.
Force-window validation, room creation caps, and exit-tag compatibility are
implemented for generated room targets and `nextRoom` candidates.

Full force-pressure validation is still deferred. The validator checks whether
a generated forced room is inside its declared force window, but it does not
yet require missing forced rooms to appear when pressure says they should.
Reward requirements and bag simulation are still deferred.

## Next Slices

The next implementation work should continue from
`docs/system_design/migration/IMPLEMENTATION_SEQUENCE.md`.

Near-term slices:

- add force-pressure validation that requires eligible forced rooms to appear
  in generated-door batches when physically possible;
- expand candidate export/evaluation beyond generated next-room targets;
- extend reward offer validation toward offer domains and reward bag
  simulation;
- wire candidate feedback application into route-control rebuilds once the
  control layer exists;
- add route scope and multi-biome history once the single-biome history and
  validator behavior are stable;
- defer runtime compilation until validated history and feedback semantics are
  stable.
