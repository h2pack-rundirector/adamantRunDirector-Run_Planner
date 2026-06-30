local lu = require("luaunit")

-- luacheck: globals TestRunPlannerBiomeHelpers
TestRunPlannerBiomeHelpers = {}

local nextChoiceView = dofile("src/mods/controls/biome_helpers/next_choice_view.lua")

function TestRunPlannerBiomeHelpers.testNextChoiceModelMapsCurrentAndNextRows()
    local slots = {
        { label = "Opening" },
        { label = "Depth 1" },
        { label = "Depth 2" },
    }
    local view = nextChoiceView.fillRow(
        {},
        2,
        #slots,
        function(rowIndex)
            return slots[rowIndex]
        end,
        function(rowIndex)
            return slots[rowIndex] and slots[rowIndex].label or nil
        end
    )

    lu.assertFalse(view.currentRoom.isEntry)
    lu.assertEquals(view.currentRoom.rowIndex, 2)
    lu.assertEquals(view.currentRoom.label, "Depth 1")
    lu.assertEquals(view.currentRoom.slot, slots[2])

    lu.assertEquals(view.nextChoices.sourceRowIndex, 2)
    lu.assertTrue(view.nextChoices.picked.active)
    lu.assertEquals(view.nextChoices.picked.targetRowIndex, 3)
    lu.assertEquals(view.nextChoices.picked.targetLabel, "Depth 2")
    lu.assertEquals(view.nextChoices.picked.targetSlot, slots[3])

    lu.assertEquals(view.nextChoices.others.sourceRowIndex, 2)
    lu.assertEquals(view.nextChoices.others.sourceLabel, "Depth 1")
    lu.assertEquals(view.nextChoices.others.sourceSlot, slots[2])
end

function TestRunPlannerBiomeHelpers.testNextChoiceModelMarksEntryAndRouteEnd()
    lu.assertTrue(nextChoiceView.fillRow({}, 1, 2).currentRoom.isEntry)

    local view = nextChoiceView.fillRow({}, 2, 2)

    lu.assertEquals(view.currentRoom.rowIndex, 2)
    lu.assertFalse(view.nextChoices.picked.active)
    lu.assertNil(view.nextChoices.picked.targetRowIndex)
end
