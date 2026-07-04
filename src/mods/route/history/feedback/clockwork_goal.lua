local common = (... or {}).common

local function clockworkTarget(record)
    if record.clockworkControl == "routeKind" then
        return {
            tabKey = "rooms",
            controlAlias = "RouteKindKey",
            value = record.clockworkValue,
        }
    elseif record.clockworkControl == "nonGoalKind" then
        return {
            tabKey = "rooms",
            controlAlias = "NonGoalKindKey",
            value = record.clockworkValue,
        }
    end
    return common.targetFor(record)
end

return common.createAdapter({
    targetFor = clockworkTarget,
})
