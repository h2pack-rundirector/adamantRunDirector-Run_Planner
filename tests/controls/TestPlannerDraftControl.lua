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

local function scalarHandle(initialValue)
    local value = initialValue or 0
    local handle = {}

    function handle:read()
        return value
    end

    function handle:write(nextValue)
        value = nextValue
        return true
    end

    return handle
end

local function fields(initial)
    initial = initial or {}
    return {
        Revision = scalarHandle(initial.Revision),
        Rooms = tableHandle(initial.Rooms),
        GeneratedDoors = tableHandle(initial.GeneratedDoors),
        GeneratedDoorOffers = tableHandle(initial.GeneratedDoorOffers),
        RoomOffers = tableHandle(initial.RoomOffers),
    }
end

local function nodeByKey(storage, key)
    for _, node in ipairs(storage) do
        if node.key == key then
            return node
        end
    end
    return nil
end

local function rowKeys(node)
    local keys = {}
    for _, column in ipairs(node.row or {}) do
        keys[#keys + 1] = column.key
    end
    return keys
end

local function assertNoDerivedColumns(rows)
    local forbidden = {
        candidateProviders = true,
        feedback = true,
        history = true,
    }
    for _, row in ipairs(rows or {}) do
        for key in pairs(forbidden) do
            lu.assertNil(row[key])
        end
    end
end

local function sampleDraft()
    return h.testImport("mods/forms/defaults.lua").fSampleDraft()
end

local function representativeDraft()
    return {
        routeKey = "Underworld",
        biomes = {
            {
                biomeKey = "F",
                rooms = {
                    {
                        roomKey = "F_Opening01",
                        generatedDoors = {
                            batchRule = "Standard",
                            selectedDoorIndex = 2,
                            doors = {
                                {
                                    exitIndex = 1,
                                    targetRoomKey = "F_Combat01",
                                    offerPoint = {
                                        kind = "generatedDoorRewards",
                                        batchKey = "nextDoors",
                                        offers = {
                                            {
                                                store = "RunProgress",
                                                rewardType = "Boon",
                                                acquired = true,
                                                payload = {
                                                    source = "AphroditeUpgrade",
                                                },
                                            },
                                        },
                                    },
                                },
                                {
                                    exitIndex = 2,
                                    targetRoomKey = "F_Shop01",
                                    offerPoint = {
                                        kind = "generatedDoorRewards",
                                        batchKey = "nextDoors",
                                        offers = {
                                            {
                                                store = "RunProgress",
                                                rewardType = "Devotion",
                                                acquired = false,
                                                payload = {
                                                    sources = {
                                                        "PoseidonUpgrade",
                                                        "ApolloUpgrade",
                                                    },
                                                },
                                            },
                                        },
                                    },
                                },
                            },
                        },
                    },
                    {
                        roomKey = "F_Shop01",
                        offerPoints = {
                            {
                                kind = "roomRewards",
                                batchKey = "room",
                                offers = {
                                    {
                                        store = "WorldShop",
                                        rewardType = "RoomRewardMoneyDrop",
                                        acquired = true,
                                    },
                                },
                            },
                        },
                    },
                    {
                        roomKey = "F_PreBoss01",
                    },
                },
            },
        },
    }
end

function TestPlannerDraftControl.testStorageDeclaresFlatDraftTables()
    h.withTestImport(function()
        local template = h.testImport("mods/controls/PlannerDraft/PlannerDraft.lua")
        local storage = template.storage()

        lu.assertEquals(nodeByKey(storage, "Revision").type, "int")
        lu.assertEquals(nodeByKey(storage, "Rooms").type, "table")
        lu.assertEquals(nodeByKey(storage, "Rooms").defaultRows, 0)
        lu.assertEquals(nodeByKey(storage, "GeneratedDoors").type, "table")
        lu.assertEquals(nodeByKey(storage, "GeneratedDoorOffers").type, "table")
        lu.assertEquals(nodeByKey(storage, "RoomOffers").type, "table")
    end)
end

function TestPlannerDraftControl.testStorageDeclaresFlatRowSchemas()
    h.withTestImport(function()
        local template = h.testImport("mods/controls/PlannerDraft/PlannerDraft.lua")
        local storage = template.storage()

        lu.assertEquals(rowKeys(nodeByKey(storage, "Rooms")), {
            "RouteKey",
            "BiomeIndex",
            "BiomeKey",
            "RoomIndex",
            "RoomKey",
            "SelectedDoorIndex",
            "BatchRule",
        })
        lu.assertEquals(rowKeys(nodeByKey(storage, "GeneratedDoors")), {
            "RouteKey",
            "BiomeIndex",
            "BiomeKey",
            "RoomIndex",
            "DoorIndex",
            "ExitIndex",
            "TargetRoomKey",
        })
        lu.assertEquals(rowKeys(nodeByKey(storage, "GeneratedDoorOffers")), {
            "RouteKey",
            "BiomeIndex",
            "BiomeKey",
            "RoomIndex",
            "DoorIndex",
            "OfferIndex",
            "OfferPointKind",
            "BatchKey",
            "Store",
            "RewardType",
            "Acquired",
            "PayloadSource",
            "PayloadSourceA",
            "PayloadSourceB",
        })
        lu.assertEquals(rowKeys(nodeByKey(storage, "RoomOffers")), {
            "RouteKey",
            "BiomeIndex",
            "BiomeKey",
            "RoomIndex",
            "OfferPointIndex",
            "OfferIndex",
            "OfferPointKind",
            "BatchKey",
            "Store",
            "RewardType",
            "Acquired",
            "PayloadSource",
            "PayloadSourceA",
            "PayloadSourceB",
        })
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

function TestPlannerDraftControl.testUiControlIncrementsRevisionOnWrite()
    h.withTestImport(function()
        local template = h.testImport("mods/controls/PlannerDraft/PlannerDraft.lua")
        local instance = template.prepare({})
        local currentFields = fields()
        local control = template.createUi(currentFields, instance)

        lu.assertEquals(control:revision(), 0)

        lu.assertTrue(control:writeDraft(sampleDraft()))
        lu.assertEquals(control:revision(), 1)

        lu.assertTrue(control:writeDraft(sampleDraft()))
        lu.assertEquals(control:revision(), 2)
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

function TestPlannerDraftControl.testUiControlRoundtripsRepresentativeFDraft()
    h.withTestImport(function()
        local template = h.testImport("mods/controls/PlannerDraft/PlannerDraft.lua")
        local instance = template.prepare({})
        local currentFields = fields()
        local control = template.createUi(currentFields, instance)
        local draft = representativeDraft()

        lu.assertTrue(control:writeDraft(draft))

        lu.assertEquals(currentFields.Rooms:count(), 3)
        lu.assertEquals(currentFields.GeneratedDoors:count(), 2)
        lu.assertEquals(currentFields.GeneratedDoorOffers:count(), 2)
        lu.assertEquals(currentFields.RoomOffers:count(), 1)
        lu.assertEquals(currentFields.Rooms:read(1, "SelectedDoorIndex"), 2)
        lu.assertEquals(currentFields.GeneratedDoorOffers:read(2, "PayloadSourceA"), "PoseidonUpgrade")
        lu.assertEquals(currentFields.GeneratedDoorOffers:read(2, "PayloadSourceB"), "ApolloUpgrade")
        lu.assertEquals(currentFields.RoomOffers:read(1, "Store"), "WorldShop")
        lu.assertEquals(control:readDraft(), draft)
    end)
end

function TestPlannerDraftControl.testUiControlDoesNotSerializeDerivedState()
    h.withTestImport(function()
        local template = h.testImport("mods/controls/PlannerDraft/PlannerDraft.lua")
        local instance = template.prepare({})
        local currentFields = fields()
        local control = template.createUi(currentFields, instance)
        local draft = representativeDraft()

        draft.feedback = { status = "invalid" }
        draft.history = { rooms = { "F_Opening01" } }
        draft.candidateProviders = { route = {} }
        draft.biomes[1].feedback = { status = "invalid" }
        draft.biomes[1].rooms[1].candidateProviders = { roomKey = {} }
        draft.biomes[1].rooms[1].generatedDoors.doors[1].feedback = { status = "invalid" }
        draft.biomes[1].rooms[1].generatedDoors.doors[1].candidateProviders = { nextDoorTarget = {} }
        draft.biomes[1].rooms[1].generatedDoors.doors[1].offerPoint.offers[1].feedback = { status = "invalid" }
        draft.biomes[1].rooms[1].generatedDoors.doors[1].offerPoint.offers[1].candidateProviders = { rewardType = {} }
        draft.biomes[1].rooms[2].offerPoints[1].offers[1].history = { reward = "seen" }

        lu.assertTrue(control:writeDraft(draft))

        assertNoDerivedColumns(currentFields.Rooms:snapshots())
        assertNoDerivedColumns(currentFields.GeneratedDoors:snapshots())
        assertNoDerivedColumns(currentFields.GeneratedDoorOffers:snapshots())
        assertNoDerivedColumns(currentFields.RoomOffers:snapshots())
        lu.assertEquals(control:readDraft(), representativeDraft())
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

function TestPlannerDraftControl.testStoredChildRowsDoNotMaterializeMissingParents()
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
                    SelectedDoorIndex = 0,
                    BatchRule = "",
                },
            },
            GeneratedDoorOffers = {
                {
                    RouteKey = "Underworld",
                    BiomeIndex = 1,
                    BiomeKey = "F",
                    RoomIndex = 1,
                    DoorIndex = 1,
                    OfferIndex = 1,
                    OfferPointKind = "generatedDoorRewards",
                    BatchKey = "nextDoors",
                    Store = "RunProgress",
                    RewardType = "Boon",
                    Acquired = false,
                    PayloadSource = "AphroditeUpgrade",
                    PayloadSourceA = "",
                    PayloadSourceB = "",
                },
            },
            RoomOffers = {
                {
                    RouteKey = "Underworld",
                    BiomeIndex = 1,
                    BiomeKey = "F",
                    RoomIndex = 2,
                    OfferPointIndex = 1,
                    OfferIndex = 1,
                    OfferPointKind = "roomRewards",
                    BatchKey = "room",
                    Store = "WorldShop",
                    RewardType = "RoomRewardMoneyDrop",
                    Acquired = true,
                    PayloadSource = "",
                    PayloadSourceA = "",
                    PayloadSourceB = "",
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
                        },
                    },
                },
            },
        })
    end)
end
