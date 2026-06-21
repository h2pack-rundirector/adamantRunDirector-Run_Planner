-- luacheck: no unused args

local deps = ...
local data = deps.data
local common = deps.common
local rewardSystem = deps.rewards
local rewardItems = deps.rewardItems
local rewardOfferGroups = deps.rewardOfferGroups
local rewardOfferRules = deps.rewardOfferRules
local invalidLocations = deps.invalidLocations

local runtime = {}
local EMPTY_LIST = {}

local function createRouteRows(fields)
    return {
        read = function(_, rowIndex, alias)
            if rewardSystem.isAlias(alias) then
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
    if rewardSystem == nil then
        return nil
    end
    return rewardSystem.surfaceFor(context)
end

local function rewardSurface(role, option)
    if rewardSystem == nil or role == nil then
        return nil
    end
    return rewardSystem.surfaceFor(rewardContext(role, option))
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
    local picks = rewardSystem and rewardSystem.snapshot(surface, rewardSystem.fields(cageRewardRows, cageRewardRowIndex))
        or {}
    for _, pick in ipairs(picks) do
        pick.storageAlias = pick.alias
    end
    return picks
end

local function cageRewardSnapshot(fields, instance, rowIndex, routeOrdinal, cageIndex, leg, rewardsConfigured)
    local cageRewardRowIndex = data.cageRewardRowIndex(instance, rowIndex, cageIndex)
    if leg == nil or cageRewardRowIndex == nil then
        return nil
    end

    local surface = rewardsConfigured and rewardSurfaceForContext(leg.reward) or nil
    return {
        rowIndex = rowIndex,
        routeOrdinal = routeOrdinal,
        cageIndex = cageIndex,
        key = leg.key,
        label = leg.label,
        rewards = rewardsConfigured and rewardSystem.readRewards(fields.CageRewards, cageRewardRowIndex) or EMPTY_LIST,
        rewardLoot = rewardsConfigured and rewardSystem.readRewardLoot(fields.CageRewards, cageRewardRowIndex)
            or EMPTY_LIST,
        rewardKind = rewardsConfigured and (surface and surface.kind or "none") or "vanilla",
        rewardPicks = rewardsConfigured and cageRewardPicks(surface, fields.CageRewards, cageRewardRowIndex) or EMPTY_LIST,
    }
end

local function cageRewardSnapshots(fields, instance, routeRows, rowIndex, rewardsConfigured)
    if not rewardsConfigured then
        return EMPTY_LIST
    end

    local snapshots = {}
    local slot = instance.routeSlots and instance.routeSlots[rowIndex] or nil
    for cageIndex = 1, data.cageRewardCountForRow(instance, routeRows, rowIndex) do
        local leg = data.cageRewardLegForRow(instance, routeRows, rowIndex, cageIndex)
        local snapshot = cageRewardSnapshot(
            fields,
            instance,
            rowIndex,
            slot and slot.routeOrdinal or nil,
            cageIndex,
            leg,
            rewardsConfigured
        )
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

local function offerGroupForScope(instance, scope)
    if rewardOfferRules == nil or rewardOfferGroups == nil then
        return nil
    end

    local groupKey = instance.biome
        and instance.biome.fields
        and instance.biome.fields.offerGroup
    return rewardOfferRules.groupForScope(rewardOfferGroups, groupKey, scope)
end

local function applyOfferGroups(instance, rows, invalidRows, seenInvalids)
    local group = offerGroupForScope(instance, "row.cageRewards")
    if group == nil then
        return
    end

    local cageRewardItems = {}
    for _, row in ipairs(rows) do
        if row ~= nil and row.valid then
            for _, invalid in ipairs(rewardOfferRules.validateOffer(
                group,
                rewardItems.collectBySource(row, "cage", cageRewardItems)
            )) do
                if row.valid then
                    row.valid = false
                    row.invalidCode = invalid.code
                    row.invalidReason = invalid.message
                end
                invalid.locationLabel = invalid.locationLabel or invalidLocations.biomeRow(instance, row, "Rewards")
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

    function control:rewardsConfigured()
        return common == nil or common.rewardsConfigured(instance)
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
        local rewardsConfigured = self:rewardsConfigured()
        local surface = rewardsConfigured and role ~= nil and role.cageRewardPolicy == nil and rewardSurface(role, option) or nil
        local context = data.rowContext(instance, routeRows, rowIndex)
        local row = {
            rowIndex = rowIndex,
            routeOrdinal = slot.routeOrdinal,
            biomeDepthCache = context.biomeDepthCache,
            biomeDepthCacheCost = context.biomeDepthCacheCost,
            biomeEncounterDepth = context.biomeEncounterDepth,
            biomeEncounterDepthCost = context.biomeEncounterDepthCost,
            slotKind = slot.kind or "biomeRow",
            isBiomeEntry = slot.isBiomeEntry == true,
            slotLabel = slot.label,
            roomHistoryCost = context.roomHistoryCost,
            roomHistoryIdentity = slot.roomHistoryIdentity,
            roleKey = roleKey,
            role = role,
            optionKey = optionKey,
            option = option,
            features = data.rowFeatures(slot, role, option),
            roomKey = selectedRoomKey(slot, option),
            valid = validation.valid,
            invalidCode = validation.code,
            invalidReason = validation.message,
            variantKey = cageCountKey,
            cagePolicyKey = role and role.cageRewardPolicy or nil,
            cageRewardCountKey = cageCountKey,
            cageRewardCount = cageCount and cageCount.cageRewardCount or nil,
            cageRewards = cageRewardSnapshots(fields, instance, routeRows, rowIndex, rewardsConfigured),
            rewards = rewardsConfigured and rewardSystem.readRewards(fields.Rewards, rowIndex) or EMPTY_LIST,
            rewardLoot = rewardsConfigured and rewardSystem.readRewardLoot(fields.Rewards, rowIndex) or EMPTY_LIST,
            rewardKind = rewardsConfigured and (surface and surface.kind or "none") or "vanilla",
            rewardPicks = rewardsConfigured
                and rewardSystem
                and rewardSystem.snapshot(surface, rewardSystem.fields(fields.Rewards, rowIndex))
                or EMPTY_LIST,
        }
        return rewardItems.attach(row)
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
                    routeOrdinal = row.routeOrdinal,
                    locationLabel = invalidLocations.biomeRow(instance, row),
                    code = row.invalidCode,
                    message = row.invalidReason,
                })
            end
        end
        if self:rewardsConfigured() then
        applyOfferGroups(instance, rows, invalidRows, seenInvalids)
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
