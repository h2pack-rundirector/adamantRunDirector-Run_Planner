local deps = ... or {}

local migrationCandidates = {}
local formAddress = import("mods/route/history/form_address.lua")

local roomCandidates = deps.roomCandidates
local rewardCandidates = deps.rewardCandidates
local siblingCandidates = deps.siblingCandidates

local function markMigrationCandidates(entry)
    entry.builderCandidateTables = true
end

function migrationCandidates.attachCurrentRoomCandidates(context, entry, selectedRow, resolved)
    entry.roomCandidates = roomCandidates.forBiomeRow(context.biome, selectedRow, resolved, {
        availabilityContext = entry.phases.generated or entry.phases.entry,
    })
    markMigrationCandidates(entry)
end

function migrationCandidates.attachPickedDoorCandidates(context, entry, nextRow, nextResolved)
    if nextRow == nil or nextResolved == nil then
        return
    end
    local candidates = roomCandidates.forBiomeRow(context.biome, nextRow, nextResolved, {
        availabilityContext = entry.phases.offer,
        targetRowIndex = nextRow.rowIndex,
        targetRouteOrdinal = nextResolved.routeOrdinal,
        targetFormAddress = formAddress.withRowFallback(nextRow.formAddress, nextRow.rowIndex),
    })
    entry.roomCandidates = entry.roomCandidates or {}
    for _, candidate in ipairs(candidates) do
        entry.roomCandidates[#entry.roomCandidates + 1] = candidate
    end
    markMigrationCandidates(entry)
end

function migrationCandidates.attachSiblingCandidates(context, entry, selectedRow)
    entry.siblingCandidates = siblingCandidates.forBiomeRow(context.biome, selectedRow, {
        availabilityContext = entry.phases.offer,
    })
    markMigrationCandidates(entry)
end

function migrationCandidates.attachRewardCandidates(entry, rewardContext, opts)
    entry.rewardCandidates = rewardCandidates.forContext(rewardContext, opts)
    markMigrationCandidates(entry)
end

function migrationCandidates.attachForRoom(context, entry, selectedRow, resolved, opts)
    if opts.attachCurrentRoomCandidates ~= false then
        migrationCandidates.attachCurrentRoomCandidates(context, entry, selectedRow, resolved)
    end
    if opts.attachPickedDoorCandidates ~= false then
        migrationCandidates.attachPickedDoorCandidates(context, entry, opts.nextRow, opts.nextResolved)
    end
    if opts.attachSiblingCandidates ~= false then
        migrationCandidates.attachSiblingCandidates(context, entry, selectedRow)
    end
    if opts.attachReward ~= false then
        migrationCandidates.attachRewardCandidates(entry, resolved.rewardContext, opts.rewardCandidateOpts)
    end
end

return migrationCandidates
