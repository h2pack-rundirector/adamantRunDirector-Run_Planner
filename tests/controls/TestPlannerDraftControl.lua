-- luacheck: globals TestPlannerDraftControl
-- luacheck: no unused args

local lu = require("luaunit")
local h = dofile("tests/support/import_harness.lua")

TestPlannerDraftControl = {}

local function copyTable(source)
    if source == nil then
        return nil
    end

    local copy = {}
    for key, value in pairs(source) do
        if type(value) == "table" then
            copy[key] = copyTable(value)
        else
            copy[key] = value
        end
    end
    return copy
end

local function tableHandle(initialRows)
    local rows = copyTable(initialRows or {})
    local handle = {}

    function handle:count()
        return #rows
    end

    function handle:read(rowIndex, alias)
        local row = rows[rowIndex]
        return row and row[alias] or nil
    end

    function handle:clear()
        local changed = #rows > 0
        rows = {}
        return changed
    end

    function handle:append(row)
        rows[#rows + 1] = copyTable(row or {})
        return true
    end

    function handle:snapshots()
        return copyTable(rows)
    end

    return handle
end

local function fields(initial)
    initial = initial or {}
    return {
        Rooms = tableHandle(initial.Rooms),
        GeneratedDoors = tableHandle(initial.GeneratedDoors),
        GeneratedDoorOffers = tableHandle(initial.GeneratedDoorOffers),
        RoomOffers = tableHandle(initial.RoomOffers),
    }
end

local function sampleDraft()
    return h.testImport("mods/forms/defaults.lua").fSampleDraft()
end

function TestPlannerDraftControl.testStorageDeclaresFlatDraftTables()
    h.withTestImport(function()
        local template = h.testImport("mods/controls/PlannerDraft/PlannerDraft.lua")
        local storage = template.storage()

        lu.assertEquals(storage[1].key, "Rooms")
        lu.assertEquals(storage[1].type, "table")
        lu.assertEquals(storage[1].defaultRows, 0)
        lu.assertEquals(storage[2].key, "GeneratedDoors")
        lu.assertEquals(storage[3].key, "GeneratedDoorOffers")
        lu.assertEquals(storage[4].key, "RoomOffers")
    end)
end

function TestPlannerDraftControl.testEmptyStorageReadsDefaultFDraft()
    h.withTestImport(function()
        local template = h.testImport("mods/controls/PlannerDraft/PlannerDraft.lua")
        local instance = template.prepare({})
        local control = template.createRuntime(fields(), instance)

        lu.assertEquals(control:readDraft(), sampleDraft())
    end)
end

function TestPlannerDraftControl.testUiControlWritesAndReadsFlatDraftRows()
    h.withTestImport(function()
        local template = h.testImport("mods/controls/PlannerDraft/PlannerDraft.lua")
        local instance = template.prepare({})
        local currentFields = fields()
        local control = template.createUi(currentFields, instance)

        lu.assertTrue(control:writeDraft(sampleDraft()))

        lu.assertEquals(currentFields.Rooms:count(), 2)
        lu.assertEquals(currentFields.GeneratedDoors:count(), 2)
        lu.assertEquals(currentFields.GeneratedDoorOffers:count(), 2)
        lu.assertEquals(currentFields.RoomOffers:count(), 0)
        lu.assertEquals(currentFields.Rooms:read(1, "RoomKey"), "F_Opening01")
        lu.assertEquals(currentFields.GeneratedDoorOffers:read(1, "PayloadSource"), "AphroditeUpgrade")
        lu.assertEquals(control:readDraft(), sampleDraft())
    end)
end

function TestPlannerDraftControl.testStoredRowsCanMaterializeIncompleteDraft()
    h.withTestImport(function()
        local template = h.testImport("mods/controls/PlannerDraft/PlannerDraft.lua")
        local instance = template.prepare({})
        local control = template.createRuntime(fields({
            Rooms = {
                {
                    RouteKey = "Underworld",
                    BiomeIndex = 1,
                    BiomeKey = "F",
                    RoomIndex = 1,
                    RoomKey = "F_Opening01",
                    SelectedDoorIndex = 1,
                    BatchRule = "Standard",
                },
            },
        }), instance)

        lu.assertEquals(control:readDraft(), {
            routeKey = "Underworld",
            biomes = {
                {
                    biomeKey = "F",
                    rooms = {
                        {
                            roomKey = "F_Opening01",
                            generatedDoors = {
                                batchRule = "Standard",
                                selectedDoorIndex = 1,
                                doors = {},
                            },
                        },
                    },
                },
            },
        })
    end)
end
