local candidateProviderModule = import("mods/forms/candidate_provider.lua")
local dataModule = import("mods/data.lua")
local defaultDrafts = import("mods/forms/defaults.lua")
local routePipeline = import("mods/pipeline/route.lua")
local plannerOptions = import("mods/ui/planner/options.lua")

local plannerState = {}

local function selectedDoorOptionCache()
    return setmetatable({}, {
        __mode = "k",
    })
end

function plannerState.defaultDraft()
    return defaultDrafts.fSampleDraft()
end

local function projectedSources(sources, sourceIndex, value)
    local projected = {}
    for index, source in ipairs(sources or {}) do
        projected[index] = source
    end
    projected[sourceIndex] = value
    return projected
end

local function defaultPayloadForRewardType(state, rewardType)
    return plannerOptions.defaultPayloadForRewardType(state.catalog, rewardType)
end

local function ensureOffer(state, door)
    door.offerPoint = door.offerPoint or plannerOptions.defaultGeneratedDoorOfferPoint(state.catalog)
    door.offerPoint.kind = door.offerPoint.kind or "generatedDoorRewards"
    door.offerPoint.batchKey = door.offerPoint.batchKey or "nextDoors"
    door.offerPoint.offers = door.offerPoint.offers or { plannerOptions.defaultOffer(state.catalog, "RunProgress") }
    door.offerPoint.offers[1] = door.offerPoint.offers[1] or plannerOptions.defaultOffer(state.catalog, "RunProgress")
    return door.offerPoint.offers[1]
end

local function ensureRoomOffer(state, room)
    local biome = state.currentBiome()
    room.offerPoints = plannerOptions.materializedRoomOfferPoints(state.catalog, biome.biomeKey, room.roomKey, room.offerPoints)
    local roomDeclaration = plannerOptions.roomDeclaration(state.catalog, biome.biomeKey, room.roomKey)
    room.offerPoints = room.offerPoints or { plannerOptions.defaultRoomOfferPoint(state.catalog, roomDeclaration or { key = room.roomKey }) }
    room.offerPoints[1] = room.offerPoints[1] or plannerOptions.defaultRoomOfferPoint(state.catalog, roomDeclaration or { key = room.roomKey })
    room.offerPoints[1].offers = room.offerPoints[1].offers or { plannerOptions.defaultOffer(state.catalog, "WorldShop") }
    room.offerPoints[1].offers[1] = room.offerPoints[1].offers[1] or plannerOptions.defaultOffer(state.catalog, "WorldShop")
    return room.offerPoints[1].offers[1]
end

local function rewardTypeOptionsFor(state, storeKey)
    return state.rewardTypeOptions[storeKey] or plannerOptions.empty()
end

local function selectedDoorOptionsFor(state, generatedDoors)
    if generatedDoors == nil then
        return state.emptyOptions
    end

    local doors = generatedDoors.doors or state.emptyOptions.values
    local doorCount = #doors
    local cached = state.selectedDoorOptionCache[generatedDoors]
    if cached ~= nil and cached.doorCount == doorCount then
        return cached.options
    end

    local values = {}
    local labels = {}
    for index = 1, doorCount do
        values[index] = index
        labels[index] = "Door " .. tostring(index)
    end

    local optionSet = {
        values = values,
        labels = labels,
    }
    state.selectedDoorOptionCache[generatedDoors] = {
        doorCount = doorCount,
        options = optionSet,
    }
    return optionSet
end

local function roomAt(state, roomIndex)
    local biome = state.currentBiome()
    return biome and biome.rooms and biome.rooms[roomIndex] or nil
end

local function roomLocationLabel(state, roomIndex)
    local label = "Room " .. tostring(roomIndex)
    local room = roomAt(state, roomIndex)
    if room ~= nil and room.roomKey ~= nil then
        label = label .. " (" .. tostring(room.roomKey) .. ")"
    end
    return label
end

local function feedbackLocationLabel(state, address)
    if address == nil then
        return nil
    end

    local parts = {}
    if address.roomIndex ~= nil then
        parts[#parts + 1] = roomLocationLabel(state, address.roomIndex)
    elseif address.biomeIndex ~= nil then
        parts[#parts + 1] = "Biome " .. tostring(address.biomeIndex)
    elseif address.routeKey ~= nil then
        parts[#parts + 1] = "Route " .. tostring(address.routeKey)
    end

    if address.doorIndex ~= nil then
        parts[#parts + 1] = "door " .. tostring(address.doorIndex)
    end
    if address.offerPointIndex ~= nil then
        parts[#parts + 1] = "offer point " .. tostring(address.offerPointIndex)
    end
    if address.offerIndex ~= nil then
        local offerLabel = address.doorIndex ~= nil and "reward " or "offer "
        parts[#parts + 1] = offerLabel .. tostring(address.offerIndex)
    end

    if #parts == 0 then
        return nil
    end
    return table.concat(parts, " ")
end

local function attachRewardProvider(state, offer)
    local rewardOptions = rewardTypeOptionsFor(state, offer.store)
    offer.candidateProviders = {
        rewardType = state.candidateProvider.create({
            key = "rewardType",
            version = state.providerVersion,
            values = rewardOptions.values,
            labels = rewardOptions.labels,
            semanticForValue = function(value, _, _, context)
                return {
                    kind = "rewardType",
                    store = context.candidate.store,
                    rewardType = value,
                    payload = defaultPayloadForRewardType(state, value),
                }
            end,
        }),
    }
end

local function attachDevotionSourceProviders(state, offer)
    if offer.rewardType ~= "Devotion" then
        return
    end

    offer.payload = offer.payload or defaultPayloadForRewardType(state, "Devotion")
    offer.payload.sources = offer.payload.sources or defaultPayloadForRewardType(state, "Devotion").sources
    for sourceIndex = 1, 2 do
        local slotIndex = sourceIndex
        local providerKey = "devotionSource" .. tostring(sourceIndex)
        offer.candidateProviders[providerKey] = state.candidateProvider.create({
            key = providerKey,
            version = state.providerVersion,
            values = state.boonSourceOptions.values,
            labels = state.boonSourceOptions.labels,
            semanticForValue = function(value, _, _, _context)
                return {
                    kind = "devotionSource",
                    sourceIndex = slotIndex,
                    source = value,
                    sources = projectedSources(offer.payload.sources, slotIndex, value),
                }
            end,
        })
    end
end

local function attachCandidateProviders(state)
    local biome = state.currentBiome()
    for _, room in ipairs((biome and biome.rooms) or {}) do
        for _, offerPoint in ipairs(room.offerPoints or {}) do
            for _, offer in ipairs(offerPoint.offers or {}) do
                attachRewardProvider(state, offer)
            end
        end

        local generatedDoors = room.generatedDoors
        if generatedDoors ~= nil then
            for _, door in ipairs(generatedDoors.doors or {}) do
                door.candidateProviders = {
                    nextDoorTarget = state.candidateProvider.create({
                        key = "nextDoorTarget",
                        version = state.providerVersion,
                        values = state.roomOptions.values,
                        labels = state.roomOptions.labels,
                        semanticForValue = function(value, _, _, context)
                            return {
                                kind = "nextRoom",
                                biomeKey = context.candidate.biomeKey,
                                sourceRoomKey = context.candidate.sourceRoomKey,
                                exitIndex = context.candidate.exitIndex,
                                targetRoomKey = value,
                            }
                        end,
                    }),
                }

                local offer = ensureOffer(state, door)
                attachRewardProvider(state, offer)
                attachDevotionSourceProviders(state, offer)
            end
        end
    end
end

local function evaluate(state)
    attachCandidateProviders(state)
    state.evaluation = state.pipeline.evaluate(state.draft, {
        catalog = state.catalog,
    })
    state.pipeline.applyCandidateFeedback(state.draft, state.evaluation)
    state.dirty = false
    return state.evaluation
end

local function markDirty(state)
    state.providerVersion = state.providerVersion + 1
    state.dirty = true
end

local function persistDraft(state)
    local control = state.draftControl
    if control ~= nil then
        local changed = control:writeDraft(plannerOptions.deepCopy(state.draft))
        if control.revision ~= nil then
            state.draftControlRevision = control:revision()
        end
        return changed
    end
    return false
end

local function draftChanged(state)
    markDirty(state)
    persistDraft(state)
end

local function controlRevision(control)
    if control.revision == nil then
        return nil
    end
    return control:revision()
end

local function loadDraftFromControl(state, control, revision)
    state.draftControl = control
    state.draftControlRevision = revision
    state.draft = plannerOptions.deepCopy(control:readDraft())
    state.selectedDoorOptionCache = selectedDoorOptionCache()
    markDirty(state)
    return true
end

local function bindDraftControl(state, control)
    if control == nil then
        return false
    end
    if type(control.readDraft) ~= "function" or type(control.writeDraft) ~= "function" then
        error("PlannerDraft control must expose readDraft() and writeDraft()")
    end
    if control.revision ~= nil and type(control.revision) ~= "function" then
        error("PlannerDraft control revision must be a function when provided")
    end

    local revision = controlRevision(control)
    if control == state.draftControl then
        if revision ~= nil and revision ~= state.draftControlRevision then
            return loadDraftFromControl(state, control, revision)
        end
        return false
    end

    return loadDraftFromControl(state, control, revision)
end

local function bindUiContext(state, ctx)
    return bindDraftControl(state, ctx.controls.get(state.draftControlName))
end

local function setRoomKey(state, roomIndex, roomKey)
    local biome = state.currentBiome()
    local room = biome.rooms[roomIndex]
    if room == nil or room.roomKey == roomKey then
        return false
    end
    room.roomKey = roomKey
    room.offerPoints = plannerOptions.materializedRoomOfferPoints(state.catalog, biome.biomeKey, roomKey, room.offerPoints)
    room.generatedDoors = plannerOptions.materializedGeneratedDoors(state.catalog, biome.biomeKey, roomKey, room.generatedDoors)
    draftChanged(state)
    return true
end

local function setDoorTarget(state, roomIndex, doorIndex, targetRoomKey)
    local door = state.currentBiome().rooms[roomIndex].generatedDoors.doors[doorIndex]
    if door.targetRoomKey == targetRoomKey then
        return false
    end
    door.targetRoomKey = targetRoomKey
    draftChanged(state)
    return true
end

local function setRewardStore(state, roomIndex, doorIndex, storeKey)
    local offer = ensureOffer(state, state.currentBiome().rooms[roomIndex].generatedDoors.doors[doorIndex])
    if offer.store == storeKey then
        return false
    end
    offer.store = storeKey
    offer.rewardType = plannerOptions.first(plannerOptions.rewardTypesForStore(state.catalog, storeKey), offer.rewardType)
    offer.payload = defaultPayloadForRewardType(state, offer.rewardType)
    draftChanged(state)
    return true
end

local function setRewardType(state, roomIndex, doorIndex, rewardType)
    local offer = ensureOffer(state, state.currentBiome().rooms[roomIndex].generatedDoors.doors[doorIndex])
    if offer.rewardType == rewardType then
        return false
    end
    offer.rewardType = rewardType
    offer.payload = defaultPayloadForRewardType(state, rewardType)
    draftChanged(state)
    return true
end

local function setBoonSource(state, roomIndex, doorIndex, source)
    local offer = ensureOffer(state, state.currentBiome().rooms[roomIndex].generatedDoors.doors[doorIndex])
    offer.payload = offer.payload or {}
    if offer.payload.source == source then
        return false
    end
    offer.payload.source = source
    draftChanged(state)
    return true
end

local function setDevotionSource(state, roomIndex, doorIndex, sourceIndex, source)
    local offer = ensureOffer(state, state.currentBiome().rooms[roomIndex].generatedDoors.doors[doorIndex])
    offer.payload = offer.payload or defaultPayloadForRewardType(state, "Devotion")
    offer.payload.sources = offer.payload.sources or {}
    if offer.payload.sources[sourceIndex] == source then
        return false
    end
    offer.payload.sources[sourceIndex] = source
    draftChanged(state)
    return true
end

local function setRewardAcquired(state, roomIndex, doorIndex, acquired)
    local offer = ensureOffer(state, state.currentBiome().rooms[roomIndex].generatedDoors.doors[doorIndex])
    if offer.acquired == acquired then
        return false
    end
    offer.acquired = acquired
    draftChanged(state)
    return true
end

local function setRoomOfferStore(state, roomIndex, storeKey)
    local offer = ensureRoomOffer(state, state.currentBiome().rooms[roomIndex])
    if offer.store == storeKey then
        return false
    end
    offer.store = storeKey
    offer.rewardType = plannerOptions.first(plannerOptions.rewardTypesForStore(state.catalog, storeKey), offer.rewardType)
    offer.payload = defaultPayloadForRewardType(state, offer.rewardType)
    draftChanged(state)
    return true
end

local function setRoomOfferType(state, roomIndex, rewardType)
    local offer = ensureRoomOffer(state, state.currentBiome().rooms[roomIndex])
    if offer.rewardType == rewardType then
        return false
    end
    offer.rewardType = rewardType
    offer.payload = defaultPayloadForRewardType(state, rewardType)
    draftChanged(state)
    return true
end

local function setRoomOfferAcquired(state, roomIndex, acquired)
    local offer = ensureRoomOffer(state, state.currentBiome().rooms[roomIndex])
    if offer.acquired == acquired then
        return false
    end
    offer.acquired = acquired
    draftChanged(state)
    return true
end

local function setSelectedDoor(state, roomIndex, selectedDoorIndex)
    local generatedDoors = state.currentBiome().rooms[roomIndex].generatedDoors
    if generatedDoors.selectedDoorIndex == selectedDoorIndex then
        return false
    end
    generatedDoors.selectedDoorIndex = selectedDoorIndex
    draftChanged(state)
    return true
end

local function appendSelectedTarget(state)
    local biome = state.currentBiome()
    local lastRoom = biome.rooms[#biome.rooms]
    if lastRoom == nil or lastRoom.generatedDoors == nil then
        return false
    end

    local selectedDoor = lastRoom.generatedDoors.doors[lastRoom.generatedDoors.selectedDoorIndex or 1]
    if selectedDoor == nil then
        return false
    end

    local room = {
        roomKey = selectedDoor.targetRoomKey,
    }
    room.offerPoints = plannerOptions.materializedRoomOfferPoints(state.catalog, biome.biomeKey, room.roomKey, nil)
    room.generatedDoors = plannerOptions.materializedGeneratedDoors(state.catalog, biome.biomeKey, room.roomKey, nil)
    biome.rooms[#biome.rooms + 1] = room
    draftChanged(state)
    return true
end

local function removeLastRoom(state)
    local rooms = state.currentBiome().rooms
    if #rooms <= 1 then
        return false
    end
    rooms[#rooms] = nil
    draftChanged(state)
    return true
end

local function resetDraft(state)
    state.draft = plannerState.defaultDraft()
    state.selectedDoorOptionCache = selectedDoorOptionCache()
    draftChanged(state)
end

function plannerState.create(opts)
    opts = opts or {}
    local catalog = opts.catalog or opts.data and opts.data.loadCatalog() or dataModule.loadCatalog()
    local state = {
        catalog = catalog,
        pipeline = opts.pipeline or routePipeline,
        candidateProvider = opts.candidateProvider or candidateProviderModule,
        draft = plannerOptions.deepCopy(opts.draft or plannerState.defaultDraft()),
        dirty = true,
        evaluation = nil,
        providerVersion = 1,
        draftControlName = opts.draftControlName or dataModule.PLANNER_DRAFT_CONTROL,
        roomOptions = plannerOptions.roomOptions(catalog, "F"),
        storeOptions = plannerOptions.storeOptions(catalog),
        rewardTypeOptions = plannerOptions.rewardTypeOptions(catalog),
        boonSourceOptions = plannerOptions.sourceOptions(catalog, "boon"),
        emptyOptions = plannerOptions.empty(),
        selectedDoorOptionCache = selectedDoorOptionCache(),
    }

    function state.currentBiome()
        return state.draft.biomes[1]
    end
    function state.defaultPayloadForRewardType(rewardType)
        return defaultPayloadForRewardType(state, rewardType)
    end
    function state.ensureOffer(door)
        return ensureOffer(state, door)
    end
    function state.ensureRoomOffer(room)
        return ensureRoomOffer(state, room)
    end
    function state.selectedDoorOptions(generatedDoors)
        return selectedDoorOptionsFor(state, generatedDoors)
    end
    function state.feedbackLocationLabel(address)
        return feedbackLocationLabel(state, address)
    end
    function state.evaluate()
        return evaluate(state)
    end
    function state.ensureEvaluation()
        if state.dirty or state.evaluation == nil then
            return evaluate(state)
        end
        return state.evaluation
    end
    function state.markDirty()
        return markDirty(state)
    end
    function state.bindDraftControl(control)
        return bindDraftControl(state, control)
    end
    function state.bindUiContext(ctx)
        return bindUiContext(state, ctx)
    end
    function state.resetDraft()
        return resetDraft(state)
    end
    function state.appendSelectedTarget()
        return appendSelectedTarget(state)
    end
    function state.removeLastRoom()
        return removeLastRoom(state)
    end
    function state.setRoomKey(roomIndex, roomKey)
        return setRoomKey(state, roomIndex, roomKey)
    end
    function state.setDoorTarget(roomIndex, doorIndex, targetRoomKey)
        return setDoorTarget(state, roomIndex, doorIndex, targetRoomKey)
    end
    function state.setRewardStore(roomIndex, doorIndex, storeKey)
        return setRewardStore(state, roomIndex, doorIndex, storeKey)
    end
    function state.setRewardType(roomIndex, doorIndex, rewardType)
        return setRewardType(state, roomIndex, doorIndex, rewardType)
    end
    function state.setRewardAcquired(roomIndex, doorIndex, acquired)
        return setRewardAcquired(state, roomIndex, doorIndex, acquired)
    end
    function state.setBoonSource(roomIndex, doorIndex, source)
        return setBoonSource(state, roomIndex, doorIndex, source)
    end
    function state.setDevotionSource(roomIndex, doorIndex, sourceIndex, source)
        return setDevotionSource(state, roomIndex, doorIndex, sourceIndex, source)
    end
    function state.setRoomOfferStore(roomIndex, storeKey)
        return setRoomOfferStore(state, roomIndex, storeKey)
    end
    function state.setRoomOfferType(roomIndex, rewardType)
        return setRoomOfferType(state, roomIndex, rewardType)
    end
    function state.setRoomOfferAcquired(roomIndex, acquired)
        return setRoomOfferAcquired(state, roomIndex, acquired)
    end
    function state.setSelectedDoor(roomIndex, selectedDoorIndex)
        return setSelectedDoor(state, roomIndex, selectedDoorIndex)
    end

    if opts.draftControl ~= nil then
        bindDraftControl(state, opts.draftControl)
    end

    return state
end

return plannerState
