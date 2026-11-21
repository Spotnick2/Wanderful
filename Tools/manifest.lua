-- Resolve the addon manifest, including its pinned embedded library's XML.
local M = {}
function M.LibRoot()
    return (os.getenv("LIBGLASS") or "../LibGlass"):gsub("\\", "/"):gsub("/$", "")
end
function M.Files(tocPath)
    local root = tocPath:match("^(.*[/\\])") or ""
    local result = {}
    for line in io.lines(tocPath) do
        line = line:match("^%s*(.-)%s*$")
        if line ~= "" and line:sub(1, 1) ~= "#" then
            if line == "Libs\\LibGlass-1.0\\LibGlass-1.0.xml" then
                local libRoot = M.LibRoot()
                local f = assert(io.open(libRoot .. "/LibGlass-1.0.xml", "rb"), "LibGlass missing; set LIBGLASS or use ../LibGlass")
                local xml = f:read("*a"):gsub("<!%-%-.-%-%->", ""); f:close()
                assert(not xml:find("<Include"), "Unsupported library XML include")
                local count = 0
                for script in xml:gmatch('<Script%s+file="([^"]+)"%s*/>') do
                    assert(script:match("%.lua$") and not script:find("..", 1, true) and not script:find(":", 1, true), "Invalid XML script")
                    result[#result + 1] = libRoot .. "/" .. script:gsub("\\", "/"); count = count + 1
                end
                assert(count > 0, "Empty library XML")
            else
                assert(line:match("%.lua$") and not line:find("..", 1, true), "Unsupported TOC entry: " .. line)
                result[#result + 1] = root .. line:gsub("\\", "/")
            end
        end
    end
    assert(#result > 0, "Empty runtime manifest")
    return result
end
function M.Load(env, namespace)
    env._G = env
    env.strmatch = string.match
    for _, path in ipairs(M.Files("Wanderful.toc")) do
        setfenv(assert(loadfile(path)), env)("Wanderful", namespace)
    end
end
return M