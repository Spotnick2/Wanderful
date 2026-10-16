# WanderfulProbe: item and quest API measurements

Status: **procedure implemented; no in-game findings recorded yet**. This work is part of #3.
The planning reference is Forever 1.60.1.70374 / Interface 16001. It is not a measured build for
this probe. Every observation logs GetBuildInfo, locale and combat context; the host also keeps
its session baseline. Do not promote catalog data or API assumptions until actual evidence is read.

## Setup and validation

The host contract is the sibling ForeverProbe checkout's docs/GUIDE.md. It remains a private,
local development tool. This module is not a runtime dependency or release external.

From the Wanderful repository root:

    pwsh tests/run.ps1
    pwsh Tools/deploy.ps1 -Probe

The runner requires Lua 5.1 and luac on PATH (or use -Lua/-Luac). The real-host integration test
uses $env:FOREVERPROBE, otherwise ../ForeverProbe. It loads that host's TOC into the same client
stubs, then checks real command dispatch, saved-variable adoption, log clearing, and guided
records without UI rendering. CI runs the measurement/manifest tests but explicitly skips the
real-host integration if the private checkout is absent. No host code or credentials are fetched
into CI.

Deployment requires an existing AddOns directory. -AddOnsPath overrides the default Forever
directory. -Probe deploys Wanderful plus the module; -ProbeOnly deploys just the module and host.
Both call the host's own deploy first and stop if it refuses. Only listed runtime files are
copied. Neither script recursively deletes folders. The player package excludes all of Tools.

## Guided run

After deployment, enable the addons and /reload, then run:

    /fp steps wand check

The panel walks through context, item loading, a public tooltip comparison, equipped/empty/
replacement slots, combat observations, character quest completion, and a reload to save.
The initial load experiment runs before the procedure opens sample tooltips. It reports warm,
cold, or unknown cache state; it cannot force an uncached item. If all samples are warm, cold
loading remains unmeasured. The invalid-ID candidate is 2147483647, not an assertion about what
IDs the server supports.

Use Skip for unavailable actions, such as lacking a spare wand or a combat encounter. Use the
panel's Note box for differences and missing fields. Yes to the combat restriction question
means a restriction was observed, not a failed procedure. Screenshots are local evidence; do
not publish player-identifying screenshots without preparing them appropriately.

One-off commands are /fp wand state, item <ID>, load, quests, watch, stop, and clear. Equipment
watching captures at most 20 relevant events per activation. It starts only on request. Item
requests have an eight-second deadline; replacing a batch invalidates its previous deadline.

The module log is capped at 3000 lines. An unusually large tooltip/event run can trim old lines;
repeat a smaller one-off experiment if earlier evidence has been trimmed.

## Reading the saved evidence

After the procedure's reload, inspect these files under the account's SavedVariables directory:

- WanderfulProbe.lua: bound log, context, item calls, requests, events, and STEP lines.
- ForeverProbe.lua: steps.records["WanderfulProbe/check"], including outcomes, notes, skipped
  steps, errors and screenshots, plus the host's client baseline and blocked-action watcher.

Use ../ForeverProbe/Tools/screenshots.ps1 -Module WanderfulProbe to locate recorded screenshots.
After documenting findings, only that script's -Remove option should remove probe screenshots.
Do not delete the owner's unrelated screenshots.

## Interpretation

- Both slots 18 and 16 and their named slot queries are recorded. No slot is declared correct
  from a Classic/Retail assumption; use the item identity and actual equipment changes.
- Empty, unavailable, unexpected, and restricted equipment values are distinct.
- Public item tooltips include structured line/argument data, up to 40 lines. Inventory tooltip
  text is logged by shape to avoid saving maker names. An equipped item's public ID query does
  not preserve suffix/bonus variants; the inventory link is logged for later investigation.
- Secret values go only through the host's Show/Shape/Describe helpers. Raw return tables are
  never stored by this module. No localized damage parsing or arithmetic is attempted.
- UnitRangedDamage is diagnostic and can include character modifiers. It is not base item DPS.
- A request returning normally is not load success. Success/failure events are tracked only for
  requested IDs. Secret or malformed payloads stay unresolved until the deadline. A timeout
  does not establish that an item is invalid or that a system is unavailable.
- Late events for an earlier request of the same ID have no generation tag in the client
  payload. Avoid overlapping manual experiments; cache state and timeline are evidence.
- Character quest completion is not proof of quest eligibility, source availability or account
  completion. The probe intentionally avoids account-level substitution.
- The probe does not define account-wide facts: these observations depend on equipment, cache,
  character, locale, or combat.

## Findings to fill after the first run

| Question | Observed build / locale | Evidence | Result |
| --- | --- | --- | --- |
| Wand slot and equipment events | Pending | Pending | Pending |
| Metadata, stats and public tooltip fields | Pending | Pending | Pending |
| Cold/warm load success and invalid-ID outcome | Pending | Pending | Pending |
| Combat secrecy and missing values | Pending | Pending | Pending |
| Character quest completion | Pending | Pending | Pending |

Record actual values, missing APIs and unresolved cases here after reading the saved files.
Offline stubs and a successful CI run establish test behavior, not Forever runtime behavior.
