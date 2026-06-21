local parser = {}

local function shallowCopy(source)
    local copy = {}
    for key, value in pairs(source or {}) do
        copy[key] = value
    end
    return copy
end

local function keyLookup(items)
    local lookup = {}
    for _, item in ipairs(items or {}) do
        lookup[item.key] = true
    end
    return lookup
end

local function indexByKey(items)
    local lookup = {}
    for _, item in ipairs(items or {}) do
        lookup[item.key] = item
    end
    return lookup
end

local function defaultBossRooms(biomeKey)
    return {
        { key = tostring(biomeKey) .. "_Boss01", label = "Boss" },
        { key = tostring(biomeKey) .. "_Boss02", label = "Boss Alternate" },
    }
end

local function withReward(baseOptions, rewardOptions, reward)
    local rewardKeys = keyLookup(rewardOptions)
    local options = {}
    for index, option in ipairs(baseOptions or {}) do
        if rewardKeys[option.key] then
            local copy = shallowCopy(option)
            copy.reward = reward
            options[index] = copy
        else
            options[index] = option
        end
    end
    return options
end

local function standardTimeline(biomeKey, opts)
    opts = opts or {}
    return {
        defaultRoomHistoryCost = opts.defaultRoomHistoryCost or 1,
        roomHistoryCostBySlotKind = opts.roomHistoryCostBySlotKind,
        afterBiome = {
            {
                key = "Boss",
                label = "Boss",
                roomOptions = opts.bossRooms or defaultBossRooms(biomeKey),
                roomHistoryCost = opts.bossRoomHistoryCost or 1,
            },
            {
                key = "PostBoss",
                label = "Post-Boss",
                roomKey = opts.postBossRoomKey or (tostring(biomeKey) .. "_PostBoss01"),
                roomHistoryCost = opts.postBossRoomHistoryCost or 1,
                features = opts.postBossFeatures,
            },
        },
    }
end

local function normalize(definition)
    definition.rolesByKey = indexByKey(definition.roles)
    definition.slotLayout.special = definition.slotLayout.special or {}
    return definition
end

function parser.create(deps)
    deps = deps or {}

    local instance = {}

    function instance.withReward(baseOptions, rewardOptions, reward)
        return withReward(baseOptions, rewardOptions, reward)
    end

    function instance.standardTimeline(biomeKey, opts)
        return standardTimeline(biomeKey, opts)
    end

    function instance.normalize(definition)
        return normalize(definition)
    end

    function instance.declarationDeps()
        return {
            parser = instance,
            rewards = deps.rewards,
            routeRules = deps.routeRules,
        }
    end

    return instance
end

return parser
