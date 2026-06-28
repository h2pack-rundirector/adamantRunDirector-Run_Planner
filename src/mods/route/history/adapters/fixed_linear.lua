local fixedLinear = {}

local EMPTY_LIST = {}
local BIOME_ENCOUNTER_DEPTH_START = 1

local function numericCost(value, fallback)
    local cost = math.floor(tonumber(value) or fallback or 0)
    if cost < 0 then
        return 0
    end
    return cost
end

local function roleOptionList(role)
    return role and (role.roomOptions or role.mapOptions) or EMPTY_LIST
end

local function optionByKey(role, optionKey)
    if role == nil or optionKey == nil or optionKey == "" then
        return nil
    end
    if role.optionsByKey ~= nil then
        return role.optionsByKey[optionKey]
    end
    for _, option in ipairs(roleOptionList(role)) do
        if option.key == optionKey then
            return option
        end
    end
    return nil
end

local function fixedSpecialByKind(slotLayout, kind)
    for _, special in pairs(slotLayout and slotLayout.special or {}) do
        if special.kind == kind or special.key == kind then
            return special
        end
    end
    return nil
end

local function fixedSpecialOrdinal(slotLayout, key)
    for ordinal, special in pairs(slotLayout and slotLayout.special or {}) do
        if special.kind == key or special.key == key then
            return math.floor(tonumber(ordinal) or 0)
        end
    end
    return nil
end

local function routeStartOrdinal(slotLayout)
    return math.floor(tonumber(slotLayout and slotLayout.routeStartOrdinal or 1) or 1)
end

local function fixedPrefixRowCount(slotLayout)
    local count = 0
    if slotLayout and slotLayout.entry ~= nil then
        count = count + 1
    end
    for ordinal, special in pairs(slotLayout and slotLayout.special or {}) do
        if special.kind == "opening"
            and math.floor(tonumber(ordinal) or 0) < routeStartOrdinal(slotLayout)
        then
            count = count + 1
        end
    end
    return count
end

local function roleForRow(biome, selectedRow)
    local role = biome.rolesByKey and biome.rolesByKey[selectedRow.roleKey] or nil
    if role ~= nil then
        return role
    end

    local special = fixedSpecialByKind(biome.slotLayout, selectedRow.roleKey)
    if special ~= nil then
        return special
    end
    return nil
end

local function defaultOption(role)
    return roleOptionList(role)[1]
end

local function optionForRow(role, selectedRow)
    return optionByKey(role, selectedRow.optionKey) or defaultOption(role)
end

local function roomKeyFor(role, option)
    return option and option.key
        or role and role.roomKey
        or role and role.room and role.room.key
        or nil
end

local function eventKeyFor(selectedRow, role, option)
    return roomKeyFor(role, option)
        or role and role.key
        or selectedRow.roleKey
end

local function costValue(slotLayout, role, option, field, fallback)
    if option ~= nil and option[field] ~= nil then
        return numericCost(option[field], fallback)
    end
    if role ~= nil and role[field] ~= nil then
        return numericCost(role[field], fallback)
    end
    if field == "biomeDepthCacheCost" then
        if role ~= nil and role.kind ~= "biomeRow" then
            return numericCost(
                slotLayout and slotLayout.defaultFixedBiomeDepthCacheCost,
                fallback
            )
        end
        return numericCost(slotLayout and slotLayout.routeBiomeDepthCacheCost, fallback)
    end
    return fallback
end

local function selectedRouteOrdinal(slotLayout, selectedRow)
    local entry = slotLayout and slotLayout.entry or nil
    if entry ~= nil and selectedRow.roleKey == (entry.key or "Intro") then
        return entry.routeOrdinal or 0
    end

    local specialOrdinal = fixedSpecialOrdinal(slotLayout, selectedRow.roleKey)
    if specialOrdinal ~= nil then
        return specialOrdinal
    end

    return routeStartOrdinal(slotLayout)
        + (selectedRow.rowIndex or 1)
        - fixedPrefixRowCount(slotLayout)
        - 1
end

local function appendRoom(history, routeHistory, context, selectedRow, resolved)
    local roomKey = roomKeyFor(resolved.role, resolved.option)
    local eventKey = eventKeyFor(selectedRow, resolved.role, resolved.option)
    if eventKey == nil or eventKey == "" then
        return
    end

    routeHistory.emitAt(history, {
        routeKey = context.routeKey,
        controlName = context.snapshot.controlName,
        biomeKey = context.biome.key,
        routeBiomeIndex = context.routeBiomeIndex,
        rowIndex = selectedRow.rowIndex,
        routeOrdinal = resolved.routeOrdinal,
        roomHistoryOrdinal = context.routeState.roomHistoryOrdinal,
        runDepthCache = 1 + context.routeState.roomHistoryOrdinal,
        runEncounterDepth = context.routeState.runEncounterDepth,
        biomeDepthCache = context.biomeState.biomeDepthCache,
        biomeEncounterDepth = context.biomeState.biomeEncounterDepth,
    }, {
        kind = "room",
        eventKey = eventKey,
        groupKey = selectedRow.roleKey,
        sourceKind = "row",
        roomKey = roomKey,
        roleKey = selectedRow.roleKey,
        optionKey = selectedRow.optionKey,
        variantKey = selectedRow.variantKey,
        source = selectedRow,
    })
end

local function resolveRow(context, selectedRow)
    local role = roleForRow(context.biome, selectedRow)
    local option = optionForRow(role, selectedRow)
    local slotLayout = context.biome.slotLayout or {}
    local routeOrdinal = selectedRouteOrdinal(slotLayout, selectedRow)
    local biomeDepthCacheCost = costValue(slotLayout, role, option, "biomeDepthCacheCost", 0)
    local biomeEncounterDepthCost = costValue(slotLayout, role, option, "biomeEncounterDepthCost", 0)
    local roomHistoryCost = costValue(slotLayout, role, option, "roomHistoryCost", 1)

    if selectedRow.roleKey ~= "Opening"
        and selectedRow.roleKey ~= "Intro"
        and selectedRow.roleKey ~= "Preboss"
        and role ~= nil
        and role.kind == nil
    then
        biomeDepthCacheCost = costValue(slotLayout, role, option, "biomeDepthCacheCost", 1)
    end

    return {
        role = role,
        option = option,
        routeOrdinal = routeOrdinal,
        biomeDepthCacheCost = biomeDepthCacheCost,
        biomeEncounterDepthCost = biomeEncounterDepthCost,
        roomHistoryCost = roomHistoryCost,
    }
end

local function advanceRoomHistoryBeforeEmit(context, resolved)
    context.routeState.roomHistoryOrdinal = context.routeState.roomHistoryOrdinal + resolved.roomHistoryCost
end

local function advanceNextRoomCountersAfterEmit(context, resolved)
    context.routeState.runEncounterDepth = context.routeState.runEncounterDepth + resolved.biomeEncounterDepthCost
    context.biomeState.biomeDepthCache = context.biomeState.biomeDepthCache + resolved.biomeDepthCacheCost
    context.biomeState.biomeEncounterDepth = context.biomeState.biomeEncounterDepth + resolved.biomeEncounterDepthCost
end

function fixedLinear.build(args)
    local history = args.history
    local routeHistory = args.routeHistory
    local context = {
        routeKey = args.route and args.route.key or args.snapshot.routeKey,
        routeBiomeIndex = args.routeBiomeIndex,
        snapshot = args.snapshot,
        biome = args.biome,
        routeState = args.routeState,
        biomeState = {
            biomeDepthCache = numericCost(
                args.biome and args.biome.slotLayout and args.biome.slotLayout.biomeDepthCacheStart,
                0
            ),
            biomeEncounterDepth = BIOME_ENCOUNTER_DEPTH_START,
        },
    }

    for _, selectedRow in ipairs(args.snapshot.rows or EMPTY_LIST) do
        local resolved = resolveRow(context, selectedRow)
        advanceRoomHistoryBeforeEmit(context, resolved)
        appendRoom(history, routeHistory, context, selectedRow, resolved)
        advanceNextRoomCountersAfterEmit(context, resolved)
    end
end

return fixedLinear
