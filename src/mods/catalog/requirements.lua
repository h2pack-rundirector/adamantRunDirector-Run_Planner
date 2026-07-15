local deps = ...
local s = deps.schema
local kindRegistry = deps.kindRegistry

local requirements = {}

local function allowed(node, path, contract)
    local keys = { "kind", "code" }
    for _, key in ipairs(contract.fields) do
        keys[#keys + 1] = key
    end
    s.onlyKeys(node, keys, path)
end

local function validateNode(node, registry, path, contactPhase, resolvingNamed)
    s.table(node, path)
    resolvingNamed = resolvingNamed or {}
    if node.named ~= nil then
        s.onlyKeys(node, { "named" }, path)
        s.string(node.named, path .. ".named")
        local target = registry.named[node.named]
        if target == nil then
            s.fail(path .. ".named", "unknown named requirement '" .. node.named .. "'")
        end
        if resolvingNamed[node.named] then
            s.fail(path .. ".named", "cyclic named requirement reference '" .. node.named .. "'")
        end
        resolvingNamed[node.named] = true
        validateNode(target, registry, "requirements.named." .. node.named, contactPhase, resolvingNamed)
        resolvingNamed[node.named] = nil
        return
    end

    s.string(node.kind, path .. ".kind")
    local contract = kindRegistry[node.kind]
    if contract == nil then
        s.fail(path .. ".kind", "unknown modeled requirement kind '" .. node.kind .. "'")
    end
    if contactPhase ~= nil and not s.contains(contract.contactPhases, contactPhase) then
        s.fail(
            path .. ".kind",
            "kind '" .. node.kind .. "' has no evaluator at contact phase '" .. contactPhase .. "'"
        )
    end
    allowed(node, path, contract)
    if node.kind == "All" then
        if node.code ~= nil then
            s.fail(path .. ".code", "All propagates child failures and must not declare a code")
        end
    else
        s.string(node.code, path .. ".code")
    end

    if contract.childShape == "many" then
        s.list(node.requirements, path .. ".requirements", true)
        for index, child in ipairs(node.requirements) do
            validateNode(
                child,
                registry,
                path .. ".requirements[" .. tostring(index) .. "]",
                contactPhase,
                resolvingNamed
            )
        end
    elseif contract.childShape == "one" then
        validateNode(node.requirement, registry, path .. ".requirement", contactPhase, resolvingNamed)
    else
        contract.validatePayload(node, path)
    end
end

function requirements.validateNode(node, registry, path, contactPhase)
    validateNode(node, registry, path, contactPhase, {})
end

function requirements.validateRegistry(raw)
    local registry = s.copy(raw)
    s.table(registry, "requirements")
    s.onlyKeys(registry, { "named" }, "requirements")
    s.table(registry.named, "requirements.named")
    for key, node in pairs(registry.named) do
        s.string(key, "requirements.named.<key>")
        validateNode(node, registry, "requirements.named." .. key, nil, { [key] = true })
    end
    return registry
end

function requirements.validateReferences(node, registry, references, path, resolvingNamed)
    if node == nil then
        return
    end
    resolvingNamed = resolvingNamed or {}
    if node.named ~= nil then
        if resolvingNamed[node.named] then
            s.fail(path .. ".named", "cyclic named requirement reference '" .. node.named .. "'")
        end
        resolvingNamed[node.named] = true
        requirements.validateReferences(
            registry.named[node.named],
            registry,
            references,
            "requirements.named." .. node.named,
            resolvingNamed
        )
        resolvingNamed[node.named] = nil
        return
    end

    local contract = kindRegistry[node.kind]
    if contract.validateReferences ~= nil then
        contract.validateReferences(node, references, path)
    end
    for index, child in ipairs(node.requirements or {}) do
        requirements.validateReferences(
            child,
            registry,
            references,
            path .. ".requirements[" .. tostring(index) .. "]",
            resolvingNamed
        )
    end
    if node.requirement ~= nil then
        requirements.validateReferences(
            node.requirement,
            registry,
            references,
            path .. ".requirement",
            resolvingNamed
        )
    end
end

function requirements.staticCompatibility(node, registry, context, excludedKinds, path)
    if node == nil then
        return true
    end
    if node.named ~= nil then
        return requirements.staticCompatibility(
            registry.named[node.named],
            registry,
            context,
            excludedKinds,
            path .. ".named(" .. node.named .. ")"
        )
    end

    local contract = kindRegistry[node.kind]
    if contract.capacity == "dynamic" then
        excludedKinds[node.kind] = true
        return nil
    end
    if contract.staticEvaluate ~= nil then
        return contract.staticEvaluate(node, context, path)
    end
    if contract.staticCombine == "all" then
        local unknown = false
        for index, child in ipairs(node.requirements) do
            local result = requirements.staticCompatibility(
                child,
                registry,
                context,
                excludedKinds,
                path .. ".requirements[" .. tostring(index) .. "]"
            )
            if result == false then return false end
            if result == nil then unknown = true end
        end
        return unknown and nil or true
    end
    if contract.staticCombine == "any" then
        local unknown = false
        for index, child in ipairs(node.requirements) do
            local result = requirements.staticCompatibility(
                child,
                registry,
                context,
                excludedKinds,
                path .. ".requirements[" .. tostring(index) .. "]"
            )
            if result == true then return true end
            if result == nil then unknown = true end
        end
        return unknown and nil or false
    end
    if contract.staticCombine == "not" then
        local result = requirements.staticCompatibility(
            node.requirement,
            registry,
            context,
            excludedKinds,
            path .. ".requirement"
        )
        return result == nil and nil or not result
    end
    s.fail(path .. ".kind", "static capacity evaluator is not registered")
end

return requirements
