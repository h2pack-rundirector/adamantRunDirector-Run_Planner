local query = {}

local VANILLA_ROLE_KEY = "Vanilla"

local function numeric(value)
    if value == nil then
        return nil
    end
    return tonumber(value)
end

function query.runDepthCache(context)
    return context and context.runDepthCache or nil
end

function query.biomeDepthCache(context)
    return context and context.biomeDepthCache or nil
end

function query.enteredBiomes(context)
    return context and context.routeBiomeIndex or nil
end

function query.runEncounterDepth(context)
    return context and context.runEncounterDepth or nil
end

function query.biomeEncounterDepth(context)
    return context and context.biomeEncounterDepth or nil
end

function query.roomsSinceDepth(context, previousRunDepthCache)
    local current = query.runDepthCache(context)
    if current == nil or previousRunDepthCache == nil then
        return nil
    end
    return current - previousRunDepthCache
end

function query.minRoomsSinceDepth(context, previousRunDepthCache, count)
    local rooms = query.roomsSinceDepth(context, previousRunDepthCache)
    return rooms ~= nil and rooms >= count
end

function query.exitCount(row)
    if row == nil or row.valid == false or row.roleKey == VANILLA_ROLE_KEY then
        return nil
    end

    local topology = row.roomTopology
    local value = numeric(topology and topology.exitCount)
    if value ~= nil then
        return value
    end

    value = numeric(row.exitCount)
    if value ~= nil then
        return value
    end

    return numeric(row.option and row.option.exitCount)
end

function query.requiredMinExits(row, count)
    local exitCount = query.exitCount(row)
    return exitCount ~= nil and exitCount >= count
end

return query
