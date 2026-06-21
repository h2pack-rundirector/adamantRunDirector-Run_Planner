local deps = ...
local logic = {}

local catalog = deps and deps.catalog or nil
local routePlan = deps and deps.routePlan or nil
local roomRouting = deps and deps.roomRouting or nil

if catalog == nil then
    error("logic requires catalog")
end
if routePlan == nil then
    error("logic requires route plan")
end
if roomRouting == nil then
    error("logic requires room routing")
end

function logic.defineCache(moduleRef)
    routePlan.defineCache(moduleRef)
end

function logic.registerHooks(moduleRef)
    routePlan.registerHooks(moduleRef, catalog)
    roomRouting.registerHooks(moduleRef, catalog)
end

function logic.attach(moduleRef)
    logic.defineCache(moduleRef)
    logic.registerHooks(moduleRef)
end

return logic
