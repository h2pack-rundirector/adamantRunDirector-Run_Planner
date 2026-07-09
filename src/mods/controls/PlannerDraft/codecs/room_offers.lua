local common = import("mods/controls/PlannerDraft/codecs/common.lua")
local payloadCodec = import("mods/controls/PlannerDraft/codecs/payloads.lua")

local roomOffers = {}

local MAX_OFFERS = 768

local function offerFromRow(row)
    return {
        store = row.store,
        rewardType = row.rewardType,
        acquired = row.acquired == true,
        payload = payloadCodec.fromRow(row),
    }
end

local function readRow(rows, index)
    local row = {
        biomeIndex = rows:read(index, "BiomeIndex"),
        biomeKey = rows:read(index, "BiomeKey"),
        roomIndex = rows:read(index, "RoomIndex"),
        offerPointIndex = rows:read(index, "OfferPointIndex"),
        offerIndex = rows:read(index, "OfferIndex"),
        offerPointKind = rows:read(index, "OfferPointKind"),
        batchKey = rows:read(index, "BatchKey"),
        store = rows:read(index, "Store"),
        rewardType = rows:read(index, "RewardType"),
        acquired = rows:read(index, "Acquired"),
    }
    local payload = payloadCodec.readColumns(rows, index)
    row.payloadSource = payload.payloadSource
    row.payloadSourceA = payload.payloadSourceA
    row.payloadSourceB = payload.payloadSourceB
    return row
end

function roomOffers.storageNode()
    return {
        key = "RoomOffers",
        type = "table",
        maxRows = MAX_OFFERS,
        defaultRows = 0,
        row = payloadCodec.appendStorageColumns(common.routeAddressRows({
            common.intField("OfferPointIndex", 1, 1, 16),
            common.intField("OfferIndex", 1, 1, 16),
            common.stringField("OfferPointKind", "", 64),
            common.stringField("BatchKey", "", 64),
            common.stringField("Store", "", 64),
            common.stringField("RewardType", "", 64),
            common.boolField("Acquired", false),
        })),
    }
end

function roomOffers.read(fields, draft)
    local rows = fields.RoomOffers
    for index = 1, rows:count() do
        local row = readRow(rows, index)
        local biome = common.ensureBiome(draft, row.biomeIndex, row.biomeKey)
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
            offerPoint.offers[row.offerIndex] = offerFromRow(row)
        end
    end
end

function roomOffers.append(fields, routeKey, biomeIndex, biomeKey, roomIndex, offerPointIndex, offerPoint, offerIndex, offer)
    local payload = payloadCodec.toColumns(offer)
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

return roomOffers
