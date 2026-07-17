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

local function preparedRows(root, rows, path)
    if type(rows) ~= "table" then
        error(path .. " must be a dense array", 0)
    end
    local count = 0
    local maximum = 0
    for key, row in pairs(rows) do
        if type(key) ~= "number"
            or key ~= math.floor(key)
            or key < 1
            or type(row) ~= "table"
        then
            error(path .. " must be a dense array of rows", 0)
        end
        count = count + 1
        maximum = math.max(maximum, key)
    end
    if count ~= maximum then
        error(path .. " must be a dense array of rows", 0)
    end
    if maximum > root.storage.maxRows then
        error(path .. " exceeds its bounded row capacity", 0)
    end
    local result = {}
    for rowIndex = 1, maximum do
        local row = rows[rowIndex]
        local physical = {}
        for semanticKey, physicalKey in pairs(root.columns) do
            physical[physicalKey] = row[semanticKey]
        end
        result[rowIndex] = physical
    end
    return result
end

local function replaceRows(handle, rows)
    handle:clear()
    for _, row in ipairs(rows) do
        handle:append(row)
    end
end

local function createCommon(surface, catalog)
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

    function access.readScalar(_, root)
        return surface.data.read(root.alias)
    end

    function access.readRows(_, root)
        return readRows(surface.data, root)
    end

    return access
end

function stateAccess.createRuntime(runtime, catalog)
    return createCommon(runtime, catalog)
end

function stateAccess.createUi(ui, catalog)
    local access = createCommon(ui, catalog)

    function access.writeRoute(_, routeKey, configuredBiomePrefix)
        requireRoute(catalog, routeKey)
        ui.controls.get(routeKey):write(configuredBiomePrefix)
    end

    function access.replaceScalar(_, root, value)
        ui.data.get(root.alias):write(value)
    end

    function access.replaceRows(_, root, rows)
        local prepared = preparedRows(root, rows, "storage root '" .. root.alias .. "'")
        replaceRows(ui.data.get(root.alias), prepared)
    end

    function access.resetAll(_)
        return ui.resetAll()
    end

    return access
end

return stateAccess
