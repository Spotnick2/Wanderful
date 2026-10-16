local _, ns = ...
local Comparison = {}
ns.Comparison = Comparison

local function finite(value)
    return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

-- Plain snapshots only. The live adapter must reject restricted values before calling.
function Comparison.DPS(snapshot)
    local result = {}
    if type(snapshot) == "table" then result.evidence = snapshot.evidence end
    local stats = type(snapshot) == "table" and snapshot.stats
    if type(stats) ~= "table" then result.reason = "missing_stats"; return result end
    for _, field in ipairs({ "minDamage", "maxDamage", "dps", "speed" }) do
        local value = stats[field]
        if value ~= nil and (not finite(value) or value < 0 or (field == "speed" and value == 0)) then
            result.reason = "invalid_" .. field
            return result
        end
    end
    if stats.minDamage ~= nil and stats.maxDamage ~= nil and stats.minDamage > stats.maxDamage then
        result.reason = "invalid_damage_range"; return result
    end
    if stats.minDamage ~= nil and stats.maxDamage ~= nil and stats.speed ~= nil then
        -- Divide before adding so a valid large range does not overflow its mean.
        result.value = (stats.minDamage / 2 + stats.maxDamage / 2) / stats.speed
        result.method = "damage_range"
    elseif stats.dps ~= nil then
        result.value, result.method = stats.dps, "reported"
    else
        result.reason = "missing_dps"; return result
    end
    if not finite(result.value) then result.value, result.reason = nil, "invalid_derived_dps" end
    return result
end

function Comparison.Compare(candidate, baseline)
    local result = { candidate = Comparison.DPS(candidate), baseline = Comparison.DPS(baseline), relation = "unknown" }
    if result.candidate.value == nil then result.reason = "candidate_" .. result.candidate.reason; return result end
    if result.baseline.value == nil then result.reason = "baseline_" .. result.baseline.reason; return result end
    result.delta = result.candidate.value - result.baseline.value
    if result.delta > 0 then result.relation = "upgrade"
    elseif result.delta < 0 then result.relation = "downgrade"
    else result.relation = "equal" end
    if result.baseline.value == 0 then result.reason = "zero_baseline"; return result end
    result.percent = result.delta / result.baseline.value * 100
    if not finite(result.percent) then result.percent, result.reason = nil, "invalid_percentage" end
    return result
end

local function contains(list, value)
    for _, member in ipairs(list) do if member == value then return true end end
    return false
end

-- nil means unknown; an explicit empty list means no restriction.
local function membership(list, value)
    if list == nil then return "unknown" end
    if #list == 0 then return "allowed" end
    if value == nil then return "unknown" end
    return contains(list, value) and "allowed" or "blocked"
end

local function add(reasons, condition, reason)
    if condition then reasons[#reasons + 1] = reason end
end

local function equip(stats, character)
    local reasons = {}
    local class = membership(stats.classIDs, character.classID)
    add(reasons, class == "blocked", "class_restricted")
    add(reasons, class == "unknown", "class_unknown")
    local level = "unknown"
    if stats.equipLevel ~= nil and finite(character.level) then
        level = character.level >= stats.equipLevel and "allowed" or "upcoming"
    end
    add(reasons, level == "upcoming", "equip_level")
    add(reasons, level == "unknown", "equip_level_unknown")
    local status = "usable"
    if class == "blocked" then status = "blocked"
    elseif level == "upcoming" then status = "upcoming"
    elseif class == "unknown" or level == "unknown" then status = "unknown" end
    return { status = status, reasons = reasons }
end

local function sourceAccess(source, character)
    local blocked, unknown, reasons = false, false, {}
    local function requireState(state, reason)
        blocked = blocked or state == "blocked"
        unknown = unknown or state == "unknown"
        if state ~= "allowed" then reasons[#reasons + 1] = reason end
    end
    if source.availability == "unavailable" or source.availability == "test" then
        requireState("blocked", "source_unavailable")
    elseif source.availability ~= "verified" then
        requireState("unknown", "availability_unknown")
    end
    if not source.requirementsComplete then requireState("unknown", "requirements_incomplete") end
    local faction = "unknown"
    if source.faction == "Both" then faction = "allowed"
    elseif source.faction ~= nil and character.faction ~= nil then
        faction = source.faction == character.faction and "allowed" or "blocked"
    end
    requireState(faction, "source_faction")
    requireState(membership(source.classIDs, character.classID), "source_class")
    requireState(membership(source.raceIDs, character.raceID), "source_race")
    if source.prerequisiteQuestIDs == nil then
        requireState("unknown", "prerequisites_unknown")
    else
        for _, id in ipairs(source.prerequisiteQuestIDs) do
            local done = character.completedQuests and character.completedQuests[id]
            if done == false then requireState("blocked", "prerequisite:" .. id)
            elseif done ~= true then requireState("unknown", "prerequisite_unknown:" .. id) end
        end
    end
    if source.kind == "quest" then
        if source.minQuestLevel == nil or not finite(character.level) then
            requireState("unknown", "quest_level_unknown")
        elseif character.level < source.minQuestLevel then
            requireState("blocked", "quest_level")
        end
    elseif source.kind == "crafting" then
        -- Skill for this recipe, supplied by a caller; never an equip requirement.
        local skill = character.recipeSkills and character.recipeSkills[source.spellID]
        if source.professionSkill == nil or not finite(skill) then
            requireState("unknown", "recipe_skill_unknown")
        elseif skill < source.professionSkill then
            requireState("blocked", "recipe_skill")
        end
    end
    return { status = blocked and "blocked" or (unknown and "unknown" or "available"), reasons = reasons }
end

local function sourceMatches(source, filters)
    if filters.sourceKind and source.kind ~= filters.sourceKind then return false end
    if filters.faction and source.faction and source.faction ~= "Both"
        and filters.faction ~= source.faction then return false end
    if filters.classID and membership(source.classIDs, filters.classID) == "blocked" then return false end
    return true
end

local function contextFor(character, filters)
    local context = {}
    for key, value in pairs(character or {}) do context[key] = value end
    if filters.classID ~= nil then context.classID = filters.classID end
    if filters.faction ~= nil then context.faction = filters.faction end
    return context
end

-- The catalog is validated at load. Keep individual source alternatives and unknowns.
function Comparison.Assess(data, item, character, filters)
    filters = filters or {}
    character = contextFor(character, filters)
    local result = { equip = equip(item.forever.stats, character), sources = {} }
    local available, unknown = false, false
    for _, id in ipairs(item.sourceIDs) do
        local source = data.sources[id]
        if sourceMatches(source, filters) then
            local assessment = sourceAccess(source, character)
            assessment.id, assessment.source = id, source
            result.sources[#result.sources + 1] = assessment
            available = available or assessment.status == "available"
            unknown = unknown or assessment.status == "unknown"
        end
    end
    result.acquisition = available and "available"
        or ((unknown or #result.sources == 0) and "unknown" or "blocked")
    if result.equip.status == "blocked" or result.acquisition == "blocked" then result.status = "requirements_unmet"
    elseif result.equip.status == "upcoming" then result.status = "upcoming"
    elseif result.equip.status == "unknown" or result.acquisition == "unknown" then result.status = "availability_unknown"
    else result.status = "usable_now" end
    return result
end

local function ordered(a, b)
    local as, bs = a.item.forever.stats, b.item.forever.stats
    local al, bl = as.equipLevel, bs.equipLevel
    if al ~= bl then
        if al == nil then return false end
        if bl == nil then return true end
        return al < bl
    end
    local ad, bd = a.comparison.candidate.value, b.comparison.candidate.value
    if ad ~= bd then
        if ad == nil then return false end
        if bd == nil then return true end
        return ad > bd
    end
    if a.item.itemID ~= b.item.itemID then return a.item.itemID < b.item.itemID end
    return a.item.variant < b.item.variant
end

function Comparison.List(data, baseline, character, filters)
    filters = filters or {}
    local context = contextFor(character, filters)
    local rows = {}
    for _, item in ipairs(data.items) do
        local stats = item.forever.stats
        local match = not filters.school or stats.school == filters.school
        if context.classID and membership(stats.classIDs, context.classID) == "blocked" then match = false end
        -- Unknown levels stay visible; level bounds never turn them into level 1.
        if stats.equipLevel ~= nil then
            if filters.minLevel and stats.equipLevel < filters.minLevel then match = false end
            if filters.maxLevel and stats.equipLevel > filters.maxLevel then match = false end
        end
        local assessment = Comparison.Assess(data, item, context, filters)
        if #item.sourceIDs > 0 and #assessment.sources == 0 then match = false end
        if filters.sourceKind and #assessment.sources == 0 then match = false end
        local comparison = Comparison.Compare(item.forever, baseline)
        if filters.upgradesOnly and comparison.relation ~= "upgrade" then match = false end
        if filters.usableOnly and assessment.status ~= "usable_now" then match = false end
        if match then
            rows[#rows + 1] = { item = item, comparison = comparison, eligibility = assessment }
        end
    end
    table.sort(rows, ordered)
    return rows
end
