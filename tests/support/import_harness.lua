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

return importHarness
