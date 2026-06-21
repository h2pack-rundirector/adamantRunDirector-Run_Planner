local deps = ... or {}
local majorMinor = deps.majorMinor or import("mods/rewards/surfaces/major_minor.lua", nil, {
    common = deps.common,
})

local shipWheel = {}

function shipWheel.create(definitions, context)
    return majorMinor.create(definitions, {
        kind = "majorMinor",
        majorRewardStore = context.defaultRewardStore or "RunProgress",
        minorRewardStore = "MetaProgress",
        eligibleRewardTypes = context.eligibleRewardTypes,
        ineligibleRewardTypes = context.ineligibleRewardTypes,
    })
end

return shipWheel
