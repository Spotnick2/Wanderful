local _, ns = ...
ns.Equipped = ns.Equipment.New(_G, ns.WandData)
-- Registration can differ by build; failed load-event registration disables requests.
if type(CreateFrame) == "function" then
    local ok, frame = pcall(CreateFrame, "Frame")
    if ok and frame then
        for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_EQUIPMENT_CHANGED",
            "PLAYER_LEVEL_UP", "PLAYER_REGEN_ENABLED", "ITEM_DATA_LOAD_RESULT", "GET_ITEM_INFO_RECEIVED" }) do
            local ok, registered = pcall(frame.RegisterEvent, frame, event)
            if (not ok or registered ~= true) and (event == "ITEM_DATA_LOAD_RESULT" or event == "GET_ITEM_INFO_RECEIVED") then
                ns.Equipped.loadsAvailable = false
            end
        end
        frame:SetScript("OnEvent", function(_, event, ...) ns.Equipped:Event(event, ...) end)
    else ns.Equipped.loadsAvailable = false end
else ns.Equipped.loadsAvailable = false end
