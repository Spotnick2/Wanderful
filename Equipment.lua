local _, ns = ...
local Equipment = {}
ns.Equipment = Equipment

-- All client values cross this boundary before comparisons, formatting or storage.
function Equipment.New(env, data, changed)
    local self = { state = { mode = "automatic", status = "unknown", provenance = "none" }, loadsAvailable = true }
    local identityID, identityLink, generation, pending, attempted = nil, nil, 0, false, false
    local function api(path)
        local value = env
        for part in path:gmatch("[^.]+") do
            if type(value) ~= "table" then return nil end
            value = rawget(value, part)
        end
        return value
    end
    local function restricted(value)
        local fn = api("issecretvalue")
        if type(fn) ~= "function" then return true end
        local ok, result = pcall(fn, value)
        return not ok or type(result) ~= "boolean" or result
    end
    local function finite(value)
        return not restricted(value) and type(value) == "number"
            and value == value and value > -math.huge and value < math.huge
    end
    local function id(value) return finite(value) and value > 0 and value % 1 == 0 end
    local function call(path, ...)
        local fn = api(path)
        if type(fn) ~= "function" then return false end
        return pcall(fn, ...)
    end
    local function cancel()
        generation, pending, attempted = generation + 1, false, false
    end
    local function publish(state, levelHint)
        local ok, level = call("UnitLevel", "player")
        if finite(levelHint) and levelHint > 0 then ok, level = true, levelHint end
        if ok and finite(level) and level > 0 then state.level = level
        else state.levelStatus = ok and restricted(level) and "restricted" or "unknown" end
        self.state = state
        if changed then changed(state) end
    end
    local function base(status, reason)
        return { mode = "automatic", status = status, reason = reason, provenance = "none" }
    end
    local function build()
        local ok, _, value = call("GetBuildInfo")
        if ok and not restricted(value) and type(value) == "string" then return value end
    end

    -- Never map a full equipped link to a catalog base variant or use UnitRangedDamage.
    local function read()
        local ok, itemID = call("GetInventoryItemID", "player", 18)
        if not ok then return base("unavailable", "inventory_api") end
        if restricted(itemID) then return base("restricted", "item_id") end
        if itemID == nil then return base("empty", "no_wand") end
        if not id(itemID) then return base("unknown", "invalid_item_id") end
        local state = base("unknown", "missing_data")
        state.itemID = itemID
        local linkOK, link = call("GetInventoryItemLink", "player", 18)
        if not linkOK then state.status, state.reason = "unavailable", "inventory_link_api"; return state end
        if restricted(link) then state.status, state.reason = "restricted", "item_link"; return state end
        if link == nil then state.needsLoad = true; return state end
        if type(link) ~= "string" or link == "" then state.reason = "invalid_link"; return state end
        state.link = link
        local infoOK, infoID, _, _, _, _, classID, subclassID = call("C_Item.GetItemInfoInstant", link)
        if not infoOK then state.status, state.reason = "unavailable", "item_info_api"; return state end
        if restricted(infoID) or restricted(classID) or restricted(subclassID) then
            state.status, state.reason = "restricted", "item_type"; return state
        end
        if infoID == nil or classID == nil or subclassID == nil then state.needsLoad = true; return state end
        if not id(infoID) or infoID ~= itemID or not finite(classID) or not finite(subclassID) then
            state.reason = "invalid_item_type"; return state
        end
        -- Enum.ItemClass.Weapon = 2, Enum.ItemWeaponSubclass.Wand = 19.
        if classID ~= 2 or subclassID ~= 19 then state.status, state.reason = "not_wand", "item_type"; return state end
        local statsOK, stats = call("C_Item.GetItemStats", link)
        if not statsOK then state.status, state.reason = "unavailable", "item_stats_api"; return state end
        if restricted(stats) then state.status, state.reason = "restricted", "item_stats"; return state end
        if stats == nil then state.needsLoad = true; return state end
        if type(stats) ~= "table" then state.reason = "invalid_stats"; return state end
        local dps = stats.ITEM_MOD_DAMAGE_PER_SECOND_SHORT
        if restricted(dps) then state.status, state.reason = "restricted", "item_dps"; return state end
        if dps == nil then state.needsLoad = true; return state end
        if not finite(dps) or dps < 0 then state.reason = "invalid_dps"; return state end
        state.status, state.reason, state.provenance = "ready", nil, "live"
        state.snapshot = { stats = { dps = dps }, evidence = { game = "forever", method = "client", build = build() } }
        return state
    end

    function self:Refresh(levelHint)
        if self.state.mode == "manual" then
            publish({ mode = "manual", status = self.state.status, provenance = self.state.provenance,
                itemID = self.state.itemID, variant = self.state.variant, snapshot = self.state.snapshot }, levelHint)
            return
        end
        local state = read()
        if state.itemID ~= identityID or state.link ~= identityLink then
            cancel()
            identityID, identityLink = state.itemID, state.link
        end
        if not state.needsLoad then
            -- Invalidate any deadline once data is readable, empty, or restricted.
            if pending then generation, pending = generation + 1, false end
            publish(state, levelHint)
            return
        end
        state.needsLoad = nil
        if pending then state.status = "loading"; publish(state, levelHint); return end
        if attempted then state.status, state.reason = "unknown", "load_exhausted"; publish(state, levelHint); return end
        attempted = true
        if not self.loadsAvailable or type(api("C_Timer.After")) ~= "function"
            or type(api("C_Item.RequestLoadItemDataByID")) ~= "function" then
            state.status, state.reason = "unavailable", "bounded_loading_unavailable"; publish(state, levelHint); return
        end
        pending = true
        local token = generation
        state.status = "loading"
        publish(state, levelHint)
        -- Arm the deadline before requesting; reentrant events see the pending identity.
        local scheduled = call("C_Timer.After", 8, function()
            if generation ~= token or not pending or self.state.mode ~= "automatic" then return end
            pending = false
            self:Refresh() -- rereads current equipment and clears an unresolved baseline
        end)
        if not scheduled then
            pending = false
            state.status, state.reason = "unavailable", "timer_failed"; publish(state, levelHint); return
        end
        local sent = call("C_Item.RequestLoadItemDataByID", state.itemID)
        if not sent and generation == token and pending then
            generation, pending = generation + 1, false
            state.status, state.reason = "failed", "request_failed"; publish(state, levelHint)
        end
    end

    function self:Event(event, ...)
        if event == "ITEM_DATA_LOAD_RESULT" or event == "GET_ITEM_INFO_RECEIVED" then
            local itemID, success = ...
            if restricted(itemID) or restricted(success) then return end
            if not id(itemID) or type(success) ~= "boolean" then return end
            if self.state.mode ~= "automatic" or not pending or itemID ~= identityID then return end
            -- Events have no request generation. Even false/old events only trigger a reread;
            -- they cannot install their item or terminate a newer request for the same ID.
            self:Refresh()
        elseif event == "PLAYER_EQUIPMENT_CHANGED" then
            local slot = ...
            if not restricted(slot) and slot == 18 then self:Refresh() end
        elseif event == "PLAYER_LEVEL_UP" then
            self:Refresh((...))
        elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD"
            or event == "PLAYER_REGEN_ENABLED" then
            self:Refresh()
        end
    end

    function self:Automatic()
        cancel()
        identityID, identityLink = nil, nil
        self.state = base("unknown")
        self:Refresh()
    end

    function self:Manual(itemID, variant, historical)
        if type(itemID) ~= "number" or itemID ~= itemID or itemID <= 0 or itemID >= math.huge
            or itemID % 1 ~= 0 or type(variant) ~= "string" then return false end
        local chosen
        for _, item in ipairs(data.items) do
            if item.itemID == itemID and item.variant == variant then chosen = item; break end
        end
        local snapshot = chosen and (historical and chosen.classic or (not historical and chosen.forever))
        if not snapshot then return false end
        cancel()
        publish({ mode = "manual", itemID = itemID, variant = variant, snapshot = snapshot,
            provenance = historical and "historical" or "bundled",
            status = ns.Comparison.DPS(snapshot).value ~= nil and "ready" or "unknown" })
        return true
    end
    return self
end
