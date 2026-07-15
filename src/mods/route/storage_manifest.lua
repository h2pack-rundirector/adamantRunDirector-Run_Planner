local storageManifest = {}

local CONTROL_KEY_MAX = 64
local RULE_KEY_MAX = 32

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

local function batchRoot(biome)
    local columns = {
        column("ParentRoomControlKey", {
            semanticKey = "parentRoomControlKey",
            type = "string",
            default = "",
            maxLen = CONTROL_KEY_MAX,
        }),
        column("RuleKey", {
            semanticKey = "ruleKey",
            type = "string",
            default = "",
            maxLen = RULE_KEY_MAX,
        }),
    }
    if biome.batchRuleKey == "FieldsCageBatch" then
        columns[#columns + 1] = column("CageRoll", {
            semanticKey = "cageRoll",
            type = "string",
            default = "",
            maxLen = 8,
        })
    end
    return tableRoot(biome.biomeStepKey .. "_Batches", biome.topologyBounds.maxBatches, columns)
end

local function targetRoot(biome)
    local maxExitIndex = 0
    for _, room in ipairs(biome.rooms.ordered) do
        if #room.exits > maxExitIndex then
            maxExitIndex = #room.exits
        end
    end
    if biome.key == "N" then
        for _, value in ipairs(biome.biomeState.hubDoorCount.values) do
            if value > maxExitIndex then
                maxExitIndex = value
            end
        end
    end
    local columns = {
        column("ParentRoomControlKey", {
            semanticKey = "parentRoomControlKey",
            type = "string",
            default = "",
            maxLen = CONTROL_KEY_MAX,
        }),
        column("ExitIndex", {
            semanticKey = "exitIndex",
            type = "int",
            default = 0,
            min = 0,
            max = maxExitIndex,
        }),
        column("RoomControlKey", {
            semanticKey = "roomControlKey",
            type = "string",
            default = "",
            maxLen = CONTROL_KEY_MAX,
        }),
    }
    if biome.batchRuleKey == "EphyraHubBatch" then
        columns[#columns + 1] = column("VisitOrder", {
            semanticKey = "visitOrder",
            type = "int",
            default = 0,
            min = 0,
            max = biome.biomeState.visitedTargetCount.value,
        })
    else
        columns[#columns + 1] = column("Picked", {
            semanticKey = "picked",
            type = "bool",
            default = false,
        })
    end
    return tableRoot(biome.biomeStepKey .. "_Targets", biome.topologyBounds.maxTargets, columns)
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
    local alias = biomeStepKey .. "_" .. string.upper(string.sub(semanticKey, 1, 1)) .. string.sub(semanticKey, 2)
    return {
        alias = alias,
        semanticKey = semanticKey,
        values = state.values,
        valueLookup = valueLookup,
        storage = {
            alias = alias,
            type = "int",
            default = 0,
            min = 0,
            max = max,
        },
    }
end

function storageManifest.build(catalog)
    local result = {
        moduleStorage = {},
        biomes = { ordered = {}, lookup = {} },
    }
    for _, biome in ipairs(catalog.biomes.ordered) do
        local descriptor = {
            key = biome.biomeStepKey,
            batches = batchRoot(biome),
            targets = targetRoot(biome),
            globals = { ordered = {}, lookup = {} },
        }
        result.moduleStorage[#result.moduleStorage + 1] = descriptor.batches.storage
        result.moduleStorage[#result.moduleStorage + 1] = descriptor.targets.storage
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
            result.moduleStorage[#result.moduleStorage + 1] = global.storage
        end
        result.biomes.ordered[#result.biomes.ordered + 1] = descriptor
        result.biomes.lookup[descriptor.key] = descriptor
    end
    return result
end

return storageManifest
