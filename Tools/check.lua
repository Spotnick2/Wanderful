local ok, files = pcall(dofile("Tools/manifest.lua").Files, arg[1] or "Wanderful.toc")
if not ok then io.stderr:write(tostring(files), "\n"); os.exit(1) end
for _, path in ipairs(files) do
    local chunk, err = loadfile(path)
    if not chunk then io.stderr:write(tostring(err), "\n"); os.exit(1) end
end
print("Syntax OK: " .. #files .. " runtime Lua file(s).")