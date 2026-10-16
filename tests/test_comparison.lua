local ns = {}
assert(loadfile("Comparison.lua"))("Wanderful", ns)
local C = ns.Comparison
local count = 0
local function test(name, fn)
    local ok, err = pcall(fn)
    assert(ok, name .. ": " .. tostring(err))
    count = count + 1
end
local function near(a, b) assert(a and math.abs(a - b) < 0.00000001, tostring(a) .. " ~= " .. b) end
local function snapshot(dps)
    return { evidence = "fixture", stats = { dps = dps, equipLevel = 10, classIDs = {}, school = "Arcane" } }
end
local function source(extra)
    local result = { kind = "vendor", availability = "verified", requirementsComplete = true,
        faction = "Both", classIDs = {}, raceIDs = {}, prerequisiteQuestIDs = {} }
    for key, value in pairs(extra or {}) do result[key] = value end
    return result
end
local function item(id, dps, refs)
    return { itemID = id, variant = "base", name = "Fixture", forever = snapshot(dps), sourceIDs = refs or { "vendor" } }
end
local function data(items, sources) return { items = items, sources = sources or { vendor = source() } } end
local character = { level = 15, classID = 5, raceID = 1, faction = "Alliance" }

test("20 to 25 is +5 and +25 percent base wand DPS", function()
    local result = C.Compare(snapshot(25), snapshot(20))
    near(result.delta, 5); near(result.percent, 25)
    assert(result.relation == "upgrade")
end)

test("equal values and downgrades retain their signs", function()
    local equal = C.Compare(snapshot(20), snapshot(20))
    assert(equal.relation == "equal" and equal.delta == 0 and equal.percent == 0)
    local down = C.Compare(snapshot(15), snapshot(20))
    assert(down.relation == "downgrade" and down.delta == -5 and down.percent == -25)
end)

test("damage range wins over a rounded reported value without rounding", function()
    local s = { evidence = "observed", stats = { minDamage = 12, maxDamage = 22, speed = 1.5, dps = 11.3 } }
    local result = C.DPS(s)
    near(result.value, 17/1.5)
    assert(result.method == "damage_range" and result.evidence == "observed")
    local reported = C.DPS(snapshot(11.3))
    assert(reported.value == 11.3 and reported.method == "reported" and reported.evidence == "fixture")
end)

test("absent and zero baselines never invent percentages", function()
    local absent = C.Compare(snapshot(25), nil)
    assert(absent.delta == nil and absent.percent == nil and absent.relation == "unknown")
    local zero = C.Compare(snapshot(25), snapshot(0))
    assert(zero.delta == 25 and zero.percent == nil and zero.reason == "zero_baseline")
    local missing = C.Compare({ stats = {} }, snapshot(20))
    assert(missing.delta == nil and missing.percent == nil)
    assert(C.DPS(false).reason == "missing_stats")
end)

test("invalid speed and numeric fields cannot fall back to reported DPS", function()
    for _, value in ipairs({ 0, -1, math.huge, 0/0 }) do
        local s = snapshot(25); s.stats.speed = value
        assert(C.DPS(s).value == nil)
    end
    for _, value in ipairs({ -1, math.huge, 0/0 }) do assert(C.DPS(snapshot(value)).value == nil) end
    assert(C.DPS({ stats = { minDamage = 10, maxDamage = 5, speed = 1, dps = 20 } }).value == nil)
    assert(C.DPS({ stats = { minDamage = 1e308, maxDamage = 1e308, speed = 1e-300 } }).value == nil)
    local huge = C.DPS({ stats = { minDamage = 1e308, maxDamage = 1e308, speed = 1 } })
    assert(huge.value == 1e308)
    local overflow = C.Compare(snapshot(1e308), snapshot(1e-300))
    assert(overflow.percent == nil and overflow.reason == "invalid_percentage")
end)

test("usable, upcoming, blocked and unknown equipment remain distinct", function()
    local it = item(1, 25)
    local d = data({ it })
    assert(C.Assess(d, it, character).status == "usable_now")
    it.forever.stats.equipLevel = 20
    assert(C.Assess(d, it, character).status == "upcoming")
    it.forever.stats.classIDs = { 8 }
    assert(C.Assess(d, it, character).equip.status == "blocked")
    it.forever.stats.classIDs, it.forever.stats.equipLevel = {}, nil
    assert(C.Assess(d, it, character).equip.status == "unknown")
    it.forever.stats.equipLevel, it.forever.stats.classIDs = 10, nil
    assert(C.Assess(d, it, character).equip.status == "unknown")
end)

test("quest minimum never substitutes for equip level or source access", function()
    local it = item(1, 25)
    local d = data({ it }, { vendor = source({ kind = "quest", minQuestLevel = 20 }) })
    local a = C.Assess(d, it, character)
    assert(a.equip.status == "usable" and a.acquisition == "blocked" and a.status == "requirements_unmet")
    it.forever.stats.equipLevel = nil
    assert(C.Assess(d, it, character).equip.status == "unknown")
end)

test("prerequisites use explicit false and unknown as different states", function()
    local it = item(1, 25)
    local d = data({ it }, { vendor = source({ kind = "quest", minQuestLevel = 1, prerequisiteQuestIDs = { 99 } }) })
    assert(C.Assess(d, it, character).acquisition == "unknown")
    local ctx = { level = 15, classID = 5, raceID = 1, faction = "Alliance", completedQuests = { [99] = false } }
    assert(C.Assess(d, it, ctx).acquisition == "blocked")
    ctx.completedQuests[99] = true
    assert(C.Assess(d, it, ctx).acquisition == "available")
end)

test("one blocked route does not hide an available or unknown alternative", function()
    local it = item(1, 25, { "horde", "alternative" })
    local d = data({ it }, { horde = source({ faction = "Horde" }), alternative = source() })
    local a = C.Assess(d, it, character)
    assert(a.acquisition == "available" and #a.sources == 2 and a.sources[1].status == "blocked")
    d.sources.alternative.availability = "listed"
    assert(C.Assess(d, it, character).acquisition == "unknown")
    d.sources.alternative.availability = "unavailable"
    assert(C.Assess(d, it, character).acquisition == "blocked")
end)

test("incomplete requirements and missing race restrictions stay unknown", function()
    local it = item(1, 25)
    local d = data({ it }, { vendor = source({ requirementsComplete = false }) })
    assert(C.Assess(d, it, character).acquisition == "unknown")
    d.sources.vendor.requirementsComplete = true
    d.sources.vendor.raceIDs = nil
    assert(C.Assess(d, it, character).acquisition == "unknown")
    d.sources.vendor.raceIDs = { 4 }
    assert(C.Assess(d, it, character).acquisition == "blocked")
end)

test("crafting skill gates that source, not equipping or another source", function()
    local it = item(1, 25, { "craft", "vendor" })
    local d = data({ it }, { vendor = source(), craft = source({ kind = "crafting", spellID = 14293, professionSkill = 70 }) })
    local ctx = { level = 15, classID = 5, raceID = 1, faction = "Alliance", recipeSkills = { [14293] = 20 } }
    local a = C.Assess(d, it, ctx)
    assert(a.equip.status == "usable" and a.acquisition == "available" and a.sources[1].status == "blocked")
    ctx.recipeSkills[14293] = 70
    assert(C.Assess(d, it, ctx).sources[1].status == "available")
end)

test("class, faction, school and source filters preserve only matching paths", function()
    local mage, priest = item(1, 25), item(2, 24)
    mage.forever.stats.classIDs, priest.forever.stats.classIDs = { 8 }, { 5 }
    mage.sourceIDs = { "alliance", "horde" }
    local d = data({ priest, mage }, { vendor = source(), alliance = source({ faction = "Alliance" }), horde = source({ faction = "Horde", kind = "dungeon" }) })
    local rows = C.List(d, snapshot(20), character, { classID = 8, faction = "Horde", school = "Arcane", sourceKind = "dungeon" })
    assert(#rows == 1 and rows[1].item == mage and #rows[1].eligibility.sources == 1)
    assert(rows[1].eligibility.sources[1].id == "horde")
    local classRows = C.List(d, snapshot(20), character, { classID = 8 })
    assert(#classRows == 1 and classRows[1].item == mage)
    local factionRows = C.List(d, snapshot(20), { level = 15, classID = 8 }, { faction = "Horde" })
    assert(#factionRows == 1 and #factionRows[1].eligibility.sources == 1)
    assert(factionRows[1].eligibility.sources[1].id == "horde" and factionRows[1].eligibility.acquisition == "available")
    local kindRows = C.List(d, snapshot(20), character, { classID = 8, sourceKind = "vendor" })
    assert(#kindRows == 1 and #kindRows[1].eligibility.sources == 1)
    assert(kindRows[1].eligibility.sources[1].id == "alliance")
    assert(C.Assess(d, mage, character, { classID = 8, faction = "Horde" }).equip.status == "usable")
    assert(character.classID == 5 and character.faction == "Alliance")
    assert(#C.List(d, snapshot(20), character, { school = "Fire" }) == 0)
end)

test("unknown equip levels remain visible within a level range", function()
    local low, high, unknown = item(1, 25), item(2, 26), item(3, 27)
    low.forever.stats.equipLevel, high.forever.stats.equipLevel, unknown.forever.stats.equipLevel = 5, 20, nil
    local rows = C.List(data({ low, high, unknown }), snapshot(20), character, { minLevel = 10, maxLevel = 15 })
    assert(#rows == 1 and rows[1].item == unknown and rows[1].eligibility.equip.status == "unknown")
end)

test("upgrades only excludes unknown, equal and lower DPS", function()
    local d = data({ item(1, 25), item(2, 20), item(3, 15), item(4, nil) })
    assert(#C.List(d, snapshot(20), character, { upgradesOnly = true }) == 1)
    assert(#C.List(d, nil, character, { upgradesOnly = true }) == 0)
    assert(#C.List(d, snapshot(20), character) == 4)
end)

test("sorting uses raw DPS then identity while retaining useful alternatives", function()
    local a, b, c, variant, unknown = item(2, 25.001), item(1, 25.002), item(3, 25.001), item(2, 25.001), item(4, 100)
    variant.variant, unknown.forever.stats.equipLevel = "suffix", nil
    local input = { unknown, variant, c, a, b }
    local rows = C.List(data(input), snapshot(20), character)
    assert(#rows == 5 and rows[1].item == b and rows[2].item == a and rows[3].item == variant)
    assert(rows[4].item == c and rows[5].item == unknown and input[1] == unknown)
end)

test("unknown acquisition stays visible but never becomes usable now", function()
    local it = item(1, 25, {})
    local d = data({ it })
    assert(C.Assess(d, it, character).acquisition == "unknown")
    assert(#C.List(d, snapshot(20), character) == 1)
    assert(#C.List(d, snapshot(20), character, { sourceKind = "quest" }) == 0)
    assert(#C.List(d, snapshot(20), character, { usableOnly = true }) == 0)
end)

test("catalog snapshots and descriptive attributes are retained without historical fallback", function()
    assert(loadfile("Catalog.lua"))("Wanderful", ns)
    assert(loadfile("Data/Wands.lua"))("Wanderful", ns)
    local rows = C.List(ns.WandData, snapshot(10), { level = 20, classID = 5, faction = "Alliance" })
    assert(#rows > 0)
    for _, row in ipairs(rows) do
        assert(row.item.forever.evidence and row.eligibility.status ~= "usable_now")
        if row.item.itemID == 11287 then
            assert(row.item.forever.stats.effects[1] and row.comparison.candidate.method == "damage_range")
        end
    end
    local it = item(1, nil); it.classic = snapshot(99)
    assert(C.List(data({ it }), snapshot(20), character)[1].comparison.candidate.value == nil)
end)


test("runtime TOC loads the comparison model without client APIs", function()
    local runtimeNS = {}
    local env = setmetatable({ SlashCmdList = {}, print = function() end }, { __index = _G })
    dofile("Tools/manifest.lua").Load(env, runtimeNS)
    assert(runtimeNS.Comparison.Compare(snapshot(25), snapshot(20)).percent == 25)
    assert(#runtimeNS.Comparison.List(runtimeNS.WandData, snapshot(10), character) > 0)
end)

print("Comparison: " .. count .. " tests passed.")
