-- luacheck: no unused args

local deps = ...
local data = deps.data
local rewardRuntime = deps.rewardRuntime

local runtime = {}

local function readRewards(rewardRows, rowIndex)
    local rewards = {}
    for index = 1, data.REWARD_SLOT_COUNT do
        rewards[index] = rewardRows:read(rowIndex, "Reward" .. tostring(index) .. "Key") or ""
    end
    return rewards
end

local function readRewardLoot(rewardRows, rowIndex)
    local loot = {}
    for index = 1, data.REWARD_SLOT_COUNT do
        loot[index] = rewardRows:read(rowIndex, "Reward" .. tostring(index) .. "LootKey") or ""
    end
    return loot
end

local function rewardFields(rewardRows, rowIndex)
    return {
        read = function(_, alias)
            return rewardRows:read(rowIndex, alias)
        end,
    }
end

local function createRouteRows(fields)
    return {
        read = function(_, rowIndex, alias)
            if data.isRewardAlias(alias) then
                return fields.Rewards:read(rowIndex, alias)
            end
            return fields.Rooms:read(rowIndex, alias)
        end,
    }
end

local function rewardContext(role, option)
    if role ~= nil and role.reward ~= nil and role.reward.kind == "forcedReward" then
        return role.reward
    end
    if option ~= nil and option.reward ~= nil then
        return option.reward
    end
    return role and role.reward or nil
end

local function rewardSurface(role, option)
    if rewardRuntime == nil or role == nil then
        return nil
    end
    return rewardRuntime.surfaceFor(rewardContext(role, option))
end

local function prewarmRewardSurface(role, option)
    rewardSurface(role, option)
end

local function prewarmRewardSurfaces(instance)
    for _, role in ipairs(instance.roles or {}) do
        prewarmRewardSurface(role)
        for _, option in ipairs(data.optionListForRole(role)) do
            prewarmRewardSurface(role, option)
        end
    end
    for _, slot in ipairs(instance.routeSlots or {}) do
        prewarmRewardSurface(slot.role)
    end
end

local function rowRoomKey(slot, option)
    if option ~= nil and option.key ~= nil and option.key ~= "" then
        return option.key
    end
    return slot and slot.roomKey or nil
end

local function roomOptions(slot)
    local options = {}
    for index, option in ipairs(slot and slot.roomOptions or {}) do
        options[index] = {
            key = option.key,
            label = option.label,
        }
    end
    return options
end

function runtime.create(fields, instance)
    prewarmRewardSurfaces(instance)
    local routeRows = createRouteRows(fields)

    local control = {}

    function control:name()
        return instance.name
    end

    function control:biomeKey()
        return instance.biomeKey
    end

    function control:setRouteContext(routeContext, routeKey)
        instance.routeContext = routeContext
        instance.routeKey = routeKey
    end

    function control:godSource()
        if instance.routeContext ~= nil and instance.routeContext.godSourceForRoute ~= nil then
            return instance.routeContext:godSourceForRoute(instance.routeKey)
        end
        return nil
    end

    function control:rewardDrawOpts(baseOpts)
        instance.rewardDrawOpts = instance.rewardDrawOpts or {}
        instance.rewardDrawOpts.hideGenericRewardLabel = baseOpts and baseOpts.hideGenericRewardLabel
        instance.rewardDrawOpts.godSource = self:godSource()
        return instance.rewardDrawOpts
    end

    function control:label()
        return instance.label
    end

    function control:rowCount()
        return fields.Rooms:count()
    end

    function control:routeRows()
        return routeRows
    end

    function control:slot(rowIndex)
        return instance.routeSlots[math.floor(tonumber(rowIndex) or 0)]
    end

    function control:role(rowIndex)
        local _, role = data.resolveRole(instance, routeRows, rowIndex)
        return role
    end

    function control:option(rowIndex)
        local roleKey = data.resolveRole(instance, routeRows, rowIndex)
        local _, option = data.resolveOption(instance, routeRows, rowIndex, roleKey)
        return option
    end

    function control:rewardSurface(rowIndex)
        return rewardSurface(self:role(rowIndex), self:option(rowIndex))
    end

    function control:beginReadPass()
        data.beginReadPass(instance)
    end

    function control:invalidateReadPass()
        data.invalidateReadPass(instance)
        if instance.routeContext ~= nil and instance.routeContext.markDirty ~= nil then
            instance.routeContext:markDirty(instance.routeKey, instance.biomeKey)
        end
    end

    function control:endReadPass()
        data.endReadPass(instance)
    end

    function control:rowSnapshot(rowIndex)
        local slot = self:slot(rowIndex)
        if slot == nil then
            return nil
        end

        local roleKey, role = data.resolveRole(instance, routeRows, rowIndex)
        local optionKey, option = data.resolveOption(instance, routeRows, rowIndex, roleKey)
        local validation = data.validateRow(instance, routeRows, rowIndex)
        local surface = rewardSurface(role, option)
        return {
            rowIndex = rowIndex,
            coordinate = slot.coordinate,
            routeRow = slot.routeRow,
            slotKind = slot.kind or "route",
            roomKey = rowRoomKey(slot, option),
            roomOptions = roomOptions(slot),
            slotLabel = slot.label,
            roomHistoryCost = slot.roomHistoryCost,
            roomHistoryIdentity = slot.roomHistoryIdentity,
            roleKey = roleKey,
            role = role,
            optionKey = optionKey,
            option = option,
            features = data.rowFeatures(slot, role, option),
            countsGoalReward = role ~= nil and role.countsGoalReward == true,
            countsNonGoalReward = role ~= nil and role.countsNonGoalReward == true
                or option ~= nil and option.countsNonGoalReward == true,
            valid = validation.valid,
            invalidCode = validation.code,
            invalidReason = validation.message,
            variantKey = fields.Rooms:read(rowIndex, "VariantKey") or "",
            rewards = readRewards(fields.Rewards, rowIndex),
            rewardLoot = readRewardLoot(fields.Rewards, rowIndex),
            rewardKind = surface and surface.kind or "none",
            rewardPicks = rewardRuntime and rewardRuntime.snapshot(surface, rewardFields(fields.Rewards, rowIndex)) or {},
        }
    end

    function control:buildSnapshot()
        local rows = {}
        local invalidRows = {}
        self:beginReadPass()
        for rowIndex = 1, self:rowCount() do
            local row = self:rowSnapshot(rowIndex)
            rows[#rows + 1] = row
            if row ~= nil and not row.valid then
                invalidRows[#invalidRows + 1] = {
                    rowIndex = row.rowIndex,
                    coordinate = row.coordinate,
                    code = row.invalidCode,
                    message = row.invalidReason,
                }
            end
        end
        local goalCount = data.countGoals(instance, routeRows)
        local nonGoalCount = data.countNonGoals(instance, routeRows)
        local storyCount = data.countStories(instance, routeRows)
        self:endReadPass()
        return {
            controlName = instance.name,
            biomeKey = instance.biomeKey,
            adapter = instance.biome.adapter,
            valid = invalidRows[1] == nil,
            disabled = invalidRows[1] ~= nil,
            invalidRows = invalidRows,
            clockwork = {
                goalCount = goalCount,
                requiredGoalRewards = data.requiredGoalRewards(instance),
                nonGoalRewardCount = nonGoalCount,
                maxNonGoalRewards = data.maxNonGoalRewards(instance),
                storyCount = storyCount,
            },
            rows = rows,
        }
    end

    function control:read(path, ...)
        if path == "snapshot" then
            return self:buildSnapshot()
        elseif path == "row" then
            return self:rowSnapshot(...)
        end
        return nil
    end

    return control
end

return runtime
