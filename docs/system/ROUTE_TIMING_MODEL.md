# Route Timing Model

This note is the timing source of truth for vanilla room, reward, and counter
lifecycles in Run Planner. `BIOME_DEPTH_AUDIT.md` is the companion per-biome
data reference for room groups, counter costs, and exceptions.

## Core Counters

Run Planner keeps three timing axes separate:

- `biomeDepthCache`: vanilla `CurrentRun.BiomeDepthCache`. This is derived
  from committed room history by `GetBiomeDepth(...)`.
- `biomeEncounterDepth`: vanilla `CurrentRun.BiomeEncounterDepth`. This is
  advanced by `StartEncounter(...)` when the started encounter has
  `CountsForRoomEncounterDepth = true`.
- `roomHistoryOrdinal`: planner route-history axis for spacing rules. This
  models vanilla `RoomHistory` / `SumPrevRooms` style checks.

These axes are related, but they are observed at different phases of the room
lifecycle. Do not replace them with a single route coordinate.

## Vanilla Anchors

The relevant vanilla ordering is:

1. `StartRoom(...)` applies room `RunOverrides`.
2. `StartEncounter(...)` starts the selected encounter.
3. If the encounter has `CountsForRoomEncounterDepth = true`,
   `BiomeEncounterDepth` and run encounter depth increment.
4. The room plays out.
5. The current room reward is spawned and picked up.
6. Reward pickup updates run state such as `CurrentRun.UseRecord`,
   `LootTypeHistory`, resources, and similar reward-derived state.
7. Next-room candidates are evaluated from the current room.
8. The selected next room object is created.
9. The next room encounter is chosen.
10. The next room reward is chosen.
11. `LeaveRoom(...)` inserts the current room into `RoomHistory`.
12. `UpdateRunHistoryCache(...)` recomputes `RunDepthCache` and
    `BiomeDepthCache`.
13. `CurrentRoom` switches to the chosen next room.

So the offer context is not a single "next room depth" value. It is a snapshot
after the current encounter and current reward, but before the current room is
committed to room history.

## Planner Phase Model

For one current route leaf:

```text
Process current room leaf
  advance biomeEncounterDepth by current leaf encounter cost
  advance runEncounterDepth by current leaf encounter cost

Apply current room reward
  update reward-derived state:
    SpellDrop seen
    Talent/Hermes/Hammer counts
    god history
    other reward legality state

Evaluate next room / next reward eligibility
  BED-sensitive rules see the current encounter already counted
  reward-sensitive rules see the current reward already collected
  BDC-sensitive rules still see the current room depth before leave
  room-history spacing still sees the pre-leave history ordinal

Leave current room
  advance biomeDepthCache by current leaf BDC cost
  advance roomHistoryOrdinal by current leaf room-history cost
```

In code terms, a next-offer context is closer to:

```lua
{
    biomeEncounterDepth = afterCurrentEncounter,
    runEncounterDepth = afterCurrentEncounter,
    rewardState = afterCurrentReward,
    biomeDepthCache = beforeLeavingCurrentRoom,
    roomHistoryOrdinal = beforeLeavingCurrentRoom,
}
```

Then the timeline commits the current row's `biomeDepthCacheCost` and
`roomHistoryCost`.

## Room Eligibility Timing

Room eligibility checks use the current run state at next-room generation time.

If a room checks `CurrentRun.BiomeDepthCache`, it sees the current room's cached
depth before the current room is committed to history. Example: `F_Story01`
requires `BiomeDepthCache >= 4` and `<= 8`. That means it can be offered while
standing in an F room whose current BDC is `4`, and if chosen it is entered as
the next room.

If a room checks `CurrentRun.BiomeEncounterDepth`, it sees the value after the
current room's encounter has started and counted. Example: `P_Story01` checks
`BiomeEncounterDepth > 2` and `BiomeDepthCache <= 7`, so its BED requirement is
post-current-encounter while its BDC requirement is pre-leave.

This mixed timing is intentional vanilla behavior. Declarations should preserve
the vanilla requirement axis:

- requirements reading `CurrentRun.BiomeDepthCache` become
  `availability.biomeDepthCache`;
- requirements reading `CurrentRun.BiomeEncounterDepth` become
  `availability.biomeEncounterDepth`.

## Reward Eligibility Timing

The next room's reward is chosen while the next room object is created, before
the next map loads. By that point, the current room reward has normally already
been picked up.

This matters for reward dependencies. If the current room gives `SpellDrop` and
the player picks it up before taking the exit, then `CurrentRun.UseRecord.SpellDrop`
is updated before the next room reward is chosen. A planned `TalentDrop` in the
very next room can therefore be legal if its other requirements pass.

Planner reward simulation should treat a selected current-room reward as visible
to downstream rooms immediately after that room in the route timeline.

## Room History Timing

Vanilla inserts the current room into `CurrentRun.RoomHistory` during
`LeaveRoom(...)`, before recomputing history caches and before switching
`CurrentRoom` to the chosen next room.

For planner modeling, `roomHistoryOrdinal` should advance on leave, together
with `biomeDepthCache`. NPC, Chaos, Stygian well, Hermes shrine, and similar
spacing checks should use the pre-leave history ordinal when evaluating what
can be offered from the current room, unless a specific vanilla system is shown
to use a different counter.

## `NextRoomSet` And Biome Boundaries

`GetBiomeDepth(...)` starts at `1`. If `CurrentRoom` is nil or the current room
has `NextRoomSet`, it returns `1`. Otherwise it walks `RoomHistory` backward
until it finds a room with `NextRoomSet`, incrementing depth for each room after
that boundary.

`NextRoomSet` therefore means "biome boundary / reset to depth 1", not "depth
0". F opening only has depth 0 because `F_Opening01` explicitly sets
`RunOverrides = { BiomeDepthCache = 0 }` on room start. After leaving F opening,
`UpdateRunHistoryCache(...)` sees the opening as the current boundary room and
recomputes BDC to `1` for the first real F body room.

## Room Kind Defaults

These defaults are modeling guidance. Individual room or encounter declarations
still win.

- F opening: starts BDC at `0`; first body room sees BDC `1` after leave. BED
  depends on the selected opening encounter. Room history counts it.
- N opening: normal surface opening; starts BDC at `1`. BED depends on the
  selected opening encounter. Room history counts it.
- Other intros: start BDC at `1` after the prior postboss boundary and count on
  leave. BED is usually `0`, unless the selected intro encounter counts. Room
  history counts them.
- Normal route body: advances by selected room BDC cost, selected encounter BED
  cost, and selected room-history cost.
- Story/fountain/shop: advances BDC like a room. BED is usually `0`. Room
  history counts them.
- Miniboss: advances BDC like a room. BED depends on the selected miniboss
  encounter. Room history counts it.
- Preboss: advances BDC like a room. BED is usually `0`. Room history counts
  it.
- Boss: advances BDC and room history as a room. BED depends on the boss
  encounter, but is usually not route-eligibility relevant.
- Postboss: marks the boundary for the next biome. BED is usually `0`. Room
  history counts it.

Postboss rooms should remain in the timeline for run-history spacing and future
Dream Dive completeness, but they should be treated as biome-boundary entries
rather than ordinary previous-biome body rows.

## Intro And Opening Notes

- F opening is special because it explicitly sets `BiomeDepthCache = 0`.
- Non-F intros normally enter at BDC `1` because the previous postboss room has
  `NextRoomSet`.
- N opening is not F-special. It is a first-biome surface opening with normal
  boundary/start behavior.
- Intro rooms should not be assumed to have BED cost `0` globally. Use the
  selected encounter's `CountsForRoomEncounterDepth` behavior.
- Dream Dive may reuse biome intros differently. Keep intro/opening behavior
  declarative so Dream Dive can add its own route-start overrides later.

## Multi-Encounter Rooms

Multi-encounter rooms choose their encounter slots while the room object is
created. Counter and spacing state does not advance between those slots during
selection.

For example, O ship rooms have an intro/pre-spawn encounter slot, then one
required post-intro encounter slot, then one optional post-intro encounter slot.
Field NPCs such as Icarus can be eligible in either post-intro slot if they are
in that slot's legal encounter set, but their own room-history or BDC
requirements do not become valid between slot 1 and slot 2 inside the same room.

If a field NPC is invalid for the first post-intro slot because of BDC or
room-history spacing, it is also invalid for the optional second slot in that
same room.

## Practical Modeling Rules

- Advance BED and run encounter depth at room-entry/start-encounter phase.
- Apply current reward state before evaluating downstream reward legality.
- Evaluate next-room BDC requirements before committing the current room's BDC
  cost.
- Evaluate room-history spacing before committing the current room's
  room-history cost.
- Commit BDC and room-history costs together in the leave phase.
- Keep declarations in vanilla language. Do not pre-shift BDC windows to match
  UI row numbers.
- If a rule is read from BED, model it as BED. If it is read from BDC, model it
  as BDC. If it is read from room history / `SumPrevRooms`, model it on
  `roomHistoryOrdinal`.
