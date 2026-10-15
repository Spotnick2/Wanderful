param(
    [string]$Lua = "lua",
    [string]$Luac = "luac"
)
$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $RepoRoot
try {
    foreach ($folder in @(".", "Data", "Tools", "tests")) {
        $paths = if ($folder -eq ".") {
            Get-ChildItem -LiteralPath $RepoRoot -File -Filter "*.lua"
        } else {
            Get-ChildItem -LiteralPath (Join-Path $RepoRoot $folder) -File -Filter "*.lua" -Recurse
        }
        foreach ($path in $paths) {
            & $Luac -p $path.FullName
            if ($LASTEXITCODE -ne 0) { throw "Lua syntax validation failed: $($path.FullName)" }
        }
    }
    & $Lua Tools/check.lua
    if ($LASTEXITCODE -ne 0) { throw "Runtime TOC validation failed" }
    & $Lua Tools/check.lua Tools/WanderfulProbe/WanderfulProbe.toc
    if ($LASTEXITCODE -ne 0) { throw "Probe TOC validation failed" }
    foreach ($path in Get-ChildItem -LiteralPath $PSScriptRoot -File -Filter "test_*.lua" | Sort-Object Name) {
        & $Lua $path.FullName
        if ($LASTEXITCODE -ne 0) { throw "Test failed: $($path.Name)" }
    }
} finally {
    Pop-Location
}
