local historyAssembly = {}

function historyAssembly.create(opts)
    opts = opts or {}
    local events = import("mods/route/history/events.lua")
    local history = import("mods/route/history/history.lua", nil, {
        events = events,
    })
    local query = import("mods/route/history/query.lua", nil, {
        events = events,
        history = history,
    })
    local loot = import("mods/route/history/loot.lua", nil, {
        history = history,
    })
    local rewardCandidates = import("mods/route/history/reward_candidates.lua", nil, {
        rewardDomain = opts.rewardDomain,
    })
    local roomCandidates = import("mods/route/history/room_candidates.lua")
    local siblingCandidates = import("mods/route/history/sibling_candidates.lua")
    local adapters = {
        clockworkGoal = import("mods/route/history/adapters/clockwork_goal.lua", nil, {
            rewardCandidates = rewardCandidates,
            roomCandidates = roomCandidates,
            siblingCandidates = siblingCandidates,
        }),
        fieldsCageRoute = import("mods/route/history/adapters/fields_cage.lua", nil, {
            rewardCandidates = rewardCandidates,
            roomCandidates = roomCandidates,
            siblingCandidates = siblingCandidates,
        }),
        fixedLinear = import("mods/route/history/adapters/fixed_linear.lua", nil, {
            rewardCandidates = rewardCandidates,
            roomCandidates = roomCandidates,
            siblingCandidates = siblingCandidates,
        }),
        hubPylon = import("mods/route/history/adapters/hub_pylon.lua", nil, {
            rewardCandidates = rewardCandidates,
            roomCandidates = roomCandidates,
            siblingCandidates = siblingCandidates,
        }),
        multiEncounterFixed = import("mods/route/history/adapters/multi_encounter_fixed.lua", nil, {
            rewardCandidates = rewardCandidates,
            roomCandidates = roomCandidates,
            siblingCandidates = siblingCandidates,
        }),
    }
    local builder = import("mods/route/history/builder.lua", nil, {
        history = history,
        loot = loot,
        adapters = adapters,
    })
    local biomeStructureValidator = import("mods/route/history/validator/biome_structure.lua", nil, {
        history = history,
    })
    local rewardValidator = import("mods/route/history/validator/rewards.lua", nil, {
        history = history,
        query = query,
    })
    local validator = import("mods/route/history/validator.lua", nil, {
        biomeStructure = biomeStructureValidator,
        rewards = rewardValidator,
        selectedLegalityRules = opts.selectedLegalityRules,
    })

    return {
        adapters = adapters,
        events = events,
        history = history,
        loot = loot,
        roomCandidates = roomCandidates,
        rewardCandidates = rewardCandidates,
        siblingCandidates = siblingCandidates,
        query = query,
        builder = builder,
        validator = validator,
    }
end

return historyAssembly
