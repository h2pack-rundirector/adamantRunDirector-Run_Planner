-- luacheck: no unused args

local deps = ...
local data = deps.data
local common = deps.common
local rewardSystem = deps.rewards
local form = deps.form
local formAddress = import("mods/route/history/form_address.lua")

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
        for _, option in ipairs(data.optionListForRole(slot.role)) do
            prewarmRewardSurface(slot.role, option)
        end
    end
end

local function formValidation(instance, routeRows, rowIndex)
    return form.validateRoomChoice({
        data = data,
        instance = instance,
        rows = routeRows,
        rowIndex = rowIndex,
    })
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
        instance.rewardDrawOpts.sameExitRewardCount = baseOpts and baseOpts.sameExitRewardCount
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

    function control:sameExitRewardCount(rowIndex)
        local _, role = data.resolveRole(instance, routeRows, rowIndex)
        if role == nil or role.cageRewardPolicy == nil then
            return nil
        end
        return data.cageRewardCountForRow(instance, routeRows, rowIndex)
    end

    function control:rewardSurface(rowIndex)
        local role = self:role(rowIndex)
        if role ~= nil and role.cageRewardPolicy ~= nil and (self:sameExitRewardCount(rowIndex) or 0) <= 0 then
            return nil
        end
        return rewardSurface(role, self:option(rowIndex))
    end

    function control:rewardsConfigured()
        return common == nil or common.rewardsConfigured(instance)
    end

    function control:rowValidation(rowIndex)
        local validation = formValidation(instance, routeRows, rowIndex)
        if not validation.valid then
            return validation
        end

        local selectedTopologyInvalid = data.validateSelectedRoomTopology(instance, routeRows, rowIndex)
        if selectedTopologyInvalid ~= nil and not selectedTopologyInvalid.valid then
            return selectedTopologyInvalid
        end

        if form.shouldValidateCompletionTopology(self:slot(rowIndex), self:slot(rowIndex + 1)) then
            local topologyInvalid = data.validateRoomTopology(instance, routeRows, rowIndex)
            if topologyInvalid ~= nil and not topologyInvalid.valid then
                return topologyInvalid
            end
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
            formAddress = formAddress.row(rowIndex),
        }
    end

    local function pickedNextChoice(self, rowIndex)
        local targetRowIndex = rowIndex + 1
        local targetSlot = self:slot(targetRowIndex)
        if targetSlot == nil then
            return nil
        end

        local currentRoom = currentRoomNode(self, targetRowIndex)
        if currentRoom == nil then
            return nil
        end

        currentRoom.targetRowIndex = targetRowIndex
        currentRoom.targetRouteOrdinal = targetSlot.routeOrdinal
        currentRoom.targetSlotLabel = targetSlot.label
        return currentRoom
    end

    local function otherDoorChoices(self, rowIndex)
        local slot = self:slot(rowIndex)
        if not form.shouldValidateCompletionTopology(slot, self:slot(rowIndex + 1))
            or not data.shouldDrawOtherDoor(instance, routeRows, rowIndex)
        then
            return nil
        end

        return {
            {
                doorIndex = 1,
                structureKey = fields.Rooms:read(rowIndex, data.otherDoorAlias(instance)) or "",
                formAddress = formAddress.child(rowIndex, "otherDoor", 1),
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
            slotLabel = slot.label,
            currentRoom = currentRoomNode(self, rowIndex),
            nextChoices = {
                picked = pickedNextChoice(self, rowIndex),
                otherDoors = otherDoorChoices(self, rowIndex),
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

    function control:buildSelectedNodesSnapshot()
        local nodes = {}
        for rowIndex = 1, self:rowCount() do
            nodes[#nodes + 1] = self:selectedNodeSnapshot(rowIndex)
        end
        return {
            schema = "selectedNodes.v1",
            routeKey = instance.routeKey,
            controlName = instance.name,
            biomeKey = instance.biomeKey,
            adapter = instance.biome.adapter,
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
