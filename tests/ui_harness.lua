local H = dofile("tests/probe_harness.lua")
local U = {}
function U.New(saved)
    local w = H.New()
    local env = w.env
    local methods = {}
    w.uiMethods = {}
    local function call(wd, name, ...)
        if wd.scripts and wd.scripts[name] then wd.scripts[name](wd, ...) end
    end
    local mt = { __index = function(wd, key)
        local fn = methods[key]
        if fn then return function(self, ...)
            w.uiMethods[self.kind .. ":" .. key] = true
            return fn(self, ...)
        end end
    end }
    local function widget(kind, parent)
        return setmetatable({ kind = kind, parent = parent, scripts = {}, events = {}, points = {},
            shown = true, enabled = true, width = 0, height = 0, level = parent and parent.level + 1 or 1, value = 0 }, mt)
    end
    local function anchor(point, axis)
        if point == "CENTER" then return 0.5 end
        if axis == "x" then
            if point:find("LEFT") then return 0 elseif point:find("RIGHT") then return 1 end
        else
            if point:find("BOTTOM") then return 0 elseif point:find("TOP") then return 1 end
        end
        return 0.5
    end
    local function dimension(wd, axis)
        local low, high
        for _, p in ipairs(wd.points) do
            local own = anchor(p[1], axis)
            if own == 0 or own == 1 then
                local relative = p[2] or wd.parent
                local size = relative and (axis == "x" and relative:GetWidth() or relative:GetHeight()) or 0
                local value = size * anchor(p[3], axis) + (axis == "x" and p[4] or p[5])
                if own == 0 then low = value else high = value end
            end
        end
        if low and high then return high - low end
        return axis == "x" and wd.width or wd.height
    end
    function methods.SetPoint(wd, point, relative, relativePoint, x, y)
        if type(relative) == "number" or relative == nil then
            x, y, relative, relativePoint = relative or 0, relativePoint or 0, wd.parent, point
        end
        wd.points[#wd.points + 1] = { point, relative, relativePoint or point, x or 0, y or 0 }
    end
    function methods.ClearAllPoints(wd) wd.points = {} end
    function methods.SetAllPoints(wd, relative)
        relative = relative or wd.parent
        wd.points = { { "TOPLEFT", relative, "TOPLEFT", 0, 0 }, { "BOTTOMRIGHT", relative, "BOTTOMRIGHT", 0, 0 } }
    end
    function methods.SetSize(wd, a, b)
        assert(a > 0 and b > 0)
        wd.width, wd.height = a, b
        call(wd, "OnSizeChanged", a, b)
    end
    function methods.SetWidth(wd, value) assert(value > 0); wd.width = value end
    function methods.SetHeight(wd, value) assert(value > 0); wd.height = value end
    function methods.GetWidth(wd) return dimension(wd, "x") end
    function methods.GetHeight(wd) return dimension(wd, "y") end
    function methods.GetCenter(wd)
        if wd == env.UIParent then return wd.width / 2, wd.height / 2 end
        for _, p in ipairs(wd.points) do
            if p[1] == "CENTER" then local x, y = p[2]:GetCenter(); return x + p[4], y + p[5] end
        end
        return 0, 0
    end
    function methods.GetParent(wd) return wd.parent end
    function methods.GetFrameLevel(wd) return wd.level end
    function methods.SetFrameLevel(wd, v) wd.level = v end
    function methods.RegisterEvent(wd, event) wd.events[event] = true; return true end
    function methods.UnregisterEvent(wd, event) wd.events[event] = nil end
    function methods.SetScript(wd, name, fn) wd.scripts[name] = fn end
    function methods.Show(wd) local old = wd.shown; wd.shown = true; if not old then call(wd, "OnShow") end end
    function methods.Hide(wd) local old = wd.shown; wd.shown = false; if old then call(wd, "OnHide") end end
    function methods.SetShown(wd, value) if value then wd:Show() else wd:Hide() end end
    function methods.IsShown(wd) return wd.shown and (not wd.parent or wd.parent:IsShown()) end
    function methods.CreateTexture(wd) return widget("Texture", wd) end
    function methods.CreateMaskTexture(wd) return widget("MaskTexture", wd) end
    function methods.CreateFontString(wd) return widget("FontString", wd) end
    function methods.SetTexture(wd, path) wd.texture = path end
    function methods.SetColorTexture(wd, ...) wd.color = { ... } end
    function methods.SetVertexColor(wd, ...) wd.vertex = { ... } end
    function methods.SetGradient(wd, ...) wd.gradient = { ... } end
    function methods.SetAlpha(wd, value) wd.alpha = value end
    function methods.GetAlpha(wd) return wd.alpha or 1 end
    function methods.SetText(wd, text) assert(type(text) == "string" or type(text) == "number"); wd.text = tostring(text) end
    function methods.GetText(wd) return wd.text or "" end
    function methods.SetFont(wd, _, size) wd.fontSize = size end
    function methods.GetStringHeight(wd)
        local height, size = 0, wd.fontSize or 12
        for line in (wd:GetText() .. "\n"):gmatch("(.-)\n") do
            height = height + math.max(1, math.ceil(#line * size * 0.52 / math.max(1, wd:GetWidth()))) * size * 1.2
        end
        return height
    end
    function methods.SetHighlightTexture(wd) wd.highlight = widget("Texture", wd) end
    function methods.GetHighlightTexture(wd) return wd.highlight end
    function methods.SetThumbTexture(wd) wd.thumb = widget("Texture", wd) end
    function methods.GetThumbTexture(wd) return wd.thumb end
    function methods.SetMinMaxValues(wd, low, high) wd.low, wd.high = low, high end
    function methods.SetValue(wd, value) wd.value = value; call(wd, "OnValueChanged", value) end
    function methods.GetValue(wd) return wd.value end
    function methods.SetVerticalScroll(wd, offset) wd.offset = offset end
    function methods.SetScrollChild(wd, child) wd.child = child end
    function methods.Enable(wd) wd.enabled = true end
    function methods.Disable(wd) wd.enabled = false end
    function methods.HasFocus(wd) return wd.focused or false end
    function methods.ClearFocus(wd) wd.focused = false end
    for _, name in ipairs({ "SetClampedToScreen", "SetFrameStrata", "SetMovable", "EnableMouse", "SetResizable",
        "SetResizeBounds", "StartMoving", "StopMovingOrSizing", "StartSizing", "RegisterForDrag", "EnableMouseWheel",
        "SetAutoFocus", "SetFontObject", "SetNumeric", "SetMaxLetters", "SetTextInsets", "SetOrientation", "SetValueStep",
        "SetTextColor", "SetWordWrap", "SetJustifyH", "SetShadowColor", "SetShadowOffset", "AddMaskTexture",
        "SetTextureSliceMargins", "SetTextureSliceMode", "SetHorizTile", "SetVertTile", "SetBlendMode", "SetClipsChildren" }) do
        methods[name] = function() end
    end
    env.CreateFrame = function(kind, name, parent)
        local frame = widget(kind, parent)
        w.frames[#w.frames + 1] = frame
        if name then env[name] = frame end
        return frame
    end
    env.UIParent = widget("Frame"); env.UIParent.width, env.UIParent.height = 1440, 900
    env.CreateColor = function(...) return { ... } end
    env.Enum = { UITextureSliceMode = { Stretched = 0 } }
    env.UISpecialFrames = {}
    env.UnitClass = function() return "Mage", "MAGE", 8 end
    env.UnitRace = function() return "Human", "Human", 1 end
    env.UnitFactionGroup = function() return "Alliance", "Alliance" end
    local ns = H.LoadRuntime(w)
    env.WanderfulDB = saved
    w.fire("ADDON_LOADED", "Wanderful")
    w.fire("PLAYER_LOGIN")
    w.ns, w.guide = ns, ns.Guide
    function w.click(button) assert(button.enabled); call(button, "OnClick") end
    return w
end
return U