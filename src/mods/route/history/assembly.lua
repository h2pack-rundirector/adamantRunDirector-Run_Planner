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
    local builder = import("mods/route/history/builder.lua", nil, {
        history = history,
    })

    return {
        events = events,
        history = history,
        query = query,
        builder = builder,
    }
end

return historyAssembly
