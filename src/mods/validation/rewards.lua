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
    guard.expectTable(catalog.rewards.sources, "rewardValidation.catalog.rewards.sources")
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

local function offerAddressKey(formAddress)
    return doorAddressKey(formAddress) .. ":" .. tostring(formAddress.offerIndex)
end

local function indexHistory(history)
    local indexed = {
        generatedDoorByAddress = {},
        offerPointByEventIndex = {},
        rewardOfferByAddress = {},
    }

    for _, event in ipairs(history.events) do
        if event.kind == "offer_point.emit" then
            indexed.offerPointByEventIndex[event.eventIndex] = event
        end
    end

    for _, door in ipairs(history.generatedDoorHistory) do
        indexed.generatedDoorByAddress[doorAddressKey(door.sourceAddress)] = door
    end

    for _, offer in ipairs(history.rewardOfferHistory) do
        indexed.rewardOfferByAddress[offerAddressKey(offer.sourceAddress)] = offer
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

local function boonSourceCatalog(catalog)
    local boon = catalog.rewards.sources.boon
    guard.expectTable(boon, "rewardValidation.catalog.rewards.sources.boon")
    guard.expectTable(boon.lookup, "rewardValidation.catalog.rewards.sources.boon.lookup")
    return boon
end

local function sourceExists(catalog, source)
    return boonSourceCatalog(catalog).lookup[source] ~= nil
end

local function copyArray(values)
    local copy = {}
    for index, value in ipairs(values or {}) do
        copy[index] = value
    end
    return copy
end

local function copyTable(source)
    if type(source) ~= "table" then
        return source
    end

    local copy = {}
    for key, value in pairs(source) do
        copy[key] = copyTable(value)
    end
    return copy
end

local function invalidPayload(result, offer, code, payload, message)
    payload.store = offer.store
    payload.rewardType = offer.rewardType
    validationResult.invalid(result, code, offer.phase, offer.sourceAddress, payload, message)
    return false
end

local function validateBoonPayload(result, catalog, offer)
    local payload = offer.payload or {}
    local source = payload.source
    if source == nil then
        return true
    end

    guard.expectString(source, "rewardValidation.boon.payload.source")
    if sourceExists(catalog, source) then
        return true
    end

    return invalidPayload(result, offer, "reward_payload_source_unknown", {
        source = source,
    }, "Reward payload references an undeclared boon source.")
end

local function devotionSources(offer)
    local payload = guard.expectTable(offer.payload, "rewardValidation.devotion.payload")
    local sources = guard.expectArray(payload.sources, "rewardValidation.devotion.payload.sources")
    if #sources ~= 2 then
        guard.fail("rewardValidation.devotion.payload.sources", "Devotion payload must contain exactly two sources")
    end
    for index, source in ipairs(sources) do
        guard.expectString(source, "rewardValidation.devotion.payload.sources[" .. tostring(index) .. "]")
    end
    return sources
end

local function validateDeclaredSources(result, catalog, offer, sources)
    local unknown = {}
    for _, source in ipairs(sources) do
        if not sourceExists(catalog, source) then
            unknown[#unknown + 1] = source
        end
    end

    if #unknown == 0 then
        return true
    end

    return invalidPayload(result, offer, "reward_payload_source_unknown", {
        unknownSources = unknown,
        sources = copyArray(sources),
    }, "Reward payload references an undeclared boon source.")
end

local function validateDistinctSources(result, offer, sources)
    if sources[1] ~= sources[2] then
        return true
    end

    return invalidPayload(result, offer, "devotion_sources_not_distinct", {
        duplicateSource = sources[1],
        sources = copyArray(sources),
    }, "Devotion sources must be distinct.")
end

local function validatePriorSources(result, history, offer, sources)
    local missing = historyQuery.missingAcquiredLootSourcesBefore(history, sources, offer.eventIndex)
    if #missing == 0 then
        return true
    end

    return invalidPayload(result, offer, "devotion_sources_not_acquired", {
        missingSources = missing,
        sources = copyArray(sources),
    }, "Devotion sources must already exist in acquired loot history.")
end

local function validateDevotionPayload(result, catalog, history, offer)
    local sources = devotionSources(offer)
    local declared = validateDeclaredSources(result, catalog, offer, sources)
    local distinct = declared and validateDistinctSources(result, offer, sources)
    return distinct and validatePriorSources(result, history, offer, sources)
end

local function validatePayload(result, catalog, history, offer)
    if offer.rewardType == "Boon" then
        return validateBoonPayload(result, catalog, offer)
    elseif offer.rewardType == "Devotion" then
        return validateDevotionPayload(result, catalog, history, offer)
    end
    return true
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
        counters = historyQuery.countersForEvent(history, offer.eventIndex),
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

local function candidateRecords(context, history)
    local records = context.candidateRecords or history.candidateRecords
    if records == nil then
        return {}
    end
    return guard.expectArray(records, "rewardValidation.candidateRecords")
end

local function expectCandidateRecord(record, context)
    guard.expectTable(record, context)
    guard.expectTable(record.formAddress, context .. ".formAddress")
    guard.expectString(record.providerKey, context .. ".providerKey")
    guard.expectNumber(record.providerVersion, context .. ".providerVersion")
    guard.expectString(record.candidateKey, context .. ".candidateKey")
    guard.expectNumber(record.candidateIndex, context .. ".candidateIndex")
    local semantic = guard.expectTable(record.semantic, context .. ".semantic")
    local kind = guard.expectString(semantic.kind, context .. ".semantic.kind")
    return kind, semantic
end

local function rewardOfferForRecord(indexed, record, context)
    local offer = indexed.rewardOfferByAddress[offerAddressKey(record.formAddress)]
    if offer == nil then
        guard.fail(context .. ".formAddress", "reward candidate address must resolve to reward offer history")
    end
    return offer
end

local function addCandidateFindings(result, record, findings)
    for _, finding in ipairs(findings or {}) do
        validationResult.candidate(
            result,
            record,
            finding.code,
            finding.phase,
            finding.presentation or "invalid",
            finding.payload,
            finding.message,
            finding.color
        )
    end
end

local function projectOffer(baseOffer, fields)
    local offer = copyTable(baseOffer)
    for key, value in pairs(fields or {}) do
        offer[key] = copyTable(value)
    end
    return offer
end

local function selectedFindingsForProjectedOffer(catalog, history, indexed, offer)
    local result = validationResult.new()
    local domainValid = validateOfferDomain(result, catalog, indexed, offer)
    local payloadValid = domainValid and validatePayload(result, catalog, history, offer)

    if domainValid and payloadValid then
        validateBagEntryRequirements(result, catalog, history, offer)
    end

    return result.findings
end

local function evaluateRewardTypeCandidate(result, catalog, history, indexed, record, semantic, context)
    local currentOffer = rewardOfferForRecord(indexed, record, context)
    local rewardType = guard.expectString(semantic.rewardType, context .. ".semantic.rewardType")
    local projectedOffer = projectOffer(currentOffer, {
        store = semantic.store or currentOffer.store,
        rewardType = rewardType,
        payload = semantic.payload or currentOffer.payload,
    })

    addCandidateFindings(result, record, selectedFindingsForProjectedOffer(catalog, history, indexed, projectedOffer))
end

local function evaluateDevotionSourceCandidate(result, catalog, history, indexed, record, semantic, context)
    local currentOffer = rewardOfferForRecord(indexed, record, context)
    if currentOffer.rewardType ~= "Devotion" then
        guard.fail(context .. ".semantic.kind", "devotionSource candidate requires a Devotion reward offer")
    end

    guard.expectString(semantic.source, context .. ".semantic.source")
    guard.expectNumber(semantic.sourceIndex, context .. ".semantic.sourceIndex")
    local sources = guard.expectArray(semantic.sources, context .. ".semantic.sources")
    local projectedOffer = projectOffer(currentOffer, {
        payload = {
            sources = copyArray(sources),
        },
    })
    local resultBuffer = validationResult.new()
    validatePayload(resultBuffer, catalog, history, projectedOffer)
    addCandidateFindings(result, record, resultBuffer.findings)
end

local function evaluateCandidateRecords(result, catalog, history, indexed, records)
    for index, record in ipairs(records) do
        local context = "rewardValidation.candidateRecords[" .. tostring(index) .. "]"
        local kind, semantic = expectCandidateRecord(record, context)

        if kind ~= "nextRoom" then
            if kind == "rewardType" then
                evaluateRewardTypeCandidate(result, catalog, history, indexed, record, semantic, context)
            elseif kind == "devotionSource" then
                evaluateDevotionSourceCandidate(result, catalog, history, indexed, record, semantic, context)
            else
                guard.fail(context .. ".semantic.kind", "unknown candidate kind '" .. kind .. "'")
            end
        end
    end
end

function rewardValidation.append(result, history, context)
    context = context or {}
    expectCatalog(context.catalog)
    expectHistory(history)

    local indexed = indexHistory(history)
    local domainValidByEventIndex = {}
    local payloadValidByEventIndex = {}
    for _, offer in ipairs(history.rewardOfferHistory) do
        domainValidByEventIndex[offer.eventIndex] = validateOfferDomain(result, context.catalog, indexed, offer)
        payloadValidByEventIndex[offer.eventIndex] = domainValidByEventIndex[offer.eventIndex]
            and validatePayload(result, context.catalog, history, offer)
    end

    for _, offer in ipairs(history.rewardOfferHistory) do
        if domainValidByEventIndex[offer.eventIndex] and payloadValidByEventIndex[offer.eventIndex] then
            validateBagEntryRequirements(result, context.catalog, history, offer)
        end
    end

    evaluateCandidateRecords(result, context.catalog, history, indexed, candidateRecords(context, history))

    return result
end

function rewardValidation.validate(history, context)
    return rewardValidation.append(validationResult.new(), history, context)
end

return rewardValidation
