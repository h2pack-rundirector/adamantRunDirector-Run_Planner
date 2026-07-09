local feedback = import("mods/ui/forms/feedback.lua")
local feedbackPresentation = import("mods/ui/forms/feedback_presentation.lua")
local identity = import("mods/ui/forms/identity.lua")
local rewardOffer = import("mods/ui/forms/reward_offer.lua")
local widgets = import("mods/ui/planner/widgets.lua")

local generatedDoor = {}

function generatedDoor.draw(state, imgui, evaluation, context, door)
    local form = identity.generatedDoor(context)
    widgets.subsection(imgui, "Door " .. tostring(context.doorIndex) .. " / exit " .. tostring(door.exitIndex))
    local doorIndent = widgets.indent(imgui)
    local address = identity.address(form)
    local routeBlocker = feedback.firstRouteBlockerForAddress(evaluation, address)
    local doorFeedback = feedback.forAddress(evaluation, address)

    local participant = state.participants:find(form)
    local providers = participant and participant.providers or {}
    local targetOptions = providers.nextDoorTarget or state.roomOptions
    local nextTarget, targetChanged = widgets.dropdown(
        imgui,
        identity.control(form, "Target", "targetRoom"),
        door.targetRoomKey,
        targetOptions
    )
    if targetChanged then
        state.setDoorTarget(context.roomIndex, context.doorIndex, nextTarget)
    end

    rewardOffer.drawGeneratedDoor(state, imgui, evaluation, context, door)
    feedbackPresentation.draw(imgui, "Route blocker", routeBlocker, { role = "blocker" })
    if doorFeedback ~= routeBlocker then
        feedbackPresentation.draw(imgui, "Door feedback", doorFeedback)
    end
    widgets.unindent(imgui, doorIndent)
end

return generatedDoor
