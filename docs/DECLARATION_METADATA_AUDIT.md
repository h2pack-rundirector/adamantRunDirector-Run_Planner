# Declaration Metadata Audit

Date: 2026-06-20

This audit covers Run Planner declaration metadata in `src/mods/data/biomes/*.lua`
and the directly exported layout metadata in `src/mods/data/biomes/*_layout.lua`.
It does not remove anything. It only records which fields are production
consumed, which are tests/docs-only, and which look like stale or future-facing
game provenance.

## Audit Method

- Production consumers were traced with `rg` through `src/mods/controls`,
  `src/mods/route`, `src/mods/logic`, and `src/mods/ui.lua`.
- Test-only assertions were treated as evidence that the data exists, not that
  runtime/UI needs it.
- Some metadata is still useful as game provenance, but should be marked as such
  or moved to docs if it is not part of the active control/runtime contract.

## Production-Consumed Metadata

These fields are part of the current active declaration contract.

- Root biome: `key`, `label`, `region`, `adapter`, `timeline`,
  `featurePolicies`, `biomeRules`, `roles`.
- `slotLayout`: `routeRowLabelPrefix`, `biomeDepthCacheStart`,
  `defaultFixedBiomeDepthCacheCost`, `routeBiomeDepthCacheCost`,
  `routeStartOrdinal`, `routeEndOrdinal`, `entry`, `special`,
  `fixedBeforeRoute`, `fixedAfterRoute`, `fixedBeforeHub`, `fixedAfterHub`,
  `fixedAfterGoals`.
- Fixed/special slots: `kind`, `key`, `label`, `isBiomeEntry`, `roomKey`,
  `roomOptions`, `reward`, `features`, `tags`, `locked`, `branches`,
  `branchKey`, `biomeDepthCache`, `biomeDepthCacheCost`,
  `biomeEncounterDepthCost`, `roomHistoryCost`.
- Roles and options: `key`, `label`, `mapOptions`, `roomOptions`, `reward`,
  `features`, `tags`, `exitCount`, `biomeDepthCacheCost`,
  `biomeEncounterDepthCost`, `roomHistoryCost`, `availability`, `routeRules`,
  `routeRequirements`, `reserve`, `requiresConcreteOption`,
  `countsGoalReward`, `countsNonGoalReward`, `requiresExistingIExit`,
  `supportsExtensionChoice`, `encounterPolicy`, `cageRewardPolicy`,
  `sideRooms`, `maxCageRewards`, `hubDoorId`, `sideDoors`, `doorId`.
- Route features: row/side-room `features` plus biome `featurePolicies`.
- H Fields active policy: `fields.cageRewardPolicy`, role
  `cageRewardPolicy`, cage `countControl`, `cageRewardCount`,
  `requiresAllOfferedRoomsSupport`.
- O Thessaly active policy: `combatEncounterPolicy`, its `countControl`,
  variant legs, and role `encounterPolicy`.
- Q Summit active policy: `forcedDepthOptions`.
- N Ephyra active policy: `hub.offerPolicy`, `hub.sideRoomAvailability.modes`,
  `hub.pylonRoomHistoryCost`, combat/miniboss/story room lists, side doors, and
  side-door rewards embedded on each side door.
- I Tartarus active policy: `clockwork.requiredGoalRewards`,
  `clockwork.forcedFirstRouteRole`, `clockwork.extensionRewardBudget`,
  `clockwork.extensionRoom`, and `clockwork.goalRoom`.

## Tests/Docs-Only Or Likely Dead

These fields have no production consumers in the current code. They are either
duplicates of active metadata, stale scaffolding, or game-provenance notes that
could move to docs.

### N Ephyra

- `hub.requiredPylons`
  - Current consumers: tests/docs only.
  - Active equivalent: `slotLayout.routeEndOrdinal = 6` controls generated
    pylon rows. Kept for now as semantic hub provenance.

- `hub.doorSelectionFunction`
  - Current consumers: tests/docs only.
  - Looks like game provenance for future runtime door forcing.

- `hub.doorTypes`
  - Current consumers: tests/docs only.
  - Looks like game provenance for future runtime door filtering.

- `hub.availableDoorCount`
  - Current consumers: tests/docs only.
  - Looks like vanilla layout documentation. No current UI/runtime behavior uses
    the min/max.

- `hub.pylonObjective`
  - Current consumers: tests/docs only.
  - Looks like game provenance. Current route logic does not read objective
    names.

- `hub.minibossAvailability`
  - Current consumers: tests/docs only.
  - Active equivalent: the `Miniboss` role options and shared route rules. If N
    needs special miniboss semantics, the adapter should consume this explicitly;
    otherwise it is stale.

- `hub.sideRoomAvailability.identity`
  - Current consumers: tests/docs only.
  - Active equivalent: side room identity is implicit in parent combat room plus
    side door index. Runtime/UI does not read the declared identity string.

- `hub.sideRoomAvailability.default`
  - Current consumers: tests/docs only.
  - Active equivalent: the side-room table row default is hardcoded by
    `HubPylonRoute` as the vanilla mode. If default should be declarative, the
    storage builder needs to consume it.

- `hub.combatRoomsByKey`, `hub.minibossRoomsByKey`, `hub.storyRoomsByKey`
  - Current consumers: tests only.
  - Active equivalent: UI/runtime use the list fields and embedded selected
    option data.

- `hub.hubDoorRooms`
  - Current consumers: tests only.
  - Looks like generated provenance for all hub doors. Current runtime uses the
    selected option's `hubDoorId` and `sideDoors`, not this flattened list.

- `hub.subroomRewardStores`
  - Current consumers: tests only.
  - Active equivalent: side-door entries already contain `reward` surfaces.
    Exporting the raw store lookup is redundant unless future validation needs
    it.

### H Fields

- `fields.routeCount`
  - Current consumers: tests/docs only.
  - Active equivalent: `slotLayout.routeEndOrdinal = 4` defines the four route
    body picks. If route count is needed as semantic documentation, it should be
    documented rather than attached to runtime declarations.

- `fields.routeCount.counter`, `requiredBeforePreboss`, `countedRooms`
  - Current consumers: tests/docs only.
  - Looks like game provenance for vanilla Fields preboss gating. No current
    adapter logic reads it.

- `fields.combatRoomsByKey`, `fields.minibossRoomsByKey`
  - Current consumers: tests only.
  - Active equivalent: role option lists and selected option objects.

- `fields.bridge`
  - Current consumers: tests only.
  - Active equivalent: the active Bridge role uses `layout.bridgeRoom` and
    `rewards.fieldsBridge()`. The richer `layout.bridge` table is not consumed.

- `layout.bridge.defaultPick`, `rewardModes`, reward-mode `forcedReward`,
  reward-mode `encounter`, reward-mode special availability
  (`requiresPriorFieldsBoss`, `requiresPriorFieldsBridgeRooms`)
  - Current consumers: tests only through `fields.bridge`.
  - Looks like a more detailed future bridge model that the current Bridge role
    does not use.

- `layout.cageRewardPolicy.maxDoorDepthChanceTable`,
  `maxDoorCageCeiling`, `locationModel`, `maxDoorChance`, `ceilingCheck`
  - Current consumers: tests/docs only.
  - Active cage UI only uses count-control options and room `maxCageRewards`.
    These look like vanilla probability/provenance metadata.

### I Tartarus

- `clockwork.extensionChoice.default`
  - Current consumers: tests/docs only.
  - The active behavior uses `requiresPreviousRoomSupportsExtensionChoice`.
    There is no current storage default derived from this field.

### Generic Layout Provenance

- Room option `encounter`
  - Current consumers: tests/docs only.
  - Present on H/N minibosses and bridge modes. Current room routing forces room
    keys, not encounter names. Keep only if planned runtime encounter forcing
    will consume it.

- Exported `combatRoomsByKey` from several layout files
  - Current consumers: usually the layout module itself while deriving lists
    such as trial combat rooms, plus tests. Once exported, production generally
    consumes lists, not the lookup tables.
  - Recommendation: keep local indexes inside layout files when needed for
    derivation, but avoid re-exporting unless runtime/UI consumes them.

## Probably Keep Even If They Look Like Metadata

These fields may look descriptive, but current behavior depends on them.

- `maxCreationsThisRun` and `maxAppearancesThisBiome`
  - Consumed through `availability.optionCap(...)` and row validation.

- `exitCount`
  - Consumed by route requirements such as midshop/devotion previous-room exit
    checks and by Tartarus extension support.

- `supportsExtensionChoice`
  - Consumed by the Clockwork Goal adapter when deciding whether later extension
    rows remain meaningful after goals are satisfied.

- `maxCageRewards`
  - Consumed by Fields cage reward-count UI/validation.

- `hubDoorId`, `sideDoors`, side-door `doorId`
  - Consumed by Ephyra side-room UI/runtime snapshots.

- `featurePolicies`
  - Consumed by route context feature target filtering.

- `biomeRules`
  - Consumed by row validation, currently for the Thessaly story/shop deadline.

- `vanillaDepthHints`
  - Consumed indirectly by the Q fixed-linear adapter through
    `forcedDepthOptions` preparation.

## Recommended Follow-Up Order

1. Decide whether the remaining N semantic provenance should be kept or moved
   to docs:
   - `N.hub.requiredPylons`
   - `N.hub.doorSelectionFunction`
   - `N.hub.doorTypes`
   - `N.hub.availableDoorCount`
   - `N.hub.pylonObjective`

2. Decide whether other N hub game-provenance fields should be docs-only or future
   runtime:
   - `minibossAvailability`, side-room `identity/default`.

3. Decide whether H bridge/probability metadata belongs in the active model:
   - If yes, wire it into the Fields template.
   - If no, move it to docs or delete it with tests.

4. Remove exported lookup tables when they are only test conveniences:
   - `combatRoomsByKey`, `minibossRoomsByKey`, `storyRoomsByKey`,
     `hubDoorRooms`, `subroomRewardStores`, `fields.bridge`.

5. After cleanup, update `tests/TestData.lua` so it asserts active contracts
   instead of preserving stale metadata.
