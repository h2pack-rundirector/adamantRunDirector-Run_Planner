local lu = require("luaunit")
local h = require("tests.support.control_harness")
local testImport = h.testImport
local primaryRewardItem = h.primaryRewardItem
local loadCatalog = h.loadCatalog
local loadFixedLinearTemplate = h.loadFixedLinearTemplate
local loadClockworkGoalTemplate = h.loadClockworkGoalTemplate
local loadRouteGlobalTemplate = h.loadRouteGlobalTemplate
local loadFixedLinearData = h.loadFixedLinearData
local loadRunContext = h.loadRunContext
local routeDefinitions = h.routeDefinitions
local hasValue = h.hasValue
local optionByKey = h.optionByKey
local routeFields = h.routeFields
local routeUiFields = h.routeUiFields
local routeRewardRow = h.routeRewardRow
local fakeRouteControlSnapshot = h.fakeRouteControlSnapshot
local rewardLegalityRouteContext = h.rewardLegalityRouteContext
local fakeTimelineBiome = h.fakeTimelineBiome
local devotionRewardRow = h.devotionRewardRow
local boonRewardRow = h.boonRewardRow
local firstValidDevotionRows = h.firstValidDevotionRows
local valueStates = testImport("mods/route/value_states.lua")

-- luacheck: globals TestRunPlannerRewardPlanning
TestRunPlannerRewardPlanning = {}

local function rewardCandidateControl(kind, values, alias)
    return {
        alias = alias or "Reward1Key",
        kind = kind or "rewardType",
        values = values,
    }
end

local function prebossRewardOffers()
    local choiceGroup = {
        key = "prebossChoice",
        effectTiming = "sameChoiceUnion",
    }
    return {
        {
            address = "prebossShop",
            label = "Shop",
            kind = "shop",
            shopProfile = "WorldShop",
            rewardAliasStart = 1,
            rewardAliasCount = 3,
            rewardGeneration = {
                effectTiming = "afterNextRow",
            },
            rewardChoiceGroup = choiceGroup,
        },
        {
            address = "prebossReward",
            label = "Free Reward",
            kind = "roomStore",
            rewardStore = "RunProgress",
            ineligibleRewardTypes = { "Devotion", "RoomMoneyDrop" },
            rewardAliasStart = 4,
            rewardAliasCount = 2,
            rewardChoiceGroup = choiceGroup,
        },
    }
end

local function prebossRewardRow(rowIndex, rewards)
    return {
        rowIndex = rowIndex,
        routeOrdinal = rowIndex,
        slotLabel = "Preboss",
        roleKey = "Preboss",
        valid = true,
        rewardKind = "preboss",
        rewardOffers = prebossRewardOffers(),
        rewards = rewards,
        rewardPicks = {},
        biomeEncounterDepthCost = 0,
        biomeEncounterDepthCostMin = 0,
        biomeEncounterDepthCostMax = 0,
    }
end

function TestRunPlannerRewardPlanning.testRewardContextStoresCounterOccurrenceAndPendingProvenance()
    local rewardContext = testImport("mods/route/reward_planning/context.lua")
    local ctx = rewardContext.create()
    local rowContext = {
        biomeKey = "F",
        roomHistoryOrdinal = 4,
    }
    local spellEvent = {
        rewardType = "SpellDrop",
    }
    local shopEvent = {
        rewardType = "WeaponUpgradeDrop",
    }
    local laterSpellEvent = {
        rewardType = "SpellDrop",
    }

    rewardContext.applyCounts(ctx, {
        {
            key = "spell",
            scope = "route",
        },
        {
            key = "spell",
            scope = "biome",
        },
    }, rowContext, spellEvent)
    rewardContext.storeRewardOccurrence(ctx, rowContext, spellEvent)
    rewardContext.stagePendingEvent(ctx, rowContext, shopEvent)
    rewardContext.activateStagedPending(ctx)

    lu.assertEquals(rewardContext.counterValue(ctx, "spell", "route", "F"), 1)
    lu.assertEquals(rewardContext.counterValue(ctx, "spell", "biome", "F"), 1)
    lu.assertIs(rewardContext.counterProducerOccurrence(ctx, "spell", "route", "F").ctx, rowContext)
    lu.assertIs(rewardContext.counterProducerOccurrence(ctx, "spell", "route", "F").event, spellEvent)
    lu.assertIs(rewardContext.counterProducerOccurrence(ctx, "spell", "biome", "F").ctx, rowContext)
    lu.assertIs(rewardContext.counterProducerOccurrence(ctx, "spell", "biome", "F").event, spellEvent)
    lu.assertEquals(rewardContext.lastRewardRoomHistoryOrdinal(ctx, "SpellDrop"), 4)
    lu.assertIs(rewardContext.lastRewardOccurrence(ctx, "SpellDrop").ctx, rowContext)
    lu.assertIs(rewardContext.lastRewardOccurrence(ctx, "SpellDrop").event, spellEvent)
    lu.assertTrue(rewardContext.hasPendingOffer(ctx, "WeaponUpgradeDrop"))
    lu.assertIs(rewardContext.pendingOfferOccurrence(ctx, "WeaponUpgradeDrop").ctx, rowContext)
    lu.assertIs(rewardContext.pendingOfferOccurrence(ctx, "WeaponUpgradeDrop").event, shopEvent)

    local snapshot = rewardContext.snapshot(ctx)
    rewardContext.applyCounts(ctx, {
        {
            key = "spell",
            scope = "route",
        },
    }, rowContext, laterSpellEvent)

    lu.assertIs(rewardContext.counterProducerOccurrence(ctx, "spell", "route", "F").event, laterSpellEvent)
    lu.assertIs(rewardContext.counterProducerOccurrence(snapshot, "spell", "route", "F").event, spellEvent)
    lu.assertIs(rewardContext.lastRewardOccurrence(snapshot, "SpellDrop").event, spellEvent)
    lu.assertIs(rewardContext.pendingOfferOccurrence(snapshot, "WeaponUpgradeDrop").event, shopEvent)
end

function TestRunPlannerRewardPlanning.testRewardContextStoresRowGroupProvenance()
    local rewardContext = testImport("mods/route/reward_planning/context.lua")
    local ctx = rewardContext.create()
    local group = {
        key = "N_HubPylons",
    }
    local boonEvent = {
        rewardType = "Boon",
        boonSource = "ZeusUpgrade",
        item = {
            rewardRowGroup = group,
        },
    }

    local rowContext = {
        biomeKey = "N",
        roomHistoryOrdinal = 8,
    }

    rewardContext.storeRewardRowGroupOccurrence(ctx, rowContext, boonEvent)

    lu.assertTrue(rewardContext.rewardRowGroupHasRewardType(ctx, "N_HubPylons", "Boon"))
    lu.assertTrue(rewardContext.rewardRowGroupHasBoonSource(ctx, "N_HubPylons", "ZeusUpgrade"))
    lu.assertIs(rewardContext.rewardRowGroupRewardTypeOccurrence(ctx, "N_HubPylons", "Boon").ctx, rowContext)
    lu.assertIs(rewardContext.rewardRowGroupRewardTypeOccurrence(ctx, "N_HubPylons", "Boon").event, boonEvent)
    lu.assertIs(rewardContext.rewardRowGroupBoonSourceOccurrence(ctx, "N_HubPylons", "ZeusUpgrade").ctx, rowContext)
    lu.assertIs(rewardContext.rewardRowGroupBoonSourceOccurrence(ctx, "N_HubPylons", "ZeusUpgrade").event, boonEvent)

    local snapshot = rewardContext.snapshot(ctx)
    lu.assertIs(rewardContext.rewardRowGroupRewardTypeOccurrence(snapshot, "N_HubPylons", "Boon").event, boonEvent)
    lu.assertIs(rewardContext.rewardRowGroupBoonSourceOccurrence(snapshot, "N_HubPylons", "ZeusUpgrade").event, boonEvent)
end

function TestRunPlannerRewardPlanning.testRewardItemsNormalizeRowRewardMetadata()
    local rewardItems = testImport("mods/route/reward_planning/items.lua")
    local row = {
        rowIndex = 2,
        routeOrdinal = 2,
        slotLabel = "Depth 2",
        rewardKind = "majorMinor",
        rewards = { "Major", "Boon", "ZeusUpgrade" },
        rewardPicks = {
            { kind = "boonSource", value = "ZeusUpgrade" },
        },
        sideRooms = {
            {
                sideIndex = 1,
                rewardKind = "roomStore",
                rewards = { "MaxHealthDrop" },
            },
        },
        encounterRewardLegs = {
            {
                legIndex = 3,
                rewardKind = "roomStore",
                rewards = { "RoomMoneyDrop" },
            },
        },
    }

    rewardItems.attach(row)

    lu.assertEquals(#row.rewardItems, 3)
    lu.assertEquals(row.rewardItems[1].address, "row")
    lu.assertEquals(row.rewardItems[1].rowLabel, "Depth 2")
    lu.assertEquals(row.rewardItems[1].sourceLabel, "Rewards")
    lu.assertEquals(row.rewardItems[1].sourceKind, "row")
    lu.assertEquals(row.rewardItems[1].rewards[2], "Boon")
    lu.assertEquals(row.rewardItems[2].address, "side:1")
    lu.assertEquals(row.rewardItems[2].sourceLabel, "Side Room 1 Reward")
    lu.assertEquals(row.rewardItems[2].sourceKind, "side")
    lu.assertEquals(row.rewardItems[3].address, "encounter:3")
    lu.assertEquals(row.rewardItems[3].sourceLabel, "Combat 3 Reward")
    lu.assertEquals(row.rewardItems[3].sourceKind, "encounter")

    local scratch = {}
    lu.assertIs(rewardItems.collect(row, scratch), scratch)
    lu.assertEquals(#scratch, 3)
    lu.assertEquals(scratch[3].address, "encounter:3")
end

function TestRunPlannerRewardPlanning.testRewardItemsSplitCompositePrebossRewards()
    local rewardItems = testImport("mods/route/reward_planning/items.lua")
    local row = {
        rowIndex = 12,
        routeOrdinal = 11,
        slotLabel = "Preboss",
        rewardKind = "preboss",
        rewardOffers = prebossRewardOffers(),
        rewards = {
            "RandomLoot",
            "ArmorBoost",
            "SpellDrop",
            "Boon",
            "ZeusUpgrade",
        },
        rewardLoot = {
            "DemeterUpgrade",
        },
        rewardPicks = {
            { key = "Boon", kind = "shopOption", alias = "Reward1Key", value = "RandomLoot" },
            { key = "BoonLoot", kind = "boonSource", alias = "Reward1LootKey", value = "DemeterUpgrade" },
            { key = "rewardType", kind = "rewardType", alias = "Reward4Key", value = "Boon" },
            { key = "boonSource", kind = "boonSource", alias = "Reward5Key", value = "ZeusUpgrade" },
        },
    }

    rewardItems.attach(row)

    lu.assertEquals(#row.rewardItems, 2)
    lu.assertEquals(row.rewardItems[1].address, "prebossShop")
    lu.assertEquals(row.rewardItems[1].rewardKind, "shop")
    lu.assertEquals(row.rewardItems[1].rewards[1], "RandomLoot")
    lu.assertEquals(row.rewardItems[1].rewardLoot[1], "DemeterUpgrade")
    lu.assertEquals(#row.rewardItems[1].rewardPicks, 2)
    lu.assertEquals(row.rewardItems[1].rewardChoiceGroup, {
        key = "prebossChoice",
        effectTiming = "sameChoiceUnion",
    })
    lu.assertEquals(row.rewardItems[2].address, "prebossReward")
    lu.assertEquals(row.rewardItems[2].rewardKind, "roomStore")
    lu.assertEquals(row.rewardItems[2].rewards, {
        "Boon",
        "ZeusUpgrade",
    })
    lu.assertEquals(row.rewardItems[2].rewardAliasOffset, 3)
    lu.assertEquals(row.rewardItems[2].rewardStore, "RunProgress")
    lu.assertEquals(#row.rewardItems[2].rewardPicks, 2)
    lu.assertEquals(row.rewardItems[2].rewardChoiceGroup, {
        key = "prebossChoice",
        effectTiming = "sameChoiceUnion",
    })
end

function TestRunPlannerRewardPlanning.testPrebossRewardMarkersUseShiftedAliases()
    local rewardItems = testImport("mods/route/reward_planning/items.lua")
    local semantics = testImport("mods/route/reward_planning/semantics.lua")
    local row = {
        rowIndex = 12,
        routeOrdinal = 11,
        slotLabel = "Preboss",
        rewardKind = "preboss",
        rewardOffers = prebossRewardOffers(),
        rewards = {
            "RandomLoot",
            "ArmorBoost",
            "SpellDrop",
            "Boon",
            "ZeusUpgrade",
        },
        rewardPicks = {
            { key = "rewardType", kind = "rewardType", alias = "Reward4Key", value = "Boon" },
            { key = "boonSource", kind = "boonSource", alias = "Reward5Key", value = "ZeusUpgrade" },
        },
    }

    rewardItems.attach(row)
    local events = semantics.eventsForItem(row.rewardItems[2], row, {})
    local targets = semantics.valueTargetsForEvent(events[1], {})

    lu.assertEquals(targets[1], {
        address = "prebossReward",
        controlAlias = "Reward4Key",
        value = "Boon",
    })
    lu.assertEquals(targets[2], {
        address = "prebossReward",
        controlAlias = "Reward5Key",
        value = "ZeusUpgrade",
    })
end

function TestRunPlannerRewardPlanning.testRouteSnapshotsTreatRewardsAsVanillaWhenRewardsAreNotConfigured()
    local catalog = loadCatalog()
    local globalTemplate = loadRouteGlobalTemplate()
    local fixedTemplate = loadFixedLinearTemplate()
    local globalInstance = globalTemplate.prepare({
        name = "RouteGlobalUnderworld",
        route = catalog.routes.lookup.Underworld,
        gods = catalog.gods,
    })
    local globalFields = routeUiFields(globalTemplate.storage(globalInstance))
    globalFields.ConfigureRewards:write(false)
    local globalControl = globalTemplate.createRuntime(globalFields, globalInstance)
    local fInstance = fixedTemplate.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local fControl = fixedTemplate.createRuntime(routeFields({
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat04",
            Reward1Key = "Major",
            Reward2Key = "Boon",
            Reward3LootKey = "ZeusUpgrade",
        },
    }), fInstance)
    local routeContext = loadRunContext().create({
        routes = routeDefinitions({
            {
                key = "Underworld",
                label = "Underworld",
                biomes = { "F" },
            },
        }),
        controlResolver = function(controlName)
            if controlName == "RouteGlobalUnderworld" then
                return globalControl
            elseif controlName == "RouteF" then
                return fControl
            end
            return nil
        end,
    })
    fControl:setRouteContext(routeContext, "Underworld")

    local row = fControl:rowSnapshot(1)

    lu.assertNil(row.rewardKind)
    lu.assertNil(row.rewards)
    lu.assertNil(row.rewardLoot)
    lu.assertNil(row.rewardPicks)
    lu.assertEquals(primaryRewardItem(row).rewardKind, "vanilla")
    lu.assertEquals(primaryRewardItem(row).rewards, {})
    lu.assertEquals(primaryRewardItem(row).rewardLoot, {})
    lu.assertEquals(primaryRewardItem(row).rewardPicks, {})
end

function TestRunPlannerRewardPlanning.testCombatRewardSurfaceHidesDevotionByDefault()
    local catalog = loadCatalog()
    local template = loadFixedLinearTemplate()
    local instance = template.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
	    local control = template.createRuntime(routeFields({
	            {
	                RoleKey = "",
	            },
	            {
	                RoleKey = "Combat",
	                OptionKey = "F_Combat01",
	            },
	        }), instance)
    local surface = control:rewardSurface(2)

    lu.assertEquals(surface.kind, "majorMinor")
    lu.assertEquals(surface.controls[1].values, { "Major", "Minor" })
    lu.assertFalse(hasValue(surface.controls[2].values, "Devotion"))
    lu.assertTrue(hasValue(surface.controls[2].values, "RoomMoneyDrop"))
    lu.assertTrue(hasValue(surface.controls[4].values, "GiftDrop"))
end

function TestRunPlannerRewardPlanning.testFixedLinearCombatRewardSurfaceMarksDevotionCapableMaps()
    local catalog = loadCatalog()
    local data = loadFixedLinearData()
    local instance = data.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })

    local combatRole = instance.rolesByKey.Combat
    lu.assertNil(optionByKey(combatRole.mapOptions, "F_Combat02").reward)
    lu.assertEquals(optionByKey(combatRole.mapOptions, "F_Combat05").reward, {
        kind = "majorMinor",
        majorRewardStore = "RunProgress",
        minorRewardStore = "MetaProgress",
        allowDevotion = true,
    })
    lu.assertFalse(hasValue(instance.roleValues, "Trial"))
end

function TestRunPlannerRewardPlanning.testRouteContextDevotionRewardUsesPriorUnderworldBiomes()
    local catalog = loadCatalog()
    local fixedTemplate = loadFixedLinearTemplate()
    local fInstance = fixedTemplate.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local fControl = fixedTemplate.createRuntime(routeFields({
        {
            RoleKey = "",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat02",
            Reward1Key = "Major",
            Reward2Key = "Boon",
            Reward3Key = "ZeusUpgrade",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat03",
            Reward1Key = "Major",
            Reward2Key = "Boon",
            Reward3Key = "ApolloUpgrade",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat04",
            Reward1Key = "Major",
            Reward2Key = "MaxHealthDrop",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat06",
            Reward1Key = "Major",
            Reward2Key = "MaxHealthDrop",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat13",
            Reward1Key = "Major",
            Reward2Key = "MaxHealthDrop",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat07",
            Reward1Key = "Major",
            Reward2Key = "MaxHealthDrop",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat05",
            Reward1Key = "Major",
            Reward2Key = "MaxHealthDrop",
        },
    }), fInstance)
    local template = loadClockworkGoalTemplate()
    local iInstance = template.prepare({
        name = "RouteI",
        biome = catalog.lookup.I,
    })
    local iControl = template.createRuntime(routeFields({
        {},
        {
            RoleKey = "Combat",
            OptionKey = "I_Combat01",
        },
        {
            RoleKey = "Combat",
            OptionKey = "I_Combat03",
            Reward1Key = "Devotion",
            Reward3Key = "ZeusUpgrade",
            Reward4Key = "ApolloUpgrade",
        },
    }), iInstance)
    local routeContext = loadRunContext().create({
        routes = routeDefinitions({
            {
                key = "Underworld",
                label = "Underworld",
                biomes = { "F", "I" },
            },
        }),
        controlResolver = function(controlName)
            if controlName == "RouteF" then
                return fControl
            elseif controlName == "RouteI" then
                return iControl
            end
            return nil
        end,
    })

    local overview = routeContext:overview("Underworld")

    lu.assertTrue(overview.valid)
end

function TestRunPlannerRewardPlanning.testRouteContextScopesPriorGodLootByRoute()
    local catalog = loadCatalog()
    local fixedTemplate = loadFixedLinearTemplate()
    local fInstance = fixedTemplate.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local fControl = fixedTemplate.createRuntime(routeFields({
        {},
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat02",
            Reward1Key = "Major",
            Reward2Key = "Boon",
            Reward3Key = "ZeusUpgrade",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat03",
            Reward1Key = "Major",
            Reward2Key = "Boon",
            Reward3Key = "ApolloUpgrade",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat04",
            Reward1Key = "Major",
            Reward2Key = "MaxHealthDrop",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat06",
            Reward1Key = "Major",
            Reward2Key = "MaxHealthDrop",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat13",
            Reward1Key = "Major",
            Reward2Key = "MaxHealthDrop",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat07",
            Reward1Key = "Major",
            Reward2Key = "MaxHealthDrop",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat05",
            Reward1Key = "Major",
            Reward2Key = "MaxHealthDrop",
        },
    }), fInstance)
    local template = loadClockworkGoalTemplate()
    local iInstance = template.prepare({
        name = "RouteI",
        biome = catalog.lookup.I,
    })
    local iControl = template.createRuntime(routeFields({
        {},
        {
            RoleKey = "Combat",
            OptionKey = "I_Combat01",
        },
        {
            RoleKey = "Combat",
            OptionKey = "I_Combat03",
            Reward1Key = "Devotion",
            Reward3Key = "ZeusUpgrade",
            Reward4Key = "ApolloUpgrade",
        },
    }), iInstance)
    local routeContext = loadRunContext().create({
        routes = routeDefinitions({
            {
                key = "WithErebus",
                label = "With Erebus",
                biomes = { "F", "I" },
            },
            {
                key = "TartarusOnly",
                label = "Tartarus Only",
                biomes = { "I" },
            },
        }),
        controlResolver = function(controlName)
            if controlName == "RouteF" then
                return fControl
            elseif controlName == "RouteI" then
                return iControl
            end
            return nil
        end,
    })

    lu.assertFalse(routeContext:overview("TartarusOnly").valid)
    lu.assertEquals(routeContext:rewardRowValidation("TartarusOnly", "I", 3).code, "prior_distinct_god_loot")

    lu.assertTrue(routeContext:overview("WithErebus").valid)
end

function TestRunPlannerRewardPlanning.testRouteContextInvalidatesTalentRewardsBeforeSpellDrop()
    local routeContext = rewardLegalityRouteContext({
        key = "Underworld",
        label = "Underworld",
        biomes = { "F" },
    }, {
        RouteF = fakeRouteControlSnapshot("RouteF", {
            routeRewardRow(1, "TalentDrop"),
            routeRewardRow(2, "MinorTalentDrop"),
            routeRewardRow(3, "SpellDrop"),
            routeRewardRow(4, "TalentBigDrop"),
        }),
    }, {
        biomes = {
            F = { label = "Erebus" },
        },
    })

    local overview = routeContext:overview("Underworld")

    lu.assertFalse(overview.valid)
    lu.assertEquals(#overview.invalidRows, 1)
    lu.assertEquals(overview.invalidRows[1].rowIndex, 1)
    lu.assertEquals(overview.invalidRows[1].address, "row")
    lu.assertEquals(overview.invalidRows[1].rewardType, "TalentDrop")
    lu.assertEquals(overview.invalidRows[1].locationLabel, "Erebus Depth 1 Rewards")
    lu.assertEquals(overview.invalidRows[1].code, "talent_requires_spell")
    lu.assertEquals(routeContext:rewardRowValidation("Underworld", "F", 1).code, "talent_requires_spell")
    lu.assertEquals(routeContext:rewardRowValidation("Underworld", "F", 1).address, "row")
    lu.assertEquals(routeContext:rewardRowValidation("Underworld", "F", 1).rewardType, "TalentDrop")
    lu.assertNil(routeContext:rewardRowValidation("Underworld", "F", 2))
    lu.assertNil(routeContext:rewardRowValidation("Underworld", "F", 4))

    local decision = routeContext:rewardLegality("Underworld").decisionsByBiomeRowAddress.F[1].row
    lu.assertEquals(decision.address, "row")
    lu.assertEquals(decision.selectedEvents[1].rewardType, "TalentDrop")
    lu.assertEquals(decision.selectedInvalid.code, "talent_requires_spell")
end

function TestRunPlannerRewardPlanning.testPrebossSiblingRewardsApplyDedupedUnionDownstream()
    local routeContext = rewardLegalityRouteContext({
        key = "Underworld",
        label = "Underworld",
        biomes = { "F", "G", "H" },
    }, {
        RouteF = fakeRouteControlSnapshot("RouteF", {
            prebossRewardRow(11, {
                nil,
                "WeaponUpgradeDrop",
                nil,
                "WeaponUpgrade",
            }),
        }),
        RouteG = fakeRouteControlSnapshot("RouteG", {}),
        RouteH = fakeRouteControlSnapshot("RouteH", {
            routeRewardRow(1, "WeaponUpgrade", {
                slotLabel = "Depth 1",
            }),
            routeRewardRow(2, "WeaponUpgrade", {
                slotLabel = "Depth 2",
            }),
        }),
    }, {
        biomes = {
            F = { label = "Erebus" },
            G = { label = "Oceanus" },
            H = { label = "Fields" },
        },
    })

    local overview = routeContext:overview("Underworld")

    lu.assertFalse(overview.valid)
    lu.assertNil(routeContext:rewardRowValidation("Underworld", "F", 11))
    lu.assertNil(routeContext:rewardRowValidation("Underworld", "H", 1))
    lu.assertEquals(routeContext:rewardRowValidation("Underworld", "H", 2).code, "weapon_upgrade_run_limit")
    lu.assertEquals(overview.invalidRows[1].biomeKey, "H")
    lu.assertEquals(overview.invalidRows[1].rowIndex, 2)
end

function TestRunPlannerRewardPlanning.testRouteContextMarksInvalidRewardCandidates()
    local control = rewardCandidateControl("rewardType", {
        "",
        "TalentDrop",
        "SpellDrop",
    })
    local routeContext = rewardLegalityRouteContext({
        key = "Underworld",
        label = "Underworld",
        biomes = { "F" },
    }, {
        RouteF = fakeRouteControlSnapshot("RouteF", {
            routeRewardRow(1, "MaxHealthDrop"),
        }),
    })

    local states = routeContext:rewardValueStates("Underworld", "F", 1, "row", "Reward1Key", control)

    lu.assertEquals(states.TalentDrop, valueStates.INVALID)
    lu.assertNil(states.SpellDrop)
    lu.assertIs(states, routeContext:rewardValueStates("Underworld", "F", 1, "row", "Reward1Key", control))
end

function TestRunPlannerRewardPlanning.testRouteContextMarksRelatedRewardParticipantValue()
    local control = rewardCandidateControl("rewardType", {
        "",
        "SpellDrop",
        "MaxHealthDrop",
    })
    local routeContext = rewardLegalityRouteContext({
        key = "Underworld",
        label = "Underworld",
        biomes = { "F" },
    }, {
        RouteF = fakeRouteControlSnapshot("RouteF", {
            routeRewardRow(1, "SpellDrop"),
            routeRewardRow(2, "SpellDrop"),
        }),
    })

    local overview = routeContext:overview("Underworld")

    lu.assertFalse(overview.valid)
    lu.assertEquals(#overview.invalidRows, 2)
    lu.assertEquals(overview.invalidRows[1].rowIndex, 2)
    lu.assertEquals(overview.invalidRows[1].markerKind, "primary")
    lu.assertEquals(overview.invalidRows[1].code, "spell_drop_limit")
    lu.assertEquals(overview.invalidRows[2].rowIndex, 1)
    lu.assertEquals(overview.invalidRows[2].markerKind, "related")
    lu.assertEquals(overview.invalidRows[2].code, "spell_drop_limit")

    local priorStates = routeContext:rewardValueStates("Underworld", "F", 1, "row", "Reward1Key", control)
    local invalidStates = routeContext:rewardValueStates("Underworld", "F", 2, "row", "Reward1Key", control)

    lu.assertEquals(priorStates.SpellDrop, valueStates.INVALID)
    lu.assertEquals(invalidStates.SpellDrop, valueStates.INVALID)
    lu.assertNil(priorStates.MaxHealthDrop)
    lu.assertNil(invalidStates.MaxHealthDrop)
end

function TestRunPlannerRewardPlanning.testRouteContextMarksRelatedMultiSourceRewardParticipantValue()
    local constraint = {
        kind = "uniqueRewardTypes",
        sourceIndices = { 1, 2 },
        code = "duplicate_reward_type",
        message = "Fields cage rewards cannot duplicate non-boon rewards",
    }
    local routeContext = rewardLegalityRouteContext({
        key = "Underworld",
        label = "Underworld",
        biomes = { "H" },
    }, {
        RouteH = fakeRouteControlSnapshot("RouteH", {
            routeRewardRow(1, "Cages", {
                rewardKind = "fieldsCages",
                rewards = { "MaxHealthDrop", "MaxHealthDrop" },
                rewardSourceCount = 2,
                rewardConstraints = { constraint },
            }),
        }),
    })
    local firstControl = rewardCandidateControl("rewardType", {
        "",
        "MaxHealthDrop",
        "MaxManaDrop",
    }, "Reward1Key")
    firstControl.sourceIndex = 1
    local secondControl = rewardCandidateControl("rewardType", {
        "",
        "MaxHealthDrop",
        "MaxManaDrop",
    }, "Reward2Key")
    secondControl.sourceIndex = 2

    local overview = routeContext:overview("Underworld")

    lu.assertFalse(overview.valid)
    lu.assertEquals(#overview.invalidRows, 2)
    lu.assertEquals(overview.invalidRows[1].address, "cage:2")
    lu.assertEquals(overview.invalidRows[2].address, "cage:1")

    local firstStates = routeContext:rewardValueStates("Underworld", "H", 1, "row", "Reward1Key", firstControl)
    local secondStates = routeContext:rewardValueStates("Underworld", "H", 1, "row", "Reward2Key", secondControl)

    lu.assertEquals(firstStates.MaxHealthDrop, valueStates.INVALID)
    lu.assertEquals(secondStates.MaxHealthDrop, valueStates.INVALID)
    lu.assertNil(firstStates.MaxManaDrop)
    lu.assertNil(secondStates.MaxManaDrop)
end

function TestRunPlannerRewardPlanning.testRouteContextAllowsCandidatesAfterRequiredPriorReward()
    local control = rewardCandidateControl("rewardType", {
        "",
        "TalentDrop",
    })
    local routeContext = rewardLegalityRouteContext({
        key = "Underworld",
        label = "Underworld",
        biomes = { "F" },
    }, {
        RouteF = fakeRouteControlSnapshot("RouteF", {
            routeRewardRow(1, "SpellDrop"),
            routeRewardRow(2, "MaxHealthDrop"),
        }),
    })

    lu.assertNil(routeContext:rewardValueStates("Underworld", "F", 2, "row", "Reward1Key", control))
end

function TestRunPlannerRewardPlanning.testRouteContextRefreshesRewardCandidateStatesAfterUpstreamEdit()
    local control = rewardCandidateControl("rewardType", {
        "",
        "TalentDrop",
    })
    local rows = {
        routeRewardRow(1, "MaxHealthDrop"),
        routeRewardRow(2, "MaxHealthDrop"),
    }
    local routeContext = rewardLegalityRouteContext({
        key = "Underworld",
        label = "Underworld",
        biomes = { "F" },
    }, {
        RouteF = fakeRouteControlSnapshot("RouteF", rows),
    })

    local states = routeContext:rewardValueStates("Underworld", "F", 2, "row", "Reward1Key", control)

    lu.assertEquals(states.TalentDrop, valueStates.INVALID)

    rows[1] = routeRewardRow(1, "SpellDrop")
    routeContext:markDirty("Underworld", "F")

    lu.assertNil(routeContext:rewardValueStates("Underworld", "F", 2, "row", "Reward1Key", control))
end

function TestRunPlannerRewardPlanning.testRouteContextMarksCandidatesInvalidBeforePendingShopRewardPromotes()
    local control = rewardCandidateControl("rewardType", {
        "",
        "TalentDrop",
    })
    local routeContext = rewardLegalityRouteContext({
        key = "Underworld",
        label = "Underworld",
        biomes = { "F" },
    }, {
        RouteF = fakeRouteControlSnapshot("RouteF", {
            routeRewardRow(1, "SpellDrop", {
                rewardKind = "shop",
            }),
            routeRewardRow(2, "MaxHealthDrop"),
        }),
    })

    local states = routeContext:rewardValueStates("Underworld", "F", 2, "row", "Reward1Key", control)

    lu.assertEquals(states.TalentDrop, valueStates.INVALID)
end

function TestRunPlannerRewardPlanning.testRouteContextAllowsCandidatesAfterPendingShopRewardPromotes()
    local control = rewardCandidateControl("rewardType", {
        "",
        "TalentDrop",
    })
    local routeContext = rewardLegalityRouteContext({
        key = "Underworld",
        label = "Underworld",
        biomes = { "F" },
    }, {
        RouteF = fakeRouteControlSnapshot("RouteF", {
            routeRewardRow(1, "SpellDrop", {
                rewardKind = "shop",
            }),
            routeRewardRow(2, "MaxHealthDrop"),
            routeRewardRow(3, "MaxHealthDrop"),
        }),
    })

    lu.assertNil(routeContext:rewardValueStates("Underworld", "F", 3, "row", "Reward1Key", control))
end

function TestRunPlannerRewardPlanning.testRouteContextMarksInvalidShopOptionCandidates()
    local control = rewardCandidateControl("shopOption", {
        "",
        "TalentBigDrop",
    })
    local routeContext = rewardLegalityRouteContext({
        key = "Underworld",
        label = "Underworld",
        biomes = { "F" },
    }, {
        RouteF = fakeRouteControlSnapshot("RouteF", {
            routeRewardRow(1, "SpellDrop"),
            routeRewardRow(2, "TalentDrop", {
                rewardKind = "shop",
            }),
            routeRewardRow(3, "MaxHealthDrop", {
                rewardKind = "shop",
            }),
        }),
    })

    local states = routeContext:rewardValueStates("Underworld", "F", 3, "row", "Reward1Key", control)

    lu.assertEquals(states.TalentBigDrop, valueStates.INVALID)
end

function TestRunPlannerRewardPlanning.testRewardCandidateLookupRebuildsAfterBoundedOverview()
    local control = rewardCandidateControl("rewardType", {
        "",
        "TalentDrop",
    })
    local routeContext = rewardLegalityRouteContext({
        key = "Underworld",
        label = "Underworld",
        biomes = { "F" },
    }, {
        RouteF = fakeRouteControlSnapshot("RouteF", {
            routeRewardRow(1, "MaxHealthDrop", {
                valid = false,
                invalidCode = "bad_room",
                invalidReason = "Bad room",
            }),
            routeRewardRow(2, "MaxHealthDrop"),
        }),
    })

    lu.assertEquals(routeContext:overview("Underworld").invalidRows[1].code, "bad_room")

    local states = routeContext:rewardValueStates("Underworld", "F", 2, "row", "Reward1Key", control)

    lu.assertEquals(states.TalentDrop, valueStates.INVALID)
end

function TestRunPlannerRewardPlanning.testRouteOverviewReportsRewardInvalidBeforeLaterRoomInvalid()
    local routeContext = rewardLegalityRouteContext({
        key = "Underworld",
        label = "Underworld",
        biomes = { "F" },
    }, {
        RouteF = fakeRouteControlSnapshot("RouteF", {
            routeRewardRow(1, "TalentDrop"),
            routeRewardRow(2, "MaxHealthDrop", {
                valid = false,
                invalidCode = "bad_room",
                invalidReason = "Bad room",
            }),
        }),
    }, {
        biomes = {
            F = { label = "Erebus" },
        },
    })

    local overview = routeContext:overview("Underworld")

    lu.assertFalse(overview.valid)
    lu.assertEquals(#overview.invalidRows, 1)
    lu.assertEquals(overview.invalidRows[1].rowIndex, 1)
    lu.assertEquals(overview.invalidRows[1].code, "talent_requires_spell")
end

function TestRunPlannerRewardPlanning.testRouteOverviewStopsRewardValidationAfterEarlierRoomInvalid()
    local routeContext = rewardLegalityRouteContext({
        key = "Underworld",
        label = "Underworld",
        biomes = { "F" },
    }, {
        RouteF = fakeRouteControlSnapshot("RouteF", {
            routeRewardRow(1, "MaxHealthDrop", {
                valid = false,
                invalidCode = "bad_room",
                invalidReason = "Bad room",
            }),
            routeRewardRow(2, "TalentDrop"),
        }),
    })

    local overview = routeContext:overview("Underworld")

    lu.assertFalse(overview.valid)
    lu.assertEquals(#overview.invalidRows, 1)
    lu.assertEquals(overview.invalidRows[1].rowIndex, 1)
    lu.assertEquals(overview.invalidRows[1].code, "bad_room")
end

function TestRunPlannerRewardPlanning.testRouteContextPreservesRewardInvalidAddress()
    local routeContext = rewardLegalityRouteContext({
        key = "Underworld",
        label = "Underworld",
        biomes = { "F" },
    }, {
        RouteF = fakeRouteControlSnapshot("RouteF", {
            routeRewardRow(1, "Shop", {
                rewardKind = "shop",
                rewards = { "RandomLoot", "TalentDrop" },
                rewardLoot = { "ZeusUpgrade", "" },
            }),
        }),
    }, {
        biomes = {
            F = { label = "Erebus" },
        },
    })

    local invalid = routeContext:overview("Underworld").invalidRows[1]

    lu.assertEquals(invalid.rowIndex, 1)
    lu.assertEquals(invalid.address, "shop:2")
    lu.assertEquals(invalid.rewardType, "TalentDrop")
    lu.assertEquals(invalid.locationLabel, "Erebus Depth 1 Shop Offer 2")
    lu.assertEquals(invalid.code, "talent_requires_spell")
    lu.assertEquals(routeContext:rewardRowValidation("Underworld", "F", 1).address, "shop:2")
end

function TestRunPlannerRewardPlanning.testShopRewardsDoNotSatisfySameBatchRewards()
    local routeContext = rewardLegalityRouteContext({
        key = "Underworld",
        label = "Underworld",
        biomes = { "F" },
    }, {
        RouteF = fakeRouteControlSnapshot("RouteF", {
            routeRewardRow(1, "Shop", {
                rewardKind = "shop",
                rewards = { "SpellDrop", "TalentDrop" },
            }),
        }),
    })

    local invalid = routeContext:overview("Underworld").invalidRows[1]

    lu.assertEquals(invalid.rowIndex, 1)
    lu.assertEquals(invalid.address, "shop:2")
    lu.assertEquals(invalid.rewardType, "TalentDrop")
    lu.assertEquals(invalid.code, "talent_requires_spell")
end

function TestRunPlannerRewardPlanning.testFieldsCageRewardsDoNotSatisfySameBatchRewards()
    local routeContext = rewardLegalityRouteContext({
        key = "Underworld",
        label = "Underworld",
        biomes = { "H" },
    }, {
        RouteH = fakeRouteControlSnapshot("RouteH", {
            routeRewardRow(1, "Cages", {
                rewardKind = "fieldsCages",
                rewards = { "SpellDrop", "TalentBigDrop" },
                rewardSourceCount = 2,
            }),
        }),
    })

    local invalid = routeContext:overview("Underworld").invalidRows[1]

    lu.assertEquals(invalid.rowIndex, 1)
    lu.assertEquals(invalid.address, "cage:2")
    lu.assertEquals(invalid.rewardType, "TalentBigDrop")
    lu.assertEquals(invalid.code, "talent_requires_spell")
end

function TestRunPlannerRewardPlanning.testRewardRowGroupRejectsDuplicateRewardTypesAcrossRows()
    local group = {
        key = "TestBatch",
        constraints = {
            uniqueRewardTypes = {
                allow = {
                    Boon = true,
                },
            },
        },
    }
    local routeContext = rewardLegalityRouteContext({
        key = "Surface",
        label = "Surface",
        biomes = { "N" },
    }, {
        RouteN = fakeRouteControlSnapshot("RouteN", {
            routeRewardRow(1, "MaxHealthDropBig", { rewardRowGroup = group }),
            routeRewardRow(2, "MaxHealthDropBig", { rewardRowGroup = group }),
        }),
    }, {
        biomes = {
            N = { label = "Ephyra" },
        },
    })

    local invalid = routeContext:overview("Surface").invalidRows[1]

    lu.assertEquals(invalid.biomeKey, "N")
    lu.assertEquals(invalid.rowIndex, 2)
    lu.assertEquals(invalid.rewardType, "MaxHealthDropBig")
    lu.assertEquals(invalid.locationLabel, "Ephyra Depth 2 Rewards")
    lu.assertEquals(invalid.code, "duplicate_reward_type")
end

function TestRunPlannerRewardPlanning.testRewardRowGroupRefreshesSelectedValidityAfterDuplicateChanges()
    local group = {
        key = "TestBatch",
        constraints = {
            uniqueRewardTypes = {},
        },
    }
    local rows = {
        routeRewardRow(1, "MaxHealthDropBig", { rewardRowGroup = group }),
        routeRewardRow(2, "MaxHealthDropBig", { rewardRowGroup = group }),
    }
    local routeContext = rewardLegalityRouteContext({
        key = "Surface",
        label = "Surface",
        biomes = { "N" },
    }, {
        RouteN = fakeRouteControlSnapshot("RouteN", rows),
    })

    lu.assertEquals(routeContext:overview("Surface").invalidRows[1].code, "duplicate_reward_type")

    rows[2] = routeRewardRow(2, "MaxManaDropBig", { rewardRowGroup = group })
    routeContext:markDirty("Surface", "N")

    lu.assertTrue(routeContext:overview("Surface").valid)
end

function TestRunPlannerRewardPlanning.testRewardRowGroupAllowsConfiguredDuplicateRewardTypes()
    local group = {
        key = "TestBatch",
        constraints = {
            uniqueRewardTypes = {
                allow = {
                    Boon = true,
                },
            },
        },
    }
    local routeContext = rewardLegalityRouteContext({
        key = "Surface",
        label = "Surface",
        biomes = { "N" },
    }, {
        RouteN = fakeRouteControlSnapshot("RouteN", {
            routeRewardRow(1, "Boon", {
                rewardRowGroup = group,
                rewardPicks = {
                    { kind = "boonSource", value = "ZeusUpgrade" },
                },
            }),
            routeRewardRow(2, "Boon", {
                rewardRowGroup = group,
                rewardPicks = {
                    { kind = "boonSource", value = "ZeusUpgrade" },
                },
            }),
        }),
    })

    lu.assertTrue(routeContext:overview("Surface").valid)
end

function TestRunPlannerRewardPlanning.testRewardRowGroupMarksDuplicateRewardCandidatesInvalid()
    local group = {
        key = "TestBatch",
        constraints = {
            uniqueRewardTypes = {},
        },
    }
    local control = rewardCandidateControl("rewardType", {
        "",
        "MaxHealthDropBig",
        "MaxManaDropBig",
    })
    local routeContext = rewardLegalityRouteContext({
        key = "Surface",
        label = "Surface",
        biomes = { "N" },
    }, {
        RouteN = fakeRouteControlSnapshot("RouteN", {
            routeRewardRow(1, "MaxHealthDropBig", { rewardRowGroup = group }),
            routeRewardRow(2, "MaxManaDropBig", { rewardRowGroup = group }),
        }),
    })

    local states = routeContext:rewardValueStates("Surface", "N", 2, "row", "Reward1Key", control)

    lu.assertEquals(states.MaxHealthDropBig, valueStates.INVALID)
    lu.assertNil(states.MaxManaDropBig)
end

function TestRunPlannerRewardPlanning.testRewardRowGroupRefreshesCandidateStatesAfterPriorRewardChanges()
    local group = {
        key = "TestBatch",
        constraints = {
            uniqueRewardTypes = {},
        },
    }
    local control = rewardCandidateControl("rewardType", {
        "",
        "MaxHealthDropBig",
        "MaxManaDropBig",
    })
    local rows = {
        routeRewardRow(1, "MaxHealthDropBig", { rewardRowGroup = group }),
        routeRewardRow(2, "MaxManaDropBig", { rewardRowGroup = group }),
    }
    local routeContext = rewardLegalityRouteContext({
        key = "Surface",
        label = "Surface",
        biomes = { "N" },
    }, {
        RouteN = fakeRouteControlSnapshot("RouteN", rows),
    })

    local states = routeContext:rewardValueStates("Surface", "N", 2, "row", "Reward1Key", control)

    lu.assertEquals(states.MaxHealthDropBig, valueStates.INVALID)

    rows[1] = routeRewardRow(1, "MaxManaDropBig", { rewardRowGroup = group })
    routeContext:markDirty("Surface", "N")

    states = routeContext:rewardValueStates("Surface", "N", 2, "row", "Reward1Key", control)

    lu.assertNil(states.MaxHealthDropBig)
    lu.assertEquals(states.MaxManaDropBig, valueStates.INVALID)
end

function TestRunPlannerRewardPlanning.testRewardRowGroupDoesNotLetEarlierRowsSatisfyLaterRows()
    local group = {
        key = "TestBatch",
    }
    local routeContext = rewardLegalityRouteContext({
        key = "Surface",
        label = "Surface",
        biomes = { "N" },
    }, {
        RouteN = fakeRouteControlSnapshot("RouteN", {
            routeRewardRow(1, "SpellDrop", { rewardRowGroup = group }),
            routeRewardRow(2, "TalentBigDrop", { rewardRowGroup = group }),
        }),
    })

    local invalid = routeContext:overview("Surface").invalidRows[1]

    lu.assertEquals(invalid.rowIndex, 2)
    lu.assertEquals(invalid.rewardType, "TalentBigDrop")
    lu.assertEquals(invalid.code, "talent_requires_spell")
end

function TestRunPlannerRewardPlanning.testSameSurfaceConstraintRejectsDuplicateDevotionGods()
    local constraint = {
        kind = "uniqueBoonSource",
        code = "duplicate_devotion_god",
        message = "Trial gods must be different",
    }
    local routeContext = rewardLegalityRouteContext({
        key = "Underworld",
        label = "Underworld",
        biomes = { "F" },
    }, {
        RouteF = fakeRouteControlSnapshot("RouteF", {
            routeRewardRow(1, "Devotion", {
                rewardKind = "devotionPair",
                rewards = { "ZeusUpgrade", "ZeusUpgrade" },
                rewardConstraints = { constraint },
            }),
        }),
    })

    local invalid = routeContext:overview("Underworld").invalidRows[1]

    lu.assertEquals(invalid.rowIndex, 1)
    lu.assertEquals(invalid.rewardType, "Devotion")
    lu.assertEquals(invalid.code, "duplicate_devotion_god")
end

function TestRunPlannerRewardPlanning.testSameSurfaceConstraintColorsDuplicateDevotionGodCandidate()
    local constraint = {
        kind = "uniqueBoonSource",
        code = "duplicate_devotion_god",
        message = "Trial gods must be different",
    }
    local control = rewardCandidateControl("boonSource", {
        "",
        "ZeusUpgrade",
        "HeraUpgrade",
    }, "Reward2Key")
    local rows = firstValidDevotionRows()
    rows[2] = boonRewardRow(2, "HeraUpgrade")
    rows[9] = routeRewardRow(9, "Devotion", {
        rewardKind = "devotionPair",
        rewards = { "ZeusUpgrade", "HeraUpgrade" },
        rewardConstraints = { constraint },
    })
    local routeContext = rewardLegalityRouteContext({
        key = "Underworld",
        label = "Underworld",
        biomes = { "F" },
    }, {
        RouteF = fakeRouteControlSnapshot("RouteF", rows),
    })

    local states = routeContext:rewardValueStates("Underworld", "F", 9, "row", "Reward2Key", control)

    lu.assertEquals(states.ZeusUpgrade, valueStates.INVALID)
    lu.assertNil(states.HeraUpgrade)
end

function TestRunPlannerRewardPlanning.testSameSurfaceConstraintRejectsLinkedShopOfferDuplicates()
    local constraint = {
        kind = "uniqueRewardTypes",
        sourceIndices = { 1, 2 },
        code = "duplicate_shop_group_option",
        message = "Offers 1 and 2 share one vanilla shop group and cannot duplicate the same reward",
    }
    local routeContext = rewardLegalityRouteContext({
        key = "Surface",
        label = "Surface",
        biomes = { "Q" },
    }, {
        RouteQ = fakeRouteControlSnapshot("RouteQ", {
            routeRewardRow(1, "RandomLoot", {
                rewardKind = "shop",
                rewards = { "RandomLoot", "RandomLoot" },
                rewardConstraints = { constraint },
            }),
        }),
    })

    local invalid = routeContext:overview("Surface").invalidRows[1]

    lu.assertEquals(invalid.rowIndex, 1)
    lu.assertEquals(invalid.address, "shop:2")
    lu.assertEquals(invalid.code, "duplicate_shop_group_option")
end

function TestRunPlannerRewardPlanning.testSameSurfaceConstraintColorsLinkedShopOfferCandidates()
    local constraint = {
        kind = "uniqueRewardTypes",
        sourceIndices = { 1, 2 },
        code = "duplicate_shop_group_option",
        message = "Offers 1 and 2 share one vanilla shop group and cannot duplicate the same reward",
    }
    local control = rewardCandidateControl("shopOption", {
        "",
        "RandomLoot",
        "BoostedRandomLoot",
    }, "Reward2Key")
    control.rowIndex = 2
    local routeContext = rewardLegalityRouteContext({
        key = "Surface",
        label = "Surface",
        biomes = { "Q" },
    }, {
        RouteQ = fakeRouteControlSnapshot("RouteQ", {
            routeRewardRow(1, "RandomLoot", {
                rewardKind = "shop",
                rewards = { "RandomLoot", "BoostedRandomLoot" },
                rewardConstraints = { constraint },
            }),
        }),
    })

    local states = routeContext:rewardValueStates("Surface", "Q", 1, "row", "Reward2Key", control)

    lu.assertEquals(states.RandomLoot, valueStates.INVALID)
    lu.assertNil(states.BoostedRandomLoot)
end

function TestRunPlannerRewardPlanning.testShopConstraintsRefreshAfterDuplicateOfferChanges()
    local constraint = {
        kind = "uniqueRewardTypes",
        sourceIndices = { 1, 2 },
        code = "duplicate_shop_group_option",
        message = "Offers 1 and 2 share one vanilla shop group and cannot duplicate the same reward",
    }
    local control = rewardCandidateControl("shopOption", {
        "",
        "RandomLoot",
        "BoostedRandomLoot",
    }, "Reward2Key")
    control.rowIndex = 2
    local rows = {
        routeRewardRow(1, "RandomLoot", {
            rewardKind = "shop",
            rewards = { "RandomLoot", "RandomLoot" },
            rewardConstraints = { constraint },
        }),
    }
    local routeContext = rewardLegalityRouteContext({
        key = "Surface",
        label = "Surface",
        biomes = { "Q" },
    }, {
        RouteQ = fakeRouteControlSnapshot("RouteQ", rows),
    })

    lu.assertEquals(routeContext:overview("Surface").invalidRows[1].code, "duplicate_shop_group_option")

    rows[1] = routeRewardRow(1, "RandomLoot", {
        rewardKind = "shop",
        rewards = { "RandomLoot", "BoostedRandomLoot" },
        rewardConstraints = { constraint },
    })
    routeContext:markDirty("Surface", "Q")

    lu.assertTrue(routeContext:overview("Surface").valid)
    local states = routeContext:rewardValueStates("Surface", "Q", 1, "row", "Reward2Key", control)
    lu.assertEquals(states.RandomLoot, valueStates.INVALID)
    lu.assertNil(states.BoostedRandomLoot)
end

function TestRunPlannerRewardPlanning.testSameSurfaceConstraintColorsFieldsCageDuplicateCandidates()
    local constraints = {
        {
            kind = "uniqueRewardTypes",
            sourceIndices = { 1, 2 },
            allow = {
                Boon = true,
            },
            code = "duplicate_reward_type",
            message = "Fields cage rewards cannot duplicate non-boon rewards",
        },
        {
            kind = "uniqueBoonSource",
            sourceIndices = { 1, 2 },
            code = "duplicate_boon_source",
            message = "Fields cage boon sources must be different",
        },
    }
    local rows = {
        routeRewardRow(1, "Cages", {
            rewardKind = "fieldsCages",
            rewards = { "MaxHealthDrop", "MaxManaDrop" },
            rewardLoot = { "", "" },
            rewardSourceCount = 2,
            rewardConstraints = constraints,
        }),
    }
    local routeContext = rewardLegalityRouteContext({
        key = "Underworld",
        label = "Underworld",
        biomes = { "H" },
    }, {
        RouteH = fakeRouteControlSnapshot("RouteH", rows),
    })
    local rewardControl = rewardCandidateControl("rewardType", {
        "",
        "MaxHealthDrop",
        "MaxManaDrop",
    }, "Reward2Key")
    rewardControl.sourceIndex = 2
    local sourceControl = rewardCandidateControl("boonSource", {
        "",
        "ZeusUpgrade",
        "HeraUpgrade",
    }, "Reward2LootKey")
    sourceControl.sourceIndex = 2

    local rewardStates = routeContext:rewardValueStates("Underworld", "H", 1, "row", "Reward2Key", rewardControl)
    lu.assertEquals(rewardStates.MaxHealthDrop, valueStates.INVALID)
    lu.assertNil(rewardStates.MaxManaDrop)

    rows[1] = routeRewardRow(1, "Cages", {
        rewardKind = "fieldsCages",
        rewards = { "Boon", "Boon" },
        rewardLoot = { "ZeusUpgrade", "HeraUpgrade" },
        rewardSourceCount = 2,
        rewardConstraints = constraints,
    })
    routeContext:markDirty("Underworld", "H")

    local sourceStates = routeContext:rewardValueStates("Underworld", "H", 1, "row", "Reward2LootKey", sourceControl)
    lu.assertEquals(sourceStates.ZeusUpgrade, valueStates.INVALID)
    lu.assertNil(sourceStates.HeraUpgrade)
end

function TestRunPlannerRewardPlanning.testFieldsCageConstraintsIgnorePriorScratchAfterRewardChanges()
    local constraints = {
        {
            kind = "uniqueRewardTypes",
            sourceIndices = { 1, 2 },
            allow = {
                Boon = true,
            },
            code = "duplicate_reward_type",
            message = "Fields cage rewards cannot duplicate non-boon rewards",
        },
        {
            kind = "uniqueBoonSource",
            sourceIndices = { 1, 2 },
            code = "duplicate_boon_source",
            message = "Fields cage boon sources must be different",
        },
    }
    local rows = {
        routeRewardRow(1, "Cages", {
            rewardKind = "fieldsCages",
            rewards = { "Boon", "Boon" },
            rewardLoot = { "DemeterUpgrade", "DemeterUpgrade" },
            rewardSourceCount = 2,
            rewardConstraints = constraints,
        }),
    }
    local routeContext = rewardLegalityRouteContext({
        key = "Underworld",
        label = "Underworld",
        biomes = { "H" },
    }, {
        RouteH = fakeRouteControlSnapshot("RouteH", rows),
    })
    local sourceControl = rewardCandidateControl("boonSource", {
        "",
        "DemeterUpgrade",
        "ZeusUpgrade",
    }, "Reward2LootKey")
    sourceControl.sourceIndex = 2

    lu.assertEquals(routeContext:overview("Underworld").invalidRows[1].code, "duplicate_boon_source")

    rows[1] = routeRewardRow(1, "Cages", {
        rewardKind = "fieldsCages",
        rewards = { "RoomMoneyDrop", "Boon" },
        rewardLoot = { "DemeterUpgrade", "DemeterUpgrade" },
        rewardSourceCount = 2,
        rewardConstraints = constraints,
    })
    routeContext:markDirty("Underworld", "H")

    lu.assertTrue(routeContext:overview("Underworld").valid)
    lu.assertNil(routeContext:rewardValueStates("Underworld", "H", 1, "row", "Reward2LootKey", sourceControl))
end

function TestRunPlannerRewardPlanning.testRewardRowGroupEffectsApplyAfterGroupCloses()
    local group = {
        key = "TestBatch",
    }
    local routeContext = rewardLegalityRouteContext({
        key = "Surface",
        label = "Surface",
        biomes = { "N" },
    }, {
        RouteN = fakeRouteControlSnapshot("RouteN", {
            routeRewardRow(1, "SpellDrop", { rewardRowGroup = group }),
            routeRewardRow(2, "MaxHealthDropBig", { rewardRowGroup = group }),
            routeRewardRow(3, "TalentBigDrop"),
        }),
    })

    lu.assertTrue(routeContext:overview("Surface").valid)
end

function TestRunPlannerRewardPlanning.testSideRoomCandidateStatesUsePostRewardGroupContext()
    local group = {
        key = "N_HubPylons",
    }
    local control = rewardCandidateControl("rewardType", {
        "",
        "MinorTalentDrop",
    })
    local function pylonRow(primaryReward)
        local row = routeRewardRow(1, primaryReward, {
            rewardRowGroup = group,
        })
        row.sideRooms = {
            {
                sideIndex = 1,
                rewardKind = "roomStore",
                rewards = { "MinorTalentDrop" },
                rewardPicks = {},
            },
        }
        return row
    end
    local rows = {
        pylonRow("SpellDrop"),
    }
    local routeContext = rewardLegalityRouteContext({
        key = "Surface",
        label = "Surface",
        biomes = { "N" },
    }, {
        RouteN = fakeRouteControlSnapshot("RouteN", rows),
    })

    lu.assertTrue(routeContext:overview("Surface").valid)
    local decision = routeContext:rewardLegality("Surface").decisionsByBiomeRowAddress.N[1]["side:1"]
    lu.assertEquals(decision.address, "side:1")
    lu.assertEquals(decision.selectedEvents[1].rewardType, "MinorTalentDrop")
    lu.assertEquals(decision.rewardCtxBeforeDecision.routeCounters.spell, 1)
    lu.assertNil(decision.selectedInvalid)
    lu.assertNil(routeContext:rewardValueStates("Surface", "N", 1, "side:1", "Reward1Key", control))

    rows[1] = pylonRow("MaxHealthDrop")
    routeContext:markDirty("Surface", "N")

    local states = routeContext:rewardValueStates("Surface", "N", 1, "side:1", "Reward1Key", control)
    decision = routeContext:rewardLegality("Surface").decisionsByBiomeRowAddress.N[1]["side:1"]

    lu.assertEquals(states.MinorTalentDrop, valueStates.INVALID)
    lu.assertEquals(decision.selectedInvalid.code, "talent_requires_spell")

    rows[1] = pylonRow("SpellDrop")
    routeContext:markDirty("Surface", "N")

    lu.assertTrue(routeContext:overview("Surface").valid)
    decision = routeContext:rewardLegality("Surface").decisionsByBiomeRowAddress.N[1]["side:1"]
    lu.assertEquals(decision.rewardCtxBeforeDecision.routeCounters.spell, 1)
    lu.assertNil(decision.selectedInvalid)
    lu.assertNil(routeContext:rewardValueStates("Surface", "N", 1, "side:1", "Reward1Key", control))
end

function TestRunPlannerRewardPlanning.testBlankSideRoomCandidatesUsePostRewardGroupContext()
    local group = {
        key = "N_HubPylons",
    }
    local control = rewardCandidateControl("rewardType", {
        "",
        "MinorTalentDrop",
    })
    local function pylonRow(primaryReward)
        local row = routeRewardRow(1, primaryReward, {
            rewardRowGroup = group,
        })
        row.sideRooms = {
            {
                sideIndex = 1,
                rewardKind = "roomStore",
                rewards = { "" },
                rewardPicks = {},
            },
        }
        return row
    end
    local rows = {
        pylonRow("SpellDrop"),
    }
    local routeContext = rewardLegalityRouteContext({
        key = "Surface",
        label = "Surface",
        biomes = { "N" },
    }, {
        RouteN = fakeRouteControlSnapshot("RouteN", rows),
    })

    lu.assertTrue(routeContext:overview("Surface").valid)
    local decision = routeContext:rewardLegality("Surface").decisionsByBiomeRowAddress.N[1]["side:1"]
    lu.assertEquals(decision.rewardCtxBeforeDecision.routeCounters.spell, 1)
    lu.assertEquals(decision.selectedEvents, {})
    lu.assertNil(routeContext:rewardValueStates("Surface", "N", 1, "side:1", "Reward1Key", control))

    rows[1] = pylonRow("MaxHealthDrop")
    routeContext:markDirty("Surface", "N")

    local states = routeContext:rewardValueStates("Surface", "N", 1, "side:1", "Reward1Key", control)

    lu.assertEquals(states.MinorTalentDrop, valueStates.INVALID)
end

function TestRunPlannerRewardPlanning.testRouteContextInvalidatesDevotionBeforeSevenRunEncounters()
    local routeContext = rewardLegalityRouteContext({
        key = "Underworld",
        label = "Underworld",
        biomes = { "F" },
    }, {
        RouteF = fakeRouteControlSnapshot("RouteF", {
            boonRewardRow(1, "ZeusUpgrade"),
            boonRewardRow(2, "ApolloUpgrade", { exitCount = 2 }),
            devotionRewardRow(3),
        }),
    })

    local overview = routeContext:overview("Underworld")

    lu.assertFalse(overview.valid)
    lu.assertEquals(#overview.invalidRows, 1)
    lu.assertEquals(overview.invalidRows[1].rowIndex, 3)
    lu.assertEquals(overview.invalidRows[1].code, "devotion_run_encounter_depth")
end

function TestRunPlannerRewardPlanning.testRouteContextAllowsDevotionAfterSevenRunEncounters()
    local routeContext = rewardLegalityRouteContext({
        key = "Underworld",
        label = "Underworld",
        biomes = { "F" },
    }, {
        RouteF = fakeRouteControlSnapshot("RouteF", {
            boonRewardRow(1, "ZeusUpgrade"),
            boonRewardRow(2, "ApolloUpgrade"),
            routeRewardRow(3, "MaxHealthDrop"),
            routeRewardRow(4, "MaxHealthDrop"),
            routeRewardRow(5, "MaxHealthDrop"),
            routeRewardRow(6, "MaxHealthDrop"),
            routeRewardRow(7, "MaxHealthDrop", { exitCount = 2 }),
            devotionRewardRow(8),
        }),
    })

    lu.assertTrue(routeContext:overview("Underworld").valid)
    lu.assertNil(routeContext:rewardRowValidation("Underworld", "F", 8))
end

function TestRunPlannerRewardPlanning.testRouteContextInvalidatesUnseenDevotionGods()
    local routeContext = rewardLegalityRouteContext({
        key = "Underworld",
        label = "Underworld",
        biomes = { "F" },
    }, {
        RouteF = fakeRouteControlSnapshot("RouteF", {
            boonRewardRow(1, "ZeusUpgrade"),
            boonRewardRow(2, "ApolloUpgrade"),
            routeRewardRow(3, "MaxHealthDrop"),
            routeRewardRow(4, "MaxHealthDrop"),
            routeRewardRow(5, "MaxHealthDrop"),
            routeRewardRow(6, "MaxHealthDrop"),
            routeRewardRow(7, "MaxHealthDrop", { exitCount = 2 }),
            devotionRewardRow(8, {
                lootAName = "ZeusUpgrade",
                lootBName = "PoseidonUpgrade",
            }),
        }),
    })

    local overview = routeContext:overview("Underworld")

    lu.assertFalse(overview.valid)
    lu.assertEquals(overview.invalidRows[1].rowIndex, 8)
    lu.assertEquals(overview.invalidRows[1].code, "devotion_sources_not_seen")
end

function TestRunPlannerRewardPlanning.testRewardRowGroupDoesNotSatisfyDevotionGods()
    local group = {
        key = "TestBatch",
    }
    local routeContext = rewardLegalityRouteContext({
        key = "Surface",
        label = "Surface",
        biomes = { "N" },
    }, {
        RouteN = fakeRouteControlSnapshot("RouteN", {
            boonRewardRow(1, "ZeusUpgrade"),
            boonRewardRow(2, "ApolloUpgrade"),
            routeRewardRow(3, "MaxHealthDrop"),
            routeRewardRow(4, "MaxHealthDrop"),
            routeRewardRow(5, "MaxHealthDrop"),
            routeRewardRow(6, "MaxHealthDrop"),
            routeRewardRow(7, "MaxHealthDrop", { exitCount = 2 }),
            boonRewardRow(8, "PoseidonUpgrade", { exitCount = 2, rewardRowGroup = group }),
            devotionRewardRow(9, {
                rewardRowGroup = group,
                lootAName = "ZeusUpgrade",
                lootBName = "PoseidonUpgrade",
            }),
        }),
    })

    local overview = routeContext:overview("Surface")

    lu.assertFalse(overview.valid)
    lu.assertEquals(overview.invalidRows[1].rowIndex, 9)
    lu.assertEquals(overview.invalidRows[1].code, "devotion_sources_not_seen")
end

function TestRunPlannerRewardPlanning.testRouteContextInvalidatesDevotionBeforeFifteenRooms()
    local routeContext = rewardLegalityRouteContext({
        key = "Underworld",
        label = "Underworld",
        biomes = { "F", "G" },
    }, {
        RouteF = fakeRouteControlSnapshot("RouteF", firstValidDevotionRows()),
        RouteG = fakeRouteControlSnapshot("RouteG", {
            routeRewardRow(1, "MaxHealthDrop"),
            routeRewardRow(2, "MaxHealthDrop"),
            routeRewardRow(3, "MaxHealthDrop"),
            routeRewardRow(4, "MaxHealthDrop"),
            routeRewardRow(5, "MaxHealthDrop"),
            routeRewardRow(6, "MaxHealthDrop"),
            routeRewardRow(7, "MaxHealthDrop"),
            routeRewardRow(8, "MaxHealthDrop"),
            routeRewardRow(9, "MaxHealthDrop"),
            routeRewardRow(10, "MaxHealthDrop"),
            routeRewardRow(11, "MaxHealthDrop", { exitCount = 2 }),
            devotionRewardRow(12),
        }),
    }, {
        biomes = {
            F = fakeTimelineBiome(),
            G = fakeTimelineBiome(),
        },
    })

    local overview = routeContext:overview("Underworld")

    lu.assertFalse(overview.valid)
    lu.assertEquals(#overview.invalidRows, 2)
    lu.assertEquals(overview.invalidRows[1].biomeKey, "G")
    lu.assertEquals(overview.invalidRows[1].rowIndex, 12)
    lu.assertEquals(overview.invalidRows[1].code, "devotion_spacing")
end

function TestRunPlannerRewardPlanning.testRouteContextCountsTimelineRoomsForDevotionSpacing()
    local routeContext = rewardLegalityRouteContext({
        key = "Underworld",
        label = "Underworld",
        biomes = { "F", "G" },
    }, {
        RouteF = fakeRouteControlSnapshot("RouteF", firstValidDevotionRows()),
        RouteG = fakeRouteControlSnapshot("RouteG", {
            routeRewardRow(1, "MaxHealthDrop"),
            routeRewardRow(2, "MaxHealthDrop"),
            routeRewardRow(3, "MaxHealthDrop"),
            routeRewardRow(4, "MaxHealthDrop"),
            routeRewardRow(5, "MaxHealthDrop"),
            routeRewardRow(6, "MaxHealthDrop"),
            routeRewardRow(7, "MaxHealthDrop"),
            routeRewardRow(8, "MaxHealthDrop"),
            routeRewardRow(9, "MaxHealthDrop"),
            routeRewardRow(10, "MaxHealthDrop"),
            routeRewardRow(11, "MaxHealthDrop"),
            routeRewardRow(12, "MaxHealthDrop", { exitCount = 2 }),
            devotionRewardRow(13),
        }),
    }, {
        biomes = {
            F = fakeTimelineBiome(),
            G = fakeTimelineBiome(),
        },
    })

    local overview = routeContext:overview("Underworld")

    lu.assertTrue(overview.valid)
    lu.assertNil(routeContext:rewardRowValidation("Underworld", "G", 13))
end

function TestRunPlannerRewardPlanning.testRouteContextRefreshesDevotionSpacingCandidateAfterPriorTrialChanges()
    local control = rewardCandidateControl("rewardType", {
        "",
        "Devotion",
        "MaxHealthDrop",
    }, "Reward2Key")
    local fRows = firstValidDevotionRows()
    local gRows = {
        routeRewardRow(1, "MaxHealthDrop"),
        routeRewardRow(2, "MaxHealthDrop"),
        routeRewardRow(3, "MaxHealthDrop"),
        routeRewardRow(4, "MaxHealthDrop"),
        routeRewardRow(5, "MaxHealthDrop"),
        routeRewardRow(6, "MaxHealthDrop"),
        routeRewardRow(7, "MaxHealthDrop"),
        routeRewardRow(8, "MaxHealthDrop"),
        routeRewardRow(9, "MaxHealthDrop"),
        routeRewardRow(10, "MaxHealthDrop"),
        routeRewardRow(11, "MaxHealthDrop", { exitCount = 2 }),
        devotionRewardRow(12),
    }
    local routeContext = rewardLegalityRouteContext({
        key = "Underworld",
        label = "Underworld",
        biomes = { "F", "G" },
    }, {
        RouteF = fakeRouteControlSnapshot("RouteF", fRows),
        RouteG = fakeRouteControlSnapshot("RouteG", gRows),
    }, {
        biomes = {
            F = fakeTimelineBiome(),
            G = fakeTimelineBiome(),
        },
    })

    local states = routeContext:rewardValueStates("Underworld", "G", 12, "row", "Reward1Key", control)

    lu.assertEquals(states.Devotion, valueStates.INVALID)

    fRows[9] = routeRewardRow(9, "MaxHealthDrop", { exitCount = 2 })
    routeContext:markDirty("Underworld", "F")

    lu.assertNil(routeContext:rewardValueStates("Underworld", "G", 12, "row", "Reward1Key", control))
end

function TestRunPlannerRewardPlanning.testRouteContextInvalidatesDuplicateSpellDrops()
    local routeContext = rewardLegalityRouteContext({
        key = "Underworld",
        label = "Underworld",
        biomes = { "F" },
    }, {
        RouteF = fakeRouteControlSnapshot("RouteF", {
            routeRewardRow(1, "SpellDrop"),
            routeRewardRow(2, "SpellDrop"),
        }),
    })

    local overview = routeContext:overview("Underworld")

    lu.assertFalse(overview.valid)
    lu.assertEquals(#overview.invalidRows, 2)
    lu.assertEquals(overview.invalidRows[1].rowIndex, 2)
    lu.assertEquals(overview.invalidRows[1].code, "spell_drop_limit")
end

function TestRunPlannerRewardPlanning.testRouteContextInvalidatesSpellAfterPendingShopSpell()
    local routeContext = rewardLegalityRouteContext({
        key = "Underworld",
        label = "Underworld",
        biomes = { "F" },
    }, {
        RouteF = fakeRouteControlSnapshot("RouteF", {
            routeRewardRow(1, "SpellDrop", {
                rewardKind = "shop",
            }),
            routeRewardRow(2, "SpellDrop"),
        }),
    })

    local overview = routeContext:overview("Underworld")

    lu.assertFalse(overview.valid)
    lu.assertEquals(#overview.invalidRows, 2)
    lu.assertEquals(overview.invalidRows[1].rowIndex, 2)
    lu.assertEquals(overview.invalidRows[1].code, "spell_shop_conflict")
end

function TestRunPlannerRewardPlanning.testRouteContextPromotesShopSpellAfterNextRow()
    local routeContext = rewardLegalityRouteContext({
        key = "Underworld",
        label = "Underworld",
        biomes = { "F" },
    }, {
        RouteF = fakeRouteControlSnapshot("RouteF", {
            routeRewardRow(1, "SpellDrop", {
                rewardKind = "shop",
            }),
            routeRewardRow(2, "MaxHealthDrop"),
            routeRewardRow(3, "TalentDrop"),
        }),
    })

    local overview = routeContext:overview("Underworld")

    lu.assertTrue(overview.valid)
    lu.assertEquals(#overview.invalidRows, 0)
end

function TestRunPlannerRewardPlanning.testRouteContextInvalidatesTalentAfterPendingShopSpell()
    local routeContext = rewardLegalityRouteContext({
        key = "Underworld",
        label = "Underworld",
        biomes = { "F" },
    }, {
        RouteF = fakeRouteControlSnapshot("RouteF", {
            routeRewardRow(1, "SpellDrop", {
                rewardKind = "shop",
            }),
            routeRewardRow(2, "TalentDrop"),
        }),
    })

    local overview = routeContext:overview("Underworld")

    lu.assertFalse(overview.valid)
    lu.assertEquals(#overview.invalidRows, 1)
    lu.assertEquals(overview.invalidRows[1].rowIndex, 2)
    lu.assertEquals(overview.invalidRows[1].code, "talent_requires_spell")
end

function TestRunPlannerRewardPlanning.testRouteContextInvalidatesTalentAfterPreviousShopTalent()
    local routeContext = rewardLegalityRouteContext({
        key = "Underworld",
        label = "Underworld",
        biomes = { "F" },
    }, {
        RouteF = fakeRouteControlSnapshot("RouteF", {
            routeRewardRow(1, "SpellDrop"),
            routeRewardRow(2, "TalentDrop", {
                rewardKind = "shop",
            }),
            routeRewardRow(3, "TalentBigDrop"),
        }),
    })

    local overview = routeContext:overview("Underworld")

    lu.assertFalse(overview.valid)
    lu.assertEquals(#overview.invalidRows, 2)
    lu.assertEquals(overview.invalidRows[1].rowIndex, 3)
    lu.assertEquals(overview.invalidRows[1].code, "talent_shop_conflict")
end

function TestRunPlannerRewardPlanning.testRouteContextOnlyAppliesShopTalentBlockerToNextRow()
    local routeContext = rewardLegalityRouteContext({
        key = "Underworld",
        label = "Underworld",
        biomes = { "F" },
    }, {
        RouteF = fakeRouteControlSnapshot("RouteF", {
            routeRewardRow(1, "SpellDrop"),
            routeRewardRow(2, "TalentDrop", {
                rewardKind = "shop",
            }),
            routeRewardRow(3, "MaxHealthDrop"),
            routeRewardRow(4, "TalentBigDrop"),
        }),
    })

    local overview = routeContext:overview("Underworld")

    lu.assertTrue(overview.valid)
    lu.assertEquals(#overview.invalidRows, 0)
end

function TestRunPlannerRewardPlanning.testRouteContextInvalidatesHermesAfterPendingShopHermes()
    local routeContext = rewardLegalityRouteContext({
        key = "Underworld",
        label = "Underworld",
        biomes = { "F" },
    }, {
        RouteF = fakeRouteControlSnapshot("RouteF", {
            routeRewardRow(1, "ShopHermesUpgrade", {
                rewardKind = "shop",
            }),
            routeRewardRow(2, "HermesUpgrade"),
        }),
    })

    local overview = routeContext:overview("Underworld")

    lu.assertFalse(overview.valid)
    lu.assertEquals(#overview.invalidRows, 2)
    lu.assertEquals(overview.invalidRows[1].rowIndex, 2)
    lu.assertEquals(overview.invalidRows[1].code, "hermes_shop_conflict")
end

function TestRunPlannerRewardPlanning.testRouteContextDevotionPairSkipsPreviousExitRequirement()
    local routeContext = rewardLegalityRouteContext({
        key = "Surface",
        label = "Surface",
        biomes = { "O" },
    }, {
        RouteO = fakeRouteControlSnapshot("RouteO", {
            routeRewardRow(1, "Boon", {
                rewards = { "Boon", "ZeusUpgrade" },
            }),
            routeRewardRow(2, "Boon", {
                rewards = { "Boon", "ApolloUpgrade" },
            }),
            routeRewardRow(3, "MaxHealthDrop"),
            routeRewardRow(4, "MaxHealthDrop"),
            routeRewardRow(5, "MaxHealthDrop"),
            routeRewardRow(6, "MaxHealthDrop"),
            routeRewardRow(7, "MaxHealthDrop"),
            routeRewardRow(8, "Devotion", {
                rewardKind = "devotionPair",
                rewards = { "ZeusUpgrade", "ApolloUpgrade" },
            }),
        }),
    })

    local overview = routeContext:overview("Surface")

    lu.assertTrue(overview.valid)
    lu.assertNil(routeContext:rewardRowValidation("Surface", "O", 8))
end

function TestRunPlannerRewardPlanning.testRouteContextDevotionPairRequiresPriorGodLoot()
    local routeContext = rewardLegalityRouteContext({
        key = "Surface",
        label = "Surface",
        biomes = { "O" },
    }, {
        RouteO = fakeRouteControlSnapshot("RouteO", {
            routeRewardRow(1, "Devotion", {
                rewardKind = "devotionPair",
                rewards = { "ZeusUpgrade", "ApolloUpgrade" },
            }),
        }),
    })

    local overview = routeContext:overview("Surface")

    lu.assertFalse(overview.valid)
    lu.assertEquals(#overview.invalidRows, 1)
    lu.assertEquals(overview.invalidRows[1].rowIndex, 1)
    lu.assertEquals(overview.invalidRows[1].code, "prior_distinct_god_loot")
end

function TestRunPlannerRewardPlanning.testRouteContextSelectableDevotionRequiresPreviousExitCount()
    local routeContext = rewardLegalityRouteContext({
        key = "Underworld",
        label = "Underworld",
        biomes = { "F" },
    }, {
        RouteF = fakeRouteControlSnapshot("RouteF", {
            routeRewardRow(1, "Boon", {
                rewards = { "Major", "Boon", "ZeusUpgrade" },
                rewardKind = "majorMinor",
                rewardPicks = {
                    { kind = "boonSource", value = "ZeusUpgrade" },
                },
            }),
            routeRewardRow(2, "Boon", {
                rewards = { "Major", "Boon", "ApolloUpgrade" },
                rewardKind = "majorMinor",
                rewardPicks = {
                    { kind = "boonSource", value = "ApolloUpgrade" },
                },
            }),
            routeRewardRow(3, "Devotion", {
                rewards = { "Major", "Devotion", "", "", "ZeusUpgrade", "ApolloUpgrade" },
                rewardKind = "majorMinor",
            }),
        }),
    })

    local overview = routeContext:overview("Underworld")

    lu.assertFalse(overview.valid)
    lu.assertEquals(#overview.invalidRows, 1)
    lu.assertEquals(overview.invalidRows[1].rowIndex, 3)
    lu.assertEquals(overview.invalidRows[1].code, "previous_room_exit_count")
end

function TestRunPlannerRewardPlanning.testRouteContextInvalidatesHermesBiomeAndRouteLimits()
    local routeContext = rewardLegalityRouteContext({
        key = "Underworld",
        label = "Underworld",
        biomes = { "F", "G", "H" },
    }, {
        RouteF = fakeRouteControlSnapshot("RouteF", {
            routeRewardRow(1, "HermesUpgrade"),
            routeRewardRow(2, "ShopHermesUpgrade"),
        }),
        RouteG = fakeRouteControlSnapshot("RouteG", {
            routeRewardRow(1, "HermesUpgrade"),
        }),
        RouteH = fakeRouteControlSnapshot("RouteH", {
            routeRewardRow(1, "HermesUpgrade"),
        }),
    })

    local overview = routeContext:overview("Underworld")

    lu.assertFalse(overview.valid)
    lu.assertEquals(#overview.invalidRows, 2)
    lu.assertEquals(overview.invalidRows[1].biomeKey, "F")
    lu.assertEquals(overview.invalidRows[1].rowIndex, 2)
    lu.assertEquals(overview.invalidRows[1].code, "hermes_biome_limit")
end

function TestRunPlannerRewardPlanning.testRouteContextInvalidatesEarlySecondWeaponUpgrade()
    local routeContext = rewardLegalityRouteContext({
        key = "Underworld",
        label = "Underworld",
        biomes = { "F", "G", "H" },
    }, {
        RouteF = fakeRouteControlSnapshot("RouteF", {
            routeRewardRow(1, "WeaponUpgrade"),
        }),
        RouteG = fakeRouteControlSnapshot("RouteG", {
            routeRewardRow(1, "WeaponUpgrade"),
        }),
        RouteH = fakeRouteControlSnapshot("RouteH", {
            routeRewardRow(1, "WeaponUpgradeDrop"),
        }),
    })

    local overview = routeContext:overview("Underworld")

    lu.assertFalse(overview.valid)
    lu.assertEquals(#overview.invalidRows, 2)
    lu.assertEquals(overview.invalidRows[1].biomeKey, "G")
    lu.assertEquals(overview.invalidRows[1].code, "weapon_upgrade_late_requirement")
end

function TestRunPlannerRewardPlanning.testRouteContextAllowsSecondWeaponUpgradeFromThirdBiome()
    local routeContext = rewardLegalityRouteContext({
        key = "Underworld",
        label = "Underworld",
        biomes = { "F", "G", "H" },
    }, {
        RouteF = fakeRouteControlSnapshot("RouteF", {
            routeRewardRow(1, "WeaponUpgrade"),
        }),
        RouteG = fakeRouteControlSnapshot("RouteG", {}),
        RouteH = fakeRouteControlSnapshot("RouteH", {
            routeRewardRow(1, "WeaponUpgradeDrop"),
        }),
    })

    local overview = routeContext:overview("Underworld")

    lu.assertTrue(overview.valid)
    lu.assertEquals(#overview.invalidRows, 0)
end

function TestRunPlannerRewardPlanning.testRouteContextInvalidatesWeaponUpgradeAfterPreviousShopHammer()
    local routeContext = rewardLegalityRouteContext({
        key = "Underworld",
        label = "Underworld",
        biomes = { "F", "G", "H" },
    }, {
        RouteF = fakeRouteControlSnapshot("RouteF", {}),
        RouteG = fakeRouteControlSnapshot("RouteG", {}),
        RouteH = fakeRouteControlSnapshot("RouteH", {
            routeRewardRow(1, "WeaponUpgradeDrop", {
                rewardKind = "shop",
            }),
            routeRewardRow(2, "WeaponUpgrade"),
        }),
    })

    local overview = routeContext:overview("Underworld")

    lu.assertFalse(overview.valid)
    lu.assertEquals(#overview.invalidRows, 2)
    lu.assertEquals(overview.invalidRows[1].biomeKey, "H")
    lu.assertEquals(overview.invalidRows[1].rowIndex, 2)
    lu.assertEquals(overview.invalidRows[1].code, "weapon_upgrade_shop_conflict")
end

function TestRunPlannerRewardPlanning.testRouteContextOnlyAppliesShopHammerBlockerToNextRow()
    local routeContext = rewardLegalityRouteContext({
        key = "Underworld",
        label = "Underworld",
        biomes = { "F", "G", "H" },
    }, {
        RouteF = fakeRouteControlSnapshot("RouteF", {}),
        RouteG = fakeRouteControlSnapshot("RouteG", {}),
        RouteH = fakeRouteControlSnapshot("RouteH", {
            routeRewardRow(1, "WeaponUpgradeDrop", {
                rewardKind = "shop",
            }),
            routeRewardRow(2, "MaxHealthDrop"),
            routeRewardRow(3, "WeaponUpgrade"),
        }),
    })

    local overview = routeContext:overview("Underworld")

    lu.assertTrue(overview.valid)
    lu.assertEquals(#overview.invalidRows, 0)
end

function TestRunPlannerRewardPlanning.testRouteContextInvalidatesThirdWeaponUpgrade()
    local routeContext = rewardLegalityRouteContext({
        key = "Underworld",
        label = "Underworld",
        biomes = { "F", "G", "H", "I" },
    }, {
        RouteF = fakeRouteControlSnapshot("RouteF", {
            routeRewardRow(1, "WeaponUpgrade"),
        }),
        RouteG = fakeRouteControlSnapshot("RouteG", {}),
        RouteH = fakeRouteControlSnapshot("RouteH", {
            routeRewardRow(1, "WeaponUpgradeDrop"),
        }),
        RouteI = fakeRouteControlSnapshot("RouteI", {
            routeRewardRow(1, "WeaponUpgrade"),
        }),
    })

    local overview = routeContext:overview("Underworld")

    lu.assertFalse(overview.valid)
    lu.assertEquals(#overview.invalidRows, 2)
    lu.assertEquals(overview.invalidRows[1].biomeKey, "I")
    lu.assertEquals(overview.invalidRows[1].code, "weapon_upgrade_run_limit")
end

function TestRunPlannerRewardPlanning.testFixedLinearRuntimeInvalidatesDevotionRewardRequirements()
    local catalog = loadCatalog()
    local template = loadFixedLinearTemplate()
    local instance = template.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
	    local control = template.createRuntime(routeFields({
	            {
	                RoleKey = "",
	            },
	            {
	                RoleKey = "Combat",
	                OptionKey = "F_Combat02",
                Reward1Key = "Major",
                Reward2Key = "Boon",
                Reward3Key = "ZeusUpgrade",
            },
            {
                RoleKey = "Combat",
                OptionKey = "F_Combat03",
            },
            {
                RoleKey = "Combat",
                OptionKey = "F_Combat04",
            },
            {
                RoleKey = "Combat",
                OptionKey = "F_Combat04",
            },
            {
                RoleKey = "Combat",
                OptionKey = "F_Combat05",
                Reward1Key = "Major",
                Reward2Key = "Devotion",
                Reward5Key = "ZeusUpgrade",
                Reward6Key = "ApolloUpgrade",
            },
	        }), instance)
    local routeContext = loadRunContext().create({
        routes = routeDefinitions({
            {
                key = "Underworld",
                label = "Underworld",
                biomes = { "F" },
            },
        }),
        controlResolver = function(controlName)
            if controlName == "RouteF" then
                return control
            end
            return nil
        end,
    })
    control:setRouteContext(routeContext, "Underworld")

    local validation = control:rowValidation(6)

    lu.assertFalse(validation.valid)
    lu.assertEquals(validation.code, "prior_distinct_god_loot")
    lu.assertEquals(routeContext:rewardRowValidation("Underworld", "F", 6).code, "prior_distinct_god_loot")
end

function TestRunPlannerRewardPlanning.testRouteOverviewInvalidatesDuplicateTrialRewardGods()
    local catalog = loadCatalog()
    local template = loadFixedLinearTemplate()
    local instance = template.prepare({
        name = "RouteF",
        biome = catalog.lookup.F,
    })
    local control = template.createRuntime(routeFields({
        {
            RoleKey = "",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat02",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat03",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat06",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat04",
        },
        {
            RoleKey = "Combat",
            OptionKey = "F_Combat05",
            Reward1Key = "Major",
            Reward2Key = "Devotion",
            Reward5Key = "ZeusUpgrade",
            Reward6Key = "ZeusUpgrade",
        },
    }), instance)
    local routeContext = loadRunContext().create({
        routes = routeDefinitions({
            {
                key = "Underworld",
                label = "Underworld",
                biomes = { "F" },
            },
        }),
        controlResolver = function(controlName)
            if controlName == "RouteF" then
                return control
            end
            return nil
        end,
    })

    local overview = routeContext:overview("Underworld")

    lu.assertFalse(overview.valid)
    lu.assertEquals(overview.invalidRows[1].rowIndex, 6)
    lu.assertEquals(overview.invalidRows[1].code, "duplicate_devotion_god")
    lu.assertEquals(overview.invalidRows[1].message, "Trial gods must be different")
end
