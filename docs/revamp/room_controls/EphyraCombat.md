# `EphyraCombat` Room Control

## Coverage

All 23 `Surface_N` controls `N_Combat01..23` use encounter profile
`EphyraCombat`. Their incoming surfaces and child slots are declaration-fixed.

| Room | Incoming counted binding | Side slots (`slot = game room : store`) |
| --- | --- | --- |
| `N_Combat01` | HubRewards | none |
| `N_Combat02` | HubRewards | `sideDoor1 = N_Sub01 : SubRoomRewards`; `sideDoor2 = N_Sub03 : SubRoomRewards` |
| `N_Combat03` | HubRewards | `sideDoor1 = N_Sub04 : SubRoomRewards` |
| `N_Combat04` | HubRewards | `sideDoor1 = N_Sub02 : SubRoomRewards`; `sideDoor2 = N_Sub06 : SubRoomRewards` |
| `N_Combat05` | HubRewards | `sideDoor1 = N_Sub02 : SubRoomRewards`; `sideDoor2 = N_Sub07 : SubRoomRewards`; `sideDoor3 = N_Sub03 : SubRoomRewards` |
| `N_Combat06` | HubRewards | `sideDoor1 = N_Sub10 : SubRoomRewardsHard`; `sideDoor2 = N_Sub05 : SubRoomRewards` |
| `N_Combat07..08` | HubRewards | none |
| `N_Combat09` | HubRewards | `sideDoor1 = N_Sub11 : SubRoomRewardsHard`; `sideDoor2 = N_Sub08 : SubRoomRewards`; `sideDoor3 = N_Sub14 : SubRoomRewardsHard` |
| `N_Combat10` | HubRewards | `sideDoor1 = N_Sub05 : SubRoomRewards`; `sideDoor2 = N_Sub09 : SubRoomRewardsHard` |
| `N_Combat11` | HubRewards | `sideDoor1 = N_Sub01 : SubRoomRewards` |
| `N_Combat12` | HubRewards; exclude WeaponUpgrade/HermesUpgrade | `sideDoor1 = N_Sub09 : SubRoomRewardsHard`; `sideDoor2 = N_Sub10 : SubRoomRewardsHard`; `sideDoor3 = N_Sub07 : SubRoomRewards` |
| `N_Combat13..14` | HubRewards | none |
| `N_Combat15` | HubRewards | `sideDoor1 = N_Sub03 : SubRoomRewards` |
| `N_Combat16` | HubRewards | `sideDoor1 = N_Sub04 : SubRoomRewards` |
| `N_Combat17` | HubRewards; exclude WeaponUpgrade/HermesUpgrade | `sideDoor1 = N_Sub11 : SubRoomRewardsHard` |
| `N_Combat18` | HubRewards | `sideDoor1 = N_Sub12 : SubRoomRewards` |
| `N_Combat19` | HubRewards | none |
| `N_Combat20` | HubRewards | `sideDoor1 = N_Sub06 : SubRoomRewards` |
| `N_Combat21` | HubRewards | none |
| `N_Combat22` | HubRewards | `sideDoor1 = N_Sub14 : SubRoomRewardsHard`; `sideDoor2 = N_Sub02 : SubRoomRewards` |
| `N_Combat23` | HubRewards | `sideDoor1 = N_Sub12 : SubRoomRewards`; `sideDoor2 = N_Sub13 : SubRoomRewards`; `sideDoor3 = N_Sub15 : SubRoomRewards` |

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

The incoming store is fixed. N_Combat12 and N_Combat17 declare negative
WeaponUpgrade and HermesUpgrade filters. Incoming persistence is `rewardType`
plus one conditional
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
