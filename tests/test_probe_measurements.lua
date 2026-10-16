local H = dofile("tests/probe_harness.lua")
local count = 0
local function test(name, fn)
    local ok, err = pcall(fn)
    assert(ok, name .. ": " .. tostring(err))
    count = count + 1
end

test("missing APIs remain unavailable rather than empty", function()
    local w = H.New()
    local result = w.measure:Equipment("missing")
    assert(result:find("18=unavailable", 1, true))
    assert(result:find("16=unavailable", 1, true))
    assert(w.has("MISSING") and #w.chat == 0)
end)

test("empty slots and restricted values are distinct", function()
    local w = H.New()
    local secret = w.secret()
    w.env.GetInventoryItemID = function(_, slot) if slot == 16 then return secret end end
    w.env.GetInventoryItemLink = function() return secret end
    w.env.UnitRangedDamage = function() return secret, secret, secret end
    local result = w.measure:Equipment("restricted")
    assert(result == "18=empty, 16=restricted")
    assert(w.has("<secret>") and #w.chat == 0)
end)

test("API errors do not stop the remaining observations", function()
    local w = H.New()
    w.env.C_Item.GetItemInfo = function() error("fixture error") end
    w.env.C_Item.GetItemInfoInstant = function() return 11287, "Weapon", "Wand" end
    w.measure:Item(11287)
    assert(w.has("ERROR") and w.has("Wand"))
end)

test("tooltip secrets and inventory names are not saved", function()
    local w = H.New()
    local s = w.secret()
    w.env.C_TooltipInfo = {
        GetItemByID = function() return { dataInstanceID = s, lines = { s, { type = 1, args = { { floatVal = s } } } } } end,
        GetInventoryItem = function() return { lines = { { type = 1, leftText = "PRIVATE-MAKER-NAME", rightText = s } } } end,
    }
    w.measure:Item(11287)
    w.measure:Tooltip("C_TooltipInfo.GetInventoryItem", true, "player", 18)
    assert(w.has("<secret>") and not w.has("PRIVATE-MAKER-NAME"))
    w.env.C_TooltipInfo.GetItemByID = function() return s end
    w.measure:Item(11287)
end)

test("cache state precedes requests and includes the invalid candidate", function()
    local w = H.New()
    w.cache[11287] = true
    assert(w.measure:RequestSamples())
    assert(#w.requests == 10 and w.requests[10] == 2147483647)
    assert(w.has("REQUEST 11287 cacheBefore=warm"))
    assert(w.has("REQUEST 11288 cacheBefore=cold"))
end)

test("success and failure events resolve only matching requests", function()
    local w = H.New()
    w.measure:RequestSamples()
    w.measure:LoadEvent("ITEM_DATA_LOAD_RESULT", 11287, true)
    w.measure:LoadEvent("ITEM_DATA_LOAD_RESULT", 11288, false)
    w.measure:LoadEvent("ITEM_DATA_LOAD_RESULT", 7, true)
    assert(w.measure.pending[11287] == nil and w.measure.pending[11288] == nil)
    assert(w.has("ITEM 11287") and not w.has("ITEM 11288") and not w.has("ITEM 7"))
    w.tick()
    assert(next(w.measure.pending) == nil)
    assert(w.has("timeout; not proof"))
end)

test("restricted and malformed event payloads remain unresolved", function()
    local w = H.New()
    w.measure:RequestSamples()
    w.measure:LoadEvent("ITEM_DATA_LOAD_RESULT", w.secret(), true)
    w.measure:LoadEvent("ITEM_DATA_LOAD_RESULT", 11287, w.secret())
    w.measure:LoadEvent("ITEM_DATA_LOAD_RESULT", 11287, "true")
    assert(w.measure.pending[11287] and w.has("restricted payload"))
    w.tick()
    assert(next(w.measure.pending) == nil)
end)

test("old deadlines cannot expire a replacement experiment", function()
    local w = H.New()
    w.measure:RequestSamples()
    local old = w.timers[1]
    w.measure:RequestSamples()
    old()
    assert(w.measure.pending[11287])
    w.timers[2]()
    assert(next(w.measure.pending) == nil)
end)

test("missing or refusing timers never leave pending requests", function()
    local w = H.New()
    w.env.C_Timer = nil
    assert(not w.measure:RequestSamples() and #w.requests == 0)
    w.env.C_Timer = { After = function() error("timer unavailable") end }
    assert(not w.measure:RequestSamples() and next(w.measure.pending) == nil)
end)

test("missing request API has an explicit outcome", function()
    local w = H.New()
    w.env.C_Item.RequestLoadItemDataByID = nil
    w.measure:RequestSamples()
    assert(next(w.measure.pending) == nil and w.has("request unavailable/refused"))
end)

test("warm metadata does not turn a request dispatch into success", function()
    local w = H.New()
    w.env.C_Item.IsItemDataCachedByID = nil
    w.measure:RequestSamples()
    assert(w.measure.pending[11287] and w.has("cacheBefore=unknown"))
end)

test("equipment watch is bounded and can be stopped", function()
    local w = H.New()
    w.measure:BeginWatch()
    for i = 1, 25 do w.measure:Event("PLAYER_EQUIPMENT_CHANGED", 18, true) end
    assert(w.measure.eventCount == 20 and w.has("Watch event limit"))
    w.measure:StopWatch()
    w.measure:Event("PLAYER_REGEN_DISABLED")
    assert(w.measure.eventCount == 20)
end)

test("quest returns are observations including false and secret", function()
    local w = H.New()
    w.env.C_QuestLog = { IsQuestFlaggedCompleted = function(id)
        if id == 99 then return false elseif id == 96393 then return true else return w.secret() end
    end }
    w.measure:Quests()
    assert(w.has("99 characterCompleted=false") and w.has("96393 characterCompleted=true"))
    assert(w.has("96391 characterCompleted=<secret>") and #w.chat == 0)
end)

test("combat measurement never treats missing or restricted state as active", function()
    local w = H.New()
    assert(w.measure:CombatState() == "peace")
    w.combat = true
    assert(w.measure:CombatState() == "combat")
    w.env.InCombatLockdown = function() return w.secret() end
    assert(w.measure:CombatState() == "restricted")
    w.env.InCombatLockdown = nil
    assert(w.measure:CombatState() == "unavailable")
end)


test("comparison evidence is readable without logs and guards secrets", function()
    local w = H.New()
    w.env.GetInventoryItemID = function() return 11287 end
    w.env.C_Item.GetItemInfo = function() return "Lesser Magic Wand" end
    w.env.C_Item.GetItemStats = function() return { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 11.3333 } end
    w.env.C_TooltipInfo = { GetItemByID = function()
        return { lines = { { leftText = "12 - 22 Arcane Damage", rightText = "Speed 1.50" } } }
    end }
    local text, id = w.measure:ReviewEquipment()
    assert(id == 11287 and text:find("Lesser Magic Wand", 1, true))
    assert(text:find("11.3333", 1, true) and text:find("Speed 1.50", 1, true))
    w.env.C_Item.GetItemStats = function() return w.secret() end
    w.env.C_TooltipInfo.GetItemByID = function() return { lines = { { leftText = w.secret(), rightText = w.secret() } } } end
    assert(w.measure:ReviewItem(11287):find("<secret>", 1, true))
    w.env.UnitRangedDamage = function() return w.secret(), w.secret() end
    assert(w.measure:ReviewRestrictions():find("<secret>", 1, true))
    w.env.GetInventoryItemID = function() return w.secret() end
    assert(w.measure:ReviewEquipment() == "Ranged slot 18: <secret>")
end)

print("Probe measurements: " .. count .. " tests passed.")
