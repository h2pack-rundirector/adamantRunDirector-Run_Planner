local deps = ... or {}

local fixedLinear = {}
local materializeRoom = deps.materializeRoom

local EMPTY_LIST = {}
local BIOME_ENCOUNTER_DEPTH_START = 0
local MAJOR_REWARD_STORE = "RunProgress"
local MINOR_REWARD_STORE = "MetaProgress"
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

local function fixedSpecialByKind(slotLayout, kind)
    for _, special in pairs(slotLayout and slotLayout.special or {}) do
        if special.kind == kind or special.key == kind then
            return special
        end
    end
    return nil
end

local function fixedSpecialOrdinal(slotLayout, key)
    for ordinal, special in pairs(slotLayout and slotLayout.special or {}) do
        if special.kind == key or special.key == key then
            return math.floor(tonumber(ordinal) or 0)
        end
    end
    return nil
end

local function routeStartOrdinal(slotLayout)
    return math.floor(tonumber(slotLayout and slotLayout.routeStartOrdinal or 1) or 1)
end

local function fixedPrefixRowCount(slotLayout)
    local count = 0
    if slotLayout and slotLayout.entry ~= nil then
        count = count + 1
    end
    for ordinal, special in pairs(slotLayout and slotLayout.special or {}) do
        if special.kind == "opening"
            and math.floor(tonumber(ordinal) or 0) < routeStartOrdinal(slotLayout)
        then
            count = count + 1
        end
    end
    return count
end

local function roleForRow(biome, selectedRow)
    local role = biome.rolesByKey and biome.rolesByKey[selectedRow.roleKey] or nil
    if role ~= nil then
        return role
    end

    local entry = biome.slotLayout and biome.slotLayout.entry or nil
    if entry ~= nil and selectedRow.roleKey == (entry.key or "Intro") then
        return entry
    end

    local special = fixedSpecialByKind(biome.slotLayout, selectedRow.roleKey)
    if special ~= nil then
        return special
    end
    return nil
end

local function optionForRow(role, selectedRow)
    return optionByKey(role, selectedRow.optionKey)
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

local function rewardStoreForClass(rewardClass)
    if rewardClass == "Major" then
        return MAJOR_REWARD_STORE
    elseif rewardClass == "Minor" then
        return MINOR_REWARD_STORE
    end
    return nil
end

local function selectedRewardFromMajorMinor(context, rewards)
    local values = rewards and rewards.row and rewards.row.values or EMPTY_LIST
    local rewardClass = values[1]
    if rewardClass == "Major" then
        local rewardType = values[2]
        return {
            kind = "majorMinor",
            rewardClass = rewardClass,
            rewardStore = context.majorRewardStore or MAJOR_REWARD_STORE,
            controlAlias = "Reward2Key",
            rewardType = rewardType ~= "" and rewardType or nil,
            boonSource = rewardType == "Boon" and values[3] or nil,
            devotionSources = rewardType == "Devotion" and { values[5], values[6] } or nil,
        }
    elseif rewardClass == "Minor" then
        local rewardType = values[4]
        return {
            kind = "majorMinor",
            rewardClass = rewardClass,
            rewardStore = context.minorRewardStore or MINOR_REWARD_STORE,
            controlAlias = "Reward4Key",
            rewardType = rewardType ~= "" and rewardType or nil,
        }
    end
    return {
        kind = "majorMinor",
    }
end

local function onlyEligibleRewardType(context)
    local eligible = context and context.eligibleRewardTypes or nil
    if eligible ~= nil and eligible[1] ~= nil and eligible[2] == nil then
        return eligible[1]
    end
    return nil
end

local function selectedRewardFromRoomStore(context, rewards)
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

local function prebossOfferSummaries(context)
    local offers = {}
    for index, offer in ipairs(context.offers or EMPTY_LIST) do
        offers[index] = {
            address = offer.address,
            kind = offer.kind,
            shopProfile = offer.shopProfile,
            rewardStore = offer.rewardStore,
            sameExitRewardCount = offer.sameExitRewardCount,
            requiredBranchValue = offer.requiredBranchValue,
            eligibleRewardTypes = copyList(offer.eligibleRewardTypes),
            ineligibleRewardTypes = copyList(offer.ineligibleRewardTypes),
        }
    end
    return offers
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

local function selectedPrebossRewardSummary(context, rewards)
    local branchKey = rewards and rewards.row and rewards.row.branchKey or nil
    if branchKey == PREBOSS_SHOP_BRANCH then
        return prebossShopOutcome(context, rewards)
    elseif branchKey == PREBOSS_FREE_REWARD_BRANCH then
        return prebossFreeRewardOutcome(context, rewards)
    end
    return {
        kind = "preboss",
        branch = branchKey ~= "" and branchKey or nil,
        offers = prebossOfferSummaries(context),
    }
end

local function selectedRewardSummary(context, rewards)
    if context == nil or context.kind == nil or context.kind == "none" then
        return nil
    elseif context.kind == "majorMinor" then
        return selectedRewardFromMajorMinor(context, rewards)
    elseif context.kind == "roomStore" then
        return selectedRewardFromRoomStore(context, rewards)
    elseif context.kind == "shop" then
        return {
            kind = "shop",
            shopProfile = context.shopProfile,
            effectTiming = context.rewardGeneration and context.rewardGeneration.effectTiming or nil,
        }
    elseif context.kind == "preboss" then
        return selectedPrebossRewardSummary(context, rewards)
    elseif context.kind == "forcedReward" then
        return {
            kind = "forcedReward",
            rewardStore = context.rewardStore,
            rewardType = context.rewardType,
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

local function explicitCostValue(role, option, field)
    if option ~= nil and option[field] ~= nil then
        return numericCost(option[field], 0)
    end
    if role ~= nil and role[field] ~= nil then
        return numericCost(role[field], 0)
    end
    return nil
end

local function selectedRouteOrdinal(slotLayout, selectedRow)
    local entry = slotLayout and slotLayout.entry or nil
    if entry ~= nil and selectedRow.roleKey == (entry.key or "Intro") then
        return entry.routeOrdinal or 0
    end

    local specialOrdinal = fixedSpecialOrdinal(slotLayout, selectedRow.roleKey)
    if specialOrdinal ~= nil then
        return specialOrdinal
    end

    return routeStartOrdinal(slotLayout)
        + (selectedRow.rowIndex or 1)
        - fixedPrefixRowCount(slotLayout)
        - 1
end

local function resolveRow(context, selectedRow)
    local role = roleForRow(context.biome, selectedRow)
    local option = optionForRow(role, selectedRow)
    local slotLayout = context.biome.slotLayout or {}
    local routeOrdinal = selectedRouteOrdinal(slotLayout, selectedRow)
    local biomeDepthCacheCost = costValue(slotLayout, role, option, "biomeDepthCacheCost", 0)
    local biomeEncounterDepthCost = costValue(slotLayout, role, option, "biomeEncounterDepthCost", 0)
    local roomHistoryCost = costValue(slotLayout, role, option, "roomHistoryCost", 0)

    if selectedRow.roleKey ~= "Opening"
        and selectedRow.roleKey ~= "Intro"
        and selectedRow.roleKey ~= "Preboss"
        and role ~= nil
        and role.kind == nil
    then
        biomeDepthCacheCost = explicitCostValue(role, option, "biomeDepthCacheCost")
            or numericCost(slotLayout.routeRow and slotLayout.routeRow.biomeDepthCacheCost, 0)
    end

    return {
        role = role,
        option = option,
        routeOrdinal = routeOrdinal,
        roomKey = roomKeyFor(role, option),
        eventKey = eventKeyFor(selectedRow, role, option),
        rewardContext = rewardContext(role, option),
        biomeDepthCacheCost = biomeDepthCacheCost,
        biomeEncounterDepthCost = biomeEncounterDepthCost,
        roomHistoryCost = roomHistoryCost,
    }
end

local function selectedStructure(selectedRow, resolved)
    local roleKey = selectedRow.roleKey
    local option = resolved.option
    return {
        roleKey = roleKey,
        optionKey = selectedRow.optionKey,
        variantKey = selectedRow.variantKey,
        structure = roleKey,
        roomKey = resolved.roomKey,
        eventKey = resolved.eventKey,
        sameExitRewardCount = option and option.sameExitRewardCount or nil,
    }
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

local function siblingRewardSummary(selectedRow, siblingIndex, option)
    if option == nil or option.sameExitRewardCount == nil or option.sameExitRewardCount <= 0 then
        return nil
    end
    local rewardClass = selectedRow
        and selectedRow.rewards
        and selectedRow.rewards.sibling
        and selectedRow.rewards.sibling[siblingIndex]
        and selectedRow.rewards.sibling[siblingIndex].rewardClassKey
        or nil
    if option.rewardBranch == "majorMinor" then
        return {
            kind = "majorMinor",
            rewardClass = rewardClass ~= "" and rewardClass or nil,
            rewardStore = rewardStoreForClass(rewardClass),
        }
    end
    return {
        rewardStore = option.rewardStore,
        rewardClass = option.rewardClass,
        eligibleRewardTypes = copyList(option.eligibleRewardTypes),
        ineligibleRewardTypes = copyList(option.ineligibleRewardTypes),
    }
end

local function siblingExit(context, selectedRow, siblingIndex, sibling)
    local structureKey = sibling and sibling.structureKey or nil
    if structureKey == nil or structureKey == "" then
        return nil
    end
    local option = siblingPolicyOption(context.biome, structureKey)
    if option == nil then
        return nil
    end
    return {
        branch = "sibling",
        siblingIndex = siblingIndex,
        structureKey = structureKey,
        structure = option.structure,
        roleKey = option.roleKey,
        optionKey = option.roomKey,
        roomKey = option.roomKey,
        sameExitRewardCount = option.sameExitRewardCount,
        reward = siblingRewardSummary(selectedRow, siblingIndex, option),
    }
end

local function pickedExit(selectedRow, resolved)
    if selectedRow == nil or resolved == nil then
        return nil
    end
    local selected = selectedStructure(selectedRow, resolved)
    selected.branch = "picked"
    selected.reward = selectedRewardSummary(resolved.rewardContext, selectedRow.rewards)
    return selected
end

local function branchOffers(context)
    local offers = {}
    local branchKeys = {}
    for _, offer in ipairs(context and context.offers or EMPTY_LIST) do
        local requiredBranchValue = offer.requiredBranchValue
        if requiredBranchValue ~= nil and requiredBranchValue ~= "" then
            offers[#offers + 1] = offer
            branchKeys[requiredBranchValue] = true
        end
    end
    return offers, branchKeys
end

local function hasGeneratedRewardBranches(context)
    local offers, branchKeys = branchOffers(context)
    if offers[2] == nil then
        return false
    end
    local branchCount = 0
    for _ in pairs(branchKeys) do
        branchCount = branchCount + 1
    end
    return branchCount > 1
end

local function rewardBranchStructure(offer)
    if offer.kind == "shop" then
        return "PrebossShop"
    elseif offer.kind == "roomStore" then
        return "PrebossFreeReward"
    end
    return offer.requiredBranchValue
end

local function rewardBranchSummary(offer)
    if offer.kind == "shop" then
        return shopOfferSummary(offer)
    elseif offer.kind == "roomStore" then
        return roomStoreOfferSummary(offer)
    end
    return {
        kind = offer.kind,
        address = offer.address,
    }
end

local function rewardBranchExitForOffer(nextRow, nextResolved, offer, selectedBranchKey)
    local requiredBranchValue = offer and offer.requiredBranchValue
    local exit = selectedStructure(nextRow, nextResolved)
    exit.branch = requiredBranchValue == selectedBranchKey and "picked" or "sibling"
    exit.structure = rewardBranchStructure(offer)
    exit.rewardBranchKey = requiredBranchValue
    exit.reward = rewardBranchSummary(offer)
    return exit
end

local function generatedRewardBranchExits(nextRow, nextResolved)
    local exits = {}
    local context = nextResolved.rewardContext
    local selectedBranchKey = nextRow and nextRow.rewards and nextRow.rewards.row.branchKey or nil
    local offers = branchOffers(context)
    for _, offer in ipairs(offers) do
        exits[#exits + 1] = rewardBranchExitForOffer(nextRow, nextResolved, offer, selectedBranchKey)
    end
    return exits
end

local function attachNextChoiceTopology(context, roomEntry, selectedRow, nextRow, nextResolved)
    if roomEntry == nil or nextRow == nil then
        return
    end
    local exits = {}
    if hasGeneratedRewardBranches(nextResolved.rewardContext) then
        exits = generatedRewardBranchExits(nextRow, nextResolved)
    else
        exits[#exits + 1] = pickedExit(nextRow, nextResolved)
    end

    for siblingIndex, sibling in ipairs(selectedRow and selectedRow.topology and selectedRow.topology.siblings or EMPTY_LIST) do
        local exit = siblingExit(context, selectedRow, siblingIndex, sibling)
        if exit ~= nil then
            exits[#exits + 1] = exit
        end
    end

    roomEntry.topology = {
        kind = "fixedLinearNextChoice",
        exits = exits,
    }
end

function fixedLinear.build(args)
    local history = args.history
    local routeHistory = args.routeHistory
    local context = {
        routeKey = args.route and args.route.key or args.snapshot.routeKey,
        routeBiomeIndex = args.routeBiomeIndex,
        history = history,
        routeHistory = routeHistory,
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

    local resolvedRows = {}
    for index, selectedRow in ipairs(args.snapshot.rows or EMPTY_LIST) do
        resolvedRows[index] = resolveRow(context, selectedRow)
    end

    for index, selectedRow in ipairs(args.snapshot.rows or EMPTY_LIST) do
        local resolved = resolvedRows[index]
        materializeRoom.stepRoom(context, selectedRow, resolved, {
            nextRow = args.snapshot.rows[index + 1],
            nextResolved = resolvedRows[index + 1],
            reward = selectedRewardSummary(resolved.rewardContext, selectedRow.rewards),
            attachTopology = function(roomEntry)
                attachNextChoiceTopology(
                    context,
                    roomEntry,
                    selectedRow,
                    args.snapshot.rows[index + 1],
                    resolvedRows[index + 1]
                )
            end,
        })
    end
end

return fixedLinear
