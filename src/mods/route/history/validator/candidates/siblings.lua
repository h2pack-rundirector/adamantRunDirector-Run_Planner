local deps = ... or {}

local common = deps.common
local findings = deps.findings

local siblings = {}

local EMPTY_LIST = common.EMPTY_LIST

function siblings.appendFindings(target, entry)
    for _, candidate in ipairs(entry.siblingCandidates or EMPTY_LIST) do
        common.appendAvailabilityFinding(
            target,
            findings.siblingCandidateInvalid,
            entry,
            candidate,
            candidate.availability
        )
    end
end

return siblings
