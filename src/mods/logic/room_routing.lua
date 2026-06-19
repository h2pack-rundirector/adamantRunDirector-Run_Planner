local deps = ...
local routePlan = deps.routePlan
local game = deps.game or {}

local roomRouting = {}
local startingBiome

local LINEAR_BIOMES = {
    F = true,
    G = true,
    P = true,
    Q = true,
}

local LINEAR_ADAPTERS = {
    fixedLinear = true,
    scriptedFixedLinear = true,
    FixedLinearRoute = true,
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

local function firstListValue(values)
    if type(values) ~= "table" then
        return nil
    end
    return values[1]
end

local function debugLog(message)
    local printer = game.print or _G.print
    local text = "[RunPlanner] room_routing: " .. tostring(message)
    if type(printer) == "function" then
        printer(text)
    end
end

local function rewardSummary(reward)
    if reward == nil then
        return "none"
    end

    local kind = reward.kind or "vanilla"
    local rewards = joinList(reward.rewards)
    if rewards ~= "" then
        return kind .. ":" .. rewards
    end

    local loot = joinList(reward.loot)
    if loot ~= "" then
        return kind .. ":loot=" .. loot
    end

    local picks = {}
    for index, pick in ipairs(reward.picks or {}) do
        picks[index] = tostring(pick.alias or pick.key or index) .. "=" .. tostring(pick.value)
    end
    if picks[1] ~= nil then
        return kind .. ":picks=" .. table.concat(picks, ",")
    end

    return kind
end

local function rowSummary(biomeKey, row)
    return "plan row biome=" .. tostring(biomeKey)
        .. " row=" .. fieldValue(row.rowIndex)
        .. " coord=" .. fieldValue(row.coordinate)
        .. " kind=" .. fieldValue(row.slotKind)
        .. " room=" .. fieldValue(row.roomKey)
        .. " role=" .. fieldValue(row.roleKey)
        .. " option=" .. fieldValue(row.optionKey)
        .. " branch=" .. fieldValue(row.branchKey)
        .. " variant=" .. fieldValue(row.variantKey)
        .. " features=" .. fieldValue(joinList(sortedKeys(row.features)))
        .. " reward=" .. rewardSummary(row.reward)
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

local function previousRoom(currentRun)
    local getPreviousRoom = game.GetPreviousRoom or _G.GetPreviousRoom
    if type(getPreviousRoom) == "function" then
        return getPreviousRoom(currentRun)
    end
    local history = currentRun and currentRun.RoomHistory or nil
    return history and history[#history] or nil
end

local function currentRoomSetName(currentRun, args)
    args = args or {}
    local currentRoom = currentRun and currentRun.CurrentRoom or nil
    local roomSetName = args.RoomSetName or currentRoom and currentRoom.RoomSetName or "F"
    if args.ForceNextRoomSet ~= nil or currentRoom and currentRoom.ForceNextRoomSet ~= nil then
        roomSetName = args.ForceNextRoomSet or currentRoom.ForceNextRoomSet
    elseif currentRoom and currentRoom.NextRoomSet ~= nil then
        roomSetName = firstListValue(currentRoom.NextRoomSet)
    elseif currentRoom and currentRoom.UsePreviousRoomSet then
        local prevRoom = previousRoom(currentRun) or currentRoom
        roomSetName = prevRoom.RoomSetName
    end
    return roomSetName
end

local function nextCoordinate(currentRun)
    return math.floor(tonumber(currentRun and currentRun.BiomeDepthCache or 0) or 0) + 1
end

local function isLinearBiomePlan(biomeKey, biomePlan)
    return biomeKey ~= nil
        and LINEAR_BIOMES[biomeKey] == true
        and biomePlan ~= nil
        and LINEAR_ADAPTERS[biomePlan.adapter] == true
end

local function plannedRoomLimit(bucket, roomKey)
    if bucket == nil then
        return 0
    end
    local roomBucket = bucket.byRoomKey and bucket.byRoomKey[roomKey] or nil
    if roomBucket ~= nil and bucket.branchGroup then
        return #roomBucket.rows
    end
    return 1
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

local function roomAlreadyFilled(bucket, otherDoors, roomKey)
    return offeredRoomCount(otherDoors, roomKey) >= plannedRoomLimit(bucket, roomKey)
end

local function mergeExcludedNames(args, biomePlan, coordinate, includeCurrent)
    local excluded = shallowCopy(args and args.ExcludedNames)
    local changed = false
    for _, row in ipairs(biomePlan and biomePlan.plannedRows or {}) do
        if row.roomKey ~= nil
            and row.roomKey ~= ""
            and row.coordinate ~= nil
            and (row.coordinate > coordinate or includeCurrent and row.coordinate == coordinate)
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
    return args and args.StartingBiome or nil
end

local function plannedStartingRoom(plan, args)
    local biomeKey = startingBiome(args)
    local biomePlan = plan and plan.biomes and plan.biomes[biomeKey] or nil
    if not isLinearBiomePlan(biomeKey, biomePlan) then
        return nil
    end

    local bucket = biomePlan.plannedByCoordinate[0]
    return bucket and bucket.primary or nil
end

local function roomName(roomData)
    return roomData and (roomData.GenusName or roomData.Name) or nil
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

function roomRouting.buildArgs(runtime, currentRun, args, otherDoors)
    args = args or {}
    if args.ForceNextRoom ~= nil or _G.ForceNextRoom ~= nil then
        return nil
    end

    local plan = planFromRuntime(runtime)
    local biomeKey = currentRoomSetName(currentRun, args)
    local biomePlan = plan and plan.biomes and plan.biomes[biomeKey] or nil
    if not isLinearBiomePlan(biomeKey, biomePlan) then
        return nil
    end

    local coordinate = nextCoordinate(currentRun)
    local bucket = biomePlan.plannedByCoordinate[coordinate]
    if bucket == nil or bucket.primary == nil then
        return argsWithExcludedNames(args, mergeExcludedNames(args, biomePlan, coordinate, false))
    end

    local roomKey = bucket.primary.roomKey
    if roomKey == nil or roomKey == "" then
        return argsWithExcludedNames(args, mergeExcludedNames(args, biomePlan, coordinate, false))
    end

    if roomAlreadyFilled(bucket, otherDoors, roomKey) or not roomEligible(currentRun, args, roomKey) then
        return argsWithExcludedNames(args, mergeExcludedNames(args, biomePlan, coordinate, true))
    end

    return forceArgs(args, roomKey, mergeExcludedNames(args, biomePlan, coordinate, false))
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
    local coordinate = nextCoordinate(currentRun)
    local bucket = biomePlan and biomePlan.plannedByCoordinate[coordinate] or nil
    local planned = bucket and bucket.primary or nil
    local plannedRoomKey = planned and planned.roomKey or nil
    local eligible = plannedRoomKey ~= nil and plannedRoomKey ~= "" and roomEligible(currentRun, args, plannedRoomKey) or nil
    local filled = plannedRoomKey ~= nil and plannedRoomKey ~= "" and roomAlreadyFilled(bucket, otherDoors, plannedRoomKey) or nil
    local currentRoom = currentRun and currentRun.CurrentRoom or nil

    return "next detail set=" .. fieldValue(biomeKey)
        .. " current=" .. fieldValue(roomName(currentRoom))
        .. " runDepth=" .. fieldValue(currentRun and currentRun.RunDepthCache)
        .. " biomeDepthCache=" .. fieldValue(currentRun and currentRun.BiomeDepthCache)
        .. " coord=" .. fieldValue(coordinate)
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
            .. tostring(nextCoordinate(currentRun)) .. "] "
            .. routeDecision(args, nextArgs) .. " -> " .. tostring(roomName(roomData)))
        return roomData
    end)
end

roomRouting.nextCoordinate = nextCoordinate
roomRouting.currentRoomSetName = currentRoomSetName

return roomRouting
