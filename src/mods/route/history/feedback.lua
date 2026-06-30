local deps = ... or {}

local feedbackAdapters = deps.adapters or {}
local routeFeedback = deps.routeFeedback
local routeHistory = deps.history

local feedback = {}

local EMPTY_LIST = {}

local function rangeContains(range, value)
    if range == nil then
        return true
    end
    if value == nil then
        return false
    end
    if range.exact ~= nil and value ~= range.exact then
        return false
    end
    if range.min ~= nil and value < range.min then
        return false
    end
    if range.max ~= nil and value > range.max then
        return false
    end
    if range.minExclusive ~= nil and value <= range.minExclusive then
        return false
    end
    if range.maxExclusive ~= nil and value >= range.maxExclusive then
        return false
    end
    return true
end

local function topologyForBiome(biome)
    return biome and (
        biome.roomTopology
            or biome.fields and biome.fields.roomTopology
    ) or nil
end

local function topologyWindow(topology)
    return topology and (topology.topologyWindow or topology.siblingStructureWindow) or nil
end

local function controlWindow(topology)
    return topology and (
        topology.siblingControlWindow
            or topology.siblingStructureWindow
            or topology.topologyWindow
    ) or nil
end

local function windowActive(window, entry)
    return rangeContains(window and window.biomeDepthCache or nil, entry and entry.biomeDepthCache)
end

local function rowFeedback(feedbackState, biomeKey, rowIndex)
    local biome = feedbackState.byBiome[biomeKey]
    if biome == nil then
        biome = {}
        feedbackState.byBiome[biomeKey] = biome
    end
    local row = biome[rowIndex]
    if row == nil then
        row = {
            valueStates = {},
            rewardValueStates = {},
        }
        biome[rowIndex] = row
    end
    return row
end

local function applyTopologyMetadata(args, feedbackState)
    local history = args and args.history or nil
    if history == nil or routeHistory == nil then
        return
    end

    for _, entry in ipairs(routeHistory.byKind(history, "room")) do
        local topology = topologyForBiome(args.biomeLookup and args.biomeLookup[entry.biomeKey] or nil)
        if topology ~= nil and entry.rowIndex ~= nil then
            rowFeedback(feedbackState, entry.biomeKey, entry.rowIndex).topology = {
                active = windowActive(topologyWindow(topology), entry),
                controlsActive = windowActive(controlWindow(topology), entry),
            }
        end
    end
end

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
        if record.layer ~= "npcs" then
            append(record)
        end
    end
    for _, record in ipairs(invalids or EMPTY_LIST) do
        if record.layer ~= "npcs" then
            append(record)
            for _, related in ipairs(record.relatedEvents or EMPTY_LIST) do
                append(routeFeedback.marker(args, related, {
                    markerKind = "related",
                    message = related.message or record.message,
                    code = related.code or record.code,
                }))
            end
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
    applyTopologyMetadata(args or {}, feedbackState)
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

function feedback.valueStatesForBiomeRow(biomeFeedback, rowIndex, controlAlias, rewardAddress)
    local row = biomeFeedback and biomeFeedback[rowIndex] or nil
    if rewardAddress ~= nil and rewardAddress ~= "" then
        local addressStates = row
            and row.rewardValueStates
            and row.rewardValueStates[rewardAddress]
            or nil
        if addressStates ~= nil and addressStates[controlAlias] ~= nil then
            return addressStates[controlAlias]
        end
    end
    return row and row.valueStates and row.valueStates[controlAlias] or nil
end

function feedback.topologyForBiomeRow(biomeFeedback, rowIndex)
    local row = biomeFeedback and biomeFeedback[rowIndex] or nil
    return row and row.topology or nil
end

function feedback.topologyForRow(feedbackState, biomeKey, rowIndex)
    return feedback.topologyForBiomeRow(feedback.forBiome(feedbackState, biomeKey), rowIndex)
end

function feedback.biomeRowInactive(biomeFeedback, rowIndex)
    return biomeFeedback ~= nil
        and biomeFeedback.inactiveAfterRowIndex ~= nil
        and rowIndex ~= nil
        and rowIndex > biomeFeedback.inactiveAfterRowIndex
end

function feedback.valueStatesForControl(feedbackState, biomeKey, rowIndex, controlAlias, rewardAddress)
    return feedback.valueStatesForBiomeRow(
        feedback.forBiome(feedbackState, biomeKey),
        rowIndex,
        controlAlias,
        rewardAddress
    )
end

function feedback.rowInactive(feedbackState, biomeKey, rowIndex)
    return feedback.biomeRowInactive(feedback.forBiome(feedbackState, biomeKey), rowIndex)
end

return feedback
