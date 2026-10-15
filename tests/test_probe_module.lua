local H = dofile("tests/probe_harness.lua")
local w = H.New()
local P, env = w.Probe, w.env
env.ForeverProbe = { Module = function(_, name, options)
    assert(name == "WanderfulProbe" and options.api == 1 and options.cmd == "wand")
    return P
end }
local chunk = assert(loadfile("Tools/WanderfulProbe/WanderfulProbe.lua"))
setfenv(chunk, env)("WanderfulProbe", w.NS)
assert(rawget(env, "WanderfulProbeDB") == nil)
local log = {}
env.WanderfulProbeDB = { log = log }
w.fire("ADDON_LOADED", "AnotherAddon")
assert(#log == 0)
w.fire("ADDON_LOADED", "WanderfulProbe")
assert(P.log == log and env.WanderfulProbeDB.loads == 1)
P.commands.clear()
assert(#log == 1 and log[1] == "log cleared")
P.commands.state()
assert(#w.chat == 0 and w.has("slot 18 unavailable"))

local steps = assert(P.procedures.check)
assert(steps.rev == 1 and #steps == 20)
for _, step in ipairs(steps) do
    assert(type(step.text) == "string")
    local kinds = 0
    for _, field in ipairs({ "run", "event", "ask", "reload" }) do
        if step[field] ~= nil then kinds = kinds + 1 end
    end
    assert(kinds <= 1, "each step must have at most one action kind")
end
assert(steps[19].reload == true)
assert(not pcall(steps[15].run), "combat sampling must refuse an out-of-combat run")
w.combat = true
assert(pcall(steps[15].run))
assert(not pcall(steps[18].run), "final sampling must refuse an in-combat run")
w.combat = false
assert(pcall(steps[18].run))
env.InCombatLockdown = nil
assert(not pcall(steps[18].run), "missing combat API is not proof of being out of combat")
print("Probe module: saved-variable timing, guided definitions and combat preconditions passed.")
