local lu = require("luaunit")
local h = require("tests.support.control_harness")
local normalizeRewardRows = h.normalizeRewardRows
local loadCatalog = h.loadCatalog
local loadFixedLinearTemplate = h.loadFixedLinearTemplate
local loadHubPylonTemplate = h.loadHubPylonTemplate
local loadRouteGlobalTemplate = h.loadRouteGlobalTemplate
local loadRouteNpcsTemplate = h.loadRouteNpcsTemplate
local loadRunContext = h.loadRunContext
local routeDefinitions = h.routeDefinitions
local routeFields = h.routeFields
local npcFields = h.npcFields
local routeUiFields = h.routeUiFields

-- luacheck: globals TestRunPlannerRouteNpcs
TestRunPlannerRouteNpcs = {}

function TestRunPlannerRouteNpcs.testRouteNpcsStorageDerivesSlotsFromDeclarations()
    local catalog = loadCatalog()
    local template = loadRouteNpcsTemplate()
    local underworld = template.prepare({
        name = "RouteNpcsUnderworld",
        route = catalog.routes.lookup.Underworld,
        npcs = catalog.npcs,
        biomeLookup = catalog.lookup,
    })
    local surface = template.prepare({
        name = "RouteNpcsSurface",
        route = catalog.routes.lookup.Surface,
        npcs = catalog.npcs,
        biomeLookup = catalog.lookup,
    })

    lu.assertEquals(underworld.slotCount, 4)
    lu.assertEquals(underworld.slots[1].key, "Artemis")
    lu.assertEquals(underworld.slots[1].label, "Artemis")
    lu.assertEquals(underworld.slots[2].key, "Nemesis")
    lu.assertEquals(underworld.slots[3].key, "Arachne_F")
    lu.assertEquals(underworld.slots[3].label, "Arachne")
    lu.assertEquals(underworld.slots[3].fixedBiomeKey, "F")
    lu.assertEquals(underworld.slots[4].key, "Arachne_G")
    lu.assertEquals(underworld.slots[4].label, "Arachne")

    lu.assertEquals(surface.slotCount, 4)
    lu.assertEquals(surface.slots[1].key, "Artemis")
    lu.assertEquals(surface.slots[2].key, "Heracles")
    lu.assertEquals(surface.slots[3].key, "Icarus")
    lu.assertEquals(surface.slots[4].key, "Athena")

    local storage = template.storage(underworld)
    lu.assertEquals(#storage, 1)
    lu.assertEquals(storage[1].key, "Targets")
    lu.assertEquals(storage[1].type, "table")
    lu.assertEquals(storage[1].minRows, 4)
    lu.assertEquals(storage[1].defaultRows, 4)
    lu.assertEquals(storage[1].maxRows, 4)
    lu.assertEquals(storage[1].row[1].key, "TargetKey")
    lu.assertEquals(storage[1].row[2].key, "VariantKey")
    lu.assertEquals(storage[1].row[3].key, "BiomeKey")
    lu.assertEquals(storage[1].row[4].key, "RowIndex")
end

function TestRunPlannerRouteNpcs.testRouteNpcsUsesBiomeRoomTypeSelection()
    local catalog = loadCatalog()
    local route = {
        key = "Underworld",
        label = "Underworld",
        biomes = { "F" },
    }
    local template = loadRouteNpcsTemplate()
    local instance = template.prepare({
        name = "RouteNpcsUnderworld",
        route = route,
        npcs = catalog.npcs,
        biomeLookup = catalog.lookup,
    })
    local fields = routeUiFields(template.storage(instance))
    local control = template.createRuntime(fields, instance)
    local routeContext = loadRunContext().create({
        routes = routeDefinitions({ route }),
        biomes = catalog.lookup,
        npcs = catalog.npcs,
        controlResolver = function(controlName)
            if controlName == "RouteF" then
                return {
                    read = function(_, path)
                        if path == "snapshot" then
                            return {
                                controlName = "RouteF",
                                valid = true,
                                invalidRows = {},
                                rows = normalizeRewardRows({
                                    {
                                        rowIndex = 3,
                                        routeOrdinal = 5,
                                        slotLabel = "Depth 5",
                                        roleKey = "Combat",
                                        option = { key = "F_Combat04", label = "C04" },
                                        valid = true,
                                        rewardKind = "majorMinor",
                                        rewards = { "Major", "MaxHealthDrop" },
                                    },
                                    {
                                        rowIndex = 4,
                                        routeOrdinal = 6,
                                        slotLabel = "Depth 6",
                                        roleKey = "Combat",
                                        valid = true,
                                        rewardKind = "majorMinor",
                                        rewards = { "Major", "MaxHealthDrop" },
                                    },
                                    {
                                        rowIndex = 5,
                                        routeOrdinal = 7,
                                        slotLabel = "Depth 7",
                                        roleKey = "Combat",
                                        option = { key = "F_Combat05", label = "C05" },
                                        valid = true,
                                        rewardKind = "majorMinor",
                                        rewards = {},
                                    },
                                }),
                            }
                        end
                        return nil
                    end,
                }
            end
            return nil
        end,
    })
    control:setRouteContext(routeContext, "Underworld")

    lu.assertEquals(control:biomeOptions(1).values, { "", "Disabled", "F" })
    lu.assertEquals(control:biomeOptions(1).displayValues[""], "Vanilla")
    lu.assertEquals(control:biomeOptions(1).displayValues.Disabled, "Disabled")
    lu.assertEquals(control:biomeOptions(1).displayValues.F, "Erebus")

    control:writeBiome(1, "Disabled")
    lu.assertEquals(fields.Targets:read(1, "BiomeKey"), "Disabled")
    lu.assertEquals(fields.Targets:read(1, "RowIndex"), "")
    lu.assertEquals(fields.Targets:read(1, "VariantKey"), "")
    lu.assertEquals(fields.Targets:read(1, "TargetKey"), "")
    lu.assertFalse(control:shouldRenderRoom(1))
    lu.assertFalse(control:shouldRenderVariant(1))

    local disabledRow = control:rowSnapshot(1)
    lu.assertTrue(disabledRow.valid)
    lu.assertTrue(disabledRow.disabled)
    lu.assertEquals(disabledRow.mode, "Disabled")
    lu.assertEquals(disabledRow.biomeKey, "")
    lu.assertEquals(disabledRow.targetKey, "")

    control:writeBiome(1, "F")
    lu.assertEquals(fields.Targets:read(1, "BiomeKey"), "F")
    lu.assertEquals(control:roomOptions(1).values, { "", "3" })
    lu.assertEquals(control:roomOptions(1).displayValues["3"], "Depth 5 - C04")

    control:writeRoom(1, "3")
    lu.assertEquals(fields.Targets:read(1, "RowIndex"), "3")
    lu.assertEquals(fields.Targets:read(1, "VariantKey"), "ArtemisCombatF")
    lu.assertEquals(fields.Targets:read(1, "TargetKey"), "F:3:ArtemisCombatF")
    lu.assertEquals(control:selectedTargetKey(1), "F:3:ArtemisCombatF")
    lu.assertFalse(control:shouldRenderVariant(1))

    control:writeBiome(2, "F")
    control:writeRoom(2, "3")
    lu.assertEquals(control:variantOptions(2).values, { "Combat", "Random" })
    lu.assertTrue(control:shouldRenderVariant(2))
    lu.assertEquals(fields.Targets:read(2, "VariantKey"), "Combat")
    lu.assertEquals(control:rowValidation(2).code, "npc_room_occupied")

    control:writeVariant(2, "Random")
    lu.assertEquals(fields.Targets:read(2, "TargetKey"), "F:3:Random")
    lu.assertEquals(control:selectedTargetKey(2), "F:3:Random")
    lu.assertEquals(control:rowValidation(2).code, "npc_room_occupied")
    local npcSnapshot = control:buildSnapshot()
    lu.assertEquals(#npcSnapshot.invalidRows, 2)
    lu.assertEquals(npcSnapshot.invalidRows[1].locationLabel, "Underworld Nemesis")
    lu.assertEquals(npcSnapshot.invalidRows[1].markerKind, "primary")
    lu.assertEquals(npcSnapshot.invalidRows[2].locationLabel, "Underworld Artemis")
    lu.assertEquals(npcSnapshot.invalidRows[2].markerKind, "related")
    lu.assertEquals(control:valueStates(1, "RowIndex")["3"], 2)
    lu.assertEquals(control:valueStates(2, "RowIndex")["3"], 2)
    control:setRouteContext({
        canDecorateLayer = function()
            return false
        end,
    }, "Underworld")
    lu.assertNil(control:valueStates(1, "RowIndex"))

    control:writeBiome(2, "")
    lu.assertEquals(fields.Targets:read(2, "BiomeKey"), nil)
    lu.assertEquals(fields.Targets:read(2, "RowIndex"), nil)
    lu.assertEquals(fields.Targets:read(2, "VariantKey"), nil)
    lu.assertEquals(fields.Targets:read(2, "TargetKey"), nil)
    lu.assertTrue(control:rowValidation(2).valid)
end

function TestRunPlannerRouteNpcs.testRouteInvalidSuppressesNpcDecoration()
    local catalog = loadCatalog()
    local routeContext = loadRunContext().create({
        routes = routeDefinitions({
            {
                key = "Underworld",
                label = "Underworld",
                biomes = { "F" },
            },
        }),
        biomes = catalog.lookup,
        npcs = catalog.npcs,
        controlResolver = function(controlName)
            if controlName == "RouteF" then
                return {
                    read = function(_, path)
                        if path == "snapshot" then
                            return {
                                controlName = "RouteF",
                                valid = false,
                                invalidRows = {
                                    {
                                        biomeKey = "F",
                                        controlName = "RouteF",
                                        rowIndex = 1,
                                        code = "route_invalid",
                                        message = "Route invalid",
                                    },
                                },
                                rows = {},
                            }
                        end
                        return nil
                    end,
                }
            end
            return nil
        end,
    })

    local overview = routeContext:overview("Underworld")

    lu.assertFalse(overview.layerStatus.route.valid)
    lu.assertFalse(overview.layerStatus.npcs.canDecorate)
    lu.assertFalse(routeContext:canDecorateLayer("Underworld", "npcs"))
end

function TestRunPlannerRouteNpcs.testRouteContextBuildsNpcTargetsFromValidCombatRows()
    local catalog = loadCatalog()
    local routeContext = loadRunContext().create({
        routes = routeDefinitions({
            {
                key = "Underworld",
                label = "Underworld",
                biomes = { "F" },
            },
        }),
        biomes = catalog.lookup,
        npcs = catalog.npcs,
        controlResolver = function(controlName)
            if controlName == "RouteF" then
                return {
                    read = function(_, path)
                        if path == "snapshot" then
                            return {
                                controlName = "RouteF",
                                valid = true,
                                invalidRows = {},
                                rows = normalizeRewardRows({
                                    {
                                        rowIndex = 1,
                                        routeOrdinal = 3,
                                        slotLabel = "Depth 3",
                                        roleKey = "Combat",
                                        option = { key = "F_Combat02", label = "C02" },
                                        valid = true,
                                    },
                                    {
                                        rowIndex = 2,
                                        routeOrdinal = 4,
                                        slotLabel = "Depth 4",
                                        roleKey = "Combat",
                                        option = { key = "F_Combat03", label = "C03" },
                                        valid = true,
                                        rewardKind = "majorMinor",
                                        rewards = { "Major", "Boon", "ZeusUpgrade" },
                                    },
                                    {
                                        rowIndex = 3,
                                        routeOrdinal = 5,
                                        slotLabel = "Depth 5",
                                        roleKey = "Combat",
                                        option = { key = "F_Combat04", label = "C04" },
                                        valid = true,
                                        rewardKind = "majorMinor",
                                        rewards = { "Major", "MaxHealthDrop" },
                                    },
                                }),
                            }
                        end
                        return nil
                    end,
                }
            end
            return nil
        end,
    })

    local targets = routeContext:npcTargets("Underworld")

    lu.assertNil(targets.byNpc.Artemis.lookup["F:1:ArtemisCombatF"])
    lu.assertNil(targets.byNpc.Artemis.lookup["F:2:ArtemisCombatF"])
    lu.assertNotNil(targets.byNpc.Artemis.lookup["F:3:ArtemisCombatF"])
    lu.assertEquals(targets.byNpc.Artemis.displayValues["F:3:ArtemisCombatF"], "Erebus Depth 5 - C04")
    lu.assertNotNil(targets.byNpc.Nemesis.lookup["F:3:Combat"])
    lu.assertNotNil(targets.byNpc.Nemesis.lookup["F:3:Random"])
    lu.assertEquals(targets.byNpcBiome.Arachne.F.values, {
        "",
        "F:3:ArachneCombatF",
    })
end

function TestRunPlannerRouteNpcs.testRouteContextDisablesNpcTargetsWhenRewardsAreNotConfigured()
    local catalog = loadCatalog()
    local globalTemplate = loadRouteGlobalTemplate()
    local globalInstance = globalTemplate.prepare({
        name = "RouteGlobalUnderworld",
        route = catalog.routes.lookup.Underworld,
        gods = catalog.gods,
    })
    local globalFields = routeUiFields(globalTemplate.storage(globalInstance))
    globalFields.ConfigureRewards:write(false)
    local globalControl = globalTemplate.createRuntime(globalFields, globalInstance)
    local routeContext = loadRunContext().create({
        routes = routeDefinitions({
            {
                key = "Underworld",
                label = "Underworld",
                biomes = { "F" },
            },
        }),
        biomes = catalog.lookup,
        npcs = catalog.npcs,
        controlResolver = function(controlName)
            if controlName == "RouteGlobalUnderworld" then
                return globalControl
            elseif controlName == "RouteF" then
                return {
                    read = function(_, path)
                        if path == "snapshot" then
                            return {
                                controlName = "RouteF",
                                valid = true,
                                invalidRows = {},
                                rows = normalizeRewardRows({
                                    {
                                        rowIndex = 1,
                                        routeOrdinal = 5,
                                        slotLabel = "Depth 5",
                                        roleKey = "Combat",
                                        option = { key = "F_Combat04", label = "C04" },
                                        valid = true,
                                        rewardKind = "majorMinor",
                                        rewards = { "Major", "Boon", "ZeusUpgrade" },
                                    },
                                }),
                            }
                        end
                        return nil
                    end,
                }
            end
            return nil
        end,
    })

    local targets = routeContext:npcTargets("Underworld")

    lu.assertNil(targets.byNpc.Artemis)
    lu.assertNil(targets.byNpcBiome.Artemis)
end

function TestRunPlannerRouteNpcs.testRouteContextTargetsNemesisOnTartarusRewardCombat()
    local catalog = loadCatalog()
    local route = {
        key = "Underworld",
        label = "Underworld",
        biomes = { "I" },
    }
    local routeContext = loadRunContext().create({
        routes = routeDefinitions({ route }),
        biomes = catalog.lookup,
        npcs = catalog.npcs,
        controlResolver = function(controlName)
            if controlName == "RouteI" then
                return {
                    read = function(_, path)
                        if path == "snapshot" then
                            return {
                                controlName = "RouteI",
                                valid = true,
                                invalidRows = {},
                                rows = normalizeRewardRows({
                                    {
                                        rowIndex = 5,
                                        routeOrdinal = 4,
                                        slotLabel = "Step 4",
                                        roleKey = "RewardCombat",
                                        role = {
                                            npcRoleKeys = { "Combat" },
                                            targetKinds = { combatSlot = true },
                                        },
                                        option = { key = "I_Combat09", label = "C09" },
                                        biomeDepthCache = 4,
                                        biomeEncounterDepth = 4,
                                        valid = true,
                                        rewardKind = "roomStore",
                                        rewardStore = "TartarusRewards",
                                        rewards = { "MaxHealthDrop" },
                                    },
                                }),
                            }
                        end
                        return nil
                    end,
                }
            end
            return nil
        end,
    })

    local targets = routeContext:npcTargets("Underworld")

    lu.assertNotNil(targets.byNpc.Nemesis.lookup["I:5:Combat"])
    lu.assertEquals(targets.byNpc.Nemesis.displayValues["I:5:Combat"], "Tartarus Step 4 - C09 [Combat]")
end

function TestRunPlannerRouteNpcs.testRouteContextUsesRoomHistoryTimelineForNpcTargets()
    local catalog = loadCatalog()
    local hubTemplate = loadHubPylonTemplate()
    local nInstance = hubTemplate.prepare({
        name = "RouteN",
        biome = catalog.lookup.N,
    })
	    local nControl = hubTemplate.createRuntime(routeFields({
	        {},
	        {},
	        {},
	        {
	            RoleKey = "Combat",
	            OptionKey = "N_Combat01",
	            Reward1Key = "MaxHealthDropBig",
	        },
	        {
	            RoleKey = "Combat",
	            OptionKey = "N_Combat02",
	            Reward1Key = "MaxManaDropBig",
	        },
	    }), nInstance)
    local routeContext = loadRunContext().create({
        routes = routeDefinitions({
            {
                key = "Surface",
                label = "Surface",
                biomes = { "N" },
            },
        }),
        biomes = catalog.lookup,
        npcs = catalog.npcs,
        controlResolver = function(controlName)
            if controlName == "RouteN" then
                return nControl
            end
            return nil
        end,
    })

    local targets = routeContext:npcTargets("Surface")

    lu.assertEquals(targets.byNpc.Heracles.lookup["N:4:HeraclesCombatN"].roomHistoryOrdinal, 4)
    lu.assertEquals(targets.byNpc.Heracles.lookup["N:5:HeraclesCombatN"].roomHistoryOrdinal, 6)
end

function TestRunPlannerRouteNpcs.testRouteContextAddsPostBiomeTimelineForNpcSpacing()
    local catalog = loadCatalog()
    local routeContext = loadRunContext().create({
        routes = routeDefinitions({
            {
                key = "Underworld",
                label = "Underworld",
                biomes = { "F", "G" },
            },
        }),
        biomes = catalog.lookup,
        npcs = catalog.npcs,
        controlResolver = function(controlName)
            if controlName == "RouteF" then
                return {
                    read = function(_, path)
                        if path == "snapshot" then
                            return {
                                controlName = "RouteF",
                                valid = true,
                                invalidRows = {},
                                rows = normalizeRewardRows({
                                    {
                                        rowIndex = 1,
	                                        routeOrdinal = 4,
	                                        slotLabel = "Depth 4",
	                                        roleKey = "Combat",
	                                        option = { key = "F_Combat03", label = "Combat F" },
	                                        valid = true,
	                                        rewardKind = "majorMinor",
	                                        rewards = { "Major", "MaxHealthDrop" },
	                                    },
                                }),
                            }
                        end
                        return nil
                    end,
                }
            elseif controlName == "RouteG" then
                return {
                    read = function(_, path)
                        if path == "snapshot" then
                            return {
                                controlName = "RouteG",
                                valid = true,
                                invalidRows = {},
                                rows = normalizeRewardRows({
                                    {
                                        rowIndex = 1,
	                                        routeOrdinal = 4,
	                                        slotLabel = "Depth 4",
	                                        roleKey = "Combat",
	                                        option = { key = "G_Combat03", label = "Combat G" },
	                                        valid = true,
	                                        rewardKind = "majorMinor",
	                                        rewards = { "Major", "MaxHealthDrop" },
	                                    },
                                }),
                            }
                        end
                        return nil
                    end,
                }
            end
            return nil
        end,
    })

    local targets = routeContext:npcTargets("Underworld")

    lu.assertEquals(targets.byNpc.Artemis.lookup["F:1:ArtemisCombatF"].roomHistoryOrdinal, 1)
    lu.assertEquals(targets.byNpc.Artemis.lookup["G:1:ArtemisCombatG"].roomHistoryOrdinal, 4)
end

function TestRunPlannerRouteNpcs.testRouteContextFiltersOlympusNpcsByRoomTag()
    local catalog = loadCatalog()
    local template = loadFixedLinearTemplate()
    local pInstance = template.prepare({
        name = "RouteP",
        biome = catalog.lookup.P,
    })
    local pControl = template.createRuntime(routeFields({
        {},
        { RoleKey = "Combat", OptionKey = "P_Combat02", Reward1Key = "Major", Reward2Key = "MaxHealthDrop" },
        {
            RoleKey = "Combat",
            OptionKey = "P_Combat04",
            SiblingStructureKey = "Combat",
            SiblingRewardClassKey = "Major",
            Reward1Key = "Major",
            Reward2Key = "MaxHealthDrop",
        },
        {
            RoleKey = "Combat",
            OptionKey = "P_Combat07",
            SiblingStructureKey = "Combat",
            SiblingRewardClassKey = "Major",
            Reward1Key = "Major",
            Reward2Key = "MaxHealthDrop",
        },
        {
            RoleKey = "Combat",
            OptionKey = "P_Combat17",
            SiblingStructureKey = "Combat",
            SiblingRewardClassKey = "Major",
            Reward1Key = "Major",
            Reward2Key = "MaxHealthDrop",
        },
    }), pInstance)
    local routeContext = loadRunContext().create({
        routes = routeDefinitions({
            {
                key = "Surface",
                label = "Surface",
                biomes = { "P" },
            },
        }),
        biomes = catalog.lookup,
        npcs = catalog.npcs,
        controlResolver = function(controlName)
            if controlName == "RouteP" then
                return pControl
            end
            return nil
        end,
    })

    local targets = routeContext:npcTargets("Surface")

    lu.assertNotNil(targets.byNpc.Heracles.lookup["P:4:HeraclesCombatP"])
    lu.assertNil(targets.byNpc.Heracles.lookup["P:5:HeraclesCombatP"])
    lu.assertNil(targets.byNpc.Icarus.lookup["P:4:IcarusCombatP"])
    lu.assertNotNil(targets.byNpc.Icarus.lookup["P:5:IcarusCombatP"])
    lu.assertEquals(
        targets.byNpc.Heracles.displayValues["P:4:HeraclesCombatP"],
        "Olympus Depth 3 - C07 (Indoor)"
    )
    lu.assertEquals(
        targets.byNpc.Icarus.displayValues["P:5:IcarusCombatP"],
        "Olympus Depth 4 - C17 (Outdoor)"
    )
end

function TestRunPlannerRouteNpcs.testRouteNpcsSnapshotValidatesTargetsAndSpacing()
    local catalog = loadCatalog()
    local route = {
        key = "Underworld",
        label = "Underworld",
        biomes = { "F" },
    }
    local template = loadRouteNpcsTemplate()
    local instance = template.prepare({
        name = "RouteNpcsUnderworld",
        route = route,
        npcs = catalog.npcs,
        biomeLookup = catalog.lookup,
    })
    local control = template.createRuntime(npcFields({
        {
            VariantKey = "ArtemisCombatF",
            BiomeKey = "F",
            RowIndex = "3",
        },
        {
            VariantKey = "Combat",
            BiomeKey = "F",
            RowIndex = "4",
        },
        {
            VariantKey = "ArachneCombatF",
            BiomeKey = "F",
            RowIndex = "2",
        },
    }), instance)
    local routeContext = loadRunContext().create({
        routes = routeDefinitions({ route }),
        biomes = catalog.lookup,
        npcs = catalog.npcs,
        controlResolver = function(controlName)
            if controlName == "RouteF" then
                return {
                    read = function(_, path)
                        if path == "snapshot" then
                            return {
                                controlName = "RouteF",
                                valid = true,
                                invalidRows = {},
                                rows = normalizeRewardRows({
                                    {
                                        rowIndex = 2,
	                                        routeOrdinal = 4,
	                                        slotLabel = "Depth 4",
	                                        roleKey = "Combat",
	                                        option = { key = "F_Combat03", label = "C03" },
	                                        valid = true,
	                                        rewardKind = "majorMinor",
	                                        rewards = { "Major", "Boon", "ZeusUpgrade" },
                                    },
                                    {
                                        rowIndex = 3,
	                                        routeOrdinal = 5,
	                                        slotLabel = "Depth 5",
	                                        roleKey = "Combat",
	                                        option = { key = "F_Combat04", label = "C04" },
	                                        valid = true,
	                                        rewardKind = "majorMinor",
	                                        rewards = { "Major", "MaxHealthDrop" },
                                    },
                                    {
                                        rowIndex = 4,
	                                        routeOrdinal = 6,
	                                        slotLabel = "Depth 6",
	                                        roleKey = "Combat",
	                                        option = { key = "F_Combat05", label = "C05" },
	                                        valid = true,
	                                        rewardKind = "majorMinor",
                                        rewards = { "Major", "MaxHealthDrop" },
                                    },
                                }),
                            }
                        end
                        return nil
                    end,
                }
            end
            if controlName == "RouteNpcsUnderworld" then
                return control
            end
            return nil
        end,
    })

    control:setRouteContext(routeContext, "Underworld")
    local snapshot = control:buildSnapshot()

    lu.assertFalse(snapshot.valid)
    lu.assertTrue(snapshot.rows[1].valid)
    lu.assertFalse(snapshot.rows[2].valid)
    lu.assertEquals(snapshot.rows[2].invalidCode, "npc_spacing")
    lu.assertFalse(snapshot.rows[3].valid)
    lu.assertEquals(snapshot.rows[3].invalidCode, "npc_target_unavailable")

    local routeSnapshot = routeContext:overview("Underworld")
    lu.assertFalse(routeSnapshot.valid)
    lu.assertEquals(routeSnapshot.invalidRows[1].controlName, "RouteNpcsUnderworld")
    lu.assertEquals(routeSnapshot.invalidRows[1].code, "npc_spacing")
    lu.assertEquals(routeSnapshot.invalidRows[1].locationLabel, snapshot.invalidRows[1].locationLabel)
end
