local harness = {}

function harness.testImport(path)
    return assert(loadfile("src/" .. path))()
end

function harness.withImport(callback)
    local previous = _G.import
    _G.import = harness.testImport
    local ok, result = pcall(callback)
    _G.import = previous
    if not ok then
        error(result, 0)
    end
    return result
end

function harness.rawDeclarations()
    return {
        routes = harness.testImport("mods/biomes/declarations/routes.lua"),
        biomes = harness.testImport("mods/biomes/declarations/init.lua"),
        roomTemplates = harness.testImport("mods/controls/declarations/room_templates.lua"),
        routeTemplates = harness.testImport("mods/controls/declarations/route_templates.lua"),
        batchRules = harness.testImport("mods/controls/declarations/batch_rules.lua"),
        encounterProfiles = harness.testImport("mods/biomes/declarations/encounter_profiles.lua"),
        exitTypes = harness.testImport("mods/biomes/declarations/exit_types.lua"),
        requirements = harness.testImport("mods/route/declarations/requirements.lua"),
        rewards = harness.testImport("mods/rewards/declarations/init.lua"),
    }
end

return harness
