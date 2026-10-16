local _, NS = ...
local Measurements = {}
NS.Measurements = Measurements

local SAMPLE_IDS = { 11287, 11288, 5243, 5242, 279896, 5208, 7001, 5198, 12984 }
local INVALID_ID = 2147483647
Measurements.SampleIDs = SAMPLE_IDS
Measurements.InvalidID = INVALID_ID

function Measurements.New(Probe, env)
    local self = { pending = {}, generation = 0, watching = false, eventCount = 0 }
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
        return type(fn) == "function" and fn(value)
    end
    local function say(text) Probe:Say(text) end
    local function plainID(value)
        return not secret(value) and type(value) == "number"
            and value > 0 and value < math.huge and value % 1 == 0
    end
    local function call(path, ...)
        return Probe:Call(path, api(path), ...)
    end

    function self:Context(label)
        say("CONTEXT " .. label)
        call("GetBuildInfo")
        call("GetLocale")
        call("InCombatLockdown")
        say("WOW_PROJECT_ID=" .. Probe.Show(rawget(env, "WOW_PROJECT_ID")))
    end

    -- Public item tooltips may be described; inventory text can include a maker's name.
    -- Never parse localized text or calculate DPS from possibly restricted returns.
    function self:Tooltip(path, private, ...)
        local ok, data = Probe:Try(path, api(path), ...)
        if not ok then return end
        if secret(data) then say(path .. " <secret>"); return end
        if type(data) ~= "table" then say(path .. " " .. Probe.Show(data)); return end
        say(path .. " dataInstanceID=" .. Probe.Show(data.dataInstanceID))
        local lines = data.lines
        if secret(lines) then say("tooltip lines <secret>"); return end
        if type(lines) ~= "table" then say("tooltip lines " .. Probe.Shape(lines)); return end
        for i = 1, 40 do
            local line = lines[i]
            if secret(line) then
                say("tooltip line " .. i .. " <secret>")
            elseif line == nil then
                return
            elseif type(line) ~= "table" then
                say("tooltip line " .. i .. " " .. Probe.Shape(line))
            elseif private then
                say("inventory line " .. i .. " type=" .. Probe.Show(line.type)
                    .. " left=" .. Probe.Shape(line.leftText) .. " right=" .. Probe.Shape(line.rightText))
            else
                say("public line " .. i .. " " .. Probe.Describe(line, 4))
            end
        end
        say("tooltip truncated after 40 lines")
    end

    function self:Item(itemID)
        assert(plainID(itemID), "Item requires a plain positive item ID")
        say("ITEM " .. itemID)
        call("C_Item.IsItemDataCachedByID", itemID)
        call("C_Item.GetItemInfo", itemID)
        call("C_Item.GetItemInfoInstant", itemID)
        call("C_Item.GetItemStats", "item:" .. itemID)
        self:Tooltip("C_TooltipInfo.GetItemByID", false, itemID)
    end

    function self:Equipment(label)
        self:Context(label)
        call("GetInventorySlotInfo", "RangedSlot")
        call("GetInventorySlotInfo", "MainHandSlot")
        -- Measure both possible locations instead of assuming a Retail or Classic slot model.
        local states = {}
        for _, slot in ipairs({ 18, 16 }) do
            local ok, id = Probe:Try("GetInventoryItemID slot " .. slot, api("GetInventoryItemID"), "player", slot)
            local state
            if not ok then state = "unavailable"
            elseif secret(id) then state = "restricted"
            elseif id == nil then state = "empty"
            elseif plainID(id) then state = "item:" .. id
            else state = "unexpected:" .. Probe.Shape(id) end
            states[#states + 1] = slot .. "=" .. state
            say("EQUIPMENT slot " .. slot .. " " .. state)
            -- These returns are diagnostic only. Never reuse a restricted link as an API input.
            call("GetInventoryItemLink", "player", slot)
            self:Tooltip("C_TooltipInfo.GetInventoryItem", true, "player", slot)
            if ok and plainID(id) then self:Item(id) end
        end
        call("UnitRangedDamage", "player") -- may include character modifiers; not item base DPS
        return table.concat(states, ", ")
    end

    function self:Quests()
        for _, id in ipairs({ 99, 96393, 96391 }) do
            local path = "C_QuestLog.IsQuestFlaggedCompleted"
            local ok, complete = Probe:Try(path .. " " .. id, api(path), id)
            if ok then say("QUEST " .. id .. " characterCompleted=" .. Probe.Show(complete)) end
        end
        say("Quest completion is a character observation, not source eligibility or availability.")
    end

    function self:BeginWatch()
        self.watching, self.eventCount = true, 0
        say("Equipment/combat watch enabled; first 20 relevant events per watch.")
        return "watch enabled"
    end
    function self:StopWatch()
        self.watching = false
        say("Watch stopped. Load-request events remain tracked until their deadline.")
        return "watch stopped"
    end

    function self:LoadEvent(event, itemID, success)
        if secret(itemID) or secret(success) then
            say(event .. " id=" .. Probe.Show(itemID) .. " success=" .. Probe.Show(success)
                .. "; restricted payload, request remains unresolved")
            return
        end
        if not plainID(itemID) or not self.pending[itemID] then return end
        if type(success) ~= "boolean" then
            say(event .. " item " .. itemID .. " unexpected success=" .. Probe.Shape(success))
            return
        end
        self.pending[itemID] = nil
        say("LOAD " .. itemID .. " " .. event .. " success=" .. tostring(success))
        if success and itemID ~= INVALID_ID then self:Item(itemID) end
    end

    function self:RequestSamples()
        self:Context("item load requests")
        local after = api("C_Timer.After")
        if type(after) ~= "function" then
            say("C_Timer.After MISSING; no bounded load experiment can be started")
            return false, "timer missing"
        end
        if self.eventsAvailable == false then
            say("Load events could not be registered; timeouts will not prove item failure.")
        end
        self.generation = self.generation + 1
        local generation = self.generation
        self.pending = {}
        local ids = {}
        for _, id in ipairs(SAMPLE_IDS) do ids[#ids + 1] = id end
        ids[#ids + 1] = INVALID_ID
        for _, id in ipairs(ids) do self.pending[id] = true end
        -- Arm the deadline before requests; a missing/refused timer cannot leave stale requests.
        local scheduled = Probe:Try("C_Timer.After", after, 8, function()
            if self.generation ~= generation then return end
            for _, id in ipairs(ids) do
                if self.pending[id] then
                    self.pending[id] = nil
                    say("LOAD " .. id .. " timeout; not proof that item does not exist")
                    if id ~= INVALID_ID then self:Item(id) end
                end
            end
        end)
        if not scheduled then self.pending = {}; return false, "timer refused" end
        for _, id in ipairs(ids) do
            local ok, cached = Probe:Try("cache before " .. id, api("C_Item.IsItemDataCachedByID"), id)
            local state = "unknown"
            if ok and not secret(cached) and type(cached) == "boolean" then
                state = cached and "warm" or "cold"
            end
            say("REQUEST " .. id .. " cacheBefore=" .. state .. (id == INVALID_ID and " invalid-ID candidate" or ""))
            local sent = Probe:Try("RequestLoadItemDataByID " .. id, api("C_Item.RequestLoadItemDataByID"), id)
            if not sent then
                self.pending[id] = nil
                say("LOAD " .. id .. " request unavailable/refused")
            end
        end
        say("Requests dispatched; inspect events and the 8-second deadline before continuing.")
        return true, "requests dispatched, not a load-success claim"
    end

    function self:Event(event, ...)
        if event == "ITEM_DATA_LOAD_RESULT" or event == "GET_ITEM_INFO_RECEIVED" then
            self:LoadEvent(event, ...)
        elseif self.watching and self.eventCount < 20 then
            self.eventCount = self.eventCount + 1
            say("EVENT " .. event .. " " .. Probe.Describe(Probe.Pack(...), 1))
            self:Equipment(event)
            if self.eventCount == 20 then say("Watch event limit reached; start watch again to reset.") end
        end
    end

    function self:CombatState()
        local ok, value = Probe:Try("InCombatLockdown", api("InCombatLockdown"))
        if not ok then return "unavailable" end
        if secret(value) then return "restricted" end
        if value == true then return "combat" end
        if value == false then return "peace" end
        return "unexpected"
    end

    return self
end
