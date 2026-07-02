local deps = ...
local roomTopology = deps.roomTopology
local topologyControls = deps.topologyControls
local slots = deps.slots

local topology = {}

local function selectedRoomTopology(roleKey, option)
    if roleKey == "GoalCombat" then
        return {
            structure = roleKey,
            roomKey = option and option.key or nil,
            isClockworkGoal = true,
            sameExitRewardCount = 0,
        }
    elseif roleKey == "RewardCombat" then
        return {
            structure = roleKey,
            roomKey = option and option.key or nil,
            rewardStore = "TartarusRewards",
            ineligibleRewardTypes = { "Boon" },
            sameExitRewardCount = 1,
            rewardAddresses = { "row" },
        }
    elseif roleKey == "Story" then
        return {
            structure = "Story",
            roomKey = option and option.key or nil,
            sameExitRewardCount = 0,
        }
    elseif roleKey == "Fountain" then
        return {
            structure = "Fountain",
            roomKey = option and option.key or nil,
            rewardStore = "TartarusRewards",
            ineligibleRewardTypes = { "Devotion" },
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
    elseif roleKey == "Preboss" then
        return {
            structure = "Preboss",
            isPreboss = true,
            sameExitRewardCount = 0,
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
        isClockworkGoal = option.isClockworkGoal,
        isPreboss = option.isPreboss,
        eligibleRewardTypes = option.eligibleRewardTypes,
        ineligibleRewardTypes = option.ineligibleRewardTypes,
        sameExitRewardCount = option.sameExitRewardCount,
    }
end

local function hasSelectableSiblingStructure(roleKey, option)
    return roleKey == "GoalCombat"
        or roleKey == "RewardCombat"
        or roleKey == "Story"
        or roleKey == "Fountain"
        or (roleKey == "Miniboss" and option ~= nil)
end

function topology.create(data)
    return topologyControls.create(data, {
        namespace = "clockwork",
        slots = slots,
        topologyKind = "clockworkSiblingChoice",
        isFixedIdentityRow = data.isFixedIdentityRow,
        hasSelectableSiblingStructure = function(_, _, _, roleKey, _, option)
            return hasSelectableSiblingStructure(roleKey, option)
        end,
        shouldValidateRow = function(instance, rows, rowIndex)
            local roleKey = data.resolveRole(instance, rows, rowIndex)
            local _, option = data.resolveOption(instance, rows, rowIndex, roleKey)
            return hasSelectableSiblingStructure(roleKey, option)
        end,
        requiredCode = "clockwork_sibling_structure_required",
        requiredMessage = "Choose Other Door",
        unavailableCode = "clockwork_sibling_structure_unavailable",
        unavailableMessage = function(sibling, siblingKey)
            return "Other Door " .. tostring(sibling.label or siblingKey) .. " is not valid at this step"
        end,
        selectedTopology = function(instance, rows, rowIndex)
            local roleKey = data.resolveRole(instance, rows, rowIndex)
            local _, option = data.resolveOption(instance, rows, rowIndex, roleKey)
            return selectedRoomTopology(roleKey, option)
        end,
        siblingTopology = function(_, _, _, _, _, option)
            return siblingRoomTopology(option)
        end,
    })
end

return topology
