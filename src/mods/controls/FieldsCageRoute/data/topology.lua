local deps = ...
local common = deps.common
local roomTopology = deps.roomTopology
local topologyControls = deps.topologyControls
local slots = deps.slots

local topology = {}

local invalidStatus = common.invalidStatus

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

local function hasSelectableSiblingStructure(roleKey)
    return roleKey == "Combat" or roleKey == "Miniboss" or roleKey == "Bridge"
end

function topology.create(data)
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

    local function isFirstFieldsPick(instance, _rows, rowIndex)
        local slot = slots.slotForRow(instance, rowIndex)
        return slot ~= nil and slot.routeOrdinal == 1
    end

    local function implicitFirstPickSiblingStructure(instance, rows, rowIndex)
        local roleKey = data.resolveRole(instance, rows, rowIndex)
        if roleKey ~= "Combat" or not isFirstFieldsPick(instance, rows, rowIndex) then
            return nil
        end

        local selectedCount = selectedCombatCageRewardCount(instance, rows, rowIndex)
        if selectedCount == nil then
            return nil
        end
        return {
            key = "CombatCage" .. tostring(selectedCount),
            structure = "CombatCage" .. tostring(selectedCount),
            rewardStore = "RunProgress",
            offerCount = selectedCount,
        }
    end

    local function hasImplicitFirstPickSiblingStructure(instance, rows, rowIndex)
        return data.resolveRole(instance, rows, rowIndex) == "Combat"
            and isFirstFieldsPick(instance, rows, rowIndex)
    end

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
        shouldDrawSiblingStructure = function(shared, instance, rows, rowIndex)
            if hasImplicitFirstPickSiblingStructure(instance, rows, rowIndex) then
                return false
            end
            return shared.shouldDrawSiblingStructure(instance, rows, rowIndex, 1)
        end,
        implicitSiblingStructure = function(_, instance, rows, rowIndex)
            return implicitFirstPickSiblingStructure(instance, rows, rowIndex)
        end,
        shouldValidateRow = function(instance, rows, rowIndex)
            return not data.isFixedIdentityRow(instance, rowIndex)
                and hasSelectableSiblingStructure(data.resolveRole(instance, rows, rowIndex))
        end,
        validateSelected = function(instance, rows, rowIndex)
            local roleKey = data.resolveRole(instance, rows, rowIndex)
            local _, cageCount = data.resolveCageCount(instance, rows, rowIndex, roleKey)
            if roleKey == "Combat" and (cageCount == nil or (cageCount.cageRewardCount or 0) <= 0) then
                return invalidStatus("fields_cage_count_required", "Fields topology needs picked cage reward count")
            end
            return nil
        end,
        skipSiblingValidation = function(instance, rows, rowIndex)
            return hasImplicitFirstPickSiblingStructure(instance, rows, rowIndex)
        end,
        requiredCode = "fields_sibling_structure_required",
        requiredMessage = "Fields topology needs sibling door structure",
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
