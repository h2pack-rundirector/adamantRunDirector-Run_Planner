local feedback = import("mods/ui/forms/feedback.lua")
local payload = import("mods/ui/forms/payload/init.lua")
local widgets = import("mods/ui/planner/widgets.lua")

local rewardOffer = {}

local function offerAddress(state, context)
    return {
        routeKey = state.draft.routeKey,
        biomeIndex = context.biomeIndex,
        roomIndex = context.roomIndex,
        doorIndex = context.doorIndex,
        offerIndex = 1,
    }
end

function rewardOffer.drawGeneratedDoor(state, imgui, evaluation, context, door)
    local offer = state.ensureOffer(door)
    local address = offerAddress(state, context)
    local routeBlocker = feedback.firstIssueForAddress(evaluation, address)
    local offerFeedback = feedback.forAddress(evaluation, address)

    local offerProviders = offer.candidateProviders or {}
    local nextStore, storeChanged = widgets.dropdown(
        imgui,
        "Store##room" .. context.roomIndex .. "_door" .. context.doorIndex,
        offer.store,
        state.storeOptions
    )
    if storeChanged then
        state.setRewardStore(context.roomIndex, context.doorIndex, nextStore)
        offer = state.ensureOffer(door)
        offerProviders = offer.candidateProviders or {}
    end

    local rewardOptions = offerProviders.rewardType or state.rewardTypeOptions[offer.store] or state.emptyOptions
    local nextRewardType, rewardChanged = widgets.dropdown(
        imgui,
        "Reward##room" .. context.roomIndex .. "_door" .. context.doorIndex,
        offer.rewardType,
        rewardOptions
    )
    if rewardChanged then
        state.setRewardType(context.roomIndex, context.doorIndex, nextRewardType)
        offer = state.ensureOffer(door)
    end

    payload.draw(state, imgui, context, offer)
    widgets.feedback(imgui, "Route blocker", routeBlocker)
    if offerFeedback ~= routeBlocker then
        widgets.feedback(imgui, "Reward feedback", offerFeedback)
    end

    local nextAcquired, acquiredChanged = widgets.checkbox(
        imgui,
        "Acquired##room" .. context.roomIndex .. "_door" .. context.doorIndex,
        offer.acquired == true
    )
    if acquiredChanged then
        state.setRewardAcquired(context.roomIndex, context.doorIndex, nextAcquired)
    end
end

return rewardOffer
