-- luacheck: no unused args

local defaults = import("mods/forms/defaults.lua")
local common = import("mods/controls/PlannerDraft/codecs/common.lua")
local generatedDoorOfferCodec = import("mods/controls/PlannerDraft/codecs/generated_door_offers.lua")
local generatedDoorCodec = import("mods/controls/PlannerDraft/codecs/generated_doors.lua")
local roomOfferCodec = import("mods/controls/PlannerDraft/codecs/room_offers.lua")
local roomCodec = import("mods/controls/PlannerDraft/codecs/rooms.lua")

local PlannerDraft = {}

local MAX_REVISION = 2147483647

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

local function readDraft(fields, instance)
    if fields.Rooms:count() == 0 then
        return copyTable(instance.defaultDraft)
    end

    local draft = {
        routeKey = "",
        biomes = {},
    }
    roomCodec.read(fields, draft)
    generatedDoorCodec.read(fields, draft)
    generatedDoorOfferCodec.read(fields, draft)
    roomOfferCodec.read(fields, draft)
    return draft
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
                generatedDoorCodec.append(fields, routeKey, biomeIndex, biomeKey, roomIndex, doorIndex, door)
                for offerIndex, offer in ipairs((door.offerPoint and door.offerPoint.offers) or {}) do
                    generatedDoorOfferCodec.append(fields, routeKey, biomeIndex, biomeKey, roomIndex, doorIndex, door.offerPoint, offerIndex, offer)
                end
            end

            for offerPointIndex, offerPoint in ipairs(room.offerPoints or {}) do
                for offerIndex, offer in ipairs(offerPoint.offers or {}) do
                    roomOfferCodec.append(fields, routeKey, biomeIndex, biomeKey, roomIndex, offerPointIndex, offerPoint, offerIndex, offer)
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
        common.intField("Revision", 0, 0, MAX_REVISION),
        roomCodec.storageNode(),
        generatedDoorCodec.storageNode(),
        generatedDoorOfferCodec.storageNode(),
        roomOfferCodec.storageNode(),
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
