local instances = {}

local function biomeByStep(catalog, biomeStepKey)
    for _, biome in ipairs(catalog.biomes.ordered) do
        if biome.biomeStepKey == biomeStepKey then
            return biome
        end
    end
end

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

function instances.build(catalog, routeSupport)
    local result = {}
    for _, route in ipairs(catalog.controlManifest.routes.ordered) do
        local routeDeclaration = catalog.routes.lookup[route.key]
        local support = routeSupport and routeSupport.lookup[route.key] or nil
        local values, lookup = activePrefixes(
            routeDeclaration,
            support and support.maximumEditablePrefix or nil
        )
        local labels = { [""] = "Vanilla" }
        for _, biomeStepKey in ipairs(values) do
            if biomeStepKey ~= "" then
                local biome = biomeByStep(catalog, biomeStepKey)
                labels[biomeStepKey] = biome.label
            end
        end
        result[route.key] = {
            template = route.templateKey,
            configuredPrefixValues = values,
            configuredPrefixLookup = lookup,
            configuredPrefixLabels = labels,
        }
    end
    for _, room in ipairs(catalog.controlManifest.rooms.ordered) do
        local instance = {
            template = room.templateKey,
            routeKey = room.routeKey,
            biomeStepKey = room.biomeStepKey,
            gameName = room.gameName,
            label = room.label,
            incomingReward = room.incomingReward,
            entryOfferPolicy = room.entryOfferPolicy,
        }
        for key in pairs(room.prepared) do
            if key ~= "state" then
                error("room control preparation cannot enter Lib declaration field '"
                    .. tostring(key) .. "'", 0)
            end
        end
        if room.prepared.state ~= nil then
            instance.state = room.prepared.state
        end
        result[room.key] = instance
    end
    return result
end

return instances
