local markers = {}

local function copyFields(marker, fields)
    for key, value in pairs(fields or {}) do
        marker[key] = value
    end
end

function markers.row(ctx, row, invalid, markerKind, opts)
    opts = opts or {}
    local marker = {
        valid = false,
        markerKind = markerKind,
        scope = opts.scope,
        biomeKey = ctx.biomeKey,
        controlName = ctx.controlName,
        rowIndex = row.rowIndex,
        routeOrdinal = row.routeOrdinal,
        locationLabel = opts.locationLabel,
        code = invalid.code,
        message = invalid.message,
    }
    copyFields(marker, opts.fields)
    return marker
end

return markers
