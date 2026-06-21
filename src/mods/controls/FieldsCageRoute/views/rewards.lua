-- luacheck: no unused args

local deps = ...
local data = deps.data
local rewardRuntime = deps.rewardRuntime
local rewardUi = deps.rewardUi

local rewards = {}

local REWARD_COLUMN_X = 130
local CAGE_REWARD_COLUMN_X = 260
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

local function cageRewardFields(control, cageRewardRowIndex)
    control._cageRewardFieldsByRow = control._cageRewardFieldsByRow or {}
    local fields = control._cageRewardFieldsByRow[cageRewardRowIndex]
    if fields == nil then
        fields = {
            get = function(_, alias)
                return control:cageRewardField(cageRewardRowIndex, alias)
            end,
            read = function(_, alias)
                return control:fields().CageRewards:read(cageRewardRowIndex, alias)
            end,
        }
        control._cageRewardFieldsByRow[cageRewardRowIndex] = fields
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

local function drawCageRewardRows(draw, control, instance, rowIndex)
    for cageIndex = 1, data.cageRewardCountForRow(instance, control:routeRows(), rowIndex) do
        local leg = data.cageRewardLegForRow(instance, control:routeRows(), rowIndex, cageIndex)
        local cageRewardRowIndex = data.cageRewardRowIndex(instance, rowIndex, cageIndex)
        local legSurface = leg ~= nil and rewardRuntime and rewardRuntime.surfaceFor(leg.reward) or nil
        if cageRewardRowIndex ~= nil
            and rewardUi ~= nil
            and rewardRuntime ~= nil
            and rewardRuntime.hasControls(legSurface)
        then
            if cageIndex == 1 then
                draw.imgui.SameLine()
            else
                draw.imgui.Spacing()
            end
            draw.imgui.SetCursorPosX(REWARD_COLUMN_X)
            draw.imgui.AlignTextToFramePadding()
            draw.imgui.Text(tostring(leg.label or leg.key or "Cage"))
            draw.imgui.SameLine()
            draw.imgui.SetCursorPosX(CAGE_REWARD_COLUMN_X)
            if rewardUi.draw(draw, legSurface, cageRewardFields(control, cageRewardRowIndex), rewardDrawOpts(control)) then
                control:invalidateReadPass()
            end
        end
    end
end

local function drawRewardRow(draw, control, instance, rowIndex)
    local slot = control:slot(rowIndex)
    if slot == nil then
        return
    end

    local imgui = draw.imgui
    local surface = control:rewardSurface(rowIndex)

    drawRewardRowHeader(imgui, control, rowIndex, slot)
    drawCageRewardRows(draw, control, instance, rowIndex)

    if rewardUi ~= nil
        and rewardRuntime ~= nil
        and rewardRuntime.hasControls(surface)
    then
        imgui.SameLine()
        imgui.SetCursorPosX(REWARD_COLUMN_X)
        if rewardUi.draw(draw, surface, rewardFields(control, rowIndex), rewardDrawOpts(control)) then
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
