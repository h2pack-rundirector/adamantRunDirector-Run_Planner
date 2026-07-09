-- luacheck: globals TestFeedbackPresentation

local lu = require("luaunit")
local h = dofile("tests/support/import_harness.lua")
local fakeImgui = dofile("tests/support/fake_imgui.lua")

TestFeedbackPresentation = {}

function TestFeedbackPresentation.testDrawColorsRouteBlocker()
    h.withTestImport(function()
        local presentation = h.testImport("mods/ui/forms/feedback_presentation.lua")
        local lines, imgui = fakeImgui.surface()

        local drawn = presentation.draw(imgui, "Route blocker", {
            severity = "invalid",
            code = "f_preboss_too_early",
            message = "Pre-boss room is too early.",
        }, {
            role = "blocker",
        })

        lu.assertTrue(drawn)
        lu.assertEquals(lines, {
            "Route blocker: f_preboss_too_early - Pre-boss room is too early.",
        })
        lu.assertEquals(fakeImgui.countCalls(imgui, "PushStyleColor"), 1)
        lu.assertEquals(fakeImgui.countCalls(imgui, "PopStyleColor"), 1)
    end)
end

function TestFeedbackPresentation.testFormatsFieldFeedbackAndNoopsWhenAbsent()
    h.withTestImport(function()
        local presentation = h.testImport("mods/ui/forms/feedback_presentation.lua")
        local lines, imgui = fakeImgui.surface()

        lu.assertFalse(presentation.draw(imgui, "Reward feedback", nil))
        lu.assertEquals(lines, {})

        local drawn = presentation.draw(imgui, "Reward feedback", {
            severity = "incomplete",
            code = "reward_type_required",
            field = "rewardType",
            message = "Reward type is required.",
        })

        lu.assertTrue(drawn)
        lu.assertEquals(lines, {
            "Reward feedback: reward_type_required [rewardType] - Reward type is required.",
        })
        lu.assertEquals(presentation.colorFor({ severity = "incomplete" }), { 1.0, 0.72, 0.25, 1.0 })
    end)
end
