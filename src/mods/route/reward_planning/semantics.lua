local semantics = {}

local EMPTY_LIST = {}
local SHOP_BOON_SOURCE_REWARDS = {
    RandomLoot = true,
    BoostedRandomLoot = true,
}

local function clearList(list)
    for index = #list, 1, -1 do
        list[index] = nil
    end
end

local function appendValue(values, value)
    if value ~= nil and value ~= "" then
        values[#values + 1] = value
    end
end

local function pickValue(item, key)
    for _, pick in ipairs(item and item.rewardPicks or EMPTY_LIST) do
        if pick.key == key then
            return pick.value
        end
    end
    return nil
end

local function pickValueByKind(item, kind)
    for _, pick in ipairs(item and item.rewardPicks or EMPTY_LIST) do
        if pick.kind == kind then
            return pick.value
        end
    end
    return nil
end

local function rewardValue(item, index)
    local value = item and item.rewards and item.rewards[index] or nil
    if value == nil or value == "" then
        return nil
    end
    return value
end

local function shopAddress(address, index)
    local shopSuffix = "shop:" .. tostring(index)
    if address == nil or address == "" or address == "row" then
        return shopSuffix
    end
    return tostring(address) .. "/" .. shopSuffix
end

local function shopAddressLabel(item, index)
    local label = item and item.sourceLabel or nil
    local offerLabel = "Shop Offer " .. tostring(index)
    if label == nil or label == "" or label == "Rewards" then
        return offerLabel
    end
    return tostring(label) .. " " .. offerLabel
end

local function sourceForShopReward(item, index, rewardType)
    if not SHOP_BOON_SOURCE_REWARDS[rewardType] then
        return nil
    end
    return item and item.rewardLoot and item.rewardLoot[index] or nil
end

local function sourceCount(item)
    return math.floor(tonumber(item and item.rewardSourceCount or 0) or 0)
end

local function fieldsCageAddress(address, index)
    local cageSuffix = "cage:" .. tostring(index)
    if address == nil or address == "" or address == "row" then
        return cageSuffix
    end
    return tostring(address) .. "/" .. cageSuffix
end

local function fieldsCageAddressLabel(_, index)
    return "Cage " .. tostring(index) .. " Reward"
end

local function sourceForFieldsCageReward(item, index, rewardType)
    if rewardType ~= "Boon" then
        return nil
    end
    return item and item.rewardLoot and item.rewardLoot[index] or nil
end

local function effectTimingForItem(item)
    local generation = item and item.rewardGeneration or nil
    if generation ~= nil and generation.effectTiming ~= nil then
        return generation.effectTiming
    end
    if item ~= nil and item.rewardKind == "shop" then
        return "afterNextRow"
    end
    return "afterBatch"
end

function semantics.rewardType(item)
    if item == nil or item.valid == false then
        return nil
    end

    local kind = item.rewardKind
    if kind == "boonSource" then
        return "Boon"
    elseif kind == "devotionPair" then
        return "Devotion"
    elseif kind == "fixedReward" then
        return item.fixedRewardType or rewardValue(item, 1)
    elseif kind == "roomStore" then
        return pickValue(item, "rewardType") or rewardValue(item, 1)
    elseif kind == "majorMinor" then
        local branch = rewardValue(item, 1)
        if branch == "Major" then
            return pickValue(item, "rewardType") or rewardValue(item, 2)
        elseif branch == "Minor" then
            return pickValue(item, "rewardType") or rewardValue(item, 4)
        end
    end
    return nil
end

function semantics.boonSource(item)
    if item == nil or item.valid == false then
        return nil
    end

    local rewards = item.rewards or EMPTY_LIST
    if item.rewardKind == "boonSource" then
        return pickValue(item, "boonSource") or pickValueByKind(item, "boonSource") or rewards[1]
    elseif item.rewardKind == "roomStore" and rewards[1] == "Boon" then
        return pickValue(item, "boonSource") or rewards[2]
    elseif item.rewardKind == "majorMinor"
        and rewards[1] == "Major"
        and rewards[2] == "Boon"
    then
        return pickValue(item, "boonSource") or rewards[3]
    end
    return nil
end

function semantics.devotionSources(item, out)
    local sources = out or {}
    clearList(sources)
    if item == nil or item.valid == false then
        return sources
    end

    local rewards = item.rewards or EMPTY_LIST
    if item.rewardKind == "devotionPair" then
        appendValue(sources, pickValue(item, "lootAName") or rewards[1])
        appendValue(sources, pickValue(item, "lootBName") or rewards[2])
    elseif item.rewardKind == "roomStore" and rewards[1] == "Devotion" then
        appendValue(sources, pickValue(item, "lootAName") or rewards[3])
        appendValue(sources, pickValue(item, "lootBName") or rewards[4])
    elseif item.rewardKind == "majorMinor"
        and rewards[1] == "Major"
        and rewards[2] == "Devotion"
    then
        appendValue(sources, pickValue(item, "lootAName") or rewards[5])
        appendValue(sources, pickValue(item, "lootBName") or rewards[6])
    end
    return sources
end

function semantics.godLootSources(item, out)
    local sources = out or {}
    clearList(sources)
    if item == nil or item.valid == false then
        return sources
    end

    if item.rewardKind == "shop" then
        for index, rewardType in ipairs(item.rewards or EMPTY_LIST) do
            appendValue(sources, sourceForShopReward(item, index, rewardType))
        end
        return sources
    elseif item.rewardKind == "fieldsCages" then
        for index = 1, sourceCount(item) do
            appendValue(sources, sourceForFieldsCageReward(item, index, item.rewards and item.rewards[index] or nil))
        end
        return sources
    end

    local rewardType = semantics.rewardType(item)
    if rewardType == "Boon" then
        appendValue(sources, semantics.boonSource(item))
    elseif rewardType == "Devotion" then
        semantics.devotionSources(item, sources)
    end
    return sources
end

function semantics.isConcrete(item)
    if item == nil or item.valid == false then
        return false
    end

    local kind = item.rewardKind
    if kind == "none" or kind == "fixedReward" or kind == "boonSource" or kind == "devotionPair" then
        return true
    elseif kind == "roomStore" then
        return rewardValue(item, 1) ~= nil
    elseif kind == "majorMinor" then
        local branch = rewardValue(item, 1)
        if branch == "Major" then
            return rewardValue(item, 2) ~= nil
        elseif branch == "Minor" then
            return rewardValue(item, 4) ~= nil
        end
        return false
    elseif kind == "shop" then
        return rewardValue(item, 1) ~= nil
    elseif kind == "fieldsCages" then
        for index = 1, sourceCount(item) do
            if rewardValue(item, index) == nil then
                return false
            end
        end
        return sourceCount(item) > 0
    end
    return false
end

function semantics.hasBannedValue(item, banned)
    if item == nil or banned == nil then
        return false
    end
    if item.rewardKind == "boonSource" and banned.Boon then
        return true
    end
    if item.rewardKind == "devotionPair" and banned.Devotion then
        return true
    end
    for _, value in ipairs(item.rewards or EMPTY_LIST) do
        if value ~= nil and value ~= "" and banned[value] then
            return true
        end
    end
    for _, pick in ipairs(item.rewardPicks or EMPTY_LIST) do
        if pick.value ~= nil and pick.value ~= "" and banned[pick.value] then
            return true
        end
    end
    return false
end

local function appendEvent(events, row, item, rewardType, address, addressLabel, boonSource, devotionSourceA, devotionSourceB)
    if rewardType == nil or rewardType == "" then
        return
    end

    local event = {
        row = row,
        item = item,
        rewardType = rewardType,
        address = address,
        addressLabel = addressLabel,
        rowLabel = item and item.rowLabel or nil,
    }
    if boonSource ~= nil and boonSource ~= "" then
        event.boonSource = boonSource
    end
    if devotionSourceA ~= nil and devotionSourceA ~= "" then
        event.devotionSourceA = devotionSourceA
    end
    if devotionSourceB ~= nil and devotionSourceB ~= "" then
        event.devotionSourceB = devotionSourceB
    end
    events[#events + 1] = event
end

function semantics.eventsForItem(item, row, out)
    local events = out or {}
    if item == nil or item.valid == false then
        return events
    end

    if item.rewardKind == "shop" then
        for index, rewardType in ipairs(item.rewards or EMPTY_LIST) do
            appendEvent(
                events,
                row,
                item,
                rewardType,
                shopAddress(item.address, index),
                shopAddressLabel(item, index),
                sourceForShopReward(item, index, rewardType)
            )
        end
        return events
    elseif item.rewardKind == "fieldsCages" then
        for index = 1, sourceCount(item) do
            local rewardType = item.rewards and item.rewards[index] or nil
            appendEvent(
                events,
                row,
                item,
                rewardType,
                fieldsCageAddress(item.address, index),
                fieldsCageAddressLabel(item, index),
                sourceForFieldsCageReward(item, index, rewardType)
            )
        end
        return events
    end

    local rewardType = semantics.rewardType(item)
    if rewardType == "Devotion" then
        local rewards = item.rewards or EMPTY_LIST
        if item.rewardKind == "devotionPair" then
            appendEvent(
                events,
                row,
                item,
                rewardType,
                item.address,
                item.sourceLabel,
                nil,
                pickValue(item, "lootAName") or rewards[1],
                pickValue(item, "lootBName") or rewards[2]
            )
        elseif item.rewardKind == "roomStore" then
            appendEvent(
                events,
                row,
                item,
                rewardType,
                item.address,
                item.sourceLabel,
                nil,
                pickValue(item, "lootAName") or rewards[3],
                pickValue(item, "lootBName") or rewards[4]
            )
        elseif item.rewardKind == "majorMinor" then
            appendEvent(
                events,
                row,
                item,
                rewardType,
                item.address,
                item.sourceLabel,
                nil,
                pickValue(item, "lootAName") or rewards[5],
                pickValue(item, "lootBName") or rewards[6]
            )
        else
            appendEvent(events, row, item, rewardType, item.address, item.sourceLabel)
        end
        return events
    end
    appendEvent(events, row, item, rewardType, item.address, item.sourceLabel, semantics.boonSource(item))
    return events
end

function semantics.eventsForRow(row, rewardItems, out, itemScratch)
    local events = out or {}
    clearList(events)
    for _, item in ipairs(rewardItems.collect(row, itemScratch)) do
        semantics.eventsForItem(item, row, events)
    end
    return events
end

function semantics.batchesForRow(row, rewardItems, out, itemScratch, eventScratch)
    local batches = out or {}
    local events = eventScratch or {}
    clearList(batches)
    clearList(events)

    for _, item in ipairs(rewardItems.collect(row, itemScratch)) do
        local firstEventIndex = #events + 1
        semantics.eventsForItem(item, row, events)
        if events[firstEventIndex] ~= nil then
            batches[#batches + 1] = {
                row = row,
                item = item,
                effectTiming = effectTimingForItem(item),
                events = events,
                firstEventIndex = firstEventIndex,
                lastEventIndex = #events,
            }
        end
    end
    return batches
end

return semantics
