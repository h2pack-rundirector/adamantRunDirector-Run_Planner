# Validation Model

## Purpose

Validation is the game-rule authority for complete canonical plans. It does
not author Biome Plan state, invent missing choices, or render UI controls.

```text
controls decide completeness
-> materialization emits canonical facts and candidates
-> history establishes lifecycle state
-> validators decide legality
-> feedback returns to semantic owners
```

## Inputs

The validator receives:

- a complete canonical route-prefix plan;
- route and declaration catalogs;
- materialized lifecycle history;
- candidate records exported by Biome Plan, batch, and node owners;
- semantic source and topology location metadata on authored facts.

Incomplete Biome Plan state does not enter game validation. Completeness emits
its own findings and stops materialization at the incomplete biome boundary.

## Outputs

Validation emits:

`findings`
: Blocking or warning records about selected/authored facts.

`candidateResults`
: Presentation policies for provider-owned candidate values.

Both preserve the source and location supplied by materialization:

```lua
{
    code = "room_depth_unavailable",
    severity = "invalid",
    phase = "room.generate_next",
    source = {
        routeKey = "Underworld",
        biomeKey = "F",
        gameRoomKey = "F_Story01",
        aspect = "nextRoomTarget",
    },
    location = {
        biomeControlId = "Underworld_F",
        nodeId = 17,
        parentNodeId = 12,
        doorIndex = 2,
    },
    payload = {
        requiredBiomeDepthMin = 4,
        actualBiomeDepth = 3,
    },
}
```

The validator may compare game room keys. It never treats them as occurrence
addresses or inspects storage rows, templates, widgets, or ImGui ids.

## Validation Layers

### Scope Validation

Scope validation checks that configured biomes form a complete route prefix in
the declared route order. It does not walk room or reward legality.

### Structural Validation

Structural validation checks canonical physical facts:

- room keys exist in declarations;
- generated doors reference declared exits;
- generated door counts and exit constraints are satisfied;
- selection shape is valid for the batch rule;
- the selected/visited targets match the entered sequence;
- terminal/preboss shape is satisfied;
- every generated occurrence has compatible typed state;
- room creation caps count generated occurrences correctly.

For `MaxCreationsThisRun`, every generated door target counts when created,
including unselected peers. Same-batch doors are processed in generation order.
Rooms without an explicit cap are not made unique by the planner.

### Timing And Eligibility Validation

Timing validation checks at the correct lifecycle phase:

- room eligibility;
- force windows and force pressure;
- encounter-depth gates;
- biome-depth gates;
- room-history spacing;
- previous-room exit requirements;
- generated-door batch rules.

The validator names the actual counter axis. `depth` alone is not a valid
query. Force-pressure details live in `FORCE_PRESSURE_MODEL.md`.

### Reward Validation

Reward validation covers offer domains, entry requirements, offer-batch rules,
reward bags, and acquired loot history. See `../model/REWARD_MODEL.md`.

## Lifecycle Phases

Validation follows history phases:

```text
room.enter
room.encounters
room.offer_points
room.generate_next
room.commit
```

- next-room targets and generated-door rewards evaluate at
  `room.generate_next`;
- every generated peer contributes generation and offer facts;
- selected-door acquisition applies when the selected target is entered;
- N hub offers generate as one hub batch, then acquisition follows visit order;
- O wheel offers evaluate sequentially inside `room.offer_points`;
- `BiomeDepthCache` changes at `room.commit`;
- `BiomeEncounterDepth` changes with encounter events.

## Candidate Providers

The control that understands a semantic choice owns its allocation-stable
provider:

```lua
provider = {
    key = "nextDoorTarget",
    version = 12,
    values = stableValues,
    labels = stableLabels,
    hidden = mutableHidden,
    colors = mutableColors,
    messages = mutableMessages,
}
```

Examples include outgoing-batch targets and selection, reward/payload choices,
shop options, H cage roll, O wheel choices, N hub visits, and I reward kind.

The provider may rebuild values/labels only when its candidate domain changes.
Route-context changes update presentation arrays rather than reshaping values
during draw.

## Candidate Export

Materialization asks each semantic owner to export candidates. The generic
walker does not inspect storage or switch on template names.

```lua
owner:exportCandidates(out, context)
```

An exported record contains:

- semantic source;
- topology location;
- provider key and version;
- stable candidate key and optional cached index;
- game-language semantic payload.

```lua
{
    source = {
        routeKey = "Underworld",
        biomeKey = "F",
        gameRoomKey = "F_Combat03",
        aspect = "nextRoomTarget",
    },
    location = {
        biomeControlId = "Underworld_F",
        nodeId = 12,
        doorIndex = 1,
    },
    providerKey = "nextDoorTarget",
    providerVersion = 12,
    candidateKey = "F_MiniBoss02",
    candidateIndex = 7,
    semantic = {
        kind = "nextRoom",
        sourceRoomKey = "F_Combat03",
        exitIndex = 1,
        targetRoomKey = "F_MiniBoss02",
    },
}
```

The validator reads `semantic`. Feedback uses source/location/provider metadata
to return the result.

## Candidate Evaluation

Candidate evaluation is part of the normal history walk, not a separate route
walk for every control.

- `nextRoom` uses eligibility, exits, force pressure, creation caps, and timing;
- `rewardType` uses offer domain, entry requirements, and reward bag state;
- `devotionSource` uses acquired god history and payload duplicate rules;
- `shopOption` uses shop domain and replacement requirements;
- batch candidates use peer facts visible at the batch lifecycle phase.

Selected-value findings and candidate results use the same rule functions. An
invalid selected value produces both its presentation result and a blocking
route finding.

## Presentation Policy

Policy belongs to the failed condition:

- declaration-time impossible candidates can be absent;
- depth/declaration-range conditions may explicitly hide;
- route-context conflicts usually remain visible and invalid;
- selected invalid candidates are blocking findings;
- unselected invalid candidates affect option presentation only;
- profile-dependent or unsupported rules are explicit warnings or failures;
- enrichment colors appear only while the route scope is valid.

Do not infer UI behavior from a broad `impossible` category.

## Feedback Application

Feedback resolves:

```text
location.biomeControlId
-> Biome Plan
-> node/batch/biome owner
-> provider or semantic component
```

Provider feedback applies only when `providerVersion` still matches. Otherwise
the route rebuilds rather than applying stale candidate indexes.

Feedback mutates prepared hidden/color/message arrays. Draw reads those arrays
directly and does not recompute validity.

## Error Horizon

The first blocking finding defines the presentation horizon. Downstream content
may become grey/inactive and enrichment is suppressed, while the canonical plan
and history remain unchanged. Route status and markers are the common invalid
reporting path; inline invalid labels are not reintroduced.

## Requirement Handling

`REQUIREMENTS_DSL.md` owns normalized game predicates. Unknown kinds are
contract failures. Requirements that depend on save state or unmodeled systems
produce explicit unsupported/profile policies rather than defaulting valid.

## Performance Rules

- no per-frame candidate or address allocation;
- stable candidate arrays between dirty rebuilds;
- one history/validation walk per dirty route rebuild;
- feedback applies by cached control/node/provider lookup;
- builders and validators do not repeatedly query nested UI internals.

## Non-Goals

Validation does not:

- validate incomplete control state;
- invent default rooms or rewards;
- render or mutate authored UI state;
- know storage rows, node-template internals, or widget aliases;
- model probabilities;
- compensate for incomplete declarations with fallbacks.

## Supporting Docs

- `../ui/BIOME_PLAN_CONTROL_MODEL.md` owns topology and control ownership.
- `../ui/FORM_FEEDBACK_CONTRACT.md` owns completeness and feedback routing.
- `../pipeline/TIMELINE_EVENTS.md` owns lifecycle phases.
- `../model/REWARD_MODEL.md` owns reward validation and bag simulation.
