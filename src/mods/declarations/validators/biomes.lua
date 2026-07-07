local guard = import("mods/declarations/guard.lua")
local common = import("mods/declarations/common.lua")
local requirementsValidator = import("mods/declarations/validators/requirements.lua")

local biomesValidator = {}

local function validateExits(room, context)
    guard.expectArray(room.exits, context .. ".exits")
    for index, exit in ipairs(room.exits) do
        local exitContext = context .. ".exits[" .. tostring(index) .. "]"
        guard.expectTable(exit, exitContext)
        if exit.tags ~= nil then
            guard.expectArray(exit.tags, exitContext .. ".tags")
            for tagIndex, tag in ipairs(exit.tags) do
                guard.expectString(tag, exitContext .. ".tags[" .. tostring(tagIndex) .. "]")
            end
        end
    end
end

local function validateRoomTemplate(room, roomTemplates, context)
    local template = roomTemplates[room.roomTemplate]
    if template == nil then
        guard.fail(context .. ".roomTemplate", "unknown room template '" .. room.roomTemplate .. "'")
    end
    if template.roomKindSet ~= nil and not template.roomKindSet[room.kind] then
        guard.fail(context .. ".roomTemplate", "template '" .. room.roomTemplate .. "' does not support room kind '" .. room.kind .. "'")
    end
end

local function validateOfferProfile(room, offerProfiles, context)
    if room.offerProfile == nil then
        return
    end
    if offerProfiles[room.offerProfile] == nil then
        guard.fail(context .. ".offerProfile", "unknown offer profile '" .. room.offerProfile .. "'")
    end
end

local function validateForce(force, context)
    guard.expectTable(force, context)

    local kind = guard.expectString(force.kind, context .. ".kind")
    if kind ~= "BiomeDepthWindow" then
        guard.fail(context .. ".kind", "unknown force kind '" .. kind .. "'")
    end

    local axis = guard.expectString(force.axis, context .. ".axis")
    if axis ~= "BiomeDepthCache" then
        guard.fail(context .. ".axis", "unknown force axis '" .. axis .. "'")
    end

    local start = guard.expectNumber(force.start, context .. ".start")
    local deadline = guard.expectNumber(force.deadline, context .. ".deadline")
    if deadline < start then
        guard.fail(context .. ".deadline", "force deadline must be greater than or equal to start")
    end
end

local function validateRoom(room, context)
    guard.expectTable(room, context)
    guard.expectString(room.key, context .. ".key")
    guard.expectString(room.label, context .. ".label")
    guard.expectString(room.kind, context .. ".kind")
    guard.expectString(room.roomTemplate, context .. ".roomTemplate")
    guard.expectNonEmptyArray(room.tags, context .. ".tags")
    guard.expectTable(room.caps, context .. ".caps")
    guard.expectOptionalString(room.encounterProfile, context .. ".encounterProfile")
    guard.expectOptionalString(room.offerProfile, context .. ".offerProfile")
    guard.expectOptionalBoolean(room.terminal, context .. ".terminal")
    guard.expectOptionalTable(room.counters, context .. ".counters")
    validateExits(room, context)
end

local function routeContainsBiome(route, biomeKey)
    for _, routeBiomeKey in ipairs(route.biomeKeys) do
        if routeBiomeKey == biomeKey then
            return true
        end
    end
    return false
end

local function validateBiomeRoute(biome, routesCatalog, context)
    local route = routesCatalog.lookup[biome.routeKey]
    if route == nil then
        guard.fail(context .. ".routeKey", "unknown route '" .. biome.routeKey .. "'")
    end
    if not routeContainsBiome(route, biome.key) then
        guard.fail(context .. ".key", "biome '" .. biome.key .. "' is not in route '" .. biome.routeKey .. "'")
    end
end

local function validateBiome(biome, context)
    guard.expectTable(biome, context)
    guard.expectString(biome.key, context .. ".key")
    guard.expectString(biome.label, context .. ".label")
    guard.expectString(biome.routeKey, context .. ".routeKey")
    guard.expectTable(biome.structure, context .. ".structure")
    guard.expectString(biome.structure.kind, context .. ".structure.kind")
    guard.expectTable(biome.structure.start, context .. ".structure.start")
    local startRoomKind = guard.expectString(biome.structure.start.roomKind, context .. ".structure.start.roomKind")
    guard.expectTable(biome.structure.terminal, context .. ".structure.terminal")
    guard.expectString(biome.structure.terminal.prebossRoomKey, context .. ".structure.terminal.prebossRoomKey")
    guard.expectNonEmptyArray(biome.rooms, context .. ".rooms")

    local roomsByKey = guard.indexByKey(biome.rooms, context .. ".rooms")
    if roomsByKey[biome.structure.terminal.prebossRoomKey] == nil then
        guard.fail(context .. ".structure.terminal.prebossRoomKey", "room '" .. biome.structure.terminal.prebossRoomKey .. "' is not declared")
    end
    local hasStartRoomKind = false
    for _, room in ipairs(biome.rooms) do
        if room.kind == startRoomKind then
            hasStartRoomKind = true
            break
        end
    end
    if not hasStartRoomKind then
        guard.fail(context .. ".structure.start.roomKind", "no declared room has kind '" .. startRoomKind .. "'")
    end

    return roomsByKey
end

function biomesValidator.validateList(biomes, namedRequirements, roomTemplates, offerProfiles, routesCatalog)
    guard.expectArray(biomes, "biomes")

    local normalizedBiomes = {}
    for index, biome in ipairs(biomes) do
        local context = "biomes[" .. tostring(index) .. "]"
        local roomsByKey = validateBiome(biome, context)
        validateBiomeRoute(biome, routesCatalog, context)

        for roomIndex, room in ipairs(biome.rooms) do
            local roomContext = context .. ".rooms[" .. tostring(roomIndex) .. "]"
            validateRoom(room, roomContext)
            validateRoomTemplate(room, roomTemplates, roomContext)
            validateOfferProfile(room, offerProfiles, roomContext)

            if room.eligibility ~= nil then
                requirementsValidator.validateRequirement(room.eligibility, namedRequirements, roomContext .. ".eligibility")
            end
            if room.force ~= nil then
                validateForce(room.force, roomContext .. ".force")
            end
        end

        local normalized = common.shallowCopy(biome)
        normalized.rooms = {
            ordered = biome.rooms,
            lookup = roomsByKey,
        }
        normalizedBiomes[index] = normalized
    end

    return common.packageOrderedMap(normalizedBiomes, "biomes")
end

return biomesValidator
