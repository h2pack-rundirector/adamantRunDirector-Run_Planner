local result = {}

function result.new()
    return {
        valid = true,
        findings = {},
    }
end

function result.add(target, finding)
    target.valid = false
    target.findings[#target.findings + 1] = finding
    return finding
end

function result.invalid(target, code, phase, sourceAddress, payload, message)
    return result.add(target, {
        severity = "invalid",
        code = code,
        phase = phase,
        sourceAddress = sourceAddress,
        payload = payload or {},
        message = message,
    })
end

return result
