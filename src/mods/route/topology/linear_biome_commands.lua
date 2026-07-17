local linearBiomeCommands = {}

local function copy(value)
    if type(value) ~= "table" then
        return value
    end
    local result = {}
    for key, child in pairs(value) do
        result[key] = copy(child)
    end
    return result
end

local function onlyKeys(specification, allowed)
    local lookup = { kind = true }
    for _, key in ipairs(allowed) do
        lookup[key] = true
    end
    for key in pairs(specification.command) do
        if not lookup[key] then
            specification.fail("command." .. tostring(key), "unexpected command field")
        end
    end
end

local function nonEmptyString(specification, key)
    local value = specification.command[key]
    if type(value) ~= "string" or value == "" then
        specification.fail("command." .. key, "expected a non-empty string")
    end
    return value
end

local function positiveInteger(specification, key)
    local value = specification.command[key]
    if type(value) ~= "number" or value ~= math.floor(value) or value < 1 then
        specification.fail("command." .. key, "expected a positive integer")
    end
    return value
end

local function findBatch(authored, parentRoomControlKey)
    for index, batch in ipairs(authored.batches) do
        if batch.parentRoomControlKey == parentRoomControlKey then
            return batch, index
        end
    end
end

local function requireBatch(specification, authored, parentRoomControlKey)
    local batch, index = findBatch(authored, parentRoomControlKey)
    if batch == nil then
        specification.fail(
            "command.parentRoomControlKey",
            "selected source does not own a generated batch"
        )
    end
    return batch, index
end

local function findTarget(authored, parentRoomControlKey, exitIndex)
    for index, target in ipairs(authored.targets) do
        if target.parentRoomControlKey == parentRoomControlKey
            and target.exitIndex == exitIndex
        then
            return target, index
        end
    end
end

local function requireTarget(specification, authored, parentRoomControlKey, exitIndex)
    local target, index = findTarget(authored, parentRoomControlKey, exitIndex)
    if target == nil then
        specification.fail("command.exitIndex", "physical exit has no generated target")
    end
    return target, index
end

local function clearTerminal(authored)
    authored.terminalTransition = { parentRoomControlKey = "" }
end

local function filterRows(rows, removedParents)
    local result = {}
    for _, row in ipairs(rows) do
        if not removedParents[row.parentRoomControlKey] then
            result[#result + 1] = row
        end
    end
    return result
end

local function clearAfterBatch(
    specification,
    authored,
    topology,
    parentRoomControlKey,
    removeParent
)
    local batchIndex
    for index, batch in ipairs(topology.batches) do
        if batch.parentRoomControlKey == parentRoomControlKey then
            batchIndex = index
            break
        end
    end
    if batchIndex == nil then
        specification.fail(
            "command.parentRoomControlKey",
            "generated batch is not on the selected spine"
        )
    end

    local removedParents = {}
    local firstRemoved = removeParent and batchIndex or batchIndex + 1
    for index = firstRemoved, #topology.batches do
        removedParents[topology.batches[index].parentRoomControlKey] = true
    end
    authored.batches = filterRows(authored.batches, removedParents)
    authored.targets = filterRows(authored.targets, removedParents)
    clearTerminal(authored)
end

local function selectStart(specification, authored)
    onlyKeys(specification, { "roomControlKey" })
    if specification.layout.start.mode ~= "oneOf" then
        specification.fail("command", "fixed-start topology does not admit SelectStart")
    end
    local roomControlKey = nonEmptyString(specification, "roomControlKey")
    if authored.selectedStartRoomControlKey ~= roomControlKey then
        authored.selectedStartRoomControlKey = roomControlKey
        authored.batches = {}
        authored.targets = {}
        clearTerminal(authored)
    end
end

local function createBatch(specification, authored)
    onlyKeys(specification, { "parentRoomControlKey" })
    local parentRoomControlKey = nonEmptyString(specification, "parentRoomControlKey")
    if findBatch(authored, parentRoomControlKey) ~= nil then
        specification.fail("command.parentRoomControlKey", "selected source already owns a batch")
    end
    if authored.terminalTransition.parentRoomControlKey ~= "" then
        specification.fail(
            "command.parentRoomControlKey",
            "terminal transition must be replaced explicitly"
        )
    end
    authored.batches[#authored.batches + 1] = {
        parentRoomControlKey = parentRoomControlKey,
    }
end

local function setTarget(specification, authored, topology)
    onlyKeys(specification, { "exitIndex", "parentRoomControlKey", "roomControlKey" })
    local parentRoomControlKey = nonEmptyString(specification, "parentRoomControlKey")
    local exitIndex = positiveInteger(specification, "exitIndex")
    local roomControlKey = nonEmptyString(specification, "roomControlKey")
    requireBatch(specification, authored, parentRoomControlKey)
    local target = findTarget(authored, parentRoomControlKey, exitIndex)
    if target == nil then
        authored.targets[#authored.targets + 1] = {
            parentRoomControlKey = parentRoomControlKey,
            exitIndex = exitIndex,
            roomControlKey = roomControlKey,
            picked = false,
        }
    else
        if target.picked and target.roomControlKey ~= roomControlKey then
            clearAfterBatch(
                specification,
                authored,
                topology,
                parentRoomControlKey,
                false
            )
        end
        target.roomControlKey = roomControlKey
    end
end

local function setPicked(specification, authored, topology)
    onlyKeys(specification, { "exitIndex", "parentRoomControlKey" })
    local parentRoomControlKey = nonEmptyString(specification, "parentRoomControlKey")
    local exitIndex = positiveInteger(specification, "exitIndex")
    requireBatch(specification, authored, parentRoomControlKey)
    local selected = requireTarget(specification, authored, parentRoomControlKey, exitIndex)
    if selected.picked then
        return
    end
    local previous
    for _, target in ipairs(authored.targets) do
        if target.parentRoomControlKey == parentRoomControlKey and target.picked then
            previous = target
            break
        end
    end
    if previous ~= nil then
        clearAfterBatch(
            specification,
            authored,
            topology,
            parentRoomControlKey,
            false
        )
        previous.picked = false
    end
    selected.picked = true
end

local function removeBatch(specification, authored, topology)
    onlyKeys(specification, { "parentRoomControlKey" })
    local parentRoomControlKey = nonEmptyString(specification, "parentRoomControlKey")
    requireBatch(specification, authored, parentRoomControlKey)
    clearAfterBatch(specification, authored, topology, parentRoomControlKey, true)
end

local function createTerminalTransition(specification, authored)
    onlyKeys(specification, { "parentRoomControlKey" })
    local parentRoomControlKey = nonEmptyString(specification, "parentRoomControlKey")
    if authored.terminalTransition.parentRoomControlKey ~= "" then
        specification.fail("command", "topology already owns a terminal transition")
    end
    if findBatch(authored, parentRoomControlKey) ~= nil then
        specification.fail(
            "command.parentRoomControlKey",
            "generated batch must be replaced explicitly"
        )
    end
    authored.terminalTransition = {
        parentRoomControlKey = parentRoomControlKey,
        companionTargets = {},
    }
end

local function requireCompanionPolicy(specification)
    if specification.layout.terminal.exitPolicy.kind ~= "terminalWithCompanions" then
        specification.fail("command", "terminal policy does not admit companion targets")
    end
end

local function requireTerminal(specification, authored)
    if authored.terminalTransition.parentRoomControlKey == "" then
        specification.fail("command", "topology has no terminal transition")
    end
end

local function setTerminalCompanion(specification, authored)
    onlyKeys(specification, { "exitIndex", "roomControlKey" })
    requireCompanionPolicy(specification)
    requireTerminal(specification, authored)
    local exitIndex = positiveInteger(specification, "exitIndex")
    local roomControlKey = nonEmptyString(specification, "roomControlKey")
    local companions = authored.terminalTransition.companionTargets or {}
    authored.terminalTransition.companionTargets = companions
    for _, target in ipairs(companions) do
        if target.exitIndex == exitIndex then
            target.roomControlKey = roomControlKey
            return
        end
    end
    companions[#companions + 1] = {
        exitIndex = exitIndex,
        roomControlKey = roomControlKey,
    }
end

local function removeTerminalTransition(specification, authored)
    onlyKeys(specification, {})
    requireTerminal(specification, authored)
    clearTerminal(authored)
end

local function replaceWithBatch(specification, authored)
    onlyKeys(specification, { "parentRoomControlKey" })
    local parentRoomControlKey = nonEmptyString(specification, "parentRoomControlKey")
    requireTerminal(specification, authored)
    if authored.terminalTransition.parentRoomControlKey ~= parentRoomControlKey then
        specification.fail(
            "command.parentRoomControlKey",
            "selected source does not own the terminal transition"
        )
    end
    if findBatch(authored, parentRoomControlKey) ~= nil then
        specification.fail("command.parentRoomControlKey", "selected source already owns a batch")
    end
    clearTerminal(authored)
    authored.batches[#authored.batches + 1] = {
        parentRoomControlKey = parentRoomControlKey,
    }
end

local function replaceWithTerminalTransition(specification, authored, topology)
    onlyKeys(specification, { "parentRoomControlKey" })
    local parentRoomControlKey = nonEmptyString(specification, "parentRoomControlKey")
    if authored.terminalTransition.parentRoomControlKey ~= "" then
        specification.fail("command", "topology already owns a terminal transition")
    end
    requireBatch(specification, authored, parentRoomControlKey)
    clearAfterBatch(specification, authored, topology, parentRoomControlKey, true)
    authored.terminalTransition = {
        parentRoomControlKey = parentRoomControlKey,
        companionTargets = {},
    }
end

local function clearTopology(specification, authored)
    onlyKeys(specification, {})
    if specification.layout.start.mode == "oneOf" then
        authored.selectedStartRoomControlKey = ""
    end
    authored.batches = {}
    authored.targets = {}
    clearTerminal(authored)
end

local handlers = {
    SelectStart = selectStart,
    CreateBatch = createBatch,
    SetTarget = setTarget,
    SetPicked = setPicked,
    RemoveBatch = removeBatch,
    CreateTerminalTransition = createTerminalTransition,
    SetTerminalCompanion = setTerminalCompanion,
    RemoveTerminalTransition = removeTerminalTransition,
    ReplaceWithBatch = replaceWithBatch,
    ReplaceWithTerminalTransition = replaceWithTerminalTransition,
    ClearTopology = clearTopology,
}

function linearBiomeCommands.apply(specification)
    if type(specification.command) ~= "table" then
        specification.fail("command", "expected a command table")
    end
    local handler = handlers[specification.command.kind]
    if handler == nil then
        specification.fail(
            "command.kind",
            "unknown LinearBiome command '" .. tostring(specification.command.kind) .. "'"
        )
    end

    local current = specification.normalize(specification.authored)
    local proposed = copy(specification.authored)
    handler(specification, proposed, current)
    return proposed, specification.normalize(proposed)
end

return linearBiomeCommands
