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
local MANAGED_COUNT_OPTS = {
    label = "Targets",
    values = {},
    displayValues = {},
    labelWidth = 145,
    controlWidth = 90,
}

for _, value in ipairs(deps.data.MANAGED_COUNT_VALUES) do
    MANAGED_COUNT_OPTS.values[#MANAGED_COUNT_OPTS.values + 1] = value
    MANAGED_COUNT_OPTS.displayValues[value] = value
end

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

local function managedCountOpts(control)
    local opts = control._managedCountOpts
    if opts == nil then
        opts = copyBaseOpts(MANAGED_COUNT_OPTS)
        control._managedCountOpts = opts
    end
    opts.label = control:featureLabel()
    return opts
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

local function drawFeatureRow(draw, control, rowIndex)
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
end

local function drawRows(draw, control)
    local rowCount = control:rowCount()
    if draw.widgets.dropdown(control:managedCountField(), managedCountOpts(control)) then
        control:writeManagedCount(control:rawManagedCount())
    end
    draw.imgui.Spacing()

    if rowCount == 0 then
        draw.imgui.Text("No route features")
        return
    end

    for rowIndex = 1, rowCount do
        drawFeatureRow(draw, control, rowIndex)
        if rowIndex < rowCount then
            draw.imgui.Spacing()
        end
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

    function control:managedCountField()
        return fields.ManagedCount
    end

    function control:featureLabel()
        return instance.label or (instance.feature and instance.feature.label) or "Targets"
    end

    function control:biomeField(rowIndex)
        return fields.Targets:get(rowIndex, "BiomeKey")
    end

    function control:roomField(rowIndex)
        return fields.Targets:get(rowIndex, "RowIndex")
    end

    return control
end

ui.views = {}

function ui.views.planner(draw, control)
    drawRows(draw, control)
end

ui.views.default = ui.views.planner

return ui
