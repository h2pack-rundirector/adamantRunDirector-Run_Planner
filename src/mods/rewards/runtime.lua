local deps = ... or {}
local catalog = deps.catalog

local runtime = {}

local function conditionMatches(condition, fields)
    return fields:read(condition.alias) == condition.value
end

local function isControlVisible(control, fields)
    local condition = control and control.visibleWhen
    if condition == nil then
        return true
    end
    for _, item in ipairs(condition.any or {}) do
        if conditionMatches(item, fields) then
            return true
        end
    end
    if condition.any ~= nil then
        return false
    end
    for _, item in ipairs(condition.all or {}) do
        if not conditionMatches(item, fields) then
            return false
        end
    end
    if condition.all ~= nil then
        return true
    end
    return conditionMatches(condition, fields)
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
                local pick = {
                    key = control.key,
                    kind = control.kind,
                    alias = control.alias,
                    value = value,
                }
                if control.rewardStore ~= nil then
                    pick.rewardStore = control.rewardStore
                end
                picks[#picks + 1] = pick
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
