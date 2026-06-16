-- luacheck: no unused args

local deps = ...
local data = deps.data
local runtime = deps.runtime

local ui = {}

local ROLE_OPTS = {
    label = "",
    controlWidth = 130,
}
local OPTION_OPTS = {
    label = "",
    controlWidth = 190,
}

local function copyBaseOpts(base)
    local copy = {}
    for key, value in pairs(base or {}) do
        copy[key] = value
    end
    return copy
end

local function resetRowDetails(fields, rowIndex)
    fields.Rows:reset(rowIndex, "OptionKey")
    fields.Rows:reset(rowIndex, "VariantKey")
    for index = 1, data.REWARD_SLOT_COUNT do
        fields.Rows:reset(rowIndex, "Reward" .. tostring(index) .. "Key")
    end
end

local function normalizeRoleField(control, instance, rowIndex)
    local roleField = control:rowField(rowIndex, "RoleKey")
    local roleKey = roleField:read()
    if instance.rolesByKey[roleKey] ~= nil then
        return roleField, roleKey
    end

    roleField:write("Vanilla")
    resetRowDetails(control:fields(), rowIndex)
    return roleField, "Vanilla"
end

local function normalizeOptionField(control, instance, rowIndex, roleKey)
    local role = instance.rolesByKey[roleKey]
    if role == nil then
        return
    end

    local values = instance.optionValuesByRole[roleKey] or {}
    local defaultValue = values[1] or ""
    local optionKey = control:rowField(rowIndex, "OptionKey"):read()
    if optionKey == defaultValue or role.optionsByKey[optionKey] ~= nil then
        return
    end
    control:rowField(rowIndex, "OptionKey"):write(defaultValue)
end

local function getRoleOpts(control, instance)
    if control._roleOpts == nil then
        local opts = copyBaseOpts(ROLE_OPTS)
        opts.values = instance.roleValues
        opts.displayValues = instance.roleLabels
        control._roleOpts = opts
    end
    return control._roleOpts
end

local function getOptionOpts(control, instance, roleKey)
    control._optionOptsByRole = control._optionOptsByRole or {}
    local opts = control._optionOptsByRole[roleKey]
    if opts == nil then
        opts = copyBaseOpts(OPTION_OPTS)
        opts.values = instance.optionValuesByRole[roleKey] or { "" }
        opts.displayValues = instance.optionLabelsByRole[roleKey] or {}
        control._optionOptsByRole[roleKey] = opts
    end
    return opts
end

local function drawOptionDropdown(draw, control, instance, rowIndex, roleKey)
    local role = instance.rolesByKey[roleKey]
    if role == nil or #data.optionListForRole(role) == 0 then
        return
    end

    normalizeOptionField(control, instance, rowIndex, roleKey)
    draw.imgui.SameLine()
    draw.imgui.SetCursorPosX(230)
    draw.widgets.dropdown(
        control:rowField(rowIndex, "OptionKey"),
        getOptionOpts(control, instance, roleKey)
    )
end

local function drawRouteRow(draw, control, instance, rowIndex)
    local slot = control:slot(rowIndex)
    if slot == nil then
        return
    end

    local imgui = draw.imgui
    local roleField, currentRoleKey = normalizeRoleField(control, instance, rowIndex)

    imgui.AlignTextToFramePadding()
    imgui.Text(slot.label)
    imgui.SameLine()
    imgui.SetCursorPosX(80)
    if draw.widgets.dropdown(roleField, getRoleOpts(control, instance)) then
        resetRowDetails(control:fields(), rowIndex)
        currentRoleKey = roleField:read()
    end
    drawOptionDropdown(draw, control, instance, rowIndex, currentRoleKey)
end

function ui.create(fields, instance)
    local control = runtime.create(fields, instance)

    function control:fields()
        return fields
    end

    function control:rowField(rowIndex, rowAlias)
        return fields.Rows:get(rowIndex, rowAlias)
    end

    function control:resetRow(rowIndex)
        fields.Rows:reset(rowIndex, "RoleKey")
        resetRowDetails(fields, rowIndex)
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

ui.views = {}

function ui.views.planner(draw, control, instance)
    draw.widgets.text(instance.label)
    draw.widgets.separator()
    for rowIndex = 1, control:rowCount() do
        drawRouteRow(draw, control, instance, rowIndex)
    end
end

ui.views.default = ui.views.planner

return ui
