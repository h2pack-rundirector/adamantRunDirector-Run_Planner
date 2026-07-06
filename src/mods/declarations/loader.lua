local requirementsValidator = import("mods/declarations/validators/requirements.lua")
local rewardsValidator = import("mods/declarations/validators/rewards.lua")
local roomTemplatesValidator = import("mods/declarations/validators/room_templates.lua")
local offerProfilesValidator = import("mods/declarations/validators/offer_profiles.lua")
local routesValidator = import("mods/declarations/validators/routes.lua")
local biomesValidator = import("mods/declarations/validators/biomes.lua")

local loader = {}

function loader.load(opts)
    opts = opts or {}

    local routes = opts.routes or import("mods/declarations/routes.lua")
    local requirements = opts.requirements or import("mods/declarations/requirements.lua")
    local rewards = opts.rewards or import("mods/declarations/rewards.lua")
    local roomTemplates = opts.roomTemplates or import("mods/declarations/room_templates.lua")
    local offerProfiles = opts.offerProfiles or import("mods/declarations/offer_profiles.lua")
    local biomes = opts.biomes or import("mods/declarations/biomes/init.lua")

    requirementsValidator.validateRegistry(requirements)
    local routesCatalog = routesValidator.validate(routes)
    local normalizedRewards = rewardsValidator.validate(rewards, requirements)
    local normalizedRoomTemplates = roomTemplatesValidator.validate(roomTemplates)
    local normalizedOfferProfiles = offerProfilesValidator.validate(offerProfiles, normalizedRewards)
    local biomesCatalog = biomesValidator.validateList(biomes, requirements, normalizedRoomTemplates, normalizedOfferProfiles, routesCatalog)

    return {
        routes = routesValidator.withImplementedBiomes(routesCatalog, biomesCatalog),
        biomes = biomesCatalog,
        rewards = normalizedRewards,
        requirements = requirements,
        roomTemplates = normalizedRoomTemplates,
        offerProfiles = normalizedOfferProfiles,
    }
end

return loader
