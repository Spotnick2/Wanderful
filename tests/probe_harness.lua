-- Shared measurement fixture. CI uses a small helper double; test_probe_host loads
-- the real local ForeverProbe into these same client stubs.
local H = {}

function H.New()
    local w = { log = {}, chat = {}, timers = {}, frames = {}, now = 0, cache = {}, requests = {}, combat = false }
    local env = setmetatable({}, { __index = _G })
    env._G = env
    local secrets = setmetatable({}, { __mode = "k" })
    function w.secret()
        local value = newproxy(true)
        local mt = getmetatable(value)
        local function touched() error("secret value used") end
        for _, key in ipairs({ "__tostring", "__concat", "__add", "__sub", "__mul", "__div", "__index", "__lt", "__le" }) do
            mt[key] = touched
        end
        secrets[value] = true
        return value
    end
    env.issecretvalue = function(v) return secrets[v] == true end
    local P = {}
    function P.Pack(...) return { n = select("#", ...), ... } end
    function P.Show(v)
        if env.issecretvalue(v) then return "<secret>" end
        return tostring(v)
    end
    function P.Shape(v)
        if env.issecretvalue(v) then return "<secret>" end
        if type(v) == "string" then return "str" .. #v end
        return type(v)
    end
    function P.Describe(v, depth)
        if env.issecretvalue(v) then return "<secret>" end
        if type(v) ~= "table" then return P.Show(v) end
        depth = depth or 1
        if depth <= 0 then return "{...}" end
        local parts = {}
        for k, value in pairs(v) do parts[#parts + 1] = P.Show(k) .. "=" .. P.Describe(value, depth - 1) end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    function P:Say(line)
        w.log[#w.log + 1] = line
        if self.log then self.log[#self.log + 1] = line end
    end
    P.commands, P.procedures = {}, {}
    function P:Command(name, fn) self.commands[name] = fn end
    function P:Steps(name, definition) self.procedures[name] = definition end
    function P:Ready() return true end
    function P:UseLog(log) self.log = log end
    function P:ClearLog() for i = #self.log, 1, -1 do self.log[i] = nil end end
    function P:RegisterEvents(frame, events)
        local all = true
        for _, event in ipairs(events) do
            local ok, accepted = pcall(frame.RegisterEvent, frame, event)
            if not ok or accepted == false then self:Say("RegisterEvent refused: " .. event); all = false end
        end
        return all
    end
    function P:Try(label, fn, ...)
        if type(fn) ~= "function" then self:Say(label .. ": MISSING"); return false end
        local result = P.Pack(pcall(fn, ...))
        if not result[1] then self:Say(label .. ": ERROR " .. P.Show(result[2])) end
        return unpack(result, 1, result.n)
    end
    function P:Call(label, fn, ...)
        local result = P.Pack(self:Try(label, fn, ...))
        for i = 2, result.n do self:Say(label .. " " .. P.Describe(result[i], 3)) end
    end
    function w.has(part)
        for _, line in ipairs(w.log) do if line:find(part, 1, true) then return true end end
        return false
    end
    function w.tick()
        local timers = w.timers
        w.timers = {}
        for _, fn in ipairs(timers) do fn() end
    end
    env.CreateFrame = function()
        local frame = { events = {}, scripts = {} }
        function frame:RegisterEvent(event) self.events[event] = true; return true end
        function frame:UnregisterEvent(event) self.events[event] = nil end
        function frame:SetScript(kind, fn) self.scripts[kind] = fn end
        w.frames[#w.frames + 1] = frame
        return frame
    end
    function w.fire(event, ...)
        for _, frame in ipairs(w.frames) do
            if frame.events[event] and frame.scripts.OnEvent then frame.scripts.OnEvent(frame, event, ...) end
        end
    end
    env.GetBuildInfo = function() return "1.60.1", "test-build", "test-date", 16001 end
    env.GetLocale = function() return "enUS" end
    env.GetTime = function() return w.now end
    env.InCombatLockdown = function() return w.combat end
    env.print = function(...) w.chat[#w.chat + 1] = { ... } end
    env.SlashCmdList = {}
    env.C_Timer = { After = function(_, fn) w.timers[#w.timers + 1] = fn end }
    env.C_Item = {
        IsItemDataCachedByID = function(id) return w.cache[id] == true end,
        RequestLoadItemDataByID = function(id) w.requests[#w.requests + 1] = id end,
    }
    local NS = {}
    local chunk = assert(loadfile("Tools/WanderfulProbe/Measurements.lua"))
    setfenv(chunk, env)("WanderfulProbe", NS)
    w.env, w.Probe, w.NS = env, P, NS
    w.measure = NS.Measurements.New(P, env)
    return w
end

return H
