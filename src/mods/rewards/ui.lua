local deps = ... or {}
local runtime = deps.runtime

local ui = {}

local function isControlVisible(control, fields)
    local condition = control and control.visibleWhen
    if condition == nil then
        return true
    end
    return fields:read(condition.alias) == condition.value
end

function ui.draw(draw, surface, fields)
    if runtime ~= nil and not runtime.hasControls(surface) then
        return false
    end
    if surface == nil or fields == nil then
        return false
    end

    local drew = false
    local imgui = draw.imgui
    for _, control in ipairs(surface.controls or {}) do
        if isControlVisible(control, fields) then
            if drew then
                imgui.SameLine()
            end
            draw.widgets.dropdown(fields:get(control.alias), control.drawOpts)
            drew = true
        end
    end
    return drew
end

return ui
