-- luacheck: no unused args

local deps = ...
local data = deps.data
local rewardSystem = deps.rewards
local runtime = deps.runtime
local sideRoomProbability = deps.sideRoomProbability

local ui = {}

local function resetRewardDetails(fields, rowIndex)
    rewardSystem.resetRows(fields.Rewards, rowIndex)
end

local function resetSideRewardDetails(fields, rowIndex, sideIndex)
    rewardSystem.resetRows(fields.Rewards, rowIndex, function(alias)
        return data.sideRoomRewardAlias(sideIndex, alias)
    end)
end

local function resetSideRoomDetails(fields, rowIndex, sideIndex)
    fields.Rooms:reset(rowIndex, data.sideRoomModeAlias(sideIndex))
    fields.Rooms:reset(rowIndex, data.sideRoomEnteredAlias(sideIndex))
    fields.Rooms:reset(rowIndex, data.sideRoomEncounterClassAlias(sideIndex))
    resetSideRewardDetails(fields, rowIndex, sideIndex)
end

local function resetAllSideRoomDetails(fields, instance, rowIndex)
    for sideIndex = 1, data.maxSideDoorCount(instance) do
        resetSideRoomDetails(fields, rowIndex, sideIndex)
    end
end

local function resetRoomDetails(fields, rowIndex)
    fields.Rooms:reset(rowIndex, "OptionKey")
    fields.Rooms:reset(rowIndex, "VariantKey")
end

local function resetRowDetails(fields, instance, rowIndex)
    resetRoomDetails(fields, rowIndex)
    resetRewardDetails(fields, rowIndex)
    resetAllSideRoomDetails(fields, instance, rowIndex)
end

local sideRooms = import("mods/controls/HubPylonRoute/ui/side_rooms.lua", nil, {
    data = data,
    resetSideRewardDetails = resetSideRewardDetails,
    rewards = deps.rewards,
    sideRoomProbability = sideRoomProbability,
    decorations = deps.decorations,
    valueStateHelpers = deps.valueStateHelpers,
})
local rooms = import("mods/controls/HubPylonRoute/ui/rooms.lua", nil, {
    data = data,
    resetRowDetails = resetRowDetails,
    sideRooms = sideRooms,
    valueStateHelpers = deps.valueStateHelpers,
    decorations = deps.decorations,
})
local rewards = import("mods/controls/HubPylonRoute/ui/rewards.lua", nil, {
    rewards = deps.rewards,
    sideRooms = sideRooms,
    decorations = deps.decorations,
})
local planner = import("mods/controls/HubPylonRoute/ui/planner.lua", nil, {
    rooms = rooms,
    rewards = rewards,
    decorations = deps.decorations,
})

function ui.create(fields, instance)
    local control = runtime.create(fields, instance)
    function control:fields()
        return fields
    end

    function control:roomField(rowIndex, rowAlias)
        return fields.Rooms:get(rowIndex, rowAlias)
    end

    function control:rewardField(rowIndex, rowAlias)
        return fields.Rewards:get(rowIndex, rowAlias)
    end

    function control:sideRoomField(rowIndex, rowAlias)
        return fields.Rooms:get(rowIndex, rowAlias)
    end

    function control:sideRewardField(rowIndex, rowAlias)
        return fields.Rewards:get(rowIndex, rowAlias)
    end

    function control:onRoomOptionChanged(rowIndex, previousOptionKey)
        deps.form.resetRewardsIfRoomContextChanged(self, resetRewardDetails, rowIndex, previousOptionKey)
        if (previousOptionKey or "") ~= (fields.Rooms:read(rowIndex, "OptionKey") or "") then
            resetAllSideRoomDetails(fields, instance, rowIndex)
        end
    end

    function control:resetRow(rowIndex)
        fields.Rooms:reset(rowIndex, "RoleKey")
        resetRowDetails(fields, instance, rowIndex)
    end

    function control:resetAllRows()
        local changed = false
        for rowIndex = 1, self:rowCount() do
            self:resetRow(rowIndex)
            changed = true
        end
        return changed
    end

    return control
end

ui.views = {
    rooms = rooms.draw,
    rewards = rewards.draw,
    planner = planner.draw,
}
ui.views.default = ui.views.planner

return ui
