local deps = ... or {}

local multiEncounterFixed = {}
local rewardCandidates = deps.rewardCandidates
local routeStep = deps.step

local EMPTY_LIST = {}
local BIOME_ENCOUNTER_DEPTH_START = 0
local MAJOR_REWARD_STORE = "RunProgress"
local MINOR_REWARD_STORE = "MetaProgress"

local function numericCost(value, fallback)
    local cost = math.floor(tonumber(value) or fallback or 0)
    if cost < 0 then
        return 0
    end
    return cost
end

local function copyList(source)
    if source == nil then
        return nil
    end
    local copy = {}
    for index, value in ipairs(source) do
        copy[index] = value
    end
    return copy
end

local function routeStartOrdinal(slotLayout)
    return math.floor(tonumber(slotLayout and slotLayout.routeStartOrdinal or 1) or 1)
end

local function fixedPrefixRowCount(slotLayout)
    local count = 0
    if slotLayout and slotLayout.entry ~= nil then
        count = count + 1
    end
    return count
end

local function fixedSpecialOrdinal(slotLayout, key)
    for ordinal, special in pairs(slotLayout and slotLayout.special or {}) do
        if special.kind == key or special.key == key then
            return math.floor(tonumber(ordinal) or 0)
        end
    end
    return nil
end

local function roleOptionList(role)
    return role and (role.roomOptions or role.mapOptions) or EMPTY_LIST
end

local function optionByKey(role, optionKey)
    if role == nil or optionKey == nil or optionKey == "" then
        return nil
    end
    if role.optionsByKey ~= nil then
        return role.optionsByKey[optionKey]
    end
    for _, option in ipairs(roleOptionList(role)) do
        if option.key == optionKey then
            return option
        end
    end
    return nil
end

local function defaultOption(role)
    return roleOptionList(role)[1]
end

local function fixedSpecialByKind(slotLayout, kind)
    local entry = slotLayout and slotLayout.entry or nil
    if entry ~= nil and (entry.kind == kind or entry.key == kind or kind == "Intro") then
        return entry
    end
    for _, special in pairs(slotLayout and slotLayout.special or {}) do
        if special.kind == kind or special.key == kind then
            return special
        end
    end
    return nil
end

local function roleForRow(biome, selectedRow)
    local role = biome.rolesByKey and biome.rolesByKey[selectedRow.roleKey] or nil
    if role ~= nil then
        return role
    end
    local special = fixedSpecialByKind(biome.slotLayout, selectedRow.roleKey)
    if special ~= nil then
        return special
    end
    return nil
end

local function optionForRow(role, selectedRow)
    return optionByKey(role, selectedRow.optionKey) or defaultOption(role)
end

local function roomKeyFor(role, option)
    return option and option.key
        or role and role.roomKey
        or role and role.room and role.room.key
        or nil
end

local function eventKeyFor(selectedRow, role, option)
    return roomKeyFor(role, option)
        or role and role.key
        or selectedRow.roleKey
end

local function rewardContext(role, option)
    if option ~= nil and option.reward ~= nil then
        return option.reward
    end
    return role and role.reward or nil
end

local function variantPolicyForRole(biome, role)
    local policyKey = role and role.encounterPolicy or nil
    if policyKey == nil then
        return nil
    end
    local policy = biome
        and biome.roomTopology
        and biome.roomTopology.combatEncounterPolicy
        or nil
    if policy ~= nil and policy.key == policyKey then
        return policy
    end
    return nil
end

local function optionByControlKey(control, key)
    if key == nil or key == "" then
        return nil
    end
    if control ~= nil and control.optionsByKey ~= nil then
        return control.optionsByKey[key]
    end
    for _, option in ipairs(control and control.options or EMPTY_LIST) do
        if option.key == key then
            return option
        end
    end
    return nil
end

local function variantForRow(biome, role, selectedRow)
    local policy = variantPolicyForRole(biome, role)
    return optionByControlKey(policy and policy.countControl or nil, selectedRow.variantKey)
end

local function variantCandidates(policy)
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

local function wheelOfferForKey(policy, key)
    return optionByControlKey(policy and policy.wheelOfferControl or nil, key)
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

local function selectedRouteOrdinal(slotLayout, selectedRow)
    local entry = slotLayout and slotLayout.entry or nil
    if entry ~= nil and selectedRow.roleKey == (entry.key or "Intro") then
        return entry.routeOrdinal or 0
    end

    local specialOrdinal = fixedSpecialOrdinal(slotLayout, selectedRow.roleKey)
    if specialOrdinal ~= nil then
        return specialOrdinal
    end

    return routeStartOrdinal(slotLayout)
        + (selectedRow.rowIndex or 1)
        - fixedPrefixRowCount(slotLayout)
        - 1
end

local function costValue(_, role, option, field, fallback)
    if option ~= nil and option[field] ~= nil then
        return numericCost(option[field], fallback)
    end
    if role ~= nil and role[field] ~= nil then
        return numericCost(role[field], fallback)
    end
    return fallback
end

local function selectedRewardFromMajorMinor(context, rewards)
    local values = rewards and rewards.values or EMPTY_LIST
    local rewardClass = values[1]
    if rewardClass == "Major" then
        local rewardType = values[2]
        return {
            kind = "majorMinor",
            rewardClass = rewardClass,
            rewardStore = context.majorRewardStore or MAJOR_REWARD_STORE,
            controlAlias = "Reward2Key",
            rewardType = rewardType ~= "" and rewardType or nil,
            boonSource = rewardType == "Boon" and values[3] or nil,
            devotionSources = rewardType == "Devotion" and { values[5], values[6] } or nil,
        }
    elseif rewardClass == "Minor" then
        local rewardType = values[4]
        return {
            kind = "majorMinor",
            rewardClass = rewardClass,
            rewardStore = context.minorRewardStore or MINOR_REWARD_STORE,
            controlAlias = "Reward4Key",
            rewardType = rewardType ~= "" and rewardType or nil,
        }
    end
    return {
        kind = "majorMinor",
    }
end

local function onlyEligibleRewardType(context)
    local eligible = context and context.eligibleRewardTypes or nil
    if eligible ~= nil and eligible[1] ~= nil and eligible[2] == nil then
        return eligible[1]
    end
    return nil
end

local function selectedRewardFromRoomStore(context, rewards)
    local values = rewards and rewards.row and rewards.row.values or EMPTY_LIST
    local fixedRewardType = onlyEligibleRewardType(context)
    local rewardType = fixedRewardType or values[1]
    return {
        kind = "roomStore",
        rewardStore = context.rewardStore,
        controlAlias = "Reward1Key",
        rewardType = rewardType ~= "" and rewardType or nil,
        eligibleRewardTypes = copyList(context.eligibleRewardTypes),
        ineligibleRewardTypes = copyList(context.ineligibleRewardTypes),
        boonSource = rewardType == "Boon" and values[fixedRewardType ~= nil and 1 or 2] or nil,
        devotionSources = rewardType == "Devotion" and { values[3], values[4] } or nil,
    }
end

local function selectedRewardSummary(context, rewards)
    if context == nil or context.kind == nil or context.kind == "none" then
        return nil
    elseif context.kind == "majorMinor" then
        return selectedRewardFromMajorMinor(context, rewards and rewards.row)
    elseif context.kind == "roomStore" then
        return selectedRewardFromRoomStore(context, rewards)
    elseif context.kind == "shop" then
        return {
            kind = "shop",
            shopProfile = context.shopProfile,
            effectTiming = context.rewardGeneration and context.rewardGeneration.effectTiming or nil,
        }
    elseif context.kind == "forcedReward" then
        return {
            kind = "forcedReward",
            rewardStore = context.rewardStore,
            rewardType = context.rewardType,
        }
    end
    return {
        kind = context.kind,
    }
end

local function selectedEncounterRewardSummary(leg, encounterReward)
    return selectedRewardFromMajorMinor(leg.reward, encounterReward)
end

local function encounterRewardCandidates(leg, legIndex)
    local candidates = rewardCandidates.forContext(leg.reward)
    for _, candidate in ipairs(candidates) do
        candidate.address = "encounter:" .. tostring(legIndex)
    end
    return candidates
end

local function encounterRewardAt(selectedRow, legIndex)
    for _, reward in ipairs(selectedRow and selectedRow.rewards and selectedRow.rewards.encounter or EMPTY_LIST) do
        if reward.legIndex == legIndex then
            return reward
        end
    end
    return nil
end

local function encounterSnapshots(context, selectedRow, resolved)
    local policy = resolved.policy
    local encounters = {}
    for legIndex, leg in ipairs(rewardLegs(policy)) do
        local encounterReward = encounterRewardAt(selectedRow, legIndex)
        if encounterReward ~= nil then
            local wheel = wheelOfferForKey(policy, encounterReward.wheelOfferKey)
            encounters[#encounters + 1] = {
                legIndex = legIndex,
                key = leg.key,
                label = leg.label,
                wheelOfferKey = encounterReward.wheelOfferKey,
                wheelOfferCount = wheel and wheel.wheelOfferCount or nil,
                biomeEncounterDepth = context.biomeState.biomeEncounterDepth + legIndex - 1,
                runEncounterDepth = context.routeState.runEncounterDepth + legIndex - 1,
                reward = selectedEncounterRewardSummary(leg, encounterReward),
                rewardCandidates = encounterRewardCandidates(leg, legIndex),
            }
        end
    end
    return encounters
end

local function attachShipCombat(context, roomEntry, selectedRow, resolved)
    if roomEntry == nil or resolved.policy == nil then
        return
    end

    local encounters = encounterSnapshots(context, selectedRow, resolved)
    if encounters[1] == nil then
        return
    end

    local topologyEncounters = {}
    for index, encounter in ipairs(encounters) do
        topologyEncounters[index] = {
            legIndex = encounter.legIndex,
            key = encounter.key,
            wheelOfferKey = encounter.wheelOfferKey,
            wheelOfferCount = encounter.wheelOfferCount,
        }
    end

    roomEntry.reward = {
        kind = "multiEncounter",
        encounters = encounters,
    }
    roomEntry.rewardCandidates = {}
    for _, encounter in ipairs(encounters) do
        for _, candidate in ipairs(encounter.rewardCandidates or EMPTY_LIST) do
            roomEntry.rewardCandidates[#roomEntry.rewardCandidates + 1] = candidate
        end
    end
    roomEntry.topology = {
        kind = "shipCombat",
        encounters = topologyEncounters,
    }
end

local function resolveRow(context, selectedRow)
    local role = roleForRow(context.biome, selectedRow)
    local option = optionForRow(role, selectedRow)
    local slotLayout = context.biome.slotLayout or {}
    local variant = variantForRow(context.biome, role, selectedRow)
    local biomeEncounterDepthCost = variant ~= nil
        and numericCost(variant.biomeEncounterDepthCost, 0)
        or costValue(slotLayout, role, option, "biomeEncounterDepthCost", 0)
    local biomeDepthCacheCost = costValue(slotLayout, role, option, "biomeDepthCacheCost", 0)

    if selectedRow.roleKey ~= "Intro"
        and selectedRow.roleKey ~= "Preboss"
        and role ~= nil
        and role.kind == nil
    then
        biomeDepthCacheCost = numericCost(slotLayout.routeRow and slotLayout.routeRow.biomeDepthCacheCost, 0)
    end

    return {
        role = role,
        option = option,
        variant = variant,
        policy = variantPolicyForRole(context.biome, role),
        routeOrdinal = selectedRouteOrdinal(slotLayout, selectedRow),
        roomKey = roomKeyFor(role, option),
        eventKey = eventKeyFor(selectedRow, role, option),
        rewardContext = rewardContext(role, option),
        biomeDepthCacheCost = biomeDepthCacheCost,
        biomeEncounterDepthCost = biomeEncounterDepthCost,
        roomHistoryCost = costValue(slotLayout, role, option, "roomHistoryCost", 0),
    }
end

function multiEncounterFixed.build(args)
    local context = {
        routeKey = args.route and args.route.key or args.snapshot.routeKey,
        routeBiomeIndex = args.routeBiomeIndex,
        history = args.history,
        routeHistory = args.routeHistory,
        snapshot = args.snapshot,
        biome = args.biome,
        routeState = args.routeState,
        biomeState = {
            biomeDepthCache = numericCost(
                args.biome and args.biome.slotLayout and args.biome.slotLayout.biomeDepthCacheStart,
                0
            ),
            biomeEncounterDepth = BIOME_ENCOUNTER_DEPTH_START,
        },
    }

    local resolvedRows = {}
    for index, selectedRow in ipairs(args.snapshot.rows or EMPTY_LIST) do
        resolvedRows[index] = resolveRow(context, selectedRow)
    end

    for index, selectedRow in ipairs(args.snapshot.rows or EMPTY_LIST) do
        local resolved = resolvedRows[index]
        routeStep.stepRoom(context, selectedRow, resolved, {
            reward = selectedRewardSummary(resolved.rewardContext, selectedRow.rewards),
            fields = {
                variantLabel = resolved.variant and resolved.variant.label or nil,
                variantAvailability = resolved.variant and resolved.variant.availableAtBiomeEncounterDepth or nil,
                variantCandidates = variantCandidates(resolved.policy),
            },
            attachReward = false,
            attachTopology = function(roomEntry)
                roomEntry.reward = selectedRewardSummary(resolved.rewardContext, selectedRow.rewards)
                attachShipCombat(context, roomEntry, selectedRow, resolved)
            end,
        })
    end
end

return multiEncounterFixed
