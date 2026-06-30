local nextChoiceView = {}

local function positiveIndex(value)
    local index = math.floor(tonumber(value) or 0)
    if index < 1 then
        return nil
    end
    return index
end

local function clear(target)
    for key in pairs(target) do
        target[key] = nil
    end
end

local function pickedDoorTargetRowIndex(rowIndex, rowCount)
    local current = positiveIndex(rowIndex)
    local count = math.floor(tonumber(rowCount) or 0)
    if current == nil or current >= count then
        return nil
    end
    return current + 1
end

local function isEntryRow(rowIndex)
    return rowIndex == 1
end

local function isTerminalRow(rowIndex, rowCount)
    return rowIndex ~= nil and rowCount ~= nil and rowIndex >= rowCount
end

local function fillCurrentRoom(currentRoom, rowIndex, rowCount, slotAt, labelForRow)
    clear(currentRoom)
    currentRoom.rowIndex = rowIndex
    currentRoom.isEntry = isEntryRow(rowIndex)
    currentRoom.isTerminal = isTerminalRow(rowIndex, rowCount)

    if slotAt ~= nil and rowIndex ~= nil then
        currentRoom.slot = slotAt(rowIndex)
    end
    if labelForRow ~= nil and rowIndex ~= nil then
        currentRoom.label = labelForRow(rowIndex)
    end
end

local function fillPickedDoor(pickedDoor, targetRowIndex, slotAt, labelForRow)
    clear(pickedDoor)
    pickedDoor.active = targetRowIndex ~= nil
    pickedDoor.targetRowIndex = targetRowIndex

    if slotAt ~= nil and targetRowIndex ~= nil then
        pickedDoor.targetSlot = slotAt(targetRowIndex)
    end
    if labelForRow ~= nil and targetRowIndex ~= nil then
        pickedDoor.targetLabel = labelForRow(targetRowIndex)
    end
end

local function fillOtherDoors(otherDoors, rowIndex, slotAt, labelForRow)
    clear(otherDoors)
    otherDoors.sourceRowIndex = rowIndex

    if slotAt ~= nil and rowIndex ~= nil then
        otherDoors.sourceSlot = slotAt(rowIndex)
    end
    if labelForRow ~= nil and rowIndex ~= nil then
        otherDoors.sourceLabel = labelForRow(rowIndex)
    end
end

local function fillNextChoices(nextChoices, rowIndex, rowCount, slotAt, labelForRow)
    local picked = nextChoices.picked or {}
    local others = nextChoices.others or {}
    clear(nextChoices)
    nextChoices.sourceRowIndex = rowIndex
    nextChoices.picked = picked
    nextChoices.others = others

    fillPickedDoor(picked, pickedDoorTargetRowIndex(rowIndex, rowCount), slotAt, labelForRow)
    nextChoices.active = picked.active
end

function nextChoiceView.fillRow(target, rowIndex, rowCount, slotAt, labelForRow)
    target = target or {}
    local currentRoom = target.currentRoom or {}
    local nextChoices = target.nextChoices or {}
    clear(target)

    rowIndex = positiveIndex(rowIndex)
    rowCount = math.floor(tonumber(rowCount) or 0)

    target.currentRoom = currentRoom
    target.nextChoices = nextChoices
    fillCurrentRoom(currentRoom, rowIndex, rowCount, slotAt, labelForRow)
    fillNextChoices(nextChoices, rowIndex, rowCount, slotAt, labelForRow)
    fillOtherDoors(nextChoices.others, rowIndex, slotAt, labelForRow)

    return target
end

return nextChoiceView
