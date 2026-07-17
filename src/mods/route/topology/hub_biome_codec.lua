local codec = {}

local CONTROL_KEY_MAX = 64
local scalarRoot

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

local function column(alias, semanticKey, descriptor)
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

scalarRoot = function(alias, semanticKey, descriptor)
    descriptor.alias = alias
    return {
        alias = alias,
        semanticKey = semanticKey,
        storage = descriptor,
    }
end

function codec.storage(_, biome)
    local doorCountState = biome.biomeState[biome.layout.hub.doorCountStateKey]
    local maximumDoorCount = 0
    for _, value in ipairs(doorCountState.values) do
        maximumDoorCount = math.max(maximumDoorCount, value)
    end
    local hubTargets = tableRoot(
        biome.biomeStepKey .. "_HubTargets",
        biome.layout.bounds.maxTargets,
        {
            column("DoorIndex", "doorIndex", {
                type = "int",
                default = 0,
                min = 0,
                max = maximumDoorCount,
            }),
            column("RoomControlKey", "roomControlKey", {
                type = "string",
                default = "",
                maxLen = CONTROL_KEY_MAX,
            }),
            column("VisitOrder", "visitOrder", {
                type = "int",
                default = 0,
                min = 0,
                max = biome.layout.hub.visitedTargetCount,
            }),
        }
    )
    local terminalTransition = scalarRoot(
        biome.biomeStepKey .. "_TerminalTransition",
        "terminalTransition",
        { type = "bool", default = false }
    )
    local descriptor = {
        key = biome.biomeStepKey,
        layoutKind = "HubBiome",
        roots = { hubTargets, terminalTransition },
        hubTargets = hubTargets,
        terminalTransition = terminalTransition,
        globals = { ordered = {}, lookup = {} },
    }
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
        descriptor.roots[#descriptor.roots + 1] = global
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
        layoutKind = "HubBiome",
        hubTargets = access:readRows(descriptor.hubTargets),
        terminalTransition = access:readScalar(descriptor.terminalTransition),
    }
    for _, global in ipairs(descriptor.globals.ordered) do
        authored[global.semanticKey] = readAllowedScalar(
            access,
            global,
            "biome plan '" .. descriptor.key .. "' authored global '"
                .. global.semanticKey .. "'"
        )
    end
    return authored
end

function codec.replace(access, descriptor, authored)
    access:replaceRows(descriptor.hubTargets, authored.hubTargets)
    access:replaceScalar(descriptor.terminalTransition, authored.terminalTransition)
    for _, global in ipairs(descriptor.globals.ordered) do
        access:replaceScalar(global, authored[global.semanticKey])
    end
end

return codec
