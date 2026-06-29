local deps = ... or {}

local valueStates = deps.valueStates

local feedback = {}

local EMPTY_LIST = {}

local function rewardAliasForCageAddress(address)
    local index = type(address) == "string" and string.match(address, "^cage:(%d+)$") or nil
    if index == nil then
        return nil
    end
    return "Reward" .. tostring(math.floor(tonumber(index) or 1)) .. "Key"
end

local function rewardControlAliasForFinding(finding)
    local cageAlias = rewardAliasForCageAddress(finding.address)
    if cageAlias ~= nil then
        return cageAlias
    elseif finding.rewardClass == "Major" then
        return "Reward2Key"
    elseif finding.rewardClass == "Minor" then
        return "Reward4Key"
    end
    return "Reward1Key"
end

local function controlAliasForFinding(finding)
    if finding.kind == "siblingCandidateInvalid" then
        local siblingIndex = math.floor(tonumber(finding.siblingIndex) or 1)
        if siblingIndex <= 1 then
            return "SiblingStructureKey"
        end
        return "SiblingStructure" .. tostring(siblingIndex) .. "Key"
    elseif finding.kind == "roomCandidateInvalid" then
        if finding.optionKey ~= nil and finding.optionKey ~= "" then
            return "OptionKey"
        end
        return "RoleKey"
    elseif finding.kind == "rewardCandidateInvalid" then
        return rewardControlAliasForFinding(finding)
    end
    return nil
end

local function valueForFinding(finding)
    if finding.kind == "siblingCandidateInvalid" then
        return finding.structureKey
    elseif finding.kind == "roomCandidateInvalid" then
        return finding.optionKey ~= nil and finding.optionKey ~= ""
            and finding.optionKey
            or finding.roleKey
    elseif finding.kind == "rewardCandidateInvalid" then
        return finding.rewardType
    end
    return nil
end

local function stateForFinding(finding)
    return valueStates.forFailureCode(finding.reason)
end

local function ensureBiome(feedbackState, biomeKey)
    local byBiome = feedbackState.byBiome
    local biome = byBiome[biomeKey]
    if biome == nil then
        biome = {}
        byBiome[biomeKey] = biome
    end
    return biome
end

local function ensureRow(feedbackState, finding)
    local biome = ensureBiome(feedbackState, finding.biomeKey or "")
    local row = biome[finding.rowIndex or 0]
    if row == nil then
        row = {
            valueStates = {},
        }
        biome[finding.rowIndex or 0] = row
    end
    return row
end

local function setValueState(row, controlAlias, value, state)
    if controlAlias == nil or value == nil or value == "" then
        return
    end
    local control = row.valueStates[controlAlias]
    if control == nil then
        control = {}
        row.valueStates[controlAlias] = control
    end
    valueStates.set(control, value, state)
end

function feedback.fromFindings(findings)
    local feedbackState = {
        byBiome = {},
    }
    for _, finding in ipairs(findings or EMPTY_LIST) do
        local row = ensureRow(feedbackState, finding)
        setValueState(
            row,
            controlAliasForFinding(finding),
            valueForFinding(finding),
            stateForFinding(finding)
        )
    end
    return feedbackState
end

function feedback.valueStatesForControl(feedbackState, biomeKey, rowIndex, controlAlias)
    local row = feedbackState
        and feedbackState.byBiome
        and feedbackState.byBiome[biomeKey]
        and feedbackState.byBiome[biomeKey][rowIndex]
        or nil
    return row and row.valueStates and row.valueStates[controlAlias] or nil
end

return feedback
