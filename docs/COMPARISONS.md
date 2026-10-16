# Base wand comparisons and eligibility

Comparison.lua is a pure model exposed as ns.Comparison. It uses plain Lua catalog snapshots
and supplied character context. It does not query WoW APIs or inspect equipment. A future live
adapter must remove restricted values and normalize its inputs before calling it.

## Numeric results

DPS(snapshot) takes { stats = {...}, evidence = <reference> } and returns a table containing
value, method and evidence. It uses (minDamage / 2 + maxDamage / 2) / speed when all three
fields are available; otherwise it uses reported dps. It never rounds or substitutes Classic
data. The evidence reference remains attached, and method distinguishes damage_range from
reported, so a rounded database number cannot silently look like a newly calculated value.

A supplied invalid numeric field (negative, NaN, infinity, inverted range, or zero speed) makes
the value unknown with a reason. It does not fall back to a plausible reported DPS. Arithmetic
overflow likewise produces an unknown result.

Compare(candidateSnapshot, baselineSnapshot) returns both DPS results, relation, delta and
percent. Relation is upgrade, equal, downgrade, or unknown. Missing data produces no invented
delta or percentage. An explicit zero-DPS baseline can have a delta, but no percentage.
These are base wand DPS changes; no character DPS, talent, resistance, proc or spell-power
model is implied. Attributes, effects, school and speed remain available on the original item.

## Equip and acquisition are independent

Assess(data, item, character, filters) consumes a validated catalog entry. It returns equip
status/reasons, the selected source assessments, acquisition status, and an overall status.

- Equip status is usable, upcoming, blocked (known class restriction), or unknown.
- Acquisition is available, blocked, or unknown. One available source is enough; a blocked
  route does not conceal another available or uncertain route.
- Overall status is requirements_unmet if an equip/source blocker is established, upcoming
  for a known unmet equip level, availability_unknown for incomplete evidence, and usable_now
  only when both equipping and an acquisition route are established.

A quest minimum level only gates that quest source. It never supplies a missing equip level.
Suggested acquisition levels are descriptive and do not gate access. The model checks explicit
faction, class, race, mandatory prerequisite quests, quest minimum level and recipe skill.
It does not infer eligibility from an account completion flag or the reward quest's completion.
Consumed rewards, optional/OR chains, stock, travel and repeatable quests need later modeling.

Character context contains level, classID, raceID, faction, completedQuests and recipeSkills:

    local context = {
        level = 15, classID = 5, raceID = 1, faction = "Alliance",
        completedQuests = { [99] = false },
        recipeSkills = { [14293] = 70 },
    }

Recipe skills are indexed by crafting spell ID and apply only to producing through that source.
Buying a crafted item is a different acquisition route; a missing profession never blocks
equipping the item or a separately modeled purchase route.

An omitted restriction is unknown; an explicit empty restriction list establishes no such
restriction. Missing prerequisite completion is unknown; explicit false blocks that prerequisite.
A source needs verified availability, requirementsComplete, and satisfied explicit requirements
to count as available. Listed/unknown availability stays uncertain. Unavailable/test sources
are blocked. Source records must have passed catalog validation, which also checks the evidence
needed to mark a source verified. No automatic catalog promotion happens here.

## Filtering and ordering

List(data, baselineSnapshot, character, filters) returns new rows with item, comparison and
eligibility. It does not mutate the catalog, baseline, character, or source arrays.

Supported filters are classID, faction, school, sourceKind, minLevel, maxLevel, upgradesOnly
and usableOnly. Class/faction filters override those fields in a copied character context;
known-incompatible sources are removed only for an explicit corresponding filter. Other
blocked source alternatives remain visible with reasons. Unknown restrictions remain visible
rather than being asserted compatible. A sourceKind filter needs a matching source.

Level bounds apply to known equip requirements. Unknown levels remain visible with unknown
status; they are never treated as level 1 or inferred from quest levels. School filtering requires
a known matching school. upgradesOnly requires a positive known delta, so a missing baseline
cannot yield an upgrade list. usableOnly requires overall usable_now.

Rows sort by known equip level ascending (unknown last), unrounded candidate DPS descending
(unknown last), item ID ascending, then variant key. The model retains all matching alternatives;
it does not prune a quest option because a world drop has higher DPS. Matching source entries
remain in their declared order. Names and localized text do not affect the ordering.

The bundled sample still has incomplete acquisition/class evidence, so calculating a numerical
upgrade does not establish that the item can be obtained or equipped. Live equipment integration
is #5; rendering the list and its uncertainty is #6.

Run lua tests/test_comparison.lua for focused regression tests, or pwsh tests/run.ps1 for the
full local suite (including the private local ForeverProbe integration).
