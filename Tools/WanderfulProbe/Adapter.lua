local _, NS = ...
local Adapter = {}
NS.Adapter = Adapter
local SAVE_STEP = 14 -- Definition()[SAVE_STEP] is the intended reload/save step.

function Adapter.New(Probe, env, measure)
    local self = {}
    local originalID, manual, beforeManualID
    local beforeManualKnown = false
    local lastWait
    local function api(path)
        local value = env
        for part in path:gmatch("[^.]+") do
            if type(value) ~= "table" then return nil end
            value = rawget(value, part)
        end
        return value
    end
    local function secret(value)
        local fn = api("issecretvalue")
        if type(fn) ~= "function" then return true end
        local ok, result = pcall(fn, value)
        return not ok or type(result) ~= "boolean" or result
    end
    local function finite(value)
        return not secret(value) and type(value) == "number"
            and value == value and value > -math.huge and value < math.huge
    end
    local function call(path, ...) return Probe:Try(path, api(path), ...) end
    local function runtime()
        local value = api("Wanderful")
        assert(type(value) == "table" and value.apiVersion == 1,
            "Wanderful adapter API missing. Enable the matching Wanderful build, then reload.")
        return value
    end
    local function view()
        local ok, state = Probe:Try("Wanderful.GetBaseline", runtime().GetBaseline)
        assert(ok and not secret(state) and type(state) == "table", "Baseline could not be read.")
        -- Never store raw tables/links, even if an unexpected API version supplies them.
        local clean = {}
        for _, key in ipairs({ "mode", "status", "provenance", "itemID", "variant", "dps", "reason", "level", "levelStatus" }) do
            local value = state[key]
            if secret(value) then clean[key] = "<secret>"
            elseif type(value) == "string" or type(value) == "boolean" or finite(value) then clean[key] = value end
        end
        return clean
    end
    local function summary(state)
        local parts = {}
        for _, key in ipairs({ "mode", "status", "provenance", "itemID", "variant", "dps", "reason", "level", "levelStatus" }) do
            parts[#parts + 1] = key .. "=" .. Probe.Show(state[key])
        end
        return table.concat(parts, " ")
    end
    -- Independent client read: never invokes Refresh or a Wanderful slash command.
    local function equipped()
        local ok, id = call("GetInventoryItemID", "player", 18)
        if not ok then return { status = "unavailable" } end
        if secret(id) then return { status = "restricted" } end
        if id == nil then return { status = "empty" } end
        if not finite(id) or id <= 0 or id % 1 ~= 0 then return { status = "unknown" } end
        local input = { status = "unknown", itemID = id }
        local linkOK, link = call("GetInventoryItemLink", "player", 18)
        if not linkOK then input.status = "unavailable"; return input end
        if secret(link) then input.status = "restricted"; return input end
        if type(link) ~= "string" or link == "" then return input end
        local infoOK, infoID, _, _, _, _, classID, subclassID = call("C_Item.GetItemInfoInstant", link)
        if not infoOK then input.status = "unavailable"; return input end
        if secret(infoID) or secret(classID) or secret(subclassID) then input.status = "restricted"; return input end
        if infoID ~= id or not finite(classID) or not finite(subclassID) then return input end
        if classID ~= 2 or subclassID ~= 19 then input.status = "not_wand"; return input end
        local statsOK, stats = call("C_Item.GetItemStats", link)
        if not statsOK then input.status = "unavailable"; return input end
        if secret(stats) then input.status = "restricted"; return input end
        if type(stats) ~= "table" then return input end
        local dps = stats.ITEM_MOD_DAMAGE_PER_SECOND_SHORT
        if secret(dps) then input.status = "restricted"; return input end
        if finite(dps) and dps >= 0 then input.status, input.dps = "ready", dps end
        return input
    end
    local function live(state, input)
        if state.mode ~= "automatic" or input.status ~= "ready" or state.status ~= "ready"
            or state.provenance ~= "live" or state.itemID ~= input.itemID
            or not finite(state.dps) or state.dps ~= input.dps then return false end
        return true
    end
    local function record(label, state, input)
        local detail = summary(state)
        if input then detail = detail .. " | client " .. summary(input) end
        Probe:Say("ADAPTER " .. label .. " " .. detail)
        return detail
    end
    function self:Capture(label)
        return record(label or "passive snapshot", view(), equipped())
    end
    function self:Start()
        originalID, manual, beforeManualID, beforeManualKnown, lastWait = nil, nil, nil, false, nil
        assert(measure:CombatState() == "peace", "Start out of combat with a wand equipped.")
        local input = equipped()
        assert(finite(input.itemID), "Equip a wand before starting.")
        originalID = input.itemID
        measure:Context("adapter procedure")
        assert(Probe:Try("Wanderful.UseAutomaticBaseline", runtime().UseAutomaticBaseline))
        return self:Capture("begin automatic")
    end
    function self:CheckLive()
        local state, input = view(), equipped()
        return live(state, input), record("live comparison", state, input)
    end
    function self:Wait(kind)
        local state, input = view(), equipped()
        local passed
        if kind == "settled" then passed = state.status ~= "loading"
        elseif kind == "empty" then
            passed = state.mode == "automatic" and state.status == "empty"
                and state.dps == nil and input.status == "empty"
        elseif kind == "restored" then passed = originalID ~= nil and input.itemID == originalID and live(state, input)
        elseif kind == "replacement" then
            passed = originalID ~= nil and input.itemID ~= originalID and live(state, input)
        elseif kind == "manual-change" then
            passed = manual ~= nil and beforeManualKnown and input.itemID ~= beforeManualID
                and (input.status == "empty" or finite(input.itemID)) and input.status ~= "restricted"
                and input.status ~= "unavailable" and self:ManualMatches(state)
        elseif kind == "combat" then passed = measure:CombatState() == "combat"
        elseif kind == "peace" then passed = measure:CombatState() == "peace"
        end
        local detail = summary(state) .. " | client " .. summary(input)
        if kind == "combat" or kind == "peace" then detail = detail .. " | combat=" .. measure:CombatState() end
        if detail ~= lastWait then Probe:Say("ADAPTER waiting " .. kind .. " " .. detail); lastWait = detail end
        return passed == true, detail
    end
    function self:CheckEmpty()
        local passed = self:Wait("empty")
        return passed, self:Capture("empty")
    end
    function self:CheckRestored()
        local passed = self:Wait("restored")
        return passed, self:Capture("restored")
    end
    function self:CheckReplacement()
        local passed = self:Wait("replacement")
        return passed, self:Capture("replacement")
    end
    function self:ManualMatches(state)
        return manual ~= nil and state.mode == "manual" and state.status == "ready"
            and state.itemID == manual.itemID and state.variant == manual.variant
            and state.provenance == manual.provenance and state.dps == manual.dps
    end
    function self:SelectManual(historical)
        -- Invalidate an earlier attempt even if this retry cannot observe equipment.
        manual, beforeManualID, beforeManualKnown = nil, nil, false
        local input = equipped()
        local known = input.status == "empty" or finite(input.itemID)
        if not historical then
            assert(known, "Equipped identity is unreadable; retry when readable or Skip the manual-change check.")
        end
        local ok, selected = Probe:Try("Wanderful.SelectManualBaseline", runtime().SelectManualBaseline, 11287, "base", historical)
        assert(ok and selected == true, "Catalog baseline unavailable.")
        local state = view()
        assert(state.mode == "manual" and state.itemID == 11287 and state.variant == "base"
            and state.provenance == (historical and "historical" or "bundled") and finite(state.dps),
            "Manual selection was not reflected in runtime state.")
        manual, beforeManualID, beforeManualKnown = state, input.itemID, known
        return record(historical and "historical selection" or "manual selection", state, input)
    end
    function self:CheckManualChange()
        local passed = self:Wait("manual-change")
        return passed, self:Capture("manual after equipment change")
    end
    function self:Automatic()
        assert(measure:CombatState() == "peace", "Leave combat before restoring automatic mode.")
        assert(Probe:Try("Wanderful.UseAutomaticBaseline", runtime().UseAutomaticBaseline))
        return self:Capture("restored automatic")
    end
    function self:CheckCombat()
        assert(measure:CombatState() == "combat", "Retry while combat is active, or Skip.")
        local state, input = view(), equipped()
        local passed = live(state, input)
        if input.status == "restricted" then
            passed = state.mode == "automatic" and state.status == "restricted" and state.dps == nil
        end
        return passed, record("combat comparison", state, input)
    end
    -- The host resumes active steps, but adapter setup is intentionally session-only.
    -- An intermediate reload must not turn lost setup into a runtime timeout/FAIL.
    function self:OnLogin(host)
        if originalID ~= nil or type(host) ~= "table" then return false end
        local steps = type(host.db) == "table" and host.db.steps
        local key = "WanderfulProbe/adapter"
        local rec = type(steps) == "table" and steps.active == key
            and type(steps.records) == "table" and steps.records[key]
        if type(rec) ~= "table" or rec.status ~= "active" or not finite(rec.at)
            or rec.at < 1 or rec.at >= SAVE_STEP then return false end
        local reason = "Adapter setup was lost on reload; restart /fp steps wand adapter."
        Probe:Say(reason)
        return Probe:Try("stop interrupted adapter procedure", host.Steps and host.Steps.Stop, reason)
    end
    function self:Definition()
        return {
            rev = 2, title = "Wanderful: equipped-wand adapter",
            { text = "Equip a wand and stay out of combat, then Begin. The panel records build, baseline and checks automatically. It observes stored state without refreshing it. Skip optional actions you cannot perform.",
              button = "Begin adapter check", run = function() return self:Start() end },
            { text = "Wait for the initial baseline to settle. Unknown or failed reads are recorded; no item is treated as zero DPS.",
              wait = function() return self:Wait("settled") end, timeout = 15,
              check = function() return self:CheckLive() end },
            { text = "Remove your wand. This step completes when the client and the event-driven adapter both show an empty slot.",
              wait = function() return self:Wait("empty") end, timeout = 120,
              check = function() return self:CheckEmpty() end },
            { text = "Equip the original wand again. The panel checks its item ID and DPS without calling Refresh.",
              wait = function() return self:Wait("restored") end, timeout = 120,
              check = function() return self:CheckRestored() end },
            { text = "Optional: equip a different wand. Skip if you have no spare. A different item ID and its live DPS are required for this check.",
              wait = function() return self:Wait("replacement") end, timeout = 120,
              check = function() return self:CheckReplacement() end },
            { text = "Select Lesser Magic Wand as an explicit bundled baseline.", button = "Select manual baseline",
              run = function() return self:SelectManual(false) end },
            { text = "Remove or change your equipped wand. The manual baseline must stay unchanged. This step records both the equipment change and the manual state.",
              wait = function() return self:Wait("manual-change") end, timeout = 120,
              check = function() return self:CheckManualChange() end },
            { text = "Select the historical Classic reference. Its provenance is checked automatically.", button = "Select historical reference",
              run = function() return self:SelectManual(true) end },
            { text = "Equip a wand and stay out of combat, then restore automatic detection.", button = "Use equipped wand",
              run = function() return self:Automatic() end },
            { text = "Wait for the restored automatic baseline to settle.",
              wait = function() return self:Wait("settled") end, timeout = 15,
              check = function() return self:CheckLive() end },
            { text = "Optional: enter a safe combat encounter and remain in combat for the next button. Skip the combat steps if unavailable.",
              wait = function() return self:Wait("combat") end, timeout = 120 },
            { text = "While still in combat, record the stored baseline and independent item data. No console reading or yes/no judgment is needed.",
              button = "Record combat check", run = function() return self:Capture("combat sample") end,
              check = function() return self:CheckCombat() end },
            { text = "Leave combat. The adapter should refresh from its postcombat event.",
              wait = function() return self:Wait("peace") end, timeout = 120,
              check = function() return self:CheckLive() end },
            { text = "Reload to save the adapter results and context. This does not replace the earlier API or tooltip records.", reload = true },
            { text = "The adapter record is saved. Finish; if you add a Note here, reload once more to save it. No chat output needs to be pasted." },
        }
    end
    return self
end
