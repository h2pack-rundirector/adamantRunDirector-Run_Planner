-- luacheck: no unused args

local deps = ...
local rooms = deps.rooms
local rewards = deps.rewards

local planner = {}

local function rewardsConfigured(control)
    return control.rewardsConfigured == nil or control:rewardsConfigured()
end

function planner.draw(draw, control, instance)
    local imgui = draw.imgui
    local tabId = tostring(control:name()) .. "RoutePlanTabs"
    if not imgui.BeginTabBar(tabId) then
        rooms.draw(draw, control, instance)
        return
    end
    if imgui.BeginTabItem("Rooms") then
        rooms.draw(draw, control, instance)
        imgui.EndTabItem()
    end
    if rewardsConfigured(control) and imgui.BeginTabItem("Rewards") then
        rewards.draw(draw, control, instance)
        imgui.EndTabItem()
    end
    imgui.EndTabBar()
end

return planner
