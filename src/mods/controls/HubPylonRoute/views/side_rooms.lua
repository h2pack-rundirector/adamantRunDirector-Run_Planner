-- luacheck: no unused args

local deps = ...
local data = deps.data
local resetSideRewardDetails = deps.resetSideRewardDetails
local rewardSystem = deps.rewards
local decorations = deps.decorations
local sideRoomProbability = deps.sideRoomProbability

local sideRooms = {}

local SIDE_MODE_OPTS = {
    label = "",
    controlWidth = 110,
}
local SIDE_MODE_COLUMN_X = 130
local SIDE_REWARD_COLUMN_X = 260
local REWARD_DRAW_OPTS = {
    hideGenericRewardLabel = true,
}

local function copyBaseOpts(base)
    local copy = {}
    for key, value in pairs(base or {}) do
        copy[key] = value
    end
    return copy
end

local function rewardDrawOpts(control)
    if control.rewardDrawOpts ~= nil then
        return control:rewardDrawOpts(REWARD_DRAW_OPTS)
    end
    return REWARD_DRAW_OPTS
end

local function drawRewardSurface(draw, control, surface, fields, opts)
    if rewardSystem.draw(draw, surface, fields, opts) and (opts == nil or opts.onControlChanged == nil) then
        control:invalidateReadPass()
    end
end

local function getSideModeOpts(control, instance)
    if control._sideModeOpts == nil then
        control._sideModeOpts = copyBaseOpts(SIDE_MODE_OPTS)
        control._sideModeOpts.values = data.sideRoomModeValues(instance)
        control._sideModeOpts.displayValues = data.sideRoomModeLabels(instance)
    end
    return control._sideModeOpts
end

local function sideRewardFields(control, sideRowIndex, rowIndex, sideIndex)
    control._sideRewardFieldsByRow = control._sideRewardFieldsByRow or {}
    local fields = control._sideRewardFieldsByRow[sideRowIndex]
    if fields == nil then
        fields = {
            rewardContext = {
                rowIndex = rowIndex,
                address = "side:" .. tostring(sideIndex),
                sourceKind = "side",
                sourceIndex = sideIndex,
                storageRowIndex = sideRowIndex,
            },
            get = function(_, alias)
                return control:sideRewardField(sideRowIndex, data.sideRoomRewardAlias(nil, alias))
            end,
            read = function(_, alias)
                return control:fields().SideRewards:read(sideRowIndex, data.sideRoomRewardAlias(nil, alias))
            end,
        }
        control._sideRewardFieldsByRow[sideRowIndex] = fields
    end
    return fields
end

local function drawSideRoomMode(draw, control, instance, rowIndex, sideIndex)
    local sideDoor = data.sideDoorForRow(instance, control:routeRows(), rowIndex, sideIndex)
    local sideRowIndex = data.sideRoomRowIndex(instance, rowIndex, sideIndex)
    if sideDoor == nil or sideRowIndex == nil then
        return nil
    end

    local imgui = draw.imgui
    local modeAlias = data.sideRoomModeAlias()
    imgui.AlignTextToFramePadding()
    imgui.Text(tostring(control:slot(rowIndex).label or "Pylon") .. " / Side " .. tostring(sideIndex))
    imgui.SameLine()
    imgui.SetCursorPosX(SIDE_MODE_COLUMN_X)
    if draw.widgets.dropdown(control:sideRoomField(sideRowIndex, modeAlias), getSideModeOpts(control, instance)) then
        if (control:fields().SideRooms:read(sideRowIndex, modeAlias) or "") ~= data.sideRoomEnabledMode() then
            resetSideRewardDetails(control:fields(), sideRowIndex)
        end
        control:invalidateReadPass()
    end
    return sideRowIndex, sideDoor
end

local function drawSideRoomRow(draw, control, instance, rowIndex)
    for sideIndex = 1, data.sideDoorCountForRow(instance, control:routeRows(), rowIndex) do
        if sideIndex > 1 then
            draw.imgui.Spacing()
        end
        local sideRowIndex, sideDoor = drawSideRoomMode(draw, control, instance, rowIndex, sideIndex)
        local mode = sideRowIndex and control:fields().SideRooms:read(sideRowIndex, data.sideRoomModeAlias()) or ""
        local surface = sideDoor ~= nil and rewardSystem and rewardSystem.surfaceFor(sideDoor.reward) or nil
        if mode == data.sideRoomEnabledMode()
            and rewardSystem ~= nil
            and rewardSystem.hasDisplay(surface)
        then
            draw.imgui.SameLine()
            draw.imgui.SetCursorPosX(SIDE_REWARD_COLUMN_X)
            drawRewardSurface(
                draw,
                control,
                surface,
                sideRewardFields(control, sideRowIndex, rowIndex, sideIndex),
                rewardDrawOpts(control)
            )
        end
    end
end

local function drawRouteRowSeparator(imgui)
    imgui.Spacing()
    imgui.Separator()
    imgui.Spacing()
end

local function hasSideRoomRows(control, instance, rowIndex)
    return data.sideDoorCountForRow(instance, control:routeRows(), rowIndex) > 0
end

function sideRooms.draw(draw, control, instance)
    local rowCount = control:rowCount()
    local drewRow = false
    local allRowsInactive, inactiveBoundary = decorations.routeInactiveBoundary(instance)
    sideRoomProbability.drawInfoLine(draw.imgui, decorations, control:sideRoomProbabilitySummary())
    control:beginReadPass()
    for rowIndex = 1, rowCount do
        if hasSideRoomRows(control, instance, rowIndex) then
            if drewRow then
                drawRouteRowSeparator(draw.imgui)
            end
            local inactive = decorations.pushInactive(
                draw.imgui,
                decorations.routeRowInactive(allRowsInactive, inactiveBoundary, control:slot(rowIndex), "sideRooms")
            )
            drawSideRoomRow(draw, control, instance, rowIndex)
            decorations.popInactive(draw.imgui, inactive)
            drewRow = true
        end
    end
    control:endReadPass()
end

return sideRooms
