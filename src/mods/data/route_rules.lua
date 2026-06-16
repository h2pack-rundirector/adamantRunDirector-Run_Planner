local routeRules = {}

local GOD_LOOT_NAMES = {
    "AphroditeUpgrade",
    "ApolloUpgrade",
    "AresUpgrade",
    "DemeterUpgrade",
    "HephaestusUpgrade",
    "HestiaUpgrade",
    "HeraUpgrade",
    "PoseidonUpgrade",
    "ZeusUpgrade",
}

local DEVOTION_REQUIREMENT_LOOT_NAMES = {
    "AphroditeUpgrade",
    "ApolloUpgrade",
    "DemeterUpgrade",
    "HephaestusUpgrade",
    "HestiaUpgrade",
    "HeraUpgrade",
    "PoseidonUpgrade",
    "ZeusUpgrade",
}

local ROLE_RULES = {
    Story = {
        maxSelectionsPerBiome = 1,
    },
    Fountain = {
        maxSelectionsPerBiome = 1,
    },
    Midshop = {
        maxSelectionsPerBiome = 1,
    },
    Trial = {
        maxSelectionsPerBiome = 1,
    },
    Miniboss = {
        maxSelectionsPerBiome = 1,
    },
}

local function copyList(source)
    local copy = {}
    for index, value in ipairs(source) do
        copy[index] = value
    end
    return copy
end

local function copyTable(source)
    if source == nil then
        return nil
    end

    local copy = {}
    for key, value in pairs(source) do
        copy[key] = value
    end
    return copy
end

function routeRules.role(key, overrides)
    local rules = copyTable(ROLE_RULES[key])
    if rules == nil then
        return nil
    end

    for overrideKey, overrideValue in pairs(overrides or {}) do
        rules[overrideKey] = overrideValue
    end
    return rules
end

function routeRules.boonSourcePick()
    return {
        kind = "boonSource",
        allowedLootNames = copyList(GOD_LOOT_NAMES),
    }
end

function routeRules.previousRoomExitCount(minCount)
    return {
        kind = "previousRoomExitCount",
        minCount = minCount,
    }
end

function routeRules.priorDistinctGodLoot(minDistinct)
    return {
        kind = "priorDistinctGodLoot",
        minDistinct = minDistinct,
        countedLootNames = copyList(DEVOTION_REQUIREMENT_LOOT_NAMES),
    }
end

function routeRules.midshopRequirements()
    return {
        routeRules.previousRoomExitCount(2),
    }
end

function routeRules.devotionPick()
    return {
        kind = "devotionPair",
        source = "priorDistinctGodLoot",
        minDistinct = 2,
        allowedLootNames = copyList(GOD_LOOT_NAMES),
    }
end

function routeRules.devotionRequirements()
    return {
        routeRules.priorDistinctGodLoot(2),
        routeRules.previousRoomExitCount(2),
    }
end

return routeRules
