local feedback = {}

local function addressMatches(left, right)
    if left == nil or right == nil then
        return false
    end
    for key, value in pairs(left) do
        if right[key] ~= value then
            return false
        end
    end
    for key, value in pairs(right) do
        if left[key] ~= value then
            return false
        end
    end
    return true
end

function feedback.forAddress(evaluation, address)
    for _, finding in ipairs((evaluation and evaluation.feedback) or {}) do
        if addressMatches(finding.address, address) then
            return finding
        end
    end
    return nil
end

return feedback
