-- luacheck: globals TestFErebusPanel

local lu = require("luaunit")
local h = dofile("tests/support/import_harness.lua")
local fakeImgui = dofile("tests/support/fake_imgui.lua")

TestFErebusPanel = {}

local function lineSink()
    return fakeImgui.lineSink()
end

local function callIndex(imgui, predicate)
    for index, call in ipairs(imgui._calls or {}) do
        if predicate(call) then
            return index
        end
    end
    return nil
end

local function callIndexByName(imgui, name)
    return callIndex(imgui, function(call)
        return call.name == name
    end)
end

local function textCallIndexContaining(imgui, text)
    return callIndex(imgui, function(call)
        return call.name == "Text" and tostring(call.args[1]):find(text, 1, true) ~= nil
    end)
end

function TestFErebusPanel.testDrawsPlannerStateThroughForms()
    h.withTestImport(function()
        local data = h.testImport("mods/data.lua")
        local plannerState = h.testImport("mods/ui/planner/state.lua")
        local fErebusPanel = h.testImport("mods/ui/biomes/f_erebus_panel.lua")
        local state = plannerState.create({
            catalog = data.loadCatalog(),
        })
        local lines, ctx = lineSink()

        fErebusPanel.draw(state, ctx)

        local combined = table.concat(lines, "\n")
        lu.assertNotNil(combined:find("F / Erebus", 1, true))
        lu.assertNil(combined:find("debug harness", 1, true))
        lu.assertNotNil(combined:find("State: valid", 1, true))
        lu.assertNotNil(combined:find("Room 1 - Opening 1 (F_Opening01)", 1, true))
        lu.assertNotNil(combined:find("Room identity", 1, true))
        lu.assertNotNil(combined:find("Generated door batch", 1, true))
        lu.assertNotNil(combined:find("Generated reward offer", 1, true))
        lu.assertNotNil(combined:find("##routeUnderworld_biome1_room1_door1_offer1_rewardType", 1, true))
        lu.assertEquals(fakeImgui.countCalls(ctx.draw.imgui, "BeginDisabled"), 0)
        lu.assertNil(combined:find("Downstream inactive", 1, true))
    end)
end

function TestFErebusPanel.testDrawsFirstBlockingIssueMarker()
    h.withTestImport(function()
        local data = h.testImport("mods/data.lua")
        local plannerState = h.testImport("mods/ui/planner/state.lua")
        local fErebusPanel = h.testImport("mods/ui/biomes/f_erebus_panel.lua")
        local state = plannerState.create({
            catalog = data.loadCatalog(),
        })
        state.setDoorTarget(2, 1, "F_PreBoss01")
        local lines, ctx = lineSink()

        fErebusPanel.draw(state, ctx)

        local combined = table.concat(lines, "\n")
        lu.assertNotNil(combined:find(
            "First issue: f_preboss_too_early at Room 2 (F_Combat01) door 1 (room.generate_next)",
            1,
            true
        ))
        lu.assertNotNil(combined:find("Route blocker: f_preboss_too_early", 1, true))
    end)
end

function TestFErebusPanel.testDrawsDownstreamRoomsInactiveAfterFirstIssue()
    h.withTestImport(function()
        local data = h.testImport("mods/data.lua")
        local plannerState = h.testImport("mods/ui/planner/state.lua")
        local fErebusPanel = h.testImport("mods/ui/biomes/f_erebus_panel.lua")
        local state = plannerState.create({
            catalog = data.loadCatalog(),
        })
        state.setDoorTarget(2, 1, "F_PreBoss01")
        state.appendSelectedTarget()
        local lines, ctx = lineSink()

        fErebusPanel.draw(state, ctx)

        local combined = table.concat(lines, "\n")
        local imgui = ctx.draw.imgui
        local blockerIndex = textCallIndexContaining(imgui, "Route blocker: f_preboss_too_early")
        local markerIndex = textCallIndexContaining(imgui, "Downstream inactive after first issue")
        local disabledIndex = callIndexByName(imgui, "BeginDisabled")
        local room3Index = textCallIndexContaining(imgui, "Room 3")

        lu.assertEquals(fakeImgui.countCalls(ctx.draw.imgui, "BeginDisabled"), 1)
        lu.assertEquals(fakeImgui.countCalls(ctx.draw.imgui, "EndDisabled"), 1)
        lu.assertNotNil(combined:find("Room 3", 1, true))
        lu.assertNotNil(combined:find(
            "Downstream inactive after first issue: Room 2 (F_Combat01) door 1",
            1,
            true
        ))
        lu.assertNotNil(blockerIndex)
        lu.assertNotNil(markerIndex)
        lu.assertNotNil(disabledIndex)
        lu.assertNotNil(room3Index)
        lu.assertTrue(blockerIndex < markerIndex)
        lu.assertTrue(markerIndex < disabledIndex)
        lu.assertTrue(disabledIndex < room3Index)
    end)
end

function TestFErebusPanel.testDrawsRewardTypeCompletionFeedbackLocally()
    h.withTestImport(function()
        local data = h.testImport("mods/data.lua")
        local plannerState = h.testImport("mods/ui/planner/state.lua")
        local fErebusPanel = h.testImport("mods/ui/biomes/f_erebus_panel.lua")
        local state = plannerState.create({
            catalog = data.loadCatalog(),
        })
        state.setRewardType(1, 1, "Auto")
        local evaluation = state.ensureEvaluation()
        local lines, ctx = lineSink()

        fErebusPanel.draw(state, ctx, {
            evaluation = evaluation,
        })

        local combined = table.concat(lines, "\n")
        lu.assertEquals(evaluation.state, "incomplete")
        lu.assertNil(evaluation.history)
        lu.assertEquals(evaluation.candidateResults, {})
        lu.assertNotNil(combined:find("State: incomplete", 1, true))
        lu.assertNotNil(combined:find(
            "Reward feedback: reward_type_required [rewardType] - Reward type must be concrete.",
            1,
            true
        ))
        lu.assertNil(combined:find("Route blocker: reward_type_required", 1, true))
        lu.assertNil(combined:find("Downstream inactive", 1, true))
        lu.assertEquals(fakeImgui.countCalls(ctx.draw.imgui, "BeginDisabled"), 0)
    end)
end

function TestFErebusPanel.testDrawsDevotionSourceCompletionFeedbackLocally()
    h.withTestImport(function()
        local data = h.testImport("mods/data.lua")
        local plannerState = h.testImport("mods/ui/planner/state.lua")
        local fErebusPanel = h.testImport("mods/ui/biomes/f_erebus_panel.lua")
        local state = plannerState.create({
            catalog = data.loadCatalog(),
        })
        state.setRewardType(1, 1, "Devotion")
        state.setDevotionSource(1, 1, 2, "Auto")
        local evaluation = state.ensureEvaluation()
        local lines, ctx = lineSink()

        fErebusPanel.draw(state, ctx, {
            evaluation = evaluation,
        })

        local combined = table.concat(lines, "\n")
        lu.assertEquals(evaluation.state, "incomplete")
        lu.assertNil(evaluation.history)
        lu.assertEquals(evaluation.candidateResults, {})
        lu.assertNotNil(combined:find(
            "Reward feedback: devotion_source_required [payload.sources[2]] - Devotion source must be concrete.",
            1,
            true
        ))
        lu.assertNil(combined:find("Route blocker: devotion_source_required", 1, true))
        lu.assertNil(combined:find("Downstream inactive", 1, true))
    end)
end

function TestFErebusPanel.testDrawsRoomLocalOfferInsideRoomUnit()
    h.withTestImport(function()
        local data = h.testImport("mods/data.lua")
        local plannerState = h.testImport("mods/ui/planner/state.lua")
        local fErebusPanel = h.testImport("mods/ui/biomes/f_erebus_panel.lua")
        local state = plannerState.create({
            catalog = data.loadCatalog(),
        })
        state.setDoorTarget(1, 1, "F_Shop01")
        state.setRoomKey(2, "F_Shop01")
        local lines, ctx = lineSink()

        fErebusPanel.draw(state, ctx)

        local combined = table.concat(lines, "\n")
        lu.assertNotNil(combined:find("Room 2 - Shop (F_Shop01)", 1, true))
        lu.assertNotNil(combined:find("Room-local offers", 1, true))
        lu.assertNotNil(combined:find("Room offer 1 / shop", 1, true))
        lu.assertNotNil(combined:find("##routeUnderworld_biome1_room2_offerPoint1_offer1_rewardType", 1, true))
    end)
end

function TestFErebusPanel.testDrawDoesNotCallMaterializers()
    h.withTestImport(function()
        local data = h.testImport("mods/data.lua")
        local plannerState = h.testImport("mods/ui/planner/state.lua")
        local fErebusPanel = h.testImport("mods/ui/biomes/f_erebus_panel.lua")
        local state = plannerState.create({
            catalog = data.loadCatalog(),
        })
        local evaluation = state.ensureEvaluation()
        state.ensureOffer = function()
            error("draw called generated offer materializer")
        end
        state.ensureRoomOffer = function()
            error("draw called room offer materializer")
        end
        state.defaultPayloadForRewardType = function()
            error("draw called payload materializer")
        end
        local lines, ctx = lineSink()

        fErebusPanel.draw(state, ctx, {
            hideStatus = true,
            evaluation = evaluation,
        })

        local combined = table.concat(lines, "\n")
        lu.assertNotNil(combined:find("Generated reward offer", 1, true))
    end)
end

function TestFErebusPanel.testFormsReadProvidersFromParticipants()
    h.withTestImport(function()
        local data = h.testImport("mods/data.lua")
        local identity = h.testImport("mods/ui/forms/identity.lua")
        local plannerState = h.testImport("mods/ui/planner/state.lua")
        local fErebusPanel = h.testImport("mods/ui/biomes/f_erebus_panel.lua")
        local state = plannerState.create({
            catalog = data.loadCatalog(),
        })
        local evaluation = state.ensureEvaluation()
        local doorContext = {
            routeKey = state.draft.routeKey,
            biomeIndex = 1,
            roomIndex = 2,
            doorIndex = 1,
        }
        local door = state.currentBiome().rooms[2].generatedDoors.doors[1]
        local offer = door.offerPoint.offers[1]
        state.participants:find(identity.generatedDoor(doorContext)).providers.nextDoorTarget = {
            values = { door.targetRoomKey },
            labels = { "Participant target" },
        }
        state.participants:find(identity.generatedOffer(doorContext, 1)).providers.rewardType = {
            values = { offer.rewardType },
            labels = { "Participant reward" },
        }
        door.candidateProviders = {
            nextDoorTarget = {
                values = { door.targetRoomKey },
                labels = { "Bridge target" },
            },
        }
        offer.candidateProviders = {
            rewardType = {
                values = { offer.rewardType },
                labels = { "Bridge reward" },
            },
        }
        local lines, ctx = lineSink()

        fErebusPanel.draw(state, ctx, {
            hideStatus = true,
            evaluation = evaluation,
        })

        local combined = table.concat(lines, "\n")
        lu.assertNotNil(combined:find("Participant target", 1, true))
        lu.assertNotNil(combined:find("Participant reward", 1, true))
        lu.assertNil(combined:find("Bridge target", 1, true))
        lu.assertNil(combined:find("Bridge reward", 1, true))
    end)
end

function TestFErebusPanel.testDrawShowsCandidateProviderMessagesAfterRouteRebuild()
    h.withTestImport(function()
        local data = h.testImport("mods/data.lua")
        local plannerState = h.testImport("mods/ui/planner/state.lua")
        local fErebusPanel = h.testImport("mods/ui/biomes/f_erebus_panel.lua")
        local state = plannerState.create({
            catalog = data.loadCatalog(),
        })
        local tooltips = {}
        local _, ctx = fakeImgui.lineSink({
            imgui = {
                BeginCombo = function()
                    return true
                end,
                IsItemHovered = function()
                    return true
                end,
                SetTooltip = function(message)
                    tooltips[#tooltips + 1] = message
                end,
            },
        })

        fErebusPanel.draw(state, ctx, {
            hideStatus = true,
        })

        local combinedTooltips = table.concat(tooltips, "\n")
        lu.assertStrContains(combinedTooltips, "Generated room target fails declared eligibility.")
        lu.assertStrContains(combinedTooltips, "Devotion sources must already exist in acquired loot history.")
    end)
end

function TestFErebusPanel.testRoomOfferAndDevotionReadParticipantProviders()
    h.withTestImport(function()
        local data = h.testImport("mods/data.lua")
        local identity = h.testImport("mods/ui/forms/identity.lua")
        local plannerState = h.testImport("mods/ui/planner/state.lua")
        local fErebusPanel = h.testImport("mods/ui/biomes/f_erebus_panel.lua")
        local state = plannerState.create({
            catalog = data.loadCatalog(),
        })
        state.setRewardType(1, 1, "Devotion")
        state.setDoorTarget(1, 1, "F_Shop01")
        state.setRoomKey(2, "F_Shop01")
        local evaluation = state.ensureEvaluation()
        local generatedContext = {
            routeKey = state.draft.routeKey,
            biomeIndex = 1,
            roomIndex = 1,
            doorIndex = 1,
        }
        local roomContext = {
            routeKey = state.draft.routeKey,
            biomeIndex = 1,
            roomIndex = 2,
        }
        local generatedOffer = state.currentBiome().rooms[1].generatedDoors.doors[1].offerPoint.offers[1]
        local roomOffer = state.currentBiome().rooms[2].offerPoints[1].offers[1]
        state.participants:find(identity.generatedOffer(generatedContext, 1)).providers.devotionSource1 = {
            values = { generatedOffer.payload.sources[1] },
            labels = { "Participant devotion source" },
        }
        state.participants:find(identity.roomOffer(roomContext, 1, 1)).providers.rewardType = {
            values = { roomOffer.rewardType },
            labels = { "Participant room reward" },
        }
        generatedOffer.candidateProviders = {
            devotionSource1 = {
                values = { generatedOffer.payload.sources[1] },
                labels = { "Bridge devotion source" },
            },
        }
        roomOffer.candidateProviders = {
            rewardType = {
                values = { roomOffer.rewardType },
                labels = { "Bridge room reward" },
            },
        }
        local lines, ctx = lineSink()

        fErebusPanel.draw(state, ctx, {
            hideStatus = true,
            evaluation = evaluation,
        })

        local combined = table.concat(lines, "\n")
        lu.assertNotNil(combined:find("Participant devotion source", 1, true))
        lu.assertNotNil(combined:find("Participant room reward", 1, true))
        lu.assertNil(combined:find("Bridge devotion source", 1, true))
        lu.assertNil(combined:find("Bridge room reward", 1, true))
    end)
end
