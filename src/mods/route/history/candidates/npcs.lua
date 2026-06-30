local deps = ... or {}

local routeHistory = deps.history

local npcCandidates = {}

local EMPTY_LIST = {}

local function variantKey(variant)
    return variant and (variant.key or variant.encounterName) or ""
end

local function targetKey(biomeKey, rowIndex, variant)
    return tostring(biomeKey or "") .. ":" .. tostring(rowIndex or "") .. ":" .. tostring(variantKey(variant))
end

local function rangeContains(range, value)
    if range == nil then
        return true
    end
    if value == nil then
        return false
    end
    if range.exact ~= nil and value ~= range.exact then
        return false
    end
    if range.min ~= nil and value < range.min then
        return false
    end
    if range.max ~= nil and value > range.max then
        return false
    end
    return true
end

local function keyLookup(values)
    local lookup = {}
    for _, value in ipairs(values or EMPTY_LIST) do
        lookup[value] = true
    end
    return lookup
end

local function hasTag(tags, expected)
    if expected == nil then
        return true
    end
    for _, tag in ipairs(tags or EMPTY_LIST) do
        if tag == expected then
            return true
        end
    end
    return false
end

local function roleMatches(biome, npc, entry)
    local lookup = keyLookup(npc and npc.roleKeys)
    if lookup[entry and entry.roleKey or ""] then
        return true
    end
    local role = biome and biome.rolesByKey and biome.rolesByKey[entry and entry.roleKey or ""] or nil
    for _, roleKey in ipairs(role and role.npcRoleKeys or EMPTY_LIST) do
        if lookup[roleKey] then
            return true
        end
    end
    return false
end

local function targetKindMatches(biome, variant, entry)
    local targetKind = variant.targetKind or "combatSlot"
    if targetKind ~= "combatSlot" then
        return true
    end
    if entry and entry.roleKey == "Combat" then
        return true
    end
    local role = biome and biome.rolesByKey and biome.rolesByKey[entry and entry.roleKey or ""] or nil
    return role and role.targetKinds and role.targetKinds.combatSlot == true
end

local function rewardBanLookup(npcs, npc)
    if npc == nil or npc.rewardBanSet == nil then
        return nil
    end
    return keyLookup(npcs.rewardBanSets and npcs.rewardBanSets[npc.rewardBanSet])
end

local function roomHasBannedLoot(history, entry, banned)
    if banned == nil then
        return false
    end
    for _, loot in ipairs(routeHistory.byKind(history, "loot")) do
        if loot.parentEntry == entry and banned[loot.lootType] == true then
            return true
        end
    end
    return false
end

local function biomeLabel(biome)
    return tostring(biome and (biome.label or biome.key) or "")
end

local function roomLabel(biome, entry)
    local room = entry and (entry.roomKey or entry.eventKey) or ""
    return biomeLabel(biome) .. " Room " .. tostring(entry and entry.rowIndex or "") .. " - " .. tostring(room)
end

local function variantMatches(history, npcs, biomeLookup, npc, biomeEntry, variant, entry)
    local biome = biomeLookup and biomeLookup[entry and entry.biomeKey or ""] or nil
    return roleMatches(biome, npc, entry)
        and targetKindMatches(biome, variant, entry)
        and rangeContains(variant.biomeDepthCache, entry and entry.biomeDepthCache)
        and rangeContains(variant.biomeEncounterDepth, entry and entry.biomeEncounterDepth)
        and hasTag(entry and entry.tags, biomeEntry.requiredRoomTag or variant.requiredRoomTag)
        and not roomHasBannedLoot(history, entry, rewardBanLookup(npcs, npc))
end

local function appendCandidate(targets, candidate)
    targets.values[#targets.values + 1] = candidate
    targets.lookup[candidate.key] = candidate
    local byNpc = targets.byNpc[candidate.npcKey]
    if byNpc == nil then
        byNpc = {
            values = {},
            lookup = {},
        }
        targets.byNpc[candidate.npcKey] = byNpc
    end
    byNpc.values[#byNpc.values + 1] = candidate
    byNpc.lookup[candidate.key] = candidate

    local byNpcBiome = targets.byNpcBiome[candidate.npcKey]
    if byNpcBiome == nil then
        byNpcBiome = {}
        targets.byNpcBiome[candidate.npcKey] = byNpcBiome
    end
    local byBiome = byNpcBiome[candidate.biomeKey]
    if byBiome == nil then
        byBiome = {
            values = {},
            lookup = {},
        }
        byNpcBiome[candidate.biomeKey] = byBiome
    end
    byBiome.values[#byBiome.values + 1] = candidate
    byBiome.lookup[candidate.key] = candidate
end

function npcCandidates.build(args)
    local history = args and args.history or nil
    local npcs = args and args.npcs or {}
    local biomeLookup = args and args.biomeLookup or {}
    local result = {
        values = {},
        lookup = {},
        byNpc = {},
        byNpcBiome = {},
    }
    for _, entry in ipairs(routeHistory.byKind(history, "room")) do
        local npcBiomeKey = entry.biomeKey
        for _, npcKey in ipairs(npcs.ordered or EMPTY_LIST) do
            local npc = npcs.byKey and npcs.byKey[npcKey] or nil
            local biomeEntry = npc and npc.biomes and npc.biomes[npcBiomeKey] or nil
            if biomeEntry ~= nil then
                for _, variant in ipairs(biomeEntry.variants or EMPTY_LIST) do
                    if variantMatches(history, npcs, biomeLookup, npc, biomeEntry, variant, entry) then
                        appendCandidate(result, {
                            key = targetKey(npcBiomeKey, entry.rowIndex, variant),
                            label = roomLabel(biomeLookup[npcBiomeKey], entry),
                            npcKey = npc.key,
                            groupKey = npc.routeGroup,
                            biomeKey = npcBiomeKey,
                            routeBiomeIndex = entry.routeBiomeIndex,
                            rowIndex = entry.rowIndex,
                            routeOrdinal = entry.routeOrdinal,
                            roomHistoryOrdinal = entry.roomHistoryOrdinal,
                            roomKey = entry.roomKey,
                            variantKey = variantKey(variant),
                            variantLabel = variant.label or variant.key or variant.encounterName,
                            encounterName = variant.encounterName,
                            entry = entry,
                        })
                    end
                end
            end
        end
    end
    return result
end

return npcCandidates
