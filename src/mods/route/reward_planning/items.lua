local rewardItems = {}
local EMPTY_LIST = {}
local REWARD_SOURCE_FIELDS = {
    "rewards",
    "rewardLoot",
    "rewardPicks",
    "selectionRequirements",
    "rewardKind",
    "fixedRewardType",
    "rewardSourceCount",
    "rewardGeneration",
    "rewardConstraints",
    "rewardRowGroup",
    "rewardChoiceGroup",
    "rewardAliasOffset",
    "rewardOffers",
}

local function clearList(list)
    for index = #list, 1, -1 do
        list[index] = nil
    end
end

local function clearRewardSource(source)
    if source == nil then
        return
    end
    for _, field in ipairs(REWARD_SOURCE_FIELDS) do
        source[field] = nil
    end
end

local function hasRewardSourceFields(source)
    if source == nil then
        return false
    end
    for _, field in ipairs(REWARD_SOURCE_FIELDS) do
        if source[field] ~= nil then
            return true
        end
    end
    return false
end

local function indexedLabel(prefix, index, suffix)
    return tostring(prefix) .. " " .. tostring(index or "") .. tostring(suffix or "")
end

local function defaultSourceLabel(source, sourceKind, sourceIndex)
    if sourceKind == "row" then
        return "Rewards"
    end

    local label = source and (source.rewardLocationLabel or source.label) or nil
    if label ~= nil and label ~= "" then
        return tostring(label) .. " Reward"
    end

    if sourceKind == "side" then
        return indexedLabel("Side Room", sourceIndex, " Reward")
    elseif sourceKind == "encounter" then
        return indexedLabel("Combat", sourceIndex, " Reward")
    end
    return "Rewards"
end

local function copyRewardPick(pick)
    return {
        key = pick.key,
        kind = pick.kind,
        alias = pick.alias,
        storageAlias = pick.storageAlias,
        value = pick.value,
        label = pick.label,
        sourceIndex = pick.sourceIndex,
        rewardAddress = pick.rewardAddress,
        rewardStore = pick.rewardStore,
    }
end

local function copySelectionRequirement(requirement)
    return {
        tabKey = requirement.tabKey,
        address = requirement.address,
        key = requirement.key,
        kind = requirement.kind,
        controlAlias = requirement.controlAlias,
        storageAlias = requirement.storageAlias,
        label = requirement.label,
        sourceIndex = requirement.sourceIndex,
    }
end

local function rewardControlIndex(entry)
    local alias = entry and (entry.alias or entry.controlAlias) or ""
    return math.floor(tonumber(string.match(alias, "^Reward(%d+)")) or 0)
end

local function entriesForRewardAliasRange(entries, minIndex, maxIndex, copyEntry)
    local selected = {}
    for _, entry in ipairs(entries or EMPTY_LIST) do
        local index = rewardControlIndex(entry)
        if index >= minIndex and index <= maxIndex then
            selected[#selected + 1] = copyEntry(entry)
        end
    end
    return selected
end

local function offerEndIndex(offer)
    return offer.rewardAliasStart + offer.rewardAliasCount - 1
end

local function shopRewards(source, offer)
    local rewards = {}
    local rewardLoot = {}
    for index = 1, offer.rewardAliasCount do
        local sourceIndex = offer.rewardAliasStart + index - 1
        rewards[index] = source.rewards and source.rewards[sourceIndex] or nil
        rewardLoot[index] = source.rewardLoot and source.rewardLoot[sourceIndex] or nil
    end
    return rewards, rewardLoot
end

local function roomStoreRewardValues(source, offer)
    return {
        source.rewards and source.rewards[offer.rewardAliasStart] or nil,
        source.rewards and source.rewards[offer.rewardAliasStart + 1] or nil,
    }
end

local function appendItem(items, row, source, address, sourceKind, sourceIndex)
    if source == nil then
        return
    end

    items[#items + 1] = {
        address = address,
        sourceLabel = defaultSourceLabel(source, sourceKind, sourceIndex),
        sourceKind = sourceKind,
        sourceIndex = sourceIndex,
        rowLabel = row and row.slotLabel or source.slotLabel,
        rowIndex = row and row.rowIndex or source.rowIndex,
        routeOrdinal = row and row.routeOrdinal or source.routeOrdinal,
        rewardKind = source.rewardKind,
        rewards = source.rewards or EMPTY_LIST,
        rewardLoot = source.rewardLoot or EMPTY_LIST,
        rewardPicks = source.rewardPicks or EMPTY_LIST,
        selectionRequirements = source.selectionRequirements or EMPTY_LIST,
        fixedRewardType = source.fixedRewardType,
        rewardStore = source.rewardStore,
        shopProfile = source.shopProfile,
        rewardSourceCount = source.rewardSourceCount,
        rewardGeneration = source.rewardGeneration,
        rewardConstraints = source.rewardConstraints,
        rewardRowGroup = source.rewardRowGroup,
        rewardChoiceGroup = source.rewardChoiceGroup,
        rewardAliasOffset = source.rewardAliasOffset,
        rewardOffers = source.rewardOffers,
        valid = source.valid,
    }
end

local function appendPrebossShopItem(items, row, source, offer, sourceKind, sourceIndex)
    local rewards, rewardLoot = shopRewards(source, offer)
    items[#items + 1] = {
        address = offer.address,
        sourceLabel = offer.label,
        sourceKind = sourceKind,
        sourceIndex = sourceIndex,
        rowLabel = row and row.slotLabel or source.slotLabel,
        rowIndex = row and row.rowIndex or source.rowIndex,
        routeOrdinal = row and row.routeOrdinal or source.routeOrdinal,
        rewardKind = "shop",
        shopProfile = offer.shopProfile,
        rewards = rewards,
        rewardLoot = rewardLoot,
        rewardPicks = entriesForRewardAliasRange(
            source.rewardPicks,
            offer.rewardAliasStart,
            offerEndIndex(offer),
            copyRewardPick
        ),
        selectionRequirements = entriesForRewardAliasRange(
            source.selectionRequirements,
            offer.rewardAliasStart,
            offerEndIndex(offer),
            copySelectionRequirement
        ),
        rewardSourceCount = offer.rewardAliasCount,
        rewardGeneration = offer.rewardGeneration,
        rewardConstraints = source.rewardConstraints,
        rewardChoiceGroup = offer.rewardChoiceGroup,
        valid = source.valid,
    }
end

local function appendPrebossRoomStoreItem(items, row, source, offer, sourceKind, sourceIndex)
    items[#items + 1] = {
        address = offer.address,
        sourceLabel = offer.label,
        sourceKind = sourceKind,
        sourceIndex = sourceIndex,
        rowLabel = row and row.slotLabel or source.slotLabel,
        rowIndex = row and row.rowIndex or source.rowIndex,
        routeOrdinal = row and row.routeOrdinal or source.routeOrdinal,
        rewardKind = "roomStore",
        rewards = roomStoreRewardValues(source, offer),
        rewardPicks = entriesForRewardAliasRange(
            source.rewardPicks,
            offer.rewardAliasStart,
            offerEndIndex(offer),
            copyRewardPick
        ),
        selectionRequirements = entriesForRewardAliasRange(
            source.selectionRequirements,
            offer.rewardAliasStart,
            offerEndIndex(offer),
            copySelectionRequirement
        ),
        rewardStore = offer.rewardStore,
        rewardChoiceGroup = offer.rewardChoiceGroup,
        rewardAliasOffset = offer.rewardAliasStart - 1,
        valid = source.valid,
    }
end

local function appendPrebossItems(items, row, source, sourceKind, sourceIndex)
    for _, offer in ipairs(source.rewardOffers or EMPTY_LIST) do
        if offer.kind == "shop" then
            appendPrebossShopItem(items, row, source, offer, sourceKind, sourceIndex)
        elseif offer.kind == "roomStore" then
            appendPrebossRoomStoreItem(items, row, source, offer, sourceKind, sourceIndex)
        end
    end
end

local function collectFromRow(row, items)
    if row ~= nil and row.rewardKind == "preboss" then
        appendPrebossItems(items, row, row, "row", "row")
    else
        appendItem(items, row, row, "row", "row")
    end

    for _, sideRoom in ipairs(row and row.sideRooms or EMPTY_LIST) do
        appendItem(items, row, sideRoom, "side:" .. tostring(sideRoom.sideIndex or ""), "side", sideRoom.sideIndex)
    end
    for _, encounterRewardLeg in ipairs(row and row.encounterRewardLegs or EMPTY_LIST) do
        appendItem(
            items,
            row,
            encounterRewardLeg,
            "encounter:" .. tostring(encounterRewardLeg.legIndex or ""),
            "encounter",
            encounterRewardLeg.legIndex
        )
    end
end

function rewardItems.attach(row)
    if row == nil then
        return nil
    end
    if row.rewardItems ~= nil and not hasRewardSourceFields(row) then
        return row
    end

    local items = row.rewardItems
    if items == nil then
        items = {}
        row.rewardItems = items
    else
        clearList(items)
    end
    collectFromRow(row, items)
    clearRewardSource(row)
    for _, sideRoom in ipairs(row.sideRooms or EMPTY_LIST) do
        clearRewardSource(sideRoom)
    end
    for _, encounterRewardLeg in ipairs(row.encounterRewardLegs or EMPTY_LIST) do
        clearRewardSource(encounterRewardLeg)
    end
    return row
end

function rewardItems.collect(row, out)
    if out == nil and row ~= nil and row.rewardItems ~= nil then
        return row.rewardItems
    end

    local items = out or {}
    clearList(items)
    if row == nil then
        return items
    end

    for _, item in ipairs(row.rewardItems or EMPTY_LIST) do
        items[#items + 1] = item
    end
    return items
end

function rewardItems.collectBySource(row, sourceKind, out)
    local items = out or {}
    clearList(items)
    for _, item in ipairs(row and row.rewardItems or EMPTY_LIST) do
        if item.sourceKind == sourceKind then
            items[#items + 1] = item
        end
    end
    return items
end

return rewardItems
