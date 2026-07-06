local address = import("mods/forms/address.lua")
local guard = import("mods/declarations/guard.lua")

local candidates = {}

local function stableAddressKey(formAddress, context)
    guard.expectTable(formAddress, context)

    local keys = {}
    for key, value in pairs(formAddress) do
        local valueType = type(value)
        if valueType ~= "string" and valueType ~= "number" and valueType ~= "boolean" then
            guard.fail(context .. "." .. tostring(key), "address values must be scalar")
        end
        keys[#keys + 1] = key
    end
    table.sort(keys)

    local parts = {}
    for index, key in ipairs(keys) do
        parts[index] = tostring(key) .. "=" .. tostring(formAddress[key])
    end
    return table.concat(parts, "|")
end

local function providerKey(formAddress, providerKeyValue, context)
    return stableAddressKey(formAddress, context .. ".formAddress")
        .. "::"
        .. guard.expectString(providerKeyValue, context .. ".providerKey")
end

local function expectProvider(provider, context)
    guard.expectTable(provider, context)
    guard.expectString(provider.key, context .. ".key")
    if type(provider.clearCandidateFeedback) ~= "function" then
        guard.fail(context, "candidate provider must expose clearCandidateFeedback")
    end
    if type(provider.applyCandidateFeedback) ~= "function" then
        guard.fail(context, "candidate provider must expose applyCandidateFeedback")
    end
end

local function sortedKeys(map)
    local keys = {}
    for key, _ in pairs(map) do
        keys[#keys + 1] = key
    end
    table.sort(keys, function(left, right)
        return tostring(left) < tostring(right)
    end)
    return keys
end

local function addProvider(indexed, formAddress, provider, context)
    expectProvider(provider, context)

    local key = providerKey(formAddress, provider.key, context)
    if indexed.byKey[key] ~= nil then
        guard.fail(context, "duplicate candidate provider key at form address")
    end

    indexed.all[#indexed.all + 1] = provider
    indexed.byKey[key] = provider
end

local function indexProviderMap(indexed, formAddress, providers, context)
    if providers == nil then
        return
    end

    guard.expectTable(providers, context)
    for _, key in ipairs(sortedKeys(providers)) do
        addProvider(indexed, formAddress, providers[key], context .. "." .. tostring(key))
    end
end

local function indexDraftProviders(draft)
    guard.expectTable(draft, "candidateFeedback.draft")
    local routeKey = guard.expectString(draft.routeKey, "candidateFeedback.draft.routeKey")
    guard.expectArray(draft.biomes, "candidateFeedback.draft.biomes")

    local indexed = {
        all = {},
        byKey = {},
    }

    for biomeIndex, biomeDraft in ipairs(draft.biomes) do
        guard.expectTable(biomeDraft, "candidateFeedback.draft.biomes[" .. tostring(biomeIndex) .. "]")
        guard.expectArray(biomeDraft.rooms, "candidateFeedback.draft.biomes[" .. tostring(biomeIndex) .. "].rooms")

        for roomIndex, roomNode in ipairs(biomeDraft.rooms) do
            guard.expectTable(roomNode, "candidateFeedback.draft.biomes[" .. tostring(biomeIndex) .. "].rooms[" .. tostring(roomIndex) .. "]")
            local generatedDoors = roomNode.generatedDoors
            if generatedDoors ~= nil then
                guard.expectTable(generatedDoors, "candidateFeedback.generatedDoors")
                guard.expectArray(generatedDoors.doors, "candidateFeedback.generatedDoors.doors")

                for doorIndex, door in ipairs(generatedDoors.doors) do
                    guard.expectTable(door, "candidateFeedback.generatedDoors.doors[" .. tostring(doorIndex) .. "]")
                    indexProviderMap(
                        indexed,
                        address.door(routeKey, biomeIndex, roomIndex, doorIndex),
                        door.candidateProviders,
                        "candidateFeedback.generatedDoors.doors[" .. tostring(doorIndex) .. "].candidateProviders"
                    )

                    local offerPoint = door.offerPoint
                    if offerPoint ~= nil then
                        guard.expectTable(offerPoint, "candidateFeedback.generatedDoors.doors[" .. tostring(doorIndex) .. "].offerPoint")
                        guard.expectArray(offerPoint.offers or {}, "candidateFeedback.generatedDoors.doors[" .. tostring(doorIndex) .. "].offerPoint.offers")
                        for offerIndex, offer in ipairs(offerPoint.offers or {}) do
                            guard.expectTable(offer, "candidateFeedback.generatedDoors.doors[" .. tostring(doorIndex) .. "].offerPoint.offers[" .. tostring(offerIndex) .. "]")
                            indexProviderMap(
                                indexed,
                                address.offer(routeKey, biomeIndex, roomIndex, doorIndex, offerIndex),
                                offer.candidateProviders,
                                "candidateFeedback.generatedDoors.doors[" .. tostring(doorIndex) .. "].offerPoint.offers[" .. tostring(offerIndex) .. "].candidateProviders"
                            )
                        end
                    end
                end
            end
        end
    end

    return indexed
end

local function clearProviders(indexed)
    for _, provider in ipairs(indexed.all) do
        provider.clearCandidateFeedback()
    end
end

local function expectResult(result, context)
    guard.expectTable(result, context)
    guard.expectTable(result.formAddress, context .. ".formAddress")
    guard.expectString(result.providerKey, context .. ".providerKey")
end

local function expectResults(candidateResults)
    local results = guard.expectArray(candidateResults or {}, "candidateFeedback.candidateResults")
    for resultIndex, result in ipairs(results) do
        expectResult(result, "candidateFeedback.candidateResults[" .. tostring(resultIndex) .. "]")
    end
    return results
end

function candidates.apply(draft, candidateResults)
    local results = expectResults(candidateResults)
    local indexed = indexDraftProviders(draft)
    local summary = {
        cleared = #indexed.all,
        applied = 0,
        stale = 0,
        missing = 0,
    }

    clearProviders(indexed)

    for resultIndex, result in ipairs(results) do
        local provider = indexed.byKey[providerKey(result.formAddress, result.providerKey, "candidateFeedback.candidateResults[" .. tostring(resultIndex) .. "]")]

        if provider == nil then
            summary.missing = summary.missing + 1
        elseif provider.applyCandidateFeedback(result) then
            summary.applied = summary.applied + 1
        else
            summary.stale = summary.stale + 1
        end
    end

    return summary
end

return candidates
