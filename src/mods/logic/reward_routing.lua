local deps = ...
local routePlan = deps.routePlan
local runState = deps.runState
local game = deps.game or {}

local rewardRouting = {}
local EMPTY_LIST = {}
local ROW_REWARD_BIOMES = {
    F = true,
    G = true,
    H = true,
    I = true,
    N = true,
    O = true,
    P = true,
    Q = true,
}

local function fieldValue(value)
    if value == nil or value == "" then
        return "-"
    end
    return tostring(value)
end

local function joinList(source)
    local values = {}
    for index, value in ipairs(source or EMPTY_LIST) do
        values[index] = tostring(value)
    end
    return table.concat(values, ",")
end

local function debugLog(message)
    local printer = game.print or _G.print
    local text = "[RunPlanner] reward_routing: " .. tostring(message)
    if type(printer) == "function" then
        printer(text)
    end
end

local function rewardItemSummary(item)
    local kind = item.kind or "vanilla"
    local rewards = joinList(item.rewards)
    if rewards ~= "" then
        return fieldValue(item.address) .. "=" .. kind .. ":" .. rewards
    end

    local loot = joinList(item.loot)
    if loot ~= "" then
        return fieldValue(item.address) .. "=" .. kind .. ":loot=" .. loot
    end

    local picks = {}
    for index, pick in ipairs(item.picks or EMPTY_LIST) do
        picks[index] = tostring(pick.alias or pick.key or index) .. "=" .. tostring(pick.value)
    end
    if picks[1] ~= nil then
        return fieldValue(item.address) .. "=" .. kind .. ":picks=" .. table.concat(picks, ",")
    end

    return fieldValue(item.address) .. "=" .. kind
end

local function rewardItemsSummary(row)
    if row == nil or row.rewardItems == nil or row.rewardItems[1] == nil then
        return "none"
    end

    local parts = {}
    for index, item in ipairs(row.rewardItems) do
        parts[index] = rewardItemSummary(item)
    end
    return table.concat(parts, ";")
end

local function rewardValue(item, index)
    local value = item and item.rewards and item.rewards[index] or nil
    if value == nil or value == "" then
        return nil
    end
    return value
end

local function pickValue(item, key)
    for _, pick in ipairs(item and item.picks or EMPTY_LIST) do
        if pick.key == key then
            return pick.value
        end
    end
    return nil
end

local function pickRewardStore(item, key)
    for _, pick in ipairs(item and item.picks or EMPTY_LIST) do
        if pick.key == key and pick.rewardStore ~= nil and pick.rewardStore ~= "" then
            return pick.rewardStore
        end
    end
    return nil
end

local function planFromRuntime(runtime)
    local state = routePlan.get(runtime)
    if state == nil or state.active ~= true or state.valid ~= true then
        return nil
    end
    local plan = state.executionPlan
    if plan == nil or plan.layers == nil or plan.layers.rewards ~= true then
        return nil
    end
    return plan
end

local function roomName(room)
    return runState.roomName(room)
end

local function rowFromDepthBucket(biomePlan, roomKey, biomeDepthCache)
    local bucket = biomePlan.plannedByBiomeDepthCache[biomeDepthCache]
    local roomBucket = bucket and bucket.byRoomKey and bucket.byRoomKey[roomKey] or nil
    if roomBucket ~= nil then
        return roomBucket.primary, "depth-room"
    end
    if bucket ~= nil and bucket.primary ~= nil and bucket.primary.roomKey == roomKey then
        return bucket.primary, "depth-primary"
    end
    return nil
end

local function rowFromRoomBucket(biomePlan, roomKey)
    local bucket = biomePlan.plannedByRoomKey and biomePlan.plannedByRoomKey[roomKey] or nil
    if bucket == nil then
        return nil
    end
    return bucket.primary, "room"
end

local function isRowRewardBiome(biomeKey)
    return ROW_REWARD_BIOMES[biomeKey] == true
end

local function isEphyraSideRoom(room)
    local roomSetName = runState.roomSetName(room)
    if roomSetName == "N_SubRooms" then
        return true
    end
    local key = roomName(room)
    return type(key) == "string" and string.sub(key, 1, 5) == "N_Sub"
end

function rewardRouting.plannedRewardRow(runtime, currentRun, room)
    local plan = planFromRuntime(runtime)
    local biomeKey = runState.currentBiomeKey(currentRun, nil, room)
    local roomKey = roomName(room)
    if plan == nil then
        return nil, {
            active = false,
            biomeKey = biomeKey,
            roomKey = roomKey,
        }
    end

    local biomePlan = plan.biomes and plan.biomes[biomeKey] or nil
    if biomePlan == nil or roomKey == nil or roomKey == "" then
        return nil, {
            active = true,
            biomeKey = biomeKey,
            roomKey = roomKey,
        }
    end

    local biomeDepthCache = runState.biomeDepthCache(currentRun)
    local row, source = rowFromDepthBucket(biomePlan, roomKey, biomeDepthCache)
    if row ~= nil then
        return row, {
            active = true,
            biomeKey = biomeKey,
            roomKey = roomKey,
            biomeDepthCache = biomeDepthCache,
            source = source,
        }
    end

    row, source = rowFromRoomBucket(biomePlan, roomKey)
    return row, {
        active = true,
        biomeKey = biomeKey,
        roomKey = roomKey,
        biomeDepthCache = biomeDepthCache,
        source = source,
    }
end

local function plannedEphyraParentRow(runtime, currentRun)
    local plan = planFromRuntime(runtime)
    local biomePlan = plan and plan.biomes and plan.biomes.N or nil
    local parentRoom = currentRun and currentRun.CurrentRoom or nil
    local parentRoomKey = roomName(parentRoom)
    if plan == nil then
        return nil, {
            active = false,
            biomeKey = "N",
            roomKey = parentRoomKey,
        }
    end
    if biomePlan == nil or parentRoomKey == nil or parentRoomKey == "" then
        return nil, {
            active = true,
            biomeKey = "N",
            roomKey = parentRoomKey,
        }
    end

    local biomeDepthCache = runState.biomeDepthCache(currentRun)
    local row, source = rowFromDepthBucket(biomePlan, parentRoomKey, biomeDepthCache)
    if row == nil then
        row, source = rowFromRoomBucket(biomePlan, parentRoomKey)
    end
    return row, {
        active = true,
        biomeKey = "N",
        roomKey = parentRoomKey,
        biomeDepthCache = biomeDepthCache,
        source = source,
    }
end

local function sideRewardAddress(row, room, args)
    local doorId = args and args.Door and args.Door.ObjectId or nil
    local sideRoomKey = roomName(room)
    for _, sideRoom in ipairs(row and row.sideRooms or EMPTY_LIST) do
        if sideRoom.enabled == true
            and sideRoom.doorId == doorId
            and sideRoom.roomKey == sideRoomKey
        then
            return "side:" .. tostring(sideRoom.sideIndex), sideRoom
        end
    end
    return nil
end

local function plannedEphyraSideRewardRow(runtime, currentRun, room, args)
    if not isEphyraSideRoom(room) then
        return nil, nil
    end

    local row, context = plannedEphyraParentRow(runtime, currentRun)
    context.sideReward = true
    context.sideRoomKey = roomName(room)
    local address, sideRoom = sideRewardAddress(row, room, args)
    if address ~= nil then
        context.rewardAddress = address
        context.sideIndex = sideRoom.sideIndex
        context.sideDoorId = sideRoom.doorId
        context.source = "side-door"
    end
    return row, context
end

local function plannedRewardItem(row, address)
    for _, item in ipairs(row and row.rewardItems or EMPTY_LIST) do
        if item.valid ~= false then
            local matchesAddress = (
                address == nil
                    and (item.address == nil or item.address == "row")
                    and (item.sourceKind == nil or item.sourceKind == "row")
            ) or (
                address ~= nil and item.address == address
            )
            if matchesAddress
                and item.kind ~= "none"
                and item.kind ~= "vanilla"
                and item.kind ~= "shop"
                and item.kind ~= "fieldsCages"
            then
                return item
            end
        end
    end
    return nil
end

local function rewardListEmpty(rewards)
    return rewards == nil or rewards[1] == nil
end

local function currentEncounterRewardAddress(currentRun, room)
    local currentRoom = currentRun and currentRun.CurrentRoom or nil
    if currentRoom == nil or room ~= currentRoom then
        return nil
    end

    local encounter = currentRoom.Encounter
    for index, candidate in ipairs(currentRoom.Encounters or EMPTY_LIST) do
        if candidate == encounter then
            local legIndex = index - 1
            if legIndex > 0 then
                return "encounter:" .. tostring(legIndex)
            end
            return nil
        end
    end
    return nil
end

local function fieldsCageSourceCount(item)
    return math.floor(tonumber(item and item.rewardSourceCount) or #(item and item.rewards or EMPTY_LIST))
end

local function fieldsCageRewardIndex(row, room, args)
    if row == nil or row.roleKey ~= "Combat" then
        return nil
    end

    if args ~= nil and args.Door ~= nil then
        return nil
    end

    local cageRewards = room and room.CageRewards
    if cageRewards == nil then
        return nil
    end

    return #cageRewards + 1
end

local function fieldsCageRewardItemForCall(row, room, args)
    local sourceIndex = fieldsCageRewardIndex(row, room, args)
    if sourceIndex == nil then
        return nil
    end

    for _, item in ipairs(row.rewardItems or EMPTY_LIST) do
        if item.valid ~= false and item.kind == "fieldsCages" and sourceIndex <= fieldsCageSourceCount(item) then
            local rewardType = rewardValue(item, sourceIndex)
            if rewardType ~= nil then
                return {
                    kind = "roomStore",
                    address = "cage:" .. tostring(sourceIndex),
                    rewards = {
                        rewardType,
                        item.loot and item.loot[sourceIndex] or nil,
                    },
                    picks = EMPTY_LIST,
                    rewardStore = item.rewardStore,
                    valid = true,
                }
            end
        end
    end
    return nil
end

local function tartarusRewardApplies(row, previouslyChosenRewards, phase)
    if phase == "store" then
        return true
    end

    local firstReward = rewardListEmpty(previouslyChosenRewards)
    if row and row.roleKey == "Goal" then
        return firstReward
    elseif row and row.roleKey == "ExtensionCombat" then
        return not firstReward
    end
    return true
end

local function plannedRewardItemForCall(row, context, currentRun, room, previouslyChosenRewards, phase, args)
    if context.sideReward == true then
        if context.rewardAddress == nil then
            return nil
        end
        return plannedRewardItem(row, context.rewardAddress)
    end

    if context.rewardAddress ~= nil then
        return plannedRewardItem(row, context.rewardAddress)
    end

    if context.biomeKey == "H" then
        local item = fieldsCageRewardItemForCall(row, room, args)
        if item ~= nil then
            return item
        end
    end

    if context.biomeKey == "O" then
        local address = currentEncounterRewardAddress(currentRun, room)
        if address ~= nil then
            if phase ~= "store" and not rewardListEmpty(previouslyChosenRewards) then
                return nil
            end
            return plannedRewardItem(row, address)
        end
    end

    if context.biomeKey == "I" and not tartarusRewardApplies(row, previouslyChosenRewards, phase) then
        return nil
    end

    return plannedRewardItem(row)
end

local function boonSourceForItem(item, rewardType)
    if rewardType ~= "Boon" then
        return nil
    end

    if item.kind == "boonSource" then
        return pickValue(item, "boonSource") or rewardValue(item, 1)
    elseif item.kind == "roomStore" then
        return pickValue(item, "boonSource") or rewardValue(item, 2)
    elseif item.kind == "majorMinor" then
        return pickValue(item, "boonSource") or rewardValue(item, 3)
    end
    return nil
end

local function devotionSourcesForItem(item, rewardType)
    if rewardType ~= "Devotion" then
        return nil, nil
    end

    if item.kind == "devotionPair" then
        return pickValue(item, "lootAName") or rewardValue(item, 1),
            pickValue(item, "lootBName") or rewardValue(item, 2)
    elseif item.kind == "roomStore" then
        return pickValue(item, "lootAName") or rewardValue(item, 3),
            pickValue(item, "lootBName") or rewardValue(item, 4)
    elseif item.kind == "majorMinor" then
        return pickValue(item, "lootAName") or rewardValue(item, 5),
            pickValue(item, "lootBName") or rewardValue(item, 6)
    end
    return nil, nil
end

local function rewardStoreForItem(item, _rewardType)
    if item.kind == "majorMinor" then
        local branch = rewardValue(item, 1)
        if branch == "Major" then
            return pickRewardStore(item, "rewardType") or "RunProgress"
        elseif branch == "Minor" then
            return pickRewardStore(item, "rewardType") or "MetaProgress"
        end
        return nil
    end
    return item.rewardStore
end

local function rewardTypeForItem(item)
    if item == nil then
        return nil
    end

    if item.kind == "boonSource" then
        return "Boon"
    elseif item.kind == "devotionPair" then
        return "Devotion"
    elseif item.kind == "fixedReward" then
        return item.fixedRewardType or rewardValue(item, 1)
    elseif item.kind == "roomStore" then
        return pickValue(item, "rewardType") or rewardValue(item, 1)
    elseif item.kind == "majorMinor" then
        local branch = rewardValue(item, 1)
        if branch == "Major" then
            return pickValue(item, "rewardType") or rewardValue(item, 2)
        elseif branch == "Minor" then
            return pickValue(item, "rewardType") or rewardValue(item, 4)
        end
    end
    return nil
end

local function plannedReward(runtime, currentRun, room, previouslyChosenRewards, phase, args)
    local row, context = plannedEphyraSideRewardRow(runtime, currentRun, room, args)
    if context == nil then
        row, context = rewardRouting.plannedRewardRow(runtime, currentRun, room)
    end
    if context.active ~= true or not isRowRewardBiome(context.biomeKey) then
        return nil, row, context
    end

    local item = plannedRewardItemForCall(row, context, currentRun, room, previouslyChosenRewards, phase, args)
    local rewardType = rewardTypeForItem(item)
    if rewardType == nil or rewardType == "" then
        return nil, row, context
    end

    local planned = {
        item = item,
        rewardType = rewardType,
        rewardStore = rewardStoreForItem(item, rewardType),
        boonSource = boonSourceForItem(item, rewardType),
    }
    planned.devotionSourceA, planned.devotionSourceB = devotionSourcesForItem(item, rewardType)
    return planned, row, context
end

local function plannedNextReward(runtime, currentRun)
    local plan = planFromRuntime(runtime)
    local biomeKey = runState.currentBiomeKey(currentRun)
    if plan == nil or not isRowRewardBiome(biomeKey) then
        return nil, nil, {
            active = plan ~= nil,
            biomeKey = biomeKey,
        }
    end

    if biomeKey == "O" then
        local row, context = rewardRouting.plannedRewardRow(runtime, currentRun, currentRun and currentRun.CurrentRoom or nil)
        local item = plannedRewardItemForCall(row, context, currentRun, currentRun and currentRun.CurrentRoom or nil, nil, "store")
        local rewardType = rewardTypeForItem(item)
        if rewardType ~= nil and rewardType ~= "" then
            return {
                item = item,
                rewardType = rewardType,
                rewardStore = rewardStoreForItem(item, rewardType),
            }, row, context
        end
    end

    local biomePlan = plan.biomes and plan.biomes[biomeKey] or nil
    local bucket = biomePlan
        and biomePlan.plannedRoutableByBiomeDepthCache
        and biomePlan.plannedRoutableByBiomeDepthCache[runState.biomeDepthCache(currentRun)]
        or nil
    local row = bucket and bucket.primary or nil
    local item = plannedRewardItem(row)
    local rewardType = rewardTypeForItem(item)
    if rewardType == nil or rewardType == "" then
        return nil, row, {
            active = true,
            biomeKey = biomeKey,
            biomeDepthCache = runState.biomeDepthCache(currentRun),
        }
    end
    return {
        item = item,
        rewardType = rewardType,
        rewardStore = rewardStoreForItem(item, rewardType),
    }, row, {
        active = true,
        biomeKey = biomeKey,
        biomeDepthCache = runState.biomeDepthCache(currentRun),
    }
end

local function removeInjectedPriority(priorities, rewardType)
    if priorities[1] == rewardType then
        table.remove(priorities, 1)
    end
end

local function withRewardPriority(currentRun, rewardType, callback)
    local run = runState.currentRun(currentRun)
    local priorities = run.RewardPriorities
    table.insert(priorities, 1, rewardType)
    local reward = callback()
    removeInjectedPriority(priorities, rewardType)
    return reward
end

local function rewardChoiceDetail(row, context, rewardStoreName, actualRewardType)
    if context.active ~= true then
        return nil
    end
    return "choose set=" .. fieldValue(context.biomeKey)
        .. " room=" .. fieldValue(context.roomKey)
        .. " biomeDepthCache=" .. fieldValue(context.biomeDepthCache)
        .. " store=" .. fieldValue(rewardStoreName)
        .. " match=" .. fieldValue(context.source)
        .. " row=" .. fieldValue(row and row.rowIndex)
        .. " plannedRewards=" .. rewardItemsSummary(row)
        .. " actual=" .. fieldValue(actualRewardType)
end

local function forcedRewardChoiceDetail(row, context, rewardStoreName, planned, actualRewardType)
    if context.active ~= true then
        return nil
    end
    local result = actualRewardType == planned.rewardType and "forced" or "vanilla"
    return "choose set=" .. fieldValue(context.biomeKey)
        .. " room=" .. fieldValue(context.roomKey)
        .. " biomeDepthCache=" .. fieldValue(context.biomeDepthCache)
        .. " store=" .. fieldValue(rewardStoreName)
        .. " match=" .. fieldValue(context.source)
        .. " row=" .. fieldValue(row and row.rowIndex)
        .. " planned=" .. fieldValue(planned.rewardType)
        .. " plannedStore=" .. fieldValue(planned.rewardStore)
        .. " actual=" .. fieldValue(actualRewardType)
        .. " action=" .. result
end

local function setupRewardDetail(row, context, room, actualRewardType)
    if context.active ~= true then
        return nil
    end
    return "setup set=" .. fieldValue(context.biomeKey)
        .. " room=" .. fieldValue(context.roomKey)
        .. " biomeDepthCache=" .. fieldValue(context.biomeDepthCache)
        .. " match=" .. fieldValue(context.source)
        .. " row=" .. fieldValue(row and row.rowIndex)
        .. " plannedRewards=" .. rewardItemsSummary(row)
        .. " chosen=" .. fieldValue(actualRewardType)
        .. " loot=" .. fieldValue(room and room.ForceLootName)
end

function rewardRouting.chooseRoomReward(runtime, base, currentRun, room, rewardStoreName, previouslyChosenRewards, args)
    local planned, row, context = plannedReward(runtime, currentRun, room, previouslyChosenRewards, "choose", args)
    local rewardType
    local detail
    if planned ~= nil then
        rewardType = withRewardPriority(currentRun, planned.rewardType, function()
            return base(currentRun, room, rewardStoreName, previouslyChosenRewards, args)
        end)
        if rewardType == planned.rewardType and rewardType == "Boon" and planned.boonSource ~= nil then
            room.ForceLootName = planned.boonSource
        end
        detail = forcedRewardChoiceDetail(row, context, rewardStoreName, planned, rewardType)
    else
        rewardType = base(currentRun, room, rewardStoreName, previouslyChosenRewards, args)
        detail = rewardChoiceDetail(row, context, rewardStoreName, rewardType)
    end
    if detail ~= nil then
        debugLog(detail)
    end
    return rewardType
end

function rewardRouting.setupRoomReward(runtime, base, currentRun, room, previouslyChosenRewards, args)
    local planned, row, context = plannedReward(runtime, currentRun, room, previouslyChosenRewards, "setup", args)
    local rewardType = args and args.ChosenRewardType or room and room.ChosenRewardType or nil
    if planned ~= nil
        and rewardType == "Boon"
        and planned.rewardType == "Boon"
        and planned.boonSource ~= nil
    then
        room.ForceLootName = planned.boonSource
    end

    local result = base(currentRun, room, previouslyChosenRewards, args)
    if planned ~= nil
        and rewardType == "Devotion"
        and planned.rewardType == "Devotion"
        and room.Encounter ~= nil
    then
        room.Encounter.LootAName = planned.devotionSourceA or room.Encounter.LootAName
        room.Encounter.LootBName = planned.devotionSourceB or room.Encounter.LootBName
    end
    local detail = setupRewardDetail(row, context, room, rewardType)
    if detail ~= nil then
        debugLog(detail)
    end
    return result
end

function rewardRouting.chooseNextRewardStore(runtime, base, currentRun)
    local planned, row, context = plannedNextReward(runtime, currentRun)
    local plannedStore = planned and planned.rewardStore or nil
    if plannedStore == "RunProgress" or plannedStore == "MetaProgress" then
        currentRun.NextRewardStoreName = plannedStore
        debugLog("store set=" .. fieldValue(context.biomeKey)
            .. " biomeDepthCache=" .. fieldValue(context.biomeDepthCache)
            .. " row=" .. fieldValue(row and row.rowIndex)
            .. " planned=" .. fieldValue(planned.rewardType)
            .. " forced=" .. plannedStore)
        return plannedStore
    end

    local rewardStore = base(currentRun)
    if context.active == true then
        debugLog("store set=" .. fieldValue(context.biomeKey)
            .. " biomeDepthCache=" .. fieldValue(context.biomeDepthCache)
            .. " row=" .. fieldValue(row and row.rowIndex)
            .. " planned=" .. fieldValue(planned and planned.rewardType)
            .. " vanilla=" .. fieldValue(rewardStore))
    end
    return rewardStore
end

function rewardRouting.registerHooks(moduleRef)
    moduleRef.hooks.wrap("ChooseNextRewardStore", function(host, runtime, base, currentRun)
        if host ~= nil and host.isEnabled ~= nil and not host.isEnabled() then
            return base(currentRun)
        end

        return rewardRouting.chooseNextRewardStore(runtime, base, currentRun)
    end)

    moduleRef.hooks.wrap("ChooseRoomReward", function(host, runtime, base, currentRun, room, rewardStoreName, previouslyChosenRewards, args)
        if host ~= nil and host.isEnabled ~= nil and not host.isEnabled() then
            return base(currentRun, room, rewardStoreName, previouslyChosenRewards, args)
        end

        return rewardRouting.chooseRoomReward(runtime, base, currentRun, room, rewardStoreName, previouslyChosenRewards, args)
    end)

    moduleRef.hooks.wrap("SetupRoomReward", function(host, runtime, base, currentRun, room, previouslyChosenRewards, args)
        if host ~= nil and host.isEnabled ~= nil and not host.isEnabled() then
            return base(currentRun, room, previouslyChosenRewards, args)
        end

        return rewardRouting.setupRoomReward(runtime, base, currentRun, room, previouslyChosenRewards, args)
    end)
end

return rewardRouting
