local deps = ... or {}

local common = deps.common
local findings = deps.findings

local clockwork = {}

local function isClockworkGoalExit(exit, progression)
    return exit ~= nil
        and (
            exit.isClockworkGoal == true
                or exit.roleKey == progression.goalRole
                or exit.structure == progression.goalRole
        )
end

local function isClockworkPrebossExit(exit, progression)
    return exit ~= nil
        and (
            exit.isPreboss == true
                or exit.structure == progression.prebossStructure
        )
end

local function clockworkGoalDoorCount(entry, progression)
    local count = 0
    for _, exit in ipairs(common.selectedAndGeneratedExits(entry)) do
        if isClockworkGoalExit(exit, progression) then
            count = count + 1
        end
    end
    return count
end

local function clockworkPrebossDoorCount(entry, progression)
    local count = 0
    for _, exit in ipairs(common.selectedAndGeneratedExits(entry)) do
        if isClockworkPrebossExit(exit, progression) then
            count = count + 1
        end
    end
    return count
end

local function pickedClockworkGoal(entry, progression)
    return isClockworkGoalExit(common.selectedExit(entry), progression)
end

local function pickedClockworkPreboss(entry, progression)
    return isClockworkPrebossExit(common.selectedExit(entry), progression)
end

local function siblingClockworkFinding(entry, reason, message)
    local topology = entry and entry.topology or nil
    local sibling = topology and topology.sibling or nil
    return findings.siblingCandidateInvalid(entry, {
        siblingIndex = 1,
        structureKey = sibling and (
            sibling.key
                or sibling.roomKey
                or sibling.structure
        ) or "",
        roomKey = sibling and sibling.roomKey or nil,
    }, reason, {
        message = message,
    })
end

local function routeKindFinding(entry, value, reason, message)
    return findings.roomCandidateInvalid(entry, {
        roleKey = entry and entry.roleKey or nil,
        optionKey = entry and entry.optionKey or nil,
        roomKey = entry and entry.roomKey or nil,
    }, reason, {
        clockworkControl = "routeKind",
        clockworkValue = value,
        message = message,
    })
end

local function nonGoalKindFinding(entry, value, reason, message)
    return findings.roomCandidateInvalid(entry, {
        roleKey = entry and entry.roleKey or nil,
        optionKey = entry and entry.optionKey or nil,
        roomKey = entry and entry.roomKey or nil,
    }, reason, {
        clockworkControl = "nonGoalKind",
        clockworkValue = value,
        message = message,
    })
end

local function clockworkFindingForEntry(entry, progression, reason, message)
    if entry and entry.roleKey == progression.goalRole then
        return routeKindFinding(entry, "Goal", reason, message)
    end
    if entry and entry.roleKey == progression.prebossRole then
        return routeKindFinding(entry, progression.prebossStructure or "Preboss", reason, message)
    end
    if entry and entry.roleKey ~= nil and entry.roleKey ~= "" then
        return nonGoalKindFinding(entry, entry.roleKey, reason, message)
    end
    return routeKindFinding(entry, entry and entry.roleKey or "", reason, message)
end

function clockwork.validate(history, biome)
    local progression = biome and biome.clockwork and biome.clockwork.progression or nil
    if progression == nil then
        return nil
    end

    local goalCount = 0
    local progressionFindings = {}
    local requiredGoals = tonumber(progression.requiredGoals) or 0
    for _, entry in ipairs(common.biomeRoomEntries(history, biome.key)) do
        if entry.roleKey ~= "Intro" then
            local beforeComplete = goalCount < requiredGoals
            local prebossDoorCount = clockworkPrebossDoorCount(entry, progression)
            if beforeComplete then
                if prebossDoorCount > 0 then
                    local message = "Tartarus Preboss cannot appear before Clockwork goals are complete"
                    local finding = pickedClockworkPreboss(entry, progression)
                        and clockworkFindingForEntry(
                            entry,
                            progression,
                            "clockwork_preboss_too_early",
                            message
                        )
                        or siblingClockworkFinding(entry, "clockwork_preboss_too_early", message)
                    return common.invalidWithFindings(
                        entry,
                        "clockwork_preboss_too_early",
                        message,
                        { finding }
                    )
                end

                local goalDoorCount = clockworkGoalDoorCount(entry, progression)
                if progression.singleDoorMustBeGoalBeforeComplete == true
                    and common.generatedExitCount(entry) == 0
                    and goalDoorCount ~= 1
                then
                    local message = "Tartarus single doors need Goal Room before Clockwork goals are complete"
                    return common.invalidWithFindings(
                        entry,
                        "clockwork_single_door_goal_required",
                        message,
                        {
                            clockworkFindingForEntry(
                                entry,
                                progression,
                                "clockwork_single_door_goal_required",
                                message
                            ),
                        }
                    )
                end

                if progression.exactlyOneGoalDoorBeforeComplete == true
                    and common.generatedExitCount(entry) > 0
                    and goalDoorCount ~= 1
                then
                    local message = "Tartarus generated doors need exactly one Goal Room before Clockwork goals are complete"
                    return common.invalidWithFindings(
                        entry,
                        "clockwork_goal_door_count",
                        message,
                        {
                            siblingClockworkFinding(
                                entry,
                                "clockwork_goal_door_count",
                                message
                            ),
                        }
                    )
                end
            elseif progression.prebossRequiredAfterComplete == true
                and prebossDoorCount ~= 1
            then
                local message = "Tartarus post-goal doors need Preboss"
                return common.invalidWithFindings(
                    entry,
                    "clockwork_preboss_required",
                    message,
                    {
                        common.generatedExitCount(entry) > 0
                            and siblingClockworkFinding(
                                entry,
                                "clockwork_preboss_required",
                                message
                            )
                            or clockworkFindingForEntry(
                                entry,
                                progression,
                                "clockwork_preboss_required",
                                message
                            ),
                    }
                )
            end

            if pickedClockworkGoal(entry, progression) then
                goalCount = goalCount + 1
                if goalCount >= requiredGoals and common.generatedExitCount(entry) == 0 then
                    progressionFindings[#progressionFindings + 1] = findings.rowInactiveBoundary(
                        entry,
                        "clockwork_route_complete",
                        {
                            message = "Tartarus route is complete after Clockwork goals",
                        }
                    )
                    break
                end
            end
            if pickedClockworkPreboss(entry, progression) then
                progressionFindings[#progressionFindings + 1] = findings.rowInactiveBoundary(
                    entry,
                    "clockwork_route_complete",
                    {
                        message = "Tartarus route is complete after Preboss",
                    }
                )
                break
            end
        end
    end
    return nil, progressionFindings
end

return clockwork
