# N / Ephyra Model

## Purpose

N should participate in the same fresh-start pipeline as the other biomes:

```text
form snapshot
-> canonical plan
-> history ledger
-> validators
-> feedback
```

N is special in how its hub and pylon rooms materialize into history. It should
not require a separate validation or feedback architecture.

The important distinction is:

```text
N is not an open linear stream.
N is a fixed hub structure with an ordered selected pylon stream.
```

## Fixed Intro

N starts with a fixed multi-room intro sequence:

```text
N_Opening
-> N_PreHub
-> N_Hub
```

The route form does not need to model these as ordinary editable room picks.
Layout/structure declares them as fixed physical rooms that are materialized
before hub door generation.

## Hub Generated Doors

The hub generates the pylon doors as one batch.

Unlike linear biomes, the hub does not select exactly one generated door. It
generates a larger fixed set and the player enters an ordered subset of those
doors.

Canonical shape:

```lua
roomNode = {
    roomKey = "N_Hub",
    roomState = {
        kind = "EphyraHub",
        hubDoorCount = 10,
    },
    generatedDoors = {
        selection = {
            mode = "orderedSubset",
            requiredCount = 6,
            visits = {
                { doorIndex = 3, visitOrder = 1 },
                { doorIndex = 1, visitOrder = 2 },
                { doorIndex = 7, visitOrder = 3 },
                { doorIndex = 2, visitOrder = 4 },
                { doorIndex = 5, visitOrder = 5 },
                { doorIndex = 4, visitOrder = 6 },
            },
        },
        doors = {
            { exitIndex = 1, targetRoomKey = "N_Combat04", offerPoint = { ... } },
            { exitIndex = 2, targetRoomKey = "N_Combat08", offerPoint = { ... } },
            { exitIndex = 3, targetRoomKey = "N_MiniBoss01", offerPoint = { ... } },
            -- ...
        },
    },
}
```

`hubDoorCount` is explicit user-authored data. The UI should expose whether the
hub generated 9 or 10 doors. The completed plan must then provide that many
concrete generated doors.

The hub UI should be hard-structured around these doors:

```text
Hub Door Count: 9 / 10

Door 1   N_Combat04     Visit 2
Door 2   N_Combat08     Visit 4
Door 3   N_MiniBoss01   Visit 1
Door 4   N_Story01      Visit 6
Door 5   N_Combat12     Visit 5
Door 6   N_Combat17     -
Door 7   N_Combat03     Visit 3
...

Terminal
N_PreBoss
```

`Visit -` means the hub door was generated but not entered. `Visit N` means
the player entered that generated door at that point in the pylon stream.

## Hub Reward Batch

All hub pylon door rewards are generated when the hub generates its doors.

This is one reward offer batch for bag simulation:

```text
room.enter N_Hub
  generate 9-10 pylon doors
  generate 9-10 pylon door offer points
  deplete reward bags for the full hub batch
```

Unselected hub doors still exist. Their rewards are offered and can affect bag
state, but they are not acquired.

Selected hub doors are acquired/entered in `visitOrder` order.

## Selection Mode

Most generated-door sets use:

```lua
selection = {
    mode = "single",
    selectedDoorIndex = 1,
}
```

N hub uses:

```lua
selection = {
    mode = "orderedSubset",
    requiredCount = 6,
    visits = {
        { doorIndex = 3, visitOrder = 1 },
        ...
    },
}
```

This keeps N inside the same generated-door model while expressing its real
hub behavior.

Validation rules:

- visit orders must be unique;
- visit orders must be exactly `1..6`;
- visited door indexes must be unique;
- visited door indexes must reference generated hub doors;
- exactly six pylon doors must be selected before preboss;
- selected doors materialize in visit order;
- unselected doors still participate in hub reward offer generation.

Do not use hub door index as implicit walking order. Door index is generated
door identity. Visit order is player route order.

## Selected Pylon Stream

The selected pylon stream is derived from the hub selection:

```text
N_Opening
-> N_PreHub
-> N_Hub
-> selected pylon visit 1
-> selected pylon visit 2
-> selected pylon visit 3
-> selected pylon visit 4
-> selected pylon visit 5
-> selected pylon visit 6
-> N_PreBoss
```

This is the N equivalent of the authored room stream in linear biomes.

The form is hub-shaped, but the history builder sees a deterministic stream:

```text
sort hub visits by visitOrder
materialize each selected pylon visit
materialize terminal preboss
```

Preboss is not one of the 9-10 generated hub doors. It is the terminal room
after six selected pylon visits.

## Pylon Materialization

Selected pylon doors materialize into physical room-history entries.

For a selected combat pylon:

```text
N_CombatXX
-> optional side room
-> N_CombatXX restore
-> N_Hub return
```

For multiple side rooms, the restore/return sequence repeats according to the
game traversal:

```text
N_CombatXX
-> SideRoom 1
-> N_CombatXX restore
-> SideRoom 2
-> N_CombatXX restore
-> N_Hub return
```

For story and miniboss pylons:

```text
N_StoryXX
-> N_Hub return
```

```text
N_MiniBossXX
-> N_Hub return
```

The canonical plan stores the selected pylon door and any pylon-local state.
The history builder emits the deterministic restore/hub-return physical entries.

## Pylon Room State

N pylon room kinds own their local state.

Combat pylons may contain side-room child state:

```lua
roomState = {
    kind = "EphyraCombat",
    sideRooms = {
        {
            roomKey = "N_Sub13",
            entered = true,
            roomState = { ... },
            offerPoints = { ... },
        },
    },
}
```

Story and miniboss pylons can use smaller typed payloads when needed:

```lua
roomState = {
    kind = "EphyraStory",
}
```

```lua
roomState = {
    kind = "EphyraMiniboss",
}
```

## Preboss Termination

N preboss becomes valid after six selected pylon visits.

The structure rule is:

```text
fixed intro sequence
-> hub generated-door batch
-> six selected pylon visits in selected order
-> N_PreBoss
```

Preboss termination is based on selected pylon count, not on total generated
hub door count.

## History Source Addresses

History entries emitted from N materialization should carry source addresses
back to the authored participant:

- hub-generated door findings target the hub door participant;
- pylon room findings target the selected pylon room/door participant;
- side-room findings target the pylon room's side-room child participant;
- derived restore and hub-return entries point back to the pylon room that
  caused them.

Validators still consume the history ledger only. Feedback uses source
addresses to return findings to the correct form participant.

## Boundary

N is graph-shaped in history but still uses the same canonical generated-door
model:

```text
N special case = hub selection mode + pylon materializers
not a separate route/validator/feedback architecture
```
