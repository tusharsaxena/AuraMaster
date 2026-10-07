# 04 — Technical design: Ka0s Aura Master (2026-10-07)

How to close each open deviation in `02_DEVIATIONS.md`. Nothing here changes stored data, a slash
verb or a schema path. No `NS.SCHEMA_VERSION` bump is owed, and nothing needs an in-client change
that a player would notice. AM-38 and AM-39 touch code. The rest are docs, config, the issue store or
the release record.

## AM-21 — the missing re-vendor bundle

- Add one span bundle, `docs/revendor/2026-10-07-v1.69.0-v1.70.0/`, holding `01_DELTA.md` and `05_SUMMARY.md` only (audit-review-history's span shape).
  - `01_DELTA.md` line 1 must read exactly `Delta: LibKa0s v1.68.1 -> v1.70.0 (span: v1.68.1 v1.69.0 v1.70.0)`. The base is v1.68.1, the last recorded tag (`docs/revendor/2026-10-04-v1.68.1/`). Below it, record what each tag brought: v1.69.0 added `WidgetsLineChart.lua` and kit 37; v1.70.0 added `WidgetsAutocomplete.lua`.
  - `05_SUMMARY.md` gets one line per tag, *carried by sweep, nothing adopted*, since this addon wires neither `LineChart` nor `Autocomplete`.
- **Risk.** None, because the bundle is docs only. Re-run E-7's loop afterwards. It must print nothing.

## AM-25 — spill Module Map

- Move `docs/ARCHITECTURE.md:73-134` into `docs/data-flow.md`, under a new `## Placement, attachment and the drag` heading. That text covers the attach chain, hang modes, the font primer, test mode versus unlock, the snap driver, the detach leeway, the strip tooltip and the label.
- Add any per-file facts it carries to the matching `docs/module-map.md` rows.
- In the hub, leave 3–5 lines naming the engine-facing modules and the placement modules, plus the existing single link at `:136`.
- **Target.** Module Map at or under about 40 lines, and the hub under about 400.
- **Risk.** The docs gate (`tests/test_docs.lua`) checks citations. Every `file:line` that moves must be re-checked in its new home.

## AM-31 — complexity: one function, then a sighted release record

- **`logCandidates`** (`modules/Anchors_Snap.lua:892-912`, CCN 18). This is guarding and defaulting, not tangled flow, so the fix removes decisions rather than respelling them (performance-§11):
  - Write a characterization case first (testing-§13). With logging on, drive one drag start over two eligible targets and one ineligible one, and assert the exact `[Anchor]` line.
  - Extract `local function targetText(dragged, t)` at module level. It returns `ineligibleWhy(dragged, t)` or the parent rect text. That moves one `if` and one `and/or` pair out of the loop body.
  - Bind `local own = rectOrNone(ownFootprint(dragged, logRect))` through a one-line module-level helper, `rectOrNone(ok)`. It is used twice, so the two `x and rectText(logRect) or "no rect"` sites become one.
  - Do **not** build a table inside the function (#43), and do **not** rewrite `a or b` as `if` (#52).
  - Expected CCN after the change is about 10. Re-run `--suite complexity --no-bundle` to confirm.
- **The record.** At the next release (or sooner), run `bash tests/_kit/run-automated-tests.sh` through `ka0s-bounded` to produce a sighted bundle.
  - The manifest must carry `"blindFiles": 0`.
  - Write a disposition for each new band file: `modules/Anchors_Snap.lua` (1126) and `tests/test_anchors_drag.lua` (1490).
  - The test file is 10 lines from the cap, so its disposition should name a peel seam now (for example, the detach-leeway cases into `tests/test_anchors_detach.lua`), not *Accepted*.

## AM-35 — ignore `.claude`

- In `.pkgmeta:12-13`, replace the commented template lines with `  - .claude          # dev-only: agent tooling (.claude/commands/aura-spells-review.md); never loaded by the client`.
- Re-run packaging checks (a)–(c). (a) and (b) must print nothing except `UNACCOUNTED — .git`.

## AM-36 — relabel #22

- Run `gh issue edit 22 --remove-label state:untriaged --add-label state:done`. It is a single write, so there is nothing to throttle.

## AM-37 — the doc and comment sweep

| Site | Change |
|---|---|
| `docs/ARCHITECTURE.md:216-218` | "…shared with the Master controls *Test mode* checkbox and the launcher menu's *Test mode* entry." |
| `docs/settings-panel.md:148-149` | "…the one writer `/am test` and the launcher menu's *Test mode* entry also use" |
| `modules/Preview.lua:27` | "The Master controls checkbox, `/am test` and the launcher menu's *Test mode* entry all come through here." |
| `settings/General.lua:31-32`, `:117` | Change the same phrase the same way. |
| `docs/ARCHITECTURE.md:384` | "The `Page \| Covers` table (here `Page \| Tabs \| Covers`), the page → tab → row tree, …" |
| `tests/test_render_coverage.lua:24-25` | Point at the kit's `test_lizard_sighted`, or drop the reason now that the sighted shadow handles `#`. |

- All of these are comment or doc edits, so no behavior changes.
- After the sweep, `grep -rniE "left[- ]click" docs settings modules core` must return only the launcher's own "opens the settings panel" lines and the frame-picker and close-mark lines.

## AM-38 — the degraded help row

- In `settings/Slash.lua`'s `if not SlashLib then` branch:
  - Delete the `FormatRow` member at `:423`, leaving `SlashLib = {}`.
  - At `:441`, write `out[#out + 1] = "/am " .. e[1] .. "  " .. e[2]`.
- Check every other `SlashLib.FormatRow` reader on the degraded path, such as a landing-page row builder. The E-14 grep finds only `:441`.
- **Test.** In the degraded-env suite (`tests/degraded_env.lua` and its consumers), assert that a help row has no `—` and no `|c` escape. It should go red under the current stub.
- **Risk.** Only a library-absent load sees this.

## AM-39 — migration lines that land

- In `core/Database.lua`, switch the ladder's per-step lines (`:1252`–`:1346`), the stamp line (`:1377`) and the seed line (`:1405`) from `NS.Debug("Migrate", fmt, …)` to `NS.DebugLog.DebugAtEnable("Migrate", fmt, …)`. Keep the gate's cheapness: the queue builds the line only when called, and it is called once per step at login.
- The stub already answers `DebugAtEnable` with `false` (`core/DebugLogSetup.lua:60`), so the degraded path is unchanged.
- `PrepareProfile`'s `[Migrate]` lines at `:153`/`:198` can also run on a profile switch, while logging may be on. Leave them on the gated sink.
- **Test.** Run the migration with logging off, then `SetEnabled(true)`. Assert that the `[Migrate] v… -> v…` line follows the `[Init]` summary. It should go red under the current code. The queue's cap is 32; a 12-step ladder plus one stamp line per step is under it.

## AM-40 — screenshots in the package (owner's call)

- If accepted, add `  - media/screenshots  # README/store images; the client cannot load PNG/JPG and the README links forgecdn` to `.pkgmeta`.
- Propose the same line upstream in packaging's minimum template, so every addon gets it.

## Ordering constraints

- AM-37 before AM-25: the sweep edits `docs/ARCHITECTURE.md:216-218`, which is outside the moved block. Doing it first keeps the diff of the move clean.
- AM-31's characterization test before its refactor.
- AM-31's sighted record **last**, after AM-38 and AM-39 land, so the bundle measures the final tree.
