local locations = {}

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

function locations.biomeLabel(biome, fallback)
    return nonEmpty(biome and (biome.label or biome.key)) or nonEmpty(fallback) or "Route"
end

function locations.rowLabel(row, fallback)
    return nonEmpty(row and row.slotLabel)
        or nonEmpty(row and row.label)
        or nonEmpty(fallback)
        or (row ~= nil and row.rowIndex ~= nil and ("Row " .. tostring(row.rowIndex)) or nil)
        or "Row"
end

function locations.biomeRow(instance, row, suffix)
    local parts = {}
    append(parts, locations.biomeLabel(instance and instance.biome, instance and instance.biomeKey))
    append(parts, locations.rowLabel(row))
    append(parts, suffix)
    return table.concat(parts, " ")
end

return locations
