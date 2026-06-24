-- luacheck: no unused args

local deps = ...
local godData = deps.gods
local decorations = deps.decorations

local RouteGlobal = {}

local GODS_PER_ROW = 3
local GOD_COLUMN_WIDTH = 170
local VANILLA_VALUE = ""
local CONFIGURE_REWARDS_KEY = "ConfigureRewards"
local CONFIGURE_NPCS_KEY = "ConfigureNpcs"
local CONFIGURE_FEATURES_KEY = "ConfigureFeatures"
local CONFIGURE_FEATURE_PREFIX = "ConfigureFeature"
local DISABLED_TEXT_COLOR = { 0.55, 0.55, 0.55, 1 }
local REWARDS_DISABLED_NOTE = "Disabling rewards invalidates Trial rewards and disables NPC encounter planning."

local CONFIG_TOGGLES = {
    {
        key = CONFIGURE_REWARDS_KEY,
        label = "Configure Rewards",
    },
    {
        key = CONFIGURE_NPCS_KEY,
        label = "Configure NPC Encounters",
    },
    {
        key = CONFIGURE_FEATURES_KEY,
        label = "Configure Features",
    },
}

local function clearList(list)
    for index = #list, 1, -1 do
        list[index] = nil
    end
end

local function featureConfigKey(featureKey)
    return CONFIGURE_FEATURE_PREFIX .. tostring(featureKey or "")
end

local function routeBiomeLookup(route)
    local lookup = {}
    for _, biomeKey in ipairs(route and route.biomes or {}) do
        lookup[biomeKey] = true
    end
    return lookup
end

local function routeHasFeature(routeLookup, feature)
    for biomeKey in pairs(feature and feature.biomes or {}) do
        if routeLookup[biomeKey] then
            return true
        end
    end
    return false
end

local function copyColor(color)
    if color == nil then
        return nil
    end
    return {
        color[1],
        color[2],
        color[3],
        color[4],
    }
end

local function resolveGameColor(colorKey)
    local gameGlobal = rawget(_G, "game")
    local color = gameGlobal and gameGlobal.Color and gameGlobal.Color[colorKey] or nil
    if color == nil then
        return nil
    end
    return {
        color[1] / 255,
        color[2] / 255,
        color[3] / 255,
        (color[4] or 255) / 255,
    }
end

local function copyGod(god)
    return {
        key = god.key,
        label = god.label,
        colorKey = god.colorKey,
        color = resolveGameColor(god.colorKey) or copyColor(god.color),
    }
end

local function copyGods(source)
    local copy = {}
    for index, god in ipairs(source or {}) do
        copy[index] = copyGod(god)
    end
    return copy
end

local function buildBits(gods)
    local bits = {}
    for index, god in ipairs(gods or {}) do
        bits[#bits + 1] = {
            key = god.key,
            label = god.label,
            type = "bool",
            offset = index - 1,
            width = 1,
            default = true,
        }
    end
    return bits
end

local function buildGodSourceOptions(instance)
    instance.godSourceLabels = {
        [VANILLA_VALUE] = "Vanilla",
    }
    instance.godSourceLookup = {
        [VANILLA_VALUE] = true,
    }
    instance.godSourceValuesByCurrent = {
        [VANILLA_VALUE] = {},
    }
    for _, god in ipairs(instance.gods or {}) do
        instance.godSourceLabels[god.key] = god.label
        instance.godSourceLookup[god.key] = true
        instance.godSourceValuesByCurrent[god.key] = {}
    end
    instance.godSourceDirty = true
end

local function buildFeatureConfigToggles(instance)
    local routeLookup = routeBiomeLookup(instance.route)
    instance.featureConfigToggles = {}
    instance.featureConfigKeyByKey = {}
    instance.featureConfigKeyByFeatureKey = {}

    for _, featureKey in ipairs(instance.features and instance.features.ordered or {}) do
        local feature = instance.features.byKey and instance.features.byKey[featureKey] or nil
        if feature ~= nil and routeHasFeature(routeLookup, feature) then
            local key = featureConfigKey(feature.key)
            instance.featureConfigToggles[#instance.featureConfigToggles + 1] = {
                key = key,
                label = feature.configLabel or ("Configure " .. tostring(feature.label or feature.key)),
                featureKey = feature.key,
                runtimeFeatureKey = feature.featureKey,
            }
            instance.featureConfigKeyByKey[feature.key] = key
            instance.featureConfigKeyByFeatureKey[feature.featureKey] = key
        end
    end
end

local function buildDrawLabels(instance)
    local controlName = tostring(instance.name)
    instance.configDrawLabels = {}
    instance.configDisabledLabels = {}
    for _, toggle in ipairs(CONFIG_TOGGLES) do
        local visibleLabel = tostring(toggle.label)
        instance.configDrawLabels[toggle.key] = visibleLabel .. "##" .. controlName .. ":" .. tostring(toggle.key)
        instance.configDisabledLabels[toggle.key] = {
            checked = "[x] " .. visibleLabel,
            unchecked = "[ ] " .. visibleLabel,
        }
    end
    for _, toggle in ipairs(instance.featureConfigToggles or {}) do
        local visibleLabel = tostring(toggle.label)
        instance.configDrawLabels[toggle.key] = visibleLabel .. "##" .. controlName .. ":" .. tostring(toggle.key)
        instance.configDisabledLabels[toggle.key] = {
            checked = "[x] " .. visibleLabel,
            unchecked = "[ ] " .. visibleLabel,
        }
    end

    for _, god in ipairs(instance.gods or {}) do
        god.drawLabel = tostring(god.label or god.key) .. "##" .. controlName .. ":" .. tostring(god.key)
    end
end

function RouteGlobal.prepare(instance)
    instance.route = instance.route or {}
    instance.routeKey = instance.route.key or instance.routeKey or instance.name
    instance.label = instance.label or "Global"
    instance.gods = copyGods(instance.gods or (godData and godData.olympian()) or {})
    buildFeatureConfigToggles(instance)
    instance.godBits = buildBits(instance.gods)
    buildGodSourceOptions(instance)
    buildDrawLabels(instance)
    return instance
end

function RouteGlobal.storage(instance)
    local storage = {
        {
            key = CONFIGURE_REWARDS_KEY,
            type = "bool",
            default = true,
        },
        {
            key = CONFIGURE_NPCS_KEY,
            type = "bool",
            default = true,
        },
        {
            key = CONFIGURE_FEATURES_KEY,
            type = "bool",
            default = true,
        },
    }
    for _, toggle in ipairs(instance.featureConfigToggles or {}) do
        storage[#storage + 1] = {
            key = toggle.key,
            type = "bool",
            default = true,
        }
    end
    storage[#storage + 1] = {
        key = "GodPool",
        type = "packedInt",
        width = #instance.godBits,
        bits = instance.godBits,
    }
    return storage
end

local function featureConfigFieldKey(instance, featureKey)
    return (instance.featureConfigKeyByKey and instance.featureConfigKeyByKey[featureKey])
        or (instance.featureConfigKeyByFeatureKey and instance.featureConfigKeyByFeatureKey[featureKey])
end

function RouteGlobal.createRuntime(fields, instance)
    local control = {}

    local function rebuildGodSourceValues()
        local enabled = {}
        for _, god in ipairs(instance.gods or {}) do
            enabled[god.key] = fields.GodPool:readAlias(god.key) == true
        end

        for currentValue, values in pairs(instance.godSourceValuesByCurrent or {}) do
            clearList(values)
            values[#values + 1] = VANILLA_VALUE
            for _, god in ipairs(instance.gods or {}) do
                if enabled[god.key] then
                    values[#values + 1] = god.key
                end
            end
            if currentValue ~= VANILLA_VALUE
                and instance.godSourceLookup[currentValue]
                and not enabled[currentValue]
            then
                values[#values + 1] = currentValue
            end
        end

        instance.godSourceDirty = false
    end

    local function ensureGodSourceValues()
        if instance.godSourceDirty then
            rebuildGodSourceValues()
        end
    end

    function control:name()
        return instance.name
    end

    function control:routeKey()
        return instance.routeKey
    end

    function control:setRouteContext(routeContext, routeKey)
        instance.routeContext = routeContext
        instance.routeKey = routeKey or instance.routeKey
    end

    function control:gods()
        return instance.gods
    end

    function control:isGodEnabled(key)
        return fields.GodPool:readAlias(key) == true
    end

    function control:isConfigEnabled(key)
        local field = fields[key]
        if field == nil or field.read == nil then
            return true
        end
        return field:read() == true
    end

    function control:isFeatureConfigured(featureKey)
        if not self:isLayerConfigured("features") then
            return false
        end
        local key = featureConfigFieldKey(instance, featureKey)
        if key == nil then
            return true
        end
        return self:isConfigEnabled(key)
    end

    function control:isLayerConfigured(layer)
        if layer == "rewards" then
            return self:isConfigEnabled(CONFIGURE_REWARDS_KEY)
        elseif layer == "npcs" then
            return self:isConfigEnabled(CONFIGURE_REWARDS_KEY)
                and self:isConfigEnabled(CONFIGURE_NPCS_KEY)
        elseif layer == "features" then
            return self:isConfigEnabled(CONFIGURE_FEATURES_KEY)
        end
        return true
    end

    function control:invalidateConfiguration()
        if instance.routeContext ~= nil and instance.routeContext.markDirty ~= nil then
            instance.routeContext:markDirty(instance.routeKey)
        end
    end

    function control:invalidateGodSource()
        instance.godSourceDirty = true
        if instance.routeContext ~= nil and instance.routeContext.markDirty ~= nil then
            instance.routeContext:markDirty(instance.routeKey)
        end
    end

    function control:godSourceValues(currentValue)
        ensureGodSourceValues()
        return instance.godSourceValuesByCurrent[currentValue or VANILLA_VALUE]
            or instance.godSourceValuesByCurrent[VANILLA_VALUE]
    end

    function control:godSourceDrawOpts(baseOpts, currentValue)
        ensureGodSourceValues()
        instance.godSourceDrawOptsByBase = instance.godSourceDrawOptsByBase or {}
        local drawOpts = instance.godSourceDrawOptsByBase[baseOpts]
        if drawOpts == nil then
            drawOpts = {}
            instance.godSourceDrawOptsByBase[baseOpts] = drawOpts
        end
        drawOpts.id = baseOpts.id
        drawOpts.label = baseOpts.label
        drawOpts.tooltip = baseOpts.tooltip
        drawOpts.controlWidth = baseOpts.controlWidth
        drawOpts.labelWidth = baseOpts.labelWidth
        drawOpts.controlGap = baseOpts.controlGap
        drawOpts.action = baseOpts.action
        drawOpts.value = baseOpts.value
        drawOpts.default = baseOpts.default
        drawOpts.values = self:godSourceValues(currentValue)
        drawOpts.displayValues = instance.godSourceLabels
        return drawOpts
    end

    function control:enabledGods(target)
        target = target or {}
        for index = #target, 1, -1 do
            target[index] = nil
        end
        for _, god in ipairs(instance.gods or {}) do
            if self:isGodEnabled(god.key) then
                target[#target + 1] = god.key
            end
        end
        return target
    end

    function control:read(path, ...)
        if path == "isGodEnabled" then
            return self:isGodEnabled(...)
        elseif path == "enabledGods" then
            return self:enabledGods(...)
        elseif path == "godSourceValues" then
            return self:godSourceValues(...)
        end
        return nil
    end

    return control
end

function RouteGlobal.createUi(fields, instance)
    local control = RouteGlobal.createRuntime(fields, instance)

    function control:configToggles()
        return CONFIG_TOGGLES
    end

    function control:featureConfigToggles()
        return instance.featureConfigToggles
    end

    function control:configField(key)
        return fields[key]
    end

    function control:configLabel(key)
        return instance.configDrawLabels and instance.configDrawLabels[key] or nil
    end

    function control:disabledConfigLabel(key, current)
        local labels = instance.configDisabledLabels and instance.configDisabledLabels[key] or nil
        if labels == nil then
            return nil
        end
        return current and labels.checked or labels.unchecked
    end

    function control:godPoolField()
        return fields.GodPool
    end

    return control
end

local function drawDisabledText(draw, text)
    decorations.drawText(draw.imgui, DISABLED_TEXT_COLOR, text)
end

local function drawPolicyNote(draw, text)
    decorations.drawWrappedText(draw.imgui, DISABLED_TEXT_COLOR, text)
end

local function drawDisabledCheckbox(draw, visibleLabel, label, current)
    local imgui = draw.imgui
    if imgui.BeginDisabled ~= nil and imgui.EndDisabled ~= nil then
        imgui.BeginDisabled(true)
        imgui.Checkbox(label, current)
        imgui.EndDisabled()
        return
    end

    drawDisabledText(draw, visibleLabel)
end

local function drawGodCheckbox(draw, control, god)
    local field = control:godPoolField()
    local current = field:readAlias(god.key) == true
    local nextValue, changed = decorations.checkboxWithTextColor(draw.imgui, god.drawLabel, current, god.color)
    if changed then
        field:writeAlias(god.key, nextValue == true)
        control:invalidateGodSource()
    end
end

local function drawGodPool(draw, control, instance)
    local imgui = draw.imgui
    local startX = imgui.GetCursorPosX()
    for index, god in ipairs(instance.gods or {}) do
        local column = (index - 1) % GODS_PER_ROW
        if column > 0 then
            imgui.SameLine()
        end
        imgui.SetCursorPosX(startX + column * GOD_COLUMN_WIDTH)
        drawGodCheckbox(draw, control, god)
    end
end

local function drawConfigCheckbox(draw, control, toggle, disabled)
    local field = control:configField(toggle.key)
    if field == nil or field.read == nil or field.write == nil then
        return
    end

    local label = control:configLabel(toggle.key)
    local current = field:read() == true
    if disabled then
        drawDisabledCheckbox(draw, control:disabledConfigLabel(toggle.key, current), label, current)
        return
    end

    local nextValue, changed = draw.imgui.Checkbox(label, current)
    if changed then
        field:write(nextValue == true)
        control:invalidateConfiguration()
    end
end

local function drawConfiguration(draw, control)
    draw.widgets.text("Configuration", { alignToFramePadding = true })
    local rewardsEnabled = control:isConfigEnabled(CONFIGURE_REWARDS_KEY)
    local featuresEnabled = control:isConfigEnabled(CONFIGURE_FEATURES_KEY)

    for _, toggle in ipairs(control:configToggles()) do
        drawConfigCheckbox(draw, control, toggle, toggle.key == CONFIGURE_NPCS_KEY and not rewardsEnabled)
        if toggle.key == CONFIGURE_REWARDS_KEY and not rewardsEnabled then
            drawPolicyNote(draw, REWARDS_DISABLED_NOTE)
        elseif toggle.key == CONFIGURE_FEATURES_KEY then
            draw.imgui.Indent()
            for _, featureToggle in ipairs(control:featureConfigToggles() or {}) do
                drawConfigCheckbox(draw, control, featureToggle, not featuresEnabled)
            end
            draw.imgui.Unindent()
        end
    end
end

function RouteGlobal.draw(draw, control, instance)
    drawConfiguration(draw, control)
    draw.imgui.Spacing()
    draw.imgui.Separator()
    draw.imgui.Spacing()
    draw.widgets.text("God Pool", { alignToFramePadding = true })
    drawGodPool(draw, control, instance)
end

RouteGlobal.views = {
    default = RouteGlobal.draw,
    planner = RouteGlobal.draw,
}

return RouteGlobal
