local routeForm = import("mods/forms/route.lua")
local historyBuilder = import("mods/history/builder.lua")
local structuralValidator = import("mods/validation/structural.lua")

local routePipeline = {}

local function addFeedback(feedback, finding, address)
    feedback[#feedback + 1] = {
        address = address,
        severity = finding.severity,
        code = finding.code,
        phase = finding.phase,
        message = finding.message,
        payload = finding.payload or {},
        field = finding.field,
    }
end

local function completionFeedback(completion)
    local feedback = {}
    for _, finding in ipairs(completion.findings or {}) do
        addFeedback(feedback, finding, finding.address)
    end
    return feedback
end

local function validationFeedback(validation)
    local feedback = {}
    for _, finding in ipairs(validation.findings or {}) do
        addFeedback(feedback, finding, finding.sourceAddress)
    end
    return feedback
end

local function status(state, feedback)
    return {
        state = state,
        feedbackCount = #feedback,
        firstIssue = feedback[1],
    }
end

local function contextWithCandidateRecords(context, candidateRecords)
    local copy = {}
    for key, value in pairs(context or {}) do
        copy[key] = value
    end
    copy.candidateRecords = candidateRecords
    return copy
end

function routePipeline.evaluate(draft, context)
    context = context or {}

    local completion = routeForm.isComplete(draft, context)
    if not completion.complete then
        local feedback = completionFeedback(completion)
        return {
            state = "incomplete",
            complete = false,
            valid = false,
            status = status("incomplete", feedback),
            completion = completion,
            candidateRecords = {},
            candidateResults = {},
            feedback = feedback,
        }
    end

    local candidateRecords = routeForm.exportCandidates(draft, context)
    local plan = routeForm.materialize(draft, context)
    local history = historyBuilder.build(plan, contextWithCandidateRecords(context, candidateRecords))
    local validation = structuralValidator.validate(history, context)
    local candidateResults = validation.candidateResults or {}

    if not validation.valid then
        local feedback = validationFeedback(validation)
        return {
            state = "invalid",
            complete = true,
            valid = false,
            status = status("invalid", feedback),
            completion = completion,
            plan = plan,
            history = history,
            validation = validation,
            candidateRecords = candidateRecords,
            candidateResults = candidateResults,
            feedback = feedback,
        }
    end

    return {
        state = "valid",
        complete = true,
        valid = true,
        status = status("valid", {}),
        completion = completion,
        plan = plan,
        history = history,
        validation = validation,
        candidateRecords = candidateRecords,
        candidateResults = candidateResults,
        feedback = {},
    }
end

return routePipeline
