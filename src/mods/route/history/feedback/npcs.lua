local deps = ... or {}

local valueStates = deps.valueStates

local npcFeedback = {}

local EMPTY_LIST = {}

local function ensureRow(feedback, rowIndex)
    local row = feedback.byRow[rowIndex]
    if row == nil then
        row = {
            valueStates = {},
        }
        feedback.byRow[rowIndex] = row
    end
    return row
end

local function setValueState(feedback, record)
    if record == nil or record.rowIndex == nil then
        return
    end
    local alias = record.controlAlias or "RowIndex"
    local value = record.controlValue
        or alias == "BiomeKey" and record.biomeKey
        or alias == "VariantKey" and record.variantKey
        or record.targetRowIndex
    if value == nil or value == "" then
        return
    end
    local row = ensureRow(feedback, record.rowIndex)
    local states = row.valueStates[alias]
    if states == nil then
        states = {}
        row.valueStates[alias] = states
    end
    valueStates.set(states, tostring(value), valueStates.INVALID)
end

function npcFeedback.fromResult(args)
    local feedback = {
        byRow = {},
    }
    for _, record in ipairs(args and args.findings or EMPTY_LIST) do
        if record.layer == "npcs" or record.kind == "npcSelectionInvalid" then
            setValueState(feedback, record)
        end
    end
    for _, record in ipairs(args and args.invalids or EMPTY_LIST) do
        if record.layer == "npcs" or record.kind == "npcSelectionInvalid" then
            setValueState(feedback, record)
            for _, related in ipairs(record.relatedEvents or EMPTY_LIST) do
                setValueState(feedback, related)
            end
        end
    end
    return feedback
end

return npcFeedback
