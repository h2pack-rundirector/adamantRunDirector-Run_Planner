local debugHarness = import("mods/ui/debug_harness.lua")

local ui = {}
local defaultInstance

function ui.create(opts)
    return debugHarness.create(opts)
end

function ui.drawTab(_, ctx)
    if defaultInstance == nil then
        defaultInstance = debugHarness.create()
    end
    return defaultInstance.drawTab(nil, ctx)
end

return ui
