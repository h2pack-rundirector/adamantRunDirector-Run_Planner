local deps = ...
local batchImplementations = deps.batchImplementations
local terminalTransitions = deps.terminalTransitions

local linearBiome = {}

function linearBiome.supports(biome)
    local continuation = biome.layout.continuation
    if batchImplementations[continuation.defaultBatchRuleKey] == nil then
        return false
    end
    for _, override in ipairs(continuation.overrides) do
        if batchImplementations[override.batchRuleKey] == nil then
            return false
        end
    end
    local terminal = biome.layout.terminal
    if terminalTransitions[terminal.transitionRuleKey] == nil then
        return false
    end
    local companionRuleKey = terminal.exitPolicy.companionBatchRuleKey
    return companionRuleKey == nil or batchImplementations[companionRuleKey] ~= nil
end

local function fail(context, path, message)
    error("biome topology '" .. context.biome.biomeStepKey .. "' at " .. path .. ": " .. message, 0)
end

local function onlyKeys(context, value, allowed, path)
    if type(value) ~= "table" then
        fail(context, path, "expected a table")
    end
    local lookup = {}
    for _, key in ipairs(allowed) do
        lookup[key] = true
    end
    for key in pairs(value) do
        if not lookup[key] then
            fail(context, path .. "." .. tostring(key), "unexpected field")
        end
    end
end

local function denseList(context, value, path)
    if type(value) ~= "table" then
        fail(context, path, "expected a dense array")
    end
    local count = 0
    local maximum = 0
    for key in pairs(value) do
        if type(key) ~= "number" or key ~= math.floor(key) or key < 1 then
            fail(context, path, "expected a dense array")
        end
        count = count + 1
        maximum = math.max(maximum, key)
    end
    if count ~= maximum then
        fail(context, path, "expected a dense array")
    end
    return maximum
end

local function room(context, controlKey, path)
    if type(controlKey) ~= "string" or controlKey == "" then
        fail(context, path, "expected a Room Control key")
    end
    local result = context.rooms.lookup[controlKey]
    if result == nil then
        fail(context, path, "unknown or cross-biome Room Control '" .. controlKey .. "'")
    end
    return result
end

local function claimRoom(context, claims, record, path)
    local previous = claims[record.control.key]
    if previous ~= nil then
        fail(
            context,
            path,
            "Room Control '" .. record.control.key .. "' is already used at " .. previous
        )
    end
    claims[record.control.key] = path
end

local function contains(values, candidate)
    for _, value in ipairs(values) do
        if value == candidate then
            return true
        end
    end
    return false
end

local function resolveBatchRule(context, parent)
    for _, override in ipairs(context.biome.layout.continuation.overrides) do
        if contains(override.when.parentRoomKeys, parent.room.key) then
            return override.batchRuleKey, override.key
        end
    end
    return context.biome.layout.continuation.defaultBatchRuleKey, nil
end

local function authoredStateKeys(context)
    local keys = {
        "batches", "layoutKind", "targets", "terminalTransition",
    }
    if context.biome.layout.start.mode == "oneOf" then
        keys[#keys + 1] = "selectedStartRoomControlKey"
    end
    for semanticKey, state in pairs(context.biome.biomeState or {}) do
        if state.authored == true then
            keys[#keys + 1] = semanticKey
        end
    end
    return keys
end

local function normalizeStart(context, authored, claims)
    local start = context.biome.layout.start
    local controlKey
    if start.mode == "fixed" then
        controlKey = context.rooms.byGameRoomKey[start.roomKeys[1]].control.key
    else
        if type(authored.selectedStartRoomControlKey) ~= "string" then
            fail(context, "selectedStartRoomControlKey", "expected a string")
        end
        if authored.selectedStartRoomControlKey == "" then
            return nil
        end
        controlKey = authored.selectedStartRoomControlKey
        local candidate = room(context, controlKey, "selectedStartRoomControlKey")
        if not context.startRoomLookup[candidate.room.key] then
            fail(context, "selectedStartRoomControlKey", "room is not an admitted start")
        end
    end
    local result = room(context, controlKey, "startRoomControlKey")
    claimRoom(context, claims, result, "startRoomControlKey")
    return result
end

local function normalizeBatches(context, authored, claims)
    local bounds = context.biome.layout.bounds
    if denseList(context, authored.batches, "batches") > bounds.maxBatches then
        fail(context, "batches", "count exceeds the declared layout bound")
    end
    if denseList(context, authored.targets, "targets") > bounds.maxTargets then
        fail(context, "targets", "count exceeds the declared layout bound")
    end

    local batches = {}
    for index, source in ipairs(authored.batches) do
        local path = "batches[" .. tostring(index) .. "]"
        if type(source) ~= "table" then
            fail(context, path, "expected a table")
        end
        local parent = room(context, source.parentRoomControlKey, path .. ".parentRoomControlKey")
        if batches[parent.control.key] ~= nil then
            fail(context, path .. ".parentRoomControlKey", "duplicate generated batch parent")
        end
        batches[parent.control.key] = {
            authored = source,
            parent = parent,
            path = path,
            targets = {},
        }
    end

    for index, source in ipairs(authored.targets) do
        local path = "targets[" .. tostring(index) .. "]"
        onlyKeys(
            context,
            source,
            { "exitIndex", "parentRoomControlKey", "picked", "roomControlKey" },
            path
        )
        local batch = batches[source.parentRoomControlKey]
        if batch == nil then
            fail(context, path .. ".parentRoomControlKey", "target has no owning generated batch")
        end
        if type(source.exitIndex) ~= "number"
            or source.exitIndex ~= math.floor(source.exitIndex)
            or source.exitIndex < 1
            or source.exitIndex > #batch.parent.room.exits
        then
            fail(context, path .. ".exitIndex", "exit index is outside the parent room")
        end
        if type(source.picked) ~= "boolean" then
            fail(context, path .. ".picked", "expected a boolean")
        end
        if batch.targets[source.exitIndex] ~= nil then
            fail(context, path .. ".exitIndex", "duplicate physical exit")
        end
        local target = room(context, source.roomControlKey, path .. ".roomControlKey")
        if target.control.key == context.terminal.control.key then
            fail(context, path .. ".roomControlKey", "terminal room cannot be an ordinary target")
        end
        claimRoom(context, claims, target, path .. ".roomControlKey")
        batch.targets[source.exitIndex] = {
            exitIndex = source.exitIndex,
            roomControlKey = target.control.key,
            picked = source.picked,
            room = target,
        }
    end
    return batches
end

local function normalizeCompanions(context, authored, claims)
    local source = authored.terminalTransition.companionTargets or {}
    denseList(context, source, "terminalTransition.companionTargets")
    local result = {}
    local exitIndexes = {}
    for index, target in ipairs(source) do
        local path = "terminalTransition.companionTargets[" .. tostring(index) .. "]"
        onlyKeys(context, target, { "exitIndex", "roomControlKey" }, path)
        if type(target.exitIndex) ~= "number"
            or target.exitIndex ~= math.floor(target.exitIndex)
            or target.exitIndex < 1
        then
            fail(context, path .. ".exitIndex", "expected a positive exit index")
        end
        if exitIndexes[target.exitIndex] then
            fail(context, path .. ".exitIndex", "duplicate physical exit")
        end
        exitIndexes[target.exitIndex] = true
        local targetRoom = room(context, target.roomControlKey, path .. ".roomControlKey")
        if targetRoom.control.key == context.terminal.control.key then
            fail(context, path .. ".roomControlKey", "terminal room cannot be its own companion")
        end
        claimRoom(context, claims, targetRoom, path .. ".roomControlKey")
        result[index] = {
            exitIndex = target.exitIndex,
            roomControlKey = targetRoom.control.key,
        }
    end
    return result
end

local function normalizeTerminal(context, authored, claims)
    onlyKeys(
        context,
        authored.terminalTransition,
        { "companionTargets", "parentRoomControlKey" },
        "terminalTransition"
    )
    local parentControlKey = authored.terminalTransition.parentRoomControlKey
    if type(parentControlKey) ~= "string" then
        fail(context, "terminalTransition.parentRoomControlKey", "expected a string")
    end
    local companions = normalizeCompanions(context, authored, claims)
    if parentControlKey == "" then
        if #companions > 0 then
            fail(context, "terminalTransition.companionTargets", "companions require a terminal transition")
        end
        return nil
    end
    local parent = room(
        context,
        parentControlKey,
        "terminalTransition.parentRoomControlKey"
    )
    local implementation = terminalTransitions[context.biome.layout.terminal.transitionRuleKey]
    if implementation == nil then
        fail(
            context,
            "terminalTransition",
            "no executable transition implementation for '"
                .. context.biome.layout.terminal.transitionRuleKey .. "'"
        )
    end
    return implementation.normalize({
        companionTargets = companions,
        declaration = context.biome.layout.terminal,
        fail = function(path, message)
            fail(context, path, message)
        end,
        parent = parent,
        path = "terminalTransition",
        terminal = context.terminal,
    })
end

local function sortedTargets(batch)
    local result = {}
    for _, target in pairs(batch.targets) do
        result[#result + 1] = target
    end
    table.sort(result, function(left, right)
        return left.exitIndex < right.exitIndex
    end)
    return result
end

local function normalizeBatch(context, batch)
    local batchRuleKey, continuationOverrideKey = resolveBatchRule(context, batch.parent)
    local implementation = batchImplementations[batchRuleKey]
    if implementation == nil then
        fail(
            context,
            batch.path,
            "no executable batch implementation for '" .. batchRuleKey .. "'"
        )
    end
    return implementation.normalize({
        authored = batch.authored,
        continuationOverrideKey = continuationOverrideKey,
        fail = function(path, message)
            fail(context, path, message)
        end,
        onlyKeys = function(value, allowed, path)
            onlyKeys(context, value, allowed, path)
        end,
        parent = batch.parent,
        path = batch.path,
        rule = context.catalog.batchRules.lookup[batchRuleKey],
        targets = sortedTargets(batch),
    })
end

local function biomeState(context, authored)
    local result = {}
    for semanticKey, state in pairs(context.biome.biomeState or {}) do
        if state.authored == true then
            result[semanticKey] = authored[semanticKey]
        end
    end
    return result
end

function linearBiome.readTopology(context, authored)
    onlyKeys(context, authored, authoredStateKeys(context), "authoredState")
    if authored.layoutKind ~= "LinearBiome" then
        fail(context, "layoutKind", "expected 'LinearBiome'")
    end
    if type(authored.terminalTransition) ~= "table" then
        fail(context, "terminalTransition", "expected a table")
    end

    local claims = {}
    claimRoom(context, claims, context.terminal, "terminalRoomControlKey")
    local start = normalizeStart(context, authored, claims)
    local batches = normalizeBatches(context, authored, claims)
    local terminal = normalizeTerminal(context, authored, claims)
    local companionCount = terminal and #terminal.companionTargets or 0
    if #authored.targets + companionCount > context.biome.layout.bounds.maxTargets then
        fail(context, "targets", "ordinary and terminal companion targets exceed the layout bound")
    end
    if terminal ~= nil and batches[terminal.parentRoomControlKey] ~= nil then
        fail(
            context,
            "terminalTransition.parentRoomControlKey",
            "selected source owns both a generated batch and terminal transition"
        )
    end

    local orderedBatches = {}
    local current = start
    local reached = {}
    local selected = {}
    if current ~= nil then
        selected[current.control.key] = true
    end
    while current ~= nil do
        if reached[current.control.key] then
            fail(context, "batches", "picked continuation forms a cycle")
        end
        reached[current.control.key] = true
        local batch = batches[current.control.key]
        if batch == nil then
            break
        end
        local normalized = normalizeBatch(context, batch)
        orderedBatches[#orderedBatches + 1] = normalized
        local picked
        for _, target in ipairs(normalized.targets) do
            if target.picked then
                picked = target.room
            end
            target.room = nil
        end
        if picked == nil then
            break
        end
        selected[picked.control.key] = true
        current = picked
    end

    for parentControlKey, batch in pairs(batches) do
        if not reached[parentControlKey] then
            fail(
                context,
                batch.path .. ".parentRoomControlKey",
                "generated batch parent is not on the selected spine"
            )
        end
    end
    if terminal ~= nil and not selected[terminal.parentRoomControlKey] then
        fail(
            context,
            "terminalTransition.parentRoomControlKey",
            "terminal predecessor is not on the selected spine"
        )
    end

    return {
        biomeStepKey = context.biome.biomeStepKey,
        layoutKind = "LinearBiome",
        startRoomControlKey = start and start.control.key or nil,
        biomeState = biomeState(context, authored),
        batches = orderedBatches,
        terminalTransition = terminal,
    }
end

return linearBiome
