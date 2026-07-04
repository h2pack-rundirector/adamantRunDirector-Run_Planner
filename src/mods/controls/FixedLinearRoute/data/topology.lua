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

local function hasSelectableOtherDoor(roleKey, option)
    return roleKey == "Combat"
        or roleKey == "Fountain"
        or roleKey == "Story"
        or roleKey == "Midshop"
        or (roleKey == "Miniboss" and option ~= nil)
end

local function otherDoorRewardStoreForChoice(data, instance, rows, rowIndex, otherDoorIndex, option)
    if data.siblingNeedsRewardClass(option) then
        if not data.otherDoorStatus(instance, rows, rowIndex).valid then
            return rewardStoreForMajorMinorChoice(rows, rowIndex)
        end
        local rewardClass = data.resolveSiblingRewardClass(instance, rows, rowIndex, otherDoorIndex)
        return rewardStoreForRewardClass(rewardClass)
    end
    return option and option.rewardStore or nil, option and option.rewardClass or nil
end

local function otherDoorRewardBranchLabel(activeOtherDoorCount, otherDoorIndex)
    if (activeOtherDoorCount or 0) > 1 then
        return "Other Door " .. tostring(otherDoorIndex) .. " Reward"
    end
    return "Other Door Reward"
end

local function otherDoorRoomTopology(data, instance, rows, rowIndex, otherDoorIndex, activeOtherDoorCount, option)
    if option == nil or option.key == nil or option.key == "" then
        return nil
    end
    local rewardStore, rewardClass = otherDoorRewardStoreForChoice(data, instance, rows, rowIndex, otherDoorIndex, option)
    local hasVisibleRewardBranch = option.rewardBranch ~= nil
        and data.otherDoorStatus(instance, rows, rowIndex).valid == true
    return {
        structure = option.structure,
        roomKey = roomTopology.roomKey(option),
        rewardStore = rewardStore,
        rewardClass = rewardClass,
        rewardBranch = hasVisibleRewardBranch and option.rewardBranch or nil,
        rewardBranchAddress = hasVisibleRewardBranch and data.siblingRewardClassAddress(instance, otherDoorIndex) or nil,
        rewardBranchControlAlias = hasVisibleRewardBranch
            and data.siblingRewardClassAlias(instance, otherDoorIndex)
            or nil,
        rewardBranchLabel = hasVisibleRewardBranch
            and otherDoorRewardBranchLabel(activeOtherDoorCount, otherDoorIndex)
            or nil,
        eligibleRewardTypes = option.eligibleRewardTypes,
        sameExitRewardCount = option.sameExitRewardCount,
    }
end

function topology.create(data)
    local function implicitOtherDoor(instance, rows, rowIndex)
        if data.otherDoorTopologyStatus(instance, rows, rowIndex).valid ~= true
            or data.otherDoorStatus(instance, rows, rowIndex).valid == true
        then
            return nil
        end

        local roleKey = data.resolveRole(instance, rows, rowIndex)
        if roleKey ~= "Combat" then
            return nil
        end

        local policy = instance.otherDoorPolicy
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
        local otherDoors = {}
        for _, node in ipairs(pair.nodes or {}) do
            if node.roomKey ~= roomKey then
                otherDoors[#otherDoors + 1] = deterministicTopologyNode(node)
            end
        end
        if selected == nil or otherDoors[1] == nil then
            return nil
        end

        return {
            kind = "fixedLinearSiblingChoice",
            selected = selected,
            otherDoors = otherDoors,
        }
    end

    return topologyControls.create(data, {
        namespace = "fixed",
        slots = slots,
        indexedAliases = true,
        topologyKind = "fixedLinearSiblingChoice",
        isFixedIdentityRow = data.isFixedIdentityRow,
        deterministicTopology = deterministicRoomTopology,
        implicitOtherDoor = function(_, instance, rows, rowIndex)
            return implicitOtherDoor(instance, rows, rowIndex)
        end,
        hasSelectableOtherDoor = function(_, _, _, roleKey, _, option)
            return hasSelectableOtherDoor(roleKey, option)
        end,
        shouldValidateRow = function(instance, rows, rowIndex)
            local roleKey = data.resolveRole(instance, rows, rowIndex)
            local _, option = data.resolveOption(instance, rows, rowIndex, roleKey)
            return hasSelectableOtherDoor(roleKey, option)
        end,
        requiredCode = "fixed_sibling_structure_required",
        requiredMessage = "Choose Other Door",
        unavailableCode = "fixed_sibling_structure_unavailable",
        unavailableMessage = function(otherDoor, otherDoorKey)
            return "Other Door " .. tostring(otherDoor.label or otherDoorKey) .. " is not valid at this depth"
        end,
        selectedTopology = function(instance, rows, rowIndex)
            return selectedRoomTopologyForRow(data, instance, rows, rowIndex)
        end,
        otherDoorTopology = function(instance, rows, rowIndex, otherDoorIndex, activeOtherDoorCount, option)
            return otherDoorRoomTopology(data, instance, rows, rowIndex, otherDoorIndex, activeOtherDoorCount, option)
        end,
    })
end

return topology
