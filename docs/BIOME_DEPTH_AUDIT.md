# Biome Depth Audit

Run Planner needs three different counters. They are related, but they are not
the same thing:

- `roomHistoryCost`: planner approximation of vanilla `SumPrevRooms` spacing.
  NPCs, Chaos gates, Hermes shrines, Stygian wells, and post-biome blockers use
  this axis.
- `biomeDepthCache`: vanilla `CurrentRun.BiomeDepthCache`, derived from room
  history by `GetBiomeDepth(...)`.
- `biomeEncounterDepth`: vanilla `CurrentRun.BiomeEncounterDepth`, advanced only
  when the started encounter has `CountsForRoomEncounterDepth = true`.

The data model should keep these axes separate. A room availability requirement
that comes from `CurrentRun.BiomeDepthCache` should be declared as
`biomeDepthCache`. A requirement that comes from
`CurrentRun.BiomeEncounterDepth` should be declared as `biomeEncounterDepth`.
`roomHistoryCost` should stay scoped to route spacing and should not be reused
as encounter depth.

## Vanilla Anchors

- `RunLogic.lua:GetBiomeDepth(...)` walks `CurrentRun.RoomHistory` backwards
  until a room with `NextRoomSet` is found. This is the source of
  `BiomeDepthCache`.
- `RoomLogic.lua:StartRoom(...)` initializes `RunDepthCache` and
  `BiomeDepthCache` at room start.
- `RoomLogic.lua:StartEncounter(...)` increments `BiomeEncounterDepth` only
  when the encounter has `CountsForRoomEncounterDepth`.
- `RunLogic.lua:IsRoomEligible(...)` checks `ForceAtBiomeDepth`,
  `ForceAtBiomeDepthMin`, `ForceAtBiomeDepthMax`, and game-state requirements
  against current run state.
- Encounter difficulty and type-count logic can use either `BiomeDepthCache` or
  `BiomeEncounterDepth` depending on encounter flags such as
  `UseEncounterDepth` and `UseEncounterDepthForTypes`.

## Modeling Rules

- Keep raw vanilla requirement values in declarations. Do not pre-shift Arachne
  from `4..8` to `5..9` in layout data.
- Declarations store per-row or per-option counter costs. They do not store a
  final absolute `biomeEncounterDepth` for each row.
- A route row exposes computed context with separate `biomeDepthCache` and
  `biomeEncounterDepth` values. The encounter-depth value is the counter before
  the selected row advances it.
- Availability checks compare explicit requirements to explicit context axes:
  `availability.biomeDepthCache` reads `context.biomeDepthCache`, and
  `availability.biomeEncounterDepth` reads `context.biomeEncounterDepth`.
- If a biome has inconsistent coordinate behavior, fix that in the biome
  adapter/context builder, not in every room declaration.
- Mixed legal encounter pools are normal. F/G/N/P combat rooms include field
  NPC or special replacement encounters; route defaults should still model the
  normal combat path unless the planner explicitly selects the replacement.
- First-run/tutorial-only alternatives are treated as provenance unless the
  route planner explicitly models first-run routing.

## Counter Audit Summary

This audit groups room keys when the keys share the same vanilla behavior.
`roomHistoryCost` is the planner spacing cost, not a vanilla field.
`biomeDepthCache` requirements should be copied from vanilla room/depth
requirements. `biomeEncounterDepth` should follow the encounter selected by the
room or encounter policy.

### F - Erebus

- `F_Opening01/02/03`: `roomHistoryCost = 1`; `biomeDepthCache = 0`; normal
  generated opening counts for `biomeEncounterDepth`.
- `F_Combat01..22`: `roomHistoryCost = 1`; `biomeDepthCache = route depth`;
  normal generated combat counts for `biomeEncounterDepth`.
- `F_Story01`, `F_Reprieve01`, `F_Shop01`: `roomHistoryCost = 1`;
  `biomeDepthCache = route depth`; selected encounter does not count for
  `biomeEncounterDepth`.
- `F_MiniBoss01/02/03`: `roomHistoryCost = 1`; `biomeDepthCache = route depth`;
  selected miniboss encounter counts for `biomeEncounterDepth`.
- `F_PreBoss01`: `roomHistoryCost = 1`; `biomeDepthCache = 10`; selected
  encounter does not count for `biomeEncounterDepth`.

### G - Oceanus

- `G_Intro`: `roomHistoryCost = 1`; `biomeDepthCache = 1`; selected encounter
  does not count for `biomeEncounterDepth`.
- `G_Combat01..20`: `roomHistoryCost = 1`; `biomeDepthCache = route depth`;
  normal generated combat counts for `biomeEncounterDepth`.
- `G_Story01`, `G_Reprieve01`, `G_Shop01`: `roomHistoryCost = 1`;
  `biomeDepthCache = route depth`; selected encounter does not count for
  `biomeEncounterDepth`.
- `G_MiniBoss01`, `G_MiniBoss03`: `roomHistoryCost = 1`;
  `biomeDepthCache = route depth`; selected miniboss encounter counts for
  `biomeEncounterDepth`.
- `G_MiniBoss02`: `roomHistoryCost = 1`; `biomeDepthCache = route depth`;
  `MiniBossCrawler` does not count for `biomeEncounterDepth`.
- `G_PreBoss01`: `roomHistoryCost = 1`; `biomeDepthCache = 8`; selected
  encounter does not count for `biomeEncounterDepth`.

### H - Mourning Fields

- `H_Intro`: `roomHistoryCost = 1`; selected encounter does not count for
  `biomeEncounterDepth`.
- `H_Combat01..15`: `roomHistoryCost = 1`; `biomeDepthCache = route pick`;
  passive cage encounters do not count for `biomeEncounterDepth`.
- `H_Bridge01`: `roomHistoryCost = 1`; `biomeDepthCache = route pick`;
  selected encounter does not count for `biomeEncounterDepth`.
- `H_MiniBoss01/02`: `roomHistoryCost = 1`; `biomeDepthCache = route pick`;
  selected miniboss encounter counts for `biomeEncounterDepth`.
- `H_PreBoss01`: `roomHistoryCost = 1`; selected encounter does not count for
  `biomeEncounterDepth`.

### I - Tartarus

- `I_Intro`: `roomHistoryCost = 1`; selected encounter does not count in normal
  routing. `ClockworkIntro` counts, but is first-time provenance.
- `I_Combat01..24`: `roomHistoryCost = 1`; `biomeDepthCache = route row`;
  generated combat counts for `biomeEncounterDepth`.
- `I_Story01`, `I_Reprieve01`: `roomHistoryCost = 1`;
  `biomeDepthCache = route row`; selected encounter does not count for
  `biomeEncounterDepth`.
- `I_MiniBoss01/02`: `roomHistoryCost = 1`; `biomeDepthCache = route row`;
  selected miniboss encounter counts for `biomeEncounterDepth`.
- Tartarus preboss shop (`I_PreBoss01` or `I_PreBoss02`): `roomHistoryCost = 1`;
  selected encounter does not count for `biomeEncounterDepth`.

### N - Ephyra

- `N_Opening01`: `roomHistoryCost = 1`; normal surface opening combat counts
  for `biomeEncounterDepth`.
- `N_PreHub01`: `roomHistoryCost = 1`; selected encounter does not count for
  `biomeEncounterDepth`.
- `N_Hub`: `roomHistoryCost = 0`; selected encounter does not count for
  `biomeEncounterDepth`.
- `N_Combat01..23`: `roomHistoryCost = 2`; pylon combat encounter counts for
  `biomeEncounterDepth`.
- `N_MiniBoss01/02`: `roomHistoryCost = 2`; selected miniboss encounter counts
  for `biomeEncounterDepth`.
- `N_Story01`: `roomHistoryCost = 2`; selected encounter does not count for
  `biomeEncounterDepth`.
- `N_Sub01..15`: side-room spacing is parent depth plus one for feature
  targeting; selected subroom encounter does not count for
  `biomeEncounterDepth`.
- `N_PreBoss01`: `roomHistoryCost = 1`; selected encounter does not count for
  `biomeEncounterDepth`.

### O - Rift of Thessaly

- `O_Intro`: `roomHistoryCost = 1`; `biomeDepthCache = 1`; selected encounter
  does not count for `biomeEncounterDepth`.
- `O_Combat01..15`: `roomHistoryCost = 1`; `biomeDepthCache = route depth`;
  the main combat leg counts for `biomeEncounterDepth`, and the optional third
  combat also counts when selected.
- `O_Story01`, `O_Reprieve01`, `O_Shop01`: `roomHistoryCost = 1`;
  `biomeDepthCache = route depth`; selected encounter does not count for
  `biomeEncounterDepth`.
- `O_Devotion01`: `roomHistoryCost = 1`; `biomeDepthCache = route depth`;
  selected encounter counts for `biomeEncounterDepth`.
- `O_MiniBoss01`: `roomHistoryCost = 1`; `biomeDepthCache = route depth`;
  `MiniBossCharybdis` does not count for `biomeEncounterDepth`.
- `O_MiniBoss02`: `roomHistoryCost = 1`; `biomeDepthCache = route depth`;
  selected encounter counts for `biomeEncounterDepth`.
- `O_PreBoss01`: `roomHistoryCost = 1`; `biomeDepthCache = 7`; selected
  encounter does not count for `biomeEncounterDepth`.

### P - Mount Olympus

- `P_Intro`: `roomHistoryCost = 1`; `biomeDepthCache = 1`; selected encounter
  does not count for `biomeEncounterDepth`.
- `P_Combat01..19`: `roomHistoryCost = 1`; `biomeDepthCache = route depth`;
  main generated combat counts for `biomeEncounterDepth`.
- `P_Story01`, `P_Reprieve01`, `P_Shop01`: `roomHistoryCost = 1`;
  `biomeDepthCache = route depth`; selected encounter does not count for
  `biomeEncounterDepth`.
- `P_MiniBoss01`: `roomHistoryCost = 1`; `biomeDepthCache = route depth`;
  `MiniBossTalos` does not count for `biomeEncounterDepth`.
- `P_MiniBoss02`: `roomHistoryCost = 1`; `biomeDepthCache = route depth`;
  selected encounter counts for `biomeEncounterDepth`.
- `P_PreBoss01`: `roomHistoryCost = 1`; `biomeDepthCache = 9`; selected
  encounter does not count for `biomeEncounterDepth`.

### Q - Summit

- `Q_Intro`: `roomHistoryCost = 1`; `biomeDepthCache = 1`; selected encounter
  does not count for `biomeEncounterDepth`.
- `Q_Combat01..16`: `roomHistoryCost = 1`; `biomeDepthCache = route depth`;
  selected combat encounter counts for `biomeEncounterDepth`.
- `Q_MiniBoss02/03/05`: `roomHistoryCost = 1`; `biomeDepthCache = route
  depth`; selected miniboss encounter counts for `biomeEncounterDepth`.
- `Q_MiniBoss04`: `roomHistoryCost = 1`; `biomeDepthCache = route depth`;
  `BossTyphonEye01` does not count for `biomeEncounterDepth`.
- `Q_PreBoss01`: `roomHistoryCost = 1`; `biomeDepthCache = 7`; selected
  encounter does not count for `biomeEncounterDepth`.

## Biome F - Erebus

Route surface:

- Opening: `F_Opening01`, `F_Opening02`, `F_Opening03`
- Normal route: `F_Combat01` through `F_Combat22`
- Story: `F_Story01`
- Fountain: `F_Reprieve01`
- Midshop: `F_Shop01`
- Devotion-capable combat maps: `F_Combat05`, `F_Combat06`, `F_Combat07`, `F_Combat11`,
  `F_Combat12`, `F_Combat13`, `F_Combat14`, `F_Combat15`, `F_Combat16`,
  `F_Combat17`, `F_Combat18`, `F_Combat20`
- Miniboss: `F_MiniBoss01`, `F_MiniBoss02`, `F_MiniBoss03`
- Preboss: logical reward marker; vanilla resolves `F_PreBoss01`

Depth facts:

- Opening rooms are mixed in vanilla because first-run/tutorial alternatives do
  not all count. Normal route modeling treats the regular generated opening as
  count-producing.
- F combat rooms are mixed because the legal pool can include field NPC and
  Arachne combat replacements. The normal generated combat path counts.
- `F_Story01`, `F_Reprieve01`, `F_Shop01`, and `F_PreBoss01` do not count for
  `BiomeEncounterDepth`.
- All modeled F miniboss rooms count.
- F combat map gates use `BiomeEncounterDepth`.
- F story/fountain/shop/miniboss/preboss gates use `BiomeDepthCache`.

## Biome G - Oceanus

Route surface:

- Entry: `G_Intro`
- Normal route: `G_Combat01` through `G_Combat20`
- Story: `G_Story01`
- Fountain: `G_Reprieve01`
- Midshop: `G_Shop01`
- Devotion-capable combat maps: `G_Combat02`, `G_Combat03`, `G_Combat09`, `G_Combat10`,
  `G_Combat11`, `G_Combat12`, `G_Combat13`, `G_Combat14`, `G_Combat15`,
  `G_Combat16`, `G_Combat17`
- Miniboss: `G_MiniBoss01`, `G_MiniBoss02`, `G_MiniBoss03`
- Preboss: logical reward marker; vanilla resolves `G_PreBoss01`

Depth facts:

- `G_Intro` and `G_PreBoss01` do not count.
- G combat rooms are mixed because the legal pool can include field NPC and
  Arachne combat replacements. The normal generated combat path counts.
- `G_Story01`, `G_Reprieve01`, and `G_Shop01` do not count.
- `G_MiniBoss01` and `G_MiniBoss03` count.
- `G_MiniBoss02` (`MiniBossCrawler`) does not count.
- G combat map gates use `BiomeEncounterDepth`.
- G story/fountain/shop/miniboss/preboss gates use `BiomeDepthCache`.

## Biome H - Mourning Fields

Route surface:

- Entry: `H_Intro`
- Cage combat maps: `H_Combat01` through `H_Combat15`
- Bridge/story: `H_Bridge01`
- Miniboss: `H_MiniBoss01`, `H_MiniBoss02`
- Preboss: logical reward marker; vanilla resolves `H_PreBoss01`

Depth facts:

- H passive cage combat uses `GeneratedH_Passive` or
  `GeneratedH_PassiveSmall`, both non-counting.
- H minibosses count.
- `H_Intro`, `H_Bridge01`, and `H_PreBoss01` do not count.
- H route eligibility mostly uses route-pick position and `BiomeDepthCache`
  windows; cage reward count is a separate room-template concept.

## Biome I - Tartarus

Route surface:

- Entry: `I_Intro`
- Clockwork/extension combat maps: `I_Combat01` through `I_Combat24`
- Story: `I_Story01`
- Fountain: `I_Reprieve01`
- Miniboss: `I_MiniBoss01`, `I_MiniBoss02`
- Preboss: logical shop marker; vanilla resolves `I_PreBoss01` or `I_PreBoss02`

Depth facts:

- I generated combat and smaller generated combat count.
- `ClockworkIntro` counts, but it is first-time/intro provenance rather than a
  normal route decision.
- `I_Story01`, `I_Reprieve01`, and shop/preboss rooms do not count.
- I minibosses count.
- `I_Combat24` is gated by `BiomeDepthCache < 6`.
- Tartarus routing has its own clockwork-goal axis; do not collapse it into
  either depth counter.

## Biome N - Ephyra

Route surface:

- Fixed before hub: `N_Opening01`, `N_PreHub01`, `N_Hub`
- Pylon combat maps: `N_Combat01` through `N_Combat23`
- Story: `N_Story01`
- Miniboss: `N_MiniBoss01`, `N_MiniBoss02`
- Side rooms: `N_Sub*` rooms behind combat-room doors
- Preboss: logical shop marker; vanilla resolves `N_PreBoss01`

Depth facts:

- `N_Opening01` is mixed because `OpeningEmpty` can be selected, but normal
  surface opening generated combat counts.
- `N_PreHub01` does not count.
- `N_Hub` does not count and should have `roomHistoryCost = 0`.
- N pylon combat rooms count.
- `N_MiniBoss01` and `N_MiniBoss02` count.
- `N_Story01` does not count.
- N side rooms inherit `GeneratedNSubRoom` behavior and do not count for
  `BiomeEncounterDepth`.
- Route spacing currently approximates each pylon pick as cost `2` to account
  for hub traversal.

## Biome O - Rift of Thessaly

Route surface:

- Entry: `O_Intro`
- Ship combat maps: `O_Combat01` through `O_Combat15`
- Story: `O_Story01`
- Fountain: `O_Reprieve01`
- Midshop: `O_Shop01`
- Devotion room: `O_Devotion01`
- Miniboss: `O_MiniBoss01`, `O_MiniBoss02`
- Preboss: logical shop marker; vanilla resolves `O_PreBoss01`

Depth facts:

- `O_Intro` and `O_PreBoss01` do not count.
- O combat rooms are multi-encounter rooms. The intro leg can be mixed because
  Heracles can replace it; the main combat leg counts; the optional third leg
  counts when present.
- `O_Story01`, `O_Reprieve01`, and `O_Shop01` do not count.
- `O_Devotion01` counts.
- `O_MiniBoss01` (`MiniBossCharybdis`) does not count.
- `O_MiniBoss02` counts.
- O special-room gates use both `BiomeDepthCache` and `BiomeEncounterDepth`.

## Biome P - Mount Olympus

Route surface:

- Entry: `P_Intro`
- Combat maps: `P_Combat01` through `P_Combat19`
- Story: `P_Story01`
- Fountain: `P_Reprieve01`
- Midshop: `P_Shop01`
- Miniboss: `P_MiniBoss01`, `P_MiniBoss02`
- Preboss: logical reward marker; vanilla resolves `P_PreBoss01`

Depth facts:

- `P_Intro` does not count.
- P combat rooms are multi-encounter rooms. The pre-combat leg is usually
  non-counting, but Heracles can replace it with a counting encounter. The main
  generated combat leg counts.
- `P_Story01`, `P_Reprieve01`, `P_Shop01`, and `P_PreBoss01` do not count.
- `P_MiniBoss01` (`MiniBossTalos`) does not count.
- `P_MiniBoss02` counts.
- P special-room gates use both `BiomeDepthCache` and `BiomeEncounterDepth`.

## Biome Q - Summit

Route surface:

- Entry: `Q_Intro`
- Combat maps: `Q_Combat01` through `Q_Combat16`
- Miniboss: `Q_MiniBoss02`, `Q_MiniBoss03`, `Q_MiniBoss04`, `Q_MiniBoss05`
- Preboss: logical shop marker; vanilla resolves `Q_PreBoss01`

Depth facts:

- `Q_Intro` and `Q_PreBoss01` do not count.
- Q normal combat and island combat rooms count.
- `Q_MiniBoss02`, `Q_MiniBoss03`, and `Q_MiniBoss05` count.
- `Q_MiniBoss04` (`BossTyphonEye01`) does not count.
- Q room gates use `BiomeDepthCache`.

## Implemented Data Split

The current implementation uses the three-axis split:

1. Generic room availability `biomeDepth` declarations were renamed to
   `biomeDepthCache`.
2. Room/layout availability keeps raw vanilla values.
3. `biomeEncounterDepthCost` declares how the selected row advances encounter
   depth for later rows.
4. Row-engine context separately exposes `biomeDepthCache`,
   `biomeEncounterDepth`, and `biomeEncounterDepthCost`.
5. `roomHistoryCost` remains the independent spacing axis for NPCs, Chaos,
   wells, shrines, and post-biome blockers.
