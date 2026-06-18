local deps = ... or {}
local runtime = deps.runtime
local routeStatusUi = deps.routeStatusUi

local ui = {}

local ROW_HEADER_WIDTH = 80
local GENERIC_REWARD_HEADER = "Reward"

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

local function drawRowHeader(imgui, header)
    imgui.AlignTextToFramePadding()
    imgui.Text(tostring(header or ""))
    imgui.SameLine()
end

local function drawGroupedRowStart(imgui, startX, header, reserveHeaderColumn)
    if header ~= nil then
        drawRowHeader(imgui, header)
    end
    if header ~= nil or reserveHeaderColumn then
        imgui.SetCursorPosX(startX + ROW_HEADER_WIDTH)
    else
        imgui.SetCursorPosX(startX)
    end
end

local function drawControl(draw, fields, control, opts)
    local field = fields:get(control.alias)
    local drawOpts = control.drawOpts
    if opts ~= nil
        and opts.hideGenericRewardLabel
        and control.genericRewardLabelHiddenDrawOpts ~= nil
    then
        drawOpts = control.genericRewardLabelHiddenDrawOpts
    end
    if control.kind == "boonSource"
        and opts ~= nil
        and opts.godSource ~= nil
        and opts.godSource.godSourceDrawOpts ~= nil
    then
        drawOpts = opts.godSource:godSourceDrawOpts(drawOpts, field:read())
    end
    return draw.widgets.dropdown(field, drawOpts)
end

local function hasGroupedRows(surface)
    if surface.rowHeader ~= nil then
        return true
    end
    for _, control in ipairs(surface.controls or {}) do
        if control.rowIndex ~= nil then
            return true
        end
    end
    return false
end

local function surfaceValidation(surface, fields)
    if runtime == nil
        or runtime.validate == nil
        or surface == nil
        or surface.uniqueOfferGroups == nil
        or surface.uniqueOfferGroups[1] == nil
    then
        return nil
    end
    return runtime.validate(surface, fields)
end

local function aliasIsInvalid(validation, alias)
    if validation == nil or validation.valid or alias == nil then
        return false
    end
    for _, invalidAlias in ipairs(validation.aliases or {}) do
        if invalidAlias == alias then
            return true
        end
    end
    return false
end

local function drawInvalid(draw, validation)
    if routeStatusUi == nil then
        return
    end
    if routeStatusUi.drawInvalidInline ~= nil then
        routeStatusUi.drawInvalidInline(draw, validation)
    elseif routeStatusUi.drawInvalid ~= nil then
        routeStatusUi.drawInvalid(draw, validation)
    end
end

local function drawGroupedControls(draw, surface, fields, opts)
    local imgui = draw.imgui
    local startX = imgui.GetCursorPosX()
    local rowIndex = nil
    local rowInvalid = false
    local drew = false
    local changed = false
    local validation = surfaceValidation(surface, fields)
    local rowHeader = surface.rowHeader
    if opts ~= nil and opts.hideGenericRewardLabel and rowHeader == GENERIC_REWARD_HEADER then
        rowHeader = nil
    end
    local reserveHeaderColumn = rowHeader ~= nil

    for _, control in ipairs(surface.controls or {}) do
        if isControlVisible(control, fields) then
            if rowIndex ~= control.rowIndex then
                if rowInvalid then
                    drawInvalid(draw, validation)
                    rowInvalid = false
                end
                rowIndex = control.rowIndex
                drawGroupedRowStart(imgui, startX, not drew and rowHeader or nil, reserveHeaderColumn)
            else
                imgui.SameLine()
            end
            rowInvalid = rowInvalid or aliasIsInvalid(validation, control.alias)
            changed = drawControl(draw, fields, control, opts) or changed
            drew = true
        end
    end
    if rowInvalid then
        drawInvalid(draw, validation)
    end
    return changed
end

function ui.draw(draw, surface, fields, opts)
    if runtime ~= nil and not runtime.hasControls(surface) then
        return false
    end
    if surface == nil or fields == nil then
        return false
    end

    local drew = false
    local invalid = false
    local changed = false
    local imgui = draw.imgui
    local validation = surfaceValidation(surface, fields)
    if hasGroupedRows(surface) then
        return drawGroupedControls(draw, surface, fields, opts)
    end

    for _, control in ipairs(surface.controls or {}) do
        if isControlVisible(control, fields) then
            if drew then
                imgui.SameLine()
            end
            invalid = invalid or aliasIsInvalid(validation, control.alias)
            changed = drawControl(draw, fields, control, opts) or changed
            drew = true
        end
    end
    if invalid then
        drawInvalid(draw, validation)
    end
    return changed
end

return ui
