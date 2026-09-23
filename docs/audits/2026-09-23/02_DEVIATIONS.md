# 02 — Deviations: Ka0s Aura Master (2026-09-23)

Audited against **Ka0s WoW Addon Standard v2.64.0 (2026-09-23)**. The deviation-ID prefix is **`AM-`**,
reused from `docs/audits/2026-09-11/`. A recurring gap keeps its old ID; new IDs run from `AM-21`.

**How grades are set.** Each grade follows `AUDIT.md` step 5: it measures impact, not how strongly the rule
is worded. A failure that lives only in docs or config is graded Low or Info even when it breaks a MUST,
and the entry still names that MUST.

There is one exception, AM-21. `AUDIT.md` step 4's re-vendor check says in plain words that an unrecorded
vendored tag "is a **High** finding". AM-21 therefore uses the grade that check gives it. Step 5's
impact table would have made it Low, because no player can hit it. Both grades are recorded in the
entry, so the tension inside the playbook stays visible.

## Tally

The **headline tally counts roots only**. Entries marked `derived from <ID>` are listed under their root.
They are left out of the headline and out of the headline MUST count.

| | High | Medium | Low | Info | Total |
|---|---|---|---|---|---|
| **Headline (roots only)** | 1 | 0 | 16 | 2 | **19** |
| Total including dependents | 1 | 0 | 17 | 2 | **20** |

| MUST failures | High | Medium | Low | Total |
|---|---|---|---|---|
| **Roots only** | 1 | 0 | 11 | **12** |
| Including dependents | 1 | 0 | 12 | **13** |

Five roots fail a SHOULD, not a MUST: AM-13, AM-27, AM-28, AM-29 and AM-31. The two Info roots,
AM-35 and AM-36, are observations about config and the issue store.

**Recorded deviations** are gaps a ratified register row already covers. They are accepted and are not
counted above:

- **AM-03** (`options-ui-§17`, row decided 2026-09-12, `docs/ARCHITECTURE.md:825`).

The register's **`documentation-§1`** row is **not** accepted: its own trigger has fired (AM-20). Its four
**`layout-§1`** rows are marked unratified in their own text (AM-32).

**Verdict: minor deviations.** Only one entry is High, and it is a gap in the re-vendor record, not a
defect a player can hit. No user-reachable defect was found. The disabled state now genuinely stands
down; it is built on the Lifecycle latch. The Low entries are two latent runtime risks (AM-23, AM-24),
one stub-shape issue (AM-22), and documentation or config drift.

---

## Roots and dependents

### AM-21 — `audit-review-history` (*A re-vendor commit implies a bundle*) — **High** (by the check's own grade; Low by step 5's impact table) — MUST

**What is wrong.** Nineteen LibKa0s tags were vendored with no `docs/revendor/` bundle and no register row.
The unrecorded tags are v1.35.0, v1.36.0, v1.36.1, v1.36.2, v1.37.0, v1.38.0, v1.39.0, v1.42.0, v1.44.0,
v1.46.1, v1.47.0, v1.48.0, v1.48.1, v1.49.0, v1.49.1, v1.50.0, v1.51.0, v1.52.0 and v1.53.0.

The counting window starts at the store's first bundle, 2026-09-12. Inside it, 27 commits touch
`libs/LibKa0s`, and they vendored 22 distinct tags. Six tags are recorded in the store (E-7).

The newest bundle has a second problem. `docs/revendor/2026-09-23-v1.55.0/01_DELTA.md:1` says it covers
v1.54.2 → v1.55.0. This repo went straight from **v1.53.0** (`f6f61d3`) to **v1.55.0** (`f6f3ffb`), so that
delta leaves out whatever v1.54.0–v1.54.2 brought in.

**Fix direction.** Write **one consolidated bundle** covering the span v1.34.0 → v1.53.0, as
`audit-review-history` allows. It records what arrived and notes that sweeps carried it. The frozen
v1.55.0 bundle is not edited. Instead, the new bundle states that the true base of the v1.55.0 re-vendor
was v1.53.0, and records the v1.53.0 → v1.54.2 delta.

### AM-20 — `documentation-§1` item 4 (`## Screenshots`) and `audit-review-history` — **Low** — MUST (the addon is published)

**What is wrong.** The README's `## Screenshots` section is still a placeholder: "No screenshots yet.
They'll come before the first release" (`README.md:26-29`).

The register row that ratified the placeholder (`docs/ARCHITECTURE.md:826`) no longer covers it, for three
reasons:

- Its trigger has fired. The TOC has carried `X-Curse-Project-ID: 1698345` since `a326ed7` (2026-09-16),
  at `AuraMaster.toc:13`, and the README shows the live CurseForge badge. The row itself says the "first
  publish" half has fired.
- It cites "item 5". Since v2.45.0, `## Screenshots` is item **4**.
- It asserts a live deviation against what is now a MUST.

Three other docs contradict each other on whether the addon is published:

- Known Limitations says "**Unpublished**" (`docs/ARCHITECTURE.md:744-745`).
- The README's Version History records a "First release" (`README.md:156`).
- The README's own screenshots placeholder says they are owed "before the first release".

**Fix direction.** Capture real in-client screenshots (issue #3), add the captioned section, and retire
the row. Until the images exist, the owner decides whether to re-ratify the row. A re-ratified row cites
item 4, uses a fresh trigger, and drops the wording that its trigger has fired. Then make Known
Limitations and the README agree on whether the addon is published.

### AM-22 — `options-ui-§1` (anti-pattern #73) — **Low** — MUST

**What is wrong.** The Options degradation stub fills in content it should leave empty. Its composers
rebuild each composed block's stored surface (one row per canonical leaf, with its path and type) in
`composeBlock`, `ColorPair`, `FontGroup`, `BorderGroup`, `BarGroup` and `MasterControls`
(`settings/OptionsSetup.lua:198-280`).

Since v2.64.0 the rule is that a stub's composer members "MUST answer an **empty row list**… A host copy of
a composed block inside the stub is anti-pattern #73". The suite pins the wrong thing:
`#NS2.Schema == #NS.Schema` (`tests/test_optionssetup.lua:369`). It should pin the full-load count, the
library-absent count, and the delta between them.

The `docs/revendor/2026-09-23-v1.55.0` decisions predate this reading. Only a degraded install reaches
this code.

**Fix direction.**

- Make each composer member return `{}`, plus `MasterControls`' no-op tail.
- Pin the two counts and the named delta.
- Check the fall-together property. With Options absent, the Slash major is absent too, so no composed
  row can be addressed.
- Update `docs/settings-panel.md` → *The degraded panel*.

### AM-23 — `events-frames-taint-§1` (*An unknown event name raises*) — **Low** — MUST (the `IsEventValid` front-gate is a SHOULD)

**What is wrong.** Every event registration is a bare call:

- `addon:RegisterLifecycleEvents` makes eight straight `self:RegisterEvent` calls
  (`core/AuraMaster.lua:57-67`).
- `TS.Sync` registers three more the same way (`modules/TimedSpells.lua:140-142`), and `syncAuraListen`
  registers `UNIT_AURA` (`:121`).

None of them goes through a per-event `pcall` helper, and nothing records a name the client rejected
where `/am debug` or the console can reach it. The newest of these names is
`ADDON_RESTRICTION_STATE_CHANGED`. If a client did not know one, it would throw, and every registration
after it in the block would silently go unbound.

This is latent: every name exists on the supported 12.1 client.

**Fix direction.** Add one `NS.RegisterEventSafe(target, event, handler)`. It front-gates with
`C_EventUtils.IsEventValid` where the client has it, calls `pcall(target.RegisterEvent, …)`, and records
each refused name. Surface that list through the debug console's `[Init]` summary or an `/am debug events`
line. Route all three sites through it. Pin it with the kit mock's `M.__badEvents`.

### AM-24 — `slash-commands-§7` (*Every timer … is canceled*) — **Low** — MUST

**What is wrong.** Two one-shot `C_Timer.After` callbacks armed before a stand-down cannot be canceled.
Each one wakes up after it and finds the latch:

- `CM.RequestApply` arms `C_Timer.After(0, CM.FlushPending)` (`modules/ContainerManager.lua:155`), and
  `FlushPending` returns on `NS.IsStoodDown()` (`:253`).
- `scheduleScan` arms `C_Timer.After(0.5, scanTick)` (`modules/TimedSpells.lua:106`). `scanTick` drops
  it on its `listening` guard (`:94-97`), which the file's own comment admits: "dropped by scanTick's `listening` guard rather than
  canceled -- C_Timer.After hands back no handle to cancel" (`:163-164`).

The standard's wording is "not left armed to wake up and find a flag".

Graded Low rather than the Medium the playbook gives an armed repaint timer. Each callback wakes at most
once, within a frame or half a second, and never re-arms.

**Fix direction.** Use `C_Timer.NewTimer`, which returns a handle, in both places. Hold the handle, and
`:Cancel()` it in `CM.StopListening` and `TS.StandDown`. Extend `tests/test_disabled.lua` step 4 to arm
both callbacks before disabling.

### AM-07 — `documentation-§5` — **Low** — MUST (recurs)

**What is wrong.** Five of the 35 distinct `file:line` citations in `docs/ARCHITECTURE.md` point at the
wrong line (E-15):

| Cited | Actual line |
|---|---|
| `settings/Schema.lua:377` (the `CONFIG_CHANGED` send) | `:460` |
| `modules/ContainerManager.lua:520` | `:535` |
| `modules/ContainerManager.lua:543` | `:545` |
| `settings/OptionsSetup.lua:380` (the panel's subscription) | `:396` |
| `modules/Style.lua:823-825` (`RightButtonUp`) | `:826-828` |

Two other hub claims have drifted from the code:

- "Twenty-two verbs" is still true.
- `docs/testing.md:16-19` says the suite gets `-j auto` "if the serial suite ever passes about ten
  seconds", while it runs 174 s serial. That fix belongs to AM-27.

**Fix direction.** Run one citation sweep over `docs/` and the root docs. Make the docs gate, which
closed issue #6, compare each citation's text as well as whether the line exists.

- **AM-08 — `documentation-§7` — Low — MUST — derived from AM-07.** `DEPENDENCIES.md` has three wrong
  citations:

  | Cited | Actual line |
  |---|---|
  | `core/Constants.lua:25` (`C.LOGO_PATH`) | `:26` |
  | `core/Constants.lua:31` (`C.LOGO_ICON_PATH`) | `:32` |
  | `modules/ContainerManager.lua:568` (the no-engine notice) | `:572` |

  Same cause, same sweep.

### AM-25 — `documentation-§3` (the hub's spill rule) — **Low** — MUST (spill) / SHOULD (≈400 lines)

**What is wrong.** `docs/ARCHITECTURE.md` is 841 lines long, against a SHOULD of about 400. Four sections break the spill rule:

- **Settings Schema** (`:107-243`, 137 lines) is a mandated section well past about 60 lines. It carries
  both registries' full surfaces table and the named-state detail inline, and links `schema.md` only at
  its end.
- **Overview** (`:6-74`, 69 lines, including the libraries tables) is also past about 60 lines.
- **Known Limitations** (`:586-775`, 190 lines) and **Taint Notes** (`:488-585`, 98 lines) have no
  canonical spill target.
- Four sections that are not mandated add about 150 more lines:
  - Locale routing, `:245-268`;
  - Filter priority, `:270-318`;
  - Launcher, `:391-419`;
  - The disabled state, `:444-486`.

**Fix direction.**

- Spill the Settings Schema detail into `docs/schema.md`, leaving a summary and one link.
- Move Filter priority into `docs/data-flow.md` and Locale routing into a Tier 3 doc.
- Move the disabled-state narrative into `docs/data-flow.md` or a Tier 3 `lifecycle.md`.
- Trim Known Limitations and Taint Notes to one line per item, linking `docs/midnight-quirks.md` for the
  detail.

### AM-26 — `documentation-§3` (`## Documentation map`) — **Low** — MUST

**What is wrong.** The hub lists `docs/spell-research/<date>/` among the out-of-scope frozen directories
(`docs/ARCHITECTURE.md:778-781`). documentation-§3's list of those stores does not contain it, and a
repo does not get to extend that list.

As a result, the three tracked `.md` files under `docs/spell-research/2026-09-20/` (`ANALYSIS.md`,
`DIFF.md` and `SOURCES.md`) appear in no table. Meanwhile `### Addon-specific` reads "None."
(`:817-819`).

**Fix direction.** Register the store as one Tier 3 row: a store gets one row and its dated bundles get
none, which documentation-§3 records as a coherent reading. Remove it from the prose list, or propose
the store upstream for the canonical list.

### AM-27 — `testing-§14` — **Low** — SHOULD

**What is wrong.** The commit gate takes **2m54s wall** serially. It spends 36.4 s of user CPU, about
28% utilization, and runs 1296 cases (E-2). `Kit.run` sets no `jobs` (`tests/run.lua:57-115`). The
standard says `--jobs` SHOULD be on once a serial gate passes about 10 s. The 28% figure is itself the
diagnosis that most of the run is waiting.

**Fix direction.**

- Measure first, as testing-§14 MUSTs, and record the figure in `docs/automated-tests/RESULTS.md`.
- Check that a `-j auto` run matches the serial totals and exit code.
- Then set `jobs = "auto"`, and correct `docs/testing.md:16-19`.

### AM-28 — `lint` (config hygiene) — **Low** — SHOULD

**What is wrong.** Four `read_globals` entries in `.luacheckrc:13-23` are referenced by no authored file:
`GameTooltip`, `C_Spell`, `GetAddOnMetadata` and `GetSpellInfo`.

The file's own comment (`:11-12`) says "a name nothing reads comes off the list". A probe run with the
four removed is still 0/0 over 110 files (E-1). Two of them are the deprecated globals `compat` confines
to `core/Compat.lua`. Leaving them declared means lint would stay silent if anti-pattern #10 regressed.

**Fix direction.** Delete the four entries.

### AM-13 — `localization-§1` (the routing SHOULD) — **Low** — SHOULD (recurs, narrower)

**What is wrong.** Four library-missing lines join two routed fragments into one sentence
(`NS.LIBKA0S_MISSING .. ", " .. NS.L["so … is unavailable."]`):

- `core/CoreSetup.lua:72`
- `core/DebugLogSetup.lua:19`
- `core/LauncherSetup.lua:50`
- `core/PerfSetup.lua:24`

Two neighbouring sites already route the whole sentence with a placeholder:
`settings/OptionsSetup.lua:194` and `settings/Slash.lua:361`.

**Fix direction.** Use `L["%s, so … is unavailable."]` through `Printf` or `format` at all four sites.

### AM-29 — `slash-commands-§2` / `slash-commands-§8` (the confirmation SHOULD) — **Low** — SHOULD

**What is wrong.** `/am enable`, `/am disable`, `/am lock` and `/am unlock` write through `NS.SetByPath`,
which is correct, but each confirms with a sentence of its own, such as "Aura Master enabled"
(`settings/Slash.lua:194`, `:284`). The standard wants the `set` shape from slash-commands-§5, for
example `enabled = true`.

**Fix direction.** Echo the stored value through the library's key/value formatter, which is the same
line `/am set enabled true` prints. The prose sentence can be dropped, or kept as a tooltip-free second
line only if the owner wants it (the SHOULD allows one line).

### AM-30 — `line-endings-§7` (property e) — **Low** — MUST

**What is wrong.** **1 tracked file disagrees with the declared pin**, measured by the working-tree
one-liner in E-8.

The file is `tests/page_helpers.lua`. Line 80 ends `\r\r\n`: a stray bare CR inside a comment. Because of
it, git classifies the file as binary (`git ls-files --eol`: `i/-text`), so the blob is stored CRLF
(272 CR) and not normalized to LF like every other text file.

The kit's `test_eol` is green over it. This is the lone-`\r` case line-endings-§7 names as the one-liner's
known limit, so the finding is filed against the file, not the gate.

**Fix direction.** Delete the stray `\r` at `:80`. Then run
`git add --renormalize tests/page_helpers.lua` and re-check: `i/lf w/crlf` is the expected state.

As an upstream note for LibKa0s's testkit: `test_eol` could also flag tracked files whose index
classification is `-text` while `.gitattributes` says `text=auto`.

### AM-31 — `performance-§10` / `automated-tests-§3` / `automated-tests-§4` — **Low** — SHOULD (regenerate mid-cycle; the release gate is a MUST when the release comes)

**What is wrong.** The complexity record has drifted from the code.

The newest run, `20260916-184324`, is 129 commits behind HEAD. Measured against it (E-10):

| | Recorded | Now |
|---|---|---|
| NLOC | 21,163 | 30,336 |
| Functions | 2,446 | 3,348 |
| Test cases | 943 | 1,296 |
| Functions over CCN 15 | 0 | **2** |
| Files over the 1500-line cap | 0 | 4 |
| Files in the 1000–1500 band | 2 | 4 |

The two newly warned functions:

- **`Cat.SyncUserCategories`**, CCN 25 (`defaults/Categories.lua:1112-1194`). This is real control
  flow, not defaulting: four phases of loops and branches (teardown, anchor lookup, materialize,
  register).
- **`renderCategories`**, CCN 16 (`settings/Filters.lua:500-543`). This is a real dispatch on the grid key.

The next release gate (zero functions above CCN 15) would refuse the release. `RESULTS.md`'s band table
still shows `tests/test_database.lua` at 1037 lines; it is 1702.

**Fix direction.**

- Split `Cat.SyncUserCategories` into named phase helpers (performance-§11 shape 4).
- Replace `renderCategories`' `if g.key ==` chain with a module-level per-grid renderer table (shape 1).
- Write characterization tests before either change (testing-§13).
- Then run the four-suite runner and record the run.

### AM-32 — `documentation-§3` (the register) / `audit-review-history` (the trigger evaluation) — **Low** — MUST

**What is wrong.** Four `layout-§1` rows sit in `## Documented deviations` (`docs/ARCHITECTURE.md:827-830`),
and each says in its own Why cell that it "awaits the owner's ratification". The register is the one home
for *ratified* decisions. None of the four is needed: open issues #16, #17, #18 and #19 already put each
over-cap file in a compliant terminal state, and the census says so (`:834-841`).

Each row's re-check trigger reads "the next change that grows this file carries the peel …, and so does
the next standards audit if nothing grows it first". That trigger is an instruction, not a condition, and
its audit arm names this run.

**Fix direction.** Choose one of two:

- The owner ratifies the rows, giving a real ending condition such as "the peel lands".
- Or delete them and let the issues carry the terminal state. This is the lighter option.

Either way, the census's "the `layout-§1` rows above record the same breach" wording follows. The
breaches themselves are **not** filed: they are compliant through their issues.

### AM-33 — `architecture-§5` (named non-setting state) / `documentation-§3` (Settings Schema) — **Low** — MUST (doc-only)

**What is wrong.** Under architecture-§5, a vendored library's own writes into a table the addon hands it
count as named non-setting state. LibDBIcon's `minimapPos` in `global.minimap` is one. The Settings
Schema section says the addon holds "two pieces of named non-setting state"
(`docs/ARCHITECTURE.md:216`), `timedSpells` and `AuraMasterPerfDB`, and leaves `minimapPos` out.

`docs/schema.md:39` names the key and says who writes it, but gives no owner module. This is the same
class of state as the perf ring the hub does name.

**Fix direction.** Add one sentence naming it. Storage key: `global.minimap.minimapPos`. Owner:
`core/LauncherSetup.lua`. Writer: LibDBIcon, reached by the player dragging the button.

### AM-34 — `documentation-§7` (the three groups) — **Low** — MUST

**What is wrong.** `DEPENDENCIES.md` puts tools in the wrong groups:

- Its summary table puts **Python 3** under *Development* and says *Release / assets* is "None."
  (`DEPENDENCIES.md:13-14`). Yet the section below documents **Pillow** as the icon regenerator
  (`:117-133`).
- `research.py` regenerates committed data (`defaults/CastToAura.lua:3-6` and the `hardCC`/`softCC`
  lists). That is the *Release / assets* group's definition: "anything needed only to … regenerate
  committed assets".
- Pillow, an import outside the standard library, gets no install command. Only the recipe is given.

**Fix direction.** Move `python3` and the network note to *Release / assets*, and list Pillow there with
a `pipx`/`apt` install line (`python3-pil`) and a check command. Make the table's third row say "Python 3
(+ Pillow for the icon); not needed to build, run or test".

### AM-35 — `packaging` (conditional ignore entries) — **Info**

**What is wrong.** `.pkgmeta:12` ignores `.claude`, but this repo has no `.claude/` directory. packaging's
check (c) prints `FALSE CLAIM — .claude ignored, no such directory` (E-9). It costs nothing at package
time, but it states something false.

**Fix direction.** Delete the line, or comment it out with its condition, following the template's shape.

### AM-36 — `audit-review-history` (the status-label vocabulary) — **Info**

**What is wrong.** Issue #10 ("Let players create their own spell categories") is **closed** but labelled
`state:triaged`. That is an open-status label, and the work has shipped: `docs/ARCHITECTURE.md:167-214`
documents it.

**Fix direction.** Relabel it `state:done`.

---

## Recorded deviations (accepted, excluded from the tally)

### AM-03 — `options-ui-§17` ("One resolver") — **Info** — recorded

**The ratified decision.** A unit-scoped container snapshots its unit's class on each apply. It keeps
showing the previous unit's class until it re-applies after a swap made under lockdown or secrecy.

**Why it still holds.** The row is at `docs/ARCHITECTURE.md:825`, decided 2026-09-12, and its evidence
cites `docs/audits/2026-09-11 AM-03`, which resolves. The cited rule still says what the row claims.
Neither trigger has fired: there is no class-colour engine binding, and `MustDefer` still holds a
class-only re-dress.

---

## Checked and not filed

Each of these was measured and found compliant, or outside a rule's scope. The evidence is in `03_EVIDENCE.md`.

- **Vendoring.** `diff -r` is empty for both payloads at v1.55.0. The provenance line is in `CLAUDE.md`
  only, the Standard badge is bare, the README shows no logo, and it carries no library inventory.
- **The disabled state (slash-commands-§7).** It uses one latch with two holds; there is no second
  teardown. Every registration is undone except two:
  - the settings panel's own refresh subscription, `settings/OptionsSetup.lua:396`. open-evolutions
    records this as open, so neither reading is a finding;
  - the sanctioned `PLAYER_REGEN_ENABLED` pending hold.

  No SavedVariables write comes from a game event. The slash surface follows v2.57.0. The launcher
  refuses left-click while disabled and still opens the panel on right-click. `tests/test_disabled.lua`
  asserts on the recording registry. The residual timers are AM-24.
- **The launcher.** One object, `label` `Ka0s Aura Master`, rung (b) test mode matching `ADDONS.md`, and
  `minimap.hide` stored globally and vetoed from both resets.
- **Test mode.** It is a composed session row, ends when combat starts, is refused in combat, and is
  ended by Reset all.
- **The settings panel, checks (a)–(i).** Every row has a group. Master controls is first and complete.
  No colour row carries `disabledIf`, and `expiringColor` is annotated as a palette swatch. There are no
  arrow reorders. Font, border and bar blocks are composed. The wrap-stability case exists, and nothing
  closes Blizzard's settings window in combat.
- **The bus.** Four constants through `Bus.Catalog`, no literal at any call site, PascalCase tails, and
  `message-bus.md` correctly marked *Not applicable*.
- **Compat.** 21 shims by the canonical grep, matching the map's row. No deprecated global is called
  outside Compat, which closes prior AM-10.
- **Layout-§1 census and gate.** The kit gate is wired and green. The census matches the tree in both
  directions. Each over-cap file has an issue terminal state. The only generator is under `tools/`.
- **Line-endings body.** Byte-identical to the canonical client-bound file once CRLF is stripped; the
  `*.sh` and `*.py` carve-outs and 23 binary marks are present.
- **Retired-notation sweep.** 19 raw hits, all of them `§N.M` references to this addon's own spec
  documents (`docs/superpowers/…`, `docs/smoke-tests.md:606`), not to the standard. No `filename-§N`
  citation is out of range: 77 distinct citations were checked against each file's `### N.` count.
- **Issue store.** No `LEDGER.md` and no `[status]` prefixes. #20 declines the Bus stand-down record,
  which v2.64.0 permits outright, so no register row is owed.
- **TOC.** `X-Curse-Project-ID` is a real id, not a placeholder.
- **Events.** The `UNIT_AURA` firehose through AceEvent is compliant, since AceEvent is the MUST path.
  The v2.64.0 carve-out would now also allow a private `RegisterUnitEvent("UNIT_AURA", "player", "pet")`
  frame. That is optional, so it is not filed.
