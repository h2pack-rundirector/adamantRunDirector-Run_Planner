local feedback = import("mods/ui/forms/feedback.lua")
local rewardOffer = import("mods/ui/forms/reward_offer.lua")
local widgets = import("mods/ui/planner/widgets.lua")

local generatedDoor = {}

local function doorAddress(state, context)
    return {
        routeKey = state.draft.routeKey,
        biomeIndex = context.biomeIndex,
        roomIndex = context.roomIndex,
        doorIndex = context.doorIndex,
    }
end

function generatedDoor.draw(state, imgui, evaluation, context, door)
    widgets.subsection(imgui, "Door " .. tostring(context.doorIndex) .. " / exit " .. tostring(door.exitIndex))
    local doorIndent = widgets.indent(imgui)
    local address = doorAddress(state, context)
    local routeBlocker = feedback.firstIssueForAddress(evaluation, address)
    local doorFeedback = feedback.forAddress(evaluation, address)

    local providers = door.candidateProviders or {}
    local targetOptions = providers.nextDoorTarget or state.roomOptions
    local nextTarget, targetChanged = widgets.dropdown(
        imgui,
        "Target##room" .. context.roomIndex .. "_door" .. context.doorIndex,
        door.targetRoomKey,
        targetOptions
    )
    if targetChanged then
        state.setDoorTarget(context.roomIndex, context.doorIndex, nextTarget)
    end

    rewardOffer.drawGeneratedDoor(state, imgui, evaluation, context, door)
    widgets.feedback(imgui, "Route blocker", routeBlocker)
    if doorFeedback ~= routeBlocker then
        widgets.feedback(imgui, "Door feedback", doorFeedback)
    end
    widgets.unindent(imgui, doorIndent)
end

return generatedDoor
