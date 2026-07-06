local guard = import("mods/declarations/guard.lua")

local common = {}

function common.shallowCopy(source)
    local copy = {}
    for key, value in pairs(source) do
        copy[key] = value
    end
    return copy
end

function common.packageOrderedMap(ordered, context)
    return {
        ordered = ordered,
        lookup = guard.indexByKey(ordered, context),
    }
end

return common
