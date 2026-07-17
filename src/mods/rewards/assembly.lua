local deps = ... or {}

local payloadRegistry = deps.payloadRegistry or import("mods/rewards/payloads/registry.lua")
local primitiveRegistry = deps.primitiveRegistry or import("mods/rewards/primitives/registry.lua")
local bagRegistry = deps.bagRegistry or import("mods/rewards/bags/registry.lua")
local countedBindings = deps.countedBindings or import("mods/rewards/bindings/counted.lua")
local countedChoice = deps.countedChoice or import("mods/rewards/components/counted_choice.lua")
local none = deps.none or import("mods/rewards/components/none.lua")
local fixed = deps.fixed or import("mods/rewards/components/fixed.lua")
local primitiveChoice = deps.primitiveChoice
    or import("mods/rewards/components/primitive_choice.lua")
local shopRegistry = deps.shopRegistry or import("mods/rewards/shops/registry.lua")
local shop = deps.shop or import("mods/rewards/components/shop.lua", nil, {
    primitiveChoice = primitiveChoice,
})
local rewardUi = deps.rewardUi or import("mods/rewards/ui.lua", nil, {
    countedChoice = countedChoice,
    primitiveChoice = primitiveChoice,
})

local assembly = {}

function assembly.create(rewards)
    local payloadDomains = payloadRegistry.build(rewards.payloadDomains, rewards.primitives)
    local primitives = primitiveRegistry.build(rewards.primitives, payloadDomains)
    local bags = bagRegistry.build(rewards.bags, primitives)
    local shops = shopRegistry.build(rewards.shops, primitives)
    return {
        payloadDomains = payloadDomains,
        primitives = primitives,
        bags = bags,
        shops = shops,
        countedBindings = countedBindings.create(bags),
        countedChoice = countedChoice,
        none = none,
        fixed = fixed,
        primitiveChoice = primitiveChoice,
        shop = shop,
        ui = rewardUi,
    }
end

return assembly
