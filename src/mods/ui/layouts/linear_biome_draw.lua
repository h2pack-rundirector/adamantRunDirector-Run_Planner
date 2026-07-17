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

local function pickTarget(plan, batch, target)
    plan:apply({
        kind = "SetPicked",
        parentRoomControlKey = batch.parentRoomControlKey,
        exitIndex = target.exitIndex,
    })
end

local function targetSelectorFields(ui, target)
    local choice = target.category
    local categoryField = ui.data.get(choice.selectorAlias)
    local roomField = ui.data.get(target.roomChoice.selectorAlias)
    local category = categoryField:read()
    if choice.opts.valueLookup[category] ~= true then
        category = ""
        categoryField:write(category)
        roomField:write("")
    end
    if target.current ~= "" then
        local browsingReplacement = roomField:read() == ""
            and category ~= ""
            and category ~= choice.current
        if not browsingReplacement then
            category = choice.current
            if categoryField:read() ~= category then
                categoryField:write(category)
            end
            if roomField:read() ~= target.current then
                roomField:write(target.current)
            end
        end
    end
    return categoryField, roomField
end

local function drawTarget(ui, plan, batch, target)
    local categoryField, roomField = targetSelectorFields(ui, target)
    local categoryChanged = ui.draw.widgets.dropdown(
        categoryField,
        target.category.opts
    )
    if categoryChanged then
        local category = categoryField:read()
        if target.current ~= "" and category == "" then
            categoryField:write(target.category.current)
            roomField:write(target.current)
        else
            roomField:write("")
        end
    end
    local category = categoryField:read()
    if category == "" then
        if roomField:read() ~= "" then
            roomField:write("")
        end
        return
    end

    ui.draw.imgui.SameLine()
    local displayedRoom = ""
    if category == target.category.current then
        displayedRoom = target.current
    end
    local changed, value = syncDropdown(
        ui,
        target.roomChoice.selectorAlias,
        displayedRoom,
        target.roomChoice.optsByCategory[category]
    )
    if changed and value ~= "" then
        plan:apply({
            kind = "SetTarget",
            parentRoomControlKey = batch.parentRoomControlKey,
            exitIndex = target.exitIndex,
            roomControlKey = value,
        })
        if batch.singleExit then
            pickTarget(plan, batch, target)
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
