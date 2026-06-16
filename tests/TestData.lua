local lu = require("luaunit")

-- luacheck: globals TestRunPlannerData
TestRunPlannerData = {}

local function findStorage(storage, alias)
    for _, node in ipairs(storage) do
        if node.alias == alias then
            return node
        end
    end
end

function TestRunPlannerData.testStorageDeclaresInitialPlannerControls()
    local data = dofile("src/mods/data.lua")
    local storage = data.buildStorage()

    lu.assertEquals(findStorage(storage, "RoomRoutingEnabled").type, "bool")
    lu.assertFalse(findStorage(storage, "RoomRoutingEnabled").default)
    lu.assertEquals(findStorage(storage, "RewardRoutingEnabled").type, "bool")
    lu.assertFalse(findStorage(storage, "RewardRoutingEnabled").default)
    lu.assertEquals(findStorage(storage, "PlanMode").default, "Prefer")
end

function TestRunPlannerData.testPlanModesExposePreferenceAndStrictMode()
    local data = dofile("src/mods/data.lua")

    lu.assertEquals(data.PLAN_MODE_VALUES, { "Prefer", "Strict" })
end
