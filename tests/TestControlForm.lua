local lu = require("luaunit")
local h = require("tests.support.control_harness")

local form = h.withTestImport(function()
    return h.testImport("mods/controls/form.lua", nil, {
        valueStates = h.testImport("mods/ui/value_states.lua"),
    })
end)
local fakeRows = h.fakeRows

-- luacheck: globals TestRunPlannerControlForm
TestRunPlannerControlForm = {}

function TestRunPlannerControlForm.testInvalidBuildsSelectedCompletionTarget()
    local invalid = form.invalid({
        code = "option_required",
        label = "Combat",
        tabKey = "rooms",
        controlAlias = "OptionKey",
    })

    lu.assertFalse(invalid.valid)
    lu.assertTrue(form.isCompletionInvalid(invalid))
    lu.assertEquals(invalid.message, "Combat needs a concrete selection")
    lu.assertEquals(invalid.controlTargets[1], {
        tabKey = "rooms",
        controlAlias = "OptionKey",
        state = 3,
        mode = "selected",
    })
end

function TestRunPlannerControlForm.testValidateRoomChoiceUsesRoomVocabularyForUnknownStoredKeys()
    local data = {
        resolveRole = function(_, rows, rowIndex)
            local roleKey = rows:read(rowIndex, "RoleKey") or ""
            if roleKey == "Combat" then
                return roleKey, {
                    key = "Combat",
                    label = "Combat",
                    roomOptions = {
                        { key = "F_Combat01" },
                    },
                }
            end
            return roleKey, nil
        end,
        optionListForRole = function(role)
            return role.roomOptions or {}
        end,
        resolveOption = function(_, rows, rowIndex)
            local optionKey = rows:read(rowIndex, "OptionKey") or ""
            if optionKey == "F_Combat01" then
                return optionKey, { key = optionKey }
            end
            return optionKey, nil
        end,
    }

    local unknownRole = form.validateRoomChoice({
        data = data,
        instance = {},
        rows = fakeRows({
            { RoleKey = "BadRole" },
        }),
        rowIndex = 1,
    })
    lu.assertFalse(unknownRole.valid)
    lu.assertEquals(unknownRole.message, "Unknown room type: BadRole")

    local unknownOption = form.validateRoomChoice({
        data = data,
        instance = {},
        rows = fakeRows({
            { RoleKey = "Combat", OptionKey = "BadRoom" },
        }),
        rowIndex = 1,
    })
    lu.assertFalse(unknownOption.valid)
    lu.assertEquals(unknownOption.message, "Unknown room option: BadRoom")
end

function TestRunPlannerControlForm.testIndexedRenderHelpersClampCounts()
    lu.assertEquals(form.clampedCount(5, 2), 2)
    lu.assertEquals(form.clampedCount(-1, 2), 0)
    lu.assertTrue(form.shouldDrawIndex(2, 2))
    lu.assertFalse(form.shouldDrawIndex(2, 3))
end

function TestRunPlannerControlForm.testSingleStaticValueRequiresConcreteSingleton()
    lu.assertEquals(form.singleConcreteValue({ "", "A" }), "A")
    lu.assertNil(form.singleConcreteValue({ "A", "B" }))
    lu.assertEquals(form.shouldRenderStaticValue({ "A" }, ""), "A")
    lu.assertEquals(form.shouldRenderStaticValue({ "A" }, "A"), "A")
    lu.assertNil(form.shouldRenderStaticValue({ "A" }, "B"))
end
