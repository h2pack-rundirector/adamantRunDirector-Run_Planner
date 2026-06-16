local ui = {}

local roomRoutingOpts = {
    label = "Room Routing",
}
local rewardRoutingOpts = {
    label = "Reward Routing",
}
local planModeOpts

function ui.bind(deps)
    planModeOpts = {
        label = "Plan Mode",
        values = deps.PLAN_MODE_VALUES,
        controlWidth = 180,
    }
    return ui
end

function ui.drawQuickContent(_, ctx)
    local draw = ctx.draw
    local state = ctx.data

    draw.widgets.checkbox(state.get("RoomRoutingEnabled"), roomRoutingOpts)
    draw.widgets.checkbox(state.get("RewardRoutingEnabled"), rewardRoutingOpts)
end

function ui.drawTab(_, ctx)
    local draw = ctx.draw
    local state = ctx.data

    draw.widgets.checkbox(state.get("RoomRoutingEnabled"), roomRoutingOpts)
    draw.widgets.checkbox(state.get("RewardRoutingEnabled"), rewardRoutingOpts)
    draw.widgets.dropdown(state.get("PlanMode"), planModeOpts)
end

return ui
