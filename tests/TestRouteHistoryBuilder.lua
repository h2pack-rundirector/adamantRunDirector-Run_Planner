local lu = require("luaunit")
local h = require("tests.support.control_harness")

local historySystem = h.withTestImport(function()
    return h.testImport("mods/route/history/assembly.lua").create()
end)
local routeHistory = historySystem.history
local historyBuilder = historySystem.builder

-- luacheck: globals TestRunPlannerRouteHistoryBuilder
TestRunPlannerRouteHistoryBuilder = {}

local function roomEvents(history)
    return routeHistory.byKind(history, "room")
end

local function fullFErebusRows()
    return {
        {
            OptionKey = "F_Opening01",
            Reward1Key = "SpellDrop",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat01",
            Reward1Key = "Major",
            Reward2Key = "MaxHealthDrop",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat02",
            Reward1Key = "Major",
            Reward2Key = "MaxManaDrop",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat03",
            Reward1Key = "Major",
            Reward2Key = "RoomMoneyDrop",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat04",
            SiblingStructureKey = "F_Story01",
            Reward1Key = "Major",
            Reward2Key = "StackUpgrade",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat05",
            SiblingStructureKey = "Combat",
            Reward1Key = "Major",
            Reward2Key = "Boon",
            Reward3Key = "ZeusUpgrade",
            SiblingRewardClassKey = "Major",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat06",
            Reward1Key = "Major",
            Reward2Key = "MaxHealthDrop",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat07",
            Reward1Key = "Major",
            Reward2Key = "MaxManaDrop",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat08",
            Reward1Key = "Major",
            Reward2Key = "RoomMoneyDrop",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat09",
            Reward1Key = "Major",
            Reward2Key = "StackUpgrade",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat10",
            Reward1Key = "Major",
            Reward2Key = "MaxHealthDrop",
        },
        {
            PrebossBranchKey = "FreeReward",
            Reward4Key = "Boon",
            Reward5Key = "ZeusUpgrade",
        },
    }
end

local function fullHFieldsRows()
    return {
        {},
        {
            RoleKey = "Combat",
            OptionKey = "H_Combat04",
            VariantKey = "ThreeRewards",
            Reward1Key = "Boon",
            Reward1LootKey = "PoseidonUpgrade",
            Reward2Key = "HermesUpgrade",
            Reward3Key = "StackUpgrade",
        },
        {
            RoleKey = "Combat",
            OptionKey = "H_Combat09",
            VariantKey = "TwoRewards",
            SiblingStructureKey = "CombatCage2",
            Reward1Key = "Boon",
            Reward1LootKey = "HestiaUpgrade",
            Reward2Key = "WeaponUpgrade",
        },
        {
            RoleKey = "Bridge",
            SiblingStructureKey = "H_MiniBoss02",
        },
        {
            RoleKey = "Miniboss",
            OptionKey = "H_MiniBoss01",
            SiblingStructureKey = "CombatCage2",
            Reward1Key = "ZeusUpgrade",
        },
        {
            PrebossBranchKey = "Shop",
            Reward1Key = "RandomLoot",
            Reward1LootKey = "ApolloUpgrade",
            Reward1StateKey = "Bought",
        },
    }
end

local function oCombatRow(optionKey, variantKey)
    return {
        RoleKey = "Combat",
        OptionKey = optionKey,
        VariantKey = variantKey or "TwoCombats",
    }
end

local function fullOThessalyRows()
    return {
        {},
        oCombatRow("O_Combat01"),
        oCombatRow("O_Combat02", "ThreeCombats"),
        {
            RoleKey = "Story",
            OptionKey = "O_Story01",
        },
        {
            RoleKey = "Fountain",
            OptionKey = "O_Reprieve01",
            Reward1Key = "Minor",
            Reward4Key = "RoomMoneyDrop",
        },
        {
            RoleKey = "Miniboss",
            OptionKey = "O_MiniBoss02",
            Reward1Key = "ZeusUpgrade",
        },
        oCombatRow("O_Combat05"),
        {
            Reward1Key = "RandomLoot",
            Reward1LootKey = "ApolloUpgrade",
            Reward1StateKey = "Bought",
        },
    }
end

local function fullOThessalyEncounterRewardRows()
    return {
        {
            WheelOffer1Key = "OneChoice",
            Reward1Key = "Major",
            Reward2Key = "MaxHealthDrop",
        },
        {},
        {
            WheelOffer1Key = "TwoChoices",
            Reward1Key = "Major",
            Reward2Key = "Boon",
            Reward3Key = "ApolloUpgrade",
        },
        {
            WheelOffer2Key = "TwoChoices",
            Reward1Key = "Minor",
            Reward4Key = "RoomMoneyDrop",
        },
        {},
        {},
        {},
        {},
        {},
        {},
        {
            WheelOffer1Key = "OneChoice",
            Reward1Key = "Major",
            Reward2Key = "MaxManaDrop",
        },
    }
end

local function withShopOnlyPreboss(biome)
    local copy = {}
    for key, value in pairs(biome) do
        copy[key] = value
    end
    copy.slotLayout = {}
    for key, value in pairs(biome.slotLayout) do
        copy.slotLayout[key] = value
    end
    copy.slotLayout.special = {}
    for ordinal, special in pairs(biome.slotLayout.special or {}) do
        local specialCopy = {}
        for key, value in pairs(special) do
            specialCopy[key] = value
        end
        copy.slotLayout.special[ordinal] = specialCopy
    end
    copy.slotLayout.special[11].reward = {
        kind = "shop",
        shopProfile = "WorldShop",
    }
    return copy
end

function TestRunPlannerRouteHistoryBuilder.testFixedLinearEmitsDumbSelectedRowsSnapshot()
    local catalog = h.loadCatalog()
    local template = h.loadFixedLinearTemplate()
    local instance = template.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local control = template.createRuntime(h.routeFields({
        {
            OptionKey = "F_Opening01",
            Reward1Key = "SpellDrop",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat02",
            SiblingStructureKey = "Combat",
            Reward1Key = "Major",
            Reward2Key = "MaxHealthDrop",
            SiblingRewardClassKey = "Major",
        },
    }), instance)

    local snapshot = control:buildSelectedRowsSnapshot()

    lu.assertEquals(snapshot.schema, "selectedRows.v1")
    lu.assertEquals(snapshot.controlName, "RouteF")
    lu.assertEquals(snapshot.biomeKey, "F")
    lu.assertEquals(snapshot.adapter, "fixedLinear")
    lu.assertNil(snapshot.rows[1].valid)
    lu.assertNil(snapshot.rows[1].roomTopology)
    lu.assertNil(snapshot.rows[1].rewardItems)
    lu.assertEquals(snapshot.rows[1].roleKey, "Opening")
    lu.assertEquals(snapshot.rows[1].optionKey, "F_Opening01")
    lu.assertEquals(snapshot.rows[2].roleKey, "Combat")
    lu.assertEquals(snapshot.rows[2].optionKey, "F_Combat02")
    lu.assertEquals(snapshot.rows[2].topology.siblings[1].structureKey, "Combat")
    lu.assertEquals(snapshot.rows[2].rewards.row.values[1], "Major")
    lu.assertEquals(snapshot.rows[2].rewards.row.values[2], "MaxHealthDrop")
    lu.assertEquals(snapshot.rows[2].rewards.row.states[1], "")
    lu.assertEquals(snapshot.rows[2].rewards.sibling[1].rewardClassKey, "Major")
end

function TestRunPlannerRouteHistoryBuilder.testFixedLinearBuilderResolvesRoomFactsFromDeclarations()
    local catalog = h.loadCatalog()
    local template = h.loadFixedLinearTemplate()
    local instance = template.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local control = template.createRuntime(h.routeFields({
        {
            OptionKey = "F_Opening01",
            Reward1Key = "SpellDrop",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat02",
            Reward1Key = "Major",
            Reward2Key = "MaxHealthDrop",
        },
    }), instance)
    local selectedSnapshot = control:buildSelectedRowsSnapshot()

    local history = historyBuilder.build({
        route = catalog.routes.lookup.Underworld,
        biomeLookup = catalog.lookup,
        snapshotForBiome = function(_, biomeKey)
            if biomeKey == "F" then
                return selectedSnapshot
            end
            return nil
        end,
    })

    local rooms = roomEvents(history)
    lu.assertEquals(#rooms, 4)
    lu.assertEquals(rooms[1].eventKey, "F_Opening01")
    lu.assertEquals(rooms[1].roleKey, "Opening")
    lu.assertEquals(rooms[1].routeOrdinal, 0)
    lu.assertEquals(rooms[1].roomHistoryOrdinal, 1)
    lu.assertEquals(rooms[1].runDepthCache, 2)
    lu.assertEquals(rooms[1].biomeDepthCache, 0)
    lu.assertEquals(rooms[1].biomeEncounterDepth, 1)
    lu.assertEquals(rooms[2].eventKey, "F_Combat02")
    lu.assertEquals(rooms[2].roleKey, "Combat")
    lu.assertEquals(rooms[2].routeOrdinal, 1)
    lu.assertEquals(rooms[2].roomHistoryOrdinal, 2)
    lu.assertEquals(rooms[2].runDepthCache, 3)
    lu.assertEquals(rooms[2].biomeDepthCache, 0)
    lu.assertEquals(rooms[2].biomeEncounterDepth, 2)
    lu.assertEquals(rooms[2].runEncounterDepth, 2)
    lu.assertEquals(rooms[3].eventKey, "Boss")
    lu.assertEquals(rooms[3].sourceKind, "afterBiome")
    lu.assertEquals(rooms[4].eventKey, "F_PostBoss01")
    lu.assertEquals(rooms[4].sourceKind, "afterBiome")
end

function TestRunPlannerRouteHistoryBuilder.testFixedLinearBuildsFullDeclaredFErebusSpine()
    local catalog = h.loadCatalog()
    local template = h.loadFixedLinearTemplate()
    local instance = template.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local control = template.createRuntime(h.routeFields(fullFErebusRows()), instance)
    local selectedSnapshot = control:buildSelectedRowsSnapshot()

    local history = historyBuilder.build({
        route = catalog.routes.lookup.Underworld,
        biomeLookup = catalog.lookup,
        snapshotForBiome = function(_, biomeKey)
            if biomeKey == "F" then
                return selectedSnapshot
            end
            return nil
        end,
    })

    local rooms = roomEvents(history)
    lu.assertEquals(#rooms, 14)
    lu.assertEquals(rooms[1].eventKey, "F_Opening01")
    lu.assertEquals(rooms[1].roleKey, "Opening")
    lu.assertEquals(rooms[2].eventKey, "F_Combat01")
    lu.assertEquals(rooms[11].eventKey, "F_Combat10")
    lu.assertEquals(rooms[12].eventKey, "Preboss")
    lu.assertEquals(rooms[12].sourceKind, "row")
    lu.assertEquals(rooms[12].roleKey, "Preboss")
    lu.assertEquals(rooms[13].eventKey, "Boss")
    lu.assertEquals(rooms[13].sourceKind, "afterBiome")
    lu.assertEquals(rooms[14].eventKey, "F_PostBoss01")
    lu.assertEquals(rooms[14].sourceKind, "afterBiome")
    lu.assertEquals(rooms[14].roomHistoryOrdinal, 14)
end

function TestRunPlannerRouteHistoryBuilder.testFixedLinearRoomEntriesCarryNextChoiceTopology()
    local catalog = h.loadCatalog()
    local template = h.loadFixedLinearTemplate()
    local instance = template.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local control = template.createRuntime(h.routeFields(fullFErebusRows()), instance)
    local selectedSnapshot = control:buildSelectedRowsSnapshot()

    local history = historyBuilder.build({
        route = catalog.routes.lookup.Underworld,
        biomeLookup = catalog.lookup,
        snapshotForBiome = function(_, biomeKey)
            if biomeKey == "F" then
                return selectedSnapshot
            end
            return nil
        end,
    })

    local rooms = roomEvents(history)
    lu.assertEquals(rooms[1].topology.kind, "fixedLinearNextChoice")
    lu.assertEquals(rooms[1].topology.exits[1].branch, "picked")
    lu.assertEquals(rooms[1].topology.exits[1].roomKey, "F_Combat01")
    lu.assertEquals(rooms[1].topology.exits[1].reward.kind, "majorMinor")
    lu.assertEquals(rooms[1].topology.exits[1].reward.rewardStore, "RunProgress")
    lu.assertEquals(rooms[1].topology.exits[1].reward.rewardType, "MaxHealthDrop")

    lu.assertEquals(rooms[5].topology.exits[1].branch, "picked")
    lu.assertEquals(rooms[5].topology.exits[1].roomKey, "F_Combat05")
    lu.assertEquals(rooms[5].topology.exits[2].branch, "sibling")
    lu.assertEquals(rooms[5].topology.exits[2].structure, "Story")
    lu.assertEquals(rooms[5].topology.exits[2].roomKey, "F_Story01")
    lu.assertNil(rooms[5].topology.exits[2].reward)

    lu.assertEquals(rooms[6].topology.exits[1].branch, "picked")
    lu.assertEquals(rooms[6].topology.exits[1].roomKey, "F_Combat06")
    lu.assertEquals(rooms[6].topology.exits[1].reward.rewardType, "MaxHealthDrop")
    lu.assertEquals(rooms[6].topology.exits[2].branch, "sibling")
    lu.assertEquals(rooms[6].topology.exits[2].structure, "Combat")
    lu.assertEquals(rooms[6].topology.exits[2].reward.rewardClass, "Major")
    lu.assertEquals(rooms[6].topology.exits[2].reward.rewardStore, "RunProgress")
end

function TestRunPlannerRouteHistoryBuilder.testFixedLinearPrebossBranchesGeneratedTopologyAndOutcome()
    local catalog = h.loadCatalog()
    local template = h.loadFixedLinearTemplate()
    local instance = template.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local control = template.createRuntime(h.routeFields(fullFErebusRows()), instance)
    local selectedSnapshot = control:buildSelectedRowsSnapshot()

    local history = historyBuilder.build({
        route = catalog.routes.lookup.Underworld,
        biomeLookup = catalog.lookup,
        snapshotForBiome = function(_, biomeKey)
            if biomeKey == "F" then
                return selectedSnapshot
            end
            return nil
        end,
    })

    local rooms = roomEvents(history)
    local prePreboss = rooms[11]
    lu.assertEquals(prePreboss.eventKey, "F_Combat10")
    lu.assertEquals(#prePreboss.topology.exits, 2)
    lu.assertEquals(prePreboss.topology.exits[1].branch, "sibling")
    lu.assertEquals(prePreboss.topology.exits[1].structure, "PrebossShop")
    lu.assertEquals(prePreboss.topology.exits[1].rewardBranchKey, "Shop")
    lu.assertEquals(prePreboss.topology.exits[1].reward.kind, "shop")
    lu.assertEquals(prePreboss.topology.exits[1].reward.shopProfile, "WorldShop")
    lu.assertEquals(prePreboss.topology.exits[2].branch, "picked")
    lu.assertEquals(prePreboss.topology.exits[2].structure, "PrebossFreeReward")
    lu.assertEquals(prePreboss.topology.exits[2].rewardBranchKey, "FreeReward")
    lu.assertEquals(prePreboss.topology.exits[2].reward.kind, "roomStore")
    lu.assertEquals(prePreboss.topology.exits[2].reward.rewardStore, "RunProgress")
    lu.assertEquals(prePreboss.topology.exits[2].reward.ineligibleRewardTypes[1], "Devotion")

    local preboss = rooms[12]
    lu.assertEquals(preboss.eventKey, "Preboss")
    lu.assertEquals(preboss.reward.kind, "preboss")
    lu.assertEquals(preboss.reward.branch, "FreeReward")
    lu.assertEquals(preboss.reward.reward.rewardStore, "RunProgress")
    lu.assertEquals(preboss.reward.reward.rewardType, "Boon")
    lu.assertEquals(preboss.reward.reward.boonSource, "ZeusUpgrade")
end

function TestRunPlannerRouteHistoryBuilder.testFixedLinearPrebossShopOnlyDoesNotGenerateBranches()
    local catalog = h.loadCatalog()
    local template = h.loadFixedLinearTemplate()
    local biome = withShopOnlyPreboss(catalog.lookup.F)
    local instance = template.prepare({
        name = "RouteF",
        biome = biome,
    })
    local control = template.createRuntime(h.routeFields(fullFErebusRows()), instance)
    local selectedSnapshot = control:buildSelectedRowsSnapshot()

    local history = historyBuilder.build({
        route = catalog.routes.lookup.Underworld,
        biomeLookup = {
            F = biome,
        },
        snapshotForBiome = function(_, biomeKey)
            if biomeKey == "F" then
                return selectedSnapshot
            end
            return nil
        end,
    })

    local rooms = roomEvents(history)
    local prePreboss = rooms[11]
    lu.assertEquals(#prePreboss.topology.exits, 1)
    lu.assertEquals(prePreboss.topology.exits[1].branch, "picked")
    lu.assertEquals(prePreboss.topology.exits[1].structure, "Preboss")
    lu.assertNil(prePreboss.topology.exits[1].rewardBranchKey)
    lu.assertEquals(prePreboss.topology.exits[1].reward.kind, "shop")
    lu.assertEquals(prePreboss.topology.exits[1].reward.shopProfile, "WorldShop")
end

function TestRunPlannerRouteHistoryBuilder.testFieldsCageBuildsFieldsSpine()
    local catalog = h.loadCatalog()
    local template = h.loadFieldsCageTemplate()
    local instance = template.prepare({
        name = "RouteH",
        biome = catalog.lookup.H,
    })
    local control = template.createRuntime(h.routeFields(fullHFieldsRows()), instance)
    local selectedSnapshot = control:buildSelectedRowsSnapshot()

    local history = historyBuilder.build({
        route = {
            key = "Underworld",
            biomes = { "H" },
        },
        biomeLookup = catalog.lookup,
        snapshotForBiome = function(_, biomeKey)
            if biomeKey == "H" then
                return selectedSnapshot
            end
            return nil
        end,
    })

    local rooms = roomEvents(history)
    lu.assertEquals(#rooms, 8)
    lu.assertEquals(rooms[1].eventKey, "H_Intro")
    lu.assertEquals(rooms[1].roleKey, "Intro")
    lu.assertEquals(rooms[1].routeOrdinal, nil)
    lu.assertEquals(rooms[1].roomHistoryOrdinal, 1)
    lu.assertEquals(rooms[1].biomeDepthCache, 1)
    lu.assertEquals(rooms[1].biomeEncounterDepth, 1)
    lu.assertEquals(rooms[2].eventKey, "H_Combat04")
    lu.assertEquals(rooms[2].roleKey, "Combat")
    lu.assertEquals(rooms[2].routeOrdinal, 1)
    lu.assertEquals(rooms[2].variantKey, "ThreeRewards")
    lu.assertEquals(rooms[3].eventKey, "H_Combat09")
    lu.assertEquals(rooms[4].eventKey, "H_Bridge01")
    lu.assertEquals(rooms[5].eventKey, "H_MiniBoss01")
    lu.assertEquals(rooms[6].eventKey, "Preboss")
    lu.assertEquals(rooms[7].eventKey, "Boss")
    lu.assertEquals(rooms[7].sourceKind, "afterBiome")
    lu.assertEquals(rooms[8].eventKey, "H_PostBoss01")
    lu.assertEquals(rooms[8].sourceKind, "afterBiome")
end

function TestRunPlannerRouteHistoryBuilder.testFieldsCageEntriesCarryTopologyAndRewards()
    local catalog = h.loadCatalog()
    local template = h.loadFieldsCageTemplate()
    local instance = template.prepare({
        name = "RouteH",
        biome = catalog.lookup.H,
    })
    local control = template.createRuntime(h.routeFields(fullHFieldsRows()), instance)
    local selectedSnapshot = control:buildSelectedRowsSnapshot()

    local history = historyBuilder.build({
        route = {
            key = "Underworld",
            biomes = { "H" },
        },
        biomeLookup = catalog.lookup,
        snapshotForBiome = function(_, biomeKey)
            if biomeKey == "H" then
                return selectedSnapshot
            end
            return nil
        end,
    })

    local rooms = roomEvents(history)
    lu.assertEquals(rooms[2].topology.kind, "fieldsChoice")
    lu.assertEquals(rooms[2].topology.selected.structure, "CombatCage3")
    lu.assertEquals(rooms[2].topology.selected.offerCount, 3)
    lu.assertEquals(rooms[2].topology.sibling.structure, "CombatCage3")
    lu.assertEquals(rooms[2].topology.sibling.offerCount, 3)
    lu.assertEquals(rooms[2].reward.kind, "fieldsCages")
    lu.assertEquals(rooms[2].reward.sourceCount, 3)
    lu.assertEquals(rooms[2].reward.picks[1].rewardType, "Boon")
    lu.assertEquals(rooms[2].reward.picks[1].boonSource, "PoseidonUpgrade")
    lu.assertEquals(rooms[2].reward.picks[2].rewardType, "HermesUpgrade")
    lu.assertEquals(rooms[2].reward.picks[3].rewardType, "StackUpgrade")

    lu.assertEquals(rooms[4].topology.selected.structure, "Bridge")
    lu.assertEquals(rooms[4].topology.sibling.structure, "Miniboss")
    lu.assertEquals(rooms[4].topology.sibling.roomKey, "H_MiniBoss02")
    lu.assertEquals(rooms[4].topology.sibling.eligibleRewardTypes[1], "Boon")

    lu.assertEquals(rooms[5].topology.selected.structure, "Miniboss")
    lu.assertEquals(rooms[5].topology.selected.roomKey, "H_MiniBoss01")
    lu.assertEquals(rooms[5].reward.kind, "roomStore")
    lu.assertEquals(rooms[5].reward.rewardType, "Boon")
    lu.assertEquals(rooms[5].reward.boonSource, "ZeusUpgrade")

    lu.assertEquals(rooms[6].reward.kind, "preboss")
    lu.assertEquals(rooms[6].reward.branch, "Shop")
    lu.assertEquals(rooms[6].reward.offers[1].rewardType, "RandomLoot")
    lu.assertEquals(rooms[6].reward.offers[1].boonSource, "ApolloUpgrade")
    lu.assertTrue(rooms[6].reward.offers[1].bought)
end

function TestRunPlannerRouteHistoryBuilder.testMultiEncounterFixedBuildsThessalySpine()
    local catalog = h.loadCatalog()
    local template = h.loadMultiEncounterTemplate()
    local instance = template.prepare({
        name = "RouteO",
        biome = catalog.lookup.O,
    })
    local control = template.createRuntime(
        h.routeFields(fullOThessalyRows(), nil, nil, fullOThessalyEncounterRewardRows()),
        instance
    )
    local selectedSnapshot = control:buildSelectedRowsSnapshot()

    local history = historyBuilder.build({
        route = {
            key = "Surface",
            biomes = { "O" },
        },
        biomeLookup = catalog.lookup,
        snapshotForBiome = function(_, biomeKey)
            if biomeKey == "O" then
                return selectedSnapshot
            end
            return nil
        end,
    })

    local rooms = roomEvents(history)
    lu.assertEquals(#rooms, 10)
    lu.assertEquals(rooms[1].eventKey, "O_Intro")
    lu.assertEquals(rooms[1].roleKey, "Intro")
    lu.assertEquals(rooms[1].biomeDepthCache, 1)
    lu.assertEquals(rooms[1].biomeEncounterDepth, 1)
    lu.assertEquals(rooms[2].eventKey, "O_Combat01")
    lu.assertEquals(rooms[2].roleKey, "Combat")
    lu.assertEquals(rooms[2].routeOrdinal, 1)
    lu.assertEquals(rooms[3].eventKey, "O_Combat02")
    lu.assertEquals(rooms[3].variantKey, "ThreeCombats")
    lu.assertEquals(rooms[8].eventKey, "Preboss")
    lu.assertEquals(rooms[8].reward.kind, "shop")
    lu.assertEquals(rooms[9].eventKey, "Boss")
    lu.assertEquals(rooms[9].sourceKind, "afterBiome")
    lu.assertEquals(rooms[10].eventKey, "O_PostBoss01")
    lu.assertEquals(rooms[10].sourceKind, "afterBiome")
end

function TestRunPlannerRouteHistoryBuilder.testMultiEncounterFixedTracksShipEncounterDepth()
    local catalog = h.loadCatalog()
    local template = h.loadMultiEncounterTemplate()
    local instance = template.prepare({
        name = "RouteO",
        biome = catalog.lookup.O,
    })
    local control = template.createRuntime(
        h.routeFields(fullOThessalyRows(), nil, nil, fullOThessalyEncounterRewardRows()),
        instance
    )
    local selectedSnapshot = control:buildSelectedRowsSnapshot()

    local history = historyBuilder.build({
        route = {
            key = "Surface",
            biomes = { "O" },
        },
        biomeLookup = catalog.lookup,
        snapshotForBiome = function(_, biomeKey)
            if biomeKey == "O" then
                return selectedSnapshot
            end
            return nil
        end,
    })

    local rooms = roomEvents(history)
    lu.assertEquals(rooms[2].biomeDepthCache, 1)
    lu.assertEquals(rooms[2].biomeEncounterDepth, 1)
    lu.assertEquals(rooms[3].biomeDepthCache, 2)
    lu.assertEquals(rooms[3].biomeEncounterDepth, 2)
    lu.assertEquals(rooms[4].biomeDepthCache, 3)
    lu.assertEquals(rooms[4].biomeEncounterDepth, 4)
    lu.assertEquals(rooms[7].biomeDepthCache, 6)
    lu.assertEquals(rooms[7].biomeEncounterDepth, 5)
    lu.assertEquals(rooms[8].biomeDepthCache, 7)
    lu.assertEquals(rooms[8].biomeEncounterDepth, 6)
end

function TestRunPlannerRouteHistoryBuilder.testMultiEncounterFixedEntriesCarryEncounterRewards()
    local catalog = h.loadCatalog()
    local template = h.loadMultiEncounterTemplate()
    local instance = template.prepare({
        name = "RouteO",
        biome = catalog.lookup.O,
    })
    local control = template.createRuntime(
        h.routeFields(fullOThessalyRows(), nil, nil, fullOThessalyEncounterRewardRows()),
        instance
    )
    local selectedSnapshot = control:buildSelectedRowsSnapshot()

    local history = historyBuilder.build({
        route = {
            key = "Surface",
            biomes = { "O" },
        },
        biomeLookup = catalog.lookup,
        snapshotForBiome = function(_, biomeKey)
            if biomeKey == "O" then
                return selectedSnapshot
            end
            return nil
        end,
    })

    local rooms = roomEvents(history)
    lu.assertEquals(rooms[2].reward.kind, "multiEncounter")
    lu.assertEquals(#rooms[2].reward.encounters, 1)
    lu.assertEquals(rooms[2].reward.encounters[1].key, "Encounter1")
    lu.assertEquals(rooms[2].reward.encounters[1].wheelOfferCount, 1)
    lu.assertEquals(rooms[2].reward.encounters[1].reward.rewardType, "MaxHealthDrop")
    lu.assertEquals(rooms[3].reward.kind, "multiEncounter")
    lu.assertEquals(#rooms[3].reward.encounters, 2)
    lu.assertEquals(rooms[3].reward.encounters[1].reward.rewardType, "Boon")
    lu.assertEquals(rooms[3].reward.encounters[1].reward.boonSource, "ApolloUpgrade")
    lu.assertEquals(rooms[3].reward.encounters[2].reward.rewardClass, "Minor")
    lu.assertEquals(rooms[3].reward.encounters[2].reward.rewardStore, "MetaProgress")
    lu.assertEquals(rooms[3].reward.encounters[2].reward.rewardType, "RoomMoneyDrop")
    lu.assertEquals(rooms[3].reward.encounters[2].biomeEncounterDepth, 3)
    lu.assertEquals(rooms[3].topology.kind, "shipCombat")
    lu.assertEquals(rooms[3].topology.encounters[2].wheelOfferCount, 2)
end
