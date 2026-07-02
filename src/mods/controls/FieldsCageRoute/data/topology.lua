local deps = ...
local common = deps.common
local roomTopology = deps.roomTopology
local topologyControls = deps.topologyControls
local slots = deps.slots

local topology = {}

local invalidStatus = common.invalidStatus
local WARNING_STATE = 3

local function selectedControlInvalid(code, message, controlAlias)
    local invalid = invalidStatus(code, message)
    invalid.tabKey = "rooms"
    invalid.controlTargets = {
        {
            tabKey = "rooms",
            controlAlias = controlAlias,
            state = WARNING_STATE,
            mode = "selected",
        },
    }
    return invalid
end

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
            sameExitRewardCount = count,
            rewardAddresses = rewardAddresses(count),
        }
    elseif roleKey == "Miniboss" then
        return {
            structure = "Miniboss",
            roomKey = option and option.key or nil,
            rewardStore = "RunProgress",
            eligibleRewardTypes = { "Boon" },
            sameExitRewardCount = 1,
            rewardAddresses = { "row" },
        }
    elseif roleKey == "Bridge" then
        return {
            structure = "Bridge",
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
        eligibleRewardTypes = option.eligibleRewardTypes,
        sameExitRewardCount = option.sameExitRewardCount,
    }
end

local function hasSelectableSiblingStructure(roleKey)
    return roleKey == "Combat" or roleKey == "Miniboss" or roleKey == "Bridge"
end

function topology.create(data)
    return topologyControls.create(data, {
        namespace = "fields",
        slots = slots,
        topologyKind = "fieldsChoice",
        isFixedIdentityRow = data.isFixedIdentityRow,
        topologyForInstance = function(instance)
            return instance.biome.fields
                and instance.biome.fields.roomTopology
                or nil
        end,
        hasSelectableSiblingStructure = function(_, _, _, roleKey)
            return hasSelectableSiblingStructure(roleKey)
        end,
        shouldValidateRow = function(instance, rows, rowIndex)
            return not data.isFixedIdentityRow(instance, rowIndex)
                and hasSelectableSiblingStructure(data.resolveRole(instance, rows, rowIndex))
        end,
        validateSelected = function(instance, rows, rowIndex)
            local roleKey = data.resolveRole(instance, rows, rowIndex)
            local _, cageCount = data.resolveCageCount(instance, rows, rowIndex, roleKey)
            if roleKey == "Combat" and (cageCount == nil or (cageCount.cageRewardCount or 0) <= 0) then
                return selectedControlInvalid(
                    "fields_cage_count_required",
                    "Choose Picked Door reward count",
                    "VariantKey"
                )
            end
            return nil
        end,
        requiredCode = "fields_sibling_structure_required",
        requiredMessage = "Choose Other Door",
        unavailableCode = "fields_sibling_structure_unavailable",
        unavailableMessage = function(sibling, siblingKey)
            return "Other Door " .. tostring(sibling.label or siblingKey) .. " is not valid at this pick"
        end,
        selectedTopology = function(instance, rows, rowIndex)
            local roleKey = data.resolveRole(instance, rows, rowIndex)
            local _, cageCount = data.resolveCageCount(instance, rows, rowIndex, roleKey)
            local _, option = data.resolveOption(instance, rows, rowIndex, roleKey)
            return selectedRoomTopology(roleKey, option, cageCount)
        end,
        siblingTopology = function(_, _, _, _, _, option)
            return siblingRoomTopology(option)
        end,
    })
end

return topology
