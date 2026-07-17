-- luacheck: globals TestRewardHierarchy

local lu = require("luaunit")
local h = dofile("tests/support/import_harness.lua")

TestRewardHierarchy = {}

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

local function alignmentDraw()
    local textCalls = {}
    return {
        imgui = {
            SameLine = function() end,
            Spacing = function() end,
        },
        widgets = {
            text = function(value, opts)
                textCalls[#textCalls + 1] = { value = value, opts = opts }
            end,
            dropdown = function()
                return false
            end,
            checkbox = function()
                return false
            end,
        },
    }, textCalls
end

function TestRewardHierarchy.testBuildsPayloadPrimitiveAndBagRegistriesBottomUp()
    h.withImport(function()
        local systems = load()
        local rewards = systems.rewards

        lu.assertEquals(#rewards.payloadDomains.ordered, 2)
        lu.assertEquals(rewards.payloadDomains.ordered[1].key, "BoonSource")
        lu.assertEquals(rewards.payloadDomains.ordered[2].key, "DevotionPair")
        lu.assertEquals(#rewards.primitives.ordered, 57)
        lu.assertEquals(#rewards.bags.ordered, 7)
        lu.assertIs(
            rewards.primitives.lookup.Boon.payload,
            rewards.payloadDomains.lookup.BoonSource
        )
        lu.assertEquals(rewards.primitives.lookup.RandomLoot.acquiredAs, "Boon")
        lu.assertEquals(rewards.primitives.lookup.Boon.acquiredAs, "Boon")

        local runProgress = rewards.bags.lookup.RunProgress
        lu.assertEquals(#runProgress.entries, 18)
        lu.assertEquals(#runProgress.options, 10)
        lu.assertEquals(runProgress.options[1].gameName, "Boon")
        lu.assertEquals(runProgress.entries[1].primitive.gameName, "Boon")
        lu.assertEquals(runProgress.entries[4].primitive.gameName, "Boon")
        lu.assertEquals(rewards.primitives.lookup.AresUpgrade.gameName, "AresUpgrade")
        lu.assertEquals(rewards.primitives.lookup.AresUpgrade.label, "Ares")
        lu.assertEquals(
            rewards.payloadDomains.lookup.BoonSource.valueLabels.AresUpgrade,
            "Ares"
        )
        lu.assertIs(
            rewards.payloadDomains.lookup.DevotionPair.valueLabels,
            rewards.payloadDomains.lookup.BoonSource.valueLabels
        )
        lu.assertEquals(runProgress.entries[6].requirementKey, "DevotionLootRequirements")
        lu.assertEquals(rewards.shops.profiles.lookup.WorldShop.slots.ordered[1], {
            key = "Boon",
            label = "Offer 1",
            optionSet = rewards.shops.optionSets.lookup.WorldShopBoon,
        })
    end)
end

function TestRewardHierarchy.testCompilesPerStoreMembershipAndStaticPayloadCapacity()
    h.withImport(function()
        local systems = load()
        local rewards = systems.rewards

        local ordinary = rewards.countedBindings.compile(
            systems.catalog.biomes.lookup.F.rooms.lookup.F_Combat04.incomingReward
        )
        lu.assertNil(ordinary.fixedStoreKey)
        lu.assertNil(ordinary.fixedRewardType)
        lu.assertEquals(ordinary.storeKeys, { "RunProgress", "MetaProgress" })
        lu.assertEquals(ordinary.maxPayloadArity, 2)
        lu.assertNotNil(ordinary.stores.lookup.RunProgress.primitiveLookup.Devotion)
        lu.assertNil(ordinary.stores.lookup.MetaProgress.primitiveLookup.Devotion)

        local noDevotion = rewards.countedBindings.compile(
            systems.catalog.biomes.lookup.G.rooms.lookup.G_Combat04.incomingReward
        )
        lu.assertEquals(noDevotion.maxPayloadArity, 1)
        lu.assertNil(noDevotion.primitives.lookup.Devotion)

        local minibossBinding = systems.catalog.biomes.lookup.F.rooms.lookup.F_MiniBoss01.incomingReward
        local boonOnly = rewards.countedBindings.compile(minibossBinding)
        lu.assertEquals(boonOnly.fixedStoreKey, "RunProgress")
        lu.assertEquals(boonOnly.fixedRewardType, "Boon")
        lu.assertEquals(boonOnly.rewardTypes, { "Boon" })
        lu.assertEquals(boonOnly.maxPayloadArity, 1)
    end)
end

function TestRewardHierarchy.testPreparedPayloadUiUsesPrimitiveLabelsForGameNames()
    h.withImport(function()
        local systems = load()
        local ordinary = systems.rewards.countedBindings.compile(
            systems.catalog.biomes.lookup.F.rooms.lookup.F_Combat04.incomingReward
        )
        local descriptor = systems.rewards.ui.prepareCounted(
            systems.rewards.countedChoice.prepare(ordinary, "Reward")
        )

        lu.assertEquals(
            descriptor.editor.payloads.Boon.opts.displayValues.AresUpgrade,
            "Ares"
        )
        lu.assertEquals(
            descriptor.editor.payloads.Devotion.first.displayValues.ApolloUpgrade,
            "Apollo"
        )
        lu.assertEquals(
            descriptor.editor.payloads.Devotion.second.displayValues.ZeusUpgrade,
            "Zeus"
        )
    end)
end

function TestRewardHierarchy.testInlineRewardTextAlignsOnlyOnFramedRows()
    h.withImport(function()
        local rewardUi = h.testImport("mods/rewards/ui.lua")
        local boon = { gameName = "Boon", label = "Boon" }
        local draw, textCalls = alignmentDraw()
        rewardUi.drawCounted(draw, { Source = field("") }, {
            view = {
                fixedStoreKey = "RunProgress",
                fixedRewardType = "Boon",
                primitives = { lookup = { Boon = boon } },
            },
            fields = { source1 = "Source" },
            editor = {
                payloads = {
                    Boon = { kind = "oneOf", opts = {} },
                },
            },
        })
        lu.assertEquals(textCalls[1].value, "Boon")
        lu.assertTrue(textCalls[1].opts.alignToFramePadding)

        draw, textCalls = alignmentDraw()
        rewardUi.drawFixed(draw, {}, {
            primitive = { label = "Story" },
            fields = {},
            editor = { payload = { kind = "none" } },
        })
        lu.assertEquals(textCalls, {
            { value = "Story" },
        })

        draw, textCalls = alignmentDraw()
        rewardUi.drawShop(draw, { Purchased = field(false) }, {
            slots = {
                ordered = {
                    {
                        key = "Boon",
                        label = "Offer 1",
                        purchasedField = "Purchased",
                        reward = {
                            optionSet = {
                                fixedRewardType = "Boon",
                                primitiveLookup = { Boon = boon },
                            },
                            fields = {},
                            editor = {
                                payloads = { Boon = { kind = "none" } },
                            },
                        },
                        editor = { purchased = {} },
                    },
                },
            },
        })
        lu.assertEquals(textCalls[1].value, "Offer 1")
        lu.assertTrue(textCalls[1].opts.alignToFramePadding)
        lu.assertEquals(textCalls[2].value, "Boon")
        lu.assertTrue(textCalls[2].opts.alignToFramePadding)
    end)
end

function TestRewardHierarchy.testCompilesEveryDeclaredCountedProducer()
    h.withImport(function()
        local systems = load()
        local count = 0
        local function compile(binding)
            if binding == nil then
                return
            end
            if binding.kind == "countedChoice" then
                local view = systems.rewards.countedBindings.compile(binding)
                count = count + 1
                lu.assertNotEquals(#view.primitives.ordered, 0)
                for _, store in ipairs(view.stores.ordered) do
                    lu.assertNotEquals(#store.primitives, 0, store.key)
                end
            elseif binding.kind == "localSlots" then
                compile(binding.choice)
            elseif binding.kind == "incomingKind" then
                for _, incoming in ipairs(binding.kinds) do
                    compile(incoming.reward)
                end
            end
        end

        for _, biome in ipairs(systems.catalog.biomes.ordered) do
            for _, room in ipairs(biome.rooms.ordered) do
                compile(room.incomingReward)
                if room.entryOfferPolicy ~= nil then
                    compile(room.entryOfferPolicy.freeReward)
                end
                for _, child in ipairs(room.localChildren) do
                    compile(child.reward)
                end
            end
        end
        for _, profile in ipairs(systems.catalog.encounterProfiles.ordered) do
            for _, phase in ipairs(profile.phases) do
                if phase.offerPoint ~= nil then
                    compile(phase.offerPoint.choice)
                end
            end
        end
        lu.assertEquals(count, 203)
    end)
end

function TestRewardHierarchy.testPayloadCollaboratorsOwnShapeAndCompleteness()
    h.withImport(function()
        local rewards = load().rewards
        local boon = rewards.primitives.lookup.Boon
        local devotion = rewards.primitives.lookup.Devotion

        lu.assertFalse(boon.isComplete({ rewardType = "Boon" }))
        lu.assertTrue(boon.isComplete({
            rewardType = "Boon",
            payload = { source = "ApolloUpgrade" },
        }))
        lu.assertTrue(devotion.isComplete({
            rewardType = "Devotion",
            payload = { sources = { "ApolloUpgrade", "ZeusUpgrade" } },
        }))
        lu.assertErrorMsgContains("unknown source 'MissingUpgrade'", function()
            boon.encode({
                rewardType = "Boon",
                payload = { source = "MissingUpgrade" },
            }, "boon")
        end)
        lu.assertErrorMsgContains("sources must be distinct", function()
            devotion.encode({
                rewardType = "Devotion",
                payload = { sources = { "ApolloUpgrade", "ApolloUpgrade" } },
            }, "devotion")
        end)
    end)
end

function TestRewardHierarchy.testCountedChoiceElidesFixedFactsAndReportsCompleteness()
    h.withImport(function()
        local systems = load()
        local rewards = systems.rewards
        local binding = systems.catalog.biomes.lookup.F.rooms.lookup.F_MiniBoss01.incomingReward
        local view = rewards.countedBindings.compile(binding)
        local descriptor = rewards.countedChoice.prepare(view, "Reward")
        local storage = storageLookup(rewards.countedChoice.storage(descriptor))
        local fields = fieldsFor(rewards.countedChoice.storage(descriptor))

        lu.assertNil(storage.RewardStoreKey)
        lu.assertNil(storage.RewardType)
        lu.assertNotNil(storage.RewardPayload1)
        lu.assertNil(storage.RewardPayload2)

        local value = rewards.countedChoice.read(fields, descriptor, "miniboss")
        lu.assertEquals(value, {
            storeKey = "RunProgress",
            rewardType = "Boon",
        })
        lu.assertFalse(rewards.countedChoice.isComplete(descriptor, value))

        rewards.countedChoice.write(fields, descriptor, {
            payload = { source = "ApolloUpgrade" },
        }, "miniboss")
        value = rewards.countedChoice.read(fields, descriptor, "miniboss")
        lu.assertEquals(value, {
            storeKey = "RunProgress",
            rewardType = "Boon",
            payload = { source = "ApolloUpgrade" },
        })
        lu.assertTrue(rewards.countedChoice.isComplete(descriptor, value))
        lu.assertErrorMsgContains("cannot replace fixed reward type 'Boon'", function()
            rewards.countedChoice.write(fields, descriptor, {
                rewardType = "Devotion",
            }, "miniboss")
        end)

        lu.assertErrorMsgContains("persisted payload requires a rewardType", function()
            local ordinary = rewards.countedBindings.compile(
                systems.catalog.biomes.lookup.F.rooms.lookup.F_Combat02.incomingReward
            )
            local ordinaryDescriptor = rewards.countedChoice.prepare(ordinary, "Ordinary")
            local ordinaryFields = fieldsFor(rewards.countedChoice.storage(ordinaryDescriptor))
            ordinaryFields.OrdinaryPayload1:write("ApolloUpgrade")
            rewards.countedChoice.read(ordinaryFields, ordinaryDescriptor, "ordinary")
        end)
    end)
end
