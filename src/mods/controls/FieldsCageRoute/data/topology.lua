local deps = ...
local common = deps.common
local roomTopology = deps.roomTopology
local roomTopologyAdapter = deps.roomTopologyAdapter
local slots = deps.slots

local topology = {}

local validStatus = common.validStatus
local invalidStatus = common.invalidStatus

local EMPTY_VALUES = {}

local function rewardAddresses(count)
    local addresses = {}
    for index = 1, count do
        addresses[index] = "cage:" .. tostring(index)
    end
    return addresses
end

local function selectedRoomTopology(roleKey, option, cageCount)
    if roleKey == "Combat" then
        local count = math.floor(tonumber(cageCount and cageCount.cageRewardCount) or 0)
        if count <= 0 then
            return nil
        end
        return {
            structure = "CombatCage" .. tostring(count),
            rewardStore = "RunProgress",
            offerCount = count,
            rewardAddresses = rewardAddresses(count),
        }
    elseif roleKey == "Miniboss" then
        return {
            structure = "Miniboss",
            roomKey = option and option.key or nil,
            rewardStore = "RunProgress",
            eligibleRewardTypes = { "Boon" },
            offerCount = 1,
            rewardAddresses = { "row" },
        }
    elseif roleKey == "Bridge" then
        return {
            structure = "Bridge",
            offerCount = 0,
        }
    end
    return nil
end

local function siblingRoomTopology(option)
    if option == nil or option.key == nil or option.key == "" then
        return nil
    end
    return {
        structure = option.structure,
        roomKey = roomTopology.roomKey(option),
        rewardStore = option.rewardStore,
        eligibleRewardTypes = option.eligibleRewardTypes,
        offerCount = option.offerCount,
    }
end

local function isCombatCageStructure(structure)
    return string.match(tostring(structure or ""), "^CombatCage%d+$") ~= nil
end

local function hasSelectableSiblingStructure(roleKey)
    return roleKey == "Combat" or roleKey == "Miniboss" or roleKey == "Bridge"
end

function topology.create(data)
    local topologyRulesStatus
    local shared = roomTopologyAdapter.create(data, {
        namespace = "fields",
        slots = slots,
        topologyForInstance = function(instance)
            return instance.biome.fields
                and instance.biome.fields.roomTopology
                or nil
        end,
        hasSelectableSiblingStructure = function(_, _, _, roleKey)
            return hasSelectableSiblingStructure(roleKey)
        end,
        extraRuleStatus = function(instance, rows, rowIndex, _, sibling)
            return topologyRulesStatus(instance, rows, rowIndex, sibling)
        end,
    })

    local function selectedCombatCageRewardCount(instance, rows, rowIndex)
        local roleKey = data.resolveRole(instance, rows, rowIndex)
        if roleKey ~= "Combat" then
            return nil
        end

        local _, cageCount = data.resolveCageCount(instance, rows, rowIndex, roleKey)
        local count = cageCount and math.floor(tonumber(cageCount.cageRewardCount) or 0) or 0
        if count <= 0 then
            return nil
        end
        return count
    end

    local function matchingCombatCageRewardCountStatus(instance, rows, rowIndex, sibling)
        if not isCombatCageStructure(sibling and sibling.structure) then
            return validStatus()
        end

        local selectedCount = selectedCombatCageRewardCount(instance, rows, rowIndex)
        if selectedCount == nil then
            return validStatus()
        end

        local siblingCount = math.floor(tonumber(sibling.offerCount) or 0)
        if siblingCount == selectedCount then
            return validStatus()
        end
        return invalidStatus(
            "fields_sibling_combat_cage_count_mismatch",
            "Sibling combat reward count must match selected combat reward count"
        )
    end

    local function topologyRuleStatus(instance, rows, rowIndex, sibling, rule)
        if rule.key == "matchingCombatCageRewardCount" then
            return matchingCombatCageRewardCountStatus(instance, rows, rowIndex, sibling)
        end
        return validStatus()
    end

    topologyRulesStatus = function(instance, rows, rowIndex, sibling)
        local policy = instance.siblingStructurePolicy
        for _, rule in ipairs(policy and policy.rules or EMPTY_VALUES) do
            local status = topologyRuleStatus(instance, rows, rowIndex, sibling, rule)
            if not status.valid then
                return status
            end
        end
        return validStatus()
    end

    local api = {}

    function api.prepareSiblingStructurePolicy(instance)
        return shared.prepareSiblingStructurePolicy(instance)
    end

    function api.siblingStructureAlias(instance)
        return shared.siblingStructureAlias(instance)
    end

    function api.siblingStructureLabels(instance)
        return shared.siblingStructureLabels(instance)
    end

    function api.siblingStructureValues(instance)
        return shared.siblingStructureValues(instance)
    end

    function api.siblingStructureStatus(instance, rows, rowIndex)
        return shared.siblingStructureStatus(instance, rows, rowIndex)
    end

    function api.shouldDrawSiblingStructure(instance, rows, rowIndex)
        return shared.shouldDrawSiblingStructure(instance, rows, rowIndex, 1)
    end

    function api.resolveSiblingStructure(instance, rows, rowIndex)
        return shared.resolveSiblingStructure(instance, rows, rowIndex)
    end

    function api.siblingStructureValueStatesForRow(instance, rows, rowIndex)
        return shared.siblingStructureValueStatesForRow(instance, rows, rowIndex)
    end

    function api.validateRoomTopology(instance, rows, rowIndex)
        local roleKey = data.resolveRole(instance, rows, rowIndex)
        if data.isFixedIdentityRow(instance, rowIndex) then
            return nil
        end

        if not hasSelectableSiblingStructure(roleKey) then
            return nil
        end

        local _, cageCount = data.resolveCageCount(instance, rows, rowIndex, roleKey)
        if roleKey == "Combat" and (cageCount == nil or (cageCount.cageRewardCount or 0) <= 0) then
            return invalidStatus("fields_cage_count_required", "Fields topology needs picked cage reward count")
        end

        return shared.validateSiblingStructures(instance, rows, rowIndex, {
            requiredCode = "fields_sibling_structure_required",
            requiredMessage = "Fields topology needs sibling door structure",
            unavailableCode = "fields_sibling_structure_unavailable",
            unavailableMessage = function(sibling, siblingKey)
                return "Sibling " .. tostring(sibling.label or siblingKey) .. " is not valid at this pick"
            end,
        })
    end

    function api.roomTopology(instance, rows, rowIndex)
        local roleKey = data.resolveRole(instance, rows, rowIndex)
        if data.isFixedIdentityRow(instance, rowIndex) then
            return nil
        end
        if data.activeSiblingStructureCount(instance, rows, rowIndex) < 1 then
            return nil
        end
        if not data.siblingStructureStatus(instance, rows, rowIndex).valid then
            return nil
        end

        local _, cageCount = data.resolveCageCount(instance, rows, rowIndex, roleKey)
        local _, option = data.resolveOption(instance, rows, rowIndex, roleKey)
        local _, sibling = data.resolveSiblingStructure(instance, rows, rowIndex)
        if not shared.siblingAvailabilityStatus(instance, rows, rowIndex, nil, sibling).valid then
            return nil
        end
        local selected = selectedRoomTopology(roleKey, option, cageCount)
        local siblingTopology = siblingRoomTopology(sibling)
        if selected == nil or siblingTopology == nil then
            return nil
        end

        return {
            kind = "fieldsChoice",
            selected = selected,
            sibling = siblingTopology,
        }
    end

    function api.activeSiblingStructureCount(instance, rows, rowIndex)
        return shared.activeSiblingStructureCount(instance, rows, rowIndex)
    end

    return api
end

return topology
