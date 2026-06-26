# ForceAtBiomeDepth Audit

This note records the live-game probe around `ForceAtBiomeDepthMin` /
`ForceAtBiomeDepthMax` and the declaration-modeling consequences for Run
Planner. It is intended to guide the next data cleanup pass before sibling-path
topology for F/G/P.

## Vanilla Semantics

Source: `1GameData/Scripts/RunLogic.lua`, `IsRoomForced`.

`ForceAtBiomeDepth` is exact-depth forcing:

- A room with `ForceAtBiomeDepth = 6` is forced only when
  `CurrentRun.BiomeDepthCache == 6`.
- `IsRoomEligible` rejects it at every other biome depth.

`ForceAtBiomeDepthMin` / `ForceAtBiomeDepthMax` is a force window with a
persistent deadline:

- Before `ForceAtBiomeDepthMin`: not forced and not eligible from this force
  axis.
- Between min and max: force chance increases.
- At max: force chance becomes 100%.
- After max: still force-forced as long as the room remains eligible.

The key implementation detail is that `IsRoomForced` returns true when
`currentBiomeDepth >= ForceAtBiomeDepthMax`. `IsRoomEligible` only rejects
min/max rooms below `ForceAtBiomeDepthMin`; it does not reject rooms above
`ForceAtBiomeDepthMax`.

Therefore, `ForceAtBiomeDepthMax` is not an eligibility upper bound. If a room
has a real upper bound, it appears separately in `GameStateRequirements`, such
as `CurrentRun.BiomeDepthCache <= N`.

## Non-Intro/Preboss Min/Max Rooms

Intro/preboss topology rooms were excluded from this list:

- `F_PreBoss01`
- `G_PreBoss01`
- `G_Intro`
- `H_Intro`
- `I_Intro`
- `O_Intro`
- `O_PreBoss01`
- `P_PreBoss01`

### Erebus

`F_MiniBoss01`, `F_MiniBoss02`, `F_MiniBoss03`

- Force window: `4-6`.
- No upper eligibility bound.
- Force persists after 6 if eligible.
- Eligibility adds mutual exclusion through `CurrentRun.RoomsEntered`, plus
  max creation/appearance limits.
- `F_MiniBoss02` and `F_MiniBoss03` add meta-progression requirements.
- `F_MiniBoss03` is `DebugOnly`.

`F_Shop01`

- Force window: `4-6`.
- Eligibility has `CurrentRun.BiomeDepthCache <= 6`.
- Eligibility also requires at least two exits via `RequiredMinExits(2)`.
- It does not persist after 6 in practice.

### Oceanus

`G_Shop01`

- Force window: `3-6`.
- Eligibility has `CurrentRun.BiomeDepthCache <= 5`.
- Eligibility also requires at least two exits via `RequiredMinExits(2)`.
- Forcing past 5 is blocked by eligibility.

`G_MiniBoss01`, `G_MiniBoss02`, `G_MiniBoss03`

- Force window: `4-7`.
- No upper eligibility bound.
- Force persists after 7 if eligible.
- Eligibility adds mutual exclusion/current-run entered checks.
- Some variants add meta-progression requirements.
- `G_MiniBoss03` is `DebugOnly`.

### Fields

`H_MiniBoss01`, `H_MiniBoss02`

- Force window: `2-4`.
- No upper eligibility bound.
- Force persists after 4 if eligible.
- Normal H structure usually ends the opportunity at the same time, so the
  current model works by topology rather than by the true force semantics.
- Eligibility adds mutual exclusion and max creation/appearance limits.

### Tartarus

`I_Shop01`

- Force window: `3-5`.
- `DebugOnly = true`.
- Eligibility has `CurrentRun.BiomeDepthCache <= 5`.
- Eligibility also requires min exits and the current-room special-room
  exclusion.
- Not relevant for normal routing.

`I_MiniBoss01`

- Force window: `3-7`.
- No upper eligibility bound.
- Force persists after 7 if eligible.
- Eligibility adds `CurrentRun.BiomeDepthCache >= 3`, mutual exclusion,
  current-room special-room exclusion, and an offered door with room set `I`.

`I_MiniBoss02`

- Inherits `I_MiniBoss01`.
- Has the same force window through inheritance.
- Adds its own mutual exclusion and Clockwork non-goal reward capacity
  requirement.

`I_Story01`

- Force window: `2-4`.
- No simple upper eligibility bound.
- It can appear later in extended Tartarus if still eligible.
- Eligibility is mostly meta/story requirements plus current-room special-room
  exclusion and I-door availability.

### Olympus

`P_MiniBoss01`, `P_MiniBoss02`

- Force window: `4-7`.
- No upper eligibility bound.
- Force persists after 7 if eligible.
- Eligibility adds `CurrentRun.BiomeDepthCache >= 4`, other-miniboss-not-entered,
  and `MapState.OfferedExitDoors > 1`.

## Declaration Mismatches Fixed

The declaration pass split the force window from true availability for these
rooms:

- F minibosses currently use availability `biomeDepthCache = { min = 4, max = 6 }`.
- G minibosses currently use availability `biomeDepthCache = { min = 4, max = 7 }`.
- H minibosses currently use availability `biomeDepthCache = { min = 2, max = 4 }`.
- I minibosses currently use availability `biomeDepthCache = { min = 3, max = 7 }`.
- P minibosses currently use availability `biomeDepthCache = { min = 4, max = 7 }`.

Those max values are force-deadline maxes, not eligibility maxes. They now live
under `force.biomeDepthCache`; `availability.biomeDepthCache` keeps only true
eligibility constraints.

Known real eligibility caps:

- `F_Shop01`: `biomeDepthCache <= 6`, requires at least two exits.
- `G_Shop01`: `biomeDepthCache <= 5`, requires at least two exits.
- `I_Shop01`: debug-only, `biomeDepthCache <= 5`, requires min exits, ignored for
  normal route modeling.

## Proposed Declaration Shape

Keep hard eligibility separate from force pressure:

```lua
availability = {
    biomeDepthCache = { min = 4 },
    requiresMultipleOfferedDoors = true,
}

force = {
    biomeDepthCache = { min = 4, max = 7 },
}
```

For grouped force pressure:

```lua
forcedGroups = {
    {
        key = "P_Minibosses",
        candidates = { "P_MiniBoss01", "P_MiniBoss02" },
        force = { biomeDepthCache = { min = 4, max = 7 } },
    },
}
```

The row planner should use `availability` for option visibility/validity and
`force` for generated-room pressure.

## Modeling Consequences

For generated offers after a force window has reached max:

```lua
requiredForcedCountAtRow =
min(unresolvedForcedCandidates, generatedRewardExitCountAtRow)
```

The generated forced count should include both:

- the selected primary planned room, and
- sibling topology offers generated beside it.

For F/G/P this means force pressure belongs to the room planner and sibling
topology together, not sibling topology alone.

H currently holds because the force deadline lines up with the biome ending, but
that is an accident of topology. The generic model should not depend on that.

## Action Checklist

- Add explicit `force` metadata to forced room options and forced groups. Done.
- Correct miniboss `availability` windows so max force depth is not treated as
  eligibility max. Done.
- Preserve real shop eligibility maxes as availability bounds. Done.
- Keep `DebugOnly` variants out of normal route modeling unless we explicitly
  decide to surface debug rooms.
- Teach forced-group validation to consume generated reward-door capacity and
  primary-row plus sibling topology together.
- Apply the model to F/G/P sibling topology after the metadata split is in place.
