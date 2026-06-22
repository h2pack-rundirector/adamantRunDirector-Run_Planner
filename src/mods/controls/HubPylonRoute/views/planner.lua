-- luacheck: no unused args

local deps = ...
local rooms = deps.rooms
local rewards = deps.rewards
local sideRooms = deps.sideRooms
local decorations = deps.decorations

local planner = {}

local function rewardsConfigured(control)
    return control.rewardsConfigured == nil or control:rewardsConfigured()
end

local function beginTabItem(imgui, label, control, instance, tabKey)
    return decorations.beginPlannerTabItem(imgui, label, control, instance, tabKey)
end

function planner.draw(draw, control, instance)
    local imgui = draw.imgui
    local tabId = tostring(control:name()) .. "RoutePlanTabs"
    if not imgui.BeginTabBar(tabId) then
        rooms.draw(draw, control, instance)
        return
    end
    if beginTabItem(imgui, "Rooms", control, instance, "rooms") then
        rooms.draw(draw, control, instance)
        imgui.EndTabItem()
    end
    if rewardsConfigured(control) and beginTabItem(imgui, "Rewards", control, instance, "rewards") then
        rewards.draw(draw, control, instance)
        imgui.EndTabItem()
    end
    if beginTabItem(imgui, "Side Rooms", control, instance, "sideRooms") then
        sideRooms.draw(draw, control, instance)
        imgui.EndTabItem()
    end
    imgui.EndTabBar()
end

return planner
