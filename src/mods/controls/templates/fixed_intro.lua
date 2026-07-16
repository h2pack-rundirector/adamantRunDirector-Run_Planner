local deps = ...
local countedBindings = deps.countedBindings
local countedChoice = deps.countedChoice
local none = deps.none

local fixedIntro = {}

local function fail(room, message)
    error("FixedIntro room '" .. room.key .. "' " .. message, 0)
end

local function unavailableView()
    error("planner controls have no production draw view before the editor checkpoint", 0)
end

function fixedIntro.prepare(_, room)
    if room.kind ~= "Intro" then
        fail(room, "must have kind 'Intro'")
    end
    if room.encounterProfileKey ~= "FixedIntro" then
        fail(room, "requires encounter profile 'FixedIntro'")
    end
    if #room.localChildren ~= 0 then
        fail(room, "cannot declare local children")
    end
    if room.incomingReward.kind == "none" then
        return {}
    end
    if room.incomingReward.kind == "countedChoice" then
        return {}
    end
    fail(room, "requires a none or countedChoice incoming reward")
end

local Template = {}

function Template.prepare(instance)
    if instance.incomingReward.kind == "none" then
        instance.generatedReward = none.prepare(instance.incomingReward)
        instance.generatedRewardComponent = none
    else
        instance.generatedReward = countedChoice.prepare(
            countedBindings.compile(instance.incomingReward),
            "Reward"
        )
        instance.generatedRewardComponent = countedChoice
    end
    return instance
end

function Template.storage(instance)
    return instance.generatedRewardComponent.storage(instance.generatedReward)
end

local function context(instance)
    return "room control '" .. instance.name .. "' generatedReward"
end

local function createRuntime(fields, instance)
    local control = {}
    local rewardContext = context(instance)
    local component = instance.generatedRewardComponent

    function control.read(_)
        return {
            kind = "FixedIntro",
            generatedReward = component.read(fields, instance.generatedReward, rewardContext),
        }
    end

    function control.isComplete(_)
        local value = component.read(fields, instance.generatedReward, rewardContext)
        return component.isComplete(instance.generatedReward, value)
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
        instance.generatedRewardComponent.write(
            fields,
            instance.generatedReward,
            value,
            rewardContext
        )
    end

    return control
end

Template.views = { default = unavailableView }
fixedIntro.template = Template

return fixedIntro
