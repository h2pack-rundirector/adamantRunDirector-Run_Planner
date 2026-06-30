local deps = ... or {}

local valueStates = deps.valueStates

local common = {}

local EMPTY_LIST = {}

local function rewardAliasForAddress(address)
    local cageIndex = type(address) == "string" and string.match(address, "^cage:(%d+)$") or nil
    if cageIndex ~= nil then
        return "Reward" .. tostring(math.floor(tonumber(cageIndex) or 1)) .. "Key"
    end
    return nil
end

local function rewardControlAlias(record)
    if record ~= nil and record.controlAlias ~= nil then
        return record.controlAlias
    end
    local addressAlias = rewardAliasForAddress(record and record.address or nil)
    if addressAlias ~= nil then
        return addressAlias
    elseif record and record.rewardClass == "Major" then
        return "Reward2Key"
    elseif record and record.rewardClass == "Minor" then
        return "Reward4Key"
    end
    return "Reward1Key"
end

local function siblingControlAlias(record)
    local siblingIndex = math.floor(tonumber(record and record.siblingIndex) or 1)
    if siblingIndex <= 1 then
        return "SiblingStructureKey"
    end
    return "SiblingStructure" .. tostring(siblingIndex) .. "Key"
end

local function roomControlAlias(record)
    if record ~= nil and record.controlAlias ~= nil then
        return record.controlAlias
    end
    if record ~= nil and record.optionKey ~= nil and record.optionKey ~= "" then
        return "OptionKey"
    end
    return "RoleKey"
end

local function selectedRoomTarget(record)
    local entry = record and record.entry or nil
    if entry == nil then
        return nil
    end
    if entry.optionKey ~= nil and entry.optionKey ~= "" then
        return {
            tabKey = "rooms",
            controlAlias = "OptionKey",
            value = entry.optionKey,
        }
    end
    return {
        tabKey = "rooms",
        controlAlias = "RoleKey",
        value = entry.roleKey,
    }
end

function common.stateFor(record)
    return valueStates.forFailureCode(record and (record.reason or record.code) or nil)
end

function common.setValueState(feedbackState, record, target, state)
    if target == nil
        or target.controlAlias == nil
        or target.value == nil
        or target.value == ""
    then
        return
    end

    local biomeKey = record and record.biomeKey or ""
    local rowIndex = record and record.rowIndex or 0
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

    local controls = row.valueStates
    if target.tabKey == "rewards" and target.address ~= nil and target.address ~= "" then
        local addressStates = row.rewardValueStates[target.address]
        if addressStates == nil then
            addressStates = {}
            row.rewardValueStates[target.address] = addressStates
        end
        controls = addressStates
    end

    local control = controls[target.controlAlias]
    if control == nil then
        control = {}
        controls[target.controlAlias] = control
    end
    valueStates.set(control, target.value, target.state or state)
end

function common.setInactiveBoundary(feedbackState, record)
    local biomeKey = record and record.biomeKey or ""
    local rowIndex = record and record.rowIndex or nil
    if rowIndex == nil then
        return
    end
    local biome = feedbackState.byBiome[biomeKey]
    if biome == nil then
        biome = {}
        feedbackState.byBiome[biomeKey] = biome
    end
    if biome.inactiveAfterRowIndex == nil or rowIndex < biome.inactiveAfterRowIndex then
        biome.inactiveAfterRowIndex = rowIndex
    end
end

function common.targetFor(record)
    if record == nil then
        return nil
    end
    if record.kind == "siblingCandidateInvalid" then
        return {
            tabKey = "rooms",
            controlAlias = siblingControlAlias(record),
            value = record.structureKey,
        }
    elseif record.kind == "roomCandidateInvalid" then
        return {
            tabKey = "rooms",
            controlAlias = roomControlAlias(record),
            value = record.controlValue
                or record.optionKey ~= nil and record.optionKey ~= "" and record.optionKey
                or record.roleKey,
        }
    elseif record.kind == "rewardCandidateInvalid" or record.rewardType ~= nil then
        return {
            tabKey = "rewards",
            address = record.address or "row",
            controlAlias = rewardControlAlias(record),
            value = record.rewardType,
        }
    end
    return selectedRoomTarget(record)
end

function common.translateRecord(feedbackState, record, opts)
    if record.kind == "rowInactiveBoundary" then
        common.setInactiveBoundary(feedbackState, record)
        return
    end
    local targetRecord = record.targetFinding or record
    local target = opts and opts.targetFor and opts.targetFor(targetRecord, record)
        or common.targetFor(targetRecord)
    common.setValueState(feedbackState, record, target, common.stateFor(record))
end

function common.translateAll(feedbackState, records, opts)
    for _, record in ipairs(records or EMPTY_LIST) do
        common.translateRecord(feedbackState, record, opts)
    end
end

function common.createAdapter(opts)
    opts = opts or {}
    return {
        translate = function(feedbackState, records)
            common.translateAll(feedbackState, records, opts)
        end,
    }
end

return common
