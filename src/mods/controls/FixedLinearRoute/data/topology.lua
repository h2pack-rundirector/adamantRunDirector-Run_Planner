local deps = ...
local roomTopology = deps.roomTopology
local roomTopologyAdapter = deps.roomTopologyAdapter
local slots = deps.slots

local topology = {}

local function rewardStoreForRewardClass(rewardClass)
    if rewardClass == "Major" then
        return "RunProgress", "Major"
    elseif rewardClass == "Minor" then
        return "MetaProgress", "Minor"
    end
    return nil, nil
end

local function rewardStoreForMajorMinorChoice(rows, rowIndex)
    local rewardClass = rows and rows:read(rowIndex, "Reward1Key") or nil
    return rewardStoreForRewardClass(rewardClass)
end

local function selectedRoomTopology(roleKey, option, rows, rowIndex)
    if roleKey == "Combat" or roleKey == "Fountain" then
        local rewardStore, rewardClass = rewardStoreForMajorMinorChoice(rows, rowIndex)
        return {
            structure = roleKey,
            roomKey = option and option.key or nil,
            rewardStore = rewardStore,
            rewardClass = rewardClass,
            rewardBranch = "majorMinor",
            rewardBranchAddress = "row",
            rewardBranchControlAlias = "Reward1Key",
            rewardBranchLabel = "Rewards",
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

local function siblingRewardStoreForChoice(data, instance, rows, rowIndex, siblingIndex, option)
    if data.siblingNeedsRewardClass(option) then
        local rewardClass = data.resolveSiblingRewardClass(instance, rows, rowIndex, siblingIndex)
        return rewardStoreForRewardClass(rewardClass)
    end
    return option and option.rewardStore or nil, option and option.rewardClass or nil
end

local function siblingRewardBranchLabel(activeSiblingCount, siblingIndex)
    if (activeSiblingCount or 0) > 1 then
        return "Other Door " .. tostring(siblingIndex) .. " Reward"
    end
    return "Other Door Reward"
end

local function siblingRoomTopology(data, instance, rows, rowIndex, siblingIndex, activeSiblingCount, option)
    if option == nil or option.key == nil or option.key == "" then
        return nil
    end
    local rewardStore, rewardClass = siblingRewardStoreForChoice(data, instance, rows, rowIndex, siblingIndex, option)
    return {
        structure = option.structure,
        roomKey = roomTopology.roomKey(option),
        rewardStore = rewardStore,
        rewardClass = rewardClass,
        rewardBranch = option.rewardBranch,
        rewardBranchAddress = option.rewardBranch ~= nil and data.siblingRewardClassAddress(instance, siblingIndex) or nil,
        rewardBranchControlAlias = option.rewardBranch ~= nil
            and data.siblingRewardClassAlias(instance, siblingIndex)
            or nil,
        rewardBranchLabel = option.rewardBranch ~= nil
            and siblingRewardBranchLabel(activeSiblingCount, siblingIndex)
            or nil,
        eligibleRewardTypes = option.eligibleRewardTypes,
        offerCount = option.offerCount,
    }
end

function topology.create(data)
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
    })

    local function siblingTopologies(instance, rows, rowIndex)
        local siblings = {}
        local count = data.activeSiblingStructureCount(instance, rows, rowIndex)
        for siblingIndex = 1, count do
            local _, sibling = data.resolveSiblingStructure(instance, rows, rowIndex, siblingIndex)
            if shared.siblingAvailabilityStatus(instance, rows, rowIndex, siblingIndex, sibling).valid ~= true then
                return nil
            end

            local siblingTopology = siblingRoomTopology(data, instance, rows, rowIndex, siblingIndex, count, sibling)
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
