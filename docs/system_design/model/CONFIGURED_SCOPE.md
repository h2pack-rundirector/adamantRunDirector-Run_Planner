# Configured Scope

## Purpose

The fresh planner should be strict inside the configured route scope and
unopinionated outside it.

The user-facing relief valve is route scope, not weaker per-biome data:

```text
Configure fewer complete biomes, not partial structure-only biomes.
```

## Route Prefix

Configured scope is an ordered route prefix.

Examples for Underworld:

```text
F          valid scope
F, G       valid scope
F, G, H    valid scope
F, G, H, I valid scope
G only     invalid scope
F, H       invalid scope
```

Examples for Surface:

```text
N          valid scope
N, O       valid scope
N, O, P    valid scope
N, O, P, Q valid scope
O only     invalid scope
N, P       invalid scope
```

The game takes over after the last configured biome.

## Configured Biome Is Atomic

A configured biome must be complete as one unit:

```text
rooms
+ generated doors
+ offer points
+ independent acquisition choices where the topology does not derive them
+ room-template local state
= complete configured biome
```

There is no valid structure-only configured biome.

This is required because rewards and structure are not separable in the game:

- I `ClockworkGoal` is a reward offer that drives biome progression;
- H cage rewards are derived from generated-door batch state;
- O wheel offer points happen inside room encounter sequences;
- N hub rewards are generated as one batch before selected pylon traversal;
- unselected generated-door rewards can deplete reward bags.

## Editable Versus Complete

Biome Plan controls support incomplete workflow. A user can fill topology first
and rewards later.

But incomplete control state is not canonical history input:

```text
incomplete Biome Plan => no canonical biome plan
complete Biome Plan => canonical biome plan
```

The builder should only consume complete configured biomes.

## Outside Scope

Unconfigured biomes are intentionally absent from the canonical plan. They are
not represented as vanilla, random, or unknown nodes.

The planner may show them as outside scope in the UI, but history and
validation should stop at the configured route prefix.

## Validation Boundary

Control completeness checks whether all required data exists.

Validators check whether the complete data is legal:

```text
control: is every required room/door/offer field filled?
validator: could the game generate this complete route prefix?
```

This keeps incomplete-data errors local and keeps game legality in the
history/validation layer.
