local codec = {}

local CONTROL_KEY_MAX = 64

local function column(alias, descriptor)
    local semanticKey = descriptor.semanticKey
    descriptor.semanticKey = nil
    descriptor.alias = alias
    return {
        semanticKey = semanticKey,
        storage = descriptor,
    }
end

local function tableRoot(alias, maxRows, columns)
    local row = {}
    local columnLookup = {}
    for _, descriptor in ipairs(columns) do
        row[#row + 1] = descriptor.storage
        columnLookup[descriptor.semanticKey] = descriptor.storage.alias
    end
    return {
        storage = {
            alias = alias,
            type = "table",
            defaultRows = 0,
            minRows = 0,
            maxRows = maxRows,
            row = row,
        },
        alias = alias,
        columns = columnLookup,
    }
end

local function scalarRoot(alias, semanticKey, descriptor)
    descriptor.alias = alias
    return {
        alias = alias,
        semanticKey = semanticKey,
        storage = descriptor,
    }
end

local function controlKeyColumn(alias, semanticKey)
    return column(alias, {
        semanticKey = semanticKey,
        type = "string",
        default = "",
        maxLen = CONTROL_KEY_MAX,
    })
end

local function maximumExitCount(biome)
    local maximum = 0
    for _, room in ipairs(biome.rooms.ordered) do
        maximum = math.max(maximum, #room.exits)
    end
    return maximum
end

local function roomControlKey(catalog, biome, gameName)
    for _, room in ipairs(catalog.controlManifest.rooms.ordered) do
        if room.biomeStepKey == biome.biomeStepKey and room.gameName == gameName then
            return room.key
        end
    end
    error("missing room control for layout room '" .. gameName .. "'", 0)
end

local function authoredGlobal(biomeStepKey, semanticKey, state)
    local maximum = 0
    local valueLookup = {}
    for _, value in ipairs(state.values) do
        valueLookup[value] = true
        maximum = math.max(maximum, value)
    end
    local alias = biomeStepKey .. "_" .. string.upper(string.sub(semanticKey, 1, 1))
        .. string.sub(semanticKey, 2)
    local root = scalarRoot(alias, semanticKey, {
        type = "int",
        default = 0,
        min = 0,
        max = maximum,
    })
    root.values = state.values
    root.valueLookup = valueLookup
    return root
end

local function addRoot(descriptor, root)
    descriptor.roots[#descriptor.roots + 1] = root
end

function codec.storage(catalog, biome)
    local maximumExits = maximumExitCount(biome)
    local batchColumns = {
        controlKeyColumn("ParentRoomControlKey", "parentRoomControlKey"),
    }
    if biome.layout.continuation.defaultBatchRuleKey == "FieldsCageBatch" then
        batchColumns[#batchColumns + 1] = column("CageRoll", {
            semanticKey = "cageRoll",
            type = "string",
            default = "",
            maxLen = 8,
        })
    end
    local descriptor = {
        key = biome.biomeStepKey,
        layoutKind = "LinearBiome",
        roots = {},
        globals = { ordered = {}, lookup = {} },
        batches = tableRoot(
            biome.biomeStepKey .. "_Batches",
            biome.layout.bounds.maxBatches,
            batchColumns
        ),
        targets = tableRoot(biome.biomeStepKey .. "_Targets", biome.layout.bounds.maxTargets, {
            controlKeyColumn("ParentRoomControlKey", "parentRoomControlKey"),
            column("ExitIndex", {
                semanticKey = "exitIndex",
                type = "int",
                default = 0,
                min = 0,
                max = maximumExits,
            }),
            controlKeyColumn("RoomControlKey", "roomControlKey"),
            column("Picked", {
                semanticKey = "picked",
                type = "bool",
                default = false,
            }),
        }),
        terminalTransition = scalarRoot(
            biome.biomeStepKey .. "_TerminalParentRoomControlKey",
            "parentRoomControlKey",
            { type = "string", default = "", maxLen = CONTROL_KEY_MAX }
        ),
    }
    addRoot(descriptor, descriptor.batches)
    addRoot(descriptor, descriptor.targets)
    addRoot(descriptor, descriptor.terminalTransition)

    if biome.layout.start.mode == "oneOf" then
        local values = { "" }
        local lookup = { [""] = true }
        for _, gameName in ipairs(biome.layout.start.roomKeys) do
            local value = roomControlKey(catalog, biome, gameName)
            values[#values + 1] = value
            lookup[value] = true
        end
        descriptor.selectedStart = scalarRoot(
            biome.biomeStepKey .. "_SelectedStartRoomControlKey",
            "selectedStartRoomControlKey",
            { type = "string", default = "", maxLen = CONTROL_KEY_MAX }
        )
        descriptor.selectedStart.values = values
        descriptor.selectedStart.valueLookup = lookup
        addRoot(descriptor, descriptor.selectedStart)
    end

    if biome.layout.terminal.maxCompanionTargets > 0 then
        descriptor.companionTargets = tableRoot(
            biome.biomeStepKey .. "_TerminalCompanionTargets",
            biome.layout.terminal.maxCompanionTargets,
            {
                column("ExitIndex", {
                    semanticKey = "exitIndex",
                    type = "int",
                    default = 0,
                    min = 0,
                    max = maximumExits,
                }),
                controlKeyColumn("RoomControlKey", "roomControlKey"),
            }
        )
        addRoot(descriptor, descriptor.companionTargets)
    end

    for semanticKey, state in pairs(biome.biomeState or {}) do
        if state.authored == true then
            local global = authoredGlobal(biome.biomeStepKey, semanticKey, state)
            descriptor.globals.ordered[#descriptor.globals.ordered + 1] = global
            descriptor.globals.lookup[semanticKey] = global
        end
    end
    table.sort(descriptor.globals.ordered, function(left, right)
        return left.semanticKey < right.semanticKey
    end)
    for _, global in ipairs(descriptor.globals.ordered) do
        addRoot(descriptor, global)
    end
    return descriptor
end

local function readAllowedScalar(access, root, path)
    local value = access:readScalar(root)
    if root.valueLookup ~= nil
        and value ~= root.storage.default
        and root.valueLookup[value] ~= true
    then
        error(path .. " does not allow value '" .. tostring(value) .. "'", 0)
    end
    return value
end

function codec.read(access, descriptor)
    local authored = {
        layoutKind = "LinearBiome",
        batches = access:readRows(descriptor.batches),
        targets = access:readRows(descriptor.targets),
        terminalTransition = {
            parentRoomControlKey = access:readScalar(descriptor.terminalTransition),
        },
    }
    if descriptor.selectedStart ~= nil then
        authored.selectedStartRoomControlKey = readAllowedScalar(
            access,
            descriptor.selectedStart,
            "biome plan '" .. descriptor.key .. "' selected start"
        )
    end
    if descriptor.companionTargets ~= nil then
        authored.terminalTransition.companionTargets = access:readRows(descriptor.companionTargets)
    end
    for _, global in ipairs(descriptor.globals.ordered) do
        authored[global.semanticKey] = readAllowedScalar(
            access,
            global,
            "biome plan '" .. descriptor.key .. "' authored global '" .. global.semanticKey .. "'"
        )
    end
    return authored
end

function codec.replace(access, descriptor, authored)
    access:replaceRows(descriptor.batches, authored.batches)
    access:replaceRows(descriptor.targets, authored.targets)
    access:replaceScalar(
        descriptor.terminalTransition,
        authored.terminalTransition.parentRoomControlKey
    )
    if descriptor.selectedStart ~= nil then
        access:replaceScalar(descriptor.selectedStart, authored.selectedStartRoomControlKey)
    end
    if descriptor.companionTargets ~= nil then
        access:replaceRows(
            descriptor.companionTargets,
            authored.terminalTransition.companionTargets or {}
        )
    end
    for _, global in ipairs(descriptor.globals.ordered) do
        access:replaceScalar(global, authored[global.semanticKey])
    end
end

return codec
