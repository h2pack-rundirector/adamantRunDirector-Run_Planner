-- luacheck: no unused args

local deps = ...
local data = deps.data
local rewardSystem = deps.rewards
local decorations = deps.decorations
local rewardRatio = deps.rewardRatio

local rewards = {}

local DOOR_LABEL_COLUMN_X = 80
local DOOR_CONTROL_COLUMN_X = 190
local PICKED_DOOR_LABEL = "Picked Door"
local SIBLING_REWARD_OPTS = {
    label = "",
    controlWidth = 110,
}
local REWARD_DRAW_OPTS = {
    hideGenericRewardLabel = true,
}

local function copyBaseOpts(base)
    local copy = {}
    for key, value in pairs(base or {}) do
        copy[key] = value
    end
    return copy
end

local function rewardDrawOpts(control)
    if control.rewardDrawOpts ~= nil then
        return control:rewardDrawOpts(REWARD_DRAW_OPTS)
    end
    return REWARD_DRAW_OPTS
end

local function rewardFields(control, rowIndex)
    control._rewardFieldsByRow = control._rewardFieldsByRow or {}
    local fields = control._rewardFieldsByRow[rowIndex]
    if fields == nil then
        fields = {
            rewardContext = {
                rowIndex = rowIndex,
                address = "row",
                sourceKind = "row",
            },
            get = function(_, alias)
                return control:rewardField(rowIndex, alias)
            end,
            read = function(_, alias)
                return control:fields().Rewards:read(rowIndex, alias)
            end,
        }
        control._rewardFieldsByRow[rowIndex] = fields
    end
    return fields
end

local function rewardRowLabel(control, rowIndex, slot)
    local role = control:role(rowIndex)
    if role ~= nil then
        return tostring(role.label or role.key or slot.label)
    end
    return tostring(slot.label)
end

local function drawRewardRowHeader(imgui, control, rowIndex, slot)
    imgui.AlignTextToFramePadding()
    imgui.Text(rewardRowLabel(control, rowIndex, slot))
end

local function drawDoorLabel(imgui, label)
    imgui.SameLine()
    imgui.SetCursorPosX(DOOR_LABEL_COLUMN_X)
    imgui.AlignTextToFramePadding()
    imgui.Text(label)
end

local function drawRewardSurface(draw, control, surface, fields, opts)
    if rewardSystem.draw(draw, surface, fields, opts) and (opts == nil or opts.onControlChanged == nil) then
        control:invalidateReadPass()
    end
end

local function siblingRewardClassOpts(control, instance, siblingIndex)
    control._siblingRewardClassOptsByIndex = control._siblingRewardClassOptsByIndex or {}
    local opts = control._siblingRewardClassOptsByIndex[siblingIndex]
    if opts == nil then
        opts = copyBaseOpts(SIBLING_REWARD_OPTS)
        opts.values = data.siblingRewardClassValues(instance)
        opts.displayValues = data.siblingRewardClassLabels(instance)
        control._siblingRewardClassOptsByIndex[siblingIndex] = opts
    end
    return opts
end

local function siblingRewardClassControl(control, instance, siblingIndex)
    control._siblingRewardClassControlsByIndex = control._siblingRewardClassControlsByIndex or {}
    local surfaceControl = control._siblingRewardClassControlsByIndex[siblingIndex]
    if surfaceControl == nil then
        surfaceControl = {
            alias = data.siblingRewardClassAlias(instance, siblingIndex),
            rewardAddress = data.siblingRewardClassAddress(instance, siblingIndex),
            values = data.siblingRewardClassValues(instance),
        }
        control._siblingRewardClassControlsByIndex[siblingIndex] = surfaceControl
    end
    return surfaceControl
end

local function siblingRewardContext(control, rowIndex, surfaceControl)
    control._siblingRewardContextsByRow = control._siblingRewardContextsByRow or {}
    local contextsByAddress = control._siblingRewardContextsByRow[rowIndex]
    if contextsByAddress == nil then
        contextsByAddress = {}
        control._siblingRewardContextsByRow[rowIndex] = contextsByAddress
    end

    local context = contextsByAddress[surfaceControl.rewardAddress]
    if context == nil then
        context = {
            rowIndex = rowIndex,
            address = surfaceControl.rewardAddress,
        }
        contextsByAddress[surfaceControl.rewardAddress] = context
    end
    return context
end

local function decoratedSiblingRewardClassOpts(control, instance, rowIndex, siblingIndex)
    local opts = siblingRewardClassOpts(control, instance, siblingIndex)
    local surfaceControl = siblingRewardClassControl(control, instance, siblingIndex)
    local rewardContext = siblingRewardContext(control, rowIndex, surfaceControl)
    local states = control:rewardValueStates(
        rowIndex,
        surfaceControl.rewardAddress,
        surfaceControl.alias,
        surfaceControl,
        rewardContext
    )
    return decorations.decorateDropdown(opts, opts, states)
end

local function siblingRewardLabel(instance, activeCount, siblingIndex)
    if (activeCount or 0) > 1 then
        return "Other Door " .. tostring(siblingIndex)
    end
    return "Other Door"
end

local function drawSiblingRewardClassDropdown(draw, control, instance, rowIndex, siblingIndex, activeCount)
    if not data.shouldDrawSiblingRewardClass(instance, control:routeRows(), rowIndex, siblingIndex) then
        return false
    end

    draw.imgui.SetCursorPosX(DOOR_LABEL_COLUMN_X)
    draw.imgui.AlignTextToFramePadding()
    draw.imgui.Text(siblingRewardLabel(instance, activeCount, siblingIndex))
    draw.imgui.SameLine()
    draw.imgui.SetCursorPosX(DOOR_CONTROL_COLUMN_X)
    return draw.widgets.dropdown(
        control:rewardField(rowIndex, data.siblingRewardClassAlias(instance, siblingIndex)),
        decoratedSiblingRewardClassOpts(control, instance, rowIndex, siblingIndex)
    )
end

local function drawSiblingRewardClassDropdowns(draw, control, instance, rowIndex)
    local changed = false
    local activeCount = data.activeSiblingStructureCount(instance, control:routeRows(), rowIndex)
    for siblingIndex = 1, data.maxSiblingStructureCount(instance) do
        if drawSiblingRewardClassDropdown(draw, control, instance, rowIndex, siblingIndex, activeCount) then
            changed = true
        end
    end
    return changed
end

local function drawRewardRow(draw, control, instance, rowIndex)
    local slot = control:slot(rowIndex)
    if slot == nil then
        return
    end

    local imgui = draw.imgui
    local surface = control:rewardSurface(rowIndex)

    drawRewardRowHeader(imgui, control, rowIndex, slot)
    if rewardSystem ~= nil
        and rewardSystem ~= nil
        and rewardSystem.hasDisplay(surface)
    then
        drawDoorLabel(imgui, PICKED_DOOR_LABEL)
        imgui.SameLine()
        imgui.SetCursorPosX(DOOR_CONTROL_COLUMN_X)
        drawRewardSurface(draw, control, surface, rewardFields(control, rowIndex), rewardDrawOpts(control))
    end
    if drawSiblingRewardClassDropdowns(draw, control, instance, rowIndex) then
        control:invalidateReadPass()
    end
end

local function drawRouteRowSeparator(imgui)
    imgui.Spacing()
    imgui.Separator()
    imgui.Spacing()
end

function rewards.draw(draw, control, instance)
    local rowCount = control:rowCount()
    local drewRow = false
    local allRowsInactive, inactiveBoundary = decorations.routeInactiveBoundary(instance)
    rewardRatio.drawInfoLine(draw.imgui, decorations, control:rewardRatioSummary())
    control:beginReadPass()
    for rowIndex = 1, rowCount do
        if drewRow then
            drawRouteRowSeparator(draw.imgui)
        end
        local inactive = decorations.pushInactive(
            draw.imgui,
            decorations.routeRowInactive(allRowsInactive, inactiveBoundary, control:slot(rowIndex), "rewards")
        )
        drawRewardRow(draw, control, instance, rowIndex)
        decorations.popInactive(draw.imgui, inactive)
        drewRow = true
    end
    control:endReadPass()
end

return rewards
