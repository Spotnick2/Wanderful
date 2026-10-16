# Equipped-wand adapter

Equipment.lua exposes ns.Equipment.New(env, catalog, changed). Runtime.lua creates ns.Equipped
and forwards client events. The adapter is session-only and adds no SavedVariables or dependencies.
The optional changed callback receives a new state after each refresh. Consumers read
ns.Equipped.state.snapshot as the comparison baseline; an absent snapshot means no comparison.

## State and provenance

State includes mode (automatic/manual), status, provenance, optional itemID/link/variant,
snapshot, reason, and level. levelStatus is unknown/restricted when level cannot be read.
Only guarded, plain values leave the client boundary. No returned API tables are retained.

| Status | Meaning |
| --- | --- |
| ready | A numerical baseline is available; provenance still matters |
| loading | One item request is pending, with an eight-second deadline |
| empty | Slot 18 has no item; there is no zero-DPS baseline |
| not_wand | Numeric item class/subclass identifies a different weapon |
| unknown | Missing, malformed, or exhausted item data |
| restricted | A required value is secret, or secrecy cannot be inspected |
| unavailable | An API, event registration, or bounded loading facility is unavailable |
| failed | The item request threw an error |

Live snapshots use only C_Item.GetItemStats(fullEquippedLink).ITEM_MOD_DAMAGE_PER_SECOND_SHORT,
after checking the equipped ID, full link, item class/subclass and DPS for secrets and validity.
DPS zero is preserved as an explicitly reported zero; Comparison never divides by it.
GetItemInfoInstant's numeric weapon class 2 and wand subclass 19 establish the item type without
localized names. No UnitRangedDamage, localized tooltip parsing, or ID-only variant substitution
is used. A live snapshot carries an evidence table with game, method and the readable build.
This is a current API observation, not proof of item/source availability or universal accuracy.

Manual snapshots retain the catalog's evidence key. Provenance is bundled for the Forever
snapshot and historical for an explicitly selected Classic snapshot. Neither is silently
promoted to live evidence. An automatic failure never substitutes a catalog base item for a
potential equipped variant. The guide's catalog remains available independently of live APIs.

## Refresh and loading

Refresh on PLAYER_LOGIN, PLAYER_ENTERING_WORLD, slot-18 PLAYER_EQUIPMENT_CHANGED,
PLAYER_LEVEL_UP, and PLAYER_REGEN_ENABLED. Equipment events always reread the slot; their
hasCurrent argument is not an item identifier. Level-up uses the guarded event level because
UnitLevel can still report the previous level during dispatch. Postcombat refresh can recover
values that were restricted in combat. No OnUpdate or repeated polling is installed.

An item with missing metadata, link or DPS gets one load request per observed ID/link identity.
Duplicate events/status reads do not extend the deadline or retry an exhausted request.
A newly readable full link can establish a new identity after an initial missing-link request.
A deliberate /wanderful auto starts a fresh attempt.

Both ITEM_DATA_LOAD_RESULT and GET_ITEM_INFO_RECEIVED are hints to reread current equipment,
never sources of baseline identity or values. A change of ID/link or mode invalidates deadlines.
Old responses cannot restore an old wand, including after removal. Events have no generation
tag; a late response for the same ID is indistinguishable from a new response. Consequently
even a false event does not terminate the pending request: it triggers a reread, and unresolved
data remains pending until the deadline. Timeout yields unknown/load_exhausted, not a claim
that an item does not exist. Request/timer exceptions and missing facilities end loading safely.

## Commands

- /wanderful or /wanderful status: refresh and print baseline mode, state, provenance and DPS.
- /wanderful baseline 11287: select the bundled Forever base variant explicitly.
- /wanderful baseline <itemID> <variant>: select a known catalog variant.
- /wanderful historical 11287: explicitly select the historical Classic reference.
- /wanderful auto: discard manual selection and retry equipped detection.

Manual output identifies the selection and prints the command to return to automatic mode.
Equipment, level and load events never replace a manual selection. Reload resets to automatic.
These commands expose the adapter while the list UI is tracked in #6.

## Evidence and validation

The local ../References/forever-api-1.60.1.70425.md declares the C_Item signatures, load events,
level/equipment events, issecretvalue and UnitLevel. The public API field and slot-18 behavior
were measured on 70425/enUS in docs/FOREVER-PROBE.md. Full-link variant handling is conservative:
the probe verified base public-item queries, not every suffix/bonus link. A live full-link
query must supply its own readable DPS; it cannot borrow a base catalog number.

Run pwsh tests/run.ps1. Adapter tests exercise replacement/removal, stale same/different-ID
responses, bounded requests, secret sentinels, malformed values, unavailable APIs, manual/
historical selection, level events and real TOC/slash/event wiring.

The adapter itself has not yet been exercised through a completed guided run. The prior API
probe is evidence for the API choices, not an integration pass for this implementation.

For the in-game validation, use /fp steps wand adapter after deploying with -Probe and reloading.
The panel guides removal/restoration, optional replacement, explicit manual/historical
selection and optional combat. It records build/locale, observations, checks, skips and notes.
Follow the panel through its reload step; results are read from local SavedVariables, not
pasted from chat. See docs/FOREVER-PROBE.md for the collection and interpretation details.
Do not replace this procedure with a manual chat checklist.

Runtime.lua exposes the version-1 Wanderful API:
- GetBaseline() returns a fresh scalar view of the stored mode, status, provenance, item ID,
  variant, DPS, reason and level. It performs no client read or refresh and exposes no link,
  snapshot table or mutable adapter object.
- SelectManualBaseline(itemID, variant, historical) explicitly selects a session baseline.
- UseAutomaticBaseline() explicitly discards manual selection and retries equipped detection.

The probe uses these actions without chat output. Its independent client reads are separate
from the passive observation, so a missing equipment event remains observable. The facade
adds no runtime dependency on ForeverProbe.

Full-link variants, level-up behavior and truly uncached equipment still need client coverage
when those scenarios can be exercised; a warm-cache pass does not establish them.
