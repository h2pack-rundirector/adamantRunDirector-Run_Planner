-- luacheck: globals TestCatalogFoundation

local lu = require("luaunit")
local h = dofile("tests/support/import_harness.lua")

TestCatalogFoundation = {}

local function loadCatalog(overrides)
    return h.testImport("mods/composition/catalog.lua").load(overrides)
end

local function assertFails(callback, expected)
    local ok, err = pcall(callback)
    lu.assertFalse(ok)
    lu.assertStrContains(tostring(err), expected)
end

local function assertRoomRange(biome, prefix, count)
    for number = 1, count do
        local key = string.format("%s_Combat%02d", prefix, number)
        lu.assertNotNil(biome.rooms.lookup[key], "missing room " .. key)
    end
end

local function assertExitCounts(biome, expected, keys)
    for _, key in ipairs(keys) do
        lu.assertEquals(#biome.rooms.lookup[key].exits, expected, key)
    end
end

local function assertEnteredRoomExclusion(room, expectedRoomKeys)
    local exclusions = {}
    for _, requirement in ipairs(room.eligibility.requirements) do
        if requirement.kind == "RoomEnteredCount" then
            exclusions[#exclusions + 1] = requirement
        end
    end
    lu.assertEquals(#exclusions, 1, room.key)
    lu.assertEquals(exclusions[1].comparison, "==", room.key)
    lu.assertEquals(exclusions[1].value, 0, room.key)
    lu.assertEquals(exclusions[1].roomKeys, expectedRoomKeys, room.key)
end

local function findRawRoom(raw, biomeKey, roomKey)
    for _, biome in ipairs(raw.biomes) do
        if biome.key == biomeKey then
            for _, room in ipairs(biome.rooms) do
                if room.key == roomKey then
                    return room
                end
            end
        end
    end
    error("missing raw room " .. biomeKey .. "." .. roomKey)
end

local function findRequirement(node, kind)
    if node == nil then
        return nil
    end
    if node.kind == kind then
        return node
    end
    for _, child in ipairs(node.requirements or {}) do
        local found = findRequirement(child, kind)
        if found ~= nil then
            return found
        end
    end
    return findRequirement(node.requirement, kind)
end

function TestCatalogFoundation.testLoadsCompleteRouteAndRoomUniverseHeadlessly()
    h.withImport(function()
        local previousLib = _G.lib
        local previousRom = _G.rom
        _G.lib = nil
        _G.rom = nil
        local catalog = loadCatalog()
        _G.lib = previousLib
        _G.rom = previousRom

        lu.assertEquals(#catalog.routes.ordered, 2)
        lu.assertEquals(catalog.routes.lookup.Underworld.biomeSteps, {
            { key = "Underworld_F", biomeKey = "F" },
            { key = "Underworld_G", biomeKey = "G" },
            { key = "Underworld_H", biomeKey = "H" },
            { key = "Underworld_I", biomeKey = "I" },
        })
        lu.assertEquals(catalog.routes.lookup.Surface.biomeSteps, {
            { key = "Surface_N", biomeKey = "N" },
            { key = "Surface_O", biomeKey = "O" },
            { key = "Surface_P", biomeKey = "P" },
            { key = "Surface_Q", biomeKey = "Q" },
        })

        lu.assertEquals(#catalog.biomes.ordered, 8)
        lu.assertEquals(#catalog.controlManifest.routes.ordered, 2)
        lu.assertEquals(#catalog.controlManifest.rooms.ordered, 210)
        lu.assertNotNil(catalog.controlManifest.rooms.lookup.Underworld_F_Combat04)
        lu.assertEquals(catalog.controlManifest.rooms.lookup.Underworld_F_Combat04.gameRoomKey, "F_Combat04")
        lu.assertNotNil(catalog.controlManifest.rooms.lookup.Surface_Q_PreBoss01)
    end)
end

function TestCatalogFoundation.testCoversEverySupportedConcreteRoom()
    h.withImport(function()
        local catalog = loadCatalog()
        local expectedCounts = { F = 32, G = 28, H = 20, I = 31, N = 30, O = 23, P = 26, Q = 20 }
        local combatCounts = { F = 22, G = 20, H = 15, I = 24, N = 23, O = 15, P = 19 }
        for biomeKey, expected in pairs(expectedCounts) do
            lu.assertEquals(#catalog.biomes.lookup[biomeKey].rooms.ordered, expected, biomeKey)
        end
        for biomeKey, count in pairs(combatCounts) do
            assertRoomRange(catalog.biomes.lookup[biomeKey], biomeKey, count)
        end
        for _, key in ipairs({
            "Q_Combat01", "Q_Combat02", "Q_Combat03", "Q_Combat04", "Q_Combat05", "Q_Combat06", "Q_Combat07",
            "Q_Combat08", "Q_Combat09", "Q_Combat12", "Q_Combat13", "Q_Combat14", "Q_Combat15", "Q_Combat16",
        }) do
            lu.assertNotNil(catalog.biomes.lookup.Q.rooms.lookup[key])
        end
        lu.assertNotNil(catalog.biomes.lookup.G.rooms.lookup.G_MiniBoss03)
        lu.assertNil(catalog.biomes.lookup.I.rooms.lookup.I_Shop01)
        lu.assertNil(catalog.biomes.lookup.I.rooms.lookup.I_MiniBoss03)
        lu.assertNil(catalog.biomes.lookup.N.rooms.lookup.N_Shop01)
        lu.assertNil(catalog.biomes.lookup.Q.rooms.lookup.Q_Combat10)
        lu.assertNil(catalog.biomes.lookup.Q.rooms.lookup.Q_Combat11)
        lu.assertNil(catalog.biomes.lookup.Q.rooms.lookup.Q_MiniBoss01)
    end)
end

function TestCatalogFoundation.testPhysicalExitFactsAndTerminalShapeRemainSeparate()
    h.withImport(function()
        local catalog = loadCatalog()
        local biomes = catalog.biomes.lookup

        lu.assertEquals(#biomes.F.rooms.lookup.F_Combat01.exits, 1)
        lu.assertEquals(#biomes.F.rooms.lookup.F_Combat02.exits, 2)
        lu.assertEquals(#biomes.G.rooms.lookup.G_Combat02.exits, 3)
        lu.assertEquals(#biomes.G.rooms.lookup.G_MiniBoss02.exits, 1)
        lu.assertEquals(#biomes.G.rooms.lookup.G_MiniBoss03.exits, 2)
        lu.assertEquals(#biomes.H.rooms.lookup.H_Intro.exits, 1)
        lu.assertEquals(#biomes.H.rooms.lookup.H_Combat01.exits, 1)
        lu.assertEquals(#biomes.H.rooms.lookup.H_MiniBoss02.exits, 1)
        lu.assertEquals(#biomes.I.rooms.lookup.I_Combat01.exits, 2)
        lu.assertEquals(#biomes.I.rooms.lookup.I_Combat02.exits, 1)

        for _, room in ipairs(biomes.O.rooms.ordered) do
            if room.key ~= "O_PreBoss01" then
                lu.assertEquals(#room.exits, 1, room.key)
            end
        end
        lu.assertEquals(#biomes.P.rooms.lookup.P_Intro.exits, 2)
        lu.assertEquals(biomes.P.rooms.lookup.P_Combat01.exits[1].type, "OlympusIndoorExitDoor")
        lu.assertEquals(biomes.P.rooms.lookup.P_Combat01.exits[2].type, "OlympusOutdoorExitDoor")
        lu.assertEquals(biomes.P.rooms.lookup.P_Combat02.exits[2].type, "OlympusIndoorExitDoor")
        lu.assertEquals(#biomes.Q.rooms.lookup.Q_Intro.exits, 1)
        lu.assertEquals(#biomes.Q.rooms.lookup.Q_Combat03.exits, 2)
        lu.assertEquals(#biomes.Q.rooms.lookup.Q_Combat01.exits, 1)
        lu.assertEquals(#biomes.Q.rooms.lookup.Q_MiniBoss04.exits, 1)

        lu.assertTrue(biomes.P.rooms.lookup.P_PreBoss01.terminal)
        lu.assertEquals(biomes.P.rooms.lookup.P_PreBoss01.exits[1].targetMode, "fixedBoss")
        lu.assertEquals(biomes.P.batchRuleKey, "Standard")
    end)
end

function TestCatalogFoundation.testExecutableExitAuditCoversAllVariableExitFamilies()
    h.withImport(function()
        local biomes = loadCatalog().biomes.lookup
        assertExitCounts(biomes.F, 1, { "F_Combat01", "F_Combat09", "F_Combat10" })
        for number = 1, 22 do
            local key = string.format("F_Combat%02d", number)
            if number ~= 1 and number ~= 9 and number ~= 10 then
                assertExitCounts(biomes.F, 2, { key })
            end
        end

        local gThree = { [2] = true, [3] = true, [5] = true, [9] = true, [14] = true, [15] = true, [17] = true, [18] = true, [20] = true }
        for number = 1, 20 do
            local key = string.format("G_Combat%02d", number)
            assertExitCounts(biomes.G, gThree[number] and 3 or 2, { key })
        end

        assertExitCounts(biomes.H, 1, { "H_Combat01" })
        for number = 2, 15 do
            assertExitCounts(biomes.H, 2, { string.format("H_Combat%02d", number) })
        end

        local iTwo = { [1] = true, [3] = true, [4] = true, [9] = true, [10] = true, [11] = true, [12] = true, [15] = true, [18] = true, [21] = true, [22] = true }
        for number = 1, 24 do
            assertExitCounts(biomes.I, iTwo[number] and 2 or 1, { string.format("I_Combat%02d", number) })
        end

        for number = 1, 23 do
            assertExitCounts(biomes.N, 1, { string.format("N_Combat%02d", number) })
        end
        for number = 1, 15 do
            assertExitCounts(biomes.O, 1, { string.format("O_Combat%02d", number) })
        end
        for number = 1, 19 do
            assertExitCounts(biomes.P, 2, { string.format("P_Combat%02d", number) })
        end

        assertExitCounts(biomes.Q, 2, { "Q_Combat03", "Q_Combat05", "Q_Combat12", "Q_Combat13", "Q_Combat14", "Q_Combat15" })
        assertExitCounts(biomes.Q, 1, {
            "Q_Combat01", "Q_Combat02", "Q_Combat04", "Q_Combat06", "Q_Combat07", "Q_Combat08", "Q_Combat09", "Q_Combat16",
        })
    end)
end

function TestCatalogFoundation.testCreationAndAppearanceCapsStayDistinct()
    h.withImport(function()
        local catalog = loadCatalog()
        for _, biome in ipairs(catalog.biomes.ordered) do
            for _, room in ipairs(biome.rooms.ordered) do
                if room.kind == "Combat" then
                    if biome.key == "N" then
                        lu.assertNil(room.caps.maxAppearancesThisBiome, room.key)
                    else
                        lu.assertEquals(room.caps.maxAppearancesThisBiome, 1, room.key)
                    end
                    lu.assertNil(room.caps.maxCreationsThisRun, room.key)
                end
            end
        end
        lu.assertEquals(catalog.biomes.lookup.F.rooms.lookup.F_Story01.caps.maxCreationsThisRun, 1)
        lu.assertEquals(catalog.biomes.lookup.F.rooms.lookup.F_MiniBoss01.caps.maxAppearancesThisBiome, 1)

        local gShop = catalog.biomes.lookup.G.rooms.lookup.G_Shop01
        lu.assertEquals(gShop.force, { kind = "depthWindow", axis = "biomeDepthCache", start = 3, deadline = 6 })
        lu.assertEquals(gShop.eligibility.requirements[1].range.max, 5)
    end)
end

function TestCatalogFoundation.testLocalChildrenStayParentScoped()
    h.withImport(function()
        local catalog = loadCatalog()
        local n = catalog.biomes.lookup.N
        lu.assertEquals(#n.rooms.lookup.N_Combat01.localChildren, 0)
        lu.assertEquals(#n.rooms.lookup.N_Combat05.localChildren, 3)
        lu.assertEquals(n.rooms.lookup.N_Combat05.localChildren[1].gameRoomKey, "N_Sub02")
        lu.assertEquals(n.rooms.lookup.N_Combat22.localChildren[2].gameRoomKey, "N_Sub02")
        lu.assertEquals(n.rooms.lookup.N_Combat22.localChildren[1].rewardSurfaceKey, "SubRoomHardReward")
        lu.assertNil(catalog.controlManifest.rooms.lookup.Surface_N_Sub02)

        local descriptor = catalog.controlManifest.rooms.lookup.Surface_N_Combat05
        lu.assertEquals(#descriptor.localSlots, 3)
        lu.assertEquals(descriptor.localSlots[1].key, "sideDoor1")

        local hRoom = catalog.biomes.lookup.H.rooms.lookup.H_Combat01
        lu.assertEquals(#hRoom.localChildren, 3)
        lu.assertEquals(hRoom.metadata.maxCageRewards, 5)
        lu.assertEquals(hRoom.metadata.effectiveMaxCageRewards, 3)

        for number = 1, 15 do
            local roomKey = string.format("O_Combat%02d", number)
            local controlKey = "Surface_" .. roomKey
            local oRoom = catalog.biomes.lookup.O.rooms.lookup[roomKey]
            lu.assertEquals(#oRoom.localChildren, 0, roomKey)
            lu.assertEquals(oRoom.rewardSurfaceKey, "None", roomKey)
            lu.assertEquals(catalog.controlManifest.rooms.lookup[controlKey].localSlots, {
                { key = "wheel1", kind = "offerPoint", phaseKey = "Combat1" },
                { key = "wheel2", kind = "offerPoint", phaseKey = "Combat2" },
            }, controlKey)
        end
    end)
end

function TestCatalogFoundation.testSpecializedBiomeDeclarationsAreFiniteAndConcrete()
    h.withImport(function()
        local catalog = loadCatalog()
        local hBiome = catalog.biomes.lookup.H
        local iBiome = catalog.biomes.lookup.I
        local nBiome = catalog.biomes.lookup.N
        local qBiome = catalog.biomes.lookup.Q

        lu.assertEquals(hBiome.batchRuleKey, "FieldsCageBatch")
        lu.assertEquals(hBiome.topologyBounds.maxLocalChildrenPerRoom, 3)
        lu.assertEquals(iBiome.batchRuleKey, "ClockworkDoorBatch")
        lu.assertEquals(iBiome.biomeState.maxNonGoalRewards.values, { 3, 4, 5, 6 })
        lu.assertEquals(nBiome.batchRuleKey, "EphyraHubBatch")
        lu.assertEquals(nBiome.biomeState.hubDoorCount.values, { 9, 10 })
        lu.assertEquals(nBiome.biomeState.visitedTargetCount.value, 6)
        lu.assertEquals(qBiome.specializedBatchRuleKeys, { "QMinibossBatch" })
        lu.assertEquals(qBiome.deterministicPairs[1].roomKeys, { "Q_MiniBoss02", "Q_MiniBoss05" })
        lu.assertEquals(qBiome.deterministicPairs[2].roomKeys, { "Q_MiniBoss03", "Q_MiniBoss04" })
    end)
end

function TestCatalogFoundation.testRouteRelevantRequirementsRemainTypedAndPhaseBound()
    h.withImport(function()
        local biomes = loadCatalog().biomes.lookup
        assertEnteredRoomExclusion(biomes.G.rooms.lookup.G_MiniBoss01, {
            "G_MiniBoss02", "G_MiniBoss03",
        })
        assertEnteredRoomExclusion(biomes.G.rooms.lookup.G_MiniBoss02, {
            "G_MiniBoss01", "G_MiniBoss03",
        })
        assertEnteredRoomExclusion(biomes.G.rooms.lookup.G_MiniBoss03, {
            "G_MiniBoss01", "G_MiniBoss02",
        })

        lu.assertEquals(biomes.I.rooms.lookup.I_Combat01.eligibility.kind, "ClockworkCapacity")
        lu.assertNil(biomes.I.rooms.lookup.I_Combat02.eligibility)

        lu.assertEquals(biomes.N.rooms.lookup.N_Combat01.eligibility.kind, "BiomeRoomCreatedAny")
        lu.assertEquals(biomes.O.rooms.lookup.O_Combat01.eligibility.kind, "RecentEncounterPhaseCount")
        lu.assertEquals(biomes.O.rooms.lookup.O_Combat01.eligibility.profileKey, "ShipCombat")
        lu.assertEquals(biomes.O.rooms.lookup.O_Combat01.eligibility.phaseKey, "Intro")
        lu.assertEquals(biomes.O.rooms.lookup.O_Combat04.eligibility.kind, "All")
        lu.assertEquals(biomes.O.rooms.lookup.O_Combat04.eligibility.requirements[2].kind, "RecentEncounterPhaseCount")
        lu.assertEquals(biomes.O.rooms.lookup.O_Devotion01.eligibility.requirements[2].kind, "PriorDistinctLootSources")
        lu.assertEquals(biomes.O.rooms.lookup.O_Story01.force.kind, "requirement")
        lu.assertEquals(biomes.O.rooms.lookup.O_Shop01.force.kind, "requirement")

        lu.assertEquals(biomes.Q.rooms.lookup.Q_Combat01.eligibility.range, { maxExclusive = 7 })
        lu.assertEquals(biomes.Q.rooms.lookup.Q_Combat03.eligibility.range, { min = 2 })
        lu.assertEquals(biomes.Q.rooms.lookup.Q_Combat03.force, {
            kind = "depthWindow", axis = "biomeDepthCache", start = 2, deadline = 2,
        })
    end)
end

function TestCatalogFoundation.testRewardCatalogPreservesCountedEntriesAndTypedSurfaces()
    h.withImport(function()
        lu.assertNil(h.rawDeclarations().rewards.normalizedAcquisitions)
        local rewards = loadCatalog().rewards
        lu.assertEquals(#rewards.bags.lookup.RunProgress.entries, 18)
        lu.assertEquals(#rewards.bags.lookup.MetaProgress.entries, 13)
        lu.assertEquals(rewards.bags.lookup.RunProgress.entries[7].requirementKey, "HammerLootRequirements")
        lu.assertEquals(rewards.bags.lookup.RunProgress.entries[8].requirementKey, "LateHammerLootRequirements")
        lu.assertEquals(rewards.stores.lookup.RunProgress.options, {
            "Boon", "HermesUpgrade", "Devotion", "WeaponUpgrade", "MaxHealthDrop",
            "MaxManaDrop", "RoomMoneyDrop", "StackUpgrade", "SpellDrop", "TalentDrop",
        })
        lu.assertEquals(rewards.normalizedAcquisitions.WeaponUpgradeDrop, "WeaponUpgrade")
        lu.assertEquals(rewards.primitives.lookup.Devotion.payloadDomain, "DevotionPair")
        lu.assertEquals(rewards.surfaces.lookup.FieldsCages.maxSlots, 3)
        lu.assertEquals(rewards.surfaces.lookup.FieldsCages.constraints, {
            "UniqueNonBoonRewardTypes", "UniqueBoonSources",
        })
        lu.assertEquals(rewards.surfaces.lookup.ClockworkGoalOrTartarus.kinds[1].rewardType, "ClockworkGoal")
        lu.assertEquals(#rewards.shops.profiles.lookup.Q_WorldShop.slots, 6)
        lu.assertEquals(rewards.shops.profiles.lookup.Q_WorldShop.constraintKeys, { "QWorldShopPrimaryUnique" })
    end)
end

function TestCatalogFoundation.testCompatibleCapacityUsesMatchingNotRawTotals()
    h.withImport(function()
        local catalog = loadCatalog()
        local expectedDemand = {
            F_StandardCombat = 19,
            G_StandardCombat = 19,
            H_FieldsCombat_Cage2 = 3,
            H_FieldsCombat_Cage3 = 8,
            I_ClockworkCombat = 22,
            O_ShipCombat = 6,
            P_IndoorCombat = 9,
            P_OutdoorCombat = 10,
            Q_OneExitCombat = 8,
            Q_TwoExitCombat = 6,
        }
        local seen = {}
        for _, biome in ipairs(catalog.biomes.ordered) do
            for _, audit in ipairs(biome.capacityAudit) do
                seen[audit.familyKey] = true
                lu.assertEquals(audit.scope, "static")
                lu.assertEquals(audit.demand, expectedDemand[audit.familyKey], audit.familyKey)
                lu.assertEquals(audit.matched, audit.demand, audit.familyKey)
                lu.assertTrue(audit.candidateCount >= audit.matched, audit.familyKey)
                if biome.key == "I" then
                    lu.assertEquals(audit.excludedDynamicKinds, { "ClockworkCapacity" })
                elseif biome.key == "O" then
                    lu.assertEquals(audit.excludedDynamicKinds, { "RecentEncounterPhaseCount" })
                else
                    lu.assertEquals(audit.excludedDynamicKinds, {})
                end
            end
        end
        for familyKey in pairs(expectedDemand) do
            lu.assertTrue(seen[familyKey], "missing audit for " .. familyKey)
        end
    end)
end

function TestCatalogFoundation.testLoaderDoesNotMutateRawDeclarations()
    h.withImport(function()
        local raw = h.rawDeclarations()
        lu.assertNil(raw.biomes[1].rooms.lookup)
        lu.assertNil(raw.roomTemplates.StandardCombat.key)
        local catalog = loadCatalog(raw)
        lu.assertNotNil(catalog.biomes.lookup.F.rooms.lookup.F_Combat01)
        lu.assertNil(raw.biomes[1].rooms.lookup)
        lu.assertNil(raw.roomTemplates.StandardCombat.key)
    end)
end

function TestCatalogFoundation.testRejectsUnknownOrWrongPhaseRequirementsAtCatalogBoundary()
    h.withImport(function()
        local raw = h.rawDeclarations()
        raw.biomes[1].rooms[1].eligibility = {
            kind = "MysteryPredicate",
            phase = "room.generate_next",
        }
        assertFails(function() loadCatalog(raw) end, "unknown modeled requirement kind 'MysteryPredicate'")

        raw = h.rawDeclarations()
        raw.biomes[1].rooms[1].eligibility = {
            kind = "CounterRange",
            phase = "reward.acquire",
            axis = "biomeDepthCache",
            range = { min = 1 },
        }
        assertFails(function() loadCatalog(raw) end, "has no evaluator at phase 'reward.acquire'")

        raw = h.rawDeclarations()
        findRawRoom(raw, "F", "F_Combat01").eligibility.phase = "reward.offer"
        assertFails(
            function() loadCatalog(raw) end,
            "requirement phase 'reward.offer' must match contact phase 'room.generate_next'"
        )

        raw = h.rawDeclarations()
        findRawRoom(raw, "I", "I_PreBoss01").force.requirement = {
            kind = "CounterRange",
            phase = "reward.offer",
            axis = "biomeDepthCache",
            range = { min = 1 },
            code = "wrong_force_contact_phase",
        }
        assertFails(
            function() loadCatalog(raw) end,
            "requirement phase 'reward.offer' must match contact phase 'room.generate_next'"
        )

        raw = h.rawDeclarations()
        raw.requirements.named.RoomPhaseForBag = {
            kind = "CounterRange",
            phase = "room.generate_next",
            axis = "biomeDepthCache",
            range = { min = 1 },
            code = "wrong_bag_contact_phase",
        }
        raw.rewards.bags.RunProgress.entries[1].requirementKey = "RoomPhaseForBag"
        assertFails(
            function() loadCatalog(raw) end,
            "requirement phase 'room.generate_next' must match contact phase 'reward.offer'"
        )
    end)
end

function TestCatalogFoundation.testRejectsUnknownRequirementReferencesAtCatalogBoundary()
    h.withImport(function()
        local raw = h.rawDeclarations()
        local requirement = findRequirement(
            findRawRoom(raw, "F", "F_MiniBoss01").eligibility,
            "RoomEnteredCount"
        )
        requirement.roomKeys = { "F_MiniBoss99" }
        assertFails(function() loadCatalog(raw) end, "unknown room 'F_MiniBoss99'")

        raw = h.rawDeclarations()
        raw.requirements.named.DevotionLootRequirements.requirements[5].exceptBiomeKeys = { "MissingBiome" }
        assertFails(function() loadCatalog(raw) end, "unknown biome 'MissingBiome'")

        raw = h.rawDeclarations()
        raw.requirements.named.HammerLootRequirements.requirements[1].rewardType = "MissingReward"
        assertFails(function() loadCatalog(raw) end, "unknown reward primitive 'MissingReward'")

        raw = h.rawDeclarations()
        requirement = findRequirement(
            findRawRoom(raw, "I", "I_Reprieve01").eligibility,
            "RequiredOfferedPeer"
        )
        requirement.roomSetKey = "MissingRoomSet"
        assertFails(function() loadCatalog(raw) end, "unknown biome room set 'MissingRoomSet'")

        raw = h.rawDeclarations()
        requirement = findRequirement(
            findRawRoom(raw, "H", "H_Bridge01").eligibility,
            "EnteredKindCount"
        )
        requirement.roomKinds = { "MissingRoomKind" }
        assertFails(function() loadCatalog(raw) end, "unknown room kind 'MissingRoomKind'")

        raw = h.rawDeclarations()
        raw.requirements.named.DevotionLootRequirements.requirements[3].sourceDomain = "MissingSourceDomain"
        assertFails(function() loadCatalog(raw) end, "unknown value 'MissingSourceDomain'")

        raw = h.rawDeclarations()
        findRawRoom(raw, "I", "I_Combat01").eligibility.counter = "missingCounter"
        assertFails(function() loadCatalog(raw) end, "unknown value 'missingCounter'")
    end)
end

function TestCatalogFoundation.testRejectsMalformedRoomAndRewardFixturesAtCatalogBoundary()
    h.withImport(function()
        local raw = h.rawDeclarations()
        raw.mysteryCatalog = {}
        assertFails(function() loadCatalog(raw) end, "catalog.mysteryCatalog: unexpected field")

        raw = h.rawDeclarations()
        raw.roomTemplates.StandardCombat.key = "OtherTemplate"
        assertFails(
            function() loadCatalog(raw) end,
            "roomTemplates.StandardCombat.key: keyed catalog identity is derived from the map key"
        )

        raw = h.rawDeclarations()
        raw.biomes[1].rooms[4].templateKey = "MissingTemplate"
        assertFails(function() loadCatalog(raw) end, "unknown room template 'MissingTemplate'")

        raw = h.rawDeclarations()
        raw.biomes[1].rooms[4].caps.maxCreationsThisRun = 1
        assertFails(function() loadCatalog(raw) end, "ordinary combat canonicalization must not be encoded as a creation cap")

        raw = h.rawDeclarations()
        raw.biomes[1].rooms[4].rewardSurfaceKey = "MissingSurface"
        assertFails(function() loadCatalog(raw) end, "unknown reward surface 'MissingSurface'")

        raw = h.rawDeclarations()
        raw.rewards.bags.RunProgress.entries[1].rewardType = "MissingReward"
        assertFails(function() loadCatalog(raw) end, "unknown reward primitive 'MissingReward'")

        raw = h.rawDeclarations()
        raw.rewards.normalizedAcquisitions = { WeaponUpgradeDrop = "Boon" }
        assertFails(function() loadCatalog(raw) end, "rewards.normalizedAcquisitions: unexpected field")
    end)
end

function TestCatalogFoundation.testRejectsMissingExplicitRoomFactsAtCatalogBoundary()
    h.withImport(function()
        local requiredFacts = {
            { key = "tags", error = ".tags: expected an explicit table" },
            { key = "exits", error = ".exits: expected an explicit table" },
            { key = "rewardSurfaceKey", error = ".rewardSurfaceKey: expected a non-empty string" },
            { key = "encounterProfileKey", error = ".encounterProfileKey: expected a non-empty string" },
            { key = "counters", error = ".counters: expected an explicit table" },
            { key = "caps", error = ".caps: expected an explicit table" },
            { key = "terminal", error = ".terminal: expected an explicit boolean" },
            { key = "fixed", error = ".fixed: expected an explicit boolean" },
            { key = "localChildren", error = ".localChildren: expected an explicit table" },
        }
        for _, fact in ipairs(requiredFacts) do
            local raw = h.rawDeclarations()
            raw.biomes[1].rooms[4][fact.key] = nil
            assertFails(function() loadCatalog(raw) end, fact.error)
        end

        local raw = h.rawDeclarations()
        raw.biomes[1].rooms[4].counters.biomeEncounterDepth = 1
        assertFails(function() loadCatalog(raw) end, ".counters.biomeEncounterDepth: unexpected field")
    end)
end

function TestCatalogFoundation.testEncounterProfilesOwnBaselineEncounterDepthEffects()
    h.withImport(function()
        local catalog = loadCatalog()
        for _, biome in ipairs(catalog.biomes.ordered) do
            for _, room in ipairs(biome.rooms.ordered) do
                lu.assertNil(room.counters.biomeEncounterDepth, room.key)
            end
        end

        local profiles = catalog.encounterProfiles.lookup
        lu.assertEquals(profiles.F_Opening.phases, {
            { key = "OpeningGeneratedF", kind = "combat", countsEncounterDepth = true },
        })
        lu.assertEquals(profiles.N_Opening.phases, {
            { key = "OpeningGeneratedN", kind = "combat", countsEncounterDepth = true },
        })
        lu.assertFalse(profiles.FixedPreHub.phases[1].countsEncounterDepth)
        lu.assertTrue(profiles.G_MiniBoss03.phases[1].countsEncounterDepth)

        local ship = profiles.ShipCombat
        lu.assertEquals(ship.kind, "sequence")
        lu.assertEquals(#ship.phases, 3)
        lu.assertEquals(ship.phases[1].baselineEncounterKey, "GeneratedO_Intro01")
        lu.assertEquals(ship.phases[2].baselineEncounterKey, "GeneratedO")
        lu.assertEquals(ship.phases[3].baselineEncounterKey, "GeneratedO")
        lu.assertEquals(ship.phases[2].offerPoint, {
            key = "wheel1",
            surfaceKey = "ShipWheel",
            offerCount = { min = 1, max = 2 },
            picked = "exactlyOne",
            offerTiming = "encounterStart",
            acquisitionTiming = "postCombat",
        })
        lu.assertEquals(ship.phases[3].presence.kind, "authoredOptional")
        lu.assertEquals(ship.phases[3].presence.eligibilitySnapshot, "room.prepare_encounters")
        lu.assertEquals(ship.phases[3].presence.requirement.phase, "room.prepare_encounters")
        lu.assertNil(catalog.biomes.lookup.O.rooms.lookup.O_Combat04.metadata)
    end)
end

function TestCatalogFoundation.testRejectsMalformedRequirementsAndRegistryDiscriminators()
    h.withImport(function()
        local raw = h.rawDeclarations()
        raw.requirements.mystery = {}
        assertFails(function() loadCatalog(raw) end, "requirements.mystery: unexpected field")

        raw = h.rawDeclarations()
        raw.biomes[1].rooms[4].eligibility.range = nil
        assertFails(function() loadCatalog(raw) end, ".eligibility.range: expected a table")

        raw = h.rawDeclarations()
        raw.biomes[1].rooms[1].eligibility = {
            kind = "All", phase = "room.generate_next", requirements = {},
        }
        assertFails(function() loadCatalog(raw) end, ".eligibility.requirements: must not be empty")

        raw = h.rawDeclarations()
        raw.rewards.surfaces.None.kind = "mystery"
        assertFails(function() loadCatalog(raw) end, "rewards.surfaces.None.kind: unknown value 'mystery'")

        raw = h.rawDeclarations()
        raw.biomes[1].root.mode = "mystery"
        assertFails(function() loadCatalog(raw) end, ".root.mode: unknown value 'mystery'")

        raw = h.rawDeclarations()
        raw.batchRules.Standard.picked = "mystery"
        assertFails(function() loadCatalog(raw) end, "batchRules.Standard.picked: unknown value 'mystery'")

        raw = h.rawDeclarations()
        raw.routes[1].biomeSteps = {}
        assertFails(function() loadCatalog(raw) end, "routes.Underworld.biomeSteps: must not be empty")

        raw = h.rawDeclarations()
        findRawRoom(raw, "Q", "Q_Combat03").force.axis = "mysteryDepth"
        assertFails(function() loadCatalog(raw) end, ".force.axis: unknown value 'mysteryDepth'")
    end)
end

function TestCatalogFoundation.testRejectsMalformedEncounterProfilesAndLocalChildren()
    h.withImport(function()
        local raw = h.rawDeclarations()
        raw.encounterProfiles.ShipCombat.phases[2].countsEncounterDepth = nil
        assertFails(function() loadCatalog(raw) end, ".countsEncounterDepth: expected an explicit boolean")

        raw = h.rawDeclarations()
        raw.encounterProfiles.F_Opening.kind = "mystery"
        assertFails(function() loadCatalog(raw) end, "unknown encounter-profile kind 'mystery'")

        raw = h.rawDeclarations()
        raw.encounterProfiles.ShipCombat.phases[3].presence.eligibilitySnapshot = "room.encounters"
        assertFails(function() loadCatalog(raw) end, ".eligibilitySnapshot: unknown value 'room.encounters'")

        raw = h.rawDeclarations()
        raw.encounterProfiles.ShipCombat.phases[2].offerPoint.surfaceKey = "MissingSurface"
        assertFails(function() loadCatalog(raw) end, "unknown reward surface 'MissingSurface'")

        raw = h.rawDeclarations()
        raw.encounterProfiles.ShipCombat.phases[1].baselineEncounterKey = ""
        assertFails(function() loadCatalog(raw) end, ".baselineEncounterKey: expected a non-empty string")

        raw = h.rawDeclarations()
        raw.biomes[6].rooms[2].eligibility.phaseKey = "MissingPhase"
        assertFails(function() loadCatalog(raw) end, "unknown phase 'MissingPhase' in encounter profile 'ShipCombat'")

        raw = h.rawDeclarations()
        raw.encounterProfiles.ShipCombat.phases[2].offerPoint.offerCount.max = 0
        assertFails(function() loadCatalog(raw) end, ".offerCount.max: expected an integer >= 1")

        raw = h.rawDeclarations()
        raw.encounterProfiles.ShipCombat.phases[3].offerPoint.key = "wheel1"
        assertFails(function() loadCatalog(raw) end, "duplicate offer-point key 'wheel1'")

        raw = h.rawDeclarations()
        raw.biomes[5].rooms[5].localChildren[1].ordinal = 2
        assertFails(function() loadCatalog(raw) end, ".ordinal: must preserve local-child order")
    end)
end

function TestCatalogFoundation.testRejectsMalformedNestedRewardsAndSpecializedBiomeFacts()
    h.withImport(function()
        local raw = h.rawDeclarations()
        raw.rewards.primitives.Boon.mystery = true
        assertFails(function() loadCatalog(raw) end, "rewards.primitives.Boon.mystery: unexpected field")

        raw = h.rawDeclarations()
        raw.rewards.payloadDomains.BoonSource.mystery = true
        assertFails(function() loadCatalog(raw) end, "rewards.payloadDomains.BoonSource.mystery: unexpected field")

        raw = h.rawDeclarations()
        raw.rewards.bags.RunProgress.entries[1].mystery = true
        assertFails(function() loadCatalog(raw) end, ".entries[1].mystery: unexpected field")

        raw = h.rawDeclarations()
        raw.rewards.batchConstraints.UniqueBoonSources.mystery = true
        assertFails(function() loadCatalog(raw) end, ".UniqueBoonSources.mystery: unexpected field")

        raw = h.rawDeclarations()
        raw.rewards.shops.optionSets.WorldShopBoon[2] = nil
        assertFails(function() loadCatalog(raw) end, ".WorldShopBoon: expected a dense array")

        raw = h.rawDeclarations()
        raw.rewards.shops.profiles.WorldShop.slots = nil
        assertFails(function() loadCatalog(raw) end, ".WorldShop.slots: expected a table")

        raw = h.rawDeclarations()
        raw.rewards.shops.profiles.WorldShop.slots[2].key = "Boon"
        assertFails(function() loadCatalog(raw) end, "duplicate shop slot key 'Boon'")

        raw = h.rawDeclarations()
        raw.rewards.shops.profiles.Q_WorldShop.slots[1].uniqueGroup = "MissingGroup"
        assertFails(function() loadCatalog(raw) end, "no referenced constraint owns slot group 'MissingGroup'")

        raw = h.rawDeclarations()
        raw.rewards.surfaces.ForcedDevotion.payloadDomain = "DevotionPair"
        assertFails(function() loadCatalog(raw) end, ".ForcedDevotion.payloadDomain: unexpected field")

        raw = h.rawDeclarations()
        raw.rewards.surfaces.RunProgressBoonOnly.eligibleRewardTypes = { "ClockworkGoal" }
        assertFails(function() loadCatalog(raw) end, "is not offered by the referenced stores")

        raw = h.rawDeclarations()
        raw.rewards.surfaces.RunProgressBoonOnly.ineligibleRewardTypes = { "Boon" }
        assertFails(function() loadCatalog(raw) end, "reward primitive 'Boon' is both eligible and ineligible")

        raw = h.rawDeclarations()
        raw.rewards.surfaces.PrebossShopOrFreeReward.branches[2].eligibleRewardTypes = { "ClockworkGoal" }
        assertFails(function() loadCatalog(raw) end, "is not offered by the referenced stores")

        raw = h.rawDeclarations()
        raw.rewards.surfaces.PrebossShopOrFreeReward.branches[2].ineligibleRewardTypes = { "MissingReward" }
        assertFails(function() loadCatalog(raw) end, "unknown reward primitive 'MissingReward'")

        raw = h.rawDeclarations()
        raw.rewards.surfaces.ClockworkGoalOrTartarus.kinds[2].storeKeys = { "MissingStore" }
        assertFails(function() loadCatalog(raw) end, "unknown reward store 'MissingStore'")

        raw = h.rawDeclarations()
        raw.rewards.surfaces.ClockworkGoalOrTartarus.kinds[2].storeKeys = nil
        assertFails(function() loadCatalog(raw) end, "incoming kind requires either rewardType or storeKeys")

        raw = h.rawDeclarations()
        raw.biomes[3].rooms[2].metadata.effectiveMaxCageRewards = 6
        assertFails(function() loadCatalog(raw) end, "effective cage-reward maximum must not exceed physical maximum")

        raw = h.rawDeclarations()
        raw.biomes[4].biomeState.maxNonGoalRewards.values[1] = "three"
        assertFails(function() loadCatalog(raw) end, "expected an integer >= 1")

        raw = h.rawDeclarations()
        raw.biomes[5].rooms[4].metadata.hubDoorId = raw.biomes[5].rooms[5].metadata.hubDoorId
        assertFails(function() loadCatalog(raw) end, "duplicate physical hub door id")

        raw = h.rawDeclarations()
        raw.biomes[8].deterministicPairs[1].roomKeys[1] = "Q_MissingMiniboss"
        assertFails(function() loadCatalog(raw) end, "unknown deterministic room 'Q_MissingMiniboss'")

        raw = h.rawDeclarations()
        raw.biomes[2].excludedGameRooms = { "I_Shop01" }
        assertFails(function() loadCatalog(raw) end, ".excludedGameRooms: unexpected field")
    end)
end

function TestCatalogFoundation.testStaticCapacityRequiresItsDeclaredProofAxes()
    h.withImport(function()
        local raw = h.rawDeclarations()
        raw.biomes[1].canonicalCapacity[1].contexts[1].biomeEncounterDepth = nil
        assertFails(
            function() loadCatalog(raw) end,
            "capacity context is missing axis 'biomeEncounterDepth'"
        )

        raw = h.rawDeclarations()
        raw.biomes[1].canonicalCapacity[1].candidateConstraints.templateKey = "ShipCombat"
        assertFails(function() loadCatalog(raw) end, "compatible matching covers 0 of 19 maximum-demand slots")

        raw = h.rawDeclarations()
        raw.biomes[1].canonicalCapacity = {}
        assertFails(function() loadCatalog(raw) end, "missing capacity proof for canonical family 'F_StandardCombat'")
    end)
end
