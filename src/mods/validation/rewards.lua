local guard = import("mods/declarations/guard.lua")
local historyQuery = import("mods/history/query.lua")
local requirements = import("mods/validation/requirements.lua")
local validationResult = import("mods/validation/result.lua")

local rewardValidation = {}

local function expectCatalog(catalog)
    guard.expectTable(catalog, "rewardValidation.catalog")
    guard.expectTable(catalog.biomes, "rewardValidation.catalog.biomes")
    guard.expectTable(catalog.biomes.lookup, "rewardValidation.catalog.biomes.lookup")
    guard.expectTable(catalog.offerProfiles, "rewardValidation.catalog.offerProfiles")
    guard.expectTable(catalog.rewards, "rewardValidation.catalog.rewards")
    guard.expectTable(catalog.rewards.bags, "rewardValidation.catalog.rewards.bags")
    guard.expectTable(catalog.rewards.stores, "rewardValidation.catalog.rewards.stores")
    guard.expectTable(catalog.rewards.shops, "rewardValidation.catalog.rewards.shops")
    guard.expectTable(catalog.requirements, "rewardValidation.catalog.requirements")
end

local function expectHistory(history)
    guard.expectTable(history, "rewardValidation.history")
    guard.expectArray(history.events, "rewardValidation.history.events")
    guard.expectArray(history.generatedDoorHistory, "rewardValidation.history.generatedDoorHistory")
    guard.expectArray(history.rewardOfferHistory, "rewardValidation.history.rewardOfferHistory")
    guard.expectArray(history.lootHistory, "rewardValidation.history.lootHistory")
end

local function addressKey(formAddress)
    return tostring(formAddress.routeKey)
        .. ":" .. tostring(formAddress.biomeIndex)
        .. ":" .. tostring(formAddress.roomIndex)
end

local function doorAddressKey(formAddress)
    return addressKey(formAddress) .. ":" .. tostring(formAddress.doorIndex)
end

local function indexHistory(history)
    local indexed = {
        generatedDoorByAddress = {},
        offerPointByEventIndex = {},
    }

    for _, event in ipairs(history.events) do
        if event.kind == "offer_point.emit" then
            indexed.offerPointByEventIndex[event.eventIndex] = event
        end
    end

    for _, door in ipairs(history.generatedDoorHistory) do
        indexed.generatedDoorByAddress[doorAddressKey(door.sourceAddress)] = door
    end

    return indexed
end

local function getRoom(catalog, biomeKey, roomKey)
    local biome = catalog.biomes.lookup[biomeKey]
    if biome == nil then
        return nil
    end
    return biome.rooms.lookup[roomKey]
end

local function storeContainsReward(store, rewardType)
    for _, option in ipairs(store.options or {}) do
        if option == rewardType then
            return true
        end
    end
    return false
end

local function shopContainsReward(shop, rewardType)
    for _, slot in ipairs(shop.slots or {}) do
        for _, option in ipairs(slot.options or {}) do
            if option.rewardType == rewardType then
                return true
            end
        end
    end
    return false
end

local function storeListContains(stores, storeKey)
    for _, candidate in ipairs(stores or {}) do
        if candidate == storeKey then
            return true
        end
    end
    return false
end

local profileAllowsOffer

local function branchAllowsOffer(catalog, branch, offer)
    if branch.stores ~= nil and storeListContains(branch.stores, offer.store) then
        return true
    end

    if branch.offerProfile ~= nil then
        local profile = catalog.offerProfiles[branch.offerProfile]
        return profile ~= nil and profileAllowsOffer(catalog, profile, offer)
    end

    return false
end

function profileAllowsOffer(catalog, profile, offer)
    if profile.kind == "storeChoice" then
        return storeListContains(profile.stores, offer.store)
    end

    if profile.kind == "shop" then
        return profile.shopKey == offer.store
    end

    if profile.kind == "branch" then
        for _, branch in ipairs(profile.branches or {}) do
            if branchAllowsOffer(catalog, branch, offer) then
                return true
            end
        end
    end

    return false
end

local function validateStoreMembership(result, catalog, offer)
    local store = catalog.rewards.stores[offer.store]
    if store ~= nil then
        if not storeContainsReward(store, offer.rewardType) then
            validationResult.invalid(result, "reward_type_not_in_store", offer.phase, offer.sourceAddress, {
                store = offer.store,
                rewardType = offer.rewardType,
            }, "Reward type is not part of the selected reward store.")
        end
        return true
    end

    local shop = catalog.rewards.shops[offer.store]
    if shop ~= nil then
        if not shopContainsReward(shop, offer.rewardType) then
            validationResult.invalid(result, "reward_type_not_in_shop", offer.phase, offer.sourceAddress, {
                shopKey = offer.store,
                rewardType = offer.rewardType,
            }, "Reward type is not part of the selected shop profile.")
        end
        return true
    end

    validationResult.invalid(result, "reward_store_unknown", offer.phase, offer.sourceAddress, {
        store = offer.store,
        rewardType = offer.rewardType,
    }, "Reward offer references an undeclared reward store or shop profile.")
    return false
end

local function validateGeneratedDoorDomain(result, catalog, indexed, offer, offerPoint)
    if offerPoint.offerPointKind ~= "generatedDoorRewards" then
        validationResult.invalid(result, "offer_point_kind_invalid", offer.phase, offer.sourceAddress, {
            offerPointKind = offerPoint.offerPointKind,
            expectedOfferPointKind = "generatedDoorRewards",
            store = offer.store,
            rewardType = offer.rewardType,
        }, "Generated-door reward offer uses the wrong offer point kind.")
        return false
    end

    local door = indexed.generatedDoorByAddress[doorAddressKey(offerPoint.sourceAddress)]
    if door == nil then
        validationResult.invalid(result, "reward_offer_generated_door_missing", offer.phase, offer.sourceAddress, {
            offerPointEventIndex = offer.offerPointEventIndex,
        }, "Reward offer point must resolve to generated-door history.")
        return false
    end

    local targetRoom = getRoom(catalog, door.biomeKey, door.targetRoomKey)
    if targetRoom == nil then
        return false
    end

    if targetRoom.offerProfile == nil then
        validationResult.invalid(result, "reward_offer_profile_missing", offer.phase, offer.sourceAddress, {
            targetRoomKey = door.targetRoomKey,
            store = offer.store,
            rewardType = offer.rewardType,
        }, "Generated-door target room does not declare a reward offer profile.")
        return false
    end

    local profile = catalog.offerProfiles[targetRoom.offerProfile]
    if profile == nil then
        return false
    end

    if not profileAllowsOffer(catalog, profile, offer) then
        validationResult.invalid(result, "reward_offer_domain_mismatch", offer.phase, offer.sourceAddress, {
            targetRoomKey = door.targetRoomKey,
            offerProfile = targetRoom.offerProfile,
            profileKind = profile.kind,
            store = offer.store,
            rewardType = offer.rewardType,
        }, "Reward offer does not match the generated target room's offer domain.")
        return false
    end

    return true
end

local function validateOfferDomain(result, catalog, indexed, offer)
    local storeKnown = validateStoreMembership(result, catalog, offer)

    local offerPoint = indexed.offerPointByEventIndex[offer.offerPointEventIndex]
    if offerPoint == nil then
        validationResult.invalid(result, "reward_offer_point_missing", offer.phase, offer.sourceAddress, {
            offerPointEventIndex = offer.offerPointEventIndex,
            store = offer.store,
            rewardType = offer.rewardType,
        }, "Reward offer must reference a materialized offer point.")
        return false
    end

    if storeKnown and offer.phase == "room.generate_next" then
        return validateGeneratedDoorDomain(result, catalog, indexed, offer, offerPoint)
    end

    return storeKnown
end

local function addRewardContext(violation, offer)
    violation.payload.store = offer.store
    violation.payload.rewardType = offer.rewardType
    return violation
end

local function entryRequirementViolation(catalog, history, offer, entry)
    if entry.requirements == nil then
        return nil
    end

    local violation = requirements.evaluate(entry.requirements, {
        path = "rewardValidation.entries." .. offer.store .. "." .. offer.rewardType,
        namedRequirements = catalog.requirements,
        counters = {},
        queries = historyQuery.requirementQueries(history, offer.eventIndex),
        phase = offer.phase,
        defaultMessage = "Reward offer does not satisfy any matching reward entry requirements.",
    })

    if violation ~= nil then
        addRewardContext(violation, offer)
    end
    return violation
end

local function validateBagEntryRequirements(result, catalog, history, offer)
    local bag = catalog.rewards.bags[offer.store]
    if bag == nil then
        return
    end

    local lastViolation
    local hasMatchingEntry = false
    for _, entry in ipairs(bag.entries or {}) do
        if entry.rewardType == offer.rewardType then
            hasMatchingEntry = true
            local violation = entryRequirementViolation(catalog, history, offer, entry)
            if violation == nil then
                return
            end
            lastViolation = violation
        end
    end

    if hasMatchingEntry and lastViolation ~= nil then
        validationResult.invalid(
            result,
            lastViolation.code,
            offer.phase,
            offer.sourceAddress,
            lastViolation.payload,
            lastViolation.message
        )
    end
end

function rewardValidation.append(result, history, context)
    context = context or {}
    expectCatalog(context.catalog)
    expectHistory(history)

    local indexed = indexHistory(history)
    local domainValidByEventIndex = {}
    for _, offer in ipairs(history.rewardOfferHistory) do
        domainValidByEventIndex[offer.eventIndex] = validateOfferDomain(result, context.catalog, indexed, offer)
    end

    for _, offer in ipairs(history.rewardOfferHistory) do
        if domainValidByEventIndex[offer.eventIndex] then
            validateBagEntryRequirements(result, context.catalog, history, offer)
        end
    end

    return result
end

function rewardValidation.validate(history, context)
    return rewardValidation.append(validationResult.new(), history, context)
end

return rewardValidation
