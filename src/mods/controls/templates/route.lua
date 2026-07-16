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

local function createRuntime(fields, instance)
    local control = {}

    function control.read(_)
        local value = fields.ConfiguredBiomePrefix:read()
        requireAllowed(value, instance.configuredPrefixLookup, "route '" .. instance.name .. "' configured prefix")
        return value
    end

    return control
end

function Route.createRuntime(fields, instance)
    return createRuntime(fields, instance)
end

function Route.createUi(fields, instance)
    local control = createRuntime(fields, instance)

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

return Route
