-- luacheck: globals TestRoomTemplates

local lu = require("luaunit")
local h = dofile("tests/support/import_harness.lua")

TestRoomTemplates = {}

local function load()
    return h.testImport("mods/systems.lua").create()
end

local function field(default)
    local value = default
    return {
        read = function()
            return value
        end,
        write = function(_, nextValue)
            value = nextValue
        end,
    }
end

local function fieldsFor(storage)
    local fields = {}
    for _, descriptor in ipairs(storage) do
        fields[descriptor.key] = field(descriptor.default)
    end
    return fields
end

local function storageLookup(storage)
    local result = {}
    for _, descriptor in ipairs(storage) do
        result[descriptor.key] = descriptor
    end
    return result
end

local function controlsFor(systems, name)
    local source = systems.controls.instances[name]
    local instance = {}
    for key, value in pairs(source) do
        instance[key] = value
    end
    instance.name = name
    local template = systems.controls.templates[instance.template]
    if template.prepare ~= nil then
        instance = template.prepare(instance)
    end
    local fields = fieldsFor(template.storage(instance))
    return instance, template, fields,
        template.createRuntime(fields, instance),
        template.createUi(fields, instance)
end

local function authorWorldShop(ui, prefix)
    local setReward = prefix and ui.setShopSlotReward or ui.setSlotReward
    local setPurchased = prefix and ui.setShopPurchased or ui.setPurchased
    setReward(ui, "Boon", {
        rewardType = "RandomLoot",
        payload = { source = "ApolloUpgrade" },
    })
    setReward(ui, "MajorNonBoon", { rewardType = "MaxHealthDrop" })
    setReward(ui, "Minor", { rewardType = "StackUpgrade" })
    setPurchased(ui, "Boon", true)
    setPurchased(ui, "MajorNonBoon", false)
    setPurchased(ui, "Minor", true)
end

function TestRoomTemplates.testSharedImplementationsCoverEveryDeclaredInstance()
    h.withImport(function()
        local systems = load()
        local expected = {
            FixedOpening = 4,
            FixedIntro = 6,
            StandardCombat = 56,
            Miniboss = 20,
            Story = 7,
            Fountain = 5,
            Shop = 4,
            ForkedPreboss = 4,
        }
        local actual = {}
        for _, room in ipairs(systems.catalog.controlManifest.rooms.ordered) do
            if expected[room.templateKey] ~= nil then
                actual[room.templateKey] = (actual[room.templateKey] or 0) + 1
                lu.assertNil(room.prepared.state, room.key)
                lu.assertNil(room.prepared.generatedReward, room.key)
                lu.assertNil(room.prepared.shop, room.key)
                local source = systems.controls.instances[room.key]
                lu.assertNil(source.state, room.key)
                lu.assertNil(source.generatedReward, room.key)
                lu.assertNil(source.generatedRewardComponent, room.key)
                lu.assertNil(source.shop, room.key)
                lu.assertNil(source.freeRewards, room.key)
            end
        end
        lu.assertEquals(actual, expected)

        local f = controlsFor(systems, "Underworld_F_Combat04")
        local g = controlsFor(systems, "Underworld_G_Combat01")
        lu.assertIs(
            f.generatedReward.view.primitives.lookup.Boon,
            g.generatedReward.view.primitives.lookup.Boon
        )
    end)
end

function TestRoomTemplates.testCountedRoomTemplatesUseCompiledPerInstanceShapes()
    h.withImport(function()
        local systems = load()

        local openingInstance, openingTemplate, openingFields, openingRuntime, openingUi = controlsFor(
            systems,
            "Underworld_F_Opening01"
        )
        local openingStorage = storageLookup(openingTemplate.storage(openingInstance))
        lu.assertNil(openingStorage.RewardStoreKey)
        lu.assertNotNil(openingStorage.RewardType)
        lu.assertNotNil(openingStorage.RewardPayload1)
        lu.assertNil(openingStorage.RewardPayload2)
        lu.assertTrue(openingRuntime:isComplete())
        lu.assertEquals(openingRuntime:read().generatedReward, {
            storeKey = "RunProgress",
            rewardType = "Boon",
            payload = { source = "ApolloUpgrade" },
        })
        openingUi:setGeneratedReward({
            rewardType = "Boon",
            payload = { source = "ApolloUpgrade" },
        })
        lu.assertTrue(openingRuntime:isComplete())
        lu.assertEquals(openingRuntime:read().generatedReward.storeKey, "RunProgress")
        lu.assertNotNil(openingFields.RewardType)

        local minibossInstance, minibossTemplate, _, minibossRuntime, minibossUi = controlsFor(
            systems,
            "Underworld_G_MiniBoss01"
        )
        local minibossStorage = storageLookup(minibossTemplate.storage(minibossInstance))
        lu.assertNil(minibossStorage.RewardStoreKey)
        lu.assertNil(minibossStorage.RewardType)
        lu.assertNotNil(minibossStorage.RewardPayload1)
        lu.assertTrue(minibossRuntime:isComplete())
        minibossUi:setGeneratedReward({ payload = { source = "ZeusUpgrade" } })
        lu.assertTrue(minibossRuntime:isComplete())
        lu.assertEquals(minibossRuntime:read().generatedReward.rewardType, "Boon")

        local qInstance, qTemplate = controlsFor(systems, "Surface_Q_MiniBoss02")
        local qStorage = storageLookup(qTemplate.storage(qInstance))
        lu.assertNil(qStorage.RewardStoreKey)
        lu.assertNotNil(qStorage.RewardType)
        lu.assertNotNil(qStorage.RewardPayload1)

        local fountainInstance, fountainTemplate = controlsFor(systems, "Underworld_I_Reprieve01")
        local fountainStorage = storageLookup(fountainTemplate.storage(fountainInstance))
        lu.assertNil(fountainStorage.RewardStoreKey)
        lu.assertNotNil(fountainStorage.RewardType)
        lu.assertNotNil(fountainStorage.RewardPayload1)
        lu.assertNil(fountainStorage.RewardPayload2)
    end)
end

function TestRoomTemplates.testFixedIntroSupportsAbsentAndCountedVariants()
    h.withImport(function()
        local systems = load()
        local gInstance, gTemplate, _, gRuntime, gUi = controlsFor(systems, "Underworld_G_Intro")
        lu.assertEquals(gTemplate.storage(gInstance), {})
        lu.assertEquals(gRuntime:read(), { kind = "FixedIntro" })
        lu.assertTrue(gRuntime:isComplete())
        lu.assertErrorMsgContains("does not accept authored state", function()
            gUi:setGeneratedReward({ rewardType = "Boon" })
        end)

        local qInstance, qTemplate, _, qRuntime, qUi = controlsFor(systems, "Surface_Q_Intro")
        local qStorage = storageLookup(qTemplate.storage(qInstance))
        lu.assertNotNil(qStorage.RewardType)
        lu.assertNotNil(qStorage.RewardPayload1)
        lu.assertTrue(qRuntime:isComplete())
        qUi:setGeneratedReward({
            rewardType = "Boon",
            payload = { source = "ApolloUpgrade" },
        })
        lu.assertTrue(qRuntime:isComplete())
    end)
end

function TestRoomTemplates.testStoryIsFixedStorageFreeAndComplete()
    h.withImport(function()
        local systems = load()
        local instance, template, _, runtime, ui = controlsFor(systems, "Underworld_F_Story01")
        lu.assertEquals(template.storage(instance), {})
        lu.assertEquals(runtime:read(), {
            kind = "Story",
            generatedReward = { rewardType = "Story" },
        })
        lu.assertTrue(runtime:isComplete())
        lu.assertNil(ui.setGeneratedReward)
    end)
end

function TestRoomTemplates.testShopOwnsTypedSlotsAndPurchaseState()
    h.withImport(function()
        local systems = load()
        local instance, template, _, runtime, ui = controlsFor(systems, "Underworld_F_Shop01")
        local storage = storageLookup(template.storage(instance))
        lu.assertNotNil(storage.ShopBoonType)
        lu.assertNotNil(storage.ShopBoonPayload1)
        lu.assertNotNil(storage.ShopBoonPurchased)
        lu.assertNotNil(storage.ShopMajorNonBoonType)
        lu.assertNil(storage.ShopMajorNonBoonPayload1)
        lu.assertTrue(runtime:isComplete())
        lu.assertEquals(runtime:read().shop.slots.Boon.reward, {
            rewardType = "RandomLoot",
            payload = { source = "ApolloUpgrade" },
        })

        authorWorldShop(ui, false)
        lu.assertTrue(runtime:isComplete())
        lu.assertEquals(runtime:read().shop, {
            profileKey = "WorldShop",
            slots = {
                Boon = {
                    reward = {
                        rewardType = "RandomLoot",
                        payload = { source = "ApolloUpgrade" },
                    },
                    purchased = true,
                },
                MajorNonBoon = {
                    reward = { rewardType = "MaxHealthDrop" },
                    purchased = false,
                },
                Minor = {
                    reward = { rewardType = "StackUpgrade" },
                    purchased = true,
                },
            },
        })
        lu.assertErrorMsgContains("is not available from option set 'WorldShopBoon'", function()
            ui:setSlotReward("Boon", { rewardType = "MaxHealthDrop" })
        end)
        lu.assertErrorMsgContains("purchased must be a boolean", function()
            ui:setPurchased("Boon", "yes")
        end)
        lu.assertTrue(runtime:isComplete())
    end)
end

function TestRoomTemplates.testForkedPrebossUsesBoundedStateAndTopologyContext()
    h.withImport(function()
        local systems = load()
        local fInstance, fTemplate, _, fRuntime, fUi = controlsFor(
            systems,
            "Underworld_F_PreBoss01"
        )
        local fStorage = storageLookup(fTemplate.storage(fInstance))
        lu.assertNotNil(fStorage.EntryMode)
        lu.assertNotNil(fStorage.FreeReward1Type)
        lu.assertNil(fStorage.FreeReward2Type)
        lu.assertErrorMsgContains("free reward index '2' is not allowed", function()
            fUi:setFreeReward(2, { rewardType = "Boon" })
        end)
        lu.assertErrorMsgContains("between 0 and 1", function()
            fRuntime:isComplete({ activeFreeRewardCount = 2 })
        end)

        local gInstance, gTemplate, _, gRuntime, gUi = controlsFor(
            systems,
            "Underworld_G_PreBoss01"
        )
        local gStorage = storageLookup(gTemplate.storage(gInstance))
        lu.assertNotNil(gStorage.FreeReward1Type)
        lu.assertNotNil(gStorage.FreeReward2Type)
        lu.assertTrue(gRuntime:isComplete({ activeFreeRewardCount = 0 }))

        authorWorldShop(gUi, true)
        gUi:setEntryMode("Reward2")
        gUi:setFreeReward(1, {
            rewardType = "Boon",
            payload = { source = "ApolloUpgrade" },
        })
        lu.assertTrue(gRuntime:isComplete({ activeFreeRewardCount = 2 }))
        gUi:setFreeReward(2, { rewardType = "MaxHealthDrop" })
        lu.assertTrue(gRuntime:isComplete({ activeFreeRewardCount = 2 }))
        lu.assertFalse(gRuntime:isComplete({ activeFreeRewardCount = 1 }))
        gUi:setEntryMode("Shop")
        lu.assertTrue(gRuntime:isComplete({ activeFreeRewardCount = 1 }))
        lu.assertEquals(#gRuntime:read().freeRewards, 2)
    end)
end
