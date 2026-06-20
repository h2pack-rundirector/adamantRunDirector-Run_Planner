-- luacheck: no unused args

local deps = ...
local data = deps.data
local rewardRuntime = deps.rewardRuntime
local rewardUi = deps.rewardUi
local rewardOfferPolicies = deps.rewardOfferPolicies
local rewardOfferRules = deps.rewardOfferRules
local routeStatusUi = deps.routeStatusUi
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
local SIDE_MODE_OPTS = {
    label = "",
    controlWidth = 110,
}
local ROLE_COLUMN_X = 80
local OPTION_COLUMN_X = 230
local REWARD_COLUMN_X = 130
local SIDE_MODE_COLUMN_X = 130
local SIDE_REWARD_COLUMN_X = 260
local REWARD_DRAW_OPTS = {
    hideGenericRewardLabel = true,
}

local function rewardDrawOpts(control)
    if control.rewardDrawOpts ~= nil then
        return control:rewardDrawOpts(REWARD_DRAW_OPTS)
    end
    return REWARD_DRAW_OPTS
end

local function rewardsConfigured(control)
    return control.rewardsConfigured == nil or control:rewardsConfigured()
end

local function copyBaseOpts(base)
    local copy = {}
    for key, value in pairs(base or {}) do
        copy[key] = value
    end
    return copy
end

local function clearMap(map)
    for key in pairs(map) do
        map[key] = nil
    end
end

local function trimList(list, count)
    for index = count + 1, #list do
        list[index] = nil
    end
end

local function resetRewardDetails(fields, rowIndex)
    for index = 1, data.REWARD_SLOT_COUNT do
        fields.Rewards:reset(rowIndex, "Reward" .. tostring(index) .. "Key")
        fields.Rewards:reset(rowIndex, "Reward" .. tostring(index) .. "LootKey")
    end
end

local function resetSideRewardDetails(fields, sideRowIndex)
    if sideRowIndex == nil then
        return
    end
    for index = 1, data.REWARD_SLOT_COUNT do
        fields.SideRewards:reset(sideRowIndex, "Reward" .. tostring(index) .. "Key")
        fields.SideRewards:reset(sideRowIndex, "Reward" .. tostring(index) .. "LootKey")
    end
end

local function resetSideRoomDetails(fields, sideRowIndex)
    if sideRowIndex == nil then
        return
    end
    fields.SideRooms:reset(sideRowIndex, data.sideRoomModeAlias())
    resetSideRewardDetails(fields, sideRowIndex)
end

local function resetAllSideRoomDetails(fields, instance, rowIndex)
    for sideIndex = 1, data.maxSideDoorCount(instance) do
        resetSideRoomDetails(fields, data.sideRoomRowIndex(instance, rowIndex, sideIndex))
    end
end

local function resetRoomDetails(fields, rowIndex)
    fields.Rooms:reset(rowIndex, "OptionKey")
    fields.Rooms:reset(rowIndex, "VariantKey")
end

local function resetRowDetails(fields, instance, rowIndex)
    resetRoomDetails(fields, rowIndex)
    resetRewardDetails(fields, rowIndex)
    resetAllSideRoomDetails(fields, instance, rowIndex)
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

local function getSideModeOpts(control, instance)
    if control._sideModeOpts == nil then
        control._sideModeOpts = copyBaseOpts(SIDE_MODE_OPTS)
        control._sideModeOpts.values = data.sideRoomModeValues(instance)
        control._sideModeOpts.displayValues = data.sideRoomModeLabels(instance)
    end
    return control._sideModeOpts
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

local function sideRewardFields(control, sideRowIndex)
    control._sideRewardFieldsByRow = control._sideRewardFieldsByRow or {}
    local fields = control._sideRewardFieldsByRow[sideRowIndex]
    if fields == nil then
        fields = {
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

local function policyForScope(instance, scope)
    if rewardOfferRules == nil or rewardOfferPolicies == nil then
        return nil
    end

    local policyKey = instance.biome
        and instance.biome.hub
        and instance.biome.hub.offerPolicy
    return rewardOfferRules.policyForScope(rewardOfferPolicies, policyKey, scope)
end

local function fillPylonOfferItems(items, control, instance)
    local fields = control:fields()
    local routeRows = control:routeRows()
    local count = 0
    for rowIndex = 1, control:rowCount() do
        local slot = control:slot(rowIndex)
        if slot ~= nil and (slot.kind or "biomeRow") == "biomeRow" then
            local validation = data.validateRow(instance, routeRows, rowIndex)
            if validation.valid then
                count = count + 1
                local item = items[count] or {}
                item.rowIndex = rowIndex
                item.routeOrdinal = slot.routeOrdinal
                item.rewardType = fields.Rewards:read(rowIndex, "Reward1Key") or ""
                item.boonSource = item.rewardType == "Boon"
                    and (fields.Rewards:read(rowIndex, "Reward2Key") or "")
                    or nil
                items[count] = item
            end
        end
    end
    trimList(items, count)
    return items
end

local function validationFromInvalid(invalid, target)
    if invalid == nil then
        return nil
    end
    target = target or {}
    target.valid = false
    target.code = invalid.code
    target.message = invalid.message
    return target
end

local function pylonOfferValidationByRow(control, instance)
    local policy = policyForScope(instance, "biome.pylonRows")
    if policy == nil then
        return nil
    end

    local scratch = control._uiPylonOfferScratch
    if scratch == nil then
        scratch = {
            dirty = true,
            items = {},
            invalidByRow = {},
            validationByRow = {},
        }
        control._uiPylonOfferScratch = scratch
    end
    if not scratch.dirty then
        return scratch.validationByRow
    end

    clearMap(scratch.invalidByRow)
    clearMap(scratch.validationByRow)
    local items = fillPylonOfferItems(scratch.items, control, instance)
    for _, invalid in ipairs(rewardOfferRules.validateOffer(policy, items)) do
        scratch.invalidByRow[invalid.rowIndex] = invalid
    end
    for rowIndex, invalid in pairs(scratch.invalidByRow) do
        scratch.validationByRow[rowIndex] = validationFromInvalid(invalid, scratch.validationByRow[rowIndex])
    end
    scratch.dirty = false
    return scratch.validationByRow
end

local function uiRowValidation(control, instance, rowIndex)
    local validation = data.validateRow(instance, control:routeRows(), rowIndex)
    if not validation.valid then
        return validation
    end

    local invalidByRow = pylonOfferValidationByRow(control, instance)
    return (invalidByRow and invalidByRow[rowIndex]) or validation
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

local function drawRowValidation(draw, control, instance, rowIndex)
    local validation = control:uiRowValidation(rowIndex)
    if validation.valid then
        return
    end

    routeStatusUi.drawInvalid(draw, validation)
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
    drawRowValidation(draw, control, instance, rowIndex)
end

local function drawPrimaryRewardRow(draw, control, instance, rowIndex)
    local slot = control:slot(rowIndex)
    if slot == nil then
        return
    end

    local imgui = draw.imgui
    local surface = control:rewardSurface(rowIndex)

    drawRewardRowHeader(imgui, control, rowIndex, slot)
    drawRowValidation(draw, control, instance, rowIndex)

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

local function drawRewardRow(draw, control, instance, rowIndex)
    drawPrimaryRewardRow(draw, control, instance, rowIndex)
end

local function drawSideRoomRow(draw, control, instance, rowIndex)
    for sideIndex = 1, data.sideDoorCountForRow(instance, control:routeRows(), rowIndex) do
        if sideIndex > 1 then
            draw.imgui.Spacing()
        end
        local sideRowIndex, sideDoor = drawSideRoomMode(draw, control, instance, rowIndex, sideIndex)
        local mode = sideRowIndex and control:fields().SideRooms:read(sideRowIndex, data.sideRoomModeAlias()) or ""
        local surface = sideDoor ~= nil and rewardRuntime and rewardRuntime.surfaceFor(sideDoor.reward) or nil
        if mode == data.sideRoomEnabledMode()
            and rewardUi ~= nil
            and rewardRuntime ~= nil
            and rewardRuntime.hasControls(surface)
        then
            draw.imgui.SameLine()
            draw.imgui.SetCursorPosX(SIDE_REWARD_COLUMN_X)
            if rewardUi.draw(draw, surface, sideRewardFields(control, sideRowIndex), rewardDrawOpts(control)) then
                control:invalidateReadPass()
            end
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

local function drawRows(draw, control, instance, drawRow, includeRow)
    local rowCount = control:rowCount()
    local drewRow = false
    control:beginReadPass()
    for rowIndex = 1, rowCount do
        if includeRow == nil or includeRow(control, instance, rowIndex) then
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
    local invalidateReadPass = control.invalidateReadPass

    function control:fields()
        return fields
    end

    function control:roomField(rowIndex, rowAlias)
        return fields.Rooms:get(rowIndex, rowAlias)
    end

    function control:rewardField(rowIndex, rowAlias)
        return fields.Rewards:get(rowIndex, rowAlias)
    end

    function control:sideRoomField(sideRowIndex, rowAlias)
        return fields.SideRooms:get(sideRowIndex, rowAlias)
    end

    function control:sideRewardField(sideRowIndex, rowAlias)
        return fields.SideRewards:get(sideRowIndex, rowAlias)
    end

    function control:invalidateReadPass()
        if self._uiPylonOfferScratch ~= nil then
            self._uiPylonOfferScratch.dirty = true
        end
        invalidateReadPass(self)
    end

    function control:uiRowValidation(rowIndex)
        return uiRowValidation(self, instance, rowIndex)
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
    drawRows(draw, control, instance, drawRoomRow)
end

function ui.views.rewards(draw, control, instance)
    drawRows(draw, control, instance, drawRewardRow)
end

function ui.views.sideRooms(draw, control, instance)
    drawRows(draw, control, instance, drawSideRoomRow, hasSideRoomRows)
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
    if rewardsConfigured(control) and imgui.BeginTabItem("Rewards") then
        ui.views.rewards(draw, control, instance)
        imgui.EndTabItem()
    end
    if imgui.BeginTabItem("Side Rooms") then
        ui.views.sideRooms(draw, control, instance)
        imgui.EndTabItem()
    end
    imgui.EndTabBar()
end

ui.views.default = ui.views.planner

return ui
