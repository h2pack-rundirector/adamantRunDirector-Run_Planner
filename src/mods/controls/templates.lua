local templates = {}

local function unavailableView()
    error("planner controls have no production draw view before the editor checkpoint", 0)
end

local function requireAllowed(value, lookup, context)
    if lookup[value] ~= true then
        error(context .. " does not allow value '" .. tostring(value) .. "'", 0)
    end
end

local Route = {}

function Route.storage()
    return {
        {
            key = "ConfiguredBiomePrefix",
            type = "string",
            default = "",
            maxLen = 64,
        },
    }
end

local function createRouteRuntime(fields, instance)
    local control = {}

    function control.read(_)
        local value = fields.ConfiguredBiomePrefix:read()
        requireAllowed(value, instance.configuredPrefixLookup, "route '" .. instance.name .. "' configured prefix")
        return value
    end

    return control
end

function Route.createRuntime(fields, instance)
    return createRouteRuntime(fields, instance)
end

function Route.createUi(fields, instance)
    local control = createRouteRuntime(fields, instance)

    function control.write(_, configuredBiomePrefix)
        requireAllowed(
            configuredBiomePrefix,
            instance.configuredPrefixLookup,
            "route '" .. instance.name .. "' configured prefix"
        )
        fields.ConfiguredBiomePrefix:write(configuredBiomePrefix)
    end

    return control
end

Route.views = { default = unavailableView }

local Room = {}

function Room.storage(instance)
    return instance.state.storage
end

local function readSelection(fields, descriptor)
    local value = {
        storeKey = descriptor.fixedStoreKey,
        rewardType = descriptor.fixedRewardType,
        payloadValues = {},
    }
    if descriptor.fields.storeKey ~= nil then
        value.storeKey = fields[descriptor.fields.storeKey]:read()
    end
    if descriptor.fields.rewardType ~= nil then
        value.rewardType = fields[descriptor.fields.rewardType]:read()
    end
    for index = 1, descriptor.payloadArity do
        value.payloadValues[index] = fields[descriptor.fields["payload" .. tostring(index)]]:read()
    end
    if descriptor.fields.purchased ~= nil then
        value.purchased = fields[descriptor.fields.purchased]:read()
    end
    return value
end

local function readRoomAddress(fields, instance, address)
    local scalar = instance.state.scalars.lookup[address]
    if scalar ~= nil then
        local value = fields[scalar.fieldKey]:read()
        if scalar.allowedLookup ~= nil and value ~= "" then
            requireAllowed(value, scalar.allowedLookup, "room state address '" .. address .. "'")
        end
        return value
    end
    local selection = instance.state.selections.lookup[address]
    if selection ~= nil then
        return readSelection(fields, selection)
    end
    error("room control '" .. instance.name .. "' has no state address '" .. tostring(address) .. "'", 0)
end

local function createRoomRuntime(fields, instance)
    local control = {}

    function control.read(_, address)
        return readRoomAddress(fields, instance, address)
    end

    return control
end

local function writeScalar(fields, scalar, address, value)
    if scalar.valueType == "bool" and type(value) ~= "boolean" then
        error("room state address '" .. address .. "' expects a boolean", 0)
    end
    if scalar.valueType == "int"
        and (type(value) ~= "number" or value ~= math.floor(value))
    then
        error("room state address '" .. address .. "' expects an integer", 0)
    end
    if scalar.valueType == "string" and type(value) ~= "string" then
        error("room state address '" .. address .. "' expects a string", 0)
    end
    if scalar.allowedLookup ~= nil and value ~= "" then
        requireAllowed(value, scalar.allowedLookup, "room state address '" .. address .. "'")
    end
    fields[scalar.fieldKey]:write(value)
end

local function writeSelection(fields, descriptor, value)
    if type(value) ~= "table" then
        error("reward selection write expects a table", 0)
    end
    if value.storeKey ~= nil and type(value.storeKey) ~= "string" then
        error("reward selection storeKey expects a string", 0)
    end
    if value.rewardType ~= nil and type(value.rewardType) ~= "string" then
        error("reward selection rewardType expects a string", 0)
    end
    if descriptor.fixedStoreKey ~= nil and value.storeKey ~= nil and value.storeKey ~= descriptor.fixedStoreKey then
        error("cannot replace fixed reward store '" .. descriptor.fixedStoreKey .. "'", 0)
    end
    if descriptor.fixedRewardType ~= nil
        and value.rewardType ~= nil
        and value.rewardType ~= descriptor.fixedRewardType
    then
        error("cannot replace fixed reward type '" .. descriptor.fixedRewardType .. "'", 0)
    end
    if descriptor.fields.storeKey ~= nil then
        fields[descriptor.fields.storeKey]:write(value.storeKey or "")
    end
    if descriptor.fields.rewardType ~= nil then
        fields[descriptor.fields.rewardType]:write(value.rewardType or "")
    end
    local payloadValues = value.payloadValues or {}
    if type(payloadValues) ~= "table" then
        error("reward selection payloadValues expects a table", 0)
    end
    for index = 1, descriptor.payloadArity do
        if payloadValues[index] ~= nil and type(payloadValues[index]) ~= "string" then
            error("reward selection payload value expects a string", 0)
        end
        fields[descriptor.fields["payload" .. tostring(index)]]:write(payloadValues[index] or "")
    end
    if descriptor.fields.purchased ~= nil then
        if value.purchased ~= nil and type(value.purchased) ~= "boolean" then
            error("reward selection purchased expects a boolean", 0)
        end
        fields[descriptor.fields.purchased]:write(value.purchased == true)
    end
end

function Room.createRuntime(fields, instance)
    return createRoomRuntime(fields, instance)
end

function Room.createUi(fields, instance)
    local control = createRoomRuntime(fields, instance)

    function control.write(_, address, value)
        local scalar = instance.state.scalars.lookup[address]
        if scalar ~= nil then
            writeScalar(fields, scalar, address, value)
            return
        end
        local selection = instance.state.selections.lookup[address]
        if selection ~= nil then
            writeSelection(fields, selection, value)
            return
        end
        error("room control '" .. instance.name .. "' has no state address '" .. tostring(address) .. "'", 0)
    end

    return control
end

Room.views = { default = unavailableView }

function templates.build(catalog)
    local result = { Route = Route }
    for _, declaration in ipairs(catalog.roomTemplates.ordered) do
        result[declaration.key] = Room
    end
    return result
end

return templates
