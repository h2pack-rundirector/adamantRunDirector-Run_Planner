local historyAssembly = {}

function historyAssembly.create(opts)
    opts = opts or {}
    local events = import("mods/route/history/events.lua")
    local formAddress = import("mods/route/history/form_address.lua")
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
    local findings = import("mods/route/history/findings.lua")
    local valueStates = import("mods/ui/value_states.lua")
    local feedbackCommon = import("mods/route/history/feedback/common.lua", nil, {
        valueStates = valueStates,
    })
    local npcFeedback = import("mods/route/history/feedback/npcs.lua", nil, {
        valueStates = valueStates,
    })
    local feedbackAdapters = {
        clockworkGoal = import("mods/route/history/feedback/clockwork_goal.lua", nil, {
            common = feedbackCommon,
        }),
        fieldsCageRoute = import("mods/route/history/feedback/fields_cage.lua", nil, {
            common = feedbackCommon,
        }),
        fixedLinear = import("mods/route/history/feedback/fixed_linear.lua", nil, {
            common = feedbackCommon,
        }),
        hubPylon = import("mods/route/history/feedback/hub_pylon.lua", nil, {
            common = feedbackCommon,
        }),
        multiEncounterFixed = import("mods/route/history/feedback/multi_encounter_fixed.lua", nil, {
            common = feedbackCommon,
        }),
    }
    local routeFeedback = import("mods/route/history/feedback/route.lua")
    local feedback = import("mods/route/history/feedback.lua", nil, {
        adapters = feedbackAdapters,
        history = history,
        routeFeedback = routeFeedback,
    })
    local rewardCandidates = import("mods/route/history/candidates/rewards.lua", nil, {
        rewardDomain = opts.rewardDomain,
    })
    local roomCandidates = import("mods/route/history/candidates/rooms.lua")
    local siblingCandidates = import("mods/route/history/candidates/siblings.lua")
    local step = import("mods/route/history/step.lua", nil, {
        rewardCandidates = rewardCandidates,
        roomCandidates = roomCandidates,
        siblingCandidates = siblingCandidates,
    })
    local npcCandidates = import("mods/route/history/candidates/npcs.lua", nil, {
        history = history,
    })
    local adapters = {
        clockworkGoal = import("mods/route/history/adapters/clockwork_goal.lua", nil, {
            rewardCandidates = rewardCandidates,
            roomCandidates = roomCandidates,
            siblingCandidates = siblingCandidates,
            step = step,
        }),
        fieldsCageRoute = import("mods/route/history/adapters/fields_cage.lua", nil, {
            rewardCandidates = rewardCandidates,
            roomCandidates = roomCandidates,
            siblingCandidates = siblingCandidates,
            step = step,
        }),
        fixedLinear = import("mods/route/history/adapters/fixed_linear.lua", nil, {
            rewardCandidates = rewardCandidates,
            roomCandidates = roomCandidates,
            siblingCandidates = siblingCandidates,
            step = step,
        }),
        hubPylon = import("mods/route/history/adapters/hub_pylon.lua", nil, {
            rewardCandidates = rewardCandidates,
            roomCandidates = roomCandidates,
            siblingCandidates = siblingCandidates,
            step = step,
        }),
        multiEncounterFixed = import("mods/route/history/adapters/multi_encounter_fixed.lua", nil, {
            rewardCandidates = rewardCandidates,
            roomCandidates = roomCandidates,
            siblingCandidates = siblingCandidates,
            step = step,
        }),
    }
    local builder = import("mods/route/history/builder.lua", nil, {
        history = history,
        loot = loot,
        adapters = adapters,
    })
    local biomeStructureValidator = import("mods/route/history/validator/biome_structure.lua", nil, {
        findings = findings,
        history = history,
        query = query,
    })
    local rewardValidator = import("mods/route/history/validator/rewards.lua", nil, {
        history = history,
        query = query,
    })
    local npcValidator = import("mods/route/history/validator/npcs.lua")
    local candidateValidator = import("mods/route/history/validator/candidates.lua", nil, {
        history = history,
        findings = findings,
        ruleValidators = biomeStructureValidator.ruleValidators,
        rewards = rewardValidator,
        selectedLegalityRules = opts.selectedLegalityRules,
    })
    local validator = import("mods/route/history/validator.lua", nil, {
        biomeStructure = biomeStructureValidator,
        candidates = candidateValidator,
        npcs = npcValidator,
        rewards = rewardValidator,
        selectedLegalityRules = opts.selectedLegalityRules,
    })

    return {
        adapters = adapters,
        events = events,
        feedback = feedback,
        feedbackAdapters = feedbackAdapters,
        formAddress = formAddress,
        findings = findings,
        history = history,
        loot = loot,
        npcCandidates = npcCandidates,
        npcFeedback = npcFeedback,
        roomCandidates = roomCandidates,
        rewardCandidates = rewardCandidates,
        siblingCandidates = siblingCandidates,
        step = step,
        query = query,
        builder = builder,
        validator = validator,
    }
end

return historyAssembly
