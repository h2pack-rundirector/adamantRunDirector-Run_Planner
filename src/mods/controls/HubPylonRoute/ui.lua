-- luacheck: no unused args

local deps = ...
local data = deps.data
local runtime = deps.runtime

local ui = {}

local function resetRewardDetails(fields, rowIndex)
    for index = 1, data.REWARD_SLOT_COUNT do
        fields.Rewards:reset(rowIndex, "Reward" .. tostring(index) .. "Key")
        fields.Rewards:reset(rowIndex, "Reward" .. tostring(index) .. "LootKey")
    end
end

local function resetSideRewardDetails(fields, sideRowIndex)
    if sideRowIndex == nil then
        return
    end
    for index = 1, data.REWARD_SLOT_COUNT do
        fields.SideRewards:reset(sideRowIndex, "Reward" .. tostring(index) .. "Key")
        fields.SideRewards:reset(sideRowIndex, "Reward" .. tostring(index) .. "LootKey")
    end
end

local function resetSideRoomDetails(fields, sideRowIndex)
    if sideRowIndex == nil then
        return
    end
    fields.SideRooms:reset(sideRowIndex, data.sideRoomModeAlias())
    resetSideRewardDetails(fields, sideRowIndex)
end

local function resetAllSideRoomDetails(fields, instance, rowIndex)
    for sideIndex = 1, data.maxSideDoorCount(instance) do
        resetSideRoomDetails(fields, data.sideRoomRowIndex(instance, rowIndex, sideIndex))
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

local rooms = import("mods/controls/HubPylonRoute/views/rooms.lua", nil, {
    data = data,
    resetAllSideRoomDetails = resetAllSideRoomDetails,
    resetRewardDetails = resetRewardDetails,
    resetRowDetails = resetRowDetails,
})
local rewards = import("mods/controls/HubPylonRoute/views/rewards.lua", nil, {
    rewardRuntime = deps.rewardRuntime,
    rewardUi = deps.rewardUi,
})
local sideRooms = import("mods/controls/HubPylonRoute/views/side_rooms.lua", nil, {
    data = data,
    resetSideRewardDetails = resetSideRewardDetails,
    rewardRuntime = deps.rewardRuntime,
    rewardUi = deps.rewardUi,
})
local planner = import("mods/controls/HubPylonRoute/views/planner.lua", nil, {
    rooms = rooms,
    rewards = rewards,
    sideRooms = sideRooms,
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

    function control:sideRoomField(sideRowIndex, rowAlias)
        return fields.SideRooms:get(sideRowIndex, rowAlias)
    end

    function control:sideRewardField(sideRowIndex, rowAlias)
        return fields.SideRewards:get(sideRowIndex, rowAlias)
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
    sideRooms = sideRooms.draw,
    planner = planner.draw,
}
ui.views.default = ui.views.planner

return ui
