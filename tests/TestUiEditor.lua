-- luacheck: globals TestUiEditor

local lu = require("luaunit")
local h = dofile("tests/support/import_harness.lua")

TestUiEditor = {}

local function load()
    return h.testImport("mods/systems.lua").create()
end

local function directAccess(state)
    local function copyRows(rows)
        local result = {}
        for index, row in ipairs(rows or {}) do
            local copy = {}
            for key, value in pairs(row) do
                copy[key] = value
            end
            result[index] = copy
        end
        return result
    end
    return {
        readScalar = function(_, root)
            if string.find(root.alias, "SelectedStart", 1, true) then
                return state.selectedStartRoomControlKey
            end
            if string.find(root.alias, "TerminalParent", 1, true) then
                return state.terminalTransition.parentRoomControlKey
            end
            return state[root.semanticKey]
        end,
        readRows = function(_, root)
            if string.find(root.alias, "CompanionTargets", 1, true) then
                return copyRows(state.terminalTransition.companionTargets)
            end
            if string.find(root.alias, "_Batches", 1, true) then
                return copyRows(state.batches)
            end
            return copyRows(state.targets)
        end,
    }
end

local function completeFState()
    return {
        layoutKind = "LinearBiome",
        selectedStartRoomControlKey = "Underworld_F_Opening02",
        batches = {
            { parentRoomControlKey = "Underworld_F_Opening02" },
            { parentRoomControlKey = "Underworld_F_Combat03" },
        },
        targets = {
            {
                parentRoomControlKey = "Underworld_F_Opening02",
                exitIndex = 1,
                roomControlKey = "Underworld_F_Combat03",
                picked = true,
            },
            {
                parentRoomControlKey = "Underworld_F_Combat03",
                exitIndex = 1,
                roomControlKey = "Underworld_F_Combat04",
                picked = true,
            },
            {
                parentRoomControlKey = "Underworld_F_Combat03",
                exitIndex = 2,
                roomControlKey = "Underworld_F_Combat05",
                picked = false,
            },
        },
        terminalTransition = {
            parentRoomControlKey = "Underworld_F_Combat04",
        },
    }
end

local function completeGState()
    return {
        layoutKind = "LinearBiome",
        batches = {
            { parentRoomControlKey = "Underworld_G_Intro" },
            { parentRoomControlKey = "Underworld_G_Combat02" },
        },
        targets = {
            {
                parentRoomControlKey = "Underworld_G_Intro",
                exitIndex = 1,
                roomControlKey = "Underworld_G_Combat02",
                picked = true,
            },
            {
                parentRoomControlKey = "Underworld_G_Combat02",
                exitIndex = 1,
                roomControlKey = "Underworld_G_Combat03",
                picked = true,
            },
            {
                parentRoomControlKey = "Underworld_G_Combat02",
                exitIndex = 2,
                roomControlKey = "Underworld_G_Combat04",
                picked = false,
            },
            {
                parentRoomControlKey = "Underworld_G_Combat02",
                exitIndex = 3,
                roomControlKey = "Underworld_G_Combat05",
                picked = false,
            },
        },
        terminalTransition = {
            parentRoomControlKey = "Underworld_G_Combat03",
        },
    }
end

local function tableHandle(rows)
    return {
        count = function()
            return #rows
        end,
        read = function(_, rowIndex, column)
            return rows[rowIndex][column]
        end,
        clear = function()
            for index = #rows, 1, -1 do
                rows[index] = nil
            end
        end,
        append = function(_, row)
            rows[#rows + 1] = row
        end,
    }
end

local function runtimeState(systems, configuredUnderworld, state)
    local values = {}
    local tables = {}
    for _, descriptor in ipairs(systems.route.storage.moduleStorage) do
        if descriptor.type == "table" then
            tables[descriptor.alias] = {}
        else
            values[descriptor.alias] = descriptor.default
        end
    end
    if state ~= nil then
        local descriptor = systems.route.storage.biomes.lookup.Underworld_F
        values[descriptor.selectedStart.alias] = state.selectedStartRoomControlKey
        values[descriptor.terminalTransition.alias] =
            state.terminalTransition.parentRoomControlKey
        for index, batch in ipairs(state.batches) do
            local row = {}
            for semanticKey, physicalKey in pairs(descriptor.batches.columns) do
                row[physicalKey] = batch[semanticKey]
            end
            tables[descriptor.batches.alias][index] = row
        end
        for index, target in ipairs(state.targets) do
            local row = {}
            for semanticKey, physicalKey in pairs(descriptor.targets.columns) do
                row[physicalKey] = target[semanticKey]
            end
            tables[descriptor.targets.alias][index] = row
        end
    end
    return {
        controls = {
            read = function(routeKey)
                if routeKey == "Underworld" then
                    return configuredUnderworld
                end
                return ""
            end,
        },
        data = {
            read = function(alias)
                return values[alias]
            end,
            get = function(alias)
                if tables[alias] ~= nil then
                    return tableHandle(tables[alias])
                end
                return {
                    write = function(_, value)
                        values[alias] = value
                    end,
                }
            end,
        },
        resetAll = function() end,
    }
end

local function emptyRuntime(systems, configuredUnderworld)
    return runtimeState(systems, configuredUnderworld, nil)
end

local function contains(values, candidate)
    for _, value in ipairs(values) do
        if value == candidate then
            return true
        end
    end
    return false
end

function TestUiEditor.testPublishesOnlyTheCommittedConfiguredPrefix()
    h.withImport(function()
        local systems = load()
        local published = systems.ui.coordinator:rebuild(
            emptyRuntime(systems, "Underworld_F")
        )
        local underworld = published.routes.lookup.Underworld
        lu.assertEquals(underworld.label, "Underworld")
        lu.assertEquals(underworld.configuredPrefix, "Underworld_F")
        lu.assertEquals(#underworld.biomes.ordered, 1)
        lu.assertEquals(underworld.navTabs, {
            { key = "route", label = "Route" },
            { key = "Underworld_F", label = "Erebus" },
        })
        lu.assertEquals(underworld.biomes.lookup.Underworld_F.start.current, "")
        lu.assertEquals(published.routes.lookup.Surface.navTabs, {
            { key = "route", label = "Route" },
        })

        published = systems.ui.coordinator:rebuild(emptyRuntime(systems, ""))
        lu.assertEquals(published.routes.lookup.Underworld.biomes.ordered, {})
    end)
end

function TestUiEditor.testDrawBeforeActivationReportsUnavailable()
    h.withImport(function()
        local systems = load()
        local texts = {}
        systems.ui.drawTab(nil, {
            draw = {
                widgets = {
                    text = function(value)
                        texts[#texts + 1] = value
                    end,
                },
            },
        })

        lu.assertEquals(texts, {
            "Run Planner authored editor is unavailable.",
        })
    end)
end

function TestUiEditor.testLinearProjectionKeepsPickedAndUnpickedRoomsTogether()
    h.withImport(function()
        local systems = load()
        local plan = systems.route.biomePlans.lookup.Underworld_F
        local topology = plan:readTopology(directAccess(completeFState()))
        local view = systems.ui.layouts.LinearBiome:project(
            plan,
            topology,
            systems.ui.selectors.biomes.lookup.Underworld_F
        )

        lu.assertEquals(view.start.room.roomControlKey, "Underworld_F_Opening02")
        lu.assertEquals(view.start.room.gameName, "F_Opening02")
        lu.assertEquals(view.start.room.label, "Opening 02 (1 exit)")
        lu.assertEquals(#view.batches, 2)
        lu.assertEquals(view.batches[2].targets[1].room.roomControlKey,
            "Underworld_F_Combat04")
        lu.assertTrue(view.batches[2].targets[1].room.picked)
        lu.assertEquals(view.batches[2].targets[2].room.roomControlKey,
            "Underworld_F_Combat05")
        lu.assertFalse(view.batches[2].targets[2].room.picked)
        lu.assertEquals(view.batches[2].ordinal, 2)
        lu.assertEquals(view.batches[2].targets[1].category.current, "Combat")
        lu.assertEquals(view.batches[2].targets[1].category.opts.label, "Exit 1 Type")
        lu.assertEquals(view.batches[2].targets[1].category.opts.labelWidth, 105)
        lu.assertEquals(view.batches[2].targets[1].category.opts.values, {
            "", "Combat", "Miniboss", "Story", "Fountain", "Shop",
        })
        lu.assertEquals(
            view.batches[2].targets[1].roomChoice.optsByCategory.Combat.label,
            "Room"
        )
        lu.assertEquals(
            view.batches[2].targets[1].roomChoice.optsByCategory.Combat.labelWidth,
            55
        )
        lu.assertTrue(contains(
            view.batches[2].targets[1].roomChoice.optsByCategory.Combat.values,
            "Underworld_F_Combat04"
        ))
        lu.assertFalse(contains(
            view.batches[2].targets[1].roomChoice.optsByCategory.Miniboss.values,
            "Underworld_F_Combat04"
        ))
        lu.assertTrue(contains(
            view.batches[2].targets[1].roomChoice.optsByCategory.Miniboss.values,
            "Underworld_F_MiniBoss01"
        ))
        lu.assertEquals(
            view.batches[2].targets[1].roomChoice.optsByCategory.Miniboss
                .displayValues.Underworld_F_MiniBoss01,
            "Root-Stalker (1 exit)"
        )
        lu.assertEquals(
            view.batches[2].targets[1].roomChoice.optsByCategory.Miniboss
                .displayValues[""],
            "Keep Combat 04 (2 exits)"
        )
        lu.assertEquals(
            view.batches[2].heading,
            "Decision 2 - From Combat 03 (2 exits)"
        )
        lu.assertEquals(
            view.batches[2].removeButtonLabel,
            "Remove From Here##RunPlanner_RemoveBatch_Underworld_F_Combat03"
        )
        lu.assertNil(view.tail)
        lu.assertEquals(view.terminal.room.roomControlKey, "Underworld_F_PreBoss01")
        lu.assertEquals(
            view.terminal.continueButtonLabel,
            "Continue With Rooms##RunPlanner_ReplaceWithBatch_Underworld_F_Combat04"
        )
        lu.assertEquals(view.terminal.roomContext.activeFreeRewardCount, 1)
        lu.assertFalse(contains(
            view.batches[1].targets[1].roomChoice.optsByCategory.Combat.values,
            "Underworld_F_Combat04"
        ))
    end)
end

function TestUiEditor.testLinearProjectionAlsoConsumesFocusedGTopology()
    h.withImport(function()
        local systems = load()
        local selectorBuilder = h.testImport("mods/ui/selectors.lua")
        local selectors = selectorBuilder.build(systems.catalog, { "Underworld_G" })
        local plan = systems.route.biomePlans.lookup.Underworld_G
        local topology = plan:readTopology(directAccess(completeGState()))
        local view = systems.ui.layouts.LinearBiome:project(
            plan,
            topology,
            selectors.biomes.lookup.Underworld_G
        )

        lu.assertEquals(view.start.room.roomControlKey, "Underworld_G_Intro")
        lu.assertEquals(#view.batches[2].targets, 3)
        lu.assertEquals(view.batches[2].targets[1].room.roomControlKey,
            "Underworld_G_Combat03")
        lu.assertTrue(view.batches[2].targets[1].room.picked)
        lu.assertEquals(view.terminal.room.roomControlKey, "Underworld_G_PreBoss01")
        lu.assertEquals(view.terminal.roomContext.activeFreeRewardCount, 2)
    end)
end

function TestUiEditor.testLinearProjectionDoesNotInventSparseUnavailableTargets()
    h.withImport(function()
        local systems = load()
        local selectorBuilder = h.testImport("mods/ui/selectors.lua")
        local selectors = selectorBuilder.build(systems.catalog, { "Underworld_G" })
        local state = completeGState()
        table.remove(state.targets, 3)
        state.targets[1].roomControlKey = "Underworld_G_MiniBoss02"
        state.batches[2].parentRoomControlKey = "Underworld_G_MiniBoss02"
        state.targets[2].parentRoomControlKey = "Underworld_G_MiniBoss02"
        state.targets[3].parentRoomControlKey = "Underworld_G_MiniBoss02"
        local plan = systems.route.biomePlans.lookup.Underworld_G
        local topology = plan:readTopology(directAccess(state))
        local view = systems.ui.layouts.LinearBiome:project(
            plan,
            topology,
            selectors.biomes.lookup.Underworld_G
        )

        local targets = view.batches[2].targets
        lu.assertEquals(#targets, 2)
        lu.assertEquals(targets[1].exitIndex, 1)
        lu.assertTrue(targets[1].available)
        lu.assertEquals(targets[2].exitIndex, 3)
        lu.assertFalse(targets[2].available)
        lu.assertEquals(
            targets[2].room.roomControlKey,
            "Underworld_G_Combat05"
        )
    end)
end

function TestUiEditor.testLinearProjectionKeepsUnavailableTargetsAcrossReloadAndRepair()
    h.withImport(function()
        local systems = load()
        local state = completeFState()
        state.targets[1].roomControlKey = "Underworld_F_Combat01"
        state.batches[2].parentRoomControlKey = "Underworld_F_Combat01"
        state.targets[2].parentRoomControlKey = "Underworld_F_Combat01"
        state.targets[2].picked = false
        state.targets[3].parentRoomControlKey = "Underworld_F_Combat01"
        state.targets[3].picked = true
        state.terminalTransition.parentRoomControlKey = "Underworld_F_Combat05"
        local runtime = runtimeState(systems, "Underworld_F", state)
        local reloadHandler
        systems.ui.attach({
            ui = { tab = function() end },
            onActivate = function() end,
            onCommit = function() end,
            onReload = function(callback)
                reloadHandler = callback
            end,
        })
        reloadHandler(nil, runtime, {
            hadSettingChanges = function()
                return true
            end,
        })
        local plan = systems.route.biomePlans.lookup.Underworld_F
        local view = systems.ui.coordinator:get().routes.lookup.Underworld
            .biomes.lookup.Underworld_F

        local batch = view.batches[2]
        lu.assertEquals(#batch.targets, 2)
        lu.assertTrue(batch.targets[1].available)
        lu.assertFalse(batch.targets[2].available)
        lu.assertTrue(batch.targets[2].room.picked)
        lu.assertEquals(
            batch.targets[2].unavailableLabel,
            "Exit 2 is unavailable for Combat 01 (1 exit)"
        )
        lu.assertEquals(
            batch.targets[2].unavailableDisplayLabel,
            "Exit 2 is unavailable for Combat 01 (1 exit) [Picked]"
        )
        lu.assertTrue(batch.hasUnavailableTargets)
        lu.assertFalse(batch.canReconcileExitCapacity)
        lu.assertEquals(
            batch.reconcileButtonLabel,
            "Remove Unavailable Exits##RunPlanner_ReconcileExitCapacity_"
                .. "Underworld_F_Combat01"
        )

        local uiAccess = systems.route.stateAccess.createUi(
            runtime,
            systems.catalog,
            systems.route.storage
        )
        local topology = plan:apply(uiAccess, {
            kind = "SetPicked",
            parentRoomControlKey = "Underworld_F_Combat01",
            exitIndex = 1,
        })
        lu.assertEquals(
            topology.terminalTransition.parentRoomControlKey,
            "Underworld_F_Combat04"
        )
        reloadHandler(nil, runtime, {
            hadSettingChanges = function()
                return true
            end,
        })
        view = systems.ui.coordinator:get().routes.lookup.Underworld
            .biomes.lookup.Underworld_F
        lu.assertTrue(view.batches[2].canReconcileExitCapacity)
        lu.assertEquals(
            view.terminal.parentRoomControlKey,
            "Underworld_F_Combat04"
        )
    end)
end

function TestUiEditor.testLinearProjectionExposesOnlyTheActiveFrontier()
    h.withImport(function()
        local systems = load()
        local state = completeFState()
        state.terminalTransition = { parentRoomControlKey = "" }
        local plan = systems.route.biomePlans.lookup.Underworld_F
        local topology = plan:readTopology(directAccess(state))
        local view = systems.ui.layouts.LinearBiome:project(
            plan,
            topology,
            systems.ui.selectors.biomes.lookup.Underworld_F
        )

        lu.assertNil(view.terminal)
        lu.assertEquals(view.tail.parentRoomControlKey, "Underworld_F_Combat04")
        lu.assertEquals(view.tail.heading, "Continue from Combat 04 (2 exits)")
        lu.assertTrue(view.tail.canCreateBatch)
        lu.assertEquals(
            view.tail.addBatchButtonLabel,
            "Add Next Decision##RunPlanner_CreateBatch_Underworld_F_Combat04"
        )
        lu.assertEquals(
            view.tail.prebossButtonLabel,
            "Go to Preboss##RunPlanner_CreateTerminalTransition_Underworld_F_Combat04"
        )
    end)
end


local function fakeField(alias, initial)
    local value = initial or ""
    return {
        alias = alias,
        controlId = function()
            return alias
        end,
        read = function()
            return value
        end,
        write = function(_, nextValue)
            value = nextValue
        end,
    }
end

local function fakeDrawUi(changes)
    local fields = {}
    local commands = {}
    local drawnControls = {}
    local indentDepth = 0
    local plan = {
        apply = function(_, command)
            commands[#commands + 1] = command
        end,
        clearTopology = function()
            commands[#commands + 1] = { kind = "ClearTopology" }
        end,
    }
    local imgui = {
        AlignTextToFramePadding = function() end,
        Button = function(label)
            if changes[label] == true then
                changes[label] = nil
                return true
            end
            return false
        end,
        Indent = function(width)
            lu.assertEquals(width, 40)
            indentDepth = indentDepth + width
        end,
        RadioButton = function(label)
            if changes[label] == true then
                changes[label] = nil
                return true
            end
            return false
        end,
        SameLine = function() end,
        Spacing = function() end,
        TextDisabled = function() end,
        Unindent = function(width)
            lu.assertEquals(width, 40)
            lu.assertEquals(indentDepth, width)
            indentDepth = indentDepth - width
        end,
    }
    local ui = {
        data = {
            get = function(alias)
                fields[alias] = fields[alias] or fakeField(alias)
                return fields[alias]
            end,
        },
        controls = {
            get = function(key)
                return key
            end,
        },
        draw = {
            imgui = imgui,
            widgets = {
                text = function() end,
                separator = function() end,
                confirmButton = function()
                    return false
                end,
                dropdown = function(field)
                    local nextValue = changes[field.alias]
                    if nextValue == nil then
                        return false
                    end
                    changes[field.alias] = nil
                    field:write(nextValue)
                    return true
                end,
            },
            control = function(control)
                lu.assertEquals(indentDepth, 40)
                drawnControls[#drawnControls + 1] = control
            end,
        },
    }
    return ui, plan, commands, drawnControls
end

local function commandFixture()
    local opts = { values = {}, displayValues = {} }
    local categoryOpts = {
        values = { "", "Combat", "Miniboss" },
        displayValues = {
            [""] = "Select...",
            Combat = "Combat",
            Miniboss = "Miniboss",
        },
        valueLookup = { [""] = true, Combat = true, Miniboss = true },
    }
    return {
        key = "Underworld_F",
        label = "Erebus",
        start = {
            current = "Underworld_F_Opening02",
            selectorAlias = "start",
            opts = opts,
        },
        batches = {
            {
                ordinal = 1,
                parentRoomControlKey = "Underworld_F_Opening02",
                parentLabel = "F_Opening02",
                heading = "Decision 1 - From F_Opening02",
                removeButtonLabel = "Remove From Here##Batch1",
                singleExit = false,
                targets = {
                    {
                        exitIndex = 1,
                        current = "",
                        pickedRadioLabel = "Picked##Target1",
                        category = {
                            current = nil,
                            selectorAlias = "category",
                            opts = categoryOpts,
                        },
                        roomChoice = {
                            selectorAlias = "target",
                            optsByCategory = {
                                Combat = opts,
                                Miniboss = opts,
                            },
                        },
                    },
                },
            },
        },
    }
end

function TestUiEditor.testLinearDrawTranslatesSelectorsIntoSemanticCommands()
    h.withImport(function()
        local drawer = h.testImport("mods/ui/layouts/linear_biome_draw.lua")
        local view = commandFixture()
        local changes = { category = "Combat" }
        local ui, plan, commands = fakeDrawUi(changes)
        drawer.draw(ui, view, plan)
        lu.assertEquals(commands, {})

        changes.target = "Underworld_F_Combat03"
        drawer.draw(ui, view, plan)
        lu.assertEquals(commands, {
            {
                kind = "SetTarget",
                parentRoomControlKey = "Underworld_F_Opening02",
                exitIndex = 1,
                roomControlKey = "Underworld_F_Combat03",
            },
        })

        view.batches[1].targets[1].current = "Underworld_F_Combat03"
        view.batches[1].targets[1].category.current = "Combat"
        view.batches[1].targets[1].room = {
            picked = false,
            roomControlKey = "Underworld_F_Combat03",
        }
        ui, plan, commands = fakeDrawUi({ ["Picked##Target1"] = true })
        drawer.draw(ui, view, plan)
        lu.assertEquals(commands, {
            {
                kind = "SetPicked",
                parentRoomControlKey = "Underworld_F_Opening02",
                exitIndex = 1,
            },
        })

        view.batches[1].targets[1].current = ""
        view.batches[1].targets[1].category.current = nil
        view.batches[1].targets[1].room = nil
        view.batches[1].singleExit = true
        changes = { category = "Combat" }
        ui, plan, commands = fakeDrawUi(changes)
        drawer.draw(ui, view, plan)
        changes.target = "Underworld_F_Combat03"
        drawer.draw(ui, view, plan)
        lu.assertEquals(commands, {
            {
                kind = "SetTarget",
                parentRoomControlKey = "Underworld_F_Opening02",
                exitIndex = 1,
                roomControlKey = "Underworld_F_Combat03",
            },
            {
                kind = "SetPicked",
                parentRoomControlKey = "Underworld_F_Opening02",
                exitIndex = 1,
            },
        })

        view.batches[1].targets[1].current = "Underworld_F_Combat03"
        view.batches[1].targets[1].category.current = "Combat"
        view.batches[1].targets[1].room = {
            picked = true,
            roomControlKey = "Underworld_F_Combat03",
        }
        view.batches[1].singleExit = false
        changes = { category = "Miniboss" }
        local drawnControls
        ui, plan, commands, drawnControls = fakeDrawUi(changes)
        drawer.draw(ui, view, plan)
        lu.assertEquals(commands, {})
        lu.assertEquals(drawnControls, { "Underworld_F_Combat03" })

        changes.target = ""
        drawer.draw(ui, view, plan)
        lu.assertEquals(commands, {})

        changes.target = "Underworld_F_MiniBoss01"
        drawer.draw(ui, view, plan)
        lu.assertEquals(commands, {
            {
                kind = "SetTarget",
                parentRoomControlKey = "Underworld_F_Opening02",
                exitIndex = 1,
                roomControlKey = "Underworld_F_MiniBoss01",
            },
        })
    end)
end

function TestUiEditor.testLinearDrawDoesNotOfferUnavailableTargetSelection()
    h.withImport(function()
        local drawer = h.testImport("mods/ui/layouts/linear_biome_draw.lua")
        local view = commandFixture()
        local target = view.batches[1].targets[1]
        target.available = false
        target.unavailableDisplayLabel = "Exit 1 is unavailable [Picked]"
        target.room = {
            picked = true,
            roomControlKey = "Underworld_F_Combat03",
        }
        local ui, plan, commands, drawnControls = fakeDrawUi({
            [target.pickedRadioLabel] = true,
        })

        drawer.draw(ui, view, plan)

        lu.assertEquals(commands, {})
        lu.assertEquals(drawnControls, { "Underworld_F_Combat03" })
    end)
end

function TestUiEditor.testLinearDrawTranslatesStructuralButtonsIntoSemanticCommands()
    h.withImport(function()
        local drawer = h.testImport("mods/ui/layouts/linear_biome_draw.lua")
        local view = commandFixture()
        local ui, plan, commands = fakeDrawUi({
            ["Remove From Here##Batch1"] = true,
        })
        drawer.draw(ui, view, plan)
        lu.assertEquals(commands, {
            {
                kind = "RemoveBatch",
                parentRoomControlKey = "Underworld_F_Opening02",
            },
        })

        view = commandFixture()
        view.batches[1].hasUnavailableTargets = true
        view.batches[1].canReconcileExitCapacity = true
        view.batches[1].reconcileButtonLabel = "Remove Unavailable Exits##Batch1"
        ui, plan, commands = fakeDrawUi({
            ["Remove Unavailable Exits##Batch1"] = true,
        })
        drawer.draw(ui, view, plan)
        lu.assertEquals(commands, {
            {
                kind = "ReconcileExitCapacity",
                parentRoomControlKey = "Underworld_F_Opening02",
            },
        })

        view.batches = {}
        view.tail = {
            parentRoomControlKey = "Underworld_F_Combat03",
            heading = "Continue from Combat 03",
            canCreateBatch = true,
            addBatchButtonLabel = "Add Next Decision##FrontierBatch",
            prebossButtonLabel = "Go to Preboss##FrontierPreboss",
        }
        ui, plan, commands = fakeDrawUi({
            ["Add Next Decision##FrontierBatch"] = true,
        })
        drawer.draw(ui, view, plan)
        lu.assertEquals(commands, {
            {
                kind = "CreateBatch",
                parentRoomControlKey = "Underworld_F_Combat03",
            },
        })

        view.tail.canCreateBatch = false
        ui, plan, commands = fakeDrawUi({
            ["Go to Preboss##FrontierPreboss"] = true,
        })
        drawer.draw(ui, view, plan)
        lu.assertEquals(commands, {
            {
                kind = "CreateTerminalTransition",
                parentRoomControlKey = "Underworld_F_Combat03",
            },
        })

        view.tail = nil
        view.terminal = {
            parentRoomControlKey = "Underworld_F_Combat03",
            heading = "Preboss",
            continueButtonLabel = "Continue With Rooms##TerminalContinue",
            removeButtonLabel = "Remove##TerminalRemove",
            room = { label = "Preboss", roomControlKey = "Underworld_F_PreBoss01" },
            roomContext = {},
        }
        ui, plan, commands = fakeDrawUi({
            ["Continue With Rooms##TerminalContinue"] = true,
        })
        drawer.draw(ui, view, plan)
        lu.assertEquals(commands, {
            {
                kind = "ReplaceWithBatch",
                parentRoomControlKey = "Underworld_F_Combat03",
            },
        })

        ui, plan, commands = fakeDrawUi({
            ["Remove##TerminalRemove"] = true,
        })
        drawer.draw(ui, view, plan)
        lu.assertEquals(commands, {
            { kind = "RemoveTerminalTransition" },
        })
    end)
end

function TestUiEditor.testOuterShellDrawsDeclaredRouteLabels()
    h.withImport(function()
        local systems = load()
        systems.ui.coordinator:rebuild(emptyRuntime(systems, ""))
        local fields = {}
        local texts = {}
        local imgui = {
            BeginTabBar = function()
                return true
            end,
            BeginTabItem = function()
                return true
            end,
            EndTabItem = function() end,
            EndTabBar = function() end,
            BeginChild = function() end,
            EndChild = function() end,
            Spacing = function() end,
        }
        local ui = {
            data = {
                get = function(alias)
                    fields[alias] = fields[alias] or fakeField(alias, "route")
                    return fields[alias]
                end,
            },
            controls = {
                get = function(key)
                    return key
                end,
            },
            draw = {
                imgui = imgui,
                nav = {
                    verticalTabs = function(opts)
                        return opts.activeKey
                    end,
                },
                widgets = {
                    text = function(value)
                        texts[#texts + 1] = value
                    end,
                    separator = function() end,
                    confirmButton = function()
                        return false
                    end,
                },
                control = function() end,
            },
            resetAll = function() end,
        }

        systems.ui.drawTab(nil, ui)

        lu.assertTrue(contains(texts, "Underworld Route"))
        lu.assertTrue(contains(texts, "Surface Route"))
    end)
end

return TestUiEditor
