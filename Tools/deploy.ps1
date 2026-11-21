param(
    [switch]$Probe,
    [switch]$ProbeOnly,
    [string]$AddOnsPath = "C:\Program Files (x86)\World of Warcraft\_classic_beta_\Interface\AddOns",
    [string]$Lua = "lua"
)
$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$HostRoot = if ($env:FOREVERPROBE) { $env:FOREVERPROBE } else {
    Join-Path (Split-Path -Parent $RepoRoot) "ForeverProbe"
}
$RuntimeFiles = @("Wanderful.toc", "Core.lua", "Catalog.lua", "Comparison.lua", "Data\Wands.lua", "GuideModel.lua", "ItemPresentation.lua", "UI.lua", "Equipment.lua", "Runtime.lua")
$ProbeFiles = @("WanderfulProbe.toc", "Measurements.lua", "Adapter.lua", "GuideChecks.lua", "WanderfulProbe.lua")
$ProbeRoot = Join-Path $PSScriptRoot "WanderfulProbe"
if (-not (Test-Path -LiteralPath $AddOnsPath -PathType Container)) {
    throw "AddOns path not found: $AddOnsPath"
}
$AddOnsPath = (Resolve-Path -LiteralPath $AddOnsPath).ProviderPath
$LuaPath = (Get-Command $Lua -ErrorAction Stop).Source

# Preflight all project sources before touching either installed project addon.
$wanted = if ($ProbeOnly) { @() } else { $RuntimeFiles | ForEach-Object { Join-Path $RepoRoot $_ } }
if ($Probe -or $ProbeOnly) { $wanted += @($ProbeFiles | ForEach-Object { Join-Path $ProbeRoot $_ }) }
foreach ($path in $wanted) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Source missing: $path" }
}
Push-Location $RepoRoot
try {
    & $LuaPath Tools/check.lua
    if ($LASTEXITCODE -ne 0) { throw "Runtime syntax preflight failed" }
    if ($Probe -or $ProbeOnly) {
        & $LuaPath Tools/check.lua Tools/WanderfulProbe/WanderfulProbe.toc
        if ($LASTEXITCODE -ne 0) { throw "Probe syntax preflight failed" }
    }
} finally { Pop-Location }

if ($Probe -or $ProbeOnly) {
    $HostDeploy = Join-Path $HostRoot "Tools\deploy.ps1"
    if (-not (Test-Path -LiteralPath $HostDeploy -PathType Leaf)) {
        throw "ForeverProbe checkout missing at $HostRoot (or set FOREVERPROBE)."
    }
    # Both switches deploy the shared host first, forwarding the destination and Lua path.
    & pwsh -NoProfile -File $HostDeploy -AddOnsPath $AddOnsPath -Lua $LuaPath
    if ($LASTEXITCODE -ne 0) { throw "ForeverProbe deploy refused; WanderfulProbe was not touched." }
}

function Copy-AddonFiles($SourceRoot, $Name, $Files) {
    $destination = Join-Path $AddOnsPath $Name
    foreach ($file in $Files) {
        $target = Join-Path $destination $file
        New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $SourceRoot $file) -Destination $target -Force
    }
    Write-Host "Copied $Name ($($Files.Count) files) to $destination"
}
if (-not $ProbeOnly) {
    $LibRoot = if ($env:LIBGLASS) { $env:LIBGLASS } else { Join-Path (Split-Path -Parent $RepoRoot) "LibGlass" }
    $LibDeploy = Join-Path $LibRoot "Tools\deploy.ps1"
    if (-not (Test-Path -LiteralPath $LibDeploy -PathType Leaf)) { throw "LibGlass checkout missing at $LibRoot (or set LIBGLASS)." }
    & pwsh -NoProfile -File $LibDeploy -Addon Wanderful -AddOnsPath $AddOnsPath -Lua $LuaPath
    if ($LASTEXITCODE -ne 0) { throw "LibGlass deploy failed; Wanderful runtime was not copied." }
    Copy-AddonFiles $RepoRoot "Wanderful" $RuntimeFiles
}
if ($Probe -or $ProbeOnly) { Copy-AddonFiles $ProbeRoot "WanderfulProbe" $ProbeFiles }
Write-Host "Use /reload to load the copied files."
