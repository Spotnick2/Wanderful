-- Compile each runtime file listed by the TOC without executing WoW API calls.
local tocPath = arg[1] or "Wanderful.toc"
local toc, err = io.open(tocPath, "r")
if not toc then
    io.stderr:write(tostring(err), "\n")
    os.exit(1)
end

local root = tocPath:match("^(.*[/\\])") or ""
local count = 0
local failed = false
for line in toc:lines() do
    line = line:match("^%s*(.-)%s*$")
    if line ~= "" and line:sub(1, 1) ~= "#" then
        if not line:match("%.lua$") then
            io.stderr:write("Unsupported TOC entry (extend validation before adding XML): ", line, "\n")
            failed = true
        else
            local path = root .. line:gsub("\\", "/")
            local chunk, compileError = loadfile(path)
            if not chunk then
                io.stderr:write(tostring(compileError), "\n")
                failed = true
            end
            count = count + 1
        end
    end
end
toc:close()

if count == 0 then
    io.stderr:write("No runtime Lua files listed in ", tocPath, "\n")
    failed = true
end
if failed then
    os.exit(1)
end
print("Syntax OK: " .. count .. " runtime Lua file(s).")
