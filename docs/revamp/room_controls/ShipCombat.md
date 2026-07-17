# `ShipCombat` Room Control

## Coverage

All 15 `Surface_O` rooms `O_Combat01..15` use:

- incoming reward producer `none`;
- encounter profile `ShipCombat`;
- phase-derived offer slots `wheel1` and `wheel2`;
- no explicit room-declared local children.

## Room Spine

The immutable baseline phases are:

1. non-counting `Intro` with `GeneratedO_Intro01`;
2. counting `Combat1` with `GeneratedO` and active `wheel1`;
3. optional counting `Combat2` with `GeneratedO` and conditional `wheel2`.

The control authors only optional presence and wheel state. It does not persist
the baseline encounter names or counter effects.

## Owned State

```lua
{
    kind = "ShipCombat",
    generatedReward = nil,
    encounterCount = 3, -- 2 | 3
    phases = {
        Combat1 = {
            wheel = {
                offerCount = 2,
                pickedIndex = 1,
                storeKey = "RunProgress",
                offers = {
                    {
                        storeKey = "RunProgress",
                        rewardType = "Boon",
                        payload = { source = "ApolloUpgrade" },
                    },
                    {
                        storeKey = "RunProgress",
                        rewardType = "MaxHealthDrop",
                    },
                },
            },
        },
        Combat2 = {
            wheel = { ... },
        },
    },
}
```

Logical persistence is bounded:

```lua
{
    encounterCount = 2,
    wheel1 = {
        storeKey = "RunProgress",
        offerCount = 1,
        pickedIndex = 1,
        offer1 = { rewardType = "Boon", source1 = "ApolloUpgrade" },
        offer2 = { rewardType = "MaxHealthDrop", source1 = "" }, -- dormant
    },
    wheel2 = { -- same bounded fields as wheel1
    },
}
```

`ShipWheel` selects `RunProgress` or `MetaProgress` once per wheel, and all
active offers use that same bag. The typed offers still include the resolved
`storeKey`, but it is persisted only once at wheel level. Every O combat room
has one physical exit and the RunProgress Devotion entry requires two.
Consequently assembly compiles Devotion out of this structurally fixed wheel
context without adding a room negative filter. Each offer needs at most one
Boon source field.

## Completeness and Legality

`wheel1` is always active. It requires one or two complete offers and exactly
one picked active index.

The UI exposes one game-language dropdown: two encounters means Intro plus
Combat1; three encounters means Intro plus Combat1 plus Combat2. Zero is the
transitional manifest sentinel only; the active O template defaults to two and
never exposes zero. Selecting two makes all `wheel2` state dormant;
selecting three activates it with the same completeness rules as `wheel1`.
Stored wheel2 values survive a switch back to two.

The final active wheel's `storeKey` is also the initial base store for the
room's outgoing generated-door batch. The control owns and exports that
room-local fact. The Biome Plan owns the outgoing targets and validates their
concrete stores after applying the common forced-store prepass and
target-specific individual or forced overrides.

The pre-room `biomeEncounterDepth` window `[2, 5]` determines whether three is
legal at `room.prepare_encounters`. Encounter count remains an authored choice
so a complete but context-invalid value can receive validator feedback; the
control does not silently coerce it to two.

## Candidates and Feedback

Each wheel is addressed by the parent control and `localSlotKey = "wheel1"`
or `"wheel2"`. Offer reward and picked-index candidates are semantic wheel
operations. The wheel implementation must not expose storage indexes as
candidate identity.
