local deps = ...
local routePlan = deps.routePlan
local runState = deps.runState
local game = deps.game or {}

local rewardRouting = {}
local EMPTY_LIST = {}

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

local function rewardChoiceDetail(runtime, currentRun, room, rewardStoreName, actualRewardType)
    local row, context = rewardRouting.plannedRewardRow(runtime, currentRun, room)
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

local function setupRewardDetail(runtime, currentRun, room, actualRewardType)
    local row, context = rewardRouting.plannedRewardRow(runtime, currentRun, room)
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
    local rewardType = base(currentRun, room, rewardStoreName, previouslyChosenRewards, args)
    local detail = rewardChoiceDetail(runtime, currentRun, room, rewardStoreName, rewardType)
    if detail ~= nil then
        debugLog(detail)
    end
    return rewardType
end

function rewardRouting.setupRoomReward(runtime, base, currentRun, room, previouslyChosenRewards, args)
    local result = base(currentRun, room, previouslyChosenRewards, args)
    local rewardType = args and args.ChosenRewardType or room and room.ChosenRewardType or nil
    local detail = setupRewardDetail(runtime, currentRun, room, rewardType)
    if detail ~= nil then
        debugLog(detail)
    end
    return result
end

function rewardRouting.registerHooks(moduleRef)
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
