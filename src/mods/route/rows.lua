local deps = ...

local rewards = deps.rewards

local timeline = deps.timeline

local valueStates = import("mods/route/value_states.lua")
local common = import("mods/route/rows/common.lua")
local availability = import("mods/route/rows/availability.lua")
local readCache = import("mods/route/rows/read_cache.lua")
local requirements = import("mods/route/rows/requirements.lua", nil, {
    common = common,
    rewards = rewards,
})
local biomeRules = import("mods/route/rows/biome_rules.lua", nil, {
    common = common,
})

return {
    common = common,
    availability = availability,
    readCache = readCache,
    requirements = requirements,
    biomeRules = biomeRules,
    engine = import("mods/route/rows/engine.lua", nil, {
        common = common,
        availability = availability,
        readCache = readCache,
        requirements = requirements,
        biomeRules = biomeRules,
        valueStates = valueStates,
        timeline = timeline,
        rewards = rewards,
    }),
    valueStates = valueStates,
}
