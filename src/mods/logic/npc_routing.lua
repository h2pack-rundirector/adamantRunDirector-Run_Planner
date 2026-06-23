local deps = ...
local routePlan = deps.routePlan
local runState = deps.runState
local game = deps.game or {}

local npcRouting = {}
local EMPTY_LIST = {}

local function fieldValue(value)
    if value == nil or value == "" then
        return "-"
    end
    return tostring(value)
end

local function debugLog(message)
    local printer = game.print or _G.print
    if type(printer) == "function" then
        printer("[RunPlanner] npc_routing: " .. tostring(message))
    end
end

local function shallowCopy(source)
    local copy = {}
    for key, value in pairs(source or {}) do
        copy[key] = value
    end
    return copy
end

local function planFromRuntime(runtime)
    local state = routePlan.get(runtime)
    if state == nil or state.active ~= true or state.valid ~= true then
        return nil
    end
    local plan = state.executionPlan
    if plan == nil or plan.layers == nil or plan.layers.npcs ~= true then
        return nil
    end
    return plan
end

local function roomName(room)
    return runState.roomName(room)
end

local function biomeDepthCacheForRoom(currentRun, room)
    local currentRoom = currentRun and currentRun.CurrentRoom or nil
    if currentRoom ~= nil
        and room ~= nil
        and room ~= currentRoom
    then
        return runState.nextBiomeDepthCache(currentRun)
    end
    return runState.biomeDepthCache(currentRun)
end

local function currentPlannedRow(plan, currentRun, room)
    local biomeKey = runState.currentBiomeKey(currentRun, nil, room)
    local biome = plan and plan.biomes and plan.biomes[biomeKey] or nil
    local bucket = biome
        and biome.plannedByBiomeDepthCache
        and biome.plannedByBiomeDepthCache[biomeDepthCacheForRoom(currentRun, room)]
        or nil
    local roomKey = roomName(room)
    local roomBucket = bucket and bucket.byRoomKey and bucket.byRoomKey[roomKey] or nil
    if roomBucket ~= nil then
        return roomBucket.primary, biomeKey
    end
    if bucket ~= nil and bucket.primary ~= nil and bucket.primary.roomKey == roomKey then
        return bucket.primary, biomeKey
    end
    return nil, biomeKey
end

local function targetMatchesPlannedRow(target, plannedRow, biomeKey)
    return target ~= nil
        and plannedRow ~= nil
        and target.biomeKey == biomeKey
        and tostring(target.rowIndex or target.targetRowIndex or "") == tostring(plannedRow.rowIndex or "")
end

local function plannedNpcForRoom(plan, currentRun, room)
    local plannedRow, biomeKey = currentPlannedRow(plan, currentRun, room)
    for _, row in ipairs(plan and plan.npcs and plan.npcs.rows or EMPTY_LIST) do
        if row.disabled ~= true and targetMatchesPlannedRow(row.target, plannedRow, biomeKey) then
            return row, plannedRow, biomeKey
        end
    end
    return nil, plannedRow, biomeKey
end

local function encounterData(encounterName)
    local data = game.EncounterData or _G.EncounterData
    return data and data[encounterName] or nil
end

local function isEncounterEligible(currentRun, room, encounterName, args)
    local data = encounterData(encounterName)
    if data == nil then
        return true
    end

    local stateEligible = game.IsGameStateEligible or _G.IsGameStateEligible
    if data.GameStateRequirements ~= nil
        and type(stateEligible) == "function"
        and stateEligible(data, data.GameStateRequirements, args) ~= true
    then
        return false
    end

    local encounterEligible = game.IsEncounterEligible or _G.IsEncounterEligible
    if type(encounterEligible) == "function"
        and encounterEligible(currentRun, room, data, args) ~= true
    then
        return false
    end
    return true
end

local function legalEncounterList(args, room)
    return args and args.LegalEncounters or room and room.LegalEncounters or nil
end

local function containsEncounter(legalEncounters, encounterName)
    for _, legalEncounter in ipairs(legalEncounters or EMPTY_LIST) do
        if legalEncounter == encounterName then
            return true
        end
    end
    return false
end

local function argsWithLegalEncounters(args, legalEncounters)
    local nextArgs = shallowCopy(args)
    nextArgs.LegalEncounters = legalEncounters
    return nextArgs
end

local function npcDefinitions(catalog)
    return catalog and catalog.npcs or {}
end

local function npcDefinition(catalog, npcKey)
    local npcs = npcDefinitions(catalog)
    return npcs.byKey and npcs.byKey[npcKey] or nil
end

local function addNpcKey(lookup, npcKey)
    if npcKey ~= nil and npcKey ~= "" then
        lookup.npcKeys[npcKey] = true
    end
end

local function addNpcEncounterNames(lookup, catalog, npcKey)
    addNpcKey(lookup, npcKey)
    local npc = npcDefinition(catalog, npcKey)
    for _, biomeEntry in pairs(npc and npc.biomes or {}) do
        for _, variant in ipairs(biomeEntry.variants or EMPTY_LIST) do
            if variant.encounterName ~= nil then
                lookup.exact[variant.encounterName] = true
            end
        end
    end
end

local function addGroupNpcKeys(lookup, catalog, groupKey)
    local npcs = npcDefinitions(catalog)
    for _, npcKey in ipairs(npcs.ordered or EMPTY_LIST) do
        local npc = npcDefinition(catalog, npcKey)
        if npc ~= nil and npc.routeGroup == groupKey then
            addNpcKey(lookup, npcKey)
        end
    end
end

local function addGroupEncounterNames(lookup, catalog, row)
    local npcs = npcDefinitions(catalog)
    local npc = npcDefinition(catalog, row.npcKey)
    local groupKey = row.groupKey or npc and npc.routeGroup
    local group = npcs.groups and npcs.groups[groupKey] or nil
    addGroupNpcKeys(lookup, catalog, groupKey)
    local found = false
    for _, encounterName in ipairs(group and group.encounterNames or EMPTY_LIST) do
        lookup.exact[encounterName] = true
        found = true
    end
    if not found then
        addNpcEncounterNames(lookup, catalog, row.npcKey)
    end
end

local function addGroupExactEncounterNames(lookup, catalog, row)
    local npcs = npcDefinitions(catalog)
    local npc = npcDefinition(catalog, row.npcKey)
    local groupKey = row.groupKey or npc and npc.routeGroup
    local group = npcs.groups and npcs.groups[groupKey] or nil
    local found = false
    for _, encounterName in ipairs(group and group.encounterNames or EMPTY_LIST) do
        lookup.exact[encounterName] = true
        found = true
    end
    if not found and row.target and row.target.encounterName ~= nil then
        lookup.exact[row.target.encounterName] = true
    end
end

local function routeOrdinal(value)
    local ordinal = tonumber(value)
    if ordinal == nil then
        return nil
    end
    return math.floor(ordinal)
end

local function routeBiomeIndex(plan, biomeKey)
    for index, routeBiomeKey in ipairs(plan and plan.biomeOrder or EMPTY_LIST) do
        if routeBiomeKey == biomeKey then
            return index
        end
    end
    return nil
end

local function isFutureOrCurrentTarget(plan, row, plannedRow, biomeKey)
    if row == nil or row.target == nil then
        return false
    end
    local currentOrdinal = plannedRow ~= nil and routeOrdinal(plannedRow.routeOrdinal) or nil
    local targetOrdinal = routeOrdinal(row.target.routeOrdinal)
    if currentOrdinal ~= nil and targetOrdinal ~= nil then
        return targetOrdinal >= currentOrdinal
    end

    local currentBiomeRouteIndex = routeBiomeIndex(plan, biomeKey)
    local targetBiomeRouteIndex = routeOrdinal(row.target.biomeRouteIndex)
    if currentBiomeRouteIndex ~= nil and targetBiomeRouteIndex ~= nil then
        return targetBiomeRouteIndex >= currentBiomeRouteIndex
    end
    return true
end

local function npcGroup(catalog, row)
    local npcs = npcDefinitions(catalog)
    local npc = npcDefinition(catalog, row.npcKey)
    local groupKey = row.groupKey or npc and npc.routeGroup
    return npcs.groups and npcs.groups[groupKey] or nil
end

local function addTargetSuppression(lookup, catalog, plan, row, plannedRow, biomeKey)
    local group = npcGroup(catalog, row)
    if group ~= nil and group.maxSelectionsPerBiome == 1 then
        if isFutureOrCurrentTarget(plan, row, plannedRow, biomeKey) then
            addGroupExactEncounterNames(lookup, catalog, row)
        end
        return
    end
    addGroupEncounterNames(lookup, catalog, row)
end

local function suppressionLookup(plan, catalog, plannedRow, biomeKey)
    local lookup = {
        exact = {},
        npcKeys = {},
    }
    for _, row in ipairs(plan and plan.npcs and plan.npcs.rows or EMPTY_LIST) do
        if row.disabled == true then
            addNpcEncounterNames(lookup, catalog, row.npcKey)
        elseif row.target ~= nil then
            addTargetSuppression(lookup, catalog, plan, row, plannedRow, biomeKey)
        end
    end
    return lookup
end

local function encounterMatchesSuppressedNpc(encounterName, npcKey)
    return type(encounterName) == "string"
        and encounterName:find(npcKey, 1, true) ~= nil
        and (
            encounterName:find("Combat", 1, true) ~= nil
            or encounterName:find("RandomEvent", 1, true) ~= nil
        )
end

local function isSuppressedEncounter(encounterName, suppressed)
    if suppressed.exact[encounterName] == true then
        return true
    end
    for npcKey in pairs(suppressed.npcKeys) do
        if encounterMatchesSuppressedNpc(encounterName, npcKey) then
            return true
        end
    end
    return false
end

local function filteredEncounters(legalEncounters, suppressed)
    local filtered = {}
    local changed = false
    for _, encounterName in ipairs(legalEncounters or EMPTY_LIST) do
        if isSuppressedEncounter(encounterName, suppressed) then
            changed = true
        else
            filtered[#filtered + 1] = encounterName
        end
    end
    return changed and filtered or nil
end

function npcRouting.chooseEncounter(runtime, base, catalog, currentRun, room, args)
    local plan = planFromRuntime(runtime)
    local legalEncounters = legalEncounterList(args, room)
    if plan == nil or legalEncounters == nil then
        return base(currentRun, room, args)
    end

    local plannedNpc, plannedRow, biomeKey = plannedNpcForRoom(plan, currentRun, room)
    local encounterName = plannedNpc and plannedNpc.target and plannedNpc.target.encounterName or nil
    if encounterName ~= nil
        and containsEncounter(legalEncounters, encounterName)
        and isEncounterEligible(currentRun, room, encounterName, args)
    then
        debugLog("force npc=" .. fieldValue(plannedNpc.npcKey)
            .. " encounter=" .. fieldValue(encounterName)
            .. " biome=" .. fieldValue(biomeKey)
            .. " row=" .. fieldValue(plannedRow and plannedRow.rowIndex))
        return base(currentRun, room, argsWithLegalEncounters(args, { encounterName }))
    end

    local filtered = filteredEncounters(legalEncounters, suppressionLookup(plan, catalog, plannedRow, biomeKey))
    if filtered ~= nil then
        debugLog("suppress biome=" .. fieldValue(biomeKey)
            .. " room=" .. fieldValue(roomName(room))
            .. " row=" .. fieldValue(plannedRow and plannedRow.rowIndex)
            .. " legal=" .. tostring(#legalEncounters)
            .. " filtered=" .. tostring(#filtered))
        return base(currentRun, room, argsWithLegalEncounters(args, filtered))
    end

    return base(currentRun, room, args)
end

function npcRouting.registerHooks(moduleRef, catalog)
    moduleRef.hooks.wrap("ChooseEncounter", function(host, runtime, base, currentRun, room, args)
        if host ~= nil and host.isEnabled ~= nil and not host.isEnabled() then
            return base(currentRun, room, args)
        end

        return npcRouting.chooseEncounter(runtime, base, catalog, currentRun, room, args)
    end)
end

return npcRouting
