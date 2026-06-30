local deps = ...
local roomTopology = deps.roomTopology
local roomTopologyAdapter = deps.roomTopologyAdapter
local slots = deps.slots

local topology = {}

local function selectedRoomTopology(roleKey, option)
    if roleKey == "GoalCombat" then
        return {
            structure = roleKey,
            roomKey = option and option.key or nil,
            isClockworkGoal = true,
            offerCount = 0,
        }
    elseif roleKey == "RewardCombat" then
        return {
            structure = roleKey,
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
    elseif roleKey == "Preboss" then
        return {
            structure = "Preboss",
            isPreboss = true,
            offerCount = 0,
        }
    end
    return nil
end

local function selectedRoomTopologyForRow(data, instance, rows, rowIndex)
    local roleKey = data.resolveRole(instance, rows, rowIndex)
    local _, option = data.resolveOption(instance, rows, rowIndex, roleKey)
    return selectedRoomTopology(roleKey, option)
end

local function hasSelectableSiblingStructure(roleKey, option)
    return roleKey == "GoalCombat"
        or roleKey == "RewardCombat"
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
        isClockworkGoal = option.isClockworkGoal,
        isPreboss = option.isPreboss,
        eligibleRewardTypes = option.eligibleRewardTypes,
        ineligibleRewardTypes = option.ineligibleRewardTypes,
        offerCount = option.offerCount,
    }
end

function topology.create(data)
    local shared = roomTopologyAdapter.create(data, {
        namespace = "clockwork",
        slots = slots,
        topologyForInstance = function(instance)
            return instance.biome.roomTopology
        end,
        hasSelectableSiblingStructure = function(_, _, _, roleKey, _, option)
            return hasSelectableSiblingStructure(roleKey, option)
        end,
    })

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

    function api.siblingTopologyStatus(instance, rows, rowIndex)
        return shared.siblingTopologyStatus(instance, rows, rowIndex)
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
            or not data.siblingTopologyStatus(instance, rows, rowIndex).valid
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
