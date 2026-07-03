local deps = ... or {}

local routeHistory = deps.history
local roomCandidates = deps.roomCandidates
local rewardCandidates = deps.rewardCandidates
local siblingCandidates = deps.siblingCandidates

local walker = {}

local EMPTY_LIST = {}

local function numericCost(value, fallback)
    local cost = math.floor(tonumber(value) or fallback or 0)
    if cost < 0 then
        return 0
    end
    return cost
end

local function encounterCost(entry)
    return numericCost(entry and entry.biomeEncounterDepthCost, 0)
end

local function entryEncounterCost(entry)
    local cost = encounterCost(entry)
    if cost > 0 then
        return 1
    end
    return 0
end

local function remainingEncounterCost(entry)
    return encounterCost(entry) - entryEncounterCost(entry)
end

local function roomHistoryCost(entry)
    return numericCost(entry and entry.roomHistoryCost, 0)
end

local function preCommitRoomHistoryOrdinal(entry)
    return numericCost(entry and entry.roomHistoryOrdinal, 0) - roomHistoryCost(entry)
end

local function entryPhase(entry)
    local preCommitOrdinal = preCommitRoomHistoryOrdinal(entry)
    return {
        biomeDepthCache = entry and entry.biomeDepthCache or nil,
        biomeEncounterDepth = entry and entry.biomeEncounterDepth or nil,
        runEncounterDepth = entry and entry.runEncounterDepth or nil,
        runDepthCache = 1 + preCommitOrdinal,
        roomHistoryOrdinal = preCommitOrdinal,
    }
end

local function offerPhase(entry)
    local preCommitOrdinal = preCommitRoomHistoryOrdinal(entry)
    local remainingCost = remainingEncounterCost(entry)
    return {
        biomeDepthCache = entry and entry.biomeDepthCache or nil,
        biomeEncounterDepth = entry and entry.biomeEncounterDepth ~= nil
            and entry.biomeEncounterDepth + remainingCost
            or nil,
        runEncounterDepth = entry and entry.runEncounterDepth ~= nil
            and entry.runEncounterDepth + remainingCost
            or nil,
        runDepthCache = 1 + preCommitOrdinal,
        roomHistoryOrdinal = preCommitOrdinal,
    }
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

local function fixedSpecialByKind(slotLayout, key)
    for _, special in pairs(slotLayout and slotLayout.special or {}) do
        if special.kind == key or special.key == key then
            return special
        end
    end
    return nil
end

local function fixedEntryForRoom(slotLayout, entry)
    local entryRoomKey = entry and entry.roomKey or nil
    local layoutEntry = slotLayout and slotLayout.entry or nil
    local entryRoleMatches = entry ~= nil and entry.roleKey == (layoutEntry and layoutEntry.key or "Intro")
    local entryRoomMatches = entryRoomKey ~= nil and layoutEntry ~= nil and entryRoomKey == layoutEntry.roomKey
    if layoutEntry ~= nil and (entryRoleMatches or entryRoomMatches) then
        return layoutEntry
    end
    for _, fixed in ipairs(slotLayout and slotLayout.fixedBeforeRoute or EMPTY_LIST) do
        if entryRoomKey ~= nil and (fixed.roomKey == entryRoomKey or fixed.room and fixed.room.key == entryRoomKey) then
            return fixed
        end
    end
    for _, fixed in ipairs(slotLayout and slotLayout.fixedAfterRoute or EMPTY_LIST) do
        if entryRoomKey ~= nil and (fixed.roomKey == entryRoomKey or fixed.room and fixed.room.key == entryRoomKey) then
            return fixed
        end
    end
    return fixedSpecialByKind(slotLayout, entry and entry.roleKey or nil)
end

local function declarationForEntry(biome, entry)
    local role = biome
        and biome.rolesByKey
        and biome.rolesByKey[entry and entry.roleKey or nil]
        or fixedEntryForRoom(biome and biome.slotLayout or nil, entry)
    local option = optionByKey(role, entry and entry.optionKey)
        or optionByRoomKey(role, entry and entry.roomKey)
        or role and role.room
    return role, option
end

local function rewardContext(role, option)
    if option ~= nil and option.reward ~= nil then
        return option.reward
    end
    return role and role.reward or nil
end

local function selectedRowForEntry(entry)
    return entry and entry.source or {
        rowIndex = entry and entry.rowIndex or nil,
        formAddress = entry and entry.formAddress or nil,
        routeOrdinal = entry and entry.routeOrdinal or nil,
        roleKey = entry and entry.roleKey or nil,
        optionKey = entry and entry.optionKey or nil,
        variantKey = entry and entry.variantKey or nil,
    }
end

local function resolvedForStep(step)
    return {
        role = step.selected.role,
        option = step.selected.option,
        routeOrdinal = step.entry and step.entry.routeOrdinal or nil,
        rewardContext = step.rewardContext,
        biomeDepthCacheCost = step.entry and step.entry.biomeDepthCacheCost or nil,
        biomeEncounterDepthCost = step.entry and step.entry.biomeEncounterDepthCost or nil,
        roomHistoryCost = step.entry and step.entry.roomHistoryCost or nil,
    }
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
    local picked = topology.picked or topology.selected
    if picked ~= nil then
        exits[#exits + 1] = picked
    end
    local otherDoors = topology.otherDoors or topology.siblings
    if otherDoors ~= nil then
        for _, door in ipairs(otherDoors) do
            exits[#exits + 1] = door
        end
    elseif topology.sibling ~= nil then
        exits[#exits + 1] = topology.sibling
    end
    return exits
end

local function adapterUsesPickedDoorCandidates(adapter)
    return adapter == "fixedLinear" or adapter == "clockworkGoal"
end

local function variantPolicyForStep(step)
    local policyKey = step.selected.role and step.selected.role.encounterPolicy or nil
    local policy = step.biome
        and step.biome.roomTopology
        and step.biome.roomTopology.combatEncounterPolicy
        or nil
    if policyKey ~= nil and policy ~= nil and policy.key == policyKey then
        return policy
    end
    return nil
end

local function rewardLegs(policy)
    if policy == nil then
        return EMPTY_LIST
    end
    if policy.rewardLegs ~= nil then
        return policy.rewardLegs
    end
    local legs = {}
    for _, leg in ipairs(policy.legs or EMPTY_LIST) do
        if leg.hasReward == true then
            legs[#legs + 1] = leg
        end
    end
    return legs
end

local function rewardLegByIndex(policy, legIndex)
    local expectedKey = legIndex ~= nil and "Encounter" .. tostring(legIndex) or nil
    for _, leg in ipairs(rewardLegs(policy)) do
        if leg.legIndex == legIndex or leg.key == expectedKey then
            return leg
        end
    end
    return nil
end

local function rewardCandidateOpts(entry)
    local reward = entry and entry.reward or nil
    if reward ~= nil and reward.kind == "fieldsCages" then
        return {
            sameExitRewardCount = reward.sameExitRewardCount,
        }
    end
    return nil
end

local function rewardCandidatesForStep(step)
    local reward = step.entry and step.entry.reward or nil
    if reward ~= nil and reward.kind == "multiEncounter" then
        local candidates = {}
        for _, encounter in ipairs(reward.encounters or EMPTY_LIST) do
            local leg = rewardLegByIndex(variantPolicyForStep(step), encounter.legIndex)
            for _, candidate in ipairs(rewardCandidates.forContext(leg and leg.reward or nil)) do
                candidate.address = "encounter:" .. tostring(encounter.legIndex)
                candidates[#candidates + 1] = candidate
            end
        end
        return candidates
    end
    return rewardCandidates.forContext(step.rewardContext, rewardCandidateOpts(step.entry))
end

local function variantCandidatesForStep(step)
    local policy = variantPolicyForStep(step)
    local candidates = {}
    for _, option in ipairs(policy and policy.countControl and policy.countControl.options or EMPTY_LIST) do
        candidates[#candidates + 1] = {
            key = option.key,
            label = option.label or option.key,
            availableAtBiomeEncounterDepth = option.availableAtBiomeEncounterDepth,
            controlAlias = "VariantKey",
        }
    end
    return candidates
end

local function appendRoomCandidates(step)
    step.candidates.rooms = roomCandidates.forBiomeRow(
        step.biome,
        step.source,
        resolvedForStep(step),
        {
            availabilityContext = step.phases.generated or step.phases.entry,
        }
    )

    local nextStep = step.next
    if nextStep ~= nil and adapterUsesPickedDoorCandidates(step.biome and step.biome.adapter) then
        local candidates = roomCandidates.forBiomeRow(
            step.biome,
            nextStep.source,
            resolvedForStep(nextStep),
            {
                availabilityContext = step.phases.offer,
                targetRowIndex = nextStep.entry and nextStep.entry.rowIndex or nil,
                targetRouteOrdinal = nextStep.entry and nextStep.entry.routeOrdinal or nil,
                targetFormAddress = nextStep.entry and nextStep.entry.formAddress or nil,
            }
        )
        for _, candidate in ipairs(candidates) do
            step.candidates.rooms[#step.candidates.rooms + 1] = candidate
        end
    end
end

local function appendSiblingCandidates(step)
    step.candidates.siblings = siblingCandidates.forBiomeRow(step.biome, step.source, {
        availabilityContext = step.phases.offer,
    })
end

local function appendRewardCandidates(step)
    step.candidates.rewards = rewardCandidatesForStep(step)
end

local function appendVariantCandidates(step)
    step.candidates.variants = variantCandidatesForStep(step)
end

local function buildStep(args, entry, index, previousOffer)
    local role, option = declarationForEntry(args.biome, entry)
    local exits = topologyExits(entry)
    local phases = {
        generated = previousOffer,
        entry = entryPhase(entry),
        offer = offerPhase(entry),
    }
    return {
        history = args.history,
        biome = args.biome,
        entry = entry,
        index = index,
        source = selectedRowForEntry(entry),
        selected = {
            role = role,
            option = option,
        },
        rewardContext = rewardContext(role, option),
        phases = phases,
        topology = {
            exits = exits,
            generatedExitCount = #exits,
        },
        candidates = {
            rooms = {},
            siblings = {},
            variants = {},
            rewards = {},
        },
    }
end

local function biomeEntries(history, biomeKey)
    local entries = {}
    for _, entry in ipairs(routeHistory.byKind(history, "room")) do
        if entry.biomeKey == biomeKey and entry.eventSourceKind ~= "afterBiome" then
            entries[#entries + 1] = entry
        end
    end
    return entries
end

function walker.forBiome(args)
    local entries = biomeEntries(args.history, args.biome and args.biome.key or nil)
    local steps = {}
    local previousOffer = nil
    for index, entry in ipairs(entries) do
        local step = buildStep(args, entry, index, previousOffer)
        steps[index] = step
        previousOffer = step.phases.offer
    end
    for index, step in ipairs(steps) do
        step.previous = steps[index - 1]
        step.next = steps[index + 1]
    end
    for _, step in ipairs(steps) do
        appendRoomCandidates(step)
        appendSiblingCandidates(step)
        appendVariantCandidates(step)
        appendRewardCandidates(step)
    end
    return steps
end

function walker.forRoute(args)
    local routeSteps = {}
    for _, biomeKey in ipairs(args.route and args.route.biomes or EMPTY_LIST) do
        local biome = args.biomeLookup and args.biomeLookup[biomeKey] or nil
        if biome ~= nil then
            for _, step in ipairs(walker.forBiome({
                history = args.history,
                biome = biome,
            })) do
                routeSteps[#routeSteps + 1] = step
            end
        end
    end
    return routeSteps
end

return walker
