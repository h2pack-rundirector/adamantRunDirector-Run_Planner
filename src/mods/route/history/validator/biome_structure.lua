local deps = ... or {}

local common = import("mods/route/history/validator/biome_structure/common.lua", nil, {
    history = deps.history,
})
local pickedEntriesValidator = import("mods/route/history/validator/biome_structure/picked_entries.lua", nil, {
    common = common,
    findings = deps.findings,
})
local structureValidators = {
    pickedEntriesValidator,
    import("mods/route/history/validator/biome_structure/route_requirements.lua", nil, {
        common = common,
        pickedEntries = pickedEntriesValidator,
        query = deps.query,
    }),
    import("mods/route/history/validator/biome_structure/force_pressure.lua", nil, {
        common = common,
    }),
    import("mods/route/history/validator/biome_structure/deadlines.lua", nil, {
        common = common,
    }),
}
local ruleValidators = {
    import("mods/route/history/validator/biome_structure/rules/clockwork_goal.lua", nil, {
        common = common,
        findings = deps.findings,
    }),
    import("mods/route/history/validator/biome_structure/rules/fields_cage.lua", nil, {
        common = common,
        findings = deps.findings,
    }),
}

local biomeStructure = {}

biomeStructure.ruleValidators = ruleValidators

local EMPTY_LIST = common.EMPTY_LIST

local function validateInOrder(history, biome, validators)
    local resultFindings = {}
    for _, validator in ipairs(validators) do
        local invalid, findings = validator.validate(history, biome)
        common.appendFindings(resultFindings, findings)
        if invalid ~= nil then
            return invalid, resultFindings
        end
    end
    return nil, resultFindings
end

function biomeStructure.validate(args)
    local history = args and args.history or nil
    local route = args and args.route or nil
    local biomeLookup = args and args.biomeLookup or nil
    local resultFindings = {}
    for _, biomeKey in ipairs(route and route.biomes or EMPTY_LIST) do
        local biome = biomeLookup and biomeLookup[biomeKey] or nil
        if biome ~= nil then
            local invalid, findings = validateInOrder(history, biome, structureValidators)
            common.appendFindings(resultFindings, findings)
            if invalid == nil then
                invalid, findings = validateInOrder(history, biome, ruleValidators)
                common.appendFindings(resultFindings, findings)
            end
            if invalid ~= nil then
                return {
                    valid = false,
                    invalids = { invalid },
                    findings = findings and findings[1] ~= nil and findings or resultFindings,
                }
            end
        end
    end
    return common.validResult(resultFindings)
end

return biomeStructure
