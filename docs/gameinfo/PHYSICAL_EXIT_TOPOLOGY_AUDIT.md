# Physical Exit Topology Audit

This audit compares planner `exitCount` metadata with physical exit-door
objects in the local Hades II game data.

The goal is to keep `exitCount` tied to the current room's physical/generated
next-door capacity. Separate concepts, such as deterministic generated room
alternatives, cage reward counts, ship wheel reward choices, and Ephyra side
doors, should not be encoded by inflating `exitCount`.

## Method

Game data source:

- `/home/ayyatma/wsl-projects/modding/1GameData/Maps/bin/*.thing_bin`
- `/home/ayyatma/wsl-projects/modding/1GameData/Scripts/RoomData*.lua`

Physical door counts were probed with `strings` against exact exit-door object
names, excluding `HeroExit`, frame/decor objects, and exit lights.

Door object names used:

| Biome | Door object names |
| --- | --- |
| F | `ErebusExitDoor` |
| G | `OceanusExitDoor` |
| H | `FieldsExitDoor` |
| I | `CWTartarusExitDoor` |
| N | `N_OpeningDoor`, `EphyraExitDoorReturn`, `EphyraExitDoorReturnNE`, `N_SubRoomDoor`, hub `EphyraExitDoor` |
| O | `ShipsExitDoor` |
| P | `OlympusOutdoorExitDoor`, `OlympusIndoorExitDoor` |
| Q | `TyphonExitDoor`, `FortressMainDoor` |

Planner data source is the current working tree's normalized biome catalog and
layout declarations.

## Summary

| Biome | Result |
| --- | --- |
| F | Physical counts match current planner declarations. |
| G | Physical counts match current planner declarations. |
| H | Physical counts match current working-tree declarations after correcting `H_Intro`, `H_Combat01`, and `H_MiniBoss02`. |
| I | Physical counts match current planner declarations. |
| N | Main pylon rooms have one return-to-hub exit. Side-room doors are separate topology and match the declared side-door counts. Hub topology is special and should remain outside scalar `exitCount`. |
| O | Physical counts match current planner declarations. |
| P | Physical counts match current planner declarations after `P_Intro` is corrected to 2 exits. |
| Q | Physical counts match current working-tree declarations after correcting `Q_Intro`, one-exit combat rooms, and modeled miniboss rooms. |

## F: Erebus

Planner declarations match the physical `ErebusExitDoor` count.

| Room group | Physical count |
| --- | --- |
| `F_Opening01`, `F_Opening02`, `F_Opening03` | 1 |
| `F_Combat01`, `F_Combat09`, `F_Combat10` | 1 |
| Other `F_Combat*` rooms modeled in planner | 2 |
| `F_Story01`, `F_Reprieve01`, `F_Shop01` | 2 |
| `F_MiniBoss01`, `F_MiniBoss02`, `F_MiniBoss03` | 1 |

No planner update needed from this audit.

## G: Oceanus

Planner declarations match the physical `OceanusExitDoor` count.

| Room group | Physical count |
| --- | --- |
| `G_Intro` | 1 |
| `G_Combat02`, `G_Combat03`, `G_Combat05`, `G_Combat09`, `G_Combat14`, `G_Combat15`, `G_Combat17`, `G_Combat18`, `G_Combat20` | 3 |
| Other `G_Combat*` rooms modeled in planner | 2 |
| `G_Story01` | 1 |
| `G_Reprieve01`, `G_Shop01` | 2 |
| `G_MiniBoss01`, `G_MiniBoss03` | 2 |
| `G_MiniBoss02` | 1 |

No planner update needed from this audit.

## H: Mourning Fields

Physical `FieldsExitDoor` counts:

| Room group | Physical count | Current planner status |
| --- | ---: | --- |
| `H_Intro` | 1 | Corrected in current working tree. |
| `H_Combat01` | 1 | Corrected in current working tree. |
| `H_Combat02` through `H_Combat15` | 2 | OK. |
| `H_Bridge01` | 2 | OK. |
| `H_MiniBoss01` | 2 | OK. |
| `H_MiniBoss02` | 1 | Corrected in current working tree. |

Modeling note:

- Keep cage reward-count topology separate from physical door count.

## I: Tartarus

Planner declarations match the physical `CWTartarusExitDoor` count.

| Room group | Physical count |
| --- | --- |
| `I_Intro` | 1 |
| `I_Combat01`, `I_Combat03`, `I_Combat04`, `I_Combat09`, `I_Combat10`, `I_Combat11`, `I_Combat12`, `I_Combat15`, `I_Combat18`, `I_Combat21`, `I_Combat22` | 2 |
| Other `I_Combat*` rooms modeled in planner | 1 |
| `I_Reprieve01`, `I_MiniBoss01`, `I_MiniBoss02` | 2 |
| `I_Story01` | 1 |

No planner update needed from this audit.

## N: Ephyra

N cannot be reduced to a single ordinary scalar topology model:

- `N_Opening01` has one `N_OpeningDoor`.
- `N_PreHub01` has one return/advance door.
- Each pylon room has one return-to-hub door:
  `EphyraExitDoorReturn` or `EphyraExitDoorReturnNE`.
- Combat pylon side rooms are separate `N_SubRoomDoor` topology, not main
  path `exitCount`.
- `N_Hub` owns many pylon doors and the boss door; this is hub topology, not
  row-local `exitCount`.

Declared side-door counts match physical `N_SubRoomDoor` counts:

| Side-door count | Rooms |
| ---: | --- |
| 0 | `N_Combat01`, `N_Combat07`, `N_Combat08`, `N_Combat13`, `N_Combat14`, `N_Combat19`, `N_Combat21` |
| 1 | `N_Combat03`, `N_Combat11`, `N_Combat15`, `N_Combat16`, `N_Combat17`, `N_Combat18`, `N_Combat20` |
| 2 | `N_Combat02`, `N_Combat04`, `N_Combat06`, `N_Combat10`, `N_Combat22` |
| 3 | `N_Combat05`, `N_Combat09`, `N_Combat12`, `N_Combat23` |

No planner update needed from this audit, but future history/bag simulation
should keep N side-room traversal separate from main pylon return topology.

## O: Thessaly

Planner declarations match the physical `ShipsExitDoor` count.

All modeled O rooms checked in this audit have one physical ship exit:

- `O_Intro`
- `O_Combat01` through `O_Combat15`
- `O_Story01`
- `O_Reprieve01`
- `O_Shop01`
- `O_Devotion01`
- `O_MiniBoss01`, `O_MiniBoss02`
- `O_PreBoss01`

No planner update needed from this audit. Ship wheel reward-offer count remains
reward-generation topology, not `exitCount`.

## P: Olympus

Planner declarations match the physical Olympus door count after the current
working-tree correction to `P_Intro`.

| Room group | Physical count |
| --- | --- |
| `P_Intro` | 2 |
| `P_Combat01` through `P_Combat19` | 2 |
| `P_Story01`, `P_Reprieve01`, `P_Shop01` | 2 |
| `P_MiniBoss01` | 2 |
| `P_MiniBoss02` | 1 |
| `P_PreBoss01` | 1 |

No further planner update needed from this audit.

## Q: Summit

Physical `TyphonExitDoor` / `FortressMainDoor` counts:

| Room group | Physical count | Current planner status |
| --- | ---: | --- |
| `Q_Intro` | 1 | Corrected in current working tree. |
| `Q_Combat03`, `Q_Combat05`, `Q_Combat12`, `Q_Combat13`, `Q_Combat14`, `Q_Combat15` | 2 | OK. |
| `Q_Combat01`, `Q_Combat02`, `Q_Combat04`, `Q_Combat06`, `Q_Combat07`, `Q_Combat08`, `Q_Combat09`, `Q_Combat10`, `Q_Combat11`, `Q_Combat16` | 1 | Corrected in current working tree. |
| `Q_MiniBoss02`, `Q_MiniBoss03`, `Q_MiniBoss04`, `Q_MiniBoss05` | 1 | Corrected in current working tree. |
| `Q_PreBoss01` | 1 | OK for physical topology. |

Modeling note:

- Keep deterministic Q depth-3/depth-6 paired miniboss generation in Q topology,
  not in physical `exitCount`.
