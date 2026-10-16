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
print("Probe host integration: saved-variable timing, dispatch, log clearing and guided records passed.")
