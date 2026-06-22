local tabStatus = {}

local INVALID_COLOR = { 1.0, 0.24, 0.16, 1.0 }
local EMPTY_LIST = {}

local function pushTextColor(imgui, color)
    if imgui.PushStyleColor == nil or color == nil then
        return false
    end

    local textEnum = imgui.ImGuiCol and imgui.ImGuiCol.Text or 0
    imgui.PushStyleColor(textEnum, color[1], color[2], color[3], color[4] or 1)
    return true
end

local function popTextColor(imgui, pushed)
    if pushed and imgui.PopStyleColor ~= nil then
        imgui.PopStyleColor()
    end
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

local function hasInvalid(routeSnapshot)
    return invalidRows(routeSnapshot)[1] ~= nil
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

function tabStatus.invalidColor()
    return INVALID_COLOR
end

function tabStatus.beginTabItem(imgui, label, invalid)
    local pushed = invalid and pushTextColor(imgui, INVALID_COLOR)
    local opened = imgui.BeginTabItem(label)
    popTextColor(imgui, pushed)
    return opened
end

function tabStatus.beginPlannerTabItem(imgui, label, control, instance, tabKey)
    return tabStatus.beginTabItem(imgui, label, tabStatus.plannerTabInvalid(control, tabKey, instance))
end

function tabStatus.setNavTabInvalid(tab, invalid)
    if tab == nil then
        return
    end
    tab.color = invalid and INVALID_COLOR or nil
end

function tabStatus.plannerTabInvalid(control, tabKey, instance)
    local routeContext = instance and instance.routeContext or nil
    local routeSnapshot = routeContext and routeContext.overview and routeContext:overview(instance.routeKey) or nil
    local controlName = control and control:name()
    local biomeKey = instance and instance.biomeKey
    for _, invalid in ipairs(invalidRows(routeSnapshot)) do
        if invalidMatchesPlannerTab(invalid, controlName, biomeKey, tabKey) then
            return true
        end
    end
    return false
end

function tabStatus.routeTabInvalid(routeSnapshot)
    return hasInvalid(routeSnapshot)
end

function tabStatus.navTabInvalid(routeSnapshot, tab)
    for _, invalid in ipairs(invalidRows(routeSnapshot)) do
        if invalidMatchesNavTab(invalid, tab) then
            return true
        end
    end
    return false
end

return tabStatus
