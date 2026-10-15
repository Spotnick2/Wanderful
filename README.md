# Wanderful

A wand upgrade guide in development for casters leveling in **World of Warcraft: Forever**.

This bootstrap only registers `/wanderful`, which prints a development-status message. It does
not yet contain a wand catalog, recommendations, comparisons, or a guide window.

The [roadmap](https://github.com/Spotnick2/Wanderful/issues/10) tracks the planned level list,
acquisition details, and upgrade flowchart.

## Client target and verification

- TOC interface: **16001** (Forever 1.60.1).
- Reference client/API dump inspected during planning: **1.60.1.70374**.
- In-game tested build: **none yet; runtime validation is pending**.

The reference build is not a compatibility guarantee. Recheck the installed build when testing.
The addon uses a plain `Wanderful.toc`; it has no runtime dependencies or saved settings.

## Development setup

1. Clone `https://github.com/Spotnick2/Wanderful.git` and create a feature branch from `main`.
2. Install Lua 5.1 for local syntax validation (development tooling only).
3. From the repository root, run:

   ```sh
   lua Tools/check.lua
   luac -p Tools/check.lua
   ```

   `Tools/check.lua` compiles every Lua file named by the TOC without running it. Missing files,
   invalid syntax, an empty runtime manifest, and unsupported entries fail validation. Extend
   the checker before introducing XML manifests. CI also compiles all tracked Lua and confirms
   that a deliberately invalid runtime file is rejected.

4. For an in-game check, create an `Interface/AddOns/Wanderful` folder under `_classic_beta_`
   and copy **only `Wanderful.toc` and `Core.lua`** into it. Enable the addon and `/reload`.
5. Run `/wanderful` and verify that exactly one development-status message appears with no Lua
   error. Record `GetBuildInfo()` and the locale in the PR; do not report syntax checks as an
   in-game pass.

The source TOC uses `@project-version@` for future packager substitution. A development copy can
show that literal version. Release preparation and package verification are tracked in
[#9](https://github.com/Spotnick2/Wanderful/issues/9); no release automation is configured here.
`.pkgmeta` excludes tools, probes, tests, and documentation from future packages.

## Pull-request workflow

- Work on a feature branch and open a focused PR into `main`; do not commit implementation
  directly to `main`. The initial repository seed is the bootstrap exception.
- Link the issue. Use `Closes #N` only when its acceptance criteria are met; use `Refs #N` for
  partial work. Include behavior changes, validation results, and pending in-game checks.
- Keep each PR to one issue or a documented slice. Stop at milestone boundaries to review
  findings and agree on the next scope.
- Add dependencies only with approval. LibGlass is proposed for a later UI milestone.
- Future probes belong under `Tools/WanderfulProbe/` and use the sibling ForeverProbe host;
  they are development tools and must never become player dependencies.

Local reference projects, when available: `../References`, `../LibGlass`, and `../ForeverProbe`.
Read `../References/PROBES.md` and `../ForeverProbe/docs/GUIDE.md` before adding probes.

Report problems through [GitHub issues](https://github.com/Spotnick2/Wanderful/issues), including
the client build, locale, reproduction steps, and any Lua error.
