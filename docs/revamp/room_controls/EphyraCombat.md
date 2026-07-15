# `EphyraCombat` Room Control

## Coverage

All 23 `Surface_N` controls `N_Combat01..23` use encounter profile
`EphyraCombat`. Their incoming surfaces and child slots are declaration-fixed.

| Room | Incoming surface | Side slots (`slot = game room : surface`) |
| --- | --- | --- |
| `N_Combat01` | `HubReward` | none |
| `N_Combat02` | `HubReward` | `sideDoor1 = N_Sub01 : SubRoomReward`; `sideDoor2 = N_Sub03 : SubRoomReward` |
| `N_Combat03` | `HubReward` | `sideDoor1 = N_Sub04 : SubRoomReward` |
| `N_Combat04` | `HubReward` | `sideDoor1 = N_Sub02 : SubRoomReward`; `sideDoor2 = N_Sub06 : SubRoomReward` |
| `N_Combat05` | `HubReward` | `sideDoor1 = N_Sub02 : SubRoomReward`; `sideDoor2 = N_Sub07 : SubRoomReward`; `sideDoor3 = N_Sub03 : SubRoomReward` |
| `N_Combat06` | `HubReward` | `sideDoor1 = N_Sub10 : SubRoomHardReward`; `sideDoor2 = N_Sub05 : SubRoomReward` |
| `N_Combat07..08` | `HubReward` | none |
| `N_Combat09` | `HubReward` | `sideDoor1 = N_Sub11 : SubRoomHardReward`; `sideDoor2 = N_Sub08 : SubRoomReward`; `sideDoor3 = N_Sub14 : SubRoomHardReward` |
| `N_Combat10` | `HubReward` | `sideDoor1 = N_Sub05 : SubRoomReward`; `sideDoor2 = N_Sub09 : SubRoomHardReward` |
| `N_Combat11` | `HubReward` | `sideDoor1 = N_Sub01 : SubRoomReward` |
| `N_Combat12` | `HubRewardNoHammerHermes` | `sideDoor1 = N_Sub09 : SubRoomHardReward`; `sideDoor2 = N_Sub10 : SubRoomHardReward`; `sideDoor3 = N_Sub07 : SubRoomReward` |
| `N_Combat13..14` | `HubReward` | none |
| `N_Combat15` | `HubReward` | `sideDoor1 = N_Sub03 : SubRoomReward` |
| `N_Combat16` | `HubReward` | `sideDoor1 = N_Sub04 : SubRoomReward` |
| `N_Combat17` | `HubRewardNoHammerHermes` | `sideDoor1 = N_Sub11 : SubRoomHardReward` |
| `N_Combat18` | `HubReward` | `sideDoor1 = N_Sub12 : SubRoomReward` |
| `N_Combat19` | `HubReward` | none |
| `N_Combat20` | `HubReward` | `sideDoor1 = N_Sub06 : SubRoomReward` |
| `N_Combat21` | `HubReward` | none |
| `N_Combat22` | `HubReward` | `sideDoor1 = N_Sub14 : SubRoomHardReward`; `sideDoor2 = N_Sub02 : SubRoomReward` |
| `N_Combat23` | `HubReward` | `sideDoor1 = N_Sub12 : SubRoomReward`; `sideDoor2 = N_Sub13 : SubRoomReward`; `sideDoor3 = N_Sub15 : SubRoomReward` |

Repeated `N_SubXX` keys are intentional. Identity is parent control plus slot
key, not the child game-room key.

## Owned State

```lua
{
    kind = "EphyraCombat",
    generatedReward = {
        storeKey = "HubRewards",
        rewardType = "Boon",
        payload = { source = "ApolloUpgrade" },
    },
    sideRooms = {
        sideDoor1 = {
            gameRoomKey = "N_Sub01",
            generation = "Generated", -- Generated | NotGenerated | ""
            enteredOrder = 1,          -- zero means generated but unentered
            generatedReward = {
                storeKey = "SubRoomRewards",
                rewardType = "MaxHealthDrop",
            },
        },
    },
}
```

The incoming store is fixed. `HubRewardNoHammerHermes` further excludes Hammer
and Hermes outcomes. Incoming persistence is `rewardType` plus one conditional
Boon source.

Each side slot persists an explicit generation enum, `enteredOrder`, and one
reward type. Current subroom stores contain no payload-bearing primitive, so
side rewards require no payload fields.

## Dormancy and Completeness

All side slots are dormant when their parent pylon is not in the Hub's ordered
six visited targets. The incoming hub reward remains active because every Hub
target was generated and offered.

For a visited pylon:

- empty generation is incomplete;
- `NotGenerated` makes order and reward dormant;
- `Generated` requires a concrete reward;
- `enteredOrder = 0` means generated but not entered;
- positive orders must be unique and dense across entered slots.

The cross-slot order rule is template-local. Hub visitation order remains
batch-owned.

## Candidates and Feedback

The incoming reward uses `aspect = "generatedReward"`. Side generation,
reward, and entered order use the parent `roomControlKey`, declared
`localSlotKey`, and their semantic aspect. Candidate application never looks
up a child by `N_SubXX` alone.
