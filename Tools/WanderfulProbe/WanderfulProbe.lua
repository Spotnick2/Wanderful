local ADDON, NS = ...
local Host = rawget(_G, "ForeverProbe")
local Probe = Host:Module("WanderfulProbe", { api = 1, cmd = "wand" })
local measure = NS.Measurements.New(Probe, _G)
local adapter = NS.Adapter.New(Probe, _G, measure)
local frame = CreateFrame("Frame")
local tooltip
local evidenceFrame, evidenceText

local function showEvidence(text)
    Probe:Say("REVIEW\n" .. text)
    -- Tests use the real host headlessly; no UIParent means no client UI to render.
    local parent = rawget(_G, "UIParent")
    if not parent then return text end
    if not evidenceFrame then
        evidenceFrame = CreateFrame("Frame", "WanderfulProbeEvidence", parent, "BackdropTemplate")
        evidenceFrame:SetSize(460, 440)
        evidenceFrame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -30, -160)
        evidenceFrame:SetFrameStrata("DIALOG")
        evidenceFrame:SetClampedToScreen(true)
        evidenceFrame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
        evidenceFrame:SetBackdropColor(0.04, 0.04, 0.06, 0.96)
        evidenceFrame:SetMovable(true)
        evidenceFrame:EnableMouse(true)
        evidenceFrame:RegisterForDrag("LeftButton")
        evidenceFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
        evidenceFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
        local title = evidenceFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOPLEFT", 12, -12)
        title:SetText("Wand evidence - API values")
        local close = CreateFrame("Button", nil, evidenceFrame, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", 0, 0)
        evidenceText = evidenceFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        evidenceText:SetPoint("TOPLEFT", 12, -38)
        evidenceText:SetWidth(436)
        evidenceText:SetJustifyH("LEFT")
        evidenceText:SetWordWrap(true)
    end
    evidenceText:SetText(text)
    evidenceFrame:Show()
    return text
end

local function showItemTooltip(itemID)
    measure:Item(itemID)
    if not tooltip then
        local ok, value = Probe:Try("create sample tooltip", rawget(_G, "CreateFrame"),
            "GameTooltip", "WanderfulProbeTooltip", rawget(_G, "UIParent"), "GameTooltipTemplate")
        if not ok then return "sample tooltip unavailable" end
        tooltip = value
    end
    Probe:Try("tooltip owner", tooltip.SetOwner, tooltip, rawget(_G, "UIParent"), "ANCHOR_NONE")
    Probe:Try("clear tooltip anchors", tooltip.ClearAllPoints, tooltip)
    if evidenceFrame then
        Probe:Try("tooltip anchor", tooltip.SetPoint, tooltip, "RIGHT", evidenceFrame, "LEFT", -12, 0)
    else
        Probe:Try("tooltip anchor", tooltip.SetPoint, tooltip, "CENTER", rawget(_G, "UIParent"), "CENTER", 240, 0)
    end
    Probe:Try("sample tooltip", tooltip.SetHyperlink, tooltip, "item:" .. itemID)
    Probe:Try("show sample tooltip", tooltip.Show, tooltip)
end

local function showSampleTooltip()
    local text = showEvidence(measure:ReviewItem(11287))
    showItemTooltip(11287)
    return text
end

local function showEquipmentEvidence()
    local text, itemID = measure:ReviewEquipment()
    showEvidence(text)
    if itemID then showItemTooltip(itemID) end
    return text
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
    if evidenceFrame then evidenceFrame:Hide() end
    return measure:StopWatch()
end, "stop equipment/combat observations and hide the sample tooltip")
Probe:Command("clear", function() Probe:ClearLog(); Probe:Say("log cleared") end, "empty the bound saved log in place")

Probe:Command("adapter", function() return adapter:Capture("manual passive observation") end, "observe the stored adapter baseline without refreshing it")
Probe:Steps("adapter", adapter:Definition())

Probe:Steps("check", {
    rev = 2,
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
    { text = "Compare the API text in the Wand evidence window with the pinned game tooltip. Do damage, speed, school and DPS agree? If either is missing, choose Skip and leave a Note.",
      ask = true, screenshot = "wand-public-tooltip" },
    { text = "Record your equipped wand. Both slot 18 and slot 16 are inspected to establish Forever's slot behavior.",
      button = "Read equipment", run = function()
          if tooltip then tooltip:Hide() end
          measure:Equipment("equipped baseline")
          return showEquipmentEvidence()
      end },
    { text = "Compare the Wand evidence window with the pinned tooltip for your equipped item. Do the name, damage and speed agree? Choose Skip if you cannot see both.",
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
          showEvidence(measure:ReviewEquipment() .. "\n\n" .. measure:ReviewRestrictions())
          return result
      end },
    { text = "API restrictions were recorded automatically and are shown in the Wand evidence window. No yes/no judgment or console inspection is needed. Continue when ready." },
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

-- A short follow-up preserves the full run's saved check record.
Probe:Steps("verify", {
    rev = 1,
    title = "Wanderful: visible tooltip comparisons",
    { text = "Show the sample tooltip beside readable API evidence.", button = "Show sample", run = showSampleTooltip },
    { text = "Can you see the Wand evidence window and the game tooltip? Do their damage, speed, school and DPS agree? Skip if either is absent and use Note.",
      ask = true, screenshot = "wand-visible-sample" },
    { text = "Show your equipped ranged item's tooltip and API evidence.", button = "Show equipped", run = showEquipmentEvidence },
    { text = "Do the displayed item name, damage and speed agree between the two windows? Skip if no wand is equipped or the evidence is missing.",
      ask = true, screenshot = "wand-visible-equipped" },
    { text = "Reload to save these two comparisons.", reload = true },
    { text = "The visual follow-up is saved separately from your original full run." },
})

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        adapter:OnLogin(Host)
        frame:UnregisterEvent("PLAYER_LOGIN")
        return
    end
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
    Probe:Say("loaded; /fp steps wand adapter checks the runtime; /fp steps wand check measures item APIs")
end)
Probe:RegisterEvents(frame, { "ADDON_LOADED", "PLAYER_LOGIN" })
measure.eventsAvailable = Probe:RegisterEvents(frame, { "ITEM_DATA_LOAD_RESULT", "GET_ITEM_INFO_RECEIVED" })
Probe:RegisterEvents(frame, { "PLAYER_EQUIPMENT_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" })

NS._test = { Probe = Probe, measure = measure, adapter = adapter, frame = frame }
