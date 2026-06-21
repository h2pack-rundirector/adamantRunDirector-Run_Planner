local invalidLocations = {}

local function nonEmpty(value)
    if value == nil or value == "" then
        return nil
    end
    return tostring(value)
end

local function append(parts, value)
    value = nonEmpty(value)
    if value ~= nil then
        parts[#parts + 1] = value
    end
end

function invalidLocations.biomeLabel(biome, fallback)
    return nonEmpty(biome and (biome.label or biome.key)) or nonEmpty(fallback) or "Route"
end

function invalidLocations.rowLabel(row, fallback)
    return nonEmpty(row and row.slotLabel)
        or nonEmpty(row and row.label)
        or nonEmpty(fallback)
        or (row ~= nil and row.rowIndex ~= nil and ("Row " .. tostring(row.rowIndex)) or nil)
        or "Row"
end

function invalidLocations.biomeRow(instance, row, suffix)
    local parts = {}
    append(parts, invalidLocations.biomeLabel(instance and instance.biome, instance and instance.biomeKey))
    append(parts, invalidLocations.rowLabel(row))
    append(parts, suffix)
    return table.concat(parts, " ")
end

function invalidLocations.routeRow(instance, row, suffix)
    local route = instance and instance.route or nil
    local parts = {}
    append(parts, nonEmpty(route and (route.label or route.key)) or nonEmpty(instance and instance.routeKey))
    append(parts, invalidLocations.rowLabel(row))
    append(parts, suffix)
    return table.concat(parts, " ")
end

function invalidLocations.rewardAddress(event)
    return nonEmpty(event and event.addressLabel) or "Rewards"
end

function invalidLocations.rewardEvent(context, ctx, event)
    local biomeLookup = context and context.biomeLookup or nil
    local biome = biomeLookup and ctx and biomeLookup[ctx.biomeKey] or nil
    local parts = {}
    append(parts, invalidLocations.biomeLabel(biome, ctx and ctx.biomeKey))
    append(parts, invalidLocations.rowLabel(event and event.row))
    append(parts, invalidLocations.rewardAddress(event))
    return table.concat(parts, " ")
end

return invalidLocations
