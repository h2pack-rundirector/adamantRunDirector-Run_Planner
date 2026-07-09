local feedback = import("mods/ui/forms/feedback.lua")
local identity = import("mods/ui/forms/identity.lua")
local widgets = import("mods/ui/planner/widgets.lua")

local roomOffer = {}

function roomOffer.draw(state, imgui, evaluation, context, room)
    local form = identity.roomOffer(context, 1, 1)
    local offerPoint = room.offerPoints[1]
    local offer = offerPoint.offers[1]
    local address = identity.address(form)
    local routeBlocker = feedback.firstIssueForAddress(evaluation, address)
    local offerFeedback = feedback.forAddress(evaluation, address)

    widgets.subsection(imgui, "Room offer 1 / " .. tostring(offerPoint.kind))
    local offerIndent = widgets.indent(imgui)
    local nextStore, storeChanged = widgets.dropdown(
        imgui,
        identity.control(form, "Room store", "store"),
        offer.store,
        state.storeOptions
    )
    if storeChanged then
        state.setRoomOfferStore(context.roomIndex, nextStore)
        offer = room.offerPoints[1].offers[1]
    end

    local offerProviders = offer.candidateProviders or {}
    local rewardOptions = offerProviders.rewardType or state.rewardTypeOptions[offer.store] or state.emptyOptions
    local nextRewardType, rewardChanged = widgets.dropdown(
        imgui,
        identity.control(form, "Room reward", "rewardType"),
        offer.rewardType,
        rewardOptions
    )
    if rewardChanged then
        state.setRoomOfferType(context.roomIndex, nextRewardType)
        offer = room.offerPoints[1].offers[1]
    end

    widgets.feedback(imgui, "Route blocker", routeBlocker)
    if offerFeedback ~= routeBlocker then
        widgets.feedback(imgui, "Room reward feedback", offerFeedback)
    end

    local nextAcquired, acquiredChanged = widgets.checkbox(
        imgui,
        identity.control(form, "Room acquired", "acquired"),
        offer.acquired == true
    )
    if acquiredChanged then
        state.setRoomOfferAcquired(context.roomIndex, nextAcquired)
    end
    widgets.unindent(imgui, offerIndent)
end

return roomOffer
