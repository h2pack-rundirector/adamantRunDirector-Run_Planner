local deps = ... or {}

local feedbackAdapters = deps.adapters or {}
local routeFeedback = deps.routeFeedback

local feedback = {}

local EMPTY_LIST = {}

local function recordsByBiome(args)
    local findings = args.findings
    local invalids = args.invalids
    local grouped = {}
    local function append(record)
        local biomeKey = record and record.biomeKey or ""
        local records = grouped[biomeKey]
        if records == nil then
            records = {}
            grouped[biomeKey] = records
        end
        records[#records + 1] = record
    end
    for _, record in ipairs(findings or EMPTY_LIST) do
        append(record)
    end
    for _, record in ipairs(invalids or EMPTY_LIST) do
        append(record)
        for _, related in ipairs(record.relatedEvents or EMPTY_LIST) do
            append(routeFeedback.marker(args, related, {
                markerKind = "related",
                message = related.message or record.message,
                code = related.code or record.code,
            }))
        end
    end
    return grouped
end

local function adapterFor(args, biomeKey)
    local biome = args and args.biomeLookup and args.biomeLookup[biomeKey] or nil
    return biome and feedbackAdapters[biome.adapter] or feedbackAdapters.fixedLinear
end

local function translate(args, feedbackState)
    local grouped = recordsByBiome(args)
    for biomeKey, records in pairs(grouped) do
        local adapter = adapterFor(args, biomeKey)
        if adapter ~= nil then
            adapter.translate(feedbackState, records)
        end
    end
end

function feedback.fromResult(args)
    local feedbackState = {
        route = routeFeedback.fromResult(args or {}),
        byBiome = {},
    }
    translate(args or {}, feedbackState)
    return feedbackState
end

function feedback.fromFindings(findings, invalids)
    return feedback.fromResult({
        findings = findings,
        invalids = invalids,
    })
end

function feedback.forBiome(feedbackState, biomeKey)
    return feedbackState and feedbackState.byBiome and feedbackState.byBiome[biomeKey] or nil
end

function feedback.valueStatesForBiomeRow(biomeFeedback, rowIndex, controlAlias)
    local row = biomeFeedback and biomeFeedback[rowIndex] or nil
    return row and row.valueStates and row.valueStates[controlAlias] or nil
end

function feedback.biomeRowInactive(biomeFeedback, rowIndex)
    return biomeFeedback ~= nil
        and biomeFeedback.inactiveAfterRowIndex ~= nil
        and rowIndex ~= nil
        and rowIndex > biomeFeedback.inactiveAfterRowIndex
end

function feedback.valueStatesForControl(feedbackState, biomeKey, rowIndex, controlAlias)
    return feedback.valueStatesForBiomeRow(
        feedback.forBiome(feedbackState, biomeKey),
        rowIndex,
        controlAlias
    )
end

function feedback.rowInactive(feedbackState, biomeKey, rowIndex)
    return feedback.biomeRowInactive(feedback.forBiome(feedbackState, biomeKey), rowIndex)
end

return feedback
