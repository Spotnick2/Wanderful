local U = dofile("tests/ui_harness.lua")
local count = 0
local function test(name, fn)
    local ok, err = pcall(fn); assert(ok, name .. ": " .. tostring(err)); count = count + 1
end
test("slash toggles the actual window with one complete LibGlass instance", function()
    local w = U.New()
    assert(w.env.WanderfulDB.schemaVersion == 1 and not w.guide.window)
    w.env.SlashCmdList.WANDERFUL("")
    assert(w.guide.window:IsShown() and #w.guide.rows > 0)
    assert(w.guide.shell.reflect.header and w.guide.content:GetAlpha() == 1)
    local frame, glass = w.guide.window, w.guide.glass
    w.env.SlashCmdList.WANDERFUL(""); assert(not frame:IsShown())
    w.env.SlashCmdList.WANDERFUL(""); assert(w.guide.window == frame and w.guide.glass == glass)
end)
test("equipment events update rendered UI without refreshing through observation", function()
    local w = U.New(); w.guide:Open()
    assert(w.env.Wanderful.GetGuideState().renderedItemID == 100)
    w.itemID = nil; w.fire("PLAYER_EQUIPMENT_CHANGED", 18, false)
    assert(w.env.Wanderful.GetGuideState().renderedStatus == "empty")
    assert(w.guide.baseline:GetText():find("No wand equipped", 1, true))
    w.itemID, w.dps = 11287, 11.333333015442; w.fire("PLAYER_EQUIPMENT_CHANGED", 18, true)
    assert(w.env.Wanderful.GetGuideState().renderedItemID == 11287)
    w.dps = w.secret(); w.fire("PLAYER_EQUIPMENT_CHANGED", 18)
    assert(w.guide.baseline:GetText():find("restricted", 1, true))
end)
test("displayed gain and details use the shared model and manual controls", function()
    local w = U.New(); w.guide:Open()
    local row = w.guide.rows[1]
    assert(w.guide.pool[1].gain:GetText():find(w.ns.GuideModel.Gain(row.comparison), 1, true))
    assert(w.guide.detailText:GetText():find("not verified in game", 1, true))
    assert(not w.guide.autoButton:IsShown() and w.guide.baselineHint:IsShown())
    w.click(w.guide.manualButton)
    assert(w.guide.autoButton:IsShown() and w.guide.autoButton.label:GetText() == "Use equipped wand")
    assert(w.ns.Equipped.state.mode == "manual" and w.ns.Equipped.state.provenance == "bundled")
    assert(w.guide.baseline:GetText():find("Manual baseline", 1, true))
    w.click(w.guide.classicButton)
    assert(w.guide.baseline:GetText():find("Historical reference", 1, true))
    w.click(w.guide.autoButton)
    assert(w.guide.rendered.mode == "automatic" and not w.guide.autoButton:IsShown())
end)
test("empty results disable baseline controls and explain missing comparison", function()
    local w = U.New(); w.guide:Open()
    w.guide:SetFilter("school", "Holy")
    assert(#w.guide.rows == 0 and not w.guide.manualButton.enabled and not w.guide.classicButton.enabled)
    assert(w.guide.empty:GetText():find("No matching wands", 1, true))
    w.itemID = nil; w.fire("PLAYER_EQUIPMENT_CHANGED", 18)
    w.guide:SetFilter("upgradesOnly", true)
    assert(w.guide.empty:GetText():find("baseline is needed", 1, true))
end)
test("long content resizes, wraps and scrolls without losing model text", function()
    local w = U.New(); w.guide:Open()
    local item = w.guide.rows[1].item
    item.name = string.rep("A very long wand name ", 10)
    local source = w.ns.WandData.sources[item.sourceIDs[1]]
    source.notes = string.rep("Long acquisition note. ", 80)
    w.guide.window:SetSize(820, 560)
    assert(w.guide.pool[1].name:GetText() == item.name)
    assert(w.guide.listScroll.child:GetWidth() > 200)
    assert(w.guide.detailScroll.maximum > 0 and w.guide.detailScroll.slider:IsShown())
    w.guide.listScroll.scripts.OnMouseWheel(w.guide.listScroll, -1)
    assert(w.guide.listScroll.offset > 0)
end)
test("filters and geometry survive fresh runtime environments with loaded revision", function()
    local w = U.New(); w.guide:Open()
    w.guide:SetFilter("source", "vendor")
    w.guide:SetFilter("minLevel", 12)
    w.guide.window:SetSize(900, 600)
    w.guide.window:ClearAllPoints(); w.guide.window:SetPoint("CENTER", w.env.UIParent, "CENTER", 30, -20)
    w.guide:SaveWindow()
    local saved = w.env.WanderfulDB
    local signature = w.ns.GuideModel.Signature(saved)
    assert(saved.revision > 0 and w.guide.loadedRevision == 0)
    local fresh = U.New(saved); fresh.guide:Open()
    assert(fresh.guide:State().signature == signature and fresh.guide.loadedRevision == saved.revision)
    assert(fresh.ns.Equipped.state.mode == "automatic")
end)
test("settings reject malformed and unknown data without inventing a baseline", function()
    local w = U.New({ schemaVersion = 1, revision = math.huge,
        window = { width = -10, height = 0/0, x = math.huge },
        filters = { class = "garbage", faction = 99, school = "invalid", minLevel = -4 } })
    local p = w.guide.settings
    assert(p.revision == 0 and p.window.width == 640 and p.window.height == 680 and p.window.x == 0)
    assert(p.filters.class == "player" and p.filters.school == "all" and p.filters.minLevel == 1)
    local context = w.ns.GuideModel.Character({ issecretvalue = w.env.issecretvalue,
        UnitClass = function() return nil, nil, w.secret() end }, nil)
    assert(context.classID == nil)
    local filters = w.ns.GuideModel.Filters(w.ns.GuideModel.Settings(nil), context)
    assert(filters.minLevel == 1 and filters.maxLevel == 60)
end)
test("class/faction all option includes alternatives and profile-specific option filters them", function()
    local w = U.New(); w.guide:Open()
    w.guide:SetFilter("faction", "Horde")
    for _, row in ipairs(w.guide.rows) do
        for _, path in ipairs(row.eligibility.sources) do assert(path.source.faction ~= "Alliance") end
    end
    w.guide:SetFilter("faction", "all")
    local found = false
    for _, row in ipairs(w.guide.rows) do if row.item.itemID == 5208 then found = #row.eligibility.sources == 2 end end
    assert(found)
end)

test("browse cards respond to search and sorting while keeping the baseline and selection", function()
    local w = U.New(); w.guide:Open()
    assert(w.guide.columns == 2 and not w.guide.filtersPanel:IsShown())
    w.guide.window:SetSize(820, 560); assert(w.guide.columns == 1)
    w.guide.window:SetSize(1200, 760); assert(w.guide.columns == 2)
    local before = w.env.Wanderful.GetBaseline()
    w.click(w.guide.pool[2].icon)
    local key = w.guide.selectedKey
    w.guide:SetFilter("sort", "dps")
    assert(w.guide.selectedKey == key)
    for i = 2, #w.guide.rows do
        assert(w.guide.rows[i - 1].comparison.candidate.value >= w.guide.rows[i].comparison.candidate.value)
    end
    w.guide.search:SetText("Wailing Caverns")
    assert(#w.guide.rows == 1 and w.guide.rows[1].item.itemID == 5243)
    w.guide.search:SetText("%["); assert(#w.guide.rows == 0, "search is literal, not a Lua pattern")
    w.click(w.guide.resetButton); assert(#w.guide.rows > 1 and w.guide.search:GetText() == "")
    assert(w.env.Wanderful.GetBaseline().mode == before.mode and w.env.Wanderful.GetBaseline().itemID == before.itemID)
end)

test("native tooltip, modified chat link and cached icon metadata never substitute stats", function()
    local w = U.New(); w.guide:Open()
    local card = w.guide.pool[2]
    w.click(card)
    local key, baseline = w.guide.selectedKey, w.env.Wanderful.GetBaseline()
    card.scripts.OnEnter(card)
    assert(w.env.GameTooltip.link == "item:" .. card.row.item.itemID)
    assert(w.comparedTooltip == nil)
    w.guide:Refresh(); assert(w.ns.ItemPresentation.owner == card, "unchanged repaint must keep the hovered tooltip")
    w.shift = true; w.fire("MODIFIER_STATE_CHANGED", "LSHIFT", 1)
    assert(w.comparedTooltip == w.env.GameTooltip)
    w.click(w.guide.pool[1])
    assert(w.insertedLink == "item:" .. w.guide.pool[1].row.item.itemID)
    assert(w.guide.selectedKey == key and w.env.Wanderful.GetBaseline().itemID == baseline.itemID)
    w.shift = false; w.fire("MODIFIER_STATE_CHANGED", "LSHIFT", 0)
    w.secretIcon = w.secret()
    local value = w.guide.rows[1].comparison.candidate.value
    w.guide:Refresh()
    assert(w.guide.pool[1].icon.image.texture == "Interface\\Icons\\INV_Misc_QuestionMark")
    assert(w.guide.rows[1].comparison.candidate.value == value)
    w.guide.baselineIcon.scripts.OnEnter(w.guide.baselineIcon)
    assert(w.env.GameTooltip.link == "item:100")
end)

test("tracking persists separately and returns to a goal hidden by filters without resetting them", function()
    local w = U.New(); w.guide:Open()
    w.click(w.guide.pool[2])
    local item, baseline = w.guide.selected.item, w.env.Wanderful.GetBaseline()
    w.click(w.guide.trackButton)
    assert(w.env.WanderfulDB.goal.itemID == item.itemID and w.guide.goalButton:IsShown())
    w.guide:SetFilter("school", "Holy"); assert(#w.guide.rows == 0)
    w.click(w.guide.goalButton)
    assert(w.guide.selected.item == item and w.guide.settings.filters.school == "Holy")
    assert(w.env.Wanderful.GetBaseline().itemID == baseline.itemID)
    local fresh = U.New(w.env.WanderfulDB); fresh.guide:Open()
    assert(fresh.env.WanderfulDB.goal.itemID == item.itemID)
    fresh.guide:SelectGoal(); assert(fresh.guide.selected.item.itemID == item.itemID)
    fresh.guide:Track(); assert(fresh.env.WanderfulDB.goal == nil)
end)

test("source details keep equipment level and acquisition certainty separate", function()
    local w = U.New(); w.guide:Open()
    local row
    for _, entry in ipairs(w.guide.rows) do if entry.item.itemID == 11288 then row = entry end end
    local text = w.ns.GuideModel.Acquisition(w.ns.WandData, row, 12, false)
    assert(text:find("In 1 level", 1, true) and text:find("not verified in game", 1, true))
    assert(not text:find("Simple Wood", 1, true), "mockup ingredients are not verified catalog data")
    assert(not text:find("https://", 1, true), "audit URLs stay behind the evidence control")
    w.click(w.guide.evidenceButton)
    assert(w.guide.detailText:GetText():find("https://", 1, true))
    w.click(w.guide.filtersButton); assert(w.guide.filtersPanel:IsShown())
end)

test("gain sorting leaves unknown gains in stable catalog order", function()
    local w = U.New(); w.guide:Open()
    w.itemID = nil; w.fire("PLAYER_EQUIPMENT_CHANGED", 18)
    local first = w.guide.rows[1].item.itemID
    w.guide:SetFilter("sort", "gain")
    assert(w.guide.rows[1].item.itemID == first and w.guide.rows[1].comparison.delta == nil)
end)
test("menu choices draw above the advanced filter panel and its controls", function()
    local w = U.New(); w.guide:Open()
    w.click(w.guide.filtersButton)
    w.click(w.guide.filterButtons.class)
    local function under(frame, root)
        while frame do if frame == root then return true end; frame = frame.parent end
        return false
    end
    local panelTop, popupLow = 0, math.huge
    for _, frame in ipairs(w.frames) do
        if frame.level then
            if under(frame, w.guide.filtersPanel) then panelTop = math.max(panelTop, frame:GetFrameLevel()) end
            if under(frame, w.guide.popup) then popupLow = math.min(popupLow, frame:GetFrameLevel()) end
        end
    end
    assert(w.guide.popup:IsShown() and popupLow > panelTop, popupLow .. " <= " .. panelTop)
    w.click(w.guide.popup.buttons[1])
    assert(w.guide.settings.filters.class == "player" and not w.guide.popup:IsShown())
end)

test("live single-precision DPS equal to a catalog wand is not an upgrade", function()
    local w = U.New(); w.guide:Open()
    w.itemID, w.dps = 11287, 11.333333015442; w.fire("PLAYER_EQUIPMENT_CHANGED", 18)
    w.guide:SetFilter("minLevel", 1)
    local same
    for i, row in ipairs(w.guide.rows) do if row.item.itemID == 11287 then same = w.guide.pool[i] end end
    assert(same and same.row.comparison.relation == "equal" and same.row.comparison.delta > 0, "raw delta is kept")
    assert(same.gain:GetText() == "Same DPS as baseline")
    w.guide:SetFilter("upgradesOnly", true)
    for _, row in ipairs(w.guide.rows) do assert(row.item.itemID ~= 11287) end
end)

test("an unreadable character level is shown as unknown on cards and details", function()
    local w = U.New(); w.guide:Open()
    w.level = nil; w.fire("PLAYER_EQUIPMENT_CHANGED", 18)
    assert(w.ns.Equipped.state.level == nil and #w.guide.rows > 0)
    for i, row in ipairs(w.guide.rows) do
        local card = w.guide.pool[i].access:GetText()
        assert(not card:find("Level requirement met", 1, true), card)
        if row.item.forever.stats.equipLevel and row.eligibility.equip.status ~= "blocked" then
            assert(card:find("Your level is unknown", 1, true) and w.guide.pool[i].equip:GetText():find("Equip at level", 1, true))
        end
    end
    assert(w.guide.detailText:GetText():find("Your level is unknown", 1, true))
end)

test("item loads repaint only displayed items, once per frame", function()
    local w = U.New(); w.guide:Open()
    local refreshes, refresh = 0, w.guide.Refresh
    w.guide.Refresh = function(...) refreshes = refreshes + 1; return refresh(...) end
    w.fire("GET_ITEM_INFO_RECEIVED", 999999, true); w.fire("ITEM_DATA_LOAD_RESULT", w.secret(), true)
    w.tick(); assert(refreshes == 0, "unrelated or unreadable items do not repaint")
    local shown = w.guide.rows[1].item.itemID
    w.fire("GET_ITEM_INFO_RECEIVED", shown, true); w.fire("ITEM_DATA_LOAD_RESULT", shown, true)
    assert(refreshes == 0); w.tick(); assert(refreshes == 1, "a batch coalesces into one repaint")
    w.itemID, w.dps = 11287, nil; w.fire("PLAYER_EQUIPMENT_CHANGED", 18)
    assert(w.ns.Equipped.state.status == "loading"); refreshes = 0
    w.dps = 11.333333015442; w.fire("ITEM_DATA_LOAD_RESULT", 11287, true)
    assert(refreshes == 1 and w.ns.Equipped.state.status == "ready")
    w.tick(); assert(refreshes == 1, "the equipment repaint cancels the cosmetic one")
    w.guide.window:Hide(); w.fire("GET_ITEM_INFO_RECEIVED", shown, true); w.tick()
    assert(refreshes == 1)
end)

test("closing the guide leaves another window's tooltip alone", function()
    local w = U.New(); w.guide:Open()
    local other = w.env.CreateFrame("Frame", nil, w.env.UIParent)
    w.env.GameTooltip:SetOwner(other, "ANCHOR_RIGHT"); w.env.GameTooltip:Show()
    w.guide.window:Hide()
    assert(w.env.GameTooltip:IsShown() and w.env.GameTooltip:GetOwner() == other)
    w.guide:Open()
    local card = w.guide.pool[1]; card.scripts.OnEnter(card)
    w.guide.window:Hide()
    assert(not w.env.GameTooltip:IsShown() and w.ns.ItemPresentation.owner == nil)
end)
print("Guide UI: " .. count .. " tests passed.")