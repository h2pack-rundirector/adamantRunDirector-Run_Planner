local deps = ...
local common = deps.common
local roomTopology = deps.roomTopology
local roomTopologyAdapter = deps.roomTopologyAdapter
local slots = deps.slots

local topology = {}

local validStatus = common.validStatus
local invalidStatus = common.invalidStatus

local EMPTY_VALUES = {}

local function rewardStoreForMajorMinorChoice(rows, rowIndex)
    local rewardClass = rows and rows:read(rowIndex, "Reward1Key") or nil
    if rewardClass == "Major" then
        return "RunProgress", "Major"
    elseif rewardClass == "Minor" then
        return "MetaProgress", "Minor"
    end
    return nil, nil
end

local function selectedRoomTopology(roleKey, option, rows, rowIndex)
    if roleKey == "Combat" or roleKey == "Fountain" then
        local rewardStore, rewardClass = rewardStoreForMajorMinorChoice(rows, rowIndex)
        return {
            structure = roleKey,
            roomKey = option and option.key or nil,
            rewardStore = rewardStore,
            rewardClass = rewardClass,
            offerCount = 1,
            rewardAddresses = { "row" },
        }
    elseif roleKey == "Miniboss" then
        if option == nil then
            return nil
        end
        return {
            structure = "Miniboss",
            roomKey = option.key,
            rewardStore = "RunProgress",
            eligibleRewardTypes = { "Boon" },
            offerCount = 1,
            rewardAddresses = { "row" },
        }
    elseif roleKey == "Story" then
        return {
            structure = "Story",
            roomKey = option and option.key or nil,
            offerCount = 0,
        }
    elseif roleKey == "Midshop" then
        return {
            structure = "Midshop",
            roomKey = option and option.key or nil,
            offerCount = 0,
        }
    end
    return nil
end

local function selectedRoomTopologyForRow(data, instance, rows, rowIndex)
    local roleKey = data.resolveRole(instance, rows, rowIndex)
    local _, option = data.resolveOption(instance, rows, rowIndex, roleKey)
    return selectedRoomTopology(roleKey, option, rows, rowIndex)
end

local function hasSelectableSiblingStructure(roleKey, option)
    return roleKey == "Combat"
        or roleKey == "Fountain"
        or roleKey == "Story"
        or roleKey == "Midshop"
        or (roleKey == "Miniboss" and option ~= nil)
end

local function siblingRoomTopology(option)
    if option == nil or option.key == nil or option.key == "" then
        return nil
    end
    return {
        structure = option.structure,
        roomKey = roomTopology.roomKey(option),
        rewardStore = option.rewardStore,
        rewardClass = option.rewardClass,
        eligibleRewardTypes = option.eligibleRewardTypes,
        offerCount = option.offerCount,
    }
end

local function selectedRewardStoreForRow(data, instance, rows, rowIndex)
    local roleKey = data.resolveRole(instance, rows, rowIndex)
    if roleKey == "Combat" or roleKey == "Fountain" then
        return rewardStoreForMajorMinorChoice(rows, rowIndex)
    elseif roleKey == "Miniboss" then
        local _, option = data.resolveOption(instance, rows, rowIndex, roleKey)
        return option and "RunProgress" or nil
    end
    return nil
end

function topology.create(data)
    local topologyRulesStatus
    local shared = roomTopologyAdapter.create(data, {
        namespace = "fixed",
        slots = slots,
        indexedAliases = true,
        topologyForInstance = function(instance)
            return instance.biome.roomTopology
        end,
        hasSelectableSiblingStructure = function(_, _, _, roleKey, _, option)
            return hasSelectableSiblingStructure(roleKey, option)
        end,
        extraRuleStatus = function(instance, rows, rowIndex, siblingIndex, sibling)
            return topologyRulesStatus(instance, rows, rowIndex, siblingIndex, sibling)
        end,
    })

    local function siblingRewardStoreForRow(instance, rows, rowIndex, siblingIndex)
        local _, sibling = data.resolveSiblingStructure(instance, rows, rowIndex, siblingIndex)
        return sibling and sibling.rewardStore or nil
    end

    local function matchingSiblingRewardStoreStatus(instance, rows, rowIndex, siblingIndex, sibling)
        local candidateStore = sibling and sibling.rewardStore or nil
        if candidateStore == nil then
            return validStatus()
        end

        local selectedStore = selectedRewardStoreForRow(data, instance, rows, rowIndex)
        if selectedStore ~= nil and selectedStore ~= candidateStore then
            return invalidStatus(
                "fixed_sibling_reward_store_mismatch",
                "Sibling reward store must match selected reward store"
            )
        end

        for otherSiblingIndex = 1, data.activeSiblingStructureCount(instance, rows, rowIndex) do
            if otherSiblingIndex ~= siblingIndex then
                local otherStore = siblingRewardStoreForRow(instance, rows, rowIndex, otherSiblingIndex)
                if otherStore ~= nil and otherStore ~= candidateStore then
                    return invalidStatus(
                        "fixed_sibling_reward_store_mismatch",
                        "Sibling reward stores must match"
                    )
                end
            end
        end
        return validStatus()
    end

    local function topologyRuleStatus(instance, rows, rowIndex, siblingIndex, sibling, rule)
        if rule.key == "matchingSiblingRewardStore" then
            return matchingSiblingRewardStoreStatus(instance, rows, rowIndex, siblingIndex, sibling)
        end
        return validStatus()
    end

    topologyRulesStatus = function(instance, rows, rowIndex, siblingIndex, sibling)
        local policy = instance.siblingStructurePolicy
        for _, rule in ipairs(policy and policy.rules or EMPTY_VALUES) do
            local status = topologyRuleStatus(instance, rows, rowIndex, siblingIndex, sibling, rule)
            if not status.valid then
                return status
            end
        end
        return validStatus()
    end

    local function siblingTopologies(instance, rows, rowIndex)
        local siblings = {}
        local count = data.activeSiblingStructureCount(instance, rows, rowIndex)
        for siblingIndex = 1, count do
            local _, sibling = data.resolveSiblingStructure(instance, rows, rowIndex, siblingIndex)
            if shared.siblingAvailabilityStatus(instance, rows, rowIndex, siblingIndex, sibling).valid ~= true then
                return nil
            end

            local siblingTopology = siblingRoomTopology(sibling)
            if siblingTopology == nil then
                return nil
            end
            siblings[#siblings + 1] = siblingTopology
        end
        if siblings[1] == nil then
            return nil
        end
        return siblings
    end

    local api = {}

    function api.prepareSiblingStructurePolicy(instance)
        return shared.prepareSiblingStructurePolicy(instance)
    end

    function api.prepareSiblingStructureCount(instance)
        return shared.prepareSiblingStructureCount(instance)
    end

    function api.maxSiblingStructureCount(instance)
        return shared.maxSiblingStructureCount(instance)
    end

    function api.siblingStructureAlias(instance, siblingIndex)
        return shared.siblingStructureAlias(instance, siblingIndex)
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

    function api.activeSiblingStructureCount(instance, rows, rowIndex)
        return shared.activeSiblingStructureCount(instance, rows, rowIndex)
    end

    function api.shouldDrawSiblingStructure(instance, rows, rowIndex, siblingIndex)
        return shared.shouldDrawSiblingStructure(instance, rows, rowIndex, siblingIndex)
    end

    function api.resolveSiblingStructure(instance, rows, rowIndex, siblingIndex)
        return shared.resolveSiblingStructure(instance, rows, rowIndex, siblingIndex)
    end

    function api.siblingStructureValueStatesForRow(instance, rows, rowIndex, siblingIndex)
        return shared.siblingStructureValueStatesForRow(instance, rows, rowIndex, siblingIndex)
    end

    function api.validateRoomTopology(instance, rows, rowIndex)
        local roleKey = data.resolveRole(instance, rows, rowIndex)
        local _, option = data.resolveOption(instance, rows, rowIndex, roleKey)
        if not hasSelectableSiblingStructure(roleKey, option) then
            return nil
        end

        local siblingInvalid = shared.validateSiblingStructures(instance, rows, rowIndex, {
            requiredCode = "fixed_sibling_structure_required",
            requiredMessage = "Topology needs sibling door structure",
            unavailableCode = "fixed_sibling_structure_unavailable",
            unavailableMessage = function(sibling, siblingKey)
                return "Sibling " .. tostring(sibling.label or siblingKey) .. " is not valid at this depth"
            end,
        })
        if siblingInvalid ~= nil then
            return siblingInvalid
        end

        local forcedStatus = roomTopology.forcedGroupsStatus(
            instance.siblingStructurePolicy,
            shared.siblingPolicyContext(instance, rows, rowIndex)
        )
        if not forcedStatus.valid then
            return forcedStatus
        end
        return nil
    end

    function api.roomTopology(instance, rows, rowIndex)
        if instance.siblingStructurePolicy == nil
            or data.isFixedIdentityRow(instance, rowIndex)
            or not data.siblingStructureStatus(instance, rows, rowIndex).valid
        then
            return nil
        end

        local selected = selectedRoomTopologyForRow(data, instance, rows, rowIndex)
        local siblings = siblingTopologies(instance, rows, rowIndex)
        if selected == nil or siblings == nil then
            return nil
        end

        return {
            kind = "fixedLinearSiblingChoice",
            selected = selected,
            sibling = siblings[1],
            siblings = siblings,
        }
    end

    return api
end

return topology
