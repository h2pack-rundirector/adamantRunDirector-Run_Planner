local rewardItems = {}
local EMPTY_LIST = {}
local REWARD_SOURCE_FIELDS = {
    "rewards",
    "rewardLoot",
    "rewardPicks",
    "rewardKind",
    "fixedRewardType",
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
    elseif sourceKind == "cage" then
        return indexedLabel("Cage", sourceIndex, " Reward")
    elseif sourceKind == "encounter" then
        return indexedLabel("Combat", sourceIndex, " Reward")
    end
    return "Rewards"
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
        fixedRewardType = source.fixedRewardType,
        rewardStore = source.rewardStore,
        valid = source.valid,
    }
end

local function collectFromRow(row, items)
    appendItem(items, row, row, "row", "row")

    for _, sideRoom in ipairs(row and row.sideRooms or EMPTY_LIST) do
        appendItem(items, row, sideRoom, "side:" .. tostring(sideRoom.sideIndex or ""), "side", sideRoom.sideIndex)
    end
    for _, cageReward in ipairs(row and row.cageRewards or EMPTY_LIST) do
        appendItem(items, row, cageReward, "cage:" .. tostring(cageReward.cageIndex or ""), "cage", cageReward.cageIndex)
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
    for _, cageReward in ipairs(row.cageRewards or EMPTY_LIST) do
        clearRewardSource(cageReward)
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
