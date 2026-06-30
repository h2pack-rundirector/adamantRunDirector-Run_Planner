local deps = ...

local rewards = deps.rewards

local timeline = deps.timeline

local valueStates = import("mods/route/value_states.lua")
local common = import("mods/route/rows/common.lua")
local readCache = import("mods/route/rows/read_cache.lua")

return {
    common = common,
    readCache = readCache,
    engine = import("mods/route/rows/engine.lua", nil, {
        common = common,
        readCache = readCache,
        valueStates = valueStates,
        timeline = timeline,
        rewards = rewards,
    }),
    valueStates = valueStates,
}
