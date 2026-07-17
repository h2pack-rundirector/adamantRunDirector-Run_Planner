local linearBiomeDraw = {}

local CLEAR_OPTS = {
    confirmLabel = "Confirm Clear Biome",
}

local FRAME_ALIGNED_TEXT_OPTS = {
    alignToFramePadding = true,
}

local function syncDropdown(ui, alias, current, opts)
    local field = ui.data.get(alias)
    if field:read() ~= current then
        field:write(current)
    end
    local changed = ui.draw.widgets.dropdown(field, opts)
    return changed, field:read()
end

local function drawRoom(ui, room, context)
    if room == nil then
        return
    end
    ui.draw.imgui.SetCursorPosX(40)
    ui.draw.control(ui.controls.get(room.roomControlKey), "default", context)
end

local function drawStart(ui, plan, start)
    ui.draw.widgets.text("Starting Room")
    ui.draw.widgets.separator()
    local changed, value = syncDropdown(
        ui,
        start.selectorAlias,
        start.current,
        start.opts
    )
    if changed then
        if value == "" then
            plan:clearTopology()
        else
            plan:apply({ kind = "SelectStart", roomControlKey = value })
        end
    end
    if start.room ~= nil then
        drawRoom(ui, start.room)
    end
end

local function applyContinuation(plan, continuation, nextKind)
    local current = continuation.current
    local parent = continuation.parentRoomControlKey
    if nextKind == current then
        return
    end
    if current == "" then
        if nextKind == "batch" then
            plan:apply({ kind = "CreateBatch", parentRoomControlKey = parent })
        elseif nextKind == "terminal" then
            plan:apply({ kind = "CreateTerminalTransition", parentRoomControlKey = parent })
        end
    elseif current == "batch" then
        if nextKind == "" then
            plan:apply({ kind = "RemoveBatch", parentRoomControlKey = parent })
        elseif nextKind == "terminal" then
            plan:apply({ kind = "ReplaceWithTerminalTransition", parentRoomControlKey = parent })
        end
    elseif current == "terminal" then
        if nextKind == "" then
            plan:apply({ kind = "RemoveTerminalTransition" })
        elseif nextKind == "batch" then
            plan:apply({ kind = "ReplaceWithBatch", parentRoomControlKey = parent })
        end
    end
end

local function drawContinuation(ui, plan, continuation)
    local changed, value = syncDropdown(
        ui,
        continuation.selectorAlias,
        continuation.current,
        continuation.opts
    )
    if changed then
        applyContinuation(plan, continuation, value)
    end
end

local function removeTarget(plan, batch, target)
    plan:apply({
        kind = "RemoveTarget",
        parentRoomControlKey = batch.parentRoomControlKey,
        exitIndex = target.exitIndex,
    })
end

local function drawTargetCategory(ui, target)
    local choice = target.category
    local field = ui.data.get(choice.selectorAlias)
    if choice.current ~= nil then
        if field:read() ~= choice.current then
            field:write(choice.current)
        end
    elseif choice.opts.valueLookup[field:read()] ~= true then
        field:write("")
    end
    local changed = ui.draw.widgets.dropdown(field, choice.opts)
    return changed, field:read()
end

local function drawTarget(ui, plan, batch, target)
    local categoryChanged, category = drawTargetCategory(ui, target)
    local roomField = ui.data.get(target.roomChoice.selectorAlias)
    if categoryChanged then
        roomField:write("")
        if target.current ~= "" then
            removeTarget(plan, batch, target)
        end
        return
    end
    if category == "" then
        if roomField:read() ~= "" then
            roomField:write("")
        end
        return
    end

    ui.draw.imgui.SameLine()
    local changed, value = syncDropdown(
        ui,
        target.roomChoice.selectorAlias,
        target.current,
        target.roomChoice.optsByCategory[category]
    )
    if target.room ~= nil and target.room.picked then
        ui.draw.imgui.SameLine()
        ui.draw.widgets.text("Picked", FRAME_ALIGNED_TEXT_OPTS)
    end
    if changed then
        if value == "" then
            removeTarget(plan, batch, target)
        else
            plan:apply({
                kind = "SetTarget",
                parentRoomControlKey = batch.parentRoomControlKey,
                exitIndex = target.exitIndex,
                roomControlKey = value,
            })
        end
        return
    end
    drawRoom(ui, target.room)
end

local function drawPicked(ui, plan, batch)
    local changed, value = syncDropdown(
        ui,
        batch.pickedSelectorAlias,
        batch.picked,
        batch.pickedOpts
    )
    if not changed or value == "" then
        return
    end
    for _, target in ipairs(batch.targets) do
        if target.current == value then
            plan:apply({
                kind = "SetPicked",
                parentRoomControlKey = batch.parentRoomControlKey,
                exitIndex = target.exitIndex,
            })
            return
        end
    end
    error("picked Room Control is absent from its projected batch", 0)
end

local function drawBatch(ui, plan, batch)
    ui.draw.imgui.Spacing()
    ui.draw.widgets.separator()
    ui.draw.widgets.text(
        "Decision " .. tostring(batch.ordinal) .. " - From " .. batch.parentLabel
    )
    drawContinuation(ui, plan, batch.continuation)
    for targetIndex, target in ipairs(batch.targets) do
        if targetIndex > 1 then
            ui.draw.imgui.Spacing()
        end
        drawTarget(ui, plan, batch, target)
    end
    drawPicked(ui, plan, batch)
end

local function drawTerminal(ui, terminal)
    ui.draw.imgui.Spacing()
    ui.draw.widgets.separator()
    ui.draw.widgets.text("Preboss")
    ui.draw.widgets.text(terminal.room.label)
    drawRoom(ui, terminal.room, terminal.roomContext)
end

function linearBiomeDraw.draw(ui, view, plan)
    ui.draw.widgets.text(view.label .. " Editor")
    ui.draw.imgui.TextDisabled("Editor only - runtime planning is not active.")
    ui.draw.imgui.Spacing()
    drawStart(ui, plan, view.start)
    for _, batch in ipairs(view.batches) do
        drawBatch(ui, plan, batch)
    end
    if view.tail ~= nil then
        ui.draw.imgui.Spacing()
        ui.draw.widgets.text("Continue from " .. view.tail.parentLabel)
        drawContinuation(ui, plan, view.tail)
    end
    if view.terminal ~= nil then
        drawTerminal(ui, view.terminal)
    end
    ui.draw.imgui.Spacing()
    ui.draw.widgets.separator()
    ui.draw.imgui.Spacing()
    if ui.draw.widgets.confirmButton(
        "RunPlannerClear_" .. view.key,
        "Clear Biome",
        CLEAR_OPTS
    ) then
        plan:clearTopology()
    end
end

return linearBiomeDraw
