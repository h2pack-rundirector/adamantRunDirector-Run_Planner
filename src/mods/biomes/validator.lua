local validator = {}

local STRUCTURAL_FEATURE_KEYS = {
    chaos = true,
}

local function addIssue(issues, code, path, message)
    issues[#issues + 1] = {
        code = code,
        path = path,
        message = message,
    }
end

local function childPath(path, key)
    if type(key) == "number" then
        return path .. "[" .. tostring(key) .. "]"
    end
    if path == "" then
        return tostring(key)
    end
    return path .. "." .. tostring(key)
end

local function hasKey(list, keyField)
    local lookup = {}
    for _, item in ipairs(list or {}) do
        if type(item) == "table" and item[keyField] ~= nil then
            lookup[item[keyField]] = true
        end
    end
    return lookup
end

local function validateUniqueKeys(issues, items, path, keyField)
    local seen = {}
    for index, item in ipairs(items or {}) do
        local key = type(item) == "table" and item[keyField] or nil
        if key == nil then
            addIssue(issues, "missing_key", childPath(path, index), "Item key is missing")
        elseif seen[key] then
            addIssue(issues, "duplicate_key", childPath(path, index), "Duplicate key: " .. tostring(key))
        else
            seen[key] = true
        end
    end
end

local function rewardStoreExists(rewardDomain, rewardStore)
    return rewardStore ~= nil
        and rewardDomain.rewardStores ~= nil
        and rewardDomain.rewardStores[rewardStore] ~= nil
end

local function shopOptionSetExists(rewardDomain, optionSet)
    return optionSet ~= nil
        and rewardDomain.shopOptionSets ~= nil
        and rewardDomain.shopOptionSets[optionSet] ~= nil
end

local function shopProfileExists(rewardDomain, shopProfile)
    return shopProfile ~= nil
        and rewardDomain.shops ~= nil
        and rewardDomain.shops[shopProfile] ~= nil
end

local function primitiveExists(rewardDomain, rewardType)
    return rewardType ~= nil
        and rewardDomain.primitives ~= nil
        and rewardDomain.primitives[rewardType] ~= nil
end

local function rewardTypeFromBagEntry(entry)
    if type(entry) == "table" then
        return entry.rewardType
    end
    return entry
end

local function validateRewardTypes(issues, rewardDomain, items, path)
    for index, rewardType in ipairs(items or {}) do
        if not primitiveExists(rewardDomain, rewardType) then
            addIssue(issues, "unknown_reward_type", childPath(path, index), "Unknown reward type: " .. tostring(rewardType))
        end
    end
end

local function prefixedKey(prefix, key)
    if prefix == "" then
        return key
    end
    return prefix .. string.upper(string.sub(key, 1, 1)) .. string.sub(key, 2)
end

local function validateRewardFilters(issues, rewardDomain, context, path, prefix)
    local prefixText = prefix or ""
    local typeKey = prefixedKey(prefixText, "eligibleRewardTypes")
    local ineligibleTypeKey = prefixedKey(prefixText, "ineligibleRewardTypes")

    validateRewardTypes(issues, rewardDomain, context[typeKey], childPath(path, typeKey))
    validateRewardTypes(issues, rewardDomain, context[ineligibleTypeKey], childPath(path, ineligibleTypeKey))
end

local function validateRewardContext(issues, rewardDomain, reward, path)
    if reward == nil then
        return
    end
    if type(reward) ~= "table" then
        addIssue(issues, "invalid_reward", path, "Reward context must be a table")
        return
    end

    if reward.kind == "roomStore" then
        if not rewardStoreExists(rewardDomain, reward.rewardStore) then
            addIssue(issues, "unknown_reward_store", childPath(path, "rewardStore"), "Unknown reward store")
        end
        validateRewardFilters(issues, rewardDomain, reward, path, "")
    elseif reward.kind == "majorMinor" then
        if not rewardStoreExists(rewardDomain, reward.majorRewardStore) then
            addIssue(issues, "unknown_reward_store", childPath(path, "majorRewardStore"), "Unknown major reward store")
        end
        if not rewardStoreExists(rewardDomain, reward.minorRewardStore) then
            addIssue(issues, "unknown_reward_store", childPath(path, "minorRewardStore"), "Unknown minor reward store")
        end
        validateRewardFilters(issues, rewardDomain, reward, path, "")
        validateRewardFilters(issues, rewardDomain, reward, path, "major")
        validateRewardFilters(issues, rewardDomain, reward, path, "minor")
    elseif reward.kind == "forcedReward" then
        if not primitiveExists(rewardDomain, reward.rewardType) then
            addIssue(issues, "unknown_reward_type", childPath(path, "rewardType"), "Unknown reward type")
        end
        if reward.rewardStore ~= nil and not rewardStoreExists(rewardDomain, reward.rewardStore) then
            addIssue(issues, "unknown_reward_store", childPath(path, "rewardStore"), "Unknown reward store")
        end
    elseif reward.kind == "shop" then
        if not shopProfileExists(rewardDomain, reward.shopProfile) then
            addIssue(issues, "unknown_shop_profile", childPath(path, "shopProfile"), "Unknown shop profile")
        end
    elseif reward.kind == "fieldsCages" then
        if not rewardStoreExists(rewardDomain, reward.rewardStore) then
            addIssue(issues, "unknown_reward_store", childPath(path, "rewardStore"), "Unknown reward store")
        end
        validateRewardFilters(issues, rewardDomain, reward, path, "")
    elseif reward.kind == "preboss" then
        for index, offer in ipairs(reward.offers or {}) do
            validateRewardContext(issues, rewardDomain, offer, childPath(childPath(path, "offers"), index))
        end
    end
end

local function validateFeatures(issues, knownFeatureKeys, features, path)
    if features == nil then
        return
    end
    if type(features) ~= "table" then
        addIssue(issues, "invalid_features", path, "Features must be a table")
        return
    end
    for featureKey in pairs(features) do
        if not knownFeatureKeys[featureKey] then
            addIssue(issues, "unknown_feature", childPath(path, featureKey), "Unknown feature: " .. tostring(featureKey))
        end
    end
end

local function validateRoomOption(issues, rewardDomain, knownFeatureKeys, option, path)
    if type(option) ~= "table" then
        return
    end
    validateFeatures(issues, knownFeatureKeys, option.features, childPath(path, "features"))
    if option.reward ~= nil then
        validateRewardContext(issues, rewardDomain, option.reward, childPath(path, "reward"))
    end
end

local function validateRoomOptions(issues, rewardDomain, knownFeatureKeys, options, path)
    validateUniqueKeys(issues, options, path, "key")
    for index, option in ipairs(options or {}) do
        validateRoomOption(issues, rewardDomain, knownFeatureKeys, option, childPath(path, index))
    end
end

local function validateRole(issues, rewardDomain, knownFeatureKeys, role, path)
    if type(role) ~= "table" then
        return
    end
    validateFeatures(issues, knownFeatureKeys, role and role.features, childPath(path, "features"))
    if role and role.reward ~= nil then
        validateRewardContext(issues, rewardDomain, role.reward, childPath(path, "reward"))
    end
    validateRoomOptions(
        issues,
        rewardDomain,
        knownFeatureKeys,
        role and role.roomOptions,
        childPath(path, "roomOptions")
    )
    validateRoomOptions(
        issues,
        rewardDomain,
        knownFeatureKeys,
        role and role.mapOptions,
        childPath(path, "mapOptions")
    )
end

local function validateSlotEntry(issues, rewardDomain, knownFeatureKeys, rolesByKey, entry, path)
    if type(entry) ~= "table" then
        return
    end
    if entry.roleKey ~= nil and rolesByKey[entry.roleKey] == nil then
        addIssue(issues, "unknown_role", childPath(path, "roleKey"), "Slot references unknown role")
    end
    validateFeatures(issues, knownFeatureKeys, entry.features, childPath(path, "features"))
    if entry.reward ~= nil then
        validateRewardContext(issues, rewardDomain, entry.reward, childPath(path, "reward"))
    end
    validateRoomOption(
        issues,
        rewardDomain,
        knownFeatureKeys,
        entry.room,
        childPath(path, "room")
    )
    validateRoomOptions(
        issues,
        rewardDomain,
        knownFeatureKeys,
        entry.roomOptions,
        childPath(path, "roomOptions")
    )
end

local function validateSlotList(issues, rewardDomain, knownFeatureKeys, rolesByKey, items, path)
    for index, entry in ipairs(items or {}) do
        validateSlotEntry(issues, rewardDomain, knownFeatureKeys, rolesByKey, entry, childPath(path, index))
    end
end

local function validateSlotMap(issues, rewardDomain, knownFeatureKeys, rolesByKey, items, path)
    for key, entry in pairs(items or {}) do
        validateSlotEntry(issues, rewardDomain, knownFeatureKeys, rolesByKey, entry, childPath(path, key))
    end
end

local function validateTimelineEntry(issues, knownFeatureKeys, entry, path)
    if type(entry) ~= "table" then
        return
    end
    validateFeatures(issues, knownFeatureKeys, entry.features, childPath(path, "features"))
end

local function validateTimeline(issues, knownFeatureKeys, timeline, path)
    if timeline == nil then
        return
    end
    if type(timeline) ~= "table" then
        return
    end
    for index, entry in ipairs(timeline.afterBiome or {}) do
        validateTimelineEntry(issues, knownFeatureKeys, entry, childPath(childPath(path, "afterBiome"), index))
    end
end

local function buildKnownFeatureKeys(featureDefinitions, biomes)
    local known = {}
    for featureKey in pairs(STRUCTURAL_FEATURE_KEYS) do
        known[featureKey] = true
    end
    for _, feature in pairs((featureDefinitions or {}).byKey or {}) do
        if feature.featureKey ~= nil then
            known[feature.featureKey] = true
        end
    end
    for _, biome in ipairs(biomes or {}) do
        for featureKey in pairs(biome.featurePolicies or {}) do
            known[featureKey] = true
        end
    end
    return known
end

function validator.validateRewardDomain(rewardDomain)
    local issues = {}
    local domain = rewardDomain or {}

    for bagKey, bag in pairs(domain.rewardBags or {}) do
        if domain.rewardStores == nil or domain.rewardStores[bagKey] == nil then
            addIssue(
                issues,
                "unknown_reward_store",
                "rewardBags." .. tostring(bagKey),
                "Reward bag has no matching reward store"
            )
        end
        for index, item in ipairs(bag or {}) do
            local path = "rewardBags." .. tostring(bagKey) .. ".entries[" .. tostring(index) .. "].rewardType"
            local rewardType = rewardTypeFromBagEntry(item)
            if not primitiveExists(domain, rewardType) then
                addIssue(issues, "unknown_reward_type", path, "Unknown reward type: " .. tostring(rewardType))
            end
        end
    end
    for storeKey, store in pairs(domain.rewardStores or {}) do
        validateRewardTypes(issues, domain, store.options, "rewardStores." .. tostring(storeKey) .. ".options")
    end
    for optionSetKey, optionSet in pairs(domain.shopOptionSets or {}) do
        validateRewardTypes(issues, domain, optionSet.options, "shopOptionSets." .. tostring(optionSetKey) .. ".options")
    end
    for shopKey, shop in pairs(domain.shops or {}) do
        local seenSlots = {}
        for index, slot in ipairs(shop.slots or {}) do
            local slotPath = "shops." .. tostring(shopKey) .. ".slots[" .. tostring(index) .. "]"
            if slot.key == nil then
                addIssue(issues, "missing_key", childPath(slotPath, "key"), "Shop slot key is missing")
            elseif seenSlots[slot.key] then
                addIssue(issues, "duplicate_key", childPath(slotPath, "key"), "Duplicate shop slot key")
            else
                seenSlots[slot.key] = true
            end
            if not shopOptionSetExists(domain, slot.optionSet) then
                addIssue(issues, "unknown_shop_option_set", childPath(slotPath, "optionSet"), "Unknown shop option set")
            end
        end
    end

    return issues
end

function validator.validateBiome(biome, opts)
    opts = opts or {}
    local issues = {}
    local rewardDomain = opts.rewardDomain or {}
    local knownFeatureKeys = opts.knownFeatureKeys or buildKnownFeatureKeys(opts.featureDefinitions, { biome })
    local path = "biomes." .. tostring(biome and biome.key or "?")

    if type(biome) ~= "table" then
        addIssue(issues, "expected_table", path, "Expected declaration table")
        return issues
    end

    validateUniqueKeys(issues, biome.roles, childPath(path, "roles"), "key")
    local rolesByKey = hasKey(biome.roles, "key")
    for index, role in ipairs(biome.roles or {}) do
        validateRole(
            issues,
            rewardDomain,
            knownFeatureKeys,
            role,
            childPath(childPath(path, "roles"), index)
        )
    end

    validateTimeline(issues, knownFeatureKeys, biome.timeline, childPath(path, "timeline"))

    local layoutPath = childPath(path, "slotLayout")
    local layout = biome.slotLayout or {}
    if layout.entry ~= nil then
        validateSlotEntry(
            issues,
            rewardDomain,
            knownFeatureKeys,
            rolesByKey,
            layout.entry,
            childPath(layoutPath, "entry")
        )
    end
    validateSlotMap(
        issues,
        rewardDomain,
        knownFeatureKeys,
        rolesByKey,
        layout.special,
        childPath(layoutPath, "special")
    )
    validateSlotList(
        issues,
        rewardDomain,
        knownFeatureKeys,
        rolesByKey,
        layout.fixedBeforeRoute,
        childPath(layoutPath, "fixedBeforeRoute")
    )
    validateSlotList(
        issues,
        rewardDomain,
        knownFeatureKeys,
        rolesByKey,
        layout.fixedAfterRoute,
        childPath(layoutPath, "fixedAfterRoute")
    )
    validateSlotList(
        issues,
        rewardDomain,
        knownFeatureKeys,
        rolesByKey,
        layout.fixedBeforeHub,
        childPath(layoutPath, "fixedBeforeHub")
    )
    validateSlotList(
        issues,
        rewardDomain,
        knownFeatureKeys,
        rolesByKey,
        layout.fixedAfterHub,
        childPath(layoutPath, "fixedAfterHub")
    )
    validateSlotList(
        issues,
        rewardDomain,
        knownFeatureKeys,
        rolesByKey,
        layout.fixedAfterGoals,
        childPath(layoutPath, "fixedAfterGoals")
    )

    return issues
end

function validator.validateCatalog(catalog, opts)
    opts = opts or {}
    local issues = {}
    local biomes = catalog and catalog.ordered or {}
    local knownFeatureKeys = buildKnownFeatureKeys(opts.featureDefinitions, biomes)
    local seenBiomes = {}

    for index, biome in ipairs(biomes) do
        if biome.key == nil then
            addIssue(issues, "missing_key", "catalog.ordered[" .. tostring(index) .. "]", "Biome key is missing")
        elseif seenBiomes[biome.key] then
            addIssue(issues, "duplicate_biome_key", "catalog.ordered[" .. tostring(index) .. "]", "Duplicate biome key")
        else
            seenBiomes[biome.key] = true
        end
        local biomeIssues = validator.validateBiome(biome, {
            rewardDomain = opts.rewardDomain,
            knownFeatureKeys = knownFeatureKeys,
        })
        for _, issue in ipairs(biomeIssues) do
            issues[#issues + 1] = issue
        end
    end

    return issues
end

function validator.validateGodLists(godData, rewardDomain, routeRules, rewardConditions)
    local issues = {}

    local function assertSameList(name, expected, actual)
        for index, value in ipairs(expected) do
            if actual == nil or actual[index] ~= value then
                addIssue(issues, "god_list_drift", name, "God list drift at index " .. tostring(index))
                return
            end
        end
        if actual ~= nil and actual[#expected + 1] ~= nil then
            addIssue(issues, "god_list_drift", name, "God list has unexpected extra entries")
        end
    end

    local godLootNames = godData.godLootNames()
    local devotionPrerequisiteLootNames = godData.devotionPrerequisiteLootNames()

    assertSameList("rewardDomain.godLoot", godLootNames, rewardDomain and rewardDomain.godLoot)
    assertSameList("routeRules.boonSourcePick", godLootNames, routeRules and routeRules.boonSourcePick().allowedLootNames)
    assertSameList("routeRules.devotionPick", godLootNames, routeRules and routeRules.devotionPick().allowedLootNames)

    local godLookup = {}
    for _, key in ipairs(godLootNames) do
        godLookup[key] = true
    end
    for ruleIndex, rule in ipairs(rewardConditions or {}) do
        for reqIndex, requirement in ipairs(rule.requirements or {}) do
            if requirement.kind == "priorDistinctGodLoot" then
                assertSameList(
                    "conditions[" .. tostring(ruleIndex) .. "].requirements[" .. tostring(reqIndex) .. "].countedLootNames",
                    devotionPrerequisiteLootNames,
                    requirement.countedLootNames
                )
            end
            for lootIndex, lootName in ipairs(requirement.countedLootNames or {}) do
                if not godLookup[lootName] then
                    addIssue(
                        issues,
                        "god_list_drift",
                        "conditions[" .. tostring(ruleIndex) .. "].requirements[" .. tostring(reqIndex) .. "].countedLootNames["
                            .. tostring(lootIndex)
                            .. "]",
                        "Reward condition references unknown god loot"
                    )
                end
            end
        end
    end

    return issues
end

return validator
