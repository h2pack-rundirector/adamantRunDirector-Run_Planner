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
    if values == nil then
        return false
    end
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
            local eligible = specification.eligibleRewardTypes == nil
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

local function addSurface(catalog, layout, surface, address, fieldPrefix, context)
    if surface.kind == "none" then
        return
    end
    if surface.kind == "fixed" then
        addSelection(catalog, layout, address, fieldPrefix, {
            fixedRewardType = surface.rewardType,
        })
        return
    end
    if surface.kind == "storeChoice" then
        addSelection(catalog, layout, address, fieldPrefix, {
            storeKeys = surface.storeKeys,
            eligibleRewardTypes = surface.eligibleRewardTypes,
            ineligibleRewardTypes = surface.ineligibleRewardTypes,
        })
        return
    end
    if surface.kind == "shop" then
        addShop(catalog, layout, address, fieldPrefix, surface.shopProfileKey)
        return
    end
    if surface.kind == "branch" then
        local values = {}
        for _, branch in ipairs(surface.branches) do
            values[#values + 1] = branch.key
        end
        local valueList, valueLookup = allowedValues(values)
        addScalar(layout, address .. ".branch", fieldPrefix .. "Branch", {
            type = "string",
            default = "",
            maxLen = STRING_MAX,
            allowedValues = valueList,
            allowedLookup = valueLookup,
        })
        for _, branch in ipairs(surface.branches) do
            local branchAddress = address .. "." .. branch.key
            local branchPrefix = fieldPrefix .. title(branch.key)
            if branch.surfaceKey ~= nil then
                addSurface(
                    catalog,
                    layout,
                    catalog.rewards.surfaces.lookup[branch.surfaceKey],
                    branchAddress,
                    branchPrefix,
                    context
                )
            else
                addSelection(catalog, layout, branchAddress, branchPrefix, {
                    storeKeys = branch.storeKeys,
                    eligibleRewardTypes = branch.eligibleRewardTypes,
                    ineligibleRewardTypes = branch.ineligibleRewardTypes,
                })
            end
        end
        return
    end
    if surface.kind == "localSlots" then
        for _, child in ipairs(context.localChildren) do
            addSelection(catalog, layout, "local." .. child.key, title(child.key) .. "Reward", {
                storeKeys = surface.storeKeys,
                eligibleRewardTypes = surface.eligibleRewardTypes,
                ineligibleRewardTypes = surface.ineligibleRewardTypes,
            })
        end
        return
    end
    if surface.kind == "incomingKind" then
        local values = {}
        for _, kind in ipairs(surface.kinds) do
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
        for _, kind in ipairs(surface.kinds) do
            addSelection(catalog, layout, address .. "." .. kind.key, fieldPrefix .. title(kind.key), {
                fixedRewardType = kind.rewardType,
                storeKeys = kind.storeKeys,
                eligibleRewardTypes = kind.eligibleRewardTypes,
                ineligibleRewardTypes = kind.ineligibleRewardTypes,
            })
        end
        return
    end
    error("unsupported reward surface kind '" .. tostring(surface.kind) .. "'", 0)
end

local function addLocalChildren(catalog, layout, room)
    for _, child in ipairs(room.localChildren) do
        if child.rewardSurfaceKey ~= nil then
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
            addSurface(
                catalog,
                layout,
                catalog.rewards.surfaces.lookup[child.rewardSurfaceKey],
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
            local surface = catalog.rewards.surfaces.lookup[offer.surfaceKey]
            for index = 1, offer.offerCount.max do
                addSurface(
                    catalog,
                    layout,
                    surface,
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
    addSurface(
        catalog,
        layout,
        catalog.rewards.surfaces.lookup[room.rewardSurfaceKey],
        "reward",
        "Reward",
        room
    )
    addLocalChildren(catalog, layout, room)
    addEncounterState(catalog, layout, room)
    return layout
end

return stateManifest
