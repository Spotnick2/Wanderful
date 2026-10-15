# Wand catalog, schema version 1

The initial sample contains nine wands and ten acquisition records. It is a development dataset,
not a recommendation list. All Forever values were observed on Wowhead on 2026-10-15; none were
measured in the client. The website's patch label is not a measured client build.

## Files and loading

- `Catalog.lua`: schema validation, item indexing, and an evidence gate.
- `Data/Wands.lua`: evidence registry, acquisition sources, and item declarations.
- `tests/test_catalog.lua`: offline regression tests, run with `lua tests/test_catalog.lua`.

The TOC loads the catalog after the addon namespace. Data is validated before indexing into
`ns.WandsByItemID[itemID][variant]`. Invalid bundled data produces an explicit load error rather
than silently overwriting records. These are trusted authored Lua tables, not an import format
for arbitrary user input. Source declarations stay an array so duplicate identities can be
detected before constructing the index.

## Item identity and snapshots

Each declaration has `itemID`, `variant`, `name`, `forever`, optional `classic`, and
`sourceIDs`. Current entries use variant `base`. A future suffix/bonus/context variant must have
its own explicit key and evidence; the index preserves it rather than overwriting the base item.
Resolving live item links to those variant keys belongs to the later API adapter.

Each snapshot contains `stats` and an `evidence` registry key. The evidence applies only to
the fields present in that snapshot. Stats may include:

| Field | Meaning |
| --- | --- |
| `itemLevel` | Item level, not character level |
| `equipLevel` | Explicitly observed equip requirement |
| `minDamage`, `maxDamage`, `speed` | Base weapon damage and seconds per attack |
| `dps` | Reported, rounded DPS; retain the original precision |
| `school` | Damage school |
| `classIDs` | Explicit class restrictions when established |
| `attributes` | Named numeric bonuses, such as spirit or fireResistance |
| `effects` | Descriptive effects; no scoring or proc model |
| `reportedRequiredLevel` | Historical sheet column, deliberately not an equip requirement |

Missing fields are unknown, never zero, unrestricted, or level 1. An empty effects/requirements
list should only be authored when absence is established; omitted lists remain unknown.
Indexing does not fill missing Forever values from Classic. Historical snapshots have their own
evidence, and the validator rejects cross-game evidence references.

## Acquisition sources

Sources are separately keyed records, referenced by each item's `sourceIDs`. One item can have
multiple sources (Smoldering Wand demonstrates two vendors). A source contains:

- `kind`: quest, vendor, crafting, dungeon, or world.
- `description`, optional `questID`, `npcID`, or `spellID`.
- Optional `minQuestLevel`, `suggestedLevel`, and `professionSkill`; these never become equip level.
- Optional `faction`, `classIDs`, `raceIDs`, and `prerequisiteQuestIDs`.
- `evidence`, `availability`, `requirementsComplete`, and explanatory `notes`.

Prerequisite IDs refer to the external game quest database, not to other catalog source keys.
Only proven mandatory prerequisites belong in that array. A quest series listing alone does
not establish AND/OR or optional breadcrumb semantics; uncertain chains stay in notes for #7.
A later graph can extend the schema for alternatives once those requirements are verified.

`requirementsComplete = false` means the acquisition eligibility information is incomplete.
For example, Deepblaze's source records the site's race names in notes because Forever race IDs
have not been established. It must not be treated as open to every Alliance character.

Availability is `unknown`, `listed`, `verified`, `unavailable`, or `test`. All current sources
are `listed`, with incomplete requirements. Neither an item page nor a successful item query
proves current obtainability.

## Evidence and verification

Evidence records contain `game` (forever/classic), `method` (database/client/historical),
`url`, and `observedOn`. Client measurements also require `build`. Future probe evidence can
link to committed measurement notes. Stats and acquisition deliberately use distinct evidence
keys, even when both cite the same item page. Verifying a tooltip must not promote its source.

`Catalog.IsVerifiedCandidate(data, item)` is a conservative evidence gate for validated catalog
entries. It requires client stat evidence and at least one independently client-verified
acquisition source with complete requirements. It returns false for every current sample.
It does not check character eligibility, freshness against the running build, or calculate an
upgrade; those are later issues. Consumers must perform those checks before recommending items.

## Sample and known gaps

| ID | Wand | Sample source |
| --- | --- | --- |
| 11287 | Lesser Magic Wand | Enchanting |
| 11288 | Greater Magic Wand | Enchanting |
| 5243 | Firebelcher | Deviate Faerie Dragon, Wailing Caverns |
| 5242 | Cinder Wand | Arugal's Folly, Horde |
| 279896 | Deepblaze | Old Ironforge Incursion, restricted Alliance quest |
| 5208 | Smoldering Wand | Stormwind and Orgrimmar vendors |
| 7001 | Gravestone Scepter | Blackfathom Villainy reward sources |
| 5198 | Cookie's Stirring Rod | Cookie, The Deadmines |
| 12984 | Skycaller | World-drop candidate |

Individual item URLs and the original spreadsheet URL are stored with the data. Quest pages
99 and 96393 support the captured quest restrictions. The list page supplies observed recipe
and NPC links where used.

The list's Req. column is not always an equip requirement: Cinder Wand and Deepblaze display 9,
matching their quests' minimum level, while their item tooltips omit a required-level line.
Gravestone Scepter likewise shows 18 in the list/reward quests but no tooltip equip level.
Those three equip levels remain unknown. Classic sheet levels are preserved under
`reportedRequiredLevel` rather than copied into Forever requirements.

No farm rates, market prices, recommended character levels, talent scaling, or current server
availability are asserted. Skycaller's drop observations include other seasons; specific farms
are intentionally not selected. Crafting skills/reagents, full quest chains, class/race IDs,
and remaining vendor/quest alternatives need further evidence. Probe work is #3; broader data
coverage is #7.
