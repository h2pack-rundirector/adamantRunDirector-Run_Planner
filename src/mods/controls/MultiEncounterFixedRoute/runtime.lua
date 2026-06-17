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

local function encounterRewardFields(encounterRewardRows, encounterRewardRowIndex)
    return {
        read = function(_, alias)
            return encounterRewardRows:read(encounterRewardRowIndex, alias)
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

local function rewardSurfaceForContext(context)
    if rewardRuntime == nil then
        return nil
    end
    return rewardRuntime.surfaceFor(context)
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

local function encounterRewardPicks(surface, encounterRewardRows, encounterRewardRowIndex)
    local picks = rewardRuntime
        and rewardRuntime.snapshot(surface, encounterRewardFields(encounterRewardRows, encounterRewardRowIndex))
        or {}
    for _, pick in ipairs(picks) do
        pick.storageAlias = pick.alias
    end
    return picks
end

local function encounterRewardLegSnapshot(fields, instance, rowIndex, legIndex, leg)
    local encounterRewardRowIndex = data.encounterRewardRowIndex(instance, rowIndex, legIndex)
    if leg == nil then
        return nil
    end
    local surface = rewardSurfaceForContext(leg.reward)
    if encounterRewardRowIndex == nil then
        return nil
    end
    return {
        legIndex = legIndex,
        key = leg.key,
        label = leg.label,
        rewards = readRewards(fields.EncounterRewards, encounterRewardRowIndex),
        rewardLoot = readRewardLoot(fields.EncounterRewards, encounterRewardRowIndex),
        rewardKind = surface and surface.kind or "none",
        rewardPicks = encounterRewardPicks(surface, fields.EncounterRewards, encounterRewardRowIndex),
    }
end

local function encounterRewardLegSnapshots(fields, instance, routeRows, rowIndex)
    local snapshots = {}
    for legIndex = 1, data.encounterRewardLegCountForRow(instance, routeRows, rowIndex) do
        local leg = data.encounterRewardLegForRow(instance, routeRows, rowIndex, legIndex)
        local snapshot = encounterRewardLegSnapshot(fields, instance, rowIndex, legIndex, leg)
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

    function control:beginReadPass()
        data.beginReadPass(instance)
    end

    function control:invalidateReadPass()
        data.invalidateReadPass(instance)
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
        local validation = data.validateRow(instance, routeRows, rowIndex)
        local encounterRewardLegs = encounterRewardLegSnapshots(fields, instance, routeRows, rowIndex)
        local surface = role ~= nil and role.encounterPolicy == nil and rewardSurface(role, option) or nil
        return {
            rowIndex = rowIndex,
            coordinate = slot.coordinate,
            slotKind = slot.kind or "route",
            roomKey = slot.roomKey,
            branchKey = slot.branchKey,
            slotLabel = slot.label,
            roleKey = roleKey,
            role = role,
            optionKey = optionKey,
            option = option,
            valid = validation.valid,
            invalidCode = validation.code,
            invalidReason = validation.message,
            variantKey = variantKey,
            variant = variant,
            encounterPolicyKey = role and role.encounterPolicy or nil,
            realCombatCount = variant and variant.realCombatCount or nil,
            encounterRewardLegs = encounterRewardLegs,
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
