local plannerOptions = import("mods/ui/planner/options.lua")

local persistence = {}

function persistence.persistDraft(state)
    local control = state.draftControl
    if control ~= nil then
        local changed = control:writeDraft(plannerOptions.deepCopy(state.draft))
        if control.revision ~= nil then
            state.draftControlRevision = control:revision()
        end
        return changed
    end
    return false
end

function persistence.draftChanged(state)
    state.markDirty()
    persistence.persistDraft(state)
end

local function controlRevision(control)
    if control.revision == nil then
        return nil
    end
    return control:revision()
end

local function loadDraftFromControl(state, control, revision, onLoad)
    state.draftControl = control
    state.draftControlRevision = revision
    state.draft = plannerOptions.deepCopy(control:readDraft())
    onLoad(state)
    state.markDirty()
    return true
end

function persistence.bindDraftControl(state, control, onLoad)
    if control == nil then
        return false
    end
    if type(control.readDraft) ~= "function" or type(control.writeDraft) ~= "function" then
        error("PlannerDraft control must expose readDraft() and writeDraft()")
    end
    if control.revision ~= nil and type(control.revision) ~= "function" then
        error("PlannerDraft control revision must be a function when provided")
    end

    local revision = controlRevision(control)
    if control == state.draftControl then
        if revision ~= nil and revision ~= state.draftControlRevision then
            return loadDraftFromControl(state, control, revision, onLoad)
        end
        return false
    end

    return loadDraftFromControl(state, control, revision, onLoad)
end

function persistence.bindUiContext(state, ctx, onLoad)
    return persistence.bindDraftControl(state, ctx.controls.get(state.draftControlName), onLoad)
end

return persistence
