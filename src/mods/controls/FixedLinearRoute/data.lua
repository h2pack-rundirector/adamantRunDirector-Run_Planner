local data = {}

local REWARD_SLOT_COUNT = 6
local VANILLA_ROLE_KEY = "Vanilla"
local routeRequirementsStatus

local function shallowCopyList(source)
    local copy = {}
    for index, value in ipairs(source or {}) do
        copy[index] = value
    end
    return copy
end

local function optionListForRole(role)
    if type(role) ~= "table" then
        return {}
    end
    return role.roomOptions or role.mapOptions or {}
end

local function clearList(list)
    for index = #list, 1, -1 do
        list[index] = nil
    end
end

local function buildLookup(items)
    local lookup = {}
    for _, item in ipairs(items or {}) do
        if item.key ~= nil then
            lookup[item.key] = item
        end
    end
    return lookup
end

local function buildKeyLookup(items)
    local lookup = {}
    for _, key in ipairs(items or {}) do
        lookup[key] = true
    end
    return lookup
end

local function addChoice(values, labels, key, label)
    values[#values + 1] = key
    labels[key] = label or key
end

local function shouldOfferAutoOption(role, options)
    if #options == 0 then
        return false
    end
    if #options == 1 and role.roomOptions ~= nil then
        return false
    end
    return true
end

local function slotDepth(slot)
    return slot and slot.coordinate or nil
end

local function slotForRow(instance, rowIndex)
    return instance.routeSlots[math.floor(tonumber(rowIndex) or 0)]
end

local function isPrebossSlot(slot)
    return slot ~= nil and slot.kind == "preboss"
end

local function firstBranchKey(slot)
    return slot and slot.branchValues and slot.branchValues[1] or ""
end

local function isInRange(value, range)
    if range == nil or value == nil then
        return true
    end
    if range.exact ~= nil and value ~= range.exact then
        return false
    end
    if range.min ~= nil and value < range.min then
        return false
    end
    if range.max ~= nil and value > range.max then
        return false
    end
    if range.minExclusive ~= nil and value <= range.minExclusive then
        return false
    end
    if range.maxExclusive ~= nil and value >= range.maxExclusive then
        return false
    end
    return true
end

local function isAvailableAtSlot(option, slot)
    local availability = option and option.availability
    if availability == nil then
        return true
    end

    local depth = slotDepth(slot)
    return isInRange(depth, availability.biomeDepth)
        and isInRange(depth, availability.biomeEncounterDepth)
end

local function optionCap(option)
    if option == nil then
        return nil
    end
    return option.maxAppearancesThisBiome or option.maxCreationsThisRun
end

local function countPriorRoleSelections(instance, rows, rowIndex, roleKey)
    if rows == nil or roleKey == nil or roleKey == "" then
        return 0
    end

    local count = 0
    for priorIndex = 1, rowIndex - 1 do
        if rows:read(priorIndex, "RoleKey") == roleKey
            and data.isRoleAvailable(instance, rows, priorIndex, roleKey)
        then
            count = count + 1
        end
    end
    return count
end

local function countPriorOptionSelections(instance, role, rows, rowIndex, optionKey)
    if rows == nil or optionKey == nil or optionKey == "" then
        return 0
    end

    local count = 0
    for priorIndex = 1, rowIndex - 1 do
        if rows:read(priorIndex, "RoleKey") == role.key
            and rows:read(priorIndex, "OptionKey") == optionKey
            and data.isOptionAvailable(instance, rows, priorIndex, role.key, optionKey)
        then
            count = count + 1
        end
    end
    return count
end

local function isRoleWithinSelectionCap(instance, role, rows, rowIndex)
    local maxSelections = role and role.routeRules and role.routeRules.maxSelectionsPerBiome
    if maxSelections == nil then
        return true
    end
    return countPriorRoleSelections(instance, rows, rowIndex, role.key) < maxSelections
end

local function isOptionWithinSelectionCap(instance, role, option, rows, rowIndex)
    local maxSelections = optionCap(option)
    if maxSelections == nil then
        return true
    end
    return countPriorOptionSelections(instance, role, rows, rowIndex, option.key) < maxSelections
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

local function rewardContext(role, option)
    if option ~= nil and option.reward ~= nil then
        return option.reward
    end
    return role and role.reward or nil
end

local function isOnlyEligible(values, expected)
    if values == nil or values[1] == nil then
        return false
    end
    return values[1] == expected and values[2] == nil
end

local function hasAvailableConcreteOption(instance, role, rows, rowIndex, slot)
    for _, option in ipairs(optionListForRole(role)) do
        if isAvailableAtSlot(option, slot)
            and isOptionWithinSelectionCap(instance, role, option, rows, rowIndex)
            and isOptionAllowedByForcedRule(instance, rowIndex, role.key, option.key)
        then
            return true
        end
    end
    return false
end

local function buildRoleChoices(instance)
    instance.roleValues = {}
    instance.roleLabels = {}
    instance.optionValuesByRole = {}
    instance.optionLabelsByRole = {}

    for _, role in ipairs(instance.roles or {}) do
        addChoice(instance.roleValues, instance.roleLabels, role.key, role.label)

        local options = optionListForRole(role)
        local optionValues = {}
        local optionLabels = {}
        if shouldOfferAutoOption(role, options) then
            optionValues[#optionValues + 1] = ""
            optionLabels[""] = "Auto"
        end
        for _, option in ipairs(options) do
            addChoice(optionValues, optionLabels, option.key, option.label)
        end
        role.defaultOptionKey = optionValues[1] or ""
        instance.optionValuesByRole[role.key] = optionValues
        instance.optionLabelsByRole[role.key] = optionLabels
    end
end

local function buildRouteSlots(instance)
    local slotLayout = instance.biome.slotLayout or {}
    local startDepth = math.floor(tonumber(slotLayout.routeStartDepth) or 1)
    local endDepth = math.floor(tonumber(slotLayout.routeEndDepth) or startDepth)
    if endDepth < startDepth then
        endDepth = startDepth
    end

    instance.routeSlots = {}
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
        local branches = shallowCopyList(special.branches)
        local rowIndex = #instance.routeSlots + 1
        local slot = {
            rowIndex = rowIndex,
            coordinate = depth,
            kind = "preboss",
            label = special.label or ("Depth " .. tostring(depth) .. " Preboss"),
            roomKey = special.roomKey,
            branches = branches,
            branchesByKey = buildLookup(branches),
            branchValues = {},
            branchLabels = {},
        }
        for _, branch in ipairs(branches) do
            addChoice(slot.branchValues, slot.branchLabels, branch.key, branch.label)
        end
        instance.routeSlots[rowIndex] = slot
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

local function findFirstAvailableOption(instance, rows, rowIndex, role)
    local values = instance.optionValuesByRole[role.key] or {}
    for _, optionKey in ipairs(values) do
        if data.isOptionAvailable(instance, rows, rowIndex, role.key, optionKey) then
            return optionKey, optionKey ~= "" and role.optionsByKey[optionKey] or nil
        end
    end
    return nil, nil
end

local function readRoleKey(instance, rows, rowIndex)
    local roleKey = rows and rows:read(rowIndex, "RoleKey") or nil
    local slot = instance ~= nil and slotForRow(instance, rowIndex) or nil
    if isPrebossSlot(slot) and (roleKey == nil or roleKey == "" or roleKey == VANILLA_ROLE_KEY) then
        return firstBranchKey(slot)
    end
    if roleKey == nil or roleKey == "" then
        return VANILLA_ROLE_KEY
    end
    return roleKey
end

local function readOptionKey(rows, rowIndex)
    return rows and rows:read(rowIndex, "OptionKey") or ""
end

local function invalidStatus(code, message)
    return {
        valid = false,
        code = code,
        message = message,
    }
end

local function validStatus()
    return {
        valid = true,
    }
end

local function routeRequirementStatus(code, message)
    return {
        valid = false,
        code = code,
        message = message,
    }
end

local function buildRewardRows()
    local rows = {
        { key = "RoleKey", type = "string", default = "", maxLen = 32 },
        { key = "OptionKey", type = "string", default = "", maxLen = 64 },
        { key = "VariantKey", type = "string", default = "", maxLen = 64 },
    }

    for index = 1, REWARD_SLOT_COUNT do
        rows[#rows + 1] = {
            key = "Reward" .. tostring(index) .. "Key",
            type = "string",
            default = "",
            maxLen = 96,
        }
    end
    return rows
end

function data.prepare(instance)
    instance.biome = instance.biome or {}
    instance.biomeKey = instance.biome.key or instance.biomeKey or instance.name
    instance.label = instance.label or instance.biome.label or instance.biomeKey
    instance.roles = shallowCopyList(instance.biome.roles)
    instance.rolesByKey = buildLookup(instance.roles)
    for _, role in ipairs(instance.roles) do
        role.optionsByKey = buildLookup(optionListForRole(role))
    end
    instance.forcedDepthOptions = instance.biome.forcedDepthOptions or {}
    for _, rule in pairs(instance.forcedDepthOptions) do
        rule.optionKeysByKey = buildKeyLookup(rule.optionKeys)
    end

    buildRouteSlots(instance)
    buildRoleChoices(instance)
    addBranchLabels(instance)
    return instance
end

function data.storage(instance)
    return {
        {
            key = "Rows",
            type = "table",
            minRows = instance.routeRowCount,
            defaultRows = instance.routeRowCount,
            maxRows = instance.routeRowCount,
            row = buildRewardRows(),
        },
    }
end

function data.optionListForRole(role)
    return optionListForRole(role)
end

function data.isOptionAvailable(instance, rows, rowIndex, roleKey, optionKey)
    if isPrebossSlot(slotForRow(instance, rowIndex)) then
        return false
    end

    local role = instance.rolesByKey[roleKey]
    if role == nil then
        return false
    end

    local slot = slotForRow(instance, rowIndex)
    if optionKey == "" then
        return shouldOfferAutoOption(role, optionListForRole(role))
            and hasAvailableConcreteOption(instance, role, rows, rowIndex, slot)
    end

    local option = role.optionsByKey and role.optionsByKey[optionKey] or nil
    if option == nil then
        return false
    end
    return isAvailableAtSlot(option, slot)
        and isOptionWithinSelectionCap(instance, role, option, rows, rowIndex)
        and isOptionAllowedByForcedRule(instance, rowIndex, roleKey, optionKey)
end

function data.isRoleAvailable(instance, rows, rowIndex, roleKey)
    local slot = slotForRow(instance, rowIndex)
    if isPrebossSlot(slot) then
        return slot.branchesByKey[roleKey] ~= nil
    end

    local role = instance.rolesByKey[roleKey]
    if role == nil then
        return false
    end
    if roleKey == VANILLA_ROLE_KEY then
        return true
    end
    if not isRoleAllowedByForcedRule(instance, rowIndex, roleKey) then
        return false
    end
    if not isRoleWithinSelectionCap(instance, role, rows, rowIndex) then
        return false
    end
    if not routeRequirementsStatus(instance, rows, rowIndex, role).valid then
        return false
    end

    local options = optionListForRole(role)
    if #options == 0 then
        return true
    end
    return findFirstAvailableOption(instance, rows, rowIndex, role) ~= nil
end

function data.readRoleKey(instanceOrRows, rowsOrIndex, rowIndex)
    if rowIndex ~= nil then
        return readRoleKey(instanceOrRows, rowsOrIndex, rowIndex)
    end
    return readRoleKey(nil, instanceOrRows, rowsOrIndex)
end

function data.resolveRole(instance, rows, rowIndex)
    local roleKey = readRoleKey(instance, rows, rowIndex)
    local slot = slotForRow(instance, rowIndex)
    if isPrebossSlot(slot) then
        return roleKey, slot.branchesByKey[roleKey]
    end
    return roleKey, instance.rolesByKey[roleKey]
end

function data.resolveOption(instance, rows, rowIndex, roleKey)
    if isPrebossSlot(slotForRow(instance, rowIndex)) then
        return "", nil
    end

    local role = instance.rolesByKey[roleKey]
    if role == nil then
        return readOptionKey(rows, rowIndex) or "", nil
    end

    local options = optionListForRole(role)
    if #options == 0 then
        return "", nil
    end

    local optionKey = readOptionKey(rows, rowIndex) or ""
    if optionKey ~= "" then
        return optionKey, role.optionsByKey and role.optionsByKey[optionKey] or nil
    end

    if shouldOfferAutoOption(role, options) then
        return "", nil
    end

    local normalizedKey, option = findFirstAvailableOption(instance, rows, rowIndex, role)
    return normalizedKey or "", option
end

local function previousRoomExitCountStatus(instance, rows, rowIndex, requirement)
    local previousIndex = rowIndex - 1
    if previousIndex < 1 then
        return routeRequirementStatus(
            "previous_room_exit_count",
            "Previous planned room must have at least " .. tostring(requirement.minCount) .. " exits"
        )
    end

    local previousValidation = data.validateRow(instance, rows, previousIndex)
    if not previousValidation.valid then
        return routeRequirementStatus(
            "previous_room_invalid",
            "Previous planned room is invalid"
        )
    end

    local previousRoleKey = data.resolveRole(instance, rows, previousIndex)
    if previousRoleKey == VANILLA_ROLE_KEY then
        return routeRequirementStatus(
            "previous_room_unplanned",
            "Previous planned room is Vanilla"
        )
    end

    local _, previousOption = data.resolveOption(instance, rows, previousIndex, previousRoleKey)
    local exitCount = previousOption and tonumber(previousOption.exitCount) or nil
    if exitCount == nil or exitCount < requirement.minCount then
        return routeRequirementStatus(
            "previous_room_exit_count",
            "Previous planned room must have at least " .. tostring(requirement.minCount) .. " exits"
        )
    end
    return validStatus()
end

local function addGodLootSelection(selections, countedLookup, lootName)
    if lootName ~= nil and lootName ~= "" and countedLookup[lootName] then
        selections[lootName] = true
    end
end

local function collectRewardGodLoot(instance, rows, rowIndex, selections, countedLookup)
    local roleKey, role = data.resolveRole(instance, rows, rowIndex)
    if role == nil or roleKey == VANILLA_ROLE_KEY then
        return
    end

    local validation = data.validateRow(instance, rows, rowIndex)
    if not validation.valid then
        return
    end

    local _, option = data.resolveOption(instance, rows, rowIndex, roleKey)
    local context = rewardContext(role, option)
    if context == nil then
        return
    end

    local reward1 = rows:read(rowIndex, "Reward1Key") or ""
    local reward2 = rows:read(rowIndex, "Reward2Key") or ""
    local reward3 = rows:read(rowIndex, "Reward3Key") or ""

    if context.kind == "majorMinor" or context.kind == "shipWheel" then
        if reward1 == "Major" and reward2 == "Boon" then
            addGodLootSelection(selections, countedLookup, reward3)
        end
    elseif context.kind == "roomStore" then
        if isOnlyEligible(context.eligibleRewardTypes, "Boon") then
            addGodLootSelection(selections, countedLookup, reward1)
        elseif reward1 == "Boon" then
            addGodLootSelection(selections, countedLookup, reward2)
        end
    elseif context.kind == "forcedReward" then
        if context.rewardType == "Boon" then
            addGodLootSelection(selections, countedLookup, reward1)
        elseif context.rewardType == "Devotion" then
            addGodLootSelection(selections, countedLookup, reward1)
            addGodLootSelection(selections, countedLookup, reward2)
        end
    end
end

local function priorDistinctGodLootStatus(instance, rows, rowIndex, requirement)
    local countedLookup = buildKeyLookup(requirement.countedLootNames)
    local selections = {}
    local count = 0

    for priorIndex = 1, rowIndex - 1 do
        collectRewardGodLoot(instance, rows, priorIndex, selections, countedLookup)
    end

    for _ in pairs(selections) do
        count = count + 1
    end
    if count < requirement.minDistinct then
        return routeRequirementStatus(
            "prior_distinct_god_loot",
            "Requires at least " .. tostring(requirement.minDistinct) .. " prior planned god rewards"
        )
    end
    return validStatus()
end

local function routeRequirementItemStatus(instance, rows, rowIndex, requirement)
    if requirement.kind == "previousRoomExitCount" then
        return previousRoomExitCountStatus(instance, rows, rowIndex, requirement)
    elseif requirement.kind == "priorDistinctGodLoot" then
        return priorDistinctGodLootStatus(instance, rows, rowIndex, requirement)
    end
    return routeRequirementStatus(
        "unknown_route_requirement",
        "Unknown route requirement: " .. tostring(requirement.kind)
    )
end

local function checkRouteRequirements(instance, rows, rowIndex, requirements)
    for _, requirement in ipairs(requirements or {}) do
        local status = routeRequirementItemStatus(instance, rows, rowIndex, requirement)
        if not status.valid then
            return status
        end
    end
    return validStatus()
end

routeRequirementsStatus = function(instance, rows, rowIndex, role, option)
    local status = checkRouteRequirements(instance, rows, rowIndex, role.routeRequirements)
    if not status.valid then
        return status
    end

    local context = rewardContext(role, option)
    if context == nil then
        return validStatus()
    end
    return checkRouteRequirements(instance, rows, rowIndex, context.routeRequirements)
end

function data.validateRow(instance, rows, rowIndex)
    local roleKey, role = data.resolveRole(instance, rows, rowIndex)
    if role == nil then
        return invalidStatus("unknown_role", "Unknown route role: " .. tostring(roleKey))
    end
    if isPrebossSlot(slotForRow(instance, rowIndex)) then
        return validStatus()
    end
    if roleKey == VANILLA_ROLE_KEY then
        return validStatus()
    end
    if not isRoleAllowedByForcedRule(instance, rowIndex, roleKey) then
        local rule = forcedRuleForRow(instance, rowIndex)
        return invalidStatus(
            "forced_depth_role",
            "Depth " .. tostring(instance.routeSlots[rowIndex] and instance.routeSlots[rowIndex].coordinate)
                .. " is forced to " .. tostring(rule and rule.roleKey or "another role")
        )
    end
    if not isRoleWithinSelectionCap(instance, role, rows, rowIndex) then
        return invalidStatus("role_limit", tostring(role.label or roleKey) .. " is already planned for this biome")
    end
    local roleRequirementStatus = routeRequirementsStatus(instance, rows, rowIndex, role)
    if not roleRequirementStatus.valid then
        return invalidStatus(roleRequirementStatus.code, roleRequirementStatus.message)
    end

    local options = optionListForRole(role)
    if #options == 0 then
        return validStatus()
    end

    local optionKey = readOptionKey(rows, rowIndex) or ""
    local resolvedOptionKey, option = data.resolveOption(instance, rows, rowIndex, roleKey)
    if optionKey ~= "" and option == nil then
        return invalidStatus("unknown_option", "Unknown route option: " .. tostring(optionKey))
    end
    if resolvedOptionKey == "" and shouldOfferAutoOption(role, options) then
        if data.isOptionAvailable(instance, rows, rowIndex, roleKey, "") then
            return validStatus()
        end
        return invalidStatus("option_unavailable", tostring(role.label or roleKey) .. " has no valid option here")
    end
    if resolvedOptionKey == "" or not data.isOptionAvailable(instance, rows, rowIndex, roleKey, resolvedOptionKey) then
        return invalidStatus("option_unavailable", tostring(role.label or roleKey) .. " is not valid at this depth")
    end

    local requirementStatus = routeRequirementsStatus(instance, rows, rowIndex, role, option)
    if not requirementStatus.valid then
        return invalidStatus(requirementStatus.code, requirementStatus.message)
    end
    return validStatus()
end

function data.fillRoleValues(instance, rows, rowIndex, values)
    clearList(values)
    local slot = slotForRow(instance, rowIndex)
    if isPrebossSlot(slot) then
        for _, branchKey in ipairs(slot.branchValues or {}) do
            values[#values + 1] = branchKey
        end
        return values
    end

    for _, role in ipairs(instance.roles or {}) do
        if data.isRoleAvailable(instance, rows, rowIndex, role.key) then
            values[#values + 1] = role.key
        end
    end
    return values
end

function data.fillOptionValues(instance, rows, rowIndex, roleKey, values)
    clearList(values)
    if isPrebossSlot(slotForRow(instance, rowIndex)) then
        return values
    end

    local role = instance.rolesByKey[roleKey]
    if role == nil then
        return values
    end

    for _, optionKey in ipairs(instance.optionValuesByRole[roleKey] or {}) do
        if data.isOptionAvailable(instance, rows, rowIndex, roleKey, optionKey) then
            values[#values + 1] = optionKey
        end
    end
    return values
end

data.REWARD_SLOT_COUNT = REWARD_SLOT_COUNT

return data
