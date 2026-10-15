local ADDON, NS = ...
local Host = rawget(_G, "ForeverProbe")
local Probe = Host:Module("WanderfulProbe", { api = 1, cmd = "wand" })
local measure = NS.Measurements.New(Probe, _G)
local frame = CreateFrame("Frame")
local tooltip

local function showSampleTooltip()
    measure:Item(11287)
    if not tooltip then
        local ok, value = Probe:Try("create sample tooltip", rawget(_G, "CreateFrame"),
            "GameTooltip", "WanderfulProbeTooltip", rawget(_G, "UIParent"), "GameTooltipTemplate")
        if not ok then return "sample tooltip unavailable" end
        tooltip = value
    end
    Probe:Try("tooltip owner", tooltip.SetOwner, tooltip, rawget(_G, "UIParent"), "ANCHOR_NONE")
    Probe:Try("tooltip anchor", tooltip.SetPoint, tooltip, "CENTER", rawget(_G, "UIParent"), "CENTER", 240, 0)
    Probe:Try("sample tooltip", tooltip.SetHyperlink, tooltip, "item:11287")
    Probe:Try("show sample tooltip", tooltip.Show, tooltip)
    return "Public item tooltip shown; compare it with the public-line log entries."
end

Probe:Command("state", function() return measure:Equipment("manual state") end, "sample equipment and item APIs")
Probe:Command("item", function(args)
    local id = tonumber(args)
    if not id or id <= 0 or id >= math.huge or id % 1 ~= 0 then
        Probe:Say("Use /fp wand item <positive item ID>"); return
    end
    measure:Context("manual item")
    measure:Item(id)
end, "<itemID> inspect metadata, stats, and public tooltip")
Probe:Command("load", function() return measure:RequestSamples() end, "request nine sample IDs and an invalid candidate")
Probe:Command("quests", function() measure:Context("manual quests"); measure:Quests() end, "character quest-completion observations")
Probe:Command("watch", function() return measure:BeginWatch() end, "capture the next 20 equipment/combat events")
Probe:Command("stop", function()
    if tooltip then tooltip:Hide() end
    return measure:StopWatch()
end, "stop equipment/combat observations and hide the sample tooltip")
Probe:Command("clear", function() Probe:ClearLog(); Probe:Say("log cleared") end, "empty the bound saved log in place")

Probe:Steps("check", {
    rev = 1,
    title = "Wanderful: wand item APIs",
    { text = "Use a caster with a wand and, if available, a spare. Check /fp facts first. Stay out of combat. You can Skip any unavailable action; notes and screenshots are saved by the panel." },
    { text = "Record the client context.", button = "Record context",
      run = function() measure:Context("guided baseline"); return "context recorded" end },
    { text = "Request the sample items before opening their tooltips. This records whether each was already cached; it cannot force a cold cache.",
      button = "Request items", run = function() return measure:RequestSamples() end },
    { text = "Wait at least eight seconds. Check the console for success, failure, or timeout per item. An invalid-ID timeout is not proof that the item does not exist.",
      check = function() return next(measure.pending) == nil, "all requests reached an outcome" end },
    { text = "Read Lesser Magic Wand's public tooltip and its logged structured lines. Damage, speed, school and DPS are observed without parsing localized text.",
      button = "Show sample", run = showSampleTooltip },
    { text = "Do the logged public tooltip damage, speed, school and DPS agree with the visible sample tooltip? Use Note for missing structured fields or differences.",
      ask = true, screenshot = "wand-public-tooltip" },
    { text = "Record your equipped wand. Both slot 18 and slot 16 are inspected to establish Forever's slot behavior.",
      button = "Read equipment", run = function()
          if tooltip then tooltip:Hide() end
          return measure:Equipment("equipped baseline")
      end },
    { text = "Open your character pane and hover your wand. Does the log identify the correct item and match its base damage and speed? UnitRangedDamage can include character modifiers. Use Note for differences.",
      ask = true, screenshot = "wand-equipped-tooltip" },
    { text = "Start observing equipment and combat events.", button = "Start watch",
      run = function() return measure:BeginWatch() end },
    { text = "Out of combat, remove your wand. The next equipment event completes this step; use Done only if no event arrives, and explain that in Note.",
      event = "PLAYER_EQUIPMENT_CHANGED" },
    { text = "Read the slots after removing the wand. The log distinguishes empty, restricted and unavailable results.",
      button = "Read empty slot", run = function() return measure:Equipment("after removal") end },
    { text = "Equip a spare wand, or restore the original if no spare is available. Note which you used. The next equipment event completes the step.",
      event = "PLAYER_EQUIPMENT_CHANGED" },
    { text = "Read the restored/replaced wand.", button = "Read replacement",
      run = function() return measure:Equipment("after replacement") end },
    { text = "Enter a safe combat encounter. Keep the panel available; the next step must run while combat is still active. Skip the combat steps if unavailable.",
      event = "PLAYER_REGEN_DISABLED" },
    { text = "While still in combat, sample equipment, public item data, and character quest completion.",
      button = "Read in combat", run = function()
          assert(measure:CombatState() == "combat", "Combat is not observable as active; retry while in combat or Skip.")
          local result = measure:Equipment("combat")
          measure:Quests()
          return result
      end },
    { text = "Were any item values missing or marked <secret> in combat? Use Note to identify the API. Yes means a restriction was observed; it is not a test failure.",
      ask = true },
    { text = "Leave combat before continuing.", event = "PLAYER_REGEN_ENABLED" },
    { text = "Sample again out of combat, then stop the equipment watch.",
      button = "Read after combat", run = function()
          assert(measure:CombatState() == "peace", "Leave combat before taking the final snapshot.")
          local result = measure:Equipment("after combat")
          measure:Quests()
          measure:StopWatch()
          return result
      end },
    { text = "Reload to save the module log and guided outcomes to disk.", reload = true },
    { text = "Results are saved in WanderfulProbe.lua and ForeverProbe.lua. Finish, then /reload once more if you added notes after the reload step." },
})

frame:SetScript("OnEvent", function(_, event, ...)
    if event ~= "ADDON_LOADED" then measure:Event(event, ...); return end
    local name = ...
    if name ~= ADDON then return end
    frame:UnregisterEvent("ADDON_LOADED")
    Probe:Ready()
    local db = rawget(_G, "WanderfulProbeDB")
    if type(db) ~= "table" then db = {}; WanderfulProbeDB = db end
    if type(db.log) ~= "table" then db.log = {} end
    Probe:UseLog(db.log, 3000)
    db.loads = (type(db.loads) == "number" and db.loads or 0) + 1
    Probe:Say("loaded; /fp steps wand check starts the guided procedure")
end)
Probe:RegisterEvents(frame, { "ADDON_LOADED" })
measure.eventsAvailable = Probe:RegisterEvents(frame, { "ITEM_DATA_LOAD_RESULT", "GET_ITEM_INFO_RECEIVED" })
Probe:RegisterEvents(frame, { "PLAYER_EQUIPMENT_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" })

NS._test = { Probe = Probe, measure = measure, frame = frame }
