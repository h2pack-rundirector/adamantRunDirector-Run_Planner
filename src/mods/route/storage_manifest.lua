local storageManifest = {}

function storageManifest.build(catalog, topologyLayouts)
    local result = {
        moduleStorage = {},
        biomes = { ordered = {}, lookup = {} },
    }
    for _, biome in ipairs(catalog.biomes.ordered) do
        local layout = topologyLayouts[biome.layout.kind]
        if layout == nil or type(layout.storage) ~= "function" then
            error("missing storage codec for layout kind '" .. biome.layout.kind .. "'", 0)
        end
        local descriptor = layout.storage(catalog, biome)
        if descriptor.layoutKind ~= biome.layout.kind then
            error(
                "biome '" .. biome.biomeStepKey .. "' storage codec returned layout kind '"
                    .. tostring(descriptor.layoutKind) .. "'",
                0
            )
        end
        for _, root in ipairs(descriptor.roots) do
            result.moduleStorage[#result.moduleStorage + 1] = root.storage
        end
        result.biomes.ordered[#result.biomes.ordered + 1] = descriptor
        result.biomes.lookup[descriptor.key] = descriptor
    end
    return result
end

return storageManifest
