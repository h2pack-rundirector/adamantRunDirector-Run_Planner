local lu = require("luaunit")
local h = require("tests.support.control_harness")

local form = h.withTestImport(function()
    return h.testImport("mods/controls/form.lua", nil, {
        valueStates = h.testImport("mods/ui/value_states.lua"),
    })
end)

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
        state = 2,
        mode = "selected",
    })
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
