local deps = ... or {}

local declarations = deps.declarations or import("mods/composition/biome_support_declarations.lua")

local biomeSupport = {}

local CAPABILITIES = {
    "focusedRoomControls",
    "topology",
    "materialization",
    "headlessPipeline",
    "plannerActive",
}

local function fail(path, message)
    error("biome support invariant at " .. path .. ": " .. message, 0)
end

local function requireDenseList(values, path)
    if type(values) ~= "table" then
        fail(path, "expected a table")
    end
    local count = 0
    local maximum = 0
    for key in pairs(values) do
        if type(key) ~= "number" or key ~= math.floor(key) or key < 1 then
            fail(path, "expected a dense array")
        end
        count = count + 1
        maximum = math.max(maximum, key)
    end
    if count ~= maximum then
        fail(path, "expected a dense array")
    end
    return maximum
end

local function requireOnlyFields(value, path)
    local allowed = { biomeStepKey = true }
    for _, capability in ipairs(CAPABILITIES) do
        allowed[capability] = true
    end
    for key in pairs(value) do
        if allowed[key] ~= true then
            fail(path .. "." .. tostring(key), "unexpected field")
        end
    end
end

local function requireCapability(value, path)
    if type(value) ~= "boolean" then
        fail(path, "expected an explicit boolean")
    end
end

local function requireDependency(record, capability, dependency, path)
    if record[capability] and not record[dependency] then
        fail(path .. "." .. capability, "requires " .. dependency)
    end
end

local function implementationEvidence(controlManifest, supplied)
    local evidence = {
        focusedRoomControls = {},
        topology = supplied.topology or {},
        materialization = supplied.materialization or {},
        headlessPipeline = supplied.headlessPipeline or {},
        plannerActive = supplied.plannerActive or {},
    }
    local transitionalByBiome = {}
    for _, room in ipairs(controlManifest.rooms.ordered) do
        if room.implementationKind == "transitional" then
            transitionalByBiome[room.biomeStepKey] = transitionalByBiome[room.biomeStepKey] or room.key
        elseif room.implementationKind ~= "focused" then
            fail(
                "controlManifest.rooms." .. room.key .. ".implementationKind",
                "unknown implementation kind '" .. tostring(room.implementationKind) .. "'"
            )
        end
    end
    for _, room in ipairs(controlManifest.rooms.ordered) do
        if transitionalByBiome[room.biomeStepKey] == nil then
            evidence.focusedRoomControls[room.biomeStepKey] = true
        end
    end
    return evidence, transitionalByBiome
end

local function validateEvidence(record, path, evidence, transitionalByBiome)
    for _, capability in ipairs(CAPABILITIES) do
        local assembled = evidence[capability][record.biomeStepKey] == true
        if record[capability] ~= assembled then
            local detail = "does not match assembled implementation evidence"
            if capability == "focusedRoomControls" and transitionalByBiome[record.biomeStepKey] ~= nil then
                detail = detail .. "; room control '" .. transitionalByBiome[record.biomeStepKey]
                    .. "' is transitional"
            end
            fail(path .. "." .. capability, detail)
        end
    end
end

local function validateContiguousActivePrefixes(catalog, records)
    local routes = { ordered = {}, lookup = {} }
    for _, route in ipairs(catalog.routes.ordered) do
        local maximumActivePrefix = nil
        local encounteredInactive = false
        for _, biomeStep in ipairs(route.biomeSteps) do
            local record = records[biomeStep.key]
            if record.plannerActive then
                if encounteredInactive then
                    fail(
                        "routes." .. route.key .. ".plannerActive",
                        "biome '" .. biomeStep.key .. "' does not form a contiguous active prefix"
                    )
                end
                maximumActivePrefix = biomeStep.key
            else
                encounteredInactive = true
            end
        end
        local descriptor = {
            key = route.key,
            maximumActivePrefix = maximumActivePrefix,
        }
        routes.ordered[#routes.ordered + 1] = descriptor
        routes.lookup[route.key] = descriptor
    end
    return routes
end

function biomeSupport.create(catalog, controlManifest, capabilityEvidence)
    capabilityEvidence = capabilityEvidence or {}
    local evidence, transitionalByBiome = implementationEvidence(controlManifest, capabilityEvidence)
    local length = requireDenseList(declarations, "biomes")
    local declaredBiomes = {}
    for _, biome in ipairs(catalog.biomes.ordered) do
        declaredBiomes[biome.biomeStepKey] = true
    end
    local result = {
        biomes = { ordered = {}, lookup = {} },
    }

    for index = 1, length do
        local source = declarations[index]
        local path = "biomes[" .. tostring(index) .. "]"
        if type(source) ~= "table" then
            fail(path, "expected a table")
        end
        requireOnlyFields(source, path)
        if type(source.biomeStepKey) ~= "string" or source.biomeStepKey == "" then
            fail(path .. ".biomeStepKey", "expected a non-empty string")
        end
        if declaredBiomes[source.biomeStepKey] ~= true then
            fail(path .. ".biomeStepKey", "unknown biome '" .. source.biomeStepKey .. "'")
        end
        if result.biomes.lookup[source.biomeStepKey] ~= nil then
            fail(path .. ".biomeStepKey", "duplicate biome '" .. source.biomeStepKey .. "'")
        end

        local record = { biomeStepKey = source.biomeStepKey }
        for _, capability in ipairs(CAPABILITIES) do
            requireCapability(source[capability], path .. "." .. capability)
            record[capability] = source[capability]
        end
        requireDependency(record, "topology", "focusedRoomControls", path)
        requireDependency(record, "materialization", "topology", path)
        requireDependency(record, "headlessPipeline", "materialization", path)
        requireDependency(record, "plannerActive", "headlessPipeline", path)
        validateEvidence(record, path, evidence, transitionalByBiome)

        result.biomes.ordered[#result.biomes.ordered + 1] = record
        result.biomes.lookup[record.biomeStepKey] = record
    end

    for _, biome in ipairs(catalog.biomes.ordered) do
        if result.biomes.lookup[biome.biomeStepKey] == nil then
            fail("biomes", "missing declaration for biome '" .. biome.biomeStepKey .. "'")
        end
    end
    result.routes = validateContiguousActivePrefixes(catalog, result.biomes.lookup)
    return result
end

return biomeSupport
