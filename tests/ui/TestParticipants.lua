-- luacheck: globals TestParticipants

local lu = require("luaunit")
local h = dofile("tests/support/import_harness.lua")

TestParticipants = {}

function TestParticipants.testRegistryCachesGeneratedDoorParticipantsByIdentity()
    h.withTestImport(function()
        local participants = h.testImport("mods/ui/forms/participants.lua")
        local registry = participants.create()
        local context = {
            routeKey = "Underworld",
            biomeIndex = 1,
            roomIndex = 2,
            doorIndex = 1,
        }

        local first = registry:generatedDoor(context)
        local second = registry:generatedDoor(context)

        lu.assertTrue(first == second)
        lu.assertEquals(first.kind, "generatedDoor")
        lu.assertEquals(first.id, "routeUnderworld_biome1_room2_door1")
        lu.assertEquals(first.address, context)
        lu.assertEquals(first.providers, {})

        registry:clear()
        local rebuilt = registry:generatedDoor(context)

        lu.assertFalse(rebuilt == first)
        lu.assertEquals(rebuilt.id, first.id)
    end)
end
