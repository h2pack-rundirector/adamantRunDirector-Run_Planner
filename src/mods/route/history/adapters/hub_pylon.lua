local deps = ... or {}

local hubPylon = {}
local roomCandidates = deps.roomCandidates
local rewardCandidates = deps.rewardCandidates
local siblingCandidates = deps.siblingCandidates

local EMPTY_LIST = {}
local BIOME_ENCOUNTER_DEPTH_START = 1

local function numericCost(value, fallback)
    local cost = math.floor(tonumber(value) or fallback or 0)
    if cost < 0 then
        return 0
    end
    return cost
end

local function copyList(source)
    if source == nil then
        return nil
    end
    local copy = {}
    for index, value in ipairs(source) do
        copy[index] = value
    end
    return copy
end

local function roleOptionList(role)
    return role and (role.roomOptions or role.mapOptions) or EMPTY_LIST
end

local function optionByKey(role, optionKey)
    if role == nil or optionKey == nil or optionKey == "" then
        return nil
    end
    if role.optionsByKey ~= nil then
        return role.optionsByKey[optionKey]
    end
    for _, option in ipairs(roleOptionList(role)) do
        if option.key == optionKey then
            return option
        end
    end
    return nil
end

local function fixedRoomKey(entry)
    return entry and (entry.roomKey or entry.room and entry.room.key) or nil
end

local function buildSlots(biome)
    local slots = {}
    local slotLayout = biome and biome.slotLayout or {}
    for _, entry in ipairs(slotLayout.fixedBeforeHub or EMPTY_LIST) do
        slots[#slots + 1] = {
            kind = entry.kind or "fixedBeforeHub",
            entry = entry,
            role = entry,
        }
    end
    local startOrdinal = numericCost(slotLayout.routeStartOrdinal, 1)
    local endOrdinal = numericCost(slotLayout.routeEndOrdinal, startOrdinal)
    for ordinal = startOrdinal, endOrdinal do
        slots[#slots + 1] = {
            kind = "biomeRow",
            routeOrdinal = ordinal,
        }
    end
    for _, entry in ipairs(slotLayout.fixedAfterHub or EMPTY_LIST) do
        slots[#slots + 1] = {
            kind = entry.kind or "fixedAfterHub",
            entry = entry,
            role = entry,
        }
    end
    return slots
end

local function roleForRow(biome, slot, selectedRow)
    if slot ~= nil and slot.role ~= nil then
        return slot.role
    end
    return biome.rolesByKey and biome.rolesByKey[selectedRow.roleKey] or nil
end

local function optionForRow(role, selectedRow, slot)
    local option = optionByKey(role, selectedRow.optionKey)
    if option ~= nil then
        return option
    end
    if slot ~= nil and slot.entry ~= nil then
        return slot.entry.room or { key = fixedRoomKey(slot.entry) }
    end
    return nil
end

local function rewardContext(role, option)
    if option ~= nil and option.reward ~= nil then
        return option.reward
    end
    return role and role.reward or nil
end

local function onlyEligibleRewardType(context)
    local eligible = context and context.eligibleRewardTypes or nil
    if eligible ~= nil and eligible[1] ~= nil and eligible[2] == nil then
        return eligible[1]
    end
    return nil
end

local function selectedRoomStoreReward(context, rewards)
    local values = rewards and rewards.row and rewards.row.values or EMPTY_LIST
    local fixedRewardType = onlyEligibleRewardType(context)
    local rewardType = fixedRewardType or values[1]
    return {
        kind = "roomStore",
        rewardStore = context.rewardStore,
        controlAlias = "Reward1Key",
        rewardType = rewardType ~= "" and rewardType or nil,
        eligibleRewardTypes = copyList(context.eligibleRewardTypes),
        ineligibleRewardTypes = copyList(context.ineligibleRewardTypes),
        boonSource = rewardType == "Boon" and values[fixedRewardType ~= nil and 1 or 2] or nil,
        devotionSources = rewardType == "Devotion" and { values[3], values[4] } or nil,
    }
end

local function selectedShopReward(context)
    return {
        kind = "shop",
        shopProfile = context.shopProfile,
        effectTiming = context.rewardGeneration and context.rewardGeneration.effectTiming or nil,
    }
end

local function selectedRewardSummary(context, rewards)
    if context == nil or context.kind == nil or context.kind == "none" then
        return nil
    elseif context.kind == "roomStore" then
        return selectedRoomStoreReward(context, rewards)
    elseif context.kind == "shop" then
        return selectedShopReward(context)
    end
    return {
        kind = context.kind,
    }
end

local function sideRoomRewardSummary(sideRoom)
    local rewardType = sideRoom and sideRoom.rewards and sideRoom.rewards[1] or nil
    return {
        kind = "roomStore",
        rewardStore = sideRoom.rewardStore,
        controlAlias = "Reward1Key",
        rewardType = rewardType ~= "" and rewardType or nil,
        boonSource = rewardType == "Boon" and sideRoom.rewardLoot and sideRoom.rewardLoot[1] or nil,
    }
end

local function traversalCost(context, key, field, fallback)
    local traversal = context.hub and context.hub.traversal or {}
    local node = traversal[key] or {}
    return numericCost(node[field], fallback)
end

local function hubTopologySummary(hub)
    return {
        kind = "hubDoorBatch",
        hub = {
            roomKey = hub.roomKey,
            availableDoorCount = hub.availableDoorCount,
            generatedDoorCount = hub.generatedDoorCount,
            generatedRewardExitCount = hub.generatedRewardExitCount,
            selectedDoorCount = hub.selectedDoorCount,
            effectTiming = hub.effectTiming,
            minibossAvailability = hub.minibossAvailability,
        },
    }
end

local function pylonTopologySummary(context, selectedRow, rewardContextValue)
    return {
        kind = "hubDoorBatchPick",
        selected = {
            structure = selectedRow.roleKey,
            roomKey = selectedRow.roomKey,
            hubDoorId = selectedRow.hubDoorId,
            rewardStore = rewardContextValue and rewardContextValue.rewardStore or nil,
            eligibleRewardTypes = rewardContextValue and copyList(rewardContextValue.eligibleRewardTypes) or nil,
            ineligibleRewardTypes = rewardContextValue and copyList(rewardContextValue.ineligibleRewardTypes) or nil,
            offerCount = rewardContextValue ~= nil and 1 or 0,
            rewardAddresses = rewardContextValue ~= nil and { "row" } or nil,
        },
        hub = hubTopologySummary(context.hub).hub,
    }
end

local function emitPhysical(context, args)
    local roomHistoryCost = numericCost(args.roomHistoryCost, args.biomeDepthCacheCost or 1)
    local biomeDepthCacheCost = numericCost(args.biomeDepthCacheCost, roomHistoryCost)
    local biomeEncounterDepthCost = numericCost(args.biomeEncounterDepthCost, 0)
    context.routeState.roomHistoryOrdinal = context.routeState.roomHistoryOrdinal + roomHistoryCost

    local entry = context.routeHistory.emitAt(context.history, {
        routeKey = context.routeKey,
        controlName = context.snapshot.controlName,
        biomeKey = context.biome.key,
        routeBiomeIndex = context.routeBiomeIndex,
        rowIndex = args.rowIndex,
        routeOrdinal = args.routeOrdinal,
        roomHistoryOrdinal = context.routeState.roomHistoryOrdinal,
        runDepthCache = 1 + context.routeState.roomHistoryOrdinal,
        runEncounterDepth = context.routeState.runEncounterDepth,
        biomeDepthCache = context.biomeState.biomeDepthCache,
        biomeEncounterDepth = context.biomeState.biomeEncounterDepth,
    }, {
        kind = "room",
        eventKey = args.eventKey,
        groupKey = args.groupKey,
        sourceKind = args.sourceKind,
        roomKey = args.roomKey,
        roleKey = args.roleKey,
        optionKey = args.optionKey,
        variantKey = args.variantKey,
        nextRoomTags = args.nextRoomTags,
        tags = args.tags,
        entryKey = args.entryKey,
        entryLabel = args.entryLabel,
        sideIndex = args.sideIndex,
        doorId = args.doorId,
        encounterClassKey = args.encounterClassKey,
        source = args.source,
    })
    entry.roomCandidates = args.roomCandidates
    entry.siblingCandidates = args.siblingCandidates
    entry.reward = args.reward
    entry.rewardCandidates = args.rewardCandidates
    entry.topology = args.topology

    context.routeState.runEncounterDepth = context.routeState.runEncounterDepth + biomeEncounterDepthCost
    context.biomeState.biomeDepthCache = context.biomeState.biomeDepthCache + biomeDepthCacheCost
    context.biomeState.biomeEncounterDepth = context.biomeState.biomeEncounterDepth + biomeEncounterDepthCost
    return entry
end

local function emitFixed(context, selectedRow, slot)
    local role = roleForRow(context.biome, slot, selectedRow)
    local option = optionForRow(role, selectedRow, slot)
    local key = selectedRow.roleKey == "Opening" and "opening"
        or selectedRow.roleKey == "PreHub" and "preHub"
        or selectedRow.roleKey == "Hub" and "hubVisit"
        or selectedRow.roleKey == "Preboss" and "preboss"
        or nil
    local reward = selectedRewardSummary(rewardContext(role, option), selectedRow.rewards)
    local topology = selectedRow.roleKey == "Hub" and hubTopologySummary(context.hub) or nil
    emitPhysical(context, {
        rowIndex = selectedRow.rowIndex,
        routeOrdinal = selectedRow.routeOrdinal,
        eventKey = selectedRow.roomKey or selectedRow.roleKey,
        groupKey = selectedRow.roleKey,
        sourceKind = "row",
        roomKey = selectedRow.roomKey,
        roleKey = selectedRow.roleKey,
        optionKey = selectedRow.optionKey,
        variantKey = selectedRow.variantKey,
        source = selectedRow,
        roomCandidates = roomCandidates.forBiomeRow(context.biome, selectedRow, {
            role = role,
            option = option,
        }),
        siblingCandidates = siblingCandidates.forBiomeRow(context.biome, selectedRow),
        reward = reward,
        rewardCandidates = rewardCandidates.forContext(rewardContext(role, option)),
        topology = topology,
        biomeDepthCacheCost = traversalCost(context, key, "biomeDepthCacheCost", 1),
        biomeEncounterDepthCost = traversalCost(context, key, "biomeEncounterDepthCost", 0),
    })
end

local function emitPylonRestore(context, selectedRow, sideRoom)
    emitPhysical(context, {
        rowIndex = selectedRow.rowIndex,
        routeOrdinal = selectedRow.routeOrdinal,
        eventKey = selectedRow.roomKey,
        groupKey = "PylonRestore",
        sourceKind = "pylonRestore",
        roomKey = selectedRow.roomKey,
        roleKey = selectedRow.roleKey,
        optionKey = selectedRow.optionKey,
        sideIndex = sideRoom.sideIndex,
        source = sideRoom,
        biomeDepthCacheCost = traversalCost(context, "pylonRestore", "biomeDepthCacheCost", 1),
        biomeEncounterDepthCost = traversalCost(context, "pylonRestore", "biomeEncounterDepthCost", 0),
    })
end

local function emitSideRoom(context, selectedRow, sideRoom)
    emitPhysical(context, {
        rowIndex = selectedRow.rowIndex,
        routeOrdinal = selectedRow.routeOrdinal,
        eventKey = sideRoom.roomKey,
        groupKey = "SideRoom",
        sourceKind = "sideRoom",
        roomKey = sideRoom.roomKey,
        roleKey = "SideRoom",
        optionKey = selectedRow.optionKey,
        sideIndex = sideRoom.sideIndex,
        doorId = sideRoom.doorId,
        encounterClassKey = sideRoom.encounterClassKey,
        source = sideRoom,
        reward = sideRoomRewardSummary(sideRoom),
        rewardCandidates = rewardCandidates.forContext({
            kind = "roomStore",
            rewardStore = sideRoom.rewardStore,
        }),
        biomeDepthCacheCost = traversalCost(context, "sideRoom", "biomeDepthCacheCost", 1),
        biomeEncounterDepthCost = traversalCost(context, "sideRoom", "biomeEncounterDepthCost", 0),
    })
    emitPylonRestore(context, selectedRow, sideRoom)
end

local function emitHubReturn(context, selectedRow)
    emitPhysical(context, {
        rowIndex = selectedRow.rowIndex,
        routeOrdinal = selectedRow.routeOrdinal,
        eventKey = context.hub.roomKey,
        groupKey = "HubReturn",
        sourceKind = "hubReturn",
        roomKey = context.hub.roomKey,
        roleKey = "Hub",
        source = selectedRow,
        topology = hubTopologySummary(context.hub),
        biomeDepthCacheCost = traversalCost(context, "hubReturn", "biomeDepthCacheCost", 1),
        biomeEncounterDepthCost = traversalCost(context, "hubReturn", "biomeEncounterDepthCost", 0),
    })
end

local function emitPylon(context, selectedRow, slot)
    local role = roleForRow(context.biome, slot, selectedRow)
    local option = optionForRow(role, selectedRow, slot)
    local rewardContextValue = rewardContext(role, option)
    emitPhysical(context, {
        rowIndex = selectedRow.rowIndex,
        routeOrdinal = selectedRow.routeOrdinal,
        eventKey = selectedRow.roomKey,
        groupKey = selectedRow.roleKey,
        sourceKind = "row",
        roomKey = selectedRow.roomKey,
        roleKey = selectedRow.roleKey,
        optionKey = selectedRow.optionKey,
        variantKey = selectedRow.variantKey,
        source = selectedRow,
        roomCandidates = roomCandidates.forBiomeRow(context.biome, selectedRow, {
            role = role,
            option = option,
        }),
        siblingCandidates = siblingCandidates.forBiomeRow(context.biome, selectedRow),
        reward = selectedRewardSummary(rewardContextValue, selectedRow.rewards),
        rewardCandidates = rewardCandidates.forContext(rewardContextValue),
        topology = pylonTopologySummary(context, selectedRow, rewardContextValue),
        biomeDepthCacheCost = traversalCost(context, "pylonEntry", "biomeDepthCacheCost", 1),
        biomeEncounterDepthCost = numericCost(
            option and option.biomeEncounterDepthCost,
            numericCost(role and role.biomeEncounterDepthCost, 0)
        ),
    })
    for _, sideRoom in ipairs(selectedRow.sideRooms or EMPTY_LIST) do
        if sideRoom.entered == true then
            emitSideRoom(context, selectedRow, sideRoom)
        end
    end
    emitHubReturn(context, selectedRow)
end

local function shouldEmitPylon(selectedRow)
    return selectedRow.roleKey ~= nil and selectedRow.roleKey ~= ""
end

function hubPylon.build(args)
    local context = {
        routeKey = args.route and args.route.key or args.snapshot.routeKey,
        routeBiomeIndex = args.routeBiomeIndex,
        snapshot = args.snapshot,
        biome = args.biome,
        hub = args.snapshot.hub or args.biome and args.biome.roomTopology and args.biome.roomTopology.hub or {},
        history = args.history,
        routeHistory = args.routeHistory,
        routeState = args.routeState,
        biomeState = {
            biomeDepthCache = numericCost(
                args.biome and args.biome.slotLayout and args.biome.slotLayout.biomeDepthCacheStart,
                0
            ),
            biomeEncounterDepth = BIOME_ENCOUNTER_DEPTH_START,
        },
    }

    local slots = buildSlots(args.biome)
    for index, selectedRow in ipairs(args.snapshot.rows or EMPTY_LIST) do
        local slot = slots[index]
        if slot ~= nil and slot.kind == "biomeRow" then
            if shouldEmitPylon(selectedRow) then
                emitPylon(context, selectedRow, slot)
            end
        elseif selectedRow.roleKey ~= nil and selectedRow.roleKey ~= "" then
            emitFixed(context, selectedRow, slot)
        end
    end
end

return hubPylon
