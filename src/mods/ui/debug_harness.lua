local plannerState = import("mods/ui/planner/state.lua")

local debugHarness = {}

local TITLE = "Run Planner debug harness"
local HELP = "Minimal F route editor using the real form, history, validation, and feedback pipeline."

function debugHarness.defaultDraft()
    return plannerState.defaultDraft()
end

local function pushText(imgui, text)
    if imgui ~= nil and imgui.Text ~= nil then
        imgui.Text(text)
    end
end

local function separator(imgui)
    if imgui ~= nil and imgui.Separator ~= nil then
        imgui.Separator()
    end
end

local function sameLine(imgui)
    if imgui ~= nil and imgui.SameLine ~= nil then
        imgui.SameLine()
    end
end

local function smallButton(imgui, label)
    if imgui == nil then
        return false
    end
    if imgui.SmallButton ~= nil then
        return imgui.SmallButton(label)
    end
    if imgui.Button ~= nil then
        return imgui.Button(label)
    end
    return false
end

local function valueIndex(options, value)
    for index, candidate in ipairs(options.values or {}) do
        if candidate == value then
            return index
        end
    end
    return nil
end

local function preview(options, value)
    local index = valueIndex(options, value)
    if index == nil then
        return tostring(value)
    end
    return options.labels[index]
end

local function drawChoice(imgui, label, value, options)
    if imgui == nil or imgui.BeginCombo == nil or imgui.Selectable == nil or imgui.EndCombo == nil then
        pushText(imgui, label .. ": " .. preview(options, value))
        return value, false
    end

    local nextValue = value
    local changed = false
    if imgui.BeginCombo(label, preview(options, value)) then
        for index, candidate in ipairs(options.values or {}) do
            if not (options.hidden and options.hidden[index]) and imgui.Selectable(options.labels[index], candidate == value) then
                nextValue = candidate
                changed = nextValue ~= value
            end
        end
        imgui.EndCombo()
    end
    return nextValue, changed
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

local function drawFeedback(imgui, label, feedback)
    if feedback ~= nil then
        pushText(imgui, label .. ": " .. feedback.code .. " - " .. tostring(feedback.message))
    end
end

local function drawRewardPayload(state, imgui, roomIndex, doorIndex, offer)
    if offer.rewardType == "Boon" then
        offer.payload = offer.payload or state.defaultPayloadForRewardType("Boon")
        local nextSource, changed = drawChoice(
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
            local nextSource, changed = drawChoice(
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

local function drawStatus(imgui, evaluation)
    pushText(imgui, "State: " .. tostring(evaluation.state))
    pushText(imgui, "Complete: " .. tostring(evaluation.complete) .. "  Valid: " .. tostring(evaluation.valid))
    pushText(imgui, "Feedback: " .. tostring(evaluation.status.feedbackCount)
        .. "  Candidates: " .. tostring(#(evaluation.candidateResults or {})))
    if evaluation.history ~= nil then
        pushText(imgui, "Events: " .. tostring(#evaluation.history.events)
            .. "  Doors: " .. tostring(#evaluation.history.generatedDoorHistory)
            .. "  Offers: " .. tostring(#evaluation.history.rewardOfferHistory))
    end
    if evaluation.status.firstIssue ~= nil then
        pushText(imgui, "First issue: " .. tostring(evaluation.status.firstIssue.code)
            .. " at " .. tostring(evaluation.status.firstIssue.phase))
    end
end

local function drawDoor(state, imgui, evaluation, roomIndex, doorIndex, door)
    pushText(imgui, "Door " .. tostring(doorIndex) .. " / exit " .. tostring(door.exitIndex))
    local providers = door.candidateProviders or {}
    local targetOptions = providers.nextDoorTarget or state.roomOptions
    local nextTarget, targetChanged = drawChoice(imgui, "Target##room" .. roomIndex .. "_door" .. doorIndex, door.targetRoomKey, targetOptions)
    if targetChanged then
        state.setDoorTarget(roomIndex, doorIndex, nextTarget)
    end

    local offer = state.ensureOffer(door)
    local offerProviders = offer.candidateProviders or {}
    local nextStore, storeChanged = drawChoice(imgui, "Store##room" .. roomIndex .. "_door" .. doorIndex, offer.store, state.storeOptions)
    if storeChanged then
        state.setRewardStore(roomIndex, doorIndex, nextStore)
        offer = state.ensureOffer(door)
        offerProviders = offer.candidateProviders or {}
    end

    local rewardOptions = offerProviders.rewardType or state.rewardTypeOptions[offer.store] or state.emptyOptions
    local nextRewardType, rewardChanged = drawChoice(
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
    drawFeedback(imgui, "Reward feedback", feedbackFor(evaluation, {
        routeKey = state.draft.routeKey,
        biomeIndex = 1,
        roomIndex = roomIndex,
        doorIndex = doorIndex,
        offerIndex = 1,
    }))

    if imgui ~= nil and imgui.Checkbox ~= nil then
        local nextAcquired, acquiredChanged = imgui.Checkbox("Acquired##room" .. roomIndex .. "_door" .. doorIndex, offer.acquired == true)
        if acquiredChanged then
            state.setRewardAcquired(roomIndex, doorIndex, nextAcquired)
        end
    else
        pushText(imgui, "Acquired: " .. tostring(offer.acquired == true))
    end

    drawFeedback(imgui, "Door feedback", feedbackFor(evaluation, {
        routeKey = state.draft.routeKey,
        biomeIndex = 1,
        roomIndex = roomIndex,
        doorIndex = doorIndex,
    }))
end

local function drawRoomOffer(state, imgui, evaluation, roomIndex, room)
    local offer = state.ensureRoomOffer(room)
    local offerPoint = room.offerPoints[1]

    pushText(imgui, "Room offer 1 / " .. tostring(offerPoint.kind))
    local nextStore, storeChanged = drawChoice(imgui, "Room store##room" .. roomIndex, offer.store, state.storeOptions)
    if storeChanged then
        state.setRoomOfferStore(roomIndex, nextStore)
        offer = state.ensureRoomOffer(room)
    end

    local offerProviders = offer.candidateProviders or {}
    local rewardOptions = offerProviders.rewardType or state.rewardTypeOptions[offer.store] or state.emptyOptions
    local nextRewardType, rewardChanged = drawChoice(
        imgui,
        "Room reward##room" .. roomIndex,
        offer.rewardType,
        rewardOptions
    )
    if rewardChanged then
        state.setRoomOfferType(roomIndex, nextRewardType)
        offer = state.ensureRoomOffer(room)
    end

    drawFeedback(imgui, "Room reward feedback", feedbackFor(evaluation, {
        routeKey = state.draft.routeKey,
        biomeIndex = 1,
        roomIndex = roomIndex,
        offerPointIndex = 1,
        offerIndex = 1,
    }))

    if imgui ~= nil and imgui.Checkbox ~= nil then
        local nextAcquired, acquiredChanged = imgui.Checkbox("Room acquired##room" .. roomIndex, offer.acquired == true)
        if acquiredChanged then
            state.setRoomOfferAcquired(roomIndex, nextAcquired)
        end
    else
        pushText(imgui, "Room acquired: " .. tostring(offer.acquired == true))
    end
end

local function drawRoom(state, imgui, evaluation, roomIndex, room)
    separator(imgui)
    pushText(imgui, "Room " .. tostring(roomIndex))
    local nextRoomKey, roomChanged = drawChoice(imgui, "Room##" .. tostring(roomIndex), room.roomKey, state.roomOptions)
    if roomChanged then
        state.setRoomKey(roomIndex, nextRoomKey)
    end

    drawFeedback(imgui, "Room feedback", feedbackFor(evaluation, {
        routeKey = state.draft.routeKey,
        biomeIndex = 1,
        roomIndex = roomIndex,
    }))

    if room.offerPoints ~= nil then
        drawRoomOffer(state, imgui, evaluation, roomIndex, room)
    end

    local generatedDoors = room.generatedDoors
    if generatedDoors == nil then
        pushText(imgui, "Terminal/no generated doors")
        return
    end

    local nextSelectedDoor, selectedChanged = drawChoice(
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

    pushText(imgui, TITLE)
    pushText(imgui, HELP)
    pushText(imgui, "Uses docs/system_design contracts; not the final planner UI.")

    if smallButton(imgui, "Reset F sample") then
        state.resetDraft()
    end
    sameLine(imgui)
    if smallButton(imgui, "Append selected target") then
        state.appendSelectedTarget()
    end
    sameLine(imgui)
    if smallButton(imgui, "Remove last room") then
        state.removeLastRoom()
    end

    local evaluation = state.ensureEvaluation()
    separator(imgui)
    drawStatus(imgui, evaluation)

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
