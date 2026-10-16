local H = dofile("tests/probe_harness.lua")
local w = H.New()
local runtimeNS = H.LoadRuntime(w)
local env, P = w.env, w.Probe
env.ForeverProbe = { Module = function() return P end }
local chunk = assert(loadfile("Tools/WanderfulProbe/WanderfulProbe.lua"))
setfenv(chunk, env)("WanderfulProbe", w.NS)
w.fire("ADDON_LOADED", "WanderfulProbe")
w.fire("PLAYER_LOGIN")
local steps = assert(P.procedures.adapter)
assert(steps.rev == 1 and #steps == 15 and steps[14].reload == true)
assert(P.procedures.check and P.procedures.verify, "existing records must have separate procedure keys")
for _, step in ipairs(steps) do
    local kinds = 0
    for _, key in ipairs({ "run", "event", "wait", "ask", "reload" }) do
        if step[key] ~= nil then kinds = kinds + 1 end
    end
    assert(kinds == 1 or kinds == 0)
    assert(not step.ask, "runtime checks must not ask the owner to interpret hidden logs")
end
steps[1].run()
assert(steps[2].wait() and steps[2].check())
assert(env.Wanderful.GetBaseline().dps == 20)

-- Passive observation must not conceal a missing equipment event.
w.itemID = nil
assert(not steps[3].wait())
assert(env.Wanderful.GetBaseline().status == "ready", "the probe must not refresh the adapter")
w.fire("PLAYER_EQUIPMENT_CHANGED", 18, false)
assert(steps[3].wait() and steps[3].check())

w.itemID = 100
assert(not steps[4].wait())
w.fire("PLAYER_EQUIPMENT_CHANGED", 18, true)
assert(steps[4].wait() and steps[4].check())
w.itemID, w.dps = 200, 25
assert(not steps[5].wait())
w.fire("PLAYER_EQUIPMENT_CHANGED", 18, true)
assert(steps[5].wait() and steps[5].check())

steps[6].run()
assert(not steps[7].wait())
w.itemID = nil
w.fire("PLAYER_EQUIPMENT_CHANGED", 18, false)
assert(steps[7].wait() and steps[7].check())
assert(env.Wanderful.GetBaseline().provenance == "bundled")
steps[8].run()
assert(env.Wanderful.GetBaseline().provenance == "historical")
w.itemID, w.dps = 100, 20
steps[9].run()
assert(steps[10].wait() and steps[10].check())
assert(not steps[11].wait())
w.combat = true
assert(steps[11].wait())
steps[12].run()
assert(steps[12].check())
w.dps = w.secret()
local passed = steps[12].check()
assert(passed == false, "a stale ready baseline must not pass a restricted client reading")
w.dps, w.combat = 20, false
w.fire("PLAYER_REGEN_ENABLED")
assert(steps[13].wait() and steps[13].check())

-- Only scalar copies leave the runtime, and observation performs no client reads.
local copy = env.Wanderful.GetBaseline()
assert(copy.link == nil and copy.snapshot == nil)
copy.dps = -99
assert(env.Wanderful.GetBaseline().dps == 20)
local oldRead = env.GetInventoryItemID
env.GetInventoryItemID = function() error("passive view touched client") end
assert(env.Wanderful.GetBaseline().dps == 20)
env.GetInventoryItemID = oldRead
assert(#w.chat == 0, "guided checks must not print diagnostics or invoke chat slash commands")
assert(not w.has("PRIVATE-CRAFT-NAME"), "full links must not enter logs")
assert(w.has("ADAPTER empty") and w.has("ADAPTER manual after equipment change"))
assert(w.has("ADAPTER combat comparison") and w.has("<secret>") == false)

-- Secret client data produces a safe marker and cannot be compared or persisted raw.
env.GetInventoryItemID = function() return w.secret() end
assert(pcall(P.commands.adapter))
assert(w.has("client mode=nil status=restricted"))
env.GetInventoryItemID = oldRead

-- Missing runtime is a clear procedure error, never a fabricated pass.
env.Wanderful = nil
assert(not pcall(steps[1].run))
assert(#w.chat == 0)
print("Adapter procedure: passive event checks, manual/combat paths, privacy and runtime facade passed.")
