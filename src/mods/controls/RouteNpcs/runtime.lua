local deps = ... or {}

local data = deps.data

local runtime = {}

local EMPTY_LIST = {}
local DISABLED_BIOME_KEY = data.DISABLED_BIOME_KEY
local EMPTY_TARGETS = {
    byNpc = {},
    byNpcBiome = {},
}

local EMPTY_OPTS = {
    values = {},
    displayValues = {},
    lookup = {},
}

local function readField(fields, rowIndex, alias)
    return fields.Targets:read(rowIndex, alias) or ""
end

local function writeField(fields, rowIndex, alias, value)
    fields.Targets:get(rowIndex, alias):write(value)
end

local function markDirty(instance)
    if instance.routeContext ~= nil and instance.routeContext.markDirty ~= nil then
        instance.routeContext:markDirty(instance.routeKey)
    end
end

local function routeGeneration(instance)
    if instance.routeContext ~= nil and instance.routeContext.routeGeneration ~= nil then
        return instance.routeContext:routeGeneration(instance.routeKey)
    end
    return 0
end

local function biomeInConfiguredScope(instance, biomeKey)
    if instance.routeContext ~= nil and instance.routeContext.isBiomeInConfiguredScope ~= nil then
        return instance.routeContext:isBiomeInConfiguredScope(instance.routeKey, biomeKey)
    end
    return true
end

local function slotInConfiguredScope(instance, slot)
    if slot == nil then
        return false
    end
    if slot.fixedBiomeKey ~= nil then
        return biomeInConfiguredScope(instance, slot.fixedBiomeKey)
    end
    for _, biomeKey in ipairs(instance.route and instance.route.biomes or EMPTY_LIST) do
        if biomeInConfiguredScope(instance, biomeKey)
            and slot.npc
            and slot.npc.biomes
            and slot.npc.biomes[biomeKey] ~= nil
        then
            return true
        end
    end
    return false
end

local function biomeLabel(instance, biomeKey)
    local biome = instance.biomeLookup and instance.biomeLookup[biomeKey] or nil
    return tostring(biome and (biome.label or biome.key) or biomeKey or "")
end

local function roomLabel(candidate)
    return tostring(candidate.label or ("Row " .. tostring(candidate.rowIndex or "")))
end

local function variantLabel(candidate)
    return tostring(candidate.variantLabel or candidate.variantKey or candidate.encounterName or "")
end

local function addSelectedOption(opts, value, label)
    if value == nil or value == "" or opts.lookup[value] ~= nil then
        return opts
    end
    opts.values[#opts.values + 1] = value
    opts.displayValues[value] = label
    opts.lookup[value] = false
    return opts
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
        if biomeInConfiguredScope(instance, biomeKey)
            and slot.npc
            and slot.npc.biomes
            and slot.npc.biomes[biomeKey] ~= nil
        then
            addBiome(biomeKey)
        end
    end
    return opts
end

local function ensureIndex(control, rowIndex)
    local bucket = control:targetCandidates(rowIndex)
    control._targetIndexByRow = control._targetIndexByRow or {}
    local index = control._targetIndexByRow[rowIndex]
    if index ~= nil and index.source == bucket then
        return index
    end
    index = {
        source = bucket,
        roomsByBiome = {},
        variantsByBiomeRow = {},
    }
    for _, candidate in ipairs(bucket.values or EMPTY_LIST) do
        local biomeRooms = index.roomsByBiome[candidate.biomeKey]
        if biomeRooms == nil then
            biomeRooms = {
                values = {},
                displayValues = {},
                lookup = {},
            }
            index.roomsByBiome[candidate.biomeKey] = biomeRooms
        end
        local rowKey = tostring(candidate.rowIndex or "")
        if biomeRooms.lookup[rowKey] == nil then
            biomeRooms.values[#biomeRooms.values + 1] = rowKey
            biomeRooms.displayValues[rowKey] = roomLabel(candidate)
            biomeRooms.lookup[rowKey] = candidate
        end
        local biomeVariants = index.variantsByBiomeRow[candidate.biomeKey]
        if biomeVariants == nil then
            biomeVariants = {}
            index.variantsByBiomeRow[candidate.biomeKey] = biomeVariants
        end
        local rowVariants = biomeVariants[rowKey]
        if rowVariants == nil then
            rowVariants = {
                values = {},
                displayValues = {},
                lookup = {},
            }
            biomeVariants[rowKey] = rowVariants
        end
        local variantKey = candidate.variantKey or ""
        if rowVariants.lookup[variantKey] == nil then
            rowVariants.values[#rowVariants.values + 1] = variantKey
            rowVariants.displayValues[variantKey] = variantLabel(candidate)
            rowVariants.lookup[variantKey] = candidate
        end
    end
    control._targetIndexByRow[rowIndex] = index
    return index
end

local function emptyRoomOptions(control, rowIndex)
    control._emptyRoomOptionsByRow = control._emptyRoomOptionsByRow or {}
    local opts = control._emptyRoomOptionsByRow[rowIndex]
    if opts == nil then
        opts = {
            values = {},
            displayValues = {},
            lookup = {},
        }
        control._emptyRoomOptionsByRow[rowIndex] = opts
    end
    for index = #opts.values, 1, -1 do
        opts.values[index] = nil
    end
    for key in pairs(opts.displayValues) do
        opts.displayValues[key] = nil
    end
    for key in pairs(opts.lookup) do
        opts.lookup[key] = nil
    end
    return opts
end

function runtime.create(fields, instance)
    local control = {}

    function control.name()
        return instance.name
    end

    function control.routeKey()
        return instance.routeKey
    end

    function control.setRouteContext(_, routeContext, routeKey)
        instance.routeContext = routeContext
        instance.routeKey = routeKey or instance.routeKey
    end

    function control.slot(_, rowIndex)
        return instance.slots[math.floor(tonumber(rowIndex) or 0)]
    end

    function control.rowCount()
        return fields.Targets:count()
    end

    function control.rawBiomeKey(_, rowIndex)
        return readField(fields, rowIndex, "BiomeKey")
    end

    function control.rawRowIndex(_, rowIndex)
        return readField(fields, rowIndex, "RowIndex")
    end

    function control.rawVariantKey(_, rowIndex)
        return readField(fields, rowIndex, "VariantKey")
    end

    function control:isDisabled(rowIndex)
        return self:rawBiomeKey(rowIndex) == DISABLED_BIOME_KEY
    end

    function control:selectedBiomeKey(rowIndex)
        local biomeKey = self:rawBiomeKey(rowIndex)
        return biomeKey ~= DISABLED_BIOME_KEY and biomeKey or ""
    end

    function control:selectedRowIndex(rowIndex)
        return self:rawRowIndex(rowIndex)
    end

    function control:selectedVariantKey(rowIndex)
        local variantKey = self:rawVariantKey(rowIndex)
        if variantKey ~= "" then
            return variantKey
        end
        local variants = self:variantOptions(rowIndex)
        return variants.values[1] or ""
    end

    function control:targetCandidates(rowIndex)
        local slot = self:slot(rowIndex)
        if not slotInConfiguredScope(instance, slot)
            or instance.routeContext == nil
            or instance.routeContext.npcTargetsForSlot == nil
        then
            return EMPTY_TARGETS
        end
        return instance.routeContext:npcTargetsForSlot(instance.routeKey, slot.npcKey, slot.fixedBiomeKey)
            or EMPTY_TARGETS
    end

    function control:biomeOptions(rowIndex)
        self._biomeOptionsByRow = self._biomeOptionsByRow or {}
        self._biomeOptionsGenerationByRow = self._biomeOptionsGenerationByRow or {}
        local generation = routeGeneration(instance)
        local opts = self._biomeOptionsByRow[rowIndex]
        if opts == nil or self._biomeOptionsGenerationByRow[rowIndex] ~= generation then
            opts = buildBiomeOptions(instance, self:slot(rowIndex))
            self._biomeOptionsByRow[rowIndex] = opts
            self._biomeOptionsGenerationByRow[rowIndex] = generation
        end
        return opts
    end

    function control:roomOptions(rowIndex)
        local biomeKey = self:selectedBiomeKey(rowIndex)
        if biomeKey == "" then
            return EMPTY_OPTS
        end
        local opts = ensureIndex(self, rowIndex).roomsByBiome[biomeKey]
        if opts == nil then
            opts = emptyRoomOptions(self, rowIndex)
        end
        local selected = self:selectedRowIndex(rowIndex)
        return addSelectedOption(opts, selected, "Row " .. tostring(selected))
    end

    function control:variantOptions(rowIndex)
        local biomeKey = self:selectedBiomeKey(rowIndex)
        local rowKey = self:selectedRowIndex(rowIndex)
        if biomeKey == "" or rowKey == "" then
            return EMPTY_OPTS
        end
        local byBiome = ensureIndex(self, rowIndex).variantsByBiomeRow[biomeKey]
        local opts = byBiome and byBiome[tostring(rowKey)] or nil
        if opts == nil then
            return EMPTY_OPTS
        end
        return opts
    end

    function control:shouldRenderRoom(rowIndex)
        return self:selectedBiomeKey(rowIndex) ~= ""
    end

    function control:shouldRenderVariant(rowIndex)
        return self:selectedBiomeKey(rowIndex) ~= ""
            and self:selectedRowIndex(rowIndex) ~= ""
            and self:variantOptions(rowIndex).values[2] ~= nil
    end

    function control.valueStates(_, rowIndex, alias)
        local feedback = instance.feedback
        local row = feedback and feedback.byRow and feedback.byRow[rowIndex] or nil
        return row and row.valueStates and row.valueStates[alias] or nil
    end

    function control.applyRouteFeedback(_, feedback, generation)
        instance.feedback = feedback
        instance.feedbackGeneration = generation
    end

    function control.writeBiome(_, rowIndex, biomeKey)
        writeField(fields, rowIndex, "BiomeKey", biomeKey or DISABLED_BIOME_KEY)
        writeField(fields, rowIndex, "RowIndex", "")
        writeField(fields, rowIndex, "VariantKey", "")
        markDirty(instance)
    end

    function control:writeRoom(rowIndex, targetRowIndex)
        writeField(fields, rowIndex, "RowIndex", targetRowIndex or "")
        local variants = self:variantOptions(rowIndex)
        writeField(fields, rowIndex, "VariantKey", variants.values[1] or "")
        markDirty(instance)
    end

    function control.writeVariant(_, rowIndex, variantKey)
        writeField(fields, rowIndex, "VariantKey", variantKey or "")
        markDirty(instance)
    end

    function control:slotInConfiguredScope(rowIndex)
        return slotInConfiguredScope(instance, self:slot(rowIndex))
    end

    function control:rowSnapshot(rowIndex)
        local slot = self:slot(rowIndex)
        if slot == nil or not self:slotInConfiguredScope(rowIndex) then
            return nil
        end
        if self:isDisabled(rowIndex) then
            return {
                rowIndex = rowIndex,
                slotKey = slot.key,
                npcKey = slot.npcKey,
                groupKey = slot.groupKey,
                mode = "Disabled",
                disabled = true,
            }
        end
        return {
            rowIndex = rowIndex,
            slotKey = slot.key,
            npcKey = slot.npcKey,
            groupKey = slot.groupKey,
            mode = "Target",
            biomeKey = self:selectedBiomeKey(rowIndex),
            targetRowIndex = self:selectedRowIndex(rowIndex),
            variantKey = self:rawVariantKey(rowIndex),
        }
    end

    function control:read(path)
        if path == "selectedNpcSnapshot" then
            local rows = {}
            for rowIndex = 1, self:rowCount() do
                local row = self:rowSnapshot(rowIndex)
                if row ~= nil then
                    rows[#rows + 1] = row
                end
            end
            return {
                controlName = instance.name,
                routeKey = instance.routeKey,
                rows = rows,
            }
        end
        return nil
    end

    return control
end

return runtime
