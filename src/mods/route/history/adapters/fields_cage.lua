local deps = ... or {}

local fieldsCage = {}
local materializeRoom = deps.materializeRoom

local EMPTY_LIST = {}
local BIOME_ENCOUNTER_DEPTH_START = 0
local PREBOSS_SHOP_BRANCH = "Shop"
local PREBOSS_FREE_REWARD_BRANCH = "FreeReward"
local SHOP_BOUGHT_VALUE = "Bought"

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
    for _, entry in ipairs(slotLayout.fixedAfterRoute or EMPTY_LIST) do
        slots[#slots + 1] = {
            kind = entry.kind or "fixedAfterRoute",
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

local function roomKeyFor(role, option)
    return option and option.key
        or role and role.roomKey
        or role and role.room and role.room.key
        or nil
end

local function eventKeyFor(_selectedRow, role, option)
    local roomKey = roomKeyFor(role, option)
    if roomKey ~= nil and roomKey ~= "" then
        return roomKey
    end
    if role ~= nil and roleOptionList(role)[1] == nil then
        return role.key
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
    }
end

local function selectedFieldsCageRewards(context, rewards, sameExitRewardCount)
    local values = rewards and rewards.row and rewards.row.values or EMPTY_LIST
    local loot = rewards and rewards.row and rewards.row.loot or EMPTY_LIST
    local picks = {}
    for index = 1, sameExitRewardCount do
        picks[index] = {
            rewardType = values[index] ~= "" and values[index] or nil,
            boonSource = values[index] == "Boon" and loot[index] or nil,
            controlAlias = "Reward" .. tostring(index) .. "Key",
        }
    end
    return {
        kind = "fieldsCages",
        rewardStore = context.rewardStore,
        sameExitRewardCount = sameExitRewardCount,
        picks = picks,
    }
end

local function rewardAddresses(count)
    local addresses = {}
    for index = 1, count do
        addresses[index] = "cage:" .. tostring(index)
    end
    return addresses
end

local function prebossOfferByKind(context, kind)
    for _, offer in ipairs(context.offers or EMPTY_LIST) do
        if offer.kind == kind then
            return offer
        end
    end
    return nil
end

local function roomStoreOfferSummary(offer, rewardType, boonSource)
    if offer == nil then
        return nil
    end
    local rewardAliasStart = math.floor(tonumber(offer.rewardAliasStart) or 1)
    return {
        kind = "roomStore",
        address = offer.address,
        rewardStore = offer.rewardStore,
        sameExitRewardCount = offer.sameExitRewardCount,
        controlAlias = "Reward" .. tostring(rewardAliasStart) .. "Key",
        rewardType = rewardType ~= "" and rewardType or nil,
        boonSource = rewardType == "Boon" and boonSource or nil,
        eligibleRewardTypes = copyList(offer.eligibleRewardTypes),
        ineligibleRewardTypes = copyList(offer.ineligibleRewardTypes),
    }
end

local function shopOfferSummary(offer)
    if offer == nil then
        return nil
    end
    return {
        kind = "shop",
        address = offer.address,
        shopProfile = offer.shopProfile,
        effectTiming = offer.rewardGeneration and offer.rewardGeneration.effectTiming or nil,
    }
end

local function prebossShopOutcome(context, rewards)
    local offer = prebossOfferByKind(context, "shop")
    local values = rewards and rewards.row and rewards.row.values or EMPTY_LIST
    local loot = rewards and rewards.row and rewards.row.loot or EMPTY_LIST
    local states = rewards and rewards.row and rewards.row.states or EMPTY_LIST
    local offers = {}
    for index = 1, math.floor(tonumber(offer and offer.rewardAliasCount or 0) or 0) do
        offers[index] = {
            rewardType = values[index] ~= "" and values[index] or nil,
            boonSource = loot[index] ~= "" and loot[index] or nil,
            controlAlias = "Reward" .. tostring(index) .. "Key",
            state = states[index] ~= "" and states[index] or nil,
            bought = states[index] == SHOP_BOUGHT_VALUE,
        }
    end
    return {
        kind = "preboss",
        branch = PREBOSS_SHOP_BRANCH,
        shop = shopOfferSummary(offer),
        offers = offers,
    }
end

local function prebossFreeRewardOutcome(context, rewards)
    local offer = prebossOfferByKind(context, "roomStore")
    local values = rewards and rewards.row and rewards.row.values or EMPTY_LIST
    local rewardType = values[offer and offer.rewardAliasStart or 4]
    local boonSource = values[(offer and offer.rewardAliasStart or 4) + 1]
    return {
        kind = "preboss",
        branch = PREBOSS_FREE_REWARD_BRANCH,
        reward = roomStoreOfferSummary(offer, rewardType, boonSource),
    }
end

local function selectedPrebossReward(context, rewards)
    local branchKey = rewards and rewards.row and rewards.row.branchKey or nil
    if branchKey == PREBOSS_SHOP_BRANCH then
        return prebossShopOutcome(context, rewards)
    elseif branchKey == PREBOSS_FREE_REWARD_BRANCH then
        return prebossFreeRewardOutcome(context, rewards)
    end
    return {
        kind = "preboss",
        branch = branchKey ~= "" and branchKey or nil,
    }
end

local function selectedRewardSummary(context, rewards, sameExitRewardCount)
    if context == nil or context.kind == nil or context.kind == "none" then
        return nil
    elseif context.kind == "fieldsCages" then
        return selectedFieldsCageRewards(context, rewards, sameExitRewardCount or 0)
    elseif context.kind == "roomStore" then
        return selectedRoomStoreReward(context, rewards)
    elseif context.kind == "preboss" then
        return selectedPrebossReward(context, rewards)
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

local function cagePolicyForRole(biome, role)
    if role == nil or role.cageRewardPolicy == nil then
        return nil
    end
    local policy = biome.fields and biome.fields.cageRewardPolicy or nil
    if policy ~= nil and policy.key == role.cageRewardPolicy then
        return policy
    end
    return nil
end

local function cageCountOption(biome, role, selectedRow)
    local policy = cagePolicyForRole(biome, role)
    if policy == nil then
        return nil
    end
    for _, option in ipairs(policy.countControl and policy.countControl.options or EMPTY_LIST) do
        if option.key == selectedRow.variantKey then
            return option
        end
    end
    return nil
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

local function biomeDepthCacheCost(slotLayout, slot, role, option)
    if option ~= nil and option.biomeDepthCacheCost ~= nil then
        return numericCost(option.biomeDepthCacheCost, 0)
    end
    if role ~= nil and role.biomeDepthCacheCost ~= nil then
        return numericCost(role.biomeDepthCacheCost, 0)
    end
    if slot ~= nil and slot.kind == "biomeRow" then
        return numericCost(slotLayout and slotLayout.routeRow and slotLayout.routeRow.biomeDepthCacheCost, 0)
    end
    return 0
end

local function resolveRow(context, selectedRow, slot)
    local role = roleForRow(context.biome, slot, selectedRow)
    local option = optionForRow(role, selectedRow, slot)
    local slotLayout = context.biome.slotLayout or {}
    local cageCount = cageCountOption(context.biome, role, selectedRow)
    local sameExitRewardCount = math.floor(tonumber(cageCount and cageCount.cageRewardCount) or 0)

    return {
        slot = slot,
        role = role,
        option = option,
        cageCount = cageCount,
        sameExitRewardCount = sameExitRewardCount,
        routeOrdinal = slot and slot.routeOrdinal or nil,
        roomKey = roomKeyFor(role, option),
        eventKey = eventKeyFor(selectedRow, role, option),
        rewardContext = rewardContext(role, option),
        biomeDepthCacheCost = biomeDepthCacheCost(slotLayout, slot, role, option),
        biomeEncounterDepthCost = costValue(slotLayout, role, option, "biomeEncounterDepthCost", 0),
        roomHistoryCost = costValue(slotLayout, role, option, "roomHistoryCost", 0),
    }
end

local function selectedTopology(selectedRow, resolved)
    if selectedRow.roleKey == "Combat" then
        local count = resolved.sameExitRewardCount
        if count <= 0 then
            return nil
        end
        return {
            structure = "CombatCage" .. tostring(count),
            rewardStore = "RunProgress",
            sameExitRewardCount = count,
            rewardAddresses = rewardAddresses(count),
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
    elseif selectedRow.roleKey == "Bridge" then
        return {
            structure = "Bridge",
            roomKey = resolved.roomKey,
            sameExitRewardCount = 0,
        }
    end
    return nil
end

local function siblingOption(biome, structureKey)
    local optionsByKey = biome
        and biome.fields
        and biome.fields.roomTopology
        and biome.fields.roomTopology.siblingStructureControl
        and biome.fields.roomTopology.siblingStructureControl.optionsByKey
    if optionsByKey ~= nil then
        return optionsByKey[structureKey]
    end
    for _, option in ipairs(
        biome
            and biome.fields
            and biome.fields.roomTopology
            and biome.fields.roomTopology.siblingStructureControl
            and biome.fields.roomTopology.siblingStructureControl.options
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
    local option = siblingOption(context.biome, structureKey)
    if option == nil or option.key == "" then
        return nil
    end
    return {
        structure = option.structure,
        roomKey = option.roomKey,
        rewardStore = option.rewardStore,
        eligibleRewardTypes = copyList(option.eligibleRewardTypes),
        sameExitRewardCount = option.sameExitRewardCount,
    }
end

local function attachFieldsTopology(context, roomEntry, selectedRow, resolved)
    if roomEntry == nil then
        return
    end
    local selected = selectedTopology(selectedRow, resolved)
    local sibling = siblingTopology(context, selectedRow)
    if selected == nil or sibling == nil then
        return
    end
    roomEntry.topology = {
        kind = "fieldsChoice",
        selected = selected,
        sibling = sibling,
    }
end

function fieldsCage.build(args)
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
        resolvedRows[index] = resolveRow(context, selectedRow, slots[index])
    end

    for index, selectedRow in ipairs(args.snapshot.rows or EMPTY_LIST) do
        local resolved = resolvedRows[index]
        materializeRoom.stepRoom(context, selectedRow, resolved, {
            reward = selectedRewardSummary(
                resolved.rewardContext,
                selectedRow.rewards,
                resolved.sameExitRewardCount
            ),
            rewardCandidateOpts = {
                sameExitRewardCount = resolved.sameExitRewardCount,
            },
            attachTopology = function(roomEntry)
                attachFieldsTopology(context, roomEntry, selectedRow, resolved)
            end,
        })
    end
end

return fieldsCage
