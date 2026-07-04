-- luacheck: no unused args

local deps = ...
local data = deps.data
local common = deps.common
local rewardSystem = deps.rewards
local sideRoomProbability = deps.sideRoomProbability
local form = deps.form
local formAddress = import("mods/route/history/form_address.lua")

local runtime = {}
local EMPTY_LIST = {}

local function sideRewardFields(rewardRows, rowIndex, sideIndex)
    return rewardSystem.fields(rewardRows, rowIndex, function(alias)
        return data.sideRoomRewardAlias(sideIndex, alias)
    end)
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
            sideRoomProbability.countSideDoor(
                summary,
                fields.Rooms:read(rowIndex, data.sideRoomModeAlias(sideIndex)) or ""
            )
        end
    end
    return sideRoomProbability.finish(summary)
end

local function formValidation(instance, routeRows, rowIndex)
    return form.validateRoomChoice({
        data = data,
        instance = instance,
        rows = routeRows,
        rowIndex = rowIndex,
    })
end

local function readSideRewards(rewardRows, rowIndex, sideIndex)
    local rewards = {}
    for index = 1, rewardSystem.SLOT_COUNT do
        rewards[index] = rewardRows:read(rowIndex, data.sideRoomRewardAlias(sideIndex, rewardSystem.rewardAlias(index))) or ""
    end
    return rewards
end

local function readSideRewardLoot(rewardRows, rowIndex, sideIndex)
    local loot = {}
    for index = 1, rewardSystem.SLOT_COUNT do
        loot[index] = rewardRows:read(rowIndex, data.sideRoomRewardAlias(sideIndex, rewardSystem.lootAlias(index))) or ""
    end
    return loot
end

local function sideRoomEncounterClass(instance, rows, rowIndex, sideIndex, sideDoor, enabled)
    local storedKey, resolvedKey = data.resolveSideRoomEncounterClass(instance, rows, rowIndex, sideIndex, sideDoor)
    if not enabled then
        return storedKey, nil
    end
    return storedKey, resolvedKey
end

local function sideRoomMode(rows, rowIndex, sideIndex)
    local mode = rows:read(rowIndex, data.sideRoomModeAlias(sideIndex)) or ""
    if mode == "" then
        return "", data.sideRoomDisabledMode()
    end
    return mode, mode
end

local function sideRoomLabel(sideIndex)
    return "Side " .. tostring(sideIndex)
end

local function sideRoomAddress(sideIndex)
    return "side:" .. tostring(sideIndex)
end

local function sideRoomEncounterClassValidation(instance, fields, rowIndex, sideIndex, sideDoor)
    local values = data.sideRoomEncounterClassValues(instance, sideDoor)
    local storedKey = fields.Rooms:read(rowIndex, data.sideRoomEncounterClassAlias(sideIndex)) or ""
    if values[2] ~= nil and storedKey == "" then
        return form.invalid({
            code = "side_room_encounter_class_required",
            message = "Choose " .. sideRoomLabel(sideIndex) .. " encounter difficulty",
            tabKey = "rooms",
            controlAlias = data.sideRoomEncounterClassAlias(sideIndex),
            label = sideRoomLabel(sideIndex) .. " encounter difficulty",
        })
    end
    if storedKey ~= "" then
        for _, value in ipairs(values) do
            if storedKey == value then
                return nil
            end
        end
        return form.invalid({
            code = "unknown_side_room_encounter_class",
            message = "Unknown " .. sideRoomLabel(sideIndex) .. " encounter difficulty: " .. tostring(storedKey),
            tabKey = "rooms",
            controlAlias = data.sideRoomEncounterClassAlias(sideIndex),
            label = sideRoomLabel(sideIndex) .. " encounter difficulty",
        })
    end
    return nil
end

local function sideRoomRewardValidation(sideDoor, fields, rowIndex, sideIndex)
    local surface = rewardSurfaceForContext(sideDoor.reward)
    local _, selectionRequirements = rewardSystem.snapshot(surface, sideRewardFields(fields.Rewards, rowIndex, sideIndex))
    local requirement = selectionRequirements[1]
    if requirement == nil then
        return nil
    end
    return form.invalid({
        code = "side_room_reward_required",
        message = "Choose " .. sideRoomLabel(sideIndex) .. " reward",
        tabKey = "rewards",
        address = sideRoomAddress(sideIndex),
        controlAlias = requirement.controlAlias,
        label = requirement.label or sideRoomLabel(sideIndex) .. " reward",
    })
end

local function sideRoomValidation(instance, fields, routeRows, rowIndex, sideIndex)
    local sideDoor = data.sideDoorForRow(instance, routeRows, rowIndex, sideIndex)
    if sideDoor == nil then
        return nil
    end
    local mode = fields.Rooms:read(rowIndex, data.sideRoomModeAlias(sideIndex)) or ""
    if mode ~= data.sideRoomEnabledMode() then
        return nil
    end
    if fields.Rooms:read(rowIndex, data.sideRoomEnteredAlias(sideIndex)) ~= true then
        return nil
    end

    local encounterClassInvalid = sideRoomEncounterClassValidation(instance, fields, rowIndex, sideIndex, sideDoor)
    if encounterClassInvalid ~= nil then
        return encounterClassInvalid
    end

    if common.rewardsConfigured(instance) then
        return sideRoomRewardValidation(sideDoor, fields, rowIndex, sideIndex)
    end
    return nil
end

local function sideRoomsValidation(instance, fields, routeRows, rowIndex)
    for sideIndex = 1, data.sideDoorCountForRow(instance, routeRows, rowIndex) do
        local invalid = sideRoomValidation(instance, fields, routeRows, rowIndex, sideIndex)
        if invalid ~= nil then
            return invalid
        end
    end
    return nil
end

local function sideRoomSnapshot(instance, fields, rowIndex, sideIndex, sideDoor, rewardsConfigured)
    local storedMode, mode = sideRoomMode(fields.Rooms, rowIndex, sideIndex)
    local enabled = storedMode == data.sideRoomEnabledMode()
    local entered = enabled and fields.Rooms:read(rowIndex, data.sideRoomEnteredAlias(sideIndex)) == true
    local storedEncounterClassKey, encounterClassKey =
        sideRoomEncounterClass(instance, fields.Rooms, rowIndex, sideIndex, sideDoor, entered)
    return {
        sideIndex = sideIndex,
        formAddress = formAddress.child(rowIndex, "sideRoom", sideIndex),
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
        rewards = rewardsConfigured and readSideRewards(fields.Rewards, rowIndex, sideIndex) or EMPTY_LIST,
        rewardLoot = rewardsConfigured and readSideRewardLoot(fields.Rewards, rowIndex, sideIndex) or EMPTY_LIST,
    }
end

local function sideRoomSnapshots(instance, fields, routeRows, rowIndex, rewardsConfigured)
    local sideRooms = {}
    for sideIndex = 1, data.sideDoorCountForRow(instance, routeRows, rowIndex) do
        local sideDoor = data.sideDoorForRow(instance, routeRows, rowIndex, sideIndex)
        if sideDoor ~= nil then
            sideRooms[#sideRooms + 1] = sideRoomSnapshot(instance, fields, rowIndex, sideIndex, sideDoor, rewardsConfigured)
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
        local validation = formValidation(instance, routeRows, rowIndex)
        if not validation.valid then
            return validation
        end
        return sideRoomsValidation(instance, fields, routeRows, rowIndex) or validation
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

    local function currentRoomNode(self, rowIndex)
        local slot = self:slot(rowIndex)
        if slot == nil then
            return nil
        end

        local selection = form.selectedRoomSnapshotChoice({
            data = data,
            instance = instance,
            rows = routeRows,
            rowIndex = rowIndex,
            slot = slot,
        })

        return {
            roleKey = selection.roleKey,
            optionKey = selection.optionKey,
            variantKey = fields.Rooms:read(rowIndex, "VariantKey") or "",
            roomKey = selection.option and selection.option.key or slot.roomKey,
            hubDoorId = selection.option and selection.option.hubDoorId or slot.hubDoorId,
            formAddress = formAddress.row(rowIndex),
        }
    end

    local function rewardNode(rowIndex)
        return {
            row = {
                values = rewardSystem.readRewards(fields.Rewards, rowIndex),
                loot = rewardSystem.readRewardLoot(fields.Rewards, rowIndex),
                states = rewardSystem.readRewardStates(fields.Rewards, rowIndex),
                branchKey = fields.Rewards:read(rowIndex, rewardSystem.PREBOSS_BRANCH_ALIAS) or "",
            },
        }
    end

    function control:selectedNodeSnapshot(rowIndex)
        local slot = self:slot(rowIndex)
        if slot == nil then
            return nil
        end

        return {
            rowIndex = rowIndex,
            routeOrdinal = slot.routeOrdinal,
            slotKind = slot.kind or "biomeRow",
            slotLabel = slot.label,
            isBiomeEntry = slot.isBiomeEntry == true,
            currentRoom = currentRoomNode(self, rowIndex),
            sideRooms = sideRoomSnapshots(instance, fields, routeRows, rowIndex, self:rewardsConfigured()),
            topology = {
                hub = slot.kind == "biomeRow" and hubTopology(instance) or nil,
            },
            rewards = rewardNode(rowIndex),
        }
    end

    function control:buildSelectedNodesSnapshot()
        local nodes = {}
        self:beginReadPass()
        for rowIndex = 1, self:rowCount() do
            nodes[#nodes + 1] = self:selectedNodeSnapshot(rowIndex)
        end
        self:endReadPass()
        return {
            schema = "selectedNodes.v1",
            routeKey = instance.routeKey,
            controlName = instance.name,
            biomeKey = instance.biomeKey,
            adapter = instance.biome.adapter,
            hub = hubTopology(instance),
            nodes = nodes,
        }
    end

    local function buildCompletionReport(self)
        local completionInvalidRows = {}
        self:beginReadPass()
        for rowIndex = 1, self:rowCount() do
            local slot = self:slot(rowIndex)
            if form.shouldValidateCompletionSlot(slot) then
                local validation = self:rowValidation(rowIndex)
                if form.isCompletionInvalid(validation) then
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
                        locationLabel = form.locations.biomeRow(instance, row),
                        code = validation.code,
                        message = validation.message,
                        completion = true,
                        tabKey = validation.tabKey,
                        controlTargets = validation.controlTargets,
                        valueTargets = validation.valueTargets,
                    }
                    completionInvalidRows[#completionInvalidRows + 1] = invalidRow
                end
            end
        end
        self:endReadPass()
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
        elseif path == "selectedNodesSnapshot" then
            return self:buildSelectedNodesSnapshot()
        end
        return nil
    end

    return control
end

return runtime
