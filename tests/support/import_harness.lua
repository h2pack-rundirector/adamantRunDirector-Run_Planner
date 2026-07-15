local harness = {}

function harness.testImport(path, _, deps)
    return assert(loadfile("src/" .. path))(deps)
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
    return harness.testImport("mods/catalog/declarations.lua")
end

return harness
