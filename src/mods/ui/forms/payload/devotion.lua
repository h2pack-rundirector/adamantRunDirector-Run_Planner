local identity = import("mods/ui/forms/identity.lua")
local widgets = import("mods/ui/planner/widgets.lua")

local devotion = {}

function devotion.draw(state, imgui, context, offer)
    local form = identity.generatedOffer(context, 1)
    offer.payload = offer.payload or state.defaultPayloadForRewardType("Devotion")
    offer.payload.sources = offer.payload.sources or state.defaultPayloadForRewardType("Devotion").sources
    for sourceIndex = 1, 2 do
        local providers = offer.candidateProviders or {}
        local providerKey = "devotionSource" .. tostring(sourceIndex)
        local options = providers[providerKey] or state.boonSourceOptions
        local nextSource, changed = widgets.dropdown(
            imgui,
            identity.control(form, "Source " .. tostring(sourceIndex), "devotionSource" .. tostring(sourceIndex)),
            offer.payload.sources[sourceIndex],
            options
        )
        if changed then
            state.setDevotionSource(context.roomIndex, context.doorIndex, sourceIndex, nextSource)
        end
    end
end

return devotion
