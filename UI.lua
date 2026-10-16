local _, ns = ...
local M = ns.GuideModel
local Guide = { rows = {}, pool = {} }
ns.Guide = Guide
local ACCENT = { 0.30, 0.83, 0.79 }
local OPTIONS = {
    sort = { { "level", "Sort: Equip level" }, { "dps", "Sort: Base DPS" }, { "gain", "Sort: DPS gain" } },
    class = { { "player", "My class" }, { "all", "All classes" }, { 8, "Mage" }, { 5, "Priest" }, { 9, "Warlock" } },
    faction = { { "player", "My faction" }, { "all", "Both factions" }, { "Alliance", "Alliance" }, { "Horde", "Horde" } },
    source = { { "all", "All sources" }, { "quest", "Quest" }, { "vendor", "Vendor" }, { "crafting", "Crafting" },
        { "dungeon", "Dungeon" }, { "world", "World drop" } },
    school = { { "all", "All schools" }, { "Arcane", "Arcane" }, { "Fire", "Fire" }, { "Frost", "Frost" },
        { "Shadow", "Shadow" }, { "Holy", "Holy" }, { "Nature", "Nature" }, { "Physical", "Physical" } },
}
function Guide:Initialize(saved)
    self.settings = M.Settings(saved)
    if self.settings.goal then
        local found = false
        for _, item in ipairs(ns.WandData.items) do
            if item.itemID == self.settings.goal.itemID and item.variant == self.settings.goal.variant then found = true; break end
        end
        if not found then self.settings.goal = nil end
    end
    self.loadedRevision = self.settings.revision
    self.ready = true
    return self.settings
end
function Guide:Touch() self.settings.revision = self.settings.revision % 2147483646 + 1 end
function Guide:SetFilter(key, value)
    local p = self.settings.filters
    if p[key] == value then return end
    local copy = {}; for k, v in pairs(p) do copy[k] = v end; copy[key] = value
    self.settings.filters = M.Settings({ schemaVersion = 1, filters = copy }).filters
    self:Touch()
    self:Refresh()
end
function Guide:SaveWindow()
    if not self.window then return end
    local w, parent = self.window, UIParent
    local x, y = w:GetCenter(); local px, py = parent:GetCenter()
    if not (M.Finite(x) and M.Finite(y) and M.Finite(px) and M.Finite(py)) then return end
    local function round(v) return math.floor(v + 0.5) end
    local values = { width = round(w:GetWidth()), height = round(w:GetHeight()), x = round(x - px), y = round(y - py) }
    local changed = false
    for key, value in pairs(values) do
        if self.settings.window[key] ~= value then self.settings.window[key], changed = value, true end
    end
    if changed then self:Touch() end
end
local function font(parent, size, color)
    local fs = Guide.glass.Font(parent, size, "LEFT")
    fs:SetTextColor(unpack(color or { 0.91, 0.93, 0.96 }))
    fs:SetWordWrap(true)
    return fs
end
local function surface(host, shell)
    local G = Guide.glass
    local g = G.Apply(host, shell and "large" or "small")
    if shell then
        G.SetSurfaceTint(g, 0.085, 0.095, 0.115, 0.78); G.SetWash(g, 0); G.SetEdge(g, 0, 0, 0)
        G.SetSurfaceAlpha(g, "rim", 0.12); G.SetSurfaceAlpha(g, "dark", 0.55)
        G.SetSurfaceAlpha(g, "grain", 0); G.SetSurfaceAlpha(g, "shadow", 0.18)
        local backing = host:CreateTexture(nil, "BACKGROUND", nil, -7)
        backing:SetAllPoints(host); backing:AddMaskTexture(g.mask); backing:SetColorTexture(0.03, 0.03, 0.035, 0.55)
        G.Reflect(g, host, { header = 85 })
    else
        G.SetSurfaceTint(g, 0.095, 0.11, 0.135, 0.90); G.SetWash(g, 0.025)
        G.SetEdge(g, 0.10, 0.015, 0.12, 3); G.SetSurfaceAlpha(g, "rim", 0.22)
        G.SetSurfaceAlpha(g, "dark", 0.35); G.SetSurfaceAlpha(g, "grain", 0); G.SetSurfaceAlpha(g, "shadow", 0.05)
    end
    return g
end
local function button(parent, text, width, clicked)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width, 27)
    b.surface = surface(b, false)
    b.label = font(b.surface.top, 12)
    b.label:SetPoint("LEFT", 9, 0); b.label:SetPoint("RIGHT", -9, 0); b.label:SetHeight(23)
    b.label:SetText(text)
    b:SetScript("OnClick", clicked)
    b:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
    b:GetHighlightTexture():SetAlpha(0.06)
    return b
end
local function pane(parent)
    local p = CreateFrame("Frame", nil, parent)
    local tex = p:CreateTexture(nil, "BACKGROUND", nil, -7)
    tex:SetAllPoints(p); tex:SetColorTexture(0.072, 0.082, 0.10, 0.94)
    local S = Guide.glass.SIZES.thin_small
    tex:AddMaskTexture(Guide.glass.Mask(p, S.mask, S.maskMargin, 0, tex))
    return p
end
local function scroll(parent)
    local s = CreateFrame("ScrollFrame", nil, parent)
    local child = CreateFrame("Frame", nil, s); child:SetSize(1, 1); s:SetScrollChild(child)
    local slider = CreateFrame("Slider", nil, parent)
    slider:SetWidth(10); slider:SetPoint("TOPRIGHT", s, "TOPRIGHT", 11, 0); slider:SetPoint("BOTTOMRIGHT", s, "BOTTOMRIGHT", 11, 0)
    slider:SetOrientation("VERTICAL"); slider:SetMinMaxValues(0, 1); slider:SetValueStep(1)
    slider:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
    slider:GetThumbTexture():SetSize(6, 28); slider:GetThumbTexture():SetVertexColor(unpack(ACCENT))
    slider:SetScript("OnValueChanged", function(_, value) s:SetVerticalScroll(value) end)
    s:EnableMouseWheel(true)
    s:SetScript("OnMouseWheel", function(_, delta)
        slider:SetValue(math.max(0, math.min(s.maximum or 0, slider:GetValue() - delta * 80)))
    end)
    s.child, s.slider = child, slider
    return s
end
local function clampScroll(s)
    s.maximum = math.max(0, s.child:GetHeight() - s:GetHeight())
    s.slider:SetMinMaxValues(0, math.max(1, s.maximum))
    s.slider:SetValue(math.min(s.maximum, math.max(0, s.slider:GetValue() or 0)))
    s.slider:SetShown(s.maximum > 0)
end
function Guide:Choose(key, owner)
    if not self.popup then
        self.popup = CreateFrame("Frame", nil, self.content)
        self.popup:SetFrameStrata("DIALOG"); self.popup:SetWidth(184)
        self.popup.surface = surface(self.popup, false)
        self.popup.buttons = {}
    end
    local popup = self.popup
    popup:ClearAllPoints(); popup:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -3)
    popup:SetHeight(#OPTIONS[key] * 27 + 12)
    for _, b in ipairs(popup.buttons) do b:Hide() end
    for i, option in ipairs(OPTIONS[key]) do
        local b = popup.buttons[i]
        if not b then b = button(popup.surface.top, "", 172, function() end); popup.buttons[i] = b end
        b:ClearAllPoints(); b:SetPoint("TOPLEFT", 6, -6 - (i - 1) * 27)
        b.label:SetText((self.settings.filters[key] == option[1] and "* " or "") .. option[2])
        local value = option[1]
        b:SetScript("OnClick", function() popup:Hide(); self:SetFilter(key, value) end)
        b:Show()
    end
    popup:Show()
end
function Guide:SelectGoal()
    local goal = self.settings.goal
    if not goal then return end
    self.selectedKey = goal.itemID .. ":" .. goal.variant
    self.pinnedSelection = self.selectedKey
    self.detailScroll.slider:SetValue(0)
    self:Refresh()
end
function Guide:Track()
    if not self.selected then return end
    local item, goal = self.selected.item, self.settings.goal
    self.settings.goal = not (goal and goal.itemID == item.itemID and goal.variant == item.variant)
        and { itemID = item.itemID, variant = item.variant } or nil
    self:Touch(); self:Refresh()
end
local function icon(parent, size)
    local b = CreateFrame("Button", nil, parent); b:SetSize(size, size)
    b.image = b:CreateTexture(nil, "ARTWORK"); b.image:SetPoint("TOPLEFT", 2, -2); b.image:SetPoint("BOTTOMRIGHT", -2, 2)
    b.outline = b:CreateTexture(nil, "BACKGROUND"); b.outline:SetAllPoints(b)
    b:SetScript("OnEnter", function() ns.ItemPresentation.Tooltip(b, b.itemID) end)
    b:SetScript("OnLeave", ns.ItemPresentation.HideTooltip)
    b:SetScript("OnClick", function() ns.ItemPresentation.Link(b.itemID) end)
    return b
end
local function paintIcon(b, itemID)
    local info = ns.ItemPresentation.Metadata(itemID)
    b.itemID = itemID; b.image:SetTexture(info.icon); b.outline:SetColorTexture(unpack(info.color))
    return info
end
function Guide:Ensure()
    if self.window then return true end
    if not self.ready or not rawget(_G, "UIParent") then return false end
    local lib, minor = LibStub("LibGlass-1.0")
    assert(minor >= 9 and lib.ready == minor, "Wanderful requires a complete LibGlass r9 or newer.")
    self.glass = lib:New({ preset = "clean" })
    local w = CreateFrame("Frame", "WanderfulGuide", UIParent)
    self.window = w
    w:Hide(); w:SetFrameStrata("DIALOG"); w:SetClampedToScreen(true)
    w:SetMovable(true); w:EnableMouse(true); w:SetResizable(true)
    local pw, ph = UIParent:GetWidth(), UIParent:GetHeight()
    w:SetResizeBounds(math.min(820, pw - 32), math.min(560, ph - 32), math.min(1600, pw - 20), math.min(1100, ph - 20))
    w:SetSize(math.min(self.settings.window.width, pw - 32), math.min(self.settings.window.height, ph - 32))
    w:SetPoint("CENTER", UIParent, "CENTER", self.settings.window.x, self.settings.window.y)
    self.shell = surface(w, true)
    local content = CreateFrame("Frame", nil, w); content:SetAllPoints(w)
    content:SetFrameLevel(self.glass.ContentLevel(w)); self.content = content
    local logo = icon(content, 32); logo:SetPoint("TOPLEFT", 18, -13); paintIcon(logo, 11287)
    local title = font(self.shell.top, 25, ACCENT); title:SetPoint("TOPLEFT", 62, -15); title:SetText("Wanderful")
    local subtitle = font(self.shell.top, 12, { 0.67, 0.78, 0.83 })
    subtitle:SetPoint("TOPLEFT", 226, -25); subtitle:SetText("Your next wand, and the path ahead.")
    local drag = CreateFrame("Frame", nil, content)
    drag:SetPoint("TOPLEFT", 55, 0); drag:SetPoint("TOPRIGHT", -85, 0); drag:SetHeight(48)
    drag:EnableMouse(true); drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function() w:StartMoving() end)
    drag:SetScript("OnDragStop", function() w:StopMovingOrSizing(); self:SaveWindow() end)
    local close = button(content, "Close", 58, function() w:Hide() end); close:SetPoint("TOPRIGHT", -15, -14)
    self.header = pane(content); self.header:SetPoint("TOPLEFT", 18, -58); self.header:SetPoint("TOPRIGHT", -18, -58); self.header:SetHeight(64)
    self.character = font(self.header, 15); self.character:SetPoint("TOPLEFT", 14, -12); self.character:SetWidth(205); self.character:SetHeight(42)
    self.baselineIcon = icon(self.header, 36); self.baselineIcon:SetPoint("TOPLEFT", 232, -14)
    self.baseline = font(self.header, 15); self.baseline:SetPoint("TOPLEFT", 280, -10); self.baseline:SetHeight(46)
    self.autoButton = button(self.header, "Use equipped wand", 140, function() ns.Equipped:Automatic() end)
    self.autoButton:SetPoint("TOPRIGHT", -12, -18)
    self.baseline:SetPoint("TOPRIGHT", self.autoButton, "TOPLEFT", -12, 8)

    self.browseTitle = font(content, 18, ACCENT); self.browseTitle:SetPoint("TOPLEFT", 18, -140); self.browseTitle:SetText("Browse Wands")
    self.filtersButton = button(content, "Filters", 82, function()
        self.filtersPanel:SetShown(not self.filtersPanel:IsShown())
        if self.popup then self.popup:Hide() end
    end); self.filtersButton:SetPoint("TOPRIGHT", -18, -134)
    self.filterButtons = {}
    self.filterButtons.source = button(content, "", 148, function(owner) self:Choose("source", owner) end)
    self.filterButtons.source:SetPoint("TOPRIGHT", self.filtersButton, "TOPLEFT", -12, 0)
    self.search = CreateFrame("EditBox", nil, content); self.search:SetAutoFocus(false); self.search:SetHeight(27)
    self.search:SetPoint("TOPLEFT", 210, -134); self.search:SetPoint("TOPRIGHT", self.filterButtons.source, "TOPLEFT", -12, 0)
    self.search:SetFontObject("GameFontHighlight"); self.search:SetMaxLetters(80); self.search:SetTextInsets(10, 10, 0, 0); surface(self.search, false)
    self.searchHint = font(content, 12, { 0.60, 0.70, 0.75 }); self.searchHint:SetPoint("LEFT", self.search, "LEFT", 10, 0); self.searchHint:SetText("Find a wand or source...")
    self.search:SetScript("OnTextChanged", function(box)
        self.searchHint:SetShown(box:GetText() == "")
        self:SetFilter("search", box:GetText())
    end)
    self.search:SetScript("OnEnterPressed", function(box) box:ClearFocus() end)
    self.search:SetScript("OnEscapePressed", function(box) box:SetText(""); box:ClearFocus() end)

    local panel = pane(content); self.filtersPanel = panel
    panel:SetFrameLevel(content:GetFrameLevel() + 30); panel:SetFrameStrata("DIALOG")
    panel:SetWidth(math.min(660, w:GetWidth() - 36)); panel:SetHeight(156)
    panel:SetPoint("TOPRIGHT", self.filtersButton, "BOTTOMRIGHT", 0, -6); panel:EnableMouse(true); panel:Hide()
    local function levelBox(label, x, key)
        local fs = font(panel, 12); fs:SetPoint("TOPLEFT", x, -18); fs:SetText(label)
        local box = CreateFrame("EditBox", nil, panel)
        box:SetSize(47, 27); box:SetPoint("TOPLEFT", x + 38, -12); box:SetAutoFocus(false)
        box:SetFontObject("GameFontHighlight"); box:SetNumeric(true); box:SetMaxLetters(3)
        box:SetTextInsets(7, 5, 0, 0); surface(box, false)
        box:SetScript("OnEnterPressed", function() self:SetFilter(key, tonumber(box:GetText())); box:ClearFocus(); self:Refresh() end)
        box:SetScript("OnEscapePressed", function() box:ClearFocus(); self:Refresh() end)
        return box
    end
    self.minBox, self.maxBox = levelBox("From", 14, "minLevel"), levelBox("To", 116, "maxLevel")
    local range = button(panel, "Follow my level", 124, function()
        self.settings.filters.minLevel, self.settings.filters.maxLevel = nil, nil; self:Touch(); self:Refresh()
    end); range:SetPoint("TOPLEFT", 222, -12)
    self.resetButton = button(panel, "Reset filters", 112, function()
        self.settings.filters = M.Settings(nil).filters; self:Touch(); self:Refresh()
    end); self.resetButton:SetPoint("TOPLEFT", 358, -12)
    local x = 14
    for _, spec in ipairs({ { "class", 180 }, { "faction", 180 }, { "school", 160 } }) do
        local key = spec[1]
        local b = button(panel, "", spec[2], function(owner) self:Choose(key, owner) end)
        b:SetPoint("TOPLEFT", x, -57); x = x + spec[2] + 12; self.filterButtons[key] = b
    end
    local comparison = font(panel, 11, { 0.65, 0.73, 0.80 })
    comparison:SetPoint("TOPLEFT", 14, -116); comparison:SetText("Optional historical comparison:")
    self.classicButton = button(panel, "Use Classic reference", 164, function()
        if self.selected then ns.Equipped:Manual(self.selected.item.itemID, self.selected.item.variant, true) end
    end); self.classicButton:SetPoint("TOPLEFT", 224, -106)

    self.listPane, self.detailPane = pane(content), pane(content)
    self.listCaption = font(self.listPane, 16); self.listCaption:SetHeight(27)
    self.upgrades = button(self.listPane, "", 134, function() self:SetFilter("upgradesOnly", not self.settings.filters.upgradesOnly) end)
    self.filterButtons.sort = button(self.listPane, "", 134, function(owner) self:Choose("sort", owner) end)
    self.detailCaption = font(self.detailPane, 13, ACCENT); self.detailCaption:SetPoint("TOPLEFT", 14, -14); self.detailCaption:SetText("HOW TO GET IT")
    self.listScroll, self.detailScroll = scroll(self.listPane), scroll(self.detailPane)
    self.empty = font(self.listPane, 14, { 0.76, 0.80, 0.85 }); self.empty:SetPoint("TOPLEFT", 16, -105); self.empty:SetPoint("RIGHT", -16, 0)
    self.detailIcon = icon(self.detailScroll.child, 48); self.detailIcon:SetPoint("TOPLEFT", 0, 0)
    self.detailTitle = font(self.detailScroll.child, 19); self.detailTitle:SetPoint("TOPLEFT", 60, 0); self.detailTitle:SetHeight(48)
    self.detailStats = font(self.detailScroll.child, 16); self.detailStats:SetPoint("TOPLEFT", 0, -62); self.detailStats:SetHeight(50)
    self.detailText = font(self.detailScroll.child, 14); self.detailText:SetPoint("TOPLEFT", 0, -124)
    self.trackButton = button(self.detailPane, "Track this wand", 200, function() self:Track() end)
    self.manualButton = button(self.detailPane, "Compare from this wand", 200, function()
        if self.selected then ns.Equipped:Manual(self.selected.item.itemID, self.selected.item.variant, false) end
    end)
    self.evidenceButton = button(self.detailPane, "Evidence and requirements", 200, function()
        self.evidenceExpanded = not self.evidenceExpanded; self:Refresh()
    end)
    self.goalButton = button(content, "Tracked goal", 210, function() self:SelectGoal() end)
    self.goalButton:SetPoint("BOTTOMRIGHT", -86, 8); self.goalButton:Hide()
    self.footer = font(content, 10, { 0.68, 0.76, 0.81 }); self.footer:SetPoint("BOTTOMLEFT", 18, 11); self.footer:SetHeight(24)
    self.footer:SetText("Hover: item tooltip  |  Shift-click: link in chat\nGains compare base wand DPS. Sample catalog.")
    local resize = button(content, "Resize", 55, function() end); resize:SetPoint("BOTTOMRIGHT", -10, 8)
    resize:SetScript("OnMouseDown", function() w:StartSizing("BOTTOMRIGHT") end)
    resize:SetScript("OnMouseUp", function() w:StopMovingOrSizing(); self:SaveWindow() end)
    w:SetScript("OnSizeChanged", function() self:Layout(); self:Refresh() end)
    w:SetScript("OnShow", function() self:Layout(); self:Refresh() end)
    w:SetScript("OnHide", function()
        w:StopMovingOrSizing(); self:SaveWindow(); self.filtersPanel:Hide()
        if self.popup then self.popup:Hide() end
        ns.ItemPresentation.HideTooltip()
    end)
    w:SetScript("OnMouseDown", function() self.filtersPanel:Hide(); if self.popup then self.popup:Hide() end end)
    if type(UISpecialFrames) == "table" then UISpecialFrames[#UISpecialFrames + 1] = "WanderfulGuide" end
    w:RegisterEvent("MODIFIER_STATE_CHANGED")
    w:SetScript("OnEvent", ns.ItemPresentation.ModifiersChanged)
    self:Layout()
    return true
end
function Guide:Layout()
    if not self.window then return end
    local width = self.window:GetWidth()
    local rightWidth = math.max(285, math.min(370, width * 0.33))
    self.listPane:ClearAllPoints(); self.detailPane:ClearAllPoints()
    self.listPane:SetPoint("TOPLEFT", self.content, "TOPLEFT", 18, -176)
    self.listPane:SetPoint("BOTTOMRIGHT", self.content, "BOTTOMRIGHT", -rightWidth - 30, 42)
    self.detailPane:SetPoint("TOPRIGHT", self.content, "TOPRIGHT", -18, -176)
    self.detailPane:SetPoint("BOTTOMRIGHT", self.content, "BOTTOMRIGHT", -18, 42); self.detailPane:SetWidth(rightWidth)
    local narrow = self.listPane:GetWidth() < 620
    self.listCaption:ClearAllPoints(); self.listCaption:SetPoint("TOPLEFT", 14, -12)
    self.listCaption:SetWidth(math.max(1, self.listPane:GetWidth() - (narrow and 28 or 310)))
    self.upgrades:ClearAllPoints(); self.filterButtons.sort:ClearAllPoints()
    self.filterButtons.sort:SetPoint("TOPRIGHT", -14, narrow and -43 or -12)
    if narrow then self.upgrades:SetPoint("TOPLEFT", 14, -43)
    else self.upgrades:SetPoint("RIGHT", self.filterButtons.sort, "LEFT", -10, 0) end
    for _, spec in ipairs({ { self.listScroll, self.listPane, 14, narrow and 84 or 50 },
        { self.detailScroll, self.detailPane, 124, 46 } }) do
        local s, parent, bottom, top = unpack(spec)
        s:ClearAllPoints(); s:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, -top)
        s:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -24, bottom)
        s.child:SetWidth(math.max(1, parent:GetWidth() - 38))
    end
    local dw = math.max(1, rightWidth - 38)
    self.detailTitle:SetWidth(dw - 60); self.detailStats:SetWidth(dw); self.detailText:SetWidth(dw)
    for i, b in ipairs({ self.trackButton, self.manualButton, self.evidenceButton }) do
        b:ClearAllPoints(); b:SetPoint("BOTTOMLEFT", 14, 86 - (i - 1) * 35); b:SetWidth(rightWidth - 28)
    end
    self.filtersPanel:SetWidth(math.min(660, width - 36))
    self.footer:SetWidth(math.max(1, width - (self.settings.goal and 326 or 100)))
end
function Guide:Row(index)
    if self.pool[index] then return self.pool[index] end
    local b = CreateFrame("Button", nil, self.listScroll.child); b:SetHeight(190)
    b.surface = surface(b, false)
    self.glass.SetSurfaceTint(b.surface, 0.045, 0.063, 0.080, 0.92)
    self.glass.SetWash(b.surface, 0); self.glass.SetEdge(b.surface, 0, 0, 0)
    self.glass.SetSurfaceAlpha(b.surface, "shadow", 0)
    b.icon = icon(b.surface.top, 52); b.icon:SetPoint("TOPLEFT", 14, -14)
    b.name = font(b.surface.top, 17); b.name:SetPoint("TOPLEFT", 79, -12); b.name:SetHeight(42)
    b.equip = font(b.surface.top, 12, { 0.72, 0.81, 0.87 }); b.equip:SetPoint("TOPLEFT", 79, -57); b.equip:SetHeight(18)
    b.stats = font(b.surface.top, 18); b.stats:SetPoint("TOPLEFT", 14, -83); b.stats:SetHeight(24)
    b.gain = font(b.surface.top, 15); b.gain:SetPoint("TOPLEFT", 14, -111); b.gain:SetHeight(21)
    b.access = font(b.surface.top, 12, { 0.83, 0.73, 0.49 }); b.access:SetPoint("TOPLEFT", 14, -135); b.access:SetHeight(17)
    b.source = font(b.surface.top, 12, { 0.70, 0.79, 0.85 }); b.source:SetPoint("TOPLEFT", 14, -155); b.source:SetHeight(29)
    b:SetHighlightTexture("Interface\\Buttons\\WHITE8X8"); b:GetHighlightTexture():SetAlpha(0.035)
    b:SetScript("OnClick", function()
        if ns.ItemPresentation.Link(b.row.item.itemID) then return end
        self.filtersPanel:Hide(); if self.popup then self.popup:Hide() end
        self.detailScroll.slider:SetValue(0); self.evidenceExpanded = false; self.pinnedSelection = nil
        self.selectedKey = b.row.item.itemID .. ":" .. b.row.item.variant; self:Refresh()
    end)
    b.icon:SetScript("OnClick", function() b:GetScript("OnClick")(b) end)
    b:SetScript("OnEnter", function() ns.ItemPresentation.Tooltip(b, b.row.item.itemID) end)
    b:SetScript("OnLeave", ns.ItemPresentation.HideTooltip)
    self.pool[index] = b
    return b
end
function Guide:Refresh()
    if not self.window or not self.window:IsShown() or not self.ready then return end
    local state = ns.Equipped.state
    local context = M.Character(_G, state.level)
    local filters = M.Filters(self.settings, context)
    if self.settings.filters.class == "all" then context.classID = nil end
    if self.settings.filters.faction == "all" then context.faction = nil end
    self.rows = M.Browse(ns.Comparison.List(ns.WandData, state.snapshot, context, filters), self.settings.filters)
    local character = M.Character(_G, state.level)
    self.character:SetText((state.level and ("Level " .. state.level) or "Level unknown") .. " "
        .. (character.className or "Caster") .. "\n" .. (character.faction or "Faction unknown"))
    local info = paintIcon(self.baselineIcon, state.itemID)
    local baseline = M.Baseline(ns.WandData, state)
    if state.mode == "automatic" and info.name then
        baseline = baseline:gsub("Item " .. state.itemID, function() return info.name end)
    end
    self.baseline:SetText(baseline)
    self.autoButton.label:SetText(state.mode == "manual" and "Reset to equipped" or "Equipped baseline")
    self.rendered = { itemID = state.itemID, mode = state.mode, status = state.status, provenance = state.provenance }
    if not self.minBox:HasFocus() then self.minBox:SetText(tostring(filters.minLevel)) end
    if not self.maxBox:HasFocus() then self.maxBox:SetText(tostring(filters.maxLevel)) end
    if self.search:GetText() ~= self.settings.filters.search then self.search:SetText(self.settings.filters.search) end
    self.searchHint:SetShown(self.settings.filters.search == "")
    self.upgrades.label:SetText(self.settings.filters.upgradesOnly and "[x] Upgrades only" or "[ ] Upgrades only")
    for key, b in pairs(self.filterButtons) do
        for _, option in ipairs(OPTIONS[key]) do
            if option[1] == self.settings.filters[key] then b.label:SetText(option[2] .. "  v") end
        end
    end
    local active = self.settings.filters.school ~= "all" or self.settings.filters.class ~= "player"
        or self.settings.filters.faction ~= "player" or self.settings.filters.minLevel or self.settings.filters.maxLevel
    self.filtersButton.label:SetText(active and "Filters *" or "Filters")
    self.listCaption:SetText("Wands for your next levels  (" .. #self.rows .. ")")
    self.selected = nil
    for _, row in ipairs(self.rows) do
        if row.item.itemID .. ":" .. row.item.variant == self.selectedKey then self.selected = row; break end
    end
    if not self.selected and self.pinnedSelection == self.selectedKey then
        for _, item in ipairs(ns.WandData.items) do
            if item.itemID .. ":" .. item.variant == self.selectedKey then
                self.selected = { item = item, comparison = ns.Comparison.Compare(item.forever, state.snapshot),
                    eligibility = ns.Comparison.Assess(ns.WandData, item, context, {}) }
                break
            end
        end
    end
    self.selected = self.selected or self.rows[1]
    self.selectedKey = self.selected and (self.selected.item.itemID .. ":" .. self.selected.item.variant) or nil
    local area = self.listScroll.child:GetWidth()
    self.columns = area >= 570 and 2 or 1
    local cardWidth = (area - (self.columns - 1) * 12) / self.columns
    for i, b in ipairs(self.pool) do if i > #self.rows then b:Hide() end end
    for i, row in ipairs(self.rows) do
        local b = self:Row(i); b.row, b.itemID = row, row.item.itemID
        b:ClearAllPoints(); b:SetPoint("TOPLEFT", ((i - 1) % self.columns) * (cardWidth + 12), -math.floor((i - 1) / self.columns) * 202)
        b:SetWidth(cardWidth)
        local stats, meta = row.item.forever.stats, paintIcon(b.icon, row.item.itemID)
        b.name:SetWidth(math.max(1, cardWidth - 93)); b.equip:SetWidth(math.max(1, cardWidth - 93))
        for _, field in ipairs({ "stats", "gain", "access", "source" }) do b[field]:SetWidth(math.max(1, cardWidth - 28)) end
        b.name:SetText(row.item.name); b.name:SetTextColor(unpack(meta.color))
        local equip, badge = M.EquipLabel(row, state.level)
        b.equip:SetText(equip)
        b.stats:SetText((row.comparison.candidate.value and string.format("%.2f DPS", row.comparison.candidate.value) or "DPS unknown")
            .. "  -  " .. (stats.school or "School unknown"))
        b.gain:SetText(M.Gain(row.comparison)); b.gain:SetTextColor(unpack(row.comparison.relation == "upgrade"
            and { 0.34, 0.91, 0.48 } or { 0.74, 0.81, 0.86 }))
        local goal = self.settings.goal
        local tracked = goal and goal.itemID == row.item.itemID and goal.variant == row.item.variant
        b.access:SetText(badge .. (tracked and " - Tracked" or ""))
        b.source:SetText(M.SourceSummary(row))
        self.glass.SetSurfaceRim(b.surface, unpack(row == self.selected
            and { 0.24, 0.73, 0.75, 0.65 } or { 0.36, 0.47, 0.55, 0.22 }))
        b:Show()
    end
    self.listScroll.child:SetHeight(math.max(1, math.ceil(#self.rows / self.columns) * 202))
    self.empty:SetShown(#self.rows == 0)
    self.empty:SetText(state.snapshot == nil and filters.upgradesOnly
        and "A baseline is needed for upgrade comparisons. Turn off Upgrades only to browse, or choose a wand to compare from."
        or "No matching wands. Clear search or open Filters to widen the range or reset your choices.")
    local chosen = self.selected
    self.detailTitle:SetText(chosen and chosen.item.name or "Choose a wand")
    local meta = paintIcon(self.detailIcon, chosen and chosen.item.itemID)
    self.detailIcon:SetShown(chosen ~= nil); self.detailTitle:SetTextColor(unpack(meta.color))
    self.detailStats:SetText(chosen and ((chosen.comparison.candidate.value and string.format("%.2f DPS", chosen.comparison.candidate.value) or "DPS unknown")
        .. " - " .. (chosen.item.forever.stats.school or "School unknown") .. "\n" .. M.Gain(chosen.comparison)) or "")
    self.detailText:SetText(M.Acquisition(ns.WandData, chosen, state.level, self.evidenceExpanded))
    self.detailText:SetHeight(self.detailText:GetStringHeight() + 6)
    self.detailScroll.child:SetHeight(130 + self.detailText:GetStringHeight())
    local goal = self.settings.goal
    self.trackButton.label:SetText(chosen and goal and goal.itemID == chosen.item.itemID and goal.variant == chosen.item.variant
        and "Stop tracking this wand" or "Track this wand")
    self.evidenceButton.label:SetText(self.evidenceExpanded and "Hide evidence and requirements" or "Evidence and requirements")
    for _, b in ipairs({ self.manualButton, self.trackButton, self.evidenceButton, self.classicButton }) do
        local enabled = chosen ~= nil and (b ~= self.classicButton or chosen.item.classic ~= nil)
        self.glass.SetSurfaceEnabled(b.surface, enabled); if enabled then b:Enable() else b:Disable() end
    end
    self.goalButton:SetShown(goal ~= nil)
    if goal then self.goalButton.label:SetText("Goal: " .. M.Name(ns.WandData, goal.itemID, goal.variant)) end
    self.footer:SetWidth(math.max(1, self.window:GetWidth() - (goal and 326 or 100)))
    clampScroll(self.listScroll); clampScroll(self.detailScroll)
    ns.ItemPresentation.ValidateOwner()
end
function Guide:Toggle()
    if not self:Ensure() then return end
    self.window:SetShown(not self.window:IsShown())
end
function Guide:Open() if self:Ensure() then self.window:Show(); self:Refresh() end end
function Guide:State()
    local s = { ready = self.ready == true, shown = self.window ~= nil and self.window:IsShown(),
        loadedRevision = self.loadedRevision, revision = self.settings and self.settings.revision,
        signature = self.settings and M.Signature(self.settings), rows = #self.rows,
        selectedKey = self.selectedKey, trackedItemID = self.settings and self.settings.goal and self.settings.goal.itemID }
    if self.rendered then
        s.renderedItemID, s.renderedMode, s.renderedStatus = self.rendered.itemID, self.rendered.mode, self.rendered.status
    end
    return s
end
