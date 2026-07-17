local deps = ...
local countedBindings = deps.countedBindings
local countedChoice = deps.countedChoice
local rewardUi = deps.rewardUi

local standardCombat = {}

local function requireEqual(actual, expected, label, room)
    if actual ~= expected then
        error(
            "StandardCombat room '" .. room.key .. "' requires " .. label .. " '" .. expected
                .. "', got '" .. tostring(actual) .. "'",
            0
        )
    end
end

function standardCombat.prepare(_, room)
    requireEqual(room.kind, "Combat", "kind", room)
    requireEqual(room.incomingReward.kind, "countedChoice", "incoming reward binding kind", room)
    requireEqual(room.encounterProfileKey, "StandardCombat", "encounter profile", room)
    if #room.localChildren ~= 0 then
        error("StandardCombat room '" .. room.key .. "' cannot declare local children", 0)
    end
    return {}
end

local Template = {}

function Template.prepare(instance)
    instance.generatedReward = rewardUi.prepareCounted(countedChoice.prepare(
        countedBindings.compile(instance.incomingReward),
        "Reward"
    ))
    return instance
end

function Template.storage(instance)
    return countedChoice.storage(instance.generatedReward)
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
            generatedReward = countedChoice.read(fields, instance.generatedReward, context),
        }
    end

    function control.isComplete(_)
        local reward = countedChoice.read(fields, instance.generatedReward, context)
        return countedChoice.isComplete(instance.generatedReward, reward)
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
        countedChoice.write(fields, instance.generatedReward, value, context)
    end

    function control.drawGeneratedReward(_, draw)
        rewardUi.drawCounted(draw, fields, instance.generatedReward)
    end

    return control
end

Template.views = {
    default = function(draw, control)
        control:drawGeneratedReward(draw)
    end,
}
standardCombat.template = Template

return standardCombat
