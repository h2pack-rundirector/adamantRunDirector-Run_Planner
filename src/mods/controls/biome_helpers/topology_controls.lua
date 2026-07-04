local deps = ...
local roomTopologyAdapter = deps.roomTopologyAdapter

local topologyControls = {}

local function defaultTopologyForInstance(instance)
    return instance.biome.roomTopology
end

local function defaultSelectable()
    return true
end

local function otherDoorTopologies(data, provider, instance, rows, rowIndex)
    local otherDoors = {}
    local count = data.activeOtherDoorCount(instance, rows, rowIndex)
    for otherDoorIndex = 1, count do
        local _, otherDoor = data.resolveOtherDoor(instance, rows, rowIndex, otherDoorIndex)
        local otherDoorTopology = provider.otherDoorTopology(
            instance,
            rows,
            rowIndex,
            otherDoorIndex,
            count,
            otherDoor
        )
        if otherDoorTopology == nil then
            return nil
        end
        otherDoors[#otherDoors + 1] = otherDoorTopology
    end
    if otherDoors[1] == nil then
        return nil
    end
    return otherDoors
end

function topologyControls.create(data, provider)
    provider = provider or {}
    local shared = roomTopologyAdapter.create(data, {
        namespace = provider.namespace,
        slots = provider.slots,
        indexedAliases = provider.indexedAliases,
        topologyForInstance = provider.topologyForInstance or defaultTopologyForInstance,
        hasSelectableOtherDoor = provider.hasSelectableOtherDoor or defaultSelectable,
    })

    local api = {}

    function api.prepareOtherDoorPolicy(instance)
        return shared.prepareOtherDoorPolicy(instance)
    end

    function api.prepareOtherDoorCount(instance)
        return shared.prepareOtherDoorCount(instance)
    end

    function api.maxOtherDoorCount(instance)
        return shared.maxOtherDoorCount(instance)
    end

    function api.otherDoorAlias(instance, otherDoorIndex)
        return shared.otherDoorAlias(instance, otherDoorIndex)
    end

    function api.otherDoorLabels(instance)
        return shared.otherDoorLabels(instance)
    end

    function api.otherDoorValues(instance)
        return shared.otherDoorValues(instance)
    end

    function api.otherDoorStatus(instance, rows, rowIndex)
        return shared.otherDoorStatus(instance, rows, rowIndex)
    end

    function api.otherDoorTopologyStatus(instance, rows, rowIndex)
        return shared.otherDoorTopologyStatus(instance, rows, rowIndex)
    end

    function api.activeOtherDoorCount(instance, rows, rowIndex)
        return shared.activeOtherDoorCount(instance, rows, rowIndex)
    end

    function api.shouldDrawOtherDoor(instance, rows, rowIndex, otherDoorIndex)
        if provider.shouldDrawOtherDoor ~= nil then
            return provider.shouldDrawOtherDoor(shared, instance, rows, rowIndex, otherDoorIndex)
        end
        return shared.shouldDrawOtherDoor(instance, rows, rowIndex, otherDoorIndex)
    end

    function api.resolveOtherDoor(instance, rows, rowIndex, otherDoorIndex)
        if provider.implicitOtherDoor ~= nil then
            local implicit = provider.implicitOtherDoor(api, instance, rows, rowIndex, otherDoorIndex)
            if implicit ~= nil then
                return implicit.key, implicit
            end
        end
        return shared.resolveOtherDoor(instance, rows, rowIndex, otherDoorIndex)
    end

    function api.otherDoorValueStatesForRow(instance, rows, rowIndex, otherDoorIndex)
        return shared.otherDoorValueStatesForRow(instance, rows, rowIndex, otherDoorIndex)
    end

    function api.validateSelectedTopology(instance, rows, rowIndex)
        if provider.shouldValidateRow ~= nil and not provider.shouldValidateRow(instance, rows, rowIndex) then
            return nil
        end

        if provider.validateSelected ~= nil then
            return provider.validateSelected(instance, rows, rowIndex)
        end
        return nil
    end

    function api.validateRoomTopology(instance, rows, rowIndex)
        if provider.shouldValidateRow ~= nil and not provider.shouldValidateRow(instance, rows, rowIndex) then
            return nil
        end

        local selectedInvalid = api.validateSelectedTopology(instance, rows, rowIndex)
        if selectedInvalid ~= nil then
            return selectedInvalid
        end

        if provider.skipOtherDoorValidation ~= nil and provider.skipOtherDoorValidation(instance, rows, rowIndex) then
            return nil
        end

        local otherDoorInvalid = shared.validateOtherDoors(instance, rows, rowIndex, {
            requiredCode = provider.requiredCode,
            requiredMessage = provider.requiredMessage,
            unavailableCode = provider.unavailableCode,
            unavailableMessage = provider.unavailableMessage,
        })
        if otherDoorInvalid ~= nil then
            return otherDoorInvalid
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

        if instance.otherDoorPolicy == nil
            or (provider.isFixedIdentityRow ~= nil and provider.isFixedIdentityRow(instance, rowIndex))
            or not data.otherDoorTopologyStatus(instance, rows, rowIndex).valid
        then
            return nil
        end

        local count = data.activeOtherDoorCount(instance, rows, rowIndex)
        if count < 1 then
            return nil
        end

        local selected = provider.selectedTopology(instance, rows, rowIndex)
        local otherDoors = otherDoorTopologies(data, provider, instance, rows, rowIndex)
        if selected == nil or otherDoors == nil then
            return nil
        end

        return {
            kind = provider.topologyKind,
            picked = selected,
            selected = selected,
            otherDoors = otherDoors,
        }
    end

    function api.sharedAdapter()
        return shared
    end

    return api
end

return topologyControls
