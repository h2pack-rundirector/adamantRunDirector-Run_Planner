-- luacheck: globals rom import_as_fallback modutil lib _PLUGIN game

local mods = rom.mods
mods["SGG_Modding-ENVY"].auto()

---@diagnostic disable: lowercase-global
rom = rom
_PLUGIN = _PLUGIN
game = rom.game
modutil = mods["SGG_Modding-ModUtil"]
local reload = mods["SGG_Modding-ReLoad"]
---@module "adamant-ModpackLib"
---@type AdamantModpackLib
lib = mods["adamant-ModpackLib"]

local PACK_ID = "run-director"
local MODULE_ID = "Run_Planner"
local PLUGIN_GUID = _PLUGIN.guid

local function init()
    import_as_fallback(rom.game)

    local data = import("mods/data.lua")
    local catalog = data.loadCatalog()
    local routeControls = data.buildControls(catalog)
    local rewardLegality = import("mods/route/reward_legality.lua", nil, {
        routeRules = import("mods/rewards/route_rules.lua"),
    })
    local routeTimeline = import("mods/route/timeline.lua")
    local routeContext = import("mods/route/run_context.lua", nil, {
        rewardLegality = rewardLegality,
        timeline = routeTimeline,
    })
    local logic = import("mods/logic.lua").bind(data)
    local ui = import("mods/ui.lua").bind({
        catalog = catalog,
        data = data,
        routeContext = routeContext,
        routeControlTabs = data.routeControlTabs(catalog),
        routeStatusUi = import("mods/controls/route_status_ui.lua"),
    })

    local module = lib.createModule({
        pluginGuid = PLUGIN_GUID,
        modpack = PACK_ID,
        id = MODULE_ID,
        name = "Run Planner",
        shortName = "Run Planner",
        tooltip = "Plan biome room and reward routing by depth.",
    })
    if not module then
        return
    end

    module.controls.defineTemplates(data.loadControlTemplates())
    module.controls.define(routeControls)
    module.ui.tab(ui.drawTab)
    module.fallbackUi.attachGuiOnce(function(fallbackUi)
        rom.gui.add_imgui(fallbackUi.renderWindow)
        rom.gui.add_to_menu_bar(fallbackUi.addMenuBar)
    end)

    logic.attach(module)

    local ok = module.activate()
    if not ok then
        return
    end
end

local loader = reload.auto_single()

modutil.once_loaded.game(function()
    loader.load(nil, init)
end)
