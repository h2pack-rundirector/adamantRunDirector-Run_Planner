local deps = ...
local countedBindings = deps.countedBindings
local countedChoice = deps.countedChoice
local rewardUi = deps.rewardUi

local fountain = {}

local function fail(room, message)
    error("Fountain room '" .. room.key .. "' " .. message, 0)
end

function fountain.prepare(_, room)
    if room.kind ~= "Reprieve" then
        fail(room, "must have kind 'Reprieve'")
    end
    if room.incomingReward.kind ~= "countedChoice" then
        fail(room, "requires a countedChoice incoming reward")
    end
    if room.encounterProfileKey ~= "HealthRestore" then
        fail(room, "requires encounter profile 'HealthRestore'")
    end
    if #room.localChildren ~= 0 then
        fail(room, "cannot declare local children")
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

local function context(instance)
    return "room control '" .. instance.name .. "' generatedReward"
end

local function createRuntime(fields, instance)
    local control = {}
    local rewardContext = context(instance)

    function control.read(_)
        return {
            kind = "Fountain",
            generatedReward = countedChoice.read(fields, instance.generatedReward, rewardContext),
        }
    end

    function control.isComplete(_)
        local value = countedChoice.read(fields, instance.generatedReward, rewardContext)
        return countedChoice.isComplete(instance.generatedReward, value)
    end

    return control
end

function Template.createRuntime(fields, instance)
    return createRuntime(fields, instance)
end

function Template.createUi(fields, instance)
    local control = createRuntime(fields, instance)
    local rewardContext = context(instance)

    function control.setGeneratedReward(_, value)
        countedChoice.write(fields, instance.generatedReward, value, rewardContext)
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
fountain.template = Template

return fountain
