local feedback = {}

local function firstIssue(evaluation)
    return evaluation and evaluation.status and evaluation.status.firstIssue or nil
end

local function isRouteBlocker(finding)
    return finding ~= nil and finding.severity ~= "incomplete"
end

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

function feedback.firstRouteBlocker(evaluation)
    local issue = firstIssue(evaluation)
    if isRouteBlocker(issue) then
        return issue
    end
    return nil
end

function feedback.firstRouteBlockerForAddress(evaluation, address)
    local routeBlocker = feedback.firstRouteBlocker(evaluation)
    if routeBlocker ~= nil and addressMatches(routeBlocker.address, address) then
        return routeBlocker
    end
    return nil
end

return feedback
