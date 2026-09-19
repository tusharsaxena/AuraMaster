# Smoke-Test Feedback Batch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the owner's 2026-09-19 smoke-test feedback on the Text-style release: the Lua error
when a container is attached to another frame (E), stacked Center rows (#1), the Containers page's
picker and New in the band above the strip (#2), Restore beside the Category dropdown (#3),
dropdown-chosen sections shown rather than dimmed through a new LibKa0s opt-in (#4, with its release,
the re-vendor into all eleven consumers and the adoptions), trimmed token output and built-in Text
templates with a preview (#5), weapon enchants as a buff category only with a schema v5 migration
(#6), bars' background colored by dispel type and the Text-colour research gate (#7), a TEST marker on
the handle (#8), a right-click on the handle's "?" that opens the Containers page on that container
(#9), and Show all / Hide all on Filters → Categories (#10).

**Architecture:** Every item rides an existing seam. Geometry reads go through one new guard,
`NS.Secrets.NumberOr`, and the handle label is measured on a detached font string
(`Anchors.__labelMeasurer`, the `Style.__measurer` idea). The Containers page draws its identity
controls with the library's `PageHeader` chrome block. The template language (`modules/TextTemplate.lua`)
gains the pure built-in table and matcher; `modules/Style_Text.lua` gains the stacked layout and
`Style.ElementSize` grows a Center box to its rows. The enchant aura type retires through a
`SCHEMA_STEPS` row (`to = 5`) and a sweep of every `ENCHANT` branch. LibKa0s-Options-1.0's flow
engine (`OptionsWidgets.lua` minor 22) learns an opt-in row field, `shownWhen`, that skips a row
(heading included) unless a selector path holds a given value and re-renders the page when that
selector changes; Aura Master's Layout → Anchor and Party Frame Enhanced's Size & Position adopt it.

**Tech Stack:** Lua 5.1 (WoW Retail 12.1, interface 120100), Ace3, LibKa0s v1.44.0 → **v1.45.0**
(`LibKa0s-Options-1.0` 21.21.1.7.3 → **21.22.1.7.3**; kit revision 23, unchanged), the headless harness
`lua tests/run.lua`, `luacheck`, `lizard`, `lua tests/perf.lua`.

**Spec:** docs/superpowers/specs/2026-09-19-smoke-feedback-design.md (items E, #1–#10, "Order and
risk", "In-game checks owed after"). Read it with this plan; it is binding. Where the two differ, the
difference is resolved in **Decisions this plan pins down** below, never silently.

## Global Constraints

- **Branches and commits.** Aura Master work is on branch `feat/smoke-feedback` (already checked out;
  the spec is its only commit so far, 2b44b4f). **One commit per task**, made by the controller after
  the task's review, carrying the plan file's ledger update (every task's last step). Never merge,
  push, tag or bump a version without the owner's explicit go-ahead (CLAUDE.md).
- **Other repos.** A consumer's LibKa0s re-vendor goes on its own branch `chore/libka0s-v1.45.0`,
  branched from its default branch. A consumer's `shownWhen` adoption goes on `feat/switched-sections`,
  branched from its `chore/libka0s-v1.45.0` (the adoption needs the new copy). LibKa0s's own work
  follows its `docs/releasing.md` and its CLAUDE.md, on its `master` as every release has, and
  **STOPS before the tag and before any push** for the owner (Task 14).
- **Heavy runs go through the bounded runner, from the repo root, always:**
  `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua`,
  `/home/tushar/.claude/wow-addon/bin/ka0s-bounded luacheck .`,
  `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lizard -l lua -x "./libs/*" -x "./tests/_kit/*" -C 15 -w .`,
  `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/perf.lua`.
  A bare `luacheck`, `lizard` or `run-automated-tests.sh` is **blocked by a hook, even as text inside a
  heredoc**: write files with the Write/Edit tools (or a quoted heredoc that names none of the three).
- **Green gate after every task:** `lua tests/run.lua` → `… 0 failed …` and `luacheck .` →
  `0 warnings / 0 errors`, both bounded. The harness has no filter flag, so one case is run as
  `… lua tests/run.lua 2>&1 | grep -A3 "<case name fragment>"`.
- **Complexity:** no function above CCN 15. Run the bounded lizard line above whenever a task adds a
  branchy function; `-w` prints only the offenders, so it must print nothing.
- **Lizard's `#` rule** (`tests/test_lintconfig.lua`): no keyword (`end`, `then`, `do`, `and`, `or`, …)
  and no unbalanced `{`/`}` after a length operator on the same line. Take the length into a local
  first (`local n = #t` then `t[n + 1] = v`).
- **CRLF everywhere** (`.gitattributes`; `tests/_kit/test_eol.lua` fails an LF file). A tool that
  writes LF is followed by
  `python3 -c "import sys;p=sys.argv[1];s=open(p,newline='').read().replace('\r\n','\n');open(p,'w',newline='').write(s.replace('\n','\r\n'))" <path>`.
- **Strings:** every user-visible string goes through `NS.L`, with its key in `locales/enUS.lua` as
  `L["x"] = "x"` (key == value), ASCII except the em dash, **US English** (`tests/test_locale.lua`,
  `tests/test_docs.lua`; anti-pattern #46). A retired key is removed from `locales/enUS.lua` in the
  same task (the locale suite fails an unused key).
- **Citations:** a `file:line` citation in `docs/*.md`, `README.md` or `DEPENDENCIES.md` that a code
  change moves is re-pointed **in the same task** (`tests/test_docs.lua`). Use the helper below; a
  `BY HAND` line is re-pointed with `grep -n '<the symbol the sentence names>' <file>`.
- **The Ka0s WoW Addon Standard binds** (local copy
  `/mnt/d/Profile/Users/Tushar/Documents/GIT/WowAddonStandards/standards/standards/*.md`, v2.59.1). The
  two places the spec says "stop and flag" are resolved below (Decisions, D-4 and D-7). Any deviation a
  task finds that this plan did not foresee STOPS the task and is reported, never taken (CLAUDE.md).
- **Defaults** live only in `defaults/Profile.lua` (savedvariables-§2); every settings write goes
  through `NS.SetByPath`; a stored-shape change bumps `schemaVersion` through a `SCHEMA_STEPS` row
  (toc-file-§2, savedvariables).
- **Never** edit `libs/LibKa0s/` or `tests/_kit/` by hand in any consumer: they change only by a
  whole-folder copy from a LibKa0s tag (library-stack-§7).

---

## Status ledger (update after every task)

**How to resume after an interruption.**

1. **Where the work lives.** Aura Master: branch `feat/smoke-feedback` (Tasks 1–13, 15, 16, 19).
   LibKa0s: `master` (Task 14; its two release commits, then the owner's tag). Each of the ten other
   consumers: `chore/libka0s-v1.45.0` (Task 17), and Party Frame Enhanced also
   `feat/switched-sections` (Task 18).
2. **What is committed.** In Aura Master run `git log --oneline master..feat/smoke-feedback` and
   `git status --short`. Every task's commit subject starts with its task number (`T7: …`), and the
   task's commit also carries this file with its row updated, so the table below and the log agree.
   In another repo: `git -C ../<Repo> log --oneline <default>..<branch>` and `git -C ../<Repo> status --short`.
3. **The live execution ledger** (every ruling, deferred minor and review package) is
   `.superpowers/sdd/2026-09-19-smoke-feedback/progress.md` (git-ignored). The table below is its
   committed copy; when they disagree, the git log decides.
4. **Which row to continue at:** the first row below that is not `done`.
   - `todo`: not started — dispatch it.
   - `in progress`: the implementer may have left uncommitted work. Run `git status --short` first;
     finish or discard that work before re-dispatching, never both.
   - `in review`: its commit(s) exist; finish the review or its fix round, then mark `done`.
   - `blocked`: waiting on the owner (the Notes say for what). Do not work around it.
5. **Owner stop points — never passed without the owner:** any version
   bump of an addon. **One-off approval for this batch (owner, 2026-09-19):** the controller
   builds without a plan review, and tags, merges and pushes on its own. That covers LibKa0s
   `v1.45.0` (Task 14 Step 9 is done by the controller, not the owner), the ten consumers'
   re-vendor branches, Party Frame Enhanced's `feat/switched-sections`, and Aura Master's
   `feat/smoke-feedback`, each once it is green and reviewed. Tasks 15–18 still wait for the tag.
6. **Dependency order:** 1–5 are independent. 6 → 7 → 8 (8 needs 7's Center built-in). 9 → 10.
   11 and 13 are independent. 12 needs nothing. 14 → owner tag → 15 → 16, and 14 → owner tag → 17 → 18.
   19 is last.

**Current position:** Tasks 1–9, 13–15, 17, 18 done; Task 11 in review; next Task 16, then 10, 12, 19.

| # | Task | Repo | Status | Notes |
|---|---|---|---|---|
| 1 | E — secret geometry: the handle label measured detached; every geometry read guarded | AuraMaster | done | 0af5c7a + fix round |
| 2 | #3 — Restore beside the Category dropdown | AuraMaster | done | 2a5181f |
| 3 | #2 — the Containers page's picker and New in the band above the strip | AuraMaster | done | 1847443 + 4b3369d |
| 4 | #8 — a TEST marker on the handle while test mode is on | AuraMaster | done | 7152fd0 |
| 5 | #10 — Show all / Hide all on Filters → Categories | AuraMaster | done | 5900198 |
| 6 | #5a — token output: bare percents, no stray whitespace, the `( )` probe | AuraMaster | done | 89e74b0 |
| 7 | #5b — built-in templates, Custom, and the Preview line | AuraMaster | done | 780258e |
| 8 | #1 — Center lays a multi-piece line out as stacked rows | AuraMaster | done | 7e018b6 + fix round |
| 9 | #6a — schema v5: every ENCHANT container becomes an enchant-only buff container | AuraMaster | done | 65c8f45 + fix round |
| 10 | #6b — the Weapon enchants aura type is removed everywhere | AuraMaster | todo | |
| 11 | #7a — bars' background colored by dispel type; no type falls back to the surface's color | AuraMaster | in review |  |
| 12 | #7b — text colored by dispel type: three opt-in stand-ins (word color, backdrop, edge) | AuraMaster | todo |  |
| 13 | #9 — right-click the handle's "?" → the Containers page on that container | AuraMaster | done | f11167d |
| 14 | #4a — LibKa0s v1.45.0: `shownWhen` switched sections (STOP before tag/push) | LibKa0s | done | LibKa0s 6dbfc74 + a7053ca, tag v1.45.0 pushed |
| 15 | #4b — re-vendor LibKa0s v1.45.0 into Aura Master | AuraMaster | done | 4ebdb4a (vendored OptionsWidgets.lua) + this commit (provenance) |
| 16 | #4c — Aura Master adopts `shownWhen` on Layout → Anchor | AuraMaster | todo | |
| 17 | #4d — re-vendor v1.45.0 into the other ten consumers; the adoption sweep | 10 repos | done | 9 consumers merged+pushed; PFE c2577a5 on its chore branch (Task 18 builds on it); LibKa0s docs 2b32ee8 pushed |
| 18 | #4e — Party Frame Enhanced adopts `shownWhen` on Size & Position | PartyFrameEnhanced | done | PFE ea6f8ff, merged 8315f4c and pushed |
| 19 | Final gate, smoke items, inventory — hand back to the owner | AuraMaster | todo | |

---

## File structure

| File | Change | Responsibility after |
|---|---|---|
| `core/Secrets.lua` | modify | + `Secrets.NumberOr(v, fallback)` (T1) |
| `core/Constants.lua` | modify | `AURA_TYPES` loses `ENCHANT` (T10); `TEXT_ROW_GAP` (T8); `TEXT_BUILTINS`, `TEXT_BUILTIN_SETS`, `TEXT_SAMPLE_AURAS` (T7); `BG_COLOR_MODES` reuse (T11); `TEST_TAG_COLOR` (T4) |
| `core/Database.lua` | modify | `MigrateV5` and the `to = 5` step (T9) |
| `defaults/Categories.lua` | modify | + `Cat.EnchantOnlyStates()` (T9); `Cat.For` falls back to an empty list, `Cat.ENCHANT` gone (T10) |
| `defaults/Profile.lua` | modify | `bars.bgColorMode = "static"` (T11) |
| `modules/Anchors.lua` | modify | `__labelMeasurer`, `levelOf`, guarded `SavePosition` (T1); TEST marker (T4); right-click opens the Containers page (T13) |
| `modules/Container.lua` | modify | guarded blocker level (T1); no `ENCHANT` unit override (T10) |
| `modules/Style.lua` | modify | guarded measurer (T1); percent rule `%d` (T6); `ElementSize` grows a stacked box (T8); `DispelColorMap(stored, fallback)` (T11); no `ENCHANT` in cancel (T10) |
| `modules/Style_Text.lua` | modify | preview percent without `%` (T6); `Text.PreviewLine` (T7); `Text.Stacked`, `Text.StackHeight`, the stacked layout (T8) |
| `modules/Style_Bars.lua` | modify | background dispel binding and preview; fallback colors (T11) |
| `modules/TextTemplate.lua` | modify | `TT.Builtins`, `TT.MatchBuiltin` (T7) |
| `modules/FilterCompiler.lua` | modify | no enchant aura-type path; no NEVER_MATCHES beside enchant slots (T10) |
| `modules/Preview.lua` | modify | no enchant placeholder cap (T10) |
| `settings/OptionsSetup.lua` | modify | `Helpers.ContainerHeader` replaces `ContainerPickerCell` (T3) |
| `settings/Containers.lua` | modify | chrome block, tab `General` (T3); aura-type description (T10) |
| `settings/GeneralSpells.lua` | modify | Restore as the dropdown line's second cell (T2); the Dispel Colors `None` row retired (T11) |
| `settings/Filters.lua` | modify | Show all / Hide all (T5); no `ENCHANT` (T10) |
| `settings/Text.lua` | modify | Template dropdown, Custom, Preview, cheat-sheet line (T6, T7); Center tooltips and note (T8) |
| `settings/Bars.lua` | modify | `bgColorMode` row; Color by tooltips (T11) |
| `settings/Layout.lua` | modify | `shownWhen` on the Anchor subsections (T16) |
| `settings/Slash.lua` | modify | `/am new enchants` makes an enchant-only buff container (T10) |
| `locales/enUS.lua` | modify | every new key; retired keys removed |
| `libs/LibKa0s/`, `tests/_kit/`, `CLAUDE.md`, `DEPENDENCIES.md`, `docs/ARCHITECTURE.md` | re-vendor | v1.45.0 (T15) |
| `tests/test_*.lua` | modify | per task |
| `docs/*.md`, `README.md` | modify | per task; smoke section T (T19) |
| `../LibKa0s/LibKa0s/OptionsWidgets.lua` + a new suite, docs/api, CHANGELOG | modify | `shownWhen` (T14) |
| `../PartyFrameEnhanced/settings/ElementRows.lua` + `tests/test_optionssetup.lua`, its settings-panel, smoke-tests, test-cases, README badge | modify | `shownWhen` on Size & Position (T18) |
| `../<ten consumers>/libs/LibKa0s/`, `tests/_kit/`, `CLAUDE.md` (+ PFE and PrettyChat `docs/ARCHITECTURE.md`) | re-vendor | v1.45.0 (T17) |
| `../LibKa0s/docs/releasing.md` | modify | the Consumers table's `shownWhen` adopters; step 8 recorded (T17, post-release docs commit) |

## Decisions this plan pins down (the spec left them to the implementation)

- **D-E, the error's mechanism.** `placeHandle` read `handle.label:GetStringWidth()`; the label hangs
  off the strip, the strip off the anchor, and an anchor attached to an engine container (or a frame
  anchored to one) inherits secret geometry, so the width came back secret and `+ HANDLE_PAD` raised.
  The label is now measured on `Anchors.__labelMeasurer()`: one hidden `GameFontNormalSmall` font
  string on a hidden `UIParent` child, never anchored (the `Style.__measurer` pattern), its width taken
  through a new `NS.Secrets.NumberOr(v, fallback)` (fallback 0, so the strip keeps its old
  `math.max(…, element width)` floor). **The sweep** of every geometry read on a region that can be
  attached, with what each becomes:
  - `modules/Anchors.lua` `placeHandle` — the label width: measured detached (above).
  - `modules/Anchors.lua` `BuildHandle` and `handleLevel` — `anchor:GetFrameLevel()` and
    `target.anchor:GetFrameLevel()`: `FrameLevel` is a `SecretAspect` (`SecretAspectConstantsDocumentation`),
    so both go through `NumberOr`, falling back to the level `Container:Apply` set from the stored
    `layout.level` (`levelOf`).
  - `modules/Anchors.lua` `SavePosition` — `anchor:GetPoint(1)`: only a screen-attached anchor is ever
    dragged, but a secret point or offset now writes nothing (one `[Anchor]` debug line) instead of
    raising in `round()`.
  - `modules/Container.lua` `ApplyBlocker` — `engine:GetFrameLevel()`, already `pcall`'d for a raise but
    not for a secret: `NumberOr(…, 0)`.
  - `modules/Style.lua` `widestSample` — the time-text measurer is ours and detached, but its
    `type(w) == "number"` let a secret number through; it now asks `IsReadableNumber`.
  - Reviewed and left: `modules/Style_Bars.lua:64` and `modules/Style_Icons.lua:59` read the level of a
    frame the build itself just created inside `initializeFrame`, not an attached region, and have run
    in combat builds since batch 1; `modules/FramePicker.lua:74` reads `UIParent`'s scale. No other
    `Get*Width`, `GetLeft`/`GetRight`/`GetTop`/`GetBottom`, `GetRect`, `GetCenter` or `GetPoint` exists
    in `modules/` or `core/` (`grep -rn` over both).
  - The kit has **no** secret-value mock; a case plants the client's `issecretvalue` on a sentinel
    number (`tests/test_secrets.lua`'s method) and makes the label's own `GetStringWidth` raise the
    client's error outright, which is what turns the old code red.
- **D-1, stacked Center.** `Text.Stacked(s, compiled)` is `justifyH == "CENTER" and not compiled.single`.
  Stacked, each non-literal piece is a row; literal pieces are hidden (`fs:Hide()` after `dressPieces`
  shows them). Row pitch = the line's font size (`s.font.fontSize`, else the template's 12) +
  `C.TEXT_ROW_GAP` (2). Stack height `H = n × size + (n − 1) × gap` for `n` field pieces. Every row is
  anchored by its `TOP` to the text area's `TOP`, at `x = s.x` and `y = s.y − top − (i − 1) × pitch`,
  where `top` is 0 (Top), `(h − H) / 2` (Middle) or `h − H` (Bottom) and `h` is the element height —
  each row centered horizontally under the previous one, **fixed** in position whatever its field
  holds (an engine-written, secret-empty string cannot be measured or collapsed). `Style.ElementSize`
  answers `max(stored height, H)` for a stacked Text container, so the engine's element height, the
  handle, the outline and the preview all grow with it. A one-piece template is not stacked and
  centers as one line exactly as before.
- **D-2, the Containers band.** The band holds the identity controls only (options-ui-§14, one row):
  the Container picker (left half) and **New container** (right half), drawn by the library's
  `Helpers.PageHeader` inside a new host helper `Helpers.ContainerHeader(ctx)`, passed to
  `Helpers.RenderTabbedPage` as its `chrome`. `PageBanner` cannot be "the same helper": it draws
  exactly one Dropdown (`libs/LibKa0s/OptionsTabs.lua:810`), and its own documentation sends a page
  with a picker **and** a create control to `PageHeader`. The block's widgets are released after the
  next render (AbsorbTracker's `releaseStaleChromeWidgets` pattern), and the picker is recorded as
  `ctx.__bannerWidget`, the seam every banner test already reads. **Standard consequence:** with
  picker and New in the band, the remaining acts (Name, Enabled, Duplicate, Delete, Copy settings
  from) stay on the page's first tab, which §14 then requires to be named **`General`**. The tab
  (the schema group of the five identity rows) is renamed from `Containers` to `General`, and the
  `options-ui-§14` row in `docs/ARCHITECTURE.md → Documented deviations` is **retired** (the page now
  conforms). This is the one visible change beyond the spec's wording; flagged in the hand-back.
- **D-3, Restore's cell.** A `RenderGrid` cell after `categoryCell`, a Button at
  `H.BUTTON_PAIR_REL` (a cell-filling button, options-ui-§6). The Weapon enchants entry keeps its
  dropdown alone on the line (it has no list to restore).
- **D-4, `shownWhen` (the LibKa0s widget), and the §4 stop-and-flag.**
  - **Resolved: no deviation, no upstream change required.** options-ui carries exactly one rule that
    keeps a gated control visible and dimmed — the color swatch under its class-color companion
    (options-ui-§17, anti-pattern #74) — and the spec already leaves swatches alone. §6 requires a row
    to stay in the SCHEMA (so `/list`, the CLI, Defaults and the resets see it), which `shownWhen`
    keeps: the row is skipped by the flow engine only. §7's "a subgroup MUST NOT fake a second tab
    level" is about navigation; a switched section is chosen by a **stored setting's value** (the
    setting decides which settings apply), not by a session tab, so it is not a tab level. §11 is met:
    the re-render is scoped to the page (`O.RefreshPanel(ctx, true)`, hidden pages marked dirty),
    runs only when the selector's value actually changed, and is deferred one frame so the dropdown
    whose callback is on the stack is never released under it. A harvest into the standard (a
    sentence in options-ui-§6 naming `shownWhen`) is optional and left to the owner.
  - **The API** (`LibKa0s-Options-1.0`, `OptionsWidgets.lua` minor **22**, Options key
    **21.22.1.7.3**, LibKa0s **v1.45.0**): a row may carry
    `shownWhen = { path = "<selector path>", equals = <value> | { <value>, … } }`. `RenderRows` (the
    flow engine's `flowRows`) drops every row whose selector (read through `readKey`, so a record-backed
    row reads its record) does not equal `equals` (or any entry of an `equals` list) **before** the
    group/subgroup pass, so a subsection whose rows are all hidden draws no heading and takes no
    space, and an `afterGroup` hook fires after the group's last **drawn** row. A predicate that
    raises reads as shown. For every row of the call whose `path` is some row's selector, a refresher
    is added that compares the selector's value to the one this render drew with and, on a change,
    asks for one deferred structural re-render of that page (`C_Timer.After(0, …)`, coalesced per
    ctx; immediate where the client has no `C_Timer`). So a click, a `/<slash> set` and a Defaults
    press all re-render. **Absent, rendering is byte-for-byte unchanged**: the row list is not copied
    and no refresher is added.
  - **Adoption rule** (the sweep): a subsection other than the selector's own whose every row is
    gated by one dropdown's value is switched. A row gated by a dropdown **inside the selector's own
    subsection**, a row gated by a checkbox, a row gated by anything that is not a stored dropdown
    value, and a swatch stay as they are. The hits: Aura Master Layout → Anchor (Screen, Another
    container, Named frame, Offset); Party Frame Enhanced `settings/ElementRows.lua` (Attached to
    party frames, Free placement — one file serving Cast Bars, Target Frames and Pet Frames). The
    sweep's not-a-fit list is Task 17's report.
- **D-5, token output and built-ins.**
  - Percent components use a rule formatter with breakpoints `{ { threshold = 0, step = 1, format = "%d" } }`
    (`step = 1` rounds the engine's fractional 0–100 value to a whole number before `%d` sees it); a
    client that refuses `step` gets `{ { threshold = 0, format = "%d" } }`. The preview writes
    `math.floor(v + 0.5)` with no `%`. No format Aura Master itself authors (the percent rule, an
    unbracketed `$stacks$`'s `%d`) carries a leading or trailing space; bracket text is the player's
    and is kept verbatim.
  - **The `( )` hypothesis** (Task 6 records it and the check): the owner's `($remainingpercent$)` is
    three pieces — literal `(`, the duration run, literal `)`. Whatever the engine wrote into the run
    was EMPTY: either (H1) the old `"%d%%"` rule handed a fractional `RemainingPercent` to `%d` and
    the formatter wrote nothing, or (H2) the aura was timeless and the binding wrote its
    zero-duration text `""` (the engine disables the binding for a zero duration,
    `Blizzard_CustomAuraButton.lua` `ApplyDurationText`). The visible gap is then the empty,
    single-anchored font string itself, which the client lays out with a non-zero width. What the
    addon controls is fixed here (the `%d` + `step` rule, removing H1); the smoke item carries three
    `/run` probes that tell H1, H2 and the empty-string width apart in game.
  - Built-ins live in `core/Constants.lua` as data and are matched by the pure `TT.MatchBuiltin`:
    | key | label | template | justify |
    |---|---|---|---|
    | `name` | Name | `$spellname$` | any but Center |
    | `nameTime` | Name + time | `$spellname$[ - $remainingduration$]` | any but Center |
    | `nameStacksTime` | Name, stacks, time | `$spellname$[ x$stacks$][ - $remainingduration$]` | any but Center |
    | `timeOfMax` | Time / max | `$spellname$[ $remainingduration$ / $maxduration$]` | any but Center |
    | `nameType` | Name (type) | `$spellname$[ ($dispeltype$)]` | any but Center (debuffs) |
    | `nameTypeTime` | Name, type, time | `$spellname$[ ($dispeltype$)][ - $remainingduration$]` | any but Center (debuffs) |
    | `centered` | Centered: name over time | `$spellname$[ - $remainingduration$]` | Center |
    Buffs list `name, nameTime, nameStacksTime, timeOfMax, centered`; debuffs list the same with
    `nameType, nameTypeTime` before `centered`. A stored template matches the first built-in of the
    container's list whose template is identical and whose justify rule holds; none matching reads
    **Custom**. Picking a built-in writes `container.text.template`, then `container.text.justifyH`
    (`CENTER` for `centered`; `LEFT` for any other when the stored justify is `CENTER`), each through
    the seam. Picking **Custom** writes nothing and reveals the Template box for this container for the
    session (`customOpen[id]`); a Custom stored template shows the box always.
  - The Preview renders the compiled template against `C.TEXT_SAMPLE_AURAS[auraType]` (buffs: Ignore
    Pain, 3 stacks, 11 of 12 s, no type; debuffs: Shadow Word: Pain, 0 stacks, 11 of 16 s, Magic)
    through the same fill the placeholders use (`Text.PreviewLine`), one line for Left/Right and one
    line per field row, joined by `\n`, for a stacked Center.
- **D-6, the enchant migration.** Schema step **`to = 5`** (`core/Database.lua`'s `SCHEMA_STEPS` ends
  at 4 today, `Database.CurrentSchemaVersion()` = 4). `Database.MigrateV5(p)` turns every stored
  container with `auraType == "ENCHANT"` into `auraType = "HELPFUL"`, `unit = "player"`,
  `filter.categories = Cat.EnchantOnlyStates()` (= `Cat.StatesShowing({ "weaponEnchants" })`),
  keeping `filter.hidePermanentEnchants` and everything else; one `[Migrate]` line per converted
  container; it returns the count. The v3/v4 steps keep their `ENCHANT` handling (they run before v5
  on an old profile). An enchant-only buff container compiles to **no aura groups and the enchant
  slots**, so `finishWarnings` no longer adds "These filters can never match anything" when
  `plan.enchants` is set (measured: without that change the migrated container shows the warning).
- **D-7, colour by dispel type, and the §7 stop-and-flag.**
  - **Bars (implemented, Task 11):** `bars.bgColorMode` (`"static"` | `"dispel"`, default `"static"`),
    a second `AddDispelTypeTexture` on `am.bg` with the same options as the fill. The engine colors a
    typeless aura from the map's `"None"` key (`GetDispelTypeMapKey` → `"None"`) and otherwise leaves
    Blizzard's own `PreserveAsset` tint, so the owner's "fallback is the normal color" is implemented by
    building each map with `None` = the surface's own resolved color (fill: the bar color; background:
    the background color), memoized per palette and fallback. The profile's `dispelColors.None` swatch
    is then read by nothing, so its row is retired from General → Dispel Colors (the stored leaf stays,
    harmless); flagged in the hand-back. The preview's Magic stand-in covers the background as it does
    the fill.
  - **Owner ruling (2026-09-19), superseding the stop below:** build all three options (a)–(c), each
    opt-in and off by default ("DO all of #1,2,3 - all opt -in - all turned off by default"). Task 12
    is now that build.
  - **Text (Task 12 is a STOP):** **there is no engine path that colors a font string by the aura's
    dispel type.** Evidence: `Blizzard_CustomAuraButton.lua` — `SetDispelTypeText` adds only the
    `Text` and `Shown` secret aspects and writes text through `customDispelTextMap` (`stringView`
    values; `CustomAuraButtonDispelTypeTextOptions` in `AuraContainerUtilDocumentation.lua` has no
    color field); `SetDurationText`'s `textColor` curve is keyed by a `DurationTextBindingProperty`
    (remaining / elapsed / total time or percent, start, end), never the dispel type;
    `customDispelColorMap` and `customDispelColorCurve` exist only on
    `CustomAuraButtonDispelTypeTextureOptions` and `ApplyCustomDispelTypeTextureColor` calls
    `texture:SetVertexColor` — a Texture, not a FontString; `SetSpellName` and `SetApplicationCount`
    take no color at all. Lua cannot color the text itself: in combat every call on a button's objects
    raises (docs/midnight-quirks.md) and the aura data is secret. Task 12 reports this and offers:
    (a) a dispel-tinted **backdrop** behind the Text box (a `WHITE8X8` texture filling `clip`, added
    with `AddDispelTypeTexture` + `customDispelColorMap`, at a player-set alpha); (b) a dispel-tinted
    **edge** (four 1px textures, each added the same way); (c) the `$dispeltype$` piece's **own** text
    colored per type by writing a `|cAARRGGBB…|r` escape into each `customDispelTextMap` value — the
    one real engine path, and only for that piece.
- **D-8, the TEST marker.** While `NS.State.testMode` is on, the handle label reads
  `<name>  |cffff8000TEST|r` (`C.TEST_TAG_COLOR = "ffff8000"`, the tag through `NS.L`). The handle
  shows while unlocked, so the marker shows on an unlocked container in test mode; test mode's
  toggle already sends `VISIBILITY_CHANGED`, whose pass calls `Anchors.UpdateHandle`, so the label
  follows without a new subscription. The detached measure (D-E) measures the tagged text.
- **D-9, the right-click route.** The handle's and the help mark's right-click (they share
  `openSettings`) refuses under combat lockdown **before** touching the selection (so a refused
  click moves nothing), then `NS.State.SetActiveContainer(id)`, `NS.RefreshOptionsPanel()` (so an
  already-built Containers page redraws on the new subject) and `NS.OpenOptionsPage("containers")`,
  which prints options-ui-§2's gray refusal and calls `Settings.OpenToCategory` with the Containers
  category. Left-click and drag are unchanged.
- **D-10, the bulk write.** Show all / Hide all run `NS.Bulk.Run("show all" | "hide all",
  "<Blizzard categories | Spell categories> on container <id>", fn)`, where `fn` writes every category
  row of that grid for the container's aura type through `NS.SetByPath("container.filter.categories.<key>",
  state, id)`. The bracket mutes the per-row `[Set]` lines and logs one `[Set] show all … : N rows`;
  the writes' `CONFIG_CHANGED`s coalesce into one apply pass (`ContainerManager`'s next-frame flush).
  The buttons sit under each grid's heading, above the grid (`H.InlineButtonPair`).

## The citation re-point helper (used by every task that moves cited lines)

Each task is committed before the next starts, so `HEAD` always holds the cited lines' original text
for the task in progress. This helper reads the docs suite's drift report and moves each `file:line`
citation to the line that now holds the same text. Save it once as `/tmp/citefix.py` (outside the
repo; the Write tool) and run it from the repo root after a failing docs case:

```python
# /tmp/citefix.py — re-point drifted file:line citations by the cited line's original text (HEAD).
import re, subprocess, sys
out = sys.stdin.read()
drift = (re.findall(r'  (\S+\.md) cites (\S+?):(\d+)(?:-(\d+))? \(none of', out)
         + re.findall(r'(\S+\.md):\d+ cites (\S+?):(\d+)(?:-(\d+))? \(a blank line\)', out))
for doc, f, a, b in drift:
    old = subprocess.run(['git', 'show', 'HEAD:' + f], capture_output=True, text=True).stdout.replace('\r', '').split('\n')
    cur = open(f, newline='').read().replace('\r', '').split('\n')
    a = int(a); b = int(b) if b else None
    hits = [i + 1 for i, l in enumerate(cur) if l == old[a - 1]]
    if len(hits) != 1:
        print('BY HAND:', doc, f, a, '-', len(hits), 'matches for', repr(old[a - 1])); continue
    na = hits[0]; nb = na + (b - a) if b else None
    was = '%s:%d%s' % (f, a, '-%d' % b if b else '')
    now = '%s:%d%s' % (f, na, '-%d' % nb if nb else '')
    d = open(doc, newline='').read()
    open(doc, 'w', newline='').write(d.replace(was, now))
    print(doc, was, '->', now)
```

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua 2>&1 | python3 /tmp/citefix.py`,
then run the suite again.

---

### Task 1: E — the handle is measured off secret geometry; every geometry read is guarded

**Files:**
- Modify: `core/Secrets.lua` (insert above `--- Whether \`v\` may be used as a TABLE KEY right now.`, line 60)
- Modify: `modules/Anchors.lua` — `SavePosition` (lines 291–298), `BuildHandle` (line 399), a new
  `levelOf` above the doc comment `--- Put the strip on the side the auras do not grow into:` (line 425),
  `handleLevel` (434–442), `placeHandle` (445–458), `UpdateHandle` (496–508)
- Modify: `modules/Container.lua` — `ContainerClass:ApplyBlocker` (lines 208–209)
- Modify: `modules/Style.lua` — `widestSample` (lines 219–220)
- Modify: `docs/midnight-quirks.md` (append a section), and every citation the suite reports drifted
  (measured: `docs/ARCHITECTURE.md`, `docs/common-tasks.md`, `docs/midnight-quirks.md`,
  `docs/performance.md` cite `modules/Container.lua` lines that move down 2)
- Test: `tests/test_anchors.lua` (a helper after `last`, line 205; two cases rewritten; four appended),
  `tests/test_container.lua` (one appended)

**Interfaces:**
- Consumes: nothing new.
- Produces: `NS.Secrets.NumberOr(v, fallback) -> v | fallback` (a readable number, else the fallback);
  `NS.Anchors.__labelMeasurer() -> FontString` (a test seam: tests replace it). Task 4 changes the
  label's text; the measure follows it because `placeHandle` now takes the text as its third argument.

- [ ] **Step 1: Write the failing tests**

In `tests/test_anchors.lua`, directly after the `last` helper (`local function last(f, method) … end`,
ending line 205), add:

```lua

--- Measure every handle label as `width` wide: the handle sizes itself from a detached measuring
--- string (Anchors.__labelMeasurer, feedback E), never from the label, whose width can read secret.
local function measureAs(NS, width)
    NS.Anchors.__labelMeasurer = function()
        return { SetText = function() end, GetStringWidth = function() return width end }
    end
end
```

In the case "handle: at least as wide as its container's element, and as its label with room for the
help mark", replace

```lua
    rawset(h, "GetStringWidth", function() return w + 100 end)   -- the label is the handle's font string
```

with

```lua
    measureAs(NS, w + 100)
```

In the case "handle: while shown the anchor's clamp rect takes it in; hidden, or in combat, the rect is
left alone", replace `    rawset(h, "GetStringWidth", function() return w + 100 end)` with
`    measureAs(NS, w + 100)`.

Append to the end of `tests/test_anchors.lua`:

```lua

-- ── secret geometry (feedback E, 2026-09-19) ──────────────────────────────────────────────────
-- An anchor attached to an engine container, or to a frame anchored to one, inherits its secret
-- geometry, and so does everything anchored under it: the strip, its label. The client then answers
-- a width or a frame level as a secret number, and arithmetic on one raises ("attempt to perform
-- arithmetic on a secret number value", modules/Anchors.lua:452 before the fix). The harness cannot
-- make a number raise, so a case plants the client's issecretvalue on a sentinel number, and makes
-- the label's own GetStringWidth raise the client's error outright.

local SECRET = 41.5

--- A fresh environment whose client calls SECRET a secret number.
local function secretEnv()
    local NS, mocks = fresh()
    mocks.issecretvalue = function(v) return v == SECRET end
    return NS, mocks
end

test("handle: the width comes from a detached measuring string, never the label, which may sit on secret geometry (E)", function()
    local NS, mocks = fresh()
    local inst = NS.ContainerManager.instances[1]
    local h = recordedHandle(mocks, NS, inst)
    local w = NS.Style.ElementSize(NS.Database.FindContainer(1))
    -- The label is the strip in the kit (a font string comes back as its frame).
    rawset(h, "GetStringWidth", function() error("attempt to perform arithmetic on a secret number value") end)
    local measured = {}
    NS.Anchors.__labelMeasurer = function()
        return {
            SetText = function(_, s)
                local n = #measured
                measured[n + 1] = s
            end,
            GetStringWidth = function() return w + 100 end,
        }
    end
    local ok, err = pcall(NS.Anchors.UpdateHandle, inst, true)
    -- red under: placeHandle reading handle.label:GetStringWidth() (the reported error)
    assertTrue(ok, tostring(err))
    assertEqual(last(h, "SetWidth")[1], w + 100 + 24 + 14 * 2, "the measured width sizes the strip")
    assertEqual(measured[#measured], NS.Database.FindContainer(1).name, "the label's own text is measured")
end)

test("handle: a measured width that reads secret falls back to the element's width, never raising (E)", function()
    local NS, mocks = secretEnv()
    local inst = NS.ContainerManager.instances[2]   -- a 32px icon row: the floor and the label differ
    local h = recordedHandle(mocks, NS, inst)
    NS.Anchors.__labelMeasurer = function()
        return { SetText = function() end, GetStringWidth = function() return SECRET end }
    end
    NS.Anchors.UpdateHandle(inst, true)
    -- red under: labelWidth without its NumberOr guard (41.5 + 52 = 93.5 in the harness; a raise in
    -- the client)
    assertEqual(last(h, "SetWidth")[1], math.max(24 + 14 * 2, NS.Style.ElementSize(NS.Database.FindContainer(2))))
end)

test("handle: an anchor whose frame level reads secret places the strip from the stored level (E)", function()
    local NS, mocks = secretEnv()
    local inst = NS.ContainerManager.instances[1]
    local h = recordedHandle(mocks, NS, inst)
    rawset(inst.anchor, "GetFrameLevel", function() return SECRET end)
    local ok, err = pcall(NS.Anchors.UpdateHandle, inst, true)
    assertTrue(ok, tostring(err))
    -- red under: handleLevel adding HANDLE_LEVEL to the unguarded read (41.5 + 50)
    assertEqual(h:GetFrameLevel(), NS.CONTAINER_TEMPLATE.layout.level + 50)
end)

test("anchors: a drag whose offsets read secret saves nothing (E)", function()
    local NS = secretEnv()
    local inst = NS.ContainerManager.instances[1]
    inst.anchor.GetPoint = function() return "TOP", nil, "TOP", SECRET, -30 end
    local writes = 0
    NS.NewBusTarget():RegisterMessage(NS.MSG.CONFIG_CHANGED, function() writes = writes + 1 end)
    local ok, err = pcall(NS.Anchors.SavePosition, inst)
    assertTrue(ok, tostring(err))
    -- red under: SavePosition rounding and storing a secret offset
    assertEqual(writes, 0)
    assertEqual(NS.Database.FindContainer(1).position.x, NS.STARTER_CONTAINERS[1].position.x)
end)
```

Append to the end of `tests/test_container.lua`:

```lua

-- red under: ApplyBlocker's unguarded "engineLevel - 1" (feedback E): an engine attached to secret
-- geometry can answer its frame level secret, and the client raises on the arithmetic.
test("container: an engine whose frame level reads secret leaves the blocker at level 0, never raising (E)", function()
    local NS, mocks = fresh()
    local SECRET = 41.5
    mocks.issecretvalue = function(v) return v == SECRET end
    local inst = NS.ContainerManager.instances[1]
    rawset(inst.engine, "GetFrameLevel", function() return SECRET end)
    local ok, err = pcall(inst.ApplyBlocker, inst, inst:Cfg())
    assertTrue(ok, tostring(err))
    assertEqual(inst.blocker:GetFrameLevel(), 0)
end)
```

- [ ] **Step 2: Run them and see them fail**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua 2>&1 | grep -A3 -E "\(E\)|at least as wide|clamp rect takes it in"`
Expected: FAIL — the detached-measure case fails `ok` with "attempt to perform arithmetic on a secret
number value"; the secret-width case `expected 52, got 93.5`; the frame-level case `expected 55, got
91.5`; the drag case `expected 0, got 1`; the blocker case `expected 0, got 40.5`; the two rewritten
cases fail on the width (`expected 372, got 220`, `expected 0,152,20,0, got 0,0,20,0`): the handle
still reads its label.

- [ ] **Step 3: Implement**

`core/Secrets.lua`, directly above `--- Whether \`v\` may be used as a TABLE KEY right now.`:

```lua
--- `v` when it is a plain, readable number, else `fallback`. The one guard in front of a GEOMETRY
--- read (a width, a frame level, an offset): a region anchored to secret geometry answers secret
--- numbers even out of combat, and arithmetic on one raises (modules/Anchors.lua, feedback E).
--- @param v any
--- @param fallback any
--- @return any
function Secrets.NumberOr(v, fallback)
    if Secrets.IsReadableNumber(v) then return v end
    return fallback
end

```

`modules/Anchors.lua`:

1. In `Anchors.SavePosition`, after `    if not point then return end` insert:

```lua
    -- A screen-attached anchor holds nothing secret, but a read is guarded anyway (feedback E): a
    -- secret offset would raise in round(), and storing one would poison the saved position.
    local S = NS.Secrets
    if not (S.CanAccess(point) and S.CanAccess(relPoint) and S.CanAccess(x) and S.CanAccess(y)) then
        if NS.Debug then NS.Debug("Anchor", "container %s: position reads secret, not saved", container.id) end
        return
    end
```

2. In `Anchors.BuildHandle`, replace
`    handle:SetFrameLevel((anchor:GetFrameLevel() or 0) + HANDLE_LEVEL)` with
`    handle:SetFrameLevel(NS.Secrets.NumberOr(anchor:GetFrameLevel(), 0) + HANDLE_LEVEL)`.

3. Directly above the doc comment line `--- Put the strip on the side the auras do not grow into: above the anchor when they grow down,` insert:

```lua
--- A frame's level, READ GUARDED (feedback E): an anchor attached to an engine container, or to a
--- frame anchored to one, can answer its level secret (FrameLevel is a secret aspect), and
--- arithmetic on a secret raises. An unreadable level is the one Container:Apply set from the stored
--- `layout.level`.
local function levelOf(frame, cfg)
    local stored = tonumber(cfg and cfg.layout and cfg.layout.level) or D.layout.level
    return NS.Secrets.NumberOr(frame:GetFrameLevel(), stored)
end

```

4. Replace `handleLevel` and `placeHandle`'s head — from
`--- Levels order frames within one strata only: a target in a higher strata still draws on top.` down
to and including
`    local width = math.max((tonumber(handle.label:GetStringWidth()) or 0) + HANDLE_PAD + HANDLE_HELP * 2, w)`
— with:

```lua
--- Levels order frames within one strata only: a target in a higher strata still draws on top.
--- Every level is read through levelOf (feedback E).
local function handleLevel(container, cfg)
    local level = levelOf(container.anchor, cfg) + HANDLE_LEVEL
    local at = cfg.attach
    local target = at and at.mode == "container" and targetContainer(container, at)
    if target then
        level = math.max(level, levelOf(target.anchor, target:Cfg()) + HANDLE_LEVEL + 1)
    end
    return level
end

-- The label's width is MEASURED on a font string of our own that is never anchored to anything
-- (feedback E, 2026-09-19). The label itself hangs off the strip, the strip off the anchor, and an
-- anchor attached to an engine container (or to a frame anchored to one) inherits its secret
-- geometry: reading the label's width then answered a secret number, and the arithmetic below
-- raised "attempt to perform arithmetic on a secret number value" out of combat. The same idea as
-- modules/Style.lua's time-text measurer (B4).
local labelFS   -- the hidden measuring string, built on first use

--- The FontString a handle's label is measured on: hidden, parented to a hidden frame of ours on
--- UIParent, in the label's own font. A test replaces this function to measure on a stand-in.
function Anchors.__labelMeasurer()
    if labelFS == nil then
        local host = CreateFrame("Frame", nil, UIParent)
        host:Hide()
        labelFS = host:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    end
    return labelFS
end

--- The width `text` takes in the label's font, or 0 when it cannot be read.
local function labelWidth(text)
    local fs = Anchors.__labelMeasurer()
    if not fs then return 0 end
    fs:SetText(text or "")
    return NS.Secrets.NumberOr(fs:GetStringWidth(), 0)
end

--- @return number  how far the strip runs past the anchor along the line
local function placeHandle(container, cfg, text)
    local handle = container.handle
    handle:SetFrameLevel(handleLevel(container, cfg))
    local growH, growV = NS.Container.Growth(Anchors.EffectiveLayout(cfg) or {})
    local toward = NS.Container.AnchorPoint(growH, growV)       -- the corner the auras start from
    local away = NS.Container.AnchorPoint(growH, (growV == "down") and "up" or "down")
    local w = NS.Style.ElementSize(cfg)
    local width = math.max(labelWidth(text) + HANDLE_PAD + HANDLE_HELP * 2, w)
```

(The rest of `placeHandle` — `handle:ClearAllPoints()` to `return width - w` — is unchanged.)

5. In `Anchors.UpdateHandle`, replace

```lua
    handle.label:SetText(cfg and cfg.name or "")
    if not InCombatLockdown() then
        clampToHandle(container, cfg, show and placeHandle(container, cfg) or nil)
    elseif show and not handle.placed then
        placeHandle(container, cfg)
    end
```

with

```lua
    local text = cfg and cfg.name or ""
    handle.label:SetText(text)
    if not InCombatLockdown() then
        clampToHandle(container, cfg, show and placeHandle(container, cfg, text) or nil)
    elseif show and not handle.placed then
        placeHandle(container, cfg, text)
    end
```

`modules/Container.lua`, in `ContainerClass:ApplyBlocker`, replace

```lua
    local ok, engineLevel = pcall(engine.GetFrameLevel, engine)
    blocker:SetFrameLevel(math.max(0, (ok and engineLevel or 0) - 1))
```

with

```lua
    local ok, engineLevel = pcall(engine.GetFrameLevel, engine)
    -- Guarded (feedback E): an engine's level can read secret, and arithmetic on it raises.
    local level = ok and NS.Secrets.NumberOr(engineLevel, 0) or 0
    blocker:SetFrameLevel(math.max(0, level - 1))
```

`modules/Style.lua`, in `widestSample`, replace `        if type(w) ~= "number" then return nil end`
with `        if not NS.Secrets.IsReadableNumber(w) then return nil end`.

`docs/midnight-quirks.md`, append:

```markdown

## An attached anchor's geometry is secret

**The restriction.** A frame anchored to an aura engine container — or to any frame anchored to one —
inherits its secret geometry, and so does everything anchored under it. Its width, its points and its
frame level (`FrameLevel` is a `SecretAspect`) can read back as secret numbers even out of combat, and
arithmetic on a secret raises "attempt to perform arithmetic on a secret number value" (feedback E,
2026-09-19: the drag handle's label, on a container attached to another).

**What this addon does.** Nothing reads a measurement off a region that can be attached. The handle's
label is measured on a detached font string of ours (`Anchors.__labelMeasurer`), and every frame level
or offset read goes through `NS.Secrets.NumberOr`, which answers a fallback (the stored level, 0, or
"do not save") for a value that is not a plain number.
```

- [ ] **Step 4: Run them and see them pass**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua 2>&1 | grep -A3 -E "\(E\)|at least as wide|clamp rect takes it in|FAIL"`
Expected: every case above PASSES. The docs case fails with five citations of `modules/Container.lua`
that moved down 2: pipe the run into `/tmp/citefix.py`. It re-points four and prints one `BY HAND`
line (`docs/ARCHITECTURE.md`, the `SetUnit` citation, whose cited line is a bare `        end`): set
that one to the line `grep -n '"SetUnit"' modules/Container.lua` prints first (`callEngine(engine,
"SetUnit", …)` in `Build`). Run again: 0 failed.

- [ ] **Step 5: Checkpoint — the green gate and complexity**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua && /home/tushar/.claude/wow-addon/bin/ka0s-bounded luacheck . && /home/tushar/.claude/wow-addon/bin/ka0s-bounded lizard -l lua -x "./libs/*" -x "./tests/_kit/*" -C 15 -w .`
Expected: `… passed, 0 failed, 2 skipped …` (the two vendor-sync cases skip only where `../LibKa0s` is
absent), `0 warnings / 0 errors`, and lizard prints no function.

- [ ] **Step 6: Update the Status ledger row for this task (status, commit SHAs, repo) and the resume guide's "Current position" line; commit the plan file with the task's commit**

Row 1 → `done`, Notes: the commit SHA, "AuraMaster". Current position → "Next: Task 2 — not started;
Task 1 done." The controller's commit (after review) is `T1: the handle is measured off secret
geometry; geometry reads guarded (feedback E)` and includes this plan file.

---

### Task 2: #3 — Restore sits beside the Category dropdown

**Files:**
- Modify: `settings/GeneralSpells.lua` — the header sketch (lines 7–8), a new `restoreCell` above the
  `-- Weapon enchants (the Spell Categories tab's non-list entry)` banner (line 219), `renderSpells`
  (lines 276–288)
- Modify: `docs/settings-panel.md:150-151` (where Restore sits)
- Test: `tests/test_pages_general.lua` (one case, before `-- ── the Weapon enchants entry, and the Select seam (B7) ──…`)

**Interfaces:**
- Consumes: `editCategory`, `rerender` (file locals, defined above `restoreCell`), `H.BUTTON_PAIR_REL`.
- Produces: nothing new outside the file. The Restore button's text, tooltip and behavior are
  unchanged; only its place moves.

- [ ] **Step 1: Write the failing test**

In `tests/test_pages_general.lua`, directly above the line
`-- ── the Weapon enchants entry, and the Select seam (B7) ──…`, insert:

```lua
test("general → spell categories: Restore sits on the Category dropdown's line, to its right (feedback #3)", function()
    local NS, _, P, ws = spells()
    local dd = P.find(ws, "Dropdown", NS.L["Category"])
    local restore = P.find(ws, "Button", NS.L["Restore this category's starter list"])
    local line
    for _, w in ipairs(ws) do
        if w.children and w.children[1] == dd then line = w end
    end
    -- red under: Restore still drawn by InlineButtonPair on a line of its own under the dropdown
    assertTrue(line ~= nil, "the dropdown heads a grid line")
    assertTrue(line.children[2] == restore, "Restore is the same line's second cell")
    assertEqual(restore.relativeWidth, NS.Helpers.BUTTON_PAIR_REL, "a cell-filling button takes the inset width")
end)

```

- [ ] **Step 2: Run it and see it fail**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua 2>&1 | grep -A3 "feedback #3"`
Expected: FAIL — "Restore is the same line's second cell" (the dropdown's line holds the dropdown
alone; Restore is on the InlineButtonPair line under it).

- [ ] **Step 3: Implement**

`settings/GeneralSpells.lua`:

1. In the header sketch, replace

```lua
--     Spell Categories  [Category ▾]  -- one of the nine spell-list categories, or Weapon enchants
--                       [Restore this category's starter list]
```

with

```lua
--     Spell Categories  [Category ▾]  [Restore this category's starter list]
--                       -- one of the nine spell-list categories, or Weapon enchants
```

2. Directly above the banner

```lua
-- ---------------------------------------------------------------------------
-- Weapon enchants (the Spell Categories tab's non-list entry)
```

insert:

```lua
--- The Restore button, as the Category dropdown's right half (a RenderGrid cell, feedback #3): on
--- the same line, so the list's one reset sits beside the control that picks the list. A
--- cell-filling button, so it takes the library's inset width (options-ui-§6), never a flush half.
local function restoreCell(key)
    return { make = function(_, parent)
        local btn = NS.AceGUI:Create("Button")
        btn:SetText(L["Restore this category's starter list"])
        btn:SetRelativeWidth(H.BUTTON_PAIR_REL)
        btn:SetCallback("OnClick", function()
            editCategory(key, function(mine)
                for id in pairs(mine) do mine[id] = nil end
            end)
            rerender()
        end)
        H.AttachTooltip(btn, L["Restore this category's starter list"],
            L["Forget every edit to this category: its removed starter spells come back and the spells you added are removed. Other categories keep theirs."])
        parent:AddChild(btn)
        return btn
    end }
end

```

3. In `renderSpells`, replace

```lua
    H.RenderGrid(ctx, { categoryCell(defs, def) })
    -- At the top, under the dropdown (B2): with the checkboxes gone, a removed starter is off the
    -- list, and this is how it comes back.
    H.InlineButtonPair(ctx, {
        text    = L["Restore this category's starter list"],
        tooltip = L["Forget every edit to this category: its removed starter spells come back and the spells you added are removed. Other categories keep theirs."],
        onClick = function()
            editCategory(key, function(mine)
                for id in pairs(mine) do mine[id] = nil end
            end)
            rerender()
        end,
    }, nil)
```

with

```lua
    -- Restore on the dropdown's line (feedback #3): with the checkboxes gone (B2) a removed starter is
    -- off the list, and this is how it comes back.
    H.RenderGrid(ctx, { categoryCell(defs, def), restoreCell(key) })
```

(The Weapon enchants branch above it keeps `H.RenderGrid(ctx, { categoryCell(defs, def) })`: no list,
no restore.)

`docs/settings-panel.md`, lines 150–151: replace

```markdown
an added spell's X forgets it), and **Restore this category's starter list** at the top, under the
Category dropdown and above Add a spell.
```

with

```markdown
an added spell's X forgets it), and **Restore this category's starter list** on the Category
dropdown's own line, to its right (feedback #3), above Add a spell.
```

- [ ] **Step 4: Run it and see it pass**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua 2>&1 | grep -A3 -E "feedback #3|Restore sits above|FAIL"`
Expected: PASS for the new case, and the B2 case "Restore sits above the Add line and clears that
category's edits and no other's" still PASSES (Restore is still above Add a spell). No citation moves
(no doc cites `settings/GeneralSpells.lua` by line).

- [ ] **Step 5: Checkpoint — the green gate**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua && /home/tushar/.claude/wow-addon/bin/ka0s-bounded luacheck .`
Expected: 0 failed; `0 warnings / 0 errors`.

- [ ] **Step 6: Update the Status ledger row for this task (status, commit SHAs, repo) and the resume guide's "Current position" line; commit the plan file with the task's commit**

Row 2 → `done` with the SHA; Current position → "Next: Task 3 — not started; Tasks 1–2 done." Commit:
`T2: Restore sits beside the Category dropdown (feedback #3)`, with this plan file.

---

### Task 3: #2 — the Containers page's picker and New container move into the band above the strip

**Files:**
- Modify: `settings/OptionsSetup.lua` — the degraded stub's member list (line 313), `Helpers.ContainerPickerCell` (lines 447–465) replaced by `Helpers.ContainerHeader`
- Modify: `settings/Containers.lua` — the header (lines 5–7 and 18–23), `GROUP` (line 35), `newCell` and `render` (lines 218–238), a renderer above `build` (line 253), `H.SetRenderer` (line 263)
- Modify: `locales/enUS.lua:542` (the picker tooltip: "this tab" → "this page")
- Modify: `docs/ARCHITECTURE.md:624` (the `options-ui-§14` row is **deleted**), `docs/settings-panel.md` (lines 63–68, 169–171, 472), `docs/module-map.md` (lines 99, 158), `docs/smoke-tests.md` (item 23)
- Test: `tests/test_pages_containers.lua` (header comment; cases at lines 42, 136, 194, 242), `tests/test_options_descriptor.lua` (cases at lines 204, 318), `tests/test_pages_general.lua:273`, `tests/test_optionssetup.lua:174`

**Interfaces:**
- Consumes: the library's `Helpers.PageHeader(ctx, { height, build })`, `Helpers.BANNER_H`,
  `Helpers.RenderTabbedPage(ctx, pageKey, spec, chrome)` (its existing `chrome` argument).
- Produces: `Helpers.ContainerHeader(ctx, spec)` (`spec.onNew`), which records its widgets on
  `ctx.__chromeWidgets` and the picker on `ctx.__bannerWidget` (the seam Task 13's right-click test
  reads). The Containers page's one tab is the schema group `L["General"]`. `ContainerPickerCell` is
  gone (its only caller was this page).

- [ ] **Step 1: Rewrite the tests to the new shape**

`tests/test_pages_containers.lua`:

1. In the file's header comment, replace
   `-- top-level Containers page (N-1, batch 7) — its own Blizzard category, its one tab's picker and New`
   `-- container inside the tab body (the options-ui-§14 deviation, docs/ARCHITECTURE.md), the identity`
   `-- rows and what each writes,`
   with
   `-- top-level Containers page (N-1, batch 7) — its own Blizzard category, its picker and New container`
   `-- in the chrome block above the strip (feedback #2, options-ui-§14), its one tab, General, with the`
   `-- identity rows and what each writes,`.

2. The case at line 42: rename it to
   `"containers: registers its own top-level Blizzard category, with one tab, General (N-1, options-ui-§14)"`,
   change its red-under comment to
   `-- red under: the page drawing more than its one tab, or the tab not named General (options-ui-§14`
   `-- names the tab holding a page's acts, under a band carrying its picker)`,
   and change both `NS.L["Containers"]` in it (the tab-key assertion and the `row.group` assertion) to
   `NS.L["General"]`.

3. Replace the whole case at line 136 ("containers: the tab body opens with the Container picker and
   New container on one line") with:

```lua
--- The chrome block's two controls, as the last render drew them: the picker and New container.
local function headerWidgets(NS)
    local ctx = NS.Helpers.__pageCtx.containers
    local picker, new
    for _, w in ipairs(ctx.__chromeWidgets or {}) do
        if w.type == "Dropdown" and w.labelText == NS.L["Container"] then picker = w end
        if w.type == "Button" and w.text == NS.L["New container"] then new = w end
    end
    return picker, new
end

test("containers: the picker and New container sit in the band above the strip, drawn before it (feedback #2)", function()
    local NS, _, P = containers()
    local H = NS.Helpers
    local order, real = {}, {}
    for _, name in ipairs({ "PageHeader", "TabStrip" }) do
        real[name] = H[name]
        H[name] = function(...)
            local n = #order
            order[n + 1] = name
            return real[name](...)
        end
    end
    P.rerender("Containers")
    H.PageHeader, H.TabStrip = real.PageHeader, real.TabStrip
    -- red under: the page drawing no chrome block, or drawing it after the strip (its band unreserved)
    assertEqual(table.concat(order, ","), "PageHeader,TabStrip", "the band, then the tabs")
    local picker, new = headerWidgets(NS)
    -- red under: the picker and New still drawn in the tab body (the retired options-ui-§14 deviation)
    assertTrue(picker ~= nil and new ~= nil, "both drawn in the band")
    assertFalse(inScroll(NS, picker) or inScroll(NS, new), "neither in the tab body")
    assertTrue(H.__pageCtx.containers.__bannerWidget == picker, "the picker is the page's banner widget")
    assertEqual(table.concat(picker.order, ","), "1,2,3,4")
    assertTrue(picker.list[2]:find("(Player debuffs, icons)", 1, true) ~= nil, "what it shows: " .. picker.list[2])
end)
```

4. In the case at line 194, rename it to
   `"containers: Delete keeps the band's picker and New through both refreshes, and the picker lists what remains (C-3)"`
   and replace everything after `    assertEqual(renders, 2, "the popup's own refresh, then the registry change's")`
   up to the case's closing `end)` with:

```lua
    -- red under: the block drawn only on a first render, or its widgets released by the render that
    -- drew them (the reported loss: no picker and no New after a delete)
    local picker, new = headerWidgets(NS)
    assertTrue(picker ~= nil and not picker.__released, "the band's picker is live after both renders")
    assertTrue(new ~= nil and not new.__released, "and so is New container")
    assertEqual(table.concat(picker.order, ","), "1,3,4", "the picker lists the remaining containers")
    local live = 0
    for _, w in ipairs(P.all(after, "Dropdown", NS.L["Container"])) do
        if not w.__released then live = live + 1 end
    end
    -- red under: the stale block's widgets never handed back to AceGUI (one more per render)
    assertEqual(live, 1, "the first render's picker was released; one picker is left")
end)
```

5. In the case at line 242, rename it to
   `"containers: with no containers the page draws the band's picker and New, and one line instead of the rows"`
   and replace its three lines

```lua
    assertEqual(P.tabKeys("containers")[1], NS.L["Containers"])
    assertTrue(P.find(ws, "Button", NS.L["New container"]) ~= nil, "New is still offered")
    assertTrue(P.find(ws, "Dropdown", NS.L["Container"]) ~= nil, "the picker is drawn, empty")
```

   with

```lua
    assertEqual(P.tabKeys("containers")[1], NS.L["General"])
    local picker, new = headerWidgets(NS)
    assertTrue(new ~= nil, "New is still offered")
    assertTrue(picker ~= nil and picker.order[1] == nil, "the picker is drawn, empty")
```

`tests/test_options_descriptor.lua`:

1. Replace the whole case at line 204 ("options descriptor: Containers' picker is a plain dropdown in
   the tab body that selects") with:

```lua
test("options descriptor: Containers' picker sits in the chrome block above the strip and selects (feedback #2)", function()
    local NS2 = fresh()
    NS2.State.SetActiveContainer(1)
    NS2.Helpers.__pageCtx.containers.panel:__fire("OnShow")
    local ctx = NS2.Helpers.__pageCtx.containers
    local dd = ctx.__bannerWidget
    -- red under: the picker still drawn in the tab body (the retired options-ui-§14 deviation)
    assertTrue(dd ~= nil and dd.type == "Dropdown", "the band carries the picker")
    assertEqual(dd.labelText, "Container")
    assertTrue((ctx.__bannerHeight or 0) > 0, "and reserves the band above the strip")
    assertEqual(table.concat(dd.order, ","), "1,2,3,4")
    dd:__fire("OnValueChanged", 2)
    -- red under: the header's callback not reaching SelectContainer
    assertEqual(NS2.State.activeContainerId, 2)
end)
```

2. In the case at line 318, change `tabs = { { key = "Containers", label = "Containers", render = …`
   to `tabs = { { key = "General", label = "General", render = …`, the assertion
   `assertEqual(table.concat(keys, ","), "Containers")` to `…, "General")`, and
   `clickTab(ctx, "Containers")` to `clickTab(ctx, "General")`.

`tests/test_pages_general.lua:273`: `assertEqual(row.group, NS.L["Containers"], path)` →
`assertEqual(row.group, NS.L["General"], path)`.

`tests/test_optionssetup.lua:174`: the message `"the tab body carries the create control"` →
`"the band carries the create control"`.

- [ ] **Step 2: Run them and see them fail**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua 2>&1 | grep -A3 -E "feedback #2|C-3|with no containers|one tab, General|addon-wide tabbed|tab strip reads Master"`
Expected: FAIL — the order case `expected PageHeader,TabStrip, got TabStrip`; the descriptor case "the
band carries the picker"; the C-3 case "the band's picker is live after both renders"; the three
tab-name cases `expected General, got Containers`.

- [ ] **Step 3: Implement**

`settings/OptionsSetup.lua`:

1. In the degraded stub's member list, `"SelectContainer", "ContainerBanner", "ContainerPickerCell", "RenderWarnings",`
   → `"SelectContainer", "ContainerBanner", "ContainerHeader", "RenderWarnings",`.

2. Replace the whole of `Helpers.ContainerPickerCell` with its doc comment (from
   `--- The picker as a plain AceGUI Dropdown in a page's BODY: …` to its `end`) with:

```lua
-- The Containers page's CHROME BLOCK (options-ui-§14, feedback #2): the picker and New container on
-- one row above the tab strip. Not Helpers.PageBanner, which draws exactly one Dropdown: a page with
-- a picker AND a create control puts both in the library's PageHeader frame, and the host places
-- what it draws inside it. Its widgets are recorded on ctx.__chromeWidgets, which settings/Containers.lua
-- releases after the NEXT render: a render is usually running inside one of their own callbacks.
local HEADER_CONTROL_H = 24   -- AceGUI's Button frame height
local HEADER_PAIR_GAP  = 4    -- half the gutter between the block's two halves

--- Anchor one AceGUI widget's frame inside the block, on its LEFT or RIGHT half.
local function placeInHeader(widget, frame, y, height, half)
    local f = widget and widget.frame
    if not f then return end
    f:SetParent(frame)
    f:ClearAllPoints()
    if half == "LEFT" then
        f:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -y)
        f:SetPoint("TOPRIGHT", frame, "TOP", -HEADER_PAIR_GAP, -y)
    else
        f:SetPoint("TOPLEFT", frame, "TOP", HEADER_PAIR_GAP, -y)
        f:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -y)
    end
    f:SetHeight(height)
    f:Show()
end

--- The block's two controls, built into the frame PageHeader hands over.
local function buildContainerHeader(ctx, frame, spec)
    local kids = ctx.__chromeWidgets
    local list, order = containerList()
    local _, activeId = NS.ActiveContainer()
    local dd = NS.AceGUI:Create("Dropdown")
    kids[#kids + 1] = dd
    dd:SetLabel(L["Container"])
    dd:SetList(list, order)
    dd:SetValue(activeId)
    dd:SetCallback("OnValueChanged", function(_, _, id)
        if id == nil or id == activeId then return end
        Helpers.SelectContainer(id)
    end)
    Helpers.AttachTooltip(dd, L["Container"], L["Which container this page, and the Filters, Layout, Bars, Icons and Text pages, edit. The choice is shared by every page."])
    placeInHeader(dd, frame, 0, Helpers.BANNER_H, "LEFT")
    ctx.__bannerWidget = dd

    local btn = NS.AceGUI:Create("Button")
    kids[#kids + 1] = btn
    btn:SetText(L["New container"])
    btn:SetCallback("OnClick", function() if spec.onNew then spec.onNew() end end)
    Helpers.AttachTooltip(btn, L["New container"], L["Create a container showing the player's buffs as bars. Change what it shows below."])
    -- Level with the dropdown's control, not its label: the labeled dropdown is BANNER_H tall with
    -- the control at its foot.
    placeInHeader(btn, frame, Helpers.BANNER_H - HEADER_CONTROL_H - 1, HEADER_CONTROL_H, "RIGHT")
end

--- The Containers page's chrome: the picker and New container, one row above the strip. Called as
--- RenderTabbedPage's `chrome`, so it is drawn before the strip reserves its band. `spec.onNew` is
--- the page's own create act.
function Helpers.ContainerHeader(ctx, spec)
    ctx.__chromeWidgets = ctx.__chromeWidgets or {}
    ctx.__bannerWidget = nil
    return Helpers.PageHeader(ctx, {
        height = Helpers.BANNER_H,
        build  = function(_, frame) buildContainerHeader(ctx, frame, spec or {}) end,
    })
end
```

`settings/Containers.lua`:

1. The sketch lines

```lua
--     [ Containers ]
--     Containers  [Container v picker ][ New container ]            <- the tab body's first line
--                 [Name] [Enabled]
```

become

```lua
--     band        [Container v picker ][ New container ]            <- above the strip (options-ui-§14)
--     [ General ]
--     General     [Name] [Enabled]
```

2. The paragraph from `-- THE PICKER AND NEW CONTAINER SIT IN THE TAB BODY, not in a band above the strip. That is this`
   to `-- lose them.` becomes:

```lua
-- THE PICKER AND NEW CONTAINER SIT IN THE BAND ABOVE THE STRIP (feedback #2, 2026-09-19), in the
-- library's chrome block (Helpers.ContainerHeader, settings/OptionsSetup.lua): the identity controls
-- options-ui-§14 puts there, on one row. The acts on the selected container — Name, Enabled,
-- Duplicate, Delete, Copy settings from — stay on the page's one tab, which §14 then names General.
-- This retired the page's options-ui-§14 deviation (docs/ARCHITECTURE.md). The block is drawn anew
-- on every render, so a Delete's two refreshes cannot lose it; the widgets of the render before are
-- released after each render (releaseStale), never during one.
```

3. `local GROUP = L["Containers"]` becomes

```lua
-- options-ui-§14: the tab holding a page's acts, under a band carrying its picker, is named General.
local GROUP = L["General"]
```

4. Delete `newCell` (from `local function newCell(_, parent, rel)` to its `end`) and replace the
   `render` doc comment and its first line

```lua
--- The Containers tab: the picker and New container on one line, then the selected container's
--- identity rows and the acts on it. With no container there is nothing to edit: the line, then
--- the one sentence saying how to make one.
local function render(ctx, cfg, rows)
    H.RenderGrid(ctx, { { make = H.ContainerPickerCell }, { make = newCell } })
```

   with

```lua
--- The General tab: the selected container's identity rows and the acts on it. With no container
--- there is nothing to edit: the one sentence saying how to make one (the band still offers New).
local function render(ctx, cfg, rows)
```

5. Directly above `local function build(mainCategory)` insert:

```lua
local HEADER = { onNew = doNew }
local function header(ctx) H.ContainerHeader(ctx, HEADER) end

--- Hand the previous render's chrome widgets back to AceGUI. AFTER the render, never before: the
--- render is usually running inside one of their callbacks (the picker's, New's), and a widget
--- released on the way in could be handed straight back out, re-initialized, under its own callback.
local function releaseStale(stale)
    local AceGUI = NS.AceGUI
    if not (AceGUI and AceGUI.Release and stale) then return end
    for _, w in ipairs(stale) do AceGUI:Release(w) end
end

local function renderPage(ctx)
    local stale = ctx.__chromeWidgets
    ctx.__chromeWidgets = {}
    H.RenderTabbedPage(ctx, PAGE, PAGE_SPEC, header)
    releaseStale(stale)
end

```

6. `    H.SetRenderer(ctx, function(c) H.RenderTabbedPage(c, PAGE, PAGE_SPEC) end)` →
   `    H.SetRenderer(ctx, renderPage)`.

`locales/enUS.lua:542`: replace the key/value
`"Which container this tab, and the Filters, Layout, Bars, Icons and Text pages, edit. The choice is shared by every page."`
with `"Which container this page, and the Filters, Layout, Bars, Icons and Text pages, edit. The choice is shared by every page."`
(both sides of the `=`).

Docs:
- `docs/ARCHITECTURE.md`: **delete** the Documented deviations row that starts `` | `options-ui-§14` | The `Containers` page's one tab edits one selected container, … `` (line 624). The page now conforms.
- `docs/settings-panel.md`, the bullet at lines 63–68, becomes:

```markdown
- **Containers** carries the page's identity controls in the band, as options-ui-§14 asks: its Container
  picker and **New container** on one row, drawn by `Helpers.ContainerHeader` through the library's
  `PageHeader` chrome block (feedback #2, 2026-09-19; `PageBanner` draws exactly one dropdown). The acts
  on the selected container (Name, Enabled, Duplicate, Delete, Copy settings from) stay on the page's
  one tab, which §14 then names **General**. The block is drawn on every render, so a Delete's two
  refreshes cannot lose it, and the widgets of the render before are released after each render.
```

  and lines 169–171 become:

```markdown
A top-level page (`N-1`, batch 7 — formerly General's third tab), one tab, **General**. The band above
the strip holds the Container picker and **New container** (a player-buff bar container, then
selected) on one row. With no container, the band and one sentence are all the page draws.
```

  and at line 472 `` (`SelectContainer`, `ContainerPickerCell`, `` → `` (`SelectContainer`, `ContainerHeader`, ``.
- `docs/module-map.md:99`: the row's description becomes `The top-level Containers page (`N-1`, batch 7): the picker and New container in the band above the strip (`Helpers.ContainerHeader`), and one tab, General: the name, enable, unit, aura type and style rows, Duplicate / Delete / Copy settings from`;
  line 158: `the picker and New in the tab body` → `the picker and New in the band above the strip`.
- `docs/smoke-tests.md`, item 23's first two lines become
  `23. **Containers** (its own top-level page, one tab, **General**) → the band above the tab strip holds the`
  `    Container picker and **New container**, side by side and aligned. In the tab: Name and Enabled,`.

- [ ] **Step 4: Run them and see them pass**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua 2>&1 | grep -A3 -E "feedback #2|C-3|with no containers|one tab, General|addon-wide tabbed|tab strip reads Master|locale:|FAIL"`
Expected: all PASS, the two locale cases included (the one key was replaced on both sides).

- [ ] **Step 5: Checkpoint — the green gate and complexity**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua && /home/tushar/.claude/wow-addon/bin/ka0s-bounded luacheck . && /home/tushar/.claude/wow-addon/bin/ka0s-bounded lizard -l lua -x "./libs/*" -x "./tests/_kit/*" -C 15 -w .`
Expected: 0 failed; `0 warnings / 0 errors`; lizard prints nothing.

- [ ] **Step 6: Update the Status ledger row for this task (status, commit SHAs, repo) and the resume guide's "Current position" line; commit the plan file with the task's commit**

Row 3 → `done` with the SHA and "options-ui-§14 row retired; tab renamed General (D-2, owner to confirm)".
Current position → "Next: Task 4 — not started; Tasks 1–3 done." Commit:
`T3: the Containers page's picker and New move above the strip; its tab is General (feedback #2)`,
with this plan file.

---

### Task 4: #8 — a TEST marker on the handle while test mode is on

**Files:**
- Modify: `core/Constants.lua` (insert after `C.NOTICE_COLOR = "ffc8a85a"`, line 150)
- Modify: `modules/Anchors.lua` — a new `handleText` above `Anchors.UpdateHandle`'s doc comment
  (`--- Show or hide a container's handle, with its current name, …`), and `UpdateHandle`'s first text line
- Modify: `locales/enUS.lua` (append the batch's key section)
- Modify: `docs/schema.md` (one `core/Constants.lua:163` citation moves down 5; the helper does it)
- Test: `tests/test_anchors.lua` (append one case)

**Interfaces:**
- Consumes: `NS.State.testMode` (written only by `Preview.SetTestMode`, which sends
  `VISIBILITY_CHANGED`; every visibility pass calls `Anchors.UpdateHandle`, Task 1's text-taking
  `placeHandle` measures the tagged text).
- Produces: `NS.Constants.TEST_TAG_COLOR = "ffff8000"`; the label reads `<name>  |cffff8000TEST|r`
  while test mode is on.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_anchors.lua`:

```lua

-- ── the TEST marker (feedback #8) ─────────────────────────────────────────────────────────────

test("handle: while test mode is on the label carries an orange TEST tag after the name; off, the name alone (feedback #8)", function()
    local NS, mocks = fresh()
    local inst = NS.ContainerManager.instances[1]
    local h = recordedHandle(mocks, NS, inst)
    local texts = {}
    rawset(h, "SetText", function(_, s)
        local n = #texts
        texts[n + 1] = s
    end)
    local name = NS.Database.FindContainer(1).name
    NS.Anchors.UpdateHandle(inst, true)
    assertEqual(texts[#texts], name, "no tag outside test mode")
    NS.Preview.SetTestMode(true)
    mocks.__fireTimers()
    -- red under: UpdateHandle writing the bare name whatever the mode (no marker on the placeholders)
    assertEqual(texts[#texts], name .. "  |c" .. NS.Constants.TEST_TAG_COLOR .. NS.L["TEST"] .. "|r")
    assertEqual(NS.Constants.TEST_TAG_COLOR, "ffff8000", "orange")
    NS.Preview.SetTestMode(false)
    mocks.__fireTimers()
    -- red under: a tag left behind once test mode ends
    assertEqual(texts[#texts], name, "the tag goes when test mode does")
end)
```

- [ ] **Step 2: Run it and see it fail**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua 2>&1 | grep -A3 "feedback #8"`
Expected: FAIL — `attempt to concatenate field 'TEST_TAG_COLOR' (a nil value)` (the constant is not
there yet); once it is, `expected Player buffs  |cffff8000TEST|r, got Player buffs`.

- [ ] **Step 3: Implement**

`core/Constants.lua`, after `C.NOTICE_COLOR = "ffc8a85a"`:

```lua

-- The TEST tag on a container's drag handle while test mode is on (feedback #8, modules/Anchors.lua's
-- handleText): orange, so the placeholders cannot be mistaken for live auras. The AARRGGBB body of a
-- "|c" escape.
C.TEST_TAG_COLOR = "ffff8000"
```

`modules/Anchors.lua`, directly above `--- Show or hide a container's handle, with its current name, re-placed each time it is shown: the`:

```lua
--- The handle's label: the container's name, and while test mode is on an orange TEST tag after it
--- (feedback #8), so the placeholders on screen read as placeholders.
local function handleText(cfg)
    if not cfg then return "" end
    local name = cfg.name or ""
    if not (NS.State and NS.State.testMode) then return name end
    return ("%s  |c%s%s|r"):format(name, NS.Constants.TEST_TAG_COLOR, NS.L["TEST"])
end

```

and in `Anchors.UpdateHandle`, `    local text = cfg and cfg.name or ""` (Task 1's line) becomes
`    local text = handleText(cfg)`.

`locales/enUS.lua`, append at the end of the file:

```lua

-- The smoke-test feedback batch (2026-09-19).
L["TEST"] = "TEST"
```

(Every later task of this plan appends its keys under this comment.)

- [ ] **Step 4: Run it and see it pass**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua 2>&1 | grep -A3 -E "feedback #8|FAIL"`
Expected: PASS. The docs case reports `docs/schema.md cites core/Constants.lua:163` drifted; pipe the
run into `/tmp/citefix.py` (163 → 168) and run again.

- [ ] **Step 5: Checkpoint — the green gate**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua && /home/tushar/.claude/wow-addon/bin/ka0s-bounded luacheck .`
Expected: 0 failed; `0 warnings / 0 errors`.

- [ ] **Step 6: Update the Status ledger row for this task (status, commit SHAs, repo) and the resume guide's "Current position" line; commit the plan file with the task's commit**

Row 4 → `done` with the SHA. Current position → "Next: Task 5 — not started; Tasks 1–4 done." Commit:
`T4: a TEST marker on the handle while test mode is on (feedback #8)`, with this plan file.

---

### Task 5: #10 — Show all / Hide all on Filters → Categories

**Files:**
- Modify: `settings/Filters.lua` — the header sketch (lines 8–9), two new locals above
  `--- The Categories tab: a grid each …` (line 387), and `renderCategories`' grid branches (lines 405–429)
- Modify: `locales/enUS.lua` (four keys, appended under the batch comment)
- Modify: `docs/settings-panel.md` (the paragraph ending "A grid with no row for the aura type is not drawn.", line 238)
- Test: `tests/test_pages_filters.lua` (append three cases and two helpers)

**Interfaces:**
- Consumes: `NS.Bulk.Run(act, scope, fn)` (settings/Schema.lua), `NS.SetByPath`, the grid rows
  `renderCategories` already partitions (`mine`, per `g.key`).
- Produces: two buttons at the top of the Blizzard Categories and Spell Categories sections. One
  click = one `[Set] show all|hide all <blizzard|custom> categories of container <id>: N rows` line
  and one apply pass.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_pages_filters.lua`:

```lua

-- ── Show all / Hide all (feedback #10) ────────────────────────────────────────────────────────

--- The category keys `auraType` draws in grid `grid` ("blizzard" | "custom"), in declaration order.
local function gridKeys(NS, auraType, grid)
    local out = {}
    for _, def in ipairs(NS.Categories.For(auraType)) do
        local row = NS.FindSchemaRow("container.filter.categories." .. def.key)
        if row.grid == grid then
            local n = #out
            out[n + 1] = def.key
        end
    end
    return out
end

--- Record every [Set] and [Apply] line, rendered `[Tag] text`, with debug on.
local function captureLog(NS)
    NS.State.debug = true
    local lines = {}
    NS.Debug = function(tag, fmt, ...)
        if tag ~= "Set" and tag ~= "Apply" then return end
        local args = { ... }
        for i = 1, select("#", ...) do args[i] = tostring(args[i]) end
        local n = #lines
        lines[n + 1] = ("[%s] %s"):format(tag, fmt:format(unpack(args)))
    end
    return lines
end

test("filters: Show all and Hide all head the Blizzard and Spell Categories sections, and no other (feedback #10)", function()
    for _, id in ipairs({ 1, 2 }) do   -- the player's buffs, then the player's debuffs
        local NS, _, _, ws = categories(id)
        local L = NS.L
        local at = {}
        for i, w in ipairs(ws) do
            local key = (w.type == "Heading" and w.text) or (w.type == "Button" and w.text) or nil
            if key then
                at[key] = at[key] or {}
                table.insert(at[key], i)
            end
        end
        local shows, hides = at[L["Show all"]] or {}, at[L["Hide all"]] or {}
        local showCount, hideCount = #shows, #hides
        -- red under: no bulk buttons, or a pair on Dispel Types / Who Cast It as well
        assertEqual(showCount, 2, "container " .. id .. ": one Show all per section")
        assertEqual(hideCount, 2, "container " .. id .. ": one Hide all per section")
        local blizz, spells = at[L["Blizzard Categories"]][1], at[L["Spell Categories"]][1]
        assertTrue(blizz < shows[1] and shows[1] < spells, "the first pair heads Blizzard Categories")
        assertTrue(spells < shows[2], "the second pair heads Spell Categories")
    end
end)

test("filters: Hide all on Blizzard Categories hides exactly that section, as one [Set] line and one apply (feedback #10)", function()
    local NS, m, P, ws = categories()
    local c = NS.Database.FindContainer(1)
    local blizzard, custom = gridKeys(NS, "HELPFUL", "blizzard"), gridKeys(NS, "HELPFUL", "custom")
    local blizzardCount, customCount = #blizzard, #custom
    assertTrue(blizzardCount > 1 and customCount > 1, "both sections have rows")
    m.__fireTimers()
    local lines = captureLog(NS)
    P.all(ws, "Button", NS.L["Hide all"])[1]:__fire("OnClick")
    m.__fireTimers()
    for _, key in ipairs(blizzard) do
        -- red under: a key of the section left out of the write
        assertEqual(c.filter.categories[key], "hide", key)
    end
    for _, key in ipairs(custom) do
        -- red under: the button writing every category of the aura type, not its own section's
        assertEqual(c.filter.categories[key], "show", key .. " is another section's")
    end
    -- red under: one [Set] line per row (no bulk bracket), or one apply pass per row
    assertEqual(table.concat(lines, " | "),
        ("[Set] hide all blizzard categories of container 1: %d rows | [Apply] applied 1 container(s)"):format(blizzardCount))
end)

test("filters: Show all on Spell Categories shows exactly that section, whatever Blizzard Categories say (feedback #10)", function()
    local NS, _, P, ws = categories()
    local c = NS.Database.FindContainer(1)
    local blizzard, custom = gridKeys(NS, "HELPFUL", "blizzard"), gridKeys(NS, "HELPFUL", "custom")
    P.all(ws, "Button", NS.L["Hide all"])[1]:__fire("OnClick")    -- Blizzard Categories: all Hide
    P.all(ws, "Button", NS.L["Hide all"])[2]:__fire("OnClick")    -- Spell Categories: all Hide
    P.all(ws, "Button", NS.L["Show all"])[2]:__fire("OnClick")    -- Spell Categories: all Show
    for _, key in ipairs(custom) do assertEqual(c.filter.categories[key], "show", key) end
    for _, key in ipairs(blizzard) do
        -- red under: Show all reaching past its own section
        assertEqual(c.filter.categories[key], "hide", key .. " stays hidden")
    end
end)
```

- [ ] **Step 2: Run them and see them fail**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua 2>&1 | grep -A3 "feedback #10"`
Expected: FAIL — `container 1: one Show all per section (expected 2, got 0)`; the other two raise
`attempt to index a nil value` on `P.all(…)[1]` (no such button yet).

- [ ] **Step 3: Implement**

`settings/Filters.lua`:

1. The sketch lines

```lua
--     Categories    Blizzard Categories   Show · Hide · Category, plus an info icon (N-5)
--                   Spell Categories      (buffs)        the same grid, plus a `See spells` link
```

become

```lua
--     Categories    Blizzard Categories   [Show all][Hide all], then Show · Hide · Category, plus an
--                                         info icon (N-5)
--                   Spell Categories      (buffs)        [Show all][Hide all], the same grid, plus a
--                                                         `See spells` link
```

2. Directly above `--- The Categories tab: a grid each (the priority blurb is the What to show tab's now, F-4).` insert:

```lua
--- Show all / Hide all (feedback #10): every category row of one grid, for the selected container, as
--- ONE bulk act (settings/Schema.lua's bracket): each row still goes through the write seam — its
--- validation, CONFIG_CHANGED and the in-place grid refresh — but the log is one `[Set] <act> <scope>:
--- N rows` line, and the writes' CONFIG_CHANGEDs coalesce into one apply pass.
local function setGrid(rows, state, gridKey)
    local _, id = NS.ActiveContainer()
    if not id then return end
    NS.Bulk.Run(state == "show" and "show all" or "hide all", ("%s categories of container %s"):format(gridKey, id), function()
        for _, row in ipairs(rows) do NS.SetByPath(row.path, state, id) end
    end)
end

--- The two buttons at the top of a grid's section, acting on exactly that grid's rows.
local function bulkButtons(ctx, rows, gridKey)
    H.InlineButtonPair(ctx,
        { text = L["Show all"], tooltip = L["Set every category in this section to Show, for this container."],
          onClick = function() setGrid(rows, "show", gridKey) end },
        { text = L["Hide all"], tooltip = L["Set every category in this section to Hide, for this container."],
          onClick = function() setGrid(rows, "hide", gridKey) end })
end

```

3. In `renderCategories`, after `                H.Section(ctx, g.heading)` in the `if g.key == "custom" then`
   branch, insert the line `                bulkButtons(ctx, mine, g.key)`. Then replace the `else` branch

```lua
            else
                -- N-5: only the Blizzard Categories grid gets the extra column here — Dispel Types
                -- and Who Cast It stay exactly as wide as before. A grid with no extraColumn at all
                -- draws no 4th cell, blank or otherwise (unlike passing CATEGORY_EXTRA and letting
                -- every cell() call answer nil), which is what keeps those two grids' rows the
                -- width they always were.
                H.ChoiceGrid(ctx, {
                    heading = g.heading, rows = mine, columns = COLUMNS, labelHeader = L["Category"],
                    extraColumn = (g.key == "blizzard") and CATEGORY_EXTRA or nil,
                })
            end
```

   with

```lua
            elseif g.key == "blizzard" then
                -- Its heading drawn here rather than by ChoiceGrid, so Show all / Hide all sit
                -- between the heading and the grid (feedback #10). N-5: only this grid gets the
                -- extra column.
                H.Section(ctx, g.heading)
                bulkButtons(ctx, mine, g.key)
                H.ChoiceGrid(ctx, { rows = mine, columns = COLUMNS, labelHeader = L["Category"], extraColumn = CATEGORY_EXTRA })
            else
                -- Dispel Types and Who Cast It: no bulk buttons, and no extraColumn at all, so they
                -- draw no 4th cell, blank or otherwise (unlike passing CATEGORY_EXTRA and letting
                -- every cell() call answer nil), which keeps their rows the width they always were.
                H.ChoiceGrid(ctx, { heading = g.heading, rows = mine, columns = COLUMNS, labelHeader = L["Category"] })
            end
```

`locales/enUS.lua`, append:

```lua
L["Show all"] = "Show all"
L["Hide all"] = "Hide all"
L["Set every category in this section to Show, for this container."] = "Set every category in this section to Show, for this container."
L["Set every category in this section to Hide, for this container."] = "Set every category in this section to Hide, for this container."
```

`docs/settings-panel.md`, replace `(hover it for its description). A grid` / `with no row for the aura
type is not drawn.` with:

```markdown
(hover it for its description). A grid
with no row for the aura type is not drawn. The **Blizzard Categories** and **Spell Categories**
sections open with **Show all** and **Hide all** (feedback #10): each writes every category of that
section, and only that section, for the selected container, as one bulk act (`NS.Bulk.Run`: one
`[Set] show all|hide all <grid> categories of container <id>: N rows` line, one apply pass).
```

- [ ] **Step 4: Run them and see them pass**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua 2>&1 | grep -A3 -E "feedback #10|two grids, Blizzard|Blizzard Categories, Spell Categories, Dispel|FAIL"`
Expected: the three new cases PASS, and the two heading-order cases ("a buff container's Categories tab
is two grids …", "a debuff container's Categories tab is Blizzard Categories, Spell Categories, Dispel
Types and Who Cast It, each once") still PASS: the Blizzard heading is now an `H.Section` Heading
rather than ChoiceGrid's, in the same place.

- [ ] **Step 5: Checkpoint — the green gate and complexity**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua && /home/tushar/.claude/wow-addon/bin/ka0s-bounded luacheck . && /home/tushar/.claude/wow-addon/bin/ka0s-bounded lizard -l lua -x "./libs/*" -x "./tests/_kit/*" -C 15 -w .`
Expected: 0 failed; `0 warnings / 0 errors`; lizard prints nothing (`renderCategories` gains one branch).

- [ ] **Step 6: Update the Status ledger row for this task (status, commit SHAs, repo) and the resume guide's "Current position" line; commit the plan file with the task's commit**

Row 5 → `done` with the SHA. Current position → "Next: Task 6 — not started; Tasks 1–5 done." Commit:
`T5: Show all / Hide all on Filters -> Categories (feedback #10)`, with this plan file.

---

### Task 6: #5a — token output: bare percents, no stray whitespace, and the `( )` trace

**Files:**
- Modify: `modules/Style.lua` — the percent rule (lines 594–604) and `DurationTextFormat`'s doc line (607)
- Modify: `modules/Style_Text.lua` — `VALUES` and `componentText` (lines 354–369)
- Modify: `core/Constants.lua` — `TEXT_TOKEN_LABELS.remainingpercent` / `.elapsedpercent` (Task 4 moved them to lines 216–217)
- Modify: `settings/Text.lua` — `cheatSheet` and its doc comment (lines 81–90)
- Modify: `locales/enUS.lua` — two percent-label keys replaced (lines 535–536); one key appended
- Modify: `docs/compat-layer.md:39`, `README.md` (lines 77–80), `docs/midnight-quirks.md` (append the `( )` trace)
- Test: `tests/test_style.lua` (line 956 case edited; two appended), `tests/test_style_text.lua` (line 472 edited; one case added after it), `tests/test_pages_text.lua` (line 85 case gains an assertion)

**Interfaces:**
- Consumes: `NS.Compat.CreateRuleFormatter(breakpoints)` (returns nil when the client refuses a list).
- Produces: every percent component formats through `{ { threshold = 0, step = 1, format = "%d" } }`
  (or, refused, `{ { threshold = 0, format = "%d" } }`); the preview writes the nearest whole number
  with no `%`. Task 7's Preview line uses the same fill (`VALUES`), so it inherits this.

- [ ] **Step 1: Write the failing tests**

`tests/test_style.lua`, in the case "style: a duration run's text format has its format string and one
component per token, built once", replace `    assertEqual(bp[1].format, "%d%%")` with:

```lua
    -- red under: the old "%d%%" (a token adding a "%" the player did not type, feedback #5)
    assertEqual(bp[1].format, "%d")
    -- red under: a fractional 0-100 value handed to "%d" unrounded
    assertEqual(bp[1].step, 1)
```

and append to the end of `tests/test_style.lua`:

```lua

test("style: a client that refuses the percent rule's step gets the plain \"%d\" rule, never none (feedback #5)", function()
    local NS2 = fresh({ before = function(m)
        dofile("tests/text_apis.lua")(m)
        local create = m.C_StringUtil.CreateNumericRuleFormatter
        m.C_StringUtil.CreateNumericRuleFormatter = function()
            local f = create()
            f.SetBreakpoints = function(self, bps)
                if bps[1].step ~= nil then error("unknown breakpoint field 'step'") end
                self.given = bps
                return self
            end
            return f
        end
    end })
    local piece = NS2.TextTemplate.Compile("$remainingpercent$").pieces[1]
    local pf = NS2.Style.DurationTextFormat(piece, "short").components[1].formatter
    -- red under: percentFor giving up after the refused rule (the component would have no formatter)
    assertTrue(pf ~= nil, "a formatter was built")
    assertEqual(pf.given[1].format, "%d")
    assertEqual(pf.given[1].step, nil)
end)

test("style: no format Aura Master itself authors carries a leading or trailing space (feedback #5)", function()
    local NS2 = fresh({ before = dofile("tests/text_apis.lua") })
    local TT = NS2.TextTemplate
    local function trimmed(s) return s == s:match("^%s*(.-)%s*$") end
    -- An unbracketed token's own format: the stacks rule and the duration run.
    assertEqual(TT.Compile("$spellname$ $stacks$").pieces[3].format, "%d")
    local run = TT.Compile("$remainingpercent$").pieces[1]
    assertEqual(run.format, "{}")
    local bp = NS2.Style.DurationTextFormat(run, "short").components[1].formatter:__last("SetBreakpoints")[1]
    for _, b in ipairs(bp) do
        -- red under: a percent rule writing " %" or a trailing space around its number
        assertTrue(trimmed(b.format), ("%q is trimmed"):format(b.format))
    end
    -- Bracket text is the player's and is kept verbatim.
    assertEqual(TT.Compile("$spellname$[ - $remainingduration$]").pieces[2].format, " - {}")
end)
```

`tests/test_style_text.lua`, replace

```lua
    -- tests/text_apis.lua's formatter writes whole seconds as "<n>s"
    assertEqual(out[4], " - 28s / 40s (70%)")
end)
```

with

```lua
    -- tests/text_apis.lua's formatter writes whole seconds as "<n>s"; a percent is a bare number
    -- (feedback #5: the player types the %)
    assertEqual(out[4], " - 28s / 40s (70)")
end)

test("text style: a placeholder's percent is the nearest whole number, as the engine's step rule rounds it (feedback #5)", function()
    local out = filled({ template = "$remainingpercent$" }, { name = "Ignore Pain", icon = 1, remaining = 11, duration = 12, stacks = 0 })
    -- red under: math.floor truncating 91.67 to 91 (the live rule rounds to the nearest)
    assertEqual(out[1], "92")
end)
```

`tests/test_pages_text.lua`, after the line
`    assertTrue(P.hasText(ws, L["Escapes and brackets combine: [[[$stacks$]]] shows [3] only when stacked."]))`
insert:

```lua
    -- red under: the cheat sheet without the bracketed-duration example (feedback #5)
    assertTrue(P.hasText(ws, "[ ($remainingpercent$%)] hides with the time"))
```

- [ ] **Step 2: Run them and see them fail**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua 2>&1 | grep -A3 -E "feedback #5|built once|fills each piece as the engine|General holds Size"`
Expected: FAIL — "built once" `expected %d, got %d%%`; the refusal case `expected %d, got %d%%`
(the old list carries no `step`, so it is never refused); `expected  - 28s / 40s (70), got  - 28s /
40s (70%)`; `expected 92, got 91%`; and "General holds Size, …" on the cheat-sheet assertion. The trim
case PASSES already: it is a guard on today's shape (`%d%%` has no outer space either), kept so a
future rule cannot add one.

- [ ] **Step 3: Implement**

`modules/Style.lua`, replace

```lua
local textFormats = setmetatable({}, WEAK_KEYS)
local PERCENT_BREAKPOINTS = { { threshold = 0, format = "%d%%" } }
local percentFormatter   -- nil until first asked for; false when the client cannot build one

--- The rule formatter every percent component shares: "%d%%", RemainingPercent being 0-100.
local function percentFor()
    if percentFormatter == nil then
        percentFormatter = NS.Compat.CreateRuleFormatter(PERCENT_BREAKPOINTS) or false
    end
    return percentFormatter or nil
end
```

with

```lua
local textFormats = setmetatable({}, WEAK_KEYS)
-- A percent is written as a BARE whole number (feedback #5, 2026-09-19): the rule is "%d" and the
-- player types the % in the template, so no token adds text of its own. RemainingPercent arrives on a
-- fractional 0-100 scale; `step = 1` rounds it to a whole number before "%d" sees it (the 12.1
-- NumericRuleFormatBreakpoint's own field). A client that refuses `step` gets the plain rule.
local PERCENT_BREAKPOINTS = { { threshold = 0, step = 1, format = "%d" } }
local PERCENT_PLAIN = { { threshold = 0, format = "%d" } }
local percentFormatter   -- nil until first asked for; false when the client cannot build one

--- The rule formatter every percent component shares: a whole number, 0-100, with no "%".
local function percentFor()
    if percentFormatter == nil then
        local Compat = NS.Compat
        percentFormatter = Compat.CreateRuleFormatter(PERCENT_BREAKPOINTS)
            or Compat.CreateRuleFormatter(PERCENT_PLAIN) or false
    end
    return percentFormatter or nil
end
```

and in `Style.DurationTextFormat`'s doc comment `a percent through "%d%%". Built once` →
`a percent through "%d". Built once`.

`modules/Style_Text.lua`, replace the block from `--- One duration component of a placeholder, as the
engine would write it: a time through the look's` down to
`    if c.fmt == "percent" then return ("%d%%"):format(value) end` with:

```lua
--- One duration component of a placeholder, as the engine would write it: a time through the look's
--- formatter (Style.PreviewSeconds), a percent as a bare whole number, rounded to the nearest as the
--- engine's `step = 1` rule rounds it (modules/Style.lua's PERCENT_BREAKPOINTS).
local VALUES = {
    RemainingDuration = function(a) return a.remaining end,
    TotalDuration = function(a) return a.duration end,
    ElapsedDuration = function(a) return a.duration - a.remaining end,
    RemainingPercent = function(a) return math.floor(a.remaining / a.duration * 100 + 0.5) end,
    ElapsedPercent = function(a) return math.floor((a.duration - a.remaining) / a.duration * 100 + 0.5) end,
}
local function componentText()
    fillIndex = fillIndex + 1
    local c = fillPiece.components[fillIndex]
    local value = VALUES[c.prop](fillAura)
    if c.fmt == "percent" then return ("%d"):format(value) end
```

`core/Constants.lua`, in `C.TEXT_TOKEN_LABELS`:

```lua
    remainingpercent  = "How much of it is left, 0 to 100 (type the % yourself)",
    elapsedpercent    = "How much of it has run, 0 to 100 (type the % yourself)",
```

`locales/enUS.lua`: replace the two lines
`L["How much of it is left, in percent"] = …` and `L["How much of it has run, in percent"] = …` with

```lua
L["How much of it is left, 0 to 100 (type the % yourself)"] = "How much of it is left, 0 to 100 (type the % yourself)"
L["How much of it has run, 0 to 100 (type the % yourself)"] = "How much of it has run, 0 to 100 (type the % yourself)"
```

and append:

```lua
L["Text outside [ ] always shows, even on an aura with no duration: ($remainingpercent$%) leaves ( ) behind, [ ($remainingpercent$%)] hides with the time."] = "Text outside [ ] always shows, even on an aura with no duration: ($remainingpercent$%) leaves ( ) behind, [ ($remainingpercent$%)] hides with the time."
```

`settings/Text.lua`, `cheatSheet`: its doc comment becomes

```lua
--- The token cheat sheet, under the Template box: one line per token, then the bracket rule, the
--- escapes, how an odd run of [ combines the two, and why a duration belongs in brackets (feedback
--- #5: text outside them shows on a timeless aura too). Read-only text, drawn small.
```

and after its `Escapes and brackets combine` line add:

```lua
    H.TextRow(ctx, L["Text outside [ ] always shows, even on an aura with no duration: ($remainingpercent$%) leaves ( ) behind, [ ($remainingpercent$%)] hides with the time."], SMALL)
```

Docs:
- `docs/compat-layer.md:39`: `its percent components (\`%d%%\`)` → `its percent components (\`%d\`, rounded by \`step = 1\`; a client refusing \`step\` gets plain \`%d\`)`.
- `README.md` lines 78–80: replace
  `` `$elapsedpercent$`; text inside `[ ]` hides along with the token it holds (so ` x3` shows only at two ``
  `` or more stacks, and ` - 12s` only on an aura with a duration). `` with
  `` `$elapsedpercent$` (a percent is a bare number: type the `%` yourself); text inside `[ ]` hides along ``
  `` with the token it holds (so ` x3` shows only at two or more stacks, and ` - 12s` only on an aura with a ``
  `` duration). ``
- `docs/midnight-quirks.md`, append:

```markdown

## An empty duration run still takes a space (open, feedback #5)

**What was seen.** The owner's template `($remainingpercent$)` drew `( )`: the literal `(`, then the
duration run, then the literal `)`, with a space where the number should be. The run is one
single-anchored, auto-sized font string the engine writes into, so whatever it wrote was EMPTY, and
the gap is that empty string's own width.

**What could empty it**, and what this addon changed:
- **H1: the rule formatter.** The percent rule was `"%d%%"`, and `RemainingPercent` arrives as a
  fractional 0–100 value. If the client's `%d` writes nothing for a non-integer, the run is empty. Fixed
  here either way: the rule is now `"%d"` with `step = 1` (`modules/Style.lua`'s `PERCENT_BREAKPOINTS`),
  so `%d` only ever sees a whole number, and the player types the `%`.
- **H2: a timeless aura.** The engine disables the duration binding for a zero duration
  (`ApplyDurationText`: `binding:SetEnabled(not auraDuration:IsZero())`), and the binding's zero text is
  `""` (`Compat.CreateDurationBinding`). Nothing to fix: this is text outside `[ ]` showing on a
  timeless aura, by design. The Text page's cheat sheet now says to write `[ ($remainingpercent$%)]`.
- **The gap itself** would then be the client laying an empty, single-anchored font string out with a
  non-zero width, which no addon code can read (the string is engine-written and secret) or trim.

**The in-game check** (docs/smoke-tests.md section T) runs three `/run` probes that tell these apart:
the rule formatter on `45.5` and `45`, the binding's zero-duration text, and an empty font string's
width.
```

- [ ] **Step 4: Run them and see them pass**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua 2>&1 | grep -A3 -E "feedback #5|built once|fills each piece as the engine|General holds Size|locale:|FAIL"`
Expected: all PASS (the two replaced label keys keep the locale suite green: `C.TEXT_TOKEN_LABELS` is
routed by value).

- [ ] **Step 5: Checkpoint — the green gate**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua && /home/tushar/.claude/wow-addon/bin/ka0s-bounded luacheck .`
Expected: 0 failed; `0 warnings / 0 errors` (the local is `Compat`, not `C`, which would shadow the
file's `C = NS.Constants`).

- [ ] **Step 6: Update the Status ledger row for this task (status, commit SHAs, repo) and the resume guide's "Current position" line; commit the plan file with the task's commit**

Row 6 → `done` with the SHA, Notes "`( )`: H1 fixed; the in-game probes are smoke section T". Current
position → "Next: Task 7 — not started; Tasks 1–6 done." Commit:
`T6: percents are bare numbers; no token adds whitespace; the ( ) trace (feedback #5)`, with this plan file.

---

### Task 7: #5b — built-in templates, Custom, and a Preview line on Text → General

**Files:**
- Modify: `core/Constants.lua` (insert after `C.TEXT_TEMPLATE_MAX = 200`; Task 4 moved it to line 227)
- Modify: `modules/TextTemplate.lua` (append section 4)
- Modify: `modules/Style_Text.lua` — the preview section, from `--- A placeholder's duration run: the format …` (line 371) to the end of `Text.FillPreview` (line 411)
- Modify: `settings/Text.lua` — header (lines 6–12), locals (after line 36), the `template` and `justifyH` rows (lines 65–71), `renderGeneral` (lines 103–116)
- Modify: `locales/enUS.lua` (ten keys appended)
- Modify: `docs/settings-panel.md` (the Text section, lines 420–423 and the General row of its table, line 442)
- Test: `tests/test_pages_text.lua` (two helpers before the first case; the cases at lines 70 and 96 open Custom first; four appended), `tests/test_texttemplate.lua` (two appended)

**Interfaces:**
- Consumes: `TT.Compile`, `Style.Text.Compiled`, Task 6's `VALUES`/`componentText` (percent without `%`).
- Produces:
  - `C.TEXT_BUILTINS[key] = { template, justifyH? }`, `C.TEXT_BUILTIN_LABELS[key]`,
    `C.TEXT_BUILTIN_SETS[auraType] = { key, … }`, `C.TEXT_SAMPLE_AURAS[auraType]` (D-5's table).
  - `TT.Builtins(auraType) -> { key, … }` (the buff set for an unknown type);
    `TT.MatchBuiltin(auraType, template, justifyH) -> key | nil`.
  - `Style.Text.PreviewLine(s, aura) -> string` (Task 8 extends it to stacked rows).
  - The `template` row's label becomes **Custom template** and it gains `onChange` (a structural
    redraw); `justifyH` gains the same `onChange` (Task 8's note and Preview read it).

- [ ] **Step 1: Write the failing tests**

`tests/test_pages_text.lua`: directly above `test("text page: the four tabs are drawn in order", function()` insert:

```lua
--- The Template dropdown (feedback #5): the built-ins and Custom. Not a schema row, found by label.
local function picker(NS, P, ws) return P.find(ws, "Dropdown", NS.L["Template"]) end

--- Choose `key` in the Template dropdown and answer the page as it draws after the choice.
local function pick(NS, m, P, ws, key)
    picker(NS, P, ws):__fire("OnValueChanged", key)
    m.__fireTimers()
    return P.rerender("Text")
end

```

In the case at line 70, rename it to
`"text page: General holds Size, the Template dropdown and box, the cheat sheet, then Placement"`,
change its first lines

```lua
    local NS, _, P, ws = textPage()
    local L = NS.L
    local box = P.row(ws, P_ .. "template")
```

to

```lua
    local NS, m, P, ws = textPage()
    local L = NS.L
    ws = pick(NS, m, P, ws, "custom")
    local box = P.row(ws, P_ .. "template")
```

and after its last assertion (`assertTrue(at.box < at.sheet and at.sheet < at.justify, "box, then cheat sheet, then Placement")`) add:

```lua
    local dd = picker(NS, P, ws)
    for i, w in ipairs(ws) do
        if w == dd then at.picker = i end
    end
    -- red under: the dropdown drawn under the box (the spec puts it above the template box)
    assertTrue(at.picker < at.box, "the Template dropdown, then the box")
```

In the case at line 96 ("a valid template is stored; …"), change `    local NS, _, P, ws = textPage()` to

```lua
    local NS, m, P, ws = textPage()
    ws = pick(NS, m, P, ws, "custom")
```

Append to `tests/test_pages_text.lua`:

```lua

-- ── built-in templates, Custom and the Preview (feedback #5) ──────────────────────────────────

test("text page: the Template dropdown lists the aura type's built-ins, then Custom (feedback #5)", function()
    local NS, _, P, ws = textPage()
    local C = NS.Constants
    local function expected(auraType)
        local out = {}
        for i, key in ipairs(C.TEXT_BUILTIN_SETS[auraType]) do out[i] = key end
        local n = #out
        out[n + 1] = "custom"
        return table.concat(out, ",")
    end
    local dd = picker(NS, P, ws)
    -- red under: no Template dropdown, or the buff page offering the debuff built-ins
    assertEqual(table.concat(dd.order, ","), expected("HELPFUL"))
    assertEqual(dd.list.nameTime, NS.L["Name + time"])
    assertEqual(dd.value, "nameStacksTime", "the default template is a built-in")
    NS.SetByPath("container.style", "text", 2)
    NS.Helpers.SelectContainer(2)
    ws = P.rerender("Text")
    -- red under: the debuff page without Name (type) and Name, type, time
    assertEqual(table.concat(picker(NS, P, ws).order, ","), expected("HARMFUL"))
end)

test("text page: picking a built-in writes its template, and the centered one Center; the box stays hidden (feedback #5)", function()
    local NS, m, P, ws = textPage()
    local s = NS.Database.FindContainer(1).text
    -- red under: the box drawn for a template that is a built-in
    assertEqual(P.row(ws, P_ .. "template"), nil, "a built-in shows no box")
    ws = pick(NS, m, P, ws, "timeOfMax")
    assertEqual(s.template, "$spellname$[ $remainingduration$ / $maxduration$]")
    assertEqual(s.justifyH, "LEFT")
    ws = pick(NS, m, P, ws, "centered")
    -- red under: the centered built-in writing its template and leaving Justify alone
    assertEqual(s.template, "$spellname$[ - $remainingduration$]")
    assertEqual(s.justifyH, "CENTER")
    assertEqual(picker(NS, P, ws).value, "centered", "Name + time with Center reads as the centered one")
    ws = pick(NS, m, P, ws, "name")
    -- red under: a plain built-in leaving the line centered (Center is the centered built-in's)
    assertEqual(s.justifyH, "LEFT")
    assertEqual(picker(NS, P, ws).value, "name")
end)

test("text page: Custom reveals the box with the current template; an unmatched template reads as Custom (feedback #5)", function()
    local NS, m, P, ws = textPage()
    ws = pick(NS, m, P, ws, "custom")
    local box = P.row(ws, P_ .. "template")
    -- red under: Custom not opening the box, or opening it empty
    assertTrue(box ~= nil, "Custom shows the box")
    assertEqual(box.text, NS.CONTAINER_TEMPLATE.text.template, "seeded with the current template")
    assertEqual(picker(NS, P, ws).value, "custom")
    assertEqual(NS.Database.FindContainer(1).text.template, NS.CONTAINER_TEMPLATE.text.template, "choosing Custom writes nothing")
    -- Another container, whose stored template is no built-in: Custom, with its box, unasked.
    NS.SetByPath("container.style", "text", 3)
    NS.SetByPath(P_ .. "template", "$spellname$ $stacks$", 3)
    NS.Helpers.SelectContainer(3)
    ws = P.rerender("Text")
    -- red under: a template that matches nothing read as the first built-in
    assertEqual(picker(NS, P, ws).value, "custom")
    assertTrue(P.row(ws, P_ .. "template") ~= nil, "and its box is drawn")
end)

test("text page: the Preview line renders the sample aura, brackets filled and empty ones hidden (feedback #5)", function()
    local NS, m, P, ws = textPage()
    local L = NS.L
    -- The buff sample: Ignore Pain, 3 stacks, 11 of 12 s, no dispel type. The harness has no seconds
    -- formatter, so a time reads as whole seconds ("11s").
    -- red under: no Preview line, or one not filled from the sample
    assertTrue(P.hasText(ws, L["Preview: %s"]:format("Ignore Pain x3 - 11s")))
    NS.SetByPath(P_ .. "template", "$spellname$[ ($remainingpercent$%)][ ($dispeltype$)]", 1)
    m.__fireTimers()
    ws = P.rerender("Text")
    -- red under: an empty bracket drawn (the dispel type of a typeless aura), or a percent carrying
    -- its own "%" beside the one typed
    assertTrue(P.hasText(ws, L["Preview: %s"]:format("Ignore Pain (92%)")))
    -- The debuff sample: Shadow Word: Pain, no stacks, a Magic type.
    NS.SetByPath("container.style", "text", 2)
    NS.Helpers.SelectContainer(2)
    ws = P.rerender("Text")
    ws = pick(NS, m, P, ws, "nameTypeTime")
    assertTrue(P.hasText(ws, L["Preview: %s"]:format("Shadow Word: Pain (" .. L["Magic"] .. ") - 11s")))
    ws = pick(NS, m, P, ws, "nameStacksTime")
    assertTrue(P.hasText(ws, L["Preview: %s"]:format("Shadow Word: Pain - 11s")), "no stacks, so no ' x'")
end)
```

Append to `tests/test_texttemplate.lua`:

```lua

-- ── the built-in templates (feedback #5) ──────────────────────────────────────────────────────

test("template: every built-in compiles, and each aura type's list is the pinned one", function()
    local C = NS.Constants
    for key, def in pairs(C.TEXT_BUILTINS) do
        -- red under: a built-in the parser refuses (the dropdown would write a template it rejects)
        assertTrue(TT.Compile(def.template).ok, key)
    end
    assertEqual(table.concat(TT.Builtins("HELPFUL"), ","), "name,nameTime,nameStacksTime,timeOfMax,centered")
    assertEqual(table.concat(TT.Builtins("HARMFUL"), ","), "name,nameTime,nameStacksTime,timeOfMax,nameType,nameTypeTime,centered")
    assertEqual(table.concat(TT.Builtins("NOPE"), ","), table.concat(TT.Builtins("HELPFUL"), ","), "an unknown type offers the buff set")
    assertEqual(C.TEXT_BUILTINS.nameStacksTime.template, NS.CONTAINER_TEMPLATE.text.template, "the default is a built-in")
end)

test("template: a stored template matches a built-in by its text and its justify rule, else none", function()
    local nameTime = "$spellname$[ - $remainingduration$]"
    assertEqual(TT.MatchBuiltin("HELPFUL", nameTime, "LEFT"), "nameTime")
    assertEqual(TT.MatchBuiltin("HELPFUL", nameTime, "RIGHT"), "nameTime")
    -- red under: the justify rule ignored (Name + time centered would read as Name + time)
    assertEqual(TT.MatchBuiltin("HELPFUL", nameTime, "CENTER"), "centered")
    assertEqual(TT.MatchBuiltin("HELPFUL", "$spellname$[ x$stacks$][ - $remainingduration$]", "CENTER"), nil,
        "a built-in other than the centered one, centered, is Custom")
    assertEqual(TT.MatchBuiltin("HELPFUL", "$spellname$[ ($dispeltype$)]", "LEFT"), nil, "a debuff built-in on a buff container")
    assertEqual(TT.MatchBuiltin("HARMFUL", "$spellname$[ ($dispeltype$)]", "LEFT"), "nameType")
    assertEqual(TT.MatchBuiltin("HELPFUL", "$spellname$ $stacks$", "LEFT"), nil)
end)
```

- [ ] **Step 2: Run them and see them fail**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua 2>&1 | grep -A3 -E "feedback #5|General holds Size|a valid template is stored|template: every built-in|matches a built-in"`
Expected: FAIL — every page case raises `attempt to index a nil value` inside `pick`/`picker` (no
Template dropdown yet); the two template cases raise `attempt to call field 'Builtins' (a nil value)`
/ `'MatchBuiltin'`.

- [ ] **Step 3: Implement**

`core/Constants.lua`, after `C.TEXT_TEMPLATE_MAX = 200`:

```lua

-- The built-in templates the Text page's Template dropdown offers (feedback #5): each a template
-- string and, for the centered one, the justify it needs. TEXT_BUILTIN_SETS lists them per aura type
-- in dropdown order; a stored template matching none reads as Custom (modules/TextTemplate.lua's
-- MatchBuiltin). Every duration run is bracketed, so no built-in leaves text behind on a timeless aura.
C.TEXT_BUILTINS = {
    name           = { template = "$spellname$" },
    nameTime       = { template = "$spellname$[ - $remainingduration$]" },
    nameStacksTime = { template = "$spellname$[ x$stacks$][ - $remainingduration$]" },
    timeOfMax      = { template = "$spellname$[ $remainingduration$ / $maxduration$]" },
    nameType       = { template = "$spellname$[ ($dispeltype$)]" },
    nameTypeTime   = { template = "$spellname$[ ($dispeltype$)][ - $remainingduration$]" },
    centered       = { template = "$spellname$[ - $remainingduration$]", justifyH = "CENTER" },
}
C.TEXT_BUILTIN_LABELS = {
    name = "Name", nameTime = "Name + time", nameStacksTime = "Name, stacks, time", timeOfMax = "Time / max",
    nameType = "Name (type)", nameTypeTime = "Name, type, time", centered = "Centered: name over time",
}
C.TEXT_BUILTIN_SETS = {
    HELPFUL = { "name", "nameTime", "nameStacksTime", "timeOfMax", "centered" },
    HARMFUL = { "name", "nameTime", "nameStacksTime", "timeOfMax", "nameType", "nameTypeTime", "centered" },
}

-- The sample aura the Text page's Preview line renders a template against, per aura type: readable,
-- invented values (preview-mode). The buff has stacks and no dispel type; the debuff a type and none.
C.TEXT_SAMPLE_AURAS = {
    HELPFUL = { name = "Ignore Pain", icon = 1377132, remaining = 11, duration = 12, stacks = 3 },
    HARMFUL = { name = "Shadow Word: Pain", icon = 136207, remaining = 11, duration = 16, stacks = 0, dispel = "Magic" },
}
```

`modules/TextTemplate.lua`, append:

```lua

-- ---------------------------------------------------------------------------
-- 4. The built-in templates (feedback #5)
-- ---------------------------------------------------------------------------

--- The built-in template keys `auraType` offers, in dropdown order (core/Constants.lua's
--- TEXT_BUILTIN_SETS); an aura type with no set of its own offers the buff set.
--- @return table  keys of C.TEXT_BUILTINS
function TT.Builtins(auraType)
    return C.TEXT_BUILTIN_SETS[auraType] or C.TEXT_BUILTIN_SETS.HELPFUL
end

--- The built-in a stored template and justify are, or nil (the Text page reads nil as Custom). A
--- built-in matches when its template is identical and its justify rule holds: the centered one wants
--- Center, every other one anything but Center. First match in `auraType`'s order.
--- @return string|nil  a key of C.TEXT_BUILTINS
function TT.MatchBuiltin(auraType, template, justifyH)
    local centered = justifyH == "CENTER"
    for _, key in ipairs(TT.Builtins(auraType)) do
        local def = C.TEXT_BUILTINS[key]
        if def.template == template and (def.justifyH == "CENTER") == centered then return key end
    end
    return nil
end
```

`modules/Style_Text.lua`, replace from `--- A placeholder's duration run: the format with each {} filled,
nothing for a timeless aura (the` through the end of `Text.FillPreview` with:

```lua
--- A placeholder's duration run as text: the format with each {} filled, nothing for a timeless aura
--- (the prebuilt binding's zero-duration text).
local function durationText(piece, aura, s)
    if aura.duration <= 0 then return "" end
    fillAura, fillSettings, fillPiece, fillIndex = aura, s, piece, 0
    local text = piece.format:gsub("{}", componentText)
    fillAura, fillSettings, fillPiece = nil, nil, nil
    return text
end

-- What each kind of piece reads for a placeholder aura, as the engine would write it. Shared by the
-- placeholders (Text.FillPreview) and the Text page's Preview line (Text.PreviewLine).
local PIECE_TEXT = {
    literal = function(piece) return piece.text end,
    name = function(_, aura) return aura.name end,
    stacks = function(piece, aura) return aura.stacks >= 2 and piece.format:format(aura.stacks) or "" end,
    dispel = function(piece, aura)
        local label = aura.dispel and C.TEXT_DISPEL_LABELS[aura.dispel]
        return label and (piece.pre .. L[label] .. piece.post) or ""
    end,
    duration = durationText,
}

--- A placeholder's duration run below the running-out threshold takes the running-out color, as the
--- engine's curve paints a live one (a timeless one has no threshold to cross).
local function previewRunColor(fs, aura, s)
    if aura.duration <= 0 or not (s.expiringColorOn or s.expiringBlink) then return end
    if aura.remaining < number(s.expiringThreshold, D.expiringThreshold) then
        fs:SetTextColor(Style.Color(s.expiringColorOn and s.expiringColor or (s.font or D.font).fontColor, false))
    end
end

--- Fill a PREVIEW element with placeholder values (modules/Preview.lua), from the same compiled
--- pieces the live dress binds, so the preview and a live button cannot differ in structure. A
--- literal already holds its text (dressPieces).
function Text.FillPreview(frame, aura, cfg)
    local am = frame.__am
    if not (am and am.style == "text") then return end
    local s = (cfg and cfg.text) or {}
    local compiled = Text.Compiled(s)
    am.icon:SetTexture(aura.icon)
    for i, piece in ipairs(compiled.pieces) do
        if piece.kind ~= "literal" then
            local fs = am[PIECE[i]]
            fs:SetText(PIECE_TEXT[piece.kind](piece, aura, s))
            if piece.kind == "duration" then previewRunColor(fs, aura, s) end
        end
    end
end

--- The line text block `s` draws for a sample `aura`, as one plain string: the Text page's Preview
--- (feedback #5). The same compile and the same fill as the placeholders, so the two cannot disagree.
function Text.PreviewLine(s, aura)
    local compiled = Text.Compiled(s or {})
    local parts = {}
    for i, piece in ipairs(compiled.pieces) do parts[i] = PIECE_TEXT[piece.kind](piece, aura, s or {}) end
    return table.concat(parts)
end
```

`settings/Text.lua`:

1. The header's sketch and first paragraph (lines 6–12) become:

```lua
--     band   [Container ▾]
--     [ General ][ Font ][ Icon ][ Animation ]
--     General   Size, then -- What each line says --: [Template ▾] (a built-in, or Custom), the
--               Custom template box (Custom only), Preview: <the line on a sample aura>, the cheat
--               sheet; then Placement and the centering note
--
-- General is drawn bespoke (its `tabs` entry below) to put the built-in picker, the preview and two
-- read-only blocks between its rows: the token cheat sheet, and the centering note under Placement.
-- Its rows are still ordinary schema rows, drawn by the flow engine, so the panel, `/am set`, the
-- Defaults button and the resets all reach them through the one write seam. The Template dropdown is
-- not a row: it writes the template (and, for the centered built-in, Justify) through that seam
-- (feedback #5).
```

2. After `local GRAY = "|cff808080%s|r"` insert:

```lua
local CUSTOM = "custom"

-- Which containers have Custom chosen in the Template dropdown this session, by id. Page state, not a
-- setting: a stored template matching no built-in reads as Custom on its own; this keeps the box open
-- for one that matches a built-in once the player asked to edit it.
local customOpen = {}

-- A write that changes what the General tab draws (the box, the preview, the centering note) redraws
-- it, on the next frame, out of the widget's own callback.
local function structural() if NS.RequestPanelRefresh then NS.RequestPanelRefresh() end end
```

3. The `template` row: `label = L["Template"],` → `label = L["Custom template"],` and
   `validate = TT.Validate },` → `validate = TT.Validate, onChange = structural },`. The `justifyH`
   row gains `onChange = structural` after its `desc` (a comma after the `desc` value, then
   `      onChange = structural },`).

4. Replace `renderGeneral` and its doc comment (`--- The General tab: its rows, with the cheat sheet
   after the Template box and the centering note` … the function's `end`) with:

```lua
-- ── The built-in templates (feedback #5) ──────────────────────────────────────────────────────

--- Whether container `id`'s Template dropdown reads Custom: its template matches no built-in, or the
--- player chose Custom this session.
local function isCustom(cfg, id)
    local s = cfg.text or {}
    return customOpen[id] or TT.MatchBuiltin(cfg.auraType, s.template, s.justifyH or D.justifyH) == nil
end

--- Choose built-in `key` for container `id`: its template, then the justify it needs (Center for the
--- centered one; Left for any other when the stored justify is Center), each through the write seam.
local function pickBuiltin(cfg, id, key)
    local def = C.TEXT_BUILTINS[key]
    customOpen[id] = nil
    NS.SetByPath(P .. "template", def.template, id)
    local justify = (cfg.text and cfg.text.justifyH) or D.justifyH
    if def.justifyH and justify ~= def.justifyH then
        NS.SetByPath(P .. "justifyH", def.justifyH, id)
    elseif not def.justifyH and justify == "CENTER" then
        NS.SetByPath(P .. "justifyH", "LEFT", id)
    end
end

--- The Template dropdown: the container's built-ins, then Custom. A bespoke cell (not a schema row:
--- it has no stored value of its own), drawn disabled with the page.
local function templatePicker(cfg, id)
    return { make = function(ctx, parent, rel)
        local list, order = {}, {}
        for i, key in ipairs(TT.Builtins(cfg.auraType)) do
            list[key] = L[C.TEXT_BUILTIN_LABELS[key]]
            order[i] = key
        end
        local n = #order
        order[n + 1] = CUSTOM
        list[CUSTOM] = L["Custom"]
        local s = cfg.text or {}
        local dd = NS.AceGUI:Create("Dropdown")
        dd:SetLabel(L["Template"])
        dd:SetList(list, order)
        dd:SetValue(isCustom(cfg, id) and CUSTOM or TT.MatchBuiltin(cfg.auraType, s.template, s.justifyH or D.justifyH))
        dd:SetRelativeWidth(rel or 0.5)
        if ctx.__renderDisabled then dd:SetDisabled(true) end
        dd:SetCallback("OnValueChanged", function(_, _, key)
            if key == CUSTOM then customOpen[id] = true else pickBuiltin(cfg, id, key) end
            structural()
        end)
        H.AttachTooltip(dd, L["Template"], L["A ready-made line, or Custom to write your own from the tokens below. The Preview shows the result on a sample aura."])
        parent:AddChild(dd)
        return dd
    end }
end

--- A copy of `row` the flow engine draws nothing for but its subsection heading (RenderRows emits a
--- subgroup's heading before it looks at skipRender).
local function headingOnly(row)
    local copy = {}
    for k, v in pairs(row) do copy[k] = v end
    copy.skipRender = true
    return copy
end

--- What each line says: the subsection heading, the Template dropdown, the Custom template box (Custom
--- only), the Preview line on the aura type's sample aura, then the cheat sheet.
local function renderTemplate(ctx, cfg, row)
    local _, id = NS.ActiveContainer()
    if row then H.RenderRows(ctx, { headingOnly(row) }, nil, nil, { noHeadings = true }) end
    H.RenderGrid(ctx, { templatePicker(cfg, id) })
    if row and isCustom(cfg, id) then H.RenderRows(ctx, { row }, nil, nil, { noHeadings = true }) end
    local sample = C.TEXT_SAMPLE_AURAS[cfg.auraType] or C.TEXT_SAMPLE_AURAS.HELPFUL
    H.TextRow(ctx, L["Preview: %s"]:format(NS.Style.Text.PreviewLine(cfg.text, sample)))
    cheatSheet(ctx)
end

--- The General tab: Size, then what each line says (renderTemplate), then Placement and the
--- centering note.
local function renderGeneral(ctx, cfg, rows)
    local size, tail, templateRow = {}, {}, nil
    for _, row in ipairs(rows or {}) do
        if row.path == P .. "template" then
            templateRow = row
        else
            local list = (row.subgroup == S_PLACEMENT) and tail or size
            local n = #list
            list[n + 1] = row
        end
    end
    H.RenderRows(ctx, size, nil, nil, { noHeadings = true })
    renderTemplate(ctx, cfg, templateRow)
    H.RenderRows(ctx, tail, nil, nil, { noHeadings = true })
    centerNote(ctx, cfg)
end
```

(The second `RenderRows` over the template row draws no second heading: the subgroup tracker already
names it.)

`locales/enUS.lua`, append (`Name` and `Template` already exist):

```lua
L["Custom template"] = "Custom template"
L["Custom"] = "Custom"
L["Preview: %s"] = "Preview: %s"
L["A ready-made line, or Custom to write your own from the tokens below. The Preview shows the result on a sample aura."] = "A ready-made line, or Custom to write your own from the tokens below. The Preview shows the result on a sample aura."
L["Name + time"] = "Name + time"
L["Name, stacks, time"] = "Name, stacks, time"
L["Time / max"] = "Time / max"
L["Name (type)"] = "Name (type)"
L["Name, type, time"] = "Name, type, time"
L["Centered: name over time"] = "Centered: name over time"
```

`docs/settings-panel.md`, the Text section's first paragraph (lines 420–423) becomes:

```markdown
Four tabs. **General** is drawn bespoke, not by the ordinary schema-group renderer, so it can put the
built-in picker, the preview and two read-only blocks between its rows (feedback #5). Under **What
each line says**: a **Template** dropdown of the aura type's built-in templates (Name; Name + time;
Name, stacks, time — the default; Time / max; and on debuffs Name (type) and Name, type, time;
Centered: name over time, which also sets Justify to Center) plus **Custom**, then the **Custom
template** box (drawn only for Custom: a template matching no built-in reads as Custom by itself), then
**Preview:** the line rendered on a sample aura (`C.TEXT_SAMPLE_AURAS`, through the placeholders' own
fill, `Style.Text.PreviewLine`), then the token cheat sheet; the centering note sits under Placement.
Picking a built-in writes `template` (and `justifyH` where the built-in needs it) through the write
seam; picking Custom writes nothing. Its rows are still ordinary schema rows — the panel, `/am set`,
Defaults and the resets all reach them through the one write seam.
```

and the table's General row becomes
`| General | Size: \`width\`, \`height\`. What each line says: the Template dropdown, \`template\` (Custom only; + the Preview and the cheat sheet). Placement: \`justifyH\`, \`justifyV\`, \`x\`, \`y\` (+ the centering note) |`.

- [ ] **Step 4: Run them and see them pass**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua 2>&1 | grep -A3 -E "feedback #5|General holds Size|a valid template is stored|built-in|render coverage|locale:|FAIL"`
Expected: all PASS — render coverage included (the template row's reach is its engine binding, not
its widget), and the locale suite (the seven built-in labels are routed through
`TEXT_BUILTIN_LABELS`, a `*_LABELS` table).

- [ ] **Step 5: Checkpoint — the green gate and complexity**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua && /home/tushar/.claude/wow-addon/bin/ka0s-bounded luacheck . && /home/tushar/.claude/wow-addon/bin/ka0s-bounded lizard -l lua -x "./libs/*" -x "./tests/_kit/*" -C 15 -w .`
Expected: 0 failed; `0 warnings / 0 errors`; lizard prints nothing.

- [ ] **Step 6: Update the Status ledger row for this task (status, commit SHAs, repo) and the resume guide's "Current position" line; commit the plan file with the task's commit**

Row 7 → `done` with the SHA. Current position → "Next: Task 8 — not started; Tasks 1–7 done." Commit:
`T7: built-in Text templates, Custom and a Preview line (feedback #5)`, with this plan file.

---

### Task 8: #1 — Center lays a multi-piece line out as stacked rows

**Files:**
- Modify: `modules/Style_Text.lua` — the header (lines 12–14), `Text.JustifyFor` (lines 178–185, replaced), `layoutChain` (196–197), `Text.Apply`'s `layoutChain` call (341), `Text.PreviewLine` (Task 7's, line 422 on)
- Modify: `modules/Style.lua` — `Style.ElementSize` (line 416)
- Modify: `core/Constants.lua` — the Text justify comment and `TEXT_JUSTIFY_H` (Task 7 left it at line 181)
- Modify: `settings/Text.lua` — the `height` and `justifyH` descriptions (lines 79, 86), `centerNote` (line 110)
- Modify: `locales/enUS.lua` — three keys retired (lines 547, 551, 557), three appended
- Modify: `docs/ARCHITECTURE.md:472-474` (the Known Limitation), `docs/midnight-quirks.md:174`, and the one citation the suite reports (`docs/data-flow.md` cites `modules/Style.lua:509`; it moves down 3)
- Test: `tests/test_style_text.lua` (the case at line 113 replaced by five; one case before line 476), `tests/test_pages_text.lua` (the case at line 144 rewritten)

**Interfaces:**
- Consumes: `Text.Compiled`, `C.TEXT_ROW_GAP` (added here), Task 7's `PIECE_TEXT` and `Text.PreviewLine`.
- Produces: `Style.Text.Stacked(s, compiled) -> boolean`, `Style.Text.FieldCount(compiled) -> n`,
  `Style.Text.StackHeight(s) -> px` (0 when not stacked); `Style.ElementSize` answers
  `max(stored height, StackHeight)` for a text container. `Text.JustifyFor` is **removed** (its only
  caller was `layoutChain`).

- [ ] **Step 1: Write the failing tests**

`tests/test_style_text.lua`: replace the whole case
`test("text style: Center centers a one-piece template and lines a longer one up Left", function() … end)`
with:

```lua
test("text style: Center centers a one-piece template as one line, exactly as before (feedback #1)", function()
    local _, am = dressed(text({ template = "$spellname$", justifyH = "CENTER", justifyV = "MIDDLE" }))
    local pt = pieces(am)[1]:__last("SetPoint")
    assertEqual(pt[1], "CENTER"); assertEqual(pt[3], "CENTER")
    _, am = dressed(text({ template = "$spellname$", justifyH = "CENTER", justifyV = "TOP" }))
    assertEqual(pieces(am)[1]:__last("SetPoint")[1], "TOP")
    local NS = E()
    -- A one-piece template is a one-row stack: nothing to stack, no growth.
    assertEqual(NS.Style.Text.StackHeight({ template = "$spellname$", justifyH = "CENTER" }), 0)
end)

-- A four-piece line: name, a literal, stacks, and a bracketed duration run.
local STACKED = "$spellname$ :: $stacks$[ - $remainingduration$]"

test("text style: Center stacks a multi-piece template, each field a row centered under the last; literals are not drawn (feedback #1)", function()
    local _, am = dressed(text({ template = STACKED, justifyH = "CENTER", justifyV = "TOP", x = 3, y = -1 }))
    local p = pieces(am)
    local pitch = 12 + 2   -- the template's 12pt font, then C.TEXT_ROW_GAP
    local rows = { p[1], p[3], p[4] }
    for i, fs in ipairs(rows) do
        local pt = fs:__last("SetPoint")
        -- red under: the old chain (LEFT to the previous piece's RIGHT) for a centered multi-piece line
        assertEqual(pt[1], "TOP", "row " .. i)
        assertTrue(pt[2] == am.area, "row " .. i .. " hangs from the text area")
        assertEqual(pt[3], "TOP", "row " .. i)
        assertEqual(pt[4], 3, "row " .. i .. ": x nudges the stack")
        assertEqual(pt[5], -1 - (i - 1) * pitch, "row " .. i .. ": one pitch under the last")
        assertTrue(fs:IsShown(), "row " .. i)
    end
    -- red under: the literal drawn between two rows (it has nothing to sit between)
    assertFalse(p[2]:IsShown(), "the literal ' :: ' is not drawn")
    assertEqual(p[2]:__last("SetPoint"), nil, "and is anchored nowhere")
end)

test("text style: a stacked line's element grows to its rows; Left and Right keep the stored height (feedback #1)", function()
    local NS = E()
    local rows3 = 3 * 12 + 2 * 2
    -- red under: ElementSize ignoring the stack (rows overflowing a 16px box)
    assertEqual(select(2, NS.Style.ElementSize(text({ template = STACKED, justifyH = "CENTER", height = 16 }))), rows3)
    assertEqual(select(2, NS.Style.ElementSize(text({ template = STACKED, justifyH = "CENTER", height = 60 }))), 60,
        "a taller box keeps its height")
    assertEqual(select(2, NS.Style.ElementSize(text({ template = STACKED, justifyH = "LEFT", height = 16 }))), 16)
    assertEqual(select(2, NS.Style.ElementSize(text({ template = STACKED, justifyH = "CENTER", height = 16,
        font = { fontSize = 20 } }))), 3 * 20 + 2 * 2, "the rows follow the font size")
    local frame = dressed(text({ template = STACKED, justifyH = "CENTER", height = 16, width = 200 }))
    assertEqual(frame:__joined("SetSize"), "200," .. rows3, "the element is sized to it")
end)

test("text style: the vertical justify places the stack at the top, middle or bottom of a taller box (feedback #1)", function()
    local stack = 3 * 12 + 2 * 2
    for v, top in pairs({ TOP = 0, MIDDLE = (60 - stack) / 2, BOTTOM = 60 - stack }) do
        local _, am = dressed(text({ template = STACKED, justifyH = "CENTER", justifyV = v, height = 60, x = 0, y = 0 }))
        -- red under: STACK_TOP ignoring the justify (every stack at the top of its box)
        assertEqual(pieces(am)[1]:__last("SetPoint")[5], -top, v)
    end
end)

test("text style: a line moved off Center draws its literals again (feedback #1)", function()
    local c = text({ template = STACKED, justifyH = "CENTER" })
    local frame, am = dressed(c)
    assertFalse(pieces(am)[2]:IsShown())
    c.text.justifyH = "LEFT"
    local NS, m = E()
    B.during(m, {}, function() NS.Style.Element(frame, c, false) end)
    -- red under: a stacked dress's Hide left on the literal once the line is a chain again
    assertTrue(pieces(am)[2]:IsShown())
    assertEqual(pieces(am)[2]:__last("SetPoint")[1], "LEFT")
end)
```

and directly above the case
`test("text style: a placeholder's percent is the nearest whole number, as the engine's step rule rounds it (feedback #5)", …`
insert:

```lua
test("text style: a stacked line previews as its field rows, one per line, without its literals (feedback #1)", function()
    local NS = E()
    local aura = { name = "Ignore Pain", icon = 1, remaining = 11, duration = 12, stacks = 3 }
    -- red under: PreviewLine joining a stacked line as one line, literal included
    assertEqual(NS.Style.Text.PreviewLine({ template = STACKED, justifyH = "CENTER" }, aura), "Ignore Pain\n3\n - 11s")
    assertEqual(NS.Style.Text.PreviewLine({ template = STACKED, justifyH = "LEFT" }, aura), "Ignore Pain :: 3 - 11s")
end)

```

`tests/test_pages_text.lua`: in the case at line 144, replace its name and first five lines

```lua
test("text page: Center on a multi-piece template draws the note naming the piece count", function()
    local NS, _, P = textPage()
    local note = NS.L["Center needs a one-piece template; this one has %d pieces, so it lines up Left."]
    NS.SetByPath(P_ .. "justifyH", "CENTER", 1)
    local ws = P.rerender("Text")
    -- red under: centerNote reading the stored template's piece count wrong, or not drawn
    assertTrue(P.hasText(ws, note:format(3)), "the default template has three pieces")
```

with

```lua
test("text page: Center on a multi-piece template draws the note naming its rows (feedback #1)", function()
    local NS, _, P = textPage()
    local note = NS.L["Center stacks this template in %d rows, one per field; text outside [ ] is not drawn."]
    NS.SetByPath(P_ .. "justifyH", "CENTER", 1)
    local ws = P.rerender("Text")
    -- red under: centerNote still saying Center lines a multi-piece template up Left
    assertTrue(P.hasText(ws, note:format(3)), "the default template has three fields")
    -- red under: the Preview not showing the stack it will draw
    assertTrue(P.hasText(ws, NS.L["Preview: %s"]:format("Ignore Pain\n x3\n - 11s")))
    NS.SetByPath(P_ .. "template", "$spellname$ :: $stacks$", 1)
    ws = P.rerender("Text")
    assertTrue(P.hasText(ws, note:format(2)), "a literal is not a row")
```

(the case's remaining lines — the one-piece and Left checks — stay as they are).

- [ ] **Step 2: Run them and see them fail**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua 2>&1 | grep -A3 "feedback #1"`
Expected: FAIL — `attempt to call field 'StackHeight' (a nil value)`; the stack case
`expected TOP, got LEFT` (row 1 is still the chain's head); the growth case `expected 40, got 16`; the
justify case `expected 0, got …`; the preview cases on the joined line; the page case on the note (the
old "lines up Left" note is drawn). "a line moved off Center …" fails on its first assertion
(`assertFalse(pieces(am)[2]:IsShown())` — the literal is shown in the chain).

- [ ] **Step 3: Implement**

`core/Constants.lua`, replace

```lua
-- Where the line sits in its box. Center is honored only for a one-piece template: the chain's width
-- is never readable, so nothing longer can be centered (modules/Style_Text.lua).
C.TEXT_JUSTIFY_H = { "LEFT", "CENTER", "RIGHT" }
```

with

```lua
-- Where the line sits in its box. Center on a template of more than one piece STACKS it, one centered
-- row per field, since a chain's width is never readable (feedback #1, modules/Style_Text.lua's
-- layoutStack); TEXT_ROW_GAP is the space between two rows, in pixels.
C.TEXT_JUSTIFY_H = { "LEFT", "CENTER", "RIGHT" }
C.TEXT_ROW_GAP = 2
```

`modules/Style.lua`, replace `Style.ElementSize`'s body

```lua
function Style.ElementSize(cfg)
    local key = Style.StyleKey(cfg)
    local s, sdef = cfg[key] or {}, D[key]
    return tonumber(s.width) or sdef.width, tonumber(s.height) or sdef.height
end
```

with

```lua
function Style.ElementSize(cfg)
    local key = Style.StyleKey(cfg)
    local s, sdef = cfg[key] or {}, D[key]
    local w, h = tonumber(s.width) or sdef.width, tonumber(s.height) or sdef.height
    -- A Text line stacked by Center grows to its rows (feedback #1, modules/Style_Text.lua).
    if key == "text" and Style.Text then h = math.max(h, Style.Text.StackHeight(s)) end
    return w, h
end
```

`modules/Style_Text.lua`:

1. The header's
   `-- the next piece anchors to its edge (the 2026-09-18 probes, docs/midnight-quirks.md). Their widths`
   `-- are never readable, which is why a multi-piece line cannot be centered.`
   becomes
   `-- the next piece anchors to its edge (the 2026-09-18 probes, docs/midnight-quirks.md). Their widths`
   `-- are never readable, which is why a multi-piece line cannot be centered as one line: Center STACKS`
   `-- it instead, one centered row per field (feedback #1, layoutStack).`

2. Replace `Text.JustifyFor` and its three-line doc comment with:

```lua
--- Whether a line is laid out as STACKED ROWS (feedback #1, 2026-09-19): Center on a template of more
--- than one piece. A chain's width is never readable and no addon code runs when the engine rewrites a
--- piece in combat, so a multi-piece line cannot be centered as one line; each field piece gets a row of
--- its own instead, centered in the box, and plain literal pieces are not drawn (between two rows they
--- have nothing to sit between). A one-piece template is not stacked: the client centers it as a line.
function Text.Stacked(s, compiled)
    return (s.justifyH or D.justifyH) == "CENTER" and not compiled.single
end

--- How many field pieces (every kind but literal) a compiled template has: a stacked line's rows.
function Text.FieldCount(compiled)
    local n = 0
    for _, piece in ipairs(compiled.pieces) do
        if piece.kind ~= "literal" then n = n + 1 end
    end
    return n
end

--- The line's font size, which is a stacked row's height.
local function fontSize(s)
    return number((s.font or D.font).fontSize, D.font.fontSize)
end

--- The height a stacked line's rows take: one font size per field row and C.TEXT_ROW_GAP between two;
--- 0 for a line that is not stacked. Rows are FIXED: an engine-written string that is empty (and
--- secret) can be neither measured nor collapsed, so a row holds its place whatever its field says.
--- modules/Style.lua's ElementSize grows the element to this height.
function Text.StackHeight(s)
    local compiled = Text.Compiled(s)
    if not Text.Stacked(s, compiled) then return 0 end
    local n = Text.FieldCount(compiled)
    return n * fontSize(s) + (n - 1) * C.TEXT_ROW_GAP
end

-- How far below the text area's top a stack starts, for each vertical justify, in a box `h` tall
-- holding rows `stack` tall (never negative: the box grows to the stack).
local STACK_TOP = {
    TOP = function() return 0 end,
    MIDDLE = function(h, stack) return (h - stack) / 2 end,
    BOTTOM = function(h, stack) return h - stack end,
}

--- Lay a stacked line out in a box `h` tall: each field piece's TOP at the area's TOP, centered, a row
--- pitch lower than the one before (x/y nudge the whole stack); every literal piece hidden.
local function layoutStack(am, s, compiled, h)
    local pitch = fontSize(s) + C.TEXT_ROW_GAP
    local top = (STACK_TOP[s.justifyV or D.justifyV] or STACK_TOP.MIDDLE)(h, Text.StackHeight(s))
    local x, y = number(s.x, D.x), number(s.y, D.y)
    local row = 0
    for i, piece in ipairs(compiled.pieces) do
        local fs = am[PIECE[i]]
        fs:ClearAllPoints()
        if piece.kind == "literal" then
            fs:Hide()
        else
            fs:SetPoint("TOP", am.area, "TOP", x, y - top - row * pitch)
            row = row + 1
        end
    end
end
```

3. `layoutChain`: its doc comment's last line `--- Right-justified line, laid from the last piece back).`
   becomes `--- Right-justified line, laid from the last piece back). A stacked line is laid out by layoutStack.`,
   and its first two lines

```lua
local function layoutChain(am, s, compiled)
    local side = Text.JustifyFor(s, compiled)
```

   become

```lua
local function layoutChain(am, s, compiled, h)
    if Text.Stacked(s, compiled) then return layoutStack(am, s, compiled, h) end
    local side = s.justifyH or D.justifyH
```

4. In `Text.Apply`, `    layoutChain(am, s, compiled)` → `    layoutChain(am, s, compiled, h)`
   (`dressPieces` runs just before and `Show`s every piece, so a line moved off Center draws its
   literals again).

5. Replace Task 7's `Text.PreviewLine` with:

```lua
--- The line text block `s` draws for a sample `aura`, as one plain string: the Text page's Preview
--- (feedback #5). The same compile and the same fill as the placeholders, so the two cannot disagree.
--- A stacked line (feedback #1) previews as its field rows, one per line, its literals left out.
function Text.PreviewLine(s, aura)
    s = s or {}
    local compiled = Text.Compiled(s)
    local stacked = Text.Stacked(s, compiled)
    local parts = {}
    for _, piece in ipairs(compiled.pieces) do
        if not (stacked and piece.kind == "literal") then
            local n = #parts
            parts[n + 1] = PIECE_TEXT[piece.kind](piece, aura, s)
        end
    end
    return table.concat(parts, stacked and "\n" or "")
end
```

`settings/Text.lua`:

1. The `height` row's `desc = L["The height of one line."]` →
   `desc = L["The height of one line. Center stacks a line of several fields in rows, and the box grows to fit them."]`.
2. The `justifyH` row's `desc` →
   `L["How the line sits in its box. Center on a template of several fields stacks them, one centered row each; text outside [ ] is not drawn then, so put it inside the brackets of the field it belongs to."]`.
3. Replace `centerNote` and its doc comment with:

```lua
--- Under Placement: what Center does to a template of more than one piece (feedback #1): it stacks
--- the fields in rows and leaves plain text out (modules/Style_Text.lua's layoutStack).
local function centerNote(ctx, cfg)
    local s = cfg.text or {}
    local compiled = TT.ForDraw(s.template)
    if not NS.Style.Text.Stacked(s, compiled) then return end
    H.TextRow(ctx, GRAY:format(L["Center stacks this template in %d rows, one per field; text outside [ ] is not drawn."]:format(NS.Style.Text.FieldCount(compiled))), SMALL)
end
```

`locales/enUS.lua`: delete the three lines keyed `"The height of one line."`,
`"How the line sits in its box. Center needs a template that is one piece (one token and no text around it); any other lines up Left."`
and `"Center needs a one-piece template; this one has %d pieces, so it lines up Left."`, and append:

```lua
L["The height of one line. Center stacks a line of several fields in rows, and the box grows to fit them."] = "The height of one line. Center stacks a line of several fields in rows, and the box grows to fit them."
L["How the line sits in its box. Center on a template of several fields stacks them, one centered row each; text outside [ ] is not drawn then, so put it inside the brackets of the field it belongs to."] = "How the line sits in its box. Center on a template of several fields stacks them, one centered row each; text outside [ ] is not drawn then, so put it inside the brackets of the field it belongs to."
L["Center stacks this template in %d rows, one per field; text outside [ ] is not drawn."] = "Center stacks this template in %d rows, one per field; text outside [ ] is not drawn."
```

Docs:
- `docs/ARCHITECTURE.md`, the Known Limitation at lines 472–474 becomes:

```markdown
- **A Text line of several pieces cannot be centered as one line.** A line is a chain of font strings
  the engine writes secret, so the chain's width is never readable, and no addon code runs when the
  engine rewrites a piece in combat. A multi-piece template set to Center is therefore STACKED: one
  centered row per field, its plain literal pieces not drawn, the rows fixed in place (an empty field
  keeps its row) and the box grown to fit them (`Style.Text.Stacked`, `Style.Text.StackHeight`;
  feedback #1). The Text page says so under Placement.
```

- `docs/midnight-quirks.md:174`: `width in a chain can be read, so a multi-piece line cannot be centered.`
  → `width in a chain can be read, so a multi-piece line cannot be centered as one line (Center stacks`
  `  it in rows instead, feedback #1).`

- [ ] **Step 4: Run them and see them pass**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua 2>&1 | grep -A3 -E "feedback #1|locale:|FAIL"`
Expected: every case PASSES; the docs case reports `docs/data-flow.md cites modules/Style.lua:509`
drifted: pipe the run into `/tmp/citefix.py` (509 → 512) and run again.

- [ ] **Step 5: Checkpoint — the green gate, complexity and perf**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua && /home/tushar/.claude/wow-addon/bin/ka0s-bounded luacheck . && /home/tushar/.claude/wow-addon/bin/ka0s-bounded lizard -l lua -x "./libs/*" -x "./tests/_kit/*" -C 15 -w . && /home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/perf.lua`
Expected: 0 failed; `0 warnings / 0 errors`; lizard prints nothing; perf exits 0 (`ElementSize` now
compiles the template on a text container — `TT.Compile` is memoized, so `restyleText` stays at its
Task 7 figure within noise).

- [ ] **Step 6: Update the Status ledger row for this task (status, commit SHAs, repo) and the resume guide's "Current position" line; commit the plan file with the task's commit**

Row 8 → `done` with the SHA. Current position → "Next: Task 9 — not started; Tasks 1–8 done." Commit:
`T8: Center stacks a multi-piece Text line in rows (feedback #1)`, with this plan file.

---

### Task 9: #6a — schema v5: every ENCHANT container becomes an enchant-only buff container

**Files:**
- Modify: `defaults/Categories.lua` (append `Cat.EnchantOnlyStates`)
- Modify: `core/Database.lua` — `Database.MigrateV5` above `--- Run \`fn(profile, name)\` over every stored profile …` (line 706); a `to = 5` row closing `SCHEMA_STEPS` (after the `to = 4` row, line 765)
- Modify: `modules/FilterCompiler.lua` — `finishWarnings` (line 563)
- Modify: `docs/schema.md` (a Schema v5 bullet above "An additive change needs no step.", line 399; the `SCHEMA_STEPS` citation at line 295, **by hand** — see Step 4), and the citations the suite reports
- Test: `tests/test_database.lua` (lines 555–556, 849–854, 1010, 1033 edited; five cases appended), `tests/test_filtercompiler.lua` (one appended)

**Interfaces:**
- Consumes: `Cat.StatesShowing(keys)` (Text-style batch), `eachProfile`, the `[Migrate]` tag.
- Produces: `NS.Categories.EnchantOnlyStates() -> states` (Task 10's `/am new enchants` uses it);
  `NS.Database.MigrateV5(p) -> converted`; `Database.CurrentSchemaVersion()` = **5**. An
  enchant-only buff container compiles to the three enchant slots, no aura group and no warning.
  The `ENCHANT` aura type itself still exists after this task (Task 10 removes it), so the tree stays
  green in between.

- [ ] **Step 1: Write the failing tests**

`tests/test_database.lua`:

1. Lines 555–556:
   `    -- steps a v1 profile now climbs (v2, v3, v4).` / `    assertEqual(perProfile, 6, table.concat(lines, " | "))`
   → `    -- steps a v1 profile now climbs (v2, v3, v4, v5).` / `    assertEqual(perProfile, 8, table.concat(lines, " | "))`
   (and the line above, `-- red under: logging once for the whole step, or not at all per profile. 2 profiles x the 3`,
   ends `… 2 profiles x the 4`).
2. Replace the case "v4: the current schema version is 4" with:

```lua
test("v5: the current schema version is 5", function()
    local NS = fresh()
    -- red under: the v5 step missing from SCHEMA_STEPS
    assertEqual(NS.Database.CurrentSchemaVersion(), 5)
    assertEqual(NS.db.global.schemaVersion, 5)
end)
```

3. In the two v4 notice cases ("a genuinely lost container's notice reaches NS.Print …" and "no
   notice is printed when nothing was lost"), `    assertEqual(NS.db.global.schemaVersion, 4)` →
   `    assertEqual(NS.db.global.schemaVersion, NS.Database.CurrentSchemaVersion())`.
4. Append:

```lua

-- ---------------------------------------------------------------------------
-- Schema v5: the Weapon enchants aura type retires (feedback #6)
-- ---------------------------------------------------------------------------

--- A v4 container with the ENCHANT aura type, styled and placed as a player would have left it.
local function enchantContainer()
    return {
        name = "My enchants", enabled = true, unit = "target", auraType = "ENCHANT", style = "icons",
        filter = { hidePermanentEnchants = false, categories = { defensives = "show" }, sortDirection = "reverse" },
        position = { point = "TOPLEFT", relativePoint = "TOPLEFT", x = 12, y = -34 },
        icons = { width = 40, height = 40 },
    }
end

test("v5: an ENCHANT container becomes a player buff container showing only Weapon enchants, its look kept (feedback #6)", function()
    local NS = fresh()
    local p = { containers = { [7] = enchantContainer() } }
    local converted = NS.Database.MigrateV5(p)
    local c = p.containers[7]
    assertEqual(converted, 1)
    -- red under: the aura type left as ENCHANT (C.AURA_TYPES no longer offers it)
    assertEqual(c.auraType, "HELPFUL")
    -- red under: the unit carried over (enchants are only ever the player's)
    assertEqual(c.unit, "player")
    local cats = c.filter.categories
    assertEqual(cats.weaponEnchants, "show")
    for _, def in ipairs(NS.Categories.For("HELPFUL")) do
        if def.key ~= "weaponEnchants" then
            -- red under: a buff category left at Show (the container would draw auras too)
            assertEqual(cats[def.key], "hide", def.key)
        end
    end
    assertEqual(cats.uncategorized, "hide", "Uncategorized is hidden too")
    -- red under: the migration resetting what the player set
    assertEqual(c.filter.hidePermanentEnchants, false, "hide-permanent carries over")
    assertEqual(c.filter.sortDirection, "reverse")
    assertEqual(c.style, "icons"); assertEqual(c.icons.width, 40)
    assertEqual(c.position.x, 12); assertEqual(c.name, "My enchants")
end)

test("v5: only ENCHANT containers are touched, and a second run changes nothing (feedback #6)", function()
    local NS = fresh()
    local buff = { name = "Buffs", unit = "target", auraType = "HELPFUL", filter = { categories = { defensives = "hide" } } }
    local p = { containers = { [1] = buff, [2] = enchantContainer() } }
    NS.Database.MigrateV5(p)
    -- red under: every container rewritten as an enchant container
    assertEqual(buff.unit, "target"); assertEqual(buff.filter.categories.defensives, "hide")
    assertTrue(buff.filter.categories.weaponEnchants == nil, "a buff container's categories are its own")
    local Sig = NS.FilterCompiler.Signature
    local once = Sig(p)
    assertEqual(NS.Database.MigrateV5(p), 0, "nothing left to convert")
    assertEqual(Sig(p), once)
end)

test("v5: RunMigrations converts every stored profile, and the result draws enchants only (feedback #6)", function()
    local function raw()
        return { seeded = true, nextContainerId = 3, containerOrder = { 2 }, containers = { [2] = enchantContainer() } }
    end
    local NS = fresh({ savedVariables = { profiles = { Default = raw(), Raid = raw() }, global = { schemaVersion = 4 } } })
    assertEqual(NS.db.global.schemaVersion, 5)
    for _, name in ipairs({ "Default", "Raid" }) do
        local c = NS.db.sv.profiles[name].containers[2]
        -- red under: the step migrating the active profile only
        assertEqual(c.auraType, "HELPFUL", name)
        assertEqual(c.filter.categories.weaponEnchants, "show", name)
    end
    local plan = NS.FilterCompiler.Compile(NS.db.sv.profiles.Default.containers[2], NS.FilterCompiler.ProfileContext())
    local slotCount, groupCount, warnCount = #plan.enchants.slots, #plan.groups, #plan.warnings
    assertEqual(slotCount, 3, "the three enchant slots")
    assertEqual(groupCount, 0, "and no aura group")
    -- red under: finishWarnings calling an enchant-only container one that can never match
    assertEqual(warnCount, 0, table.concat(plan.warnings, " | "))
end)

test("v5: MigrateV5 logs one [Migrate] line per converted container, naming it (feedback #6)", function()
    local NS = fresh()
    local lines = {}
    NS.Debug = function(tag, fmt, ...)
        if tag == "Migrate" then
            local n = #lines
            lines[n + 1] = fmt:format(...)
        end
    end
    NS.Database.MigrateV5({ containers = { [3] = enchantContainer(), [4] = { auraType = "HARMFUL" }, [5] = enchantContainer() } })
    -- red under: the migration silent per container, or logging the untouched debuff one
    assertEqual(table.concat(lines, " | "), "v5 container '3' (My enchants): now a player buff container showing only Weapon enchants"
        .. " | v5 container '5' (My enchants): now a player buff container showing only Weapon enchants")
end)
```

`tests/test_filtercompiler.lua`, append:

```lua

test("filter: a buff container showing only Weapon enchants draws the slots, no aura group and no never-matches warning (feedback #6)", function()
    local c = cfg({ auraType = "HELPFUL", unit = "player" })
    c.filter.categories = NS.Categories.EnchantOnlyStates()
    local plan = FC.Compile(c, {})
    local slotCount, groupCount = #plan.enchants.slots, #plan.groups
    assertEqual(slotCount, 3)
    assertEqual(groupCount, 0)
    -- red under: NEVER_MATCHES raised for a container whose whole point is its enchant slots
    assertTrue(not hasWarning(plan, "never match"))
    -- The same states on another unit draw nothing at all, and say so.
    c.unit = "target"
    assertTrue(hasWarning(FC.Compile(c, {}), "never match"))
end)
```

- [ ] **Step 2: Run them and see them fail**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua 2>&1 | grep -A3 -E "v5:|feedback #6|one \[Migrate\] line per profile"`
Expected: FAIL — `expected 5, got 4`; `attempt to call field 'MigrateV5' (a nil value)`; the
RunMigrations case `expected 5, got 4`; the per-profile log case `expected 8, got 6`; the compiler case
`attempt to call field 'EnchantOnlyStates' (a nil value)`.

- [ ] **Step 3: Implement**

`defaults/Categories.lua`, append:

```lua

--- The states of an ENCHANT-ONLY buff container (schema v5, feedback #6): every buff category Hidden
--- but Weapon enchants, Uncategorized included, so the container draws the player's temporary weapon
--- enchants and no aura at all. The v5 migration (core/Database.lua) and `/am new enchants`
--- (settings/Slash.lua) both build one from this.
--- @return table
function Cat.EnchantOnlyStates()
    return Cat.StatesShowing({ "weaponEnchants" })
end
```

`core/Database.lua`, directly above `--- Run \`fn(profile, name)\` over every stored profile: AceDB's raw store …`:

```lua
--- Schema v5 over one profile table (feedback #6, 2026-09-19): the Weapon enchants AURA TYPE retires,
--- and enchants are a buff category only. Every stored container with `auraType == "ENCHANT"` becomes
--- an ENCHANT-ONLY buff container: `auraType = "HELPFUL"`, `unit = "player"` (enchants are only ever
--- the player's), and `filter.categories = Cat.EnchantOnlyStates()` (every buff category Hidden but
--- Weapon enchants, Uncategorized included). `filter.hidePermanentEnchants` and every other key —
--- name, style, styling, position — carry over untouched. One [Migrate] line per converted container,
--- in key order. A test seam as well as the step's body, like MigrateV2..V4.
--- @return number  the containers converted
function Database.MigrateV5(p)
    if type(p) ~= "table" or type(p.containers) ~= "table" then return 0 end
    local keys = {}
    for key in pairs(p.containers) do
        keys[#keys + 1] = key
    end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local converted = 0
    for _, key in ipairs(keys) do
        local c = p.containers[key]
        if type(c) == "table" and c.auraType == "ENCHANT" then
            c.auraType, c.unit = "HELPFUL", "player"
            if type(c.filter) ~= "table" then c.filter = {} end
            c.filter.categories = NS.Categories.EnchantOnlyStates()
            converted = converted + 1
            if NS.Debug then
                NS.Debug("Migrate", "v5 container '%s' (%s): now a player buff container showing only Weapon enchants", tostring(key), tostring(c.name))
            end
        end
    end
    return converted
end

```

and in `SCHEMA_STEPS`, after the `to = 4` row's closing `    end },`, before the table's closing `}`:

```lua
    { to = 5, apply = function(db)
        eachProfile(db, function(p, name)
            local n = Database.MigrateV5(p)
            if NS.Debug then
                NS.Debug("Migrate", "v5 profile '%s': the Weapon enchants aura type retired -- %s container(s) now show only the Weapon enchants category", name, n)
            end
        end)
    end },
```

`modules/FilterCompiler.lua`, in `finishWarnings`, replace

```lua
    local groupCount = #plan.groups
    if groupCount == 0 then
        warn(plan, FC.WARN.NEVER_MATCHES)
    end
```

with

```lua
    -- A buff container showing only Weapon enchants (schema v5) draws its enchant slots and no aura
    -- group: that is what it is for, not a filter that can never match.
    local groupCount = #plan.groups
    if groupCount == 0 and not plan.enchants then
        warn(plan, FC.WARN.NEVER_MATCHES)
    end
```

`docs/schema.md`, directly above `- **An additive change needs no step.**`:

```markdown
- **Schema v5** (`Database.MigrateV5`, `core/Database.lua`, feedback #6, 2026-09-19) runs over
  **every** stored profile and logs one `[Migrate] v5 profile '<name>'` line each, plus one
  `[Migrate] v5 container '<key>' (<name>)` line per container it converts; `Database.CurrentSchemaVersion()`
  answers `5`. The **Weapon enchants aura type retires**: weapon enchants are the buff category
  `weaponEnchants` only. Every container with `auraType == "ENCHANT"` becomes an **enchant-only buff
  container** — `auraType = "HELPFUL"`, `unit = "player"` (enchants are only ever the player's), and
  `filter.categories = Cat.EnchantOnlyStates()` (every buff category Hide but Weapon enchants,
  Uncategorized included). `filter.hidePermanentEnchants`, the name, the style, every styling block and
  the position carry over untouched. Such a container compiles to the enchant slots and no aura group,
  and `FC.Compile` does not call it one that can never match. The v3 and v4 steps keep their `ENCHANT`
  handling, because an old profile climbs them before it reaches v5.
```

- [ ] **Step 4: Run them and see them pass**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua 2>&1 | grep -A3 -E "v5:|feedback #6|FAIL"`
Expected: every case PASSES; the docs case reports `docs/common-tasks.md cites core/Database.lua:727`
and `docs/data-flow.md cites modules/FilterCompiler.lua:580`: pipe into `/tmp/citefix.py` (727 → 758,
580 → 582). **Also re-point by hand** `docs/schema.md:295`'s `` `SCHEMA_STEPS` in `core/Database.lua:727` ``
to the line `grep -n '^local SCHEMA_STEPS' core/Database.lua` prints (758): the drift check passes it
by accident (a name in its sentence happens to sit within 3 lines of 727), so the helper never sees it.

- [ ] **Step 5: Checkpoint — the green gate and complexity**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua && /home/tushar/.claude/wow-addon/bin/ka0s-bounded luacheck . && /home/tushar/.claude/wow-addon/bin/ka0s-bounded lizard -l lua -x "./libs/*" -x "./tests/_kit/*" -C 15 -w .`
Expected: 0 failed; `0 warnings / 0 errors`; lizard prints nothing.

- [ ] **Step 6: Update the Status ledger row for this task (status, commit SHAs, repo) and the resume guide's "Current position" line; commit the plan file with the task's commit**

Row 9 → `done` with the SHA. Current position → "Next: Task 10 — not started; Tasks 1–9 done." Commit:
`T9: schema v5 turns every Weapon-enchants container into an enchant-only buff container (feedback #6)`,
with this plan file.

---

### Task 10: #6b — the Weapon enchants aura type is removed everywhere

**Files** (base-commit line numbers; earlier tasks shift some — find each by the quoted text):
- Modify: `core/Constants.lua:42-46` (`AURA_TYPES`, `AURA_TYPE_LABELS`)
- Modify: `defaults/Categories.lua:317-325` (`Cat.ENCHANT`, `Cat.For`)
- Modify: `modules/FilterCompiler.lua` — `FC.WARN.ENCHANT_UNIT` (line 99), `compileEnchant` (326–333), `FC.Compile`'s ENCHANT branch (615)
- Modify: `modules/Container.lua` — `SnapshotClass` (160–164), `Build`'s `SetUnit` (263), `Update` (310–313)
- Modify: `modules/Style.lua` — `cancelEnabled` (530–538)
- Modify: `modules/Preview.lua` — `placeholderCount` (109–117)
- Modify: `settings/Slash.lua` — `NEW_WORDS` (236), `runNew` (242–255)
- Modify: `settings/Filters.lua` — the `hidePermanentEnchants` row (148), `renderCategories`' `hideDrawn` fallback (396, 414, 432–436), `CATS_TYPES` and its comment (586–590), the page spec's comment and Categories tab (620–628)
- Modify: `settings/Containers.lua:80` (the Aura type description)
- Modify: `locales/enUS.lua` (the ENCHANT_UNIT warning's key removed; the Aura type description's key replaced)
- **Keep:** `core/Database.lua`'s `KNOWN_AURA_TYPES` and every `ENCHANT` inside `MigrateV3`/`MigrateV4` and their tests — an old profile climbs v3 and v4 before Task 9's v5 converts it.
- Modify docs: `docs/ARCHITECTURE.md:8-10`, `docs/schema.md:56`, `docs/scope.md:12-15`, `docs/settings-panel.md` (47–48, 179, 259–263, 298–303), `docs/slash-dispatch.md:101`, `docs/data-flow.md:79-81`, `docs/smoke-tests.md` (items 44–45, 102), `README.md:135`; and the citations the suite reports
- Test: `tests/test_container.lua` (422, 459, 575), `tests/test_filtercompiler.lua` (500, 507, 541, the `RICH` case 4 and its signature), `tests/test_style.lua:677`, `tests/test_preview.lua:54`, `tests/test_slash_verbs.lua:528` (+1 appended), `tests/test_options_descriptor.lua:362`, `tests/test_optionssetup.lua:95`, `tests/test_pages_bars.lua:126`, `tests/test_schema_paths.lua:301`, `tests/test_pages_filters.lua` (108 and 142 deleted, 539, 658), `tests/test_pages_containers.lua:315` (+1 appended)

**Interfaces:**
- Consumes: Task 9's `NS.Categories.EnchantOnlyStates()`.
- Produces: `C.AURA_TYPES = { "HELPFUL", "HARMFUL" }`; `Cat.For(t)` answers the list for `HELPFUL`/`HARMFUL`
  and an empty list for anything else; `/am new enchant(s)` makes an enchant-only buff container;
  `FC.WARN.ENCHANT_UNIT` is gone. `grep -rn '"ENCHANT"' core modules settings defaults` afterwards
  finds only `core/Database.lua`'s migration code.

- [ ] **Step 1: Rewrite the tests to the new shape**

`tests/test_container.lua`:

1. Replace the case at line 422 ("a weapon-enchant container shows the player's enchants in the
   engine's three slots, whatever its unit") with:

```lua
test("container: a buff container showing only Weapon enchants draws the engine's three slots and no aura group (feedback #6)", function()
    local NS, mocks = fresh()
    local id = NS.ContainerManager.Create({ auraType = "HELPFUL", unit = "player",
        filter = { categories = NS.Categories.EnchantOnlyStates() } })
    mocks.__fireTimers()
    local inst = NS.ContainerManager.instances[id]
    local e = inst.engine
    -- red under: an enchant-only container still given an aura group (it would draw buffs too)
    assertEqual(sent(e, "AddAuraGroup"), 0)
    local slots = {}
    for i, c in ipairs(e:__callsTo("AddItemEnchantment")) do slots[i] = c[2] end
    local E = mocks.AuraContainerItemEnchantmentSlot
    assertEqual(table.concat(slots, ","), table.concat({ E.MainHand, E.OffHand, E.Ranged }, ","))
    assertEqual(#inst.enchantFrames, 3, "kept for the restyle")
    assertEqual(lastSent(e, "SetUnit")[2], "player")
end)
```

2. In the case at line 459 ("an enchant slot the engine refuses costs that slot, not the build"),
   `    local id = NS.ContainerManager.Create({ auraType = "ENCHANT" })` →
   `    local id = NS.ContainerManager.Create({})   -- a player buff container: its enchant slots`.
3. In the case at line 575, rename it `"container: the class snapshot is the tracked unit's, and nothing for the player"`,
   delete `    local ench = CM.Create({ auraType = "ENCHANT", unit = "target", style = "icons" })` and the
   `    mocks.__fireTimers()` right after it, change `for _, id in ipairs({ 2, 3, ench }) do` to
   `for _, id in ipairs({ 2, 3 }) do`, and delete the last three lines before `end)`
   (`-- red under: SnapshotClass reading an enchant container's own unit`,
   `assertNil(CM.instances[ench].classColor, "enchants are the player's")`,
   `assertFalse(CM.instances[ench].usesClass)`).

`tests/test_filtercompiler.lua`:

1. Delete the cases "filter: a weapon-enchant container has three slots and no aura groups" (500) and
   "filter: an enchant container on another unit still shows the player's, and says so" (507).
2. Replace the case at line 541 ("filter: an enchant container's slots also come from the profile,
   falling back to all three") with:

```lua
test("filter: an enchant-only buff container's slots also come from the profile, falling back to all three", function()
    local enchantsOnly = { unit = "player", filter = { categories = NS.Categories.EnchantOnlyStates() } }
    local none = FC.Compile(cfg(enchantsOnly), { enchantSlots = { mainHand = false, offHand = false, ranged = false } })
    assertEqual(#none.enchants.slots, 3, "every slot off falls back to all three")
    assertTrue(none.enchants.hidePermanent, "hide-permanent is on by default")
    local some = FC.Compile(cfg(enchantsOnly), { enchantSlots = { mainHand = true, offHand = false, ranged = false } })
    assertEqual(table.concat(some.enchants.slots, ","), "mainHand")
end)
```

3. In `RICH`, the fourth case `    { { unit = "target", auraType = "ENCHANT" } },` becomes
   `    { { unit = "player", auraType = "HELPFUL", filter = { categories = NS.Categories.EnchantOnlyStates() } } },`,
   and its signature in `RICH_SIGNATURES` (the last entry, three lines ending
   `enchants whatever its unit is set to.}}",`) becomes:

```lua
    -- An enchant-only buff container (schema v5): the three slots, no aura group, and no warning.
    "{enchants={hidePermanent=boolean:true,slots={1=string:mainHand,2=string:offHand,3=string:ranged}},groups={},"
    .. "warnings={}}",
```

`tests/test_style.lua:677`: rename the case to
`"style: right-click cancel reaches the player's buffs and their enchant slots, never the player's debuffs, and never when turned off"`
and replace `    assertEqual(cancelOf({ unit = "player", auraType = "ENCHANT" }), "RightButtonUp", "a weapon enchant")` with:

```lua
    assertEqual(cancelOf({ unit = "player", auraType = "HELPFUL" }), "RightButtonUp", "a player buff, or its weapon enchants")
    -- red under: cancelEnabled still reading the retired ENCHANT aura type (feedback #6)
    assertNil(cancelOf({ unit = "player", auraType = "ENCHANT" }), "no aura type of that name any more")
```

`tests/test_preview.lua:54`: rename the case `"preview: the per-group cap limits the placeholders"`
and delete its four lines from `    k = container(cfg({ auraType = "ENCHANT" }))` to
`    assertEqual(active(k), 2, "main hand and off hand")`.

`tests/test_slash_verbs.lua:528`: `"NEW Focus Enchants Bar"` → `"NEW Focus Debuffs Bar"` and
`assertEqual(c.auraType, "ENCHANT")` → `assertEqual(c.auraType, "HARMFUL")`; append:

```lua

test("slash verbs: /am new enchants makes a player buff container showing only Weapon enchants (feedback #6)", function()
    local NS2, mocks = fresh()
    local lines = capture(mocks)
    slash(NS2, lines, "new target enchants icons")
    local _, id = NS2.ActiveContainer()
    local c = NS2.Database.FindContainer(id)
    -- red under: the word still writing the retired ENCHANT aura type
    assertEqual(c.auraType, "HELPFUL")
    -- red under: the unit word honored (enchants are only ever the player's)
    assertEqual(c.unit, "player")
    assertEqual(c.style, "icons")
    assertEqual(c.filter.categories.weaponEnchants, "show")
    assertEqual(c.filter.categories.defensives, "hide")
    assertEqual(c.filter.categories.uncategorized, "hide")
end)
```

`tests/test_options_descriptor.lua:362` ("RenderWarnings draws one orange line …"): replace its last
five lines (from `    NS2.Helpers.RenderWarnings(ctx, Database.FindContainer(CM.Create({ auraType = "ENCHANT", unit = "player" })))`)
with:

```lua
    NS2.Helpers.RenderWarnings(ctx, Database.FindContainer(CM.Create({ auraType = "HARMFUL", unit = "player" })))
    assertEqual(#rows, 0, "a plain debuff container is fine")
    NS2.Helpers.RenderWarnings(ctx, Database.FindContainer(CM.Create({ auraType = "HARMFUL", unit = "player",
        filter = { durationMode = "timeless" } })))
    -- red under: RenderWarnings not wrapping the localized warning in the orange code
    assertEqual(table.concat(rows, "|"), "|cffffa040" .. NS2.FilterCompiler.WARN.TIMELESS_BUFFS_ONLY .. "|r")
```

`tests/test_optionssetup.lua:95`: rename it
`"options: the Filters page offers the Overrides tab only for a buff or debuff container, never an unknown type"`
and replace `    NS2.SetByPath("container.auraType", "ENCHANT", 1)` with:

```lua
    -- A stored aura type this build does not know (a hand-edited file; the retired ENCHANT, before
    -- schema v5 runs): no write can store one, so it is planted.
    NS2.Database.FindContainer(1).auraType = "BOGUS"
```

`tests/test_pages_bars.lua:126`: `    NS.SetByPath("container.auraType", "ENCHANT", 1)` →
`    NS.SetByPath("container.auraType", "HARMFUL", 1)`, and its red-under comment's
`(an enchant container drawn as bars loses it)` → `(a debuff container drawn as bars loses it)`.

`tests/test_schema_paths.lua:301` ("SchemaForPage keeps declaration order …"): replace

```lua
    local id = NS2.ContainerManager.Create({ auraType = "ENCHANT" })
    NS2.State.SetActiveContainer(id)
    for _, r in ipairs(NS2.SchemaForPage("filters")) do
        assertTrue(not r.auraTypes or r.auraTypes.ENCHANT, "an enchant container is offered " .. r.path)
    end
    assertTrue(has("container.filter.hidePermanentEnchants"), "a typed row that takes enchants")
    assertFalse(has("container.filter.sortMethod"), "a buffs-and-debuffs row")
```

with

```lua
    local id = NS2.ContainerManager.Create({ auraType = "HARMFUL" })
    NS2.State.SetActiveContainer(id)
    for _, r in ipairs(NS2.SchemaForPage("filters")) do
        assertTrue(not r.auraTypes or r.auraTypes.HARMFUL, "a debuff container is offered " .. r.path)
    end
    -- red under: rowApplies ignoring auraTypes (a buff-only row offered to a debuff container)
    assertFalse(has("container.filter.hidePermanentEnchants"), "a buff-only row")
    assertTrue(has("container.filter.sortMethod"), "a buffs-and-debuffs row")
```

`tests/test_pages_filters.lua`:
1. Delete the cases "filters: a weapon-enchant container's hide-permanent row is a checkbox too, and
   stores a boolean" (108) and "filters: a weapon-enchant container is offered one row on each of two
   tabs and no spell tabs" (142).
2. Line 541: `for _, auraType in ipairs({ "HELPFUL", "HARMFUL", "ENCHANT" }) do` →
   `for _, auraType in ipairs({ "HELPFUL", "HARMFUL" }) do`.
3. In "filters: every tab opens with what the engine will not honor here, in orange" (658), replace
   `NS.L[NS.FilterCompiler.WARN.ENCHANT_UNIT]` with `NS.L[NS.FilterCompiler.WARN.TIMELESS_BUFFS_ONLY]`
   and the two lines `NS.SetByPath("container.auraType", "ENCHANT", 1)` / `NS.SetByPath("container.unit", "target", 1)`
   with `NS.SetByPath("container.auraType", "HARMFUL", 1)` / `NS.SetByPath("container.filter.durationMode", "timeless", 1)`.

`tests/test_pages_containers.lua`: replace the case at line 315 ("containers: changing the aura type
redraws an open Filters page for the new type, on the next frame") with the following two cases:

```lua
test("containers: changing the aura type redraws an open Filters page for the new type, on the next frame", function()
    local NS, m, P, ws = containers()
    P.show("Filters")
    P.tab("filters", NS.L["Categories"])
    NS.Helpers.__pageCtx.filters.panel:Show()   -- on screen, so only a STRUCTURAL refresh re-renders it
    -- The Categories tab is the redraw signal: a debuff container's grids include Dispel Types, a buff
    -- container's do not.
    local function drewDispelTypes(widgets)
        for _, w in ipairs(widgets) do
            if w.type == "Heading" and w.text == NS.L["Dispel Types"] then return true end
        end
        return false
    end
    local during = P.during(function() P.row(ws, "container.auraType"):__fire("OnValueChanged", "HARMFUL") end)
    assertEqual(NS.Database.FindContainer(1).auraType, "HARMFUL")
    assertFalse(drewDispelTypes(during), "never inside the dropdown's own callback")
    local redrawn = P.during(function() m.__fireTimers() end)
    -- red under: the aura type row losing its structural onChange (the tab keeps a buff container's grids)
    assertTrue(drewDispelTypes(redrawn), "redrawn with the debuff container's Dispel Types")
end)

test("containers: Aura type offers Buffs and Debuffs only; the retired Weapon enchants type is refused (feedback #6)", function()
    local NS, _, P, ws = containers()
    local dd = P.row(ws, "container.auraType")
    -- red under: C.AURA_TYPES still listing ENCHANT
    assertEqual(table.concat(dd.order, ","), "HELPFUL,HARMFUL")
    local lines = P.chat()
    NS.Slash:OnSlash("set container.auraType ENCHANT")
    -- red under: /am set taking a value the row no longer lists
    assertEqual(NS.Database.FindContainer(1).auraType, "HELPFUL")
    assertTrue(table.concat(lines, "\n"):find("container.auraType", 1, true) ~= nil, "and says why")
end)
```

- [ ] **Step 2: Run them and see them fail**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua 2>&1 | grep -A3 -E "FAIL"`
Expected: three FAIL — "Aura type offers Buffs and Debuffs only" (`expected HELPFUL,HARMFUL, got
HELPFUL,HARMFUL,ENCHANT`), "/am new enchants makes a player buff container …" (`expected HELPFUL, got
ENCHANT`), and the right-click case ("no aura type of that name any more (got RightButtonUp)"). Every
other rewritten case PASSES already: it stops reading ENCHANT without depending on the change (Task 9
made an enchant-only buff container compile warning-free, which `RICH` case 4 now pins).

- [ ] **Step 3: Implement**

`core/Constants.lua`, replace

```lua
-- Aura types. HELPFUL and HARMFUL are the engine's own filter tokens; ENCHANT is this addon's name for
-- the player's temporary weapon enchants, which the engine draws through AddItemEnchantment rather
-- than through an aura group.
C.AURA_TYPES = { "HELPFUL", "HARMFUL", "ENCHANT" }
C.AURA_TYPE_LABELS = { HELPFUL = "Buffs", HARMFUL = "Debuffs", ENCHANT = "Weapon enchants" }
```

with

```lua
-- Aura types: the engine's own filter tokens. The player's temporary weapon enchants are not an aura
-- type (schema v5, feedback #6): they are the buff category `weaponEnchants`, which the engine draws
-- through AddItemEnchantment beside a player buff container's aura groups.
C.AURA_TYPES = { "HELPFUL", "HARMFUL" }
C.AURA_TYPE_LABELS = { HELPFUL = "Buffs", HARMFUL = "Debuffs" }
```

(`L["Weapon enchants"]` stays in `locales/enUS.lua`: it is the `weaponEnchants` category's label too.)

`defaults/Categories.lua`, replace

```lua
-- Weapon enchants have no categories: the engine draws them per slot.
Cat.ENCHANT = {}

--- The ordered category list for an aura type, never nil.
--- @param auraType string  "HELPFUL" | "HARMFUL" | "ENCHANT"
--- @return table
function Cat.For(auraType)
    return Cat[auraType] or Cat.ENCHANT
end
```

with

```lua
-- The list an aura type this build does not know gets: none (a stored ENCHANT container predates schema
-- v5, which turns it into a buff container before anything reads its categories).
local NONE = {}

--- The ordered category list for an aura type, never nil.
--- @param auraType string  "HELPFUL" | "HARMFUL"
--- @return table
function Cat.For(auraType)
    if auraType == "HELPFUL" or auraType == "HARMFUL" then return Cat[auraType] end
    return NONE
end
```

`modules/FilterCompiler.lua`: delete the `ENCHANT_UNIT = …` line from `FC.WARN`; delete
`compileEnchant` with its doc comment (`--- A weapon-enchant container: the three slots and no aura
groups.` through its `end` and the blank line after); in `FC.Compile` delete the line
`    if auraType == "ENCHANT" then return compileEnchant(plan, cfg, filter, ctx) end`.

`modules/Container.lua`:
1. In `SnapshotClass`'s doc comment delete the line
   `--- An enchant container shows the player's enchants whatever its unit, so it describes the player.`,
   and `    local unit = (cfg.auraType == "ENCHANT") and "player" or cfg.unit` → `    local unit = cfg.unit`.
2. In `Build`, `    callEngine(engine, "SetUnit", (cfg.auraType == "ENCHANT") and "player" or cfg.unit)` →
   `    callEngine(engine, "SetUnit", cfg.unit)`.
3. In `Update`, replace

```lua
    local unit = (cfg.auraType == "ENCHANT") and "player" or cfg.unit
    if self.unit ~= cfg.unit then
        callEngine(engine, "SetUnit", unit)
```

   with

```lua
    if self.unit ~= cfg.unit then
        callEngine(engine, "SetUnit", cfg.unit)
```

`modules/Style.lua`, `cancelEnabled`: the doc comment becomes

```lua
--- Whether right-click cancels this element's aura. Only the player's own buffs and weapon enchants
--- (a player buff container's enchant slots) can be canceled — a debuff or a target's buff cannot,
--- and registering the click there would only swallow it — and a click-through container takes no
--- clicks at all.
```

and `    return cfg.unit == "player" and (cfg.auraType == "HELPFUL" or cfg.auraType == "ENCHANT")` →
`    return cfg.unit == "player" and cfg.auraType == "HELPFUL"`.

`modules/Preview.lua`, replace `placeholderCount` and its doc comment with:

```lua
--- How many placeholders `cfg` shows: every placeholder aura, under the per-group cap.
local function placeholderCount(cfg)
    local count = #C.PREVIEW_AURAS
    local cap = tonumber(cfg.filter and cfg.filter.maxAuras) or 0
    if cap > 0 and cap < count then count = cap end
    return count
end
```

`settings/Slash.lua`:
1. In `NEW_WORDS`, `    enchant = { auraType = "ENCHANT" }, enchants = { auraType = "ENCHANT" },` becomes

```lua
    -- Weapon enchants are a buff category (schema v5, feedback #6): the word makes a player buff
    -- container showing only that category (runNew builds its states).
    enchant = { enchantOnly = true }, enchants = { enchantOnly = true },
```

2. In `runNew`, between the words loop's closing `end` and `    local id, err, refused = NS.ContainerManager.Create(overrides)` insert:

```lua
    if overrides.enchantOnly then
        overrides.enchantOnly = nil
        overrides.auraType, overrides.unit = "HELPFUL", "player"
        overrides.filter = { categories = NS.Categories.EnchantOnlyStates() }
    end
```

`settings/Filters.lua`:
1. The `hidePermanentEnchants` row: `auraTypes = { HELPFUL = true, ENCHANT = true },` → `auraTypes = { HELPFUL = true },`.
2. In `renderCategories`: delete `    local hideDrawn = false`, delete `                    hideDrawn = true`,
   and delete the closing block

```lua
    -- An ENCHANT container draws no Spell Categories grid at all (Cat.For("ENCHANT") is empty), so
    -- hidePermanentEnchants — offered for HELPFUL and ENCHANT alike — would otherwise never draw.
    if hideRow and not hideDrawn then
        H.RenderRows(ctx, { forRenderRows(hideRow) }, nil, nil, { noHeadings = true })
    end
```

3. Delete `CATS_TYPES` and its four-line comment (`-- The Categories tab now carries hidePermanentEnchants
   (auraTypes HELPFUL + ENCHANT), so its own` … `local CATS_TYPES = { HELPFUL = true, HARMFUL = true, ENCHANT = true }`);
   in the page spec, `auraTypes = CATS_TYPES` → `auraTypes = BUFFS_DEBUFFS`, and the comment
   `-- PRIORITY_RANKS). An enchant container has no What to show tab at all …` shrinks to
   `-- PRIORITY_RANKS).` (delete its three following lines).

`settings/Containers.lua:80`: the Aura type row's `desc` →
`L["Buffs or debuffs. The Filters page offers the categories of whichever you choose; your temporary weapon enchants are a buff category there."]`.

`locales/enUS.lua`: replace the line keyed
`"Buffs, debuffs, or your temporary weapon enchants. The Filters page offers the categories of whichever you choose."`
with

```lua
L["Buffs or debuffs. The Filters page offers the categories of whichever you choose; your temporary weapon enchants are a buff category there."] = "Buffs or debuffs. The Filters page offers the categories of whichever you choose; your temporary weapon enchants are a buff category there."
```

and delete the line keyed
`"Weapon enchants only exist on your own character; this container shows the player's enchants whatever its unit is set to."`.

Docs:
- `docs/ARCHITECTURE.md:8-10`: `one aura type (\`HELPFUL\`, \`HARMFUL\`, or` / `\`ENCHANT\` for the player's temporary weapon enchants — \`:39\`) and one style (\`bars\`, \`icons\` or`
  → `one aura type (\`HELPFUL\` or \`HARMFUL\` — \`:39\`;` / `the player's temporary weapon enchants are the buff category \`weaponEnchants\`, schema v5) and one style (\`bars\`, \`icons\` or`.
- `docs/schema.md:56`: the auraType row's last cell → `` `HELPFUL`, `HARMFUL` (`ENCHANT` retired by schema v5) ``.
- `docs/scope.md:12-15`, the "Three aura types" bullet becomes:

```markdown
- **Two aura types:** buffs (`HELPFUL`) and debuffs (`HARMFUL`). The player's temporary weapon
  enchants are a buff category, not an aura type (schema v5, feedback #6): a player-buff container
  appends them after its buffs (drawn through the engine's `AddItemEnchantment`) unless its
  `weaponEnchants` category (`container.filter.categories.weaponEnchants`) is set to Hide, and a
  container that shows ONLY enchants is a player-buff container whose every other category is Hidden
  (`Cat.EnchantOnlyStates`, `/am new enchants`).
```

- `docs/settings-panel.md`: lines 47–48 `…the buff categories are not offered on a debuff container, and a` /
  `weapon-enchant container sees only the rows that mean something for it.` →
  `…the buff categories and Hide enchants without a duration are not` / `offered on a debuff container.`;
  line 179's last cell → `Buffs / Debuffs; structural (weapon enchants are a buff category, schema v5)`;
  lines 259–263 `(… bool, buffs and enchants), behind …` → `(… bool, buffs only), behind …` and delete
  the sentence from `; an` / `` `ENCHANT`-type container, which draws no Spell Categories grid at all, … `` to
  `(there is no row above to tie it to).` (end the paragraph at `…from reading as floating).`);
  lines 298–303, the paragraph `A weapon-enchant container drops **What to show** and **Overrides** …`,
  becomes:

```markdown
A container that shows only weapon enchants is a buff container (schema v5): on its Categories tab
every category is Hide but **Weapon enchants**, and **Show all** / **Hide all** (feedback #10) reach
it like any other.
```

- `docs/slash-dispatch.md:101`, the row becomes two rows:

```markdown
| `buff`, `buffs` / `debuff`, `debuffs` | `auraType` (`HELPFUL` / `HARMFUL`) |
| `enchant`, `enchants` | a player buff container showing only the Weapon enchants category: `auraType = HELPFUL`, `unit = player`, `filter.categories = Cat.EnchantOnlyStates()` (schema v5; a unit word is overridden) |
```

- `docs/data-flow.md:79-81`, the weapon-enchant bullet becomes:

```markdown
- **A player buff container** appends the enchant slots the profile's `enchantSlots` names (falling
  back to all three when none are ticked), with `hidePermanent` from the settings, unless its
  `weaponEnchants` category is Hide. One showing ONLY enchants (schema v5: every other category Hide)
  compiles to those slots and no aura group, and is not warned about as one that can never match.
```

- `docs/smoke-tests.md`: in item 44, delete `A container with aura type *Weapon enchants* shows it too, always` /
  `(that row has no bearing on it). ` (keep `**Hide enchants without a duration** hides a permanent one.`);
  item 45 becomes

```markdown
45. `/am new enchants` → a player buff container named *Container N* whose Filters → Categories are
    all Hide but **Weapon enchants**: it shows your enchants and no buff. The Aura type dropdown on
    Containers offers Buffs and Debuffs only (schema v5, feedback #6).
```

  and item 102 becomes `102. **Weapon enchants.** An enchant-only buff container (\`/am new enchants text\`) shows the enchant's name and time.`
- `README.md:135`: `…is set to Show (the default), or in one whose aura type is *Weapon enchants*. Which weapon slots count…`
  → `…is set to Show (the default); \`/am new enchants\` makes one that shows nothing else. Which weapon slots count…`.

- [ ] **Step 4: Run them and see them pass**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua 2>&1 | grep -A3 -E "FAIL"`
Expected: only the docs cases fail, on moved citations (`modules/Style.lua`, `modules/FilterCompiler.lua`,
`settings/Slash.lua`): pipe into `/tmp/citefix.py` (measured: ten re-points, none by hand) and run again —
0 failed. Then `grep -rn '"ENCHANT"' core modules settings defaults` prints only `core/Database.lua` lines.

- [ ] **Step 5: Checkpoint — the green gate and complexity**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua && /home/tushar/.claude/wow-addon/bin/ka0s-bounded luacheck . && /home/tushar/.claude/wow-addon/bin/ka0s-bounded lizard -l lua -x "./libs/*" -x "./tests/_kit/*" -C 15 -w .`
Expected: 0 failed; `0 warnings / 0 errors` (the filter case's local is `enchantsOnly`: `only` would
shadow the file's own `only` helper); lizard prints nothing.

- [ ] **Step 6: Update the Status ledger row for this task (status, commit SHAs, repo) and the resume guide's "Current position" line; commit the plan file with the task's commit**

Row 10 → `done` with the SHA. Current position → "Next: Task 11 — not started; Tasks 1–10 done." Commit:
`T10: the Weapon enchants aura type is removed; enchants are a buff category (feedback #6)`, with this plan file.

---

### Task 11: #7a — bars' background colored by dispel type; no type keeps the surface's own color

**Files** (base-commit line numbers):
- Modify: `core/Constants.lua:161-170` (`DISPEL_TYPES` and `DEFAULT_DISPEL_COLORS` lose `None`)
- Modify: `defaults/Profile.lua:170` (`bars.bgColorMode = "static"`)
- Modify: `modules/Style.lua` — `dispelMapCurrent` (380–388), a new `buildDispelMap`, `Style.DispelColorMap` (397–411)
- Modify: `modules/Style_Bars.lua` — `paintFill` and `applySurfaces` (175–207), a new `dispelTint` above `Bars.Bind`'s doc comment (277), `Bars.Bind`'s dispel block (290–296)
- Modify: `core/Database.lua` — Task 9's `MigrateV5` also clears `dispelColors.None`
- Modify: `settings/Bars.lua` — the `colorMode` row's desc (49), the background `BarGroup` (107–111) and `BG_TOOLTIPS` (112–117)
- Modify: `settings/GeneralSpells.lua` — header lines 14 and 39–44, `DISPEL_ROWS` (317–324), `renderDispel`'s line (328)
- Modify: `locales/enUS.lua` (three keys replaced, one appended)
- Modify: `docs/settings-panel.md` (lines 95, 162–163, 354, 367, 377–378, 469), `docs/schema.md` (25, 111, 127–129), and the citations the suite reports
- Test: `tests/test_style.lua` (398–399 and 414 edited; one case after 656), `tests/test_style_bars.lua` (575–576 edited; one appended), `tests/test_preview.lua` (one appended), `tests/test_pages_general.lua` (the case at 633 edited), `tests/test_pages_bars.lua` (the case at 186 extended; one after it), `tests/test_database.lua` (one appended)

**Interfaces:**
- Consumes: `Style.CurveColor(stored, useClass)` (a stable `{r,g,b,a}` per look), `Style.ProfileDispelColors()`.
- Produces: `Style.DispelColorMap(stored, fallback) -> map` — every palette type in its color, `map.None`
  in `fallback`'s color, every entry at `fallback.a` (memoized per palette and fallback);
  `container.bars.bgColorMode` (`"static"` | `"dispel"`); `C.DISPEL_TYPES` has five entries. The
  Text half of #7 is Task 12's.

- [ ] **Step 1: Write the failing tests**

`tests/test_style.lua`:

1. Lines 398–399 become:

```lua
    -- red under: Style.DispelColorMap without its memo (a map is the palette's colors plus the None
    -- fallback, feedback #7)
    assertEqual(built.colors - k0, dispelLeaves + 1 + 2, "one dispel map and one curve's two colors")
```

2. Line 414 becomes
   `    assertEqual(built.colors - k1, dispelLeaves + 1, "a new dispel color rebuilds the map, its None fallback included")`.

3. After the case "style: a dispel color map holds a color per stored type, and nothing for a leaf that
   is not a color" add:

```lua

test("style: a dispel color map's None entry is the surface's own color, and every entry its alpha (feedback #7)", function()
    local stored = { Magic = { r = 0.1, g = 0.2, b = 0.3, a = 1 } }
    local bar = { r = 0.9, g = 0.5, b = 0.1, a = 0.6 }
    local map = NS.Style.DispelColorMap(stored, bar)
    -- red under: None left to the palette (or to Blizzard's own tint) for an aura with no type
    assertEqual(table.concat({ map.None.r, map.None.g, map.None.b, map.None.a }, ","), "0.9,0.5,0.1,0.6")
    -- red under: a dispel-colored surface drawn opaque over a translucent one's own alpha
    assertEqual(map.Magic.a, 0.6)
    assertTrue(NS.Style.DispelColorMap(stored, bar) == map, "one map per palette and fallback")
    local bg = { r = 0, g = 0, b = 0, a = 0.5 }
    assertTrue(NS.Style.DispelColorMap(stored, bg) ~= map, "another surface's fallback, another map")
    bar.r = 0.2   -- a class-colored fallback is updated in place
    assertEqual(NS.Style.DispelColorMap(stored, bar).None.r, 0.2, "a moved fallback rebuilds")
end)
```

`tests/test_style_bars.lua`, lines 575–576 (in "bars: dispel coloring tints the fill through the
engine …") become:

```lua
    -- red under: the bar still reading a per-container bars.dispelColors (schema v2 lifted it), or the
    -- map built without the bar's own color for an aura with no type (feedback #7)
    assertTrue(add[2].customDispelColorMap
        == NS2.Style.DispelColorMap(NS2.db.profile.dispelColors, NS2.Style.CurveColor(c.bars.barColor, false)), "the profile's colors")
```

and append:

```lua

-- ── the background by dispel type (feedback #7) ───────────────────────────────────────────────

test("bars: Color by dispel type on the background tints it through the engine, no type keeping the background color (feedback #7)", function()
    local NS2 = withEnums()
    local c = NS2.Database.Merge(NS2.Database.DeepCopy(NS2.CONTAINER_TEMPLATE), { bars = { bgColorMode = "dispel" } })
    local frame, am = dressed(c, true, nil, NS2)
    local add = frame:__last("AddDispelTypeTexture")
    -- red under: no background binding at all
    assertTrue(add ~= nil and add[1] == am.bg, "the background carries the tint")
    assertEqual(frame:__count("AddDispelTypeTexture"), 1, "the fill, on one color, carries none")
    assertEqual(add[2].style, 32, "PreserveAsset keeps our texture")
    assertTrue(add[2].showAlways and add[2].showWithoutDispelType, "shown for every aura")
    local map = add[2].customDispelColorMap
    local bgc = c.bars.bgColor
    -- red under: the background's map built with the bar color's fallback
    assertEqual(table.concat({ map.None.r, map.None.g, map.None.b, map.None.a }, ","),
        table.concat({ bgc.r, bgc.g, bgc.b, bgc.a }, ","))
    c.bars.bgColorMode = "static"
    frame = dressed(c, true, nil, NS2)
    assertEqual(frame:__count("AddDispelTypeTexture"), 0, "one color: no tint")
end)
```

`tests/test_preview.lua`, append:

```lua

test("preview: a background colored by dispel type stands in with Magic, keeping its own alpha (feedback #7)", function()
    local c = cfg({ style = "bars", bars = { bgColorMode = "dispel", useClassColorBg = false,
        bgColor = { r = 0, g = 0, b = 0, a = 0.5 } } })
    local k = container(c)
    NS.Preview.Show(k)
    for _, f in ipairs(k.frames) do
        for key in pairs(f.__am) do f.__am[key] = R() end
    end
    k.previewDirty = true
    NS.Preview.Show(k)
    local m = NS.db.profile.dispelColors.Magic
    for i, f in ipairs(k.previewPools.bars.active) do
        -- red under: the preview painting the background its static color whatever its Color by
        assertEqual(f.__am.bg:__joined("SetVertexColor"), table.concat({ m.r, m.g, m.b, 0.5 }, ","), "placeholder " .. i)
    end
end)
```

`tests/test_pages_general.lua`, the case at line 633: rename it
`"general → dispel colors: five profile-wide swatches, no None, no class-color companion, under a line saying they drive bars only"`;
replace `    assertEqual(#P.all(ws, "ColorPicker"), 6)` with

```lua
    -- red under: the None swatch still drawn (an aura with no type keeps the surface's color, feedback #7)
    assertEqual(#P.all(ws, "ColorPicker"), 5)
    assertEqual(NS.FindSchemaRow("dispelColors.None"), nil, "no None row")
```

and change the two quoted keys to the new ones:
`"One color per dispel type, shared by every container, for bars colored by dispel type. An aura with no dispel type keeps the bar's own color. An icon's dispel border keeps Blizzard's own colors."`
and
`"This dispel type's color for a bar's fill or background when its Color by is set to dispel type. An icon's dispel border keeps Blizzard's own colors."`.

`tests/test_pages_bars.lua`: at the end of the case at line 186 ("Highlights carries no dispel swatches,
and Color by points at General -> Dispel Colors (B-6)"), before its `end)`, add

```lua
    -- red under: the tooltip silent on why Mystic Touch keeps the bar color (feedback #7)
    assertTrue(desc:find("Mystic Touch", 1, true) ~= nil, desc)
```

and after that case add:

```lua

test("bars: Background & border offers Color by beside the background, writing bgColorMode (feedback #7)", function()
    local NS, _, P = bars()
    P.show("Bars")
    local ws = P.tab("bars", NS.L["Background & border"])
    local row = NS.FindSchemaRow("container.bars.bgColorMode")
    -- red under: no bgColorMode row
    assertTrue(row ~= nil and row.subgroup == NS.L["Background"], "a Background row")
    local dd
    for _, w in ipairs(P.rowWidgets(ws, "bars", NS.L["Background & border"])) do
        if w.type == "Dropdown" and w.labelText == row.label then dd = w end
    end
    assertTrue(dd ~= nil, "drawn on the tab")
    assertEqual(table.concat(dd.order, ","), "static,dispel")
    dd:__fire("OnValueChanged", "dispel")
    assertEqual(NS.Database.FindContainer(1).bars.bgColorMode, "dispel")
    assertTrue((row.tooltip or row.desc):find("Mystic Touch", 1, true) ~= nil, "the tooltip says why a typeless debuff keeps its color")
    assertEqual(NS.CONTAINER_TEMPLATE.bars.bgColorMode, "static", "one color by default")
end)
```

`tests/test_database.lua`, append:

```lua

test("v5: the profile's retired dispelColors.None leaf is cleared (feedback #7)", function()
    local NS = fresh()
    local p = { dispelColors = { Magic = { r = 0.2, g = 0.6, b = 1, a = 1 }, None = { r = 0.8, g = 0, b = 0, a = 1 } },
        containers = {} }
    NS.Database.MigrateV5(p)
    -- red under: MigrateV5 leaving a color nothing reads in every old profile
    assertEqual(p.dispelColors.None, nil)
    assertEqual(p.dispelColors.Magic.r, 0.2, "the palette's colors stay")
end)
```

- [ ] **Step 2: Run them and see them fail**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua 2>&1 | grep -A3 -E "feedback #7|share one formatter|tints the fill through the engine|Highlights carries no dispel"`
Expected: FAIL — `attempt to index field 'None' (a nil value)` (no None entry); the fill case on
"the profile's colors" (a different map); the background cases (`the background carries the tint`,
`attempt to index … bgColorMode` / no row); the preview case (the static color); the General case
`expected 5, got 6`; "Mystic Touch"; `expected nil` for the None leaf; and the shared-look count
`expected 9, got 8`.

- [ ] **Step 3: Implement**

`core/Constants.lua`, replace

```lua
-- The dispel types the engine names, plus "None" for an aura without one.
C.DISPEL_TYPES = { "Magic", "Curse", "Disease", "Poison", "Bleed", "None" }
```

with

```lua
-- The dispel types the engine names. An aura with none (the engine keys it "None") takes the surface's
-- own color, not a palette color (feedback #7, modules/Style.lua's DispelColorMap).
C.DISPEL_TYPES = { "Magic", "Curse", "Disease", "Poison", "Bleed" }
```

and delete the line `    None    = { r = 0.80, g = 0.00, b = 0.00, a = 1 },` from `C.DEFAULT_DISPEL_COLORS`.

`defaults/Profile.lua`, after
`        bgTexture = "Blizzard", bgAlpha = 1.0, bgColor = color(0, 0, 0, 0.5), useClassColorBg = false,` add

```lua
        bgColorMode = "static",   -- "dispel" tints the background as colorMode does the fill (feedback #7)
```

`modules/Style.lua`, replace `dispelMapCurrent` and its doc line with:

```lua
--- Whether a memoized dispel map was built from exactly the color leaves `stored` holds now, and from
--- the fallback color's channels as they are now (a class-colored fallback is reused in place).
local function dispelMapCurrent(entry, stored, fallback)
    local src = entry.src
    for _, name in ipairs(C.DISPEL_TYPES) do
        if stored[name] ~= src[name] then return false end
    end
    return entry.r == fallback.r and entry.g == fallback.g and entry.b == fallback.b and entry.a == fallback.a
end
```

and replace `Style.DispelColorMap` and its two-line doc comment with:

```lua
--- A new dispel map entry for DispelColorMap: the map, and what it was built from.
local function buildDispelMap(stored, fallback)
    local a = fallback.a or 1
    local map, src = {}, {}
    for _, name in ipairs(C.DISPEL_TYPES) do
        local c = stored[name]
        src[name] = c
        if type(c) == "table" then map[name] = _G.CreateColor(c.r or 1, c.g or 1, c.b or 1, a) end
    end
    map.None = _G.CreateColor(fallback.r or 1, fallback.g or 1, fallback.b or 1, a)
    return { map = map, src = src, r = fallback.r, g = fallback.g, b = fallback.b, a = fallback.a }
end

--- A color map for AddDispelTypeTexture's `customDispelColorMap`, from a stored { Magic = {r,g,b,a} }
--- and the surface's own color `fallback` ({ r, g, b, a }, stable per look: Style.CurveColor). Each
--- dispel type takes its palette color; an aura with NO dispel type — the engine keys it "None"
--- (GetDispelTypeMapKey) — takes `fallback`, so it keeps the surface's normal color rather than
--- Blizzard's own "none" tint (feedback #7, owner decision: no type means the normal color). Every
--- entry carries the fallback's alpha, so a dispel-colored surface keeps its own transparency.
--- Built once per set of color leaves and fallback, and shared by every button that shows it.
function Style.DispelColorMap(stored, fallback)
    if type(stored) ~= "table" or not _G.CreateColor then return {} end
    fallback = fallback or NO_COLOR
    local byFallback = dispelMaps[stored]
    if not byFallback then
        byFallback = setmetatable({}, WEAK_KEYS)
        dispelMaps[stored] = byFallback
    end
    local entry = byFallback[fallback]
    if not (entry and dispelMapCurrent(entry, stored, fallback)) then
        entry = buildDispelMap(stored, fallback)
        byFallback[fallback] = entry
    end
    return entry.map
end
```

(One function would be CCN 16; the builder keeps both under 15.)

`modules/Style_Bars.lua`:

1. Replace `paintFill` (with its doc comment) and the head of `applySurfaces` — from `--- Paint the fill
   and show it. A live dispel-colored fill takes the bar color here and the engine's` to
   `    am.bg:SetAlpha(tonumber(b.bgAlpha) or D.bars.bgAlpha)` — with:

```lua
--- Paint one surface (the fill or the background) its color. A live surface colored by dispel type
--- takes its own color here and the engine's tint over it; a PREVIEW one stands in with the profile's
--- Magic color, since no placeholder names a type, keeping the surface's own alpha. The tint is part of
--- the dress, so a later static dress is never left tinted.
local function paintSurface(tex, mode, stored, useClass, preview)
    local r, g, bl, a = Style.Color(stored, useClass)
    local dc = preview and mode == "dispel" and Style.ProfileDispelColors()
    local m = dc and dc.Magic
    if m then r, g, bl = m.r or 1, m.g or 1, m.b or 1 end
    tex:SetVertexColor(r, g, bl, a)
end

--- Paint the fill and show it. The fill is shown every dress: the engine's no-aura pass hides a
--- dispel texture, and clearing the binding does not show it again.
local function paintFill(am, b, preview)
    am.fill:SetTexture(Style.Fetch("statusbar", b.barTexture, C.FALLBACK_TEXTURE))
    paintSurface(am.fill, b.colorMode, b.barColor, b.useClassColorBar, preview)
    am.fill:SetAlpha(tonumber(b.barAlpha) or D.bars.barAlpha)
    am.fill:Show()
end

--- Paint the surfaces: the fill, the background, the border and the spark. Each surface's opacity
--- multiplies onto its color's own alpha, so a color's alpha still applies. The background colors by
--- dispel type as the fill does (feedback #7) and is shown every dress for the same reason.
local function applySurfaces(am, b, preview)
    paintFill(am, b, preview)

    am.bg:SetTexture(Style.Fetch("statusbar", b.bgTexture, C.FALLBACK_TEXTURE))
    paintSurface(am.bg, b.bgColorMode, b.bgColor, b.useClassColorBg, preview)
    am.bg:SetAlpha(tonumber(b.bgAlpha) or D.bars.bgAlpha)
    am.bg:Show()
```

2. Directly above `--- Hand the regions to the engine. Every call is guarded (Style.Bind). The two ADDITIVE bindings only`, insert:

```lua
--- AddDispelTypeTexture's options for a surface colored by dispel type: shown for every aura, our own
--- texture kept (PreserveAsset), tinted from the profile's palette, and an aura with no dispel type in
--- the surface's own `fallback` color (Style.DispelColorMap).
local function dispelTint(palette, fallback)
    return {
        showAlways = true, showWithoutDispelType = true,
        style = NS.Compat.DispelStyle("PreserveAsset"),
        customDispelColorMap = Style.DispelColorMap(palette, fallback),
    }
end

```

3. In `Bars.Bind`, replace

```lua
    if b.colorMode == "dispel" then
        Style.Bind(frame, "AddDispelTypeTexture", am.fill, {
            showAlways = true, showWithoutDispelType = true,
            style = Compat.DispelStyle("PreserveAsset"),
            customDispelColorMap = Style.DispelColorMap(Style.ProfileDispelColors()),
        })
    end
```

with

```lua
    local palette = Style.ProfileDispelColors()
    if b.colorMode == "dispel" then
        Style.Bind(frame, "AddDispelTypeTexture", am.fill,
            dispelTint(palette, Style.CurveColor(b.barColor, b.useClassColorBar)))
    end
    if b.bgColorMode == "dispel" then
        Style.Bind(frame, "AddDispelTypeTexture", am.bg,
            dispelTint(palette, Style.CurveColor(b.bgColor, b.useClassColorBg)))
    end
```

`core/Database.lua`, `MigrateV5` (Task 9): its doc comment's last lines become
`--- in key order. The profile's \`dispelColors.None\` is cleared too: an aura with no dispel type takes`
`--- the surface's own color now (feedback #7), so nothing reads it. A test seam as well as the step's`
`--- body, like MigrateV2..V4.`, and its first line
`    if type(p) ~= "table" or type(p.containers) ~= "table" then return 0 end` becomes:

```lua
    if type(p) ~= "table" then return 0 end
    if type(p.dispelColors) == "table" then p.dispelColors.None = nil end
    if type(p.containers) ~= "table" then return 0 end
```

`settings/Bars.lua`:
1. The `colorMode` row's `desc` →
   `L["One color, or each debuff's dispel type (colors on General -> Dispel Colors). An aura with no dispel type keeps the bar color: a buff, or a debuff nothing can dispel, such as Mystic Touch."]`.
2. The background `H.BarGroup({ … })` gains, after its `labels = { … },` line:

```lua
    -- feedback #7: the background colors by dispel type as the fill does, from the same palette.
    extra = {
        { path = P .. "bgColorMode", type = "string", values = NS.Choices(C.BAR_COLOR_MODES, C.BAR_COLOR_MODE_LABELS),
          label = L["Color by"] },
    },
```

3. `BG_TOOLTIPS` gains, after its `useClassColorBg` entry:

```lua
    [P .. "bgColorMode"] = L["One color, or each debuff's dispel type (colors on General -> Dispel Colors). An aura with no dispel type keeps the background color: a buff, or a debuff nothing can dispel, such as Mystic Touch."],
```

`settings/GeneralSpells.lua`:
1. Line 14: `Magic … None` → `Magic … Bleed`.
2. Lines 39–44's first sentence becomes: `-- DISPEL COLORS are five plain color rows at \`dispelColors.<type>\`: absolute, so profile-wide, and with`
   `-- no \`effect\`, so a write re-applies every container. Only bars read them, a bar's fill or background`
   `-- colored by dispel type; an icon's dispel border keeps Blizzard's own colored art (modules/Style_Icons.lua,`
   `-- owner 2026-09-13). There is no None swatch (feedback #7): an aura with no dispel type keeps the`
   `-- surface's own color, so a None color would be read by nothing; schema v5 clears the stored leaf.`
   (the paragraph's remaining lines — palette definitions, no companion — stay).
3. In `DISPEL_ROWS`, the row's `desc` →
   `L["This dispel type's color for a bar's fill or background when its Color by is set to dispel type. An icon's dispel border keeps Blizzard's own colors."]`
   (the loop is unchanged: `C.DISPEL_TYPES` no longer lists None).
4. `renderDispel`'s line → `L["One color per dispel type, shared by every container, for bars colored by dispel type. An aura with no dispel type keeps the bar's own color. An icon's dispel border keeps Blizzard's own colors."]`.

`locales/enUS.lua`: replace the three lines whose keys are the old `colorMode` desc, the old dispel
row desc and the old Dispel Colors line with their new strings (key == value), and append

```lua
L["One color, or each debuff's dispel type (colors on General -> Dispel Colors). An aura with no dispel type keeps the background color: a buff, or a debuff nothing can dispel, such as Mystic Touch."] = "One color, or each debuff's dispel type (colors on General -> Dispel Colors). An aura with no dispel type keeps the background color: a buff, or a debuff nothing can dispel, such as Mystic Touch."
```

Docs:
- `docs/settings-panel.md`: line 95 `### General (19 rows,` → `### General (18 rows,`; lines 162–163
  become `**Dispel Colors** — one line saying who reads the colors, then five swatches, \`dispelColors.Magic\`,` /
  `` `.Curse`, `.Disease`, `.Poison`, `.Bleed`: the fill or background of a bar colored by dispel type. An `` /
  `aura with no dispel type keeps the surface's own color (feedback #7), so there is no None swatch. They`;
  line 354 `### Bars (71 rows,` → `### Bars (72 rows,`; the Background & border row (367) → `| Background & border (10) | *Background:* the composed bar block on the background leaves \`bgTexture\` · \`bgAlpha\` / \`bgColor\` · \`useClassColorBg\`, then \`bgColorMode\` (one color / by dispel type); *Border:* …`;
  lines 377–378 become:

```markdown
`smooth` selects the engine's eased interpolation; `colorMode = dispel` hands the fill to the engine
as a dispel-type texture tinted from the profile's `dispelColors` (General → Dispel Colors), and
`bgColorMode = dispel` the background the same way (feedback #7); an aura with no dispel type — a buff,
or a debuff nothing can dispel, such as Mystic Touch — keeps the surface's own color (the map's
`None` entry, `Style.DispelColorMap`); every `timeFormat` hands the engine a
```

  and line 469 `the six \`dispelColors.*\`` → `the five \`dispelColors.*\``.
- `docs/schema.md`: line 25's `(\`Magic\`, \`Curse\`, \`Disease\`, \`Poison\`, \`Bleed\`, \`None\`) for a bar colored by dispel type` →
  `(\`Magic\`, \`Curse\`, \`Disease\`, \`Poison\`, \`Bleed\`; no \`None\` since schema v5, feedback #7) for a bar's fill or background colored by dispel type`;
  after the `bgColor` row (111) add `| \`bgColorMode\` | \`"static"\` (\`static\`, \`dispel\`: tinted by the profile's \`dispelColors\`, feedback #7) | | |`;
  lines 128–129's `…Bleed \`{0.80, 0.10, 0.10}\`, None` / `` `{0.80, 0.00, 0.00}`, all alpha 1. `` →
  `…Bleed \`{0.80, 0.10, 0.10}\`, all alpha 1. An aura` / `with no dispel type takes the surface's own color instead (feedback #7); schema v5 clears a stored` / `` `None` leaf. ``.

- [ ] **Step 4: Run them and see them pass**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua 2>&1 | grep -A3 -E "feedback #7|FAIL"`
Expected: all PASS but the docs case: pipe into `/tmp/citefix.py` (measured: `modules/Style.lua` ×2,
`core/Database.lua` ×2, `modules/Style_Bars.lua` ×1) and run again. The helper re-points
`docs/midnight-quirks.md`'s `modules/Style_Bars.lua:183` (the permanent-aura fill paragraph) to the
line that kept its old text, which no longer names the fill: set it **by hand** to the line
`grep -n '^local function wireFill' modules/Style_Bars.lua` prints (the fill stretched to the moving
edge is `wireFill`'s). Run again: 0 failed.

- [ ] **Step 5: Checkpoint — the green gate and complexity**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua && /home/tushar/.claude/wow-addon/bin/ka0s-bounded luacheck . && /home/tushar/.claude/wow-addon/bin/ka0s-bounded lizard -l lua -x "./libs/*" -x "./tests/_kit/*" -C 15 -w .`
Expected: 0 failed; `0 warnings / 0 errors`; lizard prints nothing.

- [ ] **Step 6: Update the Status ledger row for this task (status, commit SHAs, repo) and the resume guide's "Current position" line; commit the plan file with the task's commit**

Row 11 → `done` with the SHA, Notes "None swatch retired (D-7, owner to confirm)". Current position →
"Next: Task 12 — not started; Tasks 1–11 done." Commit:
`T11: the bar background colors by dispel type; no type keeps the normal color (feedback #7)`, with this plan file.

---

### Task 12: #7b — text by dispel type: the colored word, a tinted backdrop, a tinted edge (each opt-in, all off)

The spec (§7) asked for the Text style's text colored by the aura's dispel type, and a stop-and-report
if the engine has no path for it. It has none for the whole line (D-7). The owner then chose, 2026-09-19:
"DO all of #1,2,3 - all opt -in - all turned off by default". So this task builds three stand-ins, each
its own setting and all off by default:
- (c) the `$dispeltype$` word in its type's color;
- (a) a tinted backdrop behind the line;
- (b) a tinted edge around it.

They live in a new **Dispel type** subsection on Text → Animation, between Loop and Running out. That
tab is the Text page's counterpart of Bars → Highlights: it already holds the running-out color.

**The evidence for (c)** is the Blizzard source in the scratchpad `ui/` folder, fetched 2026-09-19:
- `Blizzard_CustomAuraButton.lua:485-503`: `ApplyDispelTypeText` looks the aura up in
  `options.customDispelTextMap[auraData.dispelName or "None"]` and writes the hit with
  `fontString:SetText(customText)` (line 499). The map's value reaches `SetText` unchanged.
- `AuraContainerUtilDocumentation.lua:250`: the map's values are `stringView`, the same plain-string
  type as `StringUtilDocumentation.lua`'s text arguments. Nothing strips escapes from them.
- `SimpleFontStringAPIDocumentation.lua:664-672`: `SetText(text: cstring)`, and a font string renders
  a `|cffRRGGBB…|r` escape.

So an escape inside each map value colors only that word. The engine writes it per aura, in combat,
with no addon code running. This is the one real engine path, and it applies to that one piece only.
Whether the engine's options processing (`ProcessCustomAuraButtonDispelTypeTextOptions`,
C side) keeps the `|` bytes can only be seen in game: smoke item 130 checks it.

**The evidence for (a) and (b):**
- `AddDispelTypeTexture` accepts a Texture only (`Blizzard_CustomAuraButton.lua:85`,
  `RequireObjectType("Texture")`).
- It tints the texture from `customDispelColorMap[dispelName or "None"]` with
  `texture:SetVertexColor(color:GetRGBA())` (line 463). It shows or hides the texture per aura
  (`ShouldShowDispelTypeForAura`, 372–392).

Every stand-in is wired at dress time, before the button locks
(`docs/midnight-quirks.md`, "Aura buttons lock while auras are secret"). Nothing runs in combat.

**Files** (line numbers are on the tree after Tasks 1–11 and 13):
- Modify: `defaults/Profile.lua` — the `text` block gains five leaves, after
  `expiringBlink = false,` (line 228).
- Modify: `modules/Style_Text.lua`:
  - a header paragraph;
  - `EDGES` after `number` (60–62);
  - `buildDispelTints`, called from `build`;
  - `dressDispelTints`, called from `Text.Apply`;
  - `hex`, `wordPalette`, `dispelWord` and `paletteCurrent`, plus `dispelOptionsFor(piece, s)`, which
    replaces `dispelOptionsFor(piece)` (320–334);
  - `tintOptionsFor` and `dispelTints`, called from `Text.Bind`;
  - `BINDERS.dispel` and `PIECE_TEXT.dispel`;
  - `previewTints`, called from `Text.FillPreview`.
- Modify: `modules/TextTemplate.lua` — `TT.Compile`'s result gains `hasDispel` (413, 425–426).
- Modify: `settings/Text.lua`:
  - the header diagram;
  - `S_DISPEL`;
  - the `noDispel` and `unlessOn` predicates;
  - five rows between `animBounce` and `expiringColorOn`.
- Modify: `settings/GeneralSpells.lua` — the DISPEL COLORS header paragraph (39–45), the
  `DISPEL_ROWS` desc (333) and `renderDispel`'s line (340).
- Modify: `locales/enUS.lua` — two keys replaced (113, 117) and eleven appended.
- Modify: `docs/settings-panel.md` (19, 162–166, 420, 439–442, 454), `docs/schema.md` (160–161),
  `docs/ARCHITECTURE.md` (105–107 and Known Limitations) and `README.md` (81). Also the citations
  the docs suite reports.
- Test:
  - `tests/test_style_text.lua` (six cases appended);
  - `tests/test_pages_text.lua` (one appended);
  - `tests/test_texttemplate.lua` (the case "the name alone is one piece, and single", extended);
  - `tests/test_pages_general.lua` (the Dispel Colors case at 633, renamed and re-keyed);
  - `tests/test_render_coverage.lua` (the Text baseline carries a `$dispeltype$` piece and is applied
    before priming).

**Interfaces:**
- Consumes:
  - `Style.DispelColorMap(stored, fallback)` from Task 11. With no fallback its `None` entry is white
    and every entry has alpha 1; `None` is never drawn here, because `showWithoutDispelType` is false.
  - `Style.ProfileDispelColors()`, `NS.Compat.DispelStyle("PreserveAsset")`, `C.WHITE_TEXTURE`,
    `C.TEXT_DISPEL_TYPES` / `C.TEXT_DISPEL_LABELS` and `TT.ForDraw`.
- Produces:
  - Five `container.text.*` leaves, all under Text → Animation → Dispel type:

    | Leaf | Default |
    |---|---|
    | `dispelTypeColor` | `false` |
    | `dispelBackdrop` | `false` |
    | `dispelBackdropAlpha` | `0.35` |
    | `dispelEdge` | `false` |
    | `dispelEdgeSize` | `1` |

  - The regions `am.backdrop`, `am.edgeTop`, `am.edgeBottom`, `am.edgeLeft` and `am.edgeRight`: textures
    of `am.area`, each its own key so the style suites can see it.
  - `TT.Compile(...).hasDispel`.
  - No schema-version bump: the ordinary backfill adds the leaves.
  - The schema grows from 235 to **240** rows, and the Text page from 31 to **36**.

- [ ] **Step 1: Write the failing tests**

`tests/test_style_text.lua`, append:

```lua

-- ── color by dispel type (feedback #7) ────────────────────────────────────────────────────────

-- The default Magic color (C.DEFAULT_DISPEL_COLORS: 0.2, 0.6, 1) as a font-string escape.
local MAGIC_CODE = "|cff3399ff"

test("text style: Color the dispel type writes each word in its palette color inside the bracket text (feedback #7)", function()
    local NS = E()
    local frame = dressed(text({ template = "$spellname$[ <$dispeltype$>]", dispelTypeColor = true }), true)
    local opts = frame:__last("SetDispelTypeText")[2]
    local map = opts.customDispelTextMap
    -- red under: the words left plain (the escape inside the map's text is the one engine path that
    -- colors a font string by dispel type)
    assertEqual(map.Magic, " <" .. MAGIC_CODE .. NS.L["Magic"] .. "|r>")
    -- Enrage has no palette color: its word keeps the font color
    assertEqual(map.Enrage, " <" .. NS.L["Enrage"] .. ">")
    assertNil(map.None)
    assertFalse(opts.showWithoutDispelType)
    local off = dressed(text({ template = "$spellname$[ <$dispeltype$>]" }), true)
    assertEqual(off:__last("SetDispelTypeText")[2].customDispelTextMap.Magic, " <" .. NS.L["Magic"] .. ">", "off: plain")
end)

test("text style: a colored dispel map is built once per look, and a new palette color rebuilds it (feedback #7)", function()
    local NS = E()
    local c = text({ template = "$spellname$[ ($dispeltype$)]", dispelTypeColor = true })
    local first = dressed(c, true):__last("SetDispelTypeText")[2]
    assertTrue(dressed(c, true):__last("SetDispelTypeText")[2] == first, "one options table per look")
    local dc = NS.db.profile.dispelColors
    local old = dc.Curse
    dc.Curse = { r = 1, g = 0, b = 0, a = 1 }   -- a settings write stores a new table (Style.lua's memo note)
    local again = dressed(c, true):__last("SetDispelTypeText")[2]
    dc.Curse = old
    -- red under: the memo keyed by the bracket text alone (a new Curse color never reaches the line)
    assertEqual(again.customDispelTextMap.Curse, " (|cffff0000" .. NS.L["Curse"] .. "|r)")
end)

test("text style: the dispel backdrop fills the text area and is tinted through the engine, for a typed aura only (feedback #7)", function()
    local NS = E()
    local frame, am = dressed(text({ dispelBackdrop = true, dispelBackdropAlpha = 0.4 }), true)
    -- red under: no backdrop region
    assertTrue(am.backdrop ~= nil and am.backdrop.parent == am.area, "in the text area, under the chain")
    assertTrue(am.backdrop:__last("SetAllPoints")[1] == am.area)
    assertEqual(am.backdrop:__joined("SetTexture"), NS.Constants.WHITE_TEXTURE)
    assertEqual(am.backdrop:__joined("SetAlpha"), "0.4")
    local add = frame:__last("AddDispelTypeTexture")
    -- red under: no backdrop binding
    assertTrue(add ~= nil and add[1] == am.backdrop, "the backdrop is the engine's to tint")
    assertEqual(frame:__count("AddDispelTypeTexture"), 1, "no edge while it is off")
    local o = add[2]
    assertTrue(o.showWhenHarmful and o.showWhenHelpful, "buffs and debuffs, as the word")
    assertFalse(o.showAlways)
    assertFalse(o.showWithoutDispelType)
    assertTrue(o.customDispelColorMap == NS.Style.DispelColorMap(NS.db.profile.dispelColors), "the profile's palette")
    assertTrue(frame:__lastSeq("ClearDispelTypeTextures") < frame:__lastSeq("AddDispelTypeTexture"), "cleared first")
    am.backdrop:Show()   -- the engine showed it for a typed aura
    local off = dressed(text({}), true, frame)
    assertEqual(off:__count("AddDispelTypeTexture"), 1, "off by default: no second binding")
    -- red under: a dress leaving a switched-off backdrop as the engine last drew it (the Clear
    -- restores nothing)
    assertFalse(am.backdrop:IsShown())
end)

test("text style: the dispel edge is four strips of its thickness around the text area, each tinted through the engine (feedback #7)", function()
    local frame, am = dressed(text({ dispelEdge = true, dispelEdgeSize = 2 }), true)
    local adds = frame:__calls("AddDispelTypeTexture")
    -- red under: no edge
    assertEqual(#adds, 4, "one binding per strip")
    local want = {
        edgeTop = { "TOPLEFT", "TOPRIGHT", "SetHeight" }, edgeBottom = { "BOTTOMLEFT", "BOTTOMRIGHT", "SetHeight" },
        edgeLeft = { "TOPLEFT", "BOTTOMLEFT", "SetWidth" }, edgeRight = { "TOPRIGHT", "BOTTOMRIGHT", "SetWidth" },
    }
    local bound = {}
    for _, a in ipairs(adds) do bound[a[1]] = a[2] end
    for key, w in pairs(want) do
        local strip = am[key]
        assertTrue(strip ~= nil and strip.parent == am.area, key)
        local pts = strip:__calls("SetPoint")
        assertEqual(pts[1][1] .. "," .. pts[2][1], w[1] .. "," .. w[2], key)
        assertTrue(pts[1][2] == am.area and pts[2][2] == am.area, key .. " on the area's edge")
        assertEqual(strip:__joined(w[3]), "2", key)
        assertTrue(bound[strip] ~= nil and bound[strip] == adds[1][2], key .. " bound with the backdrop's options")
    end
end)

test("text style: a placeholder with a dispel type shows the backdrop and edge in its palette color; one without shows neither (feedback #7)", function()
    local NS = E()
    local m = NS.db.profile.dispelColors.Magic
    local magic = table.concat({ m.r, m.g, m.b, 1 }, ",")
    local _, am = filled({ dispelBackdrop = true, dispelEdge = true }, AURA)
    -- red under: FillPreview leaving the tints to an engine a placeholder does not have
    assertTrue(am.backdrop:IsShown())
    assertEqual(am.backdrop:__joined("SetVertexColor"), magic)
    for _, key in ipairs({ "edgeTop", "edgeBottom", "edgeLeft", "edgeRight" }) do
        assertTrue(am[key]:IsShown(), key)
        assertEqual(am[key]:__joined("SetVertexColor"), magic, key)
    end
    local _, typeless = filled({ dispelBackdrop = true, dispelEdge = true },
        { name = "Well Fed", icon = 1, remaining = 0, duration = 0, stacks = 0 })
    assertFalse(typeless.backdrop:IsShown(), "no type, no backdrop")
    assertFalse(typeless.edgeTop:IsShown(), "no type, no edge")
    local _, off = filled({}, AURA)
    assertFalse(off.backdrop:IsShown(), "off: nothing, even for a typed aura")
end)

test("text style: a placeholder's and the Preview line's dispel word take its palette color when the option is on (feedback #7)", function()
    local NS = E()
    local s = { template = "$spellname$[ ($dispeltype$)]", dispelTypeColor = true }
    local out = filled(s, AURA)
    -- red under: the preview fill ignoring the option (the live line colored, the placeholder not)
    assertEqual(out[2], " (" .. MAGIC_CODE .. NS.L["Magic"] .. "|r)")
    assertEqual(NS.Style.Text.PreviewLine(s, AURA), "Bloodlust (" .. MAGIC_CODE .. NS.L["Magic"] .. "|r)")
end)
```

`tests/test_pages_text.lua`, append:

```lua

-- ── color by dispel type (feedback #7) ────────────────────────────────────────────────────────

test("text page: Animation carries the three dispel-type options, all off, each dimmed until it can show (feedback #7)", function()
    local NS, _, P = textPage()
    local L = NS.L
    local D = NS.CONTAINER_TEMPLATE.text
    -- red under: any of the three on by default (owner, 2026-09-19: all opt-in, all off)
    assertFalse(D.dispelTypeColor)
    assertFalse(D.dispelBackdrop)
    assertFalse(D.dispelEdge)
    local ws = animationTab(NS, P)
    for _, key in ipairs({ "dispelTypeColor", "dispelBackdrop", "dispelBackdropAlpha", "dispelEdge", "dispelEdgeSize" }) do
        local row = NS.FindSchemaRow(P_ .. key)
        -- red under: no row
        assertTrue(row ~= nil and row.group == L["Animation"] and row.subgroup == L["Dispel type"], key)
        assertTrue(P.row(ws, P_ .. key) ~= nil, key .. " is drawn")
    end
    -- The default template has no $dispeltype$, so there is no word to color.
    assertTrue(P.row(ws, P_ .. "dispelTypeColor").disabled, "the word needs the token")
    assertTrue(P.row(ws, P_ .. "dispelBackdropAlpha").disabled, "the opacity waits for the backdrop")
    assertTrue(P.row(ws, P_ .. "dispelEdgeSize").disabled, "the thickness waits for the edge")
    NS.SetByPath(P_ .. "template", "$spellname$[ ($dispeltype$)]", 1)
    NS.SetByPath(P_ .. "dispelBackdrop", true, 1)
    NS.SetByPath(P_ .. "dispelEdge", true, 1)
    ws = animationTab(NS, P)
    for _, key in ipairs({ "dispelTypeColor", "dispelBackdropAlpha", "dispelEdgeSize" }) do
        -- red under: a predicate reading the wrong leaf
        assertFalse(P.row(ws, P_ .. key).disabled and true or false, key .. " is live")
    end
end)
```

`tests/test_texttemplate.lua`: in "template: the name alone is one piece, and single", after
`    assertFalse(r.hasDuration)`, add:

```lua
    -- red under: no hasDispel (the Text page dims Color the dispel type on it, feedback #7)
    assertFalse(r.hasDispel)
    assertTrue(TT.Compile("$spellname$[ ($dispeltype$)]").hasDispel)
```

`tests/test_pages_general.lua`, the case at line 633:
- Its name: `…under a line saying they drive bars only` → `…under a line saying they drive bars and text`.
- The comment
  `-- keep Blizzard's own dispel colors, so the palette drives bars only)` becomes the two lines
  `-- keep Blizzard's own dispel colors), or silent on the Text style's word, backdrop and edge` and
  `-- (feedback #7)`.
- The two quoted keys become:
  - `"One color per dispel type, shared by every container, for bars colored by dispel type and for a text line's dispel type word, backdrop or edge (Text -> Animation). An aura with no dispel type keeps a bar's own color and draws no backdrop or edge. An icon's dispel border keeps Blizzard's own colors."`
  - `"This dispel type's color for a bar's fill or background colored by dispel type, and for a text line's dispel type word, backdrop or edge when those are on. An icon's dispel border keeps Blizzard's own colors."`

`tests/test_render_coverage.lua` has two edits. Without them the new rows are walked on a template
with no `$dispeltype$`, so `dispelTypeColor` reaches nothing. Changing the template's shape in the
baseline alone rebuilds the engine, and the suite refuses a rebuild ("the engine was updated, not
rebuilt", measured).

1. `SAMPLES` and its comment become:

```lua
-- A free-text row has no list to pick from, so it names the value it is walked with: the Text
-- baseline's template (GATES below), with its bracket text changed and its shape kept (a new shape
-- builds a new chain of font strings, which a recorder swapped in by `adopt` would never see).
local SAMPLES = { ["container.text.template"] = "$spellname$[ y$stacks$][ <$dispeltype$>][ ~ $remainingduration$]" }
```

   and `GATES.text` with its comment becomes:

```lua
    -- Right, so Center (a multi-piece template lines up Left) still moves the chain; an icon, so
    -- its rows reach one; a $dispeltype$ piece, so coloring its word has a word to color (feedback #7).
    text = { icon = "LEFT", iconBorderShow = true, expiringColorOn = true, justifyH = "RIGHT",
        template = "$spellname$[ x$stacks$][ ($dispeltype$)][ - $remainingduration$]" },
```

2. In `gaps`, between the `local baseline = …` line and `prime(k)`, insert:

```lua
    -- Primed on the baseline, applied once first: a baseline template of another shape than the
    -- stored one rebuilds the engine (Style.StructureKey), which prime's apply would refuse.
    k.c[page] = NS.Database.DeepCopy(baseline)
    NS.ContainerManager.RequestApply(k.c.id)
    NS.ContainerManager.FlushPending()
```

- [ ] **Step 2: Run them and see them fail**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua 2>&1 | grep -A2 FAIL`

Expected (measured): `1087 passed, 9 failed, 0 skipped, 1096 total`. The failures:
- `template: the name alone is one piece, and single`: `assertTrue failed` (no `hasDispel`).
- `Color the dispel type writes each word…`: `expected  <|cff3399ffMagic|r>, got  <Magic>`.
- `a colored dispel map is built once per look…`: `expected  (|cffff0000Curse|r), got  (Curse)`.
- `the dispel backdrop fills the text area…`: `in the text area, under the chain`.
- `the dispel edge is four strips…`: `one binding per strip (expected 4, got 0)`.
- `a placeholder with a dispel type shows the backdrop…`: `attempt to index field 'backdrop' (a nil value)`.
- `a placeholder's and the Preview line's dispel word…`: `expected  (|cff3399ffMagic|r), got  (Magic)`.
- `general → dispel colors: … drive bars and text`: `assertTrue failed` (the old line is drawn).
- `text page: Animation carries the three dispel-type options…`: `dispelTypeColor` (no row).

The coverage case stays green at this point: it is the guard that walks the five new rows once
they exist.

- [ ] **Step 3: Implement**

`defaults/Profile.lua`, in the `text` block, after `        expiringBlink = false,` add:

```lua

        -- Color by dispel type (feedback #7): each opt-in, all off (owner, 2026-09-19).
        dispelTypeColor = false,
        dispelBackdrop = false, dispelBackdropAlpha = 0.35,
        dispelEdge = false, dispelEdgeSize = 1,
```

`modules/TextTemplate.lua`, `TT.Compile`:
- Its `@return` line becomes
  `--- @return table  { ok = true, pieces, single, shape, hasDuration, hasDispel } or { ok = false, err }`.
- `            hasDuration = hasKind(pieces, "duration") }` becomes
  `            hasDuration = hasKind(pieces, "duration"), hasDispel = hasKind(pieces, "dispel") }`.

`modules/Style_Text.lua`:

1. In the header, directly above `-- ANIMATIONS ARE SET UP AT DRESS TIME ONLY.`, insert:

```lua
-- COLOR BY DISPEL TYPE (feedback #7). No engine binding colors a font string by the aura's dispel type,
-- and no addon code may read the type or touch a button's objects in combat. Three opt-in stand-ins,
-- each wired at dress time: the $dispeltype$ word colored by a |c escape written into the engine's own
-- text map (dispelOptionsFor), and a backdrop and a four-strip edge in the text area, textures the
-- engine tints and shows per aura (AddDispelTypeTexture, dispelTints).
--
```

2. After `local function number(v, default) … end`, add:

```lua

-- The dispel edge's four strips (feedback #7): each region key, the two corners of the text area it
-- runs between, and the setter its thickness goes through.
local EDGES = {
    { "edgeTop", "TOPLEFT", "TOPRIGHT", "SetHeight" },
    { "edgeBottom", "BOTTOMLEFT", "BOTTOMRIGHT", "SetHeight" },
    { "edgeLeft", "TOPLEFT", "BOTTOMLEFT", "SetWidth" },
    { "edgeRight", "TOPRIGHT", "BOTTOMRIGHT", "SetWidth" },
}
```

3. Directly above `--- Build the regions once (Style.RegionsFor).`, add:

```lua
--- The dispel backdrop and edge (feedback #7): textures of the text area, so they sit under the chain
--- (a child frame) and move with the loops. Each is its own key on `am`: a region never hides in a
--- list the style suites cannot see.
local function buildDispelTints(am)
    am.backdrop = am.area:CreateTexture(nil, "BACKGROUND")
    am.backdrop:SetAllPoints(am.area)
    for _, e in ipairs(EDGES) do
        local strip = am.area:CreateTexture(nil, "BORDER")
        strip:SetPoint(e[2], am.area, e[2])
        strip:SetPoint(e[3], am.area, e[3])
        am[e[1]] = strip
    end
end

```

   In `build`, after `    am.area:SetClipsChildren(true)`, add `    buildDispelTints(am)`.

4. Directly above `-- The loops, each the group a dress plays for its \`anim\` value.`, add:

```lua
--- The dispel backdrop and edge (feedback #7): white, the backdrop at its opacity, each strip its
--- thickness, and every one HIDDEN. A live one is shown and tinted by the engine for an aura with a
--- dispel type (Text.Bind); a placeholder's by Text.FillPreview. Hidden on every dress, because the
--- engine's Clear restores nothing: a switched-off tint would stay as the engine last drew it.
local function dressDispelTints(am, s)
    am.backdrop:SetTexture(C.WHITE_TEXTURE)
    am.backdrop:SetAlpha(number(s.dispelBackdropAlpha, D.dispelBackdropAlpha))
    am.backdrop:Hide()
    local size = number(s.dispelEdgeSize, D.dispelEdgeSize)
    for _, e in ipairs(EDGES) do
        local strip = am[e[1]]
        strip:SetTexture(C.WHITE_TEXTURE)
        strip[e[4]](strip, size)
        strip:Hide()
    end
end

```

5. Replace `dispelOptionsFor` and its three-line doc comment with:

```lua
--- One color channel as two hex digits.
local function hex(v)
    return ("%02x"):format(math.floor(math.max(0, math.min(1, tonumber(v) or 1)) * 255 + 0.5))
end

--- The palette `s` colors the dispel type word from: the profile's, when Color the dispel type is on
--- (feedback #7), else nil.
local function wordPalette(s)
    return s and s.dispelTypeColor and Style.ProfileDispelColors() or nil
end

--- Dispel type `t`'s word inside a piece's bracket text, in `palette`'s color for `t` when it has one:
--- a |cffRRGGBB escape the font string renders, closed before the bracket text, which keeps the font
--- color. A type the palette lacks (Enrage) keeps the font color.
local function dispelWord(piece, t, palette)
    local word = L[C.TEXT_DISPEL_LABELS[t]]
    local c = palette and palette[t]
    if type(c) == "table" then word = "|cff" .. hex(c.r) .. hex(c.g) .. hex(c.b) .. word .. "|r" end
    return piece.pre .. word .. piece.post
end

--- Whether a memoized dispel entry was built from exactly the palette leaves `palette` holds now (a
--- settings write stores a new leaf table, modules/Style.lua's memo note).
local function paletteCurrent(entry, palette)
    for _, t in ipairs(C.TEXT_DISPEL_TYPES) do
        if (palette and palette[t] or nil) ~= entry.src[t] then return false end
    end
    return true
end

--- SetDispelTypeText's options for a dispel piece: every type in C.TEXT_DISPEL_TYPES mapped to its
--- localized name inside the piece's bracket text (colored when `s` asks, dispelWord), on harmful and
--- helpful auras alike, nothing for an aura with no type. The map's values are the engine's own text
--- (`stringView`, written by fontString:SetText), so the escape is the one path that colors text by
--- dispel type in combat. Built once per bracket text, coloring and palette.
local function dispelOptionsFor(piece, s)
    local palette = wordPalette(s)
    local key = (palette and "c" or "p") .. piece.pre .. "\0" .. piece.post
    local entry = dispelOptions[key]
    if not (entry and paletteCurrent(entry, palette)) then
        local map, src = {}, {}
        for _, t in ipairs(C.TEXT_DISPEL_TYPES) do
            map[t] = dispelWord(piece, t, palette)
            src[t] = palette and palette[t] or nil
        end
        entry = { src = src, opts = { showWhenHarmful = true, showWhenHelpful = true,
            showWithoutDispelType = false, customDispelTextMap = map } }
        dispelOptions[key] = entry
    end
    return entry.opts
end

--- AddDispelTypeTexture's options for the backdrop and edge (feedback #7): shown for a buff or a debuff
--- WITH a dispel type (as the word is), our white texture kept (PreserveAsset) and tinted from the
--- profile's palette at full alpha (the backdrop's opacity is its own SetAlpha). Built once per map.
local tintOptions
local function tintOptionsFor()
    local map = Style.DispelColorMap(Style.ProfileDispelColors())
    if not (tintOptions and tintOptions.customDispelColorMap == map) then
        tintOptions = { showWhenHarmful = true, showWhenHelpful = true, showWithoutDispelType = false,
            style = NS.Compat.DispelStyle("PreserveAsset"), customDispelColorMap = map }
    end
    return tintOptions
end

--- Hand the backdrop and each edge strip that `s` turns on to the engine to tint (Style.Bind). The
--- additive list was cleared at the head of the dress (Style.ClearAdditiveBindings).
local function dispelTints(frame, am, s)
    if not (s.dispelBackdrop or s.dispelEdge) then return end
    local opts = tintOptionsFor()
    if s.dispelBackdrop then Style.Bind(frame, "AddDispelTypeTexture", am.backdrop, opts) end
    if not s.dispelEdge then return end
    for _, e in ipairs(EDGES) do Style.Bind(frame, "AddDispelTypeTexture", am[e[1]], opts) end
end
```

6. `BINDERS.dispel` becomes
   `    dispel = function(frame, fs, piece, s) Style.Bind(frame, "SetDispelTypeText", fs, dispelOptionsFor(piece, s)) end,`.
   In `Text.Bind`, between the pieces loop's `end` and `    Style.ApplyBehavior(frame, cfg)`, add
   `    dispelTints(frame, am, s)`.
7. In `Text.Apply`, after `    layoutChain(am, s, compiled, h)`, add `    dressDispelTints(am, s)`. The
   raw calls stay before the bindings, as `dressPieces`'s do; `applyLoops` stays last.
8. `PIECE_TEXT.dispel` becomes:

```lua
    dispel = function(piece, aura, s)
        if not (aura.dispel and C.TEXT_DISPEL_LABELS[aura.dispel]) then return "" end
        return dispelWord(piece, aura.dispel, wordPalette(s))
    end,
```

9. Directly above `--- Fill a PREVIEW element with placeholder values`, add:

```lua
--- A placeholder's backdrop and edge (feedback #7): shown in the palette color of its aura's dispel
--- type, as the engine tints a live one; left hidden (dressDispelTints) for an aura with no type or
--- no palette color.
local function previewTints(am, aura, s)
    local dc = aura.dispel and Style.ProfileDispelColors()
    local c = dc and dc[aura.dispel]
    if type(c) ~= "table" then return end
    local r, g, b = c.r or 1, c.g or 1, c.b or 1
    if s.dispelBackdrop then
        am.backdrop:SetVertexColor(r, g, b, 1)
        am.backdrop:Show()
    end
    if not s.dispelEdge then return end
    for _, e in ipairs(EDGES) do
        am[e[1]]:SetVertexColor(r, g, b, 1)
        am[e[1]]:Show()
    end
end

```

   and in `Text.FillPreview`, after the pieces loop's `end`, add `    previewTints(am, aura, s)`.

`settings/Text.lua`:
1. In the header diagram, after the General entry's last line (`--               sheet; then Placement and the centering note`), add:

```lua
--     Animation Loop, then Dispel type (feedback #7: the word's color, a backdrop, an edge, each
--               opt-in and off), then Running out and its note
```

2. `local S_PLACEMENT = L["Placement"]` → `local S_PLACEMENT, S_DISPEL = L["Placement"], L["Dispel type"]`.
3. After `noDuration`, add:

```lua

--- A `disabledIf` predicate: Color the dispel type needs a $dispeltype$ token to color (feedback #7).
local function noDispel()
    return not TT.ForDraw(textBlock().template).hasDispel
end

--- A `disabledIf` predicate: the row is dimmed while the selected container's toggle `key` is off.
local function unlessOn(key)
    return function() return not textBlock()[key] end
end
```

4. In the Animation `RegisterSchemaRows`, between the `animBounce` row and the `expiringColorOn` row,
   insert the five rows below. They go before Running out, so the Animation tab's `afterGroup` note,
   which is about Running out, still sits under Running out.

```lua
    -- Color by dispel type (feedback #7): three opt-in stand-ins, all off, since no engine binding
    -- colors a whole line by the aura's type (modules/Style_Text.lua's header).
    { path = P .. "dispelTypeColor", page = PAGE, group = G_ANIM, subgroup = S_DISPEL, type = "bool",
      startsLine = true, disabledIf = noDispel,
      label = L["Color the dispel type"],
      desc = L["Write $dispeltype$ in its type's color from General -> Dispel Colors. The rest of the line keeps the font color. Needs $dispeltype$ in the template."] },
    { path = P .. "dispelBackdrop", page = PAGE, group = G_ANIM, subgroup = S_DISPEL, type = "bool",
      startsLine = true, label = L["Backdrop in the dispel color"],
      desc = L["Fill the line's box, behind the text, with the aura's dispel type color from General -> Dispel Colors. An aura with no dispel type gets none."] },
    { path = P .. "dispelBackdropAlpha", page = PAGE, group = G_ANIM, subgroup = S_DISPEL, type = "number",
      min = 0.05, max = 1, step = 0.05, isPercent = true, disabledIf = unlessOn("dispelBackdrop"),
      label = L["Backdrop opacity"], desc = L["How strongly the backdrop shows behind the text."] },
    { path = P .. "dispelEdge", page = PAGE, group = G_ANIM, subgroup = S_DISPEL, type = "bool",
      startsLine = true, label = L["Edge in the dispel color"],
      desc = L["Outline the line's box in the aura's dispel type color from General -> Dispel Colors. An aura with no dispel type gets none."] },
    { path = P .. "dispelEdgeSize", page = PAGE, group = G_ANIM, subgroup = S_DISPEL, type = "number",
      min = 1, max = 4, step = 1, disabledIf = unlessOn("dispelEdge"),
      label = L["Edge thickness (px)"], desc = L["How thick the edge is."] },
```

`settings/GeneralSpells.lua`:
1. In the DISPEL COLORS header paragraph, replace these two lines:
   - `-- no \`effect\`, so a write re-applies every container. Only bars read them, a bar's fill or background`
   - `-- colored by dispel type; an icon's dispel border keeps Blizzard's own colored art (modules/Style_Icons.lua,`

   with these three:
   - `-- no \`effect\`, so a write re-applies every container. Bars and text read them: a bar's fill or`
   - `-- background colored by dispel type, and a text line's dispel type word, backdrop and edge (feedback`
   - `-- #7, modules/Style_Text.lua); an icon's dispel border keeps Blizzard's own colored art (modules/Style_Icons.lua,`
2. The `DISPEL_ROWS` desc and `renderDispel`'s line take the two new strings from Step 1's
   `test_pages_general.lua` edit.

`locales/enUS.lua`:
- Replace the two lines keyed by the old Dispel Colors row desc and tab line with the new strings
  (key == value).
- Append, key == value:
  - `Dispel type`
  - `Color the dispel type`
  - `Write $dispeltype$ in its type's color from General -> Dispel Colors. The rest of the line keeps the font color. Needs $dispeltype$ in the template.`
  - `Backdrop in the dispel color`
  - `Fill the line's box, behind the text, with the aura's dispel type color from General -> Dispel Colors. An aura with no dispel type gets none.`
  - `Backdrop opacity`
  - `How strongly the backdrop shows behind the text.`
  - `Edge in the dispel color`
  - `Outline the line's box in the aura's dispel type color from General -> Dispel Colors. An aura with no dispel type gets none.`
  - `Edge thickness (px)`
  - `How thick the edge is.`

Docs:

`docs/settings-panel.md`:
- Line 19, the Text row's last cell: `…its loop and running-out blink |` → `…its loop and running-out blink,
  and its opt-in dispel type colors |`.
- Lines 162–166, the Dispel Colors paragraph, from `` `.Curse`, `.Disease`, `.Poison`, `.Bleed`: `` to
  `the tab line and each row's tooltip say so.`, become:

```markdown
`.Curse`, `.Disease`, `.Poison`, `.Bleed`: the fill or background of a bar colored by dispel type, and
a Text line's dispel type word, backdrop and edge when those are on (Text → Animation → Dispel type,
feedback #7). An aura with no dispel type keeps a bar's own color and draws no text backdrop or edge,
so there is no None swatch. Icons do not read them: an icon's dispel border keeps Blizzard's own
colored art (owner, 2026-09-13), and the tab line and each row's tooltip say so.
```

- `### Text (31 rows,` → `### Text (36 rows,`.
- After the paragraph ending `…\`animBounce\` unless` / `Bounce).`, add:

```markdown

**Dispel type** (Animation, feedback #7) holds three opt-in stand-ins for "color the text by dispel
type", all off by default, since no engine binding colors a font string by the aura's type
(`docs/ARCHITECTURE.md` → Known Limitations). `dispelTypeColor` writes the `$dispeltype$` word in its
palette color: each value of the engine's `customDispelTextMap` carries a `|cffRRGGBB…|r` escape
around the word, the bracket text keeping the font color (dimmed without a `$dispeltype$` token).
`dispelBackdrop` fills the text area behind the chain with a white texture the engine tints and shows
per aura (`AddDispelTypeTexture`, `PreserveAsset`, the profile's palette), at `dispelBackdropAlpha`;
`dispelEdge` draws four strips `dispelEdgeSize` px thick around the text area the same way. The
backdrop and the edge show only for an aura with a dispel type (buff or debuff), in the palette's
color for it; a type the palette lacks (Enrage) takes Blizzard's own color. The opacity and the
thickness are dimmed while their toggle is off. The preview draws all three from the placeholder's
own type.
```

- The table's Animation row gains `Dispel type: \`dispelTypeColor\`, \`dispelBackdrop\`,
  \`dispelBackdropAlpha\`, \`dispelEdge\`, \`dispelEdgeSize\`.` between its Loop and Running out parts.

`docs/schema.md`, the `### \`text\`` paragraph's tail, from `` `expiringBlink` (false). An existing
container `` to `schema-version bump.`, becomes:

```markdown
(false), `expiringThreshold` (5), `expiringColor`, `expiringBlink` (false); by dispel type (feedback
#7, each opt-in) — `dispelTypeColor` (false: the `$dispeltype$` word in the profile's `dispelColors`),
`dispelBackdrop` (false), `dispelBackdropAlpha` (0.35), `dispelEdge` (false), `dispelEdgeSize` (1 px).
An existing container gains the block, and these leaves, by the ordinary backfill; there is no
schema-version bump.
```

`docs/ARCHITECTURE.md`:
- Lines 105–107 become the lines below. This also fixes Task 11's leftover General 19 / six / Bars 71;
  the total 235 held then only because Task 11's −1 and +1 cancelled.

```markdown
`NS.Schema` holds **240** rows across seven pages: General 18 (its Dispel Colors tab's five and its
Spell Categories tab's three `enchantSlots` rows among them), Containers 5 (`N-1`, batch 7 — split
out of General's own tab), Filters 41, Layout 26, Bars 72, Icons 42 and Text 36.
```

- In Known Limitations, before `- **A Text token can be used once,`, add:

```markdown
- **A Text line cannot be colored by its aura's dispel type.** No engine binding colors a font string by
  dispel type (`SetDispelTypeText`, `SetSpellName`, `SetApplicationCount` take no color;
  `SetDurationText`'s color curve runs over time), the dispel-keyed color map exists only on
  `AddDispelTypeTexture`, which takes a Texture, and addon code can neither read the type nor touch a
  button in combat. The Text page offers three opt-in stand-ins instead (Animation → Dispel type,
  feedback #7): the `$dispeltype$` word colored by a `|c` escape in the engine's own text map, and a
  backdrop and an edge the engine tints (`modules/Style_Text.lua`).
```

`README.md`, line 81, `can carry the aura's icon, pulse, blink or bounce, and blink its time in the
last seconds. A new`, becomes the three lines:

```markdown
can carry the aura's icon, pulse, blink or bounce, and blink its time in the last seconds. Its
Animation tab can also show the dispel type in color: the `$dispeltype$` word in its type's color, a
tinted backdrop behind the line or a tinted edge around it, each off until you turn it on. A new
```

- [ ] **Step 4: Run them and see them pass**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua 2>&1 | grep -A4 FAIL`

Expected: every case above passes, including `coverage: every Text row reaches a drawn region…`, which
now walks the five new rows on both sides. One case stays red: the docs case
`every file:line citation sits within 3 lines…`. Measured, it reports
`docs/ARCHITECTURE.md` and `docs/schema.md` citing `defaults/Profile.lua:235` (`STARTER_CONTAINERS`
moved down by five lines). Pipe the run into `/tmp/citefix.py`; it re-points both to `:240`. Run again:
`1096 passed, 0 failed, 0 skipped, 1096 total`, which is **+7 cases** (1089 before).

- [ ] **Step 5: Checkpoint — the green gate and complexity**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua && /home/tushar/.claude/wow-addon/bin/ka0s-bounded luacheck . && /home/tushar/.claude/wow-addon/bin/ka0s-bounded lizard -l lua -x "./libs/*" -x "./tests/_kit/*" -C 15 -w .`

Expected (measured):
- 0 failed.
- `0 warnings / 0 errors in 105 files`.
- lizard prints nothing: the largest new function, `dispelOptionsFor`, stays well under 15.

- [ ] **Step 6: Update the Status ledger row 12 and commit the plan with the task's commit**

Update the plan file:
- Row 12's Task cell → `#7b — text by dispel type: the colored word, a backdrop, an edge (opt-in, off)`.
- Row 12's Status → `done`, with the SHA.
- Row 12's Notes → `owner chose all three (a, b, c), 2026-09-19; the word's escape is checked in game (T item 130)`.
- Resume-guide point 5: drop the Task 12 stop point.
- The "Current position" line → the next row that is not `done`.

Commit this task's changes with the plan file:
`T12: text by dispel type — the colored word, a tinted backdrop and edge, each opt-in (feedback #7)`.

### Task 13: #9 — right-click the handle's "?" → the Containers page, that container selected

**Files:**
- Modify: `modules/Anchors.lua:320-324` (`openSettings`, shared by the strip's and the help mark's `OnClick`)
- Modify: `README.md:39-40`, `docs/smoke-tests.md:58` (item 15)
- Test: `tests/test_anchors.lua` (cases at 375 and 811 edited; two appended)

**Interfaces:**
- Consumes: `NS.OpenOptionsPage(pageKey)` (settings/OptionsSetup.lua: refuses under lockdown with
  options-ui-§2's gray line, else `Settings.OpenToCategory` on the page's own category, recorded by
  `NS.RegisterOptionsPage`); `NS.RefreshOptionsPanel()`; `NS.State.SetActiveContainer(id)`; Task 3's
  band picker (`ctx.__bannerWidget`), which re-reads the selection on every render.
- Produces: right-click on the strip or its "?" opens the **Containers** page with that container
  selected; under lockdown nothing changes but the gray line. Left-click and drag are unchanged (the
  help mark registers `RightButtonUp` only; the strip's `OnClick` ignores any other button).

- [ ] **Step 1: Write the failing tests**

`tests/test_anchors.lua`:

1. In "handle: the help mark carries the tooltip and right-click opens the settings on this container"
   (375), replace its last six lines (`    local opened = 0` … `    assertEqual(NS.State.activeContainerId, 2)`) with:

```lua
    local opened = {}
    NS.OpenOptionsPage = function(key)
        local n = #opened
        opened[n + 1] = key
    end
    NS.State.SetActiveContainer(1)
    h.help:__fire("OnClick", "RightButton")
    -- red under: the right-click opening the main panel, not the Containers page (feedback #9)
    assertEqual(table.concat(opened, ","), "containers")
    assertEqual(NS.State.activeContainerId, 2)
```

2. In "handle: a left click on the strip opens nothing; a right click opens this container's settings"
   (811), `    NS.OpenOptionsPanel = function() opened = opened + 1 end` →
   `    NS.OpenOptionsPage = function() opened = opened + 1 end`.

3. Append:

```lua

-- ── right-click the "?" → the Containers page (feedback #9) ───────────────────────────────────

test("handle: a right-click on the ? opens the Containers page with this container selected in its band (feedback #9)", function()
    local opened = {}
    local NS, mocks = fresh({ before = function(m)
        m.Settings.OpenToCategory = function(id)
            local n = #opened
            opened[n + 1] = id
        end
    end })
    local P = dofile("tests/page_helpers.lua")(NS, mocks)
    P.show("Containers")                          -- built once, on container 1
    local inst = NS.ContainerManager.instances[2]
    local h = recordedHandle(mocks, NS, inst)
    h.help:__fire("OnClick", "RightButton")
    -- red under: the click reaching the main panel's open (no category switch at all)
    assertEqual(#opened, 1, "one category switch")
    assertEqual(NS.State.activeContainerId, 2)
    P.show("Containers")
    -- red under: the Containers page opening on the container it was last drawn for
    assertEqual(NS.Helpers.__pageCtx.containers.__bannerWidget.value, 2, "the band's picker names container 2")
end)

test("handle: under combat lockdown the right-click is refused in gray and selects nothing (feedback #9)", function()
    local opened = 0
    local NS, mocks = fresh({ before = function(m)
        m.Settings.OpenToCategory = function() opened = opened + 1 end
    end })
    local inst = NS.ContainerManager.instances[2]
    local h = recordedHandle(mocks, NS, inst)
    local lines = {}
    rawset(mocks.DEFAULT_CHAT_FRAME, "AddMessage", function(_, msg)
        local n = #lines
        lines[n + 1] = tostring(msg)
    end)
    NS.State.SetActiveContainer(1)
    mocks.__lockdown = true
    h.help:__fire("OnClick", "RightButton")
    mocks.__lockdown = false
    -- red under: the category switch called under lockdown (it taints the panel for the session)
    assertEqual(opened, 0)
    -- red under: the selection moved by a click that opened nothing
    assertEqual(NS.State.activeContainerId, 1)
    assertTrue(table.concat(lines, "\n"):find("cannot open settings during combat", 1, true) ~= nil, table.concat(lines, " | "))
end)
```

- [ ] **Step 2: Run them and see them fail**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua 2>&1 | grep -A3 -E "feedback #9|help mark carries the tooltip|a left click on the strip"`
Expected: FAIL — `expected containers, got ` (the old handler calls `NS.OpenOptionsPanel`); the strip
case `expected 1, got 0`; "the band's picker names container 2 (expected 2, got 1)" (no refresh, and
the main panel); the lockdown case `expected 1, got 2` (the old handler selects before the refusal).

- [ ] **Step 3: Implement**

`modules/Anchors.lua`, replace

```lua
--- Right-click: the settings, on this container.
local function openSettings(container)
    if NS.State then NS.State.SetActiveContainer(container.id) end
    if NS.OpenOptionsPanel then NS.OpenOptionsPanel() end
end
```

with

```lua
--- Right-click (the strip or its "?"): the Containers page, with THIS container selected in its band
--- (feedback #9). Under combat lockdown the open is refused with options-ui-§2's gray line, and the
--- selection is left where it was: a refused click moves nothing. NS.OpenOptionsPage is the one
--- panel-open seam that carries the refusal; the panels are redrawn first, so a Containers page built
--- earlier shows the new subject when it opens.
local function openSettings(container)
    if not InCombatLockdown() then
        if NS.State then NS.State.SetActiveContainer(container.id) end
        if NS.RefreshOptionsPanel then NS.RefreshOptionsPanel() end
    end
    if NS.OpenOptionsPage then NS.OpenOptionsPage("containers") end
end
```

`README.md:39-40`: `Right-clicking a handle` / `opens the settings with that container already selected.` →
`Right-clicking a handle` / `(or its **?**) opens the Containers page with that container already selected.`

`docs/smoke-tests.md`, item 15's last sentence `Right-click a handle → the settings open with that container selected.` becomes:

```markdown
    the help mark moves it too. Right-click a handle, then its **?** → each time the settings open on
    the **Containers** page with that container selected in the band's picker (feedback #9); in combat
    the right-click prints the gray "cannot open settings during combat" line and changes nothing.
```

- [ ] **Step 4: Run them and see them pass**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua 2>&1 | grep -A3 -E "feedback #9|help mark carries the tooltip|a left click on the strip|FAIL"`
Expected: all PASS; no citation moves (none cites `modules/Anchors.lua` past line 320 by number).

- [ ] **Step 5: Checkpoint — the green gate**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua && /home/tushar/.claude/wow-addon/bin/ka0s-bounded luacheck .`
Expected: 0 failed; `0 warnings / 0 errors`.

- [ ] **Step 6: Update the Status ledger row for this task (status, commit SHAs, repo) and the resume guide's "Current position" line; commit the plan file with the task's commit**

Row 13 → `done` with the SHA. Current position → "Next: Task 14 — not started (LibKa0s); Tasks 1–11
and 13 done; Task 12 done." Commit:
`T13: right-clicking a handle opens the Containers page on that container (feedback #9)`, with this plan file.

---

### Task 14: #4a — LibKa0s v1.45.0: `shownWhen` switched sections (STOP before the tag and any push)

**Repo:** `/mnt/d/Profile/Users/Tushar/Documents/GIT/LibKa0s`, on `master` (clean, at 30ed9c2, tag
v1.44.0 on 7ae5b3b). Its own CLAUDE.md and `docs/releasing.md` govern this task (library-stack-§7).
Its gate, from **that** repo's root: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua`
and `/home/tushar/.claude/wow-addon/bin/ka0s-bounded luacheck .` (0/0; `.luacheckrc` excludes only
`tests/_kit/`), and lizard over the payload
(`/home/tushar/.claude/wow-addon/bin/ka0s-bounded lizard -l lua -x "./tests/_kit/*" -C 15 -w LibKa0s`).

**Files (all under the LibKa0s repo):**
- Modify: `LibKa0s/OptionsWidgets.lua` — `WIDGETS_MINOR` (line 35) 21 → 22; four locals above `--- The flow engine's loop, under the disable flag RenderRows holds for it.` (line 2689); `flowRows` (2690–2724)
- Create: `tests/test_options_switched.lua` — its own suite (`tests/test_options_widgets.lua` is over layout-§1's cap, issue #33)
- Modify: `tests/run.lua:68` (declare the suite after `test_options_idlist_remove`)
- Create: `docs/api/Options/version-21.22.1.7.3-docs.md`; modify `docs/api/Options/version-21.21.1.7.3-docs.md` (Superseded) and `docs/api/README.md` (a row); generate `docs/api/Options/members-21.22.1.7.3.json`
- Modify: `CHANGELOG.md` (a `## v1.45.0` block), `docs/releasing.md` (line 7's semver, line 201's provenance template, a "Where v1.45.0 stands" paragraph after the v1.44.0 one, line 395), `README.md` (line 3's standards pointer; the `As of **v1.44.0**` MODULES paragraph, lines 202–207), `CLAUDE.md:3` (standards pointer), `docs/test-cases.md` (regenerated)

**Interfaces:**
- Consumes: `flowRows`' existing locals (`read`, `readKey`, `startGroup`, `startSubgroup`, `drawRow`, `drawWide`, `endGroup`, `flushRow`), `O.RefreshPanel(ctx, structural)`.
- Produces (D-4): a row field `shownWhen = { path = <selector path>, equals = <value> | { <value>, … } }`;
  `RenderRows` drops a row whose selector holds another value (heading included; `afterGroup` fires
  after the last **drawn** row); for each drawn row whose `path` is a selector, a refresher that asks
  for one deferred `O.RefreshPanel(ctx, true)` when the value changes. Absent: unchanged.
  `LibStub("LibKa0s-Options-1.0").MODULES.OptionsWidgets == 22`; the Options version key is
  **21.22.1.7.3**; LibKa0s **v1.45.0**; the kit stays at revision 23.

- [ ] **Step 1: Write the failing suite**

Create `tests/test_options_switched.lua` (CRLF):

```lua
-- tests/test_options_switched.lua — LibKa0s-Options-1.0's switched sections (OptionsWidgets minor
-- 22): a row carrying `shownWhen = { path, equals }` is drawn only while its selector holds that
-- value (or one of a list), its subsection heading with it, and the page re-renders once, on the next
-- frame, when the selector changes; a row list with no `shownWhen` renders exactly as before.
--
-- Its own suite rather than more cases in tests/test_options_widgets.lua, which is over layout-§1's
-- cap and tracked by issue #33 (CLAUDE.md, "Files over the 1500-line cap"): new cases on a seam of
-- their own go to a file of their own, as v1.44.0's removeStyle cases did.

local T = _G.LK_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local Fixture = dofile("tests/fixture_options.lua")
local mocks = T.mocks

local panelSeq = 0

--- A selector and three switched subsections, the Layout -> Anchor shape: A for "a", B for "b",
--- C for "b" or "c". `extra` rows are appended as given.
local function anchorRows(extra)
  local rows = {
    { path = "mode", group = "Anchor", type = "string", label = "Attach to",
      values = { a = "A", b = "B", c = "C" }, sorting = { "a", "b", "c" } },
    { path = "a1", group = "Anchor", subgroup = "Section A", type = "bool", label = "A one",
      shownWhen = { path = "mode", equals = "a" } },
    { path = "a2", group = "Anchor", subgroup = "Section A", type = "bool", label = "A two",
      shownWhen = { path = "mode", equals = "a" } },
    { path = "b1", group = "Anchor", subgroup = "Section B", type = "bool", label = "B one",
      shownWhen = { path = "mode", equals = "b" } },
    { path = "c1", group = "Anchor", subgroup = "Section C", type = "bool", label = "C one",
      shownWhen = { path = "mode", equals = { "b", "c" } } },
  }
  for _, row in ipairs(extra or {}) do
    local n = #rows
    rows[n + 1] = row
  end
  return rows
end

--- A host and a throwaway page, its store holding `mode`.
local function bench(mode)
  local O, rec = Fixture.new()
  panelSeq = panelSeq + 1
  local ctx = O.CreatePanel("SwitchedBench" .. panelSeq, "Bench " .. panelSeq, {})
  rec.store.mode = mode
  return O, rec, ctx
end

--- The labels and heading texts one render drew, in order.
local function drawn(O, ctx)
  local out = {}
  for _, w in ipairs(Fixture.flatten(O.EnsureScroll(ctx))) do
    local t = w.labelText or (w.type == "Heading" and w.text) or nil
    if t then
      local n = #out
      out[n + 1] = t
    end
  end
  return table.concat(out, ",")
end

test("switched: only the subsection the selector names is drawn, its heading with it", function()
  local O, _, ctx = bench("a")
  O.RenderRows(ctx, anchorRows())
  -- red under: flowRows ignoring shownWhen (every section drawn), or skipping the rows but still
  -- emitting the hidden sections' headings (startSubgroup runs before the skip)
  assertEqual(drawn(O, ctx), "Anchor,Attach to,Section A,A one,A two")
end)

test("switched: equals may list several values; the row shows for any of them", function()
  local O, _, ctx = bench("c")
  O.RenderRows(ctx, anchorRows())
  assertEqual(drawn(O, ctx), "Anchor,Attach to,Section C,C one")
  O, _, ctx = bench("b")
  O.RenderRows(ctx, anchorRows())
  -- red under: a list compared as a whole (a table never equals the stored string)
  assertEqual(drawn(O, ctx), "Anchor,Attach to,Section B,B one,Section C,C one")
end)

test("switched: a group's afterGroup hook fires after its last DRAWN row, once", function()
  local O, _, ctx = bench("a")
  local fired = 0
  -- The group's last declared row (C one) is hidden under "a".
  O.RenderRows(ctx, anchorRows(), { Anchor = function() fired = fired + 1 end })
  -- red under: endGroup looking past the drawn rows (the hook waits for a row that never comes)
  assertEqual(fired, 1)
end)

test("switched: changing the selector re-renders the page once, on the next frame", function()
  local O, _, ctx = bench("a")
  local rows = anchorRows()
  local renders = 0
  O.SetRenderer(ctx, function(c)
    renders = renders + 1
    O.ClearScroll(c)
    O.RenderRows(c, rows)
  end)
  ctx.panel:Show(); ctx.panel:__fire("OnShow")
  assertEqual(renders, 1)
  local dd
  for _, w in ipairs(Fixture.flatten(O.EnsureScroll(ctx))) do
    if w.labelText == "Attach to" then dd = w end
  end
  dd:__fire("OnValueChanged", "b")
  -- red under: the re-render run inside the dropdown's own callback (it would release the dropdown)
  assertEqual(renders, 1, "not inside the callback")
  mocks.__fireTimers()
  -- red under: no refresher watching the selector (the page keeps drawing section A)
  assertEqual(renders, 2, "one re-render")
  assertEqual(drawn(O, ctx), "Anchor,Attach to,Section B,B one,Section C,C one")
  mocks.__fireTimers()
  assertEqual(renders, 2, "and only one")
end)

test("switched: a write from anywhere (a slash set, a reset) re-renders too, once per change", function()
  local O, rec, ctx = bench("a")
  local rows = anchorRows()
  local renders = 0
  O.SetRenderer(ctx, function(c)
    renders = renders + 1
    O.ClearScroll(c)
    O.RenderRows(c, rows)
  end)
  ctx.panel:Show(); ctx.panel:__fire("OnShow")
  rec.store.mode = "c"
  O.RefreshScalars()
  O.RefreshScalars()
  mocks.__fireTimers()
  assertEqual(renders, 2, "two scalar sweeps over one change: one re-render")
  assertEqual(drawn(O, ctx), "Anchor,Attach to,Section C,C one")
  O.RefreshScalars()
  mocks.__fireTimers()
  -- red under: the watcher re-rendering on every refresh rather than on a change
  assertEqual(renders, 2, "no change, no re-render")
end)

test("switched: a selector that cannot be read shows its rows rather than losing them", function()
  local O, rec, ctx = bench("a")
  local get = rec.d.get
  rec.d.get = function(path)
    if path == "mode" then error("selector unreadable") end
    return get(path)
  end
  local ok = pcall(O.RenderRows, ctx, anchorRows())
  rec.d.get = get
  assertTrue(ok, "the render survived")
  -- red under: shownNow calling the read unguarded (the whole render raises)
  assertTrue(drawn(O, ctx):find("B one", 1, true) ~= nil, "a raising read reads as shown")
end)

test("switched: rows without shownWhen render as before, and no selector watcher is added", function()
  local O, rec, ctx = bench("a")
  local rows = rec.d.rowsForPage("bar")
  O.RenderRows(ctx, rows)
  local widgets = 0
  for _, w in ipairs(Fixture.flatten(O.EnsureScroll(ctx))) do
    if w.labelText and w.type ~= "SimpleGroup" then widgets = widgets + 1 end
  end
  -- red under: a watcher added for every row (or the list copied and re-ordered) when nothing opted in
  assertEqual(#ctx.refreshers, widgets, "one refresher per drawn widget, as before minor 22")
  assertNil(ctx.__switchQueued)
  assertFalse(drawn(O, ctx) == "", "the page drew")
end)
```

In `tests/run.lua`, `"test_options_idsuggest", "test_options_idlist_remove", "test_options_compose",`
becomes `"test_options_idsuggest", "test_options_idlist_remove", "test_options_switched", "test_options_compose",`.

- [ ] **Step 2: Run it and see it fail**

Run (LibKa0s root): `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua 2>&1 | grep -A3 "switched:"`
Expected: four FAIL — the two drawing cases (every section drawn: `expected Anchor,Attach to,Section
A,A one,A two, got Anchor,Attach to,Section A,A one,A two,Section B,B one,Section C,C one`) and the two
re-render cases (`one re-render (expected 2, got 1)`). "a group's afterGroup hook …", "a selector that
cannot be read …" and "rows without shownWhen …" PASS: they guard behavior today's code already has
(the hidden rows are drawn, so nothing is lost), and must stay true once rows can be dropped.

- [ ] **Step 3: Implement**

`LibKa0s/OptionsWidgets.lua`:

1. `local WIDGETS_MINOR = 21` → `local WIDGETS_MINOR = 22`.
2. Directly above `  --- The flow engine's loop, under the disable flag RenderRows holds for it.` insert:

```lua
  -- ── switched sections: `shownWhen` (minor 22) ─────────────────────────────────────────────
  --
  -- A subsection chosen by a dropdown -- a tab strip whose selector is a stored setting -- is drawn
  -- only while that setting says so. A row carrying
  --   shownWhen = { path = "<selector path>", equals = <value> | { <value>, ... } }
  -- is DROPPED from the render (heading included, no space reserved) while the selector holds any
  -- other value, and the page re-renders once, on the next frame, when the selector changes. The
  -- row stays in the schema -- /<slash> list, get, set, the resets and Defaults all still reach it
  -- (options-ui-§6); only the flow engine skips it. Opt-in: a row list with no `shownWhen` in
  -- it renders exactly as before minor 22 -- the list is not copied and no refresher is added.

  --- Whether `row` is drawn under its `shownWhen` (none: always). The selector is read the way
  --- `disabledIf` reads a path (readKey), so a record-backed row reads its own record. A read that
  --- raises reads as shown: a broken selector never loses a section.
  local function shownNow(row)
    local sw = row.shownWhen
    if type(sw) ~= "table" or sw.path == nil then return true end
    local ok, value = pcall(readKey, row, sw.path)
    if not ok then return true end
    local want = sw.equals
    if type(want) ~= "table" then return value == want end
    for _, w in ipairs(want) do
      if value == w then return true end
    end
    return false
  end

  --- The rows of one render that are drawn, and the set of selector paths their `shownWhen` names --
  --- or `rows` itself and nil when none carries one, which is what keeps an opted-out host's render
  --- byte-for-byte unchanged.
  local function switchedRows(rows)
    local selectors
    for _, row in ipairs(rows) do
      local sw = row.shownWhen
      if type(sw) == "table" and sw.path ~= nil then
        selectors = selectors or {}
        selectors[sw.path] = true
      end
    end
    if not selectors then return rows, nil end
    local drawn = {}
    for _, row in ipairs(rows) do
      if shownNow(row) then
        drawn[#drawn + 1] = row
      end
    end
    return drawn, selectors
  end

  --- ONE structural re-render of `ctx`'s page, on the next frame: never inside the callback of the
  --- widget that changed the selector (the re-render releases it, an open pullout included --
  --- options-ui-§11). Coalesced per ctx; O.RefreshPanel scopes it to a page on screen and marks
  --- a hidden one dirty. Immediate where the client has no C_Timer.
  local function requestSwitch(ctx)
    if ctx.__switchQueued then return end
    ctx.__switchQueued = true
    local function run()
      ctx.__switchQueued = nil
      O.RefreshPanel(ctx, true)
    end
    if C_Timer and C_Timer.After then C_Timer.After(0, run) else run() end
  end

  --- For a selector row this render drew: a refresher that re-renders the page once its value differs
  --- from the one this render drew with -- the widget's own change, a /<slash> set, a Defaults press
  --- alike, since every one of them runs the refreshers. It re-arms on the new value, so a page with
  --- no renderer (refreshed by refreshers alone) asks once per change, never on every refresh. A
  --- selector that cannot be read gets no watcher (the sweep pcalls a refresher anyway).
  local function watchSelector(ctx, row)
    local ok, drawnWith = pcall(read, row)
    if not ok then return end
    local function refresh()
      local now = read(row)
      if now == drawnWith then return end
      drawnWith = now
      requestSwitch(ctx)
    end
    ctx.refreshers[#ctx.refreshers + 1] = refresh
  end

```

3. In `flowRows`, the signature and first line

```lua
  local function flowRows(ctx, scroll, rows, afterGroup, pairWith, opts)
    local pendingRow, pendingCount = nil, 0
```

   become

```lua
  local function flowRows(ctx, scroll, allRows, afterGroup, pairWith, opts)
    local pendingRow, pendingCount = nil, 0
    local rows, selectors = switchedRows(allRows)
```

   and after the drawn row's block — right after the `end` that closes `if row.wide then … else … end`,
   still inside `if not row.skipRender then` — add:

```lua
        if selectors and row.path ~= nil and selectors[row.path] then watchSelector(ctx, row) end
```

   (`endGroup(ctx, afterGroup, firedAfter, row, rows[i + 1], flushRow)` below it now reads the drawn
   list, which is what makes `afterGroup` fire after the last drawn row.)

- [ ] **Step 4: Run it — the suite passes, and the versioning gates fail as they must**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua 2>&1 | grep -A3 -E "switched:|FAIL"`
Expected: the seven `switched:` cases PASS; three `versioning:` cases FAIL ("the changelog accounts for …
(got OptionsWidgets minor 22)", "… version-21.22.1.7.3-docs.md", "… members-21.22.1.7.3.json is not on
disk"). Steps 5–6 turn them green (docs/releasing.md steps 4–6). Every other existing case stays green:
a row list without `shownWhen` takes the old path.

- [ ] **Step 5: The API document (docs/releasing.md step 5)**

Copy `docs/api/Options/version-21.21.1.7.3-docs.md` to `docs/api/Options/version-21.22.1.7.3-docs.md`. In the **new** file:
- title `# \`LibKa0s-Options-1.0\` — version 21.22.1.7.3`; the header table's `Files and minors` shows
  `OptionsWidgets.lua` **22**; `Shipped in` v1.45.0; `Supersedes` `[version 21.21.1.7.3](./version-21.21.1.7.3-docs.md)`;
  `Confirm in-game` reads `OptionsWidgets = 22`; in the `Since` paragraph after `` `W21` for `OptionsWidgets.lua` minor 21, `` add `` `W22` for `OptionsWidgets.lua` minor 22, ``;
- rename `## What changed at this version` to `## Previously, at 21.21.1.7.3` and put above it:

```markdown
## What changed at this version

**The flow engine gains one optional row field, `shownWhen` (switched sections), and nothing else
moves.** `OptionsWidgets.lua` 21 → **22**; every other file of the major is unchanged.

- **`shownWhen = { path = <selector path>, equals = <value> | { <value>, … } }` (W22)** on a row
  draws it only while the selector holds `equals` (or any value of an `equals` list). `RenderRows`
  drops every row whose selector says otherwise **before** its group/subgroup pass, so a subsection
  whose rows are all dropped draws no heading and takes no space, and an `afterGroup` hook fires after
  its group's last **drawn** row. The selector is read the way `disabledIf` reads a path (a path-less
  row reads its own record); a read that raises reads as shown. The row stays in the schema — the
  CLI, the resets and Defaults still reach it — only the flow engine skips it.
- **The page re-renders when the selector changes.** For every row of the call whose `path` is some
  row's selector, `RenderRows` adds a refresher that compares the selector's value with the one the
  render drew with and, on a change, asks for **one** structural re-render of the page on the next
  frame (`C_Timer.After(0)`, coalesced per ctx, through `O.RefreshPanel(ctx, true)`, so a hidden page
  is marked dirty instead). The widget's own change, a `/<slash> set` and a Defaults press all run the
  refreshers, so all three re-render. The re-render never runs inside the changing widget's callback.
- **Absent, the render is byte-for-byte what 21.21.1.7.3 drew**: the row list is not copied and no
  refresher is added. A selector must be drawn in the same `RenderRows` call to be watched; a host
  that draws it elsewhere re-renders the page itself.

```

- in the instance-surface table, the `RenderRows` row's Since cell becomes
  `W1 (\`opts.noHeadings\`: **W9**; \`opts.disabled\`: **W16**; \`shownWhen\`: **W22**)`;
- in `## Row fields the flow engine reads`, after the `skipRender` row add:

```markdown
| `shownWhen` | **W22** | `{ path = <selector path>, equals = <value> \| { <value>, … } }`. Draw the row only while the selector (read like a `disabledIf` path) holds `equals`, or any value of an `equals` list; otherwise it is dropped from the render, its heading with it when its whole subsection is dropped. A raising read reads as shown. A selector drawn in the same `RenderRows` call is watched, and a change re-renders the page once on the next frame — see [What changed at this version](#what-changed-at-this-version). The row stays in the schema. For a subsection a **dropdown** chooses; a single row a checkbox dims keeps `disabledIf`. |
```

In the **old** file: `Status` → Superseded; `Superseded by` → `[version 21.22.1.7.3](./version-21.22.1.7.3-docs.md)`; append:

```markdown

## Moving to version 21.22.1.7.3

One optional row field, `shownWhen` (**W22**), in LibKa0s v1.45.0: a row carrying
`{ path, equals }` is drawn only while its selector holds that value, and the page re-renders when
the selector changes. A host that does not use it renders exactly what it rendered here. See
[version 21.22.1.7.3](./version-21.22.1.7.3-docs.md).
```

In `docs/api/README.md`, replace the 21.21.1.7.3 row with:

```markdown
| [21.22.1.7.3](./Options/version-21.22.1.7.3-docs.md) | `Options.lua` 21 · `OptionsWidgets.lua` 22 · `OptionsTabs.lua` 1 · `OptionsCompose.lua` 7 · `OptionsScroll.lua` 3 | v1.45.0 | **Current** |
| [21.21.1.7.3](./Options/version-21.21.1.7.3-docs.md) | `Options.lua` 21 · `OptionsWidgets.lua` 21 · `OptionsTabs.lua` 1 · `OptionsCompose.lua` 7 · `OptionsScroll.lua` 3 | v1.44.0 | Superseded |
```

Then `lua tools/gen-api-members.lua` (writes `docs/api/Options/members-21.22.1.7.3.json`; the other
eleven manifests come out byte-identical; never hand-edit one).

- [ ] **Step 6: CHANGELOG, the version-bearing lines, the case list (docs/releasing.md steps 4, 6, 7)**

`CHANGELOG.md`, above `## v1.44.0 — 2026-09-19`:

```markdown
## v1.45.0 — 2026-09-19

Versions in this release: **OptionsWidgets minor 22** (`LibKa0s-Options-1.0` 21.22.1.7.3). Every
other major is unchanged from v1.44.0, and the kit stays at revision 23.

**Switched sections: a row can be shown only while a dropdown says so.** A new optional row field,
`shownWhen = { path = <selector path>, equals = <value> | { <value>, … } }`, makes the flow engine
draw the row only while the selector holds that value — a subsection whose rows are all dropped draws
no heading and takes no space — and re-render the page once, on the next frame, when the selector
changes (its own dropdown, a `/<slash> set`, a Defaults press). It is a tab strip whose selector is a
stored setting: the three placement subsections under an *Attach to* or *Anchor mode* dropdown, of
which only the chosen one applies. The rows stay in the schema, so the CLI and the resets still reach
them. Opt-in: a row list without the field renders exactly as at v1.44.0. Aura Master (Layout →
Anchor) and Party Frame Enhanced (Size & Position) are the first adopters. Cases:
`tests/test_options_switched.lua` (its own suite: `tests/test_options_widgets.lua` is over the
layout-§1 cap, issue #33).

```

`docs/releasing.md`: line 7 `Repo semver (\`v1.44.0\`)` → `v1.45.0`; the provenance template (line 201)
`… v1.44.0 (MIT).` → `… v1.45.0 (MIT).`; after the "**Where v1.44.0 stands (2026-09-19).**" paragraph add:

```markdown

**Where v1.45.0 stands (2026-09-19).** One LibStub minor moves — `OptionsWidgets.lua` 22
(`LibKa0s-Options-1.0` 21.22.1.7.3) — and the kit stays at revision 23. What a consumer owes: the
copy of both payloads and the provenance line; nothing more unless it adopts `shownWhen`, which Aura
Master and Party Frame Enhanced do.
```

`README.md`: `As of **v1.44.0**` → `As of **v1.45.0**`, and in that paragraph `OptionsWidgets = 21` →
`OptionsWidgets = 22`. **The standards pointer** (step 7): `head -1 ../WowAddonStandards/standards/STANDARDS.md`
prints v2.59.1 and `grep -n 'v2\.' CLAUDE.md README.md` shows v2.59.0 on line 3 of each: read the
v2.59.1 entry of the standard's changelog (a patch: preview-mode's two MUSTs clarified, no rule change,
nothing for a library) and move both lines to **v2.59.1**.

Regenerate the case list: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua --list > docs/test-cases.md` (it writes CRLF).

- [ ] **Step 7: The LibKa0s green gate, then the release commits (docs/releasing.md step 7)**

Run (LibKa0s root): `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua && /home/tushar/.claude/wow-addon/bin/ka0s-bounded luacheck . && /home/tushar/.claude/wow-addon/bin/ka0s-bounded lizard -l lua -x "./tests/_kit/*" -C 15 -w LibKa0s`
Expected: `1166 passed, 0 failed, 0 skipped` (measured on a scratch copy: 1159 + the 7 new), `0 warnings / 0 errors`,
lizard prints nothing. `git status --short` lists exactly `CHANGELOG.md`, `CLAUDE.md`,
`LibKa0s/OptionsWidgets.lua`, `README.md`, `docs/api/Options/version-21.21.1.7.3-docs.md`,
`docs/api/README.md`, `docs/releasing.md`, `docs/test-cases.md`, `tests/run.lua`, and the new
`docs/api/Options/members-21.22.1.7.3.json`, `docs/api/Options/version-21.22.1.7.3-docs.md`,
`tests/test_options_switched.lua`.

Then, as `docs/releasing.md` step 7 orders it: commit everything (`LibKa0s v1.45.0: switched sections
— shownWhen (OptionsWidgets minor 22)`, with the session's two trailer lines); confirm
`git status --porcelain` prints nothing; run the release battery
`/home/tushar/.claude/wow-addon/bin/ka0s-bounded tests/_kit/run-automated-tests.sh --release 1.45.0`;
read the manifest it wrote (`jq -r '.release, .git.dirty, .git.sha' docs/automated-tests/<stamp>/manifest.json`
→ `1.45.0`, `false`, the commit just made; `lint`, `tests`, `complexity` `pass`, `complexity.warnings`
0, `perf` the standing `skip`); commit the bundle and its `RESULTS.md` row (`The v1.45.0 release record`).

- [ ] **Step 8: STOP — owner go-ahead required**

Do **not** tag or push. Hand the owner the two LibKa0s commits, the gate result and the manifest's
fields, and the remaining release steps: tag `v1.45.0` on the release-record commit (`git -C
/mnt/d/Profile/Users/Tushar/Documents/GIT/LibKa0s tag v1.45.0 <sha2>`), push when they choose. Tasks
15–18 wait until `git -C /mnt/d/Profile/Users/Tushar/Documents/GIT/LibKa0s tag -l v1.45.0` prints
`v1.45.0`. (For v1.44.0 the owner let the controller commit and tag; that is theirs to say again.)

- [ ] **Step 9: Update the Status ledger row for this task (status, commit SHAs, repo) and the resume guide's "Current position" line; commit the plan file with the task's commit**

Row 14 → `blocked`, Notes "LibKa0s <sha1> + <sha2> on master; awaiting the owner's tag v1.45.0 and
push". Current position → "Next: the owner tags LibKa0s v1.45.0; then Task 15. Tasks 1–11, 13 done;
12 and 14 blocked on the owner." The plan file is committed in **Aura Master** (`T14: LibKa0s v1.45.0
prepared, awaiting the tag`).

---

### Task 15: #4b — re-vendor LibKa0s v1.45.0 into Aura Master

**Precondition (hard):** `git -C /mnt/d/Profile/Users/Tushar/Documents/GIT/LibKa0s tag -l v1.45.0`
prints `v1.45.0` — the owner has tagged Task 14's release-record commit. If it prints nothing, STOP:
the row stays `blocked` ("awaiting the owner's tag v1.45.0"). A copy from untagged `master` fails
`tests/test_vendor_sync.lua` by design (LibKa0s `docs/releasing.md`, "Re-vendoring consumers").

**Files:**
- Replace (whole-folder copy from the tag, never by hand): `libs/LibKa0s/`, `tests/_kit/`
- Modify: `CLAUDE.md:35` (the provenance line), `DEPENDENCIES.md:85` and `:92`, `docs/ARCHITECTURE.md:52`
- Test: none new — `tests/test_vendor_sync.lua` is the proof (it must run and pass, not SKIP)

**Interfaces:**
- Consumes: the tag `v1.45.0` in `../LibKa0s` (its `LibKa0s/` and `testkit/` trees).
- Produces: `libs/LibKa0s/OptionsWidgets.lua` at minor 22 (`shownWhen`), everything else in both
  payloads byte-identical to v1.44.0 (kit revision 23 unchanged). Nothing in Aura Master uses
  `shownWhen` until Task 16, so this commit changes no behavior: the default path is unchanged
  (Task 14's last suite case proves it in the library).

- [ ] **Step 1: Preflight**

Run (Aura Master root):

```bash
LK=/mnt/d/Profile/Users/Tushar/Documents/GIT/LibKa0s
git -C "$LK" describe --exact-match v1.45.0
git status --short
git branch --show-current
```

Expected: `v1.45.0`; an empty status (or only this plan file, if the controller keeps it staged
between tasks); `feat/smoke-feedback`.

- [ ] **Step 2: Copy both payloads from the tag, whole**

```bash
LK=/mnt/d/Profile/Users/Tushar/Documents/GIT/LibKa0s
X=$(mktemp -d)
git -C "$LK" archive v1.45.0 LibKa0s testkit | tar -x -C "$X"
rm -rf libs/LibKa0s tests/_kit
mkdir -p libs/LibKa0s tests/_kit
cp -r "$X/LibKa0s/." libs/LibKa0s/
cp -r "$X/testkit/." tests/_kit/
diff -r --strip-trailing-cr "$X/LibKa0s" libs/LibKa0s
diff -r --strip-trailing-cr "$X/testkit" tests/_kit
rm -rf "$X"
git add libs/LibKa0s tests/_kit
git update-index --chmod=+x tests/_kit/run-automated-tests.sh
git status --short
```

Expected: both diffs print nothing; the status lists exactly `M  libs/LibKa0s/OptionsWidgets.lua`
(the removal and re-copy leave every other file identical, and no file is added or deleted — the tag
removed none). If anything else appears, STOP and report: a payload drifted from the tag it claims.

- [ ] **Step 3: Move the version-bearing lines**

- `CLAUDE.md:35`: `Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.44.0 (MIT).` →
  `… v1.45.0 (MIT).`
- `DEPENDENCIES.md:85`: ``reads the tag named in root `CLAUDE.md` (`v1.44.0`) out of a checkout at `../LibKa0s` and compares``
  → `` (`v1.45.0`) ``; `DEPENDENCIES.md:92`: `git -C ../LibKa0s rev-parse --short v1.44.0   # verify: prints a commit`
  → `v1.45.0`.
- `docs/ARCHITECTURE.md:52`: `| LibKa0s v1.44.0 | Ten modules wired, one setup file each — table below |`
  → `| LibKa0s v1.45.0 | …`.

Then confirm nothing live still names the old bundle:

```bash
grep -rn "1\.44\.0" --exclude-dir=libs --exclude-dir=.git --exclude-dir=audits --exclude-dir=reviews --exclude-dir=superpowers --exclude-dir=automated-tests .
```

Expected: one line only, `settings/GeneralSpells.lua:18` — a code comment recording when the X-icon
lists arrived (history, stays).

- [ ] **Step 4: The green gate — the no-breakage proof**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua && /home/tushar/.claude/wow-addon/bin/ka0s-bounded luacheck .`
Expected: the same case count as after Task 13, `0 failed, 0 skipped` (1089 on the scratch run), and
`tests/test_vendor_sync.lua` reports PASS (not SKIP) against `v1.45.0`; `0 warnings / 0 errors`.

- [ ] **Step 5: Update the Status ledger row for this task (status, commit SHAs, repo) and the resume guide's "Current position" line; commit the plan file with the task's commit**

Row 14 → `done` (Notes: add "tagged v1.45.0 by the owner"); row 15 → `done` with the SHA. Current position → "Next: Task 16 — not started; Tasks 1–11 and 13–15 done;
12 blocked on the owner." Commit: `T15: re-vendor LibKa0s v1.45.0` (body: what
arrived — OptionsWidgets minor 22, `shownWhen`; the battery result), with this plan file.

---

### Task 16: #4c — Aura Master adopts `shownWhen` on Layout → Anchor

**Files:**
- Modify: `settings/Layout.lua:13-18` (header comment), `:30-41` (`onlyIn` → four `shownWhen` tables),
  `:93-98` (the Attach to row), `:100-153` (the ten switched rows: `disabledIf =` → `shownWhen =`)
- Modify: `locales/enUS.lua:275` (the Attach to tooltip: "enabled below" → "shown below"; old key retired)
- Modify: `docs/settings-panel.md:16` and `:319-324`, `docs/module-map.md:101` and `:160`,
  `docs/smoke-tests.md:114-118` (item 25), `:378-379` (item 69), `:450` (item 78)
- Test: `tests/test_pages_layout.lua` (helpers at 30-81 rewritten; cases at 91, 105, 121-143, 145-155,
  157, 168, 186, 196, 210 edited)

**Interfaces:**
- Consumes: Task 15's `libs/LibKa0s/OptionsWidgets.lua` minor 22 — a row's
  `shownWhen = { path = "<selector path>", equals = <value> | { … } }`; the selector is read through
  the row's own `readKey`/`get` (here `NS.GetByPath`, the selected container), the tab is redrawn
  once, on the next frame, when the selector's value changes, from any write.
- Produces: Layout → Anchor draws **Attach to**, then only what the mode reads — `screen`: Screen;
  `container`: Another container + Offset; `frame`: Named frame (with Pick a frame…) + Offset. A
  hidden subsection draws no heading. The rows stay in the schema: `/am set|get`, Defaults and the
  profile resets reach every one. The Attach to row loses its `onChange = structural` (the library's
  watcher redraws; keeping both would redraw twice). The Growth tab's rows keep their `FOLLOWS`
  dimming (a `disabledIf` on a derived state, not a dropdown's value — D-4's adoption rule).

- [ ] **Step 1: Write the failing tests**

`tests/test_pages_layout.lua`:

1. After `targetDropdown` (ends at line 27), insert:

```lua

--- layout(), with container 1 attached in `mode` first, so the Anchor tab draws that mode's
--- subsections (feedback #4: the others are not drawn at all).
local function layoutIn(mode)
    local NS, m = fresh()
    NS.SetByPath("container.attach.mode", mode, 1)
    m.__fireTimers()
    local P = pages(NS, m)
    P.show("Layout")
    return NS, m, P, P.tab("layout", NS.L["Anchor"])
end
```

2. Replace `anchorWidgets` and `assertDimming` (lines 39-75, from `--- The widget each Anchor row drew,
   by path.` through `assertDimming`'s closing `end`) with:

```lua
--- How many widgets a render drew under each label, the banner's excepted (it is a second
--- "Container" dropdown). Counts, because Screen and Named frame both have a Point and a Relative point.
local function drawnLabels(NS, ws)
    local banner = NS.Helpers.__pageCtx.layout.__bannerWidget
    local out = {}
    for _, w in ipairs(ws) do
        local label = w.labelText
        if w ~= banner and label then out[label] = (out[label] or 0) + 1 end
    end
    return out
end

--- The subsection headings a render drew, in order.
local function headingsOf(ws)
    local out = {}
    for _, w in ipairs(ws) do
        if w.type == "Heading" then
            local n = #out
            out[n + 1] = w.text
        end
    end
    return table.concat(out, ",")
end

--- Assert which subsections `mode` draws: each row label drawn exactly as many times as the `on`
--- subsections hold it (so a row of any other subsection is not drawn at all), and Attach to once.
local function assertShown(NS, ws, mode, on)
    local labels = drawnLabels(NS, ws)
    local want = {}
    for _, sub in ipairs(SUBSECTIONS) do
        for _, path in ipairs(sub.paths) do
            local label = NS.FindSchemaRow(path).label
            want[label] = (want[label] or 0) + (on[sub.key] and 1 or 0)
        end
    end
    for label, n in pairs(want) do
        assertEqual(labels[label] or 0, n, ("%s in %s mode"):format(label, mode))
    end
    assertEqual(labels[NS.L["Attach to"]], 1, "Attach to is always drawn")
end
```

3. Replace the case "layout: the Anchor tab is broken into Screen, Another container, Named frame and
   Offset" (91-103) with:

```lua
test("layout: the Anchor tab draws only the chosen mode's subsections, each under its heading (feedback #4)", function()
    local L = T.NS.L
    local want = {
        screen    = L["Screen"],
        container = L["Another container"] .. "," .. L["Offset"],
        frame     = L["Named frame"] .. "," .. L["Offset"],
    }
    for mode, heads in pairs(want) do
        local _, _, _, ws = layoutIn(mode)
        -- red under: the rows without shownWhen (every subsection drawn, dimmed), or a hidden
        -- subsection's heading drawn over nothing
        assertEqual(headingsOf(ws), heads, mode)
    end
end)
```

4. Replace the per-mode loop and "layout: changing Attach to re-dims the same widgets before any
   redraw" (121-143) with:

```lua
for _, mode in ipairs({ "screen", "container", "frame" }) do
    test("layout: in " .. mode .. " mode only the subsections that apply are drawn (feedback #4)", function()
        local NS, _, P = layout()
        NS.SetByPath("container.attach.mode", mode, 1)
        local ws = P.rerender("Layout")
        -- red under: a subsection's rows without their shownWhen, or naming the wrong mode
        assertShown(NS, ws, mode, ON[mode])
        -- Pick a frame is Frame name's partner, so it is drawn with Named frame alone.
        assertEqual(P.find(ws, "Button", NS.L["Pick a frame..."]) ~= nil, mode == "frame", "Pick a frame...")
    end)
end

test("layout: changing Attach to redraws the tab on the next frame with the chosen subsections (feedback #4)", function()
    local NS, m, P, ws = layout()
    NS.Helpers.__pageCtx.layout.panel:Show()
    assertShown(NS, ws, "screen", ON.screen)
    local during = P.during(function() P.row(ws, "container.attach.mode"):__fire("OnValueChanged", "frame") end)
    -- red under: the tab redrawn inside the dropdown's own callback (it would release the dropdown)
    assertEqual(#during, 0, "nothing drawn inside the callback")
    local redrawn = P.during(function() m.__fireTimers() end)
    -- red under: no selector watch (the tab keeps showing the Screen rows)
    assertShown(NS, redrawn, "frame", ON.frame)
    redrawn = P.during(function()
        P.row(redrawn, "container.attach.mode"):__fire("OnValueChanged", "container")
        m.__fireTimers()
    end)
    assertShown(NS, redrawn, "container", ON.container)
end)
```

5. In "layout: Attach to writes the mode and redraws an open page on the next frame" (145), the
   comment `-- red under: the mode row losing its structural onChange (a scalar refresh draws nothing new)` →

```lua
    -- red under: the mode row's rows without shownWhen (nothing watches the selector, so a scalar
    -- refresh draws nothing new)
```

6. Cases whose rows now draw only in one mode start in that mode:
   - "the Pick a frame sits beside Frame name…" (105), "Frame name stores the typed name…" (186),
     "Pick a frame in combat refuses…" (196), "a pick attaches the container selected…" (210):
     `layout()` → `layoutIn("frame")` (keeping each case's own left-hand names).
   - "a target that would close a loop is refused…" (168): `layout()` → `layoutIn("container")`.
   - "the Container dropdown offers None and every other container…" (157): its first line
     `local NS, _, P = layout()` →

```lua
    local NS, m, P = layout()
    NS.SetByPath("container.attach.mode", "container", 2)
    m.__fireTimers()
```

- [ ] **Step 2: Run them and see them fail**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua 2>&1 | grep -A1 -E "FAIL|passed"`
Expected: 5 FAIL, all feedback #4 cases (measured on a scratch copy against the unchanged Layout.lua):
"the Anchor tab draws only…" `frame (expected Named frame,Offset, got Screen,Another container,Named frame,Offset)`;
"in screen mode…" `Point in screen mode (expected 1, got 2)`; "in container mode…" and "in frame
mode…" `Y in … mode (expected 0, got 1)`; "changing Attach to redraws…" `Point in screen mode
(expected 1, got 2)`. Every other case passes (the mode-first cases still find their rows, dimmed).

- [ ] **Step 3: Implement**

`settings/Layout.lua`:

1. Header comment, replace lines 13-18 (`-- named frame (modules/Anchors.lua). A subsection the chosen
   mode does not read is dimmed through` … `-- live in every mode.`) with:

```lua
-- named frame (modules/Anchors.lua). Only the subsections the chosen mode reads are DRAWN (feedback
-- #4, LibKa0s v1.45.0's `shownWhen`): Screen for the screen; Another container, or Named frame, and
-- Offset for an attachment. The rows stay in the schema, so `/am set` and the resets reach every one
-- of them; switching Attach to redraws the tab once, on the next frame, through the library's own
-- selector watch. The frame picker (modules/FramePicker.lua) sits beside Frame name, so it is drawn
-- in Named frame mode; it closes the settings window, lets the player click a frame, writes the
-- mode itself and reopens this page.
```

2. Replace `onlyIn` and its four locals (lines 30-41, from `--- A \`disabledIf\` predicate: the row is
   dimmed unless` through `local ATTACHED_ONLY = onlyIn("container", "frame")`) with:

```lua
-- The switched subsections under Attach to (LibKa0s-Options-1.0 `shownWhen`, W22): each row is
-- drawn only while the selected container's attach mode is the one (or one of those) named.
local MODE = "container.attach.mode"
local SCREEN_ONLY    = { path = MODE, equals = "screen" }
local CONTAINER_ONLY = { path = MODE, equals = "container" }
local FRAME_ONLY     = { path = MODE, equals = "frame" }
local ATTACHED_ONLY  = { path = MODE, equals = { "container", "frame" } }
```

3. The Attach to row (93-98) becomes:

```lua
    {
        -- The selector of the switched subsections below: the library redraws the tab when it
        -- changes, from the panel, `/am set` or a reset alike, so it needs no onChange of its own.
        path = MODE, page = PAGE, group = G_ANCHOR, type = "string",
        values = NS.Choices(C.ATTACH_MODES, C.ATTACH_MODE_LABELS), label = L["Attach to"],
        desc = L["The screen (drag it anywhere), another container (it follows that container as it grows), or any named frame — a unit frame, an action bar. Only the settings for your choice are shown below."],
    },
```

4. In the ten rows that follow (100-153), every `disabledIf = SCREEN_ONLY` / `CONTAINER_ONLY` /
   `FRAME_ONLY` / `ATTACHED_ONLY` becomes `shownWhen = ` the same name — nothing else on those rows
   changes (the Container row keeps its `onChange = structural`: its attachment line names the target).

```bash
python3 - <<'EOF'
p = "settings/Layout.lua"
s = open(p, newline="").read()
for k in ("SCREEN_ONLY", "CONTAINER_ONLY", "FRAME_ONLY", "ATTACHED_ONLY"):
    s = s.replace("disabledIf = " + k, "shownWhen = " + k)
open(p, "w", newline="").write(s)
EOF
grep -c "shownWhen = " settings/Layout.lua
```

Expected: `10`. (The four `local … _ONLY = { … }` lines are untouched by it: they hold no `disabledIf`.)

`locales/enUS.lua:275`: the key and value `…Only the settings for your choice are enabled below.` →
`…Only the settings for your choice are shown below.` (both sides; the old key goes).

Docs:
- `docs/settings-panel.md:16`: `(the screen, another container or a named frame, with what the mode
  does not read dimmed)` → `(the screen, another container or a named frame, with only what the mode
  reads drawn)`.
- `docs/settings-panel.md:319-324` (the paragraph starting "Each subsection's rows carry a
  `disabledIf` predicate"), replace with:

```markdown
Each subsection's rows carry a `shownWhen` switch on **Attach to** (LibKa0s-Options-1.0 W22,
feedback #4), so only the subsections the mode reads are drawn, each heading with its rows: in
`screen` mode Screen; in `container` mode Another container and Offset; in `frame` mode Named frame
and Offset. The hidden rows stay in the schema, so `/am set`, `/am get` and the resets still reach
them. Changing **Attach to** (from the panel, `/am set` or a reset) redraws the tab once, on the next
frame, through the library's selector watch; the mode row needs no `onChange` of its own. **Pick a
frame…** (closes the settings, starts the picker, reopens this page) is Frame name's `pairWith`
partner, so it is drawn with Named frame; a pick still sets the mode to Named frame itself.
```

- `docs/module-map.md:101`: `dimmed by attach mode` → `drawn by attach mode`; `:160`: `their dimming
  per mode` → `the subsections drawn per mode`.
- `docs/smoke-tests.md` item 25 (114-118), replace with:

```markdown
25. **Layout** → **[ Frame ][ Anchor ][ Growth ][ Mouse ]**; Anchor reads **Attach to**, then only
    the subsections that mode uses, and there is no Attach to the screen button (feedback #4). Set
    **Attach to** → *Screen* → only **Screen** is drawn under it, no empty headings; → *Named frame* →
    the tab redraws with **Named frame** (Frame name with **Pick a frame…** beside it) and **Offset**,
    Screen gone; → *Another container* → **Another container** and **Offset**. Then `/am set
    container.attach.mode screen` with the page open → it redraws to Screen alone; `/am get
    container.attach.x` still answers while Offset is hidden.
```

- Item 69 (378-379): `Check 25 for the Anchor subsections;` → `Check 25 for the Anchor subsections (now
  drawn by mode, not dimmed);` and rewrap to two lines.
- Item 78 (450): `with a genuinely disabled row on Layout → Anchor (a mode's dimmed fields) to see the
  difference.` → `with a genuinely disabled row on the Bars page of an icon container (check 26) to see
  the difference.` (Layout → Anchor has no dimmed row any more.)

- [ ] **Step 4: Run them and see them pass; citations**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua 2>&1 | grep -A1 -E "FAIL|passed"`
Expected: `… 0 failed, 0 skipped` (1089 on the scratch run: the case count is unchanged — one headings
case, three mode cases and one change case replace the same five). Then
`grep -rn "Layout.lua:[0-9]\|smoke-tests.md:[0-9]\|settings-panel.md:[0-9]" docs README.md DEPENDENCIES.md | grep -v "docs/audits\|docs/reviews\|docs/superpowers"`
must print nothing (no live citation into the moved lines; the frozen audits keep theirs).

- [ ] **Step 5: Checkpoint — the green gate**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua && /home/tushar/.claude/wow-addon/bin/ka0s-bounded luacheck . && /home/tushar/.claude/wow-addon/bin/ka0s-bounded lizard -l lua -x "./libs/*" -x "./tests/_kit/*" -C 15 -w .`
Expected: 0 failed; `0 warnings / 0 errors`; lizard prints nothing.

- [ ] **Step 6: Update the Status ledger row for this task (status, commit SHAs, repo) and the resume guide's "Current position" line; commit the plan file with the task's commit**

Row 16 → `done` with the SHA. Current position → "Next: Task 17 — not started (ten consumers); Tasks
1–11 and 13–16 done; 12 blocked on the owner." Commit: `T16: Layout → Anchor draws only the chosen
mode's subsections (feedback #4)`, with this plan file.

---

### Task 17: #4d — re-vendor LibKa0s v1.45.0 into the other ten consumers; the adoption sweep

LibKa0s `docs/releasing.md` step 8 makes re-vendoring **every** consumer part of the release, and
step 9 re-sweeps its Consumers table. This task does both, the way v1.44.0's did (the Text-style
plan's Task 19): one branch and one commit per repo, nothing merged or pushed.

**Precondition (hard):** as Task 15 — `git -C /mnt/d/Profile/Users/Tushar/Documents/GIT/LibKa0s tag -l v1.45.0`
prints `v1.45.0`. Otherwise STOP; the row stays `blocked`.

**Repos** (siblings of Aura Master, `/mnt/d/Profile/Users/Tushar/Documents/GIT/<Repo>`; all on `master`
and clean when this plan was written): AbsorbTracker, BankLedger, ConsumableMaster, KickCD,
LootHistory, MultiMeters, PanelMaster, PartyFrameEnhanced, PrettyChat, WhatGroup.

**Files, per repo:**
- Replace (whole-folder copy from the tag): `libs/LibKa0s/`, `tests/_kit/`
- Modify: the `CLAUDE.md` provenance line — AbsorbTracker `CLAUDE.md:71`, BankLedger `:46`,
  ConsumableMaster `:58`, KickCD `:52`, LootHistory `:51`, MultiMeters `:52`, PanelMaster `:44`,
  PartyFrameEnhanced `:37`, PrettyChat `:34`, WhatGroup `:73` (each `v1.44.0` → `v1.45.0`, the rest of
  the sentence as it is)
- Modify: the two live docs that name the **bundled** version — `PartyFrameEnhanced/docs/ARCHITECTURE.md:23`
  (`**LibKa0s v1.44.0** vendored whole`) and `PrettyChat/docs/ARCHITECTURE.md:349`
  (`**[LibKa0s](…) v1.44.0**`). Every other `v1.44.0` in a live file is a **"since"** attribution of
  `removeStyle = "icon"` (BankLedger `docs/settings-panel.md:92`, its test name at
  `tests/test_panel_filters.lua:163` and `docs/test-cases.md:799`; LootHistory `docs/settings-panel.md:251`,
  `docs/testing.md:96-97`, `tests/test_panel_filters.lua:113`, `:164`, `:323`) — history, left as is.
- Then, in LibKa0s: `docs/releasing.md` (the Consumers table's Options row and "Where v1.45.0 stands").

**Interfaces:**
- Consumes: the tag `v1.45.0` (Task 14, tagged by the owner); the D-4 adoption rule.
- Produces: ten branches `chore/libka0s-v1.45.0`, one commit each; a sweep table for the owner; one
  post-release docs commit on LibKa0s `master` (not pushed). Only Party Frame Enhanced adopts
  `shownWhen` (Task 18); no other repo changes a line outside the copy and its version lines.

- [ ] **Step 1: Preflight, all ten**

```bash
G=/mnt/d/Profile/Users/Tushar/Documents/GIT
git -C "$G/LibKa0s" describe --exact-match v1.45.0
for a in AbsorbTracker BankLedger ConsumableMaster KickCD LootHistory MultiMeters PanelMaster PartyFrameEnhanced PrettyChat WhatGroup; do
    echo "== $a $(git -C "$G/$a" branch --show-current) dirty=$(git -C "$G/$a" status --short | wc -l)"
    git -C "$G/$a" rev-parse --verify -q chore/libka0s-v1.45.0 && echo "   branch already exists"
done
```

Expected: `v1.45.0`; every repo `master dirty=0`, no branch yet. A repo that is dirty or not on
`master` is **skipped and reported** (the owner may be working in it), never stashed or switched.

- [ ] **Step 2: Per repo — branch, copy from the tag, version lines**

For each repo `$a` that passed Step 1 (they are independent; one at a time keeps the bounded runner
uncontended):

```bash
G=/mnt/d/Profile/Users/Tushar/Documents/GIT
a=AbsorbTracker            # then each of the others in turn
cd "$G/$a"
git switch -c chore/libka0s-v1.45.0 master
X=$(mktemp -d)
git -C "$G/LibKa0s" archive v1.45.0 LibKa0s testkit | tar -x -C "$X"
rm -rf libs/LibKa0s tests/_kit
mkdir -p libs/LibKa0s tests/_kit
cp -r "$X/LibKa0s/." libs/LibKa0s/
cp -r "$X/testkit/." tests/_kit/
diff -r --strip-trailing-cr "$X/LibKa0s" libs/LibKa0s
diff -r --strip-trailing-cr "$X/testkit" tests/_kit
rm -rf "$X"
git add libs/LibKa0s tests/_kit
git update-index --chmod=+x tests/_kit/run-automated-tests.sh
git status --short
```

Expected: both diffs print nothing; status lists exactly `M  libs/LibKa0s/OptionsWidgets.lua`. Then
move the provenance line (the line numbers are in **Files** above; `grep -n "Bundles \[LibKa0s\]" CLAUDE.md`
finds it) and, in PartyFrameEnhanced and PrettyChat, the ARCHITECTURE line, `v1.44.0` → `v1.45.0`.
Confirm:

```bash
grep -rn "1\.44\.0" --exclude-dir=libs --exclude-dir=.git --exclude-dir=audits --exclude-dir=reviews --exclude-dir=superpowers --exclude-dir=automated-tests --exclude-dir=_kit .
```

Expected: nothing, except BankLedger's and LootHistory's "since v1.44.0" lines listed under **Files**.

- [ ] **Step 3: Per repo — the no-breakage proof (the full battery)**

From the repo's root:

```bash
/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua
/home/tushar/.claude/wow-addon/bin/ka0s-bounded luacheck .
/home/tushar/.claude/wow-addon/bin/ka0s-bounded lizard -l lua -x "./libs/*" -x "./tests/_kit/*" -C 15 -w .
test -f tests/perf.lua && /home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/perf.lua
```

Expected: the suite's count unchanged from `master`, `0 failed`, and `tests/test_vendor_sync.lua`
PASSES against `v1.45.0` (a SKIP means `../LibKa0s` was not found — a failed proof, not a pass);
`0 warnings / 0 errors`; lizard prints no function that `master` did not already print (run it on
`master` first if it prints anything); `tests/perf.lua` green where it exists (AbsorbTracker,
ConsumableMaster, KickCD, MultiMeters, PartyFrameEnhanced, WhatGroup). Every
`tests/test_surface_parity.lua` stays green: minor 22 adds no public member to `LibKa0s-Options-1.0`
(Task 14's members file differs from 21.21.1.7.3's only in its version key). A red here STOPS that
repo and is reported with the failing case; it is never fixed by editing `libs/` or `tests/_kit/`.

- [ ] **Step 4: Per repo — one commit**

```bash
git add CLAUDE.md docs/ARCHITECTURE.md 2>/dev/null; git add -u
git status --short
git commit -F - <<'MSG'
Re-vendor LibKa0s v1.45.0

OptionsWidgets minor 22 (LibKa0s-Options-1.0 21.22.1.7.3): the opt-in row field shownWhen draws a
row only while a selector path holds a given value, and re-renders the page once, on the next
frame, when the selector changes. Absent, a render is unchanged; this addon does not use it (see the
adoption sweep in Aura Master's docs/superpowers/plans/2026-09-19-smoke-feedback.md, Task 17).
Every other payload file is byte-identical to v1.44.0; the kit stays at revision 23.

Battery: <N> passed, 0 failed, 0 skipped (vendor-sync compared against v1.45.0); luacheck 0/0;
lizard no new warning; perf <green | none>.

<the session's two trailer lines>
MSG
```

(For PartyFrameEnhanced the body's "this addon does not use it" sentence reads "this addon adopts it
next, on feat/switched-sections".) Record the SHA.

- [ ] **Step 5: The adoption sweep — report, don't adopt**

The rule (D-4): a subsection other than the selector's own whose every row is gated by one stored
dropdown's value is switched; a row gated inside the selector's own subsection, by a checkbox, by
anything not a stored dropdown value, or a swatch, stays as it is. Re-run the sweep on the new
branches to confirm nothing moved since this plan was written:

```bash
G=/mnt/d/Profile/Users/Tushar/Documents/GIT
for a in AuraMaster AbsorbTracker BankLedger ConsumableMaster KickCD LootHistory MultiMeters PanelMaster PartyFrameEnhanced PrettyChat WhatGroup; do
    grep -rn "disabledIf\|SetDisabled" "$G/$a/settings" "$G/$a/modules" "$G/$a/core" 2>/dev/null \
      | grep -v "/libs/\|/tests/" | sed "s#^$G/##"
done
```

Then write this table into the task's report (the plan-of-record answer; each "not a fit" line was
checked against the rule when the plan was written):

| Repo | Site | Gate | Verdict |
|---|---|---|---|
| AuraMaster | `settings/Layout.lua` Anchor: Screen / Another container / Named frame / Offset | `container.attach.mode` dropdown | **fits — adopted (Task 16)** |
| AuraMaster | `settings/Layout.lua` Growth rows (`FOLLOWS`) | derived: attached to a usable container | not a fit (not a stored dropdown value) |
| AuraMaster | `settings/Text.lua` animation rows, `noDuration`, inherited rows | checkboxes / derived state | not a fit |
| PartyFrameEnhanced | `settings/ElementRows.lua` *Attached to party frames* (point, relativePoint, offsetX, offsetY) | `<page>.anchorMode == "attached"` | **fits — Task 18** |
| PartyFrameEnhanced | `settings/ElementRows.lua` *Free placement* (growth, spacing) | `<page>.anchorMode == "free"` | **fits — Task 18** |
| PartyFrameEnhanced | `settings/ElementRows.lua` `matchWidth` | anchor mode, but in the selector's own *Placement* subsection | not a fit — stays dimmed |
| PartyFrameEnhanced | `settings/ElementRows.lua` `width` (`widthFromFrame`) | a checkbox (Match width) | not a fit — stays dimmed |
| PartyFrameEnhanced | health-update rows, marker rows | checkboxes | not a fit |
| PanelMaster | `PanelEditor` path box | a bespoke editor's state, not a schema row | not a fit |
| PrettyChat, LootHistory, ConsumableMaster, KickCD | manual `SetDisabled` calls | checkboxes / runtime state, not a dropdown's sections | not a fit |
| AbsorbTracker, BankLedger, MultiMeters, WhatGroup | — | no gated rows | nothing to adopt |

If the re-run shows a new dropdown-gated subsection anywhere, add it as a row marked **fits — not
planned** and report it; do not adopt it in this task.

- [ ] **Step 6: LibKa0s — the post-release docs commit (step 9), no push**

In `/mnt/d/Profile/Users/Tushar/Documents/GIT/LibKa0s` on `master`:
1. Run step 9's loop (`docs/releasing.md` lines 162-166) and confirm every file it prints is already
   in the Consumers table's third column (a re-vendor moves no wiring; expected: no change).
2. The `LibKa0s-Options-1.0` row: append to its notes cell `` `shownWhen` (minor 22): Aura Master
   (`settings/Layout.lua`, Layout → Anchor) and Party Frame Enhanced (`settings/ElementRows.lua`,
   Size & Position, pending its merge). ``
3. After the "**Where v1.45.0 stands (2026-09-19).**" paragraph Task 14 added, append: `Step 8 is done
   on branches: every consumer carries v1.45.0 on \`chore/libka0s-v1.45.0\` (Aura Master on its
   feature branch), each green, none merged yet.`
4. `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua && /home/tushar/.claude/wow-addon/bin/ka0s-bounded luacheck .`
   → green (the docs suite checks the table's citations).
5. Commit `docs: v1.45.0's step 8 and 9 — consumers re-vendored on branches; shownWhen adopters`
   with the trailer lines. **No push, no tag.**

- [ ] **Step 7: Update the Status ledger row for this task (status, commit SHAs, repo) and the resume guide's "Current position" line; commit the plan file with the task's commit**

Row 17 → `done`, Notes: `<Repo> <sha>` for each of the ten, plus `LibKa0s <sha>`; any skipped repo
named with its reason. Current position → "Next: Task 18 — not started (PartyFrameEnhanced); Tasks
1–11 and 13–17 done; 12 blocked on the owner." The plan file is committed in **Aura Master**
(`T17: LibKa0s v1.45.0 re-vendored into the ten other consumers; the adoption sweep`).

---

### Task 18: #4e — Party Frame Enhanced adopts `shownWhen` on Size & Position

**Repo:** `/mnt/d/Profile/Users/Tushar/Documents/GIT/PartyFrameEnhanced`, branch `feat/switched-sections`
created from Task 17's `chore/libka0s-v1.45.0` (it needs the v1.45.0 copy). One commit. Nothing merged
or pushed.

**Files:**
- Modify: `settings/ElementRows.lua:30-40` (`ElementRows.Position`'s doc comment and locals),
  `:61-79` (the six rows of *Attached to party frames* and *Free placement*)
- Modify: `docs/settings-panel.md:18`, `docs/smoke-tests.md:172-178` (item 31a),
  `docs/test-cases.md` (regenerated), `README.md:7` (the Tests badge)
- Test: `tests/test_optionssetup.lua` (the case at 98-121 replaced by three)

**Interfaces:**
- Consumes: `LibKa0s-Options-1.0` 21.22.1.7.3's `shownWhen` (Task 14); `NS.Helpers.CreatePanel` /
  `NS.Helpers.RenderRows` (the library's, re-exported by `settings/OptionsSetup.lua`); the kit's
  AceGUI mock (`LibStub("AceGUI-3.0").__created`).
- Produces: on Cast Bars, Target Frames and Pet Frames → Size & Position, *Attached to party frames*
  is drawn only while Anchor mode is `attached` and *Free placement* only while it is `free`, each
  with its heading; the library redraws the tab when Anchor mode changes (the selector row is in the
  same render, so its watcher is added). *Match party frame width* stays in *Placement* and stays
  **dimmed** in free placement (selector's own subsection, D-4); *Width* stays dimmed while Match
  width sets it (a checkbox gate). The six rows stay in the schema: `/pfe set`, Defaults, profiles.

- [ ] **Step 1: Branch**

```bash
cd /mnt/d/Profile/Users/Tushar/Documents/GIT/PartyFrameEnhanced
git status --short
git switch -c feat/switched-sections chore/libka0s-v1.45.0
```

Expected: an empty status; the switch succeeds.

- [ ] **Step 2: Write the failing tests**

`tests/test_optionssetup.lua`: replace the case "optionssetup: the placement block the anchor mode
does not use is dimmed, and Width with Match width" (lines 98-121, through its `end)`) with:

```lua
--- The labels a render of `page`'s Size & Position tab draws, in order, with `page`'s anchor mode
--- set to `mode` first. Rendered through the library into a throwaway panel, the kit's AceGUI
--- recording every widget made.
local panelSeq = 0
local function positionLabels(page, mode)
  NS.SetByPath(page .. ".anchorMode", mode)
  T.mocks.__fireTimers()
  local rows = {}
  for _, row in ipairs(NS.SchemaForPage(page)) do
    if row.group == NS.L["Size & Position"] then rows[#rows + 1] = row end
  end
  panelSeq = panelSeq + 1
  local ctx = NS.Helpers.CreatePanel("PFESwitchedProbe" .. panelSeq, "Probe", {})
  local ace = T.mocks.LibStub("AceGUI-3.0")
  local mark = #ace.__created
  NS.Helpers.RenderRows(ctx, rows)
  local out = {}
  for i = mark + 1, #ace.__created do
    local w = ace.__created[i]
    local label = w.labelText or (w.type == "Heading" and w.text) or nil
    if label then out[#out + 1] = label end
  end
  return table.concat(out, ","), ctx
end

test("optionssetup: Size & Position draws only the placement block the anchor mode uses (shownWhen)", function()
  local L = NS.L
  for _, page in ipairs({ "castbar", "target", "pet" }) do
    local attachedDrawn = positionLabels(page, "attached")
    -- red under: the rows still gated by disabledIf (both blocks drawn, one dimmed), or a hidden
    -- block's heading drawn over nothing
    assertEqual(attachedDrawn, table.concat({ L["Size & Position"], L["Size"], L["Width"], L["Height"], L["Placement"],
      L["Anchor mode"], L["Match party frame width"], L["Attached to party frames"], L["Anchor point"],
      L["Party frame point"], L["X offset"], L["Y offset"] }, ","), page .. ": attached")
    local freeDrawn = positionLabels(page, "free")
    assertEqual(freeDrawn, table.concat({ L["Size & Position"], L["Size"], L["Width"], L["Height"], L["Placement"],
      L["Anchor mode"], L["Match party frame width"], L["Free placement"], L["Growth direction"],
      L["Spacing"] }, ","), page .. ": free")
    NS.ApplyDefault(NS.FindSchemaRow(page .. ".anchorMode"))
    T.mocks.__fireTimers()
  end
end)

test("optionssetup: the hidden block stays in the schema and /pfe set still reaches it", function()
  NS.SetByPath("castbar.anchorMode", "attached")
  for _, path in ipairs({ "castbar.growth", "castbar.spacing", "castbar.point", "castbar.offsetX" }) do
    -- red under: a row removed from the schema rather than skipped by the flow engine (options-ui-§6)
    assertTrue(NS.FindSchemaRow(path) ~= nil, path .. " is still a schema row")
  end
  NS.SetByPath("castbar.spacing", 7)
  assertEqual(NS.GetSetting("castbar.spacing"), 7, "a hidden row is written as before")
  NS.ApplyDefault(NS.FindSchemaRow("castbar.spacing"))
  T.mocks.__fireTimers()
end)

test("optionssetup: Match party frame width dims in free placement, and Width with Match width", function()
  local rows = rowsByPath("castbar")
  NS.SetByPath("castbar.anchorMode", "attached")
  NS.SetByPath("castbar.matchWidth", false)
  for _, path in ipairs({ "castbar.matchWidth", "castbar.width", "castbar.height" }) do
    T.assertFalse(dimmed(rows, path), "attached: " .. path .. " is live")
  end
  NS.SetByPath("castbar.matchWidth", true)
  T.assertTrue(dimmed(rows, "castbar.width"), "the party frame sets the width, so Width is dimmed")
  NS.SetByPath("castbar.anchorMode", "free")
  -- Match width is in the selector's own Placement block, so it is dimmed, never hidden (D-4).
  T.assertTrue(dimmed(rows, "castbar.matchWidth"), "free: Match party frame width is dimmed")
  T.assertFalse(dimmed(rows, "castbar.width"), "free placement always uses Width")
  for _, path in ipairs({ "castbar.point", "castbar.relativePoint", "castbar.offsetX", "castbar.offsetY",
                          "castbar.growth", "castbar.spacing" }) do
    -- red under: a switched row keeping its disabledIf as well (it would dim a row that is not drawn)
    assertEqual(rows[path].disabledIf, nil, path .. " carries shownWhen, not disabledIf")
  end
  NS.ApplyDefault(rows["castbar.anchorMode"])
  NS.ApplyDefault(rows["castbar.matchWidth"])
  T.mocks.__fireTimers()
end)
```

- [ ] **Step 3: Run them and see them fail**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua 2>&1 | grep -A1 -E "^  FAIL|passed"`
Expected (measured on a scratch copy with the v1.45.0 payload): 2 FAIL — "Size & Position draws only
the placement block…" `castbar: attached (expected Size & Position,…,Y offset, got …,Y offset,Free
placement,Growth direction,Spacing)`, and "Match party frame width dims…" `castbar.point carries
shownWhen, not disabledIf (expected nil, got function: …)`. "the hidden block stays in the schema…"
passes already (it guards the change, it does not drive it).

- [ ] **Step 4: Implement**

`settings/ElementRows.lua`, replace lines 30-40 (the doc comment of `ElementRows.Position` through
`local function widthFromFrame() …`) with:

```lua
--- The Size & Position tab: the size first, then the anchor mode, the attached pin and the free
--- stack. Only the placement block the current anchor mode uses is DRAWN (`shownWhen`, LibKa0s
--- v1.45.0): the other block's rows stay in the schema, stored, and `/pfe set` still reaches them.
--- The library watches Anchor mode and redraws the tab once, on the next frame, when it changes.
--- Match party frame width sits in the selector's own Placement block, so it is dimmed rather than
--- hidden in free placement, and Width is dimmed while Match party frame width sets it.
function ElementRows.Position(page, prefix, D)
    local group = L["Size & Position"]
    local modePath, matchPath = prefix .. "anchorMode", prefix .. "matchWidth"
    local ATTACHED_ONLY = { path = modePath, equals = "attached" }
    local FREE_ONLY = { path = modePath, equals = "free" }
    local function free() return NS.GetSetting(modePath) == "free" end
    local function attached() return not free() end
    local function widthFromFrame() return attached() and NS.GetSetting(matchPath) == true end
```

In the rows `point`, `relativePoint`, `offsetX`, `offsetY` (61-72): `disabledIf = free` →
`shownWhen = ATTACHED_ONLY`. In `growth` and `spacing` (73-79): `disabledIf = attached` →
`shownWhen = FREE_ONLY`. `matchWidth` keeps `disabledIf = free`; `width` keeps
`disabledIf = widthFromFrame`. (`attached` is still used, by `widthFromFrame`.)

Docs:
- `docs/settings-panel.md:18`: `the block the anchor mode does not use is dimmed |` → `only the block
  the anchor mode uses is drawn (\`shownWhen\`, LibKa0s v1.45.0) |`.
- `docs/smoke-tests.md` item 31a (172-178), replace with:

```markdown
31a. **Size & Position shows only what applies.** Cast Bars → Size & Position opens with the *Size*
    block (Width, Height), then *Placement*. With *Attach to party frames*: the *Attached to party
    frames* block is drawn and there is no *Free placement* heading at all; with *Match party frame
    width* ticked, *Width* is grayed. Switch to *Free placement* → the tab redraws at once with the
    *Free placement* block (Growth direction, Spacing) in place of the attached one, and *Match party
    frame width* grayed. `/pfe set castbar.anchorMode attached` with the page open → it redraws back.
    Repeat on the Target Frames and Pet Frames pages. *Failure:* the redraw lags one click behind, an
    empty heading is left behind, or the dropdown closes itself mid-choice with a Lua error.
```

- [ ] **Step 5: Run them and see them pass; the inventory**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua 2>&1 | tail -1`
Expected: `237 passed, 0 failed, 0 skipped, 237 total` (235 + 2).

Regenerate the inventory (`docs/testing.md`, "The test-case inventory and the badge"):
`/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua --list > docs/test-cases.md`, then
the CRLF one-liner from Global Constraints on it if `file docs/test-cases.md` does not say CRLF. The
diff against the old list is exactly: `test_optionssetup.lua (8)` → `(10)`, the one dimming case →
the three above, the Total `235` → `237`. `README.md:7`: `Tests-235%2F235_passing` → `Tests-237%2F237_passing`.

- [ ] **Step 6: The battery**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua && /home/tushar/.claude/wow-addon/bin/ka0s-bounded luacheck . && /home/tushar/.claude/wow-addon/bin/ka0s-bounded lizard -l lua -x "./libs/*" -x "./tests/_kit/*" -C 15 -w . && /home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/perf.lua`
Expected: 237 passed (vendor-sync against v1.45.0); `0 warnings / 0 errors`; lizard prints nothing;
perf green. Then `grep -rn "ElementRows.lua:[0-9]\|smoke-tests.md:[0-9]\|settings-panel.md:[0-9]" docs README.md CLAUDE.md | grep -v "docs/audits\|docs/reviews"`
prints nothing.

- [ ] **Step 7: Commit (in PartyFrameEnhanced)**

`git add -u && git status --short` lists `README.md`, `docs/settings-panel.md`, `docs/smoke-tests.md`,
`docs/test-cases.md`, `settings/ElementRows.lua`, `tests/test_optionssetup.lua`. Commit
`Size & Position draws only the placement block the anchor mode uses (LibKa0s shownWhen)` with the
session's two trailer lines.

- [ ] **Step 8: Update the Status ledger row for this task (status, commit SHAs, repo) and the resume guide's "Current position" line; commit the plan file with the task's commit**

Row 18 → `done`, Notes `PartyFrameEnhanced feat/switched-sections <sha>`. Current position → "Next:
Task 19 — not started; Tasks 1–11 and 13–18 done; 12 blocked on the owner." The plan file is
committed in **Aura Master** (`T18: Party Frame Enhanced adopts shownWhen (on its own branch)`).

---

### Task 19: Final gate, the in-game checks owed, the inventory — hand back to the owner

**Precondition:** every row 1–18 is `done`, except 12 (`blocked` on the owner's text-by-dispel choice),
and any row the owner has explicitly deferred. A row still `todo`, `in progress` or `in review` is
finished first.

**Files:**
- Modify: `docs/smoke-tests.md` (a new section **T** after S, items 117–132), `docs/test-cases.md`
  (regenerated), `README.md:7` (the Tests badge)
- Test: none new — this task runs everything

**Interfaces:**
- Consumes: Tasks 1–18.
- Produces: a green, fully measured Aura Master branch; the in-game checklist the spec's "In-game
  checks owed after" names; the owner's hand-back.

- [ ] **Step 1: The full battery, Aura Master**

From the Aura Master root:

```bash
/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua
/home/tushar/.claude/wow-addon/bin/ka0s-bounded luacheck .
/home/tushar/.claude/wow-addon/bin/ka0s-bounded lizard -l lua -x "./libs/*" -x "./tests/_kit/*" -C 15 -w .
/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/perf.lua
```

Expected: `N passed, 0 failed, 0 skipped` (vendor-sync compared against v1.45.0); `0 warnings /
0 errors`; lizard prints nothing; perf green (every scenario within its budget, as on master). A red
STOPS the task: it is fixed in the task that owns the code (its row goes back to `in progress`), not
here.

- [ ] **Step 2: Smoke section T — the in-game checks owed**

Append to `docs/smoke-tests.md` (after item 116, CRLF, the file's own indentation):

```markdown

## T. The smoke-test feedback batch (2026-09-19)

Run with one bar container, one Text container and one icon container on the player's buffs, and a
debuff container on the target, in a party or with a target dummy.

117. **Attached to another frame: no Lua error (E).** Attach a container to another container, then
     one to a named frame (`PlayerFrame`), with `/am unlock` → no Lua error, in or out of combat
     (enable `/console scriptErrors 1`), and each handle's strip is at least as wide as its name.
     Drag the screen-attached one → it moves and saves; `/reload` → it is where you left it.
118. **Center stacks the pieces (#1).** A Text container, Text → General → Justify Center, template
     Centered: name over time → the spell name sits on one row and the time centered under it, each
     row centered; the container's height grows to hold both, the outline and the handle follow.
     Justify Left → one line again.
119. **The Containers band (#2).** Containers opens with the **Container** picker and **New
     container** side by side above the tab strip, and the first tab is named **General**. New
     container → the new one is selected in the picker; the picker switches the page's subject.
120. **Restore beside the Category dropdown (#3).** General → Spell Categories: **Restore** sits on
     the dropdown's own line, right half; hide a starter spell, Restore → it is back.
121. **TEST on the handle (#8).** `/am test` then `/am unlock` → every handle reads its name, then an
     orange **TEST**; end test mode → the tag goes on the next frame, the strip narrows.
122. **Show all / Hide all (#10).** Filters → Categories: under each grid's heading, **Show all** and
     **Hide all**. Hide all on Spell categories → every row reads Hide, the container empties at once
     (one pass, no flicker per row), and `/am debug` shows one `[Set] hide all …` line, not one per row.
123. **Percent tokens and the `( )` (#5a).** Template `$spellname$ ($remainingpercent$%)` on a 30 s
     buff → `Name (73%)`, a whole number, no space inside the brackets. Now the three probes, one at a
     time, and write down what each prints:
     - `/run local f=C_StringUtil.CreateNumericRuleFormatter() f:SetBreakpoints({{threshold=0,format="%d%%"}}) print("["..f:FormatNumber(45.5).."]","["..f:FormatNumber(45).."]")`
       — H1 (the old rule): `[]` for 45.5 and `[45%]` for 45 confirms it; `[45%]` twice rules it out.
     - `/run local f=C_StringUtil.CreateNumericRuleFormatter() f:SetBreakpoints({{threshold=0,step=1,format="%d"}}) print("["..f:FormatNumber(45.5).."]")`
       — the new rule: `[46]` or `[45]`, never `[]`.
     - `/run local s=UIParent:CreateFontString(nil,"OVERLAY","GameFontNormal") s:SetPoint("CENTER") s:SetText("") print(s:GetWidth(), s:GetStringWidth())`
       — the empty-string gap: a non-zero first number is the space seen between `(` and `)`.
     Then the same template on a buff **without** a duration (a mount, or a permanent aura) → `( )`
     means H2 (the binding's zero-duration text); `[ ($remainingpercent$%)]` shows nothing there.
124. **Built-in templates and the Preview (#5b).** Text → General → **Template**: the list names the
     built-ins (Name, Name + time, …; the debuff container adds Name (type), Name, type, time) and
     **Custom template**. Pick each → the Preview line under it changes with it and the live auras
     follow; Centered: name over time also sets Justify to Center. Custom → the template box appears.
125. **Weapon enchants on a real profile (#6).** On a profile that had a Weapon enchants container
     (back up `WTF/…/SavedVariables/AuraMaster.lua` first): log in → one `[Migrate]` line in the debug
     console; the container now reads aura type Buffs, unit Player, with only Weapon enchants shown
     in Filters → Categories, and it still shows your weapon enchant (apply one: a sharpening stone,
     a rogue poison, a shaman imbue) with no "can never match" warning. The aura-type dropdown has no
     Weapon enchants entry; `/am new enchants` makes an enchant-only buff container.
126. **Bars' background by dispel type (#7).** Bars → Background & border → Color by **Dispel type** on
     a target-debuff bar container: a Magic debuff's background is blue, a Curse's purple; a debuff
     with no type keeps the background's own color. Color by Static → the background color alone.
     General → Dispel Colors lists the five types and no None swatch.
127. **Right-click the "?" (#9).** `/am unlock`; right-click container 2's handle **?** → the settings
     open on the **Containers** page with container 2 in the band's picker. In combat → the gray
     "cannot open settings during combat" line, nothing opens, the picker is unchanged afterwards.
128. **Switched sections, Aura Master (#4).** Check 25: only the chosen mode's subsections on Layout →
     Anchor, redrawn at once on a change, from the panel and from `/am set`.
129. **Switched sections, Party Frame Enhanced (#4).** That addon's smoke item 31a on its
     `feat/switched-sections` build.
130. **The dispel type word in color (#7).** A Text container on the target's debuffs, template Name,
     type, time; Text → Animation → Dispel type → **Color the dispel type** on. A Magic debuff reads
     `Name (Magic) - 12s` with only `Magic` in the Magic color from General → Dispel Colors, the
     brackets and the rest in the font color; a Curse in its color. Change the Magic swatch → the word
     follows after the re-apply. In combat the word keeps its color as auras come and go (the engine
     writes the text; nothing of ours runs). If the word shows the raw `|cff…` characters instead,
     the engine's options processing stripped the escape: report it (option c then does not work, and
     the toggle is withdrawn). With a template without `$dispeltype$` the toggle is dimmed.
131. **The dispel backdrop (#7).** Same container, **Backdrop in the dispel color** on: a typed debuff's
     line has a Magic-blue (or Curse-purple, …) box behind its text, the text on top and readable; a
     debuff with no type has no box. **Backdrop opacity** changes its strength (dimmed while the
     backdrop is off). With a text icon on the left, the box covers the text area only, not the icon.
     With Pulse or Bounce on, the box moves and fades with the line. Test mode: the Bloodlust
     placeholder has a Magic box, the others none. Turn the backdrop off → every box goes at once, a
     typed aura included.
132. **The dispel edge (#7).** **Edge in the dispel color** on (backdrop off): a thin outline in the
     type's color around a typed debuff's text area, none on a typeless one; **Edge thickness** 1–4
     thickens it. Both on at once → the edge draws over the backdrop. On a buff container, a
     Magic buff (Power Word: Fortitude, Arcane Intellect) is outlined too. `/reload` and
     combat: nothing to fix up, no Lua error.
```

- [ ] **Step 3: The inventory and the badge**

`/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua --list > docs/test-cases.md` (CRLF
one-liner if `file` says LF), then `README.md:7` `Tests-<old>%2F<old>_passing` → the new
`Tests-N%2FN_passing` from Step 1's line (`docs/testing.md`, "The case inventory and the badge").
Re-run the suite once more: green.

- [ ] **Step 4: The branch record**

```bash
G=/mnt/d/Profile/Users/Tushar/Documents/GIT
git -C "$G/AuraMaster" log --oneline master..feat/smoke-feedback
git -C "$G/LibKa0s" log --oneline -3 && git -C "$G/LibKa0s" tag -l v1.45.0 && git -C "$G/LibKa0s" status -sb | head -1
for a in AbsorbTracker BankLedger ConsumableMaster KickCD LootHistory MultiMeters PanelMaster PartyFrameEnhanced PrettyChat WhatGroup; do
    echo "== $a"; git -C "$G/$a" log --oneline master..chore/libka0s-v1.45.0
done
git -C "$G/PartyFrameEnhanced" log --oneline chore/libka0s-v1.45.0..feat/switched-sections
```

Expected: Aura Master `T1`…`T18` (T12 the plan-only commit) plus this task's; LibKa0s the two
release commits, the tag, the step-9 docs commit, `ahead` of `origin/master` (nothing pushed); one
`Re-vendor LibKa0s v1.45.0` per consumer; one PFE adoption commit. Every working tree clean.

- [ ] **Step 5: Hand back to the owner — and STOP**

Report, in this order:
1. **The branches to merge and push** (Step 4's table): Aura Master `feat/smoke-feedback`; LibKa0s
   `master` (push its commits and the tag); ten `chore/libka0s-v1.45.0`; PFE `feat/switched-sections`
   (after its chore branch). Nothing is merged or pushed until the owner says so.
2. **Decisions that need the owner's yes** (made by this plan, visible to players): the Containers
   page's first tab renamed **General** and the `options-ui-§14` deviation row retired (D-2); the
   **None** dispel swatch retired, a typeless aura now taking each surface's own color (D-7); the
   Layout → Anchor and PFE Size & Position switch from dimmed to hidden (D-4: no deviation and no
   standard change; an optional harvest sentence for options-ui-§6 is theirs to take upstream).
3. **Task 12 is built**: three opt-in stand-ins for text colored by dispel type (the dispel word
   in color, a backdrop, an edge), all off by default; smoke items 130–132.
4. **The in-game checks**: smoke section T (117–132) and PFE's 31a; item 123's three probe outputs
   decide whether the `( )` was H1, H2 or the empty-string width, and whether anything more is owed.
5. **The battery numbers** of every repo, and any repo Task 17 skipped.

Do not merge, push, tag or bump a version.

- [ ] **Step 6: Update the Status ledger row for this task (status, commit SHAs, repo) and the resume guide's "Current position" line; commit the plan file with the task's commit**

Row 19 → `done` with the SHA. Current position → "Complete but for the owner: the
merges and pushes (Task 19 Step 5), and the in-game checks (smoke section T)." Commit: `T19: final
gate — smoke section T (117-132), inventory N, tests N/N, lint 0/0, lizard 0 warnings, perf green`,
with this plan file.
