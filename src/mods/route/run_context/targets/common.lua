local common = {}

local EMPTY_LIST = {}
common.EMPTY_LIST = EMPTY_LIST

local function newTargetBucket()
    return {
        values = { "" },
        displayValues = {
            [""] = "Vanilla",
        },
        lookup = {},
        blockers = {},
        blockerLookup = {},
    }
end

local function targetBucket(result, allKey, biomeKey, allField, biomeField)
    local byAll = biomeKey == nil and result[allField] or result[biomeField]
    local allBucket = byAll[allKey]
    if allBucket == nil then
        allBucket = biomeKey == nil and newTargetBucket() or {}
        byAll[allKey] = allBucket
    end
    if biomeKey == nil then
        return allBucket
    end

    local bucket = allBucket[biomeKey]
    if bucket == nil then
        bucket = newTargetBucket()
        allBucket[biomeKey] = bucket
    end
    return bucket
end

function common.addTargetToBucket(bucket, candidate)
    if bucket.lookup[candidate.key] ~= nil then
        return
    end
    bucket.values[#bucket.values + 1] = candidate.key
    bucket.displayValues[candidate.key] = candidate.label
    bucket.lookup[candidate.key] = candidate
end

function common.addTarget(result, allField, biomeField, allKey, biomeKey, candidate)
    common.addTargetToBucket(targetBucket(result, allKey, nil, allField, biomeField), candidate)
    common.addTargetToBucket(targetBucket(result, allKey, biomeKey, allField, biomeField), candidate)
end

function common.addBlockerToBucket(bucket, candidate)
    if bucket.blockerLookup[candidate.key] ~= nil then
        return
    end
    bucket.blockerLookup[candidate.key] = candidate
    bucket.blockers[#bucket.blockers + 1] = candidate
end

function common.addBlocker(result, allField, biomeField, allKey, biomeKey, candidate)
    common.addBlockerToBucket(targetBucket(result, allKey, nil, allField, biomeField), candidate)
    common.addBlockerToBucket(targetBucket(result, allKey, biomeKey, allField, biomeField), candidate)
end

function common.buildKeyLookup(values)
    local lookup = {}
    for _, value in ipairs(values or EMPTY_LIST) do
        lookup[value] = true
    end
    return lookup
end

function common.valueInRange(range, value)
    if range == nil or value == nil then
        return true
    end
    if range.exact ~= nil and value ~= range.exact then
        return false
    end
    if range.min ~= nil and value < range.min then
        return false
    end
    if range.minExclusive ~= nil and value <= range.minExclusive then
        return false
    end
    if range.max ~= nil and value > range.max then
        return false
    end
    if range.maxExclusive ~= nil and value >= range.maxExclusive then
        return false
    end
    return true
end

local function nonEmpty(value)
    if value == nil or value == "" then
        return nil
    end
    return tostring(value)
end

function common.biomeLabel(context, biomeKey)
    local biome = context.biomeLookup and context.biomeLookup[biomeKey] or nil
    return nonEmpty(biome and (biome.label or biome.key)) or nonEmpty(biomeKey) or "Route"
end

function common.rowConcreteRoomKey(row)
    local option = row and row.option or nil
    if option ~= nil and option.key ~= nil and option.key ~= "" then
        return option.key
    end
    if row ~= nil and row.roomKey ~= nil and row.roomKey ~= "" then
        return row.roomKey
    end
    return nil
end

function common.rowHasConcreteRoom(row)
    return common.rowConcreteRoomKey(row) ~= nil
end

function common.candidateLabel(context, biomeKey, row, variant)
    local label = common.biomeLabel(context, biomeKey)
        .. " "
        .. tostring(row.slotLabel or ("Row " .. tostring(row.rowIndex)))
    local optionLabel = row.option and (row.option.label or row.option.key) or nil
    if optionLabel ~= nil then
        label = label .. " - " .. tostring(optionLabel)
    end
    if variant ~= nil and variant.label ~= nil then
        label = label .. " [" .. tostring(variant.label) .. "]"
    end
    return label
end

function common.sideRoomCandidateLabel(context, biomeKey, row, sideRoom)
    return common.candidateLabel(context, biomeKey, row, nil)
        .. " / Side "
        .. tostring(sideRoom.sideIndex or "")
        .. " - "
        .. tostring(sideRoom.roomKey or "")
end

return common
