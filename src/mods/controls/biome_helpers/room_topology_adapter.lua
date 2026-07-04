local deps = ...
local common = deps.common
local readCache = deps.readCache
local roomTopology = deps.roomTopology
local roomStructure = deps.roomStructure
local valueStates = deps.valueStates
local form = deps.form

local adapter = {}

local validStatus = common.validStatus
local WARNING_STATE = valueStates and valueStates.WARNING or 3
local activeReadCache = readCache.active
local rowRecord = readCache.rowRecord
local nestedRecord = readCache.nestedRecord

local EMPTY_VALUES = {}
local EMPTY_LABELS = {}

local function indexedOtherDoorAlias(baseAlias, siblingIndex)
    siblingIndex = math.floor(tonumber(siblingIndex) or 1)
    if siblingIndex <= 1 then
        return baseAlias
    end
    local prefix = string.match(baseAlias or "", "^(.*)Key$")
    return (prefix or tostring(baseAlias or "OtherDoor")) .. tostring(siblingIndex) .. "Key"
end

local function structuralCountForRow(data, slots, instance, rows, rowIndex, field)
    local slot = slots.slotForRow(instance, rowIndex)
    local roleKey, role = data.resolveRole(instance, rows, rowIndex)
    local _, option = data.resolveOption(instance, rows, rowIndex, roleKey)
    if field == "exitCount" then
        return math.floor(tonumber(roomStructure.exitCount(slot, role, option)) or 0)
    end
    if field == "rewardBearingExitCount" then
        return math.floor(tonumber(roomStructure.rewardBearingExitCount(slot, role, option)) or 0)
    end
    return 0
end

local function appliedFeedback(instance)
    local routeContext = instance.routeContext
    if routeContext == nil or routeContext.routeGeneration == nil then
        return nil
    end
    if instance.routeFeedbackGeneration ~= routeContext:routeGeneration(instance.routeKey) then
        return nil
    end
    return instance.routeFeedback
end

local function topologyFeedback(instance, rowIndex)
    local feedback = appliedFeedback(instance)
    local row = feedback and feedback[rowIndex] or nil
    return row and row.topology or nil
end

local function maxExitCountForRole(data, role)
    local maxCount = math.floor(tonumber(roomStructure.exitCount(nil, role)) or 0)
    for _, option in ipairs(data.optionListForRole(role)) do
        local count = math.floor(tonumber(roomStructure.exitCount(nil, role, option)) or 0)
        if count > maxCount then
            maxCount = count
        end
    end
    return maxCount
end

function adapter.create(data, opts)
    local api = {}
    local slots = opts.slots

    function api.prepareOtherDoorPolicy(instance)
        instance.otherDoorPolicy = roomTopology.prepareOtherDoorPolicy(opts.topologyForInstance(instance), {
            namespace = opts.namespace,
        })
    end

    function api.prepareOtherDoorCount(instance)
        if instance.otherDoorPolicy == nil then
            instance.maxOtherDoorCount = 0
            return
        end

        local maxExitCount = 0
        for _, role in ipairs(instance.roles or EMPTY_VALUES) do
            local roleMax = maxExitCountForRole(data, role)
            if roleMax > maxExitCount then
                maxExitCount = roleMax
            end
        end
        instance.maxOtherDoorCount = roomTopology.otherDoorCountForExitCount(maxExitCount)
    end

    function api.maxOtherDoorCount(instance)
        return instance.maxOtherDoorCount or 0
    end

    function api.otherDoorAlias(instance, otherDoorIndex)
        local policy = instance.otherDoorPolicy
        local baseAlias = policy and policy.alias or "OtherDoorKey"
        if opts.indexedAliases then
            return indexedOtherDoorAlias(baseAlias, otherDoorIndex)
        end
        return baseAlias
    end

    function api.otherDoorControlTargets(instance, otherDoorIndex)
        return form.selectedTargets({
            tabKey = "rooms",
            controlAlias = api.otherDoorAlias(instance, otherDoorIndex),
            state = WARNING_STATE,
        })
    end

    function api.otherDoorLabels(instance)
        local policy = instance.otherDoorPolicy
        return policy and policy.labels or EMPTY_LABELS
    end

    function api.otherDoorValues(instance)
        local policy = instance.otherDoorPolicy
        return policy and policy.values or EMPTY_VALUES
    end

    function api.resolveOtherDoor(instance, rows, rowIndex, otherDoorIndex)
        local policy = instance.otherDoorPolicy
        if policy == nil then
            return "", nil
        end

        local key = rows and rows:read(rowIndex, api.otherDoorAlias(instance, otherDoorIndex)) or ""
        key = key or ""
        return key, policy.optionsByKey[key]
    end

    function api.otherDoorPolicyContext(instance, rows, rowIndex, otherDoorIndex)
        local roleKey, role = data.resolveRole(instance, rows, rowIndex)
        local _, option = data.resolveOption(instance, rows, rowIndex, roleKey)
        return {
            rowIndex = rowIndex,
            routeRowCount = instance.routeRowCount,
            candidateOtherDoorIndex = otherDoorIndex,
            isFixedIdentityRow = data.isFixedIdentityRow(instance, rowIndex),
            hasSelectableOtherDoor = opts.hasSelectableOtherDoor(
                instance,
                rows,
                rowIndex,
                roleKey,
                role,
                option
            ),
            structuralCountAt = function(index, field)
                return structuralCountForRow(data, slots, instance, rows, index, field)
            end,
            otherDoorAt = function(currentOtherDoorIndex)
                return data.resolveOtherDoor(instance, rows, rowIndex, currentOtherDoorIndex)
            end,
        }
    end

    function api.otherDoorTopologyStatus(instance, _rows, rowIndex)
        local policy = instance.otherDoorPolicy
        if policy == nil then
            return validStatus()
        end
        local feedback = topologyFeedback(instance, rowIndex)
        if feedback ~= nil and feedback.active == false then
            return common.invalidStatus("biome_depth_unavailable", "Other Door is not active at this biome depth")
        end
        return validStatus()
    end

    function api.otherDoorStatus(instance, _rows, rowIndex)
        local policy = instance.otherDoorPolicy
        if policy == nil then
            return validStatus()
        end
        local feedback = topologyFeedback(instance, rowIndex)
        if feedback ~= nil and feedback.controlsActive == false then
            return common.invalidStatus("biome_depth_unavailable", "Other Door is not active at this biome depth")
        end
        return validStatus()
    end

    function api.activeOtherDoorCount(instance, rows, rowIndex)
        local cache = activeReadCache(instance)
        if cache == nil then
            return roomTopology.activeOtherDoorCount(
                instance.otherDoorPolicy,
                api.otherDoorPolicyContext(instance, rows, rowIndex)
            )
        end

        cache.activeOtherDoorCounts = cache.activeOtherDoorCounts or {}
        local record = rowRecord(cache.activeOtherDoorCounts, rowIndex)
        if record.pass ~= cache.pass then
            record.pass = cache.pass
            record.value = roomTopology.activeOtherDoorCount(
                instance.otherDoorPolicy,
                api.otherDoorPolicyContext(instance, rows, rowIndex)
            )
        end
        return record.value
    end

    function api.shouldDrawOtherDoor(instance, rows, rowIndex, otherDoorIndex)
        return roomTopology.shouldDrawActiveOtherDoor(
            data.activeOtherDoorCount(instance, rows, rowIndex),
            data.otherDoorStatus(instance, rows, rowIndex),
            otherDoorIndex
        )
    end

    function api.otherDoorValueStatesForRow(instance, rows, rowIndex, otherDoorIndex)
        local cache = activeReadCache(instance)
        if cache == nil then
            return roomTopology.fillOtherDoorValueStates(
                instance.otherDoorPolicy,
                api.otherDoorPolicyContext(instance, rows, rowIndex, otherDoorIndex),
                {}
            )
        end

        cache.otherDoorValueStates = cache.otherDoorValueStates or {}
        local record
        if opts.indexedAliases then
            record = nestedRecord(cache.otherDoorValueStates, rowIndex, otherDoorIndex or 1)
        else
            record = rowRecord(cache.otherDoorValueStates, rowIndex)
        end
        if record.pass ~= cache.pass then
            record.pass = cache.pass
            record.states = record.states or {}
            roomTopology.fillOtherDoorValueStates(
                instance.otherDoorPolicy,
                api.otherDoorPolicyContext(instance, rows, rowIndex, otherDoorIndex),
                record.states
            )
        end
        return record.states
    end

    function api.validateOtherDoors(instance, rows, rowIndex, validateOpts)
        local invalid, otherDoorIndex = roomTopology.validateRequiredOtherDoors(
            instance.otherDoorPolicy,
            api.otherDoorPolicyContext(instance, rows, rowIndex),
            validateOpts
        )
        if invalid ~= nil and invalid.controlTargets == nil then
            invalid.tabKey = "rooms"
            invalid.controlTargets = api.otherDoorControlTargets(instance, otherDoorIndex)
        end
        return invalid
    end

    return api
end

return adapter
