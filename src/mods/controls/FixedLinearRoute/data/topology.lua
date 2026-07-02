local deps = ...
local roomTopology = deps.roomTopology
local topologyControls = deps.topologyControls
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
            sameExitRewardCount = 1,
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
            sameExitRewardCount = 1,
            rewardAddresses = { "row" },
        }
    elseif roleKey == "Story" then
        return {
            structure = "Story",
            roomKey = option and option.key or nil,
            sameExitRewardCount = 0,
        }
    elseif roleKey == "Midshop" then
        return {
            structure = "Midshop",
            roomKey = option and option.key or nil,
            sameExitRewardCount = 0,
        }
    end
    return nil
end

local function selectedRoomTopologyForRow(data, instance, rows, rowIndex)
    local roleKey = data.resolveRole(instance, rows, rowIndex)
    local _, option = data.resolveOption(instance, rows, rowIndex, roleKey)
    return selectedRoomTopology(roleKey, option, rows, rowIndex)
end

local function deterministicTopologyNode(node, selected)
    if node == nil then
        return nil
    end

    local snapshot = {
        structure = node.structure,
        roomKey = node.roomKey,
        rewardStore = node.rewardStore,
        rewardClass = node.rewardClass,
        rewardBranch = node.rewardBranch,
        rewardBranchAddress = node.rewardBranchAddress,
        rewardBranchControlAlias = node.rewardBranchControlAlias,
        rewardBranchLabel = node.rewardBranchLabel,
        eligibleRewardTypes = node.eligibleRewardTypes,
        ineligibleRewardTypes = node.ineligibleRewardTypes,
        sameExitRewardCount = node.sameExitRewardCount,
    }
    if selected then
        snapshot.rewardAddresses = node.rewardAddresses or { "row" }
    end
    return snapshot
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
        if not data.siblingStructureStatus(instance, rows, rowIndex).valid then
            return rewardStoreForMajorMinorChoice(rows, rowIndex)
        end
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
    local hasVisibleRewardBranch = option.rewardBranch ~= nil
        and data.siblingStructureStatus(instance, rows, rowIndex).valid == true
    return {
        structure = option.structure,
        roomKey = roomTopology.roomKey(option),
        rewardStore = rewardStore,
        rewardClass = rewardClass,
        rewardBranch = hasVisibleRewardBranch and option.rewardBranch or nil,
        rewardBranchAddress = hasVisibleRewardBranch and data.siblingRewardClassAddress(instance, siblingIndex) or nil,
        rewardBranchControlAlias = hasVisibleRewardBranch
            and data.siblingRewardClassAlias(instance, siblingIndex)
            or nil,
        rewardBranchLabel = hasVisibleRewardBranch
            and siblingRewardBranchLabel(activeSiblingCount, siblingIndex)
            or nil,
        eligibleRewardTypes = option.eligibleRewardTypes,
        sameExitRewardCount = option.sameExitRewardCount,
    }
end

function topology.create(data)
    local function implicitSiblingStructure(instance, rows, rowIndex)
        if data.siblingTopologyStatus(instance, rows, rowIndex).valid ~= true
            or data.siblingStructureStatus(instance, rows, rowIndex).valid == true
        then
            return nil
        end

        local roleKey = data.resolveRole(instance, rows, rowIndex)
        if roleKey ~= "Combat" then
            return nil
        end

        local policy = instance.siblingStructurePolicy
        return policy and policy.optionsByKey and policy.optionsByKey.Combat or nil
    end

    local function deterministicRoomTopology(instance, rows, rowIndex)
        local byRoomKey = instance.biome.roomTopology and instance.biome.roomTopology.deterministicPairsByRoomKey
        if byRoomKey == nil then
            return nil
        end

        local roleKey = data.resolveRole(instance, rows, rowIndex)
        local _, option = data.resolveOption(instance, rows, rowIndex, roleKey)
        local roomKey = option and option.key or nil
        local pair = roomKey and byRoomKey[roomKey] or nil
        if pair == nil then
            return nil
        end

        local selected = deterministicTopologyNode(pair.nodesByRoomKey and pair.nodesByRoomKey[roomKey], true)
        local siblings = {}
        for _, node in ipairs(pair.nodes or {}) do
            if node.roomKey ~= roomKey then
                siblings[#siblings + 1] = deterministicTopologyNode(node)
            end
        end
        if selected == nil or siblings[1] == nil then
            return nil
        end

        return {
            kind = "fixedLinearSiblingChoice",
            selected = selected,
            sibling = siblings[1],
            siblings = siblings,
        }
    end

    return topologyControls.create(data, {
        namespace = "fixed",
        slots = slots,
        indexedAliases = true,
        topologyKind = "fixedLinearSiblingChoice",
        isFixedIdentityRow = data.isFixedIdentityRow,
        deterministicTopology = deterministicRoomTopology,
        implicitSiblingStructure = function(_, instance, rows, rowIndex)
            return implicitSiblingStructure(instance, rows, rowIndex)
        end,
        hasSelectableSiblingStructure = function(_, _, _, roleKey, _, option)
            return hasSelectableSiblingStructure(roleKey, option)
        end,
        shouldValidateRow = function(instance, rows, rowIndex)
            local roleKey = data.resolveRole(instance, rows, rowIndex)
            local _, option = data.resolveOption(instance, rows, rowIndex, roleKey)
            return hasSelectableSiblingStructure(roleKey, option)
        end,
        requiredCode = "fixed_sibling_structure_required",
        requiredMessage = "Choose Other Door",
        unavailableCode = "fixed_sibling_structure_unavailable",
        unavailableMessage = function(sibling, siblingKey)
            return "Other Door " .. tostring(sibling.label or siblingKey) .. " is not valid at this depth"
        end,
        selectedTopology = function(instance, rows, rowIndex)
            return selectedRoomTopologyForRow(data, instance, rows, rowIndex)
        end,
        siblingTopology = function(instance, rows, rowIndex, siblingIndex, activeSiblingCount, option)
            return siblingRoomTopology(data, instance, rows, rowIndex, siblingIndex, activeSiblingCount, option)
        end,
    })
end

return topology
