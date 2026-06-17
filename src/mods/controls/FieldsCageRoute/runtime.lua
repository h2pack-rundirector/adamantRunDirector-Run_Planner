-- luacheck: no unused args

local deps = ...
local data = deps.data
local rewardRuntime = deps.rewardRuntime
local rewardOfferPolicies = deps.rewardOfferPolicies
local rewardOfferRules = deps.rewardOfferRules

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

local function cageRewardFields(cageRewardRows, cageRewardRowIndex)
    return {
        read = function(_, alias)
            return cageRewardRows:read(cageRewardRowIndex, alias)
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

local function rewardSurfaceForContext(context)
    if rewardRuntime == nil then
        return nil
    end
    return rewardRuntime.surfaceFor(context)
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
        for _, option in ipairs(data.optionListForRole(slot.role)) do
            prewarmRewardSurface(slot.role, option)
        end
    end
    for _, policy in pairs(instance.cagePoliciesByKey or {}) do
        for _, leg in ipairs(policy.rewardLegs or {}) do
            rewardSurfaceForContext(leg.reward)
        end
    end
end

local function selectedRoomKey(slot, option)
    if option ~= nil and option.key ~= nil then
        return option.key
    end
    return slot and slot.roomKey or nil
end

local function cageRewardPicks(surface, cageRewardRows, cageRewardRowIndex)
    local picks = rewardRuntime and rewardRuntime.snapshot(surface, cageRewardFields(cageRewardRows, cageRewardRowIndex)) or {}
    for _, pick in ipairs(picks) do
        pick.storageAlias = pick.alias
    end
    return picks
end

local function cageRewardSnapshot(fields, instance, rowIndex, coordinate, cageIndex, leg)
    local cageRewardRowIndex = data.cageRewardRowIndex(instance, rowIndex, cageIndex)
    if leg == nil or cageRewardRowIndex == nil then
        return nil
    end

    local surface = rewardSurfaceForContext(leg.reward)
    return {
        rowIndex = rowIndex,
        coordinate = coordinate,
        cageIndex = cageIndex,
        key = leg.key,
        label = leg.label,
        rewards = readRewards(fields.CageRewards, cageRewardRowIndex),
        rewardLoot = readRewardLoot(fields.CageRewards, cageRewardRowIndex),
        rewardKind = surface and surface.kind or "none",
        rewardPicks = cageRewardPicks(surface, fields.CageRewards, cageRewardRowIndex),
    }
end

local function cageRewardSnapshots(fields, instance, routeRows, rowIndex)
    local snapshots = {}
    local slot = instance.routeSlots and instance.routeSlots[rowIndex] or nil
    for cageIndex = 1, data.cageRewardCountForRow(instance, routeRows, rowIndex) do
        local leg = data.cageRewardLegForRow(instance, routeRows, rowIndex, cageIndex)
        local snapshot = cageRewardSnapshot(fields, instance, rowIndex, slot and slot.coordinate or nil, cageIndex, leg)
        if snapshot ~= nil then
            snapshots[#snapshots + 1] = snapshot
        end
    end
    return snapshots
end

local function invalidRowKey(rowIndex, code)
    return tostring(rowIndex or "") .. ":" .. tostring(code or "")
end

local function appendInvalidRow(invalidRows, seenInvalids, invalid)
    if invalid == nil or invalid.rowIndex == nil then
        return
    end

    local key = invalidRowKey(invalid.rowIndex, invalid.code)
    if seenInvalids[key] then
        return
    end
    seenInvalids[key] = true
    invalidRows[#invalidRows + 1] = invalid
end

local function policyForScope(instance, scope)
    if rewardOfferRules == nil or rewardOfferPolicies == nil then
        return nil
    end

    local policyKey = instance.biome
        and instance.biome.fields
        and instance.biome.fields.offerPolicy
    return rewardOfferRules.policyForScope(rewardOfferPolicies, policyKey, scope)
end

local function applyOfferPolicies(instance, rows, invalidRows, seenInvalids)
    local policy = policyForScope(instance, "row.cageRewards")
    if policy == nil then
        return
    end

    for _, row in ipairs(rows) do
        if row ~= nil and row.valid then
            for _, invalid in ipairs(rewardOfferRules.validateOffer(policy, row.cageRewards)) do
                if row.valid then
                    row.valid = false
                    row.invalidCode = invalid.code
                    row.invalidReason = invalid.message
                end
                appendInvalidRow(invalidRows, seenInvalids, invalid)
            end
        end
    end
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
        local role = self:role(rowIndex)
        if role ~= nil and role.cageRewardPolicy ~= nil then
            return nil
        end
        return rewardSurface(role, self:option(rowIndex))
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
        local cageCountKey, cageCount = data.resolveCageCount(instance, routeRows, rowIndex, roleKey)
        local validation = data.validateRow(instance, routeRows, rowIndex)
        local surface = role ~= nil and role.cageRewardPolicy == nil and rewardSurface(role, option) or nil
        return {
            rowIndex = rowIndex,
            coordinate = slot.coordinate,
            slotKind = slot.kind or "fieldsPick",
            slotLabel = slot.label,
            roleKey = roleKey,
            role = role,
            optionKey = optionKey,
            option = option,
            roomKey = selectedRoomKey(slot, option),
            valid = validation.valid,
            invalidCode = validation.code,
            invalidReason = validation.message,
            variantKey = cageCountKey,
            cagePolicyKey = role and role.cageRewardPolicy or nil,
            cageRewardCountKey = cageCountKey,
            cageRewardCount = cageCount and cageCount.cageRewardCount or nil,
            cageRewards = cageRewardSnapshots(fields, instance, routeRows, rowIndex),
            rewards = readRewards(fields.Rewards, rowIndex),
            rewardLoot = readRewardLoot(fields.Rewards, rowIndex),
            rewardKind = surface and surface.kind or "none",
            rewardPicks = rewardRuntime and rewardRuntime.snapshot(surface, rewardFields(fields.Rewards, rowIndex)) or {},
        }
    end

    function control:buildSnapshot()
        local rows = {}
        local invalidRows = {}
        local seenInvalids = {}
        self:beginReadPass()
        for rowIndex = 1, self:rowCount() do
            local row = self:rowSnapshot(rowIndex)
            rows[#rows + 1] = row
            if row ~= nil and not row.valid then
                appendInvalidRow(invalidRows, seenInvalids, {
                    rowIndex = row.rowIndex,
                    coordinate = row.coordinate,
                    code = row.invalidCode,
                    message = row.invalidReason,
                })
            end
        end
        applyOfferPolicies(instance, rows, invalidRows, seenInvalids)
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
