-- luacheck: no unused args

local deps = ...
local data = deps.data
local resetSideRewardDetails = deps.resetSideRewardDetails
local rewardSystem = deps.rewards
local decorations = deps.decorations
local valueStateHelpers = deps.valueStateHelpers
local sideRoomProbability = deps.sideRoomProbability

local sideRooms = {}

local SIDE_MODE_OPTS = {
    label = "",
    controlWidth = 110,
}
local SIDE_ENCOUNTER_OPTS = {
    label = "",
    controlWidth = 95,
}
local SIDE_MODE_COLUMN_X = 130
local SIDE_ENTERED_SEPARATOR_X = 250
local SIDE_ENTERED_COLUMN_X = 275
local SIDE_AFTER_ENTERED_SEPARATOR_X = 390
local SIDE_ENCOUNTER_COLUMN_X = 415
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

local function getSideEncounterOpts(control, instance, rowIndex, sideIndex, sideDoor)
    control._sideEncounterOptsByRoomKey = control._sideEncounterOptsByRoomKey or {}
    local opts = control._sideEncounterOptsByRoomKey[sideDoor.roomKey]
    if opts == nil then
        opts = copyBaseOpts(SIDE_ENCOUNTER_OPTS)
        opts.values = data.sideRoomEncounterClassValues(instance, sideDoor)
        opts.displayValues = data.sideRoomEncounterClassLabels(instance)
        control._sideEncounterOptsByRoomKey[sideDoor.roomKey] = opts
    end
    return decorations.decorateDropdown(
        opts,
        opts,
        valueStateHelpers.history(instance, rowIndex, data.sideRoomEncounterClassAlias(sideIndex))
    )
end

local function sideRoomLabel(control, rowIndex, sideIndex)
    control._sideRoomLabels = control._sideRoomLabels or {}
    local rowLabels = control._sideRoomLabels[rowIndex]
    if rowLabels == nil then
        rowLabels = {}
        control._sideRoomLabels[rowIndex] = rowLabels
    end
    local label = rowLabels[sideIndex]
    if label == nil then
        label = "Side " .. tostring(sideIndex)
        rowLabels[sideIndex] = label
    end
    return label
end

local function sideEnteredLabel(control, rowIndex, sideIndex)
    control._sideEnteredLabels = control._sideEnteredLabels or {}
    local key = tostring(rowIndex) .. ":" .. tostring(sideIndex)
    local label = control._sideEnteredLabels[key]
    if label == nil then
        label = "Entered##side-room:" .. key
        control._sideEnteredLabels[key] = label
    end
    return label
end

local function sideRewardFields(control, rowIndex, sideIndex)
    control._sideRewardFieldsByRow = control._sideRewardFieldsByRow or {}
    local key = tostring(rowIndex) .. ":" .. tostring(sideIndex)
    local fields = control._sideRewardFieldsByRow[key]
    if fields == nil then
        fields = {
            rewardContext = {
                rowIndex = rowIndex,
                address = "side:" .. tostring(sideIndex),
                eventSourceKind = "side",
                sameExitRewardIndex = sideIndex,
                storageSideIndex = sideIndex,
            },
            get = function(_, alias)
                return control:sideRewardField(rowIndex, data.sideRoomRewardAlias(sideIndex, alias))
            end,
            read = function(_, alias)
                return control:fields().Rewards:read(rowIndex, data.sideRoomRewardAlias(sideIndex, alias))
            end,
        }
        control._sideRewardFieldsByRow[key] = fields
    end
    return fields
end

local function drawSideRoomMode(draw, control, instance, rowIndex, sideIndex)
    local sideDoor = data.sideDoorForRow(instance, control:routeRows(), rowIndex, sideIndex)
    if sideDoor == nil then
        return nil
    end

    local imgui = draw.imgui
    local modeAlias = data.sideRoomModeAlias(sideIndex)
    imgui.AlignTextToFramePadding()
    imgui.Text(sideRoomLabel(control, rowIndex, sideIndex))
    imgui.SameLine()
    imgui.SetCursorPosX(SIDE_MODE_COLUMN_X)
    if draw.widgets.dropdown(control:sideRoomField(rowIndex, modeAlias), getSideModeOpts(control, instance)) then
        if (control:fields().Rooms:read(rowIndex, modeAlias) or "") ~= data.sideRoomEnabledMode() then
            control:sideRoomField(rowIndex, data.sideRoomEnteredAlias(sideIndex)):write(false)
            resetSideRewardDetails(control:fields(), rowIndex, sideIndex)
        end
        control:invalidateReadPass()
    end
    return sideDoor
end

local function drawSideRoomEntered(draw, control, rowIndex, sideIndex)
    local imgui = draw.imgui
    local enteredAlias = data.sideRoomEnteredAlias(sideIndex)
    local entered = control:fields().Rooms:read(rowIndex, enteredAlias) == true
    local label = sideEnteredLabel(control, rowIndex, sideIndex)
    imgui.SameLine()
    imgui.SetCursorPosX(SIDE_ENTERED_SEPARATOR_X)
    imgui.AlignTextToFramePadding()
    imgui.Text("||")
    imgui.SameLine()
    imgui.SetCursorPosX(SIDE_ENTERED_COLUMN_X)
    local nextEntered, changed = imgui.Checkbox(label, entered)
    imgui.SameLine()
    imgui.SetCursorPosX(SIDE_AFTER_ENTERED_SEPARATOR_X)
    imgui.AlignTextToFramePadding()
    imgui.Text("||")
    if changed then
        control:sideRoomField(rowIndex, enteredAlias):write(nextEntered == true)
        if nextEntered ~= true then
            resetSideRewardDetails(control:fields(), rowIndex, sideIndex)
        end
        control:invalidateReadPass()
    end
    return nextEntered == true
end

local function drawFixedSideRoomEncounterClass(draw, instance, sideDoor)
    local values = data.sideRoomEncounterClassValues(instance, sideDoor)
    local encounterClassKey = values[1]
    if encounterClassKey == nil then
        return
    end
    draw.imgui.SameLine()
    draw.imgui.SetCursorPosX(SIDE_ENCOUNTER_COLUMN_X)
    draw.imgui.AlignTextToFramePadding()
    draw.imgui.Text(tostring(data.sideRoomEncounterClassLabels(instance)[encounterClassKey] or encounterClassKey))
end

local function drawSideRoomEncounterClass(draw, control, instance, rowIndex, sideIndex, sideDoor)
    local values = data.sideRoomEncounterClassValues(instance, sideDoor)
    if values[1] == nil then
        return
    end
    if values[2] == nil then
        drawFixedSideRoomEncounterClass(draw, instance, sideDoor)
        return
    end

    draw.imgui.SameLine()
    draw.imgui.SetCursorPosX(SIDE_ENCOUNTER_COLUMN_X)
    if draw.widgets.dropdown(
        control:sideRoomField(rowIndex, data.sideRoomEncounterClassAlias(sideIndex)),
        getSideEncounterOpts(control, instance, rowIndex, sideIndex, sideDoor)
    ) then
        control:invalidateReadPass()
    end
end

local function sideRoomState(control, instance, rowIndex, sideIndex)
    local sideDoor = data.sideDoorForRow(instance, control:routeRows(), rowIndex, sideIndex)
    if sideDoor == nil then
        return nil, false, false
    end
    local enabled = control:fields().Rooms:read(rowIndex, data.sideRoomModeAlias(sideIndex))
        == data.sideRoomEnabledMode()
    local entered = enabled
        and control:fields().Rooms:read(rowIndex, data.sideRoomEnteredAlias(sideIndex)) == true
    return sideDoor, enabled, entered
end

local function drawSideRoomStructureRow(draw, control, instance, rowIndex, sideIndex)
    local sideDoor, enabled = sideRoomState(control, instance, rowIndex, sideIndex)
    if sideDoor == nil then
        return
    end

    if sideIndex > 1 then
        draw.imgui.Spacing()
    end
    sideDoor = drawSideRoomMode(draw, control, instance, rowIndex, sideIndex)
    if enabled then
        local entered = drawSideRoomEntered(draw, control, rowIndex, sideIndex)
        if entered then
            drawSideRoomEncounterClass(draw, control, instance, rowIndex, sideIndex, sideDoor)
        end
    end
end

local function drawSideRewardRow(draw, control, instance, rowIndex, sideIndex)
    local sideDoor, _, entered = sideRoomState(control, instance, rowIndex, sideIndex)
    if not entered or not control:rewardsConfigured() or rewardSystem == nil then
        return false
    end

    local surface = sideDoor ~= nil and rewardSystem.surfaceFor(sideDoor.reward) or nil
    if not rewardSystem.hasDisplay(surface) then
        return false
    end

    local imgui = draw.imgui
    imgui.AlignTextToFramePadding()
    imgui.Text(sideRoomLabel(control, rowIndex, sideIndex))
    imgui.SameLine()
    imgui.SetCursorPosX(SIDE_REWARD_COLUMN_X)
    drawRewardSurface(
        draw,
        control,
        surface,
        sideRewardFields(control, rowIndex, sideIndex),
        rewardDrawOpts(control)
    )
    return true
end

function sideRooms.hasRows(control, instance, rowIndex)
    return data.sideDoorCountForRow(instance, control:routeRows(), rowIndex) > 0
end

function sideRooms.drawInfoLine(draw, control)
    sideRoomProbability.drawInfoLine(draw.imgui, decorations, control:sideRoomProbabilitySummary())
end

function sideRooms.drawStructureRowsForRouteRow(draw, control, instance, rowIndex)
    if not sideRooms.hasRows(control, instance, rowIndex) then
        return
    end
    draw.imgui.Indent()
    for sideIndex = 1, data.sideDoorCountForRow(instance, control:routeRows(), rowIndex) do
        drawSideRoomStructureRow(draw, control, instance, rowIndex, sideIndex)
    end
    draw.imgui.Unindent()
end

function sideRooms.drawRewardRowsForRouteRow(draw, control, instance, rowIndex)
    local drewRow = false
    for sideIndex = 1, data.sideDoorCountForRow(instance, control:routeRows(), rowIndex) do
        if drawSideRewardRow(draw, control, instance, rowIndex, sideIndex) then
            drewRow = true
        end
    end
    return drewRow
end

return sideRooms
