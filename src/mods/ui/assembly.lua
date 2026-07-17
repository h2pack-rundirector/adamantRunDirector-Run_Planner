local deps = ... or {}

local selectorBuilder = deps.selectors or import("mods/ui/selectors.lua")
local authoredResult = deps.authoredResult or import("mods/ui/authored_result.lua")
local linearBiomeLayout = deps.linearBiomeLayout
    or import("mods/ui/layouts/linear_biome.lua")
local linearBiomeDraw = deps.linearBiomeDraw
    or import("mods/ui/layouts/linear_biome_draw.lua")

local EDITABLE_BIOME_STEPS = {
    "Underworld_F",
}

local assembly = {}

function assembly.create(catalog, route)
    local selectorManifest = selectorBuilder.build(catalog, EDITABLE_BIOME_STEPS)
    local layouts = {
        LinearBiome = linearBiomeLayout.create(catalog),
    }
    local layoutDrawers = {
        LinearBiome = linearBiomeDraw,
    }
    local evidence = { authoredEditor = {} }
    for _, biomeStepKey in ipairs(EDITABLE_BIOME_STEPS) do
        local plan = route.biomePlans.lookup[biomeStepKey]
        if plan == nil or layouts[plan.layoutKind] == nil or layoutDrawers[plan.layoutKind] == nil then
            error("authored editor biome '" .. biomeStepKey .. "' is not fully assembled", 0)
        end
        evidence.authoredEditor[biomeStepKey] = true
    end
    local coordinator = authoredResult.create(catalog, route, layouts, selectorManifest)
    local moduleUi = import("mods/ui.lua", nil, {
        coordinator = coordinator,
        selectors = selectorManifest,
        layoutDrawers = layoutDrawers,
    })
    return {
        attach = moduleUi.attach,
        drawTab = moduleUi.drawTab,
        coordinator = coordinator,
        layouts = layouts,
        layoutDrawers = layoutDrawers,
        selectors = selectorManifest,
        storage = selectorManifest.storage,
        capabilityEvidence = evidence,
    }
end

return assembly
