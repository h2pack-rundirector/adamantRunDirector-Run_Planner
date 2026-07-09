local identity = import("mods/ui/forms/identity.lua")

local participants = {}

local function createParticipant(form)
    return {
        kind = form.kind,
        id = form.id,
        address = form.address,
        providers = {},
    }
end

function participants.create()
    local registry = {
        byId = {},
    }

    function registry:get(form)
        local participant = self.byId[form.id]
        if participant == nil then
            participant = createParticipant(form)
            self.byId[form.id] = participant
        end
        return participant
    end

    function registry:generatedDoor(context)
        return self:get(identity.generatedDoor(context))
    end

    function registry:clear()
        self.byId = {}
    end

    return registry
end

return participants
