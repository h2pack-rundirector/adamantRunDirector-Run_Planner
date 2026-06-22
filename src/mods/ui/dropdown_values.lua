local deps = ... or {}
local valueStates = deps.valueStates or import("mods/route/value_states.lua")
local dropdownValues = {}

local INVALID_VALUE_COLOR = { 1.0, 0.22, 0.16, 1.0 }
local WARNING_VALUE_COLOR = { 1.0, 0.78, 0.18, 1.0 }

local function clearMap(map)
    for key in pairs(map) do
        map[key] = nil
    end
end

local function colorForState(state, opts)
    if state == nil or state == false or state == 0 then
        return nil
    end
    if state == valueStates.INVALID then
        return (opts and opts.invalidColor) or INVALID_VALUE_COLOR
    elseif state == valueStates.WARNING then
        return (opts and opts.warningColor) or WARNING_VALUE_COLOR
    end
    return nil
end

local function visibilityForState(state)
    if state == valueStates.HIDDEN then
        return false
    end
    return nil
end

local function fillValueColors(owner, states, opts)
    local colors = owner._decoratedDropdownValueColors
    if colors == nil then
        colors = {}
        owner._decoratedDropdownValueColors = colors
    else
        clearMap(colors)
    end

    local hasColors = false
    for key, state in pairs(states or {}) do
        local color = colorForState(state, opts)
        if color ~= nil then
            colors[key] = color
            hasColors = true
        end
    end
    if hasColors then
        return colors
    end
    return nil
end

local function fillVisibleValues(owner, states)
    local visible = owner._decoratedDropdownVisibleValues
    if visible == nil then
        visible = {}
        owner._decoratedDropdownVisibleValues = visible
    else
        clearMap(visible)
    end

    local hasVisibility = false
    for key, state in pairs(states or {}) do
        local isVisible = visibilityForState(state)
        if isVisible ~= nil then
            visible[key] = isVisible
            hasVisibility = true
        end
    end
    if hasVisibility then
        return visible
    end
    return nil
end

local function decoratedOpts(owner, baseOpts)
    local target = owner._decoratedDropdownOpts
    if target == nil then
        target = {}
        owner._decoratedDropdownOpts = target
    else
        clearMap(target)
    end

    for key, value in pairs(baseOpts or {}) do
        if key ~= "_decoratedDropdownOpts"
            and key ~= "_decoratedDropdownValueColors"
            and key ~= "_decoratedDropdownVisibleValues"
        then
            target[key] = value
        end
    end
    return target
end

local function mergedMap(owner, cacheKey, base, overlay)
    if base == nil then
        return overlay
    end

    local target = owner[cacheKey]
    if target == nil then
        target = {}
        owner[cacheKey] = target
    else
        clearMap(target)
    end

    for key, value in pairs(base) do
        target[key] = value
    end
    for key, value in pairs(overlay) do
        target[key] = value
    end
    return target
end

function dropdownValues.decorate(owner, baseOpts, states, opts)
    if owner == nil or states == nil then
        return baseOpts
    end

    local valueColors = fillValueColors(owner, states, opts)
    local visibleValues = fillVisibleValues(owner, states)
    if valueColors == nil and visibleValues == nil then
        return baseOpts
    end

    local target = decoratedOpts(owner, baseOpts)
    if valueColors ~= nil then
        target.valueColors = mergedMap(
            owner,
            "_decoratedDropdownMergedValueColors",
            baseOpts and baseOpts.valueColors or nil,
            valueColors
        )
    end
    if visibleValues ~= nil then
        target.visibleValues = mergedMap(
            owner,
            "_decoratedDropdownMergedVisibleValues",
            baseOpts and baseOpts.visibleValues or nil,
            visibleValues
        )
    end
    return target
end

return dropdownValues
