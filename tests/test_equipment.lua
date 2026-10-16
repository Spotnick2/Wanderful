local ns = {}
assert(loadfile("Comparison.lua"))("Wanderful", ns)
assert(loadfile("Equipment.lua"))("Wanderful", ns)
local count = 0
local function test(name, fn)
    local ok, err = pcall(fn)
    assert(ok, name .. ": " .. tostring(err))
    count = count + 1
end
-- Secret sentinels explode if used in arithmetic, comparisons or formatting.
local secret = setmetatable({}, {
    __eq = function() error("secret compared") end, __lt = function() error("secret ordered") end,
    __add = function() error("secret arithmetic") end, __tostring = function() error("secret formatted") end,
    __index = function() error("secret indexed") end,
})
local function fixture()
    local f = { itemID = 100, link = "item:100:variantA", dps = 20, classID = 2, subclassID = 19,
        timers = {}, requests = {}, updates = {}, level = 15 }
    local snapshot = { stats = { dps = 11.33 }, evidence = "database" }
    f.data = { items = { { itemID = 11287, variant = "base", forever = snapshot,
        classic = { stats = { dps = 11.3 }, evidence = "classic" } } } }
    f.env = {
        issecretvalue = function(v) return rawequal(v, secret) end,
        GetInventoryItemID = function(unit, slot) assert(unit == "player" and slot == 18); return f.itemID end,
        GetInventoryItemLink = function(unit, slot) assert(unit == "player" and slot == 18); return f.link end,
        UnitLevel = function() return f.level end,
        GetBuildInfo = function() return "1.60.1", "70425" end,
        C_Item = {
            GetItemInfoInstant = function(link)
                assert(link == f.link)
                return f.itemID, nil, nil, nil, nil, f.classID, f.subclassID
            end,
            GetItemStats = function(link) assert(link == f.link); return f.statsOverride or { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = f.dps } end,
            RequestLoadItemDataByID = function(itemID) f.requests[#f.requests + 1] = itemID end,
        },
        C_Timer = { After = function(seconds, fn) assert(seconds == 8); f.timers[#f.timers + 1] = fn end },
    }
    f.adapter = ns.Equipment.New(f.env, f.data, function(state) f.updates[#f.updates + 1] = state end)
    function f:swap(itemID, dps, suffix)
        self.itemID, self.link, self.dps = itemID, itemID and ("item:" .. itemID .. ":" .. (suffix or "base")), dps
        self.adapter:Event("PLAYER_EQUIPMENT_CHANGED", 18, true)
    end
    return f
end

test("login reads an unknown catalog item using its full link and observed item DPS", function()
    local f = fixture(); f.adapter:Event("PLAYER_LOGIN")
    local s = f.adapter.state
    assert(s.mode == "automatic" and s.status == "ready" and s.provenance == "live")
    assert(s.snapshot.stats.dps == 20 and s.snapshot.evidence.build == "70425" and s.level == 15)
    assert(#f.requests == 0 and #f.timers == 0)
end)
test("replace and remove clear the previous comparison without relying on event boolean", function()
    local f = fixture(); f.adapter:Refresh()
    f:swap(200, 25)
    assert(f.adapter.state.itemID == 200 and f.adapter.state.snapshot.stats.dps == 25)
    f:swap(nil, nil)
    assert(f.adapter.state.status == "empty" and f.adapter.state.snapshot == nil)
end)
test("uncached data requests once and both supported events reread current equipment", function()
    for _, event in ipairs({ "ITEM_DATA_LOAD_RESULT", "GET_ITEM_INFO_RECEIVED" }) do
        local f = fixture(); f.dps = nil; f.adapter:Refresh()
        assert(f.adapter.state.status == "loading" and #f.requests == 1)
        f.adapter:Refresh(); assert(#f.requests == 1)
        f.dps = 25; f.adapter:Event(event, 100, true)
        assert(f.adapter.state.snapshot.stats.dps == 25)
        f.timers[1](); assert(f.adapter.state.status == "ready")
    end
end)
test("late success and failure cannot restore an earlier equipped wand", function()
    local f = fixture(); f.dps = nil; f.adapter:Refresh()
    f:swap(200, nil)
    f.adapter:Event("ITEM_DATA_LOAD_RESULT", 100, true)
    f.adapter:Event("GET_ITEM_INFO_RECEIVED", 100, false)
    f.timers[1]()
    assert(f.adapter.state.itemID == 200 and f.adapter.state.status == "loading")
    f.dps = 30; f.adapter:Event("ITEM_DATA_LOAD_RESULT", 200, true)
    assert(f.adapter.state.snapshot.stats.dps == 30)
    f.timers[2](); assert(f.adapter.state.snapshot.stats.dps == 30)
end)
test("late loads after removal have no baseline", function()
    local f = fixture(); f.dps = nil; f.adapter:Refresh(); f:swap(nil, nil)
    f.adapter:Event("ITEM_DATA_LOAD_RESULT", 100, true); f.timers[1]()
    assert(f.adapter.state.status == "empty" and f.adapter.state.snapshot == nil)
end)
test("same ID with different link never reuses an old DPS snapshot", function()
    local f = fixture(); f.adapter:Refresh()
    f:swap(100, nil, "variantB")
    assert(f.adapter.state.status == "loading" and f.adapter.state.snapshot == nil)
    f.adapter:Event("ITEM_DATA_LOAD_RESULT", 100, false)
    assert(f.adapter.state.status == "loading" and #f.requests == 1)
    f.dps = 33; f.adapter:Event("GET_ITEM_INFO_RECEIVED", 100, true)
    assert(f.adapter.state.snapshot.stats.dps == 33 and f.adapter.state.link == "item:100:variantB")
end)
test("deadline terminates loading without treating missing DPS as zero or retrying", function()
    local f = fixture(); f.dps = nil; f.adapter:Refresh()
    f.adapter:Event("ITEM_DATA_LOAD_RESULT", 100, false)
    f.timers[1]()
    assert(f.adapter.state.status == "unknown" and f.adapter.state.reason == "load_exhausted")
    assert(f.adapter.state.snapshot == nil)
    f.adapter:Refresh(); assert(#f.requests == 1)
    f.adapter:Automatic(); assert(#f.requests == 2)
end)
test("data available at deadline is read instead of discarded", function()
    local f = fixture(); f.dps = nil; f.adapter:Refresh()
    f.dps = 21; f.timers[1]()
    assert(f.adapter.state.snapshot.stats.dps == 21)
end)
test("restricted fields are never used in comparisons, table access, arithmetic or output", function()
    for _, field in ipairs({ "itemID", "link", "classID", "subclassID", "dps", "statsOverride" }) do
        local f = fixture(); f[field] = secret; f.adapter:Refresh()
        assert(f.adapter.state.status == "restricted" and f.adapter.state.snapshot == nil)
        assert(#f.requests == 0)
    end
    local f = fixture(); f.level = secret; f.adapter:Refresh()
    assert(f.adapter.state.level == nil and f.adapter.state.levelStatus == "restricted")
end)
test("restricted and malformed load payloads cannot resolve or compare requests", function()
    local f = fixture(); f.dps = nil; f.adapter:Refresh()
    f.adapter:Event("ITEM_DATA_LOAD_RESULT", secret, true)
    f.adapter:Event("ITEM_DATA_LOAD_RESULT", 100, secret)
    f.adapter:Event("GET_ITEM_INFO_RECEIVED", 100, "yes")
    f.adapter:Event("PLAYER_EQUIPMENT_CHANGED", secret)
    assert(f.adapter.state.status == "loading" and #f.requests == 1)
end)
test("missing restriction inspection fails closed while manual catalog remains usable", function()
    local f = fixture(); f.env.issecretvalue = nil; f.adapter:Refresh()
    assert(f.adapter.state.status == "restricted")
    assert(f.adapter:Manual(11287, "base", false))
    assert(f.adapter.state.provenance == "bundled")
end)
test("missing and throwing APIs fail safely with no stale baseline", function()
    for _, replacement in ipairs({ false, function() error("API unavailable") end }) do
        local f = fixture(); f.adapter:Refresh()
        f.env.GetInventoryItemID = replacement; f.adapter:Refresh()
        assert(f.adapter.state.status == "unavailable" and f.adapter.state.snapshot == nil)
    end
    local f = fixture(); f.env.C_Item.GetItemStats = nil; f.adapter:Refresh()
    assert(f.adapter.state.status == "unavailable" and f.adapter.state.snapshot == nil)
end)
test("timer, load event and request availability are required for bounded loading", function()
    for _, field in ipairs({ "timer", "events", "request" }) do
        local f = fixture(); f.dps = nil
        if field == "timer" then f.env.C_Timer = nil
        elseif field == "events" then f.adapter.loadsAvailable = false
        else f.env.C_Item.RequestLoadItemDataByID = nil end
        f.adapter:Refresh()
        assert(f.adapter.state.status == "unavailable" and #f.requests == 0)
    end
end)
test("refused timer and request do not leave loading or stale deadlines", function()
    local f = fixture(); f.dps = nil
    f.env.C_Timer.After = function() error("refused") end; f.adapter:Refresh()
    assert(f.adapter.state.status == "unavailable" and #f.requests == 0)
    f = fixture(); f.dps = nil
    f.env.C_Item.RequestLoadItemDataByID = function() error("refused") end; f.adapter:Refresh()
    assert(f.adapter.state.status == "failed"); f.timers[1]()
    assert(f.adapter.state.status == "failed")
end)
test("invalid DPS never becomes a valid baseline", function()
    for _, value in ipairs({ -1, math.huge, 0/0, "20" }) do
        local f = fixture(); f.dps = value; f.adapter:Refresh()
        assert(f.adapter.state.status == "unknown" and f.adapter.state.snapshot == nil)
    end
    local f = fixture(); f.dps = 0; f.adapter:Refresh()
    assert(ns.Comparison.Compare({ stats = { dps = 25 } }, f.adapter.state.snapshot).percent == nil)
end)
test("non-wands are identified using numeric class fields", function()
    local f = fixture(); f.subclassID = 7; f.adapter:Refresh()
    assert(f.adapter.state.status == "not_wand" and #f.requests == 0)
end)
test("missing link and missing instant metadata can load without catalog assumptions", function()
    local f = fixture(); f.link = nil; f.adapter:Refresh()
    assert(f.adapter.state.status == "loading" and #f.requests == 1)
    f.link = "item:100:suffix"; f.adapter:Event("ITEM_DATA_LOAD_RESULT", 100, true)
    assert(f.adapter.state.status == "ready")
    f = fixture(); f.classID = nil; f.adapter:Refresh()
    assert(f.adapter.state.status == "loading")
    f.classID = 2; f.adapter:Event("ITEM_DATA_LOAD_RESULT", 100, true)
    assert(f.adapter.state.status == "ready")
end)
test("manual and historical baselines have explicit provenance and survive late events", function()
    local f = fixture(); f.dps = nil; f.adapter:Refresh()
    assert(f.adapter:Manual(11287, "base", false))
    assert(f.adapter.state.mode == "manual" and f.adapter.state.provenance == "bundled")
    f:swap(200, 33); f.adapter:Event("ITEM_DATA_LOAD_RESULT", 100, true); f.timers[1]()
    assert(f.adapter.state.itemID == 11287 and f.adapter.state.snapshot.stats.dps == 11.33)
    assert(f.adapter:Manual(11287, "base", true))
    assert(f.adapter.state.provenance == "historical" and f.adapter.state.snapshot.stats.dps == 11.3)
    assert(not f.adapter:Manual(11287, "unknown", false))
    assert(not f.adapter:Manual(99999, "base", false))
    f.adapter:Automatic()
    assert(f.adapter.state.mode == "automatic" and f.adapter.state.snapshot.stats.dps == 33)
end)
test("level and postcombat events refresh without polling", function()
    local f = fixture(); f.adapter:Refresh()
    f.adapter:Event("PLAYER_LEVEL_UP", 16)
    assert(f.adapter.state.level == 16)
    f.dps = secret; f.adapter:Event("PLAYER_EQUIPMENT_CHANGED", 18)
    assert(f.adapter.state.status == "restricted")
    f.dps = 22; f.adapter:Event("PLAYER_REGEN_ENABLED")
    assert(f.adapter.state.snapshot.stats.dps == 22 and #f.timers == 0)
end)
test("runtime registers events, exposes slash commands and labels manual mode", function()
    local f, runtimeNS, scripts, messages, events = fixture(), {}, {}, {}, {}
    local env = setmetatable({}, { __index = _G })
    for key, value in pairs(f.env) do env[key] = value end
    env._G, env.SlashCmdList = env, {}
    env.print = function(text) messages[#messages + 1] = text end
    env.CreateFrame = function(kind)
        assert(kind == "Frame")
        return { RegisterEvent = function(_, event) events[event] = true; return true end,
            SetScript = function(_, key, fn) scripts[key] = fn end }
    end
    for line in io.lines("Wanderful.toc") do
        line = line:match("^%s*(.-)%s*$")
        if line ~= "" and line:sub(1, 1) ~= "#" then
            local chunk = assert(loadfile(line:gsub("\\", "/"))); setfenv(chunk, env)("Wanderful", runtimeNS)
        end
    end
    assert(events.PLAYER_LOGIN and events.ITEM_DATA_LOAD_RESULT and events.GET_ITEM_INFO_RECEIVED)
    assert(runtimeNS.Equipped.loadsAvailable == true)
    scripts.OnEvent(nil, "PLAYER_LOGIN")
    env.SlashCmdList.WANDERFUL("baseline 11287")
    assert(messages[#messages]:find("/wanderful auto", 1, true))
    assert(messages[#messages - 1]:find("manual baseline; ready; bundled", 1, true))
    env.SlashCmdList.WANDERFUL("historical 11287")
    assert(messages[#messages - 1]:find("historical", 1, true))
    env.SlashCmdList.WANDERFUL("auto")
    assert(messages[#messages]:find("automatic baseline; ready; live", 1, true))
end)
test("A to B to A ignores earlier deadlines and same-ID failure hints", function()
    local f = fixture(); f.dps = nil; f.adapter:Refresh()
    f:swap(200, nil); f:swap(100, nil, "variantA")
    f.adapter:Event("ITEM_DATA_LOAD_RESULT", 100, false)
    f.timers[1](); f.timers[2]()
    assert(f.adapter.state.status == "loading" and f.adapter.state.itemID == 100)
    assert(#f.requests == 3)
    f.dps = 29; f.adapter:Event("GET_ITEM_INFO_RECEIVED", 100, true)
    f.timers[3]()
    assert(f.adapter.state.snapshot.stats.dps == 29)
end)
test("a reentrant load callback cannot be overwritten by a request exception", function()
    local f = fixture(); f.dps = nil
    f.env.C_Item.RequestLoadItemDataByID = function(itemID)
        f.dps = 28; f.adapter:Event("ITEM_DATA_LOAD_RESULT", itemID, true)
        error("request threw after dispatch")
    end
    f.adapter:Refresh()
    assert(f.adapter.state.status == "ready" and f.adapter.state.snapshot.stats.dps == 28)
    f.timers[1]()
    assert(f.adapter.state.snapshot.stats.dps == 28)
end)
test("runtime refuses loading when either load event returns false or throws", function()
    for _, refusedEvent in ipairs({ "ITEM_DATA_LOAD_RESULT", "GET_ITEM_INFO_RECEIVED" }) do
        for _, throws in ipairs({ false, true }) do
            local f, runtimeNS, scripts = fixture(), { Equipment = ns.Equipment }, {}
            f.dps = nil
            runtimeNS.WandData = f.data
            local env = setmetatable({}, { __index = _G })
            for key, value in pairs(f.env) do env[key] = value end
            env._G = env
            env.CreateFrame = function()
                return {
                    RegisterEvent = function(_, event)
                        if event == refusedEvent then
                            if throws then error("registration refused") end
                            return false
                        end
                        return true
                    end,
                    SetScript = function(_, key, fn) scripts[key] = fn end,
                }
            end
            local chunk = assert(loadfile("Runtime.lua"))
            setfenv(chunk, env)("Wanderful", runtimeNS)
            assert(runtimeNS.Equipped.loadsAvailable == false, refusedEvent .. " refusal was ignored")
            scripts.OnEvent(nil, "PLAYER_LOGIN")
            local state = runtimeNS.Equipped.state
            assert(state.status == "unavailable" and state.reason == "bounded_loading_unavailable")
            assert(state.snapshot == nil and #f.requests == 0 and #f.timers == 0)
            assert(runtimeNS.Equipped:Manual(11287, "base", false))
            assert(runtimeNS.Equipped.state.provenance == "bundled")
        end
    end
end)
print("Equipment: " .. count .. " tests passed.")
