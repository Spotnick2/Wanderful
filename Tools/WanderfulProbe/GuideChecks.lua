local _, NS = ...
NS.GuideChecks = {}
function NS.GuideChecks.New(Probe, env, measure)
    local self = {}
    local db, originalID, emptyObserved, saveStartRevision
    local function runtime()
        local api = rawget(env, "Wanderful")
        assert(type(api) == "table" and type(api.GetGuideState) == "function"
            and type(api.OpenGuide) == "function", "Deploy and enable the Wanderful guide first.")
        return api
    end
    local function state()
        local s = runtime().GetGuideState()
        assert(type(s) == "table" and s.ready == true, "Guide settings have not loaded.")
        return s
    end
    local function record(label, s)
        local text = label .. "; shown=" .. tostring(s.shown) .. "; rows=" .. tostring(s.rows)
            .. "; rendered=" .. tostring(s.renderedMode) .. "/" .. tostring(s.renderedStatus)
            .. "; item=" .. tostring(s.renderedItemID) .. "; revision=" .. tostring(s.revision)
            .. "; loaded=" .. tostring(s.loadedRevision)
        Probe:Say(text)
        return text
    end
    function self:Bind(saved) db = saved end
    function self:Open()
        runtime().OpenGuide()
        return record("guide opened", state())
    end
    function self:Matches(status)
        -- Passive getters: the observation must never repair a stale rendered view.
        local api, s = runtime(), state()
        local b = api.GetBaseline()
        return s.shown == true and s.renderedMode == "automatic" and b.mode == "automatic"
            and s.renderedStatus == b.status and s.renderedItemID == b.itemID
            and (status == nil or s.renderedStatus == status), s
    end
    function self:Start()
        originalID, emptyObserved = nil, false
        measure:Context("guide UI")
        runtime().UseAutomaticBaseline()
        self:Open()
        local matches, s = self:Matches("ready")
        assert(matches and type(s.renderedItemID) == "number", "Equip a readable wand, then retry Begin.")
        originalID = s.renderedItemID
        return record("initial guide baseline", s)
    end
    function self:Observe(kind)
        assert(originalID, "UI setup was lost. Restart /fp steps wand ui.")
        local matches, s = self:Matches(kind == "empty" and "empty" or "ready")
        if kind == "empty" and matches then emptyObserved = true end
        if kind == "restored" then
            if not emptyObserved then return false, "No empty slot was observed. Go Back to removal, or Skip this unmeasured check." end
            matches = matches and s.renderedItemID == originalID
        end
        return matches, "Waiting for " .. kind .. "; guide shows " .. tostring(s.renderedStatus) .. ", item " .. tostring(s.renderedItemID)
    end
    function self:Capture(kind)
        local passed = self:Observe(kind)
        return passed, record("guide " .. kind, state())
    end
    function self:BeginSave()
        assert(db, "Probe saved variables have not loaded.")
        db.guideExpected = nil
        saveStartRevision = state().revision
        measure:Context("guide settings persistence")
        return self:Open()
    end
    function self:HasGoal()
        local s = state()
        return s.shown == true and type(s.trackedItemID) == "number",
            "In Wanderful, select a wand card, then click Track this wand in the right-hand How to get it panel. A Goal button appears along the bottom."
    end
    function self:CanRemember()
        if not db or type(saveStartRevision) ~= "number" then
            return false, "Begin the settings procedure first."
        end
        local s = state()
        if not s.shown then return false, "Open /wanderful to continue." end
        if type(s.trackedItemID) ~= "number" then
            return false, "Select a wand card and click Track this wand in the right-hand panel. Selecting or comparing a wand does not track it."
        end
        if type(s.revision) ~= "number" or s.revision <= saveStartRevision then
            return false, "Change a filter or move/resize Wanderful, then finish the edit (Enter for a level box)."
        end
        if type(s.signature) ~= "string" then return false, "Guide settings are not available yet." end
        return true, "Settings and tracked goal are ready to capture."
    end
    function self:Remember()
        if db then db.guideExpected = nil end
        local ready, detail = self:CanRemember()
        if not ready then Probe:Say(detail); return false, detail end
        local s = state()
        db.guideExpected = { signature = s.signature, revision = s.revision }
        return true, record("expected guide settings and tracked goal saved for restart comparison", s)
    end
    function self:CheckSaved()
        local expected = db and db.guideExpected
        if type(expected) ~= "table" then return false, "No expected settings were captured. Restart /fp steps wand uisave." end
        -- Compare the revision adopted at ADDON_LOADED, not a revision mutated by opening.
        local s = state()
        local passed = expected.revision > 0 and s.loadedRevision == expected.revision
            and s.signature == expected.signature
        return passed, record("guide settings after restart", s)
    end
    function self:Definition()
        return {
            rev = 3, title = "Wanderful: Browse Wands cards",
            { text = "Equip a wand and stay out of combat. Begin opens Wanderful. Move the probe panel aside. Measurements are automatic; visual answers save screenshots and notes.",
              button = "Begin UI check", run = function() return self:Start() end },
            { text = "Can you read the character, equipped baseline, item icons, names, DPS gains and level badges? Do the cards stand out from the controls without excessive glow? Note overlap or clipping.",
              ask = true, screenshot = "wand-guide-list" },
            { text = "Select several cards. Hover cards/icons for native item tooltips; try Shift comparison and Shift-click into an open chat box. Track a wand, choose another card, then return using Goal. Selection/tracking must not change the baseline. Try Compare from this wand, then Use equipped wand, and Evidence and requirements. Does each action behave as labeled?",
              ask = true, screenshot = "wand-guide-details" },
            { text = "Try search, source, sorting and Upgrades only. Open Filters for level range (Enter applies), class, faction and school. Try an empty search/filter, then Reset filters. Do the results and empty message make sense?",
              ask = true, screenshot = "wand-guide-filters" },
            { text = "Resize to a small and large window, change the game's UI scale, and inspect against a bright outdoor scene and a dark interior. Are text, controls and scrolling usable? Record the scale and any clipped text in Note.",
              ask = true, screenshot = "wand-guide-layout" },
            { text = "Prepare the equipment check. This button restores automatic comparison and records the wand currently equipped.",
              button = "Prepare equipment check", run = function() return self:Start() end },
            { text = "Open your character equipment window (C). Move the wand from its equipped slot into your bags, leaving that slot empty. Keep Wanderful visible. This is an inventory action, not a Wanderful button. The step advances when the guide shows No wand equipped; Skip if unavailable.",
              wait = function() return self:Observe("empty") end, timeout = 120,
              check = function() return self:Capture("empty") end },
            { text = "Equip the original wand. The check observes its return in the rendered guide.",
              wait = function() return self:Observe("restored") end, timeout = 120,
              check = function() return self:Capture("restored") end },
            { text = "Reload to save the UI observations. Settings persistence has its own full-exit procedure.", reload = true },
            { text = "Finish this record, then run /fp steps wand uisave for the full-exit settings check. No chat output needs to be pasted." },
        }
    end
    function self:EquipmentDefinition()
        return {
            rev = 1, title = "Wanderful: equipment UI follow-up",
            { text = "Equip a wand, stay out of combat, and press Prepare. The probe opens Wanderful, restores automatic comparison and records that wand. No baseline button needs to be pressed.",
              button = "Prepare wand check", run = function() return self:Start() end },
            { text = "Open your character equipment window (C). Move the equipped wand into your bags, leaving its slot empty. Keep Wanderful visible. The panel advances automatically when No wand equipped appears. This is an inventory action. Skip if unavailable.",
              wait = function() return self:Observe("empty") end, timeout = 120,
              check = function() return self:Capture("empty") end },
            { text = "Equip the same wand again. This check requires an observed empty state first, then the original wand returning through the rendered automatic baseline.",
              wait = function() return self:Observe("restored") end, timeout = 120,
              check = function() return self:Capture("restored") end },
            { text = "Reload to save this focused result without overwriting the full UI run.", reload = true },
            { text = "Finish. The equipment follow-up is stored separately as uiequip." },
        }
    end
    function self:SaveDefinition()
        return {
            rev = 3, title = "Wanderful: guide settings after full exit",
            { text = "Open the guide. This clears any previous expected-settings sample.",
              button = "Begin settings check", run = function() return self:BeginSave() end },
            { text = "In Wanderful, select a wand card. In the right-hand How to get it panel click Track this wand. A Goal button appears along the bottom. Selecting a card or Compare from this wand does not track it. If it already says Stop tracking this wand, the goal is set. This step advances automatically.",
              wait = function() return self:HasGoal() end, timeout = 300 },
            { text = "Move/resize Wanderful or change a filter for this test. Press Enter after editing a level. When you have finished all changes, press Next here. The following step captures the settings and tracked goal; keep them unchanged until after the restart." },
            { text = "Capture the prepared settings and goal. This step advances automatically when both are ready; any missing setup is explained below.",
              wait = function() return self:CanRemember() end, timeout = 300,
              check = function() return self:Remember() end, screenshot = "wand-guide-before-exit" },
            { text = "Exit World of Warcraft completely, then relaunch and log into the same account. Do not use /reload for this step.", reload = "exit" },
            { text = "Did you exit the client completely and relaunch, rather than use /reload? The host cannot distinguish them; choose No or Not sure if you did not.",
              ask = true },
            { text = "Compare the settings adopted at addon load with the saved sample.",
              auto = true, run = function() return self:Open() end,
              check = function() return self:CheckSaved() end },
            { text = "Are the guide position, size, filter choices and tracked goal visibly the same as before exiting? The window is opened by the probe; open/closed state and manual baseline are session-only.",
              ask = true, screenshot = "wand-guide-after-exit" },
            { text = "Reload to save the comparison and visual confirmation.", reload = true },
            { text = "Finish. Results and screenshots are in the probe record; no console transcription is needed." },
        }
    end
    return self
end