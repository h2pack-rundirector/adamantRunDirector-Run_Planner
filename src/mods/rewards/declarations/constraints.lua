local constraints = {}

local EMPTY_LIST = {}

local DEVOTION_PAIR = {
    {
        kind = "uniqueBoonSource",
        code = "duplicate_devotion_god",
    },
}

local FIELDS_CAGE_CONSTRAINTS = {
    {
        kind = "uniqueRewardTypes",
        allow = {
            Boon = true,
        },
        code = "duplicate_reward_type",
    },
    {
        kind = "uniqueBoonSource",
        code = "duplicate_boon_source",
    },
}

local SHOP_PROFILE_CONSTRAINTS = {
    Q_WorldShop = {
        {
            kind = "uniqueRewardTypes",
            slots = { "Group1Offer1", "Group1Offer2" },
            code = "duplicate_shop_group_option",
        },
    },
}

local function copyList(items)
    local copy = {}
    for index, item in ipairs(items or EMPTY_LIST) do
        copy[index] = item
    end
    return copy
end

local function copyMap(source)
    if source == nil then
        return nil
    end
    local copy = {}
    for key, value in pairs(source) do
        if type(value) == "table" then
            copy[key] = copyMap(value)
        else
            copy[key] = value
        end
    end
    return copy
end

local function copyConstraint(source)
    local copy = {
        kind = source.kind,
        code = source.code,
    }
    if source.slots ~= nil then
        copy.slots = copyList(source.slots)
    end
    if source.sourceIndices ~= nil then
        copy.sourceIndices = copyList(source.sourceIndices)
    end
    if source.allow ~= nil then
        copy.allow = copyMap(source.allow)
    end
    return copy
end

local function copyConstraints(items)
    local copy = {}
    for index, item in ipairs(items or EMPTY_LIST) do
        copy[index] = copyConstraint(item)
    end
    return copy
end

function constraints.devotionPair()
    return copyConstraints(DEVOTION_PAIR)
end

function constraints.fieldsCages(sameExitRewardCount)
    local sourceIndices = {}
    for sameExitRewardIndex = 1, math.floor(tonumber(sameExitRewardCount) or 0) do
        sourceIndices[#sourceIndices + 1] = sameExitRewardIndex
    end

    local copied = copyConstraints(FIELDS_CAGE_CONSTRAINTS)
    for _, constraint in ipairs(copied) do
        constraint.sourceIndices = copyList(sourceIndices)
    end
    return copied
end

function constraints.shopProfile(shopProfile)
    return copyConstraints(SHOP_PROFILE_CONSTRAINTS[shopProfile])
end

return constraints
