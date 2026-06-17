-- luacheck: no unused args

local deps = ...
local data = deps.data
local rewardRuntime = deps.rewardRuntime
local rewardUi = deps.rewardUi
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

local function getRoleOpts(control, instance, rowIndex)
    control._roleOptsByRow = control._roleOptsByRow or {}
    local opts = control._roleOptsByRow[rowIndex]
    if opts == nil then
        opts = copyBaseOpts(ROLE_OPTS)
        opts.values = {}
        opts.displayValues = instance.roleLabels
        control._roleOptsByRow[rowIndex] = opts
    end
    data.fillRoleValues(instance, control:fields().Rows, rowIndex, opts.values)
    return opts
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
        opts.displayValues = instance.optionLabelsByRole[roleKey] or {}
        optsByRole[roleKey] = opts
    end
    data.fillOptionValues(instance, control:fields().Rows, rowIndex, roleKey, opts.values)
    return opts
end

local function rewardFields(control, rowIndex)
    control._rewardFieldsByRow = control._rewardFieldsByRow or {}
    local fields = control._rewardFieldsByRow[rowIndex]
    if fields == nil then
        fields = {
            get = function(_, alias)
                return control:rowField(rowIndex, alias)
            end,
            read = function(_, alias)
                return control:fields().Rows:read(rowIndex, alias)
            end,
        }
        control._rewardFieldsByRow[rowIndex] = fields
    end
    return fields
end

local function drawOptionDropdown(draw, control, instance, rowIndex, roleKey)
    local role = instance.rolesByKey[roleKey]
    if role == nil or #data.optionListForRole(role) == 0 then
        return
    end

    local optionOpts = getOptionOpts(control, instance, rowIndex, roleKey)
    if optionOpts.values[1] == nil then
        return
    end

    draw.imgui.SameLine()
    draw.imgui.SetCursorPosX(230)
    draw.widgets.dropdown(
        control:rowField(rowIndex, "OptionKey"),
        optionOpts
    )
end

local function drawRowValidation(draw, control, instance, rowIndex)
    local validation = data.validateRow(instance, control:fields().Rows, rowIndex)
    if validation.valid then
        return
    end

    draw.imgui.SameLine()
    draw.imgui.Text("Invalid")
end

local function drawRouteRow(draw, control, instance, rowIndex)
    local slot = control:slot(rowIndex)
    if slot == nil then
        return
    end

    local imgui = draw.imgui
    local roleField = control:rowField(rowIndex, "RoleKey")
    local currentRoleKey = data.readRoleKey(control:fields().Rows, rowIndex)

    imgui.AlignTextToFramePadding()
    imgui.Text(slot.label)
    imgui.SameLine()
    imgui.SetCursorPosX(80)
    if draw.widgets.dropdown(roleField, getRoleOpts(control, instance, rowIndex)) then
        resetRowDetails(control:fields(), rowIndex)
        currentRoleKey = roleField:read()
    end
    drawOptionDropdown(draw, control, instance, rowIndex, currentRoleKey)
    drawRowValidation(draw, control, instance, rowIndex)

    local surface = control:rewardSurface(rowIndex)
    if rewardUi ~= nil
        and rewardRuntime ~= nil
        and rewardRuntime.hasControls(surface)
    then
        imgui.SetCursorPosX(80)
        rewardUi.draw(draw, surface, rewardFields(control, rowIndex))
    end
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
