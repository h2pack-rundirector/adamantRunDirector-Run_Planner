return {
    routes = import("mods/biomes/declarations/routes.lua"),
    biomes = import("mods/biomes/declarations/init.lua"),
    roomTemplates = import("mods/controls/declarations/room_templates.lua"),
    routeTemplates = import("mods/controls/declarations/route_templates.lua"),
    batchRules = import("mods/controls/declarations/batch_rules.lua"),
    encounterProfiles = import("mods/biomes/declarations/encounter_profiles.lua"),
    exitTypes = import("mods/biomes/declarations/exit_types.lua"),
    requirements = import("mods/route/declarations/requirements.lua"),
    rewards = import("mods/rewards/declarations/init.lua"),
}
