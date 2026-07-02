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
    for _, exit in ipairs(common.topologyExits(entry)) do
        if isClockworkGoalExit(exit, progression) then
            count = count + 1
        end
    end
    return count
end

local function clockworkPrebossDoorCount(entry, progression)
    local count = 0
    for _, exit in ipairs(common.topologyExits(entry)) do
        if isClockworkPrebossExit(exit, progression) then
            count = count + 1
        end
    end
    return count
end

local function pickedClockworkGoal(entry, progression)
    return entry ~= nil and entry.roleKey == progression.goalRole
end

local function pickedClockworkPreboss(entry, progression)
    return entry ~= nil and entry.roleKey == progression.prebossRole
end

local function siblingClockworkFinding(entry, reason, payload)
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
    }, reason, payload)
end

local clockworkFindingForEntry

local function selectedClockworkFinding(entry, nextEntry, progression, reason, payload)
    if nextEntry ~= nil then
        local finding = clockworkFindingForEntry(nextEntry, progression, reason, payload)
        finding.renderRowIndex = entry and entry.rowIndex or nil
        finding.renderRouteOrdinal = entry and entry.routeOrdinal or nil
        finding.renderTabKey = "rooms"
        return finding
    end

    local topology = entry and entry.topology or nil
    local selected = topology and topology.selected or nil
    return findings.roomCandidateInvalid(entry, {
        roleKey = selected and selected.structure or nil,
        optionKey = selected and selected.roomKey or nil,
        roomKey = selected and selected.roomKey or nil,
    }, reason, payload)
end

local function generatedClockworkFinding(entry, nextEntry, progression, predicate, reason, payload)
    local topology = entry and entry.topology or nil
    if topology ~= nil
        and topology.sibling ~= nil
        and predicate(topology.sibling, progression)
    then
        return siblingClockworkFinding(entry, reason, payload)
    end
    return selectedClockworkFinding(entry, nextEntry, progression, reason, payload)
end

local function routeKindFinding(entry, value, reason, payload)
    return findings.roomCandidateInvalid(entry, {
        roleKey = entry and entry.roleKey or nil,
        optionKey = entry and entry.optionKey or nil,
        roomKey = entry and entry.roomKey or nil,
    }, reason, {
        clockworkControl = "routeKind",
        clockworkValue = value,
        clockworkBiomeLabel = payload.clockworkBiomeLabel,
        clockworkGoalLabel = payload.clockworkGoalLabel,
        clockworkPrebossLabel = payload.clockworkPrebossLabel,
        clockworkProgressionLabel = payload.clockworkProgressionLabel,
    })
end

local function nonGoalKindFinding(entry, value, reason, payload)
    return findings.roomCandidateInvalid(entry, {
        roleKey = entry and entry.roleKey or nil,
        optionKey = entry and entry.optionKey or nil,
        roomKey = entry and entry.roomKey or nil,
    }, reason, {
        clockworkControl = "nonGoalKind",
        clockworkValue = value,
        clockworkBiomeLabel = payload.clockworkBiomeLabel,
        clockworkGoalLabel = payload.clockworkGoalLabel,
        clockworkPrebossLabel = payload.clockworkPrebossLabel,
        clockworkProgressionLabel = payload.clockworkProgressionLabel,
    })
end

function clockworkFindingForEntry(entry, progression, reason, payload)
    if entry and entry.roleKey == progression.goalRole then
        return routeKindFinding(entry, "Goal", reason, payload)
    end
    if entry and entry.roleKey == progression.prebossRole then
        return routeKindFinding(entry, progression.prebossStructure or "Preboss", reason, payload)
    end
    if entry and entry.roleKey ~= nil and entry.roleKey ~= "" then
        return nonGoalKindFinding(entry, entry.roleKey, reason, payload)
    end
    return routeKindFinding(entry, entry and entry.roleKey or "", reason, payload)
end

local function clockworkPayload(biome, progression)
    return {
        clockworkBiomeLabel = biome and biome.label or nil,
        clockworkGoalLabel = progression.goalLabel,
        clockworkPrebossLabel = progression.prebossLabel,
        clockworkProgressionLabel = progression.progressionLabel,
    }
end

function clockwork.validate(history, biome)
    local progression = biome and biome.clockwork and biome.clockwork.progression or nil
    if progression == nil then
        return nil
    end

    local goalCount = 0
    local progressionFindings = {}
    local requiredGoals = tonumber(progression.requiredGoals) or 0
    local payload = clockworkPayload(biome, progression)
    local entries = common.biomeRoomEntries(history, biome.key)
    for index, entry in ipairs(entries) do
        if entry.roleKey ~= "Intro" then
            local nextEntry = entries[index + 1]
            if pickedClockworkPreboss(entry, progression) then
                if goalCount < requiredGoals then
                    return common.invalidWithFindings(
                        entry,
                        "clockwork_preboss_too_early",
                        nil,
                        {
                            clockworkFindingForEntry(
                                entry,
                                progression,
                                "clockwork_preboss_too_early",
                                payload
                            ),
                        },
                        payload
                    )
                end
                break
            end

            if pickedClockworkGoal(entry, progression) then
                goalCount = goalCount + 1
            end

            local beforeComplete = goalCount < requiredGoals
            local prebossDoorCount = clockworkPrebossDoorCount(entry, progression)
            if beforeComplete then
                if prebossDoorCount > 0 then
                    local finding = generatedClockworkFinding(
                        entry,
                        nextEntry,
                        progression,
                        isClockworkPrebossExit,
                        "clockwork_preboss_too_early",
                        payload
                    )
                    return common.invalidWithFindings(
                        entry,
                        "clockwork_preboss_too_early",
                        nil,
                        { finding },
                        payload
                    )
                end

                local goalDoorCount = clockworkGoalDoorCount(entry, progression)
                if progression.singleDoorMustBeGoalBeforeComplete == true
                    and common.generatedExitCount(entry) == 0
                then
                    return common.invalidWithFindings(
                        entry,
                        "clockwork_single_door_goal_required",
                        nil,
                        {
                            clockworkFindingForEntry(
                                entry,
                                progression,
                                "clockwork_single_door_goal_required",
                                payload
                            ),
                        },
                        payload
                    )
                end

                if progression.exactlyOneGoalDoorBeforeComplete == true
                    and common.generatedExitCount(entry) > 0
                    and goalDoorCount ~= 1
                then
                    return common.invalidWithFindings(
                        entry,
                        "clockwork_goal_door_count",
                        nil,
                        {
                            generatedClockworkFinding(
                                entry,
                                nextEntry,
                                progression,
                                function(exit, currentProgression)
                                    return not isClockworkGoalExit(exit, currentProgression)
                                end,
                                "clockwork_goal_door_count",
                                payload
                            ),
                        },
                        payload
                    )
                end
            elseif progression.prebossRequiredAfterComplete == true
                and prebossDoorCount ~= 1
            then
                return common.invalidWithFindings(
                    entry,
                    "clockwork_preboss_required",
                    nil,
                    {
                        common.generatedExitCount(entry) > 0
                            and generatedClockworkFinding(
                                entry,
                                nextEntry,
                                progression,
                                isClockworkPrebossExit,
                                "clockwork_preboss_required",
                                payload
                            )
                            or clockworkFindingForEntry(
                                entry,
                                progression,
                                "clockwork_preboss_required",
                                payload
                            ),
                    },
                    payload
                )
            end

        end
    end
    return nil, progressionFindings
end

return clockwork
