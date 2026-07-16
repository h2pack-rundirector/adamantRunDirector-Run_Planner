local deps = ...
local primitiveChoice = deps.primitiveChoice

local shop = {}

local function append(target, values)
    for _, value in ipairs(values) do
        target[#target + 1] = value
    end
end

local function slotDescriptor(descriptor, slotKey, context)
    local slot = descriptor.slots.lookup[slotKey]
    if slot == nil then
        error(context .. ": unknown shop slot '" .. tostring(slotKey) .. "'", 0)
    end
    return slot
end

function shop.prepare(profile, fieldPrefix)
    local descriptor = {
        profile = profile,
        slots = { ordered = {}, lookup = {} },
    }
    for _, profileSlot in ipairs(profile.slots.ordered) do
        local slot = {
            key = profileSlot.key,
            purchasedField = fieldPrefix .. profileSlot.key .. "Purchased",
            reward = primitiveChoice.prepare(
                profileSlot.optionSet,
                fieldPrefix .. profileSlot.key
            ),
        }
        descriptor.slots.ordered[#descriptor.slots.ordered + 1] = slot
        descriptor.slots.lookup[slot.key] = slot
    end
    return descriptor
end

function shop.storage(descriptor)
    local storage = {}
    for _, slot in ipairs(descriptor.slots.ordered) do
        append(storage, primitiveChoice.storage(slot.reward))
        storage[#storage + 1] = {
            key = slot.purchasedField,
            type = "bool",
            default = false,
        }
    end
    return storage
end

function shop.read(fields, descriptor, context)
    local value = {
        profileKey = descriptor.profile.key,
        slots = {},
    }
    for _, slot in ipairs(descriptor.slots.ordered) do
        local purchased = fields[slot.purchasedField]:read()
        if type(purchased) ~= "boolean" then
            error(context .. ": persisted purchased state for slot '" .. slot.key
                .. "' must be a boolean", 0)
        end
        value.slots[slot.key] = {
            reward = primitiveChoice.read(
                fields,
                slot.reward,
                context .. " slot '" .. slot.key .. "'"
            ),
            purchased = purchased,
        }
    end
    return value
end

function shop.writeReward(fields, descriptor, slotKey, value, context)
    local slot = slotDescriptor(descriptor, slotKey, context)
    primitiveChoice.write(
        fields,
        slot.reward,
        value,
        context .. " slot '" .. slot.key .. "'"
    )
end

function shop.writePurchased(fields, descriptor, slotKey, value, context)
    local slot = slotDescriptor(descriptor, slotKey, context)
    if type(value) ~= "boolean" then
        error(context .. " slot '" .. slot.key .. "': purchased must be a boolean", 0)
    end
    fields[slot.purchasedField]:write(value)
end

function shop.isComplete(descriptor, value)
    if type(value) ~= "table"
        or value.profileKey ~= descriptor.profile.key
        or type(value.slots) ~= "table"
    then
        return false
    end
    for _, slot in ipairs(descriptor.slots.ordered) do
        local slotValue = value.slots[slot.key]
        if type(slotValue) ~= "table"
            or type(slotValue.purchased) ~= "boolean"
            or not primitiveChoice.isComplete(slot.reward, slotValue.reward)
        then
            return false
        end
    end
    return true
end

return shop
