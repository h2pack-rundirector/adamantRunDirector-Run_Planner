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

local function readAllowedScalar(data, root, path)
    local value = data.read(root.alias)
    if root.valueLookup ~= nil
        and value ~= root.storage.default
        and root.valueLookup[value] ~= true
    then
        error(path .. " does not allow value '" .. tostring(value) .. "'", 0)
    end
    return value
end

local function createCommon(surface, catalog, storage)
    local access = {}

    function access.readRoute(_, routeKey)
        requireRoute(catalog, routeKey)
        return surface.controls.read(routeKey)
    end

    function access.getRoom(_, roomControlKey)
        requireRoom(catalog, roomControlKey)
        return surface.controls.get(roomControlKey)
    end

    function access.readRoom(_, roomControlKey)
        requireRoom(catalog, roomControlKey)
        return surface.controls.read(roomControlKey)
    end

    function access.readBiome(_, biomeStepKey)
        local descriptor = storage.biomes.lookup[biomeStepKey]
        if descriptor == nil then
            error("unknown biome plan '" .. tostring(biomeStepKey) .. "'", 0)
        end
        local snapshot = { layoutKind = descriptor.layoutKind }
        if descriptor.layoutKind == "LinearBiome" then
            snapshot.batches = readRows(surface.data, descriptor.batches)
            snapshot.targets = readRows(surface.data, descriptor.targets)
            snapshot.terminalTransition = {
                parentRoomControlKey = surface.data.read(descriptor.terminalTransition.alias),
            }
            if descriptor.selectedStart ~= nil then
                snapshot.selectedStartRoomControlKey = readAllowedScalar(
                    surface.data,
                    descriptor.selectedStart,
                    "biome plan '" .. biomeStepKey .. "' selected start"
                )
            end
            if descriptor.companionTargets ~= nil then
                snapshot.terminalTransition.companionTargets = readRows(
                    surface.data,
                    descriptor.companionTargets
                )
            end
        elseif descriptor.layoutKind == "HubBiome" then
            snapshot.hubTargets = readRows(surface.data, descriptor.hubTargets)
            snapshot.terminalTransition = surface.data.read(descriptor.terminalTransition.alias)
        else
            error("unknown biome layout kind '" .. tostring(descriptor.layoutKind) .. "'", 0)
        end
        for _, global in ipairs(descriptor.globals.ordered) do
            snapshot[global.semanticKey] = readAllowedScalar(
                surface.data,
                global,
                "biome plan '" .. biomeStepKey .. "' authored global '" .. global.semanticKey .. "'"
            )
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
