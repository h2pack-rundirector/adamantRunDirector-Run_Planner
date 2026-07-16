local instances = {}

local function activePrefixes(route, activePrefixEnd)
    local values = { "" }
    local lookup = { [""] = true }
    if activePrefixEnd == nil then
        return values, lookup
    end
    for _, biomeStep in ipairs(route.biomeSteps) do
        values[#values + 1] = biomeStep.key
        lookup[biomeStep.key] = true
        if biomeStep.key == activePrefixEnd then
            return values, lookup
        end
    end
    error("route '" .. route.key .. "' has no declared prefix ending at '" .. tostring(activePrefixEnd) .. "'", 0)
end

function instances.build(catalog, activePrefixEnds)
    local result = {}
    for _, route in ipairs(catalog.controlManifest.routes.ordered) do
        local routeDeclaration = catalog.routes.lookup[route.key]
        local values, lookup = activePrefixes(routeDeclaration, (activePrefixEnds or {})[route.key])
        result[route.key] = {
            template = route.templateKey,
            configuredPrefixValues = values,
            configuredPrefixLookup = lookup,
        }
    end
    for _, room in ipairs(catalog.controlManifest.rooms.ordered) do
        local instance = {
            template = room.templateKey,
            routeKey = room.routeKey,
            biomeStepKey = room.biomeStepKey,
            gameRoomKey = room.gameRoomKey,
            rewardSurfaceKey = room.rewardSurfaceKey,
            entryOfferPolicy = room.entryOfferPolicy,
        }
        if room.state ~= nil then
            instance.state = room.state
        end
        if room.generatedReward ~= nil then
            instance.generatedReward = room.generatedReward
        end
        result[room.key] = instance
    end
    return result
end

return instances
