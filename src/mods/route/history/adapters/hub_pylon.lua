local deps = ... or {}

local hubPylon = {}
local materializeRoom = deps.materializeRoom
local formAddress = import("mods/route/history/form_address.lua")

local EMPTY_LIST = {}
local BIOME_ENCOUNTER_DEPTH_START = 0

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
        address = "side:" .. tostring(sideRoom.sideIndex),
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

local function shouldEmitPylon(selectedRow)
    return selectedRow.roleKey ~= nil and selectedRow.roleKey ~= ""
end

local function hubTopologySummary(hub, generatedDoors)
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
        generatedDoors = generatedDoors,
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
            sameExitRewardCount = rewardContextValue ~= nil and 1 or 0,
            rewardAddresses = rewardContextValue ~= nil and { "row" } or nil,
        },
        hub = hubTopologySummary(context.hub).hub,
    }
end

local function generatedDoorSummary(context, selectedRow, slot)
    local role = roleForRow(context.biome, slot, selectedRow)
    local option = optionForRow(role, selectedRow, slot)
    local rewardContextValue = rewardContext(role, option)
    return {
        targetRowIndex = selectedRow.rowIndex,
        targetFormAddress = formAddress.withRowFallback(selectedRow.formAddress, selectedRow.rowIndex),
        targetRouteOrdinal = selectedRow.routeOrdinal,
        structure = selectedRow.roleKey,
        roomKey = selectedRow.roomKey,
        hubDoorId = selectedRow.hubDoorId,
        roleKey = selectedRow.roleKey,
        optionKey = selectedRow.optionKey,
        reward = selectedRewardSummary(rewardContextValue, selectedRow.rewards),
    }
end

local function generatedHubDoors(context, slots, rows)
    local generatedDoors = {}
    for index, selectedRow in ipairs(rows or EMPTY_LIST) do
        local slot = slots[index]
        if slot ~= nil and slot.kind == "biomeRow" and shouldEmitPylon(selectedRow) then
            generatedDoors[#generatedDoors + 1] = generatedDoorSummary(context, selectedRow, slot)
        end
    end
    return generatedDoors
end

local function emitPhysical(context, args)
    local selectedRow = {
        rowIndex = args.rowIndex,
        formAddress = formAddress.withRowFallback(
            args.formAddress or args.source and args.source.formAddress or nil,
            args.rowIndex
        ),
        roleKey = args.roleKey,
        optionKey = args.optionKey,
        variantKey = args.variantKey,
    }
    local resolved = {
        routeOrdinal = args.routeOrdinal,
        eventKey = args.eventKey,
        roomKey = args.roomKey,
        role = args.role,
        option = args.option,
        rewardContext = args.rewardContext,
        biomeDepthCacheCost = numericCost(args.biomeDepthCacheCost, 0),
        biomeEncounterDepthCost = numericCost(args.biomeEncounterDepthCost, 0),
        roomHistoryCost = numericCost(args.roomHistoryCost, 0),
    }
    return materializeRoom.stepRoom(context, selectedRow, resolved, {
        fields = {
            groupKey = args.groupKey,
            eventSourceKind = args.eventSourceKind,
            nextRoomTags = args.nextRoomTags,
            tags = args.tags,
            entryKey = args.entryKey,
            entryLabel = args.entryLabel,
            sideIndex = args.sideIndex,
            doorId = args.doorId,
            encounterClassKey = args.encounterClassKey,
            source = args.source,
        },
        reward = args.reward,
        rewardCandidateOpts = args.rewardCandidateOpts,
        attachReward = args.attachReward,
        attachCurrentRoomCandidates = args.attachCurrentRoomCandidates,
        attachPickedDoorCandidates = false,
        attachSiblingCandidates = false,
        attachTopology = args.topology ~= nil and function(entry)
            entry.topology = args.topology
        end or nil,
    })
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
    local topology = selectedRow.roleKey == "Hub"
        and hubTopologySummary(context.hub, context.generatedHubDoors)
        or nil
    emitPhysical(context, {
        rowIndex = selectedRow.rowIndex,
        routeOrdinal = selectedRow.routeOrdinal,
        eventKey = selectedRow.roomKey or selectedRow.roleKey,
        groupKey = selectedRow.roleKey,
        eventSourceKind = "row",
        roomKey = selectedRow.roomKey,
        roleKey = selectedRow.roleKey,
        optionKey = selectedRow.optionKey,
        variantKey = selectedRow.variantKey,
        role = role,
        option = option,
        rewardContext = rewardContext(role, option),
        source = selectedRow,
        reward = reward,
        topology = topology,
        biomeDepthCacheCost = traversalCost(context, key, "biomeDepthCacheCost", 1),
        biomeEncounterDepthCost = traversalCost(context, key, "biomeEncounterDepthCost", 0),
        roomHistoryCost = traversalCost(context, key, "roomHistoryCost", 0),
    })
end

local function emitPylonRestore(context, selectedRow, sideRoom)
    emitPhysical(context, {
        rowIndex = selectedRow.rowIndex,
        routeOrdinal = selectedRow.routeOrdinal,
        eventKey = selectedRow.roomKey,
        groupKey = "PylonRestore",
        eventSourceKind = "pylonRestore",
        roomKey = selectedRow.roomKey,
        roleKey = selectedRow.roleKey,
        optionKey = selectedRow.optionKey,
        sideIndex = sideRoom.sideIndex,
        source = sideRoom,
        formAddress = formAddress.child(selectedRow.rowIndex, "pylonRestore", sideRoom.sideIndex),
        attachReward = false,
        attachCurrentRoomCandidates = false,
        biomeDepthCacheCost = traversalCost(context, "pylonRestore", "biomeDepthCacheCost", 1),
        biomeEncounterDepthCost = traversalCost(context, "pylonRestore", "biomeEncounterDepthCost", 0),
        roomHistoryCost = traversalCost(context, "pylonRestore", "roomHistoryCost", 0),
    })
end

local function emitSideRoom(context, selectedRow, sideRoom)
    emitPhysical(context, {
        rowIndex = selectedRow.rowIndex,
        routeOrdinal = selectedRow.routeOrdinal,
        eventKey = sideRoom.roomKey,
        groupKey = "SideRoom",
        eventSourceKind = "sideRoom",
        roomKey = sideRoom.roomKey,
        roleKey = "SideRoom",
        optionKey = selectedRow.optionKey,
        sideIndex = sideRoom.sideIndex,
        doorId = sideRoom.doorId,
        encounterClassKey = sideRoom.encounterClassKey,
        source = sideRoom,
        formAddress = formAddress.withRowFallback(sideRoom.formAddress, selectedRow.rowIndex),
        reward = sideRoomRewardSummary(sideRoom),
        rewardContext = {
            kind = "roomStore",
            address = "side:" .. tostring(sideRoom.sideIndex),
            rewardStore = sideRoom.rewardStore,
        },
        attachCurrentRoomCandidates = false,
        biomeDepthCacheCost = traversalCost(context, "sideRoom", "biomeDepthCacheCost", 1),
        biomeEncounterDepthCost = traversalCost(context, "sideRoom", "biomeEncounterDepthCost", 0),
        roomHistoryCost = traversalCost(context, "sideRoom", "roomHistoryCost", 0),
    })
    emitPylonRestore(context, selectedRow, sideRoom)
end

local function emitHubReturn(context, selectedRow)
    emitPhysical(context, {
        rowIndex = selectedRow.rowIndex,
        routeOrdinal = selectedRow.routeOrdinal,
        eventKey = context.hub.roomKey,
        groupKey = "HubReturn",
        eventSourceKind = "hubReturn",
        roomKey = context.hub.roomKey,
        roleKey = "Hub",
        source = selectedRow,
        formAddress = formAddress.child(selectedRow.rowIndex, "hubReturn"),
        topology = hubTopologySummary(context.hub),
        attachReward = false,
        attachCurrentRoomCandidates = false,
        biomeDepthCacheCost = traversalCost(context, "hubReturn", "biomeDepthCacheCost", 1),
        biomeEncounterDepthCost = traversalCost(context, "hubReturn", "biomeEncounterDepthCost", 0),
        roomHistoryCost = traversalCost(context, "hubReturn", "roomHistoryCost", 0),
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
        eventSourceKind = "row",
        roomKey = selectedRow.roomKey,
        roleKey = selectedRow.roleKey,
        optionKey = selectedRow.optionKey,
        variantKey = selectedRow.variantKey,
        role = role,
        option = option,
        rewardContext = rewardContextValue,
        source = selectedRow,
        reward = selectedRewardSummary(rewardContextValue, selectedRow.rewards),
        topology = pylonTopologySummary(context, selectedRow, rewardContextValue),
        biomeDepthCacheCost = traversalCost(context, "pylonEntry", "biomeDepthCacheCost", 1),
        roomHistoryCost = traversalCost(context, "pylonEntry", "roomHistoryCost", 0),
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

local function selectedRowFromNode(node)
    local currentRoom = node and node.currentRoom or nil
    if currentRoom == nil then
        return nil
    end
    return {
        rowIndex = node.rowIndex,
        formAddress = currentRoom.formAddress,
        routeOrdinal = node.routeOrdinal,
        slotKind = node.slotKind,
        slotLabel = node.slotLabel,
        isBiomeEntry = node.isBiomeEntry,
        roleKey = currentRoom.roleKey,
        optionKey = currentRoom.optionKey,
        variantKey = currentRoom.variantKey,
        roomKey = currentRoom.roomKey,
        hubDoorId = currentRoom.hubDoorId,
        sideRooms = node.sideRooms,
        topology = node.topology,
        rewards = node.rewards,
    }
end

local function buildContext(args)
    return {
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
end

local function buildRows(context, rows, slots)
    context.generatedHubDoors = generatedHubDoors(context, slots, rows)
    for index, selectedRow in ipairs(rows or EMPTY_LIST) do
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

local function buildFromNodes(args, context, slots)
    local rows = {}
    for index, node in ipairs(args.snapshot.nodes or EMPTY_LIST) do
        rows[index] = selectedRowFromNode(node)
    end
    buildRows(context, rows, slots)
end

function hubPylon.build(args)
    local context = buildContext(args)
    local slots = buildSlots(args.biome)
    if args.snapshot.schema == "selectedNodes.v1" then
        buildFromNodes(args, context, slots)
    else
        buildRows(context, args.snapshot.rows, slots)
    end
end

return hubPylon
