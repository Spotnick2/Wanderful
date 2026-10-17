local U = dofile("tests/ui_harness.lua")
local function probe(w)
    local p = w.NS.GuideChecks.New(w.Probe, w.env, w.measure)
    local db = {}; p:Bind(db)
    return p, db
end
local w = U.New()
local p, db = probe(w)
p:Start()
assert(not p:Capture("empty"), "manually completing removal while equipped must fail")
assert(not p:Capture("restored"), "an unchanged original wand is not proof of restoration")
w.itemID = nil; w.fire("PLAYER_EQUIPMENT_CHANGED", 18)
assert(p:Observe("empty") and p:Capture("empty"))
w.itemID = 100; w.fire("PLAYER_EQUIPMENT_CHANGED", 18)
assert(p:Observe("restored"))
-- A stale rendered view must fail; observation cannot call Refresh to fix it.
w.guide.rendered.itemID = 999
assert(not p:Observe("restored"))
assert(w.guide.rendered.itemID == 999)
w.guide:Refresh()
w.env.Wanderful.SelectManualBaseline(11287, "base")
assert(not p:Observe("restored"))
w.env.Wanderful.UseAutomaticBaseline()
p:BeginSave()
local ok, ready, detail = pcall(function() return p:Remember() end)
assert(ok and ready == false and detail:find("Track this wand", 1, true), "missing tracking is guidance, not a Lua error")
assert(db.guideExpected == nil and not p:HasGoal())
w.guide:SetFilter("source", "vendor")
w.guide.window:SetSize(920, 620); w.guide:SaveWindow()
local beforeTrackOK, beforeTrackReady = pcall(function() return p:Remember() end)
assert(beforeTrackOK and not beforeTrackReady and db.guideExpected == nil)
w.guide:Track()
assert(p:HasGoal() and p:CanRemember())
assert(p:Remember())
assert(db.guideExpected.revision > 0)
assert(not p:CheckSaved(), "same-session settings cannot pass a restart check")
local fresh = U.New(w.env.WanderfulDB)
local resumed = fresh.NS.GuideChecks.New(fresh.Probe, fresh.env, fresh.measure)
resumed:Bind(db)
resumed:Open()
assert(resumed:CheckSaved())
fresh.guide:SetFilter("source", "quest")
assert(not resumed:CheckSaved(), "changes after load cannot substitute for the captured settings")
resumed:BeginSave()
assert(not resumed:CanRemember(), "preexisting goals and settings cannot auto-capture before a deliberate change")
assert(db.guideExpected == nil, "new attempts invalidate an older sample")
local checked, passed = pcall(function() return resumed:CheckSaved() end)
assert(checked and passed == false, "a skipped/missing capture is a failed check, not a Lua error")
local wrong = U.New()
local lost = wrong.NS.GuideChecks.New(wrong.Probe, wrong.env, wrong.measure)
assert(not pcall(function() lost:Observe("empty") end), "lost run setup requires a restart")
for _, definition in ipairs({ p:Definition(), p:SaveDefinition(), p:EquipmentDefinition() }) do
    for _, step in ipairs(definition) do
        local count = 0
        for _, kind in ipairs({ "run", "wait", "event", "ask", "reload" }) do
            if step[kind] ~= nil then count = count + 1 end
        end
        assert(count <= 1 and type(step.text) == "string")
        if step.ask and step.text:find("visib") then assert(step.screenshot) end
    end
end
assert(p:SaveDefinition()[5].reload == "exit" and p:SaveDefinition()[6].ask)
assert(#w.chat == 0)
print("Guide probe: passive UI checks, restart revisions, stale samples and guided definitions passed.")