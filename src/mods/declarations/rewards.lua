local godSources = import("mods/declarations/god_sources.lua")

local function entry(rewardType, opts)
    opts = opts or {}

    return {
        rewardType = rewardType,
        allowDuplicates = opts.allowDuplicates,
        requirements = opts.requirements,
        acquiredLootType = opts.acquiredLootType,
    }
end

return {
    sources = {
        boon = godSources.boon,
    },

    primitives = {
        Boon = {
            label = "Boon",
        },
        Devotion = {
            label = "Trial",
        },
        HermesUpgrade = {
            label = "Hermes",
            acquiredLootType = "HermesUpgrade",
        },
        WeaponUpgrade = {
            label = "Hammer",
            acquiredLootType = "WeaponUpgrade",
        },
        WeaponUpgradeDrop = {
            label = "Hammer",
            acquiredLootType = "WeaponUpgrade",
        },
        MaxHealthDrop = {
            label = "Max Health",
        },
        MaxManaDrop = {
            label = "Max Magick",
        },
        RoomMoneyDrop = {
            label = "Gold",
        },
        GiftDrop = {
            label = "Nectar",
        },
        MetaCurrencyDrop = {
            label = "Bones",
        },
    },

    bags = {
        RunProgress = {
            key = "RunProgress",
            label = "Run Progress",
            refill = "appendWhenNoEligibleEntry",
            entries = {
                entry("Boon", { allowDuplicates = true }),
                entry("Boon", { allowDuplicates = true }),
                entry("HermesUpgrade", { acquiredLootType = "HermesUpgrade" }),
                entry("WeaponUpgrade", {
                    requirements = { named = "HammerLootRequirements" },
                    acquiredLootType = "WeaponUpgrade",
                }),
                entry("WeaponUpgrade", {
                    requirements = { named = "LateHammerLootRequirements" },
                    acquiredLootType = "WeaponUpgrade",
                }),
                entry("Devotion", {
                    requirements = { named = "DevotionLootRequirements" },
                }),
                entry("MaxHealthDrop"),
                entry("MaxManaDrop"),
                entry("RoomMoneyDrop"),
            },
        },

        MetaProgress = {
            key = "MetaProgress",
            label = "Meta Progress",
            refill = "appendWhenNoEligibleEntry",
            entries = {
                entry("GiftDrop"),
                entry("MetaCurrencyDrop", { allowDuplicates = true }),
                entry("MetaCurrencyDrop", { allowDuplicates = true }),
            },
        },
    },

    shops = {
        WorldShop = {
            key = "WorldShop",
            label = "World Shop",
            slots = {
                {
                    key = "Major",
                    options = {
                        {
                            rewardType = "WeaponUpgradeDrop",
                            requirements = { named = "HammerLootRequirements" },
                            acquiredLootType = "WeaponUpgrade",
                        },
                        {
                            rewardType = "HermesUpgrade",
                            acquiredLootType = "HermesUpgrade",
                        },
                    },
                },
            },
        },
    },
}
