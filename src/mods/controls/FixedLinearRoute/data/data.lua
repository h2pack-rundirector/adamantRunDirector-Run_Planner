local deps = ...
local common = deps.common
local timeline = deps.timeline
local rowEngine = deps.rowEngine
local slots = import("mods/controls/FixedLinearRoute/data/slots.lua", nil, {
    common = common,
})
local topologyFactory = import("mods/controls/FixedLinearRoute/data/topology.lua", nil, {
    common = common,
    roomTopologyAdapter = deps.roomTopologyAdapter,
    roomTopology = deps.roomTopology,
    slots = slots,
})

local validStatus = common.validStatus

local data
local topology
local REWARD_CLASS_VALUES = { "Major", "Minor" }
local REWARD_CLASS_LABELS = {
    Major = "Major",
    Minor = "Minor",
}

local adapter = {
    slotForRow = slots.slotForRow,
    isFixedIdentitySlot = slots.isFixedIdentitySlot,

    readRoleKey = function(instance, rows, rowIndex, slot, defaultReadRoleKey)
        if slots.isFixedRoleSlot(slot) then
            return slot.roleKey
        end
        return defaultReadRoleKey(instance, rows, rowIndex, slot)
    end,

    roleForRow = function(instance, rowIndex, roleKey, slot, defaultRoleForRow)
        if slots.isFixedRoleSlot(slot) then
            if roleKey == nil or roleKey == "" or roleKey == slot.roleKey then
                return slot.role
            end
            return nil
        end
        return defaultRoleForRow(instance, rowIndex, roleKey, slot)
    end,

    roleAvailabilityForSlot = function(_, _, _, roleKey, slot)
        if slots.isFixedRoleSlot(slot) then
            return roleKey == slot.roleKey
        end
        return nil
    end,

    fillRoleValuesForSlot = function(_, _, _, slot, values)
        if slots.isFixedRoleSlot(slot) then
            values[#values + 1] = slot.roleKey
            return true
        end
        return false
    end,

    skipOptionsForSlot = function(_, _, _, slot)
        return slots.isPrebossSlot(slot)
    end,

    validateSlot = function(_, _, _, _, _, slot)
        if slots.isPrebossSlot(slot) then
            return validStatus()
        end
        return nil
    end,

    optionUnavailableMessage = function(_, _, _, _, role)
        return tostring(role.label or role.key) .. " is not valid at this depth"
    end,
}

data = rowEngine.create(adapter)
topology = topologyFactory.create(data)

function data.prepare(instance)
    instance.biome = instance.biome or {}
    instance.biomeKey = instance.biome.key or instance.biomeKey or instance.name
    instance.label = instance.label or instance.biome.label or instance.biomeKey
    data.prepareRoles(instance)

    slots.buildRouteSlots(instance)
    timeline.applyRouteSlots(instance)
    data.buildRoleChoices(instance)
    data.prepareSlots(instance)
    topology.prepareSiblingStructurePolicy(instance)
    topology.prepareSiblingStructureCount(instance)
    return instance
end

function data.storage(instance)
    local roomRows = data.buildRoomRows()
    local rewardRows = data.buildRewardRows()
    if instance.siblingStructurePolicy ~= nil then
        for siblingIndex = 1, data.maxSiblingStructureCount(instance) do
            roomRows[#roomRows + 1] = {
                key = data.siblingStructureAlias(instance, siblingIndex),
                type = "string",
                default = "",
                maxLen = 32,
            }
            rewardRows[#rewardRows + 1] = {
                key = data.siblingRewardClassAlias(instance, siblingIndex),
                type = "string",
                default = "",
                maxLen = 16,
            }
        end
    end
    return {
        {
            key = "Rooms",
            type = "table",
            minRows = instance.routeRowCount,
            defaultRows = instance.routeRowCount,
            maxRows = instance.routeRowCount,
            row = roomRows,
        },
        {
            key = "Rewards",
            type = "table",
            minRows = instance.routeRowCount,
            defaultRows = instance.routeRowCount,
            maxRows = instance.routeRowCount,
            row = rewardRows,
        },
    }
end

function data.maxSiblingStructureCount(instance)
    return topology.maxSiblingStructureCount(instance)
end

function data.siblingStructureAlias(instance, siblingIndex)
    return topology.siblingStructureAlias(instance, siblingIndex)
end

function data.siblingStructureLabels(instance)
    return topology.siblingStructureLabels(instance)
end

function data.siblingStructureValues(instance)
    return topology.siblingStructureValues(instance)
end

function data.siblingStructureStatus(instance, rows, rowIndex)
    return topology.siblingStructureStatus(instance, rows, rowIndex)
end

function data.activeSiblingStructureCount(instance, rows, rowIndex)
    return topology.activeSiblingStructureCount(instance, rows, rowIndex)
end

function data.shouldDrawSiblingStructure(instance, rows, rowIndex, siblingIndex)
    return topology.shouldDrawSiblingStructure(instance, rows, rowIndex, siblingIndex)
end

function data.resolveSiblingStructure(instance, rows, rowIndex, siblingIndex)
    return topology.resolveSiblingStructure(instance, rows, rowIndex, siblingIndex)
end

function data.siblingStructureValueStatesForRow(instance, rows, rowIndex, siblingIndex)
    return topology.siblingStructureValueStatesForRow(instance, rows, rowIndex, siblingIndex)
end

function data.validateRoomTopology(instance, rows, rowIndex)
    return topology.validateRoomTopology(instance, rows, rowIndex)
end

function data.roomTopology(instance, rows, rowIndex)
    return topology.roomTopology(instance, rows, rowIndex)
end

function data.siblingRewardClassAlias(_, siblingIndex)
    siblingIndex = math.floor(tonumber(siblingIndex) or 1)
    if siblingIndex <= 1 then
        return "SiblingRewardClassKey"
    end
    return "Sibling" .. tostring(siblingIndex) .. "RewardClassKey"
end

function data.siblingRewardClassAddress(_, siblingIndex)
    siblingIndex = math.floor(tonumber(siblingIndex) or 1)
    return "sibling:" .. tostring(siblingIndex)
end

function data.siblingRewardClassValues()
    return REWARD_CLASS_VALUES
end

function data.siblingRewardClassLabels()
    return REWARD_CLASS_LABELS
end

function data.siblingNeedsRewardClass(sibling)
    return sibling ~= nil
        and (
            sibling.rewardBranch == "majorMinor"
            or sibling.requiresRewardClass == true
        )
end

function data.shouldDrawSiblingRewardClass(instance, rows, rowIndex, siblingIndex)
    if data.activeSiblingStructureCount(instance, rows, rowIndex) < (siblingIndex or 1) then
        return false
    end
    if not data.siblingStructureStatus(instance, rows, rowIndex).valid then
        return false
    end

    local _, sibling = data.resolveSiblingStructure(instance, rows, rowIndex, siblingIndex)
    return data.siblingNeedsRewardClass(sibling)
end

function data.resolveSiblingRewardClass(instance, rows, rowIndex, siblingIndex)
    local key = rows and rows:read(rowIndex, data.siblingRewardClassAlias(instance, siblingIndex)) or ""
    key = key or ""
    if key == "Major" then
        return key, "RunProgress"
    elseif key == "Minor" then
        return key, "MetaProgress"
    end
    return key, nil
end

return data
