local deps = ... or {}

local common = deps.common
local findings = deps.findings

local fields = {}

local EMPTY_LIST = common.EMPTY_LIST

local function isCombatCageStructure(structure)
    return string.match(tostring(structure or ""), "^CombatCage%d+$") ~= nil
end

local function validateMatchingCombatCageRewardCount(entry)
    local topology = entry and entry.topology or nil
    local selected = topology and topology.selected or nil
    local sibling = topology and topology.sibling or nil
    if not isCombatCageStructure(selected and selected.structure)
        or not isCombatCageStructure(sibling and sibling.structure)
    then
        return nil
    end

    local selectedCount = math.floor(tonumber(selected.offerCount) or 0)
    local siblingCount = math.floor(tonumber(sibling.offerCount) or 0)
    if selectedCount == siblingCount then
        return nil
    end

    local message = "Sibling combat reward count must match selected combat reward count"
    return common.invalidWithFindings(
        entry,
        "fields_sibling_combat_cage_count_mismatch",
        message,
        {
            findings.siblingCandidateInvalid(entry, {
                siblingIndex = 1,
                structureKey = sibling.key or sibling.structure,
                structure = sibling.structure,
            }, "fields_sibling_combat_cage_count_mismatch", {
                message = message,
            }),
        }
    )
end

function fields.appendCandidateFindings(target, _history, entry)
    local topology = entry and entry.topology or nil
    local selected = topology and topology.selected or nil
    if not isCombatCageStructure(selected and selected.structure) then
        return
    end

    for _, candidate in ipairs(entry.siblingCandidates or EMPTY_LIST) do
        if isCombatCageStructure(candidate and candidate.structure)
            and math.floor(tonumber(selected.offerCount) or 0)
                ~= math.floor(tonumber(candidate.offerCount) or 0)
        then
            target[#target + 1] = findings.siblingCandidateInvalid(
                entry,
                candidate,
                "fields_sibling_combat_cage_count_mismatch",
                {
                    message = "Sibling combat reward count must match selected combat reward count",
                }
            )
        end
    end
end

function fields.validate(history, biome)
    local topology = common.routeStructureForBiome(biome)
    if topology == nil then
        return nil
    end

    for _, entry in ipairs(common.biomeRoomEntries(history, biome.key)) do
        for _, rule in ipairs(topology.rules or EMPTY_LIST) do
            if rule.key == "matchingCombatCageRewardCount" then
                local invalid, invalidFindings = validateMatchingCombatCageRewardCount(entry)
                if invalid ~= nil then
                    return invalid, invalidFindings
                end
            end
        end
    end
    return nil
end

return fields
