local deps = ... or {}
local catalog = deps.catalog

local runtime = {}

local function isControlVisible(control, fields)
    local condition = control and control.visibleWhen
    if condition == nil then
        return true
    end
    return fields:read(condition.alias) == condition.value
end

function runtime.snapshot(surface, fields)
    local picks = {}
    if surface == nil or fields == nil then
        return picks
    end

    for _, control in ipairs(surface.controls or {}) do
        if isControlVisible(control, fields) then
            local value = fields:read(control.alias) or ""
            if value ~= "" then
                picks[#picks + 1] = {
                    key = control.key,
                    kind = control.kind,
                    alias = control.alias,
                    value = value,
                }
            end
        end
    end
    return picks
end

function runtime.surfaceFor(context)
    if catalog == nil then
        return {
            kind = "none",
            controls = {},
        }
    end
    return catalog:surfaceFor(context)
end

function runtime.hasControls(surface)
    return surface ~= nil and surface.controls ~= nil and surface.controls[1] ~= nil
end

return runtime
