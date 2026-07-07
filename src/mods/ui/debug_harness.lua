local plannerState = import("mods/ui/planner/state.lua")
local widgets = import("mods/ui/planner/widgets.lua")

local debugHarness = {}

local TITLE = "Run Planner debug harness"
local HELP = "Minimal F route editor using the real form, history, validation, and feedback pipeline."

function debugHarness.defaultDraft()
    return plannerState.defaultDraft()
end

local function selectedDoorOptions(generatedDoors)
    local values = {}
    local labels = {}
    for index, _ in ipairs(generatedDoors.doors or {}) do
        values[index] = index
        labels[index] = "Door " .. tostring(index)
    end
    return {
        values = values,
        labels = labels,
    }
end

local function addressMatches(left, right)
    if left == nil or right == nil then
        return false
    end
    for key, value in pairs(left) do
        if right[key] ~= value then
            return false
        end
    end
    for key, value in pairs(right) do
        if left[key] ~= value then
            return false
        end
    end
    return true
end

local function feedbackFor(evaluation, address)
    for _, feedback in ipairs((evaluation and evaluation.feedback) or {}) do
        if addressMatches(feedback.address, address) then
            return feedback
        end
    end
    return nil
end

local function drawRewardPayload(state, imgui, roomIndex, doorIndex, offer)
    if offer.rewardType == "Boon" then
        offer.payload = offer.payload or state.defaultPayloadForRewardType("Boon")
        local nextSource, changed = widgets.dropdown(
            imgui,
            "Source##room" .. roomIndex .. "_door" .. doorIndex,
            offer.payload.source,
            state.boonSourceOptions
        )
        if changed then
            state.setBoonSource(roomIndex, doorIndex, nextSource)
        end
    elseif offer.rewardType == "Devotion" then
        offer.payload = offer.payload or state.defaultPayloadForRewardType("Devotion")
        offer.payload.sources = offer.payload.sources or state.defaultPayloadForRewardType("Devotion").sources
        for sourceIndex = 1, 2 do
            local providers = offer.candidateProviders or {}
            local providerKey = "devotionSource" .. tostring(sourceIndex)
            local options = providers[providerKey] or state.boonSourceOptions
            local nextSource, changed = widgets.dropdown(
                imgui,
                "Source " .. tostring(sourceIndex) .. "##room" .. roomIndex .. "_door" .. doorIndex,
                offer.payload.sources[sourceIndex],
                options
            )
            if changed then
                state.setDevotionSource(roomIndex, doorIndex, sourceIndex, nextSource)
            end
        end
    end
end

local function drawDoor(state, imgui, evaluation, roomIndex, doorIndex, door)
    widgets.text(imgui, "Door " .. tostring(doorIndex) .. " / exit " .. tostring(door.exitIndex))
    local providers = door.candidateProviders or {}
    local targetOptions = providers.nextDoorTarget or state.roomOptions
    local nextTarget, targetChanged = widgets.dropdown(imgui, "Target##room" .. roomIndex .. "_door" .. doorIndex, door.targetRoomKey, targetOptions)
    if targetChanged then
        state.setDoorTarget(roomIndex, doorIndex, nextTarget)
    end

    local offer = state.ensureOffer(door)
    local offerProviders = offer.candidateProviders or {}
    local nextStore, storeChanged = widgets.dropdown(imgui, "Store##room" .. roomIndex .. "_door" .. doorIndex, offer.store, state.storeOptions)
    if storeChanged then
        state.setRewardStore(roomIndex, doorIndex, nextStore)
        offer = state.ensureOffer(door)
        offerProviders = offer.candidateProviders or {}
    end

    local rewardOptions = offerProviders.rewardType or state.rewardTypeOptions[offer.store] or state.emptyOptions
    local nextRewardType, rewardChanged = widgets.dropdown(
        imgui,
        "Reward##room" .. roomIndex .. "_door" .. doorIndex,
        offer.rewardType,
        rewardOptions
    )
    if rewardChanged then
        state.setRewardType(roomIndex, doorIndex, nextRewardType)
        offer = state.ensureOffer(door)
    end

    drawRewardPayload(state, imgui, roomIndex, doorIndex, offer)
    widgets.feedback(imgui, "Reward feedback", feedbackFor(evaluation, {
        routeKey = state.draft.routeKey,
        biomeIndex = 1,
        roomIndex = roomIndex,
        doorIndex = doorIndex,
        offerIndex = 1,
    }))

    local nextAcquired, acquiredChanged = widgets.checkbox(imgui, "Acquired##room" .. roomIndex .. "_door" .. doorIndex, offer.acquired == true)
    if acquiredChanged then
        state.setRewardAcquired(roomIndex, doorIndex, nextAcquired)
    end

    widgets.feedback(imgui, "Door feedback", feedbackFor(evaluation, {
        routeKey = state.draft.routeKey,
        biomeIndex = 1,
        roomIndex = roomIndex,
        doorIndex = doorIndex,
    }))
end

local function drawRoomOffer(state, imgui, evaluation, roomIndex, room)
    local offer = state.ensureRoomOffer(room)
    local offerPoint = room.offerPoints[1]

    widgets.text(imgui, "Room offer 1 / " .. tostring(offerPoint.kind))
    local nextStore, storeChanged = widgets.dropdown(imgui, "Room store##room" .. roomIndex, offer.store, state.storeOptions)
    if storeChanged then
        state.setRoomOfferStore(roomIndex, nextStore)
        offer = state.ensureRoomOffer(room)
    end

    local offerProviders = offer.candidateProviders or {}
    local rewardOptions = offerProviders.rewardType or state.rewardTypeOptions[offer.store] or state.emptyOptions
    local nextRewardType, rewardChanged = widgets.dropdown(
        imgui,
        "Room reward##room" .. roomIndex,
        offer.rewardType,
        rewardOptions
    )
    if rewardChanged then
        state.setRoomOfferType(roomIndex, nextRewardType)
        offer = state.ensureRoomOffer(room)
    end

    widgets.feedback(imgui, "Room reward feedback", feedbackFor(evaluation, {
        routeKey = state.draft.routeKey,
        biomeIndex = 1,
        roomIndex = roomIndex,
        offerPointIndex = 1,
        offerIndex = 1,
    }))

    local nextAcquired, acquiredChanged = widgets.checkbox(imgui, "Room acquired##room" .. roomIndex, offer.acquired == true)
    if acquiredChanged then
        state.setRoomOfferAcquired(roomIndex, nextAcquired)
    end
end

local function drawRoom(state, imgui, evaluation, roomIndex, room)
    widgets.section(imgui, "Room " .. tostring(roomIndex))
    local nextRoomKey, roomChanged = widgets.dropdown(imgui, "Room##" .. tostring(roomIndex), room.roomKey, state.roomOptions)
    if roomChanged then
        state.setRoomKey(roomIndex, nextRoomKey)
    end

    widgets.feedback(imgui, "Room feedback", feedbackFor(evaluation, {
        routeKey = state.draft.routeKey,
        biomeIndex = 1,
        roomIndex = roomIndex,
    }))

    if room.offerPoints ~= nil then
        drawRoomOffer(state, imgui, evaluation, roomIndex, room)
    end

    local generatedDoors = room.generatedDoors
    if generatedDoors == nil then
        widgets.text(imgui, "Terminal/no generated doors")
        return
    end

    local nextSelectedDoor, selectedChanged = widgets.dropdown(
        imgui,
        "Selected door##" .. tostring(roomIndex),
        generatedDoors.selectedDoorIndex,
        selectedDoorOptions(generatedDoors)
    )
    if selectedChanged then
        state.setSelectedDoor(roomIndex, nextSelectedDoor)
    end

    for doorIndex, door in ipairs(generatedDoors.doors or {}) do
        drawDoor(state, imgui, evaluation, roomIndex, doorIndex, door)
    end
end

local function draw(state, ctx)
    local drawContext = ctx and ctx.draw or nil
    local imgui = drawContext and drawContext.imgui or nil

    widgets.text(imgui, TITLE)
    widgets.text(imgui, HELP)
    widgets.text(imgui, "Uses docs/system_design contracts; not the final planner UI.")

    if widgets.button(imgui, "Reset F sample") then
        state.resetDraft()
    end
    widgets.sameLine(imgui)
    if widgets.button(imgui, "Append selected target") then
        state.appendSelectedTarget()
    end
    widgets.sameLine(imgui)
    if widgets.button(imgui, "Remove last room") then
        state.removeLastRoom()
    end

    local evaluation = state.ensureEvaluation()
    widgets.separator(imgui)
    widgets.status(imgui, evaluation)

    for roomIndex, room in ipairs(state.currentBiome().rooms or {}) do
        drawRoom(state, imgui, evaluation, roomIndex, room)
    end

    if state.dirty then
        state.ensureEvaluation()
    end
end

function debugHarness.create(opts)
    local state = plannerState.create(opts)
    state.drawTab = function(_, ctx)
        return draw(state, ctx)
    end
    return state
end

return debugHarness
