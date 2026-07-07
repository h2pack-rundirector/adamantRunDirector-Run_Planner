local options = {}

local EMPTY_OPTIONS = {
    values = {},
    labels = {},
}

function options.empty()
    return EMPTY_OPTIONS
end

function options.deepCopy(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}
    for key, child in pairs(value) do
        copy[key] = options.deepCopy(child)
    end
    return copy
end

function options.sortedKeys(map)
    local keys = {}
    for key, _ in pairs(map or {}) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    return keys
end

function options.first(values, fallback)
    return values and values[1] or fallback
end

function options.package(values, labelFor)
    local labels = {}
    for index, value in ipairs(values) do
        labels[index] = labelFor(value)
    end
    return {
        values = values,
        labels = labels,
    }
end

function options.labelForRoom(catalog, biomeKey, roomKey)
    local biome = catalog.biomes.lookup[biomeKey]
    local room = biome and biome.rooms.lookup[roomKey] or nil
    if room == nil then
        return roomKey
    end
    return room.label .. " (" .. room.key .. ")"
end

function options.roomOptions(catalog, biomeKey)
    local biome = catalog.biomes.lookup[biomeKey]
    local values = {}
    for _, room in ipairs((biome and biome.rooms.ordered) or {}) do
        values[#values + 1] = room.key
    end
    return options.package(values, function(roomKey)
        return options.labelForRoom(catalog, biomeKey, roomKey)
    end)
end

function options.rewardTypesForStore(catalog, storeKey)
    local store = catalog.rewards.stores[storeKey]
    if store ~= nil then
        return store.options or EMPTY_OPTIONS.values
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

function options.storeOptions(catalog)
    local values = options.sortedKeys(catalog.rewards.stores)
    for _, shopKey in ipairs(options.sortedKeys(catalog.rewards.shops)) do
        values[#values + 1] = shopKey
    end
    return options.package(values, function(value)
        return value
    end)
end

function options.rewardTypeOptions(catalog)
    local byStore = {}
    for _, storeKey in ipairs(options.storeOptions(catalog).values) do
        byStore[storeKey] = options.package(options.rewardTypesForStore(catalog, storeKey), function(value)
            return value
        end)
    end
    return byStore
end

function options.sourceOptions(catalog, sourceSetKey)
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

function options.sourceKey(catalog, sourceSetKey, index)
    local sourceSet = catalog.rewards.sources[sourceSetKey]
    local source = sourceSet and sourceSet.ordered and sourceSet.ordered[index] or nil
    return source and source.key or nil
end

function options.defaultPayloadForRewardType(catalog, rewardType)
    if rewardType == "Boon" then
        return {
            source = options.sourceKey(catalog, "boon", 1),
        }
    elseif rewardType == "Devotion" then
        return {
            sources = {
                options.sourceKey(catalog, "boon", 1),
                options.sourceKey(catalog, "boon", 2),
            },
        }
    end
    return {}
end

function options.defaultOffer(catalog, storeKey)
    storeKey = storeKey or "RunProgress"
    local rewardType = options.first(options.rewardTypesForStore(catalog, storeKey), "Boon")
    return {
        store = storeKey,
        rewardType = rewardType,
        acquired = false,
        payload = options.defaultPayloadForRewardType(catalog, rewardType),
    }
end

function options.defaultGeneratedDoorOfferPoint(catalog)
    return {
        kind = "generatedDoorRewards",
        batchKey = "nextDoors",
        offers = {
            options.defaultOffer(catalog, "RunProgress"),
        },
    }
end

local function offerProfile(catalog, profileKey)
    return catalog.offerProfiles and catalog.offerProfiles[profileKey] or nil
end

function options.shopStoreForProfile(catalog, profileKey)
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
                local storeKey = options.shopStoreForProfile(catalog, branch.offerProfile)
                if storeKey ~= nil then
                    return storeKey
                end
            end
        end
    end
    return nil
end

function options.defaultRoomOfferPoint(catalog, room)
    local storeKey = options.shopStoreForProfile(catalog, room.offerProfile) or "WorldShop"
    local kind = room.kind == "Preboss" and "prebossRewards" or "shop"
    return {
        kind = kind,
        batchKey = room.key .. "_roomOffers",
        offers = {
            options.defaultOffer(catalog, storeKey),
        },
    }
end

function options.roomDeclaration(catalog, biomeKey, roomKey)
    local biome = catalog.biomes.lookup[biomeKey]
    return biome and biome.rooms.lookup[roomKey] or nil
end

function options.materializedGeneratedDoors(catalog, biomeKey, roomKey, existing)
    local room = options.roomDeclaration(catalog, biomeKey, roomKey)
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
            offerPoint = options.deepCopy((existingDoor and existingDoor.offerPoint) or options.defaultGeneratedDoorOfferPoint(catalog)),
        }
    end

    if generatedDoors.doors[generatedDoors.selectedDoorIndex] == nil then
        generatedDoors.selectedDoorIndex = 1
    end

    return generatedDoors
end

function options.materializedRoomOfferPoints(catalog, biomeKey, roomKey, existing)
    local room = options.roomDeclaration(catalog, biomeKey, roomKey)
    if room == nil or (room.kind ~= "Shop" and room.kind ~= "Preboss") then
        return nil
    end
    return options.deepCopy(existing or { options.defaultRoomOfferPoint(catalog, room) })
end

return options
