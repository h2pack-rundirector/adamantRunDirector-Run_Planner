local linearBiome = {}

local STRUCTURAL_LABEL_WIDTH = 105
local ROOM_LABEL_WIDTH = 55
local TARGET_CATEGORY_ORDER = {
    "Combat",
    "Miniboss",
    "Story",
    "Fountain",
    "Shop",
}
local TARGET_CATEGORY_LABELS = {
    Combat = "Combat",
    Miniboss = "Miniboss",
    Story = "Story",
    Fountain = "Fountain",
    Shop = "Shop",
}
local ROOM_KIND_CATEGORY = {
    Combat = "Combat",
    Miniboss = "Miniboss",
    Story = "Story",
    Bridge = "Story",
    Reprieve = "Fountain",
    Shop = "Shop",
}

local function biomeByStep(catalog, biomeStepKey)
    for _, biome in ipairs(catalog.biomes.ordered) do
        if biome.biomeStepKey == biomeStepKey then
            return biome
        end
    end
end

local function roomLabel(room)
    local exitCount = #room.exits
    local suffix = exitCount == 1 and " exit" or " exits"
    return room.label .. " (" .. tostring(exitCount) .. suffix .. ")"
end

local function roomRecords(catalog, biome)
    local result = { ordered = {}, lookup = {}, byGameName = {} }
    for _, control in ipairs(catalog.controlManifest.rooms.ordered) do
        if control.biomeStepKey == biome.biomeStepKey then
            local room = biome.rooms.lookup[control.gameName]
            local record = {
                controlKey = control.key,
                gameName = control.gameName,
                label = roomLabel(room),
                categoryKey = ROOM_KIND_CATEGORY[room.kind],
                room = room,
            }
            result.ordered[#result.ordered + 1] = record
            result.lookup[record.controlKey] = record
            result.byGameName[record.gameName] = record
        end
    end
    return result
end

local function option(values, labels, value, label)
    values[#values + 1] = value
    labels[value] = label
end

local function dropdownOpts(label, values, labels, width, labelWidth)
    return {
        label = label,
        values = values,
        displayValues = labels,
        controlWidth = width,
        labelWidth = labelWidth or STRUCTURAL_LABEL_WIDTH,
    }
end

local function startOptions(biome, rooms)
    local values = { "" }
    local labels = { [""] = "Select..." }
    for _, gameName in ipairs(biome.layout.start.roomKeys) do
        local room = rooms.byGameName[gameName]
        option(values, labels, room.controlKey, room.label)
    end
    return dropdownOpts("Opening", values, labels, 300)
end

local function claimedRooms(topology)
    local result = {}
    if topology.startRoomControlKey ~= nil then
        result[topology.startRoomControlKey] = true
    end
    for _, batch in ipairs(topology.batches) do
        for _, target in ipairs(batch.targets) do
            result[target.roomControlKey] = true
        end
    end
    local transition = topology.terminalTransition
    if transition ~= nil then
        result[transition.terminalRoomControlKey] = true
        for _, target in ipairs(transition.companionTargets) do
            result[target.roomControlKey] = true
        end
    end
    return result
end

local function targetByExit(batch)
    local result = {}
    for _, target in ipairs(batch.targets) do
        result[target.exitIndex] = target
    end
    return result
end

local function targetSelectionOptions(
    biome,
    rooms,
    claims,
    currentControlKey,
    exitIndex
)
    local roomOptsByCategory = {}
    for _, categoryKey in ipairs(TARGET_CATEGORY_ORDER) do
        roomOptsByCategory[categoryKey] = dropdownOpts(
            "Room",
            { "" },
            { [""] = "Select..." },
            300,
            ROOM_LABEL_WIDTH
        )
    end
    for _, room in ipairs(rooms.ordered) do
        local roles = biome.roomRoles.lookup[room.gameName] or {}
        local declarationImpossible = roles.start == true
            or room.gameName == biome.layout.terminal.roomKey
        if not declarationImpossible
            and (not claims[room.controlKey] or room.controlKey == currentControlKey)
        then
            if room.categoryKey == nil then
                error("missing target selection category for room kind '"
                    .. room.room.kind .. "'", 0)
            end
            local opts = roomOptsByCategory[room.categoryKey]
            option(opts.values, opts.displayValues, room.controlKey, room.label)
        end
    end
    local categoryValues = { "" }
    local categoryLabels = { [""] = "Select..." }
    local categoryLookup = { [""] = true }
    for _, categoryKey in ipairs(TARGET_CATEGORY_ORDER) do
        if #roomOptsByCategory[categoryKey].values > 1 then
            option(
                categoryValues,
                categoryLabels,
                categoryKey,
                TARGET_CATEGORY_LABELS[categoryKey]
            )
            categoryLookup[categoryKey] = true
        end
    end
    local categoryOpts = dropdownOpts(
        "Exit " .. tostring(exitIndex) .. " Type",
        categoryValues,
        categoryLabels,
        140
    )
    categoryOpts.valueLookup = categoryLookup
    local currentCategory
    if currentControlKey ~= "" then
        currentCategory = rooms.lookup[currentControlKey].categoryKey
    end
    return currentCategory, categoryOpts, roomOptsByCategory
end

local function selectedTarget(batch)
    for _, target in ipairs(batch.targets) do
        if target.picked then
            return target
        end
    end
    return nil
end

local function roomOccurrence(rooms, roomControlKey, picked)
    if roomControlKey == nil then
        return nil
    end
    local room = rooms.lookup[roomControlKey]
    return {
        roomControlKey = roomControlKey,
        gameName = room.gameName,
        label = room.label,
        picked = picked == true,
    }
end

local function actionLabel(label, action, parentControlKey)
    return label .. "##RunPlanner_" .. action .. "_" .. parentControlKey
end

local function frontierView(parentControlKey, parentLabel, canCreateBatch)
    return {
        parentRoomControlKey = parentControlKey,
        parentLabel = parentLabel,
        heading = "Continue from " .. parentLabel,
        canCreateBatch = canCreateBatch,
        addBatchButtonLabel = actionLabel(
            "Add Next Decision",
            "CreateBatch",
            parentControlKey
        ),
        prebossButtonLabel = actionLabel(
            "Go to Preboss",
            "CreateTerminalTransition",
            parentControlKey
        ),
    }
end

function linearBiome.create(catalog)
    local layout = {}

    function layout.project(_, plan, topology, selectors)
        local biome = biomeByStep(catalog, plan.key)
        local rooms = roomRecords(catalog, biome)
        local claims = claimedRooms(topology)
        local view = {
            key = plan.key,
            label = biome.label,
            layoutKind = "LinearBiome",
            start = {
                current = topology.startRoomControlKey or "",
                selectorAlias = selectors.start,
                opts = startOptions(biome, rooms),
                room = roomOccurrence(rooms, topology.startRoomControlKey, true),
            },
            batches = {},
            tail = nil,
            terminal = nil,
        }

        local selectedControlKey = topology.startRoomControlKey
        for batchIndex, batch in ipairs(topology.batches) do
            local parent = rooms.lookup[batch.parentRoomControlKey]
            local byExit = targetByExit(batch)
            local batchView = {
                ordinal = batchIndex,
                parentRoomControlKey = batch.parentRoomControlKey,
                parentLabel = parent.label,
                heading = "Decision " .. tostring(batchIndex) .. " - From " .. parent.label,
                removeButtonLabel = actionLabel(
                    "Remove From Here",
                    "RemoveBatch",
                    batch.parentRoomControlKey
                ),
                singleExit = #parent.room.exits == 1,
                targets = {},
            }
            for exitIndex = 1, #parent.room.exits do
                local target = byExit[exitIndex]
                local targetControlKey = target and target.roomControlKey or ""
                local currentCategory, categoryOpts, roomOptsByCategory =
                    targetSelectionOptions(
                        biome,
                        rooms,
                        claims,
                        targetControlKey,
                        exitIndex
                    )
                local targetSelectors = selectors.batches[batchIndex].targets[exitIndex]
                batchView.targets[exitIndex] = {
                    exitIndex = exitIndex,
                    current = targetControlKey,
                    pickedRadioLabel = "Picked##RunPlanner_"
                        .. batch.parentRoomControlKey .. "_Exit" .. tostring(exitIndex),
                    category = {
                        current = currentCategory,
                        selectorAlias = targetSelectors.category,
                        opts = categoryOpts,
                    },
                    roomChoice = {
                        selectorAlias = targetSelectors.room,
                        optsByCategory = roomOptsByCategory,
                    },
                    room = roomOccurrence(
                        rooms,
                        target and target.roomControlKey or nil,
                        target and target.picked
                    ),
                }
            end
            view.batches[batchIndex] = batchView
            local picked = selectedTarget(batch)
            if picked == nil then
                selectedControlKey = batch.parentRoomControlKey
                break
            end
            selectedControlKey = picked.roomControlKey
        end

        local transition = topology.terminalTransition
        local lastBatch = topology.batches[#topology.batches]
        local lastBatchParent = lastBatch and lastBatch.parentRoomControlKey or nil
        local needsTail = transition == nil
            and selectedControlKey ~= nil
            and selectedControlKey ~= lastBatchParent
        if needsTail then
            view.tail = frontierView(
                selectedControlKey,
                rooms.lookup[selectedControlKey].label,
                #topology.batches < biome.layout.bounds.maxBatches
            )
        end

        if transition ~= nil then
            local parent = rooms.lookup[transition.parentRoomControlKey]
            local terminal = rooms.lookup[transition.terminalRoomControlKey]
            view.terminal = {
                parentRoomControlKey = transition.parentRoomControlKey,
                heading = "Preboss",
                continueButtonLabel = actionLabel(
                    "Continue With Rooms",
                    "ReplaceWithBatch",
                    transition.parentRoomControlKey
                ),
                removeButtonLabel = actionLabel(
                    "Remove",
                    "RemoveTerminalTransition",
                    transition.parentRoomControlKey
                ),
                room = roomOccurrence(rooms, terminal.controlKey, true),
                roomContext = {
                    activeFreeRewardCount = math.max(#parent.room.exits - 1, 0),
                },
            }
        end
        return view
    end

    return layout
end

return linearBiome
