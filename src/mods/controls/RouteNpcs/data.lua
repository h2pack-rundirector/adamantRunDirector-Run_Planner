local data = {}

local EMPTY_LIST = {}

local function routeBiomeLookup(route)
    local lookup = {}
    for _, biomeKey in ipairs(route and route.biomes or EMPTY_LIST) do
        lookup[biomeKey] = true
    end
    return lookup
end

local function routeHasNpc(routeLookup, npc)
    for biomeKey in pairs(npc and npc.biomes or {}) do
        if routeLookup[biomeKey] then
            return true
        end
    end
    return false
end

local function addSlot(instance, npc, group, fixedBiomeKey)
    local label = npc.label or npc.key

    local rowIndex = #instance.slots + 1
    instance.slots[rowIndex] = {
        rowIndex = rowIndex,
        key = fixedBiomeKey ~= nil and (npc.key .. "_" .. fixedBiomeKey) or npc.key,
        label = label,
        npcKey = npc.key,
        npc = npc,
        groupKey = npc.routeGroup,
        group = group,
        fixedBiomeKey = fixedBiomeKey,
    }
end

local function addPerBiomeSlots(instance, npc, group)
    for _, biomeKey in ipairs(instance.route.biomes or EMPTY_LIST) do
        if npc.biomes and npc.biomes[biomeKey] ~= nil then
            addSlot(instance, npc, group, biomeKey)
        end
    end
end

local function buildSlots(instance)
    local routeLookup = routeBiomeLookup(instance.route)
    instance.slots = {}

    for _, npcKey in ipairs(instance.npcs.ordered or EMPTY_LIST) do
        local npc = instance.npcs.byKey and instance.npcs.byKey[npcKey] or nil
        local group = npc and instance.npcs.groups and instance.npcs.groups[npc.routeGroup] or nil
        if npc ~= nil and routeHasNpc(routeLookup, npc) then
            if npc.maxSelectionsPerRun == 1 then
                addSlot(instance, npc, group)
            elseif group ~= nil and group.maxSelectionsPerBiome == 1 then
                addPerBiomeSlots(instance, npc, group)
            else
                addSlot(instance, npc, group)
            end
        end
    end

    instance.slotCount = #instance.slots
end

function data.prepare(instance)
    instance.route = instance.route or {}
    instance.routeKey = instance.route.key or instance.routeKey or instance.name
    instance.label = instance.label or "NPCs"
    instance.npcs = instance.npcs or {}
    instance.biomeLookup = instance.biomeLookup or {}
    buildSlots(instance)
    return instance
end

function data.storage(instance)
    return {
        {
            key = "Targets",
            type = "table",
            minRows = instance.slotCount,
            defaultRows = instance.slotCount,
            maxRows = instance.slotCount,
            row = {
                { key = "TargetKey", type = "string", default = "", maxLen = 128 },
                { key = "VariantKey", type = "string", default = "", maxLen = 64 },
                { key = "BiomeKey", type = "string", default = "", maxLen = 8 },
                { key = "RowIndex", type = "string", default = "", maxLen = 16 },
            },
        },
    }
end

function data.targetKey(biomeKey, rowIndex, variantKey)
    if biomeKey == nil or biomeKey == "" or rowIndex == nil or rowIndex == "" then
        return ""
    end
    return tostring(biomeKey) .. ":" .. tostring(rowIndex) .. ":" .. tostring(variantKey or "")
end

return data
