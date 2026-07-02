local deps = ... or {}

local routeLoot = {}

local EMPTY_LIST = {}
local SHOP_BOUGHT_VALUE = "Bought"

local routeHistory = deps.history

local function nonEmpty(value)
    if value == nil or value == "" then
        return nil
    end
    return value
end

local function sourceValues(summary)
    local values = {}
    if nonEmpty(summary.boonSource) ~= nil then
        values[#values + 1] = summary.boonSource
    end
    for _, source in ipairs(summary.devotionSources or EMPTY_LIST) do
        if nonEmpty(source) ~= nil then
            values[#values + 1] = source
        end
    end
    return values
end

local function emitLoot(history, roomEntry, summary, opts)
    local lootType = nonEmpty(summary and summary.rewardType)
    if lootType == nil then
        return nil
    end
    opts = opts or {}
    return routeHistory.emitAt(history, roomEntry, {
        kind = "loot",
        eventKey = lootType,
        groupKey = roomEntry.groupKey,
        eventSourceKind = opts.eventSourceKind or summary.kind,
        rowIndex = opts.rowIndex,
        formAddress = opts.formAddress,
        routeOrdinal = opts.routeOrdinal,
        parentEntry = roomEntry,
        parentRoomKey = opts.parentRoomKey or roomEntry.roomKey or roomEntry.eventKey,
        address = opts.address or summary.address,
        controlAlias = summary.controlAlias or opts.controlAlias,
        lootKind = summary.kind,
        lootType = lootType,
        lootName = nonEmpty(summary.boonSource),
        sourceValues = sourceValues(summary),
        rewardStore = summary.rewardStore or opts.rewardStore,
        rewardClass = summary.rewardClass or opts.rewardClass,
        shopProfile = summary.shopProfile or opts.shopProfile,
        state = summary.state or opts.state,
        bought = summary.bought or opts.bought or nil,
        timing = summary.timing or opts.timing,
        pendingUntilRoomHistoryOrdinal = summary.pendingUntilRoomHistoryOrdinal
            or opts.pendingUntilRoomHistoryOrdinal,
        acquiredAfterRoomHistoryOrdinal = summary.acquiredAfterRoomHistoryOrdinal
            or opts.acquiredAfterRoomHistoryOrdinal,
        legalityValidatedBy = summary.legalityValidatedBy or opts.legalityValidatedBy,
        targetRoomKey = opts.targetRoomKey,
        targetHubDoorId = opts.targetHubDoorId,
        targetRoleKey = opts.targetRoleKey,
        targetOptionKey = opts.targetOptionKey,
    })
end

local function emitPendingShopOffer(history, roomEntry, offer, opts)
    local rewardType = nonEmpty(offer and offer.rewardType)
    if rewardType == nil then
        return nil
    end
    opts = opts or {}
    if opts.pendingUntilRoomHistoryOrdinal == nil then
        return nil
    end
    return emitLoot(history, roomEntry, {
        kind = "shop",
        rewardType = rewardType,
        boonSource = offer.boonSource,
        controlAlias = offer.controlAlias,
        shopProfile = opts.shopProfile,
        state = offer.state,
        bought = offer.bought,
    }, {
        address = opts.address,
        controlAlias = offer.controlAlias,
        eventSourceKind = opts.eventSourceKind,
        shopProfile = opts.shopProfile,
        state = offer.state,
        bought = offer.bought,
        timing = "pendingOffer",
        pendingUntilRoomHistoryOrdinal = opts.pendingUntilRoomHistoryOrdinal,
    })
end

local function emitFieldCageLoot(history, roomEntry, reward)
    for index, pick in ipairs(reward.picks or EMPTY_LIST) do
        emitLoot(history, roomEntry, {
            kind = "fieldsCage",
            rewardStore = reward.rewardStore,
            rewardType = pick.rewardType,
            boonSource = pick.boonSource,
            controlAlias = pick.controlAlias,
        }, {
            address = "cage:" .. tostring(index),
            controlAlias = pick.controlAlias,
            eventSourceKind = "fieldsCage",
        })
    end
end

local function emitMultiEncounterLoot(history, roomEntry, reward)
    for _, encounter in ipairs(reward.encounters or EMPTY_LIST) do
        emitLoot(history, roomEntry, encounter.reward or {}, {
            address = "encounter:" .. tostring(encounter.legIndex),
            eventSourceKind = "multiEncounter",
        })
    end
end

local function emitPrebossLoot(history, roomEntry, reward, nextRoomEntry)
    local pendingUntil = nextRoomEntry and nextRoomEntry.roomHistoryOrdinal or nil
    if reward.branch == "FreeReward" then
        emitLoot(history, roomEntry, reward.reward or {}, {
            eventSourceKind = "prebossFreeReward",
        })
    elseif reward.branch == "Shop" then
        local shop = reward.shop or {}
        for index, offer in ipairs(reward.offers or EMPTY_LIST) do
            emitPendingShopOffer(history, roomEntry, offer, {
                address = "shop:" .. tostring(index),
                eventSourceKind = "prebossShop",
                shopProfile = shop.shopProfile,
                pendingUntilRoomHistoryOrdinal = pendingUntil,
            })
            if offer.bought == true then
                emitLoot(history, roomEntry, {
                    kind = "shop",
                    rewardType = offer.rewardType,
                    boonSource = offer.boonSource,
                    controlAlias = offer.controlAlias,
                    shopProfile = shop.shopProfile,
                    state = offer.state,
                    bought = offer.bought,
                    acquiredAfterRoomHistoryOrdinal = pendingUntil,
                }, {
                    address = "shop:" .. tostring(index),
                    controlAlias = offer.controlAlias,
                    eventSourceKind = "prebossShop",
                    shopProfile = shop.shopProfile,
                    state = offer.state or SHOP_BOUGHT_VALUE,
                    bought = true,
                    acquiredAfterRoomHistoryOrdinal = pendingUntil,
                })
            end
        end
    end
end

local function emitHubGeneratedDoorOffers(history, roomEntry, topology)
    for _, door in ipairs(topology.generatedDoors or EMPTY_LIST) do
        if door.reward ~= nil then
            emitLoot(history, roomEntry, door.reward, {
                eventSourceKind = "hubGeneratedDoor",
                timing = "generatedOffer",
                rowIndex = door.targetRowIndex,
                formAddress = door.targetFormAddress,
                routeOrdinal = door.targetRouteOrdinal,
                parentRoomKey = door.roomKey,
                targetRoomKey = door.roomKey,
                targetHubDoorId = door.hubDoorId,
                targetRoleKey = door.roleKey,
                targetOptionKey = door.optionKey,
                address = door.reward.address or "row",
            })
        end
    end
end

local function emitDefaultRoomLoot(history, roomEntry, reward)
    local opts = {
        address = reward.address or "row",
    }
    if roomEntry.topology ~= nil and roomEntry.topology.kind == "hubDoorBatchPick" then
        opts.legalityValidatedBy = "hubGeneratedOffer"
    end
    emitLoot(history, roomEntry, reward, opts)
end

function routeLoot.emitForRoomEntry(history, roomEntry, nextRoomEntry)
    local reward = roomEntry and roomEntry.reward or nil
    local topology = roomEntry and roomEntry.topology or nil
    if topology ~= nil and topology.kind == "hubDoorBatch" then
        emitHubGeneratedDoorOffers(history, roomEntry, topology)
    end

    if reward == nil then
        return
    elseif reward.kind == "fieldsCages" then
        emitFieldCageLoot(history, roomEntry, reward)
    elseif reward.kind == "multiEncounter" then
        emitMultiEncounterLoot(history, roomEntry, reward)
    elseif reward.kind == "preboss" then
        emitPrebossLoot(history, roomEntry, reward, nextRoomEntry)
    else
        emitDefaultRoomLoot(history, roomEntry, reward)
    end
end

local function nextRoomEntry(history, index, lastIndex)
    for nextIndex = index + 1, lastIndex do
        local entry = routeHistory.entries(history)[nextIndex]
        if entry ~= nil and entry.kind == "room" then
            return entry
        end
    end
    return nil
end

function routeLoot.emitForRoomEntries(history, firstIndex, lastIndex)
    for index = firstIndex, lastIndex do
        local entry = routeHistory.entries(history)[index]
        if entry ~= nil and entry.kind == "room" then
            routeLoot.emitForRoomEntry(history, entry, nextRoomEntry(history, index, lastIndex))
        end
    end
end

return routeLoot
