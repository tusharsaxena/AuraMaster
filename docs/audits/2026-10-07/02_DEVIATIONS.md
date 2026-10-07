# 02 — Deviations: Ka0s Aura Master (2026-10-07)

Audited against **Ka0s WoW Addon Standard v2.76.1 (2026-10-07)**. The deviation-ID prefix is **`AM-`**,
reused from `docs/audits/2026-09-11/` and `docs/audits/2026-09-23/`. A recurring gap keeps its old ID;
new IDs run from `AM-37`.

**How grades are set.** Each grade follows `AUDIT.md` step 5 and measures impact, not how strongly the
rule is worded. A failure that lives only in docs, config or a library-absent branch is graded Low or
Info even when it breaks a MUST, and the entry still names that MUST. Since v2.65.0 the playbook
hard-codes no grade, so this run carries no exception like the previous run's AM-21.

## Tally

The **headline tally counts roots only**. This run has **no `derived from` dependents**, so the
two totals are equal. Both are stated anyway, as the rule requires.

| | High | Medium | Low | Info | Total |
|---|---|---|---|---|---|
| **Headline (roots only)** | 0 | 0 | 7 | 2 | **9** |
| Total including dependents | 0 | 0 | 7 | 2 | **9** |

| MUST failures | High | Medium | Low | Total |
|---|---|---|---|---|
| **Roots only** | 0 | 0 | 5 | **5** |
| Including dependents | 0 | 0 | 5 | **5** |

- The five MUST failures are AM-21, AM-25 (the spill half), AM-35, AM-37 and AM-38.
- AM-31 and AM-39 fail a SHOULD. AM-31 becomes a MUST the moment a release is cut, because the release gate refuses it.
- AM-36 and AM-40 are Info observations.

**Recorded deviations** are gaps a ratified register row already covers. They are accepted and are not
counted above:

- **AM-03** (`options-ui-§17`, row decided 2026-09-12, `docs/ARCHITECTURE.md:422`).

**Verdict: minor deviations.** No entry is reachable by a player as a defect.

- The disabled state genuinely stands down, and every timer is now a cancelable handle.
- Every registration goes through the library's `SafeRegister*` family.
- Both vendored payloads diff clean at v1.70.0.
- The working tree agrees with its line-ending pin.

What remains is record-keeping (AM-21, AM-31, AM-36), doc drift (AM-25, AM-37), one packaging line
(AM-35), one library-absent stub shape (AM-38) and one debug-coverage gap (AM-39).

---

## Roots

### AM-21 — `audit-review-history` (*A re-vendor commit implies a bundle*) — **Low** — MUST (recurs, narrower)

**What is wrong.** Two LibKa0s tags were vendored with no `docs/revendor/` bundle and no register row:
**v1.69.0** (`3656914`, 2026-10-06) and **v1.70.0** (`c070393`, 2026-10-07).

- **Counting window:** from the store's first bundle (2026-09-12) to HEAD.
- **Vendored:** 43 distinct tags, read from the provenance line at each commit that touches `libs/LibKa0s` or `tests/_kit`.
- **Recorded:** 42 distinct tags. One of them, v1.45.0, is recorded but was never vendored here.

The whole span the previous run's AM-21 filed (v1.35.0–v1.54.2) is now recorded, by
`docs/revendor/2026-09-24-v1.35.0-v1.54.2/` (E-7).

**Grade.** Doc-only, so Low. The entry names the `audit-review-history` MUST.

**Fix direction.** Add one span bundle, `docs/revendor/2026-10-07-v1.69.0-v1.70.0/`, with `01_DELTA.md`.
Line 1 must read exactly `Delta: LibKa0s v1.68.1 -> v1.70.0 (span: v1.68.1 v1.69.0 v1.70.0)`. The
bundle also needs `05_SUMMARY.md`, with one line per tag. Alternatively, file two single-tag bundles.

### AM-25 — `documentation-§3` (the hub's spill rule) — **Low** — MUST (spill) / SHOULD (≈400 lines) (recurs, narrower)

**What is wrong.** `docs/ARCHITECTURE.md` is **426 lines**, against a SHOULD of about 400. Its mandated
**Module Map** section runs **94 lines** (`:44-137`), past the ~60-line MUST that it spill into
`module-map.md`. It keeps the link, but most of its body (`:73-134`) is a single narrative of the
drag-and-snap driver, the detach leeway, the tooltip placement and the label. That is data-flow detail,
not a module map. Every other mandated section is at or under 58 lines (E-15).

The previous run's four over-length sections (Settings Schema, Overview, Known Limitations and Taint
Notes) have all spilled.

**Fix direction.** Move `:73-134`, the drag/snap/detach/tooltip narrative, into `docs/data-flow.md`
(or `docs/module-map.md`'s per-module rows). Leave a few lines naming the engine-facing modules and one
link. That brings the hub back under about 400 lines.

### AM-31 — `performance-§10` / `automated-tests-§3` / `automated-tests-§4` — **Low** — SHOULD mid-cycle (the release gate is a MUST when the release comes) (recurs)

**What is wrong.** The complexity record is stale and was measured blind.

**The record.** The newest run, `20260927-214918`, measured commit `b5208f3`, which is **173 commits
behind HEAD**. That run predates the sighted kit (revision 35), and its `manifest.json` carries no
`blindFiles`, so its "0 warnings, max CCN 15" is an unsighted figure.

**Measured now** with the runner (`--suite complexity --no-bundle`, kit 37, E-10):

| | Recorded (`20260927-214918`) | Now (sighted) |
|---|---|---|
| NLOC | 41,031 | 49,655 |
| Functions | 4,472 | 5,443 |
| Functions over CCN 15 | 0 | **1** |
| Max CCN | 15 | 18 |
| Files in the 1000–1500 band | 10 | 12 |
| Blind files | (not recorded) | 0 |

- **Newly warned:** `logCandidates`, CCN 18 (`modules/Anchors_Snap.lua:892-912`). It was added in `cb766da` (DD-21, 2026-10-03). The score comes from **dense guarding and defaulting, not tangled control flow**. Its real branches are an early-return gate, two loops and one `if`. The rest of the 18 is `and`/`or` short-circuits:
  - `not (a and b and c)` in the gate;
  - `x and y or "no rect"`, twice;
  - `what and (...) or ""`;
  - `#parts > 0 and ... or "none"`.
- **Newly in the band:** `modules/Anchors_Snap.lua` (1126 lines) and `tests/test_anchors_drag.lua` (1490 lines, 10 lines under the cap).
- **Release gate:** the next release would be refused, because it requires zero functions above CCN 15.

**Not filed:** the watch list. All ten band entries in `RESULTS.md` read *Accepted*. Each has been
carried across **two** release runs (0.1.0→1.0.0 and 1.0.0→1.0.1), which is below anti-pattern #53's
three. Ten rows can be read in one pass.

**Fix direction.**

- Fold `logCandidates`' guards into named locals, or move the per-target `why` text into a small module-level helper named for what it answers (for example `targetRectText(dragged, t)`). Avoid a body-dump helper (#52).
- `logCandidates` is a debug-only formatter, so a characterization case on its output line is owed first (testing-§13).
- Then cut a sighted run of the four suites and record dispositions for the two new band files.

### AM-35 — `packaging` (the strong form) — **Low** — MUST (recurs, inverted)

**What is wrong.** The repo now **has** a tracked `.claude/` directory: `.claude/commands/aura-spells-review.md`,
added in `d093af8` (SID-9, 2026-09-24). But its `.pkgmeta` line is still the template's commented-out
form (`.pkgmeta:12-13`). packaging check (b) prints `UNACCOUNTED — .claude` (E-9), and check (a)
prints `NOT IGNORED — .claude`.

packaging says plainly that a commented-out line beside a directory the repo has "satisfies
**neither** branch and fails this MUST". As a result, the packaged addon ships the agent command file.

Last run's AM-35 was the opposite case: an ignore line for a `.claude/` that did not exist. The fix
for that one (comment the line out) was right until SID-9 added the directory.

**Grade.** Config only, so Low. The cost is one stray dev file in every player's download.

**Fix direction.** Uncomment the line as `  - .claude          # dev-only: agent tooling (.claude/commands/); never loaded by the client`.

### AM-36 — `audit-review-history` (the status-label vocabulary) — **Info** (recurs)

**What is wrong.** Issue **#22** ("Drag-and-drop container attachment") is **closed** but labelled
`state:untriaged`, which is an open-status label (E-17). The work shipped: the hub documents
drag-and-drop attachment at `docs/ARCHITECTURE.md:91-127` (issue #22, `modules/Anchors_Snap.lua`). The
previous run's instance, #10, is fixed.

**Fix direction.** Relabel #22 `state:done`. The issue-store write commands repair this.

### AM-37 — `documentation-§5` (keep docs in sync) — **Low** — MUST (new)

**What is wrong.** Since standard v2.67.0 and Launcher minor 4, the launcher's left-click opens the
settings panel and test mode is an entry in the right-click menu. **Six live sites still say the
left-click switches test mode** (E-15):

- `docs/ARCHITECTURE.md:216-218`: "`/am test` is the test mode's verb … shared with the Master controls *Test mode* checkbox and the minimap button's left click." This contradicts the hub's own `## Launcher`, eleven lines below (`:268`).
- `docs/settings-panel.md:148-149`: "the one writer `/am test` and the minimap button's left click also use".
- `modules/Preview.lua:27`: "The Master controls checkbox, `/am test` and the launcher's left-click all come through here."
- `settings/General.lua:31-32`: "the one writer `/am test` and the launcher's left-click also use".
- `settings/General.lua:117`: "the same refusal `/am test` and the launcher's left click answer".

Two more drifted lines have the same cause:

- `docs/ARCHITECTURE.md:384`, the Documentation map's `settings-panel.md` row, names "The `Tab | Covers` table". documentation-§3 renamed it `Page | Covers` in v2.65.0, and the doc itself carries a `Page | Tabs | Covers` table (`docs/settings-panel.md:12`).
- `tests/test_render_coverage.lua:24-25` points the reader at a `#` scanner in `tests/test_lintconfig.lua` that `:205` of that file says is retired.

**Grade.** Doc and comment only, so Low. A reader acting on them goes looking for a left-click path
that does not exist.

**Fix direction.** One sweep:

- In each of the five sites, replace "the launcher's left-click" with "the launcher menu's *Test mode* entry".
- Correct the map row to `Page | Covers`.
- Repoint the test comment at `test_lizard_sighted`.

### AM-38 — `slash-commands-§1` (the stub MUST NOT copy `FormatRow`) — **Low** — MUST (new)

**What is wrong.** The library-absent Slash stub defines
`SlashLib = { FormatRow = function(cmd, desc) return cmd .. " — " .. desc end }`
(`settings/Slash.lua:423`), and its help and landing rows call it (`:441`). That reproduces the
library's row shape: an em dash between command and description, as `libs/LibKa0s/Slash.lua:137` does,
minus the color.

The v2.65.0 text is explicit: "**In particular it MUST NOT copy `FormatRow`.** A degraded help row
prints `cmd  desc` plainly, with no gold command and no em dash."

**Grade.** Low. It is reachable only on a library-absent install, and the line it prints is
readable.

**Fix direction.** Drop the `FormatRow` member. Build the degraded row inline as `"/am " .. e[1] .. "  " .. e[2]`
(two spaces, no dash). Pin it in the degraded-env suite.

### AM-39 — `debug-logging-§8` (*Dependencies* and the at-enable queue) — **Low** — SHOULD (new)

**What is wrong.** Every migration and seeding line the schema runner writes goes through the gated
sink, `NS.Debug("Migrate", …)`:

- each ladder step's summary (`core/Database.lua:1252`, `:1260`, `:1274`, `:1290`, `:1298`, `:1306`, `:1314`, `:1322`, `:1330`, `:1338`, `:1346`);
- the stamp advance, `[Migrate] v%s -> v%s` (`:1377`);
- the starter seed (`:1405`).

The runner is called only from `NS:InitDB()` (`core/Database.lua:292`), which runs at `OnInitialize`
(`core/AuraMaster.lua:27`). At that point the session flag is `false` (`core/State.lua:19`), so **not one
of these lines can ever land**.

A player reporting that settings changed after an update cannot show the migration in a log. A
*failed* step still prints to chat (`core/Database.lua:1373-1374`), so errors are covered. Successful migrations are
invisible.

debug-logging-§8 says a state line written while the flag is off "**SHOULD** go through the console's
at-enable queue, `DebugAtEnable`". The DebugLog console is built before `core/Database.lua` loads, so
the queue is available.

**Fix direction.** Route the ladder's per-step and stamp lines, and the seed line, through
`NS.DebugLog.DebugAtEnable("Migrate", …)`, which is bounded at 32 and states the overflow. The
alternative is to fold them into one `[Init]` note ("migrated v9 → v12 at login"). The stub already
answers `DebugAtEnable`.

### AM-40 — `packaging` / `layout-§4` (observation) — **Info** (new)

**What is wrong.** No rule fails here. `media/screenshots/` holds seven PNG and JPG files totalling
**26 MB** (E-9). `.pkgmeta` does not ignore them (it ignores only `media/logos/*.png|*.jpg`), so they ship
in every player's download.

The client cannot load PNG or JPG. The README links its screenshots from `media.forgecdn.net`, not
from this folder (`README.md:27-40`). layout-§4 names `media/screenshots/` as a legitimate folder, and
packaging's template does not mention it. That is why this is filed as an observation and not as a
deviation.

**Fix direction.** This is the owner's call. Adding `  - media/screenshots` to `.pkgmeta` cuts the
package by 26 MB at no cost. If the collection agrees, the template change belongs upstream, in
packaging's minimum template.

---

## Recorded deviations (accepted, excluded from the tally)

### AM-03 — `options-ui-§17` ("One resolver") — **Info** — recorded

**The ratified decision.** A unit-scoped container snapshots its unit's class on each apply. It keeps
the previous unit's class until it re-applies after a swap made under lockdown or secrecy.

**Why it still holds.**

- The row is at `docs/ARCHITECTURE.md:422`, decided 2026-09-12.
- The clause it cites still exists (`options-ui-§17`, "**One resolver.**").
- Its evidence id, `docs/audits/2026-09-11` AM-03, resolves (`docs/audits/2026-09-11/02_DEVIATIONS.md:76`).
- Neither trigger has fired. There is no engine class-color binding, and `CM.MustDefer()` still holds every apply (`modules/ContainerManager.lua:116`).

---

## Checked and not filed

The evidence is in `03_EVIDENCE.md`.

- **Vendoring.** `diff -r` is empty for both payloads at v1.70.0. The provenance line is in `CLAUDE.md` only, the Standard badge is bare, and the README has no logo and no inventory.
- **Events.** Every registration goes through `NS.SafeRegister*`, with a player-reachable rejected list, which closes AM-23. The Core stub carries the three one-rung bodies.
- **Unit-filter frames.** There are five frames, each held on its module, unregistered by hand and reused. `CM.viewFrame` and `CM.viewPlayerFrame` each filter **two** `UNIT_*` events (`UNIT_FACTION`, `UNIT_FLAGS`).
  - events-frames-taint-§1 permits a frame "whose only job is to filter `UNIT_*` events", in the plural. It also says two unit tokens are "not a budget to spend on a second event".
  - This run reads the second sentence as being about the unit slots, so it files nothing.
  - The wording is ambiguous enough to raise upstream.
- **The disabled state (slash-commands-§7).**
  - One latch with two holds, and no second teardown.
  - Every registration is undone except the panel's own refresh subscription, which open-evolutions records as open, and the sanctioned pending `PLAYER_REGEN_ENABLED`.
  - Every timer is a handle canceled on stand-down, which closes AM-24. No game event writes SavedVariables while disabled.
  - The surface follows v2.57.0: everything stays live, and nine feature verbs refuse through the library gate.
  - `tests/test_disabled.lua` asserts on the recording registry.
- **Diagnostics (debug-logging-§14).** One row, tested first in `debug`, no alias, live while disabled, built on `RunDiagnostics`. It turns logging on, as `docs/debug.md` states, and the README section is verbatim.
- **Library debug lines (debug-logging-§4, v2.73.0).** `debug` is passed to Slash, Options, Launcher and Lifecycle, and `debugAtEnable` to the Launcher. There are no duplicate edge or refusal lines. The change gates are the console's.
- **The launcher.** One object. `label` is `Ka0s Aura Master`. Left-click opens settings. The right-click menu has three pairs matching `ADDONS.md:20`. There is no host tooltip. The minimap row's path is `global.minimap.shown`, and it is vetoed from both resets.
- **Options.** The descriptor passes `addonName` (v2.75.0). Stub composers answer `{}`, which closes AM-22. Master controls is first and composed. The nav-rail selection is session state. No `disabledIf` sits on a color row. Blizzard's settings window is touched only behind combat refusals, and the page jump uses `cat:GetID()`.
- **Slash.** `enable`/`disable`/`lock`/`unlock` write through the seam and echo in the `set` shape, which closes AM-29. `liveVerbs` is built on `SlashLib.LIVE_VERBS`.
- **savedvariables-§1 (v2.65.0).** Defaults declare `schemaVersion = 0` (`defaults/Profile.lua:92`). The runner owns the stamp, advancing only past a step that returned, and every step walks `eachProfile`.
- **Write paths (architecture-§5).** The direct-write grep is empty, and drag-attach writes through the seam.
- **Line endings.** The body diffs clean, there is no appendix, and (e) is 0, which closes AM-30.
- **Layout-§1 census and gate.** Nothing is over the cap, the census says so, and the kit gate is wired.
- **docs/ tier model.** Every Tier 1 and Tier 2 doc is accounted for. The Verification-and-record table has six rows, and `spell-research/` is registered as a Tier 3 store row, which closes AM-26. Every hub citation resolves, which closes AM-07 and AM-08.
- **Standard citations.** All 81 distinct `filename-§N` references are in range, and there are 0 retired `§N.M` hits in 197 live files.
- **Lint.** 0/0 over 171 files, with the test tree in scope. The four unused `read_globals` are gone, which closes AM-28.
- **Testing.** `jobs = "auto"` gives a 16 s gate, which closes AM-27. The badge `2049/2049` excludes the one kit skip, as testing-§5 requires.
- **Compat.** `core/Compat.lua` publishes 26 shims, matching the map's row.
