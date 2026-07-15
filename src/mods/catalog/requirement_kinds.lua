local s = import("mods/catalog/schema.lua")

local function validateReferencedKeys(values, lookup, path, description)
    for index, key in ipairs(values or {}) do
        if lookup[key] == nil then
            s.fail(path .. "[" .. tostring(index) .. "]", "unknown " .. description .. " '" .. key .. "'")
        end
    end
end

local function validateCountQuery(node, path, key)
    s.stringList(node[key], path .. "." .. key, true)
    s.comparison(node.comparison, path .. ".comparison")
    s.integer(node.value, path .. ".value", 0)
end

local function validateComparisonQuery(node, path, extra)
    s.comparison(node.comparison, path .. ".comparison")
    s.number(node.value, path .. ".value")
    if extra ~= nil then
        extra()
    end
end

local function roomReferences(node, references, path)
    validateReferencedKeys(node.roomKeys, references.rooms, path .. ".roomKeys", "room")
end

local function rangeMatches(value, range)
    if range.exact ~= nil and value ~= range.exact then return false end
    if range.min ~= nil and value < range.min then return false end
    if range.minExclusive ~= nil and value <= range.minExclusive then return false end
    if range.max ~= nil and value > range.max then return false end
    if range.maxExclusive ~= nil and value >= range.maxExclusive then return false end
    return true
end

local ROOM_GENERATE_NEXT = { "room.generate_next" }
local REWARD_OFFER = { "reward.offer" }
local ROOM_OR_REWARD = { "room.generate_next", "reward.offer" }

return {
    All = {
        contactPhases = ROOM_OR_REWARD,
        capacity = "composite",
        childShape = "many",
        staticCombine = "all",
        fields = { "requirements" },
    },
    Any = {
        contactPhases = ROOM_OR_REWARD,
        capacity = "composite",
        childShape = "many",
        staticCombine = "any",
        fields = { "requirements" },
    },
    Not = {
        contactPhases = ROOM_OR_REWARD,
        capacity = "composite",
        childShape = "one",
        staticCombine = "not",
        fields = { "requirement" },
    },
    CounterRange = {
        contactPhases = { "room.prepare_encounters", "room.generate_next", "reward.offer" },
        capacity = "static",
        fields = { "axis", "range" },
        validatePayload = function(node, path)
            s.enum(node.axis, { "biomeDepthCache", "biomeEncounterDepth" }, path .. ".axis")
            s.range(node.range, path .. ".range")
        end,
        staticEvaluate = function(node, context, path)
            local value = context[node.axis]
            if value == nil then
                s.fail(path, "capacity context is missing axis '" .. node.axis .. "'")
            end
            return rangeMatches(value, node.range)
        end,
    },
    RoomEnteredCount = {
        contactPhases = ROOM_GENERATE_NEXT,
        capacity = "dynamic",
        fields = { "roomKeys", "comparison", "value" },
        validatePayload = function(node, path)
            validateCountQuery(node, path, "roomKeys")
        end,
        validateReferences = roomReferences,
    },
    RoomCreatedCount = {
        contactPhases = ROOM_GENERATE_NEXT,
        capacity = "dynamic",
        fields = { "roomKeys", "comparison", "value" },
        validatePayload = function(node, path)
            validateCountQuery(node, path, "roomKeys")
        end,
        validateReferences = roomReferences,
    },
    RequiredMinExits = {
        contactPhases = ROOM_OR_REWARD,
        capacity = "dynamic",
        fields = { "count", "exceptBiomeKeys" },
        validatePayload = function(node, path)
            s.integer(node.count, path .. ".count", 1)
            if node.exceptBiomeKeys ~= nil then
                s.stringList(node.exceptBiomeKeys, path .. ".exceptBiomeKeys")
            end
        end,
        validateReferences = function(node, references, path)
            validateReferencedKeys(node.exceptBiomeKeys, references.biomes, path .. ".exceptBiomeKeys", "biome")
        end,
    },
    RequiredOfferedPeer = {
        contactPhases = ROOM_GENERATE_NEXT,
        capacity = "dynamic",
        fields = { "roomSetKey" },
        validatePayload = function(node, path)
            s.string(node.roomSetKey, path .. ".roomSetKey")
        end,
        validateReferences = function(node, references, path)
            if references.biomes[node.roomSetKey] == nil then
                s.fail(path .. ".roomSetKey", "unknown biome room set '" .. node.roomSetKey .. "'")
            end
        end,
    },
    RequiredNotInStore = {
        contactPhases = REWARD_OFFER,
        capacity = "dynamic",
        fields = { "rewardType" },
        validatePayload = function(node, path)
            s.string(node.rewardType, path .. ".rewardType")
        end,
        validateReferences = function(node, references, path)
            if references.rewardTypes[node.rewardType] == nil then
                s.fail(path .. ".rewardType", "unknown reward primitive '" .. node.rewardType .. "'")
            end
        end,
    },
    LootTypeHistory = {
        contactPhases = REWARD_OFFER,
        capacity = "dynamic",
        fields = { "rewardTypes", "comparison", "value" },
        validatePayload = function(node, path)
            validateComparisonQuery(node, path, function()
                s.stringList(node.rewardTypes, path .. ".rewardTypes", true)
            end)
        end,
        validateReferences = function(node, references, path)
            validateReferencedKeys(node.rewardTypes, references.rewardTypes, path .. ".rewardTypes", "reward primitive")
        end,
    },
    ClearedBiomes = {
        contactPhases = REWARD_OFFER,
        capacity = "dynamic",
        fields = { "comparison", "value" },
        validatePayload = validateComparisonQuery,
    },
    EncounterDepth = {
        contactPhases = REWARD_OFFER,
        capacity = "dynamic",
        fields = { "comparison", "value" },
        validatePayload = validateComparisonQuery,
    },
    PriorDistinctLootSources = {
        contactPhases = ROOM_OR_REWARD,
        capacity = "dynamic",
        fields = { "sourceDomain", "comparison", "value" },
        validatePayload = function(node, path)
            validateComparisonQuery(node, path, function()
                s.enum(node.sourceDomain, { "OlympianGods" }, path .. ".sourceDomain")
            end)
        end,
    },
    RequiredMinRoomsSinceEvent = {
        contactPhases = REWARD_OFFER,
        capacity = "dynamic",
        fields = { "axis", "count", "event" },
        validatePayload = function(node, path)
            s.enum(node.axis, { "roomHistoryOrdinal" }, path .. ".axis")
            s.integer(node.count, path .. ".count", 1)
            s.table(node.event, path .. ".event")
            s.onlyKeys(node.event, { "kind", "rewardType" }, path .. ".event")
            s.enum(node.event.kind, { "reward.acquire" }, path .. ".event.kind")
            s.string(node.event.rewardType, path .. ".event.rewardType")
        end,
        validateReferences = function(node, references, path)
            if references.rewardTypes[node.event.rewardType] == nil then
                s.fail(
                    path .. ".event.rewardType",
                    "unknown reward primitive '" .. node.event.rewardType .. "'"
                )
            end
        end,
    },
    EnteredKindCount = {
        contactPhases = ROOM_GENERATE_NEXT,
        capacity = "dynamic",
        fields = { "roomKinds", "range" },
        validatePayload = function(node, path)
            s.stringList(node.roomKinds, path .. ".roomKinds", true)
            s.range(node.range, path .. ".range")
        end,
        validateReferences = function(node, references, path)
            validateReferencedKeys(node.roomKinds, references.roomKinds, path .. ".roomKinds", "room kind")
        end,
    },
    ClockworkCapacity = {
        contactPhases = ROOM_GENERATE_NEXT,
        capacity = "dynamic",
        fields = { "counter", "reserve" },
        validatePayload = function(node, path)
            s.enum(node.counter, { "nonGoalRewardsAcquired" }, path .. ".counter")
            s.integer(node.reserve, path .. ".reserve", 0)
        end,
    },
    ClockworkGoalsRemaining = {
        contactPhases = ROOM_GENERATE_NEXT,
        capacity = "dynamic",
        fields = { "comparison", "value" },
        validatePayload = validateComparisonQuery,
    },
    HubVisitsCompleted = {
        contactPhases = ROOM_GENERATE_NEXT,
        capacity = "dynamic",
        fields = { "comparison", "value" },
        validatePayload = validateComparisonQuery,
    },
    ClockworkNonGoalLimitReached = {
        contactPhases = ROOM_GENERATE_NEXT,
        capacity = "dynamic",
        fields = {},
        validatePayload = function() end,
    },
    CurrentRoomCreationExclusion = {
        contactPhases = ROOM_GENERATE_NEXT,
        capacity = "dynamic",
        fields = { "roomKeys" },
        validatePayload = function(node, path)
            s.stringList(node.roomKeys, path .. ".roomKeys", true)
        end,
        validateReferences = roomReferences,
    },
    RecentEncounterPhaseCount = {
        contactPhases = ROOM_GENERATE_NEXT,
        capacity = "dynamic",
        fields = { "phaseKey", "profileKey", "roomWindow", "comparison", "value" },
        validatePayload = function(node, path)
            validateComparisonQuery(node, path, function()
                s.string(node.profileKey, path .. ".profileKey")
                s.string(node.phaseKey, path .. ".phaseKey")
                s.integer(node.roomWindow, path .. ".roomWindow", 1)
            end)
        end,
        validateReferences = function(node, references, path)
            local profile = references.encounterProfiles[node.profileKey]
            if profile == nil then
                s.fail(path .. ".profileKey", "unknown encounter profile '" .. node.profileKey .. "'")
            end
            for _, phase in ipairs(profile.phases) do
                if phase.key == node.phaseKey then
                    return
                end
            end
            s.fail(
                path .. ".phaseKey",
                "unknown phase '" .. node.phaseKey .. "' in encounter profile '" .. node.profileKey .. "'"
            )
        end,
    },
    BiomeRoomCreatedAny = {
        contactPhases = ROOM_GENERATE_NEXT,
        capacity = "dynamic",
        fields = { "roomKeys" },
        validatePayload = function(node, path)
            s.stringList(node.roomKeys, path .. ".roomKeys", true)
        end,
        validateReferences = roomReferences,
    },
}
