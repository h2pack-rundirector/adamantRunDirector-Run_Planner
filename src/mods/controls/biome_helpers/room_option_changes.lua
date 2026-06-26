local optionChanges = {}

local function rewardContext(role, option)
    if option ~= nil and option.reward ~= nil then
        return option.reward
    end
    return role and role.reward or nil
end

local function optionForKey(role, optionKey)
    if role == nil or optionKey == nil or optionKey == "" then
        return nil
    end
    return role.optionsByKey and role.optionsByKey[optionKey] or nil
end

function optionChanges.resetRewardsIfContextChanged(control, resetRewardDetails, rowIndex, previousOptionKey)
    local role = control:role(rowIndex)
    local previousContext = rewardContext(role, optionForKey(role, previousOptionKey))
    local currentContext = rewardContext(role, control:option(rowIndex))
    if previousContext ~= currentContext then
        resetRewardDetails(control:fields(), rowIndex)
    end
end

return optionChanges
