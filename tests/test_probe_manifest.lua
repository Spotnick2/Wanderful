local function read(path)
    local file = assert(io.open(path, "r"))
    local text = file:read("*a")
    file:close()
    return text
end
local runtime = read("Wanderful.toc")
assert(not runtime:find("ForeverProbe", 1, true) and not runtime:find("Tools", 1, true))
assert(read(".pkgmeta"):find("  - Tools", 1, true), "development tools must stay outside the package")
local toc = read("Tools/WanderfulProbe/WanderfulProbe.toc")
assert(toc:find("## Dependencies: ForeverProbe", 1, true))
local count = 0
for line in toc:gmatch("[^\r\n]+") do
    if line:match("%.lua$") and line:sub(1, 1) ~= "#" then
        assert(loadfile("Tools/WanderfulProbe/" .. line:gsub("\\", "/")))
        count = count + 1
    end
end
assert(count == 2)
print("Probe manifest: development dependency and package separation passed.")
