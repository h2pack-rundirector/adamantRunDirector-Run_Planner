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
    local maximum = math.min(
        specification.rule.maxTargets,
        #specification.parent.room.exits
    )
    if #targets > maximum then
        specification.fail(
            specification.path .. ".targets",
            "target count exceeds the parent exit or Standard batch bound"
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

return standard
