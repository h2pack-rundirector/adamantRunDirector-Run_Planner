local catalog = {}

local VANILLA_VALUE = ""
local MAJOR_VALUE = "Major"
local MINOR_VALUE = "Minor"

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

local function displayLabel(key)
    if key == nil or key == "" then
        return "Vanilla"
    end

    local label = tostring(key)
    label = string.gsub(label, "Upgrade$", "")
    label = string.gsub(label, "Drop$", "")
    label = string.gsub(label, "([a-z])([A-Z])", "%1 %2")
    label = string.gsub(label, "([A-Z])([A-Z][a-z])", "%1 %2")
    return label
end

local function uniqueNames(items, eligible, ineligible)
    local values = {}
    local labels = {}
    local seen = {}

    addOption(values, labels, VANILLA_VALUE, "Vanilla")
    for _, name in ipairs(items or {}) do
        if name ~= nil
            and seen[name] == nil
            and (eligible == nil or eligible[name])
            and (ineligible == nil or not ineligible[name])
        then
            seen[name] = true
            addOption(values, labels, name, displayLabel(name))
        end
    end
    return values, labels
end

local function godSourceOptions(definitions)
    local values = {}
    local labels = {}
    addOption(values, labels, VANILLA_VALUE, "Vanilla")
    for _, lootName in ipairs(definitions.godLoot or {}) do
        addOption(values, labels, lootName, displayLabel(lootName))
    end
    return values, labels
end

local function dropdown(alias, key, label, values, labels, opts)
    opts = opts or {}
    local controlWidth = opts.controlWidth or 160
    local control = {
        alias = alias,
        key = key,
        kind = opts.kind or key,
        label = label,
        values = values,
        displayValues = labels,
        controlWidth = controlWidth,
        drawOpts = {
            label = label,
            values = values,
            displayValues = labels,
            controlWidth = controlWidth,
        },
        visibleWhen = opts.visibleWhen,
    }
    if opts.rewardStore ~= nil then
        control.rewardStore = opts.rewardStore
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
    local rewardTypes = self.definitions.rewardStores[rewardStore] or {}
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
                dropdown("Reward1Key", "boonSource", "God", values, labels, {
                    kind = "boonSource",
                    controlWidth = 170,
                }),
            },
        }
    end

    local rewardValues, rewardLabels = uniqueNames(rewardTypes, eligible, ineligible)
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
    local majorValues, majorLabels = uniqueNames(self.definitions.rewardStores[majorRewardStore])
    local minorValues, minorLabels = uniqueNames(self.definitions.rewardStores[minorRewardStore])
    local godValues, godLabels = godSourceOptions(self.definitions)
    local rewardClassValues = { VANILLA_VALUE, MAJOR_VALUE, MINOR_VALUE }
    local rewardClassLabels = {
        [VANILLA_VALUE] = "Vanilla",
        [MAJOR_VALUE] = "Major",
        [MINOR_VALUE] = "Minor",
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
                }),
                dropdown("Reward2Key", "lootBName", "God B", values, labels, {
                    kind = "boonSource",
                    controlWidth = 150,
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
                dropdown("Reward1Key", "boonSource", "God", values, labels, {
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

    for index, slot in ipairs(shop.slots or {}) do
        local values, labels = uniqueNames(slot.options)
        controls[#controls + 1] = dropdown(
            "Reward" .. tostring(index) .. "Key",
            slot.key,
            slot.label,
            values,
            labels,
            {
                kind = "shopOption",
                controlWidth = 170,
            }
        )
    end

    return {
        kind = "shop",
        context = context,
        shopProfile = context.shopProfile,
        controls = controls,
    }
end

local function surfaceFor(self, context)
    context = context or { kind = "none" }
    if context.kind == "none" then
        return noSurface(context)
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
    local instance = {
        definitions = {
            godLoot = copyList(definitions and definitions.godLoot),
            rewardStores = definitions and definitions.rewardStores or {},
            shops = definitions and definitions.shops or {},
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
