local catalog = {}

local VANILLA_VALUE = ""
local MAJOR_VALUE = "Major"
local MINOR_VALUE = "Minor"
local SHOP_BOON_SOURCE_VALUES = {
    RandomLoot = true,
    BoostedRandomLoot = true,
}

local function copyList(source)
    local copy = {}
    for index, value in ipairs(source or {}) do
        copy[index] = value
    end
    return copy
end

local function lookupList(values)
    if values == nil then
        return nil
    end

    local lookup = {}
    for _, value in ipairs(values) do
        lookup[value] = true
    end
    return lookup
end

local function isOnlyEligible(values, expected)
    if values == nil or values[1] == nil then
        return false
    end
    return values[1] == expected and values[2] == nil
end

local function addOption(values, labels, key, label)
    if key == nil then
        return
    end
    values[#values + 1] = key
    labels[key] = label or key
end

local function displayLabel(definitions, key)
    if key == nil or key == "" then
        return "Vanilla"
    end

    local primitive = definitions.primitives and definitions.primitives[key]
    if primitive ~= nil and primitive.label ~= nil then
        return primitive.label
    end

    local label = tostring(key)
    label = string.gsub(label, "Upgrade$", "")
    label = string.gsub(label, "Drop$", "")
    label = string.gsub(label, "([a-z])([A-Z])", "%1 %2")
    label = string.gsub(label, "([A-Z])([A-Z][a-z])", "%1 %2")
    return label
end

local function bundleOptions(definitions, bundleName)
    local bundle = definitions.bundles and definitions.bundles[bundleName]
    if bundle ~= nil then
        return bundle.options or {}
    end
    return {}
end

local function bundleLabel(definitions, bundleName, fallback)
    local bundle = definitions.bundles and definitions.bundles[bundleName]
    if bundle ~= nil and bundle.label ~= nil then
        return bundle.label
    end
    return fallback
end

local function uniqueOfferGroups(shop, aliasBySlotKey)
    local groups = {}
    for _, group in ipairs(shop.uniqueOfferGroups or {}) do
        local aliases = {}
        for _, slotKey in ipairs(group.slots or {}) do
            local alias = aliasBySlotKey[slotKey]
            if alias ~= nil then
                aliases[#aliases + 1] = alias
            end
        end
        if aliases[2] ~= nil then
            groups[#groups + 1] = {
                aliases = aliases,
                code = group.code,
                message = group.message,
            }
        end
    end
    return groups
end

local function uniqueNames(items, eligible, ineligible, labelFor)
    local values = {}
    local labels = {}
    local seen = {}
    labelFor = labelFor or function(name)
        return displayLabel({ primitives = {} }, name)
    end

    addOption(values, labels, VANILLA_VALUE, "Vanilla")
    for _, name in ipairs(items or {}) do
        if name ~= nil
            and seen[name] == nil
            and (eligible == nil or eligible[name])
            and (ineligible == nil or not ineligible[name])
        then
            seen[name] = true
            addOption(values, labels, name, labelFor(name))
        end
    end
    return values, labels
end

local function rewardOptionLabel(definitions, name)
    return displayLabel(definitions, name)
end

local function godSourceOptions(definitions)
    local values = {}
    local labels = {}
    addOption(values, labels, VANILLA_VALUE, "Vanilla")
    for _, lootName in ipairs(definitions.godLoot or {}) do
        addOption(values, labels, lootName, rewardOptionLabel(definitions, lootName))
    end
    return values, labels
end

local function dropdown(alias, key, label, values, labels, opts)
    opts = opts or {}
    local controlWidth = opts.controlWidth or 160
    local drawOpts = {
        label = label,
        values = values,
        displayValues = labels,
        controlWidth = controlWidth,
        labelWidth = opts.labelWidth,
        controlGap = opts.controlGap,
    }
    local control = {
        alias = alias,
        key = key,
        kind = opts.kind or key,
        label = label,
        values = values,
        displayValues = labels,
        controlWidth = controlWidth,
        drawOpts = drawOpts,
        visibleWhen = opts.visibleWhen,
    }
    if label == "Reward" then
        control.genericRewardLabelHiddenDrawOpts = {
            label = "",
            values = values,
            displayValues = labels,
            controlWidth = controlWidth,
            labelWidth = opts.labelWidth,
            controlGap = opts.controlGap,
        }
    end
    if opts.rewardStore ~= nil then
        control.rewardStore = opts.rewardStore
    end
    if opts.rowIndex ~= nil then
        control.rowIndex = opts.rowIndex
    end
    return control
end

local function noSurface(context)
    return {
        kind = "none",
        context = context,
        controls = {},
    }
end

local function roomStoreSurface(self, context)
    local rewardStore = context.rewardStore or "RunProgress"
    local rewardTypes = bundleOptions(self.definitions, rewardStore)
    local eligible = lookupList(context.eligibleRewardTypes)
    local ineligible = lookupList(context.ineligibleRewardTypes)

    if isOnlyEligible(context.eligibleRewardTypes, "Boon")
        and (ineligible == nil or not ineligible.Boon)
    then
        local values, labels = godSourceOptions(self.definitions)
        return {
            kind = "boonSource",
            context = context,
            fixedRewardType = "Boon",
            controls = {
                dropdown("Reward1Key", "boonSource", "", values, labels, {
                    kind = "boonSource",
                    controlWidth = 170,
                }),
            },
        }
    end

    local rewardValues, rewardLabels = uniqueNames(rewardTypes, eligible, ineligible, function(name)
        return rewardOptionLabel(self.definitions, name)
    end)
    local godValues, godLabels = godSourceOptions(self.definitions)
    return {
        kind = "roomStore",
        context = context,
        rewardStore = rewardStore,
        controls = {
            dropdown("Reward1Key", "rewardType", "Reward", rewardValues, rewardLabels, {
                kind = "rewardType",
                controlWidth = 170,
            }),
            dropdown("Reward2Key", "boonSource", "God", godValues, godLabels, {
                kind = "boonSource",
                controlWidth = 170,
                visibleWhen = { alias = "Reward1Key", value = "Boon" },
            }),
        },
    }
end

local function majorMinorSurface(self, context)
    local majorRewardStore = context.majorRewardStore or "RunProgress"
    local minorRewardStore = context.minorRewardStore or "MetaProgress"
    local majorValues, majorLabels = uniqueNames(bundleOptions(self.definitions, majorRewardStore), nil, nil, function(name)
        return rewardOptionLabel(self.definitions, name)
    end)
    local minorValues, minorLabels = uniqueNames(bundleOptions(self.definitions, minorRewardStore), nil, nil, function(name)
        return rewardOptionLabel(self.definitions, name)
    end)
    local godValues, godLabels = godSourceOptions(self.definitions)
    local rewardClassValues = { VANILLA_VALUE, MAJOR_VALUE, MINOR_VALUE }
    local rewardClassLabels = {
        [VANILLA_VALUE] = "Vanilla",
        [MAJOR_VALUE] = bundleLabel(self.definitions, majorRewardStore, MAJOR_VALUE),
        [MINOR_VALUE] = bundleLabel(self.definitions, minorRewardStore, MINOR_VALUE),
    }

    return {
        kind = "majorMinor",
        context = context,
        majorRewardStore = majorRewardStore,
        minorRewardStore = minorRewardStore,
        controls = {
            dropdown("Reward1Key", "rewardClass", "Reward", rewardClassValues, rewardClassLabels, {
                kind = "rewardClass",
                controlWidth = 110,
            }),
            dropdown("Reward2Key", "rewardType", "", majorValues, majorLabels, {
                kind = "rewardType",
                controlWidth = 170,
                rewardStore = majorRewardStore,
                visibleWhen = { alias = "Reward1Key", value = MAJOR_VALUE },
            }),
            dropdown("Reward3Key", "boonSource", "God", godValues, godLabels, {
                kind = "boonSource",
                controlWidth = 170,
                visibleWhen = {
                    all = {
                        { alias = "Reward1Key", value = MAJOR_VALUE },
                        { alias = "Reward2Key", value = "Boon" },
                    },
                },
            }),
            dropdown("Reward4Key", "rewardType", "", minorValues, minorLabels, {
                kind = "rewardType",
                controlWidth = 170,
                rewardStore = minorRewardStore,
                visibleWhen = { alias = "Reward1Key", value = MINOR_VALUE },
            }),
        },
    }
end

local function forcedRewardSurface(self, context)
    if context.rewardType == "Devotion" then
        local values, labels = godSourceOptions(self.definitions)
        return {
            kind = "devotionPair",
            context = context,
            fixedRewardType = "Devotion",
            controls = {
                dropdown("Reward1Key", "lootAName", "God A", values, labels, {
                    kind = "boonSource",
                    controlWidth = 150,
                    rowIndex = 1,
                }),
                dropdown("Reward2Key", "lootBName", "God B", values, labels, {
                    kind = "boonSource",
                    controlWidth = 150,
                    rowIndex = 2,
                }),
            },
        }
    end

    if context.rewardType == "Boon" then
        local values, labels = godSourceOptions(self.definitions)
        return {
            kind = "boonSource",
            context = context,
            fixedRewardType = "Boon",
            controls = {
                dropdown("Reward1Key", "boonSource", "", values, labels, {
                    kind = "boonSource",
                    controlWidth = 170,
                }),
            },
        }
    end

    return {
        kind = "fixedReward",
        context = context,
        fixedRewardType = context.rewardType,
        controls = {},
    }
end

local function shopSurface(self, context)
    local shop = self.definitions.shops[context.shopProfile] or {}
    local controls = {}
    local godValues, godLabels = godSourceOptions(self.definitions)
    local aliasBySlotKey = {}

    for index, slot in ipairs(shop.slots or {}) do
        local rewardAlias = "Reward" .. tostring(index) .. "Key"
        local lootAlias = "Reward" .. tostring(index) .. "LootKey"
        aliasBySlotKey[slot.key] = rewardAlias
        local options = slot.options or bundleOptions(self.definitions, slot.bundle)
        local values, labels = uniqueNames(options, nil, nil, function(name)
            return rewardOptionLabel(self.definitions, name)
        end)
        controls[#controls + 1] = dropdown(
            rewardAlias,
            slot.key,
            slot.label,
            values,
            labels,
            {
                kind = "shopOption",
                controlWidth = 170,
                labelWidth = 130,
                rowIndex = index,
            }
        )
        for _, itemName in ipairs(options) do
            if SHOP_BOON_SOURCE_VALUES[itemName] then
                controls[#controls + 1] = dropdown(
                    lootAlias,
                    slot.key .. "Loot",
                    "God",
                    godValues,
                    godLabels,
                    {
                        kind = "boonSource",
                        controlWidth = 170,
                        labelWidth = 45,
                        rowIndex = index,
                        visibleWhen = {
                            any = {
                                { alias = rewardAlias, value = "RandomLoot" },
                                { alias = rewardAlias, value = "BoostedRandomLoot" },
                            },
                        },
                    }
                )
                break
            end
        end
    end

    return {
        kind = "shop",
        context = context,
        shopProfile = context.shopProfile,
        rowHeader = "Reward",
        uniqueOfferGroups = uniqueOfferGroups(shop, aliasBySlotKey),
        controls = controls,
    }
end

local function surfaceFor(self, context)
    context = context or { kind = "none" }
    if context.kind == "none" then
        return noSurface(context)
    elseif context.kind == "fieldsCages" then
        return roomStoreSurface(self, context)
    elseif context.kind == "roomStore" then
        return roomStoreSurface(self, context)
    elseif context.kind == "majorMinor" then
        return majorMinorSurface(self, context)
    elseif context.kind == "forcedReward" then
        return forcedRewardSurface(self, context)
    elseif context.kind == "shop" then
        return shopSurface(self, context)
    elseif context.kind == "shipWheel" then
        return majorMinorSurface(self, {
            kind = "majorMinor",
            majorRewardStore = context.defaultRewardStore or "RunProgress",
            minorRewardStore = "MetaProgress",
        })
    end
    return noSurface(context)
end

function catalog.create(definitions)
    local source = definitions or {}
    local instance = {
        definitions = {
            godLoot = copyList(source.godLoot),
            bundles = source.bundles or {},
            primitives = source.primitives or {},
            shops = source.shops or {},
        },
        surfaceCache = {},
    }

    function instance:surfaceFor(context)
        context = context or false
        local cached = self.surfaceCache[context]
        if cached == nil then
            cached = surfaceFor(self, context ~= false and context or nil)
            self.surfaceCache[context] = cached
        end
        return cached
    end

    function instance.godLootOptions()
        return copyList(instance.definitions.godLoot)
    end

    return instance
end

return catalog
