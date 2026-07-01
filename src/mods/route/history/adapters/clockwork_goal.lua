local deps = ... or {}

local clockworkGoal = {}
local routeStep = deps.step

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

local function routeStartOrdinal(slotLayout)
    return math.floor(tonumber(slotLayout and slotLayout.routeStartOrdinal or 1) or 1)
end

local function routeEndOrdinal(slotLayout, startOrdinal)
    return math.floor(tonumber(slotLayout and slotLayout.routeEndOrdinal or startOrdinal) or startOrdinal)
end

local function fixedRoomKey(entry)
    return entry and (entry.roomKey or entry.room and entry.room.key) or nil
end

local function buildSlots(biome)
    local slots = {}
    local slotLayout = biome and biome.slotLayout or {}
    for _, entry in ipairs(slotLayout.fixedBeforeRoute or EMPTY_LIST) do
        slots[#slots + 1] = {
            kind = entry.kind or "fixedBeforeRoute",
            routeOrdinal = entry.routeOrdinal,
            entry = entry,
            role = entry,
        }
    end
    local startOrdinal = routeStartOrdinal(slotLayout)
    for ordinal = startOrdinal, routeEndOrdinal(slotLayout, startOrdinal) do
        slots[#slots + 1] = {
            kind = "biomeRow",
            routeOrdinal = ordinal,
        }
    end
    for _, entry in ipairs(slotLayout.fixedAfterGoals or EMPTY_LIST) do
        slots[#slots + 1] = {
            kind = "preboss",
            routeOrdinal = entry.routeOrdinal,
            entry = entry,
            role = entry,
        }
    end
    return slots
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

local function defaultOption(role)
    return roleOptionList(role)[1]
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
    return defaultOption(role)
end

local function roomKeyFor(role, option)
    return option and option.key
        or role and role.roomKey
        or role and role.room and role.room.key
        or nil
end

local function eventKeyFor(selectedRow, role, option)
    return roomKeyFor(role, option)
        or role and role.key
        or selectedRow.roleKey
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

local function selectedRewardSummary(context, rewards)
    if context == nil or context.kind == nil or context.kind == "none" then
        return nil
    elseif context.kind == "roomStore" then
        return selectedRoomStoreReward(context, rewards)
    elseif context.kind == "shop" then
        return {
            kind = "shop",
            shopProfile = context.shopProfile,
            effectTiming = context.rewardGeneration and context.rewardGeneration.effectTiming or nil,
        }
    end
    return {
        kind = context.kind,
    }
end

local function costValue(_, role, option, field, fallback)
    if option ~= nil and option[field] ~= nil then
        return numericCost(option[field], fallback)
    end
    if role ~= nil and role[field] ~= nil then
        return numericCost(role[field], fallback)
    end
    return fallback
end

local function resolveRow(context, selectedRow, slot)
    local role = roleForRow(context.biome, slot, selectedRow)
    local option = optionForRow(role, selectedRow, slot)
    local slotLayout = context.biome.slotLayout or {}
    local biomeDepthCacheCost = costValue(slotLayout, role, option, "biomeDepthCacheCost", 0)
    if selectedRow.roleKey ~= "Intro"
        and selectedRow.roleKey ~= "Preboss"
        and role ~= nil
        and role.kind == nil
        and slot ~= nil
        and slot.kind == "biomeRow"
    then
        biomeDepthCacheCost = numericCost(slotLayout.routeRow and slotLayout.routeRow.biomeDepthCacheCost, 0)
    end
    return {
        slot = slot,
        role = role,
        option = option,
        routeOrdinal = slot and slot.routeOrdinal or nil,
        roomKey = roomKeyFor(role, option),
        eventKey = eventKeyFor(selectedRow, role, option),
        rewardContext = rewardContext(role, option),
        biomeDepthCacheCost = biomeDepthCacheCost,
        biomeEncounterDepthCost = costValue(slotLayout, role, option, "biomeEncounterDepthCost", 0),
        roomHistoryCost = costValue(slotLayout, role, option, "roomHistoryCost", 0),
    }
end

local function selectedTopology(selectedRow, resolved)
    if selectedRow == nil or resolved == nil then
        return nil
    end
    if selectedRow.roleKey == "GoalCombat" then
        return {
            structure = "GoalCombat",
            roomKey = resolved.roomKey,
            isClockworkGoal = true,
            sameExitRewardCount = 0,
        }
    elseif selectedRow.roleKey == "RewardCombat" then
        return {
            structure = "RewardCombat",
            roomKey = resolved.roomKey,
            rewardStore = "TartarusRewards",
            ineligibleRewardTypes = { "Boon" },
            sameExitRewardCount = 1,
            rewardAddresses = { "row" },
        }
    elseif selectedRow.roleKey == "Story" then
        return {
            structure = "Story",
            roomKey = resolved.roomKey,
            sameExitRewardCount = 0,
        }
    elseif selectedRow.roleKey == "Fountain" then
        return {
            structure = "Fountain",
            roomKey = resolved.roomKey,
            rewardStore = "TartarusRewards",
            ineligibleRewardTypes = { "Devotion" },
            sameExitRewardCount = 1,
            rewardAddresses = { "row" },
        }
    elseif selectedRow.roleKey == "Miniboss" then
        return {
            structure = "Miniboss",
            roomKey = resolved.roomKey,
            rewardStore = "RunProgress",
            eligibleRewardTypes = { "Boon" },
            sameExitRewardCount = 1,
            rewardAddresses = { "row" },
        }
    elseif selectedRow.roleKey == "Preboss" then
        return {
            structure = "Preboss",
            sameExitRewardCount = 0,
        }
    end
    return nil
end

local function siblingPolicyOption(biome, structureKey)
    local optionsByKey = biome
        and biome.roomTopology
        and biome.roomTopology.siblingStructureControl
        and biome.roomTopology.siblingStructureControl.optionsByKey
    if optionsByKey ~= nil then
        return optionsByKey[structureKey]
    end
    for _, option in ipairs(
        biome
            and biome.roomTopology
            and biome.roomTopology.siblingStructureControl
            and biome.roomTopology.siblingStructureControl.options
            or EMPTY_LIST
    ) do
        if option.key == structureKey then
            return option
        end
    end
    return nil
end

local function siblingTopology(context, selectedRow)
    local structureKey = selectedRow
        and selectedRow.topology
        and selectedRow.topology.siblings
        and selectedRow.topology.siblings[1]
        and selectedRow.topology.siblings[1].structureKey
        or nil
    if structureKey == nil or structureKey == "" then
        return nil
    end
    local option = siblingPolicyOption(context.biome, structureKey)
    if option == nil or option.key == "" then
        return nil
    end
    return {
        key = option.key,
        structure = option.structure,
        roomKey = option.roomKey,
        rewardStore = option.rewardStore,
        isClockworkGoal = option.isClockworkGoal,
        isPreboss = option.isPreboss,
        eligibleRewardTypes = copyList(option.eligibleRewardTypes),
        ineligibleRewardTypes = copyList(option.ineligibleRewardTypes),
        sameExitRewardCount = option.sameExitRewardCount,
    }
end

local function attachClockworkTopology(context, roomEntry, selectedRow, pickedRow, pickedResolved)
    if roomEntry == nil then
        return
    end
    local sibling = siblingTopology(context, selectedRow)
    local selected = selectedTopology(pickedRow, pickedResolved)
    if selected == nil then
        return
    end
    roomEntry.topology = {
        kind = "clockworkSiblingChoice",
        selected = selected,
        sibling = sibling,
        siblings = sibling ~= nil and { sibling } or nil,
    }
end

local function shouldEmit(selectedRow)
    return selectedRow.roleKey ~= nil
        and selectedRow.roleKey ~= ""
end

local function rowActive(snapshot, rowIndex)
    local inactiveAfterRowIndex = snapshot and snapshot.inactiveAfterRowIndex or nil
    return inactiveAfterRowIndex == nil
        or rowIndex == nil
        or rowIndex <= inactiveAfterRowIndex
end

function clockworkGoal.build(args)
    local context = {
        routeKey = args.route and args.route.key or args.snapshot.routeKey,
        routeBiomeIndex = args.routeBiomeIndex,
        history = args.history,
        routeHistory = args.routeHistory,
        snapshot = args.snapshot,
        biome = args.biome,
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
    local resolvedRows = {}
    for index, selectedRow in ipairs(args.snapshot.rows or EMPTY_LIST) do
        if rowActive(args.snapshot, index) then
            resolvedRows[index] = resolveRow(context, selectedRow, slots[index])
        end
    end

    for index, selectedRow in ipairs(args.snapshot.rows or EMPTY_LIST) do
        local resolved = resolvedRows[index]
        if rowActive(args.snapshot, index) and shouldEmit(selectedRow) then
            local nextRow = args.snapshot.rows[index + 1]
            local nextResolved = resolvedRows[index + 1]
            routeStep.stepRoom(context, selectedRow, resolved, {
                nextRow = nextRow,
                nextResolved = nextResolved,
                reward = selectedRewardSummary(resolved.rewardContext, selectedRow.rewards),
                attachTopology = function(roomEntry)
                    attachClockworkTopology(context, roomEntry, selectedRow, nextRow, nextResolved)
                end,
            })
        end
    end
end

return clockworkGoal
