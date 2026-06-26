-- luacheck: no unused args

local deps = ...
local data = deps.data
local rewardSystem = deps.rewards
local runtime = deps.runtime
local optionChanges = deps.roomOptionChanges

local ui = {}

local function resetRewardDetails(fields, rowIndex)
    rewardSystem.resetRows(fields.Rewards, rowIndex)
end

local function resetRoomDetails(fields, instance, rowIndex)
    fields.Rooms:reset(rowIndex, "OptionKey")
    fields.Rooms:reset(rowIndex, "VariantKey")
    fields.Rooms:reset(rowIndex, data.siblingStructureAlias(instance))
end

local function resetRowDetails(fields, instance, rowIndex)
    resetRoomDetails(fields, instance, rowIndex)
    resetRewardDetails(fields, rowIndex)
end

local rooms = import("mods/controls/FieldsCageRoute/ui/rooms.lua", nil, {
    data = data,
    resetRowDetails = resetRowDetails,
    decorations = deps.decorations,
})
local rewards = import("mods/controls/FieldsCageRoute/ui/rewards.lua", nil, {
    data = data,
    rewards = deps.rewards,
    decorations = deps.decorations,
})
local planner = import("mods/controls/FieldsCageRoute/ui/planner.lua", nil, {
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

    function control:onRoomOptionChanged(rowIndex, previousOptionKey)
        optionChanges.resetRewardsIfContextChanged(self, resetRewardDetails, rowIndex, previousOptionKey)
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
