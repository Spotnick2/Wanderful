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
assert(steps.rev == 2 and #steps == 20)
for _, step in ipairs(steps) do
    assert(type(step.text) == "string")
    local kinds = 0
    for _, field in ipairs({ "run", "event", "ask", "reload" }) do
        if step[field] ~= nil then kinds = kinds + 1 end
    end
    assert(kinds <= 1, "each step must have at most one action kind")
end
assert(steps[19].reload == true)
assert(not steps[16].ask, "restriction detection must not require reading hidden logs")
assert(P.procedures.verify and #P.procedures.verify == 6, "short visual follow-up preserves the original record")
assert(not pcall(steps[15].run), "combat sampling must refuse an out-of-combat run")
w.combat = true
assert(pcall(steps[15].run))
assert(not pcall(steps[18].run), "final sampling must refuse an in-combat run")
w.combat = false
assert(pcall(steps[18].run))
env.InCombatLockdown = nil
assert(not pcall(steps[18].run), "missing combat API is not proof of being out of combat")

-- Exercise the visible comparison path, rather than only the headless host.
local widgets, texts = {}, {}
local createFrame = env.CreateFrame
env.UIParent = {}
env.CreateFrame = function(...)
    local widget = createFrame(...)
    for _, method in ipairs({ "SetSize", "SetFrameStrata", "SetClampedToScreen", "SetBackdrop",
        "SetBackdropColor", "SetMovable", "EnableMouse", "RegisterForDrag", "SetWidth", "SetJustifyH",
        "SetWordWrap", "SetOwner", "ClearAllPoints", "SetHyperlink" }) do widget[method] = function() end end
    function widget:SetPoint(...) self.anchor = { ... } end
    function widget:Show() self.shown = true end
    function widget:Hide() self.shown = false end
    function widget:SetText(text) texts[#texts + 1] = text end
    function widget:CreateFontString() return env.CreateFrame("FontString") end
    widgets[#widgets + 1] = widget
    return widget
end
env.C_Item.GetItemInfo = function() return "Lesser Magic Wand" end
env.C_Item.GetItemStats = function() return { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 11.3333 } end
env.C_TooltipInfo = { GetItemByID = function()
    return { lines = { { leftText = "12 - 22 Arcane Damage", rightText = "Speed 1.50" } } }
end }
P.procedures.verify[1].run()
local visible = table.concat(texts, "\n")
assert(visible:find("Lesser Magic Wand", 1, true) and visible:find("Speed 1.50", 1, true))
local evidence, tooltip = widgets[1], widgets[#widgets]
assert(evidence.shown and tooltip.shown, "both sides of the visual comparison must be visible")
assert(tooltip.anchor[2] == evidence and tooltip.anchor[3] == "LEFT", "tooltip must sit beside the evidence")
P.commands.stop()
assert(not evidence.shown and not tooltip.shown)

print("Probe module: saved-variable timing, guided definitions and combat preconditions passed.")
