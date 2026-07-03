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
    local routeFeedbackMessageCatalog = import("mods/route/history/feedback/message_catalog.lua")
    local routeFeedbackMessages = import("mods/route/history/feedback/messages.lua", nil, {
        catalog = routeFeedbackMessageCatalog,
    })
    local routeFeedback = import("mods/route/history/feedback/route.lua", nil, {
        messages = routeFeedbackMessages,
    })
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
    local materializeRoom = import("mods/route/history/materialize_room.lua")
    local validatorWalker = import("mods/route/history/validator/walker.lua", nil, {
        history = history,
        rewardCandidates = rewardCandidates,
        roomCandidates = roomCandidates,
        siblingCandidates = siblingCandidates,
    })
    local npcCandidates = import("mods/route/history/candidates/npcs.lua", nil, {
        history = history,
    })
    local adapters = {
        clockworkGoal = import("mods/route/history/adapters/clockwork_goal.lua", nil, {
            materializeRoom = materializeRoom,
        }),
        fieldsCageRoute = import("mods/route/history/adapters/fields_cage.lua", nil, {
            materializeRoom = materializeRoom,
        }),
        fixedLinear = import("mods/route/history/adapters/fixed_linear.lua", nil, {
            materializeRoom = materializeRoom,
        }),
        hubPylon = import("mods/route/history/adapters/hub_pylon.lua", nil, {
            materializeRoom = materializeRoom,
        }),
        multiEncounterFixed = import("mods/route/history/adapters/multi_encounter_fixed.lua", nil, {
            materializeRoom = materializeRoom,
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
        walker = validatorWalker,
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
        walker = validatorWalker,
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
        materializeRoom = materializeRoom,
        npcCandidates = npcCandidates,
        npcFeedback = npcFeedback,
        roomCandidates = roomCandidates,
        rewardCandidates = rewardCandidates,
        siblingCandidates = siblingCandidates,
        query = query,
        builder = builder,
        validator = validator,
        walker = validatorWalker,
    }
end

return historyAssembly
