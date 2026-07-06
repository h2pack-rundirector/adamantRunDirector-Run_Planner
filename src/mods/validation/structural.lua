local guard = import("mods/declarations/guard.lua")
local validationResult = import("mods/validation/result.lua")
local requirements = import("mods/validation/requirements.lua")

local structural = {}

local function expectCatalog(catalog)
    guard.expectTable(catalog, "validation.catalog")
    guard.expectTable(catalog.biomes, "validation.catalog.biomes")
    guard.expectTable(catalog.biomes.lookup, "validation.catalog.biomes.lookup")
end

local function expectHistory(history)
    guard.expectTable(history, "validation.history")
    guard.expectArray(history.events, "validation.history.events")
    guard.expectArray(history.roomHistory, "validation.history.roomHistory")
    guard.expectArray(history.generatedDoorHistory, "validation.history.generatedDoorHistory")
end

local function getBiome(catalog, biomeKey)
    return catalog.biomes.lookup[biomeKey]
end

local function getRoom(catalog, biomeKey, roomKey)
    local biome = getBiome(catalog, biomeKey)
    if biome == nil then
        return nil
    end
    return biome.rooms.lookup[roomKey]
end

local function roomKey(biomeKey, roomIndex)
    return tostring(biomeKey) .. ":" .. tostring(roomIndex)
end

local function addressKey(formAddress)
    return tostring(formAddress.routeKey) .. ":" .. tostring(formAddress.biomeIndex) .. ":" .. tostring(formAddress.roomIndex)
end

local function indexHistory(history)
    local indexed = {
        roomByIndex = {},
        roomByAddress = {},
        generatedDoorsByRoom = {},
        generateNextByRoom = {},
    }

    for _, event in ipairs(history.events) do
        if event.kind == "room.enter" then
            indexed.roomByIndex[roomKey(event.biomeKey, event.roomIndex)] = event
            indexed.roomByAddress[addressKey(event.sourceAddress)] = event
        elseif event.kind == "room.generate_next" then
            indexed.generateNextByRoom[roomKey(event.biomeKey, event.roomIndex)] = event
        end
    end

    for _, door in ipairs(history.generatedDoorHistory) do
        local key = roomKey(door.biomeKey, door.roomIndex)
        local doors = indexed.generatedDoorsByRoom[key]
        if doors == nil then
            doors = {}
            indexed.generatedDoorsByRoom[key] = doors
        end
        doors[#doors + 1] = door
    end

    return indexed
end

local function addRoomExistsFinding(result, event)
    validationResult.invalid(result, "room_unknown", event.phase or "room.enter", event.sourceAddress, {
        biomeKey = event.biomeKey,
        roomKey = event.roomKey,
    }, "Room key is not declared.")
end

local function validateRoomExistence(result, catalog, history)
    for _, event in ipairs(history.events) do
        if event.roomKey ~= nil and getRoom(catalog, event.biomeKey, event.roomKey) == nil then
            addRoomExistsFinding(result, event)
        end
    end
end

local function doorExitViolation(catalog, biomeKey, sourceRoomKey, exitIndex)
    local sourceRoom = getRoom(catalog, biomeKey, sourceRoomKey)
    if sourceRoom == nil then
        return
    end

    if sourceRoom.exits[exitIndex] ~= nil then
        return nil
    end

    return {
        code = "generated_door_exit_unknown",
        phase = "room.generate_next",
        presentation = "invalid",
        payload = {
            roomKey = sourceRoomKey,
            exitIndex = exitIndex,
            declaredExitCount = #sourceRoom.exits,
        },
        message = "Generated door references an undeclared exit.",
    }
end

local function doorTargetViolation(catalog, biomeKey, targetRoomKey)
    if getRoom(catalog, biomeKey, targetRoomKey) ~= nil then
        return nil
    end

    return {
        code = "generated_door_target_unknown",
        phase = "room.generate_next",
        presentation = "invalid",
        payload = {
            targetRoomKey = targetRoomKey,
        },
        message = "Generated door target room is not declared.",
    }
end

local function addSelectedViolation(result, sourceAddress, violation)
    if violation ~= nil then
        validationResult.invalid(result, violation.code, violation.phase, sourceAddress, violation.payload, violation.message)
    end
end

local function generateNextForRoom(indexed, biomeKey, roomIndex, context)
    local generateNextEvent = indexed.generateNextByRoom[roomKey(biomeKey, roomIndex)]
    if generateNextEvent == nil then
        guard.fail(context, "generated-door eligibility requires room.generate_next history")
    end
    return generateNextEvent
end

local function eligibilityCounters(generateNextEvent)
    return {
        biomeDepthCache = generateNextEvent.biomeDepthCache,
        biomeEncounterDepth = generateNextEvent.biomeEncounterDepth,
        runEncounterDepth = generateNextEvent.runEncounterDepth,
        roomHistoryOrdinal = generateNextEvent.roomHistoryOrdinal,
    }
end

local function roomEligibilityViolation(catalog, generateNextEvent, targetRoomKey, context)
    local targetRoom = getRoom(catalog, generateNextEvent.biomeKey, targetRoomKey)
    if targetRoom == nil or targetRoom.eligibility == nil then
        return nil
    end

    local violation = requirements.evaluate(targetRoom.eligibility, {
        path = context .. ".eligibility",
        namedRequirements = catalog.requirements,
        counters = eligibilityCounters(generateNextEvent),
    })

    if violation ~= nil then
        violation.payload.targetRoomKey = targetRoomKey
        violation.payload.sourceRoomKey = generateNextEvent.roomKey
    end

    return violation
end

local function validateDoorExit(result, catalog, door)
    addSelectedViolation(result, door.sourceAddress, doorExitViolation(catalog, door.biomeKey, door.roomKey, door.exitIndex))
end

local function validateDoorTarget(result, catalog, door)
    addSelectedViolation(result, door.sourceAddress, doorTargetViolation(catalog, door.biomeKey, door.targetRoomKey))
end

local function validateDoorEligibility(result, catalog, indexed, door)
    if getRoom(catalog, door.biomeKey, door.targetRoomKey) == nil then
        return
    end

    local generateNextEvent = generateNextForRoom(
        indexed,
        door.biomeKey,
        door.roomIndex,
        "validation.generatedDoors[" .. tostring(door.eventIndex) .. "]"
    )
    addSelectedViolation(
        result,
        door.sourceAddress,
        roomEligibilityViolation(catalog, generateNextEvent, door.targetRoomKey, "validation.generatedDoors[" .. tostring(door.eventIndex) .. "].targetRoom")
    )
end

local function validateDoorCount(result, catalog, roomEvent, doors)
    local room = getRoom(catalog, roomEvent.biomeKey, roomEvent.roomKey)
    if room == nil then
        return
    end

    local actualCount = #(doors or {})
    local expectedCount = #room.exits
    if actualCount ~= expectedCount then
        validationResult.invalid(result, "generated_door_count_mismatch", "room.generate_next", roomEvent.sourceAddress, {
            roomKey = roomEvent.roomKey,
            expectedCount = expectedCount,
            actualCount = actualCount,
        }, "Generated door count must match declared exits.")
    end
end

local function validateSelectedDoor(result, indexed, generateNextEvent, doors)
    if generateNextEvent.selectedDoorIndex == nil then
        return
    end

    local selectedDoor
    for _, door in ipairs(doors or {}) do
        if door.doorIndex == generateNextEvent.selectedDoorIndex then
            selectedDoor = door
            break
        end
    end

    if selectedDoor == nil then
        validationResult.invalid(result, "selected_door_missing", "room.generate_next", generateNextEvent.sourceAddress, {
            selectedDoorIndex = generateNextEvent.selectedDoorIndex,
        }, "Selected generated door must exist.")
        return
    end

    local nextRoom = indexed.roomByIndex[roomKey(generateNextEvent.biomeKey, generateNextEvent.roomIndex + 1)]
    if nextRoom ~= nil and selectedDoor.targetRoomKey ~= nextRoom.roomKey then
        validationResult.invalid(result, "selected_door_target_mismatch", "room.generate_next", selectedDoor.sourceAddress, {
            selectedDoorIndex = selectedDoor.doorIndex,
            targetRoomKey = selectedDoor.targetRoomKey,
            nextRoomKey = nextRoom.roomKey,
        }, "Selected generated door must target the next entered room.")
    end
end

local function validateGeneratedDoors(result, catalog, history, indexed)
    for _, door in ipairs(history.generatedDoorHistory) do
        validateDoorExit(result, catalog, door)
        validateDoorTarget(result, catalog, door)
        validateDoorEligibility(result, catalog, indexed, door)
    end

    for _, roomEvent in ipairs(history.roomHistory) do
        local key = roomKey(roomEvent.biomeKey, roomEvent.roomIndex)
        local generateNextEvent = indexed.generateNextByRoom[key]
        local doors = indexed.generatedDoorsByRoom[key] or {}
        local room = getRoom(catalog, roomEvent.biomeKey, roomEvent.roomKey)

        if room ~= nil and room.terminal then
            if generateNextEvent ~= nil or #doors > 0 then
                validationResult.invalid(result, "terminal_room_generates_doors", "room.generate_next", roomEvent.sourceAddress, {
                    roomKey = roomEvent.roomKey,
                }, "Terminal rooms must not generate next-room doors.")
            end
        elseif generateNextEvent ~= nil or #doors > 0 then
            validateDoorCount(result, catalog, roomEvent, doors)
            if generateNextEvent ~= nil then
                validateSelectedDoor(result, indexed, generateNextEvent, doors)
            end
        end
    end
end

local function validateTerminalPlacement(result, catalog, history)
    for index, roomEvent in ipairs(history.roomHistory) do
        local room = getRoom(catalog, roomEvent.biomeKey, roomEvent.roomKey)
        if room ~= nil and room.terminal and history.roomHistory[index + 1] ~= nil then
            validationResult.invalid(result, "terminal_room_not_last", "room.commit", roomEvent.sourceAddress, {
                roomKey = roomEvent.roomKey,
                nextRoomKey = history.roomHistory[index + 1].roomKey,
            }, "Terminal room must end the configured biome history.")
        end
    end
end

local function candidateRecords(context, history)
    local records = context.candidateRecords or history.candidateRecords
    if records == nil then
        return {}
    end
    return guard.expectArray(records, "validation.candidateRecords")
end

local function addCandidateViolation(result, record, violation)
    if violation ~= nil then
        validationResult.candidate(
            result,
            record,
            violation.code,
            violation.phase,
            violation.presentation,
            violation.payload,
            violation.message,
            violation.color
        )
    end
end

local function sourceForNextRoomCandidate(indexed, record, semantic, context)
    local biomeKey = semantic.biomeKey
    local sourceRoomKey = semantic.sourceRoomKey

    if biomeKey ~= nil and sourceRoomKey ~= nil then
        return biomeKey, sourceRoomKey
    end

    local sourceRoom = indexed.roomByAddress[addressKey(record.formAddress)]
    if sourceRoom == nil then
        guard.fail(context .. ".formAddress", "candidate address must resolve to room history")
    end

    return biomeKey or sourceRoom.biomeKey, sourceRoomKey or sourceRoom.roomKey
end

local function evaluateNextRoomCandidate(result, catalog, indexed, record, semantic, context)
    local biomeKey, sourceRoomKey = sourceForNextRoomCandidate(indexed, record, semantic, context)
    local exitIndex = guard.expectNumber(semantic.exitIndex, context .. ".semantic.exitIndex")
    local targetRoomKey = guard.expectString(semantic.targetRoomKey, context .. ".semantic.targetRoomKey")
    local sourceRoomIndex = guard.expectNumber(record.formAddress.roomIndex, context .. ".formAddress.roomIndex")
    local generateNextEvent = generateNextForRoom(indexed, biomeKey, sourceRoomIndex, context .. ".formAddress")

    addCandidateViolation(result, record, doorExitViolation(catalog, biomeKey, sourceRoomKey, exitIndex))
    addCandidateViolation(result, record, doorTargetViolation(catalog, biomeKey, targetRoomKey))
    addCandidateViolation(result, record, roomEligibilityViolation(catalog, generateNextEvent, targetRoomKey, context .. ".semantic"))
end

local function expectCandidateRecord(record, context)
    guard.expectTable(record, context)
    guard.expectTable(record.formAddress, context .. ".formAddress")
    guard.expectString(record.providerKey, context .. ".providerKey")
    guard.expectNumber(record.providerVersion, context .. ".providerVersion")
    guard.expectString(record.candidateKey, context .. ".candidateKey")
    guard.expectNumber(record.candidateIndex, context .. ".candidateIndex")
    local semantic = guard.expectTable(record.semantic, context .. ".semantic")
    local kind = guard.expectString(semantic.kind, context .. ".semantic.kind")
    return kind, semantic
end

local function evaluateCandidateRecords(result, catalog, indexed, records)
    for index, record in ipairs(records) do
        local context = "validation.candidateRecords[" .. tostring(index) .. "]"
        local kind, semantic = expectCandidateRecord(record, context)

        if kind == "nextRoom" then
            evaluateNextRoomCandidate(result, catalog, indexed, record, semantic, context)
        else
            guard.fail(context .. ".semantic.kind", "unknown candidate kind '" .. kind .. "'")
        end
    end
end

function structural.validate(history, context)
    context = context or {}
    expectCatalog(context.catalog)
    expectHistory(history)

    local result = validationResult.new()
    local indexed = indexHistory(history)

    validateRoomExistence(result, context.catalog, history)
    validateGeneratedDoors(result, context.catalog, history, indexed)
    validateTerminalPlacement(result, context.catalog, history)
    evaluateCandidateRecords(result, context.catalog, indexed, candidateRecords(context, history))

    return result
end

return structural
