local deps = ... or {}

local common = deps.common
local findings = deps.findings

local variants = {}

local EMPTY_LIST = common.EMPTY_LIST

function variants.appendFindings(target, entry)
    for _, candidate in ipairs(entry.variantCandidates or EMPTY_LIST) do
        if not common.rangeContains(candidate.availableAtBiomeEncounterDepth, entry and entry.biomeEncounterDepth) then
            target[#target + 1] = findings.variantCandidateInvalid(
                entry,
                candidate,
                "encounter_depth_unavailable",
                {
                    controlAlias = candidate.controlAlias or "VariantKey",
                    expected = candidate.availableAtBiomeEncounterDepth,
                    actual = entry and entry.biomeEncounterDepth or nil,
                }
            )
        end
    end
end

return variants
