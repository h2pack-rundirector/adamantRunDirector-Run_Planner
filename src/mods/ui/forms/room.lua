local feedback = import("mods/ui/forms/feedback.lua")
local generatedDoor = import("mods/ui/forms/generated_door.lua")
local identity = import("mods/ui/forms/identity.lua")
local roomOffer = import("mods/ui/forms/room_offer.lua")
local widgets = import("mods/ui/planner/widgets.lua")

local roomForm = {}

local function roomTitle(state, context, room)
    return "Room " .. tostring(context.roomIndex) .. " - " .. widgets.preview(state.roomOptions, room.roomKey)
end

function roomForm.draw(state, imgui, evaluation, context, room)
    local form = identity.room(context)
    widgets.section(imgui, roomTitle(state, context, room))
    local roomIndent = widgets.indent(imgui)
    local address = identity.address(form)
    local routeBlocker = feedback.firstIssueForAddress(evaluation, address)
    local roomFeedback = feedback.forAddress(evaluation, address)

    widgets.subsection(imgui, "Room identity")
    local identityIndent = widgets.indent(imgui)
    local nextRoomKey, roomChanged = widgets.dropdown(
        imgui,
        identity.control(form, "Room", "roomKey"),
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
    widgets.unindent(imgui, identityIndent)

    if room.offerPoints ~= nil then
        widgets.subsection(imgui, "Room-local offers")
        local roomOfferIndent = widgets.indent(imgui)
        roomOffer.draw(state, imgui, evaluation, context, room)
        widgets.unindent(imgui, roomOfferIndent)
    end

    local generatedDoors = room.generatedDoors
    if generatedDoors == nil then
        widgets.subsection(imgui, "Generated door batch")
        local terminalIndent = widgets.indent(imgui)
        widgets.text(imgui, "Terminal room")
        widgets.unindent(imgui, terminalIndent)
        widgets.unindent(imgui, roomIndent)
        return
    end

    widgets.subsection(imgui, "Generated door batch")
    local batchIndent = widgets.indent(imgui)
    widgets.labelValue(imgui, "Batch rule", generatedDoors.batchRule or "Standard")
    local nextSelectedDoor, selectedChanged = widgets.dropdown(
        imgui,
        identity.control(form, "Selected door", "selectedDoor"),
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
    widgets.unindent(imgui, batchIndent)
    widgets.unindent(imgui, roomIndent)
end

return roomForm
