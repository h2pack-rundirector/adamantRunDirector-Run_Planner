-- luacheck: no unused args

local deps = ...
local rewardSystem = deps.rewards

local rewards = {}

local REWARD_COLUMN_X = 130
local REWARD_DRAW_OPTS = {
    hideGenericRewardLabel = true,
}

local function rewardDrawOpts(control, rowIndex)
    local sourceCount = control:rewardSourceCount(rowIndex)
    if control.rewardDrawOpts ~= nil then
        local opts = control:rewardDrawOpts(REWARD_DRAW_OPTS)
        opts.sourceCount = sourceCount
        return opts
    end
    if sourceCount ~= nil then
        control._rewardDrawOptsBySourceCount = control._rewardDrawOptsBySourceCount or {}
        local opts = control._rewardDrawOptsBySourceCount[sourceCount]
        if opts == nil then
            opts = {
                hideGenericRewardLabel = true,
                sourceCount = sourceCount,
            }
            control._rewardDrawOptsBySourceCount[sourceCount] = opts
        end
        return opts
    end
    return REWARD_DRAW_OPTS
end

local function rewardFields(control, rowIndex)
    control._rewardFieldsByRow = control._rewardFieldsByRow or {}
    local fields = control._rewardFieldsByRow[rowIndex]
    if fields == nil then
        fields = {
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

local function drawRewardRow(draw, control, instance, rowIndex)
    local slot = control:slot(rowIndex)
    if slot == nil then
        return
    end

    local imgui = draw.imgui
    local surface = control:rewardSurface(rowIndex)

    drawRewardRowHeader(imgui, control, rowIndex, slot)

    if rewardSystem ~= nil
        and rewardSystem ~= nil
        and rewardSystem.hasControls(surface)
        and (control:rewardSourceCount(rowIndex) or 1) > 0
    then
        imgui.SameLine()
        imgui.SetCursorPosX(REWARD_COLUMN_X)
        if rewardSystem.draw(draw, surface, rewardFields(control, rowIndex), rewardDrawOpts(control, rowIndex)) then
            control:invalidateReadPass()
        end
    end
end

local function drawRouteRowSeparator(imgui)
    imgui.Spacing()
    imgui.Separator()
    imgui.Spacing()
end

function rewards.draw(draw, control, instance)
    local rowCount = control:rowCount()
    local drewRow = false
    control:beginReadPass()
    for rowIndex = 1, rowCount do
        if drewRow then
            drawRouteRowSeparator(draw.imgui)
        end
        drawRewardRow(draw, control, instance, rowIndex)
        drewRow = true
    end
    control:endReadPass()
end

return rewards
