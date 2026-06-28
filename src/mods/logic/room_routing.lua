local deps = ...
local routePlan = deps.routePlan
local runState = deps.runState
local game = deps.game or {}

local roomRouting = {}
local startingBiome

local FIXED_DEPTH_ROOM_BIOMES = {
    F = true,
    G = true,
    H = true,
    I = true,
    O = true,
    P = true,
    Q = true,
}

local FIXED_DEPTH_ROOM_ADAPTERS = {
    clockworkGoal = true,
    ClockworkGoalRoute = true,
    fieldsCageRoute = true,
    fixedLinear = true,
    multiEncounterFixed = true,
    scriptedFixedLinear = true,
    FieldsCageRoute = true,
    FixedLinearRoute = true,
    MultiEncounterFixedRoute = true,
}

local HUB_PYLON_ADAPTERS = {
    hubPylon = true,
    HubPylonRoute = true,
}

local function sortedKeys(source)
    local keys = {}
    for key in pairs(source or {}) do
        keys[#keys + 1] = key
    end
    table.sort(keys, function(left, right)
        return tostring(left) < tostring(right)
    end)
    return keys
end

local function joinList(source)
    local values = {}
    for index, value in ipairs(source or {}) do
        values[index] = tostring(value)
    end
    return table.concat(values, ",")
end

local function fieldValue(value)
    if value == nil or value == "" then
        return "-"
    end
    return tostring(value)
end

local function shallowCopy(source)
    local copy = {}
    for key, value in pairs(source or {}) do
        copy[key] = value
    end
    return copy
end

local function debugLog(message)
    local printer = game.print or _G.print
    local text = "[RunPlanner] room_routing: " .. tostring(message)
    if type(printer) == "function" then
        printer(text)
    end
end

local function rewardItemSummary(item)
    local kind = item.kind or "vanilla"
    local rewards = joinList(item.rewards)
    if rewards ~= "" then
        return kind .. ":" .. rewards
    end

    local loot = joinList(item.loot)
    if loot ~= "" then
        return kind .. ":loot=" .. loot
    end

    local picks = {}
    for index, pick in ipairs(item.picks or {}) do
        picks[index] = tostring(pick.alias or pick.key or index) .. "=" .. tostring(pick.value)
    end
    if picks[1] ~= nil then
        return kind .. ":picks=" .. table.concat(picks, ",")
    end

    return kind
end

local function rewardSummary(rewardItems)
    if rewardItems == nil or rewardItems[1] == nil then
        return "none"
    end

    local parts = {}
    for index, item in ipairs(rewardItems) do
        parts[index] = tostring(item.address or index) .. "=" .. rewardItemSummary(item)
    end
    return table.concat(parts, ";")
end

local function counterSummary(currentRun, planned)
    return " actualRunDepth=" .. fieldValue(runState.runDepthCache(currentRun))
        .. " actualRunEncounterDepth=" .. fieldValue(runState.runEncounterDepth(currentRun))
        .. " actualBiomeDepthCache=" .. fieldValue(runState.biomeDepthCache(currentRun))
        .. " actualBiomeEncounterDepth=" .. fieldValue(runState.biomeEncounterDepth(currentRun))
        .. " simRoomHistoryOrdinal=" .. fieldValue(planned and planned.roomHistoryOrdinal)
        .. " simRunDepthCache=" .. fieldValue(planned and planned.runDepthCache)
        .. " simRunEncounterDepth=" .. fieldValue(planned and planned.runEncounterDepth)
        .. " simBiomeDepthCache=" .. fieldValue(planned and planned.biomeDepthCache)
        .. " simBiomeEncounterDepth=" .. fieldValue(planned and planned.biomeEncounterDepth)
end

local function rowSummary(biomeKey, row)
    return "plan row biome=" .. tostring(biomeKey)
        .. " row=" .. fieldValue(row.rowIndex)
        .. " routeOrdinal=" .. fieldValue(row.routeOrdinal)
        .. " kind=" .. fieldValue(row.slotKind)
        .. " room=" .. fieldValue(row.roomKey)
        .. " role=" .. fieldValue(row.roleKey)
        .. " option=" .. fieldValue(row.optionKey)
        .. " variant=" .. fieldValue(row.variantKey)
        .. " roomHistoryOrdinal=" .. fieldValue(row.roomHistoryOrdinal)
        .. " runDepthCache=" .. fieldValue(row.runDepthCache)
        .. " runEncounterDepth=" .. fieldValue(row.runEncounterDepth)
        .. " biomeDepthCache=" .. fieldValue(row.biomeDepthCache)
        .. " biomeDepthCacheCost=" .. fieldValue(row.biomeDepthCacheCost)
        .. " biomeEncounterDepth=" .. fieldValue(row.biomeEncounterDepth)
        .. " biomeEncounterDepthCost=" .. fieldValue(row.biomeEncounterDepthCost)
        .. " features=" .. fieldValue(joinList(sortedKeys(row.features)))
        .. " rewards=" .. rewardSummary(row.rewardItems)
end

local function dumpPlan(state, args)
    local plan = state and state.executionPlan or nil
    debugLog("plan begin route=" .. fieldValue(state and state.routeKey)
        .. " active=" .. tostring(state and state.active == true)
        .. " valid=" .. tostring(state and state.valid == true)
        .. " reason=" .. fieldValue(state and state.reason)
        .. " start=" .. fieldValue(startingBiome(args)))

    if plan == nil then
        debugLog("plan inactive; no execution plan")
        return
    end

    debugLog("plan layers rooms=" .. tostring(plan.layers and plan.layers.rooms == true)
        .. " rewards=" .. tostring(plan.layers and plan.layers.rewards == true)
        .. " npcs=" .. tostring(plan.layers and plan.layers.npcs == true)
        .. " features=" .. tostring(plan.layers and plan.layers.features == true))

    local order = plan.biomeOrder or sortedKeys(plan.biomes)
    for _, biomeKey in ipairs(order) do
        local biome = plan.biomes and plan.biomes[biomeKey] or nil
        if biome ~= nil then
            debugLog("plan biome=" .. tostring(biomeKey)
                .. " adapter=" .. fieldValue(biome.adapter)
                .. " rows=" .. tostring(#(biome.plannedRows or {})))
            for _, row in ipairs(biome.plannedRows or {}) do
                debugLog(rowSummary(biomeKey, row))
            end
        end
    end
end

local function gameRoomData(roomKey)
    local roomData = game.RoomData or _G.RoomData
    return roomData and roomData[roomKey] or nil
end

local function createRoom(roomData, args)
    local create = game.CreateRoom or _G.CreateRoom
    if type(create) ~= "function" then
        return nil
    end
    return create(roomData, args)
end

local function isRoomEligible(currentRun, currentRoom, args, roomData)
    local eligible = game.IsRoomEligible or _G.IsRoomEligible
    if type(eligible) ~= "function" then
        return true
    end
    return eligible(currentRun, currentRoom, roomData, args) == true
end

local function currentRoomSetName(currentRun, args)
    return runState.currentBiomeKey(currentRun, args)
end

local function currentBiomeDepthCache(currentRun)
    return runState.biomeDepthCache(currentRun)
end

local function nextRouteOrdinal(currentRun)
    return runState.nextBiomeDepthCache(currentRun)
end

local function isFixedDepthRoomPlan(biomeKey, biomePlan)
    return biomeKey ~= nil
        and FIXED_DEPTH_ROOM_BIOMES[biomeKey] == true
        and biomePlan ~= nil
        and FIXED_DEPTH_ROOM_ADAPTERS[biomePlan.adapter] == true
end

local function plannedRoomLimit(bucket)
    if bucket == nil then
        return 0
    end
    local count = math.floor(tonumber(bucket.primary and bucket.primary.roomOfferCount) or 1)
    if count < 1 then
        return 1
    end
    return count
end

local function offeredRoomName(door)
    local room = door and door.Room or nil
    return room and (room.GenusName or room.Name) or door and door.ForceRoomName or nil
end

local function offeredRoomCount(otherDoors, roomKey)
    local count = 0
    for _, door in ipairs(otherDoors or {}) do
        if offeredRoomName(door) == roomKey then
            count = count + 1
        end
    end
    return count
end

local function offeredRoomsSummary(otherDoors)
    local rooms = {}
    for index, door in ipairs(otherDoors or {}) do
        rooms[index] = tostring(offeredRoomName(door) or "-")
    end
    local summary = table.concat(rooms, ",")
    if summary == "" then
        return "-"
    end
    return summary
end

local function roomEligible(currentRun, args, roomKey)
    local roomData = gameRoomData(roomKey)
    if roomData == nil then
        return false
    end
    return isRoomEligible(currentRun, currentRun and currentRun.CurrentRoom or nil, args, roomData)
end

local function isGameStateEligible(roomKey)
    local eligible = game.IsGameStateEligible or _G.IsGameStateEligible
    if type(eligible) ~= "function" then
        return true
    end

    local roomData = gameRoomData(roomKey)
    return roomData ~= nil and eligible(roomData, roomData.GameStateRequirements) == true
end

local function isDoorClosedForRun(currentRun, source)
    local closed = game.IsDoorClosedForRun or _G.IsDoorClosedForRun
    return type(closed) == "function" and closed(currentRun, source) == true
end

local function roomAlreadyFilled(bucket, otherDoors, roomKey)
    return offeredRoomCount(otherDoors, roomKey) >= plannedRoomLimit(bucket, roomKey)
end

local function mergeExcludedNames(args, biomePlan, biomeDepthCache, includeCurrent)
    local excluded = shallowCopy(args and args.ExcludedNames)
    local changed = false
    for _, row in ipairs(biomePlan and biomePlan.plannedRows or {}) do
        if row.roomKey ~= nil
            and row.roomKey ~= ""
            and row.biomeDepthCache ~= nil
            and (row.biomeDepthCache > biomeDepthCache or includeCurrent and row.biomeDepthCache == biomeDepthCache)
        then
            excluded[row.roomKey] = true
            changed = true
        end
    end
    return changed and excluded or args and args.ExcludedNames or nil
end

local function argsWithExcludedNames(args, excludedNames)
    if excludedNames == nil then
        return nil
    end
    local nextArgs = shallowCopy(args)
    nextArgs.ExcludedNames = excludedNames
    return nextArgs
end

local function forceArgs(args, roomKey, excludedNames)
    local nextArgs = shallowCopy(args)
    nextArgs.ForceNextRoom = roomKey
    if excludedNames ~= nil then
        nextArgs.ExcludedNames = excludedNames
    end
    return nextArgs
end

local function planFromRuntime(runtime)
    local state = routePlan and routePlan.get and routePlan.get(runtime) or nil
    if state == nil or state.active ~= true or state.valid ~= true then
        return nil
    end
    local plan = state.executionPlan
    if plan == nil or plan.layers == nil or plan.layers.rooms ~= true then
        return nil
    end
    return plan
end

startingBiome = function(args)
    return runState.startingBiome(nil, args)
end

local function plannedStartingRoom(plan, args)
    local biomeKey = startingBiome(args)
    local biomePlan = plan and plan.biomes and plan.biomes[biomeKey] or nil
    return biomePlan and biomePlan.plannedEntryRoom or nil
end

local function roomName(roomData)
    return runState.roomName(roomData)
end

local function plannedRoomForSetup(runtime, currentRun, room)
    local plan = planFromRuntime(runtime)
    local biomeKey = runState.currentBiomeKey(currentRun, nil, room)
    local biomePlan = plan and plan.biomes and plan.biomes[biomeKey] or nil
    if not isFixedDepthRoomPlan(biomeKey, biomePlan) then
        return nil
    end

    local roomKey = roomName(room)
    local bucket = biomePlan.plannedRoutableByBiomeDepthCache[currentBiomeDepthCache(currentRun)]
    local roomBucket = bucket and bucket.byRoomKey and bucket.byRoomKey[roomKey] or nil
    if roomBucket ~= nil then
        return roomBucket.primary
    end
    if bucket ~= nil and bucket.primary ~= nil and bucket.primary.roomKey == roomKey then
        return bucket.primary
    end
    return nil
end

local function startingRoomEligible(currentRun, args, roomKey)
    local roomData = gameRoomData(roomKey)
    if roomData == nil or roomData.Starting ~= true then
        return nil
    end
    if not isRoomEligible(currentRun, nil, args, roomData) then
        return nil
    end
    return roomData
end

function roomRouting.createStartingRoom(runtime, currentRun, args)
    local plan = planFromRuntime(runtime)
    local planned = plannedStartingRoom(plan, args)
    local roomKey = planned and planned.roomKey or nil
    if roomKey == nil or roomKey == "" then
        debugLog("start " .. tostring(startingBiome(args)) .. "[0] vanilla; no planned opening")
        return nil
    end

    local roomData = startingRoomEligible(currentRun, args, roomKey)
    if roomData == nil then
        debugLog("start " .. tostring(startingBiome(args)) .. "[0] vanilla; planned " .. tostring(roomKey) .. " unavailable")
        return nil
    end

    local room = createRoom(roomData, shallowCopy(args))
    debugLog("start " .. tostring(startingBiome(args)) .. "[0] forced " .. tostring(roomKey)
        .. " -> " .. tostring(roomName(room) or roomKey))
    return room
end

local function forceMultipleEncounterCount(room, realCombatCount, callback)
    realCombatCount = math.floor(tonumber(realCombatCount) or 0)
    if realCombatCount <= 0 then
        return callback()
    end

    local original = room.MultipleEncountersData
    if original == nil then
        return callback()
    end

    local forced = {}
    for index = 1, realCombatCount do
        forced[index] = original[index]
    end
    if realCombatCount >= 3 and original[3] ~= nil then
        forced[3] = shallowCopy(original[3])
        forced[3].GameStateRequirements = nil
        forced[3].ForceRequirements = nil
    end

    room.MultipleEncountersData = forced
    local result = callback()
    room.MultipleEncountersData = original
    return result
end

function roomRouting.setupMultipleEncounters(runtime, base, room, args)
    local planned = plannedRoomForSetup(runtime, runState.currentRun(), room)
    if planned == nil or planned.realCombatCount == nil then
        return base(room, args)
    end

    return forceMultipleEncounterCount(room, planned.realCombatCount, function()
        local result = base(room, args)
        debugLog("encounters " .. tostring(roomName(room))
            .. " forced realCombatCount=" .. tostring(planned.realCombatCount)
            .. " actual=" .. tostring(#(room.Encounters or {})))
        return result
    end)
end

local function plannedCageRewardCount(room, planned)
    local count = math.floor(tonumber(planned and planned.cageRewardCount) or 0)
    if count <= 0 then
        return nil
    end

    local minCount = math.floor(tonumber(room.MinDoorCageRewards) or count)
    local maxCount = math.floor(tonumber(room.MaxDoorCageRewards) or count)
    if count < minCount then
        return minCount
    end
    if count > maxCount then
        return maxCount
    end
    return count
end

function roomRouting.selectFieldsDoorCageCount(runtime, base, currentRun, room)
    local planned = plannedRoomForSetup(runtime, currentRun, room)
    local count = plannedCageRewardCount(room, planned)
    if count == nil then
        return base(currentRun, room)
    end

    debugLog("cage rewards " .. tostring(roomName(room))
        .. " forced count=" .. tostring(count)
        .. " planned=" .. tostring(planned.cageRewardCount))
    return count
end

local function isHubPylonPlan(biomePlan)
    return biomePlan ~= nil and HUB_PYLON_ADAPTERS[biomePlan.adapter] == true
end

local function hubRoomData(room)
    return gameRoomData(roomName(room)) or room
end

local function plannedHubDoorRows(runtime, room)
    local plan = planFromRuntime(runtime)
    local biomeKey = runState.currentBiomeKey(runState.currentRun(), nil, room)
    local biomePlan = plan and plan.biomes and plan.biomes[biomeKey] or nil
    if not isHubPylonPlan(biomePlan) then
        return nil
    end

    local predetermined = hubRoomData(room) and hubRoomData(room).PredeterminedDoorRooms or nil
    if predetermined == nil then
        return nil
    end

    local rows = {}
    local byDoorId = {}
    for _, row in ipairs(biomePlan.plannedRows or {}) do
        local doorId = row.hubDoorId
        if doorId ~= nil
            and predetermined[doorId] == row.roomKey
            and isGameStateEligible(row.roomKey)
        then
            rows[#rows + 1] = row
            byDoorId[doorId] = row
        end
    end

    if rows[1] == nil then
        return nil
    end
    return rows, byDoorId, predetermined
end

local function plannedHubPylonRowForCurrentRoom(runtime, currentRun, room)
    local plan = planFromRuntime(runtime)
    local biomeKey = runState.currentBiomeKey(currentRun, nil, room)
    local biomePlan = plan and plan.biomes and plan.biomes[biomeKey] or nil
    if not isHubPylonPlan(biomePlan) then
        return nil
    end

    local roomKey = roomName(room)
    local depthBucket = biomePlan.plannedByBiomeDepthCache[currentBiomeDepthCache(currentRun)]
    local depthRoom = depthBucket and depthBucket.byRoomKey and depthBucket.byRoomKey[roomKey] or nil
    if depthRoom ~= nil then
        return depthRoom.primary
    end

    local roomBucket = biomePlan.plannedByRoomKey and biomePlan.plannedByRoomKey[roomKey] or nil
    return roomBucket and roomBucket.primary or nil
end

local function plannedSideRoomForDoor(runtime, source)
    local currentRun = runState.currentRun()
    local currentRoom = currentRun and currentRun.CurrentRoom or nil
    local planned = plannedHubPylonRowForCurrentRoom(runtime, currentRun, currentRoom)
    local doorId = source and source.ObjectId or nil
    for _, sideRoom in ipairs(planned and planned.sideRooms or {}) do
        if sideRoom.doorId == doorId then
            return sideRoom, planned, currentRun
        end
    end
    return nil
end

local function sortedDoorIds(source)
    local ids = {}
    for doorId in pairs(source or {}) do
        ids[#ids + 1] = doorId
    end
    table.sort(ids, function(left, right)
        return tonumber(left) < tonumber(right)
    end)
    return ids
end

local function availableDoorCount(predetermined, unavailable)
    local count = 0
    for doorId in pairs(predetermined or {}) do
        if unavailable == nil or unavailable[doorId] ~= true then
            count = count + 1
        end
    end
    return count
end

local function suppressUnplannedMinibossDoors(unavailable, predetermined, plannedByDoorId)
    local hasPlannedMiniboss = false
    for _, row in pairs(plannedByDoorId or {}) do
        if tostring(row.roomKey or ""):match("^N_MiniBoss") ~= nil then
            hasPlannedMiniboss = true
            break
        end
    end
    if not hasPlannedMiniboss then
        return
    end

    for doorId, roomKey in pairs(predetermined or {}) do
        if plannedByDoorId[doorId] == nil and tostring(roomKey or ""):match("^N_MiniBoss") ~= nil then
            unavailable[doorId] = true
        end
    end
end

local function trimUnplannedHubDoors(unavailable, predetermined, plannedByDoorId, targetCount)
    local count = availableDoorCount(predetermined, unavailable)
    if count <= targetCount then
        return
    end

    for _, doorId in ipairs(sortedDoorIds(predetermined)) do
        if count <= targetCount then
            return
        end
        if plannedByDoorId[doorId] == nil and unavailable[doorId] ~= true then
            unavailable[doorId] = true
            count = count - 1
        end
    end
end

function roomRouting.chooseAvailableNHubDoors(runtime, base, room, args)
    local result = base(room, args)
    local plannedRows, plannedByDoorId, predetermined = plannedHubDoorRows(runtime, room)
    if plannedRows == nil then
        return result
    end

    room.UnavailableDoors = room.UnavailableDoors or {}
    local targetCount = availableDoorCount(predetermined, room.UnavailableDoors)
    if targetCount < #plannedRows then
        targetCount = #plannedRows
    end

    for doorId in pairs(plannedByDoorId) do
        room.UnavailableDoors[doorId] = nil
    end
    suppressUnplannedMinibossDoors(room.UnavailableDoors, predetermined, plannedByDoorId)
    trimUnplannedHubDoors(room.UnavailableDoors, predetermined, plannedByDoorId, targetCount)

    debugLog("hub doors " .. tostring(roomName(room))
        .. " planned=" .. tostring(#plannedRows)
        .. " available=" .. tostring(availableDoorCount(predetermined, room.UnavailableDoors)))
    return result
end

function roomRouting.checkNSubRoomDoorUnavailable(runtime, base, source, args)
    local sideRoom, planned, currentRun = plannedSideRoomForDoor(runtime, source)
    if sideRoom == nil then
        return base(source, args)
    end

    local currentRoom = currentRun and currentRun.CurrentRoom or nil
    currentRoom.UnavailableDoors = currentRoom.UnavailableDoors or {}

    if sideRoom.enabled ~= true then
        currentRoom.UnavailableDoors[source.ObjectId] = true
        debugLog("side door " .. tostring(roomName(currentRoom))
            .. " door=" .. tostring(source.ObjectId)
            .. " disabled planned=" .. tostring(sideRoom.roomKey)
            .. " row=" .. tostring(planned and planned.rowIndex or "-"))
        return nil
    end

    if sideRoom.enabled == true then
        local beforeSpawned = math.floor(tonumber(currentRun.NumSubRoomsSpawned) or 0)
        local result = base(source, args)
        if not isDoorClosedForRun(currentRun, source)
            and currentRoom.UnavailableDoors ~= nil
            and currentRoom.UnavailableDoors[source.ObjectId] == true
        then
            currentRoom.UnavailableDoors[source.ObjectId] = nil
            if math.floor(tonumber(currentRun.NumSubRoomsSpawned) or 0) <= beforeSpawned then
                currentRun.NumSubRoomsSpawned = beforeSpawned + 1
            end
        end
        debugLog("side door " .. tostring(roomName(currentRoom))
            .. " door=" .. tostring(source.ObjectId)
            .. " enabled planned=" .. tostring(sideRoom.roomKey)
            .. " row=" .. tostring(planned and planned.rowIndex or "-"))
        return result
    end

    return base(source, args)
end

function roomRouting.buildArgs(runtime, currentRun, args, otherDoors)
    args = args or {}
    if args.ForceNextRoom ~= nil or _G.ForceNextRoom ~= nil then
        return nil
    end

    local plan = planFromRuntime(runtime)
    local biomeKey = currentRoomSetName(currentRun, args)
    local biomePlan = plan and plan.biomes and plan.biomes[biomeKey] or nil
    if not isFixedDepthRoomPlan(biomeKey, biomePlan) then
        return nil
    end

    local biomeDepthCache = currentBiomeDepthCache(currentRun)
    local bucket = biomePlan.plannedRoutableByBiomeDepthCache[biomeDepthCache]
    if bucket == nil or bucket.primary == nil then
        return argsWithExcludedNames(args, mergeExcludedNames(args, biomePlan, biomeDepthCache, false))
    end

    local roomKey = bucket.primary.roomKey
    if roomKey == nil or roomKey == "" then
        return argsWithExcludedNames(args, mergeExcludedNames(args, biomePlan, biomeDepthCache, false))
    end

    if roomAlreadyFilled(bucket, otherDoors, roomKey) or not roomEligible(currentRun, args, roomKey) then
        return argsWithExcludedNames(args, mergeExcludedNames(args, biomePlan, biomeDepthCache, true))
    end

    return forceArgs(args, roomKey, mergeExcludedNames(args, biomePlan, biomeDepthCache, false))
end

local function routeDecision(args, nextArgs)
    if nextArgs == nil then
        return "vanilla"
    end
    if nextArgs.ForceNextRoom ~= nil then
        return "forced " .. tostring(nextArgs.ForceNextRoom)
    end
    if nextArgs.ExcludedNames ~= nil and nextArgs.ExcludedNames ~= (args and args.ExcludedNames) then
        return "vanilla; reserved future rooms"
    end
    return "vanilla"
end

local function nextDecisionDetail(runtime, currentRun, args, otherDoors, nextArgs, roomData)
    local plan = planFromRuntime(runtime)
    local biomeKey = currentRoomSetName(currentRun, args)
    local biomePlan = plan and plan.biomes and plan.biomes[biomeKey] or nil
    local biomeDepthCache = currentBiomeDepthCache(currentRun)
    local bucket = biomePlan and biomePlan.plannedRoutableByBiomeDepthCache[biomeDepthCache] or nil
    local planned = bucket and bucket.primary or nil
    local plannedRoomKey = planned and planned.roomKey or nil
    local eligible = plannedRoomKey ~= nil and plannedRoomKey ~= "" and roomEligible(currentRun, args, plannedRoomKey) or nil
    local filled = plannedRoomKey ~= nil and plannedRoomKey ~= "" and roomAlreadyFilled(bucket, otherDoors, plannedRoomKey) or nil
    local currentRoom = currentRun and currentRun.CurrentRoom or nil

    return "next detail set=" .. fieldValue(biomeKey)
        .. " current=" .. fieldValue(roomName(currentRoom))
        .. " routeOrdinal=" .. fieldValue(nextRouteOrdinal(currentRun))
        .. counterSummary(currentRun, planned)
        .. " plannedBiomeDepthCache=" .. fieldValue(planned and planned.biomeDepthCache)
        .. " plannedBiomeDepthCacheCost=" .. fieldValue(planned and planned.biomeDepthCacheCost)
        .. " plannedBiomeEncounterDepth=" .. fieldValue(planned and planned.biomeEncounterDepth)
        .. " plannedBiomeEncounterDepthCost=" .. fieldValue(planned and planned.biomeEncounterDepthCost)
        .. " planned=" .. fieldValue(plannedRoomKey)
        .. " eligible=" .. fieldValue(eligible)
        .. " filled=" .. fieldValue(filled)
        .. " otherDoors=" .. tostring(#(otherDoors or {}))
        .. " offered=" .. offeredRoomsSummary(otherDoors)
        .. " action=" .. routeDecision(args, nextArgs)
        .. " actual=" .. fieldValue(roomName(roomData))
end

function roomRouting.registerHooks(moduleRef, catalog)
    moduleRef.hooks.wrap("ChooseStartingRoom", function(host, runtime, base, currentRun, args)
        if host ~= nil and host.isEnabled ~= nil and not host.isEnabled() then
            local room = base(currentRun, args)
            debugLog("start " .. tostring(startingBiome(args)) .. "[0] disabled -> " .. tostring(roomName(room)))
            return room
        end

        if routePlan ~= nil and routePlan.refresh ~= nil then
            dumpPlan(routePlan.refresh(catalog, runtime, currentRun, args), args)
        end

        local startingRoom = roomRouting.createStartingRoom(runtime, currentRun, args)
        if startingRoom ~= nil then
            return startingRoom
        end
        local room = base(currentRun, args)
        debugLog("start " .. tostring(startingBiome(args)) .. "[0] vanilla -> " .. tostring(roomName(room)))
        return room
    end)

    moduleRef.hooks.wrap("ChooseNextRoomData", function(host, runtime, base, currentRun, args, otherDoors)
        if host ~= nil and host.isEnabled ~= nil and not host.isEnabled() then
            local roomData = base(currentRun, args, otherDoors)
            debugLog("next disabled -> " .. tostring(roomName(roomData)))
            return roomData
        end

        local nextArgs = roomRouting.buildArgs(runtime, currentRun, args, otherDoors)
        local roomData = base(currentRun, nextArgs or args, otherDoors)
        debugLog(nextDecisionDetail(runtime, currentRun, args, otherDoors, nextArgs, roomData))
        debugLog("next " .. tostring(currentRoomSetName(currentRun, args)) .. "["
            .. tostring(nextRouteOrdinal(currentRun)) .. "] "
            .. routeDecision(args, nextArgs) .. " -> " .. tostring(roomName(roomData)))
        return roomData
    end)

    moduleRef.hooks.wrap("SetupRoomMultipleEncountersData", function(host, runtime, base, room, args)
        if host ~= nil and host.isEnabled ~= nil and not host.isEnabled() then
            return base(room, args)
        end

        return roomRouting.setupMultipleEncounters(runtime, base, room, args)
    end)

    moduleRef.hooks.wrap("SelectFieldsDoorCageCount", function(host, runtime, base, currentRun, room)
        if host ~= nil and host.isEnabled ~= nil and not host.isEnabled() then
            return base(currentRun, room)
        end

        return roomRouting.selectFieldsDoorCageCount(runtime, base, currentRun, room)
    end)

    moduleRef.hooks.wrap("ChooseAvailableN_HubDoors", function(host, runtime, base, room, args)
        if host ~= nil and host.isEnabled ~= nil and not host.isEnabled() then
            return base(room, args)
        end

        return roomRouting.chooseAvailableNHubDoors(runtime, base, room, args)
    end)

    moduleRef.hooks.wrap("CheckN_SubRoomDoorUnavailable", function(host, runtime, base, source, args)
        if host ~= nil and host.isEnabled ~= nil and not host.isEnabled() then
            return base(source, args)
        end

        return roomRouting.checkNSubRoomDoorUnavailable(runtime, base, source, args)
    end)
end

roomRouting.nextRouteOrdinal = nextRouteOrdinal
roomRouting.currentRoomSetName = currentRoomSetName

return roomRouting
