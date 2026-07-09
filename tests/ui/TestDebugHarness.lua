-- luacheck: globals TestDebugHarness

local lu = require("luaunit")
local h = dofile("tests/support/import_harness.lua")
local fakeImgui = dofile("tests/support/fake_imgui.lua")

TestDebugHarness = {}

local function createHarness()
    local data = h.testImport("mods/data.lua")
    local debugHarness = h.testImport("mods/ui/debug_harness.lua")
    return debugHarness.create({
        catalog = data.loadCatalog(),
    })
end

local function lineSink()
    return fakeImgui.lineSink()
end

local function feedbackCodeAt(result, address)
    for _, feedback in ipairs(result.feedback or {}) do
        local matches = true
        for key, value in pairs(address) do
            if feedback.address[key] ~= value then
                matches = false
                break
            end
        end
        if matches then
            return feedback.code
        end
    end
    return nil
end

local function optionIndex(provider, value)
    for index, candidate in ipairs(provider.values or {}) do
        if candidate == value then
            return index
        end
    end
    return nil
end

local function candidateCodeCount(result, code)
    local count = 0
    for _, candidate in ipairs(result.candidateResults or {}) do
        if candidate.code == code then
            count = count + 1
        end
    end
    return count
end

function TestDebugHarness.testDefaultDraftEvaluatesThroughRealPipeline()
    h.withTestImport(function()
        local harness = createHarness()

        local result = harness.ensureEvaluation()

        lu.assertEquals(result.state, "valid")
        lu.assertTrue(result.complete)
        lu.assertTrue(result.valid)
        lu.assertNotNil(result.history)
        lu.assertEquals(#result.candidateResults, 33)
        lu.assertEquals(candidateCodeCount(result, "generated_door_target_start_room"), 6)
        lu.assertEquals(candidateCodeCount(result, "f_combat05_early"), 2)
        lu.assertEquals(candidateCodeCount(result, "f_story_arachne_too_early"), 2)
        lu.assertEquals(candidateCodeCount(result, "f_preboss_too_early"), 2)
        lu.assertEquals(candidateCodeCount(result, "room_creation_cap_exceeded"), 1)

        local provider = harness.draft.biomes[1].rooms[2].generatedDoors.doors[1].candidateProviders.nextDoorTarget
        lu.assertEquals(provider.messages[optionIndex(provider, "F_Opening01")], "Generated doors cannot target start-kind rooms.")
        lu.assertEquals(provider.messages[optionIndex(provider, "F_Combat01")], "Generated room target exceeds its creation cap.")
        lu.assertEquals(provider.messages[optionIndex(provider, "F_Combat05")], "Generated room target fails declared eligibility.")
        lu.assertTrue(provider.hidden[optionIndex(provider, "F_Combat05")])
        lu.assertEquals(provider.messages[optionIndex(provider, "F_Story01")], "Generated room target fails declared eligibility.")
        lu.assertFalse(provider.hidden[optionIndex(provider, "F_Story01")])
        lu.assertTrue(provider.hidden[optionIndex(provider, "F_PreBoss01")])

        local rewardProvider = harness.draft.biomes[1].rooms[2].generatedDoors.doors[1].offerPoint.offers[1].candidateProviders.rewardType
        lu.assertEquals(rewardProvider.messages[4], "Devotion sources must already exist in acquired loot history.")
    end)
end

function TestDebugHarness.testSelectedDoorEditReturnsValidationFeedback()
    h.withTestImport(function()
        local harness = createHarness()

        harness.setDoorTarget(2, 1, "F_PreBoss01")
        local result = harness.evaluate()

        lu.assertEquals(result.state, "invalid")
        lu.assertFalse(result.valid)
        lu.assertEquals(result.feedback[1].code, "f_preboss_too_early")
        lu.assertEquals(result.feedback[1].address, {
            routeKey = "Underworld",
            biomeIndex = 1,
            roomIndex = 2,
            doorIndex = 1,
        })
    end)
end

function TestDebugHarness.testAppendSelectedTargetExtendsMutableDraft()
    h.withTestImport(function()
        local harness = createHarness()

        lu.assertEquals(#harness.draft.biomes[1].rooms, 2)
        lu.assertTrue(harness.appendSelectedTarget())

        lu.assertEquals(#harness.draft.biomes[1].rooms, 3)
        lu.assertEquals(harness.draft.biomes[1].rooms[3].roomKey, "F_Combat02")
        lu.assertEquals(#harness.draft.biomes[1].rooms[3].generatedDoors.doors, 2)
    end)
end

function TestDebugHarness.testShopRoomCreatesRoomOfferControls()
    h.withTestImport(function()
        local harness = createHarness()

        harness.setDoorTarget(1, 1, "F_Shop01")
        harness.setRoomKey(2, "F_Shop01")
        local result = harness.evaluate()

        local room = harness.draft.biomes[1].rooms[2]
        lu.assertNotNil(room.offerPoints)
        lu.assertEquals(room.offerPoints[1].kind, "shop")
        lu.assertEquals(room.offerPoints[1].offers[1].store, "WorldShop")
        lu.assertNotNil(room.offerPoints[1].offers[1].candidateProviders.rewardType)
        lu.assertTrue(result.complete)
    end)
end

function TestDebugHarness.testRoomOfferPendingStoreFeedbackReachesHarness()
    h.withTestImport(function()
        local harness = createHarness()

        harness.setDoorTarget(1, 1, "F_Shop01")
        harness.setRoomKey(2, "F_Shop01")
        harness.setRewardType(2, 1, "WeaponUpgrade")
        local result = harness.evaluate()

        lu.assertEquals(feedbackCodeAt(result, {
            routeKey = "Underworld",
            biomeIndex = 1,
            roomIndex = 2,
            doorIndex = 1,
            offerIndex = 1,
        }), "late_hammer_pending_in_shop")
    end)
end

function TestDebugHarness.testDrawTabEmitsStatusWithFakeImguiSurface()
    h.withTestImport(function()
        local harness = createHarness()
        local lines, ctx = lineSink()

        harness.drawTab(nil, ctx)

        local combined = table.concat(lines, "\n")
        lu.assertNotNil(combined:find("Run Planner debug harness", 1, true))
        lu.assertNotNil(combined:find("docs/system_design", 1, true))
        lu.assertNotNil(combined:find("State: valid", 1, true))
        lu.assertNotNil(combined:find("Candidates: 33", 1, true))
    end)
end

function TestDebugHarness.testDrawTabIncludesRoomOfferSurface()
    h.withTestImport(function()
        local harness = createHarness()
        harness.setDoorTarget(1, 1, "F_Shop01")
        harness.setRoomKey(2, "F_Shop01")
        local lines, ctx = lineSink()

        harness.drawTab(nil, ctx)

        local combined = table.concat(lines, "\n")
        lu.assertNotNil(combined:find("Room offer 1 / shop", 1, true))
        lu.assertNotNil(combined:find("Room reward##routeUnderworld_biome1_room2_offerPoint1_offer1_rewardType", 1, true))
    end)
end
