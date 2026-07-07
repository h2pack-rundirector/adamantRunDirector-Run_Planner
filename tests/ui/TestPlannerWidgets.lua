-- luacheck: globals TestPlannerWidgets

local lu = require("luaunit")
local h = dofile("tests/support/import_harness.lua")
local fakeImgui = dofile("tests/support/fake_imgui.lua")

TestPlannerWidgets = {}

function TestPlannerWidgets.testDropdownClosedUsesProviderPreview()
    h.withTestImport(function()
        local widgets = h.testImport("mods/ui/planner/widgets.lua")
        local lines, imgui = fakeImgui.surface()

        local value, changed = widgets.dropdown(imgui, "Target##room1", "B", {
            values = { "A", "B" },
            labels = { "Alpha", "Beta" },
        })

        lu.assertEquals(value, "B")
        lu.assertFalse(changed)
        lu.assertEquals(fakeImgui.countCalls(imgui, "BeginCombo"), 1)
        lu.assertEquals(lines, {
            "Target##room1: Beta",
        })
    end)
end

function TestPlannerWidgets.testDropdownUsesVisibleCandidateState()
    h.withTestImport(function()
        local widgets = h.testImport("mods/ui/planner/widgets.lua")
        local selectableLabels = {}
        local colors = {}
        local tooltips = {}
        local popped = 0
        local _, imgui = fakeImgui.surface({
            BeginCombo = function()
                return true
            end,
            Selectable = function(label)
                selectableLabels[#selectableLabels + 1] = label
                return label == "Gamma##3"
            end,
            EndCombo = function()
            end,
            CloseCurrentPopup = function()
            end,
            PushStyleColor = function(kind, r, g, b, a)
                colors[#colors + 1] = {
                    kind = kind,
                    color = { r, g, b, a },
                }
            end,
            PopStyleColor = function()
                popped = popped + 1
            end,
            IsItemHovered = function()
                return true
            end,
            SetTooltip = function(message)
                tooltips[#tooltips + 1] = message
            end,
        })

        local value, changed = widgets.dropdown(imgui, "Reward", "A", {
            values = { "A", "B", "C" },
            labels = { "Alpha", "Beta", "Gamma" },
            hidden = { false, true, false },
            colors = {
                { 1, 0, 0, 1 },
                nil,
                { 0, 1, 0, 1 },
            },
            messages = {
                "Alpha message",
                nil,
                "Gamma message",
            },
        })

        lu.assertEquals(value, "C")
        lu.assertTrue(changed)
        lu.assertEquals(selectableLabels, { "Alpha##1", "Gamma##3" })
        lu.assertEquals(colors, {
            {
                kind = "Text",
                color = { 1, 0, 0, 1 },
            },
            {
                kind = "Text",
                color = { 0, 1, 0, 1 },
            },
        })
        lu.assertEquals(popped, 2)
        lu.assertEquals(tooltips, { "Alpha message", "Gamma message" })
    end)
end

function TestPlannerWidgets.testDropdownCanSelectCandidateBeforeCurrentWithSelectableChangeReturn()
    h.withTestImport(function()
        local widgets = h.testImport("mods/ui/planner/widgets.lua")
        local closed = 0
        local _, imgui = fakeImgui.surface({
            BeginCombo = function()
                return true
            end,
            Selectable = function(label, selected)
                if label == "Alpha##1" then
                    return true, true
                end
                if selected then
                    return true, false
                end
                return false, false
            end,
            CloseCurrentPopup = function()
                closed = closed + 1
            end,
            EndCombo = function()
            end,
        })

        local value, changed = widgets.dropdown(imgui, "Reward", "C", {
            values = { "A", "B", "C" },
            labels = { "Alpha", "Beta", "Gamma" },
        })

        lu.assertEquals(value, "A")
        lu.assertTrue(changed)
        lu.assertEquals(closed, 1)
    end)
end

function TestPlannerWidgets.testCheckboxUsesImguiValue()
    h.withTestImport(function()
        local widgets = h.testImport("mods/ui/planner/widgets.lua")
        local checkboxCalls = {}
        local _, imgui = fakeImgui.surface({
            Checkbox = function(label, checked)
                checkboxCalls[#checkboxCalls + 1] = {
                    label = label,
                    checked = checked,
                }
                return false, true
            end,
        })

        local value, changed = widgets.checkbox(imgui, "Acquired##1", true)

        lu.assertFalse(value)
        lu.assertTrue(changed)
        lu.assertEquals(checkboxCalls, {
            {
                label = "Acquired##1",
                checked = true,
            },
        })
    end)
end

function TestPlannerWidgets.testDisabledUsesImguiScope()
    h.withTestImport(function()
        local widgets = h.testImport("mods/ui/planner/widgets.lua")
        local calls = {}
        local _, imgui = fakeImgui.surface({
            BeginDisabled = function(disabled)
                calls[#calls + 1] = {
                    kind = "BeginDisabled",
                    disabled = disabled,
                }
            end,
            EndDisabled = function()
                calls[#calls + 1] = {
                    kind = "EndDisabled",
                }
            end,
        })

        local pushed = widgets.beginDisabled(imgui, true)
        widgets.endDisabled(imgui, pushed)

        lu.assertTrue(pushed)
        lu.assertEquals(calls, {
            {
                kind = "BeginDisabled",
                disabled = true,
            },
            {
                kind = "EndDisabled",
            },
        })
    end)
end

function TestPlannerWidgets.testSubsectionAndLabelRenderText()
    h.withTestImport(function()
        local widgets = h.testImport("mods/ui/planner/widgets.lua")
        local lines, imgui = fakeImgui.surface()

        widgets.subsection(imgui, "Generated door batch")
        widgets.labelValue(imgui, "Batch rule", "Standard")

        lu.assertEquals(lines, {
            "Generated door batch",
            "Batch rule: Standard",
        })
    end)
end

function TestPlannerWidgets.testIndentUsesImguiPairWhenAvailable()
    h.withTestImport(function()
        local widgets = h.testImport("mods/ui/planner/widgets.lua")
        local calls = {}
        local imgui = {
            Indent = function()
                calls[#calls + 1] = "Indent"
            end,
            Unindent = function()
                calls[#calls + 1] = "Unindent"
            end,
        }

        local pushed = widgets.indent(imgui)
        widgets.unindent(imgui, pushed)

        lu.assertTrue(pushed)
        lu.assertEquals(calls, { "Indent", "Unindent" })
    end)
end

function TestPlannerWidgets.testStatusRendersSummary()
    h.withTestImport(function()
        local widgets = h.testImport("mods/ui/planner/widgets.lua")
        local lines, imgui = fakeImgui.surface()

        widgets.status(imgui, {
            state = "invalid",
            complete = true,
            valid = false,
            status = {
                feedbackCount = 1,
                firstIssue = {
                    code = "bad_room",
                    phase = "room.generate_next",
                },
            },
            candidateResults = {
                {},
                {},
            },
        })

        lu.assertEquals(lines, {
            "State: invalid",
            "Complete: true  Valid: false",
            "Feedback: 1  Candidates: 2",
            "First issue: bad_room at room.generate_next",
        })
    end)
end
