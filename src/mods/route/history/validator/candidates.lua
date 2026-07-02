local deps = ... or {}

local routeHistory = deps.history
local rewardValidator = deps.rewards
local selectedLegalityRules = deps.selectedLegalityRules
local formAddress = import("mods/route/history/form_address.lua")

local common = import("mods/route/history/validator/candidates/common.lua")
local candidateValidators = {
    import("mods/route/history/validator/candidates/rooms.lua", nil, {
        common = common,
        findings = deps.findings,
        history = routeHistory,
    }),
    import("mods/route/history/validator/candidates/siblings.lua", nil, {
        common = common,
        findings = deps.findings,
        history = routeHistory,
    }),
    import("mods/route/history/validator/candidates/variants.lua", nil, {
        common = common,
        findings = deps.findings,
    }),
    import("mods/route/history/validator/candidates/rewards.lua", nil, {
        findings = deps.findings,
        rewards = rewardValidator,
    }),
}

local candidates = {}

local function entriesByFormAddress(history)
    local byAddress = {}
    for _, entry in ipairs(routeHistory.byKind(history, "room")) do
        local key = formAddress.key(entry.formAddress)
        if key ~= nil then
            local biomeKey = entry.biomeKey or ""
            local biomeEntries = byAddress[biomeKey]
            if biomeEntries == nil then
                biomeEntries = {}
                byAddress[biomeKey] = biomeEntries
            end
            biomeEntries[key] = biomeEntries[key] or entry
        end
    end
    return byAddress
end

local function entryForFinding(byAddress, finding)
    local key = formAddress.key(finding and finding.formAddress or nil)
    if key == nil then
        return nil
    end
    local biomeEntries = byAddress[finding and finding.biomeKey or ""]
    return biomeEntries and biomeEntries[key] or nil
end

local function selectedSiblingStructure(entry, finding)
    local siblingIndex = math.floor(tonumber(finding and finding.siblingIndex) or 1)
    local siblings = entry
        and entry.source
        and entry.source.topology
        and entry.source.topology.siblings
        or common.EMPTY_LIST
    local sibling = siblings[siblingIndex]
    return sibling and sibling.structureKey or nil
end

local function selectedLoot(history, finding)
    local findingAddressKey = formAddress.key(finding and finding.formAddress or nil)
    for _, loot in ipairs(routeHistory.byKind(history, "loot")) do
        if loot.biomeKey == finding.biomeKey
            and loot.address == finding.address
            and loot.lootType == finding.rewardType
            and (
                loot.parentEntry == finding.entry
                or (
                    findingAddressKey ~= nil
                    and formAddress.key(loot.formAddress) == findingAddressKey
                )
            )
        then
            return loot
        end
    end
    return nil
end

local function roomFindingIsSelected(entry, finding)
    if entry == nil then
        return false
    end
    local controlAlias = finding.controlAlias
    local value = finding.controlValue
        or finding.optionKey ~= nil and finding.optionKey ~= "" and finding.optionKey
        or finding.roleKey
    if controlAlias == "RoleKey" then
        return entry.roleKey == value
    elseif controlAlias == "OptionKey" or controlAlias == nil then
        return entry.optionKey == value or entry.roleKey == value
    end
    return false
end

local function selectedEntryForFinding(history, byAddress, finding)
    if finding.kind == "roomCandidateInvalid" then
        local entry = entryForFinding(byAddress, finding) or finding.entry
        if roomFindingIsSelected(entry, finding) then
            return entry
        end
    elseif finding.kind == "siblingCandidateInvalid" then
        local entry = finding.entry or entryForFinding(byAddress, finding)
        if selectedSiblingStructure(entry, finding) == finding.structureKey then
            return entry
        end
    elseif finding.kind == "variantCandidateInvalid" then
        local entry = finding.entry or entryForFinding(byAddress, finding)
        if entry ~= nil and entry.variantKey == finding.variantKey then
            return entry
        end
    elseif finding.kind == "rewardCandidateInvalid" then
        return selectedLoot(history, finding)
    end
    return nil
end

local function invalidFromFinding(history, byAddress, finding)
    local entry = selectedEntryForFinding(history, byAddress, finding)
    if entry == nil then
        return nil
    end
    return {
        code = finding.reason,
        routeKey = finding.routeKey,
        biomeKey = finding.biomeKey,
        routeBiomeIndex = finding.routeBiomeIndex,
        rowIndex = finding.rowIndex,
        formAddress = finding.formAddress,
        routeOrdinal = finding.routeOrdinal,
        roomHistoryOrdinal = finding.roomHistoryOrdinal,
        roomKey = entry.roomKey or finding.roomKey,
        entry = entry,
        targetFinding = finding,
        tabKey = finding.kind == "rewardCandidateInvalid" and "rewards" or "rooms",
        address = finding.address,
        controlAlias = finding.controlAlias,
        rewardType = finding.rewardType,
        relatedEvents = finding.relatedEvents,
    }
end

local function appendSelectedInvalids(target, history, findings)
    local byAddress = entriesByFormAddress(history)
    for _, finding in ipairs(findings or common.EMPTY_LIST) do
        local invalid = invalidFromFinding(history, byAddress, finding)
        if invalid ~= nil then
            target[#target + 1] = invalid
        end
    end
end

local function positionValue(record)
    local routeBiomeIndex = math.floor(tonumber(record and record.routeBiomeIndex) or 0)
    local routeOrdinal = math.floor(tonumber(record and record.routeOrdinal) or record and record.rowIndex or 0)
    local rowIndex = math.floor(tonumber(record and record.rowIndex) or 0)
    return routeBiomeIndex * 1000000 + routeOrdinal * 1000 + rowIndex
end

local function firstByPosition(invalids)
    local first = nil
    for _, invalid in ipairs(invalids or common.EMPTY_LIST) do
        if first == nil or positionValue(invalid) < positionValue(first) then
            first = invalid
        end
    end
    return first
end

local function appendRuleFindings(target, history, entry, ruleValidators)
    for _, ruleValidator in ipairs(ruleValidators or common.EMPTY_LIST) do
        if ruleValidator.appendCandidateFindings ~= nil then
            ruleValidator.appendCandidateFindings(target, history, entry)
        end
    end
end

function candidates.validate(args)
    local history = args and args.history or nil
    local rulesByTarget = rewardValidator.rulesByTarget(selectedLegalityRules)
    local candidateFindings = {}
    for _, entry in ipairs(routeHistory.byKind(history, "room")) do
        candidateValidators[1].appendFindings(candidateFindings, history, entry)
        candidateValidators[2].appendFindings(
            candidateFindings,
            history,
            entry,
            args.biomeLookup and args.biomeLookup[entry.biomeKey] or nil
        )
        candidateValidators[3].appendFindings(candidateFindings, entry)
        candidateValidators[4].appendFindings(candidateFindings, history, entry, rulesByTarget)
        appendRuleFindings(candidateFindings, history, entry, deps.ruleValidators)
    end
    local invalids = {}
    appendSelectedInvalids(invalids, history, candidateFindings)
    local firstInvalid = firstByPosition(invalids)
    if firstInvalid ~= nil then
        return {
            valid = false,
            invalids = { firstInvalid },
            findings = candidateFindings,
        }
    end
    return common.validResult(candidateFindings)
end

return candidates
