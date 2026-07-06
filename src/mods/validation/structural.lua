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

local function doorAddressKey(formAddress)
    return addressKey(formAddress) .. ":" .. tostring(formAddress.doorIndex)
end

local function indexHistory(history)
    local indexed = {
        roomEvents = {},
        generatedDoors = {},
        roomByIndex = {},
        roomByAddress = {},
        generatedDoorByAddress = {},
        generatedDoorsByRoom = {},
        generateNextByRoom = {},
    }

    for _, event in ipairs(history.events) do
        if event.kind == "room.enter" then
            indexed.roomEvents[#indexed.roomEvents + 1] = event
            indexed.roomByIndex[roomKey(event.biomeKey, event.roomIndex)] = event
            indexed.roomByAddress[addressKey(event.sourceAddress)] = event
        elseif event.kind == "room.generate_next" then
            indexed.generateNextByRoom[roomKey(event.biomeKey, event.roomIndex)] = event
        end
    end

    for _, door in ipairs(history.generatedDoorHistory) do
        indexed.generatedDoors[#indexed.generatedDoors + 1] = door
        local key = roomKey(door.biomeKey, door.roomIndex)
        local doors = indexed.generatedDoorsByRoom[key]
        if doors == nil then
            doors = {}
            indexed.generatedDoorsByRoom[key] = doors
        end
        doors[#doors + 1] = door
        indexed.generatedDoorByAddress[doorAddressKey(door.sourceAddress)] = door
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

local function tagSet(values)
    local set = {}
    for _, value in ipairs(values or {}) do
        set[value] = true
    end
    return set
end

local function filteredExitTags(exit)
    local tags = {}
    for _, tag in ipairs(exit.tags or {}) do
        if tag ~= "Standard" then
            tags[#tags + 1] = tag
        end
    end
    return tags
end

local function exitTagsSatisfied(exit, targetRoom)
    local requiredTags = filteredExitTags(exit or {})
    if #requiredTags == 0 then
        return true
    end

    local targetTags = tagSet(targetRoom.tags)
    for _, tag in ipairs(requiredTags) do
        if not targetTags[tag] then
            return false
        end
    end
    return true
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
        defaultMessage = "Generated room target fails declared eligibility.",
    })

    if violation ~= nil then
        violation.payload.targetRoomKey = targetRoomKey
        violation.payload.sourceRoomKey = generateNextEvent.roomKey
    end

    return violation
end

local function roomCapViolation(catalog, biomeKey, targetRoomKey, projectedCount)
    local targetRoom = getRoom(catalog, biomeKey, targetRoomKey)
    if targetRoom == nil or targetRoom.caps == nil or targetRoom.caps.maxCreationsThisRun == nil then
        return nil
    end

    local maxCreations = guard.expectNumber(targetRoom.caps.maxCreationsThisRun, "validation.room.caps.maxCreationsThisRun")
    if projectedCount <= maxCreations then
        return nil
    end

    return {
        code = "room_creation_cap_exceeded",
        phase = "room.generate_next",
        presentation = "invalid",
        payload = {
            targetRoomKey = targetRoomKey,
            actualCount = projectedCount,
            maxCreationsThisRun = maxCreations,
        },
        message = "Generated room target exceeds its creation cap.",
    }
end

local function generatedTargetCountBefore(indexed, biomeKey, targetRoomKey, eventIndex)
    local count = 0
    for _, door in ipairs(indexed.generatedDoors) do
        if door.eventIndex < eventIndex and door.biomeKey == biomeKey and door.targetRoomKey == targetRoomKey then
            count = count + 1
        end
    end
    return count
end

local function enteredRoomCountBefore(indexed, biomeKey, roomKeyValue, eventIndex)
    local count = 0
    for _, event in ipairs(indexed.roomEvents) do
        if event.eventIndex < eventIndex and event.biomeKey == biomeKey and event.roomKey == roomKeyValue then
            count = count + 1
        end
    end
    return count
end

local function batchTargetCount(doors, targetRoomKey)
    local count = 0
    for _, door in ipairs(doors or {}) do
        if door.targetRoomKey == targetRoomKey then
            count = count + 1
        end
    end
    return count
end

local function projectedCreationCount(indexed, generateNextEvent, targetRoomKey, currentBatchTargetCount)
    local generatedCount = generatedTargetCountBefore(
        indexed,
        generateNextEvent.biomeKey,
        targetRoomKey,
        generateNextEvent.eventIndex
    ) + currentBatchTargetCount
    local enteredCount = enteredRoomCountBefore(
        indexed,
        generateNextEvent.biomeKey,
        targetRoomKey,
        generateNextEvent.eventIndex
    )
    return math.max(generatedCount, enteredCount)
end

local function projectedCandidateBatchTargetCount(doors, currentDoor, targetRoomKey)
    local count = 0
    for _, door in ipairs(doors or {}) do
        local projectedTargetRoomKey = door == currentDoor and targetRoomKey or door.targetRoomKey
        if projectedTargetRoomKey == targetRoomKey then
            count = count + 1
        end
    end
    return count
end

local function candidateRoomCapViolation(catalog, indexed, generateNextEvent, targetRoomKey, currentDoor, doors)
    if currentDoor == nil then
        guard.fail("validation.candidate.formAddress", "candidate address must resolve to generated door history")
    end
    return roomCapViolation(
        catalog,
        generateNextEvent.biomeKey,
        targetRoomKey,
        projectedCreationCount(
            indexed,
            generateNextEvent,
            targetRoomKey,
            projectedCandidateBatchTargetCount(doors, currentDoor, targetRoomKey)
        )
    )
end

local function selectedRoomCapViolation(catalog, indexed, generateNextEvent, door, doors)
    return roomCapViolation(
        catalog,
        generateNextEvent.biomeKey,
        door.targetRoomKey,
        projectedCreationCount(indexed, generateNextEvent, door.targetRoomKey, batchTargetCount(doors, door.targetRoomKey))
    )
end

local function roomHasForceCreationCapacity(catalog, indexed, generateNextEvent, roomKeyValue)
    local room = getRoom(catalog, generateNextEvent.biomeKey, roomKeyValue)
    if room == nil or room.caps == nil or room.caps.maxCreationsThisRun == nil then
        return true
    end

    local maxCreations = guard.expectNumber(room.caps.maxCreationsThisRun, "validation.room.caps.maxCreationsThisRun")
    return projectedCreationCount(indexed, generateNextEvent, roomKeyValue, 0) < maxCreations
end

local function forceAxisValue(force, generateNextEvent)
    if force.axis == "BiomeDepthCache" then
        return generateNextEvent.biomeDepthCache
    end

    guard.fail("validation.force.axis", "unsupported force axis '" .. tostring(force.axis) .. "'")
end

local function forceWindowStarted(force, generateNextEvent)
    return forceAxisValue(force, generateNextEvent) >= force.start
end

local function forceDeadlineReached(force, generateNextEvent)
    return forceAxisValue(force, generateNextEvent) >= force.deadline
end

local function newForceState()
    return {
        unresolvedByBiome = {},
    }
end

local function unresolvedForceSet(catalog, forceState, biomeKey)
    local unresolved = forceState.unresolvedByBiome[biomeKey]
    if unresolved ~= nil then
        return unresolved
    end

    unresolved = {}
    local biome = getBiome(catalog, biomeKey)
    if biome ~= nil then
        for _, room in ipairs(biome.rooms.ordered or {}) do
            if room.force ~= nil then
                unresolved[room.key] = true
            end
        end
    end

    forceState.unresolvedByBiome[biomeKey] = unresolved
    return unresolved
end

local function markGeneratedForceTargets(catalog, forceState, biomeKey, doors)
    local unresolved = unresolvedForceSet(catalog, forceState, biomeKey)
    for _, door in ipairs(doors or {}) do
        local room = getRoom(catalog, biomeKey, door.targetRoomKey)
        if room ~= nil and room.force ~= nil then
            unresolved[room.key] = nil
        end
    end
end

local function roomCanUseAnyGeneratedExit(sourceRoom, targetRoom, doors)
    for _, door in ipairs(doors or {}) do
        local exit = sourceRoom.exits[door.exitIndex]
        if exit ~= nil and exitTagsSatisfied(exit, targetRoom) then
            return true
        end
    end
    return false
end

local function forceRoomEligibleForBatch(catalog, indexed, generateNextEvent, sourceRoom, targetRoom, doors)
    if sourceRoom == nil or targetRoom == nil or targetRoom.force == nil then
        return false
    end

    if not forceWindowStarted(targetRoom.force, generateNextEvent) then
        return false
    end

    if roomEligibilityViolation(catalog, generateNextEvent, targetRoom.key, "validation.forcePressure." .. targetRoom.key) ~= nil then
        return false
    end

    if not roomHasForceCreationCapacity(catalog, indexed, generateNextEvent, targetRoom.key) then
        return false
    end

    return roomCanUseAnyGeneratedExit(sourceRoom, targetRoom, doors)
end

local function forcePressureViolation(catalog, indexed, forceState, generateNextEvent, doors, code)
    local biome = getBiome(catalog, generateNextEvent.biomeKey)
    local sourceRoom = getRoom(catalog, generateNextEvent.biomeKey, generateNextEvent.roomKey)
    if biome == nil or sourceRoom == nil then
        return nil
    end

    local unresolved = unresolvedForceSet(catalog, forceState, generateNextEvent.biomeKey)
    local eligibleKeys = {}
    local eligibleSet = {}
    local deadlineKeys = {}

    for _, targetRoom in ipairs(biome.rooms.ordered or {}) do
        if unresolved[targetRoom.key]
            and forceRoomEligibleForBatch(catalog, indexed, generateNextEvent, sourceRoom, targetRoom, doors) then
            eligibleKeys[#eligibleKeys + 1] = targetRoom.key
            eligibleSet[targetRoom.key] = true
            if forceDeadlineReached(targetRoom.force, generateNextEvent) then
                deadlineKeys[#deadlineKeys + 1] = targetRoom.key
            end
        end
    end

    if #deadlineKeys == 0 then
        return nil
    end

    local requiredCount = math.min(#eligibleKeys, #(doors or {}))
    if requiredCount == 0 then
        return nil
    end

    local generatedSet = {}
    local generatedKeys = {}
    for _, door in ipairs(doors or {}) do
        if eligibleSet[door.targetRoomKey] and not generatedSet[door.targetRoomKey] then
            generatedSet[door.targetRoomKey] = true
            generatedKeys[#generatedKeys + 1] = door.targetRoomKey
        end
    end

    if #generatedKeys >= requiredCount then
        return nil
    end

    return {
        code = code or "force_pressure_missing_room",
        phase = "room.generate_next",
        presentation = "invalid",
        payload = {
            roomKey = generateNextEvent.roomKey,
            deadlineForceRoomKeys = deadlineKeys,
            eligibleUnresolvedForceRoomKeys = eligibleKeys,
            generatedForceRoomKeys = generatedKeys,
            requiredForcedCount = requiredCount,
            generatedDoorCount = #(doors or {}),
        },
        message = "Generated doors must spend available slots on eligible forced room targets.",
    }
end

local function exitTagsViolation(catalog, biomeKey, sourceRoomKey, exitIndex, targetRoomKey)
    local sourceRoom = getRoom(catalog, biomeKey, sourceRoomKey)
    local targetRoom = getRoom(catalog, biomeKey, targetRoomKey)
    if sourceRoom == nil or targetRoom == nil then
        return nil
    end

    local exit = sourceRoom.exits[exitIndex]
    if exit == nil then
        return nil
    end

    if exitTagsSatisfied(exit, targetRoom) then
        return nil
    end

    return {
        code = "generated_door_exit_tags_mismatch",
        phase = "room.generate_next",
        presentation = "invalid",
        payload = {
            roomKey = sourceRoomKey,
            exitIndex = exitIndex,
            exitTags = filteredExitTags(exit),
            targetRoomKey = targetRoomKey,
            targetTags = targetRoom.tags or {},
        },
        message = "Generated door target does not satisfy declared exit tags.",
    }
end

local function validateDoorExit(result, catalog, door)
    addSelectedViolation(result, door.sourceAddress, doorExitViolation(catalog, door.biomeKey, door.roomKey, door.exitIndex))
end

local function validateDoorTarget(result, catalog, door)
    addSelectedViolation(result, door.sourceAddress, doorTargetViolation(catalog, door.biomeKey, door.targetRoomKey))
end

local function validateDoorLegality(result, catalog, indexed, door)
    if getRoom(catalog, door.biomeKey, door.targetRoomKey) == nil then
        return
    end

    local generateNextEvent = generateNextForRoom(
        indexed,
        door.biomeKey,
        door.roomIndex,
        "validation.generatedDoors[" .. tostring(door.eventIndex) .. "]"
    )
    local doors = indexed.generatedDoorsByRoom[roomKey(door.biomeKey, door.roomIndex)] or {}
    local context = "validation.generatedDoors[" .. tostring(door.eventIndex) .. "].targetRoom"
    local eligibilityViolation = roomEligibilityViolation(catalog, generateNextEvent, door.targetRoomKey, context)
    addSelectedViolation(result, door.sourceAddress, exitTagsViolation(catalog, door.biomeKey, door.roomKey, door.exitIndex, door.targetRoomKey))
    addSelectedViolation(result, door.sourceAddress, eligibilityViolation)
    addSelectedViolation(result, door.sourceAddress, selectedRoomCapViolation(catalog, indexed, generateNextEvent, door, doors))
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
        validateDoorLegality(result, catalog, indexed, door)
    end

    local forceState = newForceState()
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
                addSelectedViolation(result, generateNextEvent.sourceAddress, forcePressureViolation(
                    catalog,
                    indexed,
                    forceState,
                    generateNextEvent,
                    doors
                ))
                markGeneratedForceTargets(catalog, forceState, generateNextEvent.biomeKey, doors)
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

local function forceStateBeforeGenerateNext(catalog, indexed, history, generateNextEvent)
    local forceState = newForceState()
    for _, event in ipairs(history.events) do
        if event.eventIndex >= generateNextEvent.eventIndex then
            break
        end

        if event.kind == "room.generate_next" then
            markGeneratedForceTargets(
                catalog,
                forceState,
                event.biomeKey,
                indexed.generatedDoorsByRoom[roomKey(event.biomeKey, event.roomIndex)] or {}
            )
        end
    end
    return forceState
end

local function projectedCandidateDoors(doors, currentDoor, targetRoomKey)
    local projected = {}
    for index, door in ipairs(doors or {}) do
        if door == currentDoor then
            projected[index] = {
                biomeKey = door.biomeKey,
                roomIndex = door.roomIndex,
                roomKey = door.roomKey,
                doorIndex = door.doorIndex,
                exitIndex = door.exitIndex,
                targetRoomKey = targetRoomKey,
                sourceAddress = door.sourceAddress,
            }
        else
            projected[index] = door
        end
    end
    return projected
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

local function evaluateNextRoomCandidate(result, catalog, history, indexed, record, semantic, context)
    local biomeKey, sourceRoomKey = sourceForNextRoomCandidate(indexed, record, semantic, context)
    local exitIndex = guard.expectNumber(semantic.exitIndex, context .. ".semantic.exitIndex")
    local targetRoomKey = guard.expectString(semantic.targetRoomKey, context .. ".semantic.targetRoomKey")
    local sourceRoomIndex = guard.expectNumber(record.formAddress.roomIndex, context .. ".formAddress.roomIndex")
    local generateNextEvent = generateNextForRoom(indexed, biomeKey, sourceRoomIndex, context .. ".formAddress")
    local currentDoor = indexed.generatedDoorByAddress[doorAddressKey(record.formAddress)]
    local doors = indexed.generatedDoorsByRoom[roomKey(biomeKey, sourceRoomIndex)] or {}
    local exitViolation = doorExitViolation(catalog, biomeKey, sourceRoomKey, exitIndex)
    local targetViolation = doorTargetViolation(catalog, biomeKey, targetRoomKey)
    local tagViolation = exitTagsViolation(catalog, biomeKey, sourceRoomKey, exitIndex, targetRoomKey)
    local eligibilityViolation = roomEligibilityViolation(catalog, generateNextEvent, targetRoomKey, context .. ".semantic")
    local capViolation = candidateRoomCapViolation(catalog, indexed, generateNextEvent, targetRoomKey, currentDoor, doors)

    addCandidateViolation(result, record, exitViolation)
    addCandidateViolation(result, record, targetViolation)
    addCandidateViolation(result, record, tagViolation)
    addCandidateViolation(result, record, eligibilityViolation)
    addCandidateViolation(result, record, capViolation)

    if exitViolation == nil
        and targetViolation == nil
        and tagViolation == nil
        and eligibilityViolation == nil
        and capViolation == nil then
        addCandidateViolation(result, record, forcePressureViolation(
            catalog,
            indexed,
            forceStateBeforeGenerateNext(catalog, indexed, history, generateNextEvent),
            generateNextEvent,
            projectedCandidateDoors(doors, currentDoor, targetRoomKey),
            "force_pressure_conflict"
        ))
    end
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

local function evaluateCandidateRecords(result, catalog, history, indexed, records)
    for index, record in ipairs(records) do
        local context = "validation.candidateRecords[" .. tostring(index) .. "]"
        local kind, semantic = expectCandidateRecord(record, context)

        if kind == "nextRoom" then
            evaluateNextRoomCandidate(result, catalog, history, indexed, record, semantic, context)
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
    evaluateCandidateRecords(result, context.catalog, history, indexed, candidateRecords(context, history))

    return result
end

return structural
