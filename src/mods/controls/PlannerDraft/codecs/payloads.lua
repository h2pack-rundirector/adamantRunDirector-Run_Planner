local common = import("mods/controls/PlannerDraft/codecs/common.lua")

local payloads = {}

local MAX_PAYLOAD_LEN = 64

local function concreteString(value)
    return type(value) == "string" and value ~= "" and value or nil
end

function payloads.appendStorageColumns(row)
    row[#row + 1] = common.stringField("PayloadSource", "", MAX_PAYLOAD_LEN)
    row[#row + 1] = common.stringField("PayloadSourceA", "", MAX_PAYLOAD_LEN)
    row[#row + 1] = common.stringField("PayloadSourceB", "", MAX_PAYLOAD_LEN)
    return row
end

function payloads.readColumns(rows, index)
    return {
        payloadSource = rows:read(index, "PayloadSource"),
        payloadSourceA = rows:read(index, "PayloadSourceA"),
        payloadSourceB = rows:read(index, "PayloadSourceB"),
    }
end

function payloads.fromRow(row)
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

function payloads.toColumns(offer)
    local payload = offer and offer.payload or nil
    local sources = type(payload) == "table" and payload.sources or nil
    return {
        PayloadSource = type(payload) == "table" and payload.source or "",
        PayloadSourceA = type(sources) == "table" and sources[1] or "",
        PayloadSourceB = type(sources) == "table" and sources[2] or "",
    }
end

return payloads
