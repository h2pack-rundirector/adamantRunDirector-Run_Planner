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
local VARIANT_OPTS = {
    label = "",
    controlWidth = 130,
}
local ROLE_COLUMN_X = 80
local OPTION_COLUMN_X = 230
local VARIANT_COLUMN_X = 430
local REWARD_COLUMN_X = 130
local ENCOUNTER_REWARD_COLUMN_X = 260
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

local function resetRoomDetails(fields, rowIndex)
    fields.Rooms:reset(rowIndex, "OptionKey")
    fields.Rooms:reset(rowIndex, "VariantKey")
end

local function resetRewardDetails(fields, rowIndex)
    for index = 1, data.REWARD_SLOT_COUNT do
        fields.Rewards:reset(rowIndex, "Reward" .. tostring(index) .. "Key")
        fields.Rewards:reset(rowIndex, "Reward" .. tostring(index) .. "LootKey")
    end
end

local function resetEncounterRewardDetails(fields, instance, rowIndex)
    for legIndex = 1, data.maxEncounterRewardLegCount(instance) do
        local encounterRewardRowIndex = data.encounterRewardRowIndex(instance, rowIndex, legIndex)
        if encounterRewardRowIndex ~= nil then
            for rewardIndex = 1, data.REWARD_SLOT_COUNT do
                fields.EncounterRewards:reset(encounterRewardRowIndex, "Reward" .. tostring(rewardIndex) .. "Key")
                fields.EncounterRewards:reset(encounterRewardRowIndex, "Reward" .. tostring(rewardIndex) .. "LootKey")
            end
        end
    end
end

local function resetRowDetails(fields, instance, rowIndex)
    resetRoomDetails(fields, rowIndex)
    resetRewardDetails(fields, rowIndex)
    resetEncounterRewardDetails(fields, instance, rowIndex)
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
    opts.values = data.roleValuesForRow(instance, control:routeRows(), rowIndex)
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
        opts.displayValues = data.optionLabelsForRow(instance, rowIndex, roleKey)
        optsByRole[roleKey] = opts
    end
    opts.values = data.optionValuesForRow(instance, control:routeRows(), rowIndex, roleKey)
    return opts
end

local function variantOptsByRole(control, rowIndex)
    control._variantOptsByRow = control._variantOptsByRow or {}
    local optsByRole = control._variantOptsByRow[rowIndex]
    if optsByRole == nil then
        optsByRole = {}
        control._variantOptsByRow[rowIndex] = optsByRole
    end
    return optsByRole
end

local function getVariantOpts(control, instance, rowIndex, roleKey)
    local optsByRole = variantOptsByRole(control, rowIndex)
    local opts = optsByRole[roleKey]
    if opts == nil then
        opts = copyBaseOpts(VARIANT_OPTS)
        opts.values = {}
        opts.displayValues = data.variantLabelsForRow(instance, roleKey)
        optsByRole[roleKey] = opts
    end
    opts.values = data.variantValuesForRow(instance, rowIndex, roleKey)
    return opts
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

local function encounterRewardFields(control, encounterRewardRowIndex)
    control._encounterRewardFieldsByRow = control._encounterRewardFieldsByRow or {}
    local fields = control._encounterRewardFieldsByRow[encounterRewardRowIndex]
    if fields == nil then
        fields = {
            get = function(_, alias)
                return control:encounterRewardField(encounterRewardRowIndex, alias)
            end,
            read = function(_, alias)
                return control:fields().EncounterRewards:read(encounterRewardRowIndex, alias)
            end,
        }
        control._encounterRewardFieldsByRow[encounterRewardRowIndex] = fields
    end
    return fields
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

local function drawVariantDropdown(draw, control, instance, rowIndex, roleKey)
    local variantOpts = getVariantOpts(control, instance, rowIndex, roleKey)
    if variantOpts.values[1] == nil then
        return false
    end

    draw.imgui.SameLine()
    draw.imgui.SetCursorPosX(VARIANT_COLUMN_X)
    return draw.widgets.dropdown(
        control:roomField(rowIndex, "VariantKey"),
        variantOpts
    )
end

local function drawRowValidation(draw, control, instance, rowIndex)
    local validation = data.validateRow(instance, control:routeRows(), rowIndex)
    if validation.valid then
        return
    end

    draw.imgui.SameLine()
    draw.imgui.Text("Invalid")
end

local function drawRouteRowHeader(imgui, slot)
    imgui.AlignTextToFramePadding()
    imgui.Text(slot.label)
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
            resetEncounterRewardDetails(control:fields(), instance, rowIndex)
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
            resetEncounterRewardDetails(control:fields(), instance, rowIndex)
            control:invalidateReadPass()
        end
        if drawVariantDropdown(draw, control, instance, rowIndex, currentRoleKey) then
            control:invalidateReadPass()
        end
    end
    drawRowValidation(draw, control, instance, rowIndex)
end

local function drawRewardRow(draw, control, instance, rowIndex)
    local slot = control:slot(rowIndex)
    if slot == nil then
        return
    end

    local imgui = draw.imgui
    local surface = control:rewardSurface(rowIndex)

    drawRewardRowHeader(imgui, control, rowIndex, slot)
    drawRowValidation(draw, control, instance, rowIndex)

    for legIndex = 1, data.encounterRewardLegCountForRow(instance, control:routeRows(), rowIndex) do
        local leg = data.encounterRewardLegForRow(instance, control:routeRows(), rowIndex, legIndex)
        local encounterRewardRowIndex = data.encounterRewardRowIndex(instance, rowIndex, legIndex)
        local legSurface = leg ~= nil and rewardRuntime and rewardRuntime.surfaceFor(leg.reward) or nil
        if encounterRewardRowIndex ~= nil
            and rewardUi ~= nil
            and rewardRuntime ~= nil
            and rewardRuntime.hasControls(legSurface)
        then
            if legIndex == 1 then
                imgui.SameLine()
            else
                imgui.Spacing()
            end
            imgui.SetCursorPosX(REWARD_COLUMN_X)
            imgui.AlignTextToFramePadding()
            imgui.Text(tostring(leg.label or leg.key or "Reward"))
            imgui.SameLine()
            imgui.SetCursorPosX(ENCOUNTER_REWARD_COLUMN_X)
            rewardUi.draw(draw, legSurface, encounterRewardFields(control, encounterRewardRowIndex), REWARD_DRAW_OPTS)
        end
    end

    if rewardUi ~= nil
        and rewardRuntime ~= nil
        and rewardRuntime.hasControls(surface)
    then
        imgui.SameLine()
        imgui.SetCursorPosX(REWARD_COLUMN_X)
        rewardUi.draw(draw, surface, rewardFields(control, rowIndex), REWARD_DRAW_OPTS)
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

local function drawRows(draw, control, instance, drawRow, includeRow)
    local rowCount = control:rowCount()
    local drewRow = false
    control:beginReadPass()
    for rowIndex = 1, rowCount do
        if includeRow == nil or includeRow(control, rowIndex) then
            if drewRow then
                drawRouteRowSeparator(draw.imgui)
            end
            drawRow(draw, control, instance, rowIndex)
            drewRow = true
        end
    end
    control:endReadPass()
end

function ui.create(fields, instance)
    local control = runtime.create(fields, instance)
    local routeRows = {
        read = function(_, rowIndex, alias)
            if data.isRewardAlias(alias) then
                return fields.Rewards:read(rowIndex, alias)
            end
            return fields.Rooms:read(rowIndex, alias)
        end,
    }

    function control:fields()
        return fields
    end

    function control:routeRows()
        return routeRows
    end

    function control:roomField(rowIndex, rowAlias)
        return fields.Rooms:get(rowIndex, rowAlias)
    end

    function control:rewardField(rowIndex, rowAlias)
        return fields.Rewards:get(rowIndex, rowAlias)
    end

    function control:encounterRewardField(encounterRewardRowIndex, rowAlias)
        return fields.EncounterRewards:get(encounterRewardRowIndex, rowAlias)
    end

    function control:resetRow(rowIndex)
        fields.Rooms:reset(rowIndex, "RoleKey")
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

ui.views = {}

function ui.views.rooms(draw, control, instance)
    drawRows(draw, control, instance, drawRoomRow, isRoomTabRow)
end

function ui.views.rewards(draw, control, instance)
    drawRows(draw, control, instance, drawRewardRow)
end

function ui.views.planner(draw, control, instance)
    local imgui = draw.imgui
    local tabId = tostring(control:name()) .. "RoutePlanTabs"
    if not imgui.BeginTabBar(tabId) then
        ui.views.rooms(draw, control, instance)
        return
    end
    if imgui.BeginTabItem("Rooms") then
        ui.views.rooms(draw, control, instance)
        imgui.EndTabItem()
    end
    if imgui.BeginTabItem("Rewards") then
        ui.views.rewards(draw, control, instance)
        imgui.EndTabItem()
    end
    imgui.EndTabBar()
end

ui.views.default = ui.views.planner

return ui
