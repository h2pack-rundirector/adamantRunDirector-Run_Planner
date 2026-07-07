local boon = import("mods/ui/forms/payload/boon.lua")
local devotion = import("mods/ui/forms/payload/devotion.lua")

local payload = {}

function payload.draw(state, imgui, context, offer)
    if offer.rewardType == "Boon" then
        boon.draw(state, imgui, context, offer)
    elseif offer.rewardType == "Devotion" then
        devotion.draw(state, imgui, context, offer)
    end
end

return payload
