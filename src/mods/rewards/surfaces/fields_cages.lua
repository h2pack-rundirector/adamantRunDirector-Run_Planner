local deps = ... or {}
local roomStore = deps.roomStore or import("mods/rewards/surfaces/room_store.lua", nil, {
    common = deps.common,
})
local common = deps.common or import("mods/rewards/surfaces/common.lua")
local storage = common.storage

local fieldsCages = {}

local function sourceMembers(sourceCount, aliasFor)
    local members = {}
    for sourceIndex = 1, sourceCount do
        members[#members + 1] = {
            alias = aliasFor(sourceIndex),
            sourceIndex = sourceIndex,
        }
    end
    return members
end

local function boonSourceMembers(sourceCount)
    local members = {}
    for sourceIndex = 1, sourceCount do
        members[#members + 1] = {
            alias = storage.lootAlias(sourceIndex),
            sourceIndex = sourceIndex,
            visibleWhen = {
                alias = storage.rewardAlias(sourceIndex),
                value = "Boon",
            },
        }
    end
    return members
end

function fieldsCages.create(definitions, context)
    local sourceCount = math.floor(tonumber(context.sourceCount) or 0)
    if sourceCount <= 1 then
        return roomStore.create(definitions, context)
    end

    local rewardStore = context.rewardStore or "RunProgress"
    local rewardTypes = common.bundleOptions(definitions, rewardStore)
    local eligible = common.lookupList(context.eligibleRewardTypes)
    local ineligible = common.lookupList(context.ineligibleRewardTypes)
    local rewardValues, rewardLabels = common.uniqueNames(rewardTypes, eligible, ineligible, function(name)
        return common.rewardOptionLabel(definitions, name)
    end)
    local godValues, godLabels = common.godSourceOptions(definitions)
    local controls = {}

    for sourceIndex = 1, sourceCount do
        controls[#controls + 1] = common.dropdown(
            storage.rewardAlias(sourceIndex),
            "Cage" .. tostring(sourceIndex),
            "Cage " .. tostring(sourceIndex),
            rewardValues,
            rewardLabels,
            {
                kind = "rewardType",
                controlWidth = 170,
                rowIndex = sourceIndex,
                sourceIndex = sourceIndex,
            }
        )
        controls[#controls + 1] = common.dropdown(
            storage.lootAlias(sourceIndex),
            "Cage" .. tostring(sourceIndex) .. "Loot",
            "God",
            godValues,
            godLabels,
            {
                kind = "boonSource",
                controlWidth = 170,
                rowIndex = sourceIndex,
                sourceIndex = sourceIndex,
                visibleWhen = {
                    alias = storage.rewardAlias(sourceIndex),
                    value = "Boon",
                },
            }
        )
    end

    return {
        kind = "fieldsCages",
        context = context,
        rewardStore = rewardStore,
        sourceCount = sourceCount,
        uniqueValueGroups = {
            {
                members = sourceMembers(sourceCount, storage.rewardAlias),
                allowDuplicateValues = {
                    Boon = true,
                },
                code = "duplicate_reward_type",
                message = "Fields cage rewards cannot duplicate non-boon rewards",
            },
            {
                members = boonSourceMembers(sourceCount),
                code = "duplicate_boon_source",
                message = "Fields cage boon sources must be different",
            },
        },
        controls = controls,
    }
end

return fieldsCages
