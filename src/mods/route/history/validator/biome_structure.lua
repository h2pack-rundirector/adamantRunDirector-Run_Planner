local deps = ... or {}

local routeHistory = deps.history
local routeQuery = deps.query
local findings = deps.findings

local biomeStructure = {}

local EMPTY_LIST = {}
local biomeRoomEntries

local function validResult(resultFindings)
    return {
        valid = true,
        invalids = {},
        findings = resultFindings,
    }
end

local function invalidAt(entry, code, message, fields)
    local invalid = {
        code = code,
        message = message,
        routeKey = entry and entry.routeKey or nil,
        biomeKey = entry and entry.biomeKey or nil,
        routeBiomeIndex = entry and entry.routeBiomeIndex or nil,
        rowIndex = entry and entry.rowIndex or nil,
        routeOrdinal = entry and entry.routeOrdinal or nil,
        roomHistoryOrdinal = entry and entry.roomHistoryOrdinal or nil,
        roomKey = entry and (entry.roomKey or entry.eventKey) or nil,
        entry = entry,
    }
    for key, value in pairs(fields or {}) do
        invalid[key] = value
    end
    return invalid
end

local function invalidWithFindings(entry, code, message, findingList, fields)
    if findingList ~= nil
        and findingList[1] ~= nil
        and (fields == nil or fields.targetFinding == nil)
    then
        fields = fields or {}
        fields.targetFinding = findingList[1]
    end
    local invalid = invalidAt(entry, code, message, fields)
    return invalid, findingList
end

local function appendFindings(target, source)
    for _, finding in ipairs(source or EMPTY_LIST) do
        target[#target + 1] = finding
    end
end

local function rangeContains(range, value)
    if range == nil or value == nil then
        return true
    end
    if range.exact ~= nil and value ~= range.exact then
        return false
    end
    if range.min ~= nil and value < range.min then
        return false
    end
    if range.max ~= nil and value > range.max then
        return false
    end
    if range.minExclusive ~= nil and value <= range.minExclusive then
        return false
    end
    if range.maxExclusive ~= nil and value >= range.maxExclusive then
        return false
    end
    return true
end

local function availabilityFailure(option, entry)
    local availability = option and option.availability or nil
    if availability == nil then
        return nil
    end
    if not rangeContains(availability.biomeDepthCache, entry and entry.biomeDepthCache) then
        return "biome_depth_unavailable"
    end
    if not rangeContains(availability.biomeEncounterDepth, entry and entry.biomeEncounterDepth) then
        return "encounter_depth_unavailable"
    end
    return nil
end

local function variantFailure(entry)
    if entry == nil
        or entry.variantKey == nil
        or entry.variantKey == ""
        or entry.variantAvailability == nil
    then
        return nil
    end
    if rangeContains(entry.variantAvailability, entry.biomeEncounterDepth) then
        return nil
    end
    return "encounter_depth_unavailable"
end

local function variantFinding(entry, reason, message)
    return findings.variantCandidateInvalid(entry, {
        key = entry and entry.variantKey or nil,
        label = entry and entry.variantLabel or nil,
        availableAtBiomeEncounterDepth = entry and entry.variantAvailability or nil,
        controlAlias = "VariantKey",
    }, reason, {
        message = message,
        expected = entry and entry.variantAvailability or nil,
        actual = entry and entry.biomeEncounterDepth or nil,
    })
end

local function hasTag(tags, expected)
    for _, tag in ipairs(tags or EMPTY_LIST) do
        if tag == expected then
            return true
        end
    end
    return false
end

local function nextRoomTagsFailure(requiredTags, tags)
    if requiredTags == nil then
        return nil
    end
    for _, requiredTag in ipairs(requiredTags) do
        if hasTag(tags, requiredTag) then
            return nil
        end
    end
    return "previous_room_next_tags"
end

local function nextRoomTagsMessage(requiredTags)
    local requiredTag = requiredTags and requiredTags[1] or "required"
    return "Previous planned room only leads to " .. tostring(requiredTag) .. " rooms"
end

local function optionList(role)
    return role and (role.roomOptions or role.mapOptions) or EMPTY_LIST
end

local function optionByKey(role, key)
    if role == nil or key == nil or key == "" then
        return nil
    end
    if role.optionsByKey ~= nil then
        return role.optionsByKey[key]
    end
    for _, option in ipairs(optionList(role)) do
        if option.key == key then
            return option
        end
    end
    return nil
end

local function optionByRoomKey(role, roomKey)
    if role == nil or roomKey == nil or roomKey == "" then
        return nil
    end
    for _, option in ipairs(optionList(role)) do
        if option.key == roomKey then
            return option
        end
    end
    return nil
end

local function declarationForEntry(biome, entry)
    local role = biome
        and biome.rolesByKey
        and biome.rolesByKey[entry and entry.roleKey or nil]
        or nil
    local option = optionByKey(role, entry and entry.optionKey)
        or optionByRoomKey(role, entry and entry.roomKey)
    return role, option
end

local function capFor(value)
    return value and (
        value.maxCreationsThisRun
            or value.maxAppearancesThisBiome
            or value.routeRules and value.routeRules.maxSelectionsPerBiome
    ) or nil
end

local function appendCount(counts, key)
    if key == nil or key == "" then
        return 0
    end
    local value = (counts[key] or 0) + 1
    counts[key] = value
    return value
end

local function routeStructureForBiome(biome)
    return biome and (
        biome.roomTopology
            or biome.fields and biome.fields.roomTopology
    ) or nil
end

local function topologyOptionsByRoomKey(topology)
    local lookup = {}
    local options = topology
        and topology.siblingStructureControl
        and topology.siblingStructureControl.options
        or EMPTY_LIST
    for _, option in ipairs(options) do
        local roomKey = option.roomKey or (option.structure == "Miniboss" and option.key or nil)
        if roomKey ~= nil and roomKey ~= "" then
            lookup[roomKey] = option
        end
    end
    return lookup
end

local function candidateInList(candidates, roomKey)
    for _, candidate in ipairs(candidates or EMPTY_LIST) do
        if candidate == roomKey then
            return true
        end
    end
    return false
end

local function forceWindowActive(force, depth)
    local range = force and force.biomeDepthCache or nil
    if range == nil or depth == nil then
        return false
    end
    if range.exact ~= nil then
        return depth == range.exact
    end
    if range.min ~= nil and depth < range.min then
        return false
    end
    return range.min ~= nil or range.max ~= nil
end

local function forceDeadlineActive(force, depth)
    local range = force and force.biomeDepthCache or nil
    if range == nil or depth == nil then
        return false
    end
    if range.exact ~= nil then
        return depth == range.exact
    end
    if range.min ~= nil and depth < range.min then
        return false
    end
    return range.max ~= nil and depth >= range.max
end

local function topologyExits(entry)
    local topology = entry and entry.topology or nil
    if topology == nil then
        return EMPTY_LIST
    end
    if topology.exits ~= nil then
        return topology.exits
    end
    local exits = {}
    if topology.selected ~= nil then
        exits[#exits + 1] = topology.selected
    end
    if topology.sibling ~= nil then
        exits[#exits + 1] = topology.sibling
    end
    return exits
end

local function selectedExit(entry)
    local topology = entry and entry.topology or nil
    if topology ~= nil and topology.selected ~= nil then
        return topology.selected
    end
    return {
        structure = entry and entry.roleKey or nil,
        roomKey = entry and entry.roomKey or nil,
    }
end

local function selectedAndGeneratedExits(entry)
    local topology = entry and entry.topology or nil
    if topology == nil then
        return { selectedExit(entry) }
    end
    return topologyExits(entry)
end

local function generatedRoomKey(exit)
    return exit and (exit.roomKey or exit.optionKey) or nil
end

local function generatedExitCount(entry)
    return #topologyExits(entry)
end

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
    for _, exit in ipairs(selectedAndGeneratedExits(entry)) do
        if isClockworkGoalExit(exit, progression) then
            count = count + 1
        end
    end
    return count
end

local function clockworkPrebossDoorCount(entry, progression)
    local count = 0
    for _, exit in ipairs(selectedAndGeneratedExits(entry)) do
        if isClockworkPrebossExit(exit, progression) then
            count = count + 1
        end
    end
    return count
end

local function pickedClockworkGoal(entry, progression)
    local selected = selectedExit(entry)
    return isClockworkGoalExit(selected, progression)
end

local function pickedClockworkPreboss(entry, progression)
    local selected = selectedExit(entry)
    return isClockworkPrebossExit(selected, progression)
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
    if entry and entry.roleKey ~= nil and entry.roleKey ~= "" then
        return nonGoalKindFinding(entry, entry.roleKey, reason, message)
    end
    return routeKindFinding(entry, entry and entry.roleKey or "", reason, message)
end

local function validateClockworkProgression(history, biome)
    local progression = biome and biome.clockwork and biome.clockwork.progression or nil
    if progression == nil then
        return nil
    end

    local goalCount = 0
    local progressionFindings = {}
    local requiredGoals = tonumber(progression.requiredGoals) or 0
    for _, entry in ipairs(biomeRoomEntries(history, biome.key)) do
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
                    return invalidWithFindings(
                        entry,
                        "clockwork_preboss_too_early",
                        message,
                        { finding }
                    )
                end

                local goalDoorCount = clockworkGoalDoorCount(entry, progression)
                if progression.singleDoorMustBeGoalBeforeComplete == true
                    and generatedExitCount(entry) == 0
                    and goalDoorCount ~= 1
                then
                    local message = "Tartarus single doors need Goal Room before Clockwork goals are complete"
                    return invalidWithFindings(
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
                    and generatedExitCount(entry) > 0
                    and goalDoorCount ~= 1
                then
                    local message = "Tartarus generated doors need exactly one Goal Room before Clockwork goals are complete"
                    return invalidWithFindings(
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
                return invalidWithFindings(
                    entry,
                    "clockwork_preboss_required",
                    message,
                    {
                        generatedExitCount(entry) > 0
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
                if goalCount >= requiredGoals and generatedExitCount(entry) == 0 then
                    progressionFindings[#progressionFindings + 1] = findings.rowInactiveBoundary(
                        entry,
                        "clockwork_route_complete",
                        {
                            message = "Tartarus route is complete after Clockwork goals",
                        }
                    )
                end
            end
        end
    end
    return nil, progressionFindings
end

local function generatedCandidateAt(entry, candidate)
    for _, exit in ipairs(topologyExits(entry)) do
        if generatedRoomKey(exit) == candidate then
            return true
        end
    end
    return false
end

local function generatedCandidatesThrough(entries, index, candidates)
    local generated = {}
    for currentIndex = 1, index do
        local entry = entries[currentIndex]
        for _, candidate in ipairs(candidates or EMPTY_LIST) do
            if generated[candidate] == nil and generatedCandidateAt(entry, candidate) then
                generated[candidate] = true
            end
        end
    end
    return generated
end

local function generatedCandidateCountThrough(entries, index, candidates)
    local generated = generatedCandidatesThrough(entries, index, candidates)
    local count = 0
    for _, candidate in ipairs(candidates or EMPTY_LIST) do
        if generated[candidate] then
            count = count + 1
        end
    end
    return count
end

local function pickedCandidateBefore(entries, index, candidates)
    for currentIndex = 1, index - 1 do
        if candidateInList(candidates, entries[currentIndex] and entries[currentIndex].roomKey) then
            return true
        end
    end
    return false
end

local function preparedForceCandidates(topology)
    local grouped = {}
    for _, group in ipairs(topology and topology.forcedGroups or EMPTY_LIST) do
        for _, candidate in ipairs(group.candidates or EMPTY_LIST) do
            grouped[candidate] = true
        end
    end

    local candidates = {}
    for roomKey, option in pairs(topologyOptionsByRoomKey(topology)) do
        if option.force ~= nil and not grouped[roomKey] then
            candidates[#candidates + 1] = roomKey
        end
    end
    return candidates
end

local function forceCandidateAvailable(option, entry)
    return option ~= nil and availabilityFailure(option, entry) == nil
end

local function generatedForceWindowCandidateCount(entries, index, optionsByRoomKey)
    local entry = entries[index]
    local count = 0
    for roomKey, option in pairs(optionsByRoomKey) do
        if forceCandidateAvailable(option, entry)
            and forceWindowActive(option.force, entry and entry.biomeDepthCache)
            and generatedCandidateAt(entry, roomKey)
        then
            count = count + 1
        end
    end
    return count
end

local function validateUngroupedForce(topology, entries, index, optionsByRoomKey)
    local entry = entries[index]
    local capacity = generatedExitCount(entry)
    if capacity <= 0 then
        return nil
    end

    local hasMissingHardForce = false
    for _, candidate in ipairs(preparedForceCandidates(topology)) do
        local option = optionsByRoomKey[candidate]
        if forceCandidateAvailable(option, entry)
            and forceDeadlineActive(option.force, entry and entry.biomeDepthCache)
            and not generatedCandidateAt(entry, candidate)
        then
            hasMissingHardForce = true
            break
        end
    end
    if not hasMissingHardForce then
        return nil
    end
    if generatedForceWindowCandidateCount(entries, index, optionsByRoomKey) >= capacity then
        return nil
    end
    return invalidAt(
        entry,
        "forced_topology_pressure_unresolved",
        "Hard-forced topology needs generated force-window doors"
    )
end

local function requiredGeneratedCount(group, entry)
    if group.requiredGeneratedCount ~= nil then
        return group.requiredGeneratedCount
    end
    if group.generatedExitCount ~= nil then
        return math.min(#(group.candidates or EMPTY_LIST), group.generatedExitCount)
    end
    return math.min(#(group.candidates or EMPTY_LIST), generatedExitCount(entry))
end

local function validateForcedGroup(entries, index, group)
    local entry = entries[index]
    local deadline = group.forceAtBiomeDepthMax
    if deadline == nil or (entry.biomeDepthCache or 0) < deadline then
        return nil
    end
    if group.pickedCandidateBeforeDeadlineClosesGroup
        and pickedCandidateBefore(entries, index, group.candidates)
    then
        return nil
    end
    local required = requiredGeneratedCount(group, entry)
    if generatedCandidateCountThrough(entries, index, group.candidates) >= required then
        return nil
    end
    return invalidAt(
        entry,
        "forced_topology_group_unresolved",
        "Forced " .. tostring(group.key or "topology") .. " deadline needs generated forced doors",
        {
            topologyGroupKey = group.key,
        }
    )
end

biomeRoomEntries = function(history, biomeKey)
    local entries = {}
    for _, entry in ipairs(routeHistory.byKind(history, "room")) do
        if entry.biomeKey == biomeKey and entry.sourceKind ~= "afterBiome" then
            entries[#entries + 1] = entry
        end
    end
    return entries
end

local function validatePickedEntries(history, biome)
    local roleCounts = {}
    local optionCounts = {}
    local previousOption = nil
    for _, entry in ipairs(biomeRoomEntries(history, biome.key)) do
        local role, option = declarationForEntry(biome, entry)
        if previousOption ~= nil then
            local requiredTags = previousOption.nextRoomTags
            local failure = nextRoomTagsFailure(requiredTags, option and option.tags)
            if failure ~= nil then
                return invalidAt(entry, failure, nextRoomTagsMessage(requiredTags))
            end
        end
        if option ~= nil then
            local failure = availabilityFailure(option, entry)
            if failure ~= nil then
                return invalidAt(entry, failure, "Room is not valid at this generated depth")
            end
        end
        local variantInvalid = variantFailure(entry)
        if variantInvalid ~= nil then
            local message = tostring(entry.variantLabel or entry.variantKey) .. " is not valid at this encounter depth"
            return invalidWithFindings(
                entry,
                variantInvalid,
                message,
                {
                    variantFinding(entry, variantInvalid, message),
                }
            )
        end

        local roleCap = capFor(role)
        if roleCap ~= nil and appendCount(roleCounts, role.key) > roleCap then
            return invalidAt(entry, "role_limit", tostring(role.label or role.key) .. " is already planned")
        end

        local optionCap = capFor(option)
        if optionCap ~= nil and appendCount(optionCounts, option.key) > optionCap then
            return invalidAt(
                entry,
                "option_limit",
                tostring(option.label or option.key) .. " is already generated"
            )
        end
        previousOption = option
    end
    return nil
end

local function validateRouteRequirement(history, entry, requirement)
    if requirement.kind == "previousRoomExitCount" then
        if routeQuery.requiredMinExits(history, entry, requirement.minCount) then
            return nil
        end
        return invalidAt(
            entry,
            "previous_room_exit_count",
            "Previous planned room must have at least " .. tostring(requirement.minCount) .. " exits"
        )
    end
    return invalidAt(
        entry,
        "unknown_route_requirement",
        "Unknown route requirement: " .. tostring(requirement.kind)
    )
end

local function validateRouteRequirements(history, biome)
    for _, entry in ipairs(biomeRoomEntries(history, biome.key)) do
        local role, option = declarationForEntry(biome, entry)
        for _, requirement in ipairs(role and role.routeRequirements or EMPTY_LIST) do
            local invalid = validateRouteRequirement(history, entry, requirement)
            if invalid ~= nil then
                return invalid
            end
        end
        for _, requirement in ipairs(option and option.routeRequirements or EMPTY_LIST) do
            local invalid = validateRouteRequirement(history, entry, requirement)
            if invalid ~= nil then
                return invalid
            end
        end
    end
    return nil
end

local function validateForcePressure(history, biome)
    local topology = routeStructureForBiome(biome)
    if topology == nil then
        return nil
    end

    local entries = biomeRoomEntries(history, biome.key)
    local optionsByRoomKey = topologyOptionsByRoomKey(topology)
    for index = 1, #entries do
        local invalid = validateUngroupedForce(topology, entries, index, optionsByRoomKey)
        if invalid ~= nil then
            return invalid
        end
        for _, group in ipairs(topology.forcedGroups or EMPTY_LIST) do
            invalid = validateForcedGroup(entries, index, group)
            if invalid ~= nil then
                return invalid
            end
        end
    end
    return nil
end

local function generatedRoomKeyThrough(entries, entryIndex, roomKeys)
    for index = 1, entryIndex do
        if candidateInList(roomKeys, entries[index].roomKey or entries[index].eventKey) then
            return true
        end
        for _, exit in ipairs(selectedAndGeneratedExits(entries[index])) do
            if candidateInList(roomKeys, exit.roomKey) then
                return true
            end
        end
    end
    return false
end

local function validateDeadlineRequirements(history, biome)
    local topology = routeStructureForBiome(biome)
    if topology == nil then
        return nil
    end

    local entries = biomeRoomEntries(history, biome.key)
    for _, requirement in ipairs(topology.deadlineRequirements or EMPTY_LIST) do
        local deadline = requirement.biomeDepthCache
        if deadline ~= nil then
            for index, entry in ipairs(entries) do
                if (entry.biomeDepthCache or 0) >= deadline then
                    if not generatedRoomKeyThrough(entries, index, requirement.roomKeys) then
                        return invalidAt(
                            entry,
                            requirement.code or "room_deadline_requirement",
                            requirement.message or "Required room missing by deadline",
                            {
                                topologyRequirementKey = requirement.key,
                            }
                        )
                    end
                    break
                end
            end
        end
    end
    return nil
end

function biomeStructure.validate(args)
    local history = args and args.history or nil
    local route = args and args.route or nil
    local biomeLookup = args and args.biomeLookup or nil
    local resultFindings = {}
    for _, biomeKey in ipairs(route and route.biomes or EMPTY_LIST) do
        local biome = biomeLookup and biomeLookup[biomeKey] or nil
        if biome ~= nil then
            local findingsForInvalid
            local invalid
            invalid, findingsForInvalid = validatePickedEntries(history, biome)
            if invalid == nil then
                invalid = validateRouteRequirements(history, biome)
            end
            if invalid == nil then
                invalid, findingsForInvalid = validateClockworkProgression(history, biome)
                appendFindings(resultFindings, findingsForInvalid)
            end
            if invalid == nil then
                invalid, findingsForInvalid = validateForcePressure(history, biome)
            end
            if invalid == nil then
                invalid = validateDeadlineRequirements(history, biome)
            end
            if invalid ~= nil then
                return {
                    valid = false,
                    invalids = { invalid },
                    findings = findingsForInvalid or resultFindings,
                }
            end
        end
    end
    return validResult(resultFindings)
end

return biomeStructure
