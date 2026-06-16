local data = {}

data.PLAN_MODE_VALUES = { "Prefer", "Strict" }

function data.buildStorage()
    return {
        { type = "bool", alias = "RoomRoutingEnabled", default = false },
        { type = "bool", alias = "RewardRoutingEnabled", default = false },
        { type = "string", alias = "PlanMode", default = "Prefer", maxLen = 16 },
    }
end

return data
