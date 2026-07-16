local prebossEntry = {}

function prebossEntry.normalize(specification)
    local policy = specification.declaration.exitPolicy
    local companionTargets = specification.companionTargets
    local expectedCompanions = 0
    if policy.kind == "terminalWithCompanions" then
        expectedCompanions = #specification.parent.room.exits - 1
    end
    if #companionTargets ~= expectedCompanions then
        specification.fail(
            specification.path .. ".companionTargets",
            "expected exactly " .. tostring(expectedCompanions) .. " terminal companion targets"
        )
    end
    if policy.kind == "terminalWithCompanions" then
        for index, target in ipairs(companionTargets) do
            if target.exitIndex ~= index + 1 then
                specification.fail(
                    specification.path .. ".companionTargets[" .. tostring(index) .. "].exitIndex",
                    "terminal companions must cover physical exits 2..N in order"
                )
            end
        end
    end
    return {
        parentRoomControlKey = specification.parent.control.key,
        transitionRuleKey = specification.declaration.transitionRuleKey,
        exitPolicyKind = policy.kind,
        companionBatchRuleKey = policy.companionBatchRuleKey,
        terminalRoomControlKey = specification.terminal.control.key,
        companionTargets = companionTargets,
    }
end

return prebossEntry
