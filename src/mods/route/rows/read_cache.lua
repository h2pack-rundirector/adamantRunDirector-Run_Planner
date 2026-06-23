local readCache = {}

local function ensure(instance)
    local cache = instance._readCache
    if cache == nil then
        cache = {
            pass = 0,
            active = false,
            roles = {},
            options = {},
            validations = {},
            roleAvailability = {},
            optionAvailability = {},
            roleValues = {},
            optionValues = {},
            roleValueStates = {},
            optionValueStates = {},
            rowContexts = {},
        }
        instance._readCache = cache
    end
    return cache
end

function readCache.active(instance)
    local cache = instance and instance._readCache or nil
    if cache ~= nil and cache.active then
        return cache
    end
    return nil
end

function readCache.rowRecord(bucket, rowIndex)
    local record = bucket[rowIndex]
    if record == nil then
        record = {}
        bucket[rowIndex] = record
    end
    return record
end

function readCache.nestedRecord(bucket, rowIndex, key)
    local byRow = bucket[rowIndex]
    if byRow == nil then
        byRow = {}
        bucket[rowIndex] = byRow
    end
    local record = byRow[key]
    if record == nil then
        record = {}
        byRow[key] = record
    end
    return record
end

function readCache.begin(instance, externalGeneration)
    local cache = ensure(instance)
    cache.active = true
    if externalGeneration ~= nil and cache.externalGeneration ~= externalGeneration then
        cache.externalGeneration = externalGeneration
        cache.pass = cache.pass + 1
    end
end

function readCache.invalidate(instance)
    local cache = ensure(instance)
    cache.pass = cache.pass + 1
end

function readCache.finish(instance)
    local cache = instance and instance._readCache or nil
    if cache ~= nil then
        cache.active = false
    end
end

return readCache
