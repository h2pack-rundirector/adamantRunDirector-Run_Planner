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

local function failure(requirement, payload)
    return {
        code = requirement.code or "requirement_failed",
        phase = "room.generate_next",
        presentation = requirement.presentation or "invalid",
        payload = payload or {},
        message = requirement.message or "Generated room target fails declared eligibility.",
    }
end

local function numericFailure(requirement, axis, actual, expected)
    return failure(requirement, {
        kind = requirement.kind,
        axis = axis,
        actual = actual,
        comparison = requirement.comparison,
        expected = expected,
    })
end

local function numericRequirement(requirement, axis, actual, context)
    local comparison = guard.expectString(requirement.comparison, context .. ".comparison")
    local expected = guard.expectNumber(requirement.value, context .. ".value")

    if compare(actual, comparison, expected) then
        return nil
    end

    return numericFailure(requirement, axis, actual, expected)
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
            })
            if violation == nil then
                return nil
            end
            firstViolation = firstViolation or violation
        end
        return failure(requirement, firstViolation and firstViolation.payload or {})
    elseif kind == "Not" then
        local violation = evaluate(requirement.requirement, {
            path = context.path .. ".requirement",
            namedRequirements = context.namedRequirements,
            counters = context.counters,
        })
        if violation ~= nil then
            return nil
        end
        return failure(requirement)
    elseif kind == "BiomeDepthCache" then
        return numericRequirement(
            requirement,
            "BiomeDepthCache",
            guard.expectNumber(context.counters.biomeDepthCache, "validation.counters.biomeDepthCache"),
            context.path
        )
    elseif kind == "BiomeEncounterDepth" then
        return numericRequirement(
            requirement,
            "BiomeEncounterDepth",
            guard.expectNumber(context.counters.biomeEncounterDepth, "validation.counters.biomeEncounterDepth"),
            context.path
        )
    end

    guard.fail(context.path .. ".kind", "unsupported requirement kind '" .. kind .. "'")
end

function requirements.evaluate(requirement, context)
    context = context or {}
    return evaluate(requirement, {
        path = context.path or "validation.requirement",
        namedRequirements = context.namedRequirements or {},
        counters = guard.expectTable(context.counters, "validation.counters"),
    })
end

return requirements
