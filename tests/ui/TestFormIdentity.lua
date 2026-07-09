-- luacheck: globals TestFormIdentity

local lu = require("luaunit")
local h = dofile("tests/support/import_harness.lua")

TestFormIdentity = {}

local CONTEXT = {
    routeKey = "Underworld",
    biomeIndex = 1,
    roomIndex = 2,
    doorIndex = 3,
}

function TestFormIdentity.testRoomIdentityOwnsAddressAndControlIds()
    h.withTestImport(function()
        local identity = h.testImport("mods/ui/forms/identity.lua")
        local form = identity.room(CONTEXT)

        lu.assertEquals(form.kind, "room")
        lu.assertEquals(form.id, "routeUnderworld_biome1_room2")
        lu.assertEquals(identity.address(form), {
            routeKey = "Underworld",
            biomeIndex = 1,
            roomIndex = 2,
        })
        lu.assertEquals(identity.control(form, "Room", "roomKey"), "Room##routeUnderworld_biome1_room2_roomKey")
    end)
end

function TestFormIdentity.testGeneratedOfferIdentityExtendsDoorAddress()
    h.withTestImport(function()
        local identity = h.testImport("mods/ui/forms/identity.lua")
        local form = identity.generatedOffer(CONTEXT, 1)

        lu.assertEquals(form.kind, "generatedOffer")
        lu.assertEquals(form.id, "routeUnderworld_biome1_room2_door3_offer1")
        lu.assertEquals(identity.address(form), {
            routeKey = "Underworld",
            biomeIndex = 1,
            roomIndex = 2,
            doorIndex = 3,
            offerIndex = 1,
        })
        lu.assertEquals(
            identity.control(form, "Reward", "rewardType"),
            "Reward##routeUnderworld_biome1_room2_door3_offer1_rewardType"
        )
    end)
end

function TestFormIdentity.testRoomOfferIdentityUsesOfferPointAxis()
    h.withTestImport(function()
        local identity = h.testImport("mods/ui/forms/identity.lua")
        local form = identity.roomOffer(CONTEXT, 1, 1)

        lu.assertEquals(form.kind, "roomOffer")
        lu.assertEquals(form.id, "routeUnderworld_biome1_room2_offerPoint1_offer1")
        lu.assertEquals(identity.address(form), {
            routeKey = "Underworld",
            biomeIndex = 1,
            roomIndex = 2,
            offerPointIndex = 1,
            offerIndex = 1,
        })
    end)
end
