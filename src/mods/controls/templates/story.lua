local deps = ...
local fixed = deps.fixed
local primitives = deps.primitives

local story = {}

local function fail(room, message)
    error("Story room '" .. room.key .. "' " .. message, 0)
end

local function unavailableView()
    error("planner controls have no production draw view before the editor checkpoint", 0)
end

function story.prepare(_, room)
    if room.kind ~= "Story" and room.kind ~= "Bridge" then
        fail(room, "must have kind 'Story' or 'Bridge'")
    end
    if room.incomingReward.kind ~= "fixed" or room.incomingReward.rewardType ~= "Story" then
        fail(room, "requires the fixed Story incoming reward")
    end
    if room.encounterProfileKey ~= "Story" and room.encounterProfileKey ~= "FieldsBridge" then
        fail(room, "requires a story encounter profile")
    end
    if #room.localChildren ~= 0 then
        fail(room, "cannot declare local children")
    end
    return {}
end

local Template = {}

function Template.prepare(instance)
    instance.generatedReward = fixed.prepare(primitives.lookup.Story, "Reward")
    return instance
end

function Template.storage(instance)
    return fixed.storage(instance.generatedReward)
end

local function context(instance)
    return "room control '" .. instance.name .. "' generatedReward"
end

local function createRuntime(fields, instance)
    local control = {}
    local rewardContext = context(instance)

    function control.read(_)
        return {
            kind = "Story",
            generatedReward = fixed.read(fields, instance.generatedReward, rewardContext),
        }
    end

    function control.isComplete(_)
        local value = fixed.read(fields, instance.generatedReward, rewardContext)
        return fixed.isComplete(instance.generatedReward, value)
    end

    return control
end

function Template.createRuntime(fields, instance)
    return createRuntime(fields, instance)
end

function Template.createUi(fields, instance)
    return createRuntime(fields, instance)
end

Template.views = { default = unavailableView }
story.template = Template

return story
