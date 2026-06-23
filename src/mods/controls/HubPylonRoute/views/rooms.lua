-- luacheck: no unused args

local deps = ...
local data = deps.data
local resetAllSideRoomDetails = deps.resetAllSideRoomDetails
local resetRewardDetails = deps.resetRewardDetails
local resetRowDetails = deps.resetRowDetails
local decorations = deps.decorations

local rooms = {}

local ROLE_OPTS = {
    label = "",
    controlWidth = 130,
}
local OPTION_OPTS = {
    label = "",
    controlWidth = 190,
}
local ROLE_COLUMN_X = 80
local OPTION_COLUMN_X = 230

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
    return decorations.decorateDropdown(opts, opts, data.roleValueStatesForRow(instance, rows, rowIndex))
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

local function optionDecorateOptsByRole(control, rowIndex)
    control._optionDecorateOptsByRow = control._optionDecorateOptsByRow or {}
    local optsByRole = control._optionDecorateOptsByRow[rowIndex]
    if optsByRole == nil then
        optsByRole = {}
        control._optionDecorateOptsByRow[rowIndex] = optsByRole
    end
    return optsByRole
end

local function optionDecorateOpts(control, instance, rowIndex, roleKey)
    local optsByRole = optionDecorateOptsByRole(control, rowIndex)
    local opts = optsByRole[roleKey]
    if opts == nil then
        opts = {}
        optsByRole[roleKey] = opts
    end
    opts.routeContext = instance.routeContext
    opts.routeKey = instance.routeKey
    opts.enrichmentValueColors = data.optionEnrichmentColorsForRole(instance, roleKey)
    return opts
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
        data.optionValueStatesForRow(instance, rows, rowIndex, roleKey),
        optionDecorateOpts(control, instance, rowIndex, roleKey)
    )
end

local function optionLabelAddsInformation(role, option)
    if role == nil or option == nil then
        return false
    end
    return tostring(option.label or option.key or "") ~= tostring(role.label or role.key or "")
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
    if optionOpts.values[2] == nil
        and optionOpts.values[1] ~= ""
        and (storedOptionKey == "" or storedOptionKey == optionOpts.values[1])
    then
        drawStaticOptionLabel(draw, role, role.optionsByKey and role.optionsByKey[optionOpts.values[1]] or nil, columnX)
        return false
    end

    draw.imgui.SameLine()
    draw.imgui.SetCursorPosX(columnX or OPTION_COLUMN_X)
    return draw.widgets.dropdown(
        control:roomField(rowIndex, "OptionKey"),
        optionOpts
    )
end

local function drawRouteRowHeader(imgui, slot)
    imgui.AlignTextToFramePadding()
    imgui.Text(slot.label)
end

local function drawRoomRow(draw, control, instance, rowIndex)
    local slot = control:slot(rowIndex)
    if slot == nil then
        return
    end

    local imgui = draw.imgui
    local currentRoleKey = data.readRoleKey(instance, control:routeRows(), rowIndex)

    drawRouteRowHeader(imgui, slot)
    if data.isFixedIdentityRow(instance, rowIndex) then
        if drawOptionDropdown(draw, control, instance, rowIndex, currentRoleKey, ROLE_COLUMN_X) then
            resetRewardDetails(control:fields(), rowIndex)
            resetAllSideRoomDetails(control:fields(), instance, rowIndex)
            control:invalidateReadPass()
        end
    else
        local roleField = control:roomField(rowIndex, "RoleKey")
        imgui.SameLine()
        imgui.SetCursorPosX(ROLE_COLUMN_X)
        if draw.widgets.dropdown(roleField, getRoleOpts(control, instance, rowIndex)) then
            resetRowDetails(control:fields(), instance, rowIndex)
            control:invalidateReadPass()
            currentRoleKey = data.readRoleKey(instance, control:routeRows(), rowIndex)
        end
        if drawOptionDropdown(draw, control, instance, rowIndex, currentRoleKey) then
            resetRewardDetails(control:fields(), rowIndex)
            resetAllSideRoomDetails(control:fields(), instance, rowIndex)
            control:invalidateReadPass()
        end
    end
end

local function drawRouteRowSeparator(imgui)
    imgui.Spacing()
    imgui.Separator()
    imgui.Spacing()
end

function rooms.draw(draw, control, instance)
    local rowCount = control:rowCount()
    local drewRow = false
    local allRowsInactive, inactiveBoundary = decorations.routeInactiveBoundary(instance)
    control:beginReadPass()
    for rowIndex = 1, rowCount do
        if drewRow then
            drawRouteRowSeparator(draw.imgui)
        end
        local inactive = decorations.pushInactive(
            draw.imgui,
            decorations.routeRowInactive(allRowsInactive, inactiveBoundary, control:slot(rowIndex), "rooms")
        )
        drawRoomRow(draw, control, instance, rowIndex)
            decorations.popInactive(draw.imgui, inactive)
            drewRow = true
        end
    control:endReadPass()
end

return rooms
