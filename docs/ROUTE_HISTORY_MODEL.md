# Route History Model

This document describes the planned replacement path for the current route
context streaming model. The existing production route machinery remains the
source of truth until individual consumers are explicitly ported.

## Goal

Build a route interpretation layer that turns selected user choices plus biome
declaration facts into a shared history ledger. Query, validation, reward bag
simulation, NPC targeting, feature targeting, and runtime planning can then read
the same ordered facts instead of rebuilding separate route contexts.

The intended flow is:

```text
biome declarations + selected row snapshots
  -> route history builder
  -> route history ledger + indexes
  -> query API
  -> validators / UI markers / execution plan / runtime hooks
```

## Ownership

### Biome Declarations

Biome declarations own game-domain facts:

- role and option definitions
- room keys and variant keys
- biome depth cache costs
- biome encounter depth costs
- room history costs
- availability windows
- force metadata
- topology windows and topology rules
- reward surfaces, stores, offer counts, timing rules
- side-room declarations and encounter classes
- fixed timeline entries such as boss and post-boss rooms

Declarations should remain the place where the game model is authored.

### Templates

Templates own presentation and storage only. They render controls, store user
selections, and emit a dumb selected-row snapshot for the new route history
system.

Templates should not resolve route-wide facts for the new system:

- no validation state
- no invalid rows
- no computed depth counters
- no resolved reward items
- no interpreted topology
- no resolved reward surfaces

The old `buildSnapshot()` can keep its current production behavior during the
migration. The new selected-row snapshot is a parallel contract.

### Route History Builder

The builder owns interpretation. It consumes selected snapshots and biome
declarations, then emits common history entries.

The builder is responsible for:

- walking route biomes in route order
- resolving selected role and option keys against the biome declaration
- emitting declaration-owned fixed timeline facts that are not user-adjustable
- applying adapter-specific route structure
- computing biome depth cache and biome encounter depth
- computing run-level encounter depth and route spacing axes
- expanding generated topology facts
- emitting room, reward, NPC, feature, and topology events as the system grows

The builder should not become a validator with UI policy. It should produce
facts and attach enough metadata for query and validators to reason about those
facts.

### History

History is an append-only ledger plus indexes. It stores facts for the current
route build.

Callers should not scan raw history entries directly outside the history/query
subsystem. If a consumer needs information, add or extend a query.

### Query

Query is the public read API over history. Validators and planning code should
ask query for game-like facts instead of reading history tables directly.

Queries should be indexed where possible. If a query must scan, it should scan a
narrow indexed bucket, not the full route ledger.

## Selected Row Snapshot Contract

The selected-row snapshot records user choices, not interpreted facts.

```lua
{
    schema = "selectedRows.v1",
    routeKey = "Underworld", -- optional during isolated tests
    controlName = "RouteF",
    biomeKey = "F",
    adapter = "fixedLinear",
    rows = {
        {
            rowIndex = 5,
            roleKey = "Combat",
            optionKey = "F_Combat06",
            variantKey = "",
            topology = {
                siblings = {
                    [1] = {
                        structureKey = "Combat",
                    },
                },
                sideRooms = {},
                encounter = {},
            },
            rewards = {
                row = {
                    values = {},
                    loot = {},
                },
                sibling = {
                    [1] = {
                        rewardClassKey = "Major",
                    },
                },
                side = {},
                encounter = {},
            },
        },
    },
}
```

Rules:

- Preserve blanks. Missing required choices are validated by the new route layer.
- Use keys, not resolved declaration objects.
- Do not include labels; derive labels from declarations when needed.
- Do not include computed counters.
- Do not include `valid`, `invalidRows`, `roomTopology`, or `rewardItems`.
- Fixed structural rows may still emit their fixed role or option keys. That is
  selected/default slot state, not route interpretation.
- The snapshot does not need to contain every history entry. Non-adjustable
  declaration timeline facts are emitted by the builder from biome declarations.

## Builder Inputs

The route history builder needs both selected snapshots and biome declarations:

```lua
historyBuilder.build({
    route = route,
    biomeLookup = catalog.lookup,
    snapshotForBiome = function(routeKey, biomeKey)
        return selectedRowsSnapshot
    end,
})
```

The selected snapshot says what the user selected or what a fixed control slot
stores. The biome declaration says what those keys mean and which additional
fixed timeline entries must be emitted.

Example:

- Snapshot: `roleKey = "Miniboss"`, `optionKey = "P_MiniBoss02"`
- Declaration: `P_MiniBoss02` has encounter-depth cost, availability, force
  metadata, reward surface, and room key.
- Builder: combines both into history facts.

Example declaration-owned timeline facts:

- F/G/P/Q fixed-linear biomes emit configured route rows from the snapshot.
- The same biomes emit preboss from `slotLayout.special` when it is part of the
  fixed row layout.
- Boss and post-boss entries are emitted from `biome.timeline.afterBiome`.

## Builder Adapters

The builder should be generic at the route level and adapter-specific at the
biome level.

Proposed layout:

```text
src/mods/route/history/
  assembly.lua
  builder.lua
  events.lua
  history.lua
  query.lua
  adapters/
    fixed_linear.lua
    fields_cage.lua
    clockwork_goal.lua
    hub_pylon.lua
    multi_encounter.lua
```

`builder.lua` orchestrates:

- walk route biomes
- retrieve selected snapshot
- retrieve biome declaration
- dispatch by snapshot adapter
- append adapter output to the shared ledger

Adapters interpret selected row keys using biome declaration facts and emit the
common history language.

Adapter examples:

- `fixed_linear`: F/G/P/Q fixed rows, generated siblings, fixed topology windows.
- `fields_cage`: H cage structure, bridge/miniboss/combat cage choices.
- `clockwork_goal`: I goal vs non-goal structure, preboss after goal completion.
- `hub_pylon`: N hub doors, pylon picks, entered side rooms.
- `multi_encounter`: O ship rows, encounter legs, wheel offer counts.

## Common History Events

The event language should stay shared even though builders are adapter-specific.

Initial event kinds:

- `room`: an entered room on the deterministic path.
- `generatedRoom`: a generated but unentered room or sibling when modeled.
- `rewardOffer`: a reward offer generated by a row, shop, side room, wheel, or
  sibling.
- `rewardPick`: a reward the player is modeled as taking or buying.
- `npc`: a planned NPC target.
- `feature`: a planned route feature target.

Additional fields should use game-domain names where possible:

- `biomeKey`
- `rowIndex`
- `roomKey`
- `roleKey`
- `optionKey`
- `sourceKind`
- `sourceIndex`
- `rewardType`
- `rewardStore`
- `timing`
- `biomeDepthCache`
- `biomeEncounterDepth`
- `runEncounterDepth`

## Query Direction

Expected query families:

- `CurrentRun.LootTypeHistory[RewardType]`
- `CurrentRun.LootTypeHistory CountOf gods >= N`
- `CurrentRun.BiomeUseRecord[RewardType]`
- `CurrentRun.EnteredBiomes`
- `CurrentRun.EncounterDepth`
- `CurrentRun.BiomeEncounterDepth`
- `RequiredNotInStore(Name)`
- `RequiredMinRoomsSinceEvent(Event, Count)`
- `SumPrevRooms`-style window checks
- `RequiredMinExits(Count)`

Validators should use query, not raw history.

## Migration Rules

- Keep old production route code intact until a consumer is deliberately ported.
- Build the new history system in `src/mods/route/history/`.
- Add selected-row snapshot emitters one template at a time.
- Do not make templates emit history events directly.
- Do not feed production `buildSnapshot()` output into the history builder.
  That snapshot already speaks interpreted route language and bypasses the
  adapter boundary.
- Do not port validation until the relevant history facts and queries are tested.
- Prefer adding a selected snapshot field over teaching the builder to scrape
  old smart snapshot internals.
- If a builder adapter needs a declaration fact that is only implicit in a
  template, move that fact into the biome declaration first.

## First Implementation Slices

1. Add `selectedRows.v1` snapshot method to one template, starting with
   `FixedLinearRoute`.
2. Add `fixed_linear` builder adapter that consumes selected snapshots plus
   biome declarations and emits room facts.
3. Extend the selected snapshot and adapter to cover fixed-linear sibling
   topology facts.
4. Add reward offer/pick facts for fixed-linear rows.
5. Repeat selected snapshot emission for the other template families.
