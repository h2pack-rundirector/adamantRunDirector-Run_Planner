local candidateProviderModule = import("mods/forms/candidate_provider.lua")
local dataModule = import("mods/data.lua")
local defaultDrafts = import("mods/forms/defaults.lua")
local routePipeline = import("mods/pipeline/route.lua")
local participantRegistry = import("mods/ui/forms/participants.lua")
local evaluationCache = import("mods/ui/planner/evaluation.lua")
local materialization = import("mods/ui/planner/materialization.lua")
local plannerOptions = import("mods/ui/planner/options.lua")
local persistence = import("mods/ui/planner/persistence.lua")
local viewHelpers = import("mods/ui/planner/view_helpers.lua")

local plannerState = {}

local function ensureOffer(state, door)
    return materialization.ensureGeneratedDoorOffer(state.catalog, door)
end

local function ensureRoomOffer(state, room)
    return materialization.ensureRoomOffer(state.catalog, state.currentBiome(), room)
end

local function defaultPayloadForRewardType(state, rewardType)
    return materialization.defaultPayloadForRewardType(state.catalog, rewardType)
end

function plannerState.defaultDraft()
    return defaultDrafts.fSampleDraft()
end

local function markDirty(state)
    state.providerVersion = state.providerVersion + 1
    state.dirty = true
end

local function resetDerivedDraftState(state)
    state.selectedDoorOptionCache = viewHelpers.selectedDoorOptionCache()
    state.participants:clear()
end

local function draftChanged(state)
    persistence.draftChanged(state)
end

local function bindDraftControl(state, control)
    return persistence.bindDraftControl(state, control, resetDerivedDraftState)
end

local function bindUiContext(state, ctx)
    return persistence.bindUiContext(state, ctx, resetDerivedDraftState)
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
    resetDerivedDraftState(state)
    draftChanged(state)
end

function plannerState.create(opts)
    opts = opts or {}
    local catalog = opts.catalog or opts.data and opts.data.loadCatalog() or dataModule.loadCatalog()
    local state = {
        catalog = catalog,
        pipeline = opts.pipeline or routePipeline,
        candidateProvider = opts.candidateProvider or candidateProviderModule,
        participants = opts.participants or participantRegistry.create(),
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
        selectedDoorOptionCache = viewHelpers.selectedDoorOptionCache(),
    }

    function state.currentBiome()
        return state.draft.biomes[1]
    end
    function state.selectedDoorOptions(generatedDoors)
        return viewHelpers.selectedDoorOptions(state, generatedDoors)
    end
    function state.feedbackLocationLabel(address)
        return viewHelpers.feedbackLocationLabel(state, address)
    end
    function state.evaluate()
        return evaluationCache.evaluate(state)
    end
    function state.ensureEvaluation()
        return evaluationCache.ensure(state)
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
