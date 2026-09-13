# Feedback batch 5 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the owner's 2026-09-13 feedback on Aura Master. That covers:
- the panel restructure (General takes over the Containers page's controls, the spell lists and
  the dispel colors);
- a category grid;
- Layout anchoring that dims what does not apply and inherits the parent's flow;
- ten bug fixes;
- a new LibKa0s ID-list widget adopted in four addons.

**Architecture:** LibKa0s v1.35.0 adds three things to `LibKa0s-Options-1.0`'s widget file: generic
`disabledIf` plus a page-level disable, `ChoiceGrid`, and `IdInput`/`IdList`. AM fixes its
render-path bugs first. It then lands schema v2 (profile-wide spell lists and dispel colors, the
Healing merge, strata HIGH), re-vendors the library, and restructures the panel. ConsumableMaster,
BankLedger and LootHistory re-vendor and adopt the widget on their own branches.

**Tech Stack:** Lua 5.1 (WoW Retail 12.1), Ace3, LibKa0s, the headless harness `lua tests/run.lua`,
`luacheck`, `lizard`.

**Spec:** `docs/superpowers/specs/2026-09-13-feedback-batch5-design.md`. Requirement IDs (`C-4`,
`B-5`, …) are the spec's; read both.

## Global Constraints

- **Green gate before EVERY commit, in the repo being committed:** `lua tests/run.lua` (all green)
  and `luacheck .` (`0 warnings / 0 errors`). Complexity:
  `lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .` shows no function above CCN 15 (recorded,
  kept at zero).
- **Commits** go on feature branches only. The owner authorized checkpoint commits (2026-09-13).
  **No push, no merge to master, and no tag push without the owner's instruction.** A *local* tag
  `v1.35.0` in LibKa0s is required by the adopters' `tests/test_vendor_sync.lua`, and it is created
  locally only.
- **Branches:** AM `feat/2026-09-13-feedback-batch5`; LibKa0s `feat/2026-09-13-v1.35.0`;
  ConsumableMaster, BankLedger and LootHistory `feat/2026-09-13-idlist`.
- **Commit trailers:** every commit message ends with the two attribution lines this session's
  system prompt specifies (`Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>` and
  the `Claude-Session:` line).
- **The standard:** the Ka0s WoW Addon Standard (`../WowAddonStandards/standards/standards/*.md`) is
  binding. The ONE accepted deviation is options-ui-§14 (spec D1). Any other deviation found
  mid-task STOPS that task and is reported, never silently taken (CLAUDE.md).
- **TDD:** every bug gets a failing test first; every feature gets a test first. A test comment
  names the mutation it dies under ("red under: …"), in the repo's existing style.
- **Defaults:** every default lives in `defaults/Profile.lua` only (savedvariables-§2). Every
  settings write goes through `NS.SetByPath`. User-visible strings go through `NS.L`, with the key
  added to `locales/enUS.lua`. Use US spelling (`tests/test_docs.lua` enforces it).
- **Line endings:** the working tree is CRLF (`.gitattributes`). New files must match, and
  `tests/_kit/test_eol.lua` checks it.
- **No version bump of any addon.** Only LibKa0s gets a release version (v1.35.0).
- **Blizzard behavior claims** are verified against wow-ui-source `live`
  (https://github.com/Gethe/wow-ui-source, `Interface/AddOns/Blizzard_AuraContainer*` /
  `Blizzard_SharedXML*`). They are recorded in `docs/superpowers/research/2026-09-13-aura-engine-notes.md`
  (Task R0) before code relies on them.

---

## Status ledger (UPDATE AFTER EVERY TASK — this is the resume point)

**How to resume:**
1. Read this table.
2. Run `git -C <repo> log --oneline -15` for each repo in the Branches line above.
3. Continue at the first row that is not `done`.
4. A Workflow run can be resumed with `Workflow({scriptPath, resumeFromRunId})` using the run ids
   recorded below.
5. Never redo a `done` row. Its commit is the proof.

| Task | Req | Repo | Status | Commit | Notes |
|---|---|---|---|---|---|
| P0 spec + plan | — | AM | done | (this commit) | |
| R0 engine research | B-3 B-4 G-3 I-1 I-2 L-3 | AM | done | 370d5c0 | notes file |
| A1 disabledIf + page disable | X-3 | LibKa0s | done | c64e5ee | nested renders inherit; rows w/o disabledIf untouched |
| A2 ChoiceGrid | X-2 | LibKa0s | done | 54ac640 07704ad | spec.disabled added; review fix 07704ad |
| A3 IdInput / IdList | X-1 | LibKa0s | done | a833a4c | landed from the salvaged run; kit 20 opt-in mock_ids.lua |
| A4 release v1.35.0 (local tag) | X-4 | LibKa0s | done | 07e55cd 98eddd3 | Options 18.16.5.3 (W16), kit 20; local tag v1.35.0 on 98eddd3, NOT pushed; **CP-A reached** |
| B1 preview style switch | C-4 | AM | done | 1020798 | Style.RegionsFor + per-style preview pools |
| B2 apply error isolation | B-5 | AM | done | 6e9739c | xpcall + Style.WithStack, geterrorhandler |
| B3 justify width | B-5 | AM | done | c138d55 | ApplyText boxWidth; bar time unboxed while name stops at it |
| B4 dispel color order | B-4 | AM | done | e94f771 | additive bindings cleared first in both styles; fill shown each dress |
| B5 icon border color | I-1 | AM | done | f5ec19c | dispel art on its own frame above our border; icon frame levels set in build |
| B6 countdown rounding | I-2 | AM | done | 2280071 | every format RoundUp; Blizzard format a round-up copy of the engine default |
| B7 world-tooltip bleed + strata | L-3 | AM | done | 3197c05 | placeholders hold the hover (Style.TakesHover); strata HIGH; **CP-B reached** |
| C1 schema v2 migration + defaults | G-2 G-3 L-3 §7 | AM | done | 835d095 | v2 over every profile; readers repointed; sparkTimeless/iconBorder* keys deferred to D6 |
| C2 consumers read profile sets | G-2 G-3 | AM | done | 09038bf | icons bind the profile dispel map; profile-wide writes re-apply every container; **CP-C reached** |
| D1 re-vendor v1.35.0 | X-4 | AM | done | 9ba3d01 | Options 18.16.5.3, kit 20; four no-op stub members |
| D2 General → Containers; retire page | G-1 C-3 D1 | AM | done | bbdf178, fixes d7600d9 38747fe 6d87ee8 | picker + New in the tab body; RenderTabbedPage; container.name noReset; D1 deviation row. Review fixes: lint gate red at bbdf178 (length operator on an if line) restored; C-3 and OpenOptionsPage tests strengthened; Reset all out of noReset scope recorded in settings-panel.md |
| D3 Spell Categories + Dispel Colors | G-2 G-3 | AM | done | e697a4f, e20a014 | IdList over profile categorySpells; dispel rows on General; Filters Spell lists tab gone; bespoke tab `before` |
| D4 Filters grid + Overrides | F-1 F-3 | AM | done | fe556b2 | ChoiceGrid per grid key on a bespoke Categories tab; Overrides IdLists; /am get prints labels via Slash format hook |
| D5 Layout tabs, subsections, dimming | L-1 L-2 L-5 | AM | done | 1514e59 | onlyIn(mode) disabledIf per subsection; Pick via pairWith (spec.pairWith plumbed); test_schema disabledIf ban scoped to color rows |
| D6 Bars Icon tab, wrong-style, spark | B-1 B-2 B-3 B-6 | AM | done | 8174c2e | Icon tab + iconBorder* block; spec.disabledFor/disabledNotice page disable; sparkTimeless by clip frame (option 2, in-game check smoke 26); **CP-D reached** |
| E1 inherited flow + derived points | L-6 | AM | done | bcc54f3 | EffectiveLayout/DerivedPoints/Followers; Growth rows dimmed via panel-only row panelGet |
| E2 attached handle in preview | L-4 | AM | done | a27d172 | Preview.Extent + Anchors.PlaceAttached; strip level set per placement; **CP-E reached** |
| F1 render coverage test | B-5 | AM | done | 078eef9 53ba33b 025ab2d, lint fix af3b3bc | walk found preview time format + running-out color (fixed); smooth/pandemic engine-only |
| F2 docs | §9 | AM | todo | | **CP-F** |
| G1 ConsumableMaster IdInput | X-4 | CM | todo | | needs CP-A |
| G2 BankLedger IdList | X-4 | BL | todo | | needs CP-A |
| G3 LootHistory IdList | X-4 | LH | todo | | needs CP-A; **CP-G** |
| H1 adversarial review + fixes | all | all | todo | | |
| H2 final battery + report | all | all | todo | | **CP-H** |

Workflow runs: `wf_0af661b7-6d2` (A1-A2, R0, B1-B7) · `wf_8e85fdd5-5fa` (A3, A4, C1, C2; D+ and G not reached because of a script matcher bug) · run 3 (D1-F2, G1-G3)

**Dependency order:**
- R0, A* and B1–B3 can run concurrently (different repos, or independent files).
- B4–B7 follow R0.
- C follows B.
- D1 needs A4. D follows C and D1.
- E follows D. F follows E.
- G1–G3 need A4 only and can run concurrently with C–F (different repos).
- H is last.

**Checkpoint rule:** a CP row is reached only when:
- every row above it in its phase is `done`;
- the phase's repo gate is green;
- this ledger is committed with the phase's last commit.

---

## File structure

| File | Change | Responsibility after |
|---|---|---|
| `../LibKa0s/LibKa0s/OptionsWidgets.lua` | modify | + generic `disabledIf`, `RenderRows` `opts.disabled`, `ChoiceGrid`, `IdInput`, `IdList` |
| `../LibKa0s/testkit/mock_base.lua` (+ `tests/_kit/`) | modify | name lookups for `C_Spell` / `C_Item` / `C_CurrencyInfo`; `Kit.VERSION` bump |
| `modules/Preview.lua` | modify | one pool per style |
| `modules/Style.lua` | modify | `__am` style tag; text box width; profile dispel map |
| `modules/Style_Bars.lua` | modify | dispel clear order; icon border; spark-timeless |
| `modules/Style_Icons.lua` | modify | border fix (R0); style tag |
| `modules/ContainerManager.lua` | modify | per-container apply isolation |
| `core/Compat.lua` | modify | round-up formatter; a "blizzard" formatter |
| `core/Database.lua` | modify | `SCHEMA_STEPS` v2 |
| `defaults/Profile.lua` | modify | profile `categorySpells`, `dispelColors`; template changes |
| `defaults/Categories.lua` | modify | `healing` replaces `coreHealing` + `lesserHealing` |
| `modules/FilterCompiler.lua` | modify | spell edits from the profile |
| `modules/Anchors.lua` | modify | derived points, effective flow, preview extent |
| `modules/Container.lua` | modify | effective flow in `FlowSettings` |
| `settings/Schema.lua` | modify | absolute carve-out `categorySpells`; `noReset` honored by `ApplyDefault` |
| `settings/OptionsSetup.lua` | modify | generalized tab renderer (General uses it), `intro` page-disable, strings |
| `settings/General.lua` | modify | five tabs |
| `settings/GeneralContainers.lua` | **create** (from `settings/Containers.lua`) | the Containers tab's rows and acts |
| `settings/GeneralSpells.lua` | **create** | Spell Categories and Dispel Colors tabs |
| `settings/Containers.lua` | **delete** | — |
| `settings/Filters.lua` | modify | grid, Overrides; Spell lists removed |
| `settings/Layout.lua` | modify | tab order, subsections, dimming, inheritance display |
| `settings/Bars.lua`, `settings/Icons.lua` | modify | Icon tab, wrong-style disable, spark row |
| `AuraMaster.toc` | modify | file list (two new settings files, one removed) |
| `locales/enUS.lua` | modify | new and renamed keys |
| `tests/test_pages_general.lua` | modify | + Containers / Spell Categories / Dispel Colors |
| `tests/test_pages_containers.lua` | **delete** | cases moved to `test_pages_general.lua` |
| `tests/test_render_coverage.lua` | **create** | every Bars/Icons row reaches a region |
| docs | modify | §9 of the spec |

`tests/run.lua` declares its suites. Every created or deleted suite is added to or removed from that
list in the same task (`Kit.run` fails on a mismatch).

---

## Task R0: Aura engine research (read-only, writes one notes file)

**Files:** Create `docs/superpowers/research/2026-09-13-aura-engine-notes.md`.

- [ ] **Step 1: Fetch the sources.** Fetch the Blizzard aura container sources from wow-ui-source
  `live`. Start at the repo tree and find `Blizzard_AuraContainer` / `CustomAuraContainer` /
  `CustomAuraButton` and `SecondsFormatter`.
- [ ] **Step 2: Answer each question with a quoted source line and path.**
  1. **B-4:** What do `ClearDispelTypeTextures` and `AddDispelTypeTexture` (with style
     `PreserveAsset`, `showAlways`, `showWithoutDispelType`) do to a region: vertex color, texture,
     `Hide`/`Show`? Does Clear restore anything?
  2. **G-3:** Does `AddDispelTypeTexture` with the `Border` style honor `customDispelColorMap`?
  3. **I-1:** Where does the `Border` dispel style draw (texture, layer, size), and for a harmful
     aura with no dispel type, does it show?
  4. **I-2:** Which rounding does the engine's default duration text use when no `textFormatter` is
     given? Which does a `Cooldown` frame's countdown use? Which `Enum.SecondsFormatterRounding`
     members exist?
  5. **B-3:** Is there any binding that shows, hides or alpha-curves a region by whether the aura has
     a duration (a "permanent" flag, a curve over `RemainingDuration`, a texture binding with
     `showWhen*`)? Does `SetDurationBar` hide or reset the StatusBar for a permanent aura, and what
     value does it hold (0 elapsed)?
  6. **L-3:** How does a `CustomAuraButton` enable mouse (template attributes, `SetMouseMotionEnabled`
     defaults, hit rect)? Does the tooltip code call `GameTooltip:SetOwner` so that a world
     mouseover could also populate it?
- [ ] **Step 3: Record the notes.** Write the notes file: one section per question — answer, quoted
  evidence, and the implication for our fix. Mark any question the source cannot settle as
  **UNSETTLED — in-game check required**, and add that check to `docs/smoke-tests.md` in the owning
  task.
- [ ] **Step 4: Commit.** `git add docs/superpowers/research && git commit -m "docs: aura engine research notes for batch 5"`

---

## Phase A — LibKa0s v1.35.0 (repo `../LibKa0s`, branch `feat/2026-09-13-v1.35.0`)

Before starting: `git -C ../LibKa0s checkout -b feat/2026-09-13-v1.35.0` from `master`. Read
`docs/releasing.md` in full, and read the Options API doc for minor 18
(`docs/api/Options/version-18.15.5.3-docs.md`).

### Task A1: Generic `disabledIf` and a page-level disable (X-3)

**Files:** Modify `LibKa0s/OptionsWidgets.lua` (the makers `makeCheckbox`, `makeSlider`,
`makeDropdown`, `makeEditBox`, the LSM media makers, and `makeColorPicker` near `:1683`; also
`RenderRows` near `:1881`). Test `tests/test_options_widgets.lua`.

**Interfaces:**
- **Produces, `row.disabledIf`:** a settings path (string), OR `function(row) -> bool`. It is
  evaluated at build time and on every `RefreshScalars`, and calls `widget:SetDisabled(bool)`.
- **Produces, `O.RenderRows(ctx, rows, afterGroup, pairWith, opts)`:** `opts.disabled == true`
  disables every widget it draws, including after-group buttons drawn through `InlineButtonPair`
  during that call. It sets `ctx.__renderDisabled` for the call's duration, and `InlineButtonPair`
  reads it.
- **Unchanged:** the class-color swatch is still never disabled (`OptionsCompose.lua:228`).

- [ ] **Step 1: Write the failing tests.** Use the suite's existing fixture helper
  (`tests/fixture_options.lua`). Four cases, one per maker type, each with a path `disabledIf`, a
  function `disabledIf` and a `RefreshScalars` flip:

```lua
test("disabledIf: a function predicate disables a checkbox and re-evaluates on RefreshScalars", function()
    local O, store = fixture()             -- existing helper: instance + backing table
    store.mode = "screen"
    local row = { path = "x.flag", type = "bool", label = "Flag",
                  disabledIf = function() return store.mode == "screen" end }
    local w = O.RenderField(ctx(O), row, parentGroup(), 0.5)
    assertTrue(w.disabled, "screen mode disables the row")
    store.mode = "frame"; O.RefreshScalars()
    -- red under: evaluating disabledIf only at build time (the dimming would never lift)
    assertFalse(w.disabled)
end)
```

  Plus the same for slider, dropdown and edit box, a path-string form (`disabledIf = "x.off"`), and
  a `RenderRows(..., { disabled = true })` case asserting every drawn widget and an after-group
  `InlineButtonPair` button report `disabled`.
- [ ] **Step 2: Run the tests and watch them fail.** `lua tests/run.lua` — the new cases fail
  because non-color makers ignore `disabledIf`.
- [ ] **Step 3: Implement.** One local helper, used by every maker in place of the color picker's
  private `applyDisabled`:

```lua
local function isDisabled(ctx, row)
    if ctx and ctx.__renderDisabled then return true end
    local d = row.disabledIf
    if d == nil then return false end
    if type(d) == "function" then
        local ok, v = pcall(d, row)
        return ok and v and true or false
    end
    return readKey(row, d) and true or false
end
```

  Each maker calls `w:SetDisabled(isDisabled(ctx, row))` after building, and again in its
  `refresh` closure. The `ctx` captured at build keeps its `__renderDisabled` snapshot: store
  `local pageDisabled = ctx.__renderDisabled` at build time and use that in refresh, so a later
  render's flag cannot leak into an earlier page's widgets. `RenderRows` sets
  `ctx.__renderDisabled = opts and opts.disabled or nil` before its loop and clears it after.
  `InlineButtonPair` disables its buttons while the flag is set.
- [ ] **Step 4: Run the gate.** `lua tests/run.lua` — PASS. `luacheck .` — 0/0.
- [ ] **Step 5: Commit.** `git commit -am "Options: disabledIf on every maker (path or predicate) + RenderRows opts.disabled"`
  (the minor bump happens in A4).

### Task A2: `ChoiceGrid` (X-2)

**Files:** Modify `LibKa0s/OptionsWidgets.lua`; test `tests/test_options_widgets.lua`.

**Interfaces — `O.ChoiceGrid(ctx, spec)`:**
- `spec.rows`: schema rows. Each has `path` (or `get`/`set`), `label`, optional `tooltip`/`desc`,
  and optional `disabledIf`.
- `spec.columns`: `{ { value = "", label = "Default" }, { value = "show", label = "Whitelist" }, … }`.
- `spec.heading`: optional; drawn with `O.Section`.
- It draws one header line (the column labels, then `spec.labelHeader` or "Category"), then one
  line per row: a full-width Flow `SimpleGroup` holding N `CheckBox` widgets with
  `SetType("radio")` at relative width `0.12` each, then an `InteractiveLabel` for the rest of the
  width with the row's tooltip.
- Clicking a radio writes `column.value` through the file's `set(row, value)`, which runs
  `RefreshScalars`. Each radio's refresh sets `SetValue(read(row) == column.value)`.
- A value outside the columns lights no radio.
- Rows drawn by the grid should carry `skipRender = true`. The grid draws them regardless.
- Returns the list of line groups.

- [ ] **Step 1: Write the failing tests.**
  - header plus N lines;
  - a click writes the column value through `d.set`, and every radio on that line re-syncs (exactly
    one lit);
  - an out-of-list stored value lights none;
  - `disabledIf` and `opts.disabled` (A1) disable the radios;
  - the label tooltip is attached.
- [ ] **Step 2: Watch them fail.** Run the suite; the new cases fail.
- [ ] **Step 3: Implement `O.ChoiceGrid` after `RenderGrid`.** Reuse `O.Section`, `applyWidth` and
  `O.AttachTooltip`. Register each radio's refresh in `ctx.refreshers`, as the other makers do.
- [ ] **Step 4: Run the gate and commit.** Gate green, then
  `git commit -am "Options: ChoiceGrid — a matrix of radio cells over rows sharing one value list"`.

### Task A3: `IdInput` and `IdList` (X-1)

**Files:** Modify `LibKa0s/OptionsWidgets.lua` and `testkit/mock_base.lua` (then `Kit.VERSION` +1,
and copy `testkit/` → `tests/_kit/`). Test `tests/test_options_widgets.lua`.

**Interfaces:**
- **`O.ResolveId(kind, text, candidates)`**, a pure function, exported for tests. It returns
  `id, name, icon`, or `nil, reason` with reason `"notFound"` | `"ambiguous"` | `"empty"`.
- **Resolution order:**
  1. a number (`^%s*(%d+)%s*$`);
  2. a link (`|Hspell:(%d+)`, `|Hitem:(%d+)`, `|Hcurrency:(%d+)`, and the bare `spell:`, `item:`,
     `currency:` forms);
  3. the client name lookup: spell → `C_Spell.GetSpellInfo(text)` (`info.spellID`); item →
     `C_Item.GetItemInfoInstant(text)` (first return); currency → no client name lookup;
  4. the candidates: a case-insensitive exact name match over `candidates()` ids, resolved
     id → name through the same per-kind info API. Two matches → `"ambiguous"`.
- **Custom kinds:** `kind` may be a table `{ resolve = function(text) -> id|nil, name, icon }`,
  which replaces steps 3–4.
- **`O.IdInput(ctx, parent, spec)`:**
  - `spec`: `kind`, `label`, `tooltip`, `onAdd(id)`, `candidates()`.
  - Draws: an `EditBox` (relative width 0.78) plus an `Add` button (0.20, the `BUTTON_PAIR_REL`
    rule's spirit), and an inline status `Label` under them.
  - Enter or Add resolves the input. Success calls `onAdd(id)` and clears the box. Failure writes
    the reason in orange (`"No spell named 'x'."`, `"Several spells are named 'x' — use the id."`)
    and adds nothing.
- **`O.IdList(ctx, spec)`:**
  - `spec`: everything `IdInput` takes, plus `entries()` → `{ { id, toggle, on } }`, `onRemove(id)`,
    `onToggle(id, on)`, and `emptyText`.
  - Draws: the heading (optional `spec.heading`), the input, then one line per entry: icon, name and
    `(id)` in gray, then a `Remove` button, or a `CheckBox` for a `toggle` entry.
  - An unknown id reads `"Unknown <kind> <id>"`. An uncached item calls `lib.LoadItem(id, cb)` if
    LibKa0s-Item is present; the `cb` asks the host to re-render through `ctx.rebuild` if set,
    else `O.RefreshAllPanels()`.
- **Kit:** `mock_base` gains name-keyed tables `Kit.spellsByName` / `Kit.itemsByName` that
  `C_Spell.GetSpellInfo(name)` / `C_Item.GetItemInfoInstant(name)` consult, plus a
  `C_CurrencyInfo.GetCurrencyInfo(id)` stub.

- [ ] **Step 1: Write the failing tests for `ResolveId`.** Cover: a number; each link form; a name
  via the client; a name via the candidates; ambiguous; not found; empty; a custom resolver table.

```lua
test("ResolveId: a spell name the client knows resolves to its id", function()
    Kit.spellsByName["Power Word: Fortitude"] = { spellID = 21562, name = "Power Word: Fortitude", iconID = 135987 }
    local id, name = O.ResolveId("spell", "power word: fortitude")
    -- red under: a case-sensitive lookup (players type names in lower case)
    assertEqual(id, 21562); assertEqual(name, "Power Word: Fortitude")
end)
```

  (The mock lookup is case-insensitive, as the client's is.)
- [ ] **Step 2: Write the failing tests for the widgets.**
  - Enter with a valid name calls `onAdd` once and clears the box.
  - An invalid name shows the reason and does not call `onAdd`.
  - `IdList` draws one line per entry. Remove calls `onRemove(id)`. A toggle entry's checkbox calls
    `onToggle(id, false)`.
  - An empty list shows `emptyText`.
- [ ] **Step 3: Watch them fail.** Run the suite; the new cases fail.
- [ ] **Step 4: Implement.** Implement `ResolveId`, then `IdInput`, then `IdList`, all in
  `OptionsWidgets.lua` after `ChoiceGrid`. Keep each function under CCN 15 by splitting the parsing
  helpers (`parseNumber`, `parseLink`, `byClientName`, `byCandidates`).
- [ ] **Step 5: Update the kit.** Change the mock, bump `Kit.VERSION`, and re-copy `testkit/` into
  `tests/_kit/` (`tests/test_kitsync.lua` must pass).
- [ ] **Step 6: Run the gate and commit.** Gate green, then
  `git commit -am "Options: IdInput/IdList — add by id, link or name (spell/item/currency); kit name lookups"`.

### Task A4: Release v1.35.0 (local tag only) — CP-A

Follow `docs/releasing.md` steps 2–7 exactly:

- [ ] Bump `WIDGETS_MINOR` in `OptionsWidgets.lua`. Bump `MINOR` in `Options.lua` only if
  `Options.lua` changed. `Kit.VERSION` was already bumped in A3.
- [ ] Write the `CHANGELOG.md` block for v1.35.0: every file's new minor, and the three additions.
- [ ] Write `docs/api/Options/version-<new key>-docs.md`: Status Current, Supersedes, "What changed",
  and `Since` on `disabledIf` (every maker), `RenderRows opts.disabled`, `ChoiceGrid`, `IdInput`,
  `IdList` and `ResolveId`. Mark the old document Superseded, with its closing section. Add the row
  to `docs/api/README.md`.
- [ ] Regenerate the manifests with `lua tools/gen-api-members.lua`, and regenerate
  `docs/test-cases.md` per its banner.
- [ ] Move every version-bearing line to 1.35.0 (step 7 of `releasing.md`), then run the gate green.
- [ ] `git commit -am "LibKa0s v1.35.0: disabledIf everywhere, ChoiceGrid, IdInput/IdList (Options <minor>, kit <n>)"`.
- [ ] `git tag -a v1.35.0 -m "LibKa0s v1.35.0"`. This is **local only: never pushed** without the
  owner.
- [ ] Update the ledger (A1–A4 done, CP-A).

---

## Phase B — AM render-path bug fixes (AM branch)

### Task B1: A preview frame never reuses another style's regions (C-4)

**Files:**
- Modify `modules/Style_Bars.lua` (`build` :29, `Bars.Apply` :158);
  `modules/Style_Icons.lua` (`build` :20, `Icons.Apply` :88); `modules/Preview.lua` (`Show` :61,
  `Hide` :92).
- Test `tests/test_preview.lua`.

**Interfaces:** Produces `frame.__am.style` (`"bars"` | `"icons"`) and
`container.previewPools[style]`. `container.previewPool` is removed; update any test seam that reads
it.

- [ ] **Step 1: Write the failing test.**

```lua
test("preview: switching a previewed container from bars to icons re-dresses without error", function()
    local NS = fresh()
    NS.SetByPath("locked", false)                       -- previewing
    flush(NS)                                           -- the suite's existing apply-flush helper
    local inst = NS.ContainerManager.instances[1]       -- Player buffs, bars
    assertTrue(inst.previewShown)
    NS.SetByPath("container.style", "icons", 1)
    -- red under: reusing a bars-built __am for icons (Style_Icons.lua:80 'attempt to index cd')
    flush(NS)
    assertTrue(inst.previewShown, "the preview re-drew as icons")
end)
```

  Add the icons → bars mirror, and a Duplicate-then-switch case reproducing the owner's steps
  (`ContainerManager.Duplicate(1)` while unlocked, then set the copy's style to icons).
- [ ] **Step 2: Watch them fail.** `lua tests/run.lua` — FAIL with the `cd` nil index in
  `Style_Icons.lua`.
- [ ] **Step 3: Implement.**
  - **Tag the regions.** In each `build`, set `am.style = "bars"` / `"icons"`.
  - **Rebuild on a mismatch.** In each `Apply`, replace `local am = frame.__am or build(frame)` with
    `local am = Style.RegionsFor(frame, "bars", build)`. Add to `modules/Style.lua`:

```lua
--- The regions `frame` carries for `style`, building them when absent or built for the other style.
--- The other style's regions are hidden, never destroyed: frames are never freed in WoW.
function Style.RegionsFor(frame, style, build)
    local am = frame.__am
    if am and am.style == style then return am end
    if am then Style.HideRegions(am) end
    frame.__amByStyle = frame.__amByStyle or {}
    am = frame.__amByStyle[style]
    if am then frame.__am = am; Style.ShowRegions(am); return am end
    am = build(frame)
    frame.__amByStyle[style] = am
    return am
end
```

  (`HideRegions` / `ShowRegions` walk the table's frame and texture values, calling `Hide`/`Show`.)
  - **Split the pool per style.** In `Preview.Show`, use
    `container.previewPools = container.previewPools or {}` and
    `local pool = container.previewPools[cfg.style]`, created on demand. Release every pool, not
    just this style's, before acquiring. In `Preview.Hide`, release every pool.
- [ ] **Step 4: Run the gate.** All green.
- [ ] **Step 5: Commit.** `git commit -am "Fix: a previewed container switched between bars and icons re-dresses cleanly (C-4)"`.

### Task B2: One failing container never stops an apply pass (B-5)

**Files:** Modify `modules/ContainerManager.lua` (`applyDirty` :190). Test
`tests/test_containermanager.lua`.

- [ ] **Step 1: Write the failing test.**

```lua
test("apply: an error in one container's Apply does not stop the others or replaceAttached", function()
    local NS = fresh()
    local CM = NS.ContainerManager
    local boom = CM.instances[1]
    local real = boom.Apply
    boom.Apply = function() error("boom") end
    local applied2 = 0
    local inst2 = CM.instances[2]; local real2 = inst2.Apply
    inst2.Apply = function(self) applied2 = applied2 + 1; return real2(self) end
    CM.RequestApply(); CM.FlushPending()
    -- red under: an unguarded inst:Apply() in applyDirty (container 2 silently never applies)
    assertEqual(applied2, 1)
    boom.Apply = real
end)
```

  Also assert that the error is reported once. Spy `NS.Print` or the existing error path, whichever
  the suite already uses for errors.
- [ ] **Step 2: Watch it fail.** Run the suite; the new case fails.
- [ ] **Step 3: Implement.** In `applyDirty`, run each `inst:Apply()` through `xpcall` with
  `Style`'s `withStack` handler. Expose it as `NS.Style.WithStack`, or move it to `NS.ErrorWithStack`
  in `core/CoreSetup.lua` if `Style` is the wrong owner. On failure, hand the error to
  `geterrorhandler()(err)` (BugSack shows it, and the loop continues), then continue. Count only
  successes.
- [ ] **Step 4: Run the gate and commit.** Gate green, then
  `git commit -am "Fix: a container whose apply raises no longer drops the rest of the pass (B-5)"`.

### Task B3: Justify has a box to justify within (B-5)

**Files:** Modify `modules/Style.lua` (`Style.ApplyText` :93) and its three call sites in
`Style_Bars.lua` (`applyTexts` :144) and `Style_Icons.lua` :99. Test `tests/test_style.lua`.

**Interfaces:** `Style.ApplyText(fs, t, anchorTo, tdef, boxWidth)`. `boxWidth` is the width
available to the text, or nil for no box.

- [ ] **Step 1: Write the failing test.** Using the region recorder, `ApplyText` with
  `justify = "RIGHT"` and a box width of 200 records `SetWidth(200 - |x|)` and `SetJustifyH("RIGHT")`.
  Without a box, no `SetWidth` is recorded. For bars, the name / time / stacks boxes are the bar
  area's width; for icons, the icon's width.

  ```lua
  -- red under: a single-anchor FontString with no width (justify has nothing to align within)
  ```
- [ ] **Step 2: Watch it fail.** Run the suite; the new case fails.
- [ ] **Step 3: Implement.** After `SetPoint`, when `boxWidth` is set, call
  `fs:SetWidth(math.max(1, boxWidth - math.abs(tonumber(t.x) or 0)))`; otherwise call
  `fs:SetWidth(0)` (auto). Bars pass the bar-area width (`barAreaWidth` already exists :215, so
  hoist it above `applyTexts`). The name's extra `RIGHT` anchor to the time text stays: two anchors
  override the width. Icons pass the icon width.
- [ ] **Step 4: Run the gate and commit.** Gate green, then
  `git commit -am "Fix: text justify now takes effect — each text gets a box (B-5)"`.

### Task B4: Color by → dispel type lets go (B-4) — after R0

**Files:** Modify `modules/Style_Bars.lua` (`Bars.Apply` :158, `Bars.Bind` :180, `FillPreview`
:223). Test `tests/test_style_bars.lua`.

- [ ] **Step 1: Write the failing test** from R0's answer 1. Toggle static → dispel → static on a
  live (engine) button through `Style.Element(frame, cfg, true)`. Assert that
  `ClearDispelTypeTextures` is recorded **before** the final `SetVertexColor` on `am.fill`, that the
  final color is `barColor`, and that `am.fill` is shown. Do the same on a preview element through
  `Preview.Show` (no Magic tint left after switching back).
- [ ] **Step 2: Watch it fail.** Run the suite; the new case fails.
- [ ] **Step 3: Implement.** Move `Style.Bind(frame, "ClearDispelTypeTextures")` to the top of
  `Bars.Apply` (engine only), before `applySurfaces`. `Bind` then only adds. If R0 shows that Clear
  hides the region, `applySurfaces` also calls `am.fill:Show()`. In `FillPreview`, compute the tint
  as `dispel and Magic or barColor` every time, so a later static dress is never left tinted.
- [ ] **Step 4: Run the gate and commit.** Gate green, then
  `git commit -am "Fix: switching a bar's Color by away from dispel type restores its color (B-4)"`.

### Task B5: Icon border color shows (I-1) — after R0

**Files:** `modules/Style_Icons.lua`; test `tests/test_style_icons.lua`.

- [ ] **Step 1: Confirm the cause** from R0 answer 3 and the recorder. Look at the frame levels of
  `am.border` vs `am.cd`, and at the dispel texture's layer and extent. Write the chosen cause into
  the commit message.
- [ ] **Step 2: Write a failing test** for that cause. For example: the border frame's level must be
  above the cooldown's; or, with `dispelBorder` on and a helpful aura, our border is shown and the
  dispel texture is not bound over it.
- [ ] **Step 3: Implement the fix.** For example, `am.border:SetFrameLevel(am.cd:GetFrameLevel() + 1)`,
  and draw the dispel border texture inside the border frame at the border's inset rather than full
  frame. Then update the `dispelBorder` row's `desc` in `settings/Icons.lua`: "Where a debuff has a
  dispel type, this border replaces yours in the dispel color."
- [ ] **Step 4: Run the gate and commit.** Gate green, then `git commit -am "Fix: icon border color shows (I-1)"`.

### Task B6: The countdown agrees with Blizzard's numbers (I-2) — after R0

**Files:** `core/Compat.lua` (`CreateSecondsFormatter` ~:136), `modules/Style.lua` (`formatterFor`
:157). Test `tests/test_compat.lua`.

- [ ] **Step 1: Write the failing test.** The mock records formatter calls, so assert:
  - `CreateSecondsFormatter("short")` calls `SetRounding` with R0's round-up member (for example
    `Enum.SecondsFormatterRounding.RoundUp`);
  - `CreateSecondsFormatter("blizzard")` now returns a formatter, set up like the short one but with
    R0's cooldown-countdown settings.

  Add the enum member to `tests/wow_mock.lua` if it is missing.
- [ ] **Step 2: Watch it fail.** Run the suite; the new case fails.
- [ ] **Step 3: Implement** per R0. If R0 finds that no round-up rounding exists, emulate it: a
  custom `textFormatter` is not possible on secret values, so record that in the notes and the
  smoke tests, and stop that sub-item with a note in the ledger (do not guess).
- [ ] **Step 4: Run the gate and commit.** Gate green, then
  `git commit -am "Fix: time text rounds up like the cooldown countdown (I-2)"`.

### Task B7: World tooltips behind a bar or icon, and strata (L-3) — CP-B

**Files:**
- `modules/Style.lua` (`ApplyBehavior` :272), `modules/Preview.lua` (`factory` :50),
  `defaults/Profile.lua` (template `layout.strata`).
- Tests `tests/test_style.lua`, `tests/test_preview.lua`.

- [ ] **Step 1: Confirm the cause** from R0 answer 6.
  - If preview frames are the cause (`EnableMouse(false)`), placeholders should block the world:
    `f:EnableMouse(true)` with no scripts. They have no aura to tooltip, so nothing shows, and the
    world is blocked.
  - If engine buttons are the cause, fix their mouse enabling per R0.
- [ ] **Step 2: Write a failing test for the chosen cause, then implement.**
- [ ] **Step 3: Raise the default strata.** The template `layout.strata` default becomes `"HIGH"`
  (C1 migrates stored `MEDIUM`). `tests/test_defaults.lua` pins the new default.
- [ ] **Step 4: Add the smoke check.** Add a smoke-test row to `docs/smoke-tests.md`: "Hover a
  bar/icon over a world unit — only the aura tooltip shows."
- [ ] **Step 5: Run the gate, commit and checkpoint.** Gate green, then
  `git commit -am "Fix: hovering a container no longer shows the world unit's tooltip; strata defaults to High (L-3)"`.
  Ledger CP-B.

---

## Phase C — Schema v2

### Task C1: Migration, defaults, the Healing merge

**Files:**
- `core/Database.lua` (`SCHEMA_STEPS` ~:259, `CurrentSchemaVersion`); `defaults/Profile.lua`;
  `defaults/Categories.lua` (lines 116–136); `settings/Schema.lua` (carve-outs, `NS.IsSection`,
  validator for absolute `categorySpells` / `dispelColors.*`).
- Test `tests/test_database.lua`, `tests/test_defaults.lua`, `tests/test_schema.lua`.

**Interfaces:**
- **Profile:** `profile.categorySpells = { [key] = { [id] = true | false } }` and
  `profile.dispelColors = { Magic = {r,g,b,a}, … }` (the defaults come from
  `C.DEFAULT_DISPEL_COLORS` through `dispelColors()`, moved to `NS.defaults.profile`).
- **Template changes:** the container template loses `filter.categorySpells` and
  `bars.dispelColors`. `layout.strata = "HIGH"`. `bars.sparkTimeless = true`. `bars.iconBorderShow
  = false`, `iconBorderStyle = "Solid"`, `iconBorderSize = 1`, `iconBorderColor = color(0,0,0,1)`,
  `useClassColorIconBorder = false`.
- **Categories:** `Cat.HELPFUL` replaces `coreHealing` and `lesserHealing` with one entry
  `{ key = "healing", kind = "spells", label = "Healing", desc = "Heal-over-time effects, shields and
  beacons.", spells = <union of both lists> }`, placed where `coreHealing` was.
- **`Database.MigrateV2(profile)`** is a pure function over one profile table, exported for tests.

- [ ] **Step 1: Write the failing migration tests.** Each builds a raw v1 profile table and calls
  `MigrateV2`:
  1. **Additions union.** Container 1 adds 111 to `defensives` and container 2 adds 222, so
     `profile.categorySpells.defensives == {[111]=true,[222]=true}`.
  2. **Removals kept only when unanimous.** Starter 871 removed by container 1 only → not removed.
     Removed by both containers that have edits for that key → `[871] = false`. A container with no
     edit for the key does not veto.
  3. **Healing merge, spells.** `coreHealing` add 5 and `lesserHealing` add 6 →
     `healing = {[5]=true,[6]=true}`. The old keys are gone from `categorySpells` and from every
     container's `filter.categories`.
  4. **Healing merge, states.** `{show,""}` → show; `{"",hide}` → hide; `{hide,show}` → show;
     `{"",""}` → `""`.
  5. **Dispel colors.** The first container in `containerOrder` with `bars.colorMode == "dispel"`
     wins. Otherwise the first container's `bars.dispelColors`; with no containers, the defaults.
     `bars.dispelColors` is removed from every container.
  6. **Strata.** Stored `"MEDIUM"` becomes `"HIGH"`; `"LOW"` stays `"LOW"`.
  7. **`filter.categorySpells`** is removed from every container.
  8. **Every profile.** `NS.RunMigrations` applies `MigrateV2` to every entry of
     `AuraMasterDB.profiles` (a non-active profile included), stamps `schemaVersion = 2`, and logs
     one `[Migrate]` line per profile. A second run is a no-op.

  Plus: `CurrentSchemaVersion() == 2`; the schema validator resolves `categorySpells` and
  `dispelColors.Magic`; a fresh profile carries both defaults.
- [ ] **Step 2: Watch them fail.** Run the suite; the new cases fail.
- [ ] **Step 3: Implement.**
  - `MigrateV2`: one local per rule, each a small function (`mergeSpellEdits`,
    `mergeHealingStates`, `liftDispelColors`, `raiseStrata`), keeping each under CCN 15.
  - Register it in `SCHEMA_STEPS`.
  - Move the template and default fields.
  - Update `Categories.lua`.
  - Schema: the absolute carve-out `categorySpells` goes through the existing carve-out normalizer
    for spell sets. `dispelColors.<type>` are plain color rows (added in D3).
- [ ] **Step 4: Update the migration record.** Update `docs/schema.md` → Migration path (v2
  bullets) and the profile table.
- [ ] **Step 5: Run the gate and commit.** Gate green, then
  `git commit -am "Schema v2: profile-wide spell lists and dispel colors, Healing merge, strata High"`.

### Task C2: Consumers read the profile sets — CP-C

**Files:**
- `modules/FilterCompiler.lua` (every `categorySpells` read); `modules/Style.lua`
  (`Style.DispelColorMap` callers); `modules/Style_Bars.lua` :196, :237; `modules/Style_Icons.lua`
  :123 (when R0 answer 2 says the Border style takes a map).
- `settings/Filters.lua` (the old Spell lists tab still compiles; it is removed in D4).
- Tests `tests/test_filtercompiler.lua`, `tests/test_style_bars.lua`, `tests/test_style_icons.lua`.

- [ ] **Step 1: Write the failing tests.**
  - `Compile(cfg, { timedSpells = …, categorySpells = profileSet })` uses the passed set. Both
    compile sites (`modules/Container.lua` Apply, `settings/OptionsSetup.lua` RenderWarnings) pass
    `NS.db.profile.categorySpells`.
  - A bar in dispel mode binds `customDispelColorMap` built from `NS.db.profile.dispelColors`.
  - A dispel-color write re-applies every container (a global row, no `effect`).
- [ ] **Step 2: Watch them fail.** Run the suite; the new cases fail.
- [ ] **Step 3: Implement.** `FilterCompiler.Compile` gains `opts.categorySpells` in place of
  `cfg.filter.categorySpells`. The styles read `NS.db.profile.dispelColors`. Keep the memo in
  `Style.DispelColorMap` keyed by the profile table.
- [ ] **Step 4: Run the gate, commit and checkpoint.** Gate green, then
  `git commit -am "Filter compiler and styles read the profile-wide spell lists and dispel colors"`.
  Ledger CP-C.

---

## Phase D — Re-vendor and restructure the panel

### Task D1: Re-vendor LibKa0s v1.35.0 into AM (X-4)

- [ ] Follow the `/wow-addon:revendor-libka0s` procedure by hand. Copy
  `../LibKa0s/LibKa0s/` → `libs/LibKa0s/` whole, and `../LibKa0s/testkit/` → `tests/_kit/` whole.
  Keep CRLF per `.gitattributes`.
- [ ] Change the `CLAUDE.md` provenance line to `v1.35.0`. Update `docs/ARCHITECTURE.md`'s
  "LibKa0s v1.35.0" mentions and `DEPENDENCIES.md`.
- [ ] Run the gate. `tests/test_vendor_sync.lua` must pass against the local `v1.35.0` tag.
  `tests/test_setups.lua` / `test_optionssetup.lua` may pin member sets; update those pins to the new
  surface, and the degradation stub if `Kit.assertSurfaceParity` requires the new members (per
  options-ui-§1: stub only what page files touch at load, and none of the new widgets is touched at
  load).
- [ ] `git commit -am "Re-vendor LibKa0s v1.35.0 (Options <minors>, kit <n>)"`.

### Task D2: General → Containers; the Containers page retires (G-1, C-3, D1)

**Files:**
- Create `settings/GeneralContainers.lua` from `settings/Containers.lua` (rows, acts, copy).
  Delete `settings/Containers.lua`.
- Modify `settings/General.lua`, `settings/OptionsSetup.lua` (`collectTabs`, `renderActiveTab`,
  `RenderContainerPage` :364–451), `settings/Schema.lua` (`ApplyDefault` honors `noReset`),
  `AuraMaster.toc`, `locales/enUS.lua`, the strings listed in spec §3, and `docs/ARCHITECTURE.md`
  (the D1 deviation row, verbatim from the spec).
- Tests: `tests/test_pages_general.lua` (gains the moved cases); delete
  `tests/test_pages_containers.lua` and drop it from `tests/run.lua`'s suite list.

**Interfaces:**
- **`Helpers.RenderTabbedPage(ctx, pageKey, spec)`** is extracted from `RenderContainerPage`: the tab
  collect, settle and render path, with no banner. `RenderContainerPage` becomes the banner plus
  `RenderTabbedPage`. General renders through
  `RenderTabbedPage(ctx, "general", { afterGroup = { [H.MASTER_GROUP] = masterTail, [L["Containers"]] = afterContainers }, tabs = { … } })`.
- **Schema rows:** `container.name`, `.enabled`, `.unit`, `.auraType` and `.style` become
  `page = "general", group = L["Containers"]`. `container.name` gains `noReset = true`.
- **The picker line:** the Containers tab's `intro`-equivalent draws the picker and New on one line
  inside the body (`H.RenderGrid` with the dropdown and the button). This is the options-ui-§14
  deviation, and the deviation row is added in this task.

- [ ] **Step 1: Write the failing tests.** Port every still-valid case from
  `test_pages_containers.lua`, retargeted to `P.show("General")` and the `Containers` tab.
  Retire the Overview cases. Add:
  - The Containers tab draws a Container dropdown and a "New container" button inside the scroll.
  - **C-3:** after the Delete popup's `OnAccept` plus the next-frame refresh, the picker and New are
    both present and parented. Assert the widget count on the tab, and that the picker lists the
    remaining containers.
  - General's Defaults resets the selected container's unit, aura type, style and enabled, and does
    not change its name. `/am reset container.name` prints "A container's name has no default."
    and changes nothing.
  - `NS.OpenOptionsPage("containers")` no longer resolves to a page. No page registers the key
    `containers`.
  - The tab strip reads `Master controls, Display, Containers, Spell Categories, Dispel Colors`.
    Pin only the first three now; D3 adds the last two.
- [ ] **Step 2: Watch them fail.** Run the suite; the new cases fail.
- [ ] **Step 3: Implement.** Extract `RenderTabbedPage` and move the rows. Put the picker, New,
  Duplicate, Delete and Copy in the new file, and remove the page registration. Add `noReset` to
  `NS.ApplyDefault`, and to the CLI reset's message path in `settings/Slash.lua`. Move the strings.
  Update the TOC: remove `settings/Containers.lua`, and add `settings/GeneralContainers.lua` BEFORE
  `settings/General.lua`. Update `tests/test_loadorder.lua` if it pins the file list.
- [ ] **Step 4: Run the gate and commit.** Gate green, then
  `git commit -am "General → Containers tab; the Containers page and its Overview retire (G-1, C-3; options-ui-§14 deviation)"`.

### Task D3: General → Spell Categories and Dispel Colors (G-2, G-3)

**Files:** Create `settings/GeneralSpells.lua`; modify `settings/General.lua` (tabs), `settings/Filters.lua`
(remove the Spell lists tab and its renderer :147–228), `AuraMaster.toc`, `locales/enUS.lua`. Test
`tests/test_pages_general.lua`.

- [ ] **Step 1: Write the failing tests.**
  - The **Spell Categories** tab shows a category dropdown (the 9 spell categories, `healing`
    included), then an `IdList`. Its toggle entries are the category's starters, and its removable
    entries are the additions.
  - Adding by id or by name writes `categorySpells` whole through `NS.SetByPath("categorySpells", …)`.
  - Unticking a starter stores `false`. Restore empties the category.
  - The **Dispel Colors** tab shows six color rows `dispelColors.Magic` … `.None` with no companion.
    A write re-applies all containers.
  - The **Filters** page has no Spell lists tab.
- [ ] **Step 2: Watch them fail.** Run the suite; the new cases fail.
- [ ] **Step 3: Implement.** Use `H.IdList`, with `kind = "spell"` and
  `candidates = function() return every starter id across spell categories plus NS.db.global.timedSpells keys end`.
  The Dispel Colors rows are plain schema rows, `page = "general", group = L["Dispel Colors"]`.
- [ ] **Step 4: Run the gate and commit.** Gate green, then
  `git commit -am "General → Spell Categories (profile-wide, IdList) and Dispel Colors (G-2, G-3)"`.

### Task D4: Filters → Categories grid and Overrides (F-1, F-3)

**Files:** `settings/Filters.lua`, `core/Constants.lua` (`CATEGORY_STATE_LABELS`),
`locales/enUS.lua`. Test `tests/test_pages_filters.lua`.

- [ ] **Step 1: Write the failing tests.**
  - On a buff container the Categories tab draws two `ChoiceGrid`s headed "Blizzard Categories" and
    "Custom Categories". On a debuff container it draws "Blizzard Categories", "Dispel Types" and
    "Who Cast It". Each heading appears once.
  - The grid's columns are Default, Whitelist and Blacklist.
  - A radio click stores `"show"` / `"hide"` / `""`.
  - `/am get container.filter.categories.defensives` prints `Whitelist` for `"show"`.
  - The category rows carry `skipRender`, so the flow engine draws no dropdown for them.
  - The Overrides tab replaces "Always / never". Its subsections are Whitelist and Blacklist, each
    an `IdList` over `container.filter.whitelist` / `.blacklist`.
- [ ] **Step 2: Watch them fail.** Run the suite; the new cases fail.
- [ ] **Step 3: Implement.**
  - Change `categoryRows` to set `skipRender = true` and a `grid` key (`"blizzard"` | `"custom"` |
    `"dispel"` | `"who"`).
  - The Categories group renders through a bespoke tab keyed by the group name, which makes
    `renderActiveTab` prefer the bespoke tab. `collectTabs` must not add a duplicate tab (dedupe by
    key). The bespoke render calls `H.ChoiceGrid` per grid key.
  - Remove the `"Always / never"` tab, and add `"Overrides"` with two `IdList`s.
- [ ] **Step 4: Run the gate and commit.** Gate green, then
  `git commit -am "Filters: Default/Whitelist/Blacklist category grid, Overrides with spell names (F-1, F-3)"`.

### Task D5: Layout tabs, subsections, dimming (L-1, L-2, L-5)

**Files:** `settings/Layout.lua`, `core/Constants.lua` (`ATTACH_MODE_LABELS` → Screen / Another
container / Named frame), `locales/enUS.lua`. Test `tests/test_pages_layout.lua`.

- [ ] **Step 1: Write the failing tests.**
  - Tab order is `Frame, Anchor, Growth, Mouse`.
  - The Anchor tab's subsections are `Screen, Another container, Named frame, Offset`.
  - No "Attach to the screen" button. "Pick a frame…" sits in Named frame.
  - The dimming matrix. For each mode, assert `disabled` on every row of the non-applying
    subsections and enabled on the applying ones, and that a mode change re-syncs without a
    re-render:
    - `screen`: Screen on; the rest off;
    - `container`: Another container and Offset on;
    - `frame`: Named frame and Offset on.
- [ ] **Step 2: Watch them fail.** Run the suite; the new cases fail.
- [ ] **Step 3: Implement.**
  - Reorder the declarations (the group order is first-seen order).
  - `G_POS` becomes `L["Anchor"]`, with subgroups on each row.
  - `disabledIf = function() local c = NS.ActiveContainer(); return not c or c.attach.mode ~= "container" end`
    and its siblings. Build them from one helper, `onlyIn(mode, ...)`.
  - The `attach.point` / `.relativePoint` rows go under Named frame (frame only; container mode
    derives them in E1). `attach.x` / `.y` go under Offset (enabled in container and frame).
  - The `afterGroup` becomes the Pick button in Named frame, drawn through a row `pairWith`, or an
    afterGroup on the Anchor group placed after Named frame; choose whichever the flow engine
    supports without layout code (options-ui-§6).
- [ ] **Step 4: Run the gate and commit.** Gate green, then
  `git commit -am "Layout: Frame first, Anchor tab with Screen/Another container/Named frame/Offset, dimmed when not in use (L-1, L-2, L-5)"`.

### Task D6: Bars Icon tab, wrong-style state, spark on timeless (B-1, B-2, B-3, B-6) — CP-D

**Files:**
- `settings/Bars.lua`, `settings/Icons.lua`, `settings/OptionsSetup.lua` (`renderActiveTab` passes
  `opts.disabled` from the page's `spec.disabledFor(cfg)`), `modules/Style_Bars.lua`.
- Tests `tests/test_pages_bars.lua`, `tests/test_pages_icons.lua`, `tests/test_style_bars.lua`.

**Interfaces:** `spec.disabledFor(cfg) -> bool` on `RegisterContainerPage` specs. `renderActiveTab`
calls `Helpers.RenderRows(..., { noHeadings = true, disabled = spec.disabledFor and spec.disabledFor(cfg) })`.
Bespoke tabs receive `ctx.__renderDisabled` through the same flag.

- [ ] **Step 1: Write the failing tests.**
  - The Bars tabs are `Size, Bar, Icon, Background & border, Name text, Time text, Stack text,
    Highlights`. The Icon tab holds `icon`, `iconSize`, `iconGap`, `iconZoom`, then the composed
    icon-border block on the `iconBorder*` keys.
  - Highlights has no Dispel type colors subsection.
  - On an icons container, every row of every Bars tab is disabled, and the notice is drawn with
    `fontObject = "GameFontNormalLarge"` followed by a spacer. The same holds for the Icons page on
    a bars container.
  - `bars.sparkTimeless` exists on the Bar tab's Spark subsection.
  - `Style_Bars`:
    - the icon border draws when `iconBorderShow`, and the icon insets by its size;
    - the spark-timeless mechanism per R0 answer 5 (option 1 or 2);
    - a preview aura with `duration == 0` hides the spark when `sparkTimeless == false`.
- [ ] **Step 2: Watch them fail.** Run the suite; the new cases fail.
- [ ] **Step 3: Implement.**
  - Move the four icon rows to `group = L["Icon"]`, declared before the Background & border group.
  - Add `H.BorderGroup({ prefix = P, page = PAGE, group = G_ICON, subgroup = L["Icon border"], show = true, classColor = UNIT, keys = { borderShow = "iconBorderShow", borderStyle = "iconBorderStyle", borderSize = "iconBorderSize", borderColor = "iconBorderColor", useClassColorBorder = "useClassColorIconBorder" } })`.
    Check the composer's `keys` support for BorderGroup in `OptionsCompose.lua`. If it has none, stop
    and report; do not hand-write the block (options-ui-§16).
  - Add the spark row.
  - Build the notice with `H.TextRow(ctx, text, { fontObject = "GameFontNormalLarge" })` and
    `H.AddSpacer(scroll, 12)`.
  - In `Style_Bars`, add an `am.iconBorder` BackdropTemplate frame around `am.icon` in `layout`,
    painted by `Style.ApplyBorder`. Implement the spark mechanism.
  - If R0 says B-3 is impossible (option 3), stop the spark sub-item, mark it in the ledger, and add
    it to the H2 report for the owner.
- [ ] **Step 4: Run the gate, commit and checkpoint.** Gate green, then
  `git commit -am "Bars: Icon tab with icon border, wrong-style pages disabled with a prominent notice, spark on timeless auras (B-1, B-2, B-3, B-6)"`.
  Ledger CP-D.

---

## Phase E — Layout inheritance

### Task E1: Effective flow and derived points (L-6)

**Files:** `modules/Anchors.lua` (`targetFor` :69, `Place` :89, `placeHandle` :283, `clampToHandle`
:312), `modules/Container.lua` (`FlowSettings` :79, `growthOf` :61), `modules/Preview.lua` (`Offset`
:23), `settings/Layout.lua`. Tests `tests/test_anchors.lua`, `tests/test_pages_layout.lua`.

**Interfaces:**
- **`NS.Anchors.EffectiveLayout(cfg) -> layoutTable`.** For a container in `container` mode, it
  returns a shallow copy of `cfg.layout` with `axis`, `growH` and `growV` replaced by the chain
  root's. The walk follows `attach.container` while that target is itself in container mode, is
  cycle-safe (`WouldCycle`) and stops at 64 hops. In any other mode it returns `cfg.layout` itself,
  with no allocation.
- **`NS.Anchors.DerivedPoints(parentLayout) -> point, relativePoint`**, per the spec's table.
- `Container.FlowSettings`, `groupLayout`, `Preview.Offset`, `placeHandle` and `clampToHandle` read
  `EffectiveLayout(cfg)` instead of `cfg.layout`.

- [ ] **Step 1: Write the failing tests.**

```lua
local cases = {
    { axis = "vertical",   growH = "right", growV = "down", p = "TOPLEFT",     rp = "BOTTOMLEFT" },
    { axis = "vertical",   growH = "left",  growV = "down", p = "TOPRIGHT",    rp = "BOTTOMRIGHT" },
    { axis = "vertical",   growH = "right", growV = "up",   p = "BOTTOMLEFT",  rp = "TOPLEFT" },
    { axis = "vertical",   growH = "left",  growV = "up",   p = "BOTTOMRIGHT", rp = "TOPRIGHT" },
    { axis = "horizontal", growH = "right", growV = "down", p = "TOPLEFT",     rp = "TOPRIGHT" },
    { axis = "horizontal", growH = "right", growV = "up",   p = "BOTTOMLEFT",  rp = "BOTTOMRIGHT" },
    { axis = "horizontal", growH = "left",  growV = "down", p = "TOPRIGHT",    rp = "TOPLEFT" },
    { axis = "horizontal", growH = "left",  growV = "up",   p = "BOTTOMRIGHT", rp = "BOTTOMLEFT" },
}
for _, c in ipairs(cases) do
    test(("anchors: derived points continue a %s/%s/%s parent"):format(c.axis, c.growH, c.growV), function()
        local p, rp = NS.Anchors.DerivedPoints({ axis = c.axis, growH = c.growH, growV = c.growV })
        -- red under: a table that ignores the parent's axis (a row parent stacking its child below)
        assertEqual(p, c.p); assertEqual(rp, c.rp)
    end)
end
```

  Plus:
  - `Place` in container mode anchors with the derived points and the stored `attach.x` / `.y`,
    ignoring `attach.point`;
  - chain A←B←C: C's effective growth is A's;
  - detaching B restores B's stored flow at the next apply;
  - on the Growth tab in container mode, Fill / Grow horizontally / Grow vertically are disabled and
    read the inherited values, and the line "Fill and growth follow 'A'" is drawn;
  - the Another container subsection shows "Attached at <derived point> of <target>".
- [ ] **Step 2: Watch them fail.** Run the suite; the new cases fail.
- [ ] **Step 3: Implement.**

```lua
function Anchors.DerivedPoints(L)
    local growH = (L.growH == "left") and "LEFT" or "RIGHT"
    local down = (L.growV ~= "up")
    if L.axis == "vertical" then
        local h = (growH == "RIGHT") and "LEFT" or "RIGHT"
        if down then return "TOP" .. h, "BOTTOM" .. h end
        return "BOTTOM" .. h, "TOP" .. h
    end
    local v = down and "TOP" or "BOTTOM"
    if growH == "RIGHT" then return v .. "LEFT", v .. "RIGHT" end
    return v .. "RIGHT", v .. "LEFT"
end
```

  The Growth-tab display is a panel-only effective read: the three rows get a row `get` wrapper in
  `settings/Layout.lua` that returns the effective value in container mode. The rows keep their
  `path`, and `/am get` still reads the stored value. Check that the flow engine's `read(row)` uses
  `row.get` only for path-less rows (`OptionsWidgets.lua:773`). If so, provide the effective value
  through the descriptor's `get` in `settings/OptionsSetup.lua`, gated to these three paths and to
  the panel (a `panelGet` hook), rather than changing the library's read contract.
- [ ] **Step 4: Run the gate and commit.** Gate green, then
  `git commit -am "Layout: an attached container continues its parent's flow — inherited growth, derived points (L-6)"`.

### Task E2: The attached container's handle shows while unlocked (L-4) — CP-E

**Files:** `modules/Anchors.lua`, `modules/Preview.lua`, `modules/Container.lua`
(`ApplyVisibility` :376). Test `tests/test_anchors.lua`, `tests/test_preview.lua`.

- [ ] **Step 1: Confirm the cause** with a recorder test. With A previewing (engine disabled) and B
  attached to A, record B's anchor `SetPoint` target and A's engine size. Write the finding into the
  commit message.
- [ ] **Step 2: Write the failing test.** While previewing, B anchors to A's preview-extent frame,
  sized to A's placeholder block by `Preview.Offset` arithmetic (the bottom-right-most placeholder's
  offset plus the element size). B's handle frame level is above every placeholder of A. On lock,
  B re-anchors to A's engine.
- [ ] **Step 3: Implement.**
  - Add `Preview.Extent(container)`, which creates or updates `container.previewExtent`, a plain
    frame of ours under the anchor, sized by the placeholder count and flow.
  - `targetFor` in container mode returns `target.previewExtent` while the target is previewing
    (`target.previewShown`), else the engine.
  - `ApplyVisibility` re-places attached children when the preview toggles, out of combat only
    (`InCombatLockdown()` → leave the placement as it is, per events-frames-taint-§2).
  - The handle's level becomes `anchor level + 50 + (placeholder max level)`.
- [ ] **Step 4: Update the docs.** Rewrite the Known Limitations entry in `docs/ARCHITECTURE.md`
  :350–353. Add a smoke check.
- [ ] **Step 5: Run the gate, commit and checkpoint.** Gate green, then
  `git commit -am "Layout: an attached container's handle and placeholders show beside its parent while unlocked (L-4)"`.
  Ledger CP-E.

---

## Phase F — Coverage and docs

### Task F1: Every Bars and Icons row reaches a region (B-5)

**Files:** Create `tests/test_render_coverage.lua` and add it to `tests/run.lua`'s suite list.

- [ ] **Step 1: Write the test.** For each row of `NS.SchemaForPage("bars")` and
  `NS.SchemaForPage("icons")`:
  - set the container's style to match;
  - write a value that differs from the default (bool → not; number → a legal non-default in
    range; string with values → another value; color → a distinct color);
  - flush the apply;
  - dress a live (engine) button and a preview element with the region recorder;
  - assert that the recorded calls differ from the pre-write recording.

  A row may declare `coverage = "engine-only"` or `"preview-only"` with a comment saying why. Any
  other exemption is a failure naming the path.
- [ ] **Step 2: Run it and fix each named row.** Every row it names is a bug. Fix each at its root in
  `Style*` with a focused test, one commit per root cause.
- [ ] **Step 3: Run the gate and commit.** Gate green, then
  `git commit -am "Test: every Bars and Icons setting reaches a drawn region (B-5)"`.

### Task F2: Docs — CP-F

- [ ] Update `docs/settings-panel.md`: the page table, and every page → tab → row table, regenerated
  from the live schema (run the headless walk the doc describes).
- [ ] Update `docs/schema.md`: profile keys, template changes, v2.
- [ ] Update `docs/ARCHITECTURE.md`:
  - row counts per page, 39 → the new authored file count;
  - LibKa0s v1.35.0;
  - the options-ui-§14 deviation row (already added in D2, so check it);
  - Known Limitations;
  - the LibKa0s-Widgets note if any.
- [ ] Update `docs/module-map.md` (new and removed files, TOC order), `docs/smoke-tests.md` (every
  in-game check added by B5–B7, D6 and E2, plus R0's UNSETTLED items), `docs/common-tasks.md`
  (recipes naming `settings/Containers.lua`), and README (features and page names).
- [ ] Regenerate `docs/test-cases.md` (`lua tests/run.lua --list`, per its banner, CRLF).
- [ ] Gate green, including `tests/test_docs.lua`'s citation check. Then
  `git commit -am "docs: batch 5 — panel map, schema v2, deviation row, smoke tests"`. Ledger CP-F.

---

## Phase G — Adopters (each on branch `feat/2026-09-13-idlist` in its own repo)

Shared steps per repo:
1. Branch from master.
2. Re-vendor v1.35.0 (`libs/LibKa0s/` + `tests/_kit/` whole; the `CLAUDE.md` provenance line;
   `DEPENDENCIES.md`).
3. Run the gate. `test_vendor_sync` passes against the local tag.
4. Commit "Re-vendor LibKa0s v1.35.0".
5. Adopt the widget, test first.
6. Run the gate and commit.

### Task G1: ConsumableMaster — `IdInput` (spell/item) in `settings/Category.lua:546`

- [ ] **Step 1: Write the failing test** in the repo's page suite:
  - typing a spell name with Type = SPELL calls `Selector.AddItem` with the negative id
    (`KCM.ID.AsSpell`);
  - an item name with Type = ITEM calls it with the item id;
  - an unknown name adds nothing and shows the reason.
- [ ] **Step 2: Replace the EditBox in `renderAddByID`.** Use `H.IdInput(ctx, parent, { kind = <resolver table by the Type dropdown>, onAdd = … })`.
  The resolver maps a spell to `KCM.ID.AsSpell(id)` in `onAdd`, not in the resolver. The Type
  dropdown stays. The rows (`KCMItemRow`, `ReorderList`) are untouched.
- [ ] **Step 3: Run the gate and commit.** Gate green, then commit.

### Task G2: BankLedger — `IdList` (items) for Blacklist / Whitelist, `settings/Panel.lua:281` and `:241`

- [ ] **Step 1: Write the failing tests.**
  - Adding by item name (a cached item in the mock) calls `Filters:AddBlacklist(id)`.
  - Remove calls `RemoveBlacklist`.
  - "(none)" becomes `emptyText`.
  - Adding to one list removes the id from the other (the existing `_move`, unchanged).
- [ ] **Step 2: Replace the editor.** `makeFilterSection` and `rebuildFilterList` become one
  `H.IdList` call each. "Clear all" stays a host button beside the heading.
- [ ] **Step 3: Run the gate and commit.** Gate green, then commit.

### Task G3: LootHistory — `IdList` (items; currencies) for three tabs, `settings/Panel.lua:268` and `:219` — CP-G

- [ ] **Step 1: Write the failing tests**, as in G2, plus the Currencies tab with
  `kind = "currency"`, which accepts an id or a currency link (no name lookup: "Currencies are
  added by id or link.").
- [ ] **Step 2: Replace the editor.** Keep `ctx.rebuilders` registration so an item load re-renders.
- [ ] **Step 3: Run the gate, commit and checkpoint.** Gate green, then commit. Ledger CP-G.

---

## Phase H — Verify and hand over

### Task H1: Adversarial review and fixes

- [ ] Review the AM diff `master...feat/2026-09-13-feedback-batch5` and the LibKa0s diff
  `master...feat/2026-09-13-v1.35.0` along these dimensions:
  - correctness against the spec's acceptance criteria;
  - taint and combat rules (events-frames-taint);
  - standard conformance (any deviation other than D1);
  - migration safety;
  - test quality (does each test die under its named mutation?).
- [ ] Verify each finding adversarially, then fix the confirmed ones test-first, with one commit
  each.
- [ ] Review the adopters' diffs the same way, more lightly.

### Task H2: Final battery and report — CP-H

- [ ] In every repo: `lua tests/run.lua`, `luacheck .`, lizard (zero above CCN 15), and
  `lua tests/perf.lua` where present. Record the numbers.
- [ ] Update the ledger, and update the memory note (`ka0s-batch5-2026-09-13`).
- [ ] Report to the owner:
  - what shipped, per requirement ID;
  - anything stopped (for example B-3 option 3);
  - R0's UNSETTLED in-game checks;
  - the branch and commit list per repo, the local tag;
  - the owner's decisions still owed: merge, push, tag push, and the other six addons' re-vendor.
