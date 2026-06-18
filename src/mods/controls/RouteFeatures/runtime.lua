-- luacheck: no unused args

local deps = ...
local data = deps.data

local runtime = {}

local EMPTY_LIST = {}

local EMPTY_TARGETS = {
    values = { "" },
    displayValues = {
        [""] = "Vanilla",
    },
    lookup = {},
}

local EMPTY_ROOMS = {
    values = { "" },
    displayValues = {
        [""] = "No valid rooms",
    },
    lookup = {},
}

local VALID = {
    valid = true,
}

local function invalidStatus(code, message)
    return {
        valid = false,
        code = code,
        message = message,
    }
end

local function readField(fields, rowIndex, alias)
    return fields.Targets:read(rowIndex, alias) or ""
end

local function parseTargetKey(targetKey)
    local biomeKey, targetRowIndex = string.match(targetKey or "", "^([^:]+):([^:]+)$")
    return biomeKey or "", targetRowIndex or ""
end

local function writeField(fields, rowIndex, alias, value)
    if fields.Targets.get == nil then
        return
    end
    local field = fields.Targets:get(rowIndex, alias)
    if field ~= nil and field.write ~= nil then
        field:write(value)
    end
end

local function resetTarget(fields, rowIndex)
    if fields.Targets.reset ~= nil then
        fields.Targets:reset(rowIndex, "TargetKey")
        fields.Targets:reset(rowIndex, "BiomeKey")
        fields.Targets:reset(rowIndex, "RowIndex")
        return
    end
    writeField(fields, rowIndex, "TargetKey", "")
    writeField(fields, rowIndex, "BiomeKey", "")
    writeField(fields, rowIndex, "RowIndex", "")
end

local function writeSelection(fields, rowIndex, biomeKey, targetRowIndex)
    writeField(fields, rowIndex, "BiomeKey", biomeKey or "")
    writeField(fields, rowIndex, "RowIndex", targetRowIndex or "")
    writeField(fields, rowIndex, "TargetKey", data.targetKey(biomeKey, targetRowIndex))
end

local function markDirty(instance)
    if instance.routeContext ~= nil and instance.routeContext.markDirty ~= nil then
        instance.routeContext:markDirty(instance.routeKey)
    end
end

local function biomeLabel(instance, biomeKey)
    local biome = instance.biomeLookup and instance.biomeLookup[biomeKey] or nil
    return biome and (biome.label or biome.key) or biomeKey
end

local function buildBiomeOptions(instance, slot)
    local opts = {
        values = { "" },
        displayValues = {
            [""] = "Vanilla",
        },
        lookup = {
            [""] = true,
        },
    }

    for _, biomeKey in ipairs(instance.route and instance.route.biomes or EMPTY_LIST) do
        if slot.feature and slot.feature.biomes and slot.feature.biomes[biomeKey] and opts.lookup[biomeKey] ~= true then
            opts.values[#opts.values + 1] = biomeKey
            opts.displayValues[biomeKey] = biomeLabel(instance, biomeKey)
            opts.lookup[biomeKey] = true
        end
    end
    return opts
end

local function roomLabel(candidate)
    local row = candidate and candidate.row or nil
    if row == nil then
        return "Room " .. tostring(candidate and candidate.rowIndex or "")
    end

    local label = tostring(row.slotLabel or ("Row " .. tostring(row.rowIndex or candidate.rowIndex or "")))
    local optionLabel = row.option and (row.option.label or row.option.key) or nil
    if optionLabel ~= nil then
        label = label .. " - " .. tostring(optionLabel)
    end
    return label
end

local function ensureMap(parent, key)
    local map = parent[key]
    if map == nil then
        map = {}
        parent[key] = map
    end
    return map
end

local function newRoomOptions()
    return {
        values = { "" },
        displayValues = {
            [""] = "Select room",
        },
        lookup = {},
    }
end

local function addRoomOption(index, candidate)
    local byBiome = ensureMap(index.roomsByBiome, candidate.biomeKey)
    local rowKey = tostring(candidate.rowIndex or "")
    local opts = byBiome.options
    if opts == nil then
        opts = newRoomOptions()
        byBiome.options = opts
    end
    if opts.lookup[rowKey] == nil then
        opts.values[#opts.values + 1] = rowKey
        opts.displayValues[rowKey] = roomLabel(candidate)
        opts.lookup[rowKey] = candidate
    end
end

local function buildTargetIndex(bucket)
    local index = {
        source = bucket,
        roomsByBiome = {},
    }

    for _, targetKey in ipairs(bucket and bucket.values or EMPTY_LIST) do
        local candidate = targetKey ~= "" and bucket.lookup and bucket.lookup[targetKey] or nil
        if candidate ~= nil then
            addRoomOption(index, candidate)
        end
    end

    for _, byBiome in pairs(index.roomsByBiome) do
        if byBiome.options ~= nil and byBiome.options.values[2] == nil then
            byBiome.options.displayValues[""] = "No valid rooms"
        end
    end

    return index
end

local function selectedCandidate(control, rowIndex)
    local targetKey = control:selectedTargetKey(rowIndex)
    if targetKey == "" then
        return nil
    end
    return control:targetCandidates(rowIndex).lookup[targetKey]
end

local function hasSpacingConflict(control, rowIndex, candidate)
    if candidate == nil then
        return false
    end

    local slot = control:slot(rowIndex)
    local spacing = slot and slot.plannedSpacingRooms or nil
    if spacing == nil then
        return false
    end

    for priorIndex = 1, rowIndex - 1 do
        local priorSlot = control:slot(priorIndex)
        if priorSlot ~= nil and priorSlot.featureKey == slot.featureKey then
            local priorCandidate = selectedCandidate(control, priorIndex)
            if priorCandidate ~= nil
                and math.abs(
                    (candidate.roomHistoryOrdinal or 0) - (priorCandidate.roomHistoryOrdinal or 0)
                ) < spacing
            then
                return true
            end
        end
    end
    return false
end

function runtime.create(fields, instance)
    local control = {}

    function control:name()
        return instance.name
    end

    function control:routeKey()
        return instance.routeKey
    end

    function control:setRouteContext(routeContext, routeKey)
        instance.routeContext = routeContext
        instance.routeKey = routeKey or instance.routeKey
    end

    function control:label()
        return instance.label
    end

    function control:rowCount()
        return fields.Targets:count()
    end

    function control:slot(rowIndex)
        return instance.slots[math.floor(tonumber(rowIndex) or 0)]
    end

    function control:rawBiomeKey(rowIndex)
        return readField(fields, rowIndex, "BiomeKey")
    end

    function control:rawRowIndex(rowIndex)
        return readField(fields, rowIndex, "RowIndex")
    end

    function control:selectedBiomeKey(rowIndex)
        local biomeKey = self:rawBiomeKey(rowIndex)
        if biomeKey ~= "" then
            return biomeKey
        end
        local parsedBiomeKey = parseTargetKey(readField(fields, rowIndex, "TargetKey"))
        return parsedBiomeKey
    end

    function control:selectedRowIndex(rowIndex)
        local targetRowIndex = self:rawRowIndex(rowIndex)
        if targetRowIndex ~= "" then
            return targetRowIndex
        end
        local _, parsedRowIndex = parseTargetKey(readField(fields, rowIndex, "TargetKey"))
        return parsedRowIndex
    end

    function control:selectedTargetKey(rowIndex)
        local biomeKey = self:selectedBiomeKey(rowIndex)
        local targetRowIndex = self:selectedRowIndex(rowIndex)
        return data.targetKey(biomeKey, targetRowIndex)
    end

    function control:targetCandidates(rowIndex)
        local slot = self:slot(rowIndex)
        if slot == nil or instance.routeContext == nil or instance.routeContext.featureTargetsForSlot == nil then
            return EMPTY_TARGETS
        end
        return instance.routeContext:featureTargetsForSlot(instance.routeKey, slot.featureKey)
            or EMPTY_TARGETS
    end

    function control:targetIndex(rowIndex)
        local bucket = self:targetCandidates(rowIndex)
        self._targetIndexByRow = self._targetIndexByRow or {}
        local index = self._targetIndexByRow[rowIndex]
        if index == nil or index.source ~= bucket then
            index = buildTargetIndex(bucket)
            self._targetIndexByRow[rowIndex] = index
        end
        return index
    end

    function control:biomeOptions(rowIndex)
        self._biomeOptionsByRow = self._biomeOptionsByRow or {}
        local opts = self._biomeOptionsByRow[rowIndex]
        if opts == nil then
            local slot = self:slot(rowIndex)
            opts = slot ~= nil and buildBiomeOptions(instance, slot) or EMPTY_TARGETS
            self._biomeOptionsByRow[rowIndex] = opts
        end
        return opts
    end

    function control:roomOptions(rowIndex)
        local biomeKey = self:selectedBiomeKey(rowIndex)
        if biomeKey == "" then
            return EMPTY_ROOMS
        end

        local byBiome = self:targetIndex(rowIndex).roomsByBiome[biomeKey]
        return byBiome and byBiome.options or EMPTY_ROOMS
    end

    function control:shouldRenderRoom(rowIndex)
        return self:selectedBiomeKey(rowIndex) ~= ""
    end

    function control:writeBiome(rowIndex, biomeKey)
        if biomeKey == nil or biomeKey == "" then
            resetTarget(fields, rowIndex)
        else
            writeSelection(fields, rowIndex, biomeKey, "")
        end
        markDirty(instance)
    end

    function control:writeRoom(rowIndex, targetRowIndex)
        local biomeKey = self:selectedBiomeKey(rowIndex)
        if biomeKey == "" then
            resetTarget(fields, rowIndex)
        elseif targetRowIndex == nil or targetRowIndex == "" then
            writeSelection(fields, rowIndex, biomeKey, "")
        else
            writeSelection(fields, rowIndex, biomeKey, tostring(targetRowIndex))
        end
        markDirty(instance)
    end

    function control:writeTarget(rowIndex, targetKey)
        if targetKey == nil or targetKey == "" then
            resetTarget(fields, rowIndex)
        else
            local candidate = self:targetCandidates(rowIndex).lookup[targetKey]
            if candidate == nil then
                writeField(fields, rowIndex, "TargetKey", targetKey)
                writeField(fields, rowIndex, "BiomeKey", "")
                writeField(fields, rowIndex, "RowIndex", "")
            else
                writeField(fields, rowIndex, "TargetKey", targetKey)
                writeField(fields, rowIndex, "BiomeKey", candidate.biomeKey or "")
                writeField(fields, rowIndex, "RowIndex", tostring(candidate.rowIndex or ""))
            end
        end
        markDirty(instance)
    end

    function control:rowValidation(rowIndex)
        local slot = self:slot(rowIndex)
        if slot == nil then
            return invalidStatus("unknown_feature_slot", "Unknown feature slot")
        end

        local biomeKey = self:selectedBiomeKey(rowIndex)
        if biomeKey == "" then
            return VALID
        end
        if self:selectedRowIndex(rowIndex) == "" then
            return invalidStatus("feature_room_required", tostring(slot.label) .. " needs a target room")
        end

        local targetKey = self:selectedTargetKey(rowIndex)
        local candidate = self:targetCandidates(rowIndex).lookup[targetKey]
        if candidate == nil then
            return invalidStatus("feature_target_unavailable", "Selected feature target is no longer valid")
        end
        if hasSpacingConflict(self, rowIndex, candidate) then
            return invalidStatus("feature_spacing", tostring(slot.label) .. " is too close to another planned target")
        end
        return VALID
    end

    function control:rowSnapshot(rowIndex)
        local slot = self:slot(rowIndex)
        if slot == nil then
            return nil
        end

        local targetKey = self:selectedTargetKey(rowIndex)
        local candidate = targetKey ~= "" and self:targetCandidates(rowIndex).lookup[targetKey] or nil
        local validation = self:rowValidation(rowIndex)
        return {
            rowIndex = rowIndex,
            slotKey = slot.key,
            label = slot.label,
            featureKey = slot.featureKey,
            biomeKey = self:selectedBiomeKey(rowIndex),
            targetRowIndex = self:selectedRowIndex(rowIndex),
            targetKey = targetKey,
            target = candidate,
            valid = validation.valid,
            invalidCode = validation.code,
            invalidReason = validation.message,
        }
    end

    function control:buildSnapshot()
        local rows = {}
        local invalidRows = {}
        for rowIndex = 1, self:rowCount() do
            local row = self:rowSnapshot(rowIndex)
            rows[#rows + 1] = row
            if row ~= nil and not row.valid then
                invalidRows[#invalidRows + 1] = {
                    rowIndex = row.rowIndex,
                    code = row.invalidCode,
                    message = row.invalidReason,
                }
            end
        end

        return {
            controlName = instance.name,
            routeKey = instance.routeKey,
            valid = invalidRows[1] == nil,
            disabled = invalidRows[1] ~= nil,
            invalidRows = invalidRows,
            rows = rows,
        }
    end

    function control:read(path, ...)
        if path == "snapshot" then
            return self:buildSnapshot()
        elseif path == "row" then
            return self:rowSnapshot(...)
        end
        return nil
    end

    return control
end

return runtime
