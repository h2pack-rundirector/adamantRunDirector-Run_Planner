local deps = ... or {}
local routeMarkers = deps.markers
local semantics = deps.semantics
local invalidLocations = deps.invalidLocations

local rewardMarkers = {}

local function valueTargets(event)
    local targets = {}
    semantics.valueTargetsForEvent(event, targets)
    return targets
end

local function fields(event)
    return {
        address = event.address,
        rewardType = event.rewardType,
        sourceIndex = event.sourceIndex,
        valueTargets = valueTargets(event),
    }
end

local function markerFromOccurrence(context, occurrence, invalid, markerKind)
    local ctx = occurrence.ctx
    local event = occurrence.event
    return routeMarkers.row(ctx, event.row, invalid, markerKind, {
        scope = "reward",
        locationLabel = invalidLocations.rewardEvent(context, ctx, event),
        fields = fields(event),
    })
end

function rewardMarkers.primary(context, ctx, event, invalid)
    return markerFromOccurrence(context, { ctx = ctx, event = event }, invalid, "primary")
end

function rewardMarkers.related(context, occurrence, invalid)
    return markerFromOccurrence(context, occurrence, invalid, "related")
end

return rewardMarkers
