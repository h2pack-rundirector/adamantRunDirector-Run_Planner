local guard = import("mods/declarations/guard.lua")

local candidateProvider = {}

local function emptyArray(size, value)
    local result = {}
    for index = 1, size do
        result[index] = value
    end
    return result
end

function candidateProvider.create(opts)
    opts = opts or {}

    local key = guard.expectString(opts.key, "candidateProvider.key")
    local values = guard.expectArray(opts.values or {}, "candidateProvider.values")
    local labels = guard.expectArray(opts.labels or {}, "candidateProvider.labels")
    if #values ~= #labels then
        guard.fail("candidateProvider.labels", "labels must match values length")
    end

    local provider = {
        key = key,
        version = opts.version or 1,
        values = values,
        labels = labels,
        hidden = opts.hidden or emptyArray(#values, false),
        colors = opts.colors or emptyArray(#values, nil),
        messages = opts.messages or emptyArray(#values, nil),
    }

    function provider.clearCandidateFeedback()
        for index = 1, #provider.values do
            provider.hidden[index] = false
            provider.colors[index] = nil
            provider.messages[index] = nil
        end
    end

    function provider.applyCandidateFeedback(feedback)
        if feedback.providerVersion ~= provider.version then
            return false
        end

        local index = feedback.candidateIndex
        if index == nil or index < 1 or index > #provider.values then
            return false
        end

        provider.hidden[index] = feedback.presentation == "hide"
        provider.colors[index] = feedback.color
        provider.messages[index] = feedback.message
        return true
    end

    function provider.exportCandidates(out, formAddress, context)
        if opts.exportCandidates ~= nil then
            opts.exportCandidates(out, formAddress, context)
        end
    end

    return provider
end

return candidateProvider
