local deps = ... or {}
local routeTimeline = deps.timeline
local rewardItems = deps.rewardItems
local semantics = deps.semantics
local common = deps.common

if routeTimeline == nil then
    error("run_context.targets.npcs requires route timeline")
end
if rewardItems == nil then
    error("run_context.targets.npcs requires reward items")
end
if semantics == nil then
    error("run_context.targets.npcs requires reward semantics")
end
if common == nil then
    error("run_context.targets.npcs requires target common")
end

local npcTargets = {}
local EMPTY_LIST = common.EMPTY_LIST

local function variantKey(variant)
    return variant and (variant.key or variant.encounterName) or ""
end

local function targetKey(biomeKey, rowIndex, variant)
    if biomeKey == nil or rowIndex == nil then
        return ""
    end
    return tostring(biomeKey) .. ":" .. tostring(rowIndex) .. ":" .. tostring(variantKey(variant))
end

local function addNpcTarget(result, candidate)
    common.addTarget(result, "byNpc", "byNpcBiome", candidate.npcKey, candidate.biomeKey, candidate)
end

local function hasTag(tags, expected)
    for _, tag in ipairs(tags or EMPTY_LIST) do
        if tag == expected then
            return true
        end
    end
    return false
end

local function rowMatchesRequiredTag(row, requiredTag)
    if requiredTag == nil then
        return true
    end

    local option = row and row.option or nil
    local tags = option and (option.tags or option.roomTags or option.Tags) or nil
    if tags == nil then
        return true
    end
    return hasTag(tags, requiredTag)
end

local function roleMatches(context, npc, row)
    context.npcRoleLookups = context.npcRoleLookups or {}
    local lookup = context.npcRoleLookups[npc.key]
    if lookup == nil then
        lookup = common.buildKeyLookup(npc.roleKeys)
        context.npcRoleLookups[npc.key] = lookup
    end
    return lookup[row and row.roleKey or ""] == true
end

local function rewardItemsConcreteStateForSource(items, sourceKind)
    local sawSource = false
    for _, item in ipairs(items or EMPTY_LIST) do
        if item.sourceKind == sourceKind then
            sawSource = true
            if not semantics.isConcrete(item) then
                return false
            end
        end
    end
    if sawSource then
        return true
    end
    return nil
end

local function rowRewardItems(context, row)
    context.rewardItemScratch = context.rewardItemScratch or {}
    return rewardItems.collect(row, context.rewardItemScratch)
end

local function rowPrimaryRewardItem(items)
    for _, item in ipairs(items or EMPTY_LIST) do
        if item.sourceKind == "row" then
            return item
        end
    end
    return nil
end

local function rowHasConcreteNpcReward(context, row, banned)
    if banned == nil then
        return true
    end

    local items = rowRewardItems(context, row)
    local encounterState = rewardItemsConcreteStateForSource(items, "encounter")
    if encounterState ~= nil then
        return encounterState
    end
    return semantics.isConcrete(rowPrimaryRewardItem(items))
end

local function rowHasBannedReward(context, row, banned)
    if banned == nil then
        return false
    end

    for _, item in ipairs(rowRewardItems(context, row)) do
        if item.sourceKind ~= "side" and semantics.hasBannedValue(item, banned) then
            return true
        end
    end
    return false
end

local function npcRewardBanLookup(context, npc)
    if npc.rewardBanSet == nil then
        return nil
    end

    context.npcRewardBanLookup = context.npcRewardBanLookup or {}
    local lookup = context.npcRewardBanLookup[npc.rewardBanSet]
    if lookup == nil then
        lookup = common.buildKeyLookup(context.npcs.rewardBanSets and context.npcs.rewardBanSets[npc.rewardBanSet])
        context.npcRewardBanLookup[npc.rewardBanSet] = lookup
    end
    return lookup
end

local function targetKindMatches(_npc, _biomeEntry, variant, row)
    local targetKind = variant.targetKind or "combatSlot"
    if targetKind == "combatSlot" then
        return row ~= nil and row.roleKey == "Combat"
    end
    return true
end

local function variantMatchesRow(context, npc, biomeEntry, variant, row)
    if row == nil or row.valid == false then
        return false
    end
    local banned = npcRewardBanLookup(context, npc)
    return common.rowHasConcreteRoom(row)
        and rowHasConcreteNpcReward(context, row, banned)
        and roleMatches(context, npc, row)
        and targetKindMatches(npc, biomeEntry, variant, row)
        and common.valueInRange(variant.biomeDepthCache, row.biomeDepthCache)
        and common.boundsInRange(variant.biomeEncounterDepth, row.biomeEncounterDepthMin, row.biomeEncounterDepthMax)
        and rowMatchesRequiredTag(row, biomeEntry.requiredRoomTag or variant.requiredRoomTag)
end

function npcTargets.emptyTargets()
    return {
        byNpc = {},
        byNpcBiome = {},
    }
end

function npcTargets.buildTargets(context, routeKey)
    local result = npcTargets.emptyTargets()
    local route = context.routes.lookup and context.routes.lookup[routeKey] or nil
    if route == nil then
        return result
    end

    routeTimeline.walkRoute(route, {
        biomeLookup = context.biomeLookup,
        snapshotForBiome = function(_, biomeKey)
            return context:controlSnapshot(route.key, biomeKey)
        end,
        onRow = function(rowContext)
            local row = rowContext.row
            local biomeKey = rowContext.biomeKey
            for _, npcKey in ipairs(context.npcs.ordered or EMPTY_LIST) do
                local npc = context.npcs.byKey and context.npcs.byKey[npcKey] or nil
                local biomeEntry = npc and npc.biomes and npc.biomes[biomeKey] or nil
                local banned = npcRewardBanLookup(context, npc or {})
                if biomeEntry ~= nil and not rowHasBannedReward(context, row, banned) then
                    for _, variant in ipairs(biomeEntry.variants or EMPTY_LIST) do
                        if variantMatchesRow(context, npc, biomeEntry, variant, row) then
                            addNpcTarget(result, {
                                key = targetKey(biomeKey, row.rowIndex, variant),
                                label = common.candidateLabel(context, biomeKey, row, variant),
                                npcKey = npc.key,
                                biomeKey = biomeKey,
                                biomeRouteIndex = rowContext.routeBiomeIndex,
                                rowIndex = row.rowIndex,
                                routeOrdinal = rowContext.routeOrdinal,
                                roomHistoryOrdinal = rowContext.roomHistoryOrdinal,
                                runDepthCache = rowContext.runDepthCache,
                                variantKey = variantKey(variant),
                                variantLabel = variant.label or variant.key or variant.encounterName,
                                encounterName = variant.encounterName,
                                row = row,
                            })
                        end
                    end
                end
            end
        end,
    })
    return result
end

return npcTargets
