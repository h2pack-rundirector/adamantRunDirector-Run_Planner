local selectors = {}

local function biomeByStep(catalog, biomeStepKey)
    for _, biome in ipairs(catalog.biomes.ordered) do
        if biome.biomeStepKey == biomeStepKey then
            return biome
        end
    end
end

local function transientString(alias, default, maxLen)
    return {
        alias = alias,
        type = "string",
        default = default or "",
        maxLen = maxLen or 64,
        persist = false,
        hash = false,
    }
end

local function maximumExitCount(biome)
    local maximum = 0
    for _, room in ipairs(biome.rooms.ordered) do
        maximum = math.max(maximum, #room.exits)
    end
    return maximum
end

local function buildLinear(storage, biome)
    local prefix = "PlannerUi_" .. biome.biomeStepKey
    local result = {
        start = prefix .. "_Start",
        batches = {},
    }
    storage[#storage + 1] = transientString(result.start)
    local maxExits = maximumExitCount(biome)
    for batchIndex = 1, biome.layout.bounds.maxBatches do
        local batch = {
            targets = {},
        }
        for exitIndex = 1, maxExits do
            local targetPrefix = prefix .. "_Batch" .. tostring(batchIndex)
                .. "Target" .. tostring(exitIndex)
            local target = {
                category = targetPrefix .. "Category",
                room = targetPrefix .. "Room",
            }
            batch.targets[exitIndex] = target
            storage[#storage + 1] = transientString(target.category, "", 16)
            storage[#storage + 1] = transientString(target.room)
        end
        result.batches[batchIndex] = batch
    end
    return result
end

function selectors.build(catalog, editableBiomeStepKeys)
    local result = {
        storage = {
            transientString("PlannerUi_UnderworldPanel", "route"),
            transientString("PlannerUi_SurfacePanel", "route"),
        },
        routePanels = {
            Underworld = "PlannerUi_UnderworldPanel",
            Surface = "PlannerUi_SurfacePanel",
        },
        biomes = { lookup = {} },
    }
    for _, biomeStepKey in ipairs(editableBiomeStepKeys) do
        local biome = biomeByStep(catalog, biomeStepKey)
        if biome.layout.kind ~= "LinearBiome" then
            error("missing UI selector builder for layout kind '" .. biome.layout.kind .. "'", 0)
        end
        result.biomes.lookup[biomeStepKey] = buildLinear(result.storage, biome)
    end
    return result
end

return selectors
