local guard = import("mods/declarations/guard.lua")
local common = import("mods/declarations/common.lua")
local requirementsValidator = import("mods/declarations/validators/requirements.lua")

local rewardsValidator = {}

local function copyUniqueRewardTypes(entries)
    local seen = {}
    local options = {}
    for _, entry in ipairs(entries) do
        local rewardType = entry.rewardType
        if not seen[rewardType] then
            seen[rewardType] = true
            options[#options + 1] = rewardType
        end
    end
    return options
end

local function validatePrimitive(key, primitive, context)
    guard.expectString(key, context .. ".key")
    guard.expectTable(primitive, context)
    guard.expectString(primitive.label, context .. ".label")
    guard.expectOptionalString(primitive.acquiredLootType, context .. ".acquiredLootType")
end

function rewardsValidator.validateRewardEntry(entry, primitives, namedRequirements, context)
    guard.expectTable(entry, context)
    guard.expectString(entry.rewardType, context .. ".rewardType")
    if primitives[entry.rewardType] == nil then
        guard.fail(context .. ".rewardType", "unknown reward primitive '" .. entry.rewardType .. "'")
    end
    guard.expectOptionalBoolean(entry.allowDuplicates, context .. ".allowDuplicates")
    guard.expectOptionalString(entry.acquiredLootType, context .. ".acquiredLootType")
    if entry.requirements ~= nil then
        requirementsValidator.validateRequirement(entry.requirements, namedRequirements, context .. ".requirements")
    end
end

function rewardsValidator.validate(rewards, namedRequirements)
    guard.expectTable(rewards, "rewards")
    guard.expectTable(rewards.primitives, "rewards.primitives")
    guard.expectTable(rewards.bags, "rewards.bags")
    guard.expectTable(rewards.shops, "rewards.shops")

    for key, primitive in pairs(rewards.primitives) do
        validatePrimitive(key, primitive, "rewards.primitives." .. key)
    end

    local stores = {}
    for bagKey, bag in pairs(rewards.bags) do
        local context = "rewards.bags." .. bagKey
        guard.expectString(bagKey, context .. ".key")
        guard.expectTable(bag, context)
        guard.expectString(bag.key, context .. ".key")
        if bag.key ~= bagKey then
            guard.fail(context .. ".key", "bag key must match map key")
        end
        guard.expectString(bag.label, context .. ".label")
        guard.expectString(bag.refill, context .. ".refill")
        guard.expectNonEmptyArray(bag.entries, context .. ".entries")
        for index, entry in ipairs(bag.entries) do
            rewardsValidator.validateRewardEntry(entry, rewards.primitives, namedRequirements, context .. ".entries[" .. tostring(index) .. "]")
        end
        stores[bagKey] = {
            key = bagKey,
            label = bag.label,
            options = copyUniqueRewardTypes(bag.entries),
        }
    end

    for shopKey, shop in pairs(rewards.shops) do
        local context = "rewards.shops." .. shopKey
        guard.expectTable(shop, context)
        guard.expectString(shop.key, context .. ".key")
        if shop.key ~= shopKey then
            guard.fail(context .. ".key", "shop key must match map key")
        end
        guard.expectString(shop.label, context .. ".label")
        guard.expectNonEmptyArray(shop.slots, context .. ".slots")
        for slotIndex, slot in ipairs(shop.slots) do
            local slotContext = context .. ".slots[" .. tostring(slotIndex) .. "]"
            guard.expectTable(slot, slotContext)
            guard.expectString(slot.key, slotContext .. ".key")
            guard.expectNonEmptyArray(slot.options, slotContext .. ".options")
            for optionIndex, option in ipairs(slot.options) do
                rewardsValidator.validateRewardEntry(option, rewards.primitives, namedRequirements, slotContext .. ".options[" .. tostring(optionIndex) .. "]")
            end
        end
    end

    local normalized = common.shallowCopy(rewards)
    normalized.stores = stores
    return normalized
end

return rewardsValidator
