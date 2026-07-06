# Validation Model

## Purpose

Validation is the game-rule authority for complete canonical plans. It does
not author draft form data, invent missing choices, or render UI controls.

The guiding rule is:

```text
Forms decide whether data is complete.
History materializes complete data into game facts.
Validators decide whether those game facts are legal.
Feedback applies validation results back to form participants.
```

## Inputs

The validator receives:

- complete canonical route plan;
- route scope;
- declarations;
- materialized history;
- candidate records exported by form providers into history.

Incomplete form state does not enter validation. If a biome or leaf is
incomplete, the form layer reports completion findings and the history builder
does not materialize fake room, door, reward, or candidate facts for it.

## Outputs

Validation emits two related outputs:

`findings`
: Blocking or warning records about selected authored facts.

`candidateResults`
: Presentation policies for candidate values owned by form providers.

Both outputs use source/form addresses as return addresses. Validators may
preserve these addresses, but they do not inspect UI internals.

Example finding:

```lua
{
    code = "room_depth_unavailable",
    severity = "invalid",
    phase = "room.generate_next",
    sourceAddress = { routeKey = "Underworld", biomeIndex = 1, roomIndex = 3, doorIndex = 2 },
    payload = {
        roomKey = "F_Story01",
        requiredBiomeDepthMin = 4,
        actualBiomeDepth = 3,
    },
}
```

Example candidate result:

```lua
{
    formAddress = { routeKey = "Underworld", biomeIndex = 1, roomIndex = 3, doorIndex = 2 },
    providerKey = "nextDoorTarget",
    providerVersion = 12,
    candidateKey = "F_Story01",
    candidateIndex = 5,
    presentation = "hide",
    code = "room_depth_unavailable",
    payload = { actualBiomeDepth = 3 },
}
```

## Validation Layers

Validation is layered by responsibility.

### Scope Validation

Scope validation checks route-level shape:

- configured biomes form a route prefix;
- configured biomes match the selected route order;
- every configured biome is complete before history materialization.

Scope validation should not walk room/reward legality.

### Structural Validation

Structural validation checks physical route facts:

- room keys exist in the declaration catalog;
- generated doors reference declared exits;
- generated door counts match declared exits;
- selected door target matches the next entered room;
- exit constraints match target room tags;
- terminal/preboss conditions are satisfied;
- room caps and creation limits are not violated.

### Timing And Eligibility Validation

Timing validation checks game-rule conditions at the correct lifecycle phase:

- room eligibility;
- force windows and force pressure;
- encounter-depth gates;
- biome-depth gates;
- room-history spacing;
- previous-room exit requirements;
- generated-door batch rules.

The validator should name the counter axis it uses. `depth` alone is not a
valid query.

### Reward Validation

Reward validation is split into:

- offer domain validation;
- bag-entry requirement validation;
- offer batch validation;
- reward bag simulation;
- loot acquisition history validation.

See `../model/REWARD_MODEL.md` for the reward-specific boundary.

## Lifecycle Phases

Validation should attach checks to the same lifecycle used by history:

```text
room.enter
room.encounters
room.offer_points
room.generate_next
room.commit
```

Examples:

- next-room target candidates are evaluated at `room.generate_next`;
- generated door rewards are evaluated at `room.generate_next`;
- O wheel rewards are evaluated inside `room.offer_points`;
- acquired selected door loot updates history when the selected room is
  entered/acquired;
- `BiomeDepthCache` changes at `room.commit`;
- `BiomeEncounterDepth` changes with encounter events.

This phase split prevents BDC/BED off-by-one bugs and keeps O multi-encounter
rooms honest.

## Candidate Providers

Candidate-producing form leaves expose a common allocation-stable provider
interface.

The provider owns the hot-path storage:

```lua
provider = {
    key = "nextDoorTarget",
    version = 12,

    values = stableValues,
    labels = stableLabels,

    hidden = mutableHidden,
    colors = mutableColors,
    messages = mutableMessages,

    exportCandidates = function(out, formAddress, context) end,
    applyCandidateFeedback = function(feedback) end,
    clearCandidateFeedback = function() end,
}
```

Examples of candidate providers:

- next-door target room picker;
- reward type picker;
- reward payload picker, such as boon source;
- Devotion/Trial source picker;
- shop option picker;
- H cage roll picker;
- O wheel count picker;
- N hub door picker.

The provider may rebuild stable arrays only on a dirty domain change. Route
context changes should mutate `hidden`, `colors`, and `messages`; they should
not reshape `values` or `labels` during draw.

## Candidate Export

The history builder asks providers to export semantic candidate records while
materializing complete snapshots.

The builder treats the provider as a black box:

```lua
provider.exportCandidates(out, formAddress, context)
```

Exported records contain:

- opaque form return address;
- provider key;
- provider version;
- stable candidate key;
- optional cached candidate index;
- semantic game payload.

Example:

```lua
{
    formAddress = { routeKey = "Underworld", biomeIndex = 1, roomIndex = 3, doorIndex = 1 },
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

The validator reads `semantic`. Feedback uses the address/provider metadata to
return results. Neither layer reaches into form internals.

## Candidate Evaluation

Candidate evaluation is part of validation's normal history walk. Feedback
must not ask the validator to rewalk the route for each control.

The validator evaluates all candidate records at their appropriate lifecycle
phase and emits candidate results.

Examples:

- `semantic.kind = "nextRoom"` uses room eligibility, exit constraints,
  force pressure, caps, and timing queries.
- `semantic.kind = "rewardType"` uses offer domain, entry requirements, and
  reward bag state.
- `semantic.kind = "devotionSource"` uses acquired god source history and
  payload duplicate rules.
- `semantic.kind = "shopOption"` uses shop domain and replacement
  requirements.

The same underlying rule functions should power selected-value findings and
candidate results. If a selected value is invalid, validation should emit both
the candidate result for that value and the blocking finding for route status.

## Presentation Policy

Candidate validity is not just true/false. Failed conditions choose a
presentation policy.

Example policies:

```lua
{
    code = "room_depth_unavailable",
    presentation = "hide",
}
```

```lua
{
    code = "force_pressure_conflict",
    presentation = "invalid",
}
```

```lua
{
    code = "profile_dependent_requirement",
    presentation = "warning",
}
```

Policy belongs to the failed condition. Do not use broad abstract buckets such
as "impossible" as the source of UI behavior.

Normal policy rules:

- depth windows and declaration-range failures can hide candidates;
- route-context conflicts usually remain visible and invalid;
- selected invalid candidates become blocking findings;
- unselected invalid candidates only color or hide options;
- unsupported/profile-dependent rules should be explicit warnings or blocking
  unsupported findings, not silently valid.

## Feedback Application

Feedback maps validator results back to provider interfaces.

Feedback applies results only if the provider version still matches:

```lua
if feedback.providerVersion == provider.version then
    provider.applyCandidateFeedback(feedback)
end
```

If versions do not match, the route context should rebuild instead of applying
stale candidate results.

Provider feedback mutates stable arrays:

```lua
hidden[index] = feedback.presentation == "hide"
colors[index] = feedback.color
messages[index] = feedback.message
```

Draw code reads these arrays directly. It should not allocate or recompute
candidate validity during render.

## Error Horizon

The first blocking finding defines the route error horizon.

Before the horizon:

- selected invalid facts are shown as blocking invalids;
- candidate colors remain useful;
- local form completion feedback remains local.

After the horizon:

- downstream route content can be greyed or inactive;
- enrichment colors should be suppressed;
- validators may still compute candidate policy if needed for stable UI, but
  route status should remain focused on the first blocking issue.

The horizon is a presentation rule over findings. It should not change the
canonical plan or history facts.

## Requirement Handling

`REQUIREMENTS_DSL.md` owns the normalized predicate language.

Validator predicates should use game-language names:

- `LootTypeHistory`;
- `UseRecord`;
- `BiomeUseRecord`;
- `LootBiomeRecord`;
- `ClearedBiomes`;
- `EncounterDepth`;
- `BiomeEncounterDepth`;
- `RequiredMinRoomsSinceEvent`;
- `RequiredMinExits`;
- `RequiredNotInStore`.

Unknown requirement kinds are contract failures. They are not soft user-facing
invalids and should not default to valid.

Unsupported requirements must be explicit. If a requirement depends on save
state or unmodeled systems, it should produce a known unsupported/profile
policy rather than disappearing into a fallback.

## Performance Rules

Validation and feedback must respect the planner UI hot path:

- no per-frame candidate allocation;
- candidate arrays are stable between dirty rebuilds;
- feedback mutates arrays in place;
- candidate lookup by key/index happens during feedback application, not draw;
- validation walks history once per route rebuild, not once per control;
- builders and validators do not repeatedly query leaf internals.

The design is intentionally not purely functional at the candidate-storage
boundary. Mutable arrays are part of the contract because dropdown rendering is
hot-path UI work.

## Non-Goals

Validation should not:

- validate incomplete form drafts;
- invent default room or reward choices;
- render UI controls;
- understand leaf-local widget aliases;
- re-solve runtime hook behavior;
- model probabilities;
- compensate for incomplete declarations with silent fallbacks.

If an internal fact is malformed after the form/build boundary, fail loudly at
the boundary or in a focused validator test.

## Supporting Docs

- `../ui/FORM_FEEDBACK_CONTRACT.md` owns form completion and participant
  feedback boundaries.
- `../pipeline/TIMELINE_EVENTS.md` owns lifecycle phase definitions.
- `../model/REWARD_MODEL.md` owns reward validation layers and bag simulation.
