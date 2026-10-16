local _, ns = ...
ns.Equipped = ns.Equipment.New(_G, ns.WandData, function() if ns.Guide then ns.Guide:Refresh() end end)
-- A small addon API lets tools observe event-driven state without refreshing it.
-- Return only copied scalar fields; equipped links and internal tables stay private.
Wanderful = {
    apiVersion = 1,
    OpenGuide = function() ns.Guide:Open() end,
    GetGuideState = function() return ns.Guide:State() end,
    GetBaseline = function()
        local state = ns.Equipped.state
        return {
            mode = state.mode, status = state.status, provenance = state.provenance,
            itemID = state.itemID, variant = state.variant, reason = state.reason,
            level = state.level, levelStatus = state.levelStatus,
            dps = state.snapshot and ns.Comparison.DPS(state.snapshot).value,
        }
    end,
    UseAutomaticBaseline = function() ns.Equipped:Automatic() end,
    SelectManualBaseline = function(itemID, variant, historical)
        return ns.Equipped:Manual(itemID, variant or "base", historical)
    end,
}
-- Registration can differ by build; failed load-event registration disables requests.
if type(CreateFrame) == "function" then
    local ok, frame = pcall(CreateFrame, "Frame")
    if ok and frame then
        for _, event in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_EQUIPMENT_CHANGED",
            "PLAYER_LEVEL_UP", "PLAYER_REGEN_ENABLED", "ITEM_DATA_LOAD_RESULT", "GET_ITEM_INFO_RECEIVED" }) do
            local ok, registered = pcall(frame.RegisterEvent, frame, event)
            if (not ok or registered ~= true) and (event == "ITEM_DATA_LOAD_RESULT" or event == "GET_ITEM_INFO_RECEIVED") then
                ns.Equipped.loadsAvailable = false
            end
        end
        frame:SetScript("OnEvent", function(_, event, ...)
            if event == "ADDON_LOADED" then
                if (...) == ns.name then WanderfulDB = ns.Guide:Initialize(rawget(_G, "WanderfulDB")) end
            else
                ns.Equipped:Event(event, ...)
                if event == "ITEM_DATA_LOAD_RESULT" or event == "GET_ITEM_INFO_RECEIVED" then ns.Guide:Refresh() end
            end
        end)
    else ns.Equipped.loadsAvailable = false end
else ns.Equipped.loadsAvailable = false end
