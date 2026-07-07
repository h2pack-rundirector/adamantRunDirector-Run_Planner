# Requirements DSL

## Purpose

The requirements DSL is the planner's normalized game-language predicate
format. It is used by validators for room eligibility, force metadata, reward
entry requirements, shop replacement requirements, candidate policies, and
route-level rules.

The guiding rule is:

```text
Game paths may be imported.
Validator requirements should be explicit predicates.
Unknown predicates fail loudly.
```

The DSL is not UI logic and not runtime hook logic.

## Boundary

Game data often expresses conditions as generic path checks:

```lua
{
    Path = { "CurrentRun", "LootTypeHistory", "WeaponUpgrade" },
    Comparison = "==",
    Value = 1,
}
```

The fresh planner should translate that into an explicit predicate before
validation:

```lua
{
    kind = "LootTypeHistory",
    countOf = { "WeaponUpgrade" },
    comparison = "==",
    value = 1,
}
```

Generic `Path` requirements can exist in import/audit code, but they should
not be the normal internal validator language. If a game path is not mapped to
a known explicit predicate, it is unsupported or a contract failure.

## Requirement Shape

A normalized requirement has:

```lua
{
    kind = "LootTypeHistory",
    countOf = { "WeaponUpgrade" },
    comparison = "==",
    value = 1,
    code = "late_hammer_requires_first_hammer",
    presentation = "invalid",
}
```

Common fields:

- `kind`: explicit predicate kind;
- predicate payload fields, such as `countOf`, `event`, or `value`;
- `comparison`: numeric comparison when needed;
- `code`: stable failure code;
- `presentation`: candidate/feedback policy;
- `message`: optional author-owned message;
- `related`: optional related event selectors.

`code` and `presentation` belong to the failed condition. UI behavior should
not be inferred from vague buckets such as "impossible."

## Boolean Composition

The DSL supports composition:

```lua
{
    kind = "All",
    requirements = {
        { kind = "LootTypeHistory", countOf = { "WeaponUpgrade" }, comparison = "==", value = 1 },
        { kind = "ClearedBiomes", comparison = ">", value = 2 },
    },
}
```

```lua
{
    kind = "Any",
    requirements = {
        { kind = "LootTypeHistory", countOf = { "WeaponUpgrade" }, comparison = "==", value = 0 },
        { kind = "ClearedBiomes", comparison = ">", value = 2 },
    },
}
```

`Not` is allowed when it makes the declaration clearer:

```lua
{
    kind = "Not",
    requirement = { kind = "BiomeUseRecord", countOf = { "HermesUpgrade" }, comparison = ">", value = 0 },
}
```

Named requirements can be declarations:

```lua
{
    named = "HammerLootRequirements",
}
```

Named requirements are expanded before validation or resolved through a
declaration registry. Unknown names are contract failures.

## Operators

Numeric comparisons:

- `==`
- `~=`
- `<`
- `<=`
- `>`
- `>=`

Set/count operators:

- `countOf`
- `hasAll`
- `hasAny`
- `hasNone`

Truth operators should be explicit predicate variants when possible. Avoid
generic `pathTrue` / `pathFalse` in internal validator code unless the path has
been deliberately classified as unsupported/profile-driven.

## Lifecycle Context

Every requirement is evaluated at a lifecycle phase:

```text
room.enter
room.encounters
room.offer_points
room.generate_next
room.commit
```

The requirement itself may not need to name the phase if the caller owns it,
but tests and validators should be clear about the phase. For example:

- generated door room eligibility is checked at `room.generate_next`;
- generated door reward entry requirements are checked at
  `room.generate_next`;
- O wheel reward requirements are checked at `room.offer_points`;
- `BiomeDepthCache` changes at `room.commit`;
- `BiomeEncounterDepth` changes with encounter events.

Using the wrong phase is a validator bug, not a declaration quirk.

## History Ledgers

The DSL should query typed history ledgers.

### `LootTypeHistory`

Acquired loot counts:

```lua
{
    kind = "LootTypeHistory",
    countOf = { "WeaponUpgrade" },
    comparison = "==",
    value = 1,
}
```

Use for requirements such as early/late Hammer, prior gods for Devotion, and
Hermes route limits.

### `UseRecord`

Use/interact record counts:

```lua
{
    kind = "UseRecord",
    countOf = { "SpellDrop" },
    comparison = ">=",
    value = 1,
}
```

Use when the game requirement depends on using/acquiring a consumable rather
than only the loot type being offered.

### `BiomeUseRecord`

Biome-scoped use/interact record:

```lua
{
    kind = "BiomeUseRecord",
    hasNone = { "HermesUpgrade", "ShopHermesUpgrade" },
}
```

Use for once-per-biome restrictions such as Hermes.

### `LootBiomeRecord`

Biome-scoped loot type history:

```lua
{
    kind = "LootBiomeRecord",
    countOf = { "TalentDrop" },
    comparison = "==",
    value = 0,
}
```

Use when the game condition is explicitly about loot acquired in the current
biome.

### `ClearedBiomes`

Completed biome count:

```lua
{
    kind = "ClearedBiomes",
    comparison = ">",
    value = 2,
}
```

Use this for game requirements that read `CurrentRun.ClearedBiomes`. Do not
substitute `EnteredBiomes` or route biome index.

### `EncounterDepth`

Route-wide encounter depth:

```lua
{
    kind = "EncounterDepth",
    comparison = ">=",
    value = 7,
}
```

### `BiomeEncounterDepth`

Biome-local encounter depth:

```lua
{
    kind = "BiomeEncounterDepth",
    comparison = ">=",
    value = 2,
}
```

### `BiomeDepthCache`

Biome-local room-depth cache:

```lua
{
    kind = "BiomeDepthCache",
    comparison = ">=",
    value = 4,
}
```

### Route-Wide Room Spacing

The current planner does not use a standalone `RunDepthCache` predicate for
route-wide room spacing. Use event-distance requirements with the
`RoomHistoryOrdinal` axis when the game checks rooms since a prior event.

## Event Distance Predicates

### `RequiredMinRoomsSinceEvent`

Spacing from a prior event:

```lua
{
    kind = "RequiredMinRoomsSinceEvent",
    event = {
        kind = "reward.acquire",
        rewardType = "Devotion",
    },
    axis = "RoomHistoryOrdinal",
    count = 15,
}
```

The `axis` must be explicit. Valid axes should be named game counters or
history views, such as `RoomHistoryOrdinal` or `BiomeDepthCache`.

### Related Event Selectors

Requirements can include related selectors for feedback:

```lua
{
    kind = "RequiredMinRoomsSinceEvent",
    event = { kind = "reward.acquire", rewardType = "Devotion" },
    axis = "RoomHistoryOrdinal",
    count = 15,
    related = {
        { kind = "lastMatchingEvent" },
    },
}
```

Related selectors are feedback hints. They do not change validity.

## Generated Door Predicates

### `RequiredMinExits`

Minimum currently offered/generated exits:

```lua
{
    kind = "RequiredMinExits",
    count = 2,
}
```

This should query generated doors at the current offer phase, not the number
of UI rows or a previous cached row count.

### `ExitTags`

Exit-to-target compatibility:

```lua
{
    kind = "ExitTags",
    exitIndex = 1,
    targetRoomKey = "P_Combat03",
}
```

The validator resolves declared exit constraints and target room tags.

### `GeneratedDoorTarget`

Selected generated door must match the next entered room:

```lua
{
    kind = "GeneratedDoorTarget",
    selectedDoorIndex = 2,
    expectedNextRoomKey = "F_MiniBoss02",
}
```

This is usually produced by structural validation, not authored by hand.

## Store And Offer Predicates

### `RequiredNotInStore`

Current shop/store pending-offer block:

```lua
{
    kind = "RequiredNotInStore",
    name = "WeaponUpgradeDrop",
}
```

This checks active pending shop offers. It does not query reward bags.

### `RewardStoreEntryRequirements`

Configured reward must match at least one counted bag entry whose static and
history requirements are satisfied:

```lua
{
    kind = "RewardStoreEntryRequirements",
    store = "RunProgress",
    rewardType = "WeaponUpgrade",
}
```

This predicate belongs to entry requirement validation. It does not mean the
entry is still present after earlier offers depleted the bag. Bag
depletion/refill is a separate simulation layer.

### `OfferDomain`

Configured reward must belong to the offer point's declared domain:

```lua
{
    kind = "OfferDomain",
    offerPointKind = "generatedDoorRewards",
    store = "RunProgress",
    rewardType = "Boon",
}
```

This checks store membership and source filters such as `EligibleRewards` and
`IneligibleRewards`.

## Reward Payload Predicates

### `PriorDistinctLootSources`

Count distinct acquired source gods:

```lua
{
    kind = "PriorDistinctLootSources",
    sourceValues = {
        "AphroditeUpgrade",
        "ApolloUpgrade",
        "DemeterUpgrade",
        "HephaestusUpgrade",
        "HestiaUpgrade",
        "HeraUpgrade",
        "PoseidonUpgrade",
        "ZeusUpgrade",
        "AresUpgrade",
    },
    comparison = ">=",
    value = 2,
}
```

Use for Devotion prerequisites.

### `CurrentLootSourcesSeen`

Selected payload sources must exist in prior acquired loot:

```lua
{
    kind = "CurrentLootSourcesSeen",
    sourceValues = { "ApolloUpgrade", "PoseidonUpgrade" },
}
```

Use for Devotion payload validation.

### `UniquePayloadValues`

Payload values must be distinct:

```lua
{
    kind = "UniquePayloadValues",
    values = { "ApolloUpgrade", "PoseidonUpgrade" },
}
```

Use for Devotion pair uniqueness and similar composite rewards.

## Batch Predicates

### `UniqueRewardTypes`

No duplicate reward types in one offer batch, with optional allowed
duplicates:

```lua
{
    kind = "UniqueRewardTypes",
    allow = { Boon = true },
}
```

Use for H cage reward batches and shop groups that require distinct option
types.

### `UniqueBoonSource`

No duplicate boon source in a batch:

```lua
{
    kind = "UniqueBoonSource",
}
```

Use for H cage rewards and Devotion-like payloads.

## Room And Force Predicates

### `RoomExists`

Room key must exist in declarations:

```lua
{ kind = "RoomExists", roomKey = "F_Combat03" }
```

### `RoomEligibility`

Evaluate a room's declared requirements at the generated-door phase:

```lua
{
    kind = "RoomEligibility",
    roomKey = "F_Story01",
}
```

This is generally emitted by validators from room declarations rather than
authored as a declaration requirement.

### `ForceWindow`

Force metadata is active within a declared window:

```lua
{
    kind = "ForceWindow",
    roomKey = "F_MiniBoss01",
    biomeDepthMin = 4,
    biomeDepthMax = 6,
}
```

Force pressure should walk history and generated doors. It should not be
implemented as row-local guessing.

### `MaxCreationsThisRun`

Creation cap:

```lua
{
    kind = "MaxCreationsThisRun",
    roomKey = "F_Shop01",
    value = 1,
}
```

### `RoomEnteredHistory`

Prior entered-room checks:

```lua
{
    kind = "RoomEnteredHistory",
    roomKeys = { "F_MiniBoss01", "F_MiniBoss02" },
    comparison = "==",
    value = 0,
}
```

The count uses `room.enter` events before the evaluated event. For room target
eligibility at `room.generate_next`, this means the current room has already
entered and is visible to the requirement.

Use this instead of invented miniboss groups when the game condition is
expressed through room history.

## Presentation Policy

Every requirement can define a presentation policy:

```lua
{
    kind = "BiomeDepthCache",
    comparison = ">=",
    value = 4,
    code = "biome_depth_too_low",
    presentation = "hide",
}
```

Supported policies:

- `hide`
- `invalid`
- `warning`
- `unsupported`
- `block`

Policy meanings:

`hide`
: Candidate is not shown while the condition fails.

`invalid`
: Candidate stays visible and is colored invalid.

`warning`
: Candidate stays visible with warning decoration.

`unsupported`
: The planner cannot currently prove the condition; this should be explicit.

`block`
: Selected fact is a blocking route error.

Candidate policy and selected-route severity are related but not identical.
An unselected candidate can be hidden or invalid without blocking the route.
A selected candidate with the same failed condition emits a selected finding.

## Unsupported And Profile Inputs

Unsupported requirements should be explicit records:

```lua
{
    kind = "Unsupported",
    source = "GameState.WorldUpgrades",
    code = "profile_world_upgrade_required",
    presentation = "unsupported",
}
```

Known unsupported/profile inputs:

- `GameState.*` unlock/story progression;
- `WorldUpgrades`;
- active bounty overrides;
- `Hero.UpgradableTraitCount`;
- `AllSpellInvestedCache`;
- `CurrentRun.PendingSpellDrop` from unmodeled surface-shop purchases;
- current trait/aspect checks.

These requirements should not silently pass. They should be ignored only when
a declaration explicitly marks them as out-of-scope for the planner profile.

## Translation Examples

### Early Hammer

Game shape:

```lua
NamedRequirements = { "HammerLootRequirements" }
```

Normalized:

```lua
{
    kind = "All",
    requirements = {
        { kind = "RequiredNotInStore", name = "WeaponUpgradeDrop" },
        {
            kind = "LootTypeHistory",
            countOf = { "WeaponUpgrade" },
            comparison = "==",
            value = 0,
        },
    },
}
```

### Late Hammer

Normalized:

```lua
{
    kind = "All",
    requirements = {
        { kind = "RequiredNotInStore", name = "WeaponUpgradeDrop" },
        { kind = "ClearedBiomes", comparison = ">", value = 2 },
        {
            kind = "LootTypeHistory",
            countOf = { "WeaponUpgrade" },
            comparison = "==",
            value = 1,
        },
    },
}
```

### RunProgress Devotion

Normalized:

```lua
{
    kind = "All",
    requirements = {
        { kind = "EncounterDepth", comparison = ">=", value = 7 },
        { kind = "BiomeEncounterDepth", comparison = ">=", value = 2 },
        {
            kind = "PriorDistinctLootSources",
            sourceValues = { "AphroditeUpgrade", "ApolloUpgrade", "DemeterUpgrade" },
            comparison = ">=",
            value = 2,
        },
        {
            kind = "RequiredMinRoomsSinceEvent",
            event = { kind = "reward.acquire", rewardType = "Devotion" },
            axis = "RoomHistoryOrdinal",
            count = 15,
        },
        { kind = "RequiredMinExits", count = 2 },
    },
}
```

### Hermes

Normalized:

```lua
{
    kind = "All",
    requirements = {
        { kind = "RequiredNotInStore", name = "ShopHermesUpgrade" },
        { kind = "BiomeUseRecord", hasNone = { "HermesUpgrade", "ShopHermesUpgrade" } },
        {
            kind = "LootTypeHistory",
            countOf = { "HermesUpgrade" },
            comparison = "<=",
            value = 1,
        },
    },
}
```

## Contract Rules

- Unknown requirement kind is a contract failure.
- Unknown named requirement is a contract failure.
- Unknown comparison operator is a contract failure.
- Missing required payload for a known predicate is a contract failure.
- Unsupported game requirements must be explicit.
- Validators must not default unknown or malformed requirements to valid.
- Requirement evaluation must not allocate in draw paths.
- Requirement results should include the failed `code` and `presentation`
  policy needed by feedback.

## Supporting Docs

- `VALIDATION_MODEL.md` owns validator and candidate-provider boundaries.
- `../pipeline/TIMELINE_EVENTS.md` owns lifecycle phases.
- `../model/REWARD_MODEL.md` owns reward entry and bag simulation boundaries.
- `../model/REWARD_LEGALITY_AND_BAGS.md` audits current reward legality
  sources.
