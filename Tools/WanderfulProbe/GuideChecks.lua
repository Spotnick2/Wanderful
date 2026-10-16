local _, NS = ...
NS.GuideChecks = {}
function NS.GuideChecks.New(Probe, env, measure)
    local self = {}
    local db, originalID
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
        originalID = nil
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
        if kind == "restored" then matches = matches and s.renderedItemID == originalID end
        return matches, "Waiting for " .. kind .. "; guide shows " .. tostring(s.renderedStatus) .. ", item " .. tostring(s.renderedItemID)
    end
    function self:Capture(kind)
        local passed = self:Observe(kind)
        return passed, record("guide " .. kind, state())
    end
    function self:BeginSave()
        assert(db, "Probe saved variables have not loaded.")
        db.guideExpected = nil
        measure:Context("guide settings persistence")
        return self:Open()
    end
    function self:Remember()
        assert(db, "Probe saved variables have not loaded.")
        db.guideExpected = nil
        local s = state()
        assert(s.shown and type(s.revision) == "number" and s.revision > 0
            and s.revision > s.loadedRevision, "Move/resize the guide and change a filter in this session, then retry.")
        assert(type(s.trackedItemID) == "number", "Track a wand before capturing the settings and goal.")
        assert(type(s.signature) == "string", "Guide settings signature is missing.")
        db.guideExpected = { signature = s.signature, revision = s.revision }
        return record("expected guide settings saved for restart comparison", s)
    end
    function self:CheckSaved()
        local expected = db and db.guideExpected
        assert(type(expected) == "table", "No expected settings. Restart /fp steps wand uisave.")
        -- Compare the revision adopted at ADDON_LOADED, not a revision mutated by opening.
        local s = state()
        local passed = expected.revision > 0 and s.loadedRevision == expected.revision
            and s.signature == expected.signature
        return passed, record("guide settings after restart", s)
    end
    function self:Definition()
        return {
            rev = 2, title = "Wanderful: Browse Wands cards",
            { text = "Equip a wand and stay out of combat. Begin opens Wanderful. Move the probe panel aside. Measurements are automatic; visual answers save screenshots and notes.",
              button = "Begin UI check", run = function() return self:Start() end },
            { text = "Can you read the character, equipped baseline, item icons, names, DPS gains and level badges? Do the cards stand out from the controls without excessive glow? Note overlap or clipping.",
              ask = true, screenshot = "wand-guide-list" },
            { text = "Select several cards. Hover cards/icons for native item tooltips; try Shift comparison and Shift-click into an open chat box. Track a wand, choose another card, then return using Goal. Selection/tracking must not change the baseline. Try Compare from this wand, Reset to equipped, and Evidence and requirements. Does each action behave as labeled?",
              ask = true, screenshot = "wand-guide-details" },
            { text = "Try search, source, sorting and Upgrades only. Open Filters for level range (Enter applies), class, faction and school. Try an empty search/filter, then Reset filters. Do the results and empty message make sense?",
              ask = true, screenshot = "wand-guide-filters" },
            { text = "Resize to a small and large window, change the game's UI scale, and inspect against a bright outdoor scene and a dark interior. Are text, controls and scrolling usable? Record the scale and any clipped text in Note.",
              ask = true, screenshot = "wand-guide-layout" },
            { text = "Press Equipped baseline or Reset to equipped, keep Wanderful visible, and remove the wand without replacing it. The panel waits for an empty state. If another wand remains equipped it keeps waiting; Skip if you cannot produce an empty slot. Do not use Done to claim an empty state.",
              wait = function() return self:Observe("empty") end, timeout = 120,
              check = function() return self:Capture("empty") end },
            { text = "Equip the original wand. The check observes its return in the rendered guide.",
              wait = function() return self:Observe("restored") end, timeout = 120,
              check = function() return self:Capture("restored") end },
            { text = "Reload to save the UI observations. Settings persistence has its own full-exit procedure.", reload = true },
            { text = "Finish this record, then run /fp steps wand uisave for the full-exit settings check. No chat output needs to be pasted." },
        }
    end
    function self:SaveDefinition()
        return {
            rev = 2, title = "Wanderful: guide settings after full exit",
            { text = "Open the guide. This clears any previous expected-settings sample.",
              button = "Begin settings check", run = function() return self:BeginSave() end },
            { text = "Move and resize Wanderful, change at least one filter and Track a wand. Press Enter after editing a level. Keep these choices until after the restart. Capture stores the current settings and goal for comparison.",
              button = "Capture settings", run = function() return self:Remember() end, screenshot = "wand-guide-before-exit" },
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