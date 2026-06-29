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
        sourceKind = opts.sourceKind or summary.kind,
        parentEntry = roomEntry,
        parentRoomKey = roomEntry.roomKey or roomEntry.eventKey,
        address = opts.address or summary.address,
        lootKind = summary.kind,
        lootType = lootType,
        lootName = nonEmpty(summary.boonSource),
        sourceValues = sourceValues(summary),
        rewardStore = summary.rewardStore or opts.rewardStore,
        rewardClass = summary.rewardClass or opts.rewardClass,
        shopProfile = summary.shopProfile or opts.shopProfile,
        state = summary.state or opts.state,
        bought = summary.bought or opts.bought or nil,
    })
end

local function emitFieldCageLoot(history, roomEntry, reward)
    for index, pick in ipairs(reward.picks or EMPTY_LIST) do
        emitLoot(history, roomEntry, {
            kind = "fieldsCage",
            rewardStore = reward.rewardStore,
            rewardType = pick.rewardType,
            boonSource = pick.boonSource,
        }, {
            address = "cage:" .. tostring(index),
            sourceKind = "fieldsCage",
        })
    end
end

local function emitMultiEncounterLoot(history, roomEntry, reward)
    for _, encounter in ipairs(reward.encounters or EMPTY_LIST) do
        emitLoot(history, roomEntry, encounter.reward or {}, {
            address = "encounter:" .. tostring(encounter.legIndex),
            sourceKind = "multiEncounter",
        })
    end
end

local function emitPrebossLoot(history, roomEntry, reward)
    if reward.branch == "FreeReward" then
        emitLoot(history, roomEntry, reward.reward or {}, {
            sourceKind = "prebossFreeReward",
        })
    elseif reward.branch == "Shop" then
        local shop = reward.shop or {}
        for index, offer in ipairs(reward.offers or EMPTY_LIST) do
            if offer.bought == true then
                emitLoot(history, roomEntry, {
                    kind = "shop",
                    rewardType = offer.rewardType,
                    boonSource = offer.boonSource,
                    shopProfile = shop.shopProfile,
                    state = offer.state,
                    bought = offer.bought,
                }, {
                    address = "shop:" .. tostring(index),
                    sourceKind = "prebossShop",
                    shopProfile = shop.shopProfile,
                    state = offer.state or SHOP_BOUGHT_VALUE,
                    bought = true,
                })
            end
        end
    end
end

function routeLoot.emitForRoomEntry(history, roomEntry)
    local reward = roomEntry and roomEntry.reward or nil
    if reward == nil then
        return
    elseif reward.kind == "fieldsCages" then
        emitFieldCageLoot(history, roomEntry, reward)
    elseif reward.kind == "multiEncounter" then
        emitMultiEncounterLoot(history, roomEntry, reward)
    elseif reward.kind == "preboss" then
        emitPrebossLoot(history, roomEntry, reward)
    else
        emitLoot(history, roomEntry, reward, {
            address = reward.address or "row",
        })
    end
end

function routeLoot.emitForRoomEntries(history, firstIndex, lastIndex)
    for index = firstIndex, lastIndex do
        local entry = routeHistory.entries(history)[index]
        if entry ~= nil and entry.kind == "room" then
            routeLoot.emitForRoomEntry(history, entry)
        end
    end
end

return routeLoot
