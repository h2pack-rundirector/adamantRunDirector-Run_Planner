local stateManifest = {}

local STRING_MAX = 64

local function title(value)
    return string.upper(string.sub(value, 1, 1)) .. string.sub(value, 2)
end

local function addStorage(layout, descriptor)
    if layout.storageLookup[descriptor.key] ~= nil then
        error("duplicate room storage field '" .. tostring(descriptor.key) .. "'", 0)
    end
    if type(descriptor.key) ~= "string" or string.match(descriptor.key, "^[A-Za-z][A-Za-z0-9_]*$") == nil then
        error("invalid room storage field '" .. tostring(descriptor.key) .. "'", 0)
    end
    layout.storage[#layout.storage + 1] = descriptor
    layout.storageLookup[descriptor.key] = descriptor
end

local function addScalar(layout, address, fieldKey, descriptor)
    if layout.scalars.lookup[address] ~= nil then
        error("duplicate room-state address '" .. address .. "'", 0)
    end
    local scalar = {
        address = address,
        fieldKey = fieldKey,
        allowedValues = descriptor.allowedValues,
        allowedLookup = descriptor.allowedLookup,
        valueType = descriptor.type,
    }
    layout.scalars.ordered[#layout.scalars.ordered + 1] = scalar
    layout.scalars.lookup[address] = scalar
    descriptor.allowedValues = nil
    descriptor.allowedLookup = nil
    descriptor.key = fieldKey
    addStorage(layout, descriptor)
end

local function payloadArity(catalog, rewardType)
    local primitive = catalog.rewards.primitives.lookup[rewardType]
    if primitive.payloadDomain == nil then
        return 0
    end
    local domain = catalog.rewards.payloadDomains.lookup[primitive.payloadDomain]
    if domain.kind == "oneOf" then
        return 1
    end
    if domain.kind == "distinctPair" then
        return 2
    end
    error("unsupported payload domain kind '" .. tostring(domain.kind) .. "'", 0)
end

local function contains(values, candidate)
    for _, value in ipairs(values) do
        if value == candidate then
            return true
        end
    end
    return false
end

local function storePayloadArity(catalog, specification)
    local maximum = 0
    for _, storeKey in ipairs(specification.storeKeys or {}) do
        local bag = catalog.rewards.bags.lookup[storeKey]
        for _, entry in ipairs(bag.entries) do
            local eligible = #specification.eligibleRewardTypes == 0
                or contains(specification.eligibleRewardTypes, entry.rewardType)
            if eligible and not contains(specification.ineligibleRewardTypes, entry.rewardType) then
                local arity = payloadArity(catalog, entry.rewardType)
                if arity > maximum then
                    maximum = arity
                end
            end
        end
    end
    return maximum
end

local function rewardTypesPayloadArity(catalog, rewardTypes)
    local maximum = 0
    for _, rewardType in ipairs(rewardTypes) do
        local arity = payloadArity(catalog, rewardType)
        if arity > maximum then
            maximum = arity
        end
    end
    return maximum
end

local function addSelection(catalog, layout, address, prefix, specification)
    if layout.selections.lookup[address] ~= nil then
        error("duplicate room-state address '" .. address .. "'", 0)
    end

    local selection = {
        address = address,
        fixedStoreKey = specification.fixedStoreKey,
        fixedRewardType = specification.fixedRewardType,
        fields = {},
    }
    if specification.storeKeys ~= nil and #specification.storeKeys == 1 then
        selection.fixedStoreKey = specification.storeKeys[1]
    elseif specification.storeKeys ~= nil then
        selection.fields.storeKey = prefix .. "StoreKey"
        addStorage(layout, {
            key = selection.fields.storeKey,
            type = "string",
            default = "",
            maxLen = STRING_MAX,
        })
    end

    if specification.fixedRewardType == nil then
        selection.fields.rewardType = prefix .. "Type"
        addStorage(layout, {
            key = selection.fields.rewardType,
            type = "string",
            default = "",
            maxLen = STRING_MAX,
        })
    end

    local arity = specification.fixedRewardType ~= nil
        and payloadArity(catalog, specification.fixedRewardType)
        or specification.payloadArity
        or storePayloadArity(catalog, specification)
    selection.payloadArity = arity
    for index = 1, arity do
        local fieldKey = prefix .. "Payload" .. tostring(index)
        selection.fields["payload" .. tostring(index)] = fieldKey
        addStorage(layout, {
            key = fieldKey,
            type = "string",
            default = "",
            maxLen = STRING_MAX,
        })
    end

    if specification.purchased then
        selection.fields.purchased = prefix .. "Purchased"
        addStorage(layout, {
            key = selection.fields.purchased,
            type = "bool",
            default = false,
        })
    end

    layout.selections.ordered[#layout.selections.ordered + 1] = selection
    layout.selections.lookup[address] = selection
end

local function allowedValues(values)
    local lookup = {}
    for _, value in ipairs(values) do
        lookup[value] = true
    end
    return values, lookup
end

local function addShop(catalog, layout, addressPrefix, fieldPrefix, shopProfileKey)
    local profile = catalog.rewards.shops.profiles.lookup[shopProfileKey]
    for _, slot in ipairs(profile.slots) do
        local rewardTypes = catalog.rewards.shops.optionSets.lookup[slot.optionSetKey]
        addSelection(catalog, layout, addressPrefix .. "." .. slot.key, fieldPrefix .. title(slot.key), {
            purchased = true,
            payloadArity = rewardTypesPayloadArity(catalog, rewardTypes),
        })
    end
end

local function addReward(catalog, layout, reward, address, fieldPrefix, context)
    if reward.kind == "none" then
        return
    end
    if reward.kind == "fixed" then
        addSelection(catalog, layout, address, fieldPrefix, {
            fixedRewardType = reward.rewardType,
        })
        return
    end
    if reward.kind == "countedChoice" then
        addSelection(catalog, layout, address, fieldPrefix, {
            storeKeys = reward.storeKeys,
            eligibleRewardTypes = reward.eligibleRewardTypes,
            ineligibleRewardTypes = reward.ineligibleRewardTypes,
        })
        return
    end
    if reward.kind == "shop" then
        addShop(catalog, layout, address, fieldPrefix, reward.shopProfileKey)
        return
    end
    if reward.kind == "localSlots" then
        for _, child in ipairs(context.localChildren) do
            addReward(
                catalog,
                layout,
                reward.choice,
                "local." .. child.key,
                title(child.key) .. "Reward",
                context
            )
        end
        return
    end
    if reward.kind == "incomingKind" then
        local values = {}
        for _, kind in ipairs(reward.kinds) do
            values[#values + 1] = kind.key
        end
        local valueList, valueLookup = allowedValues(values)
        addScalar(layout, address .. ".incomingKind", fieldPrefix .. "IncomingKind", {
            type = "string",
            default = "",
            maxLen = STRING_MAX,
            allowedValues = valueList,
            allowedLookup = valueLookup,
        })
        for _, kind in ipairs(reward.kinds) do
            addReward(
                catalog,
                layout,
                kind.reward,
                address .. "." .. kind.key,
                fieldPrefix .. title(kind.key),
                context
            )
        end
        return
    end
    error("unsupported reward binding kind '" .. tostring(reward.kind) .. "'", 0)
end

local function addLocalChildren(catalog, layout, room)
    for _, child in ipairs(room.localChildren) do
        if child.reward ~= nil then
            local childPrefix = title(child.key)
            addScalar(layout, "local." .. child.key .. ".generated", childPrefix .. "Generated", {
                type = "bool",
                default = false,
            })
            addScalar(layout, "local." .. child.key .. ".enteredOrder", childPrefix .. "EnteredOrder", {
                type = "int",
                default = 0,
                min = 0,
                max = #room.localChildren,
            })
            addReward(
                catalog,
                layout,
                child.reward,
                "local." .. child.key,
                childPrefix .. "Reward",
                room
            )
        end
    end
end

local function addEncounterState(catalog, layout, room)
    local profile = catalog.encounterProfiles.lookup[room.encounterProfileKey]
    for _, phase in ipairs(profile.phases) do
        if phase.presence ~= nil then
            addScalar(layout, "phase." .. phase.key .. ".present", title(phase.key) .. "Present", {
                type = "bool",
                default = false,
            })
        end
        if phase.offerPoint ~= nil then
            local offer = phase.offerPoint
            local offerPrefix = title(offer.key)
            addScalar(layout, "offer." .. offer.key .. ".count", offerPrefix .. "OfferCount", {
                type = "int",
                default = 0,
                min = 0,
                max = offer.offerCount.max,
            })
            addScalar(layout, "offer." .. offer.key .. ".pickedIndex", offerPrefix .. "PickedIndex", {
                type = "int",
                default = 0,
                min = 0,
                max = offer.offerCount.max,
            })
            for index = 1, offer.offerCount.max do
                addReward(
                    catalog,
                    layout,
                    offer.choice,
                    "offer." .. offer.key .. "." .. tostring(index),
                    offerPrefix .. "Offer" .. tostring(index),
                    room
                )
            end
        end
    end
end

function stateManifest.build(catalog, room)
    local layout = {
        storage = {},
        storageLookup = {},
        scalars = { ordered = {}, lookup = {} },
        selections = { ordered = {}, lookup = {} },
    }
    addReward(
        catalog,
        layout,
        room.incomingReward,
        "reward",
        "Reward",
        room
    )
    addLocalChildren(catalog, layout, room)
    addEncounterState(catalog, layout, room)
    return layout
end

return stateManifest
