local guard = import("mods/declarations/guard.lua")
local validationResult = import("mods/validation/result.lua")

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

local function indexHistory(history)
    local indexed = {
        roomByIndex = {},
        generatedDoorsByRoom = {},
        generateNextByRoom = {},
    }

    for _, event in ipairs(history.events) do
        if event.kind == "room.enter" then
            indexed.roomByIndex[roomKey(event.biomeKey, event.roomIndex)] = event
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

local function validateDoorExit(result, catalog, door)
    local sourceRoom = getRoom(catalog, door.biomeKey, door.roomKey)
    if sourceRoom == nil then
        return
    end

    if sourceRoom.exits[door.exitIndex] == nil then
        validationResult.invalid(result, "generated_door_exit_unknown", "room.generate_next", door.sourceAddress, {
            roomKey = door.roomKey,
            exitIndex = door.exitIndex,
            declaredExitCount = #sourceRoom.exits,
        }, "Generated door references an undeclared exit.")
    end
end

local function validateDoorTarget(result, catalog, door)
    if getRoom(catalog, door.biomeKey, door.targetRoomKey) == nil then
        validationResult.invalid(result, "generated_door_target_unknown", "room.generate_next", door.sourceAddress, {
            targetRoomKey = door.targetRoomKey,
        }, "Generated door target room is not declared.")
    end
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

function structural.validate(history, context)
    context = context or {}
    expectCatalog(context.catalog)
    expectHistory(history)

    local result = validationResult.new()
    local indexed = indexHistory(history)

    validateRoomExistence(result, context.catalog, history)
    validateGeneratedDoors(result, context.catalog, history, indexed)
    validateTerminalPlacement(result, context.catalog, history)

    return result
end

return structural
