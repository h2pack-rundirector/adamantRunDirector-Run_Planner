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

    return plan
end

return biomePlan
