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

local function sideRewardPicks(surface, sideRewardRows, sideRowIndex)
    local picks = rewardSystem and rewardSystem.snapshot(surface, sideRewardFields(sideRewardRows, sideRowIndex)) or {}
    for _, pick in ipairs(picks) do
        pick.storageAlias = pick.alias
    end
    return picks
end

local function sideRoomSnapshot(fields, sideRowIndex, sideIndex, sideDoor, rewardsConfigured)
    local storedMode, mode = sideRoomMode(fields.SideRooms, sideRowIndex)
    local enabled = storedMode == data.sideRoomEnabledMode()
    local surface = rewardsConfigured and enabled and rewardSurfaceForContext(sideDoor.reward) or nil
    return {
        sideIndex = sideIndex,
        doorId = sideDoor.doorId,
        roomKey = sideDoor.roomKey,
        modeKey = mode,
        storedModeKey = storedMode,
        enabled = enabled,
        features = sideDoor.features,
        rewardStore = sideDoor.reward and sideDoor.reward.rewardStore or nil,
        rewards = rewardsConfigured and readSideRewards(fields.SideRewards, sideRowIndex) or EMPTY_LIST,
        rewardLoot = rewardsConfigured and readSideRewardLoot(fields.SideRewards, sideRowIndex) or EMPTY_LIST,
        rewardKind = rewardsConfigured and (surface and surface.kind or "none") or "vanilla",
        rewardPicks = rewardsConfigured and enabled and sideRewardPicks(surface, fields.SideRewards, sideRowIndex)
            or EMPTY_LIST,
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

local function collectPylonRewardItems(rows)
    local items = {}
    local rowItems = {}
    for _, row in ipairs(rows or {}) do
        if row ~= nil and row.valid and row.slotKind == "biomeRow" then
            for _, item in ipairs(rewardItems.collectBySource(row, "row", rowItems)) do
                items[#items + 1] = item
            end
        end
    end
    return items
end

local function applyOfferGroups(instance, rows, invalidRows, seenInvalids)
    if rewardOfferRules == nil or rewardOfferGroups == nil then
        return
    end

    local groupKey = instance.biome
        and instance.biome.hub
        and instance.biome.hub.offerGroup
    local group = rewardOfferRules.groupForScope(rewardOfferGroups, groupKey, "biome.pylonRows")
    if group == nil then
        return
    end

    for _, invalid in ipairs(rewardOfferRules.validateOffer(group, collectPylonRewardItems(rows))) do
        local row = rows[invalid.rowIndex]
        if row ~= nil and row.valid then
            row.valid = false
            row.invalidCode = invalid.code
            row.invalidReason = invalid.message
        end
        invalid.locationLabel = invalid.locationLabel or invalidLocations.biomeRow(instance, row, "Rewards")
        appendInvalidRow(invalidRows, seenInvalids, invalid)
    end
end

local function sideRoomSnapshots(instance, fields, routeRows, rowIndex, rewardsConfigured)
    local sideRooms = {}
    for sideIndex = 1, data.sideDoorCountForRow(instance, routeRows, rowIndex) do
        local sideDoor = data.sideDoorForRow(instance, routeRows, rowIndex, sideIndex)
        local sideRowIndex = data.sideRoomRowIndex(instance, rowIndex, sideIndex)
        if sideDoor ~= nil and sideRowIndex ~= nil then
            sideRooms[#sideRooms + 1] = sideRoomSnapshot(fields, sideRowIndex, sideIndex, sideDoor, rewardsConfigured)
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
        local validation = self:rowValidation(rowIndex)
        local rewardsConfigured = self:rewardsConfigured()
        local surface = rewardsConfigured and rewardSurface(role, option) or nil
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
            hubDoorId = option and option.hubDoorId or slot.hubDoorId,
            sideDoors = option and option.sideDoors or slot.sideDoors,
            sideRooms = sideRoomSnapshots(instance, fields, routeRows, rowIndex, rewardsConfigured),
            valid = validation.valid,
            invalidCode = validation.code,
            invalidReason = validation.message,
            variantKey = fields.Rooms:read(rowIndex, "VariantKey") or "",
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
