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

local function rewardStoreExists(rewardDefinitions, rewardStore)
    return rewardStore ~= nil
        and rewardDefinitions.rewardStores ~= nil
        and rewardDefinitions.rewardStores[rewardStore] ~= nil
end

local function shopOptionSetExists(rewardDefinitions, optionSet)
    return optionSet ~= nil
        and rewardDefinitions.shopOptionSets ~= nil
        and rewardDefinitions.shopOptionSets[optionSet] ~= nil
end

local function shopProfileExists(rewardDefinitions, shopProfile)
    return shopProfile ~= nil
        and rewardDefinitions.shops ~= nil
        and rewardDefinitions.shops[shopProfile] ~= nil
end

local function rewardSetExists(rewardDefinitions, rewardSet)
    return rewardSet ~= nil
        and rewardDefinitions.rewardSets ~= nil
        and rewardDefinitions.rewardSets[rewardSet] ~= nil
end

local function primitiveExists(rewardDefinitions, rewardType)
    return rewardType ~= nil
        and rewardDefinitions.primitives ~= nil
        and rewardDefinitions.primitives[rewardType] ~= nil
end

local function validateRewardTypes(issues, rewardDefinitions, items, path)
    for index, rewardType in ipairs(items or {}) do
        if not primitiveExists(rewardDefinitions, rewardType) then
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

local function validateRewardFilters(issues, rewardDefinitions, context, path, prefix)
    local prefixText = prefix or ""
    local typeKey = prefixedKey(prefixText, "eligibleRewardTypes")
    local ineligibleTypeKey = prefixedKey(prefixText, "ineligibleRewardTypes")
    local setKey = prefixedKey(prefixText, "eligibleRewardSet")
    local ineligibleSetKey = prefixedKey(prefixText, "ineligibleRewardSet")

    validateRewardTypes(issues, rewardDefinitions, context[typeKey], childPath(path, typeKey))
    validateRewardTypes(issues, rewardDefinitions, context[ineligibleTypeKey], childPath(path, ineligibleTypeKey))
    if context[setKey] ~= nil and not rewardSetExists(rewardDefinitions, context[setKey]) then
        addIssue(issues, "unknown_reward_set", childPath(path, setKey), "Unknown reward set: " .. tostring(context[setKey]))
    end
    if context[ineligibleSetKey] ~= nil and not rewardSetExists(rewardDefinitions, context[ineligibleSetKey]) then
        addIssue(
            issues,
            "unknown_reward_set",
            childPath(path, ineligibleSetKey),
            "Unknown reward set: " .. tostring(context[ineligibleSetKey])
        )
    end
end

local function validateRewardContext(issues, rewardDefinitions, reward, path)
    if reward == nil then
        return
    end
    if type(reward) ~= "table" then
        addIssue(issues, "invalid_reward", path, "Reward context must be a table")
        return
    end

    if reward.kind == "roomStore" then
        if not rewardStoreExists(rewardDefinitions, reward.rewardStore) then
            addIssue(issues, "unknown_reward_store", childPath(path, "rewardStore"), "Unknown reward store")
        end
        validateRewardFilters(issues, rewardDefinitions, reward, path, "")
    elseif reward.kind == "majorMinor" then
        if not rewardStoreExists(rewardDefinitions, reward.majorRewardStore) then
            addIssue(issues, "unknown_reward_store", childPath(path, "majorRewardStore"), "Unknown major reward store")
        end
        if not rewardStoreExists(rewardDefinitions, reward.minorRewardStore) then
            addIssue(issues, "unknown_reward_store", childPath(path, "minorRewardStore"), "Unknown minor reward store")
        end
        validateRewardFilters(issues, rewardDefinitions, reward, path, "")
        validateRewardFilters(issues, rewardDefinitions, reward, path, "major")
        validateRewardFilters(issues, rewardDefinitions, reward, path, "minor")
    elseif reward.kind == "forcedReward" then
        if not primitiveExists(rewardDefinitions, reward.rewardType) then
            addIssue(issues, "unknown_reward_type", childPath(path, "rewardType"), "Unknown reward type")
        end
        if reward.rewardStore ~= nil and not rewardStoreExists(rewardDefinitions, reward.rewardStore) then
            addIssue(issues, "unknown_reward_store", childPath(path, "rewardStore"), "Unknown reward store")
        end
    elseif reward.kind == "clockworkChoice" then
        if not rewardStoreExists(rewardDefinitions, reward.rewardStore) then
            addIssue(issues, "unknown_reward_store", childPath(path, "rewardStore"), "Unknown reward store")
        end
        if not primitiveExists(rewardDefinitions, reward.goalRewardType) then
            addIssue(issues, "unknown_reward_type", childPath(path, "goalRewardType"), "Unknown goal reward type")
        end
        validateRewardFilters(issues, rewardDefinitions, reward, path, "")
    elseif reward.kind == "shop" then
        if not shopProfileExists(rewardDefinitions, reward.shopProfile) then
            addIssue(issues, "unknown_shop_profile", childPath(path, "shopProfile"), "Unknown shop profile")
        end
    elseif reward.kind == "fieldsCages" then
        if not rewardStoreExists(rewardDefinitions, reward.rewardStore) then
            addIssue(issues, "unknown_reward_store", childPath(path, "rewardStore"), "Unknown reward store")
        end
        validateRewardFilters(issues, rewardDefinitions, reward, path, "")
    elseif reward.kind == "preboss" then
        for index, offer in ipairs(reward.offers or {}) do
            validateRewardContext(issues, rewardDefinitions, offer, childPath(childPath(path, "offers"), index))
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

local function validateRoomOption(issues, rewardDefinitions, knownFeatureKeys, option, path)
    if type(option) ~= "table" then
        return
    end
    validateFeatures(issues, knownFeatureKeys, option.features, childPath(path, "features"))
    if option.reward ~= nil then
        validateRewardContext(issues, rewardDefinitions, option.reward, childPath(path, "reward"))
    end
end

local function validateRoomOptions(issues, rewardDefinitions, knownFeatureKeys, options, path)
    validateUniqueKeys(issues, options, path, "key")
    for index, option in ipairs(options or {}) do
        validateRoomOption(issues, rewardDefinitions, knownFeatureKeys, option, childPath(path, index))
    end
end

local function validateRole(issues, rewardDefinitions, knownFeatureKeys, role, path)
    if type(role) ~= "table" then
        return
    end
    validateFeatures(issues, knownFeatureKeys, role and role.features, childPath(path, "features"))
    if role and role.reward ~= nil then
        validateRewardContext(issues, rewardDefinitions, role.reward, childPath(path, "reward"))
    end
    validateRoomOptions(
        issues,
        rewardDefinitions,
        knownFeatureKeys,
        role and role.roomOptions,
        childPath(path, "roomOptions")
    )
    validateRoomOptions(
        issues,
        rewardDefinitions,
        knownFeatureKeys,
        role and role.mapOptions,
        childPath(path, "mapOptions")
    )
end

local function validateSlotEntry(issues, rewardDefinitions, knownFeatureKeys, rolesByKey, entry, path)
    if type(entry) ~= "table" then
        return
    end
    if entry.roleKey ~= nil and rolesByKey[entry.roleKey] == nil then
        addIssue(issues, "unknown_role", childPath(path, "roleKey"), "Slot references unknown role")
    end
    validateFeatures(issues, knownFeatureKeys, entry.features, childPath(path, "features"))
    if entry.reward ~= nil then
        validateRewardContext(issues, rewardDefinitions, entry.reward, childPath(path, "reward"))
    end
    validateRoomOption(
        issues,
        rewardDefinitions,
        knownFeatureKeys,
        entry.room,
        childPath(path, "room")
    )
    validateRoomOptions(
        issues,
        rewardDefinitions,
        knownFeatureKeys,
        entry.roomOptions,
        childPath(path, "roomOptions")
    )
end

local function validateSlotList(issues, rewardDefinitions, knownFeatureKeys, rolesByKey, items, path)
    for index, entry in ipairs(items or {}) do
        validateSlotEntry(issues, rewardDefinitions, knownFeatureKeys, rolesByKey, entry, childPath(path, index))
    end
end

local function validateSlotMap(issues, rewardDefinitions, knownFeatureKeys, rolesByKey, items, path)
    for key, entry in pairs(items or {}) do
        validateSlotEntry(issues, rewardDefinitions, knownFeatureKeys, rolesByKey, entry, childPath(path, key))
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

function validator.validateRewardDefinitions(rewardDefinitions)
    local issues = {}
    local definitions = rewardDefinitions or {}

    for storeKey, store in pairs(definitions.rewardStores or {}) do
        validateRewardTypes(issues, definitions, store.options, "rewardStores." .. tostring(storeKey) .. ".options")
    end
    for optionSetKey, optionSet in pairs(definitions.shopOptionSets or {}) do
        validateRewardTypes(issues, definitions, optionSet.options, "shopOptionSets." .. tostring(optionSetKey) .. ".options")
    end
    for shopKey, shop in pairs(definitions.shops or {}) do
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
            if not shopOptionSetExists(definitions, slot.optionSet) then
                addIssue(issues, "unknown_shop_option_set", childPath(slotPath, "optionSet"), "Unknown shop option set")
            end
        end
    end

    return issues
end

function validator.validateBiome(biome, opts)
    opts = opts or {}
    local issues = {}
    local rewardDefinitions = opts.rewardDefinitions or {}
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
            rewardDefinitions,
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
            rewardDefinitions,
            knownFeatureKeys,
            rolesByKey,
            layout.entry,
            childPath(layoutPath, "entry")
        )
    end
    validateSlotMap(
        issues,
        rewardDefinitions,
        knownFeatureKeys,
        rolesByKey,
        layout.special,
        childPath(layoutPath, "special")
    )
    validateSlotList(
        issues,
        rewardDefinitions,
        knownFeatureKeys,
        rolesByKey,
        layout.fixedBeforeRoute,
        childPath(layoutPath, "fixedBeforeRoute")
    )
    validateSlotList(
        issues,
        rewardDefinitions,
        knownFeatureKeys,
        rolesByKey,
        layout.fixedAfterRoute,
        childPath(layoutPath, "fixedAfterRoute")
    )
    validateSlotList(
        issues,
        rewardDefinitions,
        knownFeatureKeys,
        rolesByKey,
        layout.fixedBeforeHub,
        childPath(layoutPath, "fixedBeforeHub")
    )
    validateSlotList(
        issues,
        rewardDefinitions,
        knownFeatureKeys,
        rolesByKey,
        layout.fixedAfterHub,
        childPath(layoutPath, "fixedAfterHub")
    )
    validateSlotList(
        issues,
        rewardDefinitions,
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
            rewardDefinitions = opts.rewardDefinitions,
            knownFeatureKeys = knownFeatureKeys,
        })
        for _, issue in ipairs(biomeIssues) do
            issues[#issues + 1] = issue
        end
    end

    return issues
end

function validator.validateGodLists(godData, rewardDefinitions, routeRules, rewardConditions)
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

    assertSameList("definitions.godLoot", godLootNames, rewardDefinitions and rewardDefinitions.godLoot)
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
