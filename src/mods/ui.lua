local ui = {}

local TITLE = "Run Planner fresh start"
local BODY = "Legacy planner code is unwired on this branch. The fresh planner spine will be rebuilt from docs/fresh_start."

local function drawText(imgui, text)
    if imgui ~= nil and imgui.Text ~= nil then
        imgui.Text(text)
    end
end

function ui.drawTab(_, ctx)
    local draw = ctx and ctx.draw or nil
    local imgui = draw and draw.imgui or nil

    drawText(imgui, TITLE)
    if imgui ~= nil and imgui.Spacing ~= nil then
        imgui.Spacing()
    end
    drawText(imgui, BODY)
end

return ui
