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
        return matches, "Waiting for the visible guide and automatic baseline to agree."
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
            rev = 1, title = "Wanderful: first guide window",
            { text = "Equip a wand and stay out of combat. Begin opens Wanderful. Move the probe panel aside. Measurements are automatic; visual answers save screenshots and notes.",
              button = "Begin UI check", run = function() return self:Start() end },
            { text = "Can you read the equipped baseline, wand names, level, school, DPS, gain and source status? A DPS upgrade must not imply a verified source. Note any overlap or unclear wording.",
              ask = true, screenshot = "wand-guide-list" },
            { text = "Select several wands and scroll both panes. Can you read the acquisition notes, requirements and evidence? Try both baseline buttons, then Use equipped wand. Do the labels and gains follow your choices?",
              ask = true, screenshot = "wand-guide-details" },
            { text = "Try the level boxes (press Enter), class, faction, source, school and Upgrades only. Try a filter with no results, then Reset filters. Do the list and empty message make sense?",
              ask = true, screenshot = "wand-guide-filters" },
            { text = "Resize to a small and large window, change the game's UI scale, and inspect against a bright outdoor scene and a dark interior. Are text, controls and scrolling usable? Record the scale and any clipped text in Note.",
              ask = true, screenshot = "wand-guide-layout" },
            { text = "Press Use equipped wand in Wanderful, keep the guide visible and remove your wand. The check observes the rendered empty state without refreshing it.",
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
            rev = 1, title = "Wanderful: guide settings after full exit",
            { text = "Open the guide. This clears any previous expected-settings sample.",
              button = "Begin settings check", run = function() return self:BeginSave() end },
            { text = "Move and resize Wanderful, then change at least one filter. Press Enter after editing a level. Keep those choices until after the restart. Capture stores the current settings for comparison.",
              button = "Capture settings", run = function() return self:Remember() end, screenshot = "wand-guide-before-exit" },
            { text = "Exit World of Warcraft completely, then relaunch and log into the same account. Do not use /reload for this step.", reload = "exit" },
            { text = "Did you exit the client completely and relaunch, rather than use /reload? The host cannot distinguish them; choose No or Not sure if you did not.",
              ask = true },
            { text = "Compare the settings adopted at addon load with the saved sample.",
              auto = true, run = function() return self:Open() end,
              check = function() return self:CheckSaved() end },
            { text = "Are the guide position, size and filter choices visibly the same as before exiting? The window is opened by the probe; open/closed state and manual baseline are session-only.",
              ask = true, screenshot = "wand-guide-after-exit" },
            { text = "Reload to save the comparison and visual confirmation.", reload = true },
            { text = "Finish. Results and screenshots are in the probe record; no console transcription is needed." },
        }
    end
    return self
end