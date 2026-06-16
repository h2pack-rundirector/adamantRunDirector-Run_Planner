local data = {}

local REWARD_SLOT_COUNT = 6

local function shallowCopyList(source)
    local copy = {}
    for index, value in ipairs(source or {}) do
        copy[index] = value
    end
    return copy
end

local function optionListForRole(role)
    if type(role) ~= "table" then
        return {}
    end
    return role.roomOptions or role.mapOptions or {}
end

local function buildLookup(items)
    local lookup = {}
    for _, item in ipairs(items or {}) do
        if item.key ~= nil then
            lookup[item.key] = item
        end
    end
    return lookup
end

local function addChoice(values, labels, key, label)
    values[#values + 1] = key
    labels[key] = label or key
end

local function shouldOfferAutoOption(role, options)
    if #options == 0 then
        return false
    end
    if #options == 1 and role.roomOptions ~= nil then
        return false
    end
    return true
end

local function buildRoleChoices(instance)
    instance.roleValues = {}
    instance.roleLabels = {}
    instance.optionValuesByRole = {}
    instance.optionLabelsByRole = {}

    for _, role in ipairs(instance.roles or {}) do
        addChoice(instance.roleValues, instance.roleLabels, role.key, role.label)

        local options = optionListForRole(role)
        local optionValues = {}
        local optionLabels = {}
        if shouldOfferAutoOption(role, options) then
            optionValues[#optionValues + 1] = ""
            optionLabels[""] = "Auto"
        end
        for _, option in ipairs(options) do
            addChoice(optionValues, optionLabels, option.key, option.label)
        end
        role.defaultOptionKey = optionValues[1] or ""
        instance.optionValuesByRole[role.key] = optionValues
        instance.optionLabelsByRole[role.key] = optionLabels
    end
end

local function buildRouteSlots(instance)
    local slotLayout = instance.biome.slotLayout or {}
    local startDepth = math.floor(tonumber(slotLayout.routeStartDepth) or 1)
    local endDepth = math.floor(tonumber(slotLayout.routeEndDepth) or startDepth)
    if endDepth < startDepth then
        endDepth = startDepth
    end

    instance.routeSlots = {}
    for depth = startDepth, endDepth do
        local rowIndex = #instance.routeSlots + 1
        instance.routeSlots[rowIndex] = {
            rowIndex = rowIndex,
            coordinate = depth,
            label = "Depth " .. tostring(depth),
        }
    end
    instance.routeRowCount = #instance.routeSlots
end

local function buildRewardRows()
    local rows = {
        { key = "RoleKey", type = "string", default = "Vanilla", maxLen = 32 },
        { key = "OptionKey", type = "string", default = "", maxLen = 64 },
        { key = "VariantKey", type = "string", default = "", maxLen = 64 },
    }

    for index = 1, REWARD_SLOT_COUNT do
        rows[#rows + 1] = {
            key = "Reward" .. tostring(index) .. "Key",
            type = "string",
            default = "",
            maxLen = 96,
        }
    end
    return rows
end

function data.prepare(instance)
    instance.biome = instance.biome or {}
    instance.biomeKey = instance.biome.key or instance.biomeKey or instance.name
    instance.label = instance.label or instance.biome.label or instance.biomeKey
    instance.roles = shallowCopyList(instance.biome.roles)
    instance.rolesByKey = buildLookup(instance.roles)
    for _, role in ipairs(instance.roles) do
        role.optionsByKey = buildLookup(optionListForRole(role))
    end

    buildRouteSlots(instance)
    buildRoleChoices(instance)
    return instance
end

function data.storage(instance)
    return {
        {
            key = "Rows",
            type = "table",
            minRows = instance.routeRowCount,
            defaultRows = instance.routeRowCount,
            maxRows = instance.routeRowCount,
            row = buildRewardRows(),
        },
    }
end

function data.optionListForRole(role)
    return optionListForRole(role)
end

data.REWARD_SLOT_COUNT = REWARD_SLOT_COUNT

return data
