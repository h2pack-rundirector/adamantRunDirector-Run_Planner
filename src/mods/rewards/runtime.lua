local deps = ... or {}
local catalog = deps.catalog

local runtime = {}

local function conditionMatches(condition, fields)
    return fields:read(condition.alias) == condition.value
end

local function sourceActive(sourceIndex, opts)
    if sourceIndex == nil then
        return true
    end
    local sourceCount = opts and opts.sourceCount or nil
    if sourceCount == nil then
        return true
    end
    return sourceIndex <= sourceCount
end

local function conditionActive(condition, fields)
    if condition == nil then
        return true
    end
    for _, item in ipairs(condition.any or {}) do
        if conditionActive(item, fields) then
            return true
        end
    end
    if condition.any ~= nil then
        return false
    end
    for _, item in ipairs(condition.all or {}) do
        if not conditionActive(item, fields) then
            return false
        end
    end
    if condition.all ~= nil then
        return true
    end
    return conditionMatches(condition, fields)
end

local function isControlVisible(control, fields, opts)
    return sourceActive(control and control.sourceIndex or nil, opts)
        and conditionActive(control and control.visibleWhen or nil, fields)
end

function runtime.snapshot(surface, fields, opts)
    local picks = {}
    local selectionRequirements = {}
    if surface == nil or fields == nil then
        return picks, selectionRequirements
    end

    for _, control in ipairs(surface.controls or {}) do
        if isControlVisible(control, fields, opts) then
            local value = fields:read(control.alias) or control.defaultValue or ""
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
                if control.sourceIndex ~= nil then
                    pick.sourceIndex = control.sourceIndex
                end
                if control.rewardAddress ~= nil then
                    pick.rewardAddress = control.rewardAddress
                end
                picks[#picks + 1] = pick
            else
                local requirement = {
                    tabKey = "rewards",
                    key = control.key,
                    kind = control.kind,
                    controlAlias = control.alias,
                    label = control.label,
                }
                if control.sourceIndex ~= nil then
                    requirement.sourceIndex = control.sourceIndex
                end
                if control.rewardAddress ~= nil then
                    requirement.address = control.rewardAddress
                end
                selectionRequirements[#selectionRequirements + 1] = requirement
            end
        end
    end
    return picks, selectionRequirements
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

function runtime.hasDisplay(surface)
    return runtime.hasControls(surface) or (surface ~= nil and surface.displayLabel ~= nil)
end

return runtime
