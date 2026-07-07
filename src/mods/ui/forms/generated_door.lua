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
    widgets.text(imgui, "Door " .. tostring(context.doorIndex) .. " / exit " .. tostring(door.exitIndex))
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
    widgets.feedback(imgui, "Door feedback", feedback.forAddress(evaluation, doorAddress(state, context)))
end

return generatedDoor
