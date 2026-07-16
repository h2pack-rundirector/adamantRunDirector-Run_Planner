local biomePlan = {}

function biomePlan.create(specification)
    local plan = {
        key = specification.biome.biomeStepKey,
        layoutKind = specification.biome.layout.kind,
    }

    function plan.readTopology(_, stateAccess)
        return specification.topologyLayout.readTopology(
            specification.context,
            stateAccess:readBiome(plan.key)
        )
    end

    function plan.checkStructure(_, topology)
        return specification.topologyLayout.checkStructure(specification.context, topology)
    end

    function plan.traverse(_, topology, visitor)
        return specification.topologyLayout.traverse(
            specification.context,
            topology,
            visitor
        )
    end

    function plan.semanticAddress(_, subject)
        return specification.topologyLayout.semanticAddress(specification.context, subject)
    end

    function plan.apply(_, uiStateAccess, command)
        if type(uiStateAccess) ~= "table"
            or type(uiStateAccess.replaceBiomeTopology) ~= "function"
        then
            error("biome plan '" .. plan.key .. "' mutation requires UiStateAccess", 0)
        end
        local authored, topology = specification.topologyLayout.apply(
            specification.context,
            uiStateAccess:readBiome(plan.key),
            command
        )
        uiStateAccess:replaceBiomeTopology(plan.key, authored)
        return topology
    end

    function plan.clearTopology(_, uiStateAccess)
        return plan:apply(uiStateAccess, { kind = "ClearTopology" })
    end

    return plan
end

return biomePlan
