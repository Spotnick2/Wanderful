# Wanderful

A wand upgrade guide in development for casters leveling in **World of Warcraft: Forever**.

`/wanderful` opens a movable, resizable guide with a level-sorted wand list and acquisition
details. It compares the equipped wand or an explicit manual baseline using absolute and
percentage **base wand DPS** gains. The nine-wand sample is development data; acquisition
paths are labeled unverified where evidence is incomplete.

Use the level range, class, faction, source, damage school and Upgrades only controls to narrow
the list. Defaults follow your character's class, faction and level (five levels behind through
15 ahead). Press Enter after editing a level; Follow my level restores the moving range.
Select a wand for its source routes, requirements, notes and evidence. Use as baseline selects
bundled Forever data; Use Classic reference explicitly selects historical data. Use equipped
wand restores automatic detection. Filters, window size and position persist account-wide;
manual baselines and whether the window is open are session-only.

Equip eligibility and source access are separate assessments. A numerical upgrade is not proof
that you can obtain the item. Effects, attributes and character modifiers are not scored.
See [catalog evidence](docs/CATALOG.md), [comparison semantics](docs/COMPARISONS.md) and
[equipment detection](docs/EQUIPMENT.md) for limitations. The
[roadmap](https://github.com/Spotnick2/Wanderful/issues/10) tracks catalog expansion and the future
flowchart. This change is the list/details milestone (#6); in-game UI acceptance remains pending.

## Client target and verification

- TOC interface: **16001** (Forever 1.60.1).
- Local API reference: **1.60.1.70425**.
- In-game tested build for item APIs and the equipped adapter: **1.60.1.70425**, enUS.
- The new guide has offline UI coverage; visual readability, scaling and settings after a full
  client exit/relaunch still need the guided in-game run.

The addon embeds **LibGlass r9**, MIT licensed, approved by the owner on 2026-10-16.
Its license and media ship in `Libs/LibGlass-1.0`; no separate player installation is needed.
The window follows `../References/LIBGLASS-WINDOW-STYLING.md`: reflective outer shell,
continuous reading panes, quiet controls and full-opacity text. Shared library defaults stay
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
6. Open `/wanderful`. Run `/fp steps wand ui`, followed by `/fp steps wand uisave`.
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