local deps = ...
local roomTopologyAdapter = deps.roomTopologyAdapter

local topologyControls = {}

local function defaultTopologyForInstance(instance)
    return instance.biome.roomTopology
end

local function defaultSelectable()
    return true
end

local function siblingTopologies(shared, data, provider, instance, rows, rowIndex)
    local siblings = {}
    local count = data.activeSiblingStructureCount(instance, rows, rowIndex)
    for siblingIndex = 1, count do
        local _, sibling = data.resolveSiblingStructure(instance, rows, rowIndex, siblingIndex)
        if not shared.siblingAvailabilityStatus(instance, rows, rowIndex, siblingIndex, sibling).valid then
            return nil
        end

        local siblingTopology = provider.siblingTopology(instance, rows, rowIndex, siblingIndex, count, sibling)
        if siblingTopology == nil then
            return nil
        end
        siblings[#siblings + 1] = siblingTopology
    end
    if siblings[1] == nil then
        return nil
    end
    return siblings
end

function topologyControls.create(data, provider)
    provider = provider or {}
    local shared = roomTopologyAdapter.create(data, {
        namespace = provider.namespace,
        slots = provider.slots,
        indexedAliases = provider.indexedAliases,
        topologyForInstance = provider.topologyForInstance or defaultTopologyForInstance,
        hasSelectableSiblingStructure = provider.hasSelectableSiblingStructure or defaultSelectable,
        extraRuleStatus = provider.extraRuleStatus,
    })

    local api = {}

    function api.prepareSiblingStructurePolicy(instance)
        return shared.prepareSiblingStructurePolicy(instance)
    end

    function api.prepareSiblingStructureCount(instance)
        return shared.prepareSiblingStructureCount(instance)
    end

    function api.maxSiblingStructureCount(instance)
        return shared.maxSiblingStructureCount(instance)
    end

    function api.siblingStructureAlias(instance, siblingIndex)
        return shared.siblingStructureAlias(instance, siblingIndex)
    end

    function api.siblingStructureLabels(instance)
        return shared.siblingStructureLabels(instance)
    end

    function api.siblingStructureValues(instance)
        return shared.siblingStructureValues(instance)
    end

    function api.siblingStructureStatus(instance, rows, rowIndex)
        return shared.siblingStructureStatus(instance, rows, rowIndex)
    end

    function api.siblingTopologyStatus(instance, rows, rowIndex)
        return shared.siblingTopologyStatus(instance, rows, rowIndex)
    end

    function api.activeSiblingStructureCount(instance, rows, rowIndex)
        return shared.activeSiblingStructureCount(instance, rows, rowIndex)
    end

    function api.shouldDrawSiblingStructure(instance, rows, rowIndex, siblingIndex)
        if provider.shouldDrawSiblingStructure ~= nil then
            return provider.shouldDrawSiblingStructure(shared, instance, rows, rowIndex, siblingIndex)
        end
        return shared.shouldDrawSiblingStructure(instance, rows, rowIndex, siblingIndex)
    end

    function api.resolveSiblingStructure(instance, rows, rowIndex, siblingIndex)
        if provider.implicitSiblingStructure ~= nil then
            local implicit = provider.implicitSiblingStructure(api, instance, rows, rowIndex, siblingIndex)
            if implicit ~= nil then
                return implicit.key, implicit
            end
        end
        return shared.resolveSiblingStructure(instance, rows, rowIndex, siblingIndex)
    end

    function api.siblingStructureValueStatesForRow(instance, rows, rowIndex, siblingIndex)
        return shared.siblingStructureValueStatesForRow(instance, rows, rowIndex, siblingIndex)
    end

    function api.validateRoomTopology(instance, rows, rowIndex)
        if provider.shouldValidateRow ~= nil and not provider.shouldValidateRow(instance, rows, rowIndex) then
            return nil
        end

        if provider.validateSelected ~= nil then
            local invalid = provider.validateSelected(instance, rows, rowIndex)
            if invalid ~= nil then
                return invalid
            end
        end

        if provider.skipSiblingValidation ~= nil and provider.skipSiblingValidation(instance, rows, rowIndex) then
            return nil
        end

        local siblingInvalid = shared.validateSiblingStructures(instance, rows, rowIndex, {
            requiredCode = provider.requiredCode,
            requiredMessage = provider.requiredMessage,
            unavailableCode = provider.unavailableCode,
            unavailableMessage = provider.unavailableMessage,
        })
        if siblingInvalid ~= nil then
            return siblingInvalid
        end

        if provider.validateAfterSiblings ~= nil then
            return provider.validateAfterSiblings(shared, instance, rows, rowIndex)
        end
        return nil
    end

    function api.roomTopology(instance, rows, rowIndex)
        if provider.deterministicTopology ~= nil then
            local deterministic = provider.deterministicTopology(instance, rows, rowIndex)
            if deterministic ~= nil then
                return deterministic
            end
        end

        if instance.siblingStructurePolicy == nil
            or (provider.isFixedIdentityRow ~= nil and provider.isFixedIdentityRow(instance, rowIndex))
            or not data.siblingTopologyStatus(instance, rows, rowIndex).valid
        then
            return nil
        end

        local count = data.activeSiblingStructureCount(instance, rows, rowIndex)
        if count < 1 then
            return nil
        end

        local selected = provider.selectedTopology(instance, rows, rowIndex)
        local siblings = siblingTopologies(shared, data, provider, instance, rows, rowIndex)
        if selected == nil or siblings == nil then
            return nil
        end

        return {
            kind = provider.topologyKind,
            selected = selected,
            sibling = siblings[1],
            siblings = siblings,
        }
    end

    function api.sharedAdapter()
        return shared
    end

    return api
end

return topologyControls
