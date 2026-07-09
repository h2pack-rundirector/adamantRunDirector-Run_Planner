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

local function bindNode(participant, node)
    if node ~= nil then
        participant.node = node
    end
    return participant
end

function participants.create()
    local registry = {
        byId = {},
    }

    function registry:find(form)
        return self.byId[form.id]
    end

    function registry:get(form)
        local participant = self.byId[form.id]
        if participant == nil then
            participant = createParticipant(form)
            self.byId[form.id] = participant
        end
        return participant
    end

    function registry:room(context, node)
        return bindNode(self:get(identity.room(context)), node)
    end

    function registry:generatedDoor(context, node)
        return bindNode(self:get(identity.generatedDoor(context)), node)
    end

    function registry:generatedOffer(context, offerIndex, node)
        return bindNode(self:get(identity.generatedOffer(context, offerIndex)), node)
    end

    function registry:roomOffer(context, offerPointIndex, offerIndex, node)
        return bindNode(self:get(identity.roomOffer(context, offerPointIndex, offerIndex)), node)
    end

    function registry:clear()
        self.byId = {}
    end

    return registry
end

return participants
