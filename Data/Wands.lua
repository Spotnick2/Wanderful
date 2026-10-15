local _, ns = ...

-- Database observations only. No entry has been verified in the Forever client.
ns.WandData = {
    ["schemaVersion"] = 1,
    ["evidence"] = {
        ["classicSheet"] = { ["game"] = "classic", ["method"] = "historical", ["url"] = "https://docs.google.com/spreadsheets/d/e/2PACX-1vTm4F0MKf-HFEhHV7RjCS-MmQOFKinmXLNKMVC1N1RILG80RwtSQmAewGs0glOt2GMle9hRdbdTrUG2/pubhtml", ["observedOn"] = "2026-10-15", },
        ["foreverList"] = { ["game"] = "forever", ["method"] = "database", ["url"] = "https://www.wowhead.com/forever/items/weapons/wands", ["observedOn"] = "2026-10-15", },
        ["stats-11287"] = { ["game"] = "forever", ["method"] = "database", ["url"] = "https://www.wowhead.com/forever/item=11287", ["observedOn"] = "2026-10-15", },
        ["source-11287"] = { ["game"] = "forever", ["method"] = "database", ["url"] = "https://www.wowhead.com/forever/item=11287", ["observedOn"] = "2026-10-15", },
        ["stats-11288"] = { ["game"] = "forever", ["method"] = "database", ["url"] = "https://www.wowhead.com/forever/item=11288", ["observedOn"] = "2026-10-15", },
        ["source-11288"] = { ["game"] = "forever", ["method"] = "database", ["url"] = "https://www.wowhead.com/forever/item=11288", ["observedOn"] = "2026-10-15", },
        ["stats-5243"] = { ["game"] = "forever", ["method"] = "database", ["url"] = "https://www.wowhead.com/forever/item=5243", ["observedOn"] = "2026-10-15", },
        ["source-5243"] = { ["game"] = "forever", ["method"] = "database", ["url"] = "https://www.wowhead.com/forever/item=5243", ["observedOn"] = "2026-10-15", },
        ["stats-5242"] = { ["game"] = "forever", ["method"] = "database", ["url"] = "https://www.wowhead.com/forever/item=5242", ["observedOn"] = "2026-10-15", },
        ["source-5242"] = { ["game"] = "forever", ["method"] = "database", ["url"] = "https://www.wowhead.com/forever/item=5242", ["observedOn"] = "2026-10-15", },
        ["stats-279896"] = { ["game"] = "forever", ["method"] = "database", ["url"] = "https://www.wowhead.com/forever/item=279896", ["observedOn"] = "2026-10-15", },
        ["source-279896"] = { ["game"] = "forever", ["method"] = "database", ["url"] = "https://www.wowhead.com/forever/item=279896", ["observedOn"] = "2026-10-15", },
        ["stats-5208"] = { ["game"] = "forever", ["method"] = "database", ["url"] = "https://www.wowhead.com/forever/item=5208", ["observedOn"] = "2026-10-15", },
        ["source-5208"] = { ["game"] = "forever", ["method"] = "database", ["url"] = "https://www.wowhead.com/forever/item=5208", ["observedOn"] = "2026-10-15", },
        ["stats-7001"] = { ["game"] = "forever", ["method"] = "database", ["url"] = "https://www.wowhead.com/forever/item=7001", ["observedOn"] = "2026-10-15", },
        ["source-7001"] = { ["game"] = "forever", ["method"] = "database", ["url"] = "https://www.wowhead.com/forever/item=7001", ["observedOn"] = "2026-10-15", },
        ["stats-5198"] = { ["game"] = "forever", ["method"] = "database", ["url"] = "https://www.wowhead.com/forever/item=5198", ["observedOn"] = "2026-10-15", },
        ["source-5198"] = { ["game"] = "forever", ["method"] = "database", ["url"] = "https://www.wowhead.com/forever/item=5198", ["observedOn"] = "2026-10-15", },
        ["stats-12984"] = { ["game"] = "forever", ["method"] = "database", ["url"] = "https://www.wowhead.com/forever/item=12984", ["observedOn"] = "2026-10-15", },
        ["source-12984"] = { ["game"] = "forever", ["method"] = "database", ["url"] = "https://www.wowhead.com/forever/item=12984", ["observedOn"] = "2026-10-15", },
        ["quest-99"] = { ["game"] = "forever", ["method"] = "database", ["url"] = "https://www.wowhead.com/forever/quest=99", ["observedOn"] = "2026-10-15", },
        ["quest-96393"] = { ["game"] = "forever", ["method"] = "database", ["url"] = "https://www.wowhead.com/forever/quest=96393", ["observedOn"] = "2026-10-15", },
    },
    ["sources"] = {
        ["craft-lesser"] = { ["kind"] = "crafting", ["description"] = "Enchanting: Lesser Magic Wand", ["spellID"] = 14293, ["evidence"] = "foreverList", ["availability"] = "listed", ["requirementsComplete"] = false, ["notes"] = "Recipe skill and reagents not captured; crafting requirements do not imply an equip profession requirement.", },
        ["craft-greater"] = { ["kind"] = "crafting", ["description"] = "Enchanting: Greater Magic Wand", ["spellID"] = 14807, ["evidence"] = "foreverList", ["availability"] = "listed", ["requirementsComplete"] = false, ["notes"] = "Recipe skill and reagents not captured.", },
        ["firebelcher-drop"] = { ["kind"] = "dungeon", ["description"] = "Deviate Faerie Dragon in Wailing Caverns", ["npcID"] = 5912, ["evidence"] = "foreverList", ["availability"] = "listed", ["requirementsComplete"] = false, ["notes"] = "Drop rate and current spawn availability have not been verified.", },
        ["cinder-quest"] = { ["kind"] = "quest", ["description"] = "Arugal's Folly in Silverpine Forest", ["questID"] = 99, ["minQuestLevel"] = 9, ["faction"] = "Horde", ["evidence"] = "quest-99", ["availability"] = "listed", ["requirementsComplete"] = false, ["notes"] = "Choice reward. The page lists a multi-step series; exact prerequisite logic has not been verified. No equip-level requirement was shown in the item tooltip.", },
        ["deepblaze-quest"] = { ["kind"] = "quest", ["description"] = "Old Ironforge Incursion in The Hall of Thanes", ["questID"] = 96393, ["minQuestLevel"] = 9, ["faction"] = "Alliance", ["evidence"] = "quest-96393", ["availability"] = "listed", ["requirementsComplete"] = false, ["notes"] = "Choice reward. Listed races: Dwarf, Night Elf, Gnome, High Order Skyborne; race IDs not verified. Underground Map (96391) appears in the series; prerequisite logic is not yet verified. Do not treat Alliance alone as sufficient eligibility.", },
        ["smoldering-stormwind"] = { ["kind"] = "vendor", ["description"] = "Ardwyn Cailen, Stormwind City", ["faction"] = "Alliance", ["evidence"] = "source-5208", ["availability"] = "listed", ["requirementsComplete"] = false, ["notes"] = "One of several listed vendors; no price or stock guarantee.", },
        ["smoldering-orgrimmar"] = { ["kind"] = "vendor", ["description"] = "Katis, Orgrimmar", ["faction"] = "Horde", ["evidence"] = "source-5208", ["availability"] = "listed", ["requirementsComplete"] = false, ["notes"] = "One of several listed vendors; no price or stock guarantee.", },
        ["gravestone-quests"] = { ["kind"] = "quest", ["description"] = "Blackfathom Villainy in Blackfathom Deeps", ["minQuestLevel"] = 18, ["evidence"] = "source-7001", ["availability"] = "listed", ["requirementsComplete"] = false, ["notes"] = "Two reward quests listed. Quest IDs, faction mappings and prerequisite logic not yet captured. No equip-level requirement was shown in the item tooltip.", },
        ["cookie-drop"] = { ["kind"] = "dungeon", ["description"] = "Cookie in The Deadmines", ["npcID"] = 645, ["evidence"] = "foreverList", ["availability"] = "listed", ["requirementsComplete"] = false, ["notes"] = "Drop rate not verified.", },
        ["skycaller-world"] = { ["kind"] = "world", ["description"] = "World-drop candidate with many listed creatures and containers", ["evidence"] = "source-12984", ["availability"] = "listed", ["requirementsComplete"] = false, ["notes"] = "Database contains cross-season drop observations. No specific farm, drop rate or current availability is asserted.", },
    },
    ["items"] = {
        {
            ["itemID"] = 11287,
            ["variant"] = "base",
            ["name"] = "Lesser Magic Wand",
            ["forever"] = {
                ["stats"] = {
                    ["itemLevel"] = 15,
                    ["equipLevel"] = 5,
                    ["minDamage"] = 12,
                    ["maxDamage"] = 22,
                    ["dps"] = 11.33,
                    ["speed"] = 1.5,
                    ["school"] = "Arcane",
                    ["effects"] = {
                        "Spell damage and healing bonus: 1.",
                    },
                },
                ["evidence"] = "stats-11287",
            },
            ["sourceIDs"] = {
                "craft-lesser",
            },
            ["classic"] = {
                ["stats"] = { ["itemLevel"] = 15, ["reportedRequiredLevel"] = 5, ["dps"] = 11.3, ["speed"] = 1.5, ["school"] = "Arcane", },
                ["evidence"] = "classicSheet",
            },
        },
        {
            ["itemID"] = 11288,
            ["variant"] = "base",
            ["name"] = "Greater Magic Wand",
            ["forever"] = {
                ["stats"] = {
                    ["itemLevel"] = 23,
                    ["equipLevel"] = 13,
                    ["minDamage"] = 22,
                    ["maxDamage"] = 41,
                    ["dps"] = 17.5,
                    ["speed"] = 1.8,
                    ["school"] = "Arcane",
                    ["effects"] = {
                        "Spell damage and healing bonus: 2.",
                    },
                },
                ["evidence"] = "stats-11288",
            },
            ["sourceIDs"] = {
                "craft-greater",
            },
            ["classic"] = {
                ["stats"] = { ["itemLevel"] = 23, ["reportedRequiredLevel"] = 13, ["dps"] = 17.5, ["speed"] = 1.8, ["school"] = "Arcane", },
                ["evidence"] = "classicSheet",
            },
        },
        {
            ["itemID"] = 5243,
            ["variant"] = "base",
            ["name"] = "Firebelcher",
            ["forever"] = {
                ["stats"] = {
                    ["itemLevel"] = 23,
                    ["equipLevel"] = 18,
                    ["minDamage"] = 27,
                    ["maxDamage"] = 52,
                    ["dps"] = 23.24,
                    ["speed"] = 1.7,
                    ["school"] = "Fire",
                    ["effects"] = {
                        "On-hit Fire damage effect: 25–31; proc rate and timing unverified.",
                    },
                },
                ["evidence"] = "stats-5243",
            },
            ["sourceIDs"] = {
                "firebelcher-drop",
            },
            ["classic"] = {
                ["stats"] = { ["itemLevel"] = 20, ["reportedRequiredLevel"] = 15, ["dps"] = 20.3, ["speed"] = 1.7, ["school"] = "Fire", },
                ["evidence"] = "classicSheet",
            },
        },
        {
            ["itemID"] = 5242,
            ["variant"] = "base",
            ["name"] = "Cinder Wand",
            ["forever"] = {
                ["stats"] = {
                    ["itemLevel"] = 16,
                    ["minDamage"] = 11,
                    ["maxDamage"] = 22,
                    ["dps"] = 11.79,
                    ["speed"] = 1.4,
                    ["school"] = "Fire",
                    ["effects"] = {
                        "Spell damage and healing bonus: 1.",
                    },
                },
                ["evidence"] = "stats-5242",
            },
            ["sourceIDs"] = {
                "cinder-quest",
            },
            ["classic"] = {
                ["stats"] = { ["itemLevel"] = 16, ["reportedRequiredLevel"] = 14, ["dps"] = 11.8, ["speed"] = 1.4, ["school"] = "Fire", },
                ["evidence"] = "classicSheet",
            },
        },
        {
            ["itemID"] = 279896,
            ["variant"] = "base",
            ["name"] = "Deepblaze",
            ["forever"] = {
                ["stats"] = {
                    ["itemLevel"] = 18,
                    ["minDamage"] = 22,
                    ["maxDamage"] = 41,
                    ["dps"] = 18.53,
                    ["speed"] = 1.7,
                    ["school"] = "Fire",
                    ["attributes"] = { ["fireResistance"] = 3, },
                },
                ["evidence"] = "stats-279896",
            },
            ["sourceIDs"] = {
                "deepblaze-quest",
            },
        },
        {
            ["itemID"] = 5208,
            ["variant"] = "base",
            ["name"] = "Smoldering Wand",
            ["forever"] = {
                ["stats"] = { ["itemLevel"] = 20, ["equipLevel"] = 15, ["minDamage"] = 15, ["maxDamage"] = 28, ["dps"] = 13.44, ["speed"] = 1.6, ["school"] = "Fire", },
                ["evidence"] = "stats-5208",
            },
            ["sourceIDs"] = {
                "smoldering-stormwind",
                "smoldering-orgrimmar",
            },
            ["classic"] = {
                ["stats"] = { ["itemLevel"] = 20, ["reportedRequiredLevel"] = 15, ["dps"] = 13.4, ["speed"] = 1.6, ["school"] = "Fire", },
                ["evidence"] = "classicSheet",
            },
        },
        {
            ["itemID"] = 7001,
            ["variant"] = "base",
            ["name"] = "Gravestone Scepter",
            ["forever"] = {
                ["stats"] = {
                    ["itemLevel"] = 29,
                    ["minDamage"] = 30,
                    ["maxDamage"] = 57,
                    ["dps"] = 29,
                    ["speed"] = 1.5,
                    ["school"] = "Shadow",
                    ["effects"] = {
                        "Shadow spell damage bonus: 6.",
                    },
                    ["attributes"] = { ["spirit"] = 3, ["shadowResistance"] = 4, },
                },
                ["evidence"] = "stats-7001",
            },
            ["sourceIDs"] = {
                "gravestone-quests",
            },
            ["classic"] = {
                ["stats"] = { ["itemLevel"] = 29, ["reportedRequiredLevel"] = 18, ["dps"] = 29, ["speed"] = 1.5, ["school"] = "Shadow", },
                ["evidence"] = "classicSheet",
            },
        },
        {
            ["itemID"] = 5198,
            ["variant"] = "base",
            ["name"] = "Cookie's Stirring Rod",
            ["forever"] = {
                ["stats"] = {
                    ["itemLevel"] = 22,
                    ["equipLevel"] = 17,
                    ["minDamage"] = 20,
                    ["maxDamage"] = 38,
                    ["dps"] = 22.31,
                    ["speed"] = 1.3,
                    ["school"] = "Arcane",
                    ["effects"] = {
                        "Cooking speed bonus: 25%.",
                    },
                },
                ["evidence"] = "stats-5198",
            },
            ["sourceIDs"] = {
                "cookie-drop",
            },
            ["classic"] = {
                ["stats"] = { ["itemLevel"] = 22, ["reportedRequiredLevel"] = 17, ["dps"] = 22.3, ["speed"] = 1.3, ["school"] = "Arcane", },
                ["evidence"] = "classicSheet",
            },
        },
        {
            ["itemID"] = 12984,
            ["variant"] = "base",
            ["name"] = "Skycaller",
            ["forever"] = {
                ["stats"] = {
                    ["itemLevel"] = 21,
                    ["equipLevel"] = 16,
                    ["minDamage"] = 24,
                    ["maxDamage"] = 45,
                    ["dps"] = 21.56,
                    ["speed"] = 1.6,
                    ["school"] = "Arcane",
                    ["effects"] = {
                        "Arcane spell damage bonus: 6.",
                    },
                },
                ["evidence"] = "stats-12984",
            },
            ["sourceIDs"] = {
                "skycaller-world",
            },
            ["classic"] = {
                ["stats"] = { ["itemLevel"] = 21, ["reportedRequiredLevel"] = 16, ["dps"] = 21.6, ["speed"] = 1.6, ["school"] = "Arcane", },
                ["evidence"] = "classicSheet",
            },
        },
    },
}

local index, errors = ns.Catalog.Index(ns.WandData)
assert(index, table.concat(errors or {}, "\n"))
ns.WandsByItemID = index
