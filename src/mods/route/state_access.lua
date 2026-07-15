local stateAccess = {}

local function requireRoute(catalog, routeKey)
    if catalog.controlManifest.routes.lookup[routeKey] == nil then
        error("unknown route control '" .. tostring(routeKey) .. "'", 0)
    end
end

local function requireRoom(catalog, roomControlKey)
    if catalog.controlManifest.rooms.lookup[roomControlKey] == nil then
        error("unknown room control '" .. tostring(roomControlKey) .. "'", 0)
    end
end

local function readRows(data, root)
    local handle = data.get(root.alias)
    local rows = {}
    for rowIndex = 1, handle:count() do
        local row = {}
        for semanticKey, physicalKey in pairs(root.columns) do
            row[semanticKey] = handle:read(rowIndex, physicalKey)
        end
        rows[rowIndex] = row
    end
    return rows
end

local function createCommon(surface, catalog, storage)
    local access = {}

    function access.readRoute(_, routeKey)
        requireRoute(catalog, routeKey)
        return surface.controls.read(routeKey)
    end

    function access.readRoom(_, roomControlKey, address)
        requireRoom(catalog, roomControlKey)
        return surface.controls.read(roomControlKey, address)
    end

    function access.readBiome(_, biomeStepKey)
        local descriptor = storage.biomes.lookup[biomeStepKey]
        if descriptor == nil then
            error("unknown biome plan '" .. tostring(biomeStepKey) .. "'", 0)
        end
        local snapshot = {
            globals = {},
            batches = readRows(surface.data, descriptor.batches),
            targets = readRows(surface.data, descriptor.targets),
        }
        for _, global in ipairs(descriptor.globals.ordered) do
            local value = surface.data.read(global.alias)
            if value ~= 0 and global.valueLookup[value] ~= true then
                error(
                    "biome plan '" .. biomeStepKey .. "' authored global '" .. global.semanticKey
                        .. "' does not allow value '" .. tostring(value) .. "'",
                    0
                )
            end
            snapshot.globals[global.semanticKey] = value
        end
        return snapshot
    end

    return access
end

function stateAccess.createRuntime(runtime, catalog, storage)
    return createCommon(runtime, catalog, storage)
end

function stateAccess.createUi(ui, catalog, storage)
    local access = createCommon(ui, catalog, storage)

    function access.writeRoute(_, routeKey, configuredBiomePrefix)
        requireRoute(catalog, routeKey)
        ui.controls.get(routeKey):write(configuredBiomePrefix)
    end

    function access.writeRoom(_, roomControlKey, address, value)
        requireRoom(catalog, roomControlKey)
        ui.controls.get(roomControlKey):write(address, value)
    end

    function access.writeBiomeGlobal(_, biomeStepKey, semanticKey, value)
        local descriptor = storage.biomes.lookup[biomeStepKey]
        if descriptor == nil then
            error("unknown biome plan '" .. tostring(biomeStepKey) .. "'", 0)
        end
        local global = descriptor.globals.lookup[semanticKey]
        if global == nil then
            error("biome plan '" .. biomeStepKey .. "' has no authored global '" .. tostring(semanticKey) .. "'", 0)
        end
        if value ~= 0 and global.valueLookup[value] ~= true then
            error(
                "biome plan '" .. biomeStepKey .. "' authored global '" .. semanticKey
                    .. "' does not allow value '" .. tostring(value) .. "'",
                0
            )
        end
        ui.data.get(global.alias):write(value)
    end

    function access.resetAll(_)
        return ui.resetAll()
    end

    return access
end

return stateAccess
