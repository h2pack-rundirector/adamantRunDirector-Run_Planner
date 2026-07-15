local manifest = {}

local function roomControlKey(biomeStepKey, gameRoomKey, biomeKey)
    local prefix = biomeKey .. "_"
    if string.sub(gameRoomKey, 1, #prefix) ~= prefix then
        error("room key '" .. gameRoomKey .. "' does not match biome '" .. biomeKey .. "'", 0)
    end
    return biomeStepKey .. "_" .. string.sub(gameRoomKey, #prefix + 1)
end

function manifest.build(catalog)
    local result = {
        routes = { ordered = {}, lookup = {} },
        rooms = { ordered = {}, lookup = {} },
    }
    for _, route in ipairs(catalog.routes.ordered) do
        local descriptor = {
            key = route.key,
            templateKey = route.controlTemplateKey,
            configuredPrefixValues = { "" },
            configuredPrefixLookup = { [""] = true },
        }
        for _, biomeStep in ipairs(route.biomeSteps) do
            descriptor.configuredPrefixValues[#descriptor.configuredPrefixValues + 1] = biomeStep.key
            descriptor.configuredPrefixLookup[biomeStep.key] = true
        end
        result.routes.ordered[#result.routes.ordered + 1] = descriptor
        result.routes.lookup[descriptor.key] = descriptor
    end
    for _, biome in ipairs(catalog.biomes.ordered) do
        for _, room in ipairs(biome.rooms.ordered) do
            local key = roomControlKey(biome.biomeStepKey, room.key, biome.key)
            if result.rooms.lookup[key] ~= nil then
                error("duplicate room-control key '" .. key .. "'", 0)
            end
            local descriptor = {
                key = key,
                routeKey = biome.routeKey,
                biomeStepKey = biome.biomeStepKey,
                gameRoomKey = room.key,
                templateKey = room.templateKey,
                localSlots = {},
                state = import("mods/controls/state_manifest.lua").build(catalog, room),
            }
            local encounterProfile = catalog.encounterProfiles.lookup[room.encounterProfileKey]
            for _, phase in ipairs(encounterProfile.phases) do
                if phase.offerPoint ~= nil then
                    descriptor.localSlots[#descriptor.localSlots + 1] = {
                        key = phase.offerPoint.key,
                        kind = "offerPoint",
                        phaseKey = phase.key,
                    }
                end
            end
            for _, child in ipairs(room.localChildren) do
                descriptor.localSlots[#descriptor.localSlots + 1] = {
                    key = child.key,
                    kind = child.kind,
                    gameRoomKey = child.gameRoomKey,
                }
            end
            result.rooms.ordered[#result.rooms.ordered + 1] = descriptor
            result.rooms.lookup[key] = descriptor
        end
    end
    return result
end

return manifest
