# Reward Components

## Purpose

[`REWARD_HIERARCHY.md`](REWARD_HIERARCHY.md) defines the bottom-up implementation
from payload domains and primitives through counted bindings, compiled choice
views, and shop profiles. This document defines the concrete authored and
structural shapes composed inside Room Controls.

[`REWARD_CONSUMER_AUDIT.md`](REWARD_CONSUMER_AUDIT.md) is the binding authority
for each supported producer's behavior, stores, and filters.

Reward surfaces identify behavior, not filtered option sets. Control assembly
compiles each concrete counted binding and injects the resulting immutable
choice view. Shops remain a separate branch.

A component is not a Lib control and owns no independent profile identity. Its
fields are flattened into the parent Room Control's private storage.

## Concrete Reward Value

All components produce concrete game-domain values:

```lua
{
    storeKey = "RunProgress", -- present only for counted-bag offers
    rewardType = "Boon",
    payload = {
        source = "ApolloUpgrade",
    },
}
```

The payload shape follows the primitive's declared domain:

```lua
-- no payload domain
{ rewardType = "MaxHealthDrop" }

-- BoonSource / oneOf
{ rewardType = "Boon", payload = { source = "ApolloUpgrade" } }

-- DevotionPair / distinctPair
{
    rewardType = "Devotion",
    payload = { sources = { "ApolloUpgrade", "ZeusUpgrade" } },
}
```

Private storage may flatten payload members, but `payloadValues`, positional
storage names, and generated aliases do not escape the component.

Semantic reads normalize private empty-string sentinels to `nil`. An
incomplete selection returns the same typed shape with unresolved members
absent; it does not return storage sentinels or discard already authored
members. For example, a selected Boon without a source reads as
`{ rewardType = "Boon" }`. Canonical materialization never emits an incomplete
value.

## `none`

`none` means the room has no incoming reward producer.

- persistence: none;
- authored value: `nil`;
- completeness: always complete for this aspect;
- candidates: none.

It does not mean an optional reward and must never accept a reward candidate.

## `fixed`

The declaration fixes `rewardType`. Only payload-domain values, if any, are
authored.

Logical persistence:

```lua
-- Story or ClockworkGoal
{}

-- Devotion
{
    source1 = "",
    source2 = "",
}
```

The component rejects replacement of the fixed reward type. A fixed reward
without a payload consumes no storage.

Completeness requires every payload member and all domain constraints. A
Devotion pair must contain two distinct concrete Boon sources.

## Counted reward choice

A counted binding supplies one concrete reward from its declared stores.
Positive and negative room filters are resolved into one anonymous immutable
view during assembly.

Logical persistence:

```lua
{
    storeKey = "",   -- omitted from storage when exactly one store is allowed
    rewardType = "", -- omitted when exactly one reward type is allowed
    source1 = "",    -- allocated only when an allowed primitive can need it
    source2 = "",    -- allocated only when an allowed primitive can need it
}
```

The typed read always includes the resolved concrete `storeKey`, including
when one bag is declaration-fixed and therefore not persisted.

Completeness requires a permitted bag, a concrete reward type available
from the compiled binding, and the selected primitive's complete payload. Payload
fields allocated for another reward type are dormant and ignored.

The choice does not validate counted-bag history during read or write.
Checkpoint 4A exposes its stable authored domain, Checkpoint 4B exports the
semantic candidates consumed by the pipeline, and the route validator
evaluates the concrete selection against history. Bounded wrappers such as
Fields cages and Ship wheels delegate each concrete reward to their injected
compiled counted binding.

## `shop`

A shop surface has a declaration-fixed profile and bounded slots. Each slot
authors a concrete option and whether it was purchased:

```lua
{
    profileKey = "WorldShop",
    slots = {
        Boon = {
            reward = {
                rewardType = "RandomLoot",
                payload = { source = "ApolloUpgrade" },
            },
            purchased = true,
        },
    },
}
```

Logical persistence for every slot:

```lua
{
    rewardType = "",
    source1 = "",
    source2 = "",
    purchased = false,
}
```

`purchased = false` means the offer was not acquired. Reward selection, rather
than the boolean, determines whether the slot is complete. Inactive shop
branches retain their fields but are dormant.

The component rejects reward types outside the slot's option set. Cross-slot
constraints such as Summit primary uniqueness remain validator rules over the
complete shop fragment.

## `branch`

A branch surface persists an explicit branch key and the storage for every
bounded branch:

```lua
{
    branch = "", -- for example Goal | NonGoal
    Goal = { ... },
    NonGoal = { ... },
}
```

Only the selected branch participates in completeness, materialization,
candidates, and feedback. Other branch state remains persisted but dormant.
Changing the selected branch does not reset it.

## `localSlots`

A local-slot surface applies one reward component to the parent Room
Control's declaration-derived bounded slots:

```lua
{
    slots = {
        cage1 = { reward = { ... } },
        cage2 = { reward = { ... } },
        cage3 = { reward = { ... } },
    },
}
```

The owning biome/batch rule supplies the active slot set. Only active slots
are complete or materialized. The component neither calculates active count
nor owns batch state.

## `incomingKind`

An incoming-kind surface persists a concrete semantic kind and bounded state
for every kind:

```lua
{
    kind = "", -- Goal | NonGoal
    Goal = { rewardType = "ClockworkGoal" },
    NonGoal = {
        reward = { storeKey = "TartarusRewards", rewardType = "", ... },
    },
}
```

Only the selected kind is active. The inactive kind remains dormant. The kind
is room-local incoming reward state; batch rules constrain peer combinations
without owning the target's reward value.

## Encounter Offer Point

An encounter offer point is derived from an encounter-profile phase and
flattened into the owning Room Control:

```lua
{
    offerCount = 0, -- incomplete; allowed completed values are 1 or 2
    pickedIndex = 0,
    offers = {
        [1] = { ... },
        [2] = { ... },
    },
}
```

Only offers `1..offerCount` are active. `pickedIndex` must select exactly one
active offer. Unused bounded offer storage is dormant. Offer points never
become nested controls.

## Explicit Decisions Versus Boolean Defaults

When both `true` and `false` are meaningful authored outcomes, a fresh default
must not silently choose one. Such decisions use an explicit enum with an
empty incomplete value:

```text
optional phase:  "" | Present | Absent
side generation: "" | Generated | NotGenerated
```

Shop purchase is intentionally different: `false` is the complete semantic
answer "not purchased," while the authored reward value independently carries
slot completeness.

## Feedback Addresses

The parent template supplies owner identity. Components append only the
smallest semantic local address:

```lua
-- incoming reward
{ roomControlKey = "Underworld_F_Combat04", aspect = "generatedReward" }

-- local slot reward
{
    roomControlKey = "Surface_N_Combat02",
    localSlotKey = "sideDoor1",
    aspect = "generatedReward",
}

-- encounter offer
{
    roomControlKey = "Surface_O_Combat04",
    localSlotKey = "wheel2",
    aspect = "pickedReward",
}
```
