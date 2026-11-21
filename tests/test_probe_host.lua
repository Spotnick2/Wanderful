-- Integration with the owner's real host checkout. No private host code is copied
-- or fetched by CI. Uses the same client stubs as the measurement tests.
local root = (os.getenv("FOREVERPROBE") or "../ForeverProbe"):gsub("\\", "/"):gsub("/$", "")
local toc = io.open(root .. "/ForeverProbe.toc", "r")
if not toc then
    if os.getenv("FOREVERPROBE_OPTIONAL") == "1" then
        print("SKIPPED: real ForeverProbe integration requires the local private checkout.")
        return
    end
    error("ForeverProbe checkout missing at " .. root .. "; set FOREVERPROBE or clone the sibling.")
end

local H = dofile("tests/probe_harness.lua")
local w = H.New()
local env = w.env
local function savedLogHas(environment, part)
    local db = environment.WanderfulProbeDB
    for _, line in ipairs(db and db.log or {}) do
        if line:find(part, 1, true) then return true end
    end
    return false
end
local function load(path, addon, ns)
    local chunk = assert(loadfile(path))
    setfenv(chunk, env)(addon, ns)
end
for line in toc:lines() do
    line = line:match("^%s*(.-)%s*$")
    if line:match("%.lua$") and line:sub(1, 1) ~= "#" then
        load(root .. "/" .. line:gsub("\\", "/"), "ForeverProbe", {})
    end
end
toc:close()
env.ForeverProbeDB = nil
w.fire("ADDON_LOADED", "ForeverProbe")
local FP = assert(rawget(env, "ForeverProbe"))
assert(FP.ready)
-- Headless test: use the actual commands/steps backend, without building UI widgets.
FP.Console = nil

local ns = {}
load("Tools/WanderfulProbe/Measurements.lua", "WanderfulProbe", ns)
load("Tools/WanderfulProbe/Adapter.lua", "WanderfulProbe", ns)
load("Tools/WanderfulProbe/GuideChecks.lua", "WanderfulProbe", ns)
load("Tools/WanderfulProbe/WanderfulProbe.lua", "WanderfulProbe", ns)
assert(rawget(env, "WanderfulProbeDB") == nil, "saved variables must not be made at file scope")
env.WanderfulProbeDB = { log = {}, loads = 4 }
local bound = env.WanderfulProbeDB.log
w.fire("ADDON_LOADED", "WanderfulProbe")
assert(env.WanderfulProbeDB.loads == 5 and ns._test.Probe.log == bound)

env.SlashCmdList.FOREVERPROBE("wand state")
assert(#bound > 0 and #w.chat == 0, "observations must stay out of chat")
env.SlashCmdList.FOREVERPROBE("wand clear")
assert(env.WanderfulProbeDB.log == bound and #bound == 1 and bound[1]:find("log cleared", 1, true))
assert(FP.lines[#FP.lines].text:find("log cleared", 1, true))

env.SlashCmdList.FOREVERPROBE("steps wand check")
local record = assert(FP.db.steps.records["WanderfulProbe/check"])
FP.Steps.Note("headless fixture")
FP.Steps.Next()
FP.Steps.Run() -- context
FP.Steps.Run() -- requests
w.tick()
FP.Steps.Next() -- deadline check
assert(record.results[1].notes[1] ~= nil)
assert(record.results[2].status == "done" and record.results[4].check == "PASS")
FP.Steps.Stop("test finished")
assert(record.status == "stopped" and #w.chat == 0)
-- Exercise the new procedure through the real updated host, including its wait backend.
H.LoadRuntime(w)
w.fire("PLAYER_LOGIN")
env.SlashCmdList.FOREVERPROBE("steps wand adapter")
local adapterRecord = assert(FP.db.steps.records["WanderfulProbe/adapter"])
FP.Steps.Run() -- begin, switches to automatic
FP.Steps.Poll() -- settled baseline
assert(adapterRecord.at == 3 and adapterRecord.results[2].check == "PASS")
FP.Steps.Note("removal event fixture")
w.itemID = nil
FP.Steps.Poll()
assert(adapterRecord.at == 3, "host polling must not refresh stale adapter state")
w.fire("PLAYER_EQUIPMENT_CHANGED", 18, false)
FP.Steps.Poll()
assert(adapterRecord.results[3].check == "PASS" and adapterRecord.results[3].notes[1])
w.itemID = 100
w.fire("PLAYER_EQUIPMENT_CHANGED", 18, true)
FP.Steps.Poll()
assert(adapterRecord.results[4].check == "PASS")
FP.Steps.Skip() -- optional spare
FP.Steps.Run() -- manual selection
w.itemID = nil
w.fire("PLAYER_EQUIPMENT_CHANGED", 18, false)
FP.Steps.Poll()
assert(adapterRecord.results[7].check == "PASS")
FP.Steps.Run() -- historical selection
w.itemID = 100
FP.Steps.Run() -- automatic mode
FP.Steps.Poll()
assert(adapterRecord.results[10].check == "PASS")
FP.Steps.Skip() -- optional combat encounter
FP.Steps.Skip() -- optional combat sample
FP.Steps.Poll() -- already out of combat; check live baseline
assert(adapterRecord.at == 14 and adapterRecord.results[13].check == "PASS")
-- Final reload/resume is exercised below with fresh Lua environments.
FP.Steps.Skip()
assert(adapterRecord.at == 15)
FP.Steps.Next()
assert(adapterRecord.status == "done" and adapterRecord.results[5].status == "skipped")
assert(FP.db.steps.records["WanderfulProbe/check"] == record and record.status == "stopped")

-- A missing equipment event times out as a saved FAIL, not a fabricated confirmation.
env.SlashCmdList.FOREVERPROBE("steps wand adapter")
local failedRecord = FP.db.steps.records["WanderfulProbe/adapter"]
FP.Steps.Run()
FP.Steps.Poll()
assert(failedRecord.at == 3)
w.now = w.now + 121
FP.Steps.Poll()
assert(failedRecord.results[3].status == "timeout" and failedRecord.results[3].check == "FAIL")
FP.Steps.Stop("failure path checked")
assert(#w.chat == 0 and not savedLogHas(env, "PRIVATE-CRAFT-NAME"))
-- Recreate the host, runtime and probe environments while retaining only saved tables.
-- This models a reload's loss of locals; it is not a filesystem persistence claim.
local function savedCopy(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for key, child in pairs(value) do copy[key] = savedCopy(child) end
    return copy
end
local function reloadEnvironment(hostDB, probeDB, reverseEvents)
    local fresh = H.New()
    local newEnv = fresh.env
    local function loadFresh(path, addon, namespace)
        local chunk = assert(loadfile(path))
        setfenv(chunk, newEnv)(addon, namespace)
    end
    for line in io.lines(root .. "/ForeverProbe.toc") do
        line = line:match("^%s*(.-)%s*$")
        if line:match("%.lua$") and line:sub(1, 1) ~= "#" then
            loadFresh(root .. "/" .. line:gsub("\\", "/"), "ForeverProbe", {})
        end
    end
    newEnv.ForeverProbeDB = savedCopy(hostDB)
    fresh.fire("ADDON_LOADED", "ForeverProbe")
    local host = assert(newEnv.ForeverProbe)
    host.Console = nil
    H.LoadRuntime(fresh)
    local namespace = {}
    for _, name in ipairs({ "Measurements.lua", "Adapter.lua", "GuideChecks.lua", "WanderfulProbe.lua" }) do
        loadFresh("Tools/WanderfulProbe/" .. name, "WanderfulProbe", namespace)
    end
    newEnv.WanderfulProbeDB = savedCopy(probeDB)
    fresh.fire("ADDON_LOADED", "WanderfulProbe")
    if reverseEvents then
        for i = 1, math.floor(#fresh.frames / 2) do
            local j = #fresh.frames - i + 1
            fresh.frames[i], fresh.frames[j] = fresh.frames[j], fresh.frames[i]
        end
    end
    fresh.fire("PLAYER_LOGIN")
    return fresh, host
end
for _, reverseEvents in ipairs({ false, true }) do
    for _, interruptedStep in ipairs({ 4, 5, 7 }) do
        w.itemID, w.dps = 100, 20
        env.SlashCmdList.FOREVERPROBE("steps wand adapter")
        FP.Steps.Run()
        FP.Steps.Poll()
        w.itemID = nil
        w.fire("PLAYER_EQUIPMENT_CHANGED", 18, false)
        FP.Steps.Poll() -- restoration
        if interruptedStep >= 5 then
            w.itemID = 100
            w.fire("PLAYER_EQUIPMENT_CHANGED", 18, true)
            FP.Steps.Poll()
        end
        if interruptedStep == 7 then FP.Steps.Skip(); FP.Steps.Run() end
        assert(FP.db.steps.records["WanderfulProbe/adapter"].at == interruptedStep)
        local fresh, host = reloadEnvironment(FP.db, env.WanderfulProbeDB, reverseEvents)
        local interrupted = host.db.steps.records["WanderfulProbe/adapter"]
        assert(interrupted.status == "stopped" and host.db.steps.active == nil,
            "lost intermediate context must stop with a restart message")
        assert(savedLogHas(fresh.env, "restart /fp steps wand adapter"))
        host.Steps.Poll()
        local current = interrupted.results[interruptedStep]
        assert(not current or (current.status ~= "timeout" and current.check ~= "FAIL"))
        assert(host.db.steps.records["WanderfulProbe/check"].status == "stopped")
        assert(#fresh.chat == 0)
        FP.Steps.Stop("reload fixture captured")
    end
    -- The intended final save/reload still resumes and completes with fresh environments.
    env.SlashCmdList.FOREVERPROBE("steps wand adapter")
    while FP.db.steps.records["WanderfulProbe/adapter"].at < 14 do FP.Steps.Skip() end
    local fresh, host = reloadEnvironment(FP.db, env.WanderfulProbeDB, reverseEvents)
    local finalRecord = host.db.steps.records["WanderfulProbe/adapter"]
    assert(finalRecord.status == "active" and finalRecord.at == 15)
    host.Steps.Next()
    assert(finalRecord.status == "done" and #fresh.chat == 0)
    FP.Steps.Stop("final reload fixture captured")
end
print("Probe host integration: saved-variable timing, dispatch, log clearing, adapter waits, failures and guided records passed.")
