local storageManifest = {}

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
        if #room.exits > maximum then
            maximum = #room.exits
        end
    end
    return maximum
end

local function batchRoot(biome)
    local columns = {
        controlKeyColumn("ParentRoomControlKey", "parentRoomControlKey"),
    }
    if biome.layout.continuation.defaultBatchRuleKey == "FieldsCageBatch" then
        columns[#columns + 1] = column("CageRoll", {
            semanticKey = "cageRoll",
            type = "string",
            default = "",
            maxLen = 8,
        })
    end
    return tableRoot(
        biome.biomeStepKey .. "_Batches",
        biome.layout.bounds.maxBatches,
        columns
    )
end

local function targetRoot(biome)
    return tableRoot(biome.biomeStepKey .. "_Targets", biome.layout.bounds.maxTargets, {
        controlKeyColumn("ParentRoomControlKey", "parentRoomControlKey"),
        column("ExitIndex", {
            semanticKey = "exitIndex",
            type = "int",
            default = 0,
            min = 0,
            max = maximumExitCount(biome),
        }),
        controlKeyColumn("RoomControlKey", "roomControlKey"),
        column("Picked", {
            semanticKey = "picked",
            type = "bool",
            default = false,
        }),
    })
end

local function companionTargetRoot(biome)
    return tableRoot(
        biome.biomeStepKey .. "_TerminalCompanionTargets",
        biome.layout.terminal.maxCompanionTargets,
        {
            column("ExitIndex", {
                semanticKey = "exitIndex",
                type = "int",
                default = 0,
                min = 0,
                max = maximumExitCount(biome),
            }),
            controlKeyColumn("RoomControlKey", "roomControlKey"),
        }
    )
end

local function hubTargetRoot(biome)
    local hubDoorCount = biome.biomeState[biome.layout.hub.doorCountStateKey]
    local maximumDoorCount = 0
    for _, value in ipairs(hubDoorCount.values) do
        if value > maximumDoorCount then
            maximumDoorCount = value
        end
    end
    return tableRoot(biome.biomeStepKey .. "_HubTargets", biome.layout.bounds.maxTargets, {
        column("DoorIndex", {
            semanticKey = "doorIndex",
            type = "int",
            default = 0,
            min = 0,
            max = maximumDoorCount,
        }),
        controlKeyColumn("RoomControlKey", "roomControlKey"),
        column("VisitOrder", {
            semanticKey = "visitOrder",
            type = "int",
            default = 0,
            min = 0,
            max = biome.layout.hub.visitedTargetCount,
        }),
    })
end

local function authoredGlobal(biomeStepKey, semanticKey, state)
    local max = 0
    local valueLookup = {}
    for _, value in ipairs(state.values) do
        valueLookup[value] = true
        if value > max then
            max = value
        end
    end
    local alias = biomeStepKey .. "_" .. string.upper(string.sub(semanticKey, 1, 1))
        .. string.sub(semanticKey, 2)
    local root = scalarRoot(alias, semanticKey, {
        type = "int",
        default = 0,
        min = 0,
        max = max,
    })
    root.values = state.values
    root.valueLookup = valueLookup
    return root
end

local function roomControlKey(catalog, biome, gameRoomKey)
    for _, room in ipairs(catalog.controlManifest.rooms.ordered) do
        if room.biomeStepKey == biome.biomeStepKey and room.gameRoomKey == gameRoomKey then
            return room.key
        end
    end
    error("missing room control for layout room '" .. gameRoomKey .. "'", 0)
end

local function addRoot(result, descriptor)
    result.moduleStorage[#result.moduleStorage + 1] = descriptor.storage
end

local function buildLinearDescriptor(catalog, biome, result)
    local descriptor = {
        key = biome.biomeStepKey,
        layoutKind = "LinearBiome",
        globals = { ordered = {}, lookup = {} },
        batches = batchRoot(biome),
        targets = targetRoot(biome),
        terminalTransition = scalarRoot(
            biome.biomeStepKey .. "_TerminalParentRoomControlKey",
            "parentRoomControlKey",
            { type = "string", default = "", maxLen = CONTROL_KEY_MAX }
        ),
    }
    addRoot(result, descriptor.batches)
    addRoot(result, descriptor.targets)
    addRoot(result, descriptor.terminalTransition)
    if biome.layout.start.mode == "oneOf" then
        local values = { "" }
        local lookup = { [""] = true }
        for _, gameRoomKey in ipairs(biome.layout.start.roomKeys) do
            local value = roomControlKey(catalog, biome, gameRoomKey)
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
        addRoot(result, descriptor.selectedStart)
    end
    if biome.layout.terminal.maxCompanionTargets > 0 then
        descriptor.companionTargets = companionTargetRoot(biome)
        addRoot(result, descriptor.companionTargets)
    end
    return descriptor
end

local function buildHubDescriptor(biome, result)
    local descriptor = {
        key = biome.biomeStepKey,
        layoutKind = "HubBiome",
        globals = { ordered = {}, lookup = {} },
        hubTargets = hubTargetRoot(biome),
        terminalTransition = scalarRoot(
            biome.biomeStepKey .. "_TerminalTransition",
            "terminalTransition",
            { type = "bool", default = false }
        ),
    }
    addRoot(result, descriptor.hubTargets)
    addRoot(result, descriptor.terminalTransition)
    return descriptor
end

function storageManifest.build(catalog)
    local result = {
        moduleStorage = {},
        biomes = { ordered = {}, lookup = {} },
    }
    for _, biome in ipairs(catalog.biomes.ordered) do
        local descriptor
        if biome.layout.kind == "LinearBiome" then
            descriptor = buildLinearDescriptor(catalog, biome, result)
        elseif biome.layout.kind == "HubBiome" then
            descriptor = buildHubDescriptor(biome, result)
        else
            error("missing storage descriptor for layout kind '" .. biome.layout.kind .. "'", 0)
        end
        for semanticKey, state in pairs(biome.biomeState or {}) do
            if state.authored == true then
                local global = authoredGlobal(biome.biomeStepKey, semanticKey, state)
                descriptor.globals.ordered[#descriptor.globals.ordered + 1] = global
                descriptor.globals.lookup[semanticKey] = global
            end
        end
        table.sort(descriptor.globals.ordered, function(a, b)
            return a.semanticKey < b.semanticKey
        end)
        for _, global in ipairs(descriptor.globals.ordered) do
            addRoot(result, global)
        end
        result.biomes.ordered[#result.biomes.ordered + 1] = descriptor
        result.biomes.lookup[descriptor.key] = descriptor
    end
    return result
end

return storageManifest
