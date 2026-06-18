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
local CAGE_COUNT_OPTS = {
    label = "",
    controlWidth = 120,
}
local ROLE_COLUMN_X = 80
local OPTION_COLUMN_X = 230
local CAGE_COUNT_COLUMN_X = 430
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

local function resetRewardDetails(fields, rowIndex)
    for index = 1, data.REWARD_SLOT_COUNT do
        fields.Rewards:reset(rowIndex, "Reward" .. tostring(index) .. "Key")
        fields.Rewards:reset(rowIndex, "Reward" .. tostring(index) .. "LootKey")
    end
end

local function resetCageRewardDetails(fields, instance, rowIndex)
    for cageIndex = 1, data.maxCageRewardCount(instance) do
        local cageRewardRowIndex = data.cageRewardRowIndex(instance, rowIndex, cageIndex)
        if cageRewardRowIndex ~= nil then
            for rewardIndex = 1, data.REWARD_SLOT_COUNT do
                fields.CageRewards:reset(cageRewardRowIndex, "Reward" .. tostring(rewardIndex) .. "Key")
                fields.CageRewards:reset(cageRewardRowIndex, "Reward" .. tostring(rewardIndex) .. "LootKey")
            end
        end
    end
end

local function resetRoomDetails(fields, rowIndex)
    fields.Rooms:reset(rowIndex, "OptionKey")
    fields.Rooms:reset(rowIndex, "VariantKey")
end

local function resetRowDetails(fields, instance, rowIndex)
    resetRoomDetails(fields, rowIndex)
    resetRewardDetails(fields, rowIndex)
    resetCageRewardDetails(fields, instance, rowIndex)
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

local function cageCountOptsByRole(control, rowIndex)
    control._cageCountOptsByRow = control._cageCountOptsByRow or {}
    local optsByRole = control._cageCountOptsByRow[rowIndex]
    if optsByRole == nil then
        optsByRole = {}
        control._cageCountOptsByRow[rowIndex] = optsByRole
    end
    return optsByRole
end

local function getCageCountOpts(control, instance, rowIndex, roleKey)
    local optsByRole = cageCountOptsByRole(control, rowIndex)
    local opts = optsByRole[roleKey]
    if opts == nil then
        opts = copyBaseOpts(CAGE_COUNT_OPTS)
        opts.values = {}
        opts.displayValues = data.cageCountLabelsForRole(instance, roleKey)
        optsByRole[roleKey] = opts
    end
    opts.values = data.cageCountValuesForRow(instance, control:routeRows(), rowIndex, roleKey)
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

local function trimList(list, count)
    for index = count + 1, #list do
        list[index] = nil
    end
end

local function policyForScope(instance, scope)
    if rewardOfferRules == nil or rewardOfferPolicies == nil then
        return nil
    end

    local policyKey = instance.biome
        and instance.biome.fields
        and instance.biome.fields.offerPolicy
    return rewardOfferRules.policyForScope(rewardOfferPolicies, policyKey, scope)
end

local function fillCageRewardOfferItems(items, fields, instance, routeRows, rowIndex)
    local slot = instance.routeSlots and instance.routeSlots[rowIndex] or nil
    local count = 0
    for cageIndex = 1, data.cageRewardCountForRow(instance, routeRows, rowIndex) do
        local cageRewardRowIndex = data.cageRewardRowIndex(instance, rowIndex, cageIndex)
        if cageRewardRowIndex ~= nil then
            count = count + 1
            local item = items[count] or {}
            item.rowIndex = rowIndex
            item.coordinate = slot and slot.coordinate or nil
            item.rewardType = fields.CageRewards:read(cageRewardRowIndex, "Reward1Key") or ""
            item.boonSource = item.rewardType == "Boon"
                and (fields.CageRewards:read(cageRewardRowIndex, "Reward2Key") or "")
                or nil
            items[count] = item
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

local function uiRowOfferValidation(control, instance, rowIndex, scratch)
    local policy = policyForScope(instance, "row.cageRewards")
    if policy == nil then
        return nil
    end

    scratch.items = scratch.items or {}
    scratch.validation = scratch.validation or {}
    local items = fillCageRewardOfferItems(
        scratch.items,
        control:fields(),
        instance,
        control:routeRows(),
        rowIndex
    )
    return validationFromInvalid(rewardOfferRules.firstInvalid(policy, items, scratch), scratch.validation)
end

local function uiRowValidation(control, instance, rowIndex)
    local validation = data.validateRow(instance, control:routeRows(), rowIndex)
    if not validation.valid then
        return validation
    end

    control._uiRowOfferScratchByRow = control._uiRowOfferScratchByRow or {}
    local scratch = control._uiRowOfferScratchByRow[rowIndex]
    if scratch == nil then
        scratch = {}
        control._uiRowOfferScratchByRow[rowIndex] = scratch
    end
    return uiRowOfferValidation(control, instance, rowIndex, scratch) or validation
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

local function drawCageCountDropdown(draw, control, instance, rowIndex, roleKey)
    local cageCountOpts = getCageCountOpts(control, instance, rowIndex, roleKey)
    if cageCountOpts.values[1] == nil then
        return false
    end

    draw.imgui.SameLine()
    draw.imgui.SetCursorPosX(CAGE_COUNT_COLUMN_X)
    return draw.widgets.dropdown(
        control:roomField(rowIndex, "VariantKey"),
        cageCountOpts
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
            resetCageRewardDetails(control:fields(), instance, rowIndex)
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
            resetCageRewardDetails(control:fields(), instance, rowIndex)
            control:invalidateReadPass()
        end
        if drawCageCountDropdown(draw, control, instance, rowIndex, currentRoleKey) then
            control:invalidateReadPass()
        end
    end
    drawRowValidation(draw, control, instance, rowIndex)
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
    drawRowValidation(draw, control, instance, rowIndex)
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

local function drawRows(draw, control, instance, drawRow)
    local rowCount = control:rowCount()
    local drewRow = false
    control:beginReadPass()
    for rowIndex = 1, rowCount do
        if drewRow then
            drawRouteRowSeparator(draw.imgui)
        end
        drawRow(draw, control, instance, rowIndex)
        drewRow = true
    end
    control:endReadPass()
end

function ui.create(fields, instance)
    local control = runtime.create(fields, instance)

    function control:fields()
        return fields
    end

    function control:roomField(rowIndex, rowAlias)
        return fields.Rooms:get(rowIndex, rowAlias)
    end

    function control:rewardField(rowIndex, rowAlias)
        return fields.Rewards:get(rowIndex, rowAlias)
    end

    function control:cageRewardField(cageRewardRowIndex, rowAlias)
        return fields.CageRewards:get(cageRewardRowIndex, rowAlias)
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
    imgui.EndTabBar()
end

ui.views.default = ui.views.planner

return ui
