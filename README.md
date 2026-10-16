# Wanderful

A wand upgrade guide in development for casters leveling in **World of Warcraft: Forever**.

`/wanderful` opens Browse Wands: a movable, resizable window with item-icon cards and a
persistent acquisition panel. Cards show equip level, base DPS, absolute/percentage gain, school
and a source summary. The grid uses two columns when space allows and one in narrower windows.
The nine-wand sample remains development data.

Search names or recorded sources, choose a source type, toggle Upgrades only, and sort by equip
level, DPS or gain. Filters opens school, manual level range and character overrides; class,
faction and nearby levels default from the character. Press Enter after editing a level.
Follow my level restores the range from five levels behind through 15 ahead.

Selecting a card keeps its acquisition instructions visible. Hover a card/icon for the native
WoW item tooltip; Shift or the game's always-compare setting enables equipped-item comparison
where supported. Shift-click inserts a cached item link into an open chat box. Item names,
icons and quality colors use safe client metadata; that metadata never substitutes live tooltip
stats for the catalog's comparison data.

Compare from this wand explicitly selects a bundled Forever baseline. Use equipped wand returns
to automatic detection. The optional Classic reference comparison is under Filters. Track this
wand saves a goal separately; the Goal button returns to it without changing the filters or
baseline, even if the card is hidden by the current filters. Search, sort, filters, tracked goal,
window size and position persist account-wide. Manual baselines, selection and open/closed state
remain session-only.

The acquisition panel shows recorded source information and a quiet provenance line. Evidence
and requirements expands the audit details and links. Unknown recipe materials, quest steps and
locations are not invented from the mockups. Meeting an equip-level requirement does not establish
source access; effects, attributes and character modifiers are not scored.

The accepted UX direction has **Your Path** as the eventual default, with useful level milestones,
an equipped/current-level marker, and optional alternatives. Browse Wands will share selection,
filters, baseline, tracking and acquisition details with that view. This PR implements the Browse
and shared-details milestone (#6). The progression view and recommendation rules remain in
[#8](https://github.com/Spotnick2/Wanderful/issues/8), while acquisition data and the missing
Novice's Practice Wand belong to [#7](https://github.com/Spotnick2/Wanderful/issues/7).

See [catalog evidence](docs/CATALOG.md), [comparison semantics](docs/COMPARISONS.md),
[equipment detection](docs/EQUIPMENT.md) and the
[roadmap](https://github.com/Spotnick2/Wanderful/issues/10) for coverage and limitations.

## Client target and verification

- TOC interface: **16001** (Forever 1.60.1).
- Local API reference: **1.60.1.70450**.
- In-game tested build for item APIs and the equipped adapter: **1.60.1.70425**, enUS.
- Browse Wands visual observations: **1.60.1.70450**, enUS; equipment transition remains pending.
- The original guide passed a full-exit settings check; the card UX and saved-goal additions
  need their updated guided in-game run.

The addon embeds **LibGlass r9**, MIT licensed, approved by the owner on 2026-10-16.
Its license and media ship in `Libs/LibGlass-1.0`; no separate player installation is needed.
The window follows `../References/LIBGLASS-WINDOW-STYLING.md`: reflective outer shell,
continuous reading panes, darker cards, quiet controls and full-opacity text. Shared library defaults stay
untouched. Saved settings are adopted only at Wanderful's own ADDON_LOADED.

## Development setup

1. Clone this repository and create a feature branch from `main`.
2. Install Lua 5.1 (development tooling only).
3. Keep a sibling `../LibGlass` checkout at r9, or set `LIBGLASS` to a suitable checkout.
   CI reads the pin from `.pkgmeta` and tests that exact release. For a fresh checkout using Git
   Bash: `bash tests/fetch_libglass.sh .deps/LibGlass`, then set `LIBGLASS` to that path.
4. Run `pwsh tests/run.ps1`. It compiles owned Lua and the runtime manifests, loads the real
   library through its XML, and runs catalog, comparison, equipment, UI and probe regressions.
   The optional local API dump confirms widget methods; the private sibling ForeverProbe is
   required for the local real-host integration test.
5. Deploy using `pwsh Tools/deploy.ps1 -Probe`, then enable Wanderful, ForeverProbe and
   WanderfulProbe in game and `/reload`. Use `-AddOnsPath` for a different client destination.
   The deployer invokes LibGlass's own deploy script and the shared probe host's deploy script.
6. The focused equipment follow-up is /fp steps wand uiequip; it preserves the full UI record.
   Open `/wanderful`. Run `/fp steps wand ui`, followed by `/fp steps wand uisave`.
   Follow the panels; screenshots, notes and checks are saved without chat transcription.
   The settings procedure requires a **full exit and relaunch** and asks you to confirm that
   action. A simulated reload test is not an in-game persistence pass.

`/wanderful` toggles the window; `/wanderful show` opens it. Existing text commands remain:
`/wanderful status`, `/wanderful auto`, `/wanderful baseline <itemID> [variant]` and
`/wanderful historical <itemID> [variant]`.

`lua Tools/check.lua` compiles the TOC and supported embedded LibGlass XML scripts without
executing them. Missing files, invalid syntax, empty manifests and unsupported entries fail.
CI also fetches the pinned library, dry-runs the packager without upload/release, and checks
the exact zip file set plus library code, license and media against the tested pin.
The TOC's `@project-version@` is substituted by the packager; a development deploy can show
the literal token. Release publication remains a later milestone (#9).

## Pull-request workflow

- Work on a feature branch and open a focused PR into `main`.
- Link the issue. Use `Closes #N` only when its acceptance criteria are met; use `Refs #N`
  while in-game checks remain. Include behavior changes, validation and pending checks.
- Keep each PR to one issue or a documented slice. Stop at milestone boundaries.
- Add dependencies only with approval. LibGlass r9 is approved for the guide window.
- Use `wow-addon-review` for requested reviews and post the review on the PR.
- Deploy after every merge. Probes stay under `Tools/WanderfulProbe/` and are excluded
  from player packages; ForeverProbe is never a runtime dependency.

Local references: `../References`, `../LibGlass` and `../ForeverProbe`.
Read `../References/PROBES.md` and `../ForeverProbe/docs/GUIDE.md` before adding probes.
The separate adapter/API/tooltip procedures and completed evidence are documented in
[docs/FOREVER-PROBE.md](docs/FOREVER-PROBE.md).

Report problems through [GitHub issues](https://github.com/Spotnick2/Wanderful/issues), including
the client build, locale, reproduction steps and any Lua error.