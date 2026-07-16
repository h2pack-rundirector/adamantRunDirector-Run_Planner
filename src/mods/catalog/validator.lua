local deps = ...
local s = deps.schema
local requirementSchema = deps.requirements

local validator = {}

local function fail(path, message)
    error("catalog invariant at " .. path .. ": " .. message, 0)
end

local function copy(value, seen)
    if type(value) ~= "table" then
        return value
    end
    seen = seen or {}
    if seen[value] ~= nil then
        return seen[value]
    end
    local result = {}
    seen[value] = result
    for key, child in pairs(value) do
        result[copy(key, seen)] = copy(child, seen)
    end
    return result
end

local function nonEmptyString(value, path)
    if type(value) ~= "string" or value == "" then
        fail(path, "expected a non-empty string")
    end
end

local function positiveInteger(value, path, allowZero)
    local minimum = allowZero and 0 or 1
    if type(value) ~= "number" or value ~= math.floor(value) or value < minimum then
        fail(path, "expected an integer >= " .. tostring(minimum))
    end
end

local function requiredTable(value, path)
    if type(value) ~= "table" then
        fail(path, "expected an explicit table")
    end
end

local function requiredBoolean(value, path)
    if type(value) ~= "boolean" then
        fail(path, "expected an explicit boolean")
    end
end

local function contains(values, expected)
    for _, value in ipairs(values or {}) do
        if value == expected then
            return true
        end
    end
    return false
end

local function orderedCatalog(values, path)
    return s.orderedCatalog(values, path, true)
end

local function keyedCatalog(values, path)
    return s.keyedCatalog(values, path, true)
end

local function addUniqueOption(options, seen, rewardType)
    if not seen[rewardType] then
        seen[rewardType] = true
        options[#options + 1] = rewardType
    end
end

local function validateRewards(raw, requirements)
    local rewards = copy(raw)
    requiredTable(rewards, "rewards")
    s.onlyKeys(rewards, {
        "bags", "batchConstraints", "payloadDomains", "primitives", "shops",
    }, "rewards")
    rewards.primitives = keyedCatalog(rewards.primitives, "rewards.primitives")
    rewards.payloadDomains = keyedCatalog(rewards.payloadDomains, "rewards.payloadDomains")
    rewards.bags = keyedCatalog(rewards.bags, "rewards.bags")
    rewards.batchConstraints = keyedCatalog(rewards.batchConstraints, "rewards.batchConstraints")

    for _, primitive in ipairs(rewards.primitives.ordered) do
        local path = "rewards.primitives." .. primitive.key
        s.onlyKeys(primitive, { "acquiredAs", "key", "label", "payloadDomain" }, path)
        nonEmptyString(primitive.label, path .. ".label")
        if primitive.payloadDomain ~= nil and rewards.payloadDomains.lookup[primitive.payloadDomain] == nil then
            fail(path .. ".payloadDomain", "unknown payload domain '" .. primitive.payloadDomain .. "'")
        end
        if primitive.acquiredAs ~= nil and rewards.primitives.lookup[primitive.acquiredAs] == nil then
            fail(path .. ".acquiredAs", "unknown reward primitive '" .. primitive.acquiredAs .. "'")
        end
    end
    for _, domain in ipairs(rewards.payloadDomains.ordered) do
        local path = "rewards.payloadDomains." .. domain.key
        if domain.kind == "oneOf" then
            s.onlyKeys(domain, { "key", "kind", "values" }, path)
            s.stringList(domain.values, path .. ".values", true)
            for index, rewardType in ipairs(domain.values or {}) do
                if rewards.primitives.lookup[rewardType] == nil then
                    fail(path .. ".values[" .. tostring(index) .. "]", "unknown reward primitive '" .. tostring(rewardType) .. "'")
                end
            end
        elseif domain.kind == "distinctPair" then
            s.onlyKeys(domain, { "key", "kind", "valueDomain" }, path)
            if rewards.payloadDomains.lookup[domain.valueDomain] == nil then
                fail(path .. ".valueDomain", "unknown payload domain '" .. tostring(domain.valueDomain) .. "'")
            end
        else
            fail(path .. ".kind", "unknown payload-domain kind '" .. tostring(domain.kind) .. "'")
        end
    end

    local normalizedAcquisitions = {}
    for _, primitive in ipairs(rewards.primitives.ordered) do
        normalizedAcquisitions[primitive.key] = primitive.acquiredAs or primitive.key
    end
    rewards.normalizedAcquisitions = normalizedAcquisitions

    rewards.stores = { ordered = {}, lookup = {} }
    for _, bag in ipairs(rewards.bags.ordered) do
        local bagPath = "rewards.bags." .. bag.key
        s.onlyKeys(bag, { "entries", "key", "refill" }, bagPath)
        if bag.refill ~= "appendWhenNoEligibleEntry" then
            fail(bagPath .. ".refill", "unknown refill policy '" .. tostring(bag.refill) .. "'")
        end
        s.list(bag.entries, bagPath .. ".entries", true)
        local options = {}
        local seen = {}
        for index, entry in ipairs(bag.entries) do
            local entryPath = bagPath .. ".entries[" .. tostring(index) .. "]"
            requiredTable(entry, entryPath)
            s.onlyKeys(entry, { "requirementKey", "rewardType" }, entryPath)
            nonEmptyString(entry.rewardType, entryPath .. ".rewardType")
            if rewards.primitives.lookup[entry.rewardType] == nil then
                fail(entryPath .. ".rewardType", "unknown reward primitive '" .. entry.rewardType .. "'")
            end
            if entry.requirementKey ~= nil then
                local requirement = requirements.named[entry.requirementKey]
                if requirement == nil then
                    fail(entryPath .. ".requirementKey", "unknown named requirement '" .. entry.requirementKey .. "'")
                end
                requirementSchema.validateNode(
                    requirement,
                    requirements,
                    "requirements.named." .. entry.requirementKey,
                    "reward.offer"
                )
            end
            addUniqueOption(options, seen, entry.rewardType)
        end
        local store = { key = bag.key, options = options, bagKey = bag.key }
        rewards.stores.ordered[#rewards.stores.ordered + 1] = store
        rewards.stores.lookup[bag.key] = store
    end

    for _, constraint in ipairs(rewards.batchConstraints.ordered) do
        local path = "rewards.batchConstraints." .. constraint.key
        s.enum(
            constraint.kind,
            { "distinctPayloadValues", "uniqueBoonSources", "uniqueRewardTypes" },
            path .. ".kind"
        )
        if constraint.kind == "uniqueRewardTypes" then
            s.onlyKeys(constraint, { "allowDuplicates", "key", "kind", "slotGroup" }, path)
        else
            s.onlyKeys(constraint, { "key", "kind" }, path)
        end
        if constraint.allowDuplicates ~= nil then
            requiredTable(constraint.allowDuplicates, path .. ".allowDuplicates")
            for rewardType, allowedDuplicate in pairs(constraint.allowDuplicates) do
                if rewards.primitives.lookup[rewardType] == nil then
                    fail(path .. ".allowDuplicates." .. rewardType, "unknown reward primitive")
                end
                requiredBoolean(allowedDuplicate, path .. ".allowDuplicates." .. rewardType)
            end
        end
        if constraint.slotGroup ~= nil then
            nonEmptyString(constraint.slotGroup, path .. ".slotGroup")
        end
    end

    local shops = copy(rewards.shops)
    requiredTable(shops, "rewards.shops")
    s.onlyKeys(shops, { "optionSets", "profiles" }, "rewards.shops")
    requiredTable(shops.optionSets, "rewards.shops.optionSets")
    for optionSetKey, optionSet in pairs(shops.optionSets) do
        s.stringList(optionSet, "rewards.shops.optionSets." .. tostring(optionSetKey), true)
    end
    shops.optionSets = keyedCatalog(shops.optionSets, "rewards.shops.optionSets")
    shops.profiles = keyedCatalog(shops.profiles, "rewards.shops.profiles")
    for _, optionSet in ipairs(shops.optionSets.ordered) do
        for index, rewardType in ipairs(optionSet) do
            if rewards.primitives.lookup[rewardType] == nil then
                fail("rewards.shops.optionSets." .. optionSet.key .. "[" .. tostring(index) .. "]", "unknown reward primitive '" .. tostring(rewardType) .. "'")
            end
        end
    end
    for _, profile in ipairs(shops.profiles.ordered) do
        local profilePath = "rewards.shops.profiles." .. profile.key
        s.onlyKeys(profile, { "constraintKeys", "key", "slots" }, profilePath)
        if profile.constraintKeys ~= nil then
            s.stringList(profile.constraintKeys, profilePath .. ".constraintKeys", true)
        end
        s.list(profile.slots, profilePath .. ".slots", true)
        local allowedSlotGroups = {}
        for index, constraintKey in ipairs(profile.constraintKeys or {}) do
            if rewards.batchConstraints.lookup[constraintKey] == nil then
                fail(profilePath .. ".constraintKeys[" .. tostring(index) .. "]", "unknown batch constraint '" .. constraintKey .. "'")
            end
            local slotGroup = rewards.batchConstraints.lookup[constraintKey].slotGroup
            if slotGroup ~= nil then
                allowedSlotGroups[slotGroup] = true
            end
        end
        local slotKeys = {}
        local usedSlotGroups = {}
        for index, slot in ipairs(profile.slots or {}) do
            local slotPath = profilePath .. ".slots[" .. tostring(index) .. "]"
            requiredTable(slot, slotPath)
            s.onlyKeys(slot, { "key", "optionSetKey", "uniqueGroup" }, slotPath)
            nonEmptyString(slot.key, slotPath .. ".key")
            if slotKeys[slot.key] then
                fail(slotPath .. ".key", "duplicate shop slot key '" .. slot.key .. "'")
            end
            slotKeys[slot.key] = true
            nonEmptyString(slot.optionSetKey, slotPath .. ".optionSetKey")
            if shops.optionSets.lookup[slot.optionSetKey] == nil then
                fail(slotPath .. ".optionSetKey", "unknown option set '" .. tostring(slot.optionSetKey) .. "'")
            end
            if slot.uniqueGroup ~= nil then
                nonEmptyString(slot.uniqueGroup, slotPath .. ".uniqueGroup")
                if not allowedSlotGroups[slot.uniqueGroup] then
                    fail(slotPath .. ".uniqueGroup", "no referenced constraint owns slot group '" .. slot.uniqueGroup .. "'")
                end
                usedSlotGroups[slot.uniqueGroup] = true
            end
        end
        for slotGroup in pairs(allowedSlotGroups) do
            if not usedSlotGroups[slotGroup] then
                fail(profilePath .. ".slots", "referenced slot group '" .. slotGroup .. "' has no shop slots")
            end
        end
    end
    rewards.shops = shops

    return rewards
end

local function validateConstraintKeys(rewards, constraintKeys, path)
    requiredTable(constraintKeys, path)
    s.stringList(constraintKeys, path, false)
    for index, constraintKey in ipairs(constraintKeys) do
        if rewards.batchConstraints.lookup[constraintKey] == nil then
            fail(path .. "[" .. tostring(index) .. "]", "unknown batch constraint '" .. constraintKey .. "'")
        end
    end
end

local function validateStoreKeys(rewards, storeKeys, path)
    requiredTable(storeKeys, path)
    s.stringList(storeKeys, path, true)
    for index, storeKey in ipairs(storeKeys) do
        if rewards.stores.lookup[storeKey] == nil then
            fail(path .. "[" .. tostring(index) .. "]", "unknown reward store '" .. tostring(storeKey) .. "'")
        end
    end
end

local function validateRewardTypes(rewards, rewardTypes, path)
    requiredTable(rewardTypes, path)
    s.stringList(rewardTypes, path, false)
    for index, rewardType in ipairs(rewardTypes) do
        if rewards.primitives.lookup[rewardType] == nil then
            fail(path .. "[" .. tostring(index) .. "]", "unknown reward primitive '" .. tostring(rewardType) .. "'")
        end
    end
end

local function validateCountedChoice(binding, rewards, path)
    s.onlyKeys(binding, {
        "batchConstraint", "eligibleRewardTypes", "ineligibleRewardTypes", "kind", "storeKeys",
    }, path)
    validateStoreKeys(rewards, binding.storeKeys, path .. ".storeKeys")
    validateRewardTypes(rewards, binding.eligibleRewardTypes, path .. ".eligibleRewardTypes")
    validateRewardTypes(rewards, binding.ineligibleRewardTypes, path .. ".ineligibleRewardTypes")

    local storeOptions = {}
    for _, storeKey in ipairs(binding.storeKeys) do
        for _, rewardType in ipairs(rewards.stores.lookup[storeKey].options) do
            storeOptions[rewardType] = true
        end
    end
    local eligible = {}
    for index, rewardType in ipairs(binding.eligibleRewardTypes) do
        if not storeOptions[rewardType] then
            fail(
                path .. ".eligibleRewardTypes[" .. tostring(index) .. "]",
                "reward primitive '" .. rewardType .. "' is not offered by the referenced stores"
            )
        end
        eligible[rewardType] = true
    end
    local ineligible = {}
    for index, rewardType in ipairs(binding.ineligibleRewardTypes) do
        if not storeOptions[rewardType] then
            fail(
                path .. ".ineligibleRewardTypes[" .. tostring(index) .. "]",
                "reward primitive '" .. rewardType .. "' is not offered by the referenced stores"
            )
        end
        if eligible[rewardType] then
            fail(
                path .. ".ineligibleRewardTypes[" .. tostring(index) .. "]",
                "reward primitive '" .. rewardType .. "' is both eligible and ineligible"
            )
        end
        ineligible[rewardType] = true
    end

    for storeIndex, storeKey in ipairs(binding.storeKeys) do
        local allowedCount = 0
        for _, rewardType in ipairs(rewards.stores.lookup[storeKey].options) do
            if (#binding.eligibleRewardTypes == 0 or eligible[rewardType])
                and not ineligible[rewardType]
            then
                allowedCount = allowedCount + 1
            end
        end
        if allowedCount == 0 then
            fail(
                path .. ".storeKeys[" .. tostring(storeIndex) .. "]",
                "reward store '" .. storeKey .. "' has no allowed reward primitives"
            )
        end
    end
    if binding.batchConstraint ~= nil
        and rewards.batchConstraints.lookup[binding.batchConstraint] == nil
    then
        fail(path .. ".batchConstraint", "unknown batch constraint '" .. binding.batchConstraint .. "'")
    end
end

local function validateRewardBinding(binding, rewards, path)
    requiredTable(binding, path)
    s.enum(
        binding.kind,
        { "countedChoice", "fixed", "incomingKind", "localSlots", "none", "shop" },
        path .. ".kind"
    )
    if binding.kind == "none" then
        s.onlyKeys(binding, { "kind" }, path)
    elseif binding.kind == "countedChoice" then
        validateCountedChoice(binding, rewards, path)
    elseif binding.kind == "fixed" then
        s.onlyKeys(binding, { "constraints", "kind", "rewardType" }, path)
        nonEmptyString(binding.rewardType, path .. ".rewardType")
        if rewards.primitives.lookup[binding.rewardType] == nil then
            fail(path .. ".rewardType", "unknown reward primitive '" .. binding.rewardType .. "'")
        end
        validateConstraintKeys(rewards, binding.constraints, path .. ".constraints")
    elseif binding.kind == "shop" then
        s.onlyKeys(binding, { "kind", "shopProfileKey" }, path)
        nonEmptyString(binding.shopProfileKey, path .. ".shopProfileKey")
        if rewards.shops.profiles.lookup[binding.shopProfileKey] == nil then
            fail(path .. ".shopProfileKey", "unknown shop profile '" .. binding.shopProfileKey .. "'")
        end
    elseif binding.kind == "localSlots" then
        s.onlyKeys(binding, { "choice", "constraints", "kind", "maxSlots" }, path)
        positiveInteger(binding.maxSlots, path .. ".maxSlots")
        validateConstraintKeys(rewards, binding.constraints, path .. ".constraints")
        validateRewardBinding(binding.choice, rewards, path .. ".choice")
        if binding.choice.kind ~= "countedChoice" then
            fail(path .. ".choice.kind", "local slots require a countedChoice binding")
        end
    elseif binding.kind == "incomingKind" then
        s.onlyKeys(binding, { "kind", "kinds" }, path)
        s.list(binding.kinds, path .. ".kinds", true)
        local kindKeys = {}
        for index, incoming in ipairs(binding.kinds) do
            local incomingPath = path .. ".kinds[" .. tostring(index) .. "]"
            requiredTable(incoming, incomingPath)
            s.onlyKeys(incoming, { "key", "reward" }, incomingPath)
            nonEmptyString(incoming.key, incomingPath .. ".key")
            if kindKeys[incoming.key] then
                fail(incomingPath .. ".key", "duplicate incoming kind key '" .. incoming.key .. "'")
            end
            kindKeys[incoming.key] = true
            validateRewardBinding(incoming.reward, rewards, incomingPath .. ".reward")
            if incoming.reward.kind ~= "fixed" and incoming.reward.kind ~= "countedChoice" then
                fail(incomingPath .. ".reward.kind", "incoming kinds require fixed or countedChoice bindings")
            end
        end
    end
end

local function validateExit(exit, exitTypes, path)
    requiredTable(exit, path)
    s.onlyKeys(exit, { "index", "targetMode", "type" }, path)
    positiveInteger(exit.index, path .. ".index")
    nonEmptyString(exit.type, path .. ".type")
    if exitTypes.lookup[exit.type] == nil then
        fail(path .. ".type", "unknown physical exit type '" .. exit.type .. "'")
    end
    if exit.targetMode ~= "generated" and exit.targetMode ~= "fixedBoss" then
        fail(path .. ".targetMode", "expected 'generated' or 'fixedBoss'")
    end
end

local function validateRouteRegistries(routes, routeTemplates)
    for _, template in ipairs(routeTemplates.ordered) do
        local path = "routeTemplates." .. template.key
        s.onlyKeys(template, { "key", "kind", "semanticFields" }, path)
        if template.kind ~= "RouteControl" then
            fail(path .. ".kind", "unknown route-control kind '" .. tostring(template.kind) .. "'")
        end
        s.stringList(template.semanticFields, path .. ".semanticFields", true)
    end
    for _, route in ipairs(routes.ordered) do
        local path = "routes." .. route.key
        s.onlyKeys(route, { "key", "controlTemplateKey", "biomeSteps" }, path)
        nonEmptyString(route.controlTemplateKey, path .. ".controlTemplateKey")
        s.list(route.biomeSteps, path .. ".biomeSteps", true)
        for index, step in ipairs(route.biomeSteps) do
            local stepPath = path .. ".biomeSteps[" .. tostring(index) .. "]"
            requiredTable(step, stepPath)
            s.onlyKeys(step, { "key", "biomeKey" }, stepPath)
            nonEmptyString(step.key, stepPath .. ".key")
            nonEmptyString(step.biomeKey, stepPath .. ".biomeKey")
        end
    end
end

local function validateRoomTemplates(templates)
    for _, template in ipairs(templates.ordered) do
        local path = "roomTemplates." .. template.key
        s.onlyKeys(
            template,
            { "freeRewardSlotCapacity", "key", "roomKinds", "localChildLimit" },
            path
        )
        s.stringList(template.roomKinds, path .. ".roomKinds", true)
        positiveInteger(template.localChildLimit, path .. ".localChildLimit", true)
        if template.key == "ForkedPreboss" then
            positiveInteger(template.freeRewardSlotCapacity, path .. ".freeRewardSlotCapacity")
        elseif template.freeRewardSlotCapacity ~= nil then
            fail(path .. ".freeRewardSlotCapacity", "only ForkedPreboss owns free-reward slots")
        end
    end
end

local function biomeFreeRewardMaximum(biome)
    local maxExits = 0
    local terminalRoomKey = biome.layout.terminal.roomKey
    for _, candidate in ipairs(biome.rooms.ordered) do
        if candidate.key ~= terminalRoomKey and #candidate.exits > maxExits then
            maxExits = #candidate.exits
        end
    end
    return math.max(0, maxExits - 1)
end

local function validateEntryOfferPolicy(room, template, rewards, path)
    local policy = room.entryOfferPolicy
    local isDirect = room.templateKey == "DirectPreboss"
    local isForked = room.templateKey == "ForkedPreboss"
    if not isDirect and not isForked then
        if policy ~= nil then
            fail(path .. ".entryOfferPolicy", "only preboss templates may declare an entry-offer policy")
        end
        return
    end

    requiredTable(policy, path .. ".entryOfferPolicy")
    if room.incomingReward.kind ~= "shop" then
        fail(path .. ".incomingReward.kind", "preboss incoming reward binding must be a shop")
    end

    if isDirect then
        s.onlyKeys(policy, { "kind" }, path .. ".entryOfferPolicy")
        s.enum(policy.kind, { "shopOnly" }, path .. ".entryOfferPolicy.kind")
        return
    end

    s.onlyKeys(
        policy,
        { "freeReward", "kind", "maxFreeRewards" },
        path .. ".entryOfferPolicy"
    )
    s.enum(
        policy.kind,
        { "shopThenFillRemainingExits" },
        path .. ".entryOfferPolicy.kind"
    )
    positiveInteger(policy.maxFreeRewards, path .. ".entryOfferPolicy.maxFreeRewards")
    if policy.maxFreeRewards > template.freeRewardSlotCapacity then
        fail(
            path .. ".entryOfferPolicy.maxFreeRewards",
            "exceeds ForkedPreboss slot capacity of " .. tostring(template.freeRewardSlotCapacity)
        )
    end
    validateRewardBinding(policy.freeReward, rewards, path .. ".entryOfferPolicy.freeReward")
    if policy.freeReward.kind ~= "countedChoice" then
        fail(
            path .. ".entryOfferPolicy.freeReward.kind",
            "forked preboss free rewards require a countedChoice binding"
        )
    end
end

local function validateBatchRules(batchRules)
    for _, rule in ipairs(batchRules.ordered) do
        local path = "batchRules." .. rule.key
        s.onlyKeys(rule, { "key", "maxTargets", "picked", "stateKind" }, path)
        positiveInteger(rule.maxTargets, path .. ".maxTargets")
        s.enum(rule.picked, { "exactlyOne", "orderedSix" }, path .. ".picked")
        if rule.stateKind ~= nil then
            nonEmptyString(rule.stateKind, path .. ".stateKind")
        end
    end
end

local function validateEncounterPhase(phase, profileKind, requirements, rewards, path)
    requiredTable(phase, path)
    s.onlyKeys(phase, {
        "baselineEncounterKey", "countsEncounterDepth", "key", "kind", "offerPoint", "presence",
    }, path)
    nonEmptyString(phase.key, path .. ".key")
    s.enum(phase.kind, { "combat", "miniboss", "nonCombat", "story" }, path .. ".kind")
    requiredBoolean(phase.countsEncounterDepth, path .. ".countsEncounterDepth")
    if phase.baselineEncounterKey ~= nil then
        nonEmptyString(phase.baselineEncounterKey, path .. ".baselineEncounterKey")
    end
    if phase.presence ~= nil then
        if profileKind ~= "sequence" then
            fail(path .. ".presence", "only a sequence profile may declare phase presence")
        end
        local presencePath = path .. ".presence"
        requiredTable(phase.presence, presencePath)
        s.onlyKeys(phase.presence, { "decisionPhase", "kind", "requirement" }, presencePath)
        s.enum(phase.presence.kind, { "authoredOptional" }, presencePath .. ".kind")
        s.enum(
            phase.presence.decisionPhase,
            { "room.prepare_encounters" },
            presencePath .. ".decisionPhase"
        )
        requirementSchema.validateNode(
            phase.presence.requirement,
            requirements,
            presencePath .. ".requirement",
            phase.presence.decisionPhase
        )
    end
    if phase.offerPoint ~= nil then
        local offerPath = path .. ".offerPoint"
        requiredTable(phase.offerPoint, offerPath)
        s.onlyKeys(phase.offerPoint, {
            "acquisitionTiming", "choice", "key", "kind", "offerCount", "offerTiming", "picked",
        }, offerPath)
        s.enum(phase.offerPoint.kind, { "offerPoint" }, offerPath .. ".kind")
        nonEmptyString(phase.offerPoint.key, offerPath .. ".key")
        validateRewardBinding(phase.offerPoint.choice, rewards, offerPath .. ".choice")
        if phase.offerPoint.choice.kind ~= "countedChoice" then
            fail(offerPath .. ".choice.kind", "offer points require a countedChoice binding")
        end
        requiredTable(phase.offerPoint.offerCount, offerPath .. ".offerCount")
        s.onlyKeys(phase.offerPoint.offerCount, { "max", "min" }, offerPath .. ".offerCount")
        positiveInteger(phase.offerPoint.offerCount.min, offerPath .. ".offerCount.min")
        positiveInteger(phase.offerPoint.offerCount.max, offerPath .. ".offerCount.max")
        if phase.offerPoint.offerCount.max < phase.offerPoint.offerCount.min then
            fail(offerPath .. ".offerCount", "max must be >= min")
        end
        s.enum(phase.offerPoint.picked, { "exactlyOne" }, offerPath .. ".picked")
        s.enum(phase.offerPoint.offerTiming, { "encounterStart" }, offerPath .. ".offerTiming")
        s.enum(
            phase.offerPoint.acquisitionTiming,
            { "postCombat" },
            offerPath .. ".acquisitionTiming"
        )
    end
end

local function validateEncounterProfiles(encounterProfiles, requirements, rewards)
    for _, profile in ipairs(encounterProfiles.ordered) do
        local path = "encounterProfiles." .. profile.key
        if profile.kind ~= "fixed" and profile.kind ~= "sequence" then
            fail(path .. ".kind", "unknown encounter-profile kind '" .. tostring(profile.kind) .. "'")
        end
        s.onlyKeys(profile, { "key", "kind", "phases" }, path)
        s.list(profile.phases, path .. ".phases", profile.kind == "sequence")
        local phaseKeys = {}
        local offerPointKeys = {}
        for index, phase in ipairs(profile.phases) do
            local phasePath = path .. ".phases[" .. tostring(index) .. "]"
            validateEncounterPhase(phase, profile.kind, requirements, rewards, phasePath)
            if phaseKeys[phase.key] then
                fail(phasePath .. ".key", "duplicate phase key '" .. phase.key .. "'")
            end
            phaseKeys[phase.key] = true
            if phase.offerPoint ~= nil then
                if offerPointKeys[phase.offerPoint.key] then
                    fail(phasePath .. ".offerPoint.key", "duplicate offer-point key '" .. phase.offerPoint.key .. "'")
                end
                offerPointKeys[phase.offerPoint.key] = true
            end
        end
    end
end

local function validateAllRequirementReferences(
    biomes,
    roomTemplates,
    encounterProfiles,
    rewards,
    requirements
)
    local references = {
        biomes = biomes.lookup,
        encounterProfiles = encounterProfiles.lookup,
        rewardTypes = rewards.primitives.lookup,
        roomKinds = {},
        rooms = {},
    }
    for _, template in ipairs(roomTemplates.ordered) do
        for _, roomKind in ipairs(template.roomKinds) do
            references.roomKinds[roomKind] = true
        end
    end
    for _, biome in ipairs(biomes.ordered) do
        for _, room in ipairs(biome.rooms.ordered) do
            references.rooms[room.key] = room
        end
    end

    for key, node in pairs(requirements.named) do
        requirementSchema.validateReferences(node, requirements, references, "requirements.named." .. key)
    end
    for _, profile in ipairs(encounterProfiles.ordered) do
        for phaseIndex, phase in ipairs(profile.phases) do
            if phase.presence ~= nil then
                requirementSchema.validateReferences(
                    phase.presence.requirement,
                    requirements,
                    references,
                    "encounterProfiles." .. profile.key .. ".phases[" .. tostring(phaseIndex)
                        .. "].presence.requirement"
                )
            end
        end
    end
    for _, biome in ipairs(biomes.ordered) do
        for _, room in ipairs(biome.rooms.ordered) do
            local path = "biomes." .. biome.key .. ".rooms." .. room.key
            if room.eligibility ~= nil then
                requirementSchema.validateReferences(
                    room.eligibility,
                    requirements,
                    references,
                    path .. ".eligibility"
                )
            end
            if room.force ~= nil and room.force.requirement ~= nil then
                requirementSchema.validateReferences(
                    room.force.requirement,
                    requirements,
                    references,
                    path .. ".force.requirement"
                )
            end
        end
    end
end

local function validateExitTypes(exitTypes)
    for _, exitType in ipairs(exitTypes.ordered) do
        local path = "exitTypes." .. exitType.key
        s.onlyKeys(exitType, { "key", "constraint" }, path)
        if exitType.constraint ~= nil then
            requiredTable(exitType.constraint, path .. ".constraint")
            s.onlyKeys(exitType.constraint, { "whenSourceHasTag", "targetRequiresTag" }, path .. ".constraint")
            nonEmptyString(exitType.constraint.whenSourceHasTag, path .. ".constraint.whenSourceHasTag")
            nonEmptyString(exitType.constraint.targetRequiresTag, path .. ".constraint.targetRequiresTag")
        end
    end
end

local function candidateMatches(room, constraints)
    if constraints == nil then
        return true
    end
    if constraints.templateKey ~= nil and room.templateKey ~= constraints.templateKey then
        return false
    end
    if constraints.exitCount ~= nil and #room.exits ~= constraints.exitCount then
        return false
    end
    for _, requiredTag in ipairs(constraints.requiredTags or {}) do
        if not contains(room.tags, requiredTag) then
            return false
        end
    end
    if constraints.metadata ~= nil then
        for key, expected in pairs(constraints.metadata) do
            if room.metadata == nil or room.metadata[key] ~= expected then
                return false
            end
        end
    end
    return true
end

local function maximumMatching(slots, rooms, requirements, constraints, excludedKinds, path)
    local roomForSlot = {}
    local function assign(slotIndex, visited)
        local slot = slots[slotIndex]
        for roomIndex, room in ipairs(rooms) do
            local compatible = requirementSchema.staticCompatibility(
                room.eligibility,
                requirements,
                slot,
                excludedKinds,
                path .. ".candidate(" .. room.key .. ").eligibility"
            )
            if not visited[roomIndex] and compatible ~= false and candidateMatches(room, constraints) then
                visited[roomIndex] = true
                if roomForSlot[roomIndex] == nil or assign(roomForSlot[roomIndex], visited) then
                    roomForSlot[roomIndex] = slotIndex
                    return true
                end
            end
        end
        return false
    end
    local matched = 0
    for slotIndex = 1, #slots do
        if assign(slotIndex, {}) then
            matched = matched + 1
        end
    end
    return matched
end

local function validateCapacity(biome, roomsByFamily, requirements, path)
    local audits = {}
    local proofs = biome.canonicalCapacity or {}
    s.list(proofs, path .. ".canonicalCapacity", false)
    local provedFamilies = {}
    for proofIndex, proof in ipairs(proofs) do
        local proofPath = path .. ".canonicalCapacity[" .. tostring(proofIndex) .. "]"
        requiredTable(proof, proofPath)
        s.onlyKeys(proof, { "candidateConstraints", "contexts", "familyKey" }, proofPath)
        nonEmptyString(proof.familyKey, proofPath .. ".familyKey")
        if provedFamilies[proof.familyKey] then
            fail(proofPath .. ".familyKey", "duplicate capacity proof for canonical family '" .. proof.familyKey .. "'")
        end
        provedFamilies[proof.familyKey] = true
        local candidates = roomsByFamily[proof.familyKey]
        if candidates == nil or #candidates == 0 then
            fail(proofPath .. ".familyKey", "unknown canonical family '" .. proof.familyKey .. "'")
        end
        if proof.candidateConstraints ~= nil then
            requiredTable(proof.candidateConstraints, proofPath .. ".candidateConstraints")
            s.onlyKeys(
                proof.candidateConstraints,
                { "exitCount", "metadata", "requiredTags", "templateKey" },
                proofPath .. ".candidateConstraints"
            )
            if proof.candidateConstraints.templateKey ~= nil then
                nonEmptyString(proof.candidateConstraints.templateKey, proofPath .. ".candidateConstraints.templateKey")
            end
            if proof.candidateConstraints.exitCount ~= nil then
                positiveInteger(proof.candidateConstraints.exitCount, proofPath .. ".candidateConstraints.exitCount")
            end
            if proof.candidateConstraints.requiredTags ~= nil then
                s.stringList(proof.candidateConstraints.requiredTags, proofPath .. ".candidateConstraints.requiredTags", true)
            end
            if proof.candidateConstraints.metadata ~= nil then
                requiredTable(proof.candidateConstraints.metadata, proofPath .. ".candidateConstraints.metadata")
            end
        end
        local slots = {}
        s.list(proof.contexts, proofPath .. ".contexts", true)
        for contextIndex, context in ipairs(proof.contexts or {}) do
            local contextPath = proofPath .. ".contexts[" .. tostring(contextIndex) .. "]"
            requiredTable(context, contextPath)
            s.onlyKeys(context, { "biomeDepthCache", "biomeEncounterDepth", "count" }, contextPath)
            positiveInteger(context.count, contextPath .. ".count")
            if context.biomeDepthCache ~= nil then
                positiveInteger(context.biomeDepthCache, contextPath .. ".biomeDepthCache", true)
            end
            if context.biomeEncounterDepth ~= nil then
                positiveInteger(context.biomeEncounterDepth, contextPath .. ".biomeEncounterDepth", true)
            end
            for _ = 1, context.count do
                slots[#slots + 1] = copy(context)
            end
        end
        local excludedKinds = {}
        local matched = maximumMatching(
            slots,
            candidates,
            requirements,
            proof.candidateConstraints,
            excludedKinds,
            proofPath
        )
        if matched ~= #slots then
            fail(proofPath, "compatible matching covers " .. tostring(matched) .. " of " .. tostring(#slots) .. " maximum-demand slots")
        end
        local excludedDynamicKinds = {}
        for kind in pairs(excludedKinds) do
            excludedDynamicKinds[#excludedDynamicKinds + 1] = kind
        end
        table.sort(excludedDynamicKinds)
        audits[#audits + 1] = {
            scope = "static",
            familyKey = proof.familyKey,
            demand = #slots,
            candidateCount = #candidates,
            matched = matched,
            excludedDynamicKinds = excludedDynamicKinds,
        }
    end
    for familyKey in pairs(roomsByFamily) do
        if not provedFamilies[familyKey] then
            fail(path .. ".canonicalCapacity", "missing capacity proof for canonical family '" .. familyKey .. "'")
        end
    end
    return audits
end

local function validatePositiveIntegerList(values, path)
    local length = s.list(values, path, true)
    local seen = {}
    for index = 1, length do
        local value = values[index]
        positiveInteger(value, path .. "[" .. tostring(index) .. "]")
        if seen[value] then
            fail(path .. "[" .. tostring(index) .. "]", "duplicate value '" .. tostring(value) .. "'")
        end
        seen[value] = true
    end
end

local function validateAuthoredValue(state, authored, path)
    requiredTable(state, path)
    s.onlyKeys(state, { "authored", "value" }, path)
    requiredBoolean(state.authored, path .. ".authored")
    if state.authored ~= authored then
        fail(path .. ".authored", "expected " .. tostring(authored))
    end
    positiveInteger(state.value, path .. ".value")
end

local function validateAuthoredValues(state, path)
    requiredTable(state, path)
    s.onlyKeys(state, { "authored", "values" }, path)
    requiredBoolean(state.authored, path .. ".authored")
    if not state.authored then
        fail(path .. ".authored", "expected true")
    end
    validatePositiveIntegerList(state.values, path .. ".values")
end

local function validateBiomeState(biome, path)
    if biome.key == "H" then
        requiredTable(biome.biomeState, path .. ".biomeState")
        s.onlyKeys(biome.biomeState, { "fieldsMaxDoorsRolled" }, path .. ".biomeState")
        local state = biome.biomeState.fieldsMaxDoorsRolled
        local statePath = path .. ".biomeState.fieldsMaxDoorsRolled"
        requiredTable(state, statePath)
        s.onlyKeys(state, { "derived", "max", "min" }, statePath)
        requiredBoolean(state.derived, statePath .. ".derived")
        if not state.derived then
            fail(statePath .. ".derived", "expected true")
        end
        positiveInteger(state.min, statePath .. ".min", true)
        positiveInteger(state.max, statePath .. ".max", true)
        if state.max < state.min then
            fail(statePath, "max must be >= min")
        end
    elseif biome.key == "I" then
        requiredTable(biome.biomeState, path .. ".biomeState")
        s.onlyKeys(biome.biomeState, { "initialGoals", "maxNonGoalRewards" }, path .. ".biomeState")
        validateAuthoredValue(biome.biomeState.initialGoals, false, path .. ".biomeState.initialGoals")
        validateAuthoredValues(biome.biomeState.maxNonGoalRewards, path .. ".biomeState.maxNonGoalRewards")
    elseif biome.key == "N" then
        requiredTable(biome.biomeState, path .. ".biomeState")
        s.onlyKeys(biome.biomeState, { "hubDoorCount", "visitedTargetCount" }, path .. ".biomeState")
        validateAuthoredValues(biome.biomeState.hubDoorCount, path .. ".biomeState.hubDoorCount")
        validateAuthoredValue(biome.biomeState.visitedTargetCount, false, path .. ".biomeState.visitedTargetCount")
    elseif biome.biomeState ~= nil then
        fail(path .. ".biomeState", "biome does not declare specialized state")
    end
end

local function validateRoomMetadata(biome, room, hubDoorIds, path)
    if biome.key == "H" and room.templateKey == "FieldsCombat" then
        requiredTable(room.metadata, path .. ".metadata")
        s.onlyKeys(room.metadata, { "effectiveMaxCageRewards", "maxCageRewards" }, path .. ".metadata")
        positiveInteger(room.metadata.effectiveMaxCageRewards, path .. ".metadata.effectiveMaxCageRewards")
        positiveInteger(room.metadata.maxCageRewards, path .. ".metadata.maxCageRewards")
        if room.metadata.effectiveMaxCageRewards > room.metadata.maxCageRewards then
            fail(path .. ".metadata", "effective cage-reward maximum must not exceed physical maximum")
        end
    elseif biome.key == "N" and room.key == "N_Hub" then
        requiredTable(room.metadata, path .. ".metadata")
        s.onlyKeys(room.metadata, { "availableDoorCount", "physicalDoorKind" }, path .. ".metadata")
        local doorCount = room.metadata.availableDoorCount
        local doorCountPath = path .. ".metadata.availableDoorCount"
        requiredTable(doorCount, doorCountPath)
        s.onlyKeys(doorCount, { "max", "min" }, doorCountPath)
        positiveInteger(doorCount.min, doorCountPath .. ".min")
        positiveInteger(doorCount.max, doorCountPath .. ".max")
        if doorCount.max < doorCount.min then
            fail(doorCountPath, "max must be >= min")
        end
        nonEmptyString(room.metadata.physicalDoorKind, path .. ".metadata.physicalDoorKind")
    elseif biome.key == "N" and (
        room.templateKey == "EphyraCombat" or room.kind == "Miniboss" or room.kind == "Story"
    ) then
        requiredTable(room.metadata, path .. ".metadata")
        s.onlyKeys(room.metadata, { "hubDoorId" }, path .. ".metadata")
        positiveInteger(room.metadata.hubDoorId, path .. ".metadata.hubDoorId")
        if hubDoorIds[room.metadata.hubDoorId] ~= nil then
            fail(
                path .. ".metadata.hubDoorId",
                "duplicate physical hub door id also used by '" .. hubDoorIds[room.metadata.hubDoorId] .. "'"
            )
        end
        hubDoorIds[room.metadata.hubDoorId] = room.key
    elseif room.metadata ~= nil then
        fail(path .. ".metadata", "room does not declare specialized metadata")
    end
end

local function validateLayoutShape(biome, batchRules, path)
    local layoutPath = path .. ".layout"
    requiredTable(biome.layout, layoutPath)
    s.enum(biome.layout.kind, { "LinearBiome", "HubBiome" }, layoutPath .. ".kind")

    requiredTable(biome.layout.bounds, layoutPath .. ".bounds")
    s.onlyKeys(
        biome.layout.bounds,
        { "maxBatches", "maxTargets" },
        layoutPath .. ".bounds"
    )
    positiveInteger(biome.layout.bounds.maxBatches, layoutPath .. ".bounds.maxBatches")
    positiveInteger(biome.layout.bounds.maxTargets, layoutPath .. ".bounds.maxTargets")

    requiredTable(biome.layout.terminal, layoutPath .. ".terminal")
    s.onlyKeys(
        biome.layout.terminal,
        { "exitPolicy", "roomKey", "transitionRuleKey" },
        layoutPath .. ".terminal"
    )
    nonEmptyString(biome.layout.terminal.roomKey, layoutPath .. ".terminal.roomKey")
    s.enum(
        biome.layout.terminal.transitionRuleKey,
        { "PrebossEntry" },
        layoutPath .. ".terminal.transitionRuleKey"
    )
    requiredTable(biome.layout.terminal.exitPolicy, layoutPath .. ".terminal.exitPolicy")
    local policy = biome.layout.terminal.exitPolicy
    s.enum(
        policy.kind,
        { "allExitsTerminal", "singleTerminal", "terminalWithCompanions" },
        layoutPath .. ".terminal.exitPolicy.kind"
    )
    if policy.kind == "terminalWithCompanions" then
        s.onlyKeys(
            policy,
            { "companionBatchRuleKey", "kind" },
            layoutPath .. ".terminal.exitPolicy"
        )
        nonEmptyString(
            policy.companionBatchRuleKey,
            layoutPath .. ".terminal.exitPolicy.companionBatchRuleKey"
        )
        if batchRules.lookup[policy.companionBatchRuleKey] == nil then
            fail(
                layoutPath .. ".terminal.exitPolicy.companionBatchRuleKey",
                "unknown batch rule '" .. policy.companionBatchRuleKey .. "'"
            )
        end
    else
        s.onlyKeys(policy, { "kind" }, layoutPath .. ".terminal.exitPolicy")
    end

    if biome.layout.kind == "LinearBiome" then
        s.onlyKeys(
            biome.layout,
            { "bounds", "continuation", "kind", "start", "terminal" },
            layoutPath
        )
        requiredTable(biome.layout.start, layoutPath .. ".start")
        s.onlyKeys(biome.layout.start, { "mode", "roomKeys" }, layoutPath .. ".start")
        s.enum(biome.layout.start.mode, { "fixed", "oneOf" }, layoutPath .. ".start.mode")
        s.stringList(biome.layout.start.roomKeys, layoutPath .. ".start.roomKeys", true)
        if biome.layout.start.mode == "fixed" and #biome.layout.start.roomKeys ~= 1 then
            fail(layoutPath .. ".start.roomKeys", "fixed start must contain exactly one room")
        end

        requiredTable(biome.layout.continuation, layoutPath .. ".continuation")
        s.onlyKeys(
            biome.layout.continuation,
            { "defaultBatchRuleKey", "overrides" },
            layoutPath .. ".continuation"
        )
        nonEmptyString(
            biome.layout.continuation.defaultBatchRuleKey,
            layoutPath .. ".continuation.defaultBatchRuleKey"
        )
        if batchRules.lookup[biome.layout.continuation.defaultBatchRuleKey] == nil then
            fail(
                layoutPath .. ".continuation.defaultBatchRuleKey",
                "unknown batch rule '" .. biome.layout.continuation.defaultBatchRuleKey .. "'"
            )
        end
        s.list(biome.layout.continuation.overrides, layoutPath .. ".continuation.overrides", false)
        local overrideKeys = {}
        local claimedParents = {}
        for overrideIndex, override in ipairs(biome.layout.continuation.overrides) do
            local overridePath = layoutPath .. ".continuation.overrides["
                .. tostring(overrideIndex) .. "]"
            requiredTable(override, overridePath)
            s.onlyKeys(
                override,
                { "batchRuleKey", "key", "targetRoomKeys", "when" },
                overridePath
            )
            nonEmptyString(override.key, overridePath .. ".key")
            if overrideKeys[override.key] then
                fail(overridePath .. ".key", "duplicate override key '" .. override.key .. "'")
            end
            overrideKeys[override.key] = true
            requiredTable(override.when, overridePath .. ".when")
            s.onlyKeys(override.when, { "parentRoomKeys" }, overridePath .. ".when")
            s.stringList(override.when.parentRoomKeys, overridePath .. ".when.parentRoomKeys", true)
            for parentIndex, parentRoomKey in ipairs(override.when.parentRoomKeys) do
                if claimedParents[parentRoomKey] ~= nil then
                    fail(
                        overridePath .. ".when.parentRoomKeys[" .. tostring(parentIndex) .. "]",
                        "overlaps override '" .. claimedParents[parentRoomKey] .. "'"
                    )
                end
                claimedParents[parentRoomKey] = override.key
            end
            nonEmptyString(override.batchRuleKey, overridePath .. ".batchRuleKey")
            local batchRule = batchRules.lookup[override.batchRuleKey]
            if batchRule == nil then
                fail(
                    overridePath .. ".batchRuleKey",
                    "unknown batch rule '" .. override.batchRuleKey .. "'"
                )
            end
            s.stringList(override.targetRoomKeys, overridePath .. ".targetRoomKeys", true)
            if #override.targetRoomKeys > batchRule.maxTargets then
                fail(overridePath .. ".targetRoomKeys", "exceeds batch-rule target capacity")
            end
        end
    else
        s.onlyKeys(
            biome.layout,
            { "bounds", "entry", "hub", "kind", "terminal" },
            layoutPath
        )
        requiredTable(biome.layout.entry, layoutPath .. ".entry")
        s.onlyKeys(biome.layout.entry, { "mode", "roomKeys" }, layoutPath .. ".entry")
        s.enum(biome.layout.entry.mode, { "fixedSequence" }, layoutPath .. ".entry.mode")
        s.stringList(biome.layout.entry.roomKeys, layoutPath .. ".entry.roomKeys", true)
        requiredTable(biome.layout.hub, layoutPath .. ".hub")
        s.onlyKeys(
            biome.layout.hub,
            { "batchRuleKey", "doorCountStateKey", "roomKey", "visitedTargetCount" },
            layoutPath .. ".hub"
        )
        nonEmptyString(biome.layout.hub.roomKey, layoutPath .. ".hub.roomKey")
        nonEmptyString(biome.layout.hub.batchRuleKey, layoutPath .. ".hub.batchRuleKey")
        if batchRules.lookup[biome.layout.hub.batchRuleKey] == nil then
            fail(
                layoutPath .. ".hub.batchRuleKey",
                "unknown batch rule '" .. biome.layout.hub.batchRuleKey .. "'"
            )
        end
        nonEmptyString(
            biome.layout.hub.doorCountStateKey,
            layoutPath .. ".hub.doorCountStateKey"
        )
        positiveInteger(
            biome.layout.hub.visitedTargetCount,
            layoutPath .. ".hub.visitedTargetCount"
        )
        if biome.layout.bounds.maxBatches ~= 1 then
            fail(layoutPath .. ".bounds.maxBatches", "HubBiome owns exactly one persistent batch")
        end
    end
end

local function addRoomRole(roles, roomKey, role, path)
    local roomRoles = roles.lookup[roomKey]
    if roomRoles == nil then
        roomRoles = {}
        roles.lookup[roomKey] = roomRoles
    end
    if roomRoles[role] then
        fail(path, "duplicate room role '" .. role .. "'")
    end
    roomRoles[role] = true
end

local function exactForceDepth(room)
    if room.force == nil or room.force.kind ~= "depthWindow"
        or room.force.axis ~= "biomeDepthCache"
        or room.force.start ~= room.force.deadline
    then
        return nil
    end
    return room.force.start
end

local function validateQMinibossOverride(biome, override, overridePath)
    local targetDepth
    for targetIndex, targetRoomKey in ipairs(override.targetRoomKeys) do
        local targetPath = overridePath .. ".targetRoomKeys[" .. tostring(targetIndex) .. "]"
        local target = biome.rooms.lookup[targetRoomKey]
        if target.kind ~= "Miniboss" then
            fail(targetPath, "QMinibossBatch target must be a Miniboss")
        end
        local depth = exactForceDepth(target)
        if depth == nil or target.eligibility == nil
            or target.eligibility.kind ~= "CounterRange"
            or target.eligibility.axis ~= "biomeDepthCache"
            or target.eligibility.range.exact ~= depth
        then
            fail(targetPath, "QMinibossBatch target must be forced and eligible at one exact depth")
        end
        if targetDepth ~= nil and targetDepth ~= depth then
            fail(targetPath, "QMinibossBatch targets must share one exact depth")
        end
        targetDepth = depth
    end
    if #override.targetRoomKeys ~= 2 then
        fail(overridePath .. ".targetRoomKeys", "QMinibossBatch requires exactly two targets")
    end
    for parentIndex, parentRoomKey in ipairs(override.when.parentRoomKeys) do
        local parentPath = overridePath .. ".when.parentRoomKeys[" .. tostring(parentIndex) .. "]"
        local parent = biome.rooms.lookup[parentRoomKey]
        if #parent.exits ~= #override.targetRoomKeys then
            fail(parentPath, "override parent exits must match the exact target set")
        end
        if exactForceDepth(parent) ~= targetDepth - 1 then
            fail(parentPath, "QMinibossBatch parent must be forced one depth before its targets")
        end
    end
end

local function validateLayoutReferences(biome, path)
    local layout = biome.layout
    local layoutPath = path .. ".layout"
    local roles = {
        starts = {},
        fixedEntries = {},
        lookup = {},
        terminalRoomKey = layout.terminal.roomKey,
    }
    if layout.kind == "LinearBiome" then
        for index, roomKey in ipairs(layout.start.roomKeys) do
            if biome.rooms.lookup[roomKey] == nil then
                fail(layoutPath .. ".start.roomKeys[" .. tostring(index) .. "]", "unknown start room '" .. roomKey .. "'")
            end
            roles.starts[#roles.starts + 1] = roomKey
            addRoomRole(roles, roomKey, "start", layoutPath .. ".start.roomKeys[" .. tostring(index) .. "]")
        end
        for overrideIndex, override in ipairs(layout.continuation.overrides) do
            local overridePath = layoutPath .. ".continuation.overrides["
                .. tostring(overrideIndex) .. "]"
            for parentIndex, roomKey in ipairs(override.when.parentRoomKeys) do
                if biome.rooms.lookup[roomKey] == nil then
                    fail(
                        overridePath .. ".when.parentRoomKeys[" .. tostring(parentIndex) .. "]",
                        "unknown override parent room '" .. roomKey .. "'"
                    )
                end
            end
            for targetIndex, roomKey in ipairs(override.targetRoomKeys) do
                if biome.rooms.lookup[roomKey] == nil then
                    fail(
                        overridePath .. ".targetRoomKeys[" .. tostring(targetIndex) .. "]",
                        "unknown override target room '" .. roomKey .. "'"
                    )
                end
            end
            if override.batchRuleKey == "QMinibossBatch" then
                validateQMinibossOverride(biome, override, overridePath)
            end
        end
    else
        for index, roomKey in ipairs(layout.entry.roomKeys) do
            if biome.rooms.lookup[roomKey] == nil then
                fail(layoutPath .. ".entry.roomKeys[" .. tostring(index) .. "]", "unknown entry room '" .. roomKey .. "'")
            end
            roles.fixedEntries[#roles.fixedEntries + 1] = roomKey
            addRoomRole(
                roles,
                roomKey,
                "fixedEntry",
                layoutPath .. ".entry.roomKeys[" .. tostring(index) .. "]"
            )
        end
        if biome.rooms.lookup[layout.hub.roomKey] == nil then
            fail(layoutPath .. ".hub.roomKey", "unknown hub room '" .. layout.hub.roomKey .. "'")
        end
        if not contains(layout.entry.roomKeys, layout.hub.roomKey) then
            fail(layoutPath .. ".hub.roomKey", "hub room must belong to the fixed entry sequence")
        end
        roles.hubRoomKey = layout.hub.roomKey
        addRoomRole(roles, layout.hub.roomKey, "hub", layoutPath .. ".hub.roomKey")
        local doorState = biome.biomeState[layout.hub.doorCountStateKey]
        if doorState == nil or doorState.authored ~= true then
            fail(layoutPath .. ".hub.doorCountStateKey", "must reference authored biome state")
        end
        if biome.biomeState.visitedTargetCount.value ~= layout.hub.visitedTargetCount then
            fail(layoutPath .. ".hub.visitedTargetCount", "must match fixed biome state")
        end
    end

    local terminal = biome.rooms.lookup[layout.terminal.roomKey]
    if terminal == nil then
        fail(layoutPath .. ".terminal.roomKey", "unknown terminal room '" .. layout.terminal.roomKey .. "'")
    end
    if terminal.kind ~= "Preboss" then
        fail(layoutPath .. ".terminal.roomKey", "terminal room must be a preboss")
    end
    addRoomRole(roles, terminal.key, "terminal", layoutPath .. ".terminal.roomKey")

    local topologyMaximum = biomeFreeRewardMaximum(biome)
    local policyKind = layout.terminal.exitPolicy.kind
    local entryPolicyKind = terminal.entryOfferPolicy.kind
    if policyKind == "allExitsTerminal" then
        if entryPolicyKind ~= "shopThenFillRemainingExits" then
            fail(layoutPath .. ".terminal.exitPolicy.kind", "requires shopThenFillRemainingExits")
        end
        if terminal.entryOfferPolicy.maxFreeRewards ~= topologyMaximum then
            fail(
                layoutPath .. ".terminal.roomKey",
                "terminal free-reward capacity must match predecessor maximum of "
                    .. tostring(topologyMaximum)
            )
        end
        layout.terminal.maxCompanionTargets = 0
    elseif policyKind == "terminalWithCompanions" then
        if entryPolicyKind ~= "shopOnly" then
            fail(layoutPath .. ".terminal.exitPolicy.kind", "requires shopOnly")
        end
        layout.terminal.maxCompanionTargets = topologyMaximum
    else
        if entryPolicyKind ~= "shopOnly" then
            fail(layoutPath .. ".terminal.exitPolicy.kind", "requires shopOnly")
        end
        layout.terminal.maxCompanionTargets = 0
    end
    biome.roomRoles = roles
end

local function validateSpecializedBiomeConsistency(biome, path)
    if biome.key ~= "N" then
        return
    end
    local hub = biome.rooms.lookup.N_Hub
    local available = hub.metadata.availableDoorCount
    for index, value in ipairs(biome.biomeState.hubDoorCount.values) do
        if value < available.min or value > available.max then
            fail(
                path .. ".biomeState.hubDoorCount.values[" .. tostring(index) .. "]",
                "hub door count is outside N_Hub's available-door range"
            )
        end
    end
    if biome.biomeState.visitedTargetCount.value > available.min then
        fail(path .. ".biomeState.visitedTargetCount.value", "visited targets exceed the minimum available hub doors")
    end
    if available.max > biome.layout.bounds.maxTargets then
        fail(path .. ".layout.bounds.maxTargets", "cannot contain N_Hub's maximum available door count")
    end
end

local function validateBiomes(
    rawBiomes,
    routes,
    routeTemplates,
    templates,
    batchRules,
    encounterProfiles,
    exitTypes,
    rewards,
    requirements
)
    local biomes = orderedCatalog(rawBiomes, "biomes")
    local globalRoomKeys = {}
    for biomeIndex, biome in ipairs(biomes.ordered) do
        local path = "biomes[" .. tostring(biomeIndex) .. "]"
        s.onlyKeys(biome, {
            "biomeState", "biomeStepKey", "canonicalCapacity", "combatAppearancePolicy",
            "key", "label", "layout", "rooms", "routeKey",
        }, path)
        nonEmptyString(biome.label, path .. ".label")
        nonEmptyString(biome.routeKey, path .. ".routeKey")
        nonEmptyString(biome.biomeStepKey, path .. ".biomeStepKey")
        if biome.combatAppearancePolicy ~= nil then
            s.enum(
                biome.combatAppearancePolicy,
                { "physicalHubDoorUnique" },
                path .. ".combatAppearancePolicy"
            )
        end
        validateBiomeState(biome, path)
        if routes.lookup[biome.routeKey] == nil then
            fail(path .. ".routeKey", "unknown route '" .. biome.routeKey .. "'")
        end
        validateLayoutShape(biome, batchRules, path)

        biome.rooms = orderedCatalog(biome.rooms, path .. ".rooms")
        local roomsByFamily = {}
        local hubDoorIds = {}
        for roomIndex, room in ipairs(biome.rooms.ordered) do
            local roomPath = path .. ".rooms[" .. tostring(roomIndex) .. "]"
            s.onlyKeys(room, {
                "canonicalFamily", "caps", "counters", "eligibility", "encounterProfileKey", "exits",
                "entryOfferPolicy", "force", "incomingReward", "key", "kind", "localChildren", "metadata",
                "tags", "templateKey",
            }, roomPath)
            if string.sub(room.key, 1, 2) ~= biome.key .. "_" then
                fail(roomPath .. ".key", "room key must be scoped by biome prefix '" .. biome.key .. "_'")
            end
            if globalRoomKeys[room.key] ~= nil then
                fail(roomPath .. ".key", "duplicate game room key '" .. room.key .. "'")
            end
            globalRoomKeys[room.key] = true
            nonEmptyString(room.kind, roomPath .. ".kind")
            nonEmptyString(room.templateKey, roomPath .. ".templateKey")
            requiredTable(room.tags, roomPath .. ".tags")
            s.stringList(room.tags, roomPath .. ".tags", false)
            requiredTable(room.exits, roomPath .. ".exits")
            validateRewardBinding(room.incomingReward, rewards, roomPath .. ".incomingReward")
            nonEmptyString(room.encounterProfileKey, roomPath .. ".encounterProfileKey")
            requiredTable(room.counters, roomPath .. ".counters")
            positiveInteger(room.counters.roomHistoryOrdinal, roomPath .. ".counters.roomHistoryOrdinal", true)
            positiveInteger(room.counters.biomeDepthCache, roomPath .. ".counters.biomeDepthCache", true)
            s.onlyKeys(room.counters, { "biomeDepthCache", "roomHistoryOrdinal" }, roomPath .. ".counters")
            requiredTable(room.caps, roomPath .. ".caps")
            s.onlyKeys(room.caps, {
                "maxAppearancesThisBiome", "maxCreationsPerRoom", "maxCreationsThisRun",
            }, roomPath .. ".caps")
            requiredTable(room.localChildren, roomPath .. ".localChildren")
            local template = templates.lookup[room.templateKey]
            if template == nil then
                fail(roomPath .. ".templateKey", "unknown room template '" .. tostring(room.templateKey) .. "'")
            end
            if not contains(template.roomKinds, room.kind) then
                fail(roomPath .. ".templateKey", "template '" .. room.templateKey .. "' does not accept room kind '" .. room.kind .. "'")
            end
            validateEntryOfferPolicy(room, template, rewards, roomPath)
            local encounterProfile = encounterProfiles.lookup[room.encounterProfileKey]
            if encounterProfile == nil then
                fail(roomPath .. ".encounterProfileKey", "unknown encounter profile '" .. tostring(room.encounterProfileKey) .. "'")
            end
            for exitIndex, exit in ipairs(room.exits) do
                validateExit(exit, exitTypes, roomPath .. ".exits[" .. tostring(exitIndex) .. "]")
                if exit.index ~= exitIndex then
                    fail(roomPath .. ".exits[" .. tostring(exitIndex) .. "].index", "exit indexes must preserve generation order")
                end
            end
            if room.kind == "Combat" then
                local hubUnique = biome.combatAppearancePolicy == "physicalHubDoorUnique"
                if not hubUnique and room.caps.maxAppearancesThisBiome ~= 1 then
                    fail(roomPath .. ".caps.maxAppearancesThisBiome", "supported combat rooms must retain the vanilla appearance cap of 1")
                end
                if hubUnique and room.caps.maxAppearancesThisBiome ~= nil then
                    fail(roomPath .. ".caps.maxAppearancesThisBiome", "hub-door-unique combat rooms must not invent an appearance cap")
                end
                if room.caps.maxCreationsThisRun ~= nil then
                    fail(roomPath .. ".caps.maxCreationsThisRun", "ordinary combat canonicalization must not be encoded as a creation cap")
                end
            end
            if room.caps.maxCreationsThisRun ~= nil then
                positiveInteger(room.caps.maxCreationsThisRun, roomPath .. ".caps.maxCreationsThisRun")
            end
            if room.caps.maxAppearancesThisBiome ~= nil then
                positiveInteger(room.caps.maxAppearancesThisBiome, roomPath .. ".caps.maxAppearancesThisBiome")
            end
            if room.caps.maxCreationsPerRoom ~= nil then
                positiveInteger(room.caps.maxCreationsPerRoom, roomPath .. ".caps.maxCreationsPerRoom")
            end
            if room.eligibility ~= nil then
                requirementSchema.validateNode(
                    room.eligibility,
                    requirements,
                    roomPath .. ".eligibility",
                    "room.generate_next"
                )
            end
            if room.force ~= nil then
                nonEmptyString(room.force.kind, roomPath .. ".force.kind")
                if room.force.kind == "depthWindow" then
                    s.onlyKeys(room.force, { "axis", "deadline", "kind", "start" }, roomPath .. ".force")
                    s.enum(room.force.axis, { "biomeDepthCache" }, roomPath .. ".force.axis")
                    positiveInteger(room.force.start, roomPath .. ".force.start", true)
                    positiveInteger(room.force.deadline, roomPath .. ".force.deadline", true)
                    if room.force.deadline < room.force.start then
                        fail(roomPath .. ".force", "deadline must be >= start")
                    end
                elseif room.force.kind == "requirement" then
                    s.onlyKeys(room.force, { "kind", "requirement" }, roomPath .. ".force")
                    requirementSchema.validateNode(
                        room.force.requirement,
                        requirements,
                        roomPath .. ".force.requirement",
                        "room.generate_next"
                    )
                elseif room.force.kind ~= "always" then
                    fail(roomPath .. ".force.kind", "unknown force kind '" .. room.force.kind .. "'")
                else
                    s.onlyKeys(room.force, { "kind" }, roomPath .. ".force")
                end
            end
            if room.canonicalFamily ~= nil then
                nonEmptyString(room.canonicalFamily, roomPath .. ".canonicalFamily")
            end
            validateRoomMetadata(biome, room, hubDoorIds, roomPath)
            local localSlotCount = #room.localChildren
            local childKeys = {}
            for phaseIndex, phase in ipairs(encounterProfile.phases) do
                if phase.offerPoint ~= nil then
                    local offerPath = roomPath .. ".encounterProfile.phases[" .. tostring(phaseIndex) .. "].offerPoint"
                    if childKeys[phase.offerPoint.key] then
                        fail(offerPath .. ".key", "duplicate room-local slot key '" .. phase.offerPoint.key .. "'")
                    end
                    childKeys[phase.offerPoint.key] = true
                    localSlotCount = localSlotCount + 1
                end
            end
            if localSlotCount > template.localChildLimit then
                fail(roomPath .. ".localChildren", "template limit is " .. tostring(template.localChildLimit))
            end
            for childIndex, child in ipairs(room.localChildren) do
                local childPath = roomPath .. ".localChildren[" .. tostring(childIndex) .. "]"
                requiredTable(child, childPath)
                nonEmptyString(child.key, childPath .. ".key")
                if childKeys[child.key] then
                    fail(childPath .. ".key", "duplicate local child key '" .. child.key .. "'")
                end
                childKeys[child.key] = true
                s.enum(child.kind, { "reward", "sideRoom" }, childPath .. ".kind")
                positiveInteger(child.ordinal, childPath .. ".ordinal")
                if child.ordinal ~= childIndex then
                    fail(childPath .. ".ordinal", "must preserve local-child order")
                end
                if child.kind == "reward" then
                    s.onlyKeys(child, { "key", "kind", "ordinal" }, childPath)
                elseif child.kind == "sideRoom" then
                    s.onlyKeys(child, {
                        "doorId", "gameRoomKey", "key", "kind", "ordinal", "reward",
                    }, childPath)
                    positiveInteger(child.doorId, childPath .. ".doorId")
                    nonEmptyString(child.gameRoomKey, childPath .. ".gameRoomKey")
                    validateRewardBinding(child.reward, rewards, childPath .. ".reward")
                    if child.reward.kind ~= "countedChoice" then
                        fail(childPath .. ".reward.kind", "side rooms require a countedChoice binding")
                    end
                end
            end
            if room.incomingReward.kind == "localSlots" then
                if #room.localChildren == 0 then
                    fail(roomPath .. ".localChildren", "localSlots reward requires declared reward children")
                end
                if #room.localChildren > room.incomingReward.maxSlots then
                    fail(roomPath .. ".localChildren", "exceeds reward binding maxSlots")
                end
                for childIndex, child in ipairs(room.localChildren) do
                    if child.kind ~= "reward" then
                        fail(
                            roomPath .. ".localChildren[" .. tostring(childIndex) .. "].kind",
                            "localSlots reward requires reward children"
                        )
                    end
                end
            else
                for childIndex, child in ipairs(room.localChildren) do
                    if child.kind == "reward" then
                        fail(
                            roomPath .. ".localChildren[" .. tostring(childIndex) .. "].kind",
                            "reward child requires a localSlots incoming room binding"
                        )
                    end
                end
            end
            if room.canonicalFamily ~= nil then
                roomsByFamily[room.canonicalFamily] = roomsByFamily[room.canonicalFamily] or {}
                roomsByFamily[room.canonicalFamily][#roomsByFamily[room.canonicalFamily] + 1] = room
            end
        end

        validateLayoutReferences(biome, path)
        validateSpecializedBiomeConsistency(biome, path)
        biome.capacityAudit = validateCapacity(biome, roomsByFamily, requirements, path)
    end

    local stepKeys = {}
    local routedBiomes = {}
    for _, route in ipairs(routes.ordered) do
        if routeTemplates.lookup[route.controlTemplateKey] == nil then
            fail("routes." .. route.key .. ".controlTemplateKey", "unknown route-control template '" .. tostring(route.controlTemplateKey) .. "'")
        end
        for stepIndex, step in ipairs(route.biomeSteps or {}) do
            local path = "routes." .. route.key .. ".biomeSteps[" .. tostring(stepIndex) .. "]"
            nonEmptyString(step.key, path .. ".key")
            nonEmptyString(step.biomeKey, path .. ".biomeKey")
            if stepKeys[step.key] then
                fail(path .. ".key", "duplicate biome-step key '" .. step.key .. "'")
            end
            stepKeys[step.key] = true
            local biome = biomes.lookup[step.biomeKey]
            if biome == nil then
                fail(path .. ".biomeKey", "unknown biome '" .. step.biomeKey .. "'")
            end
            if biome.routeKey ~= route.key or biome.biomeStepKey ~= step.key then
                fail(path, "biome route/step ownership does not match declaration")
            end
            if routedBiomes[step.biomeKey] then
                fail(path .. ".biomeKey", "biome is already owned by another route step")
            end
            routedBiomes[step.biomeKey] = true
        end
    end
    for _, biome in ipairs(biomes.ordered) do
        if not routedBiomes[biome.key] then
            fail("biomes." .. biome.key, "biome is not owned by a route step")
        end
    end
    return biomes
end

function validator.validate(raw)
    requiredTable(raw, "catalog")
    s.onlyKeys(raw, {
        "batchRules", "biomes", "encounterProfiles", "exitTypes", "requirements",
        "rewards", "roomTemplates", "routeTemplates", "routes",
    }, "catalog")
    local routes = orderedCatalog(raw.routes, "routes")
    local routeTemplates = keyedCatalog(raw.routeTemplates, "routeTemplates")
    local templates = keyedCatalog(raw.roomTemplates, "roomTemplates")
    local batchRules = keyedCatalog(raw.batchRules, "batchRules")
    local encounterProfiles = keyedCatalog(raw.encounterProfiles, "encounterProfiles")
    local exitTypes = keyedCatalog(raw.exitTypes, "exitTypes")
    local requirements = requirementSchema.validateRegistry(raw.requirements)
    validateRouteRegistries(routes, routeTemplates)
    validateRoomTemplates(templates)
    validateBatchRules(batchRules)
    validateExitTypes(exitTypes)
    local rewards = validateRewards(raw.rewards, requirements)
    validateEncounterProfiles(encounterProfiles, requirements, rewards)
    local biomes = validateBiomes(
        raw.biomes,
        routes,
        routeTemplates,
        templates,
        batchRules,
        encounterProfiles,
        exitTypes,
        rewards,
        requirements
    )
    validateAllRequirementReferences(biomes, templates, encounterProfiles, rewards, requirements)
    return {
        routes = routes,
        biomes = biomes,
        roomTemplates = templates,
        routeTemplates = routeTemplates,
        batchRules = batchRules,
        encounterProfiles = encounterProfiles,
        exitTypes = exitTypes,
        requirements = requirements,
        rewards = rewards,
    }
end

return validator
