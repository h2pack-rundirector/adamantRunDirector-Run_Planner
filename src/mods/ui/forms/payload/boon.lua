local identity = import("mods/ui/forms/identity.lua")
local widgets = import("mods/ui/planner/widgets.lua")

local boon = {}

function boon.draw(state, imgui, context, offer)
    local form = identity.generatedOffer(context, 1)
    offer.payload = offer.payload or state.defaultPayloadForRewardType("Boon")
    local nextSource, changed = widgets.dropdown(
        imgui,
        identity.control(form, "Source", "payloadSource"),
        offer.payload.source,
        state.boonSourceOptions
    )
    if changed then
        state.setBoonSource(context.roomIndex, context.doorIndex, nextSource)
    end
end

return boon
