local lu = require("luaunit")
local h = require("tests.support.control_harness")
local importHarness = require("tests.support.import_harness")

local historySystem = h.withTestImport(function()
    return h.testImport("mods/route/history/assembly.lua").create({
        rewardDomain = importHarness.loadRewardDomain(),
    })
end)
local routeHistory = historySystem.history
local historyBuilder = historySystem.builder

-- luacheck: globals TestRunPlannerRouteHistoryBuilder
TestRunPlannerRouteHistoryBuilder = {}

local function roomEvents(history)
    return routeHistory.byKind(history, "room")
end

local function lootEvents(history)
    return routeHistory.byKind(history, "loot")
end

local function lootEventsWithTiming(history, timing)
    local matching = {}
    for _, loot in ipairs(lootEvents(history)) do
        if loot.timing == timing then
            matching[#matching + 1] = loot
        end
    end
    return matching
end

local function findCandidate(candidates, field, expected)
    for _, candidate in ipairs(candidates or {}) do
        if candidate[field] == expected then
            return candidate
        end
    end
    return nil
end

local function buildTemplateHistory(catalog, routeKey, biomeKey, template, rows, encounterRewardRows)
    local instance = template.prepare({
        name = "Route" .. biomeKey,
        biome = catalog.lookup[biomeKey],
    })
    local control = template.createRuntime(h.routeFields(rows, encounterRewardRows), instance)
    local selectedSnapshot = control.read and control:read("selectedNodesSnapshot")
        or control:buildSelectedRowsSnapshot()
    return historyBuilder.build({
        route = {
            key = routeKey,
            biomes = { biomeKey },
        },
        biomeLookup = catalog.lookup,
        snapshotForBiome = function(_, requestedBiomeKey)
            if requestedBiomeKey == biomeKey then
                return selectedSnapshot
            end
            return nil
        end,
    })
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
            Reward4Key = "GiftDrop",
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
            Reward4Key = "GiftDrop",
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

local function iGoal(optionKey, siblingKey)
    return {
        RouteKindKey = "Goal",
        OptionKey = optionKey,
        SiblingStructureKey = siblingKey,
    }
end

local function iRewardCombat(optionKey, siblingKey, rewardType)
    return {
        RouteKindKey = "NonGoal",
        NonGoalKindKey = "RewardCombat",
        OptionKey = optionKey,
        SiblingStructureKey = siblingKey,
        Reward1Key = rewardType or "MaxHealthDrop",
    }
end

local function fullITartarusRows()
    return {
        {},
        iGoal("I_Combat01"),
        iRewardCombat("I_Combat03", "CombatGoal", "MaxHealthDrop"),
        iGoal("I_Combat04", "I_Story01"),
        {
            RouteKindKey = "NonGoal",
            NonGoalKindKey = "Story",
            OptionKey = "I_Story01",
            SiblingStructureKey = "CombatGoal",
        },
        iGoal("I_Combat09", "CombatReward"),
        {
            RouteKindKey = "NonGoal",
            NonGoalKindKey = "Fountain",
            OptionKey = "I_Reprieve01",
            SiblingStructureKey = "CombatGoal",
            Reward1Key = "MaxManaDrop",
        },
        iGoal("I_Combat10", "CombatReward"),
        {
            RouteKindKey = "NonGoal",
            NonGoalKindKey = "Miniboss",
            OptionKey = "I_MiniBoss01",
            SiblingStructureKey = "CombatGoal",
            Reward1Key = "ZeusUpgrade",
        },
        iGoal("I_Combat11", "CombatReward"),
        iRewardCombat("I_Combat12", "CombatReward", "RoomMoneyDrop"),
        {
            RouteKindKey = "Preboss",
        },
        {},
        {},
    }
end

local function fullNEphyraRows()
    return {
        { Reward1Key = "SpellDrop" },
        { Reward1Key = "WeaponUpgrade" },
        {},
        {
            RoleKey = "Combat",
            OptionKey = "N_Combat12",
            Reward1Key = "Boon",
            Reward2Key = "ZeusUpgrade",
            Side1ModeKey = "Enabled",
            Side1Entered = true,
            Side1Reward1Key = "MaxHealthDrop",
            Side2ModeKey = "Enabled",
            Side2Entered = false,
        },
        {
            RoleKey = "Story",
            OptionKey = "N_Story01",
        },
        {
            RoleKey = "Miniboss",
            OptionKey = "N_MiniBoss02",
            Reward1Key = "AphroditeUpgrade",
        },
        {
            RoleKey = "Combat",
            OptionKey = "N_Combat05",
            Reward1Key = "MaxHealthDrop",
        },
        {
            RoleKey = "Combat",
            OptionKey = "N_Combat06",
            Reward1Key = "RoomMoneyDrop",
        },
        {
            RoleKey = "Combat",
            OptionKey = "N_Combat13",
            Reward1Key = "MaxManaDrop",
        },
        {
            Reward1Key = "RandomLoot",
            Reward1LootKey = "ApolloUpgrade",
            Reward1StateKey = "Bought",
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

function TestRunPlannerRouteHistoryBuilder.testFixedLinearEmitsSelectedNodesSnapshot()
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

    local snapshot = control:read("selectedNodesSnapshot")

    lu.assertEquals(snapshot.schema, "selectedNodes.v1")
    lu.assertEquals(snapshot.controlName, "RouteF")
    lu.assertEquals(snapshot.biomeKey, "F")
    lu.assertEquals(snapshot.adapter, "fixedLinear")
    lu.assertEquals(snapshot.nodes[1].currentRoom.optionKey, "F_Opening01")
    lu.assertEquals(snapshot.nodes[1].nextChoices.picked.targetRowIndex, 2)
    lu.assertEquals(snapshot.nodes[1].nextChoices.picked.optionKey, "F_Combat02")
    lu.assertEquals(snapshot.nodes[1].nextChoices.picked.rewards.row.values[1], "Major")
    lu.assertNil(snapshot.nodes[1].nextChoices.otherDoors)
    lu.assertEquals(snapshot.nodes[2].currentRoom.optionKey, "F_Combat02")
    lu.assertEquals(snapshot.nodes[2].nextChoices.otherDoors[1].structureKey, "Combat")
    lu.assertEquals(snapshot.nodes[2].nextChoices.otherDoors[1].formAddress.childKind, "otherDoor")
    lu.assertEquals(snapshot.nodes[2].rewards.row.values[1], "Major")
    lu.assertEquals(snapshot.nodes[2].rewards.sibling[1].rewardClassKey, "Major")
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
    lu.assertEquals(rooms[2].biomeDepthCache, 1)
    lu.assertEquals(rooms[2].biomeEncounterDepth, 2)
    lu.assertEquals(rooms[2].runEncounterDepth, 2)
    lu.assertEquals(rooms[3].eventKey, "Boss")
    lu.assertEquals(rooms[3].eventSourceKind, "afterBiome")
    lu.assertEquals(rooms[4].eventKey, "F_PostBoss01")
    lu.assertEquals(rooms[4].eventSourceKind, "afterBiome")
end

function TestRunPlannerRouteHistoryBuilder.testFixedLinearAdapterDoesNotDefaultBlankRequiredRoomOption()
    local catalog = h.loadCatalog()
    local history = buildTemplateHistory(catalog, "Underworld", "F", h.loadFixedLinearTemplate(), {
        {
            OptionKey = "F_Opening01",
            Reward1Key = "SpellDrop",
        },
        {
            RoleKey = "Combat",
            OptionKey = "",
            Reward1Key = "Major",
            Reward2Key = "MaxHealthDrop",
        },
    })

    local rooms = roomEvents(history)
    lu.assertNil(findCandidate(rooms, "rowIndex", 2))
    lu.assertNil(findCandidate(rooms, "eventKey", "Combat"))
end

function TestRunPlannerRouteHistoryBuilder.testFixedLinearBuildsFullDeclaredFErebusSpine()
    local catalog = h.loadCatalog()
    local template = h.loadFixedLinearTemplate()
    local instance = template.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local control = template.createRuntime(h.routeFields(fullFErebusRows()), instance)
    local selectedSnapshot = control:read("selectedNodesSnapshot")

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
    lu.assertEquals(rooms[12].eventSourceKind, "row")
    lu.assertEquals(rooms[12].roleKey, "Preboss")
    lu.assertEquals(rooms[13].eventKey, "Boss")
    lu.assertEquals(rooms[13].eventSourceKind, "afterBiome")
    lu.assertEquals(rooms[14].eventKey, "F_PostBoss01")
    lu.assertEquals(rooms[14].eventSourceKind, "afterBiome")
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
    local selectedSnapshot = control:read("selectedNodesSnapshot")

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
    lu.assertEquals(rooms[1].roomHistoryOrdinal, 1)
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
    local selectedSnapshot = control:read("selectedNodesSnapshot")

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
    local boonLoot = routeHistory.lootEntries(history, "Boon")
    lu.assertEquals(#boonLoot, 2)
    lu.assertEquals(boonLoot[1].parentRoomKey, "F_Combat05")
    lu.assertEquals(boonLoot[1].lootName, "ZeusUpgrade")
    lu.assertEquals(boonLoot[2].parentRoomKey, "Preboss")
    lu.assertEquals(boonLoot[2].eventSourceKind, "prebossFreeReward")
    lu.assertEquals(routeHistory.sourceEntries(history, "ZeusUpgrade")[2], boonLoot[2])
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
    local selectedSnapshot = control:buildSelectedNodesSnapshot()

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
    lu.assertEquals(rooms[1].biomeEncounterDepth, 0)
    lu.assertEquals(rooms[2].eventKey, "H_Combat04")
    lu.assertEquals(rooms[2].roleKey, "Combat")
    lu.assertEquals(rooms[2].routeOrdinal, 1)
    lu.assertEquals(rooms[2].variantKey, "ThreeRewards")
    lu.assertEquals(rooms[3].eventKey, "H_Combat09")
    lu.assertEquals(rooms[4].eventKey, "H_Bridge01")
    lu.assertEquals(rooms[5].eventKey, "H_MiniBoss01")
    lu.assertEquals(rooms[6].eventKey, "Preboss")
    lu.assertEquals(rooms[7].eventKey, "Boss")
    lu.assertEquals(rooms[7].eventSourceKind, "afterBiome")
    lu.assertEquals(rooms[8].eventKey, "H_PostBoss01")
    lu.assertEquals(rooms[8].eventSourceKind, "afterBiome")
end

function TestRunPlannerRouteHistoryBuilder.testFieldsCageAdapterDoesNotDefaultBlankRequiredRoomOption()
    local catalog = h.loadCatalog()
    local history = buildTemplateHistory(catalog, "Underworld", "H", h.loadFieldsCageTemplate(), {
        {},
        {
            RoleKey = "Combat",
            OptionKey = "",
            VariantKey = "TwoRewards",
            Reward1Key = "Boon",
            Reward1LootKey = "ZeusUpgrade",
            Reward2Key = "HermesUpgrade",
        },
    })

    local rooms = roomEvents(history)
    lu.assertNil(findCandidate(rooms, "rowIndex", 2))
    lu.assertNil(findCandidate(rooms, "eventKey", "Combat"))
end

function TestRunPlannerRouteHistoryBuilder.testFieldsCageEntriesCarryTopologyAndRewards()
    local catalog = h.loadCatalog()
    local template = h.loadFieldsCageTemplate()
    local instance = template.prepare({
        name = "RouteH",
        biome = catalog.lookup.H,
    })
    local control = template.createRuntime(h.routeFields(fullHFieldsRows()), instance)
    local selectedSnapshot = control:buildSelectedNodesSnapshot()

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
    lu.assertEquals(rooms[1].topology.kind, "fieldsChoice")
    lu.assertEquals(rooms[1].topology.selected.structure, "CombatCage3")
    lu.assertEquals(rooms[1].topology.selected.sameExitRewardCount, 3)
    lu.assertEquals(rooms[2].topology.kind, "fieldsChoice")
    lu.assertEquals(rooms[2].topology.selected.structure, "CombatCage2")
    lu.assertEquals(rooms[2].topology.selected.sameExitRewardCount, 2)
    lu.assertNil(rooms[2].topology.sibling)
    lu.assertEquals(rooms[2].reward.kind, "fieldsCages")
    lu.assertEquals(rooms[2].reward.sameExitRewardCount, 3)
    lu.assertEquals(rooms[2].reward.picks[1].rewardType, "Boon")
    lu.assertEquals(rooms[2].reward.picks[1].boonSource, "PoseidonUpgrade")
    lu.assertEquals(rooms[2].reward.picks[2].rewardType, "HermesUpgrade")
    lu.assertEquals(rooms[2].reward.picks[3].rewardType, "StackUpgrade")
    lu.assertEquals(rooms[3].topology.selected.structure, "Bridge")
    lu.assertEquals(rooms[3].topology.picked.structure, "Bridge")
    lu.assertEquals(rooms[3].topology.selected.roomKey, "H_Bridge01")
    lu.assertEquals(rooms[3].topology.sibling.structure, "CombatCage2")
    lu.assertEquals(rooms[3].topology.otherDoors[1].structure, "CombatCage2")
    lu.assertEquals(rooms[3].topology.sibling.sameExitRewardCount, 2)
    lu.assertEquals(rooms[4].topology.selected.structure, "Miniboss")
    lu.assertEquals(rooms[4].topology.picked.structure, "Miniboss")
    lu.assertEquals(rooms[4].topology.selected.roomKey, "H_MiniBoss01")
    lu.assertEquals(rooms[4].topology.sibling.structure, "Miniboss")
    lu.assertEquals(rooms[4].topology.otherDoors[1].structure, "Miniboss")
    lu.assertEquals(rooms[4].topology.sibling.roomKey, "H_MiniBoss02")
    lu.assertEquals(rooms[4].topology.sibling.eligibleRewardTypes[1], "Boon")

    lu.assertNil(rooms[5].topology)
    lu.assertEquals(rooms[5].reward.kind, "roomStore")
    lu.assertEquals(rooms[5].reward.rewardType, "Boon")
    lu.assertEquals(rooms[5].reward.boonSource, "ZeusUpgrade")

    lu.assertEquals(rooms[6].reward.kind, "preboss")
    lu.assertEquals(rooms[6].reward.branch, "Shop")
    lu.assertEquals(rooms[6].reward.offers[1].rewardType, "RandomLoot")
    lu.assertEquals(rooms[6].reward.offers[1].boonSource, "ApolloUpgrade")
    lu.assertTrue(rooms[6].reward.offers[1].bought)

    local loot = lootEvents(history)
    lu.assertEquals(loot[1].eventSourceKind, "fieldsCage")
    lu.assertEquals(loot[1].address, "cage:1")
    lu.assertEquals(loot[1].lootType, "Boon")
    lu.assertEquals(loot[1].lootName, "PoseidonUpgrade")
    lu.assertEquals(loot[2].lootType, "HermesUpgrade")
    lu.assertEquals(loot[3].lootType, "StackUpgrade")
    lu.assertEquals(routeHistory.lootEntries(history, "WeaponUpgrade")[1].parentRoomKey, "H_Combat09")
    lu.assertEquals(routeHistory.lootEntries(history, "RandomLoot")[1].eventSourceKind, "prebossShop")
    lu.assertTrue(routeHistory.lootEntries(history, "RandomLoot")[1].bought)
    lu.assertNil(routeHistory.pendingLootEntries(history, "RandomLoot")[1])
end

function TestRunPlannerRouteHistoryBuilder.testMultiEncounterFixedBuildsThessalySpine()
    local catalog = h.loadCatalog()
    local template = h.loadMultiEncounterTemplate()
    local instance = template.prepare({
        name = "RouteO",
        biome = catalog.lookup.O,
    })
    local control = template.createRuntime(
        h.routeFields(fullOThessalyRows(), fullOThessalyEncounterRewardRows()),
        instance
    )
    local selectedSnapshot = control:read("selectedNodesSnapshot")

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
    lu.assertEquals(rooms[1].biomeEncounterDepth, 0)
    lu.assertEquals(rooms[2].eventKey, "O_Combat01")
    lu.assertEquals(rooms[2].roleKey, "Combat")
    lu.assertEquals(rooms[2].routeOrdinal, 1)
    lu.assertEquals(rooms[3].eventKey, "O_Combat02")
    lu.assertEquals(rooms[3].variantKey, "ThreeCombats")
    lu.assertEquals(rooms[8].eventKey, "Preboss")
    lu.assertEquals(rooms[8].reward.kind, "shop")
    lu.assertEquals(rooms[9].eventKey, "Boss")
    lu.assertEquals(rooms[9].eventSourceKind, "afterBiome")
    lu.assertEquals(rooms[10].eventKey, "O_PostBoss01")
    lu.assertEquals(rooms[10].eventSourceKind, "afterBiome")
end

function TestRunPlannerRouteHistoryBuilder.testMultiEncounterAdapterDoesNotDefaultBlankRequiredRoomOption()
    local catalog = h.loadCatalog()
    local history = buildTemplateHistory(catalog, "Surface", "O", h.loadMultiEncounterTemplate(), {
        {},
        {
            RoleKey = "Combat",
            OptionKey = "",
            VariantKey = "TwoCombats",
        },
    })

    local rooms = roomEvents(history)
    lu.assertNil(findCandidate(rooms, "rowIndex", 2))
    lu.assertNil(findCandidate(rooms, "eventKey", "Combat"))
end

function TestRunPlannerRouteHistoryBuilder.testMultiEncounterFixedTracksShipEncounterDepth()
    local catalog = h.loadCatalog()
    local template = h.loadMultiEncounterTemplate()
    local instance = template.prepare({
        name = "RouteO",
        biome = catalog.lookup.O,
    })
    local control = template.createRuntime(
        h.routeFields(fullOThessalyRows(), fullOThessalyEncounterRewardRows()),
        instance
    )
    local selectedSnapshot = control:read("selectedNodesSnapshot")

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
    lu.assertEquals(rooms[2].biomeDepthCache, 2)
    lu.assertEquals(rooms[2].biomeEncounterDepth, 1)
    lu.assertEquals(rooms[3].biomeDepthCache, 3)
    lu.assertEquals(rooms[3].biomeEncounterDepth, 2)
    lu.assertEquals(rooms[4].biomeDepthCache, 4)
    lu.assertEquals(rooms[4].biomeEncounterDepth, 3)
    lu.assertEquals(rooms[7].biomeDepthCache, 7)
    lu.assertEquals(rooms[7].biomeEncounterDepth, 5)
    lu.assertEquals(rooms[8].biomeDepthCache, 8)
    lu.assertEquals(rooms[8].biomeEncounterDepth, 5)
end

function TestRunPlannerRouteHistoryBuilder.testMultiEncounterFixedEntriesCarryEncounterRewards()
    local catalog = h.loadCatalog()
    local template = h.loadMultiEncounterTemplate()
    local instance = template.prepare({
        name = "RouteO",
        biome = catalog.lookup.O,
    })
    local control = template.createRuntime(
        h.routeFields(fullOThessalyRows(), fullOThessalyEncounterRewardRows()),
        instance
    )
    local selectedSnapshot = control:read("selectedNodesSnapshot")

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
    lu.assertEquals(rooms[3].reward.encounters[2].reward.rewardType, "GiftDrop")
    lu.assertEquals(rooms[3].reward.encounters[2].biomeEncounterDepth, 3)
    lu.assertEquals(rooms[3].biomeEncounterDepth, 2)
    lu.assertEquals(rooms[3].topology.kind, "shipCombat")
    lu.assertEquals(rooms[3].topology.encounters[2].wheelOfferCount, 2)

    local loot = lootEvents(history)
    lu.assertEquals(loot[1].parentRoomKey, "O_Combat01")
    lu.assertEquals(loot[1].eventSourceKind, "multiEncounter")
    lu.assertEquals(loot[1].address, "encounter:1")
    lu.assertEquals(loot[1].lootType, "MaxHealthDrop")
    lu.assertEquals(loot[2].parentRoomKey, "O_Combat02")
    lu.assertEquals(loot[2].lootType, "Boon")
    lu.assertEquals(loot[2].lootName, "ApolloUpgrade")
    lu.assertEquals(loot[3].address, "encounter:2")
    lu.assertEquals(loot[3].lootType, "GiftDrop")
    lu.assertEquals(#routeHistory.biomeLootEntries(history, "O", "GiftDrop"), 2)
end

function TestRunPlannerRouteHistoryBuilder.testClockworkGoalBuildsTartarusSpine()
    local catalog = h.loadCatalog()
    local template = h.loadClockworkGoalTemplate()
    local instance = template.prepare({
        name = "RouteI",
        biome = catalog.lookup.I,
    })
    local control = template.createRuntime(h.routeFields(fullITartarusRows()), instance)
    local selectedSnapshot = control:read("selectedNodesSnapshot")

    local history = historyBuilder.build({
        route = {
            key = "Underworld",
            biomes = { "I" },
        },
        biomeLookup = catalog.lookup,
        snapshotForBiome = function(_, biomeKey)
            if biomeKey == "I" then
                return selectedSnapshot
            end
            return nil
        end,
    })

    local rooms = roomEvents(history)
    lu.assertEquals(#rooms, 14)
    lu.assertEquals(rooms[1].eventKey, "I_Intro")
    lu.assertEquals(rooms[1].roleKey, "Intro")
    lu.assertEquals(rooms[2].eventKey, "I_Combat01")
    lu.assertEquals(rooms[2].roleKey, "GoalCombat")
    lu.assertEquals(rooms[3].eventKey, "I_Combat03")
    lu.assertEquals(rooms[3].roleKey, "RewardCombat")
    lu.assertEquals(rooms[11].eventKey, "I_Combat12")
    lu.assertEquals(rooms[12].eventKey, "Preboss")
    lu.assertEquals(rooms[12].roleKey, "Preboss")
    lu.assertEquals(rooms[13].eventKey, "Boss")
    lu.assertEquals(rooms[13].eventSourceKind, "afterBiome")
    lu.assertEquals(rooms[14].eventKey, "I_PostBoss01")
    lu.assertEquals(rooms[14].eventSourceKind, "afterBiome")
end

function TestRunPlannerRouteHistoryBuilder.testClockworkAdapterDoesNotDefaultBlankRequiredRoomOption()
    local catalog = h.loadCatalog()
    local history = buildTemplateHistory(catalog, "Underworld", "I", h.loadClockworkGoalTemplate(), {
        {},
        {
            RouteKindKey = "Goal",
            OptionKey = "",
        },
    })

    local rooms = roomEvents(history)
    lu.assertNil(findCandidate(rooms, "rowIndex", 2))
    lu.assertNil(findCandidate(rooms, "eventKey", "GoalCombat"))
end

function TestRunPlannerRouteHistoryBuilder.testClockworkGoalSkipsInactiveRowsAndKeepsCounters()
    local catalog = h.loadCatalog()
    local template = h.loadClockworkGoalTemplate()
    local instance = template.prepare({
        name = "RouteI",
        biome = catalog.lookup.I,
    })
    local control = template.createRuntime(h.routeFields(fullITartarusRows()), instance)
    local selectedSnapshot = control:read("selectedNodesSnapshot")

    local history = historyBuilder.build({
        route = {
            key = "Underworld",
            biomes = { "I" },
        },
        biomeLookup = catalog.lookup,
        snapshotForBiome = function(_, biomeKey)
            if biomeKey == "I" then
                return selectedSnapshot
            end
            return nil
        end,
    })

    local rooms = roomEvents(history)
    lu.assertEquals(rooms[11].rowIndex, 11)
    lu.assertEquals(rooms[11].roomHistoryOrdinal, 11)
    lu.assertEquals(rooms[12].rowIndex, 12)
    lu.assertEquals(rooms[12].roomHistoryOrdinal, 12)
    lu.assertEquals(rooms[12].biomeDepthCache, 12)
    lu.assertEquals(rooms[12].biomeEncounterDepth, 8)
end

function TestRunPlannerRouteHistoryBuilder.testClockworkGoalEntriesCarryTopologyAndRewards()
    local catalog = h.loadCatalog()
    local template = h.loadClockworkGoalTemplate()
    local instance = template.prepare({
        name = "RouteI",
        biome = catalog.lookup.I,
    })
    local control = template.createRuntime(h.routeFields(fullITartarusRows()), instance)
    local selectedSnapshot = control:read("selectedNodesSnapshot")

    local history = historyBuilder.build({
        route = {
            key = "Underworld",
            biomes = { "I" },
        },
        biomeLookup = catalog.lookup,
        snapshotForBiome = function(_, biomeKey)
            if biomeKey == "I" then
                return selectedSnapshot
            end
            return nil
        end,
    })

    local rooms = roomEvents(history)
    lu.assertEquals(rooms[3].reward.kind, "roomStore")
    lu.assertEquals(rooms[3].reward.rewardStore, "TartarusRewards")
    lu.assertEquals(rooms[3].reward.rewardType, "MaxHealthDrop")
    lu.assertEquals(rooms[2].topology.kind, "clockworkSiblingChoice")
    lu.assertEquals(rooms[2].topology.selected.structure, "RewardCombat")
    lu.assertNil(rooms[2].topology.sibling)
    lu.assertEquals(rooms[3].topology.kind, "clockworkSiblingChoice")
    lu.assertEquals(rooms[3].topology.selected.structure, "GoalCombat")
    lu.assertEquals(rooms[3].topology.picked.structure, "GoalCombat")
    lu.assertEquals(rooms[3].topology.sibling.structure, "GoalCombat")
    lu.assertEquals(rooms[3].topology.otherDoors[1].structure, "GoalCombat")
    lu.assertTrue(rooms[3].topology.sibling.isClockworkGoal)

    lu.assertEquals(rooms[7].roleKey, "Fountain")
    lu.assertEquals(rooms[7].reward.rewardStore, "TartarusRewards")
    lu.assertEquals(rooms[7].reward.rewardType, "MaxManaDrop")
    lu.assertEquals(rooms[9].roleKey, "Miniboss")
    lu.assertEquals(rooms[9].reward.rewardStore, "RunProgress")
    lu.assertEquals(rooms[9].reward.rewardType, "Boon")
    lu.assertEquals(rooms[9].reward.boonSource, "ZeusUpgrade")
    lu.assertEquals(rooms[11].topology.selected.structure, "Preboss")
    lu.assertEquals(rooms[11].topology.sibling.structure, "RewardCombat")
    lu.assertEquals(rooms[12].reward.kind, "shop")
    lu.assertEquals(rooms[12].reward.shopProfile, "I_WorldShop")
end

function TestRunPlannerRouteHistoryBuilder.testHubPylonBuildsAccurateEphyraTraversal()
    local catalog = h.loadCatalog()
    local template = h.loadHubPylonTemplate()
    local instance = template.prepare({
        name = "RouteN",
        biome = catalog.lookup.N,
    })
    local control = template.createRuntime(h.routeFields(fullNEphyraRows()), instance)
    local selectedSnapshot = control:buildSelectedRowsSnapshot()

    local history = historyBuilder.build({
        route = {
            key = "Surface",
            biomes = { "N" },
        },
        biomeLookup = catalog.lookup,
        snapshotForBiome = function(_, biomeKey)
            if biomeKey == "N" then
                return selectedSnapshot
            end
            return nil
        end,
    })

    local rooms = roomEvents(history)
    lu.assertEquals(#rooms, 20)
    lu.assertEquals(rooms[1].eventKey, "N_Opening01")
    lu.assertEquals(rooms[2].eventKey, "N_PreHub01")
    lu.assertEquals(rooms[3].eventKey, "N_Hub")
    lu.assertEquals(rooms[3].eventSourceKind, "row")
    lu.assertEquals(rooms[4].eventKey, "N_Combat12")
    lu.assertEquals(rooms[4].eventSourceKind, "row")
    lu.assertEquals(rooms[5].eventKey, "N_Sub09")
    lu.assertEquals(rooms[5].eventSourceKind, "sideRoom")
    lu.assertEquals(rooms[5].sideIndex, 1)
    lu.assertEquals(rooms[5].encounterClassKey, "Hard")
    lu.assertEquals(rooms[6].eventKey, "N_Combat12")
    lu.assertEquals(rooms[6].eventSourceKind, "pylonRestore")
    lu.assertEquals(rooms[7].eventKey, "N_Hub")
    lu.assertEquals(rooms[7].eventSourceKind, "hubReturn")
    lu.assertEquals(rooms[8].eventKey, "N_Story01")
    lu.assertEquals(rooms[9].eventKey, "N_Hub")
    lu.assertEquals(rooms[10].eventKey, "N_MiniBoss02")
    lu.assertEquals(rooms[16].eventKey, "N_Combat13")
    lu.assertEquals(rooms[17].eventKey, "N_Hub")
    lu.assertEquals(rooms[17].eventSourceKind, "hubReturn")
    lu.assertEquals(rooms[18].eventKey, "Preboss")
    lu.assertEquals(rooms[19].eventKey, "Boss")
    lu.assertEquals(rooms[20].eventKey, "N_PostBoss01")
end

function TestRunPlannerRouteHistoryBuilder.testHubPylonTraversalCountersFollowEphyraModel()
    local catalog = h.loadCatalog()
    local template = h.loadHubPylonTemplate()
    local instance = template.prepare({
        name = "RouteN",
        biome = catalog.lookup.N,
    })
    local control = template.createRuntime(h.routeFields(fullNEphyraRows()), instance)
    local selectedSnapshot = control:buildSelectedRowsSnapshot()

    local history = historyBuilder.build({
        route = {
            key = "Surface",
            biomes = { "N" },
        },
        biomeLookup = catalog.lookup,
        snapshotForBiome = function(_, biomeKey)
            if biomeKey == "N" then
                return selectedSnapshot
            end
            return nil
        end,
    })

    local rooms = roomEvents(history)
    lu.assertEquals(rooms[1].roomHistoryOrdinal, 1)
    lu.assertEquals(rooms[1].biomeDepthCache, 1)
    lu.assertEquals(rooms[1].biomeEncounterDepth, 1)
    lu.assertEquals(rooms[2].roomHistoryOrdinal, 2)
    lu.assertEquals(rooms[2].biomeDepthCache, 2)
    lu.assertEquals(rooms[2].biomeEncounterDepth, 1)
    lu.assertEquals(rooms[3].roomHistoryOrdinal, 3)
    lu.assertEquals(rooms[3].biomeDepthCache, 3)
    lu.assertEquals(rooms[3].biomeEncounterDepth, 1)
    lu.assertEquals(rooms[4].roomHistoryOrdinal, 4)
    lu.assertEquals(rooms[4].biomeDepthCache, 4)
    lu.assertEquals(rooms[4].biomeEncounterDepth, 2)
    lu.assertEquals(rooms[5].roomHistoryOrdinal, 5)
    lu.assertEquals(rooms[5].biomeDepthCache, 5)
    lu.assertEquals(rooms[5].biomeEncounterDepth, 2)
    lu.assertEquals(rooms[6].roomHistoryOrdinal, 6)
    lu.assertEquals(rooms[6].biomeDepthCache, 6)
    lu.assertEquals(rooms[6].biomeEncounterDepth, 2)
    lu.assertEquals(rooms[8].eventKey, "N_Story01")
    lu.assertEquals(rooms[8].biomeEncounterDepth, 2)
    lu.assertEquals(rooms[10].eventKey, "N_MiniBoss02")
    lu.assertEquals(rooms[10].biomeEncounterDepth, 3)
    lu.assertEquals(rooms[18].eventKey, "Preboss")
    lu.assertEquals(rooms[18].roomHistoryOrdinal, 18)
    lu.assertEquals(rooms[18].biomeDepthCache, 18)
    lu.assertEquals(rooms[18].biomeEncounterDepth, 6)
end

function TestRunPlannerRouteHistoryBuilder.testHubPylonEntriesCarryHubAndSideRewards()
    local catalog = h.loadCatalog()
    local template = h.loadHubPylonTemplate()
    local instance = template.prepare({
        name = "RouteN",
        biome = catalog.lookup.N,
    })
    local control = template.createRuntime(h.routeFields(fullNEphyraRows()), instance)
    local selectedSnapshot = control:buildSelectedRowsSnapshot()

    local history = historyBuilder.build({
        route = {
            key = "Surface",
            biomes = { "N" },
        },
        biomeLookup = catalog.lookup,
        snapshotForBiome = function(_, biomeKey)
            if biomeKey == "N" then
                return selectedSnapshot
            end
            return nil
        end,
    })

    local rooms = roomEvents(history)
    lu.assertEquals(rooms[3].topology.kind, "hubDoorBatch")
    lu.assertEquals(rooms[3].topology.hub.generatedDoorCount, 10)
    lu.assertEquals(#rooms[3].topology.generatedDoors, 6)
    lu.assertEquals(rooms[3].topology.generatedDoors[1].targetRowIndex, 4)
    lu.assertEquals(rooms[3].topology.generatedDoors[1].structure, "Combat")
    lu.assertEquals(rooms[3].topology.generatedDoors[1].roomKey, "N_Combat12")
    lu.assertEquals(rooms[3].topology.generatedDoors[1].hubDoorId, 561389)
    lu.assertEquals(rooms[3].topology.generatedDoors[1].reward.kind, "roomStore")
    lu.assertEquals(rooms[3].topology.generatedDoors[1].reward.rewardStore, "HubRewards")
    lu.assertEquals(rooms[3].topology.generatedDoors[1].reward.rewardType, "Boon")
    lu.assertEquals(rooms[3].topology.generatedDoors[1].reward.boonSource, "ZeusUpgrade")
    lu.assertEquals(rooms[3].topology.generatedDoors[2].targetRowIndex, 5)
    lu.assertEquals(rooms[3].topology.generatedDoors[2].structure, "Story")
    lu.assertEquals(rooms[3].topology.generatedDoors[2].roomKey, "N_Story01")
    lu.assertNil(rooms[3].topology.generatedDoors[2].reward)
    lu.assertEquals(rooms[3].topology.generatedDoors[3].targetRowIndex, 6)
    lu.assertEquals(rooms[3].topology.generatedDoors[3].structure, "Miniboss")
    lu.assertEquals(rooms[3].topology.generatedDoors[3].roomKey, "N_MiniBoss02")
    lu.assertEquals(rooms[3].topology.generatedDoors[3].reward.rewardStore, "RunProgress")
    lu.assertEquals(rooms[3].topology.generatedDoors[3].reward.rewardType, "Boon")
    lu.assertEquals(rooms[3].topology.generatedDoors[3].reward.boonSource, "AphroditeUpgrade")
    lu.assertEquals(rooms[4].topology.kind, "hubDoorBatchPick")
    lu.assertEquals(rooms[4].topology.selected.structure, "Combat")
    lu.assertEquals(rooms[4].topology.selected.rewardStore, "HubRewards")
    lu.assertEquals(rooms[4].reward.kind, "roomStore")
    lu.assertEquals(rooms[4].reward.rewardStore, "HubRewards")
    lu.assertEquals(rooms[4].reward.rewardType, "Boon")
    lu.assertEquals(rooms[4].reward.boonSource, "ZeusUpgrade")
    lu.assertEquals(rooms[5].reward.kind, "roomStore")
    lu.assertEquals(rooms[5].formAddress, {
        rowIndex = 4,
        childKind = "sideRoom",
        childIndex = 1,
    })
    lu.assertEquals(rooms[5].reward.address, "side:1")
    lu.assertEquals(rooms[5].reward.rewardStore, "SubRoomRewardsHard")
    lu.assertEquals(rooms[5].reward.rewardType, "MaxHealthDrop")
    lu.assertEquals(rooms[10].reward.rewardStore, "RunProgress")
    lu.assertEquals(rooms[10].reward.rewardType, "Boon")
    lu.assertEquals(rooms[10].reward.boonSource, "AphroditeUpgrade")
    lu.assertEquals(rooms[18].reward.kind, "shop")
    lu.assertEquals(rooms[18].reward.shopProfile, "WorldShop")

    local generatedOffers = lootEventsWithTiming(history, "generatedOffer")
    lu.assertEquals(#generatedOffers, 5)
    lu.assertEquals(generatedOffers[1].eventSourceKind, "hubGeneratedDoor")
    lu.assertEquals(generatedOffers[1].parentEntry, rooms[3])
    lu.assertEquals(generatedOffers[1].parentRoomKey, "N_Combat12")
    lu.assertEquals(generatedOffers[1].targetRoomKey, "N_Combat12")
    lu.assertEquals(generatedOffers[1].targetHubDoorId, 561389)
    lu.assertEquals(generatedOffers[1].rowIndex, 4)
    lu.assertEquals(generatedOffers[1].formAddress, { rowIndex = 4 })
    lu.assertEquals(generatedOffers[1].routeOrdinal, 1)
    lu.assertEquals(generatedOffers[1].roomHistoryOrdinal, rooms[3].roomHistoryOrdinal)
    lu.assertEquals(generatedOffers[1].rewardStore, "HubRewards")
    lu.assertEquals(generatedOffers[1].lootType, "Boon")
    lu.assertEquals(generatedOffers[1].lootName, "ZeusUpgrade")
    lu.assertNil(generatedOffers[1].legalityValidatedBy)

    local acquiredBoon = routeHistory.lootEntries(history, "Boon")[1]
    lu.assertEquals(acquiredBoon.parentRoomKey, "N_Combat12")
    lu.assertEquals(acquiredBoon.roomHistoryOrdinal, rooms[4].roomHistoryOrdinal)
    lu.assertEquals(acquiredBoon.legalityValidatedBy, "hubGeneratedOffer")

    lu.assertEquals(routeHistory.lootEntries(history, "MaxHealthDrop")[1].address, "side:1")
end
