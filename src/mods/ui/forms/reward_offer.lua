local feedback = import("mods/ui/forms/feedback.lua")
local identity = import("mods/ui/forms/identity.lua")
local payload = import("mods/ui/forms/payload/init.lua")
local widgets = import("mods/ui/planner/widgets.lua")

local rewardOffer = {}

function rewardOffer.drawGeneratedDoor(state, imgui, evaluation, context, door)
    local form = identity.generatedOffer(context, 1)
    local offer = state.ensureOffer(door)
    local address = identity.address(form)
    local routeBlocker = feedback.firstIssueForAddress(evaluation, address)
    local offerFeedback = feedback.forAddress(evaluation, address)

    widgets.subsection(imgui, "Generated reward offer")
    local offerIndent = widgets.indent(imgui)
    local offerProviders = offer.candidateProviders or {}
    local nextStore, storeChanged = widgets.dropdown(
        imgui,
        identity.control(form, "Store", "store"),
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
        identity.control(form, "Reward", "rewardType"),
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
        identity.control(form, "Acquired", "acquired"),
        offer.acquired == true
    )
    if acquiredChanged then
        state.setRewardAcquired(context.roomIndex, context.doorIndex, nextAcquired)
    end
    widgets.unindent(imgui, offerIndent)
end

return rewardOffer
