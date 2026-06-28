local storage = {}

storage.SLOT_COUNT = 6
storage.PREBOSS_BRANCH_ALIAS = "PrebossBranchKey"

function storage.stateAlias(index)
    return "Reward" .. tostring(index) .. "StateKey"
end

function storage.rewardAlias(index)
    return "Reward" .. tostring(index) .. "Key"
end

function storage.lootAlias(index)
    return "Reward" .. tostring(index) .. "LootKey"
end

function storage.isAlias(alias)
    return type(alias) == "string"
        and (
            string.match(alias, "^Reward%d+.*Key$") ~= nil
            or alias == storage.PREBOSS_BRANCH_ALIAS
            or string.match(alias, "^Sibling%d*RewardClassKey$") ~= nil
        )
end

function storage.buildRows()
    local rows = {}

    for index = 1, storage.SLOT_COUNT do
        rows[#rows + 1] = {
            key = storage.rewardAlias(index),
            type = "string",
            default = "",
            maxLen = 96,
        }
    end
    for index = 1, storage.SLOT_COUNT do
        rows[#rows + 1] = {
            key = storage.lootAlias(index),
            type = "string",
            default = "",
            maxLen = 96,
        }
    end
    for index = 1, storage.SLOT_COUNT do
        rows[#rows + 1] = {
            key = storage.stateAlias(index),
            type = "string",
            default = "Skipped",
            maxLen = 96,
        }
    end
    rows[#rows + 1] = {
        key = storage.PREBOSS_BRANCH_ALIAS,
        type = "string",
        default = "",
        maxLen = 32,
    }
    return rows
end

function storage.readRewards(rewardRows, rowIndex)
    local rewards = {}
    for index = 1, storage.SLOT_COUNT do
        rewards[index] = rewardRows:read(rowIndex, storage.rewardAlias(index)) or ""
    end
    return rewards
end

function storage.readRewardLoot(rewardRows, rowIndex)
    local loot = {}
    for index = 1, storage.SLOT_COUNT do
        loot[index] = rewardRows:read(rowIndex, storage.lootAlias(index)) or ""
    end
    return loot
end

function storage.readRewardStates(rewardRows, rowIndex)
    local states = {}
    for index = 1, storage.SLOT_COUNT do
        states[index] = rewardRows:read(rowIndex, storage.stateAlias(index)) or ""
    end
    return states
end

function storage.fields(rewardRows, rowIndex, aliasMapper)
    return {
        read = function(_, alias)
            if aliasMapper ~= nil then
                alias = aliasMapper(alias)
            end
            return rewardRows:read(rowIndex, alias)
        end,
    }
end

function storage.resetRows(rewardRows, rowIndex, aliasMapper)
    for index = 1, storage.SLOT_COUNT do
        local rewardAlias = storage.rewardAlias(index)
        local lootAlias = storage.lootAlias(index)
        if aliasMapper ~= nil then
            rewardAlias = aliasMapper(rewardAlias)
            lootAlias = aliasMapper(lootAlias)
        end
        local stateAlias = storage.stateAlias(index)
        if aliasMapper ~= nil then
            stateAlias = aliasMapper(stateAlias)
        end
        rewardRows:reset(rowIndex, rewardAlias)
        rewardRows:reset(rowIndex, lootAlias)
        rewardRows:reset(rowIndex, stateAlias)
    end
    local branchAlias = storage.PREBOSS_BRANCH_ALIAS
    if aliasMapper ~= nil then
        branchAlias = aliasMapper(branchAlias)
    end
    rewardRows:reset(rowIndex, branchAlias)
end

return storage
