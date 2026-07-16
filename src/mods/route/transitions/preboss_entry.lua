local prebossEntry = {}

function prebossEntry.normalize(specification)
    local policy = specification.declaration.exitPolicy
    local companionTargets = specification.companionTargets
    local expectedCompanions = 0
    if policy.kind == "terminalWithCompanions" then
        expectedCompanions = #specification.parent.room.exits - 1
    end
    if #companionTargets > expectedCompanions then
        specification.fail(
            specification.path .. ".companionTargets",
            "expected at most " .. tostring(expectedCompanions) .. " terminal companion targets"
        )
    end
    if policy.kind == "terminalWithCompanions" then
        for index, target in ipairs(companionTargets) do
            if target.exitIndex < 2 or target.exitIndex > #specification.parent.room.exits then
                specification.fail(
                    specification.path .. ".companionTargets[" .. tostring(index) .. "].exitIndex",
                    "terminal companions must use physical exits 2..N"
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

function prebossEntry.checkStructure(specification)
    if specification.transition.exitPolicyKind ~= "terminalWithCompanions" then
        return
    end
    local companionByExit = {}
    for _, target in ipairs(specification.transition.companionTargets) do
        companionByExit[target.exitIndex] = target
    end
    for exitIndex = 2, #specification.parent.room.exits do
        if companionByExit[exitIndex] == nil then
            specification.reportMissingCompanion(exitIndex)
        end
    end
end

return prebossEntry
