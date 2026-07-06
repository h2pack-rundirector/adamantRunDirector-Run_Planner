local guard = import("mods/declarations/guard.lua")

local loader = {}

local KNOWN_REQUIREMENT_KINDS = {
    All = true,
    Any = true,
    Not = true,
    BiomeDepthCache = true,
    BiomeEncounterDepth = true,
    ClearedBiomes = true,
    LootTypeHistory = true,
    RequiredNotInStore = true,
}

local KNOWN_PRESENTATION_POLICIES = {
    hide = true,
    invalid = true,
    warning = true,
    unsupported = true,
    block = true,
}

local KNOWN_COMPARISONS = {
    ["=="] = true,
    ["~="] = true,
    ["<"] = true,
    ["<="] = true,
    [">"] = true,
    [">="] = true,
}

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

local function packageOrderedMap(ordered, context)
    return {
        ordered = ordered,
        lookup = guard.indexByKey(ordered, context),
    }
end

local function shallowCopy(source)
    local copy = {}
    for key, value in pairs(source) do
        copy[key] = value
    end
    return copy
end

local function validatePresentation(requirement, context)
    if requirement.presentation ~= nil then
        guard.expectString(requirement.presentation, context .. ".presentation")
        if not KNOWN_PRESENTATION_POLICIES[requirement.presentation] then
            guard.fail(context .. ".presentation", "unknown presentation policy '" .. requirement.presentation .. "'")
        end
    end
    guard.expectOptionalString(requirement.code, context .. ".code")
    guard.expectOptionalString(requirement.message, context .. ".message")
end

local function validateCountSet(requirement, context)
    if requirement.countOf ~= nil then
        guard.expectNonEmptyArray(requirement.countOf, context .. ".countOf")
        for index, value in ipairs(requirement.countOf) do
            guard.expectString(value, context .. ".countOf[" .. tostring(index) .. "]")
        end
    end
end

local function validateComparison(requirement, context)
    if requirement.comparison ~= nil then
        guard.expectString(requirement.comparison, context .. ".comparison")
        if not KNOWN_COMPARISONS[requirement.comparison] then
            guard.fail(context .. ".comparison", "unknown comparison '" .. requirement.comparison .. "'")
        end
        guard.expectNumber(requirement.value, context .. ".value")
    end
end

local function validateRequirement(requirement, namedRequirements, context)
    guard.expectTable(requirement, context)

    if requirement.named ~= nil then
        guard.expectString(requirement.named, context .. ".named")
        if namedRequirements[requirement.named] == nil then
            guard.fail(context .. ".named", "unknown named requirement '" .. requirement.named .. "'")
        end
        return
    end

    local kind = guard.expectString(requirement.kind, context .. ".kind")
    if not KNOWN_REQUIREMENT_KINDS[kind] then
        guard.fail(context .. ".kind", "unknown requirement kind '" .. kind .. "'")
    end

    validatePresentation(requirement, context)

    if kind == "All" or kind == "Any" then
        guard.expectNonEmptyArray(requirement.requirements, context .. ".requirements")
        for index, child in ipairs(requirement.requirements) do
            validateRequirement(child, namedRequirements, context .. ".requirements[" .. tostring(index) .. "]")
        end
    elseif kind == "Not" then
        validateRequirement(requirement.requirement, namedRequirements, context .. ".requirement")
    else
        validateComparison(requirement, context)
        validateCountSet(requirement, context)

        if kind == "RequiredNotInStore" then
            guard.expectString(requirement.name, context .. ".name")
        end
    end
end

local function validateRequirementRegistry(requirements)
    guard.expectTable(requirements, "requirements")
    for key, requirement in pairs(requirements) do
        guard.expectString(key, "requirements key")
        validateRequirement(requirement, requirements, "requirements." .. key)
    end
end

local function validateRoute(route, context)
    guard.expectTable(route, context)
    guard.expectString(route.key, context .. ".key")
    guard.expectString(route.label, context .. ".label")
    guard.expectNonEmptyArray(route.biomeKeys, context .. ".biomeKeys")
    for index, biomeKey in ipairs(route.biomeKeys) do
        guard.expectString(biomeKey, context .. ".biomeKeys[" .. tostring(index) .. "]")
    end
end

local function validateRoutes(routes)
    guard.expectNonEmptyArray(routes, "routes")
    for index, route in ipairs(routes) do
        validateRoute(route, "routes[" .. tostring(index) .. "]")
    end
end

local function validateExits(room, context)
    guard.expectArray(room.exits, context .. ".exits")
    for index, exit in ipairs(room.exits) do
        local exitContext = context .. ".exits[" .. tostring(index) .. "]"
        guard.expectTable(exit, exitContext)
        if exit.tags ~= nil then
            guard.expectArray(exit.tags, exitContext .. ".tags")
            for tagIndex, tag in ipairs(exit.tags) do
                guard.expectString(tag, exitContext .. ".tags[" .. tostring(tagIndex) .. "]")
            end
        end
    end
end

local function validateRoom(room, namedRequirements, context)
    guard.expectTable(room, context)
    guard.expectString(room.key, context .. ".key")
    guard.expectString(room.label, context .. ".label")
    guard.expectString(room.kind, context .. ".kind")
    guard.expectString(room.roomTemplate, context .. ".roomTemplate")
    guard.expectNonEmptyArray(room.tags, context .. ".tags")
    guard.expectTable(room.caps, context .. ".caps")
    guard.expectOptionalString(room.encounterProfile, context .. ".encounterProfile")
    guard.expectOptionalString(room.offerProfile, context .. ".offerProfile")
    guard.expectOptionalBoolean(room.terminal, context .. ".terminal")
    guard.expectOptionalTable(room.counters, context .. ".counters")

    validateExits(room, context)

    if room.eligibility ~= nil then
        validateRequirement(room.eligibility, namedRequirements, context .. ".eligibility")
    end
    if room.force ~= nil then
        validateRequirement(room.force, namedRequirements, context .. ".force")
    end
end

local function validateBiome(biome, namedRequirements, context)
    guard.expectTable(biome, context)
    guard.expectString(biome.key, context .. ".key")
    guard.expectString(biome.label, context .. ".label")
    guard.expectString(biome.routeKey, context .. ".routeKey")
    guard.expectTable(biome.structure, context .. ".structure")
    guard.expectString(biome.structure.kind, context .. ".structure.kind")
    guard.expectString(biome.structure.startRoomKey, context .. ".structure.startRoomKey")
    guard.expectTable(biome.structure.terminal, context .. ".structure.terminal")
    guard.expectString(biome.structure.terminal.prebossRoomKey, context .. ".structure.terminal.prebossRoomKey")
    guard.expectNonEmptyArray(biome.rooms, context .. ".rooms")

    local roomsByKey = guard.indexByKey(biome.rooms, context .. ".rooms")
    if roomsByKey[biome.structure.startRoomKey] == nil then
        guard.fail(context .. ".structure.startRoomKey", "room '" .. biome.structure.startRoomKey .. "' is not declared")
    end
    if roomsByKey[biome.structure.terminal.prebossRoomKey] == nil then
        guard.fail(context .. ".structure.terminal.prebossRoomKey", "room '" .. biome.structure.terminal.prebossRoomKey .. "' is not declared")
    end

    for index, room in ipairs(biome.rooms) do
        validateRoom(room, namedRequirements, context .. ".rooms[" .. tostring(index) .. "]")
    end

    local normalized = shallowCopy(biome)
    normalized.rooms = {
        ordered = biome.rooms,
        lookup = roomsByKey,
    }
    return normalized
end

local function validatePrimitive(key, primitive, context)
    guard.expectString(key, context .. ".key")
    guard.expectTable(primitive, context)
    guard.expectString(primitive.label, context .. ".label")
    guard.expectOptionalString(primitive.acquiredLootType, context .. ".acquiredLootType")
end

local function validateRewardEntry(entry, primitives, namedRequirements, context)
    guard.expectTable(entry, context)
    guard.expectString(entry.rewardType, context .. ".rewardType")
    if primitives[entry.rewardType] == nil then
        guard.fail(context .. ".rewardType", "unknown reward primitive '" .. entry.rewardType .. "'")
    end
    guard.expectOptionalBoolean(entry.allowDuplicates, context .. ".allowDuplicates")
    guard.expectOptionalString(entry.acquiredLootType, context .. ".acquiredLootType")
    if entry.requirements ~= nil then
        validateRequirement(entry.requirements, namedRequirements, context .. ".requirements")
    end
end

local function validateRewards(rewards, namedRequirements)
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
            validateRewardEntry(entry, rewards.primitives, namedRequirements, context .. ".entries[" .. tostring(index) .. "]")
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
                validateRewardEntry(option, rewards.primitives, namedRequirements, slotContext .. ".options[" .. tostring(optionIndex) .. "]")
            end
        end
    end

    local normalized = shallowCopy(rewards)
    normalized.stores = stores
    return normalized
end

function loader.load(opts)
    opts = opts or {}

    local routes = opts.routes or import("mods/declarations/routes.lua")
    local requirements = opts.requirements or import("mods/declarations/requirements.lua")
    local rewards = opts.rewards or import("mods/declarations/rewards.lua")
    local biomes = opts.biomes or import("mods/declarations/biomes/init.lua")

    validateRequirementRegistry(requirements)
    validateRoutes(routes)
    local normalizedRewards = validateRewards(rewards, requirements)

    local normalizedBiomes = {}
    for index, biome in ipairs(biomes) do
        normalizedBiomes[index] = validateBiome(biome, requirements, "biomes[" .. tostring(index) .. "]")
    end

    return {
        routes = packageOrderedMap(routes, "routes"),
        biomes = packageOrderedMap(normalizedBiomes, "biomes"),
        rewards = normalizedRewards,
        requirements = requirements,
    }
end

return loader
