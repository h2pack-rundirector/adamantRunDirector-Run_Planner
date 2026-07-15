# `ShipCombat` Room Control

## Coverage

All 15 `Surface_O` rooms `O_Combat01..15` use:

- incoming reward surface `None`;
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
                offers = {
                    {
                        storeKey = "RunProgress",
                        rewardType = "Boon",
                        payload = { source = "ApolloUpgrade" },
                    },
                    {
                        storeKey = "MetaProgress",
                        rewardType = "GiftDrop",
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
    encounterCount = 0, -- 0 | 2 | 3; zero is incomplete
    wheel1 = {
        offerCount = 0,
        pickedIndex = 0,
        offer1 = { storeKey = "", rewardType = "", source1 = "", source2 = "" },
        offer2 = { storeKey = "", rewardType = "", source1 = "", source2 = "" },
    },
    wheel2 = { -- same bounded fields as wheel1
    },
}
```

`ShipWheel` allows `RunProgress` and `MetaProgress`; two source fields are
needed because RunProgress can produce Devotion.

## Completeness and Legality

`wheel1` is always active. It requires one or two complete offers and exactly
one picked active index.

The UI exposes one game-language dropdown: two encounters means Intro plus
Combat1; three encounters means Intro plus Combat1 plus Combat2. Zero is the
incomplete persisted value. Selecting two makes all `wheel2` state dormant;
selecting three activates it with the same completeness rules as `wheel1`.
Stored wheel2 values survive a switch back to two.

The pre-room `biomeEncounterDepth` window `[2, 5]` determines whether three is
legal at `room.prepare_encounters`. Encounter count remains an authored choice
so a complete but context-invalid value can receive validator feedback; the
control does not silently coerce it to two.

## Candidates and Feedback

Each wheel is addressed by the parent control and `localSlotKey = "wheel1"`
or `"wheel2"`. Offer reward and picked-index candidates are semantic wheel
operations. The wheel implementation must not expose storage indexes as
candidate identity.
