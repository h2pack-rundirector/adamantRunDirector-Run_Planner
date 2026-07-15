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

local function drawUnavailable(_, ui)
    ui.draw.widgets.text("Run Planner is being rebuilt from the locked revamp design.")
end

local function init()
    import_as_fallback(rom.game)

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

    local catalog = import("mods/composition/catalog.lua").load()
    import("mods/composition/managed_state.lua").install(module, catalog)

    module.ui.tab(drawUnavailable)
    module.fallbackUi.attachGuiOnce(function(fallbackUi)
        rom.gui.add_imgui(fallbackUi.renderWindow)
        rom.gui.add_to_menu_bar(fallbackUi.addMenuBar)
    end)

    module.activate()
end

local loader = reload.auto_single()

modutil.once_loaded.game(function()
    loader.load(nil, init)
end)
