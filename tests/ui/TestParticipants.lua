-- luacheck: globals TestParticipants

local lu = require("luaunit")
local h = dofile("tests/support/import_harness.lua")

TestParticipants = {}

function TestParticipants.testRegistryCachesGeneratedDoorParticipantsByIdentity()
    h.withTestImport(function()
        local participants = h.testImport("mods/ui/forms/participants.lua")
        local identity = h.testImport("mods/ui/forms/identity.lua")
        local registry = participants.create()
        local context = {
            routeKey = "Underworld",
            biomeIndex = 1,
            roomIndex = 2,
            doorIndex = 1,
        }
        local node = {
            targetRoomKey = "F_Combat02",
        }

        local first = registry:generatedDoor(context, node)
        local second = registry:generatedDoor(context)

        lu.assertTrue(first == second)
        lu.assertEquals(first.kind, "generatedDoor")
        lu.assertEquals(first.id, "routeUnderworld_biome1_room2_door1")
        lu.assertEquals(first.address, context)
        lu.assertEquals(first.providers, {})
        lu.assertTrue(first.node == node)
        lu.assertTrue(registry:find(identity.generatedDoor(context)) == first)

        registry:clear()
        local rebuilt = registry:generatedDoor(context)

        lu.assertFalse(rebuilt == first)
        lu.assertEquals(rebuilt.id, first.id)
    end)
end

function TestParticipants.testRegistryCreatesParticipantKinds()
    h.withTestImport(function()
        local participants = h.testImport("mods/ui/forms/participants.lua")
        local registry = participants.create()
        local context = {
            routeKey = "Underworld",
            biomeIndex = 1,
            roomIndex = 2,
            doorIndex = 1,
        }

        lu.assertEquals(registry:room(context).kind, "room")
        lu.assertEquals(registry:generatedDoor(context).kind, "generatedDoor")
        lu.assertEquals(registry:generatedOffer(context, 1).kind, "generatedOffer")
        lu.assertEquals(registry:roomOffer(context, 1, 1).kind, "roomOffer")
    end)
end
