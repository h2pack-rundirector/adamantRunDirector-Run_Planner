local feedback = import("mods/ui/forms/feedback.lua")
local feedbackPresentation = import("mods/ui/forms/feedback_presentation.lua")
local identity = import("mods/ui/forms/identity.lua")
local payload = import("mods/ui/forms/payload/init.lua")
local widgets = import("mods/ui/planner/widgets.lua")

local rewardOffer = {}

function rewardOffer.drawGeneratedDoor(state, imgui, evaluation, context, door)
    local form = identity.generatedOffer(context, 1)
    local offer = door.offerPoint.offers[1]
    local address = identity.address(form)
    local routeBlocker = feedback.firstRouteBlockerForAddress(evaluation, address)
    local offerFeedback = feedback.forAddress(evaluation, address)

    widgets.subsection(imgui, "Generated reward offer")
    local offerIndent = widgets.indent(imgui)
    local participant = state.participants:find(form)
    local offerProviders = participant and participant.providers or {}
    local nextStore, storeChanged = widgets.dropdown(
        imgui,
        identity.control(form, "Store", "store"),
        offer.store,
        state.storeOptions
    )
    if storeChanged then
        state.setRewardStore(context.roomIndex, context.doorIndex, nextStore)
        offer = door.offerPoint.offers[1]
        offerProviders = {}
    end

    local rewardOptions = offerProviders.rewardType or state.rewardTypeOptions[offer.store] or state.emptyOptions
    local nextRewardType, rewardChanged = widgets.dropdown(
        imgui,
        identity.control(form, "Reward", "rewardType"),
        offer.rewardType,
        rewardOptions
    )
    if rewardChanged then
        state.setRewardType(context.roomIndex, context.doorIndex, nextRewardType)
        offer = door.offerPoint.offers[1]
    end

    payload.draw(state, imgui, context, offer)
    feedbackPresentation.draw(imgui, "Route blocker", routeBlocker, { role = "blocker" })
    if offerFeedback ~= routeBlocker then
        feedbackPresentation.draw(imgui, "Reward feedback", offerFeedback)
    end

    local nextAcquired, acquiredChanged = widgets.checkbox(
        imgui,
        identity.control(form, "Acquired", "acquired"),
        offer.acquired == true
    )
    if acquiredChanged then
        state.setRewardAcquired(context.roomIndex, context.doorIndex, nextAcquired)
    end
    widgets.unindent(imgui, offerIndent)
end

return rewardOffer
