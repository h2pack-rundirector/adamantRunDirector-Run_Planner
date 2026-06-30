-- luacheck: no unused args

local deps = ...
local data = deps.data
local common = deps.common
local rewardSystem = deps.rewards
local rewardRatio = deps.rewardRatio
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

local function historyRewardValueStates(instance, rowIndex, rewardAddress, controlAlias)
    if instance.routeContext ~= nil and instance.routeContext.historyValueStates ~= nil then
        return instance.routeContext:historyValueStates(
            instance.routeKey,
            instance.biomeKey,
            rowIndex,
            controlAlias,
            rewardAddress
        )
    end
    return nil
end

local function completionStatus(status)
    if status ~= nil and not status.valid and form.isCompletionInvalid(status) then
        return status
    end
    return common.validStatus()
end

local function formValidation(instance, routeRows, rowIndex)
    return form.validateRoomChoice({
        data = data,
        instance = instance,
        rows = routeRows,
        rowIndex = rowIndex,
    })
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
    end
end

local function rebuildRewardRatio(control, fields, instance)
    local summary = rewardRatio.createSummary(instance)
    if summary == nil then
        return nil
    end

    for rowIndex = 1, control:rowCount() do
        rewardRatio.countSurface(
            summary,
            rewardSystem,
            control:rewardSurface(rowIndex),
            rewardSystem.fields(fields.Rewards, rowIndex)
        )
    end
    return rewardRatio.finish(summary)
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

    function control:historyRewardValueStates(rowIndex, rewardAddress, controlAlias)
        return historyRewardValueStates(instance, rowIndex, rewardAddress, controlAlias)
    end

    function control:rewardRatioSummary()
        local version = instance.rewardRatioVersion or 0
        if instance.rewardRatioCacheBuilt ~= true or instance.rewardRatioCacheVersion ~= version then
            instance.rewardRatioCacheBuilt = true
            instance.rewardRatioCacheVersion = version
            instance.rewardRatioSummary = rebuildRewardRatio(self, fields, instance)
        end
        return instance.rewardRatioSummary
    end

    function control:rewardsConfigured()
        return common == nil or common.rewardsConfigured(instance)
    end

    function control:rowValidation(rowIndex)
        local validation = formValidation(instance, routeRows, rowIndex)
        if not validation.valid then
            return validation
        end

        local topologyInvalid = data.validateRoomTopology(instance, routeRows, rowIndex)
        if form.isCompletionInvalid(topologyInvalid) then
            return topologyInvalid
        end

        return completionStatus(validation)
    end

    function control:beginReadPass()
        data.beginReadPass(instance)
    end

    function control:invalidateReadPass()
        data.invalidateReadPass(instance)
        rewardRatio.invalidate(instance)
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

        local roleKey = fields.Rooms:read(rowIndex, "RoleKey") or ""
        local optionKey = fields.Rooms:read(rowIndex, "OptionKey") or ""
        if slot.roleKey ~= nil then
            roleKey = slot.roleKey
            local _, option = data.resolveOption(instance, routeRows, rowIndex, roleKey)
            optionKey = option and option.key or optionKey
        end

        local siblings = {}
        for siblingIndex = 1, data.maxSiblingStructureCount(instance) do
            siblings[siblingIndex] = {
                structureKey = fields.Rooms:read(rowIndex, data.siblingStructureAlias(instance, siblingIndex)) or "",
            }
        end

        local siblingRewards = {}
        for siblingIndex = 1, data.maxSiblingStructureCount(instance) do
            siblingRewards[siblingIndex] = {
                rewardClassKey = fields.Rewards:read(rowIndex, data.siblingRewardClassAlias(instance, siblingIndex)) or "",
            }
        end

        return {
            rowIndex = rowIndex,
            roleKey = roleKey,
            optionKey = optionKey,
            variantKey = fields.Rooms:read(rowIndex, "VariantKey") or "",
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
                sibling = siblingRewards,
            },
        }
    end

    function control:buildSelectedRowsSnapshot()
        local rows = {}
        for rowIndex = 1, self:rowCount() do
            rows[#rows + 1] = self:selectedRowSnapshot(rowIndex)
        end
        return {
            schema = "selectedRows.v1",
            routeKey = instance.routeKey,
            controlName = instance.name,
            biomeKey = instance.biomeKey,
            adapter = instance.biome.adapter,
            rows = rows,
        }
    end

    local function buildCompletionReport(self)
        local completionInvalidRows = {}
        self:beginReadPass()
        for rowIndex = 1, self:rowCount() do
            local validation = self:rowValidation(rowIndex)
            if form.isCompletionInvalid(validation) then
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
                    locationLabel = form.locations.biomeRow(instance, row),
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
