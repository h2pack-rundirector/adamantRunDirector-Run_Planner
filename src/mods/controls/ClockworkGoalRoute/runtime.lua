-- luacheck: no unused args

local deps = ...
local data = deps.data
local common = deps.common
local rewardSystem = deps.rewards
local form = deps.form

local runtime = {}

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

local function rewardSurface(instance, rows, rowIndex, role, option)
    if rewardSystem == nil or role == nil then
        return nil
    end
    return rewardSystem.surfaceFor(data.rewardContext(instance, rows, rowIndex, role, option))
end

local function prewarmRewardSurface(instance, routeRows, rowIndex, role, option)
    rewardSurface(instance, routeRows, rowIndex, role, option)
end

local function prewarmRewardSurfaces(instance)
    local routeRows = {
        read = function()
            return ""
        end,
    }
    for _, role in ipairs(instance.roles or {}) do
        prewarmRewardSurface(instance, routeRows, 1, role)
        for _, option in ipairs(data.optionListForRole(role)) do
            prewarmRewardSurface(instance, routeRows, 1, role, option)
        end
    end
    for _, slot in ipairs(instance.routeSlots or {}) do
        prewarmRewardSurface(instance, routeRows, slot.rowIndex or 1, slot.role)
    end
end

local function selectedRoomKey(slot, option)
    if option ~= nil and option.key ~= nil and option.key ~= "" then
        return option.key
    end
    return slot and slot.roomKey or nil
end

local function formValidation(instance, routeRows, rowIndex)
    local slot = data.slotForRow(instance, rowIndex)
    if data.isRouteSlot(slot)
        and data.readRouteKind(instance, routeRows, rowIndex) == "NonGoal"
        and data.readNonGoalKind(instance, routeRows, rowIndex) == ""
    then
        return form.invalid({
            code = "role_required",
            message = "Choose a non-goal room",
            tabKey = "rooms",
            controlAlias = data.nonGoalKindAlias(),
            label = "Non-goal room",
        })
    end
    return form.validateRoomChoice({
        data = data,
        instance = instance,
        rows = routeRows,
        rowIndex = rowIndex,
        roleAlias = data.routeKindAlias(),
        optionAlias = data.optionAlias(),
    })
end

local function rowInactiveAfter(inactiveAfterRowIndex, rowIndex)
    return inactiveAfterRowIndex ~= nil
        and rowIndex ~= nil
        and rowIndex > inactiveAfterRowIndex
end

function runtime.create(fields, instance)
    prewarmRewardSurfaces(instance)
    local routeRows = createRouteRows(fields)
    local localInactiveAfterDirty = true
    local localInactiveAfterRowIndex = nil
    local function localInactiveAfter()
        if localInactiveAfterDirty then
            localInactiveAfterRowIndex = data.inactiveAfterRowIndex(instance, routeRows)
            localInactiveAfterDirty = false
        end
        return localInactiveAfterRowIndex
    end
    instance.localRowInactive = function(rowIndex)
        return rowInactiveAfter(localInactiveAfter(), rowIndex)
    end

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
        local role = self:role(rowIndex)
        return rewardSurface(instance, routeRows, rowIndex, role, self:option(rowIndex))
    end

    function control:rewardsConfigured()
        return common == nil or common.rewardsConfigured(instance)
    end

    function control:localInactiveAfterRowIndex()
        return localInactiveAfter()
    end

    function control:rowInactive(rowIndex)
        return rowInactiveAfter(self:localInactiveAfterRowIndex(), rowIndex)
    end

    function control:rowValidation(rowIndex)
        local validation = formValidation(instance, routeRows, rowIndex)
        if not validation.valid then
            return validation
        end

        if data.readRouteKind(instance, routeRows, rowIndex) ~= "Preboss"
            and form.shouldValidateCompletionTopology(self:slot(rowIndex), self:slot(rowIndex + 1))
        then
            local topologyInvalid = data.validateRoomTopology(instance, routeRows, rowIndex)
            if topologyInvalid ~= nil and not topologyInvalid.valid then
                return topologyInvalid
            end
        end

        return validation
    end

    function control:beginReadPass()
        localInactiveAfter()
        data.beginReadPass(instance)
    end

    function control:invalidateReadPass()
        localInactiveAfterDirty = true
        data.invalidateReadPass(instance)
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
        if slot.roleKey ~= nil then
            roleKey = slot.roleKey
            optionKey = selectedRoomKey(slot, option) or optionKey
        end

        local siblings = {}
        for siblingIndex = 1, data.maxSiblingStructureCount(instance) do
            if data.shouldDrawSiblingStructure(instance, routeRows, rowIndex, siblingIndex) then
                siblings[siblingIndex] = {
                    structureKey = fields.Rooms:read(rowIndex, data.siblingStructureAlias(instance, siblingIndex)) or "",
                }
            end
        end

        return {
            rowIndex = rowIndex,
            roleKey = roleKey,
            optionKey = optionKey,
            variantKey = fields.Rooms:read(rowIndex, "VariantKey") or "",
            routeKindKey = data.readRouteKind(instance, routeRows, rowIndex),
            nonGoalKindKey = data.readNonGoalKind(instance, routeRows, rowIndex),
            topology = {
                siblings = siblings,
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
        local inactiveAfterRowIndex = self:localInactiveAfterRowIndex()
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
            inactiveAfterRowIndex = inactiveAfterRowIndex,
            rows = rows,
        }
    end

    local function buildCompletionReport(self)
        local completionInvalidRows = {}
        self:beginReadPass()
        local inactiveAfterRowIndex = self:localInactiveAfterRowIndex()
        for rowIndex = 1, self:rowCount() do
            local slot = self:slot(rowIndex)
            if not rowInactiveAfter(inactiveAfterRowIndex, rowIndex)
                and form.shouldValidateCompletionSlot(slot)
            then
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
            inactiveAfterRowIndex = inactiveAfterRowIndex,
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
