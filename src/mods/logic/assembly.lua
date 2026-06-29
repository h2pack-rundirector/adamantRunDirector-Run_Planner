local assembly = {}

function assembly.create(opts)
    opts = opts or {}

    local catalog = opts.catalog

    return import("mods/logic.lua", nil, {
        catalog = catalog,
        liveGameValidator = import("mods/biomes/live_validator.lua"),
        rewards = opts.rewards,
    })
end

return assembly
