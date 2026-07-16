local deps = ...
local biomePlan = deps.biomePlan

local biomePlans = {}

local function scopedRooms(catalog, biome)
    local result = { ordered = {}, lookup = {}, byGameRoomKey = {} }
    for _, control in ipairs(catalog.controlManifest.rooms.ordered) do
        if control.biomeStepKey == biome.biomeStepKey then
            local room = biome.rooms.lookup[control.gameRoomKey]
            local record = { control = control, room = room }
            result.ordered[#result.ordered + 1] = record
            result.lookup[control.key] = record
            result.byGameRoomKey[room.key] = record
        end
    end
    return result
end

local function startRoomLookup(biome)
    local result = {}
    for _, roomKey in ipairs(biome.layout.start.roomKeys) do
        result[roomKey] = true
    end
    return result
end

function biomePlans.build(catalog, storage, topologyLayouts)
    local result = { ordered = {}, lookup = {}, unavailable = {} }
    for _, biome in ipairs(catalog.biomes.ordered) do
        local topologyLayout = topologyLayouts[biome.layout.kind]
        if topologyLayout == nil or not topologyLayout.supports(biome) then
            result.unavailable[biome.biomeStepKey] = biome.layout.kind
        else
            local rooms = scopedRooms(catalog, biome)
            local context = {
                biome = biome,
                catalog = catalog,
                rooms = rooms,
                startRoomLookup = startRoomLookup(biome),
                storage = storage.biomes.lookup[biome.biomeStepKey],
                terminal = rooms.byGameRoomKey[biome.layout.terminal.roomKey],
            }
            local plan = biomePlan.create({
                biome = biome,
                context = context,
                topologyLayout = topologyLayout,
            })
            result.ordered[#result.ordered + 1] = plan
            result.lookup[plan.key] = plan
        end
    end
    return result
end

return biomePlans
