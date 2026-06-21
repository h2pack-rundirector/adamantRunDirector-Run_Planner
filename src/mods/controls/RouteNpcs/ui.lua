-- luacheck: no unused args

local deps = ...
local runtime = deps.runtime

local ui = {}

local LABEL_COLUMN_X = 74
local TARGET_COLUMN_X = 145
local BIOME_OPTS = {
    label = "",
    controlWidth = 140,
}
local ROOM_OPTS = {
    label = "",
    controlWidth = 300,
}
local VARIANT_OPTS = {
    label = "",
    controlWidth = 140,
}

local function copyBaseOpts(base)
    local copy = {}
    for key, value in pairs(base or {}) do
        copy[key] = value
    end
    return copy
end

local function bindOptionValues(opts, source)
    opts.values = source.values
    opts.displayValues = source.displayValues
    return opts
end

local function cachedOpts(control, cacheName, rowIndex, base)
    control[cacheName] = control[cacheName] or {}
    local opts = control[cacheName][rowIndex]
    if opts == nil then
        opts = copyBaseOpts(base)
        control[cacheName][rowIndex] = opts
    end
    return opts
end

local function biomeOpts(control, rowIndex)
    return bindOptionValues(
        cachedOpts(control, "_biomeOptsByRow", rowIndex, BIOME_OPTS),
        control:biomeOptions(rowIndex)
    )
end

local function roomOpts(control, rowIndex)
    return bindOptionValues(
        cachedOpts(control, "_roomOptsByRow", rowIndex, ROOM_OPTS),
        control:roomOptions(rowIndex)
    )
end

local function variantOpts(control, rowIndex)
    return bindOptionValues(
        cachedOpts(control, "_variantOptsByRow", rowIndex, VARIANT_OPTS),
        control:variantOptions(rowIndex)
    )
end

local function drawDropdownLine(draw, label, field, opts, onChange)
    local imgui = draw.imgui
    imgui.AlignTextToFramePadding()
    imgui.SetCursorPosX(LABEL_COLUMN_X)
    imgui.Text(label)
    imgui.SameLine()
    imgui.SetCursorPosX(TARGET_COLUMN_X)
    if draw.widgets.dropdown(field, opts) then
        onChange()
    end
end

local function drawTargetRow(draw, control, rowIndex)
    local slot = control:slot(rowIndex)
    if slot == nil then
        return
    end

    local imgui = draw.imgui
    imgui.AlignTextToFramePadding()
    imgui.Text(slot.label)

    drawDropdownLine(draw, "Biome", control:biomeField(rowIndex), biomeOpts(control, rowIndex), function()
        control:writeBiome(rowIndex, control:rawBiomeKey(rowIndex))
    end)

    if control:shouldRenderRoom(rowIndex) then
        drawDropdownLine(draw, "Room", control:roomField(rowIndex), roomOpts(control, rowIndex), function()
            control:writeRoom(rowIndex, control:rawRowIndex(rowIndex))
        end)
    end

    if control:shouldRenderVariant(rowIndex) then
        drawDropdownLine(draw, "Type", control:variantField(rowIndex), variantOpts(control, rowIndex), function()
            control:writeVariant(rowIndex, control:rawVariantKey(rowIndex))
        end)
    end
end

local function drawSeparator(imgui)
    imgui.Spacing()
    imgui.Separator()
    imgui.Spacing()
end

local function drawRows(draw, control)
    local rowCount = control:rowCount()
    if rowCount == 0 then
        draw.imgui.Text("No route NPCs")
        return
    end

    for rowIndex = 1, rowCount do
        if rowIndex > 1 then
            drawSeparator(draw.imgui)
        end
        drawTargetRow(draw, control, rowIndex)
    end
end

function ui.create(fields, instance)
    local control = runtime.create(fields, instance)

    function control:fields()
        return fields
    end

    function control:targetField(rowIndex)
        return fields.Targets:get(rowIndex, "TargetKey")
    end

    function control:biomeField(rowIndex)
        return fields.Targets:get(rowIndex, "BiomeKey")
    end

    function control:roomField(rowIndex)
        return fields.Targets:get(rowIndex, "RowIndex")
    end

    function control:variantField(rowIndex)
        return fields.Targets:get(rowIndex, "VariantKey")
    end

    return control
end

ui.views = {}

function ui.views.planner(draw, control)
    drawRows(draw, control)
end

ui.views.default = ui.views.planner

return ui
