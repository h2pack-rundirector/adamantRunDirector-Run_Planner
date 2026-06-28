local deps = ...
local routePlan = deps.routePlan
local runState = deps.runState
local game = deps.game or {}

local featureRouting = {}
local EMPTY_LIST = {}
local DISABLE_NATURAL_CHAOS = true
local FEATURE_ORDER = {
    "wellShop",
    "surfaceShop",
}

local FEATURE_FLAGS = {
    wellShop = {
        force = "ForceWellShop",
        chance = "WellShopChanceSuccess",
    },
    surfaceShop = {
        force = "ForceSurfaceShop",
        chance = "SurfaceShopChanceSuccess",
    },
}

local function fieldValue(value)
    if value == nil or value == "" then
        return "-"
    end
    return tostring(value)
end

local function debugLog(message)
    local printer = game.print or _G.print
    if type(printer) == "function" then
        printer("[RunPlanner] feature_routing: " .. tostring(message))
    end
end

local function planFromRuntime(runtime)
    local state = routePlan.get(runtime)
    if state == nil or state.active ~= true or state.valid ~= true then
        return nil
    end
    local plan = state.executionPlan
    if plan == nil or plan.layers == nil or plan.layers.features ~= true then
        return nil
    end
    return plan
end

local function roomName(room)
    return runState.roomName(room)
end

local function roomSetName(room)
    return runState.roomSetName(room)
end

local function isEphyraSideRoom(room)
    if roomSetName(room) == "N_SubRooms" then
        return true
    end
    local key = roomName(room)
    return type(key) == "string" and string.sub(key, 1, 5) == "N_Sub"
end

local function sideRoomTargetMatches(target, currentRun, room)
    local currentRoomKey = roomName(room)
    if target == nil
        or target.sideIndex == nil
        or target.roomKey ~= currentRoomKey
    then
        return false
    end

    local previousRoom = runState.previousRoom(currentRun)
    local previousRoomKey = roomName(previousRoom)
    if target.parentRoomKey ~= nil and previousRoomKey ~= nil then
        return target.parentRoomKey == previousRoomKey
    end
    return true
end

local function currentPlannedRow(plan, currentRun, room)
    local biomeKey = runState.currentBiomeKey(currentRun, nil, room)
    local biome = plan and plan.biomes and plan.biomes[biomeKey] or nil
    local roomKey = roomName(room)
    local biomeDepthCache = runState.biomeDepthCache(currentRun)
    local bucket = biome and biome.plannedByBiomeDepthCache and biome.plannedByBiomeDepthCache[biomeDepthCache] or nil
    local roomBucket = bucket and bucket.byRoomKey and bucket.byRoomKey[roomKey] or nil
    if roomBucket ~= nil then
        return roomBucket.primary, biomeKey
    end
    if bucket ~= nil and bucket.primary ~= nil and bucket.primary.roomKey == roomKey then
        return bucket.primary, biomeKey
    end

    roomBucket = biome and biome.plannedByRoomKey and biome.plannedByRoomKey[roomKey] or nil
    return roomBucket and roomBucket.primary or nil, biomeKey
end

local function targetMatchesPlannedRow(target, plannedRow, biomeKey)
    return target ~= nil
        and plannedRow ~= nil
        and target.biomeKey == biomeKey
        and tostring(target.rowIndex or target.targetRowIndex or "") == tostring(plannedRow.rowIndex or "")
        and (target.roomKey == nil or target.roomKey == plannedRow.roomKey)
end

local function plannedFeatureForRoom(plan, featureKey, currentRun, room, plannedRow, biomeKey)
    local featurePlan = plan.features and plan.features.byFeatureKey and plan.features.byFeatureKey[featureKey] or nil
    for _, row in ipairs(featurePlan and featurePlan.rows or EMPTY_LIST) do
        if isEphyraSideRoom(room) then
            if sideRoomTargetMatches(row.target, currentRun, room) then
                return row
            end
        elseif targetMatchesPlannedRow(row.target, plannedRow, biomeKey) then
            return row
        end
    end
    return nil
end

local function hasPlannedFeature(plan, featureKey)
    local featurePlan = plan.features and plan.features.byFeatureKey and plan.features.byFeatureKey[featureKey] or nil
    return featurePlan ~= nil and featurePlan.rows ~= nil and featurePlan.rows[1] ~= nil
end

local function planIncludesBiome(plan, biomeKey)
    return plan ~= nil
        and biomeKey ~= nil
        and plan.biomes ~= nil
        and plan.biomes[biomeKey] ~= nil
end

local function scopeBiomeKey(currentRun, room, biomeKey)
    if isEphyraSideRoom(room) then
        local previousRoom = runState.previousRoom(currentRun)
        return runState.roomSetName(previousRoom) or biomeKey
    end
    return biomeKey
end

local function setFeature(room, featureKey, planned)
    local flags = FEATURE_FLAGS[featureKey]
    if flags == nil then
        return
    end

    if planned ~= nil then
        room[flags.force] = true
        debugLog("force " .. tostring(featureKey)
            .. " room=" .. fieldValue(roomName(room))
            .. " target=" .. fieldValue(planned.targetKey))
    else
        room[flags.chance] = false
    end
end

local function suppressNaturalChaos(currentRun)
    if not DISABLE_NATURAL_CHAOS then
        return
    end
    local room = currentRun and currentRun.CurrentRoom or nil
    if room ~= nil then
        room.SecretChanceSuccess = false
    end
end

function featureRouting.prepareRoomFeatures(runtime, currentRun)
    local room = currentRun and currentRun.CurrentRoom or nil
    local plan = planFromRuntime(runtime)
    if plan == nil or room == nil then
        return nil
    end

    local plannedRow, biomeKey = currentPlannedRow(plan, currentRun, room)
    if not planIncludesBiome(plan, scopeBiomeKey(currentRun, room, biomeKey)) then
        return nil
    end
    local applied = {}
    for _, featureKey in ipairs(FEATURE_ORDER) do
        if hasPlannedFeature(plan, featureKey) then
            local planned = plannedFeatureForRoom(plan, featureKey, currentRun, room, plannedRow, biomeKey)
            setFeature(room, featureKey, planned)
            applied[featureKey] = planned ~= nil
        end
    end

    return applied
end

function featureRouting.handleSecretSpawns(runtime, base, currentRun)
    suppressNaturalChaos(currentRun)
    featureRouting.prepareRoomFeatures(runtime, currentRun)
    return base(currentRun)
end

function featureRouting.registerHooks(moduleRef)
    moduleRef.hooks.wrap("HandleSecretSpawns", function(host, runtime, base, currentRun)
        if host ~= nil and host.isEnabled ~= nil and not host.isEnabled() then
            return base(currentRun)
        end

        return featureRouting.handleSecretSpawns(runtime, base, currentRun)
    end)
end

return featureRouting
