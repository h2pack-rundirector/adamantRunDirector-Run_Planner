local optionRewards = {}

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

function optionRewards.withReward(baseOptions, rewardOptions, reward)
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

return optionRewards
