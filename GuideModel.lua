local _, ns = ...
local M = {}
ns.GuideModel = M
local classes = { player = true, all = true, [5] = true, [8] = true, [9] = true }
local factions = { player = true, all = true, Alliance = true, Horde = true }
local sources = { all = true, quest = true, vendor = true, crafting = true, dungeon = true, world = true }
local schools = { all = true, Arcane = true, Fire = true, Frost = true, Shadow = true, Holy = true, Nature = true, Physical = true }
function M.Finite(v) return type(v) == "number" and v == v and v > -math.huge and v < math.huge end
local function bounded(v, low, high, default)
    if not M.Finite(v) then return default end
    return math.max(low, math.min(high, math.floor(v + 0.5)))
end
function M.Settings(saved)
    saved = type(saved) == "table" and saved.schemaVersion == 1 and saved or {}
    local w, f = type(saved.window) == "table" and saved.window or {}, type(saved.filters) == "table" and saved.filters or {}
    return { schemaVersion = 1, revision = bounded(saved.revision, 0, 2147483647, 0),
        window = { width = bounded(w.width, 640, 1600, 1040), height = bounded(w.height, 480, 1100, 680),
            x = bounded(w.x, -10000, 10000, 0), y = bounded(w.y, -10000, 10000, 0) },
        filters = { class = classes[f.class] and f.class or "player",
            faction = factions[f.faction] and f.faction or "player",
            source = sources[f.source] and f.source or "all", school = schools[f.school] and f.school or "all",
            minLevel = bounded(f.minLevel, 1, 100, nil), maxLevel = bounded(f.maxLevel, 1, 100, nil),
            upgradesOnly = f.upgradesOnly == true } }
end
function M.Character(env, level)
    local function plain(v)
        if type(env.issecretvalue) ~= "function" then return false end
        local ok, restricted = pcall(env.issecretvalue, v)
        return ok and restricted == false
    end
    local function call(fn, ...)
        if type(fn) ~= "function" then return end
        return pcall(fn, ...)
    end
    local c = { level = level }
    local ok, _, _, class = call(env.UnitClass, "player")
    if ok and plain(class) and M.Finite(class) then c.classID = class end
    local raceOK, _, _, race = call(env.UnitRace, "player")
    if raceOK and plain(race) and M.Finite(race) then c.raceID = race end
    local factionOK, faction = call(env.UnitFactionGroup, "player")
    if factionOK and plain(faction) and (faction == "Alliance" or faction == "Horde") then c.faction = faction end
    return c
end
function M.Filters(settings, character)
    local p = settings.filters
    local level = M.Finite(character.level) and character.level or nil
    local filters = { minLevel = p.minLevel or (level and math.max(1, level - 5) or 1), maxLevel = p.maxLevel or (level and math.min(100, level + 15) or 60),
        upgradesOnly = p.upgradesOnly }
    if filters.minLevel > filters.maxLevel then filters.minLevel, filters.maxLevel = filters.maxLevel, filters.minLevel end
    if p.class == "player" then filters.classID = character.classID
    elseif p.class ~= "all" then filters.classID = p.class end
    if p.faction == "player" then filters.faction = character.faction
    elseif p.faction ~= "all" then filters.faction = p.faction end
    if p.source ~= "all" then filters.sourceKind = p.source end
    if p.school ~= "all" then filters.school = p.school end
    return filters
end
function M.Name(data, id, variant)
    for _, item in ipairs(data.items) do
        if item.itemID == id and (variant == nil or item.variant == variant) then return item.name end
    end
    return id and ("Item " .. id) or "No wand"
end
function M.Baseline(data, state)
    local dps = state.snapshot and ns.Comparison.DPS(state.snapshot).value
    local name = M.Name(data, state.itemID, state.variant)
    local prefix = state.mode == "manual" and (state.provenance == "historical" and "Historical reference" or "Manual baseline") or "Equipped wand"
    local states = { loading = "Loading item data...", empty = "No wand equipped. Browse the guide or select a manual baseline.",
        restricted = "Item data is restricted. Select a manual baseline to compare.",
        unavailable = "Equipment data is unavailable. The bundled guide is still available.",
        unknown = "Wand DPS is unknown. Select a manual baseline to compare.",
        failed = "Item data could not be loaded. Retry equipped detection or select a baseline.",
        not_wand = "The ranged slot does not contain a wand." }
    if dps ~= nil then return prefix .. ": " .. name .. "  |  " .. string.format("%.2f DPS", dps)
        .. "  (" .. (state.provenance or "unknown") .. ")", dps end
    return states[state.status] or "Equipment data has not been read yet.", nil
end
function M.Gain(comparison)
    if comparison.delta == nil then return "Gain unknown" end
    local text = string.format("%+.2f DPS", comparison.delta)
    if comparison.percent ~= nil then text = text .. string.format(" (%+.1f%%)", comparison.percent) end
    return text
end
function M.Equip(row)
    local e = row.eligibility.equip.status
    return ({ usable = "Equip: ready", upcoming = "Equip: upcoming", blocked = "Equip: restricted", unknown = "Equip: unknown" })[e]
end
function M.Access(row)
    return ({ available = "Source: available", blocked = "Source: requirements unmet", unknown = "Source: unverified" })[row.eligibility.acquisition]
end
function M.Details(data, row)
    if not row then return "Select a wand", "Choose a wand on the left to see acquisition paths, requirements and evidence." end
    local item, s = row.item, row.item.forever.stats
    local lines = { M.Equip(row) .. "  |  " .. M.Access(row),
        "Equip level: " .. (s.equipLevel or "unknown") .. "  |  " .. (s.school or "Unknown school"),
        "Base DPS: " .. (row.comparison.candidate.value and string.format("%.2f", row.comparison.candidate.value) or "unknown")
            .. "  |  " .. M.Gain(row.comparison) }
    if s.speed then lines[#lines + 1] = string.format("Speed: %.2f seconds", s.speed) end
    if s.minDamage and s.maxDamage then lines[#lines + 1] = s.minDamage .. " - " .. s.maxDamage .. " base damage" end
    for _, effect in ipairs(s.effects or {}) do lines[#lines + 1] = effect end
    local keys = {}; for key in pairs(s.attributes or {}) do keys[#keys + 1] = key end; table.sort(keys)
    for _, key in ipairs(keys) do lines[#lines + 1] = key .. ": " .. s.attributes[key] end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "ACQUISITION"
    for _, assessment in ipairs(row.eligibility.sources) do
        local source = assessment.source
        lines[#lines + 1] = ""
        lines[#lines + 1] = source.description
        lines[#lines + 1] = "Type: " .. source.kind .. "  |  " .. source.availability
        if source.questID then lines[#lines + 1] = "Quest ID: " .. source.questID end
        if source.npcID then lines[#lines + 1] = "NPC ID: " .. source.npcID end
        if source.spellID then lines[#lines + 1] = "Crafting spell: " .. source.spellID end
        if source.minQuestLevel then lines[#lines + 1] = "Quest minimum level: " .. source.minQuestLevel .. " (not equip level)" end
        if source.professionSkill then lines[#lines + 1] = "Crafting skill: " .. source.professionSkill end
        if source.faction then lines[#lines + 1] = "Source faction: " .. source.faction end
        if source.prerequisiteQuestIDs and #source.prerequisiteQuestIDs > 0 then
            local ids = {}; for _, id in ipairs(source.prerequisiteQuestIDs) do ids[#ids + 1] = tostring(id) end
            lines[#lines + 1] = "Mandatory prerequisite quests: " .. table.concat(ids, ", ")
        end
        if not source.requirementsComplete then lines[#lines + 1] = "Requirements are incomplete; access is not established." end
        if source.notes then lines[#lines + 1] = source.notes end
        local e = data.evidence[source.evidence]
        lines[#lines + 1] = "Evidence: " .. e.method .. ", " .. e.observedOn .. (e.build and (", build " .. e.build) or "")
        lines[#lines + 1] = e.url
    end
    if #row.eligibility.sources == 0 then lines[#lines + 1] = "No matching acquisition path is recorded." end
    local e = data.evidence[item.forever.evidence]
    lines[#lines + 1] = ""
    lines[#lines + 1] = "ITEM EVIDENCE"
    lines[#lines + 1] = e.method .. ", observed " .. e.observedOn .. (e.build and (", build " .. e.build) or "")
    lines[#lines + 1] = e.url
    lines[#lines + 1] = "Base item DPS only. Effects and character modifiers are not scored."
    return item.name, table.concat(lines, "\n")
end
function M.Signature(settings)
    local w, f = settings.window, settings.filters
    local fields = { w.width, w.height, w.x, w.y, f.class, f.faction, f.source, f.school,
        f.minLevel or "auto", f.maxLevel or "auto", tostring(f.upgradesOnly) }
    for i, value in ipairs(fields) do fields[i] = tostring(value) end
    return table.concat(fields, "|")
end
return M