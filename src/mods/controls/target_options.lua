local targetOptions = {}

local EMPTY_LIST = {}

local function appendOption(opts, value, label)
    if value == nil or value == "" or opts.displayValues[value] ~= nil then
        return
    end
    opts.values[#opts.values + 1] = value
    opts.displayValues[value] = label or value
end

function targetOptions.biomeLabel(instance, biomeKey)
    local biome = instance.biomeLookup and instance.biomeLookup[biomeKey] or nil
    return biome and (biome.label or biome.key) or biomeKey
end

function targetOptions.copyWithSelected(control, cacheName, rowIndex, source, value, label)
    if value == nil or value == "" or source.displayValues[value] ~= nil then
        return source
    end

    control[cacheName] = control[cacheName] or {}
    local cached = control[cacheName][rowIndex]
    if cached == nil or cached.source ~= source or cached.value ~= value or cached.label ~= label then
        local opts = {
            values = {},
            displayValues = {},
            lookup = {},
        }
        for index, optionValue in ipairs(source.values or EMPTY_LIST) do
            opts.values[index] = optionValue
        end
        for optionValue, displayValue in pairs(source.displayValues or {}) do
            opts.displayValues[optionValue] = displayValue
        end
        for optionValue, candidate in pairs(source.lookup or {}) do
            opts.lookup[optionValue] = candidate
        end
        appendOption(opts, value, label)
        cached = {
            source = source,
            value = value,
            label = label,
            opts = opts,
        }
        control[cacheName][rowIndex] = cached
    end
    return cached.opts
end

function targetOptions.copyWithSelectedLazy(control, cacheName, rowIndex, source, value, version, labelFn, ...)
    if value == nil or value == "" or source.displayValues[value] ~= nil then
        return source
    end

    control[cacheName] = control[cacheName] or {}
    local cached = control[cacheName][rowIndex]
    if cached ~= nil and cached.source == source and cached.value == value and cached.version == version then
        return cached.opts
    end

    local label = labelFn(...)
    local opts = targetOptions.copyWithSelected(control, cacheName, rowIndex, source, value, label)
    cached = control[cacheName][rowIndex]
    if cached ~= nil then
        cached.version = version
    end
    return opts
end

function targetOptions.roomLabel(candidate)
    local row = candidate and candidate.row or nil
    if row == nil then
        return "Room " .. tostring(candidate and candidate.rowIndex or "")
    end

    local label = tostring(row.slotLabel or ("Row " .. tostring(row.rowIndex or candidate.rowIndex or "")))
    local optionLabel = row.option and (row.option.label or row.option.key) or nil
    if optionLabel ~= nil then
        label = label .. " - " .. tostring(optionLabel)
    end
    if candidate.sideRoom ~= nil then
        label = label
            .. " / Side "
            .. tostring(candidate.sideIndex or candidate.sideRoom.sideIndex or "")
            .. " - "
            .. tostring(candidate.sideRoom.roomKey or "")
    end
    return label
end

function targetOptions.snapshotRowForTarget(instance, biomeKey, targetRowIndex)
    if instance.routeContext == nil or instance.routeContext.controlSnapshot == nil then
        return nil
    end
    local snapshot = instance.routeContext:controlSnapshot(instance.routeKey, biomeKey)
    for _, row in ipairs(snapshot and snapshot.rows or EMPTY_LIST) do
        if tostring(row.rowIndex or "") == tostring(targetRowIndex or "") then
            return row
        end
    end
    return nil
end

function targetOptions.selectedRoomLabel(control, instance, rowIndex)
    local selectedBiomeKey = control:selectedBiomeKey(rowIndex)
    local selectedRowIndex = control:selectedRowIndex(rowIndex)
    local row = targetOptions.snapshotRowForTarget(instance, selectedBiomeKey, selectedRowIndex)
    if row ~= nil then
        return targetOptions.roomLabel({
            row = row,
            rowIndex = selectedRowIndex,
        })
    end
    return "Room " .. tostring(selectedRowIndex)
end

function targetOptions.newRoomOptions()
    return {
        values = { "" },
        displayValues = {
            [""] = "Select room",
        },
        lookup = {},
    }
end

function targetOptions.resetRoomOptions(opts)
    for index = #opts.values, 2, -1 do
        opts.values[index] = nil
    end
    opts.values[1] = ""
    for key in pairs(opts.displayValues) do
        opts.displayValues[key] = nil
    end
    opts.displayValues[""] = "Select room"
    for key in pairs(opts.lookup) do
        opts.lookup[key] = nil
    end
    return opts
end

return targetOptions
