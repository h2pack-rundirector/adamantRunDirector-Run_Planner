# Reward Model

## Purpose

The fresh planner treats rewards as first-class generated game facts, not as
optional UI annotations on rooms.

A configured biome is only complete when its room structure and reward offers
are both complete. This is required because rewards can affect:

- reward bag depletion and refill;
- later reward legality;
- biome-specific structure such as I Clockwork goals;
- shop pending-offer restrictions;
- route history such as `LootTypeHistory`, `UseRecord`, and
  `BiomeUseRecord`.

The guiding rule is:

```text
Declarations define possible reward generation.
The plan stores concrete reward offers.
History separates reward offers from acquired loot.
Validation checks domain, entry requirements, bags, and acquisition history.
```

## Design Boundaries

Rewards use these separate concepts:

`Reward Primitive`
: A named reward type such as `Boon`, `WeaponUpgrade`, `Devotion`, or
`TalentDrop`.

`Reward Store`
: A unique option domain used by forms and offer-domain validation. Stores
answer "can this surface ever offer this reward type?"

`Reward Bag`
: A counted multiset copied from game `RewardStoreData`. Bags answer "is this
specific entry still available at this offer point?"

`Bag Entry Requirement`
: A predicate attached to one counted bag entry. Duplicate reward names can
have different entry requirements.

`Offer Point`
: A game moment that generates one or more reward offers.

`Reward Offer`
: A concrete generated offer with store, reward type, acquisition state, and
payload.

`Loot Acquisition`
: A reward the player actually receives. This updates loot/use history.

`Shop Profile`
: A shop offer domain. Shops are not reward bags.

These concepts should not be collapsed. In particular, a unique reward store
is not a reward bag, and a generated offer is not the same thing as acquired
loot.

## Declaration Ownership

Reward declarations should mimic the game model.

### Primitives

Reward primitives own stable display and metadata:

```lua
WeaponUpgrade = {
    label = "Hammer",
    acquiredLootType = "WeaponUpgrade",
}
```

Primitive metadata should not own source-specific legality. For example,
Hammer timing differs between early and late counted bag entries, so that rule
belongs on those entries, not on the primitive.

### Stores

Stores are unique domains derived from bags where possible:

```lua
RunProgressStore = {
    "Boon",
    "WeaponUpgrade",
    "HermesUpgrade",
    "Devotion",
    ...
}
```

Forms use stores to render available reward-type options. Store membership is
only the first layer of validity.

### Bags

Bags are counted arrays of entries:

```lua
RunProgress = {
    { rewardType = "Boon", allowDuplicates = true },
    { rewardType = "Boon", allowDuplicates = true },
    {
        rewardType = "WeaponUpgrade",
        requirements = { named = "HammerLootRequirements" },
        acquiredLootType = "WeaponUpgrade",
    },
    {
        rewardType = "WeaponUpgrade",
        requirements = { named = "LateHammerLootRequirements" },
        acquiredLootType = "WeaponUpgrade",
    },
}
```

String shorthand is acceptable only for entries with no requirements, no
payload, no duplicate policy, and no offer/acquire name split.

### Room Reward Surfaces

Room declarations own the reward surface used when that room is generated or
entered:

```lua
F_MiniBoss01 = {
    offerProfile = "RunProgressBoonOnly",
}

RunProgressBoonOnly = {
    kind = "storeChoice",
    stores = { "RunProgress" },
    eligibleRewards = { "Boon" },
}
```

Room reward filters should match game `EligibleRewards` and
`IneligibleRewards`. The planner models these as `eligibleRewards` or
`ineligibleRewards` on the offer profile. Profiles must not define both filters
because the game data does not use both at the same time.

### Shop Profiles

Shop declarations own shop slots and replacement requirements:

```lua
WorldShop = {
    slots = {
        {
            key = "Major",
            options = {
                {
                    rewardType = "WeaponUpgradeDrop",
                    requirements = { named = "HammerLootRequirements" },
                    acquiredLootType = "WeaponUpgrade",
                },
            },
        },
    },
}
```

Shop options can block later reward generation through `RequiredNotInStore`,
but they do not remove entries from reward bags.

## Canonical Plan Shape

The plan stores concrete offers, not unresolved reward classes:

```lua
offerPoint = {
    kind = "generatedDoorRewards",
    offers = {
        {
            store = "RunProgress",
            rewardType = "WeaponUpgrade",
            acquired = true,
            payload = {},
        },
    },
}
```

A configured offer must resolve to:

- offer point kind;
- store or shop profile;
- reward type;
- acquisition flag;
- payload when needed;
- selected shop branch when a surface has mutually exclusive branches.

Completed canonical plans do not allow `Auto`, `Vanilla`, `Major`, `Minor`,
blank reward types, partial Devotion pairs, or implicit shop purchases.

## Offer Points

Offer points own timing and batch semantics.

Common offer points:

- generated next-door rewards;
- H cage rewards;
- O ship wheel rewards;
- N hub pylon rewards;
- shop offers;
- preboss shop/free-reward branches;
- structural reward offers such as I `ClockworkGoal`.

Generated next-door rewards are emitted by the current room when it generates
its next doors. The selected next room later acquires the selected offer.

O ship wheels are encounter-local offer points inside one physical room. They
are sequential; wheel 1 can affect bag state before wheel 2 is generated.

H cage rewards are batch offers. The batch owns peer-level cage generation
state, while target combat rooms own their physical capacity.

N hub pylon rewards are generated together when the hub creates its pylon
doors, even though the selected pylon rooms are visited later.

## Offer Versus Acquisition

History must emit both concepts:

```text
reward.offer
reward.acquire
```

`reward.offer` means the game generated or displayed the reward. Offers affect
reward bags.

`reward.acquire` means the player received the reward. Acquisitions affect
loot/use history.

Unselected generated doors still emit `reward.offer`. They usually do not emit
`reward.acquire`.

Unbought shop items emit shop offers. They do not emit acquisition.

Bought shop items emit acquisition at the game-correct phase. For normal shop
timing, next-room rewards are generated before bought shop loot can satisfy
later loot-history requirements.

## Reward Payloads

Some reward types need payload:

`Boon`
: selected boon source, such as `AphroditeUpgrade`.

`Devotion`
: two selected boon sources.

`RandomLoot` / shop randoms
: must eventually resolve to the acquired loot type if the planner wants to
validate downstream loot history precisely.

Payload completeness belongs to the reward form leaf. Payload legality belongs
to validation.

Example Devotion offer:

```lua
{
    store = "RunProgress",
    rewardType = "Devotion",
    acquired = true,
    payload = {
        sources = { "ApolloUpgrade", "PoseidonUpgrade" },
    },
}
```

## Validation Pipeline

Reward validation has four layers.

### 1. Offer Domain Validation

The configured offer must be part of the declared domain for that offer point.

This checks:

- store membership;
- room `EligibleRewards`;
- room `IneligibleRewards`;
- shop option set membership;
- required branch selection for mutually exclusive surfaces.

Failure means the plan describes a reward this source cannot generate.

### 2. Entry Requirement Validation

The configured reward must have a matching counted bag entry or shop option
whose requirements are satisfied at that offer point.

This checks game-language requirements such as:

- `LootTypeHistory`;
- `UseRecord`;
- `BiomeUseRecord`;
- `ClearedBiomes`;
- `EncounterDepth`;
- `BiomeEncounterDepth`;
- `RequiredMinRoomsSinceEvent`;
- `RequiredMinExits`;
- `RequiredNotInStore`.

Entry requirements are source-specific. A requirement on the `RunProgress`
Devotion entry does not automatically apply to O's forced Devotion room or to
every other Devotion source.

### 3. Offer Batch Validation

Offers generated together must satisfy same-batch rules.

Examples:

- H cage rewards should obey duplicate blocking through the same equivalent
  of game `previouslyChosenRewards`;
- Devotion must have two distinct source gods;
- shop groups can require distinct option types.

Batch validation is not bag simulation. It is about one offer group being
internally coherent.

### 4. Reward Bag Simulation

The bag simulator walks offer points in game timing order:

1. Build the current eligible set for the source store.
2. If no entry is eligible, append a full copy of that store and retry.
3. Match the configured offer to one eligible counted entry.
4. Remove the matched entry from the bag.
5. Preserve ineligible entries already in the bag.

The simulator answers:

```text
Given every offer generated so far, can this configured offer be generated now?
```

This is stricter than checking that a reward type is generally legal.

## Query Layer

`../validation/REQUIREMENTS_DSL.md` owns the normalized predicate language.

Reward validation should ask game-language questions:

```text
CurrentRun.LootTypeHistory[lootType]
CurrentRun.UseRecord[name]
CurrentRun.BiomeUseRecord[name]
CurrentRun.LootBiomeRecord[lootType]
CurrentRun.ClearedBiomes
CurrentRun.EncounterDepth
CurrentRun.BiomeEncounterDepth
RequiredMinRoomsSinceEvent(event, count, axis)
RequiredMinExits(count)
RequiredNotInStore(name)
```

The query layer should avoid planner-only names when the game has a clear
counter or ledger name.

## Form Contract

Reward forms are leaf participants.

Each reward form should provide:

- `isComplete`;
- `render`;
- `reset`;
- `snapshot`;
- `applyFeedback`.

The snapshot emits canonical offer data only when complete. UI conveniences
such as `MajorMinor` are local authoring helpers. They must resolve to concrete
store and reward facts before entering history.

Form incompleteness is local form feedback. A complete-but-invalid reward is
history/validator feedback.

## Feedback Contract

History entries should carry stable form addresses for generated offers.

The validator emits game-domain findings, such as:

```text
offer at this history point cannot satisfy LateHammerLootRequirements
```

Feedback maps that finding back to the owning reward form leaf. The feedback
layer should not need to infer UI structure from reward type strings.

## Deferred / Unsupported Inputs

Some game requirements depend on save state or systems not planned yet:

- `AllSpellInvestedCache`;
- `CurrentRun.PendingSpellDrop` from surface shop purchases;
- meta unlock requirements;
- exact `Hero.UpgradableTraitCount` for `StackUpgradeLegal`;
- random shop replacement logic that has not been materialized into concrete
  options.

These should be explicit unsupported/profile inputs, not silently assumed true
inside reward legality.

## Supporting Docs

- `REWARD_OFFERS.md` describes offer/acquire shape and offer point examples.
- `REWARD_LEGALITY_AND_BAGS.md` audits the current planner and game sources
  that informed these boundaries.
