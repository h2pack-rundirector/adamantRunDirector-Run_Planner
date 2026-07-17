local standard = {}

function standard.normalize(specification)
    local authored = specification.authored
    specification.onlyKeys(authored, { "parentRoomControlKey" }, specification.path)
    if specification.rule.picked ~= "exactlyOne" then
        specification.fail(
            specification.path,
            "Standard implementation requires exactlyOne selection semantics"
        )
    end
    local targets = specification.targets
    local maximum = specification.rule.maxTargets
    if #targets > maximum then
        specification.fail(
            specification.path .. ".targets",
            "target count exceeds the Standard batch bound"
        )
    end
    local pickedCount = 0
    for _, target in ipairs(targets) do
        if target.picked then
            pickedCount = pickedCount + 1
        end
    end
    if pickedCount > 1 then
        specification.fail(
            specification.path .. ".targets",
            "Standard batch admits at most one picked target"
        )
    end
    return {
        parentRoomControlKey = authored.parentRoomControlKey,
        continuationOverrideKey = specification.continuationOverrideKey,
        batchRuleKey = specification.rule.key,
        targets = targets,
    }
end

function standard.checkStructure(specification)
    local targetByExit = {}
    local pickedCount = 0
    local availableTargetCount = 0
    local availableExitCount = #specification.parent.room.exits
    for _, target in ipairs(specification.batch.targets) do
        targetByExit[target.exitIndex] = target
        if target.exitIndex > availableExitCount then
            specification.reportUnavailableTarget(target, availableExitCount)
        else
            availableTargetCount = availableTargetCount + 1
            if target.picked then
                pickedCount = pickedCount + 1
            end
        end
    end

    local requiredTargetCount = availableExitCount
    for exitIndex = 1, requiredTargetCount do
        if targetByExit[exitIndex] == nil then
            specification.reportMissingTarget(
                exitIndex,
                requiredTargetCount,
                availableTargetCount
            )
        end
    end
    if pickedCount == 0 then
        specification.reportMissingPickedTarget()
    end
end

return standard
