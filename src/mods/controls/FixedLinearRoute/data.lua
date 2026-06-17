local deps = ...
local common = deps.common
local availability = deps.availability
local rowEngine = deps.rowEngine

local VANILLA_ROLE_KEY = common.VANILLA_ROLE_KEY

local shallowCopyList = common.shallowCopyList
local buildLookup = common.buildLookup
local buildKeyLookup = common.buildKeyLookup
local addChoice = common.addChoice
local buildOptionChoices = common.buildOptionChoices
local validStatus = common.validStatus
local invalidStatus = common.invalidStatus
local slotDepth = availability.slotDepth

local data

local function slotForRow(instance, rowIndex)
    return instance.routeSlots[math.floor(tonumber(rowIndex) or 0)]
end

local function isPrebossSlot(slot)
    return slot ~= nil and slot.kind == "preboss"
end

local function isFixedRoleSlot(slot)
    return slot ~= nil and slot.role ~= nil
end

local function isFixedIdentitySlot(slot)
    return isPrebossSlot(slot) or isFixedRoleSlot(slot)
end

local function firstBranchKey(slot)
    return slot and (slot.branchKey or (slot.branchValues and slot.branchValues[1])) or ""
end

local function forcedRuleForSlot(instance, slot)
    local depth = slotDepth(slot)
    if depth == nil then
        return nil
    end
    return instance.forcedDepthOptions and instance.forcedDepthOptions[depth] or nil
end

local function forcedRuleForRow(instance, rowIndex)
    return forcedRuleForSlot(instance, slotForRow(instance, rowIndex))
end

local function isRoleAllowedByForcedRule(instance, rowIndex, roleKey)
    local rule = forcedRuleForRow(instance, rowIndex)
    if rule == nil or roleKey == VANILLA_ROLE_KEY then
        return true
    end
    return roleKey == rule.roleKey
end

local function isOptionAllowedByForcedRule(instance, rowIndex, roleKey, optionKey)
    local rule = forcedRuleForRow(instance, rowIndex)
    if rule == nil then
        return true
    end
    if roleKey ~= rule.roleKey then
        return false
    end
    if rule.optionKeysByKey == nil then
        return true
    end
    return rule.optionKeysByKey[optionKey] == true
end

local function buildFixedRoleSlot(instance, depth, special)
    local roomOptions = shallowCopyList(special.roomOptions)
    local role = {
        key = special.key or special.kind,
        label = special.label or special.key or special.kind,
        roomOptions = roomOptions,
        optionsByKey = buildLookup(roomOptions),
        reward = special.reward,
    }
    buildOptionChoices(role)

    local rowIndex = #instance.routeSlots + 1
    instance.routeSlots[rowIndex] = {
        rowIndex = rowIndex,
        coordinate = depth,
        kind = special.kind,
        label = special.label or role.label,
        roleKey = role.key,
        role = role,
    }
end

local function buildRouteSlots(instance)
    local slotLayout = instance.biome.slotLayout or {}
    local startDepth = math.floor(tonumber(slotLayout.routeStartDepth) or 1)
    local endDepth = math.floor(tonumber(slotLayout.routeEndDepth) or startDepth)
    if endDepth < startDepth then
        endDepth = startDepth
    end

    instance.routeSlots = {}
    local fixedDepths = {}
    for depth, slot in pairs(slotLayout.special or {}) do
        if slot.kind == "opening" then
            fixedDepths[#fixedDepths + 1] = math.floor(tonumber(depth) or 0)
        end
    end
    table.sort(fixedDepths)
    for _, depth in ipairs(fixedDepths) do
        buildFixedRoleSlot(instance, depth, slotLayout.special[depth])
    end

    for depth = startDepth, endDepth do
        local rowIndex = #instance.routeSlots + 1
        instance.routeSlots[rowIndex] = {
            rowIndex = rowIndex,
            coordinate = depth,
            kind = "route",
            label = "Depth " .. tostring(depth),
        }
    end

    local specialDepths = {}
    for depth, slot in pairs(slotLayout.special or {}) do
        if slot.kind == "preboss" then
            specialDepths[#specialDepths + 1] = math.floor(tonumber(depth) or 0)
        end
    end
    table.sort(specialDepths)
    for _, depth in ipairs(specialDepths) do
        local special = slotLayout.special[depth]
        for _, branch in ipairs(special.branches or {}) do
            local branches = { branch }
            local rowIndex = #instance.routeSlots + 1
            local slot = {
                rowIndex = rowIndex,
                coordinate = depth,
                kind = "preboss",
                label = branch.label or special.label or ("Depth " .. tostring(depth) .. " Preboss"),
                roomKey = special.roomKey,
                branchKey = branch.key,
                branch = branch,
                branches = branches,
                branchesByKey = buildLookup(branches),
                branchValues = {},
                branchLabels = {},
            }
            addChoice(slot.branchValues, slot.branchLabels, branch.key, branch.label)
            instance.routeSlots[rowIndex] = slot
        end
    end
    instance.routeRowCount = #instance.routeSlots
end

local function addBranchLabels(instance)
    for _, slot in ipairs(instance.routeSlots or {}) do
        for _, branch in ipairs(slot.branches or {}) do
            instance.roleLabels[branch.key] = branch.label or branch.key
        end
    end
end

local adapter = {
    slotForRow = slotForRow,
    isFixedIdentitySlot = isFixedIdentitySlot,

    readRoleKey = function(instance, rows, rowIndex, slot, defaultReadRoleKey)
        if isFixedRoleSlot(slot) then
            return slot.roleKey
        end
        if isPrebossSlot(slot) then
            return firstBranchKey(slot)
        end
        return defaultReadRoleKey(instance, rows, rowIndex, slot)
    end,

    roleForRow = function(instance, rowIndex, roleKey, slot, defaultRoleForRow)
        if isFixedRoleSlot(slot) then
            if roleKey == nil or roleKey == "" or roleKey == slot.roleKey then
                return slot.role
            end
            return nil
        end
        if isPrebossSlot(slot) then
            return slot.branchesByKey[roleKey]
        end
        return defaultRoleForRow(instance, rowIndex, roleKey, slot)
    end,

    roleAvailabilityForSlot = function(_, _, _, roleKey, slot)
        if isFixedRoleSlot(slot) then
            return roleKey == slot.roleKey
        end
        if isPrebossSlot(slot) then
            return slot.branchesByKey[roleKey] ~= nil
        end
        return nil
    end,

    fillRoleValuesForSlot = function(_, _, _, slot, values)
        if isFixedRoleSlot(slot) then
            values[#values + 1] = slot.roleKey
            return true
        end
        if isPrebossSlot(slot) then
            for _, branchKey in ipairs(slot.branchValues or {}) do
                values[#values + 1] = branchKey
            end
            return true
        end
        return false
    end,

    skipOptionsForSlot = function(_, _, _, slot)
        return isPrebossSlot(slot)
    end,

    validateSlot = function(_, _, _, _, _, slot)
        if isPrebossSlot(slot) then
            return validStatus()
        end
        return nil
    end,

    isRoleAllowed = function(instance, _, rowIndex, roleKey)
        return isRoleAllowedByForcedRule(instance, rowIndex, roleKey)
    end,

    isOptionAllowed = function(instance, _, rowIndex, roleKey, optionKey)
        return isOptionAllowedByForcedRule(instance, rowIndex, roleKey, optionKey)
    end,

    roleDisallowedStatus = function(instance, _, rowIndex)
        local rule = forcedRuleForRow(instance, rowIndex)
        return invalidStatus(
            "forced_depth_role",
            "Depth " .. tostring(instance.routeSlots[rowIndex] and instance.routeSlots[rowIndex].coordinate)
                .. " is forced to " .. tostring(rule and rule.roleKey or "another role")
        )
    end,

    optionUnavailableMessage = function(_, _, _, _, role)
        return tostring(role.label or role.key) .. " is not valid at this depth"
    end,
}

data = rowEngine.create(adapter)

function data.prepare(instance)
    instance.biome = instance.biome or {}
    instance.biomeKey = instance.biome.key or instance.biomeKey or instance.name
    instance.label = instance.label or instance.biome.label or instance.biomeKey
    data.prepareRoles(instance)
    instance.forcedDepthOptions = instance.biome.forcedDepthOptions or {}
    for _, rule in pairs(instance.forcedDepthOptions) do
        rule.optionKeysByKey = buildKeyLookup(rule.optionKeys)
    end

    buildRouteSlots(instance)
    data.buildRoleChoices(instance)
    addBranchLabels(instance)
    data.prepareSlots(instance)
    return instance
end

function data.storage(instance)
    return {
        {
            key = "Rooms",
            type = "table",
            minRows = instance.routeRowCount,
            defaultRows = instance.routeRowCount,
            maxRows = instance.routeRowCount,
            row = data.buildRoomRows(),
        },
        {
            key = "Rewards",
            type = "table",
            minRows = instance.routeRowCount,
            defaultRows = instance.routeRowCount,
            maxRows = instance.routeRowCount,
            row = data.buildRewardRows(),
        },
    }
end

return data
