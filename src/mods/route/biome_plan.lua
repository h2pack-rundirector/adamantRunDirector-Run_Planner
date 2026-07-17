local biomePlan = {}

function biomePlan.create(specification)
    local plan = {
        key = specification.biome.biomeStepKey,
        layoutKind = specification.biome.layout.kind,
    }
    local descriptor = specification.storage

    function plan.storage(_)
        return descriptor
    end

    function plan.bind(_, stateAccess)
        local bound = {}

        function bound.readAuthored(_)
            return specification.topologyLayout.readAuthored(stateAccess, descriptor)
        end

        function bound.readTopology(_)
            return specification.topologyLayout.readTopology(
                specification.context,
                bound:readAuthored()
            )
        end

        function bound.checkStructure(_, topology)
            return specification.topologyLayout.checkStructure(specification.context, topology)
        end

        function bound.traverse(_, topology, visitor)
            return specification.topologyLayout.traverse(
                specification.context,
                topology,
                visitor
            )
        end

        function bound.semanticAddress(_, subject)
            return specification.topologyLayout.semanticAddress(specification.context, subject)
        end

        if type(stateAccess.replaceRows) == "function"
            and type(stateAccess.replaceScalar) == "function"
        then
            function bound.apply(_, command)
                local authored, topology = specification.topologyLayout.apply(
                    specification.context,
                    bound:readAuthored(),
                    command
                )
                specification.topologyLayout.replaceAuthored(
                    stateAccess,
                    descriptor,
                    authored
                )
                return topology
            end

            function bound.clearTopology(_)
                return bound:apply({ kind = "ClearTopology" })
            end
        end

        return bound
    end

    function plan.readAuthored(_, stateAccess)
        return plan:bind(stateAccess):readAuthored()
    end

    function plan.readTopology(_, stateAccess)
        return plan:bind(stateAccess):readTopology()
    end

    function plan.checkStructure(_, topology)
        return specification.topologyLayout.checkStructure(specification.context, topology)
    end

    function plan.traverse(_, topology, visitor)
        return specification.topologyLayout.traverse(specification.context, topology, visitor)
    end

    function plan.semanticAddress(_, subject)
        return specification.topologyLayout.semanticAddress(specification.context, subject)
    end

    function plan.apply(_, uiStateAccess, command)
        local bound = plan:bind(uiStateAccess)
        if type(bound.apply) ~= "function" then
            error("biome plan '" .. plan.key .. "' mutation requires UiStateAccess", 0)
        end
        return bound:apply(command)
    end

    function plan.clearTopology(_, uiStateAccess)
        return plan:apply(uiStateAccess, { kind = "ClearTopology" })
    end

    return plan
end

return biomePlan
