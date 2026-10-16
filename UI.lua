local _, ns = ...
local M = ns.GuideModel
local Guide = { rows = {}, pool = {} }
ns.Guide = Guide
local ACCENT = { 0.30, 0.83, 0.79 }
local OPTIONS = {
    class = { { "player", "My class" }, { "all", "All classes" }, { 8, "Mage" }, { 5, "Priest" }, { 9, "Warlock" } },
    faction = { { "player", "My faction" }, { "all", "Both factions" }, { "Alliance", "Alliance" }, { "Horde", "Horde" } },
    source = { { "all", "All sources" }, { "quest", "Quest" }, { "vendor", "Vendor" }, { "crafting", "Crafting" },
        { "dungeon", "Dungeon" }, { "world", "World drop" } },
    school = { { "all", "All schools" }, { "Arcane", "Arcane" }, { "Fire", "Fire" }, { "Frost", "Frost" },
        { "Shadow", "Shadow" }, { "Holy", "Holy" }, { "Nature", "Nature" }, { "Physical", "Physical" } },
}
function Guide:Initialize(saved)
    self.settings = M.Settings(saved)
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
    local title = font(self.shell.top, 24, ACCENT); title:SetPoint("TOPLEFT", 18, -15); title:SetText("Wanderful")
    local subtitle = font(self.shell.top, 11, { 0.64, 0.70, 0.77 })
    subtitle:SetPoint("LEFT", title, "RIGHT", 15, -3); subtitle:SetText("WAND UPGRADES  /  FOREVER")
    local drag = CreateFrame("Frame", nil, content); drag:SetPoint("TOPLEFT", 0, 0); drag:SetPoint("TOPRIGHT", -85, 0); drag:SetHeight(46)
    drag:EnableMouse(true); drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function() w:StartMoving() end)
    drag:SetScript("OnDragStop", function() w:StopMovingOrSizing(); self:SaveWindow() end)
    local close = button(content, "Close", 58, function() w:Hide() end); close:SetPoint("TOPRIGHT", -15, -14)
    self.baseline = font(content, 13)
    self.baseline:SetPoint("TOPLEFT", 18, -58); self.baseline:SetHeight(43)
    local auto = button(content, "Use equipped wand", 154, function() ns.Equipped:Automatic() end)
    auto:SetPoint("TOPRIGHT", -18, -58)
    self.baseline:SetPoint("TOPRIGHT", auto, "TOPLEFT", -14, 0)

    local function levelBox(label, x, key)
        local fs = font(content, 11, { 0.70, 0.74, 0.80 }); fs:SetPoint("TOPLEFT", x, -108); fs:SetText(label)
        local box = CreateFrame("EditBox", nil, content)
        box:SetSize(47, 26); box:SetPoint("TOPLEFT", x + 34, -102); box:SetAutoFocus(false)
        box:SetFontObject("GameFontHighlightSmall"); box:SetNumeric(true); box:SetMaxLetters(3)
        box:SetTextInsets(7, 5, 0, 0); surface(box, false)
        box:SetScript("OnEnterPressed", function() self:SetFilter(key, tonumber(box:GetText())); box:ClearFocus(); self:Refresh() end)
        box:SetScript("OnEscapePressed", function() box:ClearFocus(); self:Refresh() end)
        return box
    end
    self.minBox, self.maxBox = levelBox("From", 18, "minLevel"), levelBox("To", 113, "maxLevel")
    local range = button(content, "Follow my level", 124, function()
        local p = self.settings.filters
        p.minLevel, p.maxLevel = nil, nil; self:Touch(); self:Refresh()
    end); range:SetPoint("TOPLEFT", 211, -102)
    self.upgrades = button(content, "All wands", 142, function() self:SetFilter("upgradesOnly", not self.settings.filters.upgradesOnly) end)
    self.upgrades:SetPoint("TOPLEFT", 347, -102)
    local reset = button(content, "Reset filters", 108, function()
        self.settings.filters = M.Settings(nil).filters; self:Touch(); self:Refresh()
    end); reset:SetPoint("TOPLEFT", 501, -102)
    self.filterButtons = {}
    local x = 18
    for _, spec in ipairs({ { "class", 128 }, { "faction", 128 }, { "source", 150 }, { "school", 140 } }) do
        local key = spec[1]
        local b = button(content, "", spec[2], function(owner) self:Choose(key, owner) end)
        b:SetPoint("TOPLEFT", x, -140); x = x + spec[2] + 12
        self.filterButtons[key] = b
    end
    self.listPane, self.detailPane = pane(content), pane(content)
    self.listCaption = font(self.listPane, 12, ACCENT); self.listCaption:SetPoint("TOPLEFT", 12, -12)
    self.detailCaption = font(self.detailPane, 12, ACCENT); self.detailCaption:SetPoint("TOPLEFT", 12, -12); self.detailCaption:SetText("HOW TO GET IT")
    self.listScroll, self.detailScroll = scroll(self.listPane), scroll(self.detailPane)
    self.empty = font(self.listPane, 13, { 0.76, 0.80, 0.85 })
    self.empty:SetPoint("TOPLEFT", 16, -60); self.empty:SetPoint("RIGHT", -16, 0)
    self.detailTitle = font(self.detailScroll.child, 17)
    self.detailTitle:SetPoint("TOPLEFT", 0, 0); self.detailTitle:SetHeight(48)
    self.detailText = font(self.detailScroll.child, 12)
    self.detailText:SetPoint("TOPLEFT", 0, -57)
    self.manualButton = button(self.detailPane, "Use as baseline", 150, function()
        if self.selected then ns.Equipped:Manual(self.selected.item.itemID, self.selected.item.variant, false) end
    end)
    self.classicButton = button(self.detailPane, "Use Classic reference", 164, function()
        if self.selected then ns.Equipped:Manual(self.selected.item.itemID, self.selected.item.variant, true) end
    end)
    self.manualButton:SetPoint("BOTTOMLEFT", 12, 45); self.classicButton:SetPoint("BOTTOMLEFT", 12, 12)
    local footer = font(content, 10, { 0.68, 0.73, 0.78 })
    footer:SetPoint("BOTTOMLEFT", 18, 12); footer:SetPoint("RIGHT", -75, 0); footer:SetHeight(24)
    footer:SetText("Sample catalog - acquisition paths are unverified. Gains describe base wand DPS, not total character damage.")
    local resize = button(content, "Resize", 55, function() end); resize:SetPoint("BOTTOMRIGHT", -10, 10)
    resize:SetScript("OnMouseDown", function() w:StartSizing("BOTTOMRIGHT") end)
    resize:SetScript("OnMouseUp", function() w:StopMovingOrSizing(); self:SaveWindow() end)
    w:SetScript("OnSizeChanged", function() self:Layout(); self:Refresh() end)
    w:SetScript("OnShow", function() self:Layout(); self:Refresh() end)
    w:SetScript("OnHide", function()
        w:StopMovingOrSizing(); self:SaveWindow()
        if self.popup then self.popup:Hide() end
        if rawget(_G, "GameTooltip") then GameTooltip:Hide() end
    end)
    w:SetScript("OnMouseDown", function() if self.popup then self.popup:Hide() end end)
    if type(UISpecialFrames) == "table" then UISpecialFrames[#UISpecialFrames + 1] = "WanderfulGuide" end
    self:Layout()
    return true
end
function Guide:Layout()
    if not self.window then return end
    local width = self.window:GetWidth()
    local rightWidth = math.max(235, math.min(360, width * 0.35))
    self.listPane:ClearAllPoints(); self.detailPane:ClearAllPoints()
    self.listPane:SetPoint("TOPLEFT", self.content, "TOPLEFT", 18, -182)
    self.listPane:SetPoint("BOTTOMRIGHT", self.content, "BOTTOMRIGHT", -rightWidth - 30, 44)
    self.detailPane:SetPoint("TOPRIGHT", self.content, "TOPRIGHT", -18, -182)
    self.detailPane:SetPoint("BOTTOMRIGHT", self.content, "BOTTOMRIGHT", -18, 44)
    self.detailPane:SetWidth(rightWidth)
    for _, spec in ipairs({ { self.listScroll, self.listPane, 14 }, { self.detailScroll, self.detailPane, 87 } }) do
        local s, parent, bottom = unpack(spec)
        s:ClearAllPoints(); s:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, -38)
        s:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -23, bottom)
        s.child:SetWidth(math.max(1, parent:GetWidth() - 35))
    end
    local dw = math.max(1, rightWidth - 35)
    self.detailTitle:SetWidth(dw); self.detailText:SetWidth(dw)
end
function Guide:Row(index)
    if self.pool[index] then return self.pool[index] end
    local b = CreateFrame("Button", nil, self.listScroll.child)
    b:SetHeight(113)
    b.marker = b:CreateTexture(nil, "BACKGROUND"); b.marker:SetColorTexture(unpack(ACCENT))
    b.marker:SetPoint("TOPLEFT", 0, -3); b.marker:SetPoint("BOTTOMLEFT", 0, 3); b.marker:SetWidth(2)
    b.name = font(b, 14); b.name:SetPoint("TOPLEFT", 10, -5); b.name:SetHeight(33)
    b.stats = font(b, 12); b.stats:SetPoint("TOPLEFT", 10, -40); b.stats:SetHeight(31)
    b.access = font(b, 11, { 0.73, 0.78, 0.84 }); b.access:SetPoint("TOPLEFT", 10, -72); b.access:SetHeight(15)
    b.source = font(b, 11, { 0.60, 0.68, 0.76 }); b.source:SetPoint("TOPLEFT", 10, -89); b.source:SetHeight(18)
    b:SetHighlightTexture("Interface\\Buttons\\WHITE8X8"); b:GetHighlightTexture():SetAlpha(0.04)
    b:SetScript("OnClick", function()
        self.detailScroll.slider:SetValue(0)
        self.selectedKey = b.row.item.itemID .. ":" .. b.row.item.variant
        self:Refresh()
    end)
    b:SetScript("OnEnter", function()
        local t = rawget(_G, "GameTooltip")
        if not t or not b.row then return end
        t:SetOwner(b, "ANCHOR_RIGHT"); t:SetText(b.row.item.name)
        t:AddLine(b.stats:GetText(), 1, 1, 1, true)
        t:AddLine(M.Equip(b.row) .. " / " .. M.Access(b.row), 0.8, 0.85, 0.9, true)
        t:AddLine("Select for full acquisition paths and evidence.", 0.6, 0.85, 0.8, true); t:Show()
    end)
    b:SetScript("OnLeave", function() if rawget(_G, "GameTooltip") then GameTooltip:Hide() end end)
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
    self.rows = ns.Comparison.List(ns.WandData, state.snapshot, context, filters)
    self.baseline:SetText(M.Baseline(ns.WandData, state))
    self.rendered = { itemID = state.itemID, mode = state.mode, status = state.status, provenance = state.provenance }
    if not self.minBox:HasFocus() then self.minBox:SetText(tostring(filters.minLevel)) end
    if not self.maxBox:HasFocus() then self.maxBox:SetText(tostring(filters.maxLevel)) end
    self.upgrades.label:SetText(self.settings.filters.upgradesOnly and "Upgrades only: on" or "All wands")
    for key, b in pairs(self.filterButtons) do
        for _, option in ipairs(OPTIONS[key]) do
            if option[1] == self.settings.filters[key] then b.label:SetText(option[2] .. "  v") end
        end
    end
    self.listCaption:SetText("WANDS BY EQUIP LEVEL  -  " .. #self.rows)
    self.selected = nil
    for _, row in ipairs(self.rows) do
        if row.item.itemID .. ":" .. row.item.variant == self.selectedKey then self.selected = row; break end
    end
    self.selected = self.selected or self.rows[1]
    self.selectedKey = self.selected and (self.selected.item.itemID .. ":" .. self.selected.item.variant) or nil
    for _, b in ipairs(self.pool) do b:Hide() end
    for i, row in ipairs(self.rows) do
        local b = self:Row(i); b.row = row
        b:ClearAllPoints(); b:SetPoint("TOPLEFT", 0, -(i - 1) * 113); b:SetWidth(self.listScroll.child:GetWidth())
        local stats = row.item.forever.stats
        for _, field in ipairs({ "name", "stats", "access", "source" }) do b[field]:SetWidth(math.max(1, b:GetWidth() - 21)) end
        b.name:SetText(row.item.name)
        b.stats:SetText("Lvl " .. (stats.equipLevel or "?") .. "  " .. (stats.school or "?") .. "  "
            .. (row.comparison.candidate.value and string.format("%.2f DPS", row.comparison.candidate.value) or "DPS unknown")
            .. "\n" .. M.Gain(row.comparison))
        b.access:SetText(M.Equip(row) .. " / " .. M.Access(row))
        local paths = row.eligibility.sources
        b.source:SetText(paths[1] and (paths[1].source.description .. (#paths > 1 and (" (+" .. (#paths - 1) .. " route)") or "")) or "No source recorded")
        b.marker:SetShown(row == self.selected)
        b.name:SetTextColor(unpack(row == self.selected and ACCENT or { 0.91, 0.93, 0.96 }))
        b:Show()
    end
    self.listScroll.child:SetHeight(math.max(1, #self.rows * 113))
    self.empty:SetShown(#self.rows == 0)
    self.empty:SetText(state.snapshot == nil and filters.upgradesOnly
        and "A baseline is needed for upgrade comparisons. Turn off Upgrades only to browse, or use equipped detection."
        or "No matching wands. Widen the level range or reset the filters.")
    local title, text = M.Details(ns.WandData, self.selected)
    self.detailTitle:SetText(title); self.detailText:SetText(text)
    self.detailText:SetHeight(self.detailText:GetStringHeight() + 6)
    self.detailScroll.child:SetHeight(63 + self.detailText:GetStringHeight())
    self.manualButton:Enable(); self.classicButton:Enable()
    self.glass.SetSurfaceEnabled(self.manualButton.surface, self.selected ~= nil)
    self.glass.SetSurfaceEnabled(self.classicButton.surface, self.selected ~= nil and self.selected.item.classic ~= nil)
    if not self.selected then self.manualButton:Disable() end
    if not self.selected or not self.selected.item.classic then self.classicButton:Disable() end
    clampScroll(self.listScroll); clampScroll(self.detailScroll)
end
function Guide:Toggle()
    if not self:Ensure() then return end
    self.window:SetShown(not self.window:IsShown())
end
function Guide:Open() if self:Ensure() then self.window:Show(); self:Refresh() end end
function Guide:State()
    local s = { ready = self.ready == true, shown = self.window ~= nil and self.window:IsShown(),
        loadedRevision = self.loadedRevision, revision = self.settings and self.settings.revision,
        signature = self.settings and M.Signature(self.settings), rows = #self.rows }
    if self.rendered then
        s.renderedItemID, s.renderedMode, s.renderedStatus = self.rendered.itemID, self.rendered.mode, self.rendered.status
    end
    return s
end