local deps = ...
local storeChoice = deps.storeChoice

local standardCombat = {}

local function unavailableView()
    error("planner controls have no production draw view before the editor checkpoint", 0)
end

local function requireEqual(actual, expected, label, room)
    if actual ~= expected then
        error(
            "StandardCombat room '" .. room.key .. "' requires " .. label .. " '" .. expected
                .. "', got '" .. tostring(actual) .. "'",
            0
        )
    end
end

function standardCombat.prepare(catalog, room)
    requireEqual(room.kind, "Combat", "kind", room)
    requireEqual(room.incomingReward.kind, "countedChoice", "incoming reward binding kind", room)
    requireEqual(room.encounterProfileKey, "StandardCombat", "encounter profile", room)
    if #room.localChildren ~= 0 then
        error("StandardCombat room '" .. room.key .. "' cannot declare local children", 0)
    end
    return {
        generatedReward = storeChoice.prepare(
            catalog,
            room.incomingReward,
            "Reward"
        ),
    }
end

local Template = {}

function Template.storage(instance)
    return storeChoice.storage(instance.generatedReward)
end

local function controlContext(instance)
    return "room control '" .. instance.name .. "' generatedReward"
end

local function createRuntime(fields, instance)
    local control = {}
    local context = controlContext(instance)

    function control.read(_)
        return {
            kind = "StandardCombat",
            generatedReward = storeChoice.read(fields, instance.generatedReward, context),
        }
    end

    return control
end

function Template.createRuntime(fields, instance)
    return createRuntime(fields, instance)
end

function Template.createUi(fields, instance)
    local control = createRuntime(fields, instance)
    local context = controlContext(instance)

    function control.setGeneratedReward(_, value)
        storeChoice.write(fields, instance.generatedReward, value, context)
    end

    return control
end

Template.views = { default = unavailableView }
standardCombat.template = Template

return standardCombat
