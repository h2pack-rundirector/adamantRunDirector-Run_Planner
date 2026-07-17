local deps = ... or {}
local stateAccess = deps.stateAccess or import("mods/route/state_access.lua")

local authoredResult = {}

function authoredResult.create(catalog, route, layouts, selectors)
    local coordinator = {}
    local published

    local function emptyRoute(routeDeclaration, configuredPrefix)
        return {
            key = routeDeclaration.key,
            label = routeDeclaration.label,
            configuredPrefix = configuredPrefix,
            biomes = { ordered = {}, lookup = {} },
            navTabs = {
                { key = "route", label = "Route" },
            },
        }
    end

    function coordinator.rebuild(_, runtime)
        published = nil
        local access = stateAccess.createRuntime(runtime, catalog)
        local nextResult = {
            routes = { ordered = {}, lookup = {} },
        }
        for _, routeDeclaration in ipairs(catalog.routes.ordered) do
            local configuredPrefix = access:readRoute(routeDeclaration.key)
            local routeView = emptyRoute(routeDeclaration, configuredPrefix)
            if configuredPrefix ~= "" then
                local reachedPrefix = false
                for _, biomeStep in ipairs(routeDeclaration.biomeSteps) do
                    local plan = route.biomePlans.lookup[biomeStep.key]
                    local layout = plan and layouts[plan.layoutKind] or nil
                    local selectorSet = selectors.biomes.lookup[biomeStep.key]
                    if plan == nil or layout == nil or selectorSet == nil then
                        error("configured biome '" .. biomeStep.key
                            .. "' has no authored editor implementation", 0)
                    end
                    local topology = plan:bind(access):readTopology()
                    local view = layout:project(plan, topology, selectorSet)
                    routeView.biomes.ordered[#routeView.biomes.ordered + 1] = view
                    routeView.biomes.lookup[view.key] = view
                    routeView.navTabs[#routeView.navTabs + 1] = {
                        key = view.key,
                        label = view.label,
                    }
                    if biomeStep.key == configuredPrefix then
                        reachedPrefix = true
                        break
                    end
                end
                if not reachedPrefix then
                    error("route '" .. routeDeclaration.key .. "' configured prefix '"
                        .. configuredPrefix .. "' is outside authored editor support", 0)
                end
            end
            nextResult.routes.ordered[#nextResult.routes.ordered + 1] = routeView
            nextResult.routes.lookup[routeView.key] = routeView
        end
        published = nextResult
        return nextResult
    end

    function coordinator.get(_)
        return published
    end

    function coordinator.uiPlan(_, ui, biomeStepKey)
        local plan = route.biomePlans.lookup[biomeStepKey]
        if plan == nil then
            error("unknown authored biome plan '" .. tostring(biomeStepKey) .. "'", 0)
        end
        return plan:bind(stateAccess.createUi(ui, catalog))
    end

    return coordinator
end

return authoredResult
