local feedback = import("mods/ui/forms/feedback.lua")
local widgets = import("mods/ui/planner/widgets.lua")

local roomOffer = {}

local function offerAddress(state, context)
    return {
        routeKey = state.draft.routeKey,
        biomeIndex = context.biomeIndex,
        roomIndex = context.roomIndex,
        offerPointIndex = 1,
        offerIndex = 1,
    }
end

function roomOffer.draw(state, imgui, evaluation, context, room)
    local offer = state.ensureRoomOffer(room)
    local offerPoint = room.offerPoints[1]

    widgets.text(imgui, "Room offer 1 / " .. tostring(offerPoint.kind))
    local nextStore, storeChanged = widgets.dropdown(
        imgui,
        "Room store##room" .. context.roomIndex,
        offer.store,
        state.storeOptions
    )
    if storeChanged then
        state.setRoomOfferStore(context.roomIndex, nextStore)
        offer = state.ensureRoomOffer(room)
    end

    local offerProviders = offer.candidateProviders or {}
    local rewardOptions = offerProviders.rewardType or state.rewardTypeOptions[offer.store] or state.emptyOptions
    local nextRewardType, rewardChanged = widgets.dropdown(
        imgui,
        "Room reward##room" .. context.roomIndex,
        offer.rewardType,
        rewardOptions
    )
    if rewardChanged then
        state.setRoomOfferType(context.roomIndex, nextRewardType)
        offer = state.ensureRoomOffer(room)
    end

    widgets.feedback(imgui, "Room reward feedback", feedback.forAddress(evaluation, offerAddress(state, context)))

    local nextAcquired, acquiredChanged = widgets.checkbox(
        imgui,
        "Room acquired##room" .. context.roomIndex,
        offer.acquired == true
    )
    if acquiredChanged then
        state.setRoomOfferAcquired(context.roomIndex, nextAcquired)
    end
end

return roomOffer
