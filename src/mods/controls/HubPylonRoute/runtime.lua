-- luacheck: no unused args

local deps = ...
local data = deps.data
local common = deps.common
local rewardSystem = deps.rewards
local sideRoomProbability = deps.sideRoomProbability
local invalidLocations = deps.invalidLocations
local controlRequirements = deps.controlRequirements

local runtime = {}
local EMPTY_LIST = {}

local function sideRewardAlias(alias)
    return data.sideRoomRewardAlias(nil, alias)
end

local function sideRewardFields(sideRewardRows, sideRowIndex)
    return rewardSystem.fields(sideRewardRows, sideRowIndex, sideRewardAlias)
end

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

local function hubTopology(instance)
    return instance.biome.roomTopology.hub
end

local function prewarmRewardSurface(role, option)
    rewardSurface(role, option)
end

local function prewarmRewardSurfaces(instance)
    for _, role in ipairs(instance.roles or {}) do
        prewarmRewardSurface(role)
        for _, option in ipairs(data.optionListForRole(role)) do
            prewarmRewardSurface(role, option)
            for _, sideDoor in ipairs(option.sideDoors or {}) do
                rewardSurfaceForContext(sideDoor.reward)
            end
        end
    end
    for _, slot in ipairs(instance.routeSlots or {}) do
        prewarmRewardSurface(slot.role)
        for _, option in ipairs(data.optionListForRole(slot.role)) do
            prewarmRewardSurface(slot.role, option)
        end
    end
end

local function rebuildSideRoomProbability(control, fields, instance)
    local summary = sideRoomProbability.createSummary(instance)
    if summary == nil then
        return nil
    end

    for rowIndex = 1, control:rowCount() do
        for sideIndex = 1, data.sideDoorCountForRow(instance, control:routeRows(), rowIndex) do
            local sideRowIndex = data.sideRoomRowIndex(instance, rowIndex, sideIndex)
            sideRoomProbability.countSideDoor(
                summary,
                sideRowIndex and fields.SideRooms:read(sideRowIndex, data.sideRoomModeAlias()) or ""
            )
        end
    end
    return sideRoomProbability.finish(summary)
end

local function selectedRoomKey(slot, option)
    if option ~= nil and option.key ~= nil then
        return option.key
    end
    return slot and slot.roomKey or nil
end

local function readSideRewards(sideRewardRows, sideRowIndex)
    local rewards = {}
    for index = 1, rewardSystem.SLOT_COUNT do
        rewards[index] = sideRewardRows:read(sideRowIndex, sideRewardAlias(rewardSystem.rewardAlias(index))) or ""
    end
    return rewards
end

local function readSideRewardLoot(sideRewardRows, sideRowIndex)
    local loot = {}
    for index = 1, rewardSystem.SLOT_COUNT do
        loot[index] = sideRewardRows:read(sideRowIndex, sideRewardAlias(rewardSystem.lootAlias(index))) or ""
    end
    return loot
end

local function sideRoomEncounterClass(instance, sideRows, sideRowIndex, sideDoor, enabled)
    local storedKey, resolvedKey = data.resolveSideRoomEncounterClass(instance, sideRows, sideRowIndex, sideDoor)
    if not enabled then
        return storedKey, nil
    end
    return storedKey, resolvedKey
end

local function sideRoomMode(sideRows, sideRowIndex)
    local mode = sideRows:read(sideRowIndex, data.sideRoomModeAlias()) or ""
    if mode == "" then
        return "", data.sideRoomDisabledMode()
    end
    return mode, mode
end

local function sideRewardPicks(surface, sideRewardRows, sideRowIndex)
    local picks = {}
    local selectionRequirements = {}
    if rewardSystem ~= nil then
        picks, selectionRequirements = rewardSystem.snapshot(surface, sideRewardFields(sideRewardRows, sideRowIndex))
    end
    for _, pick in ipairs(picks) do
        pick.storageAlias = pick.alias
    end
    for _, requirement in ipairs(selectionRequirements) do
        requirement.storageAlias = requirement.controlAlias
    end
    return picks, selectionRequirements
end

local function sideRoomSnapshot(instance, fields, sideRowIndex, sideIndex, sideDoor, rewardsConfigured)
    local storedMode, mode = sideRoomMode(fields.SideRooms, sideRowIndex)
    local enabled = storedMode == data.sideRoomEnabledMode()
    local entered = enabled and fields.SideRooms:read(sideRowIndex, data.sideRoomEnteredAlias()) == true
    local storedEncounterClassKey, encounterClassKey =
        sideRoomEncounterClass(instance, fields.SideRooms, sideRowIndex, sideDoor, entered)
    local surface = rewardsConfigured and entered and rewardSurfaceForContext(sideDoor.reward) or nil
    local rewardPicks = EMPTY_LIST
    local selectionRequirements = EMPTY_LIST
    if rewardsConfigured and entered then
        rewardPicks, selectionRequirements = sideRewardPicks(surface, fields.SideRewards, sideRowIndex)
    end
    return {
        sideIndex = sideIndex,
        doorId = sideDoor.doorId,
        roomKey = sideDoor.roomKey,
        modeKey = mode,
        storedModeKey = storedMode,
        entered = entered,
        enabled = enabled,
        encounterClassKey = encounterClassKey,
        storedEncounterClassKey = storedEncounterClassKey,
        features = sideDoor.features,
        rewardStore = sideDoor.reward and sideDoor.reward.rewardStore or nil,
        rewards = rewardsConfigured and readSideRewards(fields.SideRewards, sideRowIndex) or EMPTY_LIST,
        rewardLoot = rewardsConfigured and readSideRewardLoot(fields.SideRewards, sideRowIndex) or EMPTY_LIST,
        rewardKind = rewardsConfigured and (surface and surface.kind or "none") or "vanilla",
        rewardPicks = rewardPicks,
        selectionRequirements = selectionRequirements,
    }
end

local function sideRoomSnapshots(instance, fields, routeRows, rowIndex, rewardsConfigured)
    local sideRooms = {}
    for sideIndex = 1, data.sideDoorCountForRow(instance, routeRows, rowIndex) do
        local sideDoor = data.sideDoorForRow(instance, routeRows, rowIndex, sideIndex)
        local sideRowIndex = data.sideRoomRowIndex(instance, rowIndex, sideIndex)
        if sideDoor ~= nil and sideRowIndex ~= nil then
            sideRooms[#sideRooms + 1] =
                sideRoomSnapshot(instance, fields, sideRowIndex, sideIndex, sideDoor, rewardsConfigured)
        end
    end
    return sideRooms
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

    function control:applyRouteFeedback(feedback, generation)
        instance.routeFeedback = feedback
        instance.routeFeedbackGeneration = generation
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
        instance.rewardDrawOpts.valueStatesForControl = rewardSystem.historyValueStatesForControl(instance)
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
        return rewardSurface(self:role(rowIndex), self:option(rowIndex))
    end

    function control:sideRoomProbabilitySummary()
        local version = instance.sideRoomProbabilityVersion or 0
        if instance.sideRoomProbabilityCacheBuilt ~= true or instance.sideRoomProbabilityCacheVersion ~= version then
            instance.sideRoomProbabilityCacheBuilt = true
            instance.sideRoomProbabilityCacheVersion = version
            instance.sideRoomProbabilitySummary = rebuildSideRoomProbability(self, fields, instance)
        end
        return instance.sideRoomProbabilitySummary
    end

    function control:rewardsConfigured()
        return common == nil or common.rewardsConfigured(instance)
    end

    function control:rowValidation(rowIndex)
        local validation = data.validateRow(instance, routeRows, rowIndex)
        if not validation.valid then
            return validation
        end
        return validation
    end

    function control:beginReadPass()
        data.beginReadPass(instance)
    end

    function control:invalidateReadPass()
        data.invalidateReadPass(instance)
        sideRoomProbability.invalidate(instance)
        if instance.routeContext ~= nil and instance.routeContext.markDirty ~= nil then
            instance.routeContext:markDirty(instance.routeKey, instance.biomeKey)
        end
    end

    function control:endReadPass()
        data.endReadPass(instance)
    end

    function control:selectedRowSnapshot(rowIndex)
        local slot = self:slot(rowIndex)
        if slot == nil then
            return nil
        end

        local roleKey = data.resolveRole(instance, routeRows, rowIndex)
        local optionKey, option = data.resolveOption(instance, routeRows, rowIndex, roleKey)
        return {
            rowIndex = rowIndex,
            routeOrdinal = slot.routeOrdinal,
            slotKind = slot.kind or "biomeRow",
            slotLabel = slot.label,
            isBiomeEntry = slot.isBiomeEntry == true,
            roleKey = roleKey,
            optionKey = optionKey,
            variantKey = fields.Rooms:read(rowIndex, "VariantKey") or "",
            roomKey = selectedRoomKey(slot, option),
            hubDoorId = option and option.hubDoorId or slot.hubDoorId,
            sideRooms = sideRoomSnapshots(instance, fields, routeRows, rowIndex, self:rewardsConfigured()),
            topology = {
                hub = slot.kind == "biomeRow" and hubTopology(instance) or nil,
            },
            rewards = {
                row = {
                    values = rewardSystem.readRewards(fields.Rewards, rowIndex),
                    loot = rewardSystem.readRewardLoot(fields.Rewards, rowIndex),
                    states = rewardSystem.readRewardStates(fields.Rewards, rowIndex),
                    branchKey = fields.Rewards:read(rowIndex, rewardSystem.PREBOSS_BRANCH_ALIAS) or "",
                },
            },
        }
    end

    function control:buildSelectedRowsSnapshot()
        local rows = {}
        self:beginReadPass()
        for rowIndex = 1, self:rowCount() do
            rows[#rows + 1] = self:selectedRowSnapshot(rowIndex)
        end
        self:endReadPass()
        return {
            schema = "selectedRows.v1",
            routeKey = instance.routeKey,
            controlName = instance.name,
            biomeKey = instance.biomeKey,
            adapter = instance.biome.adapter,
            hub = hubTopology(instance),
            rows = rows,
        }
    end

    local function buildCompletionReport(self)
        local completionInvalidRows = {}
        self:beginReadPass()
        for rowIndex = 1, self:rowCount() do
            local validation = self:rowValidation(rowIndex)
            if controlRequirements.isCompletionInvalid(validation) then
                local slot = self:slot(rowIndex)
                local row = {
                    rowIndex = rowIndex,
                    routeOrdinal = slot and slot.routeOrdinal or nil,
                    slotLabel = slot and slot.label or nil,
                    invalidCode = validation.code,
                    invalidReason = validation.message,
                }
                local invalidRow = {
                    rowIndex = rowIndex,
                    routeOrdinal = row.routeOrdinal,
                    locationLabel = invalidLocations.biomeRow(instance, row),
                    code = validation.code,
                    message = validation.message,
                    tabKey = validation.tabKey,
                    controlTargets = validation.controlTargets,
                    valueTargets = validation.valueTargets,
                }
                completionInvalidRows[#completionInvalidRows + 1] = invalidRow
            end
        end
        self:endReadPass()
        instance.completionInvalidMessage = completionInvalidRows[1] ~= nil
                and ("Data incomplete: " .. tostring(completionInvalidRows[1].message or completionInvalidRows[1].code))
            or nil
        return {
            controlName = instance.name,
            biomeKey = instance.biomeKey,
            adapter = instance.biome.adapter,
            valid = completionInvalidRows[1] == nil,
            disabled = completionInvalidRows[1] ~= nil,
            completionInvalidRows = completionInvalidRows,
        }
    end

    function control:read(path, ...)
        if path == "completion" then
            return buildCompletionReport(self)
        elseif path == "selectedRowsSnapshot" then
            return self:buildSelectedRowsSnapshot()
        end
        return nil
    end

    return control
end

return runtime
