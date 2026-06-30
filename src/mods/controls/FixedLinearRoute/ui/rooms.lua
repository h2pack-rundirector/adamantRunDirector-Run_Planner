-- luacheck: no unused args

local deps = ...
local data = deps.data
local resetRowDetails = deps.resetRowDetails
local decorations = deps.decorations
local valueStateHelpers = deps.valueStateHelpers
local form = deps.form
local nextChoiceView = deps.nextChoiceView

local rooms = {}

local ROLE_OPTS = {
    label = "",
    controlWidth = 130,
}
local OPTION_OPTS = {
    label = "",
    controlWidth = 190,
}
local SIBLING_STRUCTURE_OPTS = {
    label = "",
    controlWidth = 170,
}
local DOOR_LABEL_COLUMN_X = 80
local DOOR_CONTROL_COLUMN_X = 190
local OPTION_COLUMN_X = 340
local PICKED_DOOR_LABEL = "Picked Door"
local ENTRY_ROOM_LABEL = "Entry Room"
local CURRENT_ROOM_LABEL = "Current Room"
local NEXT_CHOICES_LABEL = "Next Choices"

local function copyBaseOpts(base)
    local copy = {}
    for key, value in pairs(base or {}) do
        copy[key] = value
    end
    return copy
end

local function getRoleOpts(control, instance, rowIndex)
    control._roleOptsByRow = control._roleOptsByRow or {}
    local opts = control._roleOptsByRow[rowIndex]
    if opts == nil then
        opts = copyBaseOpts(ROLE_OPTS)
        opts.values = {}
        opts.displayValues = instance.roleLabels
        control._roleOptsByRow[rowIndex] = opts
    end
    local rows = control:routeRows()
    opts.values = data.roleValuesForRow(instance, rows, rowIndex)
    return decorations.decorateDropdown(
        opts,
        opts,
        valueStateHelpers.merge(
            opts,
            data.roleValueStatesForRow(instance, rows, rowIndex),
            valueStateHelpers.history(instance, rowIndex, "RoleKey")
        )
    )
end

local function optionOptsByRole(control, rowIndex)
    control._optionOptsByRow = control._optionOptsByRow or {}
    local optsByRole = control._optionOptsByRow[rowIndex]
    if optsByRole == nil then
        optsByRole = {}
        control._optionOptsByRow[rowIndex] = optsByRole
    end
    return optsByRole
end

local function getOptionOpts(control, instance, rowIndex, roleKey)
    local optsByRole = optionOptsByRole(control, rowIndex)
    local opts = optsByRole[roleKey]
    if opts == nil then
        opts = copyBaseOpts(OPTION_OPTS)
        opts.values = {}
        opts.displayValues = data.optionLabelsForRow(instance, rowIndex, roleKey)
        optsByRole[roleKey] = opts
    end
    local rows = control:routeRows()
    opts.values = data.optionValuesForRow(instance, rows, rowIndex, roleKey)
    return decorations.decorateDropdown(
        opts,
        opts,
        valueStateHelpers.merge(
            opts,
            data.optionValueStatesForRow(instance, rows, rowIndex, roleKey),
            valueStateHelpers.history(instance, rowIndex, "OptionKey")
        )
    )
end

local function siblingStructureOpts(control, instance, rowIndex, siblingIndex)
    control._siblingStructureOptsByRow = control._siblingStructureOptsByRow or {}
    local optsBySibling = control._siblingStructureOptsByRow[rowIndex]
    if optsBySibling == nil then
        optsBySibling = {}
        control._siblingStructureOptsByRow[rowIndex] = optsBySibling
    end

    siblingIndex = siblingIndex or 1
    local opts = optsBySibling[siblingIndex]
    if opts == nil then
        opts = copyBaseOpts(SIBLING_STRUCTURE_OPTS)
        opts.values = data.siblingStructureValues(instance)
        opts.displayValues = data.siblingStructureLabels(instance)
        optsBySibling[siblingIndex] = opts
    end
    return decorations.decorateDropdown(
        opts,
        opts,
        valueStateHelpers.merge(
            opts,
            data.siblingStructureValueStatesForRow(instance, control:routeRows(), rowIndex, siblingIndex),
            valueStateHelpers.history(
                instance,
                rowIndex,
                data.siblingStructureAlias(instance, siblingIndex)
            )
        )
    )
end

local function optionLabelAddsInformation(role, option)
    return form.labelAddsInformation(role, option)
end

local function drawStaticOptionLabel(draw, role, option, columnX)
    if not optionLabelAddsInformation(role, option) then
        return
    end

    draw.imgui.SameLine()
    draw.imgui.SetCursorPosX(columnX or OPTION_COLUMN_X)
    draw.imgui.AlignTextToFramePadding()
    draw.imgui.Text(tostring(option.label or option.key or ""))
end

local function roomDisplayLabel(control, instance, rowIndex)
    local slot = control:slot(rowIndex)
    local roleKey, role = data.resolveRole(instance, control:routeRows(), rowIndex)
    local _, option = data.resolveOption(instance, control:routeRows(), rowIndex, roleKey)
    local roleLabel = role and tostring(role.label or role.key or "") or ""
    local optionLabel = option and tostring(option.label or option.key or "") or ""
    if roleLabel ~= "" and optionLabel ~= "" and optionLabel ~= roleLabel then
        return roleLabel .. " - " .. optionLabel
    elseif optionLabel ~= "" then
        return optionLabel
    elseif roleLabel ~= "" then
        return roleLabel
    end
    return tostring(slot and slot.label or "")
end

local function drawOptionDropdown(draw, control, instance, rowIndex, roleKey, columnX)
    local _, role = data.resolveRole(instance, control:routeRows(), rowIndex)
    local options = data.optionListForRole(role)
    if role == nil or #options == 0 then
        return
    end

    local optionOpts = getOptionOpts(control, instance, rowIndex, roleKey)
    if optionOpts.values[1] == nil then
        return
    end
    local storedOptionKey = control:fields().Rooms:read(rowIndex, "OptionKey") or ""
    local staticOptionKey = form.shouldRenderStaticValue(optionOpts.values, storedOptionKey)
    if staticOptionKey ~= nil then
        drawStaticOptionLabel(draw, role, role.optionsByKey and role.optionsByKey[staticOptionKey] or nil, columnX)
        return false
    end

    draw.imgui.SameLine()
    draw.imgui.SetCursorPosX(columnX or OPTION_COLUMN_X)
    local changed = draw.widgets.dropdown(
        control:roomField(rowIndex, "OptionKey"),
        optionOpts
    )
    return changed, storedOptionKey
end

local function siblingStructureLabel(instance, activeCount, siblingIndex)
    local label = instance.siblingStructurePolicy and instance.siblingStructurePolicy.label or "Other Door"
    if (activeCount or 0) > 1 then
        return label .. " " .. tostring(siblingIndex)
    end
    return label
end

local function drawSiblingStructureDropdown(draw, control, instance, rowIndex, siblingIndex, activeCount)
    if not data.shouldDrawSiblingStructure(instance, control:routeRows(), rowIndex, siblingIndex) then
        return false
    end

    local opts = siblingStructureOpts(control, instance, rowIndex, siblingIndex)
    if opts.values[1] == nil then
        return false
    end

    draw.imgui.SetCursorPosX(DOOR_LABEL_COLUMN_X)
    draw.imgui.AlignTextToFramePadding()
    draw.imgui.Text(siblingStructureLabel(instance, activeCount, siblingIndex))
    draw.imgui.SameLine()
    draw.imgui.SetCursorPosX(DOOR_CONTROL_COLUMN_X)
    return draw.widgets.dropdown(control:roomField(rowIndex, data.siblingStructureAlias(instance, siblingIndex)), opts)
end

local function drawSiblingStructureDropdowns(draw, control, instance, rowIndex)
    local changed = false
    local activeCount = data.activeSiblingStructureCount(instance, control:routeRows(), rowIndex)
    for siblingIndex = 1, data.maxSiblingStructureCount(instance) do
        if drawSiblingStructureDropdown(draw, control, instance, rowIndex, siblingIndex, activeCount) then
            changed = true
        end
    end
    return changed
end

local function drawRouteRowHeader(imgui, slot)
    imgui.AlignTextToFramePadding()
    imgui.Text(slot.label)
end

local function drawDoorLabel(imgui, label, inline)
    if inline then
        imgui.SameLine()
    end
    imgui.SetCursorPosX(DOOR_LABEL_COLUMN_X)
    imgui.AlignTextToFramePadding()
    imgui.Text(label)
end

local function drawStaticDoorValue(imgui, value)
    imgui.SameLine()
    imgui.SetCursorPosX(DOOR_CONTROL_COLUMN_X)
    imgui.AlignTextToFramePadding()
    imgui.Text(tostring(value or ""))
end

local function drawNextChoicesHeader(imgui)
    imgui.SetCursorPosX(DOOR_LABEL_COLUMN_X)
    imgui.AlignTextToFramePadding()
    imgui.Text(NEXT_CHOICES_LABEL)
end

local function drawCurrentRoomLabel(draw, control, instance, rowIndex, inline)
    drawDoorLabel(draw.imgui, CURRENT_ROOM_LABEL, inline)
    drawStaticDoorValue(draw.imgui, roomDisplayLabel(control, instance, rowIndex))
end

local function drawRoleAndOptionDropdowns(draw, control, instance, rowIndex)
    local currentRoleKey = data.readRoleKey(instance, control:routeRows(), rowIndex)
    local roleField = control:roomField(rowIndex, "RoleKey")
    draw.imgui.SameLine()
    draw.imgui.SetCursorPosX(DOOR_CONTROL_COLUMN_X)
    if draw.widgets.dropdown(roleField, getRoleOpts(control, instance, rowIndex)) then
        resetRowDetails(control:fields(), instance, rowIndex)
        control:invalidateReadPass()
        currentRoleKey = data.readRoleKey(instance, control:routeRows(), rowIndex)
    end

    local changed, previousOptionKey = drawOptionDropdown(draw, control, instance, rowIndex, currentRoleKey)
    if changed then
        control:invalidateReadPass()
        control:onRoomOptionChanged(rowIndex, previousOptionKey)
    end
end

local function drawFixedIdentityDoor(draw, control, instance, rowIndex, inline)
    if inline then
        draw.imgui.SameLine()
    end
    draw.imgui.SetCursorPosX(DOOR_CONTROL_COLUMN_X)

    local currentRoleKey = data.readRoleKey(instance, control:routeRows(), rowIndex)
    local changed, previousOptionKey = drawOptionDropdown(
        draw,
        control,
        instance,
        rowIndex,
        currentRoleKey,
        DOOR_CONTROL_COLUMN_X
    )
    if changed then
        control:invalidateReadPass()
        control:onRoomOptionChanged(rowIndex, previousOptionKey)
    elseif changed == nil then
        draw.imgui.AlignTextToFramePadding()
        draw.imgui.Text(roomDisplayLabel(control, instance, rowIndex))
    end
end

local function drawEntryRoom(draw, control, instance, rowIndex)
    drawDoorLabel(draw.imgui, ENTRY_ROOM_LABEL, true)
    drawFixedIdentityDoor(draw, control, instance, rowIndex, true)
end

local function drawPickedDoor(draw, control, instance, targetRowIndex)
    drawDoorLabel(draw.imgui, PICKED_DOOR_LABEL, false)
    if data.isFixedIdentityRow(instance, targetRowIndex) then
        drawFixedIdentityDoor(draw, control, instance, targetRowIndex, false)
    else
        drawRoleAndOptionDropdowns(draw, control, instance, targetRowIndex)
    end
end

local function drawRoomRow(draw, control, instance, rowIndex, terminalRowIndex)
    local slot = control:slot(rowIndex)
    if slot == nil then
        return
    end

    local imgui = draw.imgui
    control._nextChoiceRoomView = nextChoiceView.fillRow(
        control._nextChoiceRoomView or {},
        rowIndex,
        terminalRowIndex
    )
    local view = control._nextChoiceRoomView
    local currentRoom = view.currentRoom
    local nextChoices = view.nextChoices
    local pickedDoor = nextChoices.picked
    local otherDoors = nextChoices.others

    drawRouteRowHeader(imgui, slot)
    if currentRoom.isEntry then
        drawEntryRoom(draw, control, instance, currentRoom.rowIndex)
    else
        drawCurrentRoomLabel(draw, control, instance, currentRoom.rowIndex, true)
    end

    if nextChoices.active then
        drawNextChoicesHeader(imgui)
        drawPickedDoor(draw, control, instance, pickedDoor.targetRowIndex)
        if drawSiblingStructureDropdowns(draw, control, instance, otherDoors.sourceRowIndex) then
            control:invalidateReadPass()
        end
    end
end

local function drawRouteRowSeparator(imgui)
    imgui.Spacing()
    imgui.Separator()
    imgui.Spacing()
end

local function isRoomTabRow(control, rowIndex)
    local slot = control:slot(rowIndex)
    return slot ~= nil and slot.kind ~= "preboss"
end

local function lastRoomTabRowIndex(control, rowCount)
    for rowIndex = rowCount, 1, -1 do
        if isRoomTabRow(control, rowIndex) then
            return rowIndex
        end
    end
    return rowCount
end

function rooms.draw(draw, control, instance)
    local rowCount = control:rowCount()
    local terminalRowIndex = lastRoomTabRowIndex(control, rowCount)
    local drewRow = false
    local allRowsInactive, inactiveBoundary = decorations.routeInactiveBoundary(instance)
    control:beginReadPass()
    for rowIndex = 1, rowCount do
        if isRoomTabRow(control, rowIndex) then
            if drewRow then
                drawRouteRowSeparator(draw.imgui)
            end
            local inactive = decorations.pushInactive(
                draw.imgui,
                decorations.routeRowInactive(allRowsInactive, inactiveBoundary, control:slot(rowIndex), "rooms")
            )
            drawRoomRow(draw, control, instance, rowIndex, terminalRowIndex)
            decorations.popInactive(draw.imgui, inactive)
            drewRow = true
        end
    end
    control:endReadPass()
end

return rooms
