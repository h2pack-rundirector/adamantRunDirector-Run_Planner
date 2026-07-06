local guard = import("mods/declarations/guard.lua")

local requirementsValidator = {}

local KNOWN_REQUIREMENT_KINDS = {
    All = true,
    Any = true,
    Not = true,
    BiomeDepthCache = true,
    BiomeEncounterDepth = true,
    ClearedBiomes = true,
    LootTypeHistory = true,
    RequiredNotInStore = true,
}

local KNOWN_PRESENTATION_POLICIES = {
    hide = true,
    invalid = true,
    warning = true,
    unsupported = true,
    block = true,
}

local KNOWN_COMPARISONS = {
    ["=="] = true,
    ["~="] = true,
    ["<"] = true,
    ["<="] = true,
    [">"] = true,
    [">="] = true,
}

local function validatePresentation(requirement, context)
    if requirement.presentation ~= nil then
        guard.expectString(requirement.presentation, context .. ".presentation")
        if not KNOWN_PRESENTATION_POLICIES[requirement.presentation] then
            guard.fail(context .. ".presentation", "unknown presentation policy '" .. requirement.presentation .. "'")
        end
    end
    guard.expectOptionalString(requirement.code, context .. ".code")
    guard.expectOptionalString(requirement.message, context .. ".message")
end

local function validateCountSet(requirement, context)
    if requirement.countOf ~= nil then
        guard.expectNonEmptyArray(requirement.countOf, context .. ".countOf")
        for index, value in ipairs(requirement.countOf) do
            guard.expectString(value, context .. ".countOf[" .. tostring(index) .. "]")
        end
    end
end

local function validateComparison(requirement, context)
    if requirement.comparison ~= nil then
        guard.expectString(requirement.comparison, context .. ".comparison")
        if not KNOWN_COMPARISONS[requirement.comparison] then
            guard.fail(context .. ".comparison", "unknown comparison '" .. requirement.comparison .. "'")
        end
        guard.expectNumber(requirement.value, context .. ".value")
    end
end

function requirementsValidator.validateRequirement(requirement, namedRequirements, context)
    guard.expectTable(requirement, context)

    if requirement.named ~= nil then
        guard.expectString(requirement.named, context .. ".named")
        if namedRequirements[requirement.named] == nil then
            guard.fail(context .. ".named", "unknown named requirement '" .. requirement.named .. "'")
        end
        return
    end

    local kind = guard.expectString(requirement.kind, context .. ".kind")
    if not KNOWN_REQUIREMENT_KINDS[kind] then
        guard.fail(context .. ".kind", "unknown requirement kind '" .. kind .. "'")
    end

    validatePresentation(requirement, context)

    if kind == "All" or kind == "Any" then
        guard.expectNonEmptyArray(requirement.requirements, context .. ".requirements")
        for index, child in ipairs(requirement.requirements) do
            requirementsValidator.validateRequirement(child, namedRequirements, context .. ".requirements[" .. tostring(index) .. "]")
        end
    elseif kind == "Not" then
        requirementsValidator.validateRequirement(requirement.requirement, namedRequirements, context .. ".requirement")
    else
        validateComparison(requirement, context)
        validateCountSet(requirement, context)

        if kind == "RequiredNotInStore" then
            guard.expectString(requirement.name, context .. ".name")
        end
    end
end

function requirementsValidator.validateRegistry(requirements)
    guard.expectTable(requirements, "requirements")
    for key, requirement in pairs(requirements) do
        guard.expectString(key, "requirements key")
        requirementsValidator.validateRequirement(requirement, requirements, "requirements." .. key)
    end
end

return requirementsValidator
