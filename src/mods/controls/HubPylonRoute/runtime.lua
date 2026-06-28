-- luacheck: no unused args

local deps = ...
local data = deps.data
local common = deps.common
local rewardSystem = deps.rewards
local rewardItems = deps.rewardItems
local roomStructure = deps.roomStructure
local sideRoomProbability = deps.sideRoomProbability
local invalidLocations = deps.invalidLocations

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

local function hubRewardRowGroup(instance)
    local topology = hubTopology(instance)
    return topology and topology.rewardRowGroup or nil
end

local function pylonRoomTopology(instance, slot, row)
    if slot == nil or slot.kind ~= "biomeRow" then
        return nil
    end

    local topology = hubTopology(instance)
    local context = rewardContext(row.role, row.option)
    local offerCount = context ~= nil and 1 or 0
    return {
        kind = "hubDoorBatchPick",
        selected = {
            structure = row.roleKey,
            roomKey = row.roomKey,
            hubDoorId = row.hubDoorId,
            rewardStore = context and context.rewardStore or nil,
            eligibleRewardTypes = context and context.eligibleRewardTypes or nil,
            ineligibleRewardTypes = context and context.ineligibleRewardTypes or nil,
            offerCount = offerCount,
            rewardAddresses = offerCount > 0 and { "row" } or nil,
        },
        hub = {
            roomKey = topology.roomKey,
            availableDoorCount = topology.availableDoorCount,
            generatedDoorCount = topology.generatedDoorCount,
            generatedRewardExitCount = topology.generatedRewardExitCount,
            selectedDoorCount = topology.selectedDoorCount,
            effectTiming = topology.effectTiming,
            rewardRowGroup = topology.rewardRowGroup,
        },
        sideRooms = row.sideRooms,
    }
end

local function routeRewardValidation(instance, rowIndex)
    if instance.routeContext ~= nil and instance.routeContext.rewardRowValidation ~= nil then
        return instance.routeContext:rewardRowValidation(instance.routeKey, instance.biomeKey, rowIndex)
    end
    return nil
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
        local slot = control:slot(rowIndex)
        for sideIndex = 1, data.sideDoorCountForRow(instance, control:routeRows(), rowIndex) do
            local sideRowIndex = data.sideRoomRowIndex(instance, rowIndex, sideIndex)
            sideRoomProbability.countSideDoor(
                summary,
                sideRowIndex and fields.SideRooms:read(sideRowIndex, data.sideRoomModeAlias()) or "",
                slot and slot.routeOrdinal or 0
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

local function sideRoomMode(sideRows, sideRowIndex)
    local mode = sideRows:read(sideRowIndex, data.sideRoomModeAlias()) or ""
    if mode == "" then
        return "", "Vanilla"
    end
    return mode, mode
end

local function sideRoomEncounterClass(instance, sideRows, sideRowIndex, sideDoor, enabled)
    local storedKey, resolvedKey = data.resolveSideRoomEncounterClass(instance, sideRows, sideRowIndex, sideDoor)
    if not enabled then
        return storedKey, nil
    end
    return storedKey, resolvedKey
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
    local storedEncounterClassKey, encounterClassKey =
        sideRoomEncounterClass(instance, fields.SideRooms, sideRowIndex, sideDoor, enabled)
    local surface = rewardsConfigured and enabled and rewardSurfaceForContext(sideDoor.reward) or nil
    local rewardPicks = EMPTY_LIST
    local selectionRequirements = EMPTY_LIST
    if rewardsConfigured and enabled then
        rewardPicks, selectionRequirements = sideRewardPicks(surface, fields.SideRewards, sideRowIndex)
    end
    return {
        sideIndex = sideIndex,
        doorId = sideDoor.doorId,
        roomKey = sideDoor.roomKey,
        modeKey = mode,
        storedModeKey = storedMode,
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
        if not self:rewardsConfigured() then
            return validation
        end

        local rewardInvalid = routeRewardValidation(instance, rowIndex)
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
        sideRoomProbability.invalidate(instance)
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
        local validation = self:rowValidation(rowIndex)
        local rewardsConfigured = self:rewardsConfigured()
        local surface = rewardsConfigured and rewardSurface(role, option) or nil
        local context = data.rowContext(instance, routeRows, rowIndex)
        local rewardPicks = EMPTY_LIST
        local selectionRequirements = EMPTY_LIST
        if rewardsConfigured and rewardSystem ~= nil then
            rewardPicks, selectionRequirements =
                rewardSystem.snapshot(surface, rewardSystem.fields(fields.Rewards, rowIndex))
        end
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
            exitCount = roomStructure.exitCount(slot, role, option),
            rewardExitCount = roomStructure.rewardExitCount(slot, role, option),
            hubDoorId = option and option.hubDoorId or slot.hubDoorId,
            sideDoors = option and option.sideDoors or slot.sideDoors,
            sideRooms = sideRoomSnapshots(instance, fields, routeRows, rowIndex, rewardsConfigured),
            rewardRowGroup = slot.kind == "biomeRow" and hubRewardRowGroup(instance) or nil,
            valid = validation.valid,
            invalidCode = validation.code,
            invalidReason = validation.message,
            variantKey = fields.Rooms:read(rowIndex, "VariantKey") or "",
            rewards = rewardsConfigured and rewardSystem.readRewards(fields.Rewards, rowIndex) or EMPTY_LIST,
            rewardLoot = rewardsConfigured and rewardSystem.readRewardLoot(fields.Rewards, rowIndex) or EMPTY_LIST,
            rewardKind = rewardsConfigured and (surface and surface.kind or "none") or "vanilla",
            rewardConstraints = surface and surface.rewardConstraints or nil,
            rewardPicks = rewardPicks,
            selectionRequirements = selectionRequirements,
        }
        row.roomTopology = pylonRoomTopology(instance, slot, row)
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
