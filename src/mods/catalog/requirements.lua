local s = import("mods/catalog/schema.lua")

local requirements = {}

local function allowed(node, path, extra)
    local keys = { "kind", "phase", "code" }
    for _, key in ipairs(extra) do
        keys[#keys + 1] = key
    end
    s.onlyKeys(node, keys, path)
end

local function validateChildren(node, registry, path)
    s.list(node.requirements, path .. ".requirements", true)
    for index, child in ipairs(node.requirements) do
        requirements.validateNode(child, registry, path .. ".requirements[" .. tostring(index) .. "]")
        if child.phase ~= node.phase then
            s.fail(path .. ".requirements[" .. tostring(index) .. "].phase", "must match parent phase")
        end
    end
end

local function validateCountQuery(node, path, key)
    allowed(node, path, { key, "comparison", "value" })
    s.stringList(node[key], path .. "." .. key, true)
    s.comparison(node.comparison, path .. ".comparison")
    s.integer(node.value, path .. ".value", 0)
end

local function validateComparisonQuery(node, path, extra)
    local fields = { "comparison", "value" }
    for _, field in ipairs(extra or {}) do
        fields[#fields + 1] = field
    end
    allowed(node, path, fields)
    s.comparison(node.comparison, path .. ".comparison")
    s.number(node.value, path .. ".value")
end

function requirements.validateNode(node, registry, path)
    s.table(node, path)
    if node.named ~= nil then
        s.onlyKeys(node, { "named", "phase" }, path)
        s.string(node.named, path .. ".named")
        s.string(node.phase, path .. ".phase")
        local target = registry.named[node.named]
        if target == nil then
            s.fail(path .. ".named", "unknown named requirement '" .. node.named .. "'")
        end
        if target.phase ~= node.phase then
            s.fail(path .. ".phase", "must match named requirement phase '" .. target.phase .. "'")
        end
        return
    end

    s.string(node.kind, path .. ".kind")
    local contract = registry.modeledKinds[node.kind]
    if contract == nil then
        s.fail(path .. ".kind", "unknown modeled requirement kind '" .. node.kind .. "'")
    end
    s.string(node.phase, path .. ".phase")
    if not s.contains(contract.phases, node.phase) then
        s.fail(path .. ".phase", "kind '" .. node.kind .. "' has no evaluator at phase '" .. node.phase .. "'")
    end
    if node.kind == "All" or node.kind == "Any" or node.kind == "Not" then
        if node.code ~= nil then
            s.string(node.code, path .. ".code")
        end
    else
        s.string(node.code, path .. ".code")
    end

    if node.kind == "All" or node.kind == "Any" then
        allowed(node, path, { "requirements" })
        validateChildren(node, registry, path)
    elseif node.kind == "Not" then
        allowed(node, path, { "requirement" })
        requirements.validateNode(node.requirement, registry, path .. ".requirement")
        if node.requirement.phase ~= node.phase then
            s.fail(path .. ".requirement.phase", "must match parent phase")
        end
    elseif node.kind == "CounterRange" then
        allowed(node, path, { "axis", "range" })
        s.enum(node.axis, { "biomeDepthCache", "biomeEncounterDepth" }, path .. ".axis")
        s.range(node.range, path .. ".range")
    elseif node.kind == "RoomEnteredCount" or node.kind == "RoomCreatedCount" then
        validateCountQuery(node, path, "roomKeys")
    elseif node.kind == "RequiredMinExits" then
        allowed(node, path, { "count", "exceptBiomeKeys" })
        s.integer(node.count, path .. ".count", 1)
        if node.exceptBiomeKeys ~= nil then
            s.stringList(node.exceptBiomeKeys, path .. ".exceptBiomeKeys")
        end
    elseif node.kind == "RequiredOfferedPeer" then
        allowed(node, path, { "roomSetKey" })
        s.string(node.roomSetKey, path .. ".roomSetKey")
    elseif node.kind == "RequiredNotInStore" then
        allowed(node, path, { "rewardType" })
        s.string(node.rewardType, path .. ".rewardType")
    elseif node.kind == "LootTypeHistory" then
        validateComparisonQuery(node, path, { "rewardTypes" })
        s.stringList(node.rewardTypes, path .. ".rewardTypes", true)
    elseif node.kind == "ClearedBiomes" or node.kind == "EncounterDepth"
        or node.kind == "ClockworkGoalsRemaining" or node.kind == "HubVisitsCompleted"
    then
        validateComparisonQuery(node, path)
    elseif node.kind == "PriorDistinctLootSources" then
        validateComparisonQuery(node, path, { "sourceDomain" })
        s.enum(node.sourceDomain, { "OlympianGods" }, path .. ".sourceDomain")
    elseif node.kind == "RequiredMinRoomsSinceEvent" then
        allowed(node, path, { "axis", "count", "event" })
        s.enum(node.axis, { "roomHistoryOrdinal" }, path .. ".axis")
        s.integer(node.count, path .. ".count", 1)
        s.table(node.event, path .. ".event")
        s.onlyKeys(node.event, { "kind", "rewardType" }, path .. ".event")
        s.enum(node.event.kind, { "reward.acquire" }, path .. ".event.kind")
        s.string(node.event.rewardType, path .. ".event.rewardType")
    elseif node.kind == "EnteredKindCount" then
        allowed(node, path, { "roomKinds", "range" })
        s.stringList(node.roomKinds, path .. ".roomKinds", true)
        s.range(node.range, path .. ".range")
    elseif node.kind == "ClockworkCapacity" then
        allowed(node, path, { "counter", "reserve" })
        s.enum(node.counter, { "nonGoalRewardsAcquired" }, path .. ".counter")
        s.integer(node.reserve, path .. ".reserve", 0)
    elseif node.kind == "ClockworkNonGoalLimitReached" then
        allowed(node, path, {})
    elseif node.kind == "CurrentRoomCreationExclusion" then
        allowed(node, path, { "roomKeys" })
        s.stringList(node.roomKeys, path .. ".roomKeys", true)
    elseif node.kind == "RecentEncounterPhaseCount" then
        validateComparisonQuery(node, path, { "phaseKey", "profileKey", "roomWindow" })
        s.string(node.profileKey, path .. ".profileKey")
        s.string(node.phaseKey, path .. ".phaseKey")
        s.integer(node.roomWindow, path .. ".roomWindow", 1)
    elseif node.kind == "BiomeRoomCreatedAny" then
        allowed(node, path, { "roomKeys" })
        s.stringList(node.roomKeys, path .. ".roomKeys", true)
    else
        s.fail(path .. ".kind", "payload validator is not registered")
    end
end

function requirements.validateRegistry(raw)
    local registry = s.copy(raw)
    s.table(registry, "requirements")
    s.onlyKeys(registry, { "modeledKinds", "named" }, "requirements")
    s.table(registry.modeledKinds, "requirements.modeledKinds")
    s.table(registry.named, "requirements.named")
    for key, contract in pairs(registry.modeledKinds) do
        s.string(key, "requirements.modeledKinds.<key>")
        local path = "requirements.modeledKinds." .. key
        s.table(contract, path)
        s.onlyKeys(contract, { "phases", "capacity" }, path)
        s.stringList(contract.phases, path .. ".phases", true)
        s.enum(contract.capacity, { "composite", "static", "dynamic" }, path .. ".capacity")
    end
    for key, node in pairs(registry.named) do
        s.string(key, "requirements.named.<key>")
        requirements.validateNode(node, registry, "requirements.named." .. key)
    end
    return registry
end

local function validateReferencedKeys(values, lookup, path, description)
    for index, key in ipairs(values or {}) do
        if lookup[key] == nil then
            s.fail(path .. "[" .. tostring(index) .. "]", "unknown " .. description .. " '" .. key .. "'")
        end
    end
end

function requirements.validateReferences(node, registry, references, path, resolvingNamed)
    if node == nil then
        return
    end
    resolvingNamed = resolvingNamed or {}
    if node.named ~= nil then
        if resolvingNamed[node.named] then
            s.fail(path .. ".named", "cyclic named requirement reference '" .. node.named .. "'")
        end
        resolvingNamed[node.named] = true
        requirements.validateReferences(
            registry.named[node.named],
            registry,
            references,
            "requirements.named." .. node.named,
            resolvingNamed
        )
        resolvingNamed[node.named] = nil
        return
    end

    local kind = node.kind
    if kind == "RoomEnteredCount" or kind == "RoomCreatedCount"
        or kind == "CurrentRoomCreationExclusion" or kind == "BiomeRoomCreatedAny"
    then
        validateReferencedKeys(node.roomKeys, references.rooms, path .. ".roomKeys", "room")
    elseif kind == "RequiredMinExits" then
        validateReferencedKeys(node.exceptBiomeKeys, references.biomes, path .. ".exceptBiomeKeys", "biome")
    elseif kind == "RequiredOfferedPeer" then
        if references.biomes[node.roomSetKey] == nil then
            s.fail(path .. ".roomSetKey", "unknown biome room set '" .. node.roomSetKey .. "'")
        end
    elseif kind == "RequiredNotInStore" then
        if references.rewardTypes[node.rewardType] == nil then
            s.fail(path .. ".rewardType", "unknown reward primitive '" .. node.rewardType .. "'")
        end
    elseif kind == "LootTypeHistory" then
        validateReferencedKeys(
            node.rewardTypes,
            references.rewardTypes,
            path .. ".rewardTypes",
            "reward primitive"
        )
    elseif kind == "RequiredMinRoomsSinceEvent" then
        if references.rewardTypes[node.event.rewardType] == nil then
            s.fail(
                path .. ".event.rewardType",
                "unknown reward primitive '" .. node.event.rewardType .. "'"
            )
        end
    elseif kind == "EnteredKindCount" then
        validateReferencedKeys(node.roomKinds, references.roomKinds, path .. ".roomKinds", "room kind")
    elseif kind == "RecentEncounterPhaseCount" then
        local profile = references.encounterProfiles[node.profileKey]
        if profile == nil then
            s.fail(path .. ".profileKey", "unknown encounter profile '" .. node.profileKey .. "'")
        end
        local found = false
        for _, phase in ipairs(profile.phases) do
            if phase.key == node.phaseKey then
                found = true
                break
            end
        end
        if not found then
            s.fail(
                path .. ".phaseKey",
                "unknown phase '" .. node.phaseKey .. "' in encounter profile '" .. node.profileKey .. "'"
            )
        end
    end

    for index, child in ipairs(node.requirements or {}) do
        requirements.validateReferences(
            child,
            registry,
            references,
            path .. ".requirements[" .. tostring(index) .. "]",
            resolvingNamed
        )
    end
    if node.requirement ~= nil then
        requirements.validateReferences(
            node.requirement,
            registry,
            references,
            path .. ".requirement",
            resolvingNamed
        )
    end
end

local function rangeMatches(value, range)
    if range.exact ~= nil and value ~= range.exact then return false end
    if range.min ~= nil and value < range.min then return false end
    if range.minExclusive ~= nil and value <= range.minExclusive then return false end
    if range.max ~= nil and value > range.max then return false end
    if range.maxExclusive ~= nil and value >= range.maxExclusive then return false end
    return true
end

function requirements.staticCompatibility(node, registry, context, excludedKinds, path)
    if node == nil then
        return true
    end
    if node.named ~= nil then
        return requirements.staticCompatibility(
            registry.named[node.named],
            registry,
            context,
            excludedKinds,
            path .. ".named(" .. node.named .. ")"
        )
    end
    local contract = registry.modeledKinds[node.kind]
    if contract.capacity == "dynamic" then
        excludedKinds[node.kind] = true
        return nil
    end
    if node.kind == "CounterRange" then
        local value = context[node.axis]
        if value == nil then
            s.fail(path, "capacity context is missing axis '" .. node.axis .. "'")
        end
        return rangeMatches(value, node.range)
    end
    if node.kind == "All" then
        local unknown = false
        for index, child in ipairs(node.requirements) do
            local result = requirements.staticCompatibility(
                child,
                registry,
                context,
                excludedKinds,
                path .. ".requirements[" .. tostring(index) .. "]"
            )
            if result == false then return false end
            if result == nil then unknown = true end
        end
        return unknown and nil or true
    end
    if node.kind == "Any" then
        local unknown = false
        for index, child in ipairs(node.requirements) do
            local result = requirements.staticCompatibility(
                child,
                registry,
                context,
                excludedKinds,
                path .. ".requirements[" .. tostring(index) .. "]"
            )
            if result == true then return true end
            if result == nil then unknown = true end
        end
        return unknown and nil or false
    end
    if node.kind == "Not" then
        local result = requirements.staticCompatibility(
            node.requirement,
            registry,
            context,
            excludedKinds,
            path .. ".requirement"
        )
        return result == nil and nil or not result
    end
    s.fail(path .. ".kind", "static capacity evaluator is not registered")
end

return requirements
