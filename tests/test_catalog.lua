local ns = {}
assert(loadfile("Catalog.lua"))("Wanderful", ns)
assert(loadfile("Data/Wands.lua"))("Wanderful", ns)
local Catalog, original = ns.Catalog, ns.WandData
local checks = 0

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for k, v in pairs(value) do result[k] = copy(v) end
    return result
end

local function test(name, fn)
    local ok, err = pcall(fn)
    assert(ok, name .. ": " .. tostring(err))
    checks = checks + 1
end

local function rejects(name, mutate, fragment)
    test(name, function()
        local data = copy(original)
        mutate(data)
        local index, errors = Catalog.Index(data)
        assert(index == nil, "invalid catalog was indexed")
        assert(table.concat(errors, "; "):find(fragment, 1, true), table.concat(errors, "; "))
    end)
end

test("sample validates and indexes every item", function()
    assert(#Catalog.Validate(original) == 0)
    assert(#original.items == 9)
    for _, item in ipairs(original.items) do
        assert(ns.WandsByItemID[item.itemID][item.variant] == item)
        assert(not Catalog.IsVerifiedCandidate(original, item))
    end
end)

test("quest minimum is not an equip requirement", function()
    local deepblaze = ns.WandsByItemID[279896].base
    assert(deepblaze.forever.stats.equipLevel == nil)
    assert(original.sources[deepblaze.sourceIDs[1]].minQuestLevel == 9)
    assert(deepblaze.classic == nil)
    local cinder = ns.WandsByItemID[5242].base
    assert(cinder.forever.stats.equipLevel == nil)
    assert(cinder.classic.stats.reportedRequiredLevel == 14)
end)

test("historical values survive indexing without becoming defaults", function()
    local data = copy(original)
    local firebelcher
    for _, item in ipairs(data.items) do if item.itemID == 5243 then firebelcher = item end end
    assert(firebelcher.forever.stats.dps == 23.24 and firebelcher.classic.stats.dps == 20.3)
    firebelcher.forever.stats.dps = nil
    local index = assert(Catalog.Index(data))
    assert(index[5243].base.forever.stats.dps == nil)
    assert(index[5243].base.classic.stats.dps == 20.3)
end)

test("distinct item variants do not overwrite each other", function()
    local data = copy(original)
    local variant = copy(data.items[1])
    variant.variant = "test-variant"
    data.items[#data.items + 1] = variant
    local index = assert(Catalog.Index(data))
    assert(index[11287].base ~= index[11287]["test-variant"])
end)

rejects("duplicate identity", function(d) d.items[#d.items + 1] = copy(d.items[1]) end, "duplicate identity")
rejects("missing source", function(d) d.items[1].sourceIDs = { "missing" } end, "unknown source")
rejects("missing evidence", function(d) d.items[1].forever.evidence = "missing" end, "unknown evidence")
rejects("Classic cannot masquerade as Forever", function(d) d.items[1].forever.evidence = "classicSheet" end, "another game")
rejects("zero speed", function(d) d.items[1].forever.stats.speed = 0 end, "invalid speed")
rejects("negative DPS", function(d) d.items[1].forever.stats.dps = -1 end, "invalid dps")
rejects("NaN DPS", function(d) d.items[1].forever.stats.dps = 0/0 end, "invalid dps")
rejects("infinite damage", function(d) d.items[1].forever.stats.maxDamage = math.huge end, "invalid maxDamage")
rejects("inverted damage", function(d) d.items[1].forever.stats.minDamage = 100 end, "inverted damage")
rejects("fractional equip level", function(d) d.items[1].forever.stats.equipLevel = 1.5 end, "invalid equipLevel")
rejects("invalid quest level", function(d) d.sources["cinder-quest"].minQuestLevel = 0 end, "invalid minQuestLevel")
rejects("invalid prerequisite ID", function(d) d.sources["cinder-quest"].prerequisiteQuestIDs = { -99 } end, "invalid ID")
rejects("source cannot be verified by database evidence", function(d) d.sources["cinder-quest"].availability = "verified" end, "client acquisition evidence")
rejects("client evidence requires a build", function(d) d.evidence["stats-11287"].method = "client" end, "measured build")
rejects("sparse item declarations", function(d) d.items[1] = nil end, "has a gap")

test("tooltip verification does not verify acquisition", function()
    local d = copy(original)
    local item = d.items[1]
    d.evidence[item.forever.evidence] = {
        game = "forever", method = "client", build = "test-fixture",
        observedOn = "2026-10-15", url = "https://example.com/test-evidence",
    }
    assert(#Catalog.Validate(d) == 0)
    assert(not Catalog.IsVerifiedCandidate(d, item))
    local source = d.sources[item.sourceIDs[1]]
    source.evidence = "fixtureAcquisition"
    d.evidence.fixtureAcquisition = copy(d.evidence[item.forever.evidence])
    source.availability = "verified"
    assert(not Catalog.IsVerifiedCandidate(d, item), "unknown requirements must remain blocked")
    source.requirementsComplete = true
    assert(#Catalog.Validate(d) == 0)
    assert(Catalog.IsVerifiedCandidate(d, item))
    for _, status in ipairs({ "unknown", "listed", "unavailable", "test" }) do
        source.availability = status
        assert(not Catalog.IsVerifiedCandidate(d, item))
    end
end)

test("unknown details and no acquisition sources stay unknown", function()
    local d = copy(original)
    d.items[1].forever.stats = {}
    d.items[1].sourceIDs = {}
    local index = assert(Catalog.Index(d))
    assert(index[11287].base.forever.stats.equipLevel == nil)
    assert(not Catalog.IsVerifiedCandidate(d, d.items[1]))
end)

print("Catalog: " .. checks .. " tests passed.")
