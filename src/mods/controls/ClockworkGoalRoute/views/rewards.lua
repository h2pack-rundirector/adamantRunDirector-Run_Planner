-- luacheck: no unused args

local deps = ...
local data = deps.data
local rewardSystem = deps.rewards

local rewards = {}

local REWARD_COLUMN_X = 130
local REWARD_DRAW_OPTS = {
    hideGenericRewardLabel = true,
}

local function rewardDrawOpts(control)
    if control.rewardDrawOpts ~= nil then
        return control:rewardDrawOpts(REWARD_DRAW_OPTS)
    end
    return REWARD_DRAW_OPTS
end

local function rewardFields(control, rowIndex)
    control._rewardFieldsByRow = control._rewardFieldsByRow or {}
    local fields = control._rewardFieldsByRow[rowIndex]
    if fields == nil then
        fields = {
            rewardContext = {
                rowIndex = rowIndex,
                address = "row",
                sourceKind = "row",
            },
            get = function(_, alias)
                return control:rewardField(rowIndex, alias)
            end,
            read = function(_, alias)
                return control:fields().Rewards:read(rowIndex, alias)
            end,
        }
        control._rewardFieldsByRow[rowIndex] = fields
    end
    return fields
end

local function rewardRowLabel(control, rowIndex, slot)
    local role = control:role(rowIndex)
    if role ~= nil then
        return tostring(role.label or role.key or slot.label)
    end
    return tostring(slot.label)
end

local function drawRewardRowHeader(imgui, control, rowIndex, slot)
    imgui.AlignTextToFramePadding()
    imgui.Text(rewardRowLabel(control, rowIndex, slot))
end

local function drawRewardRow(draw, control, rowIndex)
    local slot = control:slot(rowIndex)
    if slot == nil then
        return
    end

    local imgui = draw.imgui
    local surface = control:rewardSurface(rowIndex)

    drawRewardRowHeader(imgui, control, rowIndex, slot)

    if rewardSystem ~= nil and rewardSystem.hasControls(surface) then
        imgui.SameLine()
        imgui.SetCursorPosX(REWARD_COLUMN_X)
        if rewardSystem.draw(draw, surface, rewardFields(control, rowIndex), rewardDrawOpts(control)) then
            control:invalidateReadPass()
        end
    end
end

local function drawRouteRowSeparator(imgui)
    imgui.Spacing()
    imgui.Separator()
    imgui.Spacing()
end

local function shouldRenderRow(control, instance, rows, rowIndex)
    return not data.isInactiveRouteRow(instance, rows, rowIndex)
end

function rewards.draw(draw, control, instance)
    local rowCount = control:rowCount()
    local drewRow = false
    local rows = control:routeRows()
    control:beginReadPass()
    for rowIndex = 1, rowCount do
        if shouldRenderRow(control, instance, rows, rowIndex) then
            if drewRow then
                drawRouteRowSeparator(draw.imgui)
            end
            drawRewardRow(draw, control, rowIndex)
            drewRow = true
        end
    end
    control:endReadPass()
end

return rewards
