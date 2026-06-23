-- luacheck: no unused args

local deps = ...
local data = deps.data
local rewardSystem = deps.rewards
local decorations = deps.decorations
local rewardRatio = deps.rewardRatio

local rewards = {}

local REWARD_COLUMN_X = 130
local ENCOUNTER_REWARD_COLUMN_X = 260
local REWARD_DRAW_OPTS = {
    hideGenericRewardLabel = true,
}

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

local function encounterRewardFields(control, encounterRewardRowIndex, rowIndex, legIndex)
    control._encounterRewardFieldsByRow = control._encounterRewardFieldsByRow or {}
    local fields = control._encounterRewardFieldsByRow[encounterRewardRowIndex]
    if fields == nil then
        fields = {
            rewardContext = {
                rowIndex = rowIndex,
                address = "encounter:" .. tostring(legIndex),
                sourceKind = "encounter",
                sourceIndex = legIndex,
                storageRowIndex = encounterRewardRowIndex,
            },
            get = function(_, alias)
                return control:encounterRewardField(encounterRewardRowIndex, alias)
            end,
            read = function(_, alias)
                return control:fields().EncounterRewards:read(encounterRewardRowIndex, alias)
            end,
        }
        control._encounterRewardFieldsByRow[encounterRewardRowIndex] = fields
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

local function drawEncounterRewardRows(draw, control, instance, rowIndex)
    local imgui = draw.imgui
    for legIndex = 1, data.encounterRewardLegCountForRow(instance, control:routeRows(), rowIndex) do
        local leg = data.encounterRewardLegForRow(instance, control:routeRows(), rowIndex, legIndex)
        local encounterRewardRowIndex = data.encounterRewardRowIndex(instance, rowIndex, legIndex)
        local legSurface = leg ~= nil and rewardSystem and rewardSystem.surfaceFor(leg.reward) or nil
        if encounterRewardRowIndex ~= nil
            and rewardSystem ~= nil
            and rewardSystem ~= nil
            and rewardSystem.hasControls(legSurface)
        then
            if legIndex == 1 then
                imgui.SameLine()
            else
                imgui.Spacing()
            end
            imgui.SetCursorPosX(REWARD_COLUMN_X)
            imgui.AlignTextToFramePadding()
            imgui.Text(tostring(leg.label or leg.key or "Reward"))
            imgui.SameLine()
            imgui.SetCursorPosX(ENCOUNTER_REWARD_COLUMN_X)
            drawRewardSurface(
                draw,
                control,
                legSurface,
                encounterRewardFields(control, encounterRewardRowIndex, rowIndex, legIndex),
                rewardDrawOpts(control)
            )
        end
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
    drawEncounterRewardRows(draw, control, instance, rowIndex)

    if rewardSystem ~= nil
        and rewardSystem ~= nil
        and rewardSystem.hasControls(surface)
    then
        imgui.SameLine()
        imgui.SetCursorPosX(REWARD_COLUMN_X)
        drawRewardSurface(draw, control, surface, rewardFields(control, rowIndex), rewardDrawOpts(control))
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
    local allRowsInactive, inactiveAfterRouteOrdinal = decorations.routeInactiveBoundary(instance)
    rewardRatio.drawInfoLine(draw.imgui, decorations, control:rewardRatioSummary())
    control:beginReadPass()
    for rowIndex = 1, rowCount do
        if drewRow then
            drawRouteRowSeparator(draw.imgui)
        end
        local inactive = decorations.pushInactive(
            draw.imgui,
            decorations.routeRowInactive(allRowsInactive, inactiveAfterRouteOrdinal, control:slot(rowIndex))
        )
        drawRewardRow(draw, control, instance, rowIndex)
        decorations.popInactive(draw.imgui, inactive)
        drewRow = true
    end
    control:endReadPass()
end

return rewards
