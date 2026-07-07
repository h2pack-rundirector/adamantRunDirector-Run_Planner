local data = {}

local PLANNER_DRAFT_CONTROL = "PlannerDraft"

function data.loadCatalog()
    return import("mods/declarations/loader.lua").load()
end

function data.buildStorage()
    return {
        {
            alias = "SelectedRoute",
            type = "string",
            default = "Underworld",
            maxLen = 32,
        },
        {
            alias = "SelectedUnderworldBiome",
            type = "string",
            default = "F",
            maxLen = 32,
        },
        {
            alias = "SelectedSurfaceBiome",
            type = "string",
            default = "N",
            maxLen = 32,
        },
    }
end

function data.buildControlTemplates()
    return import("mods/controls/templates.lua")
end

function data.buildControls()
    return {
        [PLANNER_DRAFT_CONTROL] = {
            template = "PlannerDraft",
        },
    }
end

data.PLANNER_DRAFT_CONTROL = PLANNER_DRAFT_CONTROL

return data
