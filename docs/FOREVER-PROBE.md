# WanderfulProbe: item and quest API measurements

Status: **first client run inspected on Forever 1.60.1.70425, enUS, Interface 16001,
WOW_PROJECT_ID 18**. This work is part of #3. The run used check revision 1; revision 2 fixes the
visibility of visual comparisons. The subsequent verify procedure completed successfully with
two visual matches. Original yes/no responses about unseen logs are not accepted as evidence.

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
panel's Note box for differences and missing fields. The comparison actions show a movable
Wand evidence window with the item name, API DPS, and readable public tooltip text beside a
pinned game tooltip. Combat restriction results are recorded automatically; no yes/no question
asks the owner to inspect logs. Screenshots are local evidence; do
not publish player-identifying screenshots without preparing them appropriately.

For an already-recorded full run, use /fp steps wand verify for just the two visual comparisons.
This saves under a separate procedure key and preserves the original check record. Skip a
comparison if either window is absent. The new display was checked in the completed visual follow-up recorded below.

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

## Findings from the first run

| Question | Observed build / locale | Evidence | Result |
| --- | --- | --- | --- |
| Wand slot and equipment events | 70425 / enUS | Run #40, equipped/removal/replacement snapshots | Wand 247789 was in slot 18; slot 16 held a mace. Removing/restoring the wand generated slot-18 events and empty/item transitions. The event's second boolean must not substitute for rereading equipment. |
| Metadata, stats and public tooltip fields | 70425 / enUS | Run #40, public item calls and sample screenshot | GetItemInfo, GetItemInfoInstant, GetItemStats and GetItemByID returned data. Lesser Magic Wand reported API DPS 11.333333015442; public tooltip text and the screenshot showed 12-22 Arcane, speed 1.50 and displayed DPS 11.3. |
| Cold/warm load success and invalid-ID outcome | 70425 / enUS | Run #40, REQUEST/LOAD lines | IDs 11288, 5243, 5242 and 5198 started cold and received success=true. The other five sample IDs started warm and succeeded. Candidate 2147483647 returned success=false. |
| Combat secrecy and missing values | 70425 / enUS | Run #40, explicit combat snapshot | UnitRangedDamage returned six secret values in combat and readable values outside it. Item ID, item metadata, item DPS and the inspected public tooltip text remained readable for the equipped item. |
| Character quest completion | 70425 / enUS | Run #40, combat and post-combat snapshots | Quests 99, 96393 and 96391 returned false in both snapshots. This does not establish eligibility or account completion. |

The saved run was still active at the reload step in the inspected disk snapshot. It includes the
owner's note that the expected values were not visible. The user's yes/no answers at visual
steps are not treated as reliable independent comparisons. The sample screenshot does show a
tooltip matching the recorded public item values; the equipped comparison screenshot has no
tooltip. No console visibility can be inferred from screenshots because the host hides its own
windows while capturing.

Raw saved files remain local and include account/character-specific context. Do not commit them.
These observations establish behavior only for this run, character, locale and build. They do
not establish all classes, variants, server availability, or future builds. The visual follow-up below supplies the missing visual evidence; the full mechanical run did
not need to be repeated.

## Completed visual follow-up

On 2026-10-15, procedure verify revision 1 completed on build 70425/enUS, after deployment
of e5ce60e (PR #14). Its saved record is separate from the earlier check record:

- Started at 21:37:44; finished at 21:38:36 local time.
- Summary: 2 yes, 4 done. Both comparisons were answered Yes; neither was skipped.
- The reload step recorded a transition from host run #43 to #44, and the final step is done
  in the inspected saved record. No step errors or explanatory failure notes were present.
- Sample screenshot at 21:38:02: the evidence window and pinned Lesser Magic Wand tooltip
  are both visible. Both show 12-22 Arcane damage and speed 1.50. API DPS 11.333333015442
  corresponds to the tooltip's displayed 11.3.
- Equipped screenshot at 21:38:24: both windows identify Novice's Practice Wand, item 247789
  in slot 18, with 4-8 Arcane damage, speed 1.50 and 4.0 DPS (API value 4).

The screenshots were inspected locally and are not committed because they contain identifying
game/chat content. The evidence display includes literal nil markers for absent tooltip columns;
this is developer output and did not prevent these comparisons. Broader UI-scale coverage and
other locales are not established by this run.

Together with the first-run API observations and the passing local tests/host integration, this
completes #3's probe-verification scope. It establishes enough measured behavior for the base
DPS comparison and equipped-wand adapter work. It does not verify acquisition sources or certify
all wand variants or classes.
