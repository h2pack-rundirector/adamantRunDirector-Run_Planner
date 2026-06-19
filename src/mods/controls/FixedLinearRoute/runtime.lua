-- luacheck: no unused args

local deps = ...
local data = deps.data
local common = deps.common
local rewardRuntime = deps.rewardRuntime

local runtime = {}
local EMPTY_LIST = {}

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

local function rewardValidation(surface, rewardRows, rowIndex)
    if rewardRuntime == nil or rewardRuntime.validate == nil then
        return nil
    end
    if surface == nil
        or surface.uniqueOfferGroups == nil
        or surface.uniqueOfferGroups[1] == nil
    then
        return nil
    end
    return rewardRuntime.validate(surface, rewardFields(rewardRows, rowIndex))
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
        for _, branch in ipairs(slot.branches or {}) do
            prewarmRewardSurface(branch)
        end
    end
end

local function selectedRoomKey(slot, option)
    if option ~= nil and option.key ~= nil and option.key ~= "" then
        return option.key
    end
    return slot and slot.roomKey or nil
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

    function control:rewardsConfigured()
        return common == nil or common.rewardsConfigured(instance)
    end

    function control:rowValidation(rowIndex)
        local roleKey, role = data.resolveRole(instance, routeRows, rowIndex)
        local _, option = data.resolveOption(instance, routeRows, rowIndex, roleKey)
        local validation = data.validateRow(instance, routeRows, rowIndex)
        if not validation.valid then
            return validation
        end
        if not self:rewardsConfigured() then
            return validation
        end

        local surface = rewardSurface(role, option)
        local rewardInvalid = rewardValidation(surface, fields.Rewards, rowIndex)
        if rewardInvalid ~= nil and not rewardInvalid.valid then
            return rewardInvalid
        end
        return validation
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
        local rewardsConfigured = self:rewardsConfigured()
        local surface = rewardsConfigured and rewardSurface(role, option) or nil
        local validation = self:rowValidation(rowIndex)
        local context = data.rowContext(instance, routeRows, rowIndex)
        return {
            rowIndex = rowIndex,
            coordinate = slot.coordinate,
            biomeDepthCache = context.biomeDepthCache,
            biomeEncounterDepth = context.biomeEncounterDepth,
            biomeEncounterDepthCost = context.biomeEncounterDepthCost,
            slotKind = slot.kind or "route",
            roomKey = selectedRoomKey(slot, option),
            branchKey = slot.branchKey,
            slotLabel = slot.label,
            roomHistoryCost = slot.roomHistoryCost,
            roomHistoryIdentity = slot.roomHistoryIdentity,
            roleKey = roleKey,
            role = role,
            optionKey = optionKey,
            option = option,
            features = data.rowFeatures(slot, role, option),
            valid = validation.valid,
            invalidCode = validation.code,
            invalidReason = validation.message,
            variantKey = fields.Rooms:read(rowIndex, "VariantKey") or "",
            rewards = rewardsConfigured and readRewards(fields.Rewards, rowIndex) or EMPTY_LIST,
            rewardLoot = rewardsConfigured and readRewardLoot(fields.Rewards, rowIndex) or EMPTY_LIST,
            rewardKind = rewardsConfigured and (surface and surface.kind or "none") or "vanilla",
            rewardPicks = rewardsConfigured
                and rewardRuntime
                and rewardRuntime.snapshot(surface, rewardFields(fields.Rewards, rowIndex))
                or EMPTY_LIST,
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
        self:endReadPass()
        return {
            controlName = instance.name,
            biomeKey = instance.biomeKey,
            adapter = instance.biome.adapter,
            valid = invalidRows[1] == nil,
            disabled = invalidRows[1] ~= nil,
            invalidRows = invalidRows,
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
