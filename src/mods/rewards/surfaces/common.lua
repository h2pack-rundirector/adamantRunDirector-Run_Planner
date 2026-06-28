local storage = import("mods/rewards/storage.lua")

local common = {}

common.storage = storage
common.MAJOR_VALUE = "Major"
common.MINOR_VALUE = "Minor"

local OPTION_SOURCE_KEYS = {
    "rewardStores",
    "shopOptionSets",
}

function common.copyList(source)
    local copy = {}
    for index, value in ipairs(source or {}) do
        copy[index] = value
    end
    return copy
end

function common.lookupList(values)
    if values == nil then
        return nil
    end

    local lookup = {}
    for _, value in ipairs(values) do
        lookup[value] = true
    end
    return lookup
end

function common.rewardTypeLookup(values)
    local lookup = common.lookupList(values)
    return lookup
end

function common.isOnlyEligible(values, expected)
    if values == nil or values[1] == nil then
        return false
    end
    return values[1] == expected and values[2] == nil
end

function common.addOption(values, labels, key, label)
    if key == nil then
        return
    end
    values[#values + 1] = key
    labels[key] = label or key
end

function common.displayLabel(rewardDomain, key)
    if key == nil or key == "" then
        return "Unresolved"
    end

    local primitive = rewardDomain.primitives and rewardDomain.primitives[key]
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

function common.optionSource(rewardDomain, optionSetName)
    for _, sourceKey in ipairs(OPTION_SOURCE_KEYS) do
        local optionSet = rewardDomain[sourceKey][optionSetName]
        if optionSet ~= nil then
            return optionSet
        end
    end
    return nil
end

function common.optionsFor(rewardDomain, optionSetName)
    local optionSet = common.optionSource(rewardDomain, optionSetName)
    if optionSet ~= nil then
        return optionSet.options or {}
    end
    return {}
end

function common.optionsLabel(rewardDomain, optionSetName, fallback)
    local optionSet = common.optionSource(rewardDomain, optionSetName)
    if optionSet ~= nil and optionSet.label ~= nil then
        return optionSet.label
    end
    return fallback
end

function common.uniqueNames(items, eligible, ineligible, labelFor)
    local values = {}
    local labels = {}
    local seen = {}
    labelFor = labelFor or function(name)
        return common.displayLabel({ primitives = {} }, name)
    end

    for _, name in ipairs(items or {}) do
        if name ~= nil
            and seen[name] == nil
            and (eligible == nil or eligible[name])
            and (ineligible == nil or not ineligible[name])
        then
            seen[name] = true
            common.addOption(values, labels, name, labelFor(name))
        end
    end
    return values, labels
end

function common.rewardOptionLabel(rewardDomain, name)
    return common.displayLabel(rewardDomain, name)
end

function common.godSourceOptions(rewardDomain)
    local values = {}
    local labels = {}
    for _, lootName in ipairs(rewardDomain.godLoot or {}) do
        common.addOption(values, labels, lootName, common.rewardOptionLabel(rewardDomain, lootName))
    end
    return values, labels
end

function common.dropdown(alias, key, label, values, labels, opts)
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
        sourceIndex = opts.sourceIndex,
        rewardAddress = opts.rewardAddress,
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

return common
