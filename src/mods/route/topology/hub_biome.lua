local deps = ... or {}
local codec = deps.codec or import("mods/route/topology/hub_biome_codec.lua")

local hubBiome = {}

function hubBiome.supports(_)
    return false
end

hubBiome.storage = codec.storage
hubBiome.readAuthored = codec.read
hubBiome.replaceAuthored = codec.replace

return hubBiome
