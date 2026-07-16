local deps = ...
local countedBindings = deps.countedBindings
local countedChoice = deps.countedChoice
local shopComponent = deps.shop
local shops = deps.shops

local forkedPreboss = {}

local STRING_MAX = 16

local function fail(room, message)
    error("ForkedPreboss room '" .. room.key .. "' " .. message, 0)
end

local function unavailableView()
    error("planner controls have no production draw view before the editor checkpoint", 0)
end

local function append(target, values)
    for _, value in ipairs(values) do
        target[#target + 1] = value
    end
end

function forkedPreboss.prepare(_, room)
    if room.kind ~= "Preboss" then
        fail(room, "must have kind 'Preboss'")
    end
    if room.incomingReward.kind ~= "shop" then
        fail(room, "requires a shop incoming reward")
    end
    if room.encounterProfileKey ~= "Preboss" then
        fail(room, "requires encounter profile 'Preboss'")
    end
    local policy = room.entryOfferPolicy
    if policy.kind ~= "shopThenFillRemainingExits" then
        fail(room, "requires shopThenFillRemainingExits entry policy")
    end
    if #room.localChildren ~= 0 then
        fail(room, "cannot declare local children")
    end

    return {}
end

local Template = {}

function Template.prepare(instance)
    local policy = instance.entryOfferPolicy
    local freeView = countedBindings.compile(policy.freeReward)
    local freeRewards = {}
    local entryModeValues = { "", "Shop" }
    local entryModeLookup = { [""] = true, Shop = true }
    for index = 1, policy.maxFreeRewards do
        local mode = "Reward" .. tostring(index)
        entryModeValues[#entryModeValues + 1] = mode
        entryModeLookup[mode] = true
        freeRewards[index] = countedChoice.prepare(
            freeView,
            "FreeReward" .. tostring(index)
        )
    end
    instance.entryModeField = "EntryMode"
    instance.entryModeValues = entryModeValues
    instance.entryModeLookup = entryModeLookup
    instance.freeRewards = freeRewards
    instance.shop = shopComponent.prepare(
        shops.profiles.lookup[instance.incomingReward.shopProfileKey],
        "Shop"
    )
    return instance
end

function Template.storage(instance)
    local storage = {
        {
            key = instance.entryModeField,
            type = "string",
            default = "",
            maxLen = STRING_MAX,
        },
    }
    append(storage, shopComponent.storage(instance.shop))
    for _, reward in ipairs(instance.freeRewards) do
        append(storage, countedChoice.storage(reward))
    end
    return storage
end

local function context(instance)
    return "room control '" .. instance.name .. "'"
end

local function readEntryMode(fields, instance, controlContext)
    local value = fields[instance.entryModeField]:read()
    if type(value) ~= "string" then
        error(controlContext .. ": persisted entryMode must be a string", 0)
    end
    if instance.entryModeLookup[value] ~= true then
        error(controlContext .. ": persisted entryMode '" .. value .. "' is not allowed", 0)
    end
    return value
end

local function readValue(fields, instance, controlContext)
    local value = {
        kind = "ForkedPreboss",
        entryMode = readEntryMode(fields, instance, controlContext),
        shop = shopComponent.read(fields, instance.shop, controlContext .. " shop"),
        freeRewards = {},
    }
    for index, reward in ipairs(instance.freeRewards) do
        value.freeRewards[index] = countedChoice.read(
            fields,
            reward,
            controlContext .. " freeReward" .. tostring(index)
        )
    end
    return value
end

local function activeFreeRewardCount(value, instance, controlContext)
    if type(value) ~= "table" then
        error(controlContext .. ": completeness requires incoming topology context", 0)
    end
    local count = value.activeFreeRewardCount
    if type(count) ~= "number"
        or count ~= math.floor(count)
        or count < 0
        or count > #instance.freeRewards
    then
        error(controlContext .. ": activeFreeRewardCount must be an integer between 0 and "
            .. tostring(#instance.freeRewards), 0)
    end
    return count
end

local function createRuntime(fields, instance)
    local control = {}
    local controlContext = context(instance)

    function control.read(_)
        return readValue(fields, instance, controlContext)
    end

    function control.isComplete(_, topologyContext)
        local activeCount = activeFreeRewardCount(topologyContext, instance, controlContext)
        local value = readValue(fields, instance, controlContext)
        if not shopComponent.isComplete(instance.shop, value.shop) then
            return false
        end
        for index = 1, activeCount do
            if not countedChoice.isComplete(instance.freeRewards[index], value.freeRewards[index]) then
                return false
            end
        end
        if value.entryMode == "Shop" then
            return true
        end
        for index = 1, activeCount do
            if value.entryMode == "Reward" .. tostring(index) then
                return true
            end
        end
        return false
    end

    return control
end

function Template.createRuntime(fields, instance)
    return createRuntime(fields, instance)
end

function Template.createUi(fields, instance)
    local control = createRuntime(fields, instance)
    local controlContext = context(instance)

    function control.setEntryMode(_, value)
        if type(value) ~= "string" or instance.entryModeLookup[value] ~= true then
            error(controlContext .. ": entryMode '" .. tostring(value) .. "' is not allowed", 0)
        end
        fields[instance.entryModeField]:write(value)
    end

    function control.setShopSlotReward(_, slotKey, value)
        shopComponent.writeReward(
            fields,
            instance.shop,
            slotKey,
            value,
            controlContext .. " shop"
        )
    end

    function control.setShopPurchased(_, slotKey, value)
        shopComponent.writePurchased(
            fields,
            instance.shop,
            slotKey,
            value,
            controlContext .. " shop"
        )
    end

    function control.setFreeReward(_, index, value)
        local reward = instance.freeRewards[index]
        if reward == nil then
            error(controlContext .. ": free reward index '" .. tostring(index) .. "' is not allowed", 0)
        end
        countedChoice.write(
            fields,
            reward,
            value,
            controlContext .. " freeReward" .. tostring(index)
        )
    end

    return control
end

Template.views = { default = unavailableView }
forkedPreboss.template = Template

return forkedPreboss
