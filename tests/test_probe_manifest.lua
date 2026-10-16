local function read(path)
    local file = assert(io.open(path, "r"))
    local text = file:read("*a")
    file:close()
    return text
end
local runtime = read("Wanderful.toc")
local entries = {}
for line in runtime:gmatch("[^\r\n]+") do
    if line:sub(1, 1) ~= "#" and line:match("%S") then entries[#entries + 1] = line end
end
assert(entries[1] == "Libs\\LibGlass-1.0\\LibGlass-1.0.xml", "embedded XML must load before addon code")
assert(runtime:find("## SavedVariables: WanderfulDB", 1, true))
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
assert(count == 4)
print("Probe manifest: development dependency and package separation passed.")
