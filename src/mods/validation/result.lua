local result = {}

function result.new()
    return {
        valid = true,
        findings = {},
        candidateResults = {},
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

function result.candidate(target, record, code, phase, presentation, payload, message, color)
    local candidate = {
        formAddress = record.formAddress,
        providerKey = record.providerKey,
        providerVersion = record.providerVersion,
        candidateKey = record.candidateKey,
        candidateIndex = record.candidateIndex,
        presentation = presentation,
        code = code,
        phase = phase,
        payload = payload or {},
        message = message,
        color = color,
    }
    target.candidateResults[#target.candidateResults + 1] = candidate
    return candidate
end

return result
