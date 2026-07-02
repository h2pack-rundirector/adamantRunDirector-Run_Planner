local deps = ... or {}

local routeFeedback = {}
local messages = deps.messages
local EMPTY_LIST = {}

local function nonEmpty(value)
    if value == nil or value == "" then
        return nil
    end
    return tostring(value)
end

local function biomeLabel(args, biomeKey)
    local biome = args and args.biomeLookup and args.biomeLookup[biomeKey] or nil
    return tostring(biome and (biome.label or biome.key) or biomeKey or "Route")
end

local function append(parts, value)
    value = nonEmpty(value)
    if value ~= nil then
        parts[#parts + 1] = value
    end
end

local function renderedEntry(record)
    local target = record and (record.targetFinding or record) or nil
    local renderRowIndex = record and record.renderRowIndex or nil
    if renderRowIndex ~= nil then
        local targetEntry = target and target.entry or nil
        if targetEntry ~= nil and targetEntry.rowIndex == renderRowIndex then
            return targetEntry
        end
        local recordEntry = record and record.entry or nil
        if recordEntry ~= nil and recordEntry.rowIndex == renderRowIndex then
            return recordEntry
        end
    end
    return record and (
        record.parentEntry
            or record.entry
            or target and target.entry
    ) or nil
end

local function rowLabel(record)
    local entry = renderedEntry(record)
    local source = entry and entry.source or nil
    return nonEmpty(source and source.slotLabel)
        or nonEmpty(source and source.label)
        or nonEmpty(entry and entry.entryLabel)
        or nonEmpty(entry and entry.slotLabel)
        or nonEmpty(record and record.slotLabel)
        or (
            record ~= nil
            and (record.renderRowIndex or record.rowIndex) ~= nil
            and ("Row " .. tostring(record.renderRowIndex or record.rowIndex))
            or nil
        )
end

local function childLabel(address)
    local kind = address and address.childKind or nil
    local index = address and address.childIndex or nil
    if kind == "sideRoom" then
        return "Side " .. tostring(index or 1)
    elseif kind == "hubReturn" then
        return "Hub Return"
    elseif kind == "pylonRestore" then
        return "Pylon Restore"
    end
    return nil
end

local function rewardAddressLabel(record)
    local address = record and record.address or nil
    if address == nil or address == "" then
        return nil
    end
    local cageIndex = string.match(tostring(address), "^cage:(%d+)$")
    if cageIndex ~= nil then
        return "Cage Reward " .. tostring(cageIndex)
    end
    local sideIndex = string.match(tostring(address), "^side:(%d+)$")
    if sideIndex ~= nil then
        local formAddress = record and record.formAddress or nil
        if formAddress ~= nil
            and formAddress.childKind == "sideRoom"
            and tostring(formAddress.childIndex or "") == tostring(sideIndex)
        then
            return "Reward"
        end
        return "Side " .. tostring(sideIndex) .. " Reward"
    end
    local encounterIndex = string.match(tostring(address), "^encounter:(%d+)$")
    if encounterIndex ~= nil then
        return "Encounter " .. tostring(encounterIndex) .. " Reward"
    end
    if address == "row" or record and record.tabKey == "rewards" then
        return "Rewards"
    end
    return nil
end

local function generatedOfferLabel(record)
    local entry = record and record.entry or nil
    if entry ~= nil
        and (
            entry.timing == "generatedOffer"
                or entry.eventSourceKind == "hubGeneratedDoor"
        )
    then
        return "Generated Offer"
    end
    return nil
end

local function npcLocationLabel(record)
    if record == nil
        or (
            record.layer ~= "npcs"
            and record.kind ~= "npcSelectionInvalid"
        )
    then
        return nil
    end
    if record.rowIndex ~= nil then
        return "NPC Row " .. tostring(record.rowIndex)
    end
    return "NPC"
end

local function locationLabel(args, record)
    if record == nil then
        return nil
    end
    local npcLabel = npcLocationLabel(record)
    if npcLabel ~= nil then
        return npcLabel
    end

    local parts = {}
    append(parts, biomeLabel(args, record.biomeKey))
    append(parts, rowLabel(record))
    append(parts, childLabel(record.formAddress))
    append(parts, generatedOfferLabel(record))
    append(parts, rewardAddressLabel(record))
    return table.concat(parts, " ")
end

local function copyRecord(record, extras)
    local copy = {}
    for key, value in pairs(record or {}) do
        copy[key] = value
    end
    for key, value in pairs(extras or {}) do
        copy[key] = value
    end
    return copy
end

function routeFeedback.marker(args, record, extras)
    local code = messages.code(record, extras)
    return copyRecord(record, {
        layer = record and record.layer or "route",
        routeKey = args and args.route and args.route.key or record and record.routeKey or nil,
        locationLabel = record and record.locationLabel or locationLabel(args, record),
        message = messages.forRecord(args, record, extras, code),
        code = code,
        markerKind = extras and extras.markerKind or record and record.markerKind or nil,
    })
end

function routeFeedback.fromResult(args)
    local invalids = args and args.invalids or EMPTY_LIST
    local primary = invalids[1] and routeFeedback.marker(args, invalids[1], {
        markerKind = "primary",
    }) or nil
    local related = {}
    local markers = {}

    for index, invalid in ipairs(invalids) do
        local marker = routeFeedback.marker(args, invalid, {
            markerKind = index == 1 and "primary" or invalid.markerKind,
        })
        markers[#markers + 1] = marker
        if index == 1 then
            for _, relatedRecord in ipairs(invalid.relatedEvents or EMPTY_LIST) do
                local relatedMarker = routeFeedback.marker(args, relatedRecord, {
                    markerKind = "related",
                    message = relatedRecord.message or invalid.message,
                    code = relatedRecord.code or invalid.code,
                })
                related[#related + 1] = relatedMarker
                markers[#markers + 1] = relatedMarker
            end
        end
    end

    return {
        valid = primary == nil,
        primary = primary,
        related = related,
        markers = markers,
    }
end

return routeFeedback
