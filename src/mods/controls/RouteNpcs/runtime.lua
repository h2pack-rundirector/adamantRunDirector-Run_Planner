-- luacheck: no unused args

local deps = ...
local data = deps.data
local invalidLocations = deps.invalidLocations
local targetMarkers = deps.targetMarkers
local controlRequirements = deps.controlRequirements

local runtime = {}

local EMPTY_LIST = {}
local DISABLED_BIOME_KEY = "Disabled"

local EMPTY_TARGETS = {
    values = { "" },
    displayValues = {
        [""] = "No valid targets",
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

local EMPTY_VARIANTS = {
    values = {},
    displayValues = {},
    lookup = {},
}

local VALID = {
    valid = true,
}

local function invalidStatus(code, message, extras)
    local status = {
        valid = false,
        code = code,
        message = message,
    }
    if extras ~= nil then
        for key, value in pairs(extras) do
            status[key] = value
        end
    end
    return status
end

local function readField(fields, rowIndex, alias)
    return fields.Targets:read(rowIndex, alias) or ""
end

local function parseTargetKey(targetKey)
    local biomeKey, targetRowIndex, variantKey = string.match(targetKey or "", "^([^:]+):([^:]+):(.*)$")
    return biomeKey or "", targetRowIndex or "", variantKey or ""
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
        fields.Targets:reset(rowIndex, "VariantKey")
        fields.Targets:reset(rowIndex, "BiomeKey")
        fields.Targets:reset(rowIndex, "RowIndex")
        return
    end
    writeField(fields, rowIndex, "TargetKey", "")
    writeField(fields, rowIndex, "VariantKey", "")
    writeField(fields, rowIndex, "BiomeKey", "")
    writeField(fields, rowIndex, "RowIndex", "")
end

local function writeDisabled(fields, rowIndex)
    writeField(fields, rowIndex, "TargetKey", "")
    writeField(fields, rowIndex, "VariantKey", "")
    writeField(fields, rowIndex, "BiomeKey", DISABLED_BIOME_KEY)
    writeField(fields, rowIndex, "RowIndex", "")
end

local function writeSelection(fields, rowIndex, biomeKey, targetRowIndex, variantKey)
    writeField(fields, rowIndex, "BiomeKey", biomeKey or "")
    writeField(fields, rowIndex, "RowIndex", targetRowIndex or "")
    writeField(fields, rowIndex, "VariantKey", variantKey or "")
    writeField(fields, rowIndex, "TargetKey", data.targetKey(biomeKey, targetRowIndex, variantKey))
end

local function markDirty(instance)
    if instance.routeContext ~= nil and instance.routeContext.markDirty ~= nil then
        instance.routeContext:markDirty(instance.routeKey)
    end
end

local function clearValueStateSnapshot(control)
    control._targetValueStateSnapshot = nil
end

local function biomeLabel(instance, biomeKey)
    local biome = instance.biomeLookup and instance.biomeLookup[biomeKey] or nil
    return biome and (biome.label or biome.key) or biomeKey
end

local function buildBiomeOptions(instance, slot)
    local opts = {
        values = { DISABLED_BIOME_KEY },
        displayValues = {
            [DISABLED_BIOME_KEY] = "Disabled",
        },
        lookup = {
            [DISABLED_BIOME_KEY] = true,
        },
    }

    local function addBiome(biomeKey)
        if biomeKey ~= nil and opts.lookup[biomeKey] ~= true then
            opts.values[#opts.values + 1] = biomeKey
            opts.displayValues[biomeKey] = biomeLabel(instance, biomeKey)
            opts.lookup[biomeKey] = true
        end
    end

    if slot.fixedBiomeKey ~= nil then
        addBiome(slot.fixedBiomeKey)
        return opts
    end

    for _, biomeKey in ipairs(instance.route and instance.route.biomes or EMPTY_LIST) do
        if slot.npc and slot.npc.biomes and slot.npc.biomes[biomeKey] ~= nil then
            addBiome(biomeKey)
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

local function variantLabel(candidate)
    return candidate and (candidate.variantLabel or candidate.variantKey or candidate.encounterName) or ""
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

local function newVariantOptions()
    return {
        values = {},
        displayValues = {},
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

local function addVariantOption(index, candidate)
    local byBiome = ensureMap(index.variantsByBiomeRow, candidate.biomeKey)
    local rowKey = tostring(candidate.rowIndex or "")
    local byRow = byBiome[rowKey]
    if byRow == nil then
        byRow = newVariantOptions()
        byBiome[rowKey] = byRow
    end
    local variantKey = candidate.variantKey or ""
    if byRow.lookup[variantKey] == nil then
        byRow.values[#byRow.values + 1] = variantKey
        byRow.displayValues[variantKey] = variantLabel(candidate)
        byRow.lookup[variantKey] = candidate
    end
end

local function buildTargetIndex(bucket)
    local index = {
        source = bucket,
        roomsByBiome = {},
        variantsByBiomeRow = {},
    }

    for _, targetKey in ipairs(bucket and bucket.values or EMPTY_LIST) do
        local candidate = targetKey ~= "" and bucket.lookup and bucket.lookup[targetKey] or nil
        if candidate ~= nil then
            addRoomOption(index, candidate)
            addVariantOption(index, candidate)
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

local function spacingForSlot(slot)
    return slot and slot.group and slot.group.plannedSpacingRooms or nil
end

local function hasSpacingConflict(control, rowIndex, candidate)
    if candidate == nil then
        return nil
    end

    local slot = control:slot(rowIndex)
    local spacing = spacingForSlot(slot)
    if spacing == nil then
        return nil
    end

    for priorIndex = 1, rowIndex - 1 do
        local priorSlot = control:slot(priorIndex)
        if priorSlot ~= nil and priorSlot.groupKey == slot.groupKey then
            local priorCandidate = selectedCandidate(control, priorIndex)
            if priorCandidate ~= nil
                and math.abs(
                    (candidate.roomHistoryOrdinal or 0) - (priorCandidate.roomHistoryOrdinal or 0)
                ) < spacing
            then
                return priorIndex
            end
        end
    end
    return nil
end

local function sameTargetRoom(left, right)
    return left ~= nil
        and right ~= nil
        and left.biomeKey == right.biomeKey
        and tostring(left.rowIndex or "") == tostring(right.rowIndex or "")
end

local function hasRoomConflict(control, rowIndex, candidate)
    if candidate == nil then
        return nil
    end

    for priorIndex = 1, rowIndex - 1 do
        if sameTargetRoom(candidate, selectedCandidate(control, priorIndex)) then
            return priorIndex
        end
    end
    return nil
end

local function markerContext(instance, row)
    return {
        biomeKey = row.biomeKey,
        controlName = instance.name,
    }
end

local function invalidForRow(row)
    return {
        code = row.invalidCode,
        message = row.invalidReason,
        controlTargets = row.invalidControlTargets,
        valueTargets = row.invalidValueTargets,
    }
end

local function roomSelectionRequired(slot)
    return controlRequirements.invalid({
        message = tostring(slot.label) .. " needs a target room",
        tabKey = "npcs",
        controlAlias = "RowIndex",
    })
end

local function biomeSelectionRequired(slot)
    return controlRequirements.invalid({
        message = tostring(slot.label) .. " needs Disabled or a target biome",
        tabKey = "npcs",
        controlAlias = "BiomeKey",
    })
end

local function appendInvalidMarker(instance, invalidRows, row, markerKind)
    invalidRows[#invalidRows + 1] = targetMarkers.row(
        markerContext(instance, row),
        row,
        invalidForRow(row),
        markerKind,
        {
            scope = "npc",
            includeVariant = true,
            locationLabel = invalidLocations.routeRow(instance, row),
        }
    )
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

    function control:rawVariantKey(rowIndex)
        return readField(fields, rowIndex, "VariantKey")
    end

    function control:isDisabled(rowIndex)
        return self:rawBiomeKey(rowIndex) == DISABLED_BIOME_KEY
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

    function control:selectedVariantKey(rowIndex)
        local variantKey = self:rawVariantKey(rowIndex)
        if variantKey ~= "" then
            return variantKey
        end
        local _, _, parsedVariantKey = parseTargetKey(readField(fields, rowIndex, "TargetKey"))
        if parsedVariantKey ~= "" then
            return parsedVariantKey
        end

        local variants = self:variantOptions(rowIndex)
        return variants.values[1] or ""
    end

    function control:selectedTargetKey(rowIndex)
        if self:isDisabled(rowIndex) then
            return ""
        end
        local biomeKey = self:selectedBiomeKey(rowIndex)
        local targetRowIndex = self:selectedRowIndex(rowIndex)
        if biomeKey == "" or targetRowIndex == "" then
            return ""
        end
        return data.targetKey(biomeKey, targetRowIndex, self:selectedVariantKey(rowIndex))
    end

    function control:targetCandidates(rowIndex)
        local slot = self:slot(rowIndex)
        if slot == nil or instance.routeContext == nil or instance.routeContext.npcTargetsForSlot == nil then
            return EMPTY_TARGETS
        end
        return instance.routeContext:npcTargetsForSlot(instance.routeKey, slot.npcKey, slot.fixedBiomeKey)
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
        if biomeKey == "" or self:isDisabled(rowIndex) then
            return EMPTY_ROOMS
        end

        local byBiome = self:targetIndex(rowIndex).roomsByBiome[biomeKey]
        return byBiome and byBiome.options or EMPTY_ROOMS
    end

    function control:variantOptions(rowIndex)
        local biomeKey = self:selectedBiomeKey(rowIndex)
        local targetRowIndex = self:selectedRowIndex(rowIndex)
        if biomeKey == "" or self:isDisabled(rowIndex) or targetRowIndex == "" then
            return EMPTY_VARIANTS
        end

        local byBiome = self:targetIndex(rowIndex).variantsByBiomeRow[biomeKey]
        return byBiome and byBiome[tostring(targetRowIndex)] or EMPTY_VARIANTS
    end

    function control:shouldRenderRoom(rowIndex)
        return self:selectedBiomeKey(rowIndex) ~= "" and not self:isDisabled(rowIndex)
    end

    function control:shouldRenderVariant(rowIndex)
        return self:selectedBiomeKey(rowIndex) ~= ""
            and not self:isDisabled(rowIndex)
            and self:selectedRowIndex(rowIndex) ~= ""
            and self:variantOptions(rowIndex).values[2] ~= nil
    end

    function control:writeBiome(rowIndex, biomeKey)
        if biomeKey == nil or biomeKey == "" then
            resetTarget(fields, rowIndex)
        elseif biomeKey == DISABLED_BIOME_KEY then
            writeDisabled(fields, rowIndex)
        else
            writeSelection(fields, rowIndex, biomeKey, "", "")
        end
        clearValueStateSnapshot(self)
        markDirty(instance)
    end

    function control:writeRoom(rowIndex, targetRowIndex)
        local biomeKey = self:selectedBiomeKey(rowIndex)
        if biomeKey == "" then
            resetTarget(fields, rowIndex)
        elseif self:isDisabled(rowIndex) then
            writeDisabled(fields, rowIndex)
        elseif targetRowIndex == nil or targetRowIndex == "" then
            writeSelection(fields, rowIndex, biomeKey, "", "")
        else
            local variants = self:targetIndex(rowIndex).variantsByBiomeRow[biomeKey]
            local rowVariants = variants and variants[tostring(targetRowIndex)] or EMPTY_VARIANTS
            writeSelection(fields, rowIndex, biomeKey, tostring(targetRowIndex), rowVariants.values[1] or "")
        end
        clearValueStateSnapshot(self)
        markDirty(instance)
    end

    function control:writeVariant(rowIndex, variantKey)
        local biomeKey = self:selectedBiomeKey(rowIndex)
        local targetRowIndex = self:selectedRowIndex(rowIndex)
        if self:isDisabled(rowIndex) then
            writeDisabled(fields, rowIndex)
        elseif biomeKey == "" or targetRowIndex == "" then
            resetTarget(fields, rowIndex)
        else
            writeSelection(fields, rowIndex, biomeKey, targetRowIndex, variantKey or "")
        end
        clearValueStateSnapshot(self)
        markDirty(instance)
    end

    function control:writeTarget(rowIndex, targetKey)
        if targetKey == nil or targetKey == "" then
            resetTarget(fields, rowIndex)
        else
            local candidate = self:targetCandidates(rowIndex).lookup[targetKey]
            if candidate == nil then
                writeField(fields, rowIndex, "TargetKey", targetKey)
                writeField(fields, rowIndex, "VariantKey", "")
                writeField(fields, rowIndex, "BiomeKey", "")
                writeField(fields, rowIndex, "RowIndex", "")
            else
                writeField(fields, rowIndex, "TargetKey", targetKey)
                writeField(fields, rowIndex, "VariantKey", candidate.variantKey or "")
                writeField(fields, rowIndex, "BiomeKey", candidate.biomeKey or "")
                writeField(fields, rowIndex, "RowIndex", tostring(candidate.rowIndex or ""))
            end
        end
        clearValueStateSnapshot(self)
        markDirty(instance)
    end

    function control:rowValidation(rowIndex)
        local slot = self:slot(rowIndex)
        if slot == nil then
            return invalidStatus("unknown_npc_slot", "Unknown NPC slot")
        end

        local biomeKey = self:selectedBiomeKey(rowIndex)
        if self:isDisabled(rowIndex) then
            return VALID
        end
        if biomeKey == "" then
            return biomeSelectionRequired(slot)
        end
        if self:selectedRowIndex(rowIndex) == "" then
            return roomSelectionRequired(slot)
        end

        local targetKey = self:selectedTargetKey(rowIndex)
        local candidate = self:targetCandidates(rowIndex).lookup[targetKey]
        if candidate == nil then
            return invalidStatus("npc_target_unavailable", "Selected NPC target is no longer valid")
        end
        local roomConflictRowIndex = hasRoomConflict(self, rowIndex, candidate)
        if roomConflictRowIndex ~= nil then
            return invalidStatus(
                "npc_room_occupied",
                "Only one NPC encounter can use the same room",
                { relatedRowIndex = roomConflictRowIndex }
            )
        end
        local spacingConflictRowIndex = hasSpacingConflict(self, rowIndex, candidate)
        if spacingConflictRowIndex ~= nil then
            return invalidStatus(
                "npc_spacing",
                tostring(slot.label) .. " is too close to another planned NPC",
                { relatedRowIndex = spacingConflictRowIndex }
            )
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
        local disabled = self:isDisabled(rowIndex)
        local biomeKey = disabled and "" or self:selectedBiomeKey(rowIndex)
        return {
            rowIndex = rowIndex,
            slotKey = slot.key,
            label = slot.label,
            npcKey = slot.npcKey,
            groupKey = slot.groupKey,
            disabled = disabled,
            mode = disabled and "Disabled" or (biomeKey == "" and "Unresolved" or "Target"),
            biomeKey = biomeKey,
            targetRowIndex = disabled and "" or self:selectedRowIndex(rowIndex),
            variantKey = disabled and "" or self:selectedVariantKey(rowIndex),
            targetKey = targetKey,
            target = candidate,
            valid = validation.valid,
            invalidCode = validation.code,
            invalidReason = validation.message,
            invalidControlTargets = validation.controlTargets,
            invalidValueTargets = validation.valueTargets,
            relatedRowIndex = validation.relatedRowIndex,
        }
    end

    function control:buildSnapshot()
        local rows = {}
        local invalidRows = {}
        local foundInvalid = false
        for rowIndex = 1, self:rowCount() do
            local row = self:rowSnapshot(rowIndex)
            rows[#rows + 1] = row
            if row ~= nil and not row.valid and not foundInvalid then
                appendInvalidMarker(instance, invalidRows, row, "primary")
                if row.relatedRowIndex ~= nil and rows[row.relatedRowIndex] ~= nil then
                    appendInvalidMarker(instance, invalidRows, rows[row.relatedRowIndex], "related")
                end
                foundInvalid = true
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

    function control:valueStateSnapshot()
        local rowCount = self:rowCount()
        local cached = self._targetValueStateSnapshot
        local valid = cached ~= nil and cached.rowCount == rowCount
        if valid then
            for rowIndex = 1, rowCount do
                if cached.sources[rowIndex] ~= self:targetCandidates(rowIndex) then
                    valid = false
                    break
                end
            end
            if valid then
                return cached.snapshot
            end
        end

        local snapshot = self:buildSnapshot()
        local sources = {}
        for rowIndex = 1, rowCount do
            sources[rowIndex] = self:targetCandidates(rowIndex)
        end
        self._targetValueStateSnapshot = {
            rowCount = rowCount,
            sources = sources,
            snapshot = snapshot,
        }
        return snapshot
    end

    function control:valueStates(rowIndex, controlAlias)
        if instance.routeContext ~= nil
            and instance.routeContext:canDecorateLayer(instance.routeKey, "npcs") == false
        then
            return nil
        end
        return targetMarkers.valueStates(self:valueStateSnapshot(), rowIndex, controlAlias)
    end

    function control:inactiveBoundary()
        if instance.routeContext == nil then
            return false, nil
        end
        return instance.routeContext:targetInactiveBoundary(instance.routeKey, "npcs", instance.name)
    end

    function control:isRowInactive(rowIndex, allInactive, inactiveAfterRowIndex)
        return allInactive
            or (
                inactiveAfterRowIndex ~= nil
                and rowIndex ~= nil
                and rowIndex > inactiveAfterRowIndex
            )
    end

    return control
end

return runtime
