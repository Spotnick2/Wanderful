local U = dofile("tests/ui_harness.lua")
local path = os.getenv("FOREVER_API_DUMP") or "../References/forever-api-1.60.1.70425.md"
local f = io.open(path, "r")
if not f then print("SKIPPED: UI widget methods need the local Forever API dump."); return end
local methods = {}
for line in f:lines() do
    local name = line:match("^(%a+:%a+)%s*$")
    if name then methods[name] = true end
end
f:close()
local w = U.New(); w.guide:Open()
w.guide:Choose("school", w.guide.filterButtons.school)
w.guide.window:SetSize(820, 560)
w.guide:SaveWindow(); w.guide:Toggle(); w.guide:Toggle()
local count = 0
for name in pairs(w.uiMethods) do
    assert(methods[name], "Widget method missing on Forever: " .. name)
    count = count + 1
end
assert(count > 80, "Method exercise was incomplete")
print("Guide widget methods: " .. count .. " calls confirmed against the Forever API dump.")