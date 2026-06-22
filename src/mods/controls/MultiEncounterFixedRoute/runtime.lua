-- luacheck: no unused args

local deps = ...
local data = deps.data
local common = deps.common
local rewardSystem = deps.rewards
local rewardItems = deps.rewardItems
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

local function rewardSurface(role, option)
    if rewardSystem == nil or role == nil then
        return nil
    end
    return rewardSystem.surfaceFor(rewardContext(role, option))
end

local function rewardValidation(surface, rewardRows, rowIndex)
    if rewardSystem == nil or rewardSystem.validate == nil then
        return nil
    end
    if surface == nil
        or surface.uniqueValueGroups == nil
        or surface.uniqueValueGroups[1] == nil
    then
        return nil
    end
    return rewardSystem.validate(surface, rewardSystem.fields(rewardRows, rowIndex))
end

local function routeRewardValidation(instance, rowIndex)
    if instance.routeContext ~= nil and instance.routeContext.rewardRowValidation ~= nil then
        return instance.routeContext:rewardRowValidation(instance.routeKey, instance.biomeKey, rowIndex)
    end
    return nil
end

local function rewardSurfaceForContext(context)
    if rewardSystem == nil then
        return nil
    end
    return rewardSystem.surfaceFor(context)
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
    for _, policy in pairs(instance.encounterPoliciesByKey or {}) do
        for _, leg in ipairs(policy.rewardLegs or {}) do
            rewardSurfaceForContext(leg.reward)
        end
    end
end

local function selectedRoomKey(slot, option)
    if option ~= nil and option.key ~= nil and option.key ~= "" then
        return option.key
    end
    return slot and slot.roomKey or nil
end

local function encounterRewardPicks(surface, encounterRewardRows, encounterRewardRowIndex)
    local picks = rewardSystem
        and rewardSystem.snapshot(surface, rewardSystem.fields(encounterRewardRows, encounterRewardRowIndex))
        or {}
    for _, pick in ipairs(picks) do
        pick.storageAlias = pick.alias
    end
    return picks
end

local function encounterRewardLegSnapshot(fields, instance, rowIndex, legIndex, leg, rewardsConfigured)
    local encounterRewardRowIndex = data.encounterRewardRowIndex(instance, rowIndex, legIndex)
    if leg == nil then
        return nil
    end
    local surface = rewardsConfigured and rewardSurfaceForContext(leg.reward) or nil
    if encounterRewardRowIndex == nil then
        return nil
    end
    return {
        legIndex = legIndex,
        key = leg.key,
        label = leg.label,
        rewards = rewardsConfigured and rewardSystem.readRewards(fields.EncounterRewards, encounterRewardRowIndex)
            or EMPTY_LIST,
        rewardLoot = rewardsConfigured and rewardSystem.readRewardLoot(fields.EncounterRewards, encounterRewardRowIndex)
            or EMPTY_LIST,
        rewardKind = rewardsConfigured and (surface and surface.kind or "none") or "vanilla",
        rewardPicks = rewardsConfigured
            and encounterRewardPicks(surface, fields.EncounterRewards, encounterRewardRowIndex)
            or EMPTY_LIST,
    }
end

local function encounterRewardLegSnapshots(fields, instance, routeRows, rowIndex, rewardsConfigured)
    if not rewardsConfigured then
        return EMPTY_LIST
    end

    local snapshots = {}
    for legIndex = 1, data.encounterRewardLegCountForRow(instance, routeRows, rowIndex) do
        local leg = data.encounterRewardLegForRow(instance, routeRows, rowIndex, legIndex)
        local snapshot = encounterRewardLegSnapshot(fields, instance, rowIndex, legIndex, leg, rewardsConfigured)
        if snapshot ~= nil then
            snapshots[#snapshots + 1] = snapshot
        end
    end
    return snapshots
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
        if instance.rewardDrawChanged == nil then
            instance.rewardDrawChanged = function()
                self:invalidateReadPass()
            end
        end
        instance.rewardDrawOpts.hideGenericRewardLabel = baseOpts and baseOpts.hideGenericRewardLabel
        instance.rewardDrawOpts.godSource = self:godSource()
        instance.rewardDrawOpts.valueStatesForControl = rewardSystem.routeValueStatesForControl(instance)
        instance.rewardDrawOpts.onControlChanged = instance.rewardDrawChanged
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
        if role ~= nil and role.encounterPolicy ~= nil then
            return nil
        end
        return rewardSurface(role, self:option(rowIndex))
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

        local surface = role ~= nil and role.encounterPolicy == nil and rewardSurface(role, option) or nil
        local rewardInvalid = rewardValidation(surface, fields.Rewards, rowIndex)
        if rewardInvalid ~= nil and not rewardInvalid.valid then
            return rewardInvalid
        end
        rewardInvalid = routeRewardValidation(instance, rowIndex)
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
        local variantKey, variant = data.resolveVariant(instance, routeRows, rowIndex, roleKey)
        local validation = self:rowValidation(rowIndex)
        local rewardsConfigured = self:rewardsConfigured()
        local encounterRewardLegs = encounterRewardLegSnapshots(fields, instance, routeRows, rowIndex, rewardsConfigured)
        local surface = rewardsConfigured and role ~= nil and role.encounterPolicy == nil and rewardSurface(role, option) or nil
        local context = data.rowContext(instance, routeRows, rowIndex)
        local row = {
            rowIndex = rowIndex,
            routeOrdinal = slot.routeOrdinal,
            biomeDepthCache = context.biomeDepthCache,
            biomeDepthCacheCost = context.biomeDepthCacheCost,
            biomeEncounterDepth = context.biomeEncounterDepth,
            biomeEncounterDepthMin = context.biomeEncounterDepthMin,
            biomeEncounterDepthMax = context.biomeEncounterDepthMax,
            biomeEncounterDepthCost = context.biomeEncounterDepthCost,
            biomeEncounterDepthCostMin = context.biomeEncounterDepthCostMin,
            biomeEncounterDepthCostMax = context.biomeEncounterDepthCostMax,
            slotKind = slot.kind or "biomeRow",
            isBiomeEntry = slot.isBiomeEntry == true,
            roomKey = selectedRoomKey(slot, option),
            branchKey = slot.branchKey,
            slotLabel = slot.label,
            roomHistoryCost = context.roomHistoryCost,
            roomHistoryIdentity = slot.roomHistoryIdentity,
            roleKey = roleKey,
            role = role,
            optionKey = optionKey,
            option = option,
            features = data.rowFeatures(slot, role, option),
            valid = validation.valid,
            invalidCode = validation.code,
            invalidReason = validation.message,
            variantKey = variantKey,
            variant = variant,
            encounterPolicyKey = role and role.encounterPolicy or nil,
            realCombatCount = variant and variant.realCombatCount or nil,
            encounterRewardLegs = encounterRewardLegs,
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
        self:beginReadPass()
        for rowIndex = 1, self:rowCount() do
            local row = self:rowSnapshot(rowIndex)
            rows[#rows + 1] = row
            if row ~= nil and not row.valid then
                invalidRows[#invalidRows + 1] = {
                    rowIndex = row.rowIndex,
                    routeOrdinal = row.routeOrdinal,
                    locationLabel = invalidLocations.biomeRow(instance, row),
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
