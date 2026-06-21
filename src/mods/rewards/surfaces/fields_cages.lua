local deps = ... or {}
local roomStore = deps.roomStore or import("mods/rewards/surfaces/room_store.lua", nil, {
    common = deps.common,
})

local fieldsCages = {}

function fieldsCages.create(definitions, context)
    return roomStore.create(definitions, context)
end

return fieldsCages
