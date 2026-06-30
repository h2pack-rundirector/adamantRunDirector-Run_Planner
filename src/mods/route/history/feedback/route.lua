local routeFeedback = {}

local EMPTY_LIST = {}

local function biomeLabel(args, biomeKey)
    local biome = args and args.biomeLookup and args.biomeLookup[biomeKey] or nil
    return tostring(biome and (biome.label or biome.key) or biomeKey or "Route")
end

local function locationLabel(args, record)
    if record == nil then
        return nil
    end
    local label = biomeLabel(args, record.biomeKey)
    if record.rowIndex ~= nil then
        return label .. " Row " .. tostring(record.rowIndex)
    end
    return label
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
    return copyRecord(record, {
        layer = record and record.layer or "route",
        routeKey = args and args.route and args.route.key or record and record.routeKey or nil,
        locationLabel = record and record.locationLabel or locationLabel(args, record),
        message = extras and extras.message or record and record.message or nil,
        code = extras and extras.code or record and record.code or nil,
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
