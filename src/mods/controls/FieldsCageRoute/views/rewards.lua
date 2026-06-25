-- luacheck: no unused args

local deps = ...
local data = deps.data
local rewardSystem = deps.rewards
local decorations = deps.decorations

local rewards = {}

local REWARD_COLUMN_X = 130
local REWARD_DRAW_OPTS = {
    hideGenericRewardLabel = true,
}
local SIBLING_STRUCTURE_OPTS = {
    label = "",
    controlWidth = 130,
}

local function copyBaseOpts(base)
    local copy = {}
    for key, value in pairs(base or {}) do
        copy[key] = value
    end
    return copy
end

local function rewardDrawOpts(control, rowIndex)
    local sourceCount = control:rewardSourceCount(rowIndex)
    if control.rewardDrawOpts ~= nil then
        local opts = control:rewardDrawOpts(REWARD_DRAW_OPTS)
        opts.sourceCount = sourceCount
        return opts
    end
    if sourceCount ~= nil then
        control._rewardDrawOptsBySourceCount = control._rewardDrawOptsBySourceCount or {}
        local opts = control._rewardDrawOptsBySourceCount[sourceCount]
        if opts == nil then
            opts = {
                hideGenericRewardLabel = true,
                sourceCount = sourceCount,
            }
            control._rewardDrawOptsBySourceCount[sourceCount] = opts
        end
        return opts
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

local function drawRewardSurface(draw, control, surface, fields, opts)
    if rewardSystem.draw(draw, surface, fields, opts) and (opts == nil or opts.onControlChanged == nil) then
        control:invalidateReadPass()
    end
end

local function shouldDrawSiblingStructure(control, instance, rowIndex)
    local roleKey = data.resolveRole(instance, control:routeRows(), rowIndex)
    return roleKey == "Combat" or roleKey == "Miniboss" or roleKey == "Bridge"
end

local function siblingStructureOpts(control, instance, rowIndex)
    control._siblingStructureOptsByRow = control._siblingStructureOptsByRow or {}
    local opts = control._siblingStructureOptsByRow[rowIndex]
    if opts == nil then
        opts = copyBaseOpts(SIBLING_STRUCTURE_OPTS)
        opts.values = data.siblingStructureValues(instance)
        opts.displayValues = data.siblingStructureLabels(instance)
        control._siblingStructureOptsByRow[rowIndex] = opts
    end
    return decorations.decorateDropdown(
        opts,
        opts,
        data.siblingStructureValueStatesForRow(instance, control:routeRows(), rowIndex)
    )
end

local function drawSiblingStructure(draw, control, instance, rowIndex)
    if not shouldDrawSiblingStructure(control, instance, rowIndex) then
        return
    end

    local opts = siblingStructureOpts(control, instance, rowIndex)
    if opts.values[1] == nil then
        return
    end

    local imgui = draw.imgui
    imgui.Spacing()
    imgui.AlignTextToFramePadding()
    imgui.Text("Sibling")
    imgui.SameLine()
    imgui.SetCursorPosX(REWARD_COLUMN_X)
    if draw.widgets.dropdown(control:roomField(rowIndex, data.siblingStructureAlias(instance)), opts) then
        control:invalidateReadPass()
    end
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
        and (control:rewardSourceCount(rowIndex) or 1) > 0
    then
        imgui.SameLine()
        imgui.SetCursorPosX(REWARD_COLUMN_X)
        drawRewardSurface(draw, control, surface, rewardFields(control, rowIndex), rewardDrawOpts(control, rowIndex))
    end
    drawSiblingStructure(draw, control, instance, rowIndex)
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
