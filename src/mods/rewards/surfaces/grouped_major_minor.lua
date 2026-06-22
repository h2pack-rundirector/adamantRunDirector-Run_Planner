local deps = ... or {}
local common = deps.common or import("mods/rewards/surfaces/common.lua")
local storage = common.storage

local groupedMajorMinor = {}

local function sourceCount(context)
    return math.floor(tonumber(context.sourceCount or 2) or 2)
end

local function majorAlias(sourceIndex)
    return storage.rewardAlias(2 + ((sourceIndex - 1) * 2))
end

local function minorAlias(sourceIndex)
    return storage.rewardAlias(3 + ((sourceIndex - 1) * 2))
end

local function majorLootAlias(sourceIndex)
    return storage.lootAlias(2 + ((sourceIndex - 1) * 2))
end

local function sourceMembers(count, aliasFor, rewardClass)
    local members = {}
    for sourceIndex = 1, count do
        members[#members + 1] = {
            alias = aliasFor(sourceIndex),
            sourceIndex = sourceIndex,
            visibleWhen = {
                alias = storage.rewardAlias(1),
                value = rewardClass,
            },
        }
    end
    return members
end

local function boonSourceMembers(count)
    local members = {}
    for sourceIndex = 1, count do
        members[#members + 1] = {
            alias = majorLootAlias(sourceIndex),
            sourceIndex = sourceIndex,
            visibleWhen = {
                all = {
                    { alias = storage.rewardAlias(1), value = common.MAJOR_VALUE },
                    { alias = majorAlias(sourceIndex), value = "Boon" },
                },
            },
        }
    end
    return members
end

function groupedMajorMinor.create(definitions, context)
    local count = sourceCount(context)
    local majorRewardStore = context.majorRewardStore or "RunProgress"
    local minorRewardStore = context.minorRewardStore or "MetaProgress"
    local majorEligible = common.lookupList(context.majorEligibleRewardTypes or context.eligibleRewardTypes)
    local majorIneligible = common.lookupListWithDefaultBan(
        context.majorIneligibleRewardTypes or context.ineligibleRewardTypes,
        "Devotion",
        context.allowDevotion ~= true
    )
    local minorEligible = common.lookupList(context.minorEligibleRewardTypes)
    local minorIneligible = common.lookupList(context.minorIneligibleRewardTypes)
    local majorValues, majorLabels = common.uniqueNames(
        common.bundleOptions(definitions, majorRewardStore),
        majorEligible,
        majorIneligible,
        function(name)
            return common.rewardOptionLabel(definitions, name)
        end
    )
    local minorValues, minorLabels = common.uniqueNames(
        common.bundleOptions(definitions, minorRewardStore),
        minorEligible,
        minorIneligible,
        function(name)
            return common.rewardOptionLabel(definitions, name)
        end
    )
    local godValues, godLabels = common.godSourceOptions(definitions)
    local rewardClassValues = { common.VANILLA_VALUE, common.MAJOR_VALUE, common.MINOR_VALUE }
    local rewardClassLabels = {
        [common.VANILLA_VALUE] = "Vanilla",
        [common.MAJOR_VALUE] = common.bundleLabel(definitions, majorRewardStore, common.MAJOR_VALUE),
        [common.MINOR_VALUE] = common.bundleLabel(definitions, minorRewardStore, common.MINOR_VALUE),
    }
    local controls = {
        common.dropdown(
            storage.rewardAlias(1),
            "rewardClass",
            "Reward",
            rewardClassValues,
            rewardClassLabels,
            {
                kind = "rewardClass",
                controlWidth = 110,
            }
        ),
    }

    for sourceIndex = 1, count do
        controls[#controls + 1] = common.dropdown(
            majorAlias(sourceIndex),
            "Wheel" .. tostring(sourceIndex) .. "Major",
            "Wheel " .. tostring(sourceIndex),
            majorValues,
            majorLabels,
            {
                kind = "rewardType",
                controlWidth = 170,
                rewardStore = majorRewardStore,
                rowIndex = sourceIndex,
                sourceIndex = sourceIndex,
                visibleWhen = {
                    alias = storage.rewardAlias(1),
                    value = common.MAJOR_VALUE,
                },
            }
        )
        controls[#controls + 1] = common.dropdown(
            majorLootAlias(sourceIndex),
            "Wheel" .. tostring(sourceIndex) .. "MajorLoot",
            "God",
            godValues,
            godLabels,
            {
                kind = "boonSource",
                controlWidth = 170,
                rewardStore = majorRewardStore,
                rowIndex = sourceIndex,
                sourceIndex = sourceIndex,
                visibleWhen = {
                    all = {
                        { alias = storage.rewardAlias(1), value = common.MAJOR_VALUE },
                        { alias = majorAlias(sourceIndex), value = "Boon" },
                    },
                },
            }
        )
        controls[#controls + 1] = common.dropdown(
            minorAlias(sourceIndex),
            "Wheel" .. tostring(sourceIndex) .. "Minor",
            "Wheel " .. tostring(sourceIndex),
            minorValues,
            minorLabels,
            {
                kind = "rewardType",
                controlWidth = 170,
                rewardStore = minorRewardStore,
                rowIndex = sourceIndex,
                sourceIndex = sourceIndex,
                visibleWhen = {
                    alias = storage.rewardAlias(1),
                    value = common.MINOR_VALUE,
                },
            }
        )
    end

    return {
        kind = "groupedMajorMinor",
        context = context,
        majorRewardStore = majorRewardStore,
        minorRewardStore = minorRewardStore,
        sourceCount = count,
        sharedRewardClass = context.sharedRewardClass == true,
        uniqueValueGroups = {
            {
                members = sourceMembers(count, majorAlias, common.MAJOR_VALUE),
                allowDuplicateValues = {
                    Boon = true,
                },
                code = "duplicate_reward_type",
                message = "Linked major rewards cannot duplicate non-boon rewards",
            },
            {
                members = sourceMembers(count, minorAlias, common.MINOR_VALUE),
                code = "duplicate_reward_type",
                message = "Linked minor rewards cannot duplicate the same reward",
            },
            {
                members = boonSourceMembers(count),
                code = "duplicate_boon_source",
                message = "Linked boon sources must be different",
            },
        },
        controls = controls,
    }
end

return groupedMajorMinor
