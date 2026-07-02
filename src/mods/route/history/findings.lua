local findings = {}
local formAddress = import("mods/route/history/form_address.lua")

local function copyFields(target, fields)
    for key, value in pairs(fields or {}) do
        target[key] = value
    end
    return target
end

local function base(kind, entry, reason, fields)
    return copyFields({
        kind = kind,
        reason = reason,
        routeKey = entry and entry.routeKey or nil,
        biomeKey = entry and entry.biomeKey or nil,
        routeBiomeIndex = entry and entry.routeBiomeIndex or nil,
        rowIndex = entry and entry.rowIndex or nil,
        formAddress = formAddress.withRowFallback(entry and entry.formAddress or nil, entry and entry.rowIndex or nil),
        routeOrdinal = entry and entry.routeOrdinal or nil,
        roomHistoryOrdinal = entry and entry.roomHistoryOrdinal or nil,
        entry = entry,
    }, fields)
end

function findings.roomCandidateInvalid(entry, candidate, reason, fields)
    return base("roomCandidateInvalid", entry, reason, copyFields({
        roleKey = candidate and candidate.roleKey or nil,
        optionKey = candidate and candidate.optionKey or nil,
        roomKey = candidate and candidate.roomKey or nil,
        candidate = candidate,
    }, fields))
end

function findings.siblingCandidateInvalid(entry, candidate, reason, fields)
    return base("siblingCandidateInvalid", entry, reason, copyFields({
        siblingIndex = candidate and candidate.siblingIndex or nil,
        structureKey = candidate and candidate.structureKey or nil,
        roomKey = candidate and candidate.roomKey or nil,
        candidate = candidate,
    }, fields))
end

function findings.variantCandidateInvalid(entry, candidate, reason, fields)
    return base("variantCandidateInvalid", entry, reason, copyFields({
        variantKey = candidate and candidate.key or nil,
        candidate = candidate,
    }, fields))
end

function findings.rewardCandidateInvalid(entry, candidate, rewardType, reason, fields)
    return base("rewardCandidateInvalid", entry, reason, copyFields({
        address = candidate and candidate.address or nil,
        rewardClass = candidate and candidate.rewardClass or nil,
        rewardStore = candidate and candidate.rewardStore or nil,
        rewardType = rewardType,
        candidate = candidate,
    }, fields))
end

function findings.rowInactiveBoundary(entry, reason, fields)
    return base("rowInactiveBoundary", entry, reason, fields)
end

return findings
