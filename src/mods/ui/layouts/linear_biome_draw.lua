local linearBiomeDraw = {}

local CLEAR_OPTS = {
    confirmLabel = "Confirm Clear Biome",
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
    ui.draw.imgui.Indent(40)
    ui.draw.control(ui.controls.get(room.roomControlKey), "default", context)
    ui.draw.imgui.Unindent(40)
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

local function removeTarget(plan, batch, target)
    plan:apply({
        kind = "RemoveTarget",
        parentRoomControlKey = batch.parentRoomControlKey,
        exitIndex = target.exitIndex,
    })
end

local function pickTarget(plan, batch, target)
    plan:apply({
        kind = "SetPicked",
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
            if batch.singleExit then
                pickTarget(plan, batch, target)
            end
        end
        return
    end
    if target.room ~= nil
        and (not batch.singleExit or not target.room.picked)
    then
        ui.draw.imgui.SameLine()
        if ui.draw.imgui.RadioButton(
            target.pickedRadioLabel,
            target.room.picked
        ) then
            pickTarget(plan, batch, target)
        end
    end
    drawRoom(ui, target.room)
end

local function drawBatch(ui, plan, batch)
    ui.draw.imgui.Spacing()
    ui.draw.widgets.separator()
    ui.draw.widgets.text(batch.heading)
    ui.draw.imgui.SameLine()
    if ui.draw.imgui.Button(batch.removeButtonLabel) then
        plan:apply({
            kind = "RemoveBatch",
            parentRoomControlKey = batch.parentRoomControlKey,
        })
        return true
    end
    for targetIndex, target in ipairs(batch.targets) do
        if targetIndex > 1 then
            ui.draw.imgui.Spacing()
        end
        drawTarget(ui, plan, batch, target)
    end
    return false
end

local function drawFrontier(ui, plan, frontier)
    ui.draw.imgui.Spacing()
    ui.draw.widgets.text(frontier.heading)
    ui.draw.imgui.SameLine()
    if frontier.canCreateBatch then
        if ui.draw.imgui.Button(frontier.addBatchButtonLabel) then
            plan:apply({
                kind = "CreateBatch",
                parentRoomControlKey = frontier.parentRoomControlKey,
            })
            return true
        end
        ui.draw.imgui.SameLine()
    end
    if ui.draw.imgui.Button(frontier.prebossButtonLabel) then
        plan:apply({
            kind = "CreateTerminalTransition",
            parentRoomControlKey = frontier.parentRoomControlKey,
        })
        return true
    end
    return false
end

local function drawTerminal(ui, plan, terminal)
    ui.draw.imgui.Spacing()
    ui.draw.widgets.separator()
    ui.draw.widgets.text(terminal.heading)
    ui.draw.imgui.SameLine()
    if ui.draw.imgui.Button(terminal.continueButtonLabel) then
        plan:apply({
            kind = "ReplaceWithBatch",
            parentRoomControlKey = terminal.parentRoomControlKey,
        })
        return true
    end
    ui.draw.imgui.SameLine()
    if ui.draw.imgui.Button(terminal.removeButtonLabel) then
        plan:apply({ kind = "RemoveTerminalTransition" })
        return true
    end
    ui.draw.widgets.text(terminal.room.label)
    drawRoom(ui, terminal.room, terminal.roomContext)
    return false
end

function linearBiomeDraw.draw(ui, view, plan)
    ui.draw.widgets.text(view.label .. " Editor")
    ui.draw.imgui.TextDisabled("Editor only - runtime planning is not active.")
    ui.draw.imgui.Spacing()
    drawStart(ui, plan, view.start)
    for _, batch in ipairs(view.batches) do
        if drawBatch(ui, plan, batch) then
            return
        end
    end
    if view.tail ~= nil then
        if drawFrontier(ui, plan, view.tail) then
            return
        end
    end
    if view.terminal ~= nil then
        if drawTerminal(ui, plan, view.terminal) then
            return
        end
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
