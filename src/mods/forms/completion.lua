local completion = {}

local function newResult()
    return {
        complete = true,
        findings = {},
    }
end

local function addFinding(result, finding)
    result.complete = false
    result.findings[#result.findings + 1] = finding
    return result
end

function completion.ok()
    return newResult()
end

function completion.finding(address, code, message, field)
    return {
        severity = "incomplete",
        address = address,
        code = code,
        message = message,
        field = field,
    }
end

function completion.add(result, address, code, message, field)
    return addFinding(result, completion.finding(address, code, message, field))
end

function completion.merge(result, child)
    for _, finding in ipairs(child.findings or {}) do
        addFinding(result, finding)
    end
    return result
end

return completion
