local deps = ...
local common = deps.common
local roomTopology = deps.roomTopology
local roomTopologyAdapter = deps.roomTopologyAdapter
local slots = deps.slots

local topology = {}

local validStatus = common.validStatus
local invalidStatus = common.invalidStatus

local EMPTY_VALUES = {}

local function goalRewardType(instance)
    local counters = instance.clockwork and instance.clockwork.routeCounters or nil
    local goal = counters and counters.clockworkGoal or nil
    return goal and goal.rewardType or nil
end

local function selectedRoomTopology(data, instance, rows, rowIndex, roleKey, option)
    if roleKey == "Combat" then
        if data.rowCountsGoalReward(instance, rows, rowIndex, instance.rolesByKey.Combat, option) then
            return {
                structure = "Combat",
                roomKey = option and option.key or nil,
                rewardType = goalRewardType(instance),
                offerCount = 0,
            }
        end
        return {
            structure = "Combat",
            roomKey = option and option.key or nil,
            rewardStore = "TartarusRewards",
            ineligibleRewardTypes = { "Boon" },
            offerCount = 1,
            rewardAddresses = { "row" },
        }
    elseif roleKey == "Story" then
        return {
            structure = "Story",
            roomKey = option and option.key or nil,
            offerCount = 0,
        }
    elseif roleKey == "Fountain" then
        return {
            structure = "Fountain",
            roomKey = option and option.key or nil,
            rewardStore = "TartarusRewards",
            ineligibleRewardTypes = { "Devotion" },
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
    end
    return nil
end

local function selectedRoomTopologyForRow(data, instance, rows, rowIndex)
    local roleKey = data.resolveRole(instance, rows, rowIndex)
    local _, option = data.resolveOption(instance, rows, rowIndex, roleKey)
    return selectedRoomTopology(data, instance, rows, rowIndex, roleKey, option)
end

local function hasSelectableSiblingStructure(roleKey, option)
    return roleKey == "Combat"
        or roleKey == "Story"
        or roleKey == "Fountain"
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
        rewardType = option.rewardType,
        eligibleRewardTypes = option.eligibleRewardTypes,
        ineligibleRewardTypes = option.ineligibleRewardTypes,
        offerCount = option.offerCount,
    }
end

local function selectedRewardStoreForRow(data, instance, rows, rowIndex)
    local roleKey = data.resolveRole(instance, rows, rowIndex)
    local _, option = data.resolveOption(instance, rows, rowIndex, roleKey)
    local selected = selectedRoomTopology(data, instance, rows, rowIndex, roleKey, option)
    return selected and selected.rewardStore or nil
end

local function isGoalDoor(instance, topologyNode)
    return topologyNode ~= nil and topologyNode.rewardType == goalRewardType(instance)
end

function topology.create(data)
    local topologyRulesStatus
    local shared = roomTopologyAdapter.create(data, {
        namespace = "clockwork",
        slots = slots,
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

    local function matchingSiblingRewardStoreStatus(instance, rows, rowIndex, sibling)
        local candidateStore = sibling and sibling.rewardStore or nil
        if candidateStore == nil then
            return validStatus()
        end

        local selectedStore = selectedRewardStoreForRow(data, instance, rows, rowIndex)
        if selectedStore ~= nil and selectedStore ~= candidateStore then
            return invalidStatus(
                "clockwork_sibling_reward_store_mismatch",
                "Sibling reward store must match selected reward store"
            )
        end
        return validStatus()
    end

    local function exactlyOneClockworkGoalDoorStatus(instance, rows, rowIndex, sibling)
        local selected = selectedRoomTopologyForRow(data, instance, rows, rowIndex)
        if isGoalDoor(instance, selected) ~= isGoalDoor(instance, sibling) then
            return validStatus()
        end
        return invalidStatus(
            "clockwork_sibling_goal_door_count",
            "Tartarus doors need exactly one Goal Room"
        )
    end

    local function singleDoorClockworkGoalStatus(instance, rows, rowIndex)
        if data.activeSiblingStructureCount(instance, rows, rowIndex) > 0 then
            return validStatus()
        end

        local selected = selectedRoomTopologyForRow(data, instance, rows, rowIndex)
        if isGoalDoor(instance, selected) then
            return validStatus()
        end
        return invalidStatus(
            "clockwork_single_door_goal_required",
            "Tartarus single doors need Goal Room"
        )
    end

    local function topologyRuleStatus(instance, rows, rowIndex, sibling, rule)
        if rule.key == "exactlyOneClockworkGoalDoor" then
            return exactlyOneClockworkGoalDoorStatus(instance, rows, rowIndex, sibling)
        end
        if rule.key == "matchingSiblingRewardStore" then
            return matchingSiblingRewardStoreStatus(instance, rows, rowIndex, sibling)
        end
        return validStatus()
    end

    topologyRulesStatus = function(instance, rows, rowIndex, _, sibling)
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
            requiredCode = "clockwork_sibling_structure_required",
            requiredMessage = "Tartarus topology needs sibling door structure",
            unavailableCode = "clockwork_sibling_structure_unavailable",
            unavailableMessage = function(sibling, siblingKey)
                return "Sibling " .. tostring(sibling.label or siblingKey) .. " is not valid at this step"
            end,
        })
        if siblingInvalid ~= nil then
            return siblingInvalid
        end

        local singleDoorStatus = singleDoorClockworkGoalStatus(instance, rows, rowIndex)
        if not singleDoorStatus.valid then
            return singleDoorStatus
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

        local count = data.activeSiblingStructureCount(instance, rows, rowIndex)
        if count < 1 then
            return nil
        end

        local _, sibling = data.resolveSiblingStructure(instance, rows, rowIndex)
        if not shared.siblingAvailabilityStatus(instance, rows, rowIndex, nil, sibling).valid then
            return nil
        end

        local selected = selectedRoomTopologyForRow(data, instance, rows, rowIndex)
        local siblingTopology = siblingRoomTopology(sibling)
        if selected == nil or siblingTopology == nil then
            return nil
        end

        return {
            kind = "clockworkSiblingChoice",
            selected = selected,
            sibling = siblingTopology,
        }
    end

    return api
end

return topology
