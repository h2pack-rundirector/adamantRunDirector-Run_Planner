local importHarness = {}

function importHarness.testImport(path, _, deps)
    local chunk = assert(loadfile("src/" .. path))
    return chunk(deps)
end

function importHarness.withTestImport(callback)
    local previousImport = _G.import
    _G.import = importHarness.testImport
    local ok, result = pcall(callback)
    _G.import = previousImport
    if not ok then
        error(result, 0)
    end
    return result
end

function importHarness.loadGodData()
    return importHarness.withTestImport(function()
        return importHarness.testImport("mods/data/gods.lua")
    end)
end

function importHarness.loadRouteRules(godData)
    return importHarness.withTestImport(function()
        return importHarness.testImport("mods/biomes/declaration_rules.lua")({
            godData = godData or importHarness.loadGodData(),
        })
    end)
end

function importHarness.loadRewardDomain(godData)
    return importHarness.withTestImport(function()
        return importHarness.testImport("mods/rewards/assembly.lua").create({
            godData = godData or importHarness.loadGodData(),
        }).rewardDomain
    end)
end

function importHarness.loadRewardConditions(godData)
    return importHarness.withTestImport(function()
        return importHarness.testImport("mods/rewards/declarations/conditions.lua")({
            godData = godData or importHarness.loadGodData(),
        })
    end)
end

function importHarness.loadRewards(godData, routeRules)
    local loadedGodData = godData or importHarness.loadGodData()
    local loadedRouteRules = routeRules or importHarness.loadRouteRules(loadedGodData)
    return importHarness.withTestImport(function()
        return importHarness.testImport("mods/rewards/rewards.lua").create({
            godData = loadedGodData,
            routeRules = loadedRouteRules,
        })
    end)
end

function importHarness.loadCatalogDeps()
    local godData = importHarness.loadGodData()
    local routeRules = importHarness.loadRouteRules(godData)
    local rewards = importHarness.loadRewards(godData, routeRules)
    return {
        godData = godData,
        routeRules = routeRules,
        rewards = rewards,
    }
end

function importHarness.loadCatalog()
    local data = dofile("src/mods/data.lua")
    return importHarness.withTestImport(function()
        return data.loadCatalog(importHarness.loadCatalogDeps())
    end)
end

return importHarness
