local deps = ... or {}
local valueStates = deps.valueStates or import("mods/route/value_states.lua")

local decorations = {}

local INVALID_COLOR = { 1.0, 0.24, 0.16, 1.0 }
local VALID_COLOR = { 0.35, 0.9, 0.45, 1.0 }
local INVALID_VALUE_COLOR = { 1.0, 0.22, 0.16, 1.0 }
local WARNING_VALUE_COLOR = { 1.0, 0.78, 0.18, 1.0 }
local EMPTY_LIST = {}

local function clearMap(map)
    for key in pairs(map) do
        map[key] = nil
    end
end

local function pushTextColor(imgui, color)
    local textEnum = imgui.ImGuiCol and imgui.ImGuiCol.Text or 0
    imgui.PushStyleColor(textEnum, color[1], color[2], color[3], color[4] or 1)
end

local function popTextColor(imgui)
    imgui.PopStyleColor()
end

local function isRewardInvalid(invalid)
    return invalid ~= nil and (invalid.rewardType ~= nil or invalid.address ~= nil)
end

local function isSideInvalid(invalid)
    local address = invalid and invalid.address or nil
    return invalid ~= nil
        and (
            invalid.tabKey == "sideRooms"
            or invalid.sourceKind == "side"
            or (type(address) == "string" and string.sub(address, 1, 5) == "side:")
        )
end

local function invalidRows(routeSnapshot)
    return routeSnapshot and routeSnapshot.invalidRows or EMPTY_LIST
end

local function invalidMatchesControl(invalid, controlName, biomeKey)
    if invalid == nil then
        return false
    end
    if controlName ~= nil and invalid.controlName == controlName then
        return true
    end
    return biomeKey ~= nil and invalid.controlName == nil and invalid.biomeKey == biomeKey
end

local function invalidMatchesNavTab(invalid, tab)
    if invalid == nil or tab == nil then
        return false
    end
    if invalid.controlName ~= nil then
        for _, controlName in ipairs(tab.controlNames or EMPTY_LIST) do
            if invalid.controlName == controlName then
                return true
            end
        end
        return false
    end
    return invalid.biomeKey ~= nil and invalid.biomeKey == tab.key
end

local function invalidMatchesPlannerTab(invalid, controlName, biomeKey, tabKey)
    if not invalidMatchesControl(invalid, controlName, biomeKey) then
        return false
    end

    if tabKey == "rewards" then
        return isRewardInvalid(invalid) and not isSideInvalid(invalid)
    end
    if tabKey == "rooms" then
        return not isRewardInvalid(invalid) and not isSideInvalid(invalid)
    end
    if tabKey == "sideRooms" then
        return isSideInvalid(invalid)
    end
    return false
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

function decorations.invalidColor()
    return INVALID_COLOR
end

function decorations.validColor()
    return VALID_COLOR
end

function decorations.warningValueColor()
    return WARNING_VALUE_COLOR
end

function decorations.beginTabItem(imgui, label, invalid)
    if invalid then
        pushTextColor(imgui, INVALID_COLOR)
    end
    local opened = imgui.BeginTabItem(label)
    if invalid then
        popTextColor(imgui)
    end
    return opened
end

function decorations.beginPlannerTabItem(imgui, label, control, instance, tabKey)
    return decorations.beginTabItem(imgui, label, decorations.plannerTabInvalid(control, tabKey, instance))
end

function decorations.setNavTabInvalid(tab, invalid)
    tab.color = invalid and INVALID_COLOR or nil
end

function decorations.plannerTabInvalid(control, tabKey, instance)
    local routeSnapshot = instance.routeContext:overview(instance.routeKey)
    local controlName = control:name()
    local biomeKey = instance.biomeKey
    for _, invalid in ipairs(invalidRows(routeSnapshot)) do
        if invalidMatchesPlannerTab(invalid, controlName, biomeKey, tabKey) then
            return true
        end
    end
    return false
end

function decorations.routeTabInvalid(routeSnapshot)
    return invalidRows(routeSnapshot)[1] ~= nil
end

function decorations.navTabInvalid(routeSnapshot, tab)
    for _, invalid in ipairs(invalidRows(routeSnapshot)) do
        if invalidMatchesNavTab(invalid, tab) then
            return true
        end
    end
    return false
end

function decorations.decorateDropdown(owner, baseOpts, states, opts)
    if states == nil then
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

function decorations.drawColoredText(imgui, color, text)
    imgui.TextColored(color[1], color[2], color[3], color[4], text)
end

function decorations.drawText(imgui, color, text)
    pushTextColor(imgui, color)
    imgui.Text(text)
    popTextColor(imgui)
end

function decorations.drawWrappedText(imgui, color, text)
    pushTextColor(imgui, color)
    imgui.TextWrapped(text)
    popTextColor(imgui)
end

function decorations.checkboxWithTextColor(imgui, label, current, color)
    pushTextColor(imgui, color)
    local nextValue, changed = imgui.Checkbox(label, current)
    popTextColor(imgui)
    return nextValue, changed
end

return decorations
