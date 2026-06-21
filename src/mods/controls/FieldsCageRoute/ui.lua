-- luacheck: no unused args

local deps = ...
local data = deps.data
local rewardSystem = deps.rewards
local runtime = deps.runtime

local ui = {}

local function resetRewardDetails(fields, rowIndex)
    rewardSystem.resetRows(fields.Rewards, rowIndex)
end

local function resetCageRewardDetails(fields, instance, rowIndex)
    for cageIndex = 1, data.maxCageRewardCount(instance) do
        local cageRewardRowIndex = data.cageRewardRowIndex(instance, rowIndex, cageIndex)
        if cageRewardRowIndex ~= nil then
            rewardSystem.resetRows(fields.CageRewards, cageRewardRowIndex)
        end
    end
end

local function resetRoomDetails(fields, rowIndex)
    fields.Rooms:reset(rowIndex, "OptionKey")
    fields.Rooms:reset(rowIndex, "VariantKey")
end

local function resetRowDetails(fields, instance, rowIndex)
    resetRoomDetails(fields, rowIndex)
    resetRewardDetails(fields, rowIndex)
    resetCageRewardDetails(fields, instance, rowIndex)
end

local rooms = import("mods/controls/FieldsCageRoute/views/rooms.lua", nil, {
    data = data,
    resetCageRewardDetails = resetCageRewardDetails,
    resetRewardDetails = resetRewardDetails,
    resetRowDetails = resetRowDetails,
})
local rewards = import("mods/controls/FieldsCageRoute/views/rewards.lua", nil, {
    data = data,
    rewards = deps.rewards,
})
local planner = import("mods/controls/FieldsCageRoute/views/planner.lua", nil, {
    rooms = rooms,
    rewards = rewards,
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

    function control:cageRewardField(cageRewardRowIndex, rowAlias)
        return fields.CageRewards:get(cageRewardRowIndex, rowAlias)
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
