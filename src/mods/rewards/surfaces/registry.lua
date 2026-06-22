local surfaces = {}

local common = import("mods/rewards/surfaces/common.lua")
local constraints = import("mods/rewards/declarations/constraints.lua")
local roomStore = import("mods/rewards/surfaces/room_store.lua", nil, {
    common = common,
    constraints = constraints,
})
local majorMinor = import("mods/rewards/surfaces/major_minor.lua", nil, {
    common = common,
    constraints = constraints,
})
local builders = {
    fieldsCages = import("mods/rewards/surfaces/fields_cages.lua", nil, {
        common = common,
        constraints = constraints,
        roomStore = roomStore,
    }),
    forcedReward = import("mods/rewards/surfaces/forced_reward.lua", nil, {
        common = common,
        constraints = constraints,
    }),
    majorMinor = majorMinor,
    roomStore = roomStore,
    shop = import("mods/rewards/surfaces/shop.lua", nil, {
        common = common,
        constraints = constraints,
    }),
}

local function noSurface(context)
    return {
        kind = "none",
        context = context,
        controls = {},
    }
end

local function surfaceFor(self, context)
    context = context or { kind = "none" }
    if context.kind == "none" then
        return noSurface(context)
    end
    local builder = builders[context.kind]
    if builder ~= nil then
        return builder.create(self.definitions, context)
    end
    return noSurface(context)
end

function surfaces.create(definitions)
    local source = definitions or {}
    local instance = {
        definitions = {
            godLoot = common.copyList(source.godLoot),
            bundles = source.bundles or {},
            primitives = source.primitives or {},
            shops = source.shops or {},
        },
        surfaceCache = {},
    }

    function instance:surfaceFor(context)
        context = context or false
        local cached = self.surfaceCache[context]
        if cached == nil then
            cached = surfaceFor(self, context ~= false and context or nil)
            self.surfaceCache[context] = cached
        end
        return cached
    end

    function instance.godLootOptions()
        return common.copyList(instance.definitions.godLoot)
    end

    return instance
end

return surfaces
