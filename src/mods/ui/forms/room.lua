local feedback = import("mods/ui/forms/feedback.lua")
local generatedDoor = import("mods/ui/forms/generated_door.lua")
local roomOffer = import("mods/ui/forms/room_offer.lua")
local widgets = import("mods/ui/planner/widgets.lua")

local roomForm = {}

local function roomAddress(state, context)
    return {
        routeKey = state.draft.routeKey,
        biomeIndex = context.biomeIndex,
        roomIndex = context.roomIndex,
    }
end

function roomForm.draw(state, imgui, evaluation, context, room)
    widgets.section(imgui, "Room " .. tostring(context.roomIndex))
    local address = roomAddress(state, context)
    local routeBlocker = feedback.firstIssueForAddress(evaluation, address)
    local roomFeedback = feedback.forAddress(evaluation, address)

    local nextRoomKey, roomChanged = widgets.dropdown(
        imgui,
        "Room##" .. tostring(context.roomIndex),
        room.roomKey,
        state.roomOptions
    )
    if roomChanged then
        state.setRoomKey(context.roomIndex, nextRoomKey)
    end

    widgets.feedback(imgui, "Route blocker", routeBlocker)
    if roomFeedback ~= routeBlocker then
        widgets.feedback(imgui, "Room feedback", roomFeedback)
    end

    if room.offerPoints ~= nil then
        roomOffer.draw(state, imgui, evaluation, context, room)
    end

    local generatedDoors = room.generatedDoors
    if generatedDoors == nil then
        widgets.text(imgui, "Terminal/no generated doors")
        return
    end

    local nextSelectedDoor, selectedChanged = widgets.dropdown(
        imgui,
        "Selected door##" .. tostring(context.roomIndex),
        generatedDoors.selectedDoorIndex,
        state.selectedDoorOptions(generatedDoors)
    )
    if selectedChanged then
        state.setSelectedDoor(context.roomIndex, nextSelectedDoor)
    end

    for doorIndex, door in ipairs(generatedDoors.doors or {}) do
        generatedDoor.draw(state, imgui, evaluation, {
            routeKey = context.routeKey,
            biomeIndex = context.biomeIndex,
            roomIndex = context.roomIndex,
            doorIndex = doorIndex,
        }, door)
    end
end

return roomForm
