local guard = import("mods/declarations/guard.lua")

local requirements = {}

local function compare(actual, comparison, expected)
    if comparison == "==" then
        return actual == expected
    elseif comparison == "~=" then
        return actual ~= expected
    elseif comparison == "<" then
        return actual < expected
    elseif comparison == "<=" then
        return actual <= expected
    elseif comparison == ">" then
        return actual > expected
    elseif comparison == ">=" then
        return actual >= expected
    end

    guard.fail("validation.requirement.comparison", "unknown comparison '" .. tostring(comparison) .. "'")
end

local function failure(requirement, payload, context)
    return {
        code = requirement.code or "requirement_failed",
        phase = context.phase or "room.generate_next",
        presentation = requirement.presentation or "invalid",
        payload = payload or {},
        message = requirement.message or context.defaultMessage or "Declared requirement is not satisfied.",
    }
end

local function numericFailure(requirement, axis, actual, expected, context, extraPayload)
    local payload = {
        kind = requirement.kind,
        axis = axis,
        actual = actual,
        comparison = requirement.comparison,
        expected = expected,
    }
    for key, value in pairs(extraPayload or {}) do
        payload[key] = value
    end
    return failure(requirement, payload, context)
end

local function numericRequirement(requirement, axis, actual, context)
    local comparison = guard.expectString(requirement.comparison, context.path .. ".comparison")
    local expected = guard.expectNumber(requirement.value, context.path .. ".value")

    if compare(actual, comparison, expected) then
        return nil
    end

    return numericFailure(requirement, axis, actual, expected, context)
end

local function countSetRequirement(requirement, axis, actual, context)
    guard.expectNonEmptyArray(requirement.countOf, context.path .. ".countOf")
    local comparison = guard.expectString(requirement.comparison, context.path .. ".comparison")
    local expected = guard.expectNumber(requirement.value, context.path .. ".value")

    if compare(actual, comparison, expected) then
        return nil
    end

    return numericFailure(requirement, axis, actual, expected, context, {
        countOf = requirement.countOf,
    })
end

local function arrayPayload(values)
    local copy = {}
    for index, value in ipairs(values or {}) do
        copy[index] = value
    end
    return copy
end

local function uniqueValues(values)
    local seen = {}
    local duplicates = {}
    for _, value in ipairs(values) do
        if seen[value] then
            duplicates[#duplicates + 1] = value
        else
            seen[value] = true
        end
    end
    return duplicates
end

local function resolveNamed(requirement, context)
    local name = guard.expectString(requirement.named, context.path .. ".named")
    local registry = guard.expectTable(context.namedRequirements, "validation.namedRequirements")
    local named = registry[name]
    if named == nil then
        guard.fail(context.path .. ".named", "unknown named requirement '" .. name .. "'")
    end
    return named
end

local function evaluate(requirement, context)
    guard.expectTable(requirement, context.path)

    if requirement.named ~= nil then
        return evaluate(resolveNamed(requirement, context), {
            path = context.path .. "." .. requirement.named,
            namedRequirements = context.namedRequirements,
            counters = context.counters,
            queries = context.queries,
            phase = context.phase,
            defaultMessage = context.defaultMessage,
        })
    end

    local kind = guard.expectString(requirement.kind, context.path .. ".kind")

    if kind == "All" then
        guard.expectNonEmptyArray(requirement.requirements, context.path .. ".requirements")
        for index, child in ipairs(requirement.requirements) do
            local violation = evaluate(child, {
                path = context.path .. ".requirements[" .. tostring(index) .. "]",
                namedRequirements = context.namedRequirements,
                counters = context.counters,
                queries = context.queries,
                phase = context.phase,
                defaultMessage = context.defaultMessage,
            })
            if violation ~= nil then
                return violation
            end
        end
        return nil
    elseif kind == "Any" then
        guard.expectNonEmptyArray(requirement.requirements, context.path .. ".requirements")
        local firstViolation
        for index, child in ipairs(requirement.requirements) do
            local violation = evaluate(child, {
                path = context.path .. ".requirements[" .. tostring(index) .. "]",
                namedRequirements = context.namedRequirements,
                counters = context.counters,
                queries = context.queries,
                phase = context.phase,
                defaultMessage = context.defaultMessage,
            })
            if violation == nil then
                return nil
            end
            firstViolation = firstViolation or violation
        end
        return failure(requirement, firstViolation and firstViolation.payload or {}, context)
    elseif kind == "Not" then
        local violation = evaluate(requirement.requirement, {
            path = context.path .. ".requirement",
            namedRequirements = context.namedRequirements,
            counters = context.counters,
            queries = context.queries,
            phase = context.phase,
            defaultMessage = context.defaultMessage,
        })
        if violation ~= nil then
            return nil
        end
        return failure(requirement, nil, context)
    elseif kind == "BiomeDepthCache" then
        return numericRequirement(
            requirement,
            "BiomeDepthCache",
            guard.expectNumber(context.counters.biomeDepthCache, "validation.counters.biomeDepthCache"),
            context
        )
    elseif kind == "BiomeEncounterDepth" then
        return numericRequirement(
            requirement,
            "BiomeEncounterDepth",
            guard.expectNumber(context.counters.biomeEncounterDepth, "validation.counters.biomeEncounterDepth"),
            context
        )
    elseif kind == "LootTypeHistory" then
        local count = guard.expectFunction(
            context.queries.countLootTypeHistory,
            "validation.queries.countLootTypeHistory"
        )(requirement.countOf)
        return countSetRequirement(requirement, "LootTypeHistory", count, context)
    elseif kind == "PriorDistinctLootSources" then
        guard.expectNonEmptyArray(requirement.sourceValues, context.path .. ".sourceValues")
        local count = guard.expectFunction(
            context.queries.countDistinctLootSources,
            "validation.queries.countDistinctLootSources"
        )(requirement.sourceValues)
        return numericRequirement(requirement, "LootSourceHistory", count, context)
    elseif kind == "CurrentLootSourcesSeen" then
        guard.expectNonEmptyArray(requirement.sourceValues, context.path .. ".sourceValues")
        local missing = guard.expectFunction(
            context.queries.missingLootSources,
            "validation.queries.missingLootSources"
        )(requirement.sourceValues)
        if #missing == 0 then
            return nil
        end
        return failure(requirement, {
            kind = requirement.kind,
            missingSources = missing,
            sourceValues = arrayPayload(requirement.sourceValues),
        }, context)
    elseif kind == "UniquePayloadValues" then
        guard.expectNonEmptyArray(requirement.values, context.path .. ".values")
        local duplicates = uniqueValues(requirement.values)
        if #duplicates == 0 then
            return nil
        end
        return failure(requirement, {
            kind = requirement.kind,
            duplicateValues = duplicates,
            values = arrayPayload(requirement.values),
        }, context)
    elseif kind == "ClearedBiomes" then
        local count = guard.expectFunction(
            context.queries.countClearedBiomes,
            "validation.queries.countClearedBiomes"
        )()
        return numericRequirement(requirement, "ClearedBiomes", count, context)
    elseif kind == "RequiredNotInStore" then
        local name = guard.expectString(requirement.name, context.path .. ".name")
        local count = guard.expectFunction(
            context.queries.countPendingStoreOffers,
            "validation.queries.countPendingStoreOffers"
        )({ name })
        if count == 0 then
            return nil
        end
        return failure(requirement, {
            kind = requirement.kind,
            name = name,
            actual = count,
        }, context)
    end

    guard.fail(context.path .. ".kind", "unsupported requirement kind '" .. kind .. "'")
end

function requirements.evaluate(requirement, context)
    context = context or {}
    return evaluate(requirement, {
        path = context.path or "validation.requirement",
        namedRequirements = context.namedRequirements or {},
        counters = context.counters or {},
        queries = context.queries or {},
        phase = context.phase,
        defaultMessage = context.defaultMessage,
    })
end

return requirements
