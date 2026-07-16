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

    return plan
end

return biomePlan
