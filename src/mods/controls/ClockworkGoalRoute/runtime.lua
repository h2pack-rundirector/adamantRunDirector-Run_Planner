-- luacheck: no unused args

local deps = ...
local data = deps.data
local common = deps.common
local rewardSystem = deps.rewards
local rewardItems = deps.rewardItems
local roomStructure = deps.roomStructure
local invalidLocations = deps.invalidLocations
local controlRequirements = deps.controlRequirements

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

local function rewardSurface(instance, rows, rowIndex, role, option)
    if rewardSystem == nil or role == nil then
        return nil
    end
    return rewardSystem.surfaceFor(data.rewardContext(instance, rows, rowIndex, role, option))
end

local function routeRewardValidation(instance, rowIndex)
    if instance.routeContext ~= nil and instance.routeContext.rewardRowValidation ~= nil then
        return instance.routeContext:rewardRowValidation(instance.routeKey, instance.biomeKey, rowIndex)
    end
    return nil
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

local function rowRoomKey(slot, option)
    if option ~= nil and option.key ~= nil and option.key ~= "" then
        return option.key
    end
    return slot and slot.roomKey or nil
end

local function roomOptions(slot)
    local options = {}
    for index, option in ipairs(slot and slot.roomOptions or {}) do
        options[index] = {
            key = option.key,
            label = option.label,
        }
    end
    return options
end

local function selectedRoomKey(slot, option)
    if option ~= nil and option.key ~= nil and option.key ~= "" then
        return option.key
    end
    return slot and slot.roomKey or nil
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
        return rewardSurface(instance, routeRows, rowIndex, role, self:option(rowIndex))
    end

    function control:rewardsConfigured()
        return common == nil or common.rewardsConfigured(instance)
    end

    function control:rowValidation(rowIndex)
        local validation = data.validateRow(instance, routeRows, rowIndex)
        if not validation.valid then
            return validation
        end

        local topologyInvalid = data.validateRoomTopology(instance, routeRows, rowIndex)
        if topologyInvalid ~= nil and not topologyInvalid.valid then
            return topologyInvalid
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
        local surface = rewardsConfigured and rewardSurface(instance, routeRows, rowIndex, role, option) or nil
        local context = data.rowContext(instance, routeRows, rowIndex)
        local rewards = rewardsConfigured and rewardSystem.readRewards(fields.Rewards, rowIndex) or EMPTY_LIST
        local rewardLoot = rewardsConfigured and rewardSystem.readRewardLoot(fields.Rewards, rowIndex) or EMPTY_LIST
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
            roomKey = rowRoomKey(slot, option),
            exitCount = roomStructure.exitCount(slot, role, option),
            rewardExitCount = roomStructure.rewardExitCount(slot, role, option),
            roomOptions = roomOptions(slot),
            slotLabel = slot.label,
            roomHistoryCost = context.roomHistoryCost,
            roomHistoryIdentity = slot.roomHistoryIdentity,
            roleKey = roleKey,
            role = role,
            optionKey = optionKey,
            option = option,
            features = data.rowFeatures(slot, role, option),
            countsGoal = data.rowCountsGoal(instance, routeRows, rowIndex, role, option),
            countsNonGoalReward = data.rowCountsNonGoalReward(instance, routeRows, rowIndex, role, option),
            valid = validation.valid,
            invalidCode = validation.code,
            invalidReason = validation.message,
            invalidTabKey = validation.tabKey,
            invalidControlTargets = validation.controlTargets,
            invalidValueTargets = validation.valueTargets,
            invalidCompletion = validation.completion == true,
            variantKey = fields.Rooms:read(rowIndex, "VariantKey") or "",
            rewards = rewards,
            rewardLoot = rewardLoot,
            rewardKind = rewardsConfigured and (surface and surface.kind or "none") or "vanilla",
            rewardConstraints = surface and surface.rewardConstraints or nil,
            roomTopology = data.roomTopology(instance, routeRows, rowIndex),
            rewardPicks = rewardPicks,
            selectionRequirements = selectionRequirements,
        }
        return rewardItems.attach(row)
    end

    function control:selectedRowSnapshot(rowIndex)
        local slot = self:slot(rowIndex)
        if slot == nil then
            return nil
        end

        local roleKey, role = data.resolveRole(instance, routeRows, rowIndex)
        local optionKey, option = data.resolveOption(instance, routeRows, rowIndex, roleKey)
        if slot.roleKey ~= nil then
            roleKey = slot.roleKey
            optionKey = selectedRoomKey(slot, option) or optionKey
        end

        local siblings = {}
        for siblingIndex = 1, data.maxSiblingStructureCount(instance) do
            siblings[siblingIndex] = {
                structureKey = fields.Rooms:read(rowIndex, data.siblingStructureAlias(instance, siblingIndex)) or "",
            }
        end

        return {
            rowIndex = rowIndex,
            roleKey = roleKey,
            optionKey = optionKey,
            variantKey = fields.Rooms:read(rowIndex, "VariantKey") or "",
            routeKindKey = data.readRouteKind(instance, routeRows, rowIndex),
            nonGoalKindKey = data.readNonGoalKind(instance, routeRows, rowIndex),
            state = {
                inactive = data.isInactiveRouteRow(instance, routeRows, rowIndex) == true,
                priorGoals = data.priorGoalCount(instance, routeRows, rowIndex),
                countsGoal = data.rowCountsGoal(instance, routeRows, rowIndex, role, option),
                countsNonGoalReward = data.rowCountsNonGoalReward(instance, routeRows, rowIndex, role, option),
            },
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
        for rowIndex = 1, self:rowCount() do
            rows[#rows + 1] = self:selectedRowSnapshot(rowIndex)
        end
        local goalCount = data.countGoals(instance, routeRows)
        local nonGoalCount = data.countNonGoals(instance, routeRows)
        local storyCount = data.countStories(instance, routeRows)
        self:endReadPass()
        return {
            schema = "selectedRows.v1",
            routeKey = instance.routeKey,
            controlName = instance.name,
            biomeKey = instance.biomeKey,
            adapter = instance.biome.adapter,
            clockwork = {
                goalCount = goalCount,
                requiredGoals = data.requiredGoals(instance),
                nonGoalRewardCount = nonGoalCount,
                maxNonGoalRewards = data.maxNonGoalRewards(instance),
                storyCount = storyCount,
            },
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
        local goalCount = data.countGoals(instance, routeRows)
        local nonGoalCount = data.countNonGoals(instance, routeRows)
        local storyCount = data.countStories(instance, routeRows)
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
            clockwork = {
                goalCount = goalCount,
                requiredGoals = data.requiredGoals(instance),
                nonGoalRewardCount = nonGoalCount,
                maxNonGoalRewards = data.maxNonGoalRewards(instance),
                storyCount = storyCount,
            },
        }
    end

    function control:read(path, ...)
        if path == "completion" then
            return buildCompletionReport(self)
        elseif path == "selectedRowsSnapshot" then
            return self:buildSelectedRowsSnapshot()
        elseif path == "row" then
            return self:rowSnapshot(...)
        end
        return nil
    end

    return control
end

return runtime
