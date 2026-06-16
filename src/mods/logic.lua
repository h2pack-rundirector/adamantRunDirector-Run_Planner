local logic = {}

function logic.bind(data) -- luacheck: ignore data
    return logic
end

function logic.registerHooks(moduleRef) -- luacheck: ignore moduleRef
    -- Route hooks will be added once the route-depth schema is settled.
end

function logic.attach(moduleRef)
    logic.registerHooks(moduleRef)
end

return logic
