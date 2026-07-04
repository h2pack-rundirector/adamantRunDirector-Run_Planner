-- luacheck: no unused args

local deps = ...
local data = deps.data
local rewardSystem = deps.rewards
local runtime = deps.runtime

local ui = {}

local function resetRoomDetails(fields, instance, rowIndex)
    fields.Rooms:reset(rowIndex, data.optionAlias())
    fields.Rooms:reset(rowIndex, "VariantKey")
    if instance.otherDoorPolicy ~= nil then
        for siblingIndex = 1, data.maxOtherDoorCount(instance) do
            fields.Rooms:reset(rowIndex, data.otherDoorAlias(instance, siblingIndex))
        end
    end
end

local function resetRewardDetails(fields, rowIndex)
    rewardSystem.resetRows(fields.Rewards, rowIndex)
end

local function resetRowDetails(fields, instance, rowIndex)
    resetRoomDetails(fields, instance, rowIndex)
    resetRewardDetails(fields, rowIndex)
end

local rooms = import("mods/controls/ClockworkGoalRoute/ui/rooms.lua", nil, {
    data = data,
    resetRowDetails = resetRowDetails,
    valueStateHelpers = deps.valueStateHelpers,
    decorations = deps.decorations,
    nextChoiceView = deps.nextChoiceView,
})
local rewards = import("mods/controls/ClockworkGoalRoute/ui/rewards.lua", nil, {
    data = data,
    rewards = deps.rewards,
    valueStateHelpers = deps.valueStateHelpers,
    decorations = deps.decorations,
})
local planner = import("mods/controls/ClockworkGoalRoute/ui/planner.lua", nil, {
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
        deps.form.resetRewardsIfRoomContextChanged(self, resetRewardDetails, rowIndex, previousOptionKey)
    end

    function control:resetRow(rowIndex)
        fields.Rooms:reset(rowIndex, data.routeKindAlias())
        fields.Rooms:reset(rowIndex, data.nonGoalKindAlias())
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
