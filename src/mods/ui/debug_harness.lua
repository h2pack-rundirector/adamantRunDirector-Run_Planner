local candidateProviderModule = import("mods/forms/candidate_provider.lua")
local dataModule = import("mods/data.lua")
local routePipeline = import("mods/pipeline/route.lua")

local debugHarness = {}

local TITLE = "Run Planner debug harness"
local HELP = "Minimal F route editor using the real form, history, validation, and feedback pipeline."

local function deepCopy(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}
    for key, child in pairs(value) do
        copy[key] = deepCopy(child)
    end
    return copy
end

local function sortedKeys(map)
    local keys = {}
    for key, _ in pairs(map or {}) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    return keys
end

local function first(values, fallback)
    return values[1] or fallback
end

local function packageOptions(values, labelFor)
    local labels = {}
    for index, value in ipairs(values) do
        labels[index] = labelFor(value)
    end
    return {
        values = values,
        labels = labels,
    }
end

local function labelForRoom(catalog, biomeKey, roomKey)
    local biome = catalog.biomes.lookup[biomeKey]
    local room = biome and biome.rooms.lookup[roomKey] or nil
    if room == nil then
        return roomKey
    end
    return room.label .. " (" .. room.key .. ")"
end

local function buildRoomOptions(catalog, biomeKey)
    local biome = catalog.biomes.lookup[biomeKey]
    local values = {}
    for _, room in ipairs((biome and biome.rooms.ordered) or {}) do
        values[#values + 1] = room.key
    end
    return packageOptions(values, function(roomKey)
        return labelForRoom(catalog, biomeKey, roomKey)
    end)
end

local function rewardTypesForStore(catalog, storeKey)
    local store = catalog.rewards.stores[storeKey]
    if store ~= nil then
        return store.options or {}
    end

    local shop = catalog.rewards.shops[storeKey]
    local values = {}
    local seen = {}
    for _, slot in ipairs((shop and shop.slots) or {}) do
        for _, option in ipairs(slot.options or {}) do
            if not seen[option.rewardType] then
                seen[option.rewardType] = true
                values[#values + 1] = option.rewardType
            end
        end
    end
    return values
end

local function buildStoreOptions(catalog)
    local values = sortedKeys(catalog.rewards.stores)
    for _, shopKey in ipairs(sortedKeys(catalog.rewards.shops)) do
        values[#values + 1] = shopKey
    end
    return packageOptions(values, function(value)
        return value
    end)
end

local function buildRewardTypeOptions(catalog)
    local byStore = {}
    for _, storeKey in ipairs(buildStoreOptions(catalog).values) do
        byStore[storeKey] = packageOptions(rewardTypesForStore(catalog, storeKey), function(value)
            return value
        end)
    end
    return byStore
end

local function buildSourceOptions(catalog, sourceSetKey)
    local sourceSet = catalog.rewards.sources[sourceSetKey]
    local values = {}
    local labels = {}
    for index, source in ipairs((sourceSet and sourceSet.ordered) or {}) do
        values[index] = source.key
        labels[index] = source.label .. " (" .. source.key .. ")"
    end
    return {
        values = values,
        labels = labels,
    }
end

local function sourceKey(catalog, sourceSetKey, index)
    local sourceSet = catalog.rewards.sources[sourceSetKey]
    local source = sourceSet and sourceSet.ordered and sourceSet.ordered[index] or nil
    return source and source.key or nil
end

local function defaultPayloadForRewardType(catalog, rewardType)
    if rewardType == "Boon" then
        return {
            source = sourceKey(catalog, "boon", 1),
        }
    elseif rewardType == "Devotion" then
        return {
            sources = {
                sourceKey(catalog, "boon", 1),
                sourceKey(catalog, "boon", 2),
            },
        }
    end
    return {}
end

local function defaultOffer(catalog, storeKey)
    storeKey = storeKey or "RunProgress"
    local rewardType = first(rewardTypesForStore(catalog, storeKey), "Boon")
    return {
        store = storeKey,
        rewardType = rewardType,
        acquired = false,
        payload = defaultPayloadForRewardType(catalog, rewardType),
    }
end

local function defaultOfferPoint(catalog)
    return {
        kind = "generatedDoorRewards",
        batchKey = "nextDoors",
        offers = {
            defaultOffer(catalog, "RunProgress"),
        },
    }
end

local function offerProfile(catalog, profileKey)
    return catalog.offerProfiles and catalog.offerProfiles[profileKey] or nil
end

local function shopStoreForProfile(catalog, profileKey)
    local profile = offerProfile(catalog, profileKey)
    if profile == nil then
        return nil
    end
    if profile.kind == "shop" then
        return profile.shopKey
    end
    if profile.kind == "branch" then
        for _, branch in ipairs(profile.branches or {}) do
            if branch.offerProfile ~= nil then
                local storeKey = shopStoreForProfile(catalog, branch.offerProfile)
                if storeKey ~= nil then
                    return storeKey
                end
            end
        end
    end
    return nil
end

local function defaultRoomOfferPoint(catalog, room)
    local storeKey = shopStoreForProfile(catalog, room.offerProfile) or "WorldShop"
    local kind = room.kind == "Preboss" and "prebossRewards" or "shop"
    return {
        kind = kind,
        batchKey = room.key .. "_roomOffers",
        offers = {
            defaultOffer(catalog, storeKey),
        },
    }
end

local function roomDeclaration(catalog, biomeKey, roomKey)
    local biome = catalog.biomes.lookup[biomeKey]
    return biome and biome.rooms.lookup[roomKey] or nil
end

local function materializedGeneratedDoors(catalog, biomeKey, roomKey, existing)
    local room = roomDeclaration(catalog, biomeKey, roomKey)
    if room == nil or room.terminal then
        return nil
    end

    local generatedDoors = {
        batchRule = (existing and existing.batchRule) or "Standard",
        selectedDoorIndex = (existing and existing.selectedDoorIndex) or 1,
        doors = {},
    }

    for index, exit in ipairs(room.exits or {}) do
        local existingDoor = existing and existing.doors and existing.doors[index] or nil
        generatedDoors.doors[index] = {
            exitIndex = exit.exitIndex or index,
            targetRoomKey = (existingDoor and existingDoor.targetRoomKey) or "F_Combat01",
            offerPoint = deepCopy((existingDoor and existingDoor.offerPoint) or defaultOfferPoint(catalog)),
        }
    end

    if generatedDoors.doors[generatedDoors.selectedDoorIndex] == nil then
        generatedDoors.selectedDoorIndex = 1
    end

    return generatedDoors
end

local function materializedRoomOfferPoints(catalog, biomeKey, roomKey, existing)
    local room = roomDeclaration(catalog, biomeKey, roomKey)
    if room == nil or (room.kind ~= "Shop" and room.kind ~= "Preboss") then
        return nil
    end
    return deepCopy(existing or { defaultRoomOfferPoint(catalog, room) })
end

function debugHarness.defaultDraft()
    return {
        routeKey = "Underworld",
        biomes = {
            {
                biomeKey = "F",
                rooms = {
                    {
                        roomKey = "F_Opening01",
                        generatedDoors = {
                            batchRule = "Standard",
                            selectedDoorIndex = 1,
                            doors = {
                                {
                                    exitIndex = 1,
                                    targetRoomKey = "F_Combat01",
                                    offerPoint = {
                                        kind = "generatedDoorRewards",
                                        batchKey = "nextDoors",
                                        offers = {
                                            {
                                                store = "RunProgress",
                                                rewardType = "Boon",
                                                acquired = true,
                                                payload = {
                                                    source = "AphroditeUpgrade",
                                                },
                                            },
                                        },
                                    },
                                },
                            },
                        },
                    },
                    {
                        roomKey = "F_Combat01",
                        generatedDoors = {
                            batchRule = "Standard",
                            selectedDoorIndex = 1,
                            doors = {
                                {
                                    exitIndex = 1,
                                    targetRoomKey = "F_Combat02",
                                    offerPoint = {
                                        kind = "generatedDoorRewards",
                                        batchKey = "nextDoors",
                                        offers = {
                                            {
                                                store = "RunProgress",
                                                rewardType = "MaxHealthDrop",
                                                acquired = false,
                                            },
                                        },
                                    },
                                },
                            },
                        },
                    },
                },
            },
        },
    }
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

local function ensureOffer(catalog, door)
    door.offerPoint = door.offerPoint or defaultOfferPoint(catalog)
    door.offerPoint.kind = door.offerPoint.kind or "generatedDoorRewards"
    door.offerPoint.batchKey = door.offerPoint.batchKey or "nextDoors"
    door.offerPoint.offers = door.offerPoint.offers or { defaultOffer(catalog, "RunProgress") }
    door.offerPoint.offers[1] = door.offerPoint.offers[1] or defaultOffer(catalog, "RunProgress")
    return door.offerPoint.offers[1]
end

local function ensureRoomOffer(catalog, biomeKey, room)
    room.offerPoints = materializedRoomOfferPoints(catalog, biomeKey, room.roomKey, room.offerPoints)
    local roomDeclarationValue = roomDeclaration(catalog, biomeKey, room.roomKey)
    room.offerPoints = room.offerPoints or { defaultRoomOfferPoint(catalog, roomDeclarationValue or { key = room.roomKey }) }
    room.offerPoints[1] = room.offerPoints[1] or defaultRoomOfferPoint(catalog, roomDeclarationValue or { key = room.roomKey })
    room.offerPoints[1].offers = room.offerPoints[1].offers or { defaultOffer(catalog, "WorldShop") }
    room.offerPoints[1].offers[1] = room.offerPoints[1].offers[1] or defaultOffer(catalog, "WorldShop")
    return room.offerPoints[1].offers[1]
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

local function projectedSources(sources, sourceIndex, value)
    local projected = {}
    for index, source in ipairs(sources or {}) do
        projected[index] = source
    end
    projected[sourceIndex] = value
    return projected
end

local function attachCandidateProviders(state)
    local biome = state.draft.biomes[1]
    for _, room in ipairs(biome.rooms or {}) do
        for _, offerPoint in ipairs(room.offerPoints or {}) do
            for _, offer in ipairs(offerPoint.offers or {}) do
                local rewardOptions = state.rewardTypeOptions[offer.store] or { values = {}, labels = {} }
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
                                payload = defaultPayloadForRewardType(state.catalog, value),
                            }
                        end,
                    }),
                }
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

                local offer = ensureOffer(state.catalog, door)
                local rewardOptions = state.rewardTypeOptions[offer.store] or { values = {}, labels = {} }
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
                                payload = defaultPayloadForRewardType(state.catalog, value),
                            }
                        end,
                    }),
                }

                if offer.rewardType == "Devotion" then
                    offer.payload = offer.payload or defaultPayloadForRewardType(state.catalog, "Devotion")
                    offer.payload.sources = offer.payload.sources or defaultPayloadForRewardType(state.catalog, "Devotion").sources
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

local function ensureEvaluation(state)
    if state.dirty or state.evaluation == nil then
        return evaluate(state)
    end
    return state.evaluation
end

local function currentBiome(state)
    return state.draft.biomes[1]
end

local function setRoomKey(state, roomIndex, roomKey)
    local biome = currentBiome(state)
    local room = biome.rooms[roomIndex]
    if room == nil or room.roomKey == roomKey then
        return false
    end
    room.roomKey = roomKey
    room.offerPoints = materializedRoomOfferPoints(state.catalog, biome.biomeKey, roomKey, room.offerPoints)
    room.generatedDoors = materializedGeneratedDoors(state.catalog, biome.biomeKey, roomKey, room.generatedDoors)
    markDirty(state)
    return true
end

local function setDoorTarget(state, roomIndex, doorIndex, targetRoomKey)
    local door = currentBiome(state).rooms[roomIndex].generatedDoors.doors[doorIndex]
    if door.targetRoomKey == targetRoomKey then
        return false
    end
    door.targetRoomKey = targetRoomKey
    markDirty(state)
    return true
end

local function setRewardStore(state, roomIndex, doorIndex, storeKey)
    local offer = ensureOffer(state.catalog, currentBiome(state).rooms[roomIndex].generatedDoors.doors[doorIndex])
    if offer.store == storeKey then
        return false
    end
    offer.store = storeKey
    offer.rewardType = first(rewardTypesForStore(state.catalog, storeKey), offer.rewardType)
    offer.payload = defaultPayloadForRewardType(state.catalog, offer.rewardType)
    markDirty(state)
    return true
end

local function setRewardType(state, roomIndex, doorIndex, rewardType)
    local offer = ensureOffer(state.catalog, currentBiome(state).rooms[roomIndex].generatedDoors.doors[doorIndex])
    if offer.rewardType == rewardType then
        return false
    end
    offer.rewardType = rewardType
    offer.payload = defaultPayloadForRewardType(state.catalog, rewardType)
    markDirty(state)
    return true
end

local function setBoonSource(state, roomIndex, doorIndex, source)
    local offer = ensureOffer(state.catalog, currentBiome(state).rooms[roomIndex].generatedDoors.doors[doorIndex])
    offer.payload = offer.payload or {}
    if offer.payload.source == source then
        return false
    end
    offer.payload.source = source
    markDirty(state)
    return true
end

local function setDevotionSource(state, roomIndex, doorIndex, sourceIndex, source)
    local offer = ensureOffer(state.catalog, currentBiome(state).rooms[roomIndex].generatedDoors.doors[doorIndex])
    offer.payload = offer.payload or defaultPayloadForRewardType(state.catalog, "Devotion")
    offer.payload.sources = offer.payload.sources or {}
    if offer.payload.sources[sourceIndex] == source then
        return false
    end
    offer.payload.sources[sourceIndex] = source
    markDirty(state)
    return true
end

local function setRewardAcquired(state, roomIndex, doorIndex, acquired)
    local offer = ensureOffer(state.catalog, currentBiome(state).rooms[roomIndex].generatedDoors.doors[doorIndex])
    if offer.acquired == acquired then
        return false
    end
    offer.acquired = acquired
    markDirty(state)
    return true
end

local function setRoomOfferStore(state, roomIndex, storeKey)
    local biome = currentBiome(state)
    local offer = ensureRoomOffer(state.catalog, biome.biomeKey, biome.rooms[roomIndex])
    if offer.store == storeKey then
        return false
    end
    offer.store = storeKey
    offer.rewardType = first(rewardTypesForStore(state.catalog, storeKey), offer.rewardType)
    offer.payload = defaultPayloadForRewardType(state.catalog, offer.rewardType)
    markDirty(state)
    return true
end

local function setRoomOfferType(state, roomIndex, rewardType)
    local biome = currentBiome(state)
    local offer = ensureRoomOffer(state.catalog, biome.biomeKey, biome.rooms[roomIndex])
    if offer.rewardType == rewardType then
        return false
    end
    offer.rewardType = rewardType
    offer.payload = defaultPayloadForRewardType(state.catalog, rewardType)
    markDirty(state)
    return true
end

local function setRoomOfferAcquired(state, roomIndex, acquired)
    local biome = currentBiome(state)
    local offer = ensureRoomOffer(state.catalog, biome.biomeKey, biome.rooms[roomIndex])
    if offer.acquired == acquired then
        return false
    end
    offer.acquired = acquired
    markDirty(state)
    return true
end

local function setSelectedDoor(state, roomIndex, selectedDoorIndex)
    local generatedDoors = currentBiome(state).rooms[roomIndex].generatedDoors
    if generatedDoors.selectedDoorIndex == selectedDoorIndex then
        return false
    end
    generatedDoors.selectedDoorIndex = selectedDoorIndex
    markDirty(state)
    return true
end

local function appendSelectedTarget(state)
    local biome = currentBiome(state)
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
    room.offerPoints = materializedRoomOfferPoints(state.catalog, biome.biomeKey, room.roomKey, nil)
    room.generatedDoors = materializedGeneratedDoors(state.catalog, biome.biomeKey, room.roomKey, nil)
    biome.rooms[#biome.rooms + 1] = room
    markDirty(state)
    return true
end

local function removeLastRoom(state)
    local rooms = currentBiome(state).rooms
    if #rooms <= 1 then
        return false
    end
    rooms[#rooms] = nil
    markDirty(state)
    return true
end

local function resetDraft(state)
    state.draft = debugHarness.defaultDraft()
    markDirty(state)
end

local function drawFeedback(imgui, label, feedback)
    if feedback ~= nil then
        pushText(imgui, label .. ": " .. feedback.code .. " - " .. tostring(feedback.message))
    end
end

local function drawRewardPayload(state, imgui, roomIndex, doorIndex, offer)
    if offer.rewardType == "Boon" then
        offer.payload = offer.payload or defaultPayloadForRewardType(state.catalog, "Boon")
        local nextSource, changed = drawChoice(
            imgui,
            "Source##room" .. roomIndex .. "_door" .. doorIndex,
            offer.payload.source,
            state.boonSourceOptions
        )
        if changed then
            setBoonSource(state, roomIndex, doorIndex, nextSource)
        end
    elseif offer.rewardType == "Devotion" then
        offer.payload = offer.payload or defaultPayloadForRewardType(state.catalog, "Devotion")
        offer.payload.sources = offer.payload.sources or defaultPayloadForRewardType(state.catalog, "Devotion").sources
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
                setDevotionSource(state, roomIndex, doorIndex, sourceIndex, nextSource)
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
        setDoorTarget(state, roomIndex, doorIndex, nextTarget)
    end

    local offer = ensureOffer(state.catalog, door)
    local offerProviders = offer.candidateProviders or {}
    local nextStore, storeChanged = drawChoice(imgui, "Store##room" .. roomIndex .. "_door" .. doorIndex, offer.store, state.storeOptions)
    if storeChanged then
        setRewardStore(state, roomIndex, doorIndex, nextStore)
        offer = ensureOffer(state.catalog, door)
        offerProviders = offer.candidateProviders or {}
    end

    local rewardOptions = offerProviders.rewardType or state.rewardTypeOptions[offer.store] or { values = {}, labels = {} }
    local nextRewardType, rewardChanged = drawChoice(
        imgui,
        "Reward##room" .. roomIndex .. "_door" .. doorIndex,
        offer.rewardType,
        rewardOptions
    )
    if rewardChanged then
        setRewardType(state, roomIndex, doorIndex, nextRewardType)
        offer = ensureOffer(state.catalog, door)
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
            setRewardAcquired(state, roomIndex, doorIndex, nextAcquired)
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
    local biome = currentBiome(state)
    local offer = ensureRoomOffer(state.catalog, biome.biomeKey, room)
    local offerPoint = room.offerPoints[1]

    pushText(imgui, "Room offer 1 / " .. tostring(offerPoint.kind))
    local nextStore, storeChanged = drawChoice(imgui, "Room store##room" .. roomIndex, offer.store, state.storeOptions)
    if storeChanged then
        setRoomOfferStore(state, roomIndex, nextStore)
        offer = ensureRoomOffer(state.catalog, biome.biomeKey, room)
    end

    local offerProviders = offer.candidateProviders or {}
    local rewardOptions = offerProviders.rewardType or state.rewardTypeOptions[offer.store] or { values = {}, labels = {} }
    local nextRewardType, rewardChanged = drawChoice(
        imgui,
        "Room reward##room" .. roomIndex,
        offer.rewardType,
        rewardOptions
    )
    if rewardChanged then
        setRoomOfferType(state, roomIndex, nextRewardType)
        offer = ensureRoomOffer(state.catalog, biome.biomeKey, room)
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
            setRoomOfferAcquired(state, roomIndex, nextAcquired)
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
        setRoomKey(state, roomIndex, nextRoomKey)
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
        setSelectedDoor(state, roomIndex, nextSelectedDoor)
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
        resetDraft(state)
    end
    sameLine(imgui)
    if smallButton(imgui, "Append selected target") then
        appendSelectedTarget(state)
    end
    sameLine(imgui)
    if smallButton(imgui, "Remove last room") then
        removeLastRoom(state)
    end

    local evaluation = ensureEvaluation(state)
    separator(imgui)
    drawStatus(imgui, evaluation)

    for roomIndex, room in ipairs(currentBiome(state).rooms or {}) do
        drawRoom(state, imgui, evaluation, roomIndex, room)
    end

    if state.dirty then
        ensureEvaluation(state)
    end
end

function debugHarness.create(opts)
    opts = opts or {}
    local catalog = opts.catalog or opts.data and opts.data.loadCatalog() or dataModule.loadCatalog()
    local state = {
        catalog = catalog,
        pipeline = opts.pipeline or routePipeline,
        candidateProvider = opts.candidateProvider or candidateProviderModule,
        draft = deepCopy(opts.draft or debugHarness.defaultDraft()),
        dirty = true,
        evaluation = nil,
        providerVersion = 1,
        roomOptions = buildRoomOptions(catalog, "F"),
        storeOptions = buildStoreOptions(catalog),
        rewardTypeOptions = buildRewardTypeOptions(catalog),
        boonSourceOptions = buildSourceOptions(catalog, "boon"),
    }

    state.drawTab = function(_, ctx)
        return draw(state, ctx)
    end
    state.evaluate = function()
        return evaluate(state)
    end
    state.ensureEvaluation = function()
        return ensureEvaluation(state)
    end
    state.resetDraft = function()
        return resetDraft(state)
    end
    state.appendSelectedTarget = function()
        return appendSelectedTarget(state)
    end
    state.removeLastRoom = function()
        return removeLastRoom(state)
    end
    state.setRoomKey = function(roomIndex, roomKey)
        return setRoomKey(state, roomIndex, roomKey)
    end
    state.setDoorTarget = function(roomIndex, doorIndex, targetRoomKey)
        return setDoorTarget(state, roomIndex, doorIndex, targetRoomKey)
    end
    state.setRewardStore = function(roomIndex, doorIndex, storeKey)
        return setRewardStore(state, roomIndex, doorIndex, storeKey)
    end
    state.setRewardType = function(roomIndex, doorIndex, rewardType)
        return setRewardType(state, roomIndex, doorIndex, rewardType)
    end
    state.setRewardAcquired = function(roomIndex, doorIndex, acquired)
        return setRewardAcquired(state, roomIndex, doorIndex, acquired)
    end
    state.setBoonSource = function(roomIndex, doorIndex, source)
        return setBoonSource(state, roomIndex, doorIndex, source)
    end
    state.setDevotionSource = function(roomIndex, doorIndex, sourceIndex, source)
        return setDevotionSource(state, roomIndex, doorIndex, sourceIndex, source)
    end
    state.setRoomOfferStore = function(roomIndex, storeKey)
        return setRoomOfferStore(state, roomIndex, storeKey)
    end
    state.setRoomOfferType = function(roomIndex, rewardType)
        return setRoomOfferType(state, roomIndex, rewardType)
    end
    state.setRoomOfferAcquired = function(roomIndex, acquired)
        return setRoomOfferAcquired(state, roomIndex, acquired)
    end

    return state
end

return debugHarness
