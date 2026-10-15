local _, ns = ...
local Catalog = {}
ns.Catalog = Catalog

local function text(value)
    return type(value) == "string" and value ~= ""
end

local function number(value, minimum, integer)
    return type(value) == "number" and value == value and value < math.huge
        and value >= minimum and (not integer or value % 1 == 0)
end

function Catalog.Validate(data)
    local errors = {}
    local function check(ok, message)
        if not ok then errors[#errors + 1] = message end
        return ok
    end
    if not check(type(data) == "table", "catalog must be a table") then return errors end
    if not check(data.schemaVersion == 1, "unsupported schema version") then return errors end
    if not check(type(data.evidence) == "table", "missing evidence registry")
        or not check(type(data.sources) == "table", "missing source registry")
        or not check(type(data.items) == "table", "missing items") then return errors end

    local function array(value, label, visit)
        if not check(type(value) == "table", label .. " must be an array") then return end
        local count = 0
        for key in pairs(value) do
            if check(number(key, 1, true), label .. " has a non-array key") then count = count + 1 end
        end
        for i = 1, count do
            if check(value[i] ~= nil, label .. " has a gap") then visit(value[i], i) end
        end
    end
    local function ids(value, label)
        if value == nil then return end
        local seen = {}
        array(value, label, function(id)
            if check(number(id, 1, true), label .. " has an invalid ID") then
                check(not seen[id], label .. " repeats an ID")
                seen[id] = true
            end
        end)
    end
    local function evidence(ref, game, label)
        local e = type(ref) == "string" and data.evidence[ref]
        if not check(type(e) == "table", label .. " has an unknown evidence reference") then return end
        check(e.game == game, label .. " uses evidence from another game")
        return e
    end
    for key, e in pairs(data.evidence) do
        if check(text(key) and type(e) == "table", "invalid evidence entry") then
            check(text(e.url) and e.url:match("^https://"), key .. " needs an HTTPS source")
            check(text(e.observedOn) and e.observedOn:match("^%d%d%d%d%-%d%d%-%d%d$"),
                key .. " needs an observation date")
            check(e.game == "forever" or e.game == "classic", key .. " has an invalid game")
            check(e.method == "database" or e.method == "client" or e.method == "historical",
                key .. " has an invalid evidence method")
            if e.method == "client" then check(text(e.build), key .. " needs a measured build") end
            if e.method == "historical" then check(e.game == "classic", key .. " historical game mismatch") end
        end
    end
    local kinds = { quest = true, vendor = true, crafting = true, dungeon = true, world = true }
    local availability = { unknown = true, listed = true, verified = true, unavailable = true, test = true }
    for key, source in pairs(data.sources) do
        if check(text(key) and type(source) == "table", "invalid source entry") then
            check(kinds[source.kind], key .. " has an invalid source kind")
            check(text(source.description), key .. " needs a description")
            check(availability[source.availability], key .. " has an invalid availability")
            check(type(source.requirementsComplete) == "boolean", key .. " needs requirementsComplete")
            local e = evidence(source.evidence, "forever", key)
            if source.availability == "verified" then
                check(e and e.method == "client", key .. " needs client acquisition evidence")
            end
            for _, field in ipairs({ "questID", "npcID", "spellID" }) do
                if source[field] ~= nil then check(number(source[field], 1, true), key .. " invalid " .. field) end
            end
            for _, field in ipairs({ "minQuestLevel", "suggestedLevel", "professionSkill" }) do
                if source[field] ~= nil then check(number(source[field], 1, true), key .. " invalid " .. field) end
            end
            if source.faction ~= nil then
                check(source.faction == "Alliance" or source.faction == "Horde" or source.faction == "Both",
                    key .. " has an invalid faction")
            end
            ids(source.classIDs, key .. " classIDs")
            ids(source.raceIDs, key .. " raceIDs")
            ids(source.prerequisiteQuestIDs, key .. " prerequisites")
        end
    end

    local schools = { Arcane = true, Fire = true, Frost = true, Holy = true,
        Nature = true, Shadow = true, Physical = true }
    local function stats(snapshot, game, label)
        if not check(type(snapshot) == "table", label .. " missing snapshot") then return end
        evidence(snapshot.evidence, game, label)
        local s = snapshot.stats
        if not check(type(s) == "table", label .. " missing stats") then return end
        for _, field in ipairs({ "minDamage", "maxDamage", "dps" }) do
            if s[field] ~= nil then check(number(s[field], 0), label .. " invalid " .. field) end
        end
        if s.speed ~= nil then check(number(s.speed, 0) and s.speed > 0, label .. " invalid speed") end
        for _, field in ipairs({ "equipLevel", "itemLevel", "reportedRequiredLevel" }) do
            if s[field] ~= nil then check(number(s[field], 1, true), label .. " invalid " .. field) end
        end
        if number(s.minDamage, 0) and number(s.maxDamage, 0) then
            check(s.minDamage <= s.maxDamage, label .. " inverted damage range")
        end
        if s.school ~= nil then check(schools[s.school], label .. " invalid damage school") end
        ids(s.classIDs, label .. " classIDs")
        if s.attributes ~= nil and check(type(s.attributes) == "table", label .. " invalid attributes") then
            for key, value in pairs(s.attributes) do
                check(text(key) and number(value, 0), label .. " invalid attribute")
            end
        end
        if s.effects ~= nil then
            array(s.effects, label .. " effects", function(effect)
                check(text(effect), label .. " invalid effect description")
            end)
        end
    end
    local seen = {}
    array(data.items, "items", function(item, i)
        local label = "item " .. i
        if not check(type(item) == "table", label .. " must be a table") then return end
        if check(number(item.itemID, 1, true) and text(item.variant), label .. " invalid identity") then
            local key = item.itemID .. ":" .. item.variant
            check(not seen[key], label .. " duplicate identity " .. key)
            seen[key] = true
        end
        check(text(item.name), label .. " missing name")
        stats(item.forever, "forever", label .. " forever")
        if item.classic ~= nil then stats(item.classic, "classic", label .. " classic") end
        local refs = {}
        array(item.sourceIDs, label .. " sourceIDs", function(ref)
            if check(text(ref), label .. " invalid source reference") then
                check(type(data.sources[ref]) == "table", label .. " unknown source " .. ref)
                check(not refs[ref], label .. " duplicate source " .. ref)
                refs[ref] = true
            end
        end)
    end)
    return errors
end

-- Validate before indexing: duplicate declarations must never silently overwrite.
function Catalog.Index(data)
    local errors = Catalog.Validate(data)
    if #errors > 0 then return nil, errors end
    local byItemID = {}
    for _, item in ipairs(data.items) do
        byItemID[item.itemID] = byItemID[item.itemID] or {}
        byItemID[item.itemID][item.variant] = item
    end
    return byItemID
end

-- Evidence gate only, not character eligibility or an upgrade recommendation.
function Catalog.IsVerifiedCandidate(data, item)
    local statsEvidence = data.evidence[item.forever.evidence]
    if not statsEvidence or statsEvidence.method ~= "client" or statsEvidence.game ~= "forever" then
        return false
    end
    for _, ref in ipairs(item.sourceIDs) do
        local source = data.sources[ref]
        local e = source and data.evidence[source.evidence]
        if source and source.availability == "verified" and source.requirementsComplete and e
            and e.method == "client" and e.game == "forever" then return true end
    end
    return false
end
