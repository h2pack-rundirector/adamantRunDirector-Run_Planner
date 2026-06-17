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

local function sideRewardFields(sideRewardRows, sideRowIndex)
    return {
        read = function(_, alias)
            return sideRewardRows:read(sideRowIndex, data.sideRoomRewardAlias(nil, alias))
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
    for index = 1, data.REWARD_SLOT_COUNT do
        rewards[index] = sideRewardRows:read(
            sideRowIndex,
            data.sideRoomRewardAlias(nil, "Reward" .. tostring(index) .. "Key")
        ) or ""
    end
    return rewards
end

local function readSideRewardLoot(sideRewardRows, sideRowIndex)
    local loot = {}
    for index = 1, data.REWARD_SLOT_COUNT do
        loot[index] = sideRewardRows:read(
            sideRowIndex,
            data.sideRoomRewardAlias(nil, "Reward" .. tostring(index) .. "LootKey")
        ) or ""
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
    local picks = rewardRuntime and rewardRuntime.snapshot(surface, sideRewardFields(sideRewardRows, sideRowIndex)) or {}
    for _, pick in ipairs(picks) do
        pick.storageAlias = pick.alias
    end
    return picks
end

local function sideRoomSnapshot(fields, sideRowIndex, sideIndex, sideDoor)
    local storedMode, mode = sideRoomMode(fields.SideRooms, sideRowIndex)
    local enabled = storedMode == data.sideRoomEnabledMode()
    local surface = enabled and rewardSurfaceForContext(sideDoor.reward) or nil
    return {
        sideIndex = sideIndex,
        doorId = sideDoor.doorId,
        roomKey = sideDoor.roomKey,
        modeKey = mode,
        storedModeKey = storedMode,
        enabled = enabled,
        rewardStore = sideDoor.reward and sideDoor.reward.rewardStore or nil,
        rewards = readSideRewards(fields.SideRewards, sideRowIndex),
        rewardLoot = readSideRewardLoot(fields.SideRewards, sideRowIndex),
        rewardKind = surface and surface.kind or "none",
        rewardPicks = enabled and sideRewardPicks(surface, fields.SideRewards, sideRowIndex) or {},
    }
end

local function sideRoomSnapshots(instance, fields, routeRows, rowIndex)
    local sideRooms = {}
    for sideIndex = 1, data.sideDoorCountForRow(instance, routeRows, rowIndex) do
        local sideDoor = data.sideDoorForRow(instance, routeRows, rowIndex, sideIndex)
        local sideRowIndex = data.sideRoomRowIndex(instance, rowIndex, sideIndex)
        if sideDoor ~= nil and sideRowIndex ~= nil then
            sideRooms[#sideRooms + 1] = sideRoomSnapshot(fields, sideRowIndex, sideIndex, sideDoor)
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

    function control:label()
        return instance.label
    end

    function control:rowCount()
        return fields.Rooms:count()
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
            slotKind = slot.kind or "pylonPick",
            slotLabel = slot.label,
            roleKey = roleKey,
            role = role,
            optionKey = optionKey,
            option = option,
            roomKey = selectedRoomKey(slot, option),
            hubDoorId = option and option.hubDoorId or slot.hubDoorId,
            sideDoors = option and option.sideDoors or slot.sideDoors,
            sideRooms = sideRoomSnapshots(instance, fields, routeRows, rowIndex),
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
