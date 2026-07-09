local presentationColors = {}

presentationColors.blocker = { 1.0, 0.25, 0.20, 1.0 }
presentationColors.invalid = { 1.0, 0.35, 0.25, 1.0 }
presentationColors.incomplete = { 1.0, 0.72, 0.25, 1.0 }
presentationColors.warning = { 1.0, 0.82, 0.35, 1.0 }
presentationColors.muted = { 0.65, 0.65, 0.65, 1.0 }
presentationColors.valid = { 0.45, 0.85, 0.45, 1.0 }

local function findingSeverity(finding)
    return finding and (finding.severity or finding.presentation) or nil
end

function presentationColors.forFinding(finding, role)
    if finding == nil then
        return nil
    end
    if role == "blocker" then
        return presentationColors.blocker
    end

    local severity = findingSeverity(finding)
    if severity == "incomplete" then
        return presentationColors.incomplete
    end
    if severity == "warning" then
        return presentationColors.warning
    end
    if severity == "muted" then
        return presentationColors.muted
    end
    return presentationColors.invalid
end

function presentationColors.forEvaluation(evaluation)
    if evaluation == nil then
        return nil
    end
    if evaluation.valid == true then
        return presentationColors.valid
    end
    if evaluation.complete == false or evaluation.state == "incomplete" then
        return presentationColors.incomplete
    end
    return presentationColors.invalid
end

return presentationColors
