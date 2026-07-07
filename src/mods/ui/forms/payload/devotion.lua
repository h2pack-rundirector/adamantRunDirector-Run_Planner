local widgets = import("mods/ui/planner/widgets.lua")

local devotion = {}

function devotion.draw(state, imgui, context, offer)
    offer.payload = offer.payload or state.defaultPayloadForRewardType("Devotion")
    offer.payload.sources = offer.payload.sources or state.defaultPayloadForRewardType("Devotion").sources
    for sourceIndex = 1, 2 do
        local providers = offer.candidateProviders or {}
        local providerKey = "devotionSource" .. tostring(sourceIndex)
        local options = providers[providerKey] or state.boonSourceOptions
        local nextSource, changed = widgets.dropdown(
            imgui,
            "Source " .. tostring(sourceIndex) .. "##room" .. context.roomIndex .. "_door" .. context.doorIndex,
            offer.payload.sources[sourceIndex],
            options
        )
        if changed then
            state.setDevotionSource(context.roomIndex, context.doorIndex, sourceIndex, nextSource)
        end
    end
end

return devotion
