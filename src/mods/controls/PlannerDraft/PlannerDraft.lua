-- luacheck: no unused args

local defaults = import("mods/forms/defaults.lua")
local roomCodec = import("mods/controls/PlannerDraft/codecs/rooms.lua")

local PlannerDraft = {}

local MAX_ROOMS = 96
local MAX_DOORS = 384
local MAX_OFFERS = 768
local MAX_PAYLOAD_LEN = 64
local MAX_REVISION = 2147483647

local function stringField(key, default, maxLen)
    return {
        key = key,
        type = "string",
        default = default or "",
        maxLen = maxLen or 64,
    }
end

local function intField(key, default, min, max)
    return {
        key = key,
        type = "int",
        default = default or 0,
        min = min or 0,
        max = max or 999,
    }
end

local function boolField(key, default)
    return {
        key = key,
        type = "bool",
        default = default == true,
    }
end

local function routeAddressRows(extra)
    local row = {
        stringField("RouteKey", "Underworld", 32),
        intField("BiomeIndex", 1, 1, 16),
        stringField("BiomeKey", "F", 32),
        intField("RoomIndex", 1, 1, MAX_ROOMS),
    }
    for _, node in ipairs(extra or {}) do
        row[#row + 1] = node
    end
    return row
end

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

local function concreteString(value)
    return type(value) == "string" and value ~= "" and value or nil
end

local function readRevision(fields)
    return fields.Revision:read() or 0
end

local function nextRevision(currentRevision)
    currentRevision = tonumber(currentRevision) or 0
    if currentRevision >= MAX_REVISION then
        return 1
    end
    return currentRevision + 1
end

local function bumpRevision(fields)
    fields.Revision:write(nextRevision(readRevision(fields)))
end

local function payloadFromRow(row)
    if row.rewardType == "Boon" then
        local source = concreteString(row.payloadSource)
        return source and { source = source } or nil
    end

    if row.rewardType == "Devotion" then
        return {
            sources = {
                row.payloadSourceA or "",
                row.payloadSourceB or "",
            },
        }
    end

    return nil
end

local function offerFromRow(row)
    return {
        store = row.store,
        rewardType = row.rewardType,
        acquired = row.acquired == true,
        payload = payloadFromRow(row),
    }
end

local function readOfferRow(rows, index, includeOfferPointIndex)
    local row = {
        routeKey = rows:read(index, "RouteKey"),
        biomeIndex = rows:read(index, "BiomeIndex"),
        biomeKey = rows:read(index, "BiomeKey"),
        roomIndex = rows:read(index, "RoomIndex"),
        doorIndex = rows:read(index, "DoorIndex"),
        offerPointIndex = includeOfferPointIndex and rows:read(index, "OfferPointIndex") or nil,
        offerIndex = rows:read(index, "OfferIndex"),
        offerPointKind = rows:read(index, "OfferPointKind"),
        batchKey = rows:read(index, "BatchKey"),
        store = rows:read(index, "Store"),
        rewardType = rows:read(index, "RewardType"),
        acquired = rows:read(index, "Acquired"),
        payloadSource = rows:read(index, "PayloadSource"),
        payloadSourceA = rows:read(index, "PayloadSourceA"),
        payloadSourceB = rows:read(index, "PayloadSourceB"),
    }
    return row
end

local function appendOffer(target, offerIndex, row)
    target[offerIndex] = offerFromRow(row)
end

local ensureBiome = roomCodec.ensureBiome

local function readGeneratedDoors(fields, draft)
    local rows = fields.GeneratedDoors
    for index = 1, rows:count() do
        local biome = ensureBiome(draft, rows:read(index, "BiomeIndex"), rows:read(index, "BiomeKey"))
        local roomIndex = rows:read(index, "RoomIndex")
        local room = biome.rooms[roomIndex]
        if room == nil then
            room = {
                roomKey = "",
            }
            biome.rooms[roomIndex] = room
        end

        room.generatedDoors = room.generatedDoors or {
            batchRule = "Standard",
            selectedDoorIndex = nil,
            doors = {},
        }
        local doorIndex = rows:read(index, "DoorIndex")
        room.generatedDoors.doors[doorIndex] = {
            exitIndex = rows:read(index, "ExitIndex"),
            targetRoomKey = rows:read(index, "TargetRoomKey"),
        }
    end
end

local function readGeneratedDoorOffers(fields, draft)
    local rows = fields.GeneratedDoorOffers
    for index = 1, rows:count() do
        local row = readOfferRow(rows, index, false)
        local biome = ensureBiome(draft, row.biomeIndex, row.biomeKey)
        local room = biome.rooms[row.roomIndex]
        local generatedDoors = room and room.generatedDoors or nil
        local door = generatedDoors and generatedDoors.doors[row.doorIndex] or nil
        if door ~= nil then
            door.offerPoint = door.offerPoint or {
                kind = row.offerPointKind,
                batchKey = row.batchKey,
                offers = {},
            }
            appendOffer(door.offerPoint.offers, row.offerIndex, row)
        end
    end
end

local function readRoomOffers(fields, draft)
    local rows = fields.RoomOffers
    for index = 1, rows:count() do
        local row = readOfferRow(rows, index, true)
        local biome = ensureBiome(draft, row.biomeIndex, row.biomeKey)
        local room = biome.rooms[row.roomIndex]
        if room ~= nil then
            room.offerPoints = room.offerPoints or {}
            local offerPoint = room.offerPoints[row.offerPointIndex]
            if offerPoint == nil then
                offerPoint = {
                    kind = row.offerPointKind,
                    batchKey = row.batchKey,
                    offers = {},
                }
                room.offerPoints[row.offerPointIndex] = offerPoint
            end
            appendOffer(offerPoint.offers, row.offerIndex, row)
        end
    end
end

local function readDraft(fields, instance)
    if fields.Rooms:count() == 0 then
        return copyTable(instance.defaultDraft)
    end

    local draft = {
        routeKey = "",
        biomes = {},
    }
    roomCodec.read(fields, draft)
    readGeneratedDoors(fields, draft)
    readGeneratedDoorOffers(fields, draft)
    readRoomOffers(fields, draft)
    return draft
end

local function payloadColumns(offer)
    local payload = offer and offer.payload or nil
    local sources = type(payload) == "table" and payload.sources or nil
    return {
        PayloadSource = type(payload) == "table" and payload.source or "",
        PayloadSourceA = type(sources) == "table" and sources[1] or "",
        PayloadSourceB = type(sources) == "table" and sources[2] or "",
    }
end

local function appendGeneratedDoorOfferRow(fields, routeKey, biomeIndex, biomeKey, roomIndex, doorIndex, offerPoint, offerIndex, offer)
    local payload = payloadColumns(offer)
    return fields.GeneratedDoorOffers:append({
        RouteKey = routeKey,
        BiomeIndex = biomeIndex,
        BiomeKey = biomeKey,
        RoomIndex = roomIndex,
        DoorIndex = doorIndex,
        OfferIndex = offerIndex,
        OfferPointKind = offerPoint.kind or "",
        BatchKey = offerPoint.batchKey or "",
        Store = offer.store or "",
        RewardType = offer.rewardType or "",
        Acquired = offer.acquired == true,
        PayloadSource = payload.PayloadSource,
        PayloadSourceA = payload.PayloadSourceA,
        PayloadSourceB = payload.PayloadSourceB,
    })
end

local function appendRoomOfferRow(fields, routeKey, biomeIndex, biomeKey, roomIndex, offerPointIndex, offerPoint, offerIndex, offer)
    local payload = payloadColumns(offer)
    return fields.RoomOffers:append({
        RouteKey = routeKey,
        BiomeIndex = biomeIndex,
        BiomeKey = biomeKey,
        RoomIndex = roomIndex,
        OfferPointIndex = offerPointIndex,
        OfferIndex = offerIndex,
        OfferPointKind = offerPoint.kind or "",
        BatchKey = offerPoint.batchKey or "",
        Store = offer.store or "",
        RewardType = offer.rewardType or "",
        Acquired = offer.acquired == true,
        PayloadSource = payload.PayloadSource,
        PayloadSourceA = payload.PayloadSourceA,
        PayloadSourceB = payload.PayloadSourceB,
    })
end

local function writeDraft(fields, draft)
    fields.Rooms:clear()
    fields.GeneratedDoors:clear()
    fields.GeneratedDoorOffers:clear()
    fields.RoomOffers:clear()

    local routeKey = draft and draft.routeKey or ""
    for biomeIndex, biome in ipairs((draft and draft.biomes) or {}) do
        local biomeKey = biome.biomeKey or ""
        for roomIndex, room in ipairs(biome.rooms or {}) do
            roomCodec.append(fields, routeKey, biomeIndex, biomeKey, roomIndex, room)

            local generatedDoors = room.generatedDoors or {}
            for doorIndex, door in ipairs(generatedDoors.doors or {}) do
                fields.GeneratedDoors:append({
                    RouteKey = routeKey,
                    BiomeIndex = biomeIndex,
                    BiomeKey = biomeKey,
                    RoomIndex = roomIndex,
                    DoorIndex = doorIndex,
                    ExitIndex = door.exitIndex or 0,
                    TargetRoomKey = door.targetRoomKey or "",
                })
                for offerIndex, offer in ipairs((door.offerPoint and door.offerPoint.offers) or {}) do
                    appendGeneratedDoorOfferRow(fields, routeKey, biomeIndex, biomeKey, roomIndex, doorIndex, door.offerPoint, offerIndex, offer)
                end
            end

            for offerPointIndex, offerPoint in ipairs(room.offerPoints or {}) do
                for offerIndex, offer in ipairs(offerPoint.offers or {}) do
                    appendRoomOfferRow(fields, routeKey, biomeIndex, biomeKey, roomIndex, offerPointIndex, offerPoint, offerIndex, offer)
                end
            end
        end
    end

    bumpRevision(fields)
    return true
end

function PlannerDraft.prepare(instance)
    instance.defaultDraft = copyTable(instance.defaultDraft or defaults.fSampleDraft())
    return instance
end

function PlannerDraft.storage()
    return {
        intField("Revision", 0, 0, MAX_REVISION),
        roomCodec.storageNode(),
        {
            key = "GeneratedDoors",
            type = "table",
            maxRows = MAX_DOORS,
            defaultRows = 0,
            row = routeAddressRows({
                intField("DoorIndex", 1, 1, 16),
                intField("ExitIndex", 1, 1, 16),
                stringField("TargetRoomKey", "", 64),
            }),
        },
        {
            key = "GeneratedDoorOffers",
            type = "table",
            maxRows = MAX_OFFERS,
            defaultRows = 0,
            row = routeAddressRows({
                intField("DoorIndex", 1, 1, 16),
                intField("OfferIndex", 1, 1, 16),
                stringField("OfferPointKind", "", 64),
                stringField("BatchKey", "", 64),
                stringField("Store", "", 64),
                stringField("RewardType", "", 64),
                boolField("Acquired", false),
                stringField("PayloadSource", "", MAX_PAYLOAD_LEN),
                stringField("PayloadSourceA", "", MAX_PAYLOAD_LEN),
                stringField("PayloadSourceB", "", MAX_PAYLOAD_LEN),
            }),
        },
        {
            key = "RoomOffers",
            type = "table",
            maxRows = MAX_OFFERS,
            defaultRows = 0,
            row = routeAddressRows({
                intField("OfferPointIndex", 1, 1, 16),
                intField("OfferIndex", 1, 1, 16),
                stringField("OfferPointKind", "", 64),
                stringField("BatchKey", "", 64),
                stringField("Store", "", 64),
                stringField("RewardType", "", 64),
                boolField("Acquired", false),
                stringField("PayloadSource", "", MAX_PAYLOAD_LEN),
                stringField("PayloadSourceA", "", MAX_PAYLOAD_LEN),
                stringField("PayloadSourceB", "", MAX_PAYLOAD_LEN),
            }),
        },
    }
end

function PlannerDraft.createRuntime(fields, instance)
    local control = {}

    function control:readDraft()
        return readDraft(fields, instance)
    end

    function control:revision()
        return readRevision(fields)
    end

    return control
end

function PlannerDraft.createUi(fields, instance)
    local control = PlannerDraft.createRuntime(fields, instance)

    function control:writeDraft(draft)
        return writeDraft(fields, draft)
    end

    function control:field(key)
        return fields[key]
    end

    return control
end

function PlannerDraft.draw()
    return false
end

return PlannerDraft
