local deps = ...
local shopComponent = deps.shop
local shops = deps.shops
local rewardUi = deps.rewardUi

local shopTemplate = {}

local function fail(room, message)
    error("Shop room '" .. room.key .. "' " .. message, 0)
end

function shopTemplate.prepare(_, room)
    if room.kind ~= "Shop" then
        fail(room, "must have kind 'Shop'")
    end
    if room.incomingReward.kind ~= "shop" then
        fail(room, "requires a shop incoming reward")
    end
    if room.encounterProfileKey ~= "Shop" then
        fail(room, "requires encounter profile 'Shop'")
    end
    if #room.localChildren ~= 0 then
        fail(room, "cannot declare local children")
    end
    return {}
end

local Template = {}

function Template.prepare(instance)
    instance.shop = rewardUi.prepareShop(shopComponent.prepare(
        shops.profiles.lookup[instance.incomingReward.shopProfileKey],
        "Shop"
    ))
    return instance
end

function Template.storage(instance)
    return shopComponent.storage(instance.shop)
end

local function context(instance)
    return "room control '" .. instance.name .. "' shop"
end

local function createRuntime(fields, instance)
    local control = {}
    local shopContext = context(instance)

    function control.read(_)
        return {
            kind = "Shop",
            shop = shopComponent.read(fields, instance.shop, shopContext),
        }
    end

    function control.isComplete(_)
        local value = shopComponent.read(fields, instance.shop, shopContext)
        return shopComponent.isComplete(instance.shop, value)
    end

    return control
end

function Template.createRuntime(fields, instance)
    return createRuntime(fields, instance)
end

function Template.createUi(fields, instance)
    local control = createRuntime(fields, instance)
    local shopContext = context(instance)

    function control.setSlotReward(_, slotKey, value)
        shopComponent.writeReward(fields, instance.shop, slotKey, value, shopContext)
    end

    function control.setPurchased(_, slotKey, value)
        shopComponent.writePurchased(fields, instance.shop, slotKey, value, shopContext)
    end


    function control.drawShop(_, draw)
        rewardUi.drawShop(draw, fields, instance.shop)
    end

    return control
end

Template.views = {
    default = function(draw, control)
        control:drawShop(draw)
    end,
}
shopTemplate.template = Template

return shopTemplate
