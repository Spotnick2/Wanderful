# WanderfulProbe: item and quest API measurements

Status: **first client run inspected on Forever 1.60.1.70425, enUS, Interface 16001,
WOW_PROJECT_ID 18**. This work is part of #3. The run used check revision 1; revision 2 fixes the
visibility of visual comparisons. The subsequent verify procedure completed successfully with
two visual matches. Original yes/no responses about unseen logs are not accepted as evidence.

## Guide window procedures (#6)

The guide window has separate visual, equipment and settings procedures; these do not replace the completed adapter/API
records. After `pwsh Tools/deploy.ps1 -Probe` and `/reload`, run:

- `/fp steps wand ui`: opens the actual guide, captures visual judgments and screenshots for
  list/details, filters and layout, then checks removal/restoration against the rendered
  automatic baseline without refreshing it. Begin requires an equipped readable wand.
- `/fp steps wand uisave`: opens the guide, asks you to move/resize it and change a filter,
  captures expected settings, requires a full client exit and relaunch, then checks the
  settings adopted at ADDON_LOADED and asks for a visible comparison.

The current ui definition is revision 3 and uisave is revision 3 for the Browse Wands UX follow-up. ui now covers native
item tooltips, Shift comparison/linking, responsive cards, search/sort, the Filters panel,
explicit comparison and separate tracking. The empty step explains that replacing a wand
does not produce an empty slot, and its pending text shows the rendered status and item ID.
uisave revision 3 waits for a tracked wand as well as a deliberate settings change; the captured
signature includes search, sort and the goal. Completed visual/equipment results are recorded below;
the tracked-goal full-exit check remains pending.

The host cannot tell a reload from a full exit. The uisave record therefore includes an explicit
owner confirmation; the numeric comparison alone does not establish process-restart persistence.
Keep the captured size, position and filters unchanged until the post-restart comparison.
The expected sample lives in WanderfulProbeDB, separately from WanderfulDB. Defaults without a
deliberate change and same-session captures cannot pass the restart revision check.
Window visibility and manual baseline selection are intentionally session-only.

Use Note and Shot to record visual problems, including the UI scale and background. Visual
answers save screenshots; numerical checks write their own details. Complete the final reload
to save results. No console reading or chat paste is required. Offline tests model fresh runtime
environments and validate the new definitions against the real private host. They do not claim
an in-game visual or filesystem persistence pass.

### First guide UI run (2026-10-16)

The owner completed ui revision 1 and uisave revision 1 on Forever **1.60.1.70425**, enUS,
using PR #19 runtime e16d18f and pinned LibGlass r9. Saved host records and module STEP lines
agree. Screenshots were inspected locally; raw SavedVariables and screenshots are not committed.

- ui: completed 18:30:24-18:33:13 local, host runs #57-58; 4 yes, 5 done,
  checks **1 FAIL, 1 PASS**. The four visual answers cover the list, details, filters and
  layout. These observations do not replace the owner's requested UX pass.
- Empty-slot check (step 6): completed by hand with rendered automatic/ready item **247789**,
  rather than empty. This remains a failed/unresolved empty-state observation; the record
  does not establish why that wand was still present. Do not count this as a removal pass.
- Original-wand restoration (step 7): PASS, rendered automatic/ready item **11287**.
- uisave: completed 18:33:28-18:34:46 local, host runs #58-60; 2 yes, 6 done,
  check **1 PASS**. The owner confirmed a full client exit/relaunch at step 4.
  Captured revision 10 was adopted as loadedRevision 10 after restart; the settings
  signature matched and the owner confirmed visible persistence.
- Before/after screenshots show the same 820 x 560 window, position and Physical-school
  filter. Empty results are expected for that filter in the current sample.
- Captured images: 183041 (list), 183140 (details), 183227 (filters), 183242 (layout),
  183339 (before exit), 183436 (after exit), all named
  WoWScrnShot_101626_<time>.jpg in the local Screenshots folder.
- Layout/scale and details screenshots are evidence of the exercised view only. The record
  has no UI-scale value or dark-interior note; those variations are not independently established.

The owner will develop the UX direction with ChatGPT. No product UI changes accompany this
evidence update. Issue #6 stays open; the empty-slot case needs a focused follow-up and the
visual design needs the owner's UX pass.

The supplied tooltip also confirms a catalog gap for **Novice's Practice Wand (247789)**:
4-8 Arcane damage, speed 1.50, displayed 4.0 DPS, consistent with earlier live/probe DPS 4.
A crafted copy is visible, but recipe, profession skill, reagents, source and equip-level
requirements remain unverified. This is recorded under catalog issue #7 rather than silently
adding an acquisition recommendation to the nine-item sample.

### Browse Wands run and baseline follow-up (2026-10-16)

The owner completed ui revision 2 using runtime **28d9452**, LibGlass r9 and ForeverProbe
37fd2ea, on **Forever 1.60.1.70450**, enUS, Interface 16001 / WOW_PROJECT_ID 18.
The saved host record and module log agree: 19:10:25-19:12:07 local, runs #62-63,
4 yes, 5 done; checks 1 FAIL and 1 PASS.

- The four visual answers are Yes. Local screenshots 191040, 191058, 191110 and 191126 show
  the card grid, native item/equipped comparison, source filtering and a narrower one-column
  layout. Filenames follow WoWScrnShot_101626_<time>.jpg. Raw images remain local.
- Step 6 has an owner note that "Equipped baseline" does nothing or is unclear. That was a
  real UX ambiguity: the automatic-mode button merely selected the mode already active.
  The follow-up displays plain "Comparing with equipped wand" status in automatic mode;
  a "Use equipped wand" action appears only for a manual/historical comparison.
- Step 6 was completed by hand while the rendered state remained automatic/ready, item 11287.
  Its empty-slot check correctly failed.
- Step 7 immediately recorded PASS for matching item 11287 in that same sample. Revisions 1/2
  did not require a prior observed empty slot, so this result does **not** establish a valid
  removal/restoration transition. The probe now requires empty to have been observed first.
  The same limitation applies to interpreting the older revision-1 restoration check.
- No revision-2 uisave run is present. The saved uisave record remains revision 1 from 18:33
  on build 70425; WanderfulDB currently contains no tracked goal. Saved-goal persistence is
  still pending, rather than inferred from the older geometry/filter pass.
- Native equipped comparison is visible in 191058. The grouped owner answer covers other
  interactions, but that screenshot does not independently establish every search, sort,
  chat-link or tracking action. No numeric UI-scale value or dark-interior note was recorded.

The focused follow-up is /fp steps wand uiequip (revision 1, five steps), leaving the complete
ui record untouched. Prepare restores automatic comparison; the next step explicitly asks for
moving the equipped wand from the character equipment window into a bag. The restoration step
cannot pass without a preceding observed empty slot. /fp steps wand uisave revision 2 remains
the full-exit settings and tracked-goal check. The full ui definition is now revision 3, with
a separate preparation action and explicit inventory instructions; no full visual rerun is
needed just to exercise uiequip.

### Equipment follow-up and settings-capture fix (2026-10-17)

The focused uiequip revision-1 record is complete on Forever **1.60.1.70450**, enUS,
using runtime 71daf2a, LibGlass r9 and ForeverProbe 37fd2ea. Saved host results and
module STEP lines agree: 01:30:02-01:30:40 local, runs #68-69; **5 done, checks: 2 PASS**.

- Preparation recorded automatic/ready item 7607.
- Removal advanced automatically with rendered automatic/empty and no item ID: PASS.
- Restoration advanced automatically with rendered automatic/ready item 7607: PASS.
- The reload resumed from run #68 to #69 and the finish is saved. This establishes the
  previously unresolved rendered empty/restored transition without replacing the visual record.

The owner reported an assertion from uisave revision 2, step 2, in run #70 started 01:30:54.
The capture required a tracked goal and used assert for this ordinary setup condition.
This does not establish a tracking-code failure or a persistence failure; capture had not
succeeded and no current expected-settings sample was available.

uisave revision 3 replaces the combined capture action with separate tracking guidance,
a deliberate-edit/Next step and a readiness wait that captures automatically. Missing tracking
now returns a pending explanation instead of raising a Lua error. The text identifies the
right-hand Track this wand button and the footer Goal indicator, and distinguishes selecting
or comparing a card from tracking it. Readiness requires a change since Begin, so an existing
goal/settings combination cannot be captured prematurely.

Restart only /fp steps wand uisave after deploying and reloading this fix. Its definition has
changed, so the host will stop the old active revision rather than resume at the wrong step.
The completed uiequip result remains valid and needs no repeat. Current tracked-goal persistence
remains pending until the revised full-exit procedure is completed.

## Runtime adapter procedure (#5)

Use /fp steps wand adapter for the runtime validation. The panel records context, checks and
notes; no chat checklist or pasted output is required. This procedure is separate from check
(API experiments) and verify (visual tooltip comparisons), so it preserves those records.

Enable Wanderful, ForeverProbe and WanderfulProbe, deploy with -Probe, then /reload. Equip a
wand out of combat and start the adapter procedure. Follow its buttons and equipment prompts.
Skip the spare-wand/combat actions when unavailable. The panel waits for equipment state and
writes PASS/FAIL details automatically. Finish through its reload step; after the owner reports
completion, read WanderfulProbe.lua and ForeverProbe.lua locally.

The procedure:
- compares the stored automatic baseline with a separate client read;
- checks removal, original-wand restoration and optional replacement;
- selects explicit bundled and historical baselines, and verifies manual selection survives
  an equipment change;
- restores automatic mode and records optional combat/postcombat comparisons.

Wanderful.GetBaseline() observes a copied, scalar-only view without refreshing the adapter.
The probe never calls the product slash command or Refresh while waiting for equipment changes.
Independent item queries can warm cache data, so this procedure does not claim a forced cold
cache or every asynchronous timing path. Same-ID late responses, restricted sentinels and
deadlines are also covered offline. Level-up and non-base variants remain unmeasured unless
separately exercised. A restricted client read paired with an unchanged ready runtime baseline
is recorded as FAIL, not assumed safe from the earlier public-item probe.

The wait step's pending details appear in the host panel. There is no question asking the owner
to inspect hidden logs. All runtime evidence is numeric/scalar text: no full equipped link,
maker name, player identity or raw API table is stored. The read-only API is versioned;
missing/older Wanderful produces an explicit setup error. Manual/automatic actions deliberately
change the session's selected baseline. Finish restores automatic mode; if stopping earlier,
use /wanderful auto when ready to discard a manual selection.

Offline validation loads the actual runtime and the updated private host into the same stubs.
It exercises real command dispatch, the host wait backend, saved PASS/FAIL, skips and notes,
and simulated reload-resume dispatch. That simulation is not a filesystem persistence test.
Probe files remain excluded from the player package. The runtime API has no ForeverProbe
dependency.

### Completed adapter run

On 2026-10-16, adapter revision 1 completed on Forever 1.60.1.70425, enUS,
Interface 16001, WOW_PROJECT_ID 18, using the PR #18 build b70ad63.

- Started at 17:25:56 and finished at 17:27:21 local time.
- Saved status: done. Summary: 15 done; checks: 8 PASS.
- No skipped steps, failed checks, timeouts, step errors or notes were recorded.
- Module log context confirms the build and locale. The adapter record and matching
  ADAPTER/STEP lines agree; no matching API ERROR/MISSING lines were recorded.
- The reload step resumed from host run #46 to #47, and the final step is done in the
  saved record. This proves the results were collected and written, not process-restart
  persistence. Raw SavedVariables remain local and are not committed.

| Scenario | Recorded result |
| --- | --- |
| Initial live baseline | Lesser Magic Wand, item 11287, DPS 11.333333015442; stored adapter and independent client read agree |
| Wand removal | Both report empty; baseline DPS is absent, not zero |
| Original wand restored | Item 11287 and its live DPS return through equipment-driven updates |
| Different wand equipped | Novice's Practice Wand, item 247789, DPS 4; stored adapter and client agree |
| Explicit bundled selection | Manual/bundled item 11287, base variant, derived DPS 11.333333333333 |
| Equipment changed during manual selection | Actual equipment changed from 247789 to 11287; manual/bundled identity and DPS stayed unchanged |
| Historical selection | Manual/historical item 11287, DPS 11.3 |
| Automatic mode restored | Automatic/live item 11287, DPS 11.333333015442 |
| Combat and postcombat | The full-link item DPS remained readable and matched the stored live baseline in both samples |

The small numerical difference between live and bundled DPS is preserved: the live API
reports its own precision, while the catalog derives the mean damage divided by speed.
Both display 11.33 when rounded to two decimals; neither source was promoted to the other.

The passive checks did not call Refresh or the product slash command while waiting for
equipment changes. This establishes the observed removal/restoration/replacement behavior
without a manual status read masking the runtime event path. No restricted item values were
encountered in the combat sample, so this run does not exercise the restricted-item fallback.

Both baseline observations settled ready; truly uncached runtime equipment loading was not
established. Late/same-ID responses, deadlines, unavailable APIs and secret-value failure paths
remain covered by offline tests, with earlier cold-load API evidence documented below.
Level-up and non-base variants were not exercised, and acquisition availability is not asserted.
Together with the focused tests and earlier API evidence, this completes #5's adapter
validation scope. PR #18 records this evidence and closes #5 when merged.

### Adapter procedure revision 2

Revision 2 hardens two failure paths found during review. It does not change the runtime
adapter or invalidate the completed revision-1 run above.

- The manual-survival test now requires an observed starting equipment identity. A confirmed
  empty slot is valid; a secret, malformed or failed item-ID read is not. A refused setup/retry
  clears the earlier transition context, so the same wand becoming readable cannot count as
  an equipment change. Retry once identity is readable, or Skip that test.
- Reloading/relogging during steps before the final save loses session-only setup, including
  the runtime's manual selection. At PLAYER_LOGIN, the module stops that interrupted adapter
  record with a reason to restart /fp steps wand adapter. It does not convert the lost context
  into a timeout/FAIL or silently recreate manual selection. The final save/reload at step 14
  still resumes at the finish step; completed adapter/API/tooltip records are preserved.

Both new regressions failed on the reviewed revision-1 code before the fix. Offline coverage
now includes unreadable-to-readable identity recovery without equipment changes, an explicitly
empty starting slot, and actual reconstruction of the host/runtime/probe Lua environments
while carrying only saved tables. Intermediate restoration/replacement/manual steps stop
cleanly; the final save step resumes. Both login callback orders are exercised. This is a
reload/lifecycle simulation, not a filesystem or process-restart persistence claim.

The revision-2 guard paths have not been exercised in-game. The successful revision-1 run
had readable starting identities and reloaded only at the final save step, so its recorded
observations remain applicable.

### Owner-supplied chat excerpt before the guided procedure

The owner supplied output from 17:06:14 through 17:07:54: automatic/live item 11287 displayed
11.33 DPS; automatic then reported empty/DPS unknown; manual/bundled displayed 11.33 and
manual/historical displayed 11.30; returning to automatic reported empty again. The manual
messages explicitly identified the mode and the auto command.

This is partial owner-reported evidence only. No build/locale, independent inventory view,
replacement, manual-survival equipment change, or combat outcome was supplied. The final
empty result is not itself evidence of a failure or of successful re-equipping. It does not
complete #5. The adapter procedure above supplies the missing repeatable collection workflow.

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
