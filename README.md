# Run Planner

Run Planner is a Run Director module for planning room and reward routing by
biome depth.


## What It Does

Run Planner will let players describe a biome as a sequence of route slots, such
as combat, story, shop, fountain, trial, or miniboss rooms, with optional reward
preferences for eligible combat and fountain-style rooms. Normal route rewards
use the community-facing Major/Minor split; special rooms keep their own reward
surfaces.

## Gameplay Impact

The first version is a scaffold for the routing system. Runtime route hooks will
prefer eligible room and reward matches while preserving vanilla fallback when a
planned slot cannot be satisfied.

## How To Use

Install using r2modman. In game, open the Run Director menu and configure this module from the shared settings window.

