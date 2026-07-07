local widgets = import("mods/ui/planner/widgets.lua")

local boon = {}

function boon.draw(state, imgui, context, offer)
    offer.payload = offer.payload or state.defaultPayloadForRewardType("Boon")
    local nextSource, changed = widgets.dropdown(
        imgui,
        "Source##room" .. context.roomIndex .. "_door" .. context.doorIndex,
        offer.payload.source,
        state.boonSourceOptions
    )
    if changed then
        state.setBoonSource(context.roomIndex, context.doorIndex, nextSource)
    end
end

return boon
