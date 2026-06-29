local historyAssembly = {}

function historyAssembly.create()
    local events = import("mods/route/history/events.lua")
    local history = import("mods/route/history/history.lua", nil, {
        events = events,
    })
    local query = import("mods/route/history/query.lua", nil, {
        events = events,
        history = history,
    })
    local adapters = {
        clockworkGoal = import("mods/route/history/adapters/clockwork_goal.lua"),
        fieldsCageRoute = import("mods/route/history/adapters/fields_cage.lua"),
        fixedLinear = import("mods/route/history/adapters/fixed_linear.lua"),
        multiEncounterFixed = import("mods/route/history/adapters/multi_encounter_fixed.lua"),
    }
    local builder = import("mods/route/history/builder.lua", nil, {
        history = history,
        adapters = adapters,
    })

    return {
        adapters = adapters,
        events = events,
        history = history,
        query = query,
        builder = builder,
    }
end

return historyAssembly
