# Feedback batch 6 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the owner's 2026-09-14 feedback on Aura Master — a Show/Hide category grid that
links to the spell lists it names, a documented and visible filter priority, weapon enchants as a
category, an honest max-duration control, and a container that stops leaking the world unit's
tooltip.

**Architecture:** LibKa0s v1.36.0 adds four things to `LibKa0s-Options-1.0`: a checkbox-shaped
`ChoiceGrid` cell, an optional extra link column on that grid, a `note` line on an `IdList` entry,
and `O.SelectTab`. Aura Master then collapses its three-state category model to Show/Hide — which
deletes the per-shown-category group path in the compiler outright — migrates the stored shape to
v3, folds weapon enchants into the category model, re-vendors the library, rebuilds the Filters →
Categories tab on the new widgets, and fixes the tooltip bleed with a container-wide mouse blocker.

**Tech Stack:** Lua 5.1 (WoW Retail 12.1), Ace3, LibKa0s, the headless harness `lua tests/run.lua`,
`luacheck`, `lizard`.

**Spec:** `docs/superpowers/specs/2026-09-14-feedback-batch6-design.md`. Requirement IDs (`C-2`,
`E-8`, `K-1`, …) are the spec's; read both.

## Global Constraints

- **Green gate before EVERY commit, in the repo being committed:** `lua tests/run.lua` (all green)
  and `luacheck .` (`0 warnings / 0 errors`). Complexity:
  `lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .` shows no function above CCN 15.
- **Checkpoint commits and branch pushes are AUTHORIZED** (owner, 2026-09-14) so an interrupted
  session can resume from git. Each task ends with a commit on its feature branch once its green
  gate passes, and the branch is pushed. **Still forbidden without a further instruction:** merging
  to master, pushing a tag, and bumping any addon's version. The LibKa0s tag `v1.36.0` is created
  LOCALLY only — every adopter's `tests/test_vendor_sync.lua` needs it to exist, and pushing it
  would publish a release the owner has not approved.
- **Branches:** AM `feat/2026-09-14-feedback-batch6`; LibKa0s `feat/2026-09-14-v1.36.0`; the nine
  other adopters `chore/2026-09-14-revendor-v1.36.0`.
- **Commit trailers:** every commit message ends with the two attribution lines this session's
  system prompt specifies (`Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>` and
  the `Claude-Session:` line).
- **The standard:** the Ka0s WoW Addon Standard (`../WowAddonStandards/standards/standards/*.md`) is
  binding. No deviation is expected (spec section 10). A deviation found mid-task STOPS that task
  and is reported, never silently taken (CLAUDE.md).
- **TDD:** every change gets a failing test first. A test comment names the mutation it dies under
  ("red under: …"), in the repo's existing style.
- **Defaults** live in `defaults/Profile.lua` only (savedvariables-§2). Every settings write goes
  through `NS.SetByPath`. User-visible strings go through `NS.L` with the key added to
  `locales/enUS.lua`. US spelling (`tests/test_docs.lua` enforces it).
- **Line endings:** the working tree is CRLF (`.gitattributes`). After every tool write to a file
  under `tests/_kit/`, repair with `git add <path> && rm <path> && git checkout -- <path>`.
- **The compiler stays pure:** `modules/FilterCompiler.lua` takes `(cfg, ctx)` and returns a table.
  No frames, no database reads, no globals beyond `math.huge`.

---

## Status ledger (UPDATE AFTER EVERY TASK — this is the resume point)

### How to resume after an interruption

A fresh session with no memory of this work resumes with these six steps and nothing else:

1. **Read this plan and the spec it names.** Both are on disk; neither needs the conversation.
2. **Read this ledger.** The first row that is not `done` is where work continues.
3. **Verify the ledger against git**, because the ledger is written by hand and git is not:
   ```bash
   git -C . log --oneline -20 && git -C . status --short
   git -C ../LibKa0s log --oneline -20 && git -C ../LibKa0s status --short
   ```
   A row marked `done` whose commit is absent from `git log` is NOT done — trust git, fix the row.
   A commit present with no `done` row means the ledger update was the interrupted step: verify
   that task's tests pass, then mark it `done`.
4. **Check both working trees are clean.** Uncommitted changes are an interrupted task mid-flight.
   Read them, decide whether they are a partial implementation worth finishing or a dead end worth
   `git checkout --`, and say which to the owner before continuing.
5. **Run the gate before writing anything:** `lua tests/run.lua && luacheck .` in the repo you are
   resuming. Red on a supposedly-finished state means the last task did not land cleanly — fix that
   before starting the next one.
6. **Continue at the first not-`done` row**, honoring the dependency order below. Never redo a
   `done` row: its commit is the proof.

**Every task ends with the same four things, in this order:** green gate → commit → push → **update
this ledger's row**. A task is not finished until its row says so, and the ledger update may ride
in the task's own commit or the one immediately after.

| Task | Req | Repo | Status | Commit | Notes |
|---|---|---|---|---|---|
| P0 spec + plan | — | AM | done | 39f5e4b | pushed; branch tracks origin |
| A1 ChoiceGrid checkbox cell | K-1 | LibKa0s | done | 5845429 | replaced the old radio-typed test with its inverse; fill guarded, coverage split |
| A2 ChoiceGrid extra column | K-2 | LibKa0s | done | 2f2f299 | choiceExtraCell extracted; widths 0.98 at 2 and 3 columns |
| A3 IdList entry note | K-3 | LibKa0s | done | 4f0960a 1b3936d | also hardened choiceExtraCell onClick to a type check (A2 minor) |
| A4 O.SelectTab | K-4 | LibKa0s | done | f5d34c3 6dcbd80 | fix round 1: RefreshPanel(ctx, true), scoped to one page, not RefreshAllPanels |
| A5 release v1.36.0 (local tag) | K-1…K-4 | LibKa0s | done | 3dcf3a8 | Options 18->19, Widgets 16->17, key 19.17.5.3; tag v1.36.0 LOCAL, verified not on origin; **CP-A reached** |
| B1 Show/Hide compiler + constants | C-1…C-6 F-6 | AM | done | df16eaf 8fec9d9 | Cat.DefaultStates() replaces NeutralStates; setFlag's `soft` removal is a REAL behavior change (see ledger), documented + tested |
| B2 schema v3 migration | E-8 E-5 | AM | done | c4e3b6e 47e406a 180327a | 2 fix rounds: 3 idempotency bugs; narrowed containers also gain the whitelisted ids on filter.whitelist; kind=='enchant' excluded from the sweep |
| B3 enchant category kind | E-1…E-4 E-7 | AM | done | d5af512 1606f7e | fix round 1: a bool row must not sit in the ChoiceGrid; Categories tab widened to ENCHANT |
| B11 priority order + only-these toggle | R-1…R-11 | AM | done | d0669f8 3d90769 7673cf3 | supersedes part of C-2; reverts E-8's id copy; `only(auraType, keys)` test fixture added (a real category list defaults every row to Show, so R-4 explodes any un-narrowed Hide test) |
| B4 re-vendor v1.36.0 | K-* | AM | done | f4e09a4 | payload byte-identical to the tag, verified independently; vendor-sync ran for real |
| B5 Filters → Categories tab | F-1…F-7 R-10 P-1 | AM | done | c7862c3 | blurb verified rank-by-rank against the compiler; F-7's original wording was false under rank 3 and the spec was corrected |
| B6 ExplainSpell + Overrides notes | P-3 P-4 | AM | done | f4b408e 91dafb9 bbe87e4 f45fe89 | 3 fix rounds. Notes are COUNTERFACTUALS (an entry's own rank is uninformative) and describe only what the lists and categories decide |
| B7 General → Spell Categories | E-6 F-3 | AM | todo | | needs B4 |
| B8 max duration | D-1…D-4 | AM | done | 2f7c083 | issue #5 filed; preset uses the existing pairWith seam; 0-as-falsy verified safe |
| B9 container mouse blocker | T-1…T-5 | AM | done | 42d610b ef63966 fc86d14 | 2 fix rounds, 3 Criticals: a raw engine frame-level write made to satisfy the MOCK, a missing anchor template that would have made the fix a no-op, and a live blocker on hidden containers |
| B10 docs | P-2 D-3 | AM | done | c0bf45d | **CP-C** reached; scope grew to 8 steps (spec §6b/6c revision) — Filter priority section, schema/common-tasks tri-state prose, migration side-effect note, `onlyShown` docs, 7 falsifiable smoke checks, counts 813→880, issue #6 filed on the citation gate's blind spot |
| C1 re-vendor the other nine | K-* | 9 repos | todo | | roster confirmed 2026-09-15 |
| C2 final battery + report | all | all | todo | | **CP-D** |

**B11 was added on 2026-09-15** after the owner revised the priority order. It runs after B3 (same
file) and before B5/B6, which render its rules and explain them. See spec sections 6 and 6b.

**Dependency order:** A1–A4 are independent of each other and all precede A5. B1 → B2 → B3 are
sequential (they touch the same stored shape). B4 needs A5. B5, B6, B7 need B4 and B3. B8 and B9
are independent of everything and may run at any time. B10 is last in AM. C1 needs A5 only and may
run concurrently with B5–B10.

**Checkpoint rule:** a CP row is reached only when every row above it in its phase is `done`, the
phase's repo gate is green, and this ledger is updated.

---

## File structure

| File | Change | Responsibility after |
|---|---|---|
| `../LibKa0s/LibKa0s/OptionsWidgets.lua` | modify | ChoiceGrid cell art + `extraColumn`; IdList entry `note` |
| `../LibKa0s/LibKa0s/Options.lua` | modify | + `O.SelectTab(pageKey, tabKey)` |
| `../LibKa0s/CHANGELOG.md`, `README.md`, `CLAUDE.md` | modify | v1.36.0 release notes and version stamps |
| `core/Constants.lua` | modify | `CATEGORY_STATES` = `{ "show", "hide" }`; labels Show / Hide |
| `core/Database.lua` | modify | `SCHEMA_STEPS` gains v3; `Database.MigrateV3` |
| `defaults/Categories.lua` | modify | + `weaponEnchants`, kind `enchant` |
| `defaults/Profile.lua` | modify | + profile `enchantSlots`; template stamps every category `"show"`; drops `includeEnchants` |
| `modules/FilterCompiler.lua` | modify | one category group; `excludeCategory`; enchants from the category row and `enchantSlots`; + `FC.ExplainSpell` |
| `modules/Container.lua` | modify | + the mouse blocker frame |
| `modules/Style.lua` | modify | + `Style.ApplyBlockerBehavior(frame, cfg)` |
| `settings/Filters.lua` | modify | two-column grid, Spell Categories heading, link column, priority blurbs, enchant sub-row, max-duration presets |
| `settings/GeneralSpells.lua` | modify | + `Select(key)`, + the Weapon enchants entry |
| `locales/enUS.lua` | modify | every new/changed string key |
| `docs/*` | modify | priority table, scope limit, panel map, smoke step |
| `tests/test_filtercompiler.lua`, `test_database.lua`, `test_pages_filters.lua`, `test_pages_general.lua`, `test_container.lua`, `test_schema_paths.lua` | modify | the coverage in spec section 9 |

---

## Phase A — LibKa0s v1.36.0

Work in `/mnt/d/Profile/Users/Tushar/Documents/GIT/LibKa0s`. Its own gate is
`lua tests/run.lua` + `luacheck .` from that repo's root.

### Task A1: ChoiceGrid cell becomes a checkbox with a yellow fill

**Files:**
- Modify: `LibKa0s/OptionsWidgets.lua` (`choiceCell`, ~line 2557)
- Test: `tests/test_options_widgets.lua`

**Interfaces:**
- Consumes: nothing.
- Produces: no signature change. `O.ChoiceGrid`'s cells stop being AceGUI radios and become
  checkboxes whose exclusive behavior is unchanged.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_options_widgets.lua`:

```lua
-- red under: choiceCell calling SetType("radio") again, or the lit cell losing its fill texture.
test("ChoiceGrid: a cell is a checkbox, never a radio, and the lit one carries the fill", function()
    local ctx = T.NewCtx()
    local store = { state = "hide" }
    local row = { label = "Defensives",
        get = function() return store.state end,
        set = function(_, v) store.state = v end }
    O.ChoiceGrid(ctx, {
        rows = { row },
        columns = { { value = "show", label = "Show" }, { value = "hide", label = "Hide" } },
    })
    local cells = T.WidgetsOfType(ctx, "CheckBox")
    assertEqual(#cells, 2)
    for _, cb in ipairs(cells) do
        assertNil(cb.__type)                       -- SetType was never called
    end
    assertEqual(cells[1]:GetValue(), false)        -- "show" not held
    assertEqual(cells[2]:GetValue(), true)         -- "hide" held
    assertTrue(cells[2].__checkTexture ~= nil)     -- the lit cell got the fill
end)
```

- [ ] **Step 2: Run it and confirm it fails**

Run: `cd ../LibKa0s && lua tests/run.lua 2>&1 | grep -A3 "never a radio"`
Expected: FAIL — `cb.__type` is `"radio"`, and `__checkTexture` is nil.

- [ ] **Step 3: Implement**

In `LibKa0s/OptionsWidgets.lua`, beside the other choice-grid constants (~line 2526), add the fill
color, and rewrite `choiceCell`'s first four lines:

```lua
  -- The lit cell's fill. A checkbox SHAPE with radio BEHAVIOR: one choice per row, but drawn as a
  -- filled box rather than a dot, because a player reads a filled box as "this one is on" faster
  -- than a dot in a ring. The exclusive behavior is this function's, never the widget's, so the
  -- widget is left an ordinary CheckBox and the check glyph is replaced by a solid swatch.
  local CHOICE_FILL_R, CHOICE_FILL_G, CHOICE_FILL_B = 1, 0.82, 0
```

```lua
  --- Paint `cb`'s check region as a solid fill instead of a check glyph. Guarded end to end: a
  --- host's AceGUI fake carries no textures, and a cell with no fill is still correct, only plain.
  local function choiceFill(cb)
    local tex = cb.check or (cb.frame and cb.frame.check)
    if not (tex and tex.SetTexture and tex.SetVertexColor) then return end
    tex:SetTexture("Interface\\Buttons\\WHITE8X8")
    tex:SetVertexColor(CHOICE_FILL_R, CHOICE_FILL_G, CHOICE_FILL_B)
    if tex.SetTexCoord then tex:SetTexCoord(0, 1, 0, 1) end
    if tex.SetSize and cb.frame and cb.frame.GetHeight then
      local h = (cb.frame:GetHeight() or 24) * 0.45
      tex:SetSize(h, h)
    end
    return tex
  end
```

Then in `choiceCell`, replace:

```lua
    local cb = O.AceGUI:Create("CheckBox")
    if cb.SetType then cb:SetType("radio") end
    cb:SetLabel("")
```

with:

```lua
    local cb = O.AceGUI:Create("CheckBox")
    cb:SetLabel("")
    cb.__checkTexture = choiceFill(cb)
```

- [ ] **Step 4: Run the gate**

Run: `cd ../LibKa0s && lua tests/run.lua && luacheck .`
Expected: all green, `0 warnings / 0 errors`.

- [ ] **Step 5: Commit**

```bash
git -C ../LibKa0s add LibKa0s/OptionsWidgets.lua tests/test_options_widgets.lua
git -C ../LibKa0s commit -m "Options: ChoiceGrid cells are checkboxes with a yellow fill, not radios (K-1)"
```

---

### Task A2: ChoiceGrid gains an optional extra link column

**Files:**
- Modify: `LibKa0s/OptionsWidgets.lua` (`choiceLabelRel`, `choiceHeader`, `choiceLine`, the
  `O.ChoiceGrid` doc block)
- Test: `tests/test_options_widgets.lua`

**Interfaces:**
- Consumes: A1's `choiceCell`.
- Produces: `O.ChoiceGrid(ctx, spec)` accepts
  `spec.extraColumn = { header = <string>, cell = function(row) -> { text = <string>, onClick = function(), tooltip = <string> } | nil }`.

- [ ] **Step 1: Write the failing test**

```lua
-- red under: the extra column not drawn, its onClick not wired, or a nil cell collapsing the line.
test("ChoiceGrid: an extraColumn draws a clickable cell per row and a blank for a nil one", function()
    local ctx = T.NewCtx()
    local clicked
    local rows = {
        { label = "Defensives", get = function() return "show" end, set = function() end },
        { label = "Cancelable", get = function() return "show" end, set = function() end },
    }
    O.ChoiceGrid(ctx, {
        rows = rows,
        columns = { { value = "show", label = "Show" }, { value = "hide", label = "Hide" } },
        extraColumn = {
            header = "Spells",
            cell = function(row)
                if row.label ~= "Defensives" then return nil end
                return { text = "See spells", onClick = function() clicked = row.label end }
            end,
        },
    })
    local labels = T.WidgetsOfType(ctx, "InteractiveLabel")
    local link
    for _, w in ipairs(labels) do
        if w:GetText() == "See spells" then link = w end
    end
    assertTrue(link ~= nil)
    link:Fire("OnClick")
    assertEqual(clicked, "Defensives")
end)
```

- [ ] **Step 2: Run it and confirm it fails**

Run: `cd ../LibKa0s && lua tests/run.lua 2>&1 | grep -A3 "extraColumn draws"`
Expected: FAIL — no widget reads `"See spells"`.

- [ ] **Step 3: Implement**

`choiceLabelRel` takes the extra column into account:

```lua
  local function choiceLabelRel(columnCount, hasExtra)
    local taken = columnCount * CHOICE_CELL_REL + (hasExtra and CHOICE_EXTRA_REL or 0)
    return math.max(1 - taken - CHOICE_CLIP_INSET, CHOICE_CELL_REL)
  end
```

with `local CHOICE_EXTRA_REL = 0.18` beside the other constants. `choiceHeader` and `choiceLine`
both take `extra` and pass `extra ~= nil` into `choiceLabelRel`; the header appends one more label
after the label column:

```lua
    if extra then
      local x = O.AceGUI:Create("Label")
      x:SetText(extra.header or "")
      x:SetRelativeWidth(CHOICE_EXTRA_REL)
      line:AddChild(x)
    end
```

and `choiceLine` appends the cell after the row's own label:

```lua
    if extra then
      local ok, cell = pcall(extra.cell, row)
      local x = O.AceGUI:Create(ok and cell and "InteractiveLabel" or "Label")
      x:SetRelativeWidth(CHOICE_EXTRA_REL)
      if ok and cell then
        x:SetText(cell.text or "")
        if cell.onClick then x:SetCallback("OnClick", function() cell.onClick() end) end
        if cell.tooltip then O.AttachTooltip(x, cell.text or "", cell.tooltip) end
      else
        x:SetText("")
      end
      line:AddChild(x)
    end
```

`drawChoiceGrid` passes `spec.extraColumn` to both. Extend the `O.ChoiceGrid` doc block with the
`extraColumn` shape, in the style of the entries already there.

- [ ] **Step 4: Run the gate**

Run: `cd ../LibKa0s && lua tests/run.lua && luacheck .`
Expected: all green.

- [ ] **Step 5: Commit**

```bash
git -C ../LibKa0s add LibKa0s/OptionsWidgets.lua tests/test_options_widgets.lua
git -C ../LibKa0s commit -m "Options: ChoiceGrid takes an optional extra link column (K-2)"
```

---

### Task A3: IdList entry gains a `note` line

**Files:**
- Modify: `LibKa0s/OptionsWidgets.lua` (the entry-line builder near `entryLabel`, ~line 3325, and
  the `O.IdList` doc block ~line 3481)
- Test: `tests/test_options_widgets.lua`

**Interfaces:**
- Consumes: nothing.
- Produces: an `O.IdList` entry may carry `note = <string>`, drawn under the entry's name in
  `ID_GRAY`. An entry without one is unchanged.

- [ ] **Step 1: Write the failing test**

```lua
-- red under: `note` ignored, or drawn for an entry that carries none.
test("IdList: an entry's note is drawn under its name, and only when it has one", function()
    local ctx = T.NewCtx()
    O.IdList(ctx, {
        kind = "spell", label = "Add a spell", onAdd = function() end,
        entries = function()
            return { { id = 498, note = "also in Defensives (Hide) - hidden by rule 3" },
                     { id = 642 } }
        end,
    })
    local texts = T.AllText(ctx)
    assertTrue(texts:find("hidden by rule 3", 1, true) ~= nil)
    local _, count = texts:gsub("hidden by rule 3", "")
    assertEqual(count, 1)
end)
```

- [ ] **Step 2: Run it and confirm it fails**

Run: `cd ../LibKa0s && lua tests/run.lua 2>&1 | grep -A3 "entry's note"`
Expected: FAIL — the note never reaches a widget.

- [ ] **Step 3: Implement**

In the entry-line builder, after the name label is added and before the action widget, add:

```lua
    -- The note: a second line under the name, in the gray the id already uses, for a host that has
    -- something to say about this entry (why it is or is not drawn, say). Its own line rather than
    -- a suffix, because a note is a sentence and a name is a name.
    if type(entry.note) == "string" and entry.note ~= "" then
      local n = O.AceGUI:Create("Label")
      n:SetText(ID_GRAY .. entry.note .. "|r")
      n:SetRelativeWidth(ID_MAIN_REL)
      line:AddChild(n)
    end
```

Extend the `O.IdList` doc block's `entries` line to
`ordered { { id =, toggle = bool?, on = bool?, note = string? }, ... }`.

- [ ] **Step 4: Run the gate**

Run: `cd ../LibKa0s && lua tests/run.lua && luacheck .`
Expected: all green.

- [ ] **Step 5: Commit**

```bash
git -C ../LibKa0s add LibKa0s/OptionsWidgets.lua tests/test_options_widgets.lua
git -C ../LibKa0s commit -m "Options: an IdList entry may carry a note line (K-3)"
```

---

### Task A4: `O.SelectTab(pageKey, tabKey)`

**Files:**
- Modify: `LibKa0s/Options.lua` (beside `O.__panelFor`, ~line 1270)
- Test: `tests/test_options.lua`

**Interfaces:**
- Consumes: the private `renderedPanels` list and each panel ctx's `activeTab`, both already there.
- Produces: `O.SelectTab(pageKey, tabKey) -> boolean`.

- [ ] **Step 1: Write the failing test**

```lua
-- red under: SelectTab absent, not refreshing, or reporting success for an unrendered page.
test("SelectTab: sets a rendered page's active tab and refreshes, and reports an unknown page", function()
    local O = T.NewOptions()
    local ctx = T.RenderPage(O, "general")
    ctx.activeTab = "Display"
    assertTrue(O.SelectTab("general", "Spell Categories"))
    assertEqual(ctx.activeTab, "Spell Categories")
    assertEqual(T.RefreshCount(O), 1)
    assertEqual(O.SelectTab("nosuchpage", "Whatever"), false)
end)
```

- [ ] **Step 2: Run it and confirm it fails**

Run: `cd ../LibKa0s && lua tests/run.lua 2>&1 | grep -A3 "SelectTab:"`
Expected: FAIL — `O.SelectTab` is nil.

- [ ] **Step 3: Implement**

```lua
  --- Select one tab on an already-rendered page. For a host sending the player somewhere specific
  --- — a link on one page that lands on another page's tab. The page must be rendered: a page the
  --- player has never opened has no ctx and therefore no tab to hold, and `false` says so rather
  --- than storing an intent this function has nowhere to keep.
  ---
  --- The caller opens the page (a host's own OpenToCategory); this only moves the tab.
  --- @return boolean  whether a rendered panel with that page key was found
  function O.SelectTab(pageKey, tabKey)
    local ctx = O.__panelFor(pageKey)
    if not ctx then return false end
    ctx.activeTab = tabKey
    O.RefreshAllPanels()
    return true
  end
```

- [ ] **Step 4: Run the gate**

Run: `cd ../LibKa0s && lua tests/run.lua && luacheck .`
Expected: all green.

- [ ] **Step 5: Commit**

```bash
git -C ../LibKa0s add LibKa0s/Options.lua tests/test_options.lua
git -C ../LibKa0s commit -m "Options: O.SelectTab moves a rendered page to one tab (K-4)"
```

---

### Task A5: Release LibKa0s v1.36.0 (local tag) — **CP-A**

**Files:**
- Modify: `LibKa0s/OptionsWidgets.lua` (`WIDGETS_MINOR` 16 → 17), `LibKa0s/Options.lua` (shell
  minor + 1), `CHANGELOG.md`, `README.md`, `CLAUDE.md`, `DEPENDENCIES.md` if it stamps a version

- [ ] **Step 1: Bump the module minors**

`WIDGETS_MINOR = 17` in `OptionsWidgets.lua`; the Options shell's own `MINOR` + 1 in `Options.lua`.
Both files changed, so both counters move — the pairing check at the top of `OptionsWidgets.lua`
compares them, and a half-bumped pair is exactly what it exists to catch.

- [ ] **Step 2: Write the CHANGELOG entry**

```markdown
## v1.36.0 — 2026-09-14

### LibKa0s-Options-1.0 (Options minor +1, OptionsWidgets minor 17)

- `ChoiceGrid` cells are checkboxes with a yellow fill instead of AceGUI radios. The exclusive
  one-choice-per-row behavior is unchanged — it never lived in the widget.
- `ChoiceGrid` takes an optional `extraColumn = { header, cell(row) }`, drawn after the label
  column, for a per-row link.
- An `IdList` entry may carry `note = <string>`, drawn under its name in gray.
- New `O.SelectTab(pageKey, tabKey)`: move an already-rendered page to one tab, so a link on one
  page can land on another page's tab. Returns false for a page that has not been rendered.
```

- [ ] **Step 3: Run the full battery**

Run: `cd ../LibKa0s && lua tests/run.lua && luacheck . && lizard -l lua -x "./tests/_kit/*" .`
Expected: all green, `0 warnings / 0 errors`, no function above CCN 15.

- [ ] **Step 4: Commit and tag locally**

```bash
git -C ../LibKa0s add -A
git -C ../LibKa0s commit -m "Release v1.36.0: ChoiceGrid checkbox cells + extra column, IdList note, O.SelectTab"
git -C ../LibKa0s tag v1.36.0
```

Do NOT push the branch or the tag.

- [ ] **Step 5: Update this plan's ledger** — mark A1–A5 `done` with their commits, **CP-A reached**.

---

## Phase B — Aura Master

Branch: `git checkout -b feat/2026-09-14-feedback-batch6`.

### Task B1: Categories become Show / Hide

**Files:**
- Modify: `core/Constants.lua:57-58`, `modules/FilterCompiler.lua`, `defaults/Profile.lua`
- Test: `tests/test_filtercompiler.lua`

**Interfaces:**
- Consumes: nothing.
- Produces: `C.CATEGORY_STATES = { "show", "hide" }`;
  `C.CATEGORY_STATE_LABELS = { show = "Show", hide = "Hide" }`;
  `FC.Compile` returns exactly one category group for every configuration;
  `excludeCategory(con, def, spellEdits)` replaces `applyCategory(con, def, spellEdits, positive)`.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_filtercompiler.lua`:

```lua
-- ── Show / Hide (schema v3) ───────────────────────────────────────────────────────────────────

-- red under: the per-shown-category loop surviving, so two shown categories make two groups.
test("filter: categories set to show add no group — there is always exactly one", function()
    local plan = compile({ filter = { categories = { defensives = "show", raidCDs = "show" } } })
    assertEqual(#plan.groups, 1)
    assertEqual(plan.groups[1].filter, "HELPFUL")
    assertEqual(plan.groups[1].label, "All")
    assertNil(plan.groups[1].candidateFilters)
end)

-- red under: a hidden spell category no longer excluding, or excluding into the wrong field.
test("filter: a category set to hide excludes its spells from the one group", function()
    local plan = compile({ filter = { categories = { defensives = "hide" } } })
    assertEqual(#plan.groups, 1)
    assertTrue(plan.groups[1].candidateFilters.excludeSpellIDs[642])
end)

-- red under: a hidden token category losing its negation.
test("filter: a token category set to hide negates its token", function()
    local plan = compile({ filter = { categories = { cancelable = "hide" } } })
    assertEqual(plan.groups[1].filter, "HELPFUL|!CANCELABLE")
end)

-- red under: "show" being treated as an exclusion, which would invert the whole page.
test("filter: show and hide are not symmetric — show excludes nothing", function()
    local shown = compile({ filter = { categories = { defensives = "show" } } })
    assertNil(shown.groups[1].candidateFilters)
end)

-- red under: an empty hidden spell category writing an empty excludeSpellIDs map.
test("filter: a hidden spell category with no ids left contributes no exclusion", function()
    local edits = { defensives = {} }
    for id in pairs(NS.Categories.Find("HELPFUL", "defensives").spells) do edits.defensives[id] = false end
    local plan = FC.Compile(cfg({ filter = { categories = { defensives = "hide" } } }),
        { categorySpells = edits })
    assertEqual(#plan.groups, 1)
    assertNil(plan.groups[1].candidateFilters)
end)
```

- [ ] **Step 2: Run them and confirm they fail**

Run: `lua tests/run.lua 2>&1 | grep -E "always exactly one|not symmetric"`
Expected: FAIL — two groups, and `label` is `"Defensives"`.

- [ ] **Step 3: Implement the constants and the template**

`core/Constants.lua`:

```lua
C.CATEGORY_STATES = { "show", "hide" }
C.CATEGORY_STATE_LABELS = { show = "Show", hide = "Hide" }
```

`defaults/Profile.lua` — `defaults/Categories.lua` loads first (`AuraMaster.toc:71-72`), so the
template can stamp every key. Inside `CONTAINER_TEMPLATE`'s `filter` block, replace the empty
`categories = {}` with a stamped one built above the template:

```lua
-- Every category row starts at "show": Show is the absence of a decision (it excludes nothing), so
-- a fresh container draws every aura of its type. Stamped rather than left absent so a row always
-- lights a cell and `/am get` prints a value (savedvariables-§2: a default lives here, once).
local function stampedCategories()
    local out = {}
    for _, auraType in ipairs({ "HELPFUL", "HARMFUL" }) do
        for _, def in ipairs(NS.Categories.For(auraType)) do out[def.key] = "show" end
    end
    return out
end
```

and `categories = stampedCategories(),` in the filter block.

- [ ] **Step 4: Implement the compiler**

In `modules/FilterCompiler.lua`, replace `applyCategory` with the negative path alone:

```lua
--- Exclude category `def` from `con`. Categories are a pure exclusion filter since schema v3: a row
--- is Hide, which removes what it matches, or Show, which is the absence of a decision and reaches
--- this function never. Kind `enchant` matches no aura at all — it decides whether the container's
--- weapon-enchant slots exist — so it contributes nothing here.
local function excludeCategory(con, def, spellEdits)
    local kind = def.kind
    if kind == "token" then
        addToken(con, "!" .. def.token)
    elseif kind == "flag" then
        setFlag(con, def.field, not def.value)
    elseif kind == "dispel" then
        addToSet(con, "excludeDispelTypes", def.types)
    elseif kind == "spells" then
        local set = FC.CategorySpells(def, spellEdits)
        if not isEmpty(set) then addToSet(con, "excludeSpellIDs", set) end
    end
end
```

`setFlag` loses its `soft` parameter — every remaining call is a negation, so the collision branch
it guarded is unreachable:

```lua
local function setFlag(con, field, value)
    local current = con.cand[field]
    if current == nil then
        con.cand[field] = value
    elseif current ~= value then
        con.conflict = true
    end
end
```

`splitCategories` returns hidden alone:

```lua
--- The categories set to Hide, in declaration order. Kind `enchant` is skipped: it never narrows an
--- aura group, it decides whether the container has enchant slots (compileEnchant / Compile).
--- @return table hidden, boolean usesSpellIds
local function splitCategories(Categories, auraType, states)
    local hidden, usesSpellIds = {}, false
    for _, def in ipairs(Categories.For(auraType)) do
        if states[def.key] == "hide" and def.kind ~= "enchant" then
            hidden[#hidden + 1] = def
            if def.kind == "spells" then usesSpellIds = true end
        end
    end
    return hidden, usesSpellIds
end
```

`addCategoryGroups` collapses to one group:

```lua
--- The one category group: the base, minus every hidden category, minus the Overrides whitelist
--- (which has its own group and must not be drawn twice).
local function addCategoryGroup(plan, base, cats, look)
    local con = cloneCon(base)
    for _, def in ipairs(cats.hidden) do excludeCategory(con, def, cats.spellEdits) end
    if not isEmpty(cats.whitelist) then addToSet(con, "excludeSpellIDs", cats.whitelist) end
    addGroup(plan, con, "All", look)
end
```

and `FC.Compile`'s call site becomes:

```lua
    local hidden, categoryIds = splitCategories(Categories, auraType, filter.categories or {})
    local whitelisted = addWhitelistGroup(plan, auraType, whitelist, look)
    addCategoryGroup(plan, base,
        { hidden = hidden, whitelist = whitelist, spellEdits = ctx.categorySpells }, look)
```

- [ ] **Step 5: Rewrite the header's HOW CATEGORIES COMBINE block**

```lua
-- HOW CATEGORIES COMBINE (schema v3). A category is Show or Hide, and Show is the absence of a
-- decision. There is always exactly ONE category group: every aura of the type, minus every
-- category set to Hide, minus the Overrides whitelist (which has its own group, so nothing is
-- drawn twice). The priority, highest first:
--
--   1. Overrides -> Blacklist.  Never drawn. Beats everything, the Overrides whitelist included.
--   2. Overrides -> Whitelist.  Always drawn, in its own group, whatever the categories say.
--   3. Category  -> Hide.       Not drawn, unless rule 2 already claimed it.
--   4. Category  -> Show.       Drawn, because nothing removed it. Contributes no constraint.
--
-- A group whose constraints contradict themselves (it would need both `X` and `!X`) is dropped
-- rather than handed to the engine, because it could never match anything.
```

- [ ] **Step 6: Run the gate**

Run: `lua tests/run.lua && luacheck .`
Expected: all green. Existing tests asserting a per-shown-category group must be REWRITTEN to the
new model, never deleted wholesale — each one is a rule someone relied on; the rewrite states what
the rule became.

- [ ] **Step 7: Commit**

```bash
git add core/Constants.lua modules/FilterCompiler.lua defaults/Profile.lua tests/test_filtercompiler.lua
git commit -m "Filters: categories are Show/Hide and compile to one group (C-1..C-6, F-6)"
```

---

### Task B2: Schema v3 migration

**Files:**
- Modify: `core/Database.lua` (new `Database.MigrateV3`, `SCHEMA_STEPS` row)
- Test: `tests/test_database.lua`

**Interfaces:**
- Consumes: B1's constants.
- Produces: `Database.MigrateV3(p) -> number` (containers walked), a test seam exactly as
  `MigrateV2` is; `Database.CurrentSchemaVersion()` returns `3`.

- [ ] **Step 1: Write the failing tests**

```lua
-- red under: the old Whitelist intent being dropped, which would silently WIDEN what a container
-- draws — the one migration failure a player cannot see until an aura appears that should not.
test("v3: a container that whitelisted a category hides every other category of its type", function()
    local p = { containers = { { auraType = "HELPFUL",
        filter = { categories = { defensives = "show", raidCDs = "", cancelable = "" } } } } }
    Database.MigrateV3(p)
    local c = p.containers[1].filter.categories
    assertEqual(c.defensives, "show")
    assertEqual(c.raidCDs, "hide")
    assertEqual(c.cancelable, "hide")
end)

-- red under: "" not being normalized, so a row lights no cell.
test("v3: a container with no whitelisted category gets every row at show", function()
    local p = { containers = { { auraType = "HELPFUL",
        filter = { categories = { defensives = "", raidCDs = "hide" } } } } }
    Database.MigrateV3(p)
    local c = p.containers[1].filter.categories
    assertEqual(c.defensives, "show")
    assertEqual(c.raidCDs, "hide")
end)

-- red under: the enchant flag being read backwards, which would turn enchants on everywhere.
test("v3: includeEnchants becomes the weaponEnchants row and the old key is cleared", function()
    local p = { containers = {
        { auraType = "HELPFUL", filter = { includeEnchants = true, categories = {} } },
        { auraType = "HELPFUL", filter = { includeEnchants = false, categories = {} } },
        { auraType = "HELPFUL", filter = { categories = {} } },
    } }
    Database.MigrateV3(p)
    assertEqual(p.containers[1].filter.categories.weaponEnchants, "show")
    assertEqual(p.containers[2].filter.categories.weaponEnchants, "hide")
    assertEqual(p.containers[3].filter.categories.weaponEnchants, "hide")
    assertNil(p.containers[1].filter.includeEnchants)
end)

-- red under: an ENCHANT container being given a weaponEnchants row it never reads.
test("v3: an ENCHANT container is left alone", function()
    local p = { containers = { { auraType = "ENCHANT", filter = { categories = {} } } } }
    Database.MigrateV3(p)
    assertNil(p.containers[1].filter.categories.weaponEnchants)
end)

test("v3: the current schema version is 3", function()
    assertEqual(Database.CurrentSchemaVersion(), 3)
end)
```

- [ ] **Step 2: Run them and confirm they fail**

Run: `lua tests/run.lua 2>&1 | grep -E "^v3:"`
Expected: FAIL — `Database.MigrateV3` is nil.

- [ ] **Step 3: Implement**

```lua
--- Schema v3 over one profile table: the three-state category model becomes Show / Hide, and the
--- weapon-enchant flag becomes a category row. A test seam as well as the step's body.
---
--- ORDER MATTERS. The Whitelist lift runs first and writes only aura categories; the enchant row is
--- written after it, so the lift can never sweep the enchant row into "hide" as a category the
--- container did not whitelist.
--- @return number  the containers it walked
function Database.MigrateV3(p)
    if type(p) ~= "table" then return 0 end
    local walked = 0
    for _, c in ipairs(orderedContainers(p)) do
        local f = c.filter
        if type(f) == "table" and c.auraType ~= "ENCHANT" then
            f.categories = type(f.categories) == "table" and f.categories or {}
            liftWhitelistIntent(c, f)
            f.categories.weaponEnchants = (f.includeEnchants == true) and "show" or "hide"
            f.includeEnchants = nil
            walked = walked + 1
        end
    end
    return walked
end
```

with, above it:

```lua
--- The old Whitelist meant "draw ONLY the categories set to show". v3 has no such state, so the
--- same narrowing is written out longhand: every category of this container's aura type that was
--- NOT whitelisted becomes Hide. A container that whitelisted nothing was drawing everything, so
--- every row simply becomes Show.
local function liftWhitelistIntent(c, f)
    local auraType = (c.auraType == "HARMFUL") and "HARMFUL" or "HELPFUL"
    local narrowed = false
    for _, state in pairs(f.categories) do
        if state == "show" then narrowed = true break end
    end
    for _, def in ipairs(NS.Categories.For(auraType)) do
        if f.categories[def.key] ~= "show" then
            f.categories[def.key] = narrowed and "hide" or "show"
        end
    end
end
```

and the ladder row:

```lua
    { to = 3, apply = function(db)
        eachProfile(db, function(p, name)
            local n = Database.MigrateV3(p)
            if NS.Debug then
                NS.Debug("Migrate", "v3 profile '%s': Show/Hide categories and weapon enchants over %s container(s)", name, n)
            end
        end)
    end },
```

- [ ] **Step 4: Run the gate**

Run: `lua tests/run.lua && luacheck .`
Expected: all green.

- [ ] **Step 5: Update `docs/schema.md`** — the Migration path section gains the v3 row, in the
shape the v2 row already uses.

- [ ] **Step 6: Commit**

```bash
git add core/Database.lua docs/schema.md tests/test_database.lua
git commit -m "Schema v3: Show/Hide categories and weapon enchants as a category row (E-5, E-8)"
```

---

### Task B3: Weapon enchants become a category — **CP-B**

**Files:**
- Modify: `defaults/Categories.lua`, `defaults/Profile.lua`, `modules/FilterCompiler.lua`,
  `settings/Filters.lua` (schema rows only — the tab is B5), `locales/enUS.lua`
- Test: `tests/test_filtercompiler.lua`, `tests/test_schema_paths.lua`

**Interfaces:**
- Consumes: B1's `excludeCategory` / `splitCategories`, B2's migration.
- Produces: category `weaponEnchants` of kind `enchant`; profile `enchantSlots`;
  `FC.Compile` sets `plan.enchants` from the category row.

- [ ] **Step 1: Write the failing tests**

```lua
-- red under: the enchant row being read as a category (an extra group) or ignored (no enchants).
test("filter: the weaponEnchants row decides the enchant slots, and adds no group", function()
    local on = compile({ unit = "player", filter = { categories = { weaponEnchants = "show" } } })
    assertEqual(#on.groups, 1)
    assertTrue(on.enchants ~= nil)

    local off = compile({ unit = "player", filter = { categories = { weaponEnchants = "hide" } } })
    assertEqual(#off.groups, 1)
    assertNil(off.enchants)
end)

-- red under: enchants leaking onto a container that is not the player's buffs.
test("filter: the enchant row does nothing on a debuff or a non-player container", function()
    assertNil(compile({ unit = "target", filter = { categories = { weaponEnchants = "show" } } }).enchants)
    assertNil(compile({ auraType = "HARMFUL", unit = "player",
        filter = { categories = { weaponEnchants = "show" } } }).enchants)
end)

-- red under: enchantSlots ignored, so unticking a slot changes nothing.
test("filter: the enchant slots come from the profile", function()
    local plan = FC.Compile(cfg({ unit = "player", filter = { categories = { weaponEnchants = "show" } } }),
        { enchantSlots = { mainHand = true, offHand = false, ranged = false } })
    assertEqual(setOf(plan.enchants.slots and { mainHand = true } or {}), "mainHand")
    assertEqual(#plan.enchants.slots, 1)
    assertEqual(plan.enchants.slots[1], "mainHand")
end)
```

- [ ] **Step 2: Run them and confirm they fail**

Run: `lua tests/run.lua 2>&1 | grep -E "weaponEnchants row|enchant slots come"`
Expected: FAIL — no such category.

- [ ] **Step 3: Add the category**

In `defaults/Categories.lua`, at the end of `Cat.HELPFUL`:

```lua
    {
        key = "weaponEnchants", kind = "enchant", label = "Weapon enchants",
        desc = "Your temporary weapon enchants, drawn after the buffs. Only on a container showing your own buffs; which weapon slots count is set on General -> Spell Categories.",
    },
```

and extend the file header's KINDS list with:

```lua
--   enchant the player's temporary weapon enchants. The odd one out: it matches no aura and joins no
--           aura group. Hide takes the container's enchant slots away, Show gives them back
--           (modules/FilterCompiler.lua's Compile, not its group builder).
```

- [ ] **Step 4: Add `enchantSlots` and drop `includeEnchants`**

In `defaults/Profile.lua`: add `enchantSlots = { mainHand = true, offHand = true, ranged = true },`
at profile scope; delete `includeEnchants = false,` (line 115) from `CONTAINER_TEMPLATE`; delete
`includeEnchants = true` from the shipped `Player buffs` container (line 201) — the stamped
`"show"` default now carries it.

- [ ] **Step 5: Read the row in the compiler**

`enchantBlock` takes the slots from the context:

```lua
local ENCHANT_SLOTS = { "mainHand", "offHand", "ranged" }

--- The enchant block: which weapon slots the container draws, and whether a permanent enchant is
--- skipped. The slots are the profile's (General -> Spell Categories); a profile with none, or with
--- every slot unticked, falls back to all three, because a container showing enchants and no slots
--- would draw nothing with nothing to explain it.
local function enchantBlock(filter, enchantSlots)
    local slots = {}
    for _, name in ipairs(ENCHANT_SLOTS) do
        if not enchantSlots or enchantSlots[name] then slots[#slots + 1] = name end
    end
    if #slots == 0 then slots = { "mainHand", "offHand", "ranged" } end
    return { slots = slots, hidePermanent = filter.hidePermanentEnchants ~= false }
end
```

`FC.ProfileContext` carries them:

```lua
        enchantSlots   = db and db.profile and db.profile.enchantSlots,
```

and `FC.Compile`'s enchant line reads the category row:

```lua
    -- ── Weapon enchants appended to a player buff container ─────────────────────────────────
    -- The weaponEnchants category row, not a group: kind `enchant` matches no aura (splitCategories
    -- skips it), so Show is simply "this container has enchant slots".
    local enchantState = (filter.categories or {}).weaponEnchants
    if auraType == "HELPFUL" and cfg.unit == "player" and enchantState ~= "hide" then
        plan.enchants = enchantBlock(filter, ctx.enchantSlots)
    end
```

`compileEnchant` passes `ctx.enchantSlots` too; give it the ctx it now needs.

- [ ] **Step 6: Drop the What-to-show rows**

In `settings/Filters.lua`, delete the `container.filter.includeEnchants` schema row entirely, and
move `container.filter.hidePermanentEnchants` from `group = G_SHOW, subgroup = L["Weapon enchants"]`
to `group = G_CATS` with `grid = "custom"` and `skipRender = true`, so B5's tab can draw it under
the category row. Its `auraTypes` stays `{ HELPFUL = true, ENCHANT = true }`.

- [ ] **Step 7: Run the gate**

Run: `lua tests/run.lua && luacheck .`
Expected: all green. `tests/test_schema_paths.lua` must be updated in this task: `includeEnchants`
is gone, `enchantSlots` is present, and every category row is stamped `"show"`.

- [ ] **Step 8: Commit** — **CP-B**

```bash
git add defaults/ modules/FilterCompiler.lua settings/Filters.lua locales/enUS.lua tests/
git commit -m "Filters: weapon enchants are a category, with profile-wide slots (E-1..E-4, E-7)"
```

---

### Task B11: The revised filter priority

**Files:**
- Modify: `modules/FilterCompiler.lua`, `core/Database.lua` (revert E-8's id copy), `settings/Filters.lua` (Overrides blurb), `locales/enUS.lua`
- Test: `tests/test_filtercompiler.lua`, `tests/test_database.lua`

**Interfaces:**
- Consumes: B1's `excludeCategory`, B3's `enchant` kind.
- Produces: the rank order in spec section 6; a positive sibling to `excludeCategory`; `plan.groups`
  may again hold more than one category group.

The owner revised the priority on 2026-09-15. Read spec sections 6 and 6b — they are binding and
they supersede `C-2` and `C-4`. The two substantive changes:

1. The Overrides **whitelist beats the blacklist** (it was the other way round).
2. A category's **Show is a positive claim**: an aura in at least one Show category is drawn even
   if it is also in a Hide category. Only an aura whose categories ALL say Hide is removed. An aura
   in no category is drawn.

- [x] **Step 1: Write the failing tests** — at minimum: whitelist beats blacklist; an aura in one
      Show and one Hide category is drawn; an aura in two Hide categories is not; an aura in no
      category is drawn; no Hide anywhere still yields exactly ONE group (`R-3`); a Hide plus a Show
      yields a group per shown category plus the catch-all (`R-4`), with no aura drawn twice.
- [x] **Step 2: Run them and confirm they fail.**
- [x] **Step 3: Implement** per `R-1`…`R-7`.
- [x] **Step 4: Revert the v3 migration's whitelist-id copy** (`liftWhitelistSpells` and its tests).
      Rank 3 now does that job properly, for every category kind rather than only `spells`. Leave
      the rest of `MigrateV3` alone.
- [x] **Step 5: Reword the Overrides blurb** — the whitelist now wins where both lists name a spell.
- [x] **Step 6: Add the "only these categories" toggle** per spec section 6c (`R-8`…`R-11`): the
      `container.filter.onlyShown` schema row (bool, default false, Categories group, `skipRender`
      — B5 draws it), the compiler branch that drops the catch-all group while it is on, and
      `FC.WARN.ONLY_SHOWN_NONE` for the draws-nothing case. Tests: on + one Show category draws only
      that category's auras and NOT an uncategorized one; on + nothing shown carries the new warning;
      off behaves exactly as before.
- [x] **Step 7: Gate, commit, push, ledger.**

---
### Task B4: Re-vendor LibKa0s v1.36.0 into Aura Master

**Files:**
- Modify: `libs/LibKa0s/**`, `tests/_kit/**`, `CLAUDE.md` (the provenance line)

**Interfaces:**
- Consumes: A5's local tag `v1.36.0`.
- Produces: `H.ChoiceGrid` accepts `extraColumn`; `H.IdList` entries accept `note`;
  `H.SelectTab` exists.

- [ ] **Step 1: Copy both payloads whole**

```bash
rm -rf libs/LibKa0s && cp -r ../LibKa0s/LibKa0s libs/LibKa0s
rm -rf tests/_kit && cp -r ../LibKa0s/testkit tests/_kit
```

Whole-folder vendoring is mandatory (`tests/test_vendor_sync.lua` checks it file by file against the
tag).

- [ ] **Step 2: Repair line endings**

For every file the copy wrote:
`git add tests/_kit libs/LibKa0s && git checkout -- tests/_kit libs/LibKa0s` after removing the
working copies, per the Global Constraints rule.

- [ ] **Step 3: Roll the provenance line**

In `CLAUDE.md`, `Bundles [LibKa0s](...) v1.35.0 (MIT).` → `v1.36.0`. Same in `DEPENDENCIES.md` and
the `README.md` badge if they stamp it.

- [ ] **Step 4: Expose the new members**

In `settings/OptionsSetup.lua:214`, add `"SelectTab"` to the helper list copied onto `NS.Helpers`,
and add a no-op stub for it in the degradation branch beside `NS.OpenOptionsPage`'s.

- [ ] **Step 5: Run the gate**

Run: `lua tests/run.lua && luacheck .`
Expected: all green, `tests/test_vendor_sync.lua` runs for real (no skips).

- [ ] **Step 6: Commit**

```bash
git add libs/LibKa0s tests/_kit CLAUDE.md DEPENDENCIES.md README.md settings/OptionsSetup.lua
git commit -m "Re-vendor LibKa0s v1.36.0 (ChoiceGrid checkbox cells + extra column, IdList note, SelectTab)"
```

---

### Task B5: The Filters → Categories tab

**Files:**
- Modify: `settings/Filters.lua`, `locales/enUS.lua`
- Test: `tests/test_pages_filters.lua`

**Interfaces:**
- Consumes: `NS.GeneralSpells.Select(key)` (B7, exists); `H.ChoiceGrid`'s `extraColumn` and
  `H.SelectTab` (B4's re-vendor); the `container.filter.onlyShown` schema row (B11, exists).
- Produces: nothing a later task reads.

**This task's requirements were revised on 2026-09-15.** Spec sections 4, 6 and 6c are binding;
where this plan's earlier wording disagrees, the spec wins. In particular the priority blurb is NOT
"blacklist wins" any more.

- [ ] **Step 1: Write the failing tests** — the heading reads `Spell Categories`, not
      `Custom Categories`; the grid has exactly two columns labelled Show and Hide with no third
      state reachable; a `spells`-kind row offers a `See spells` link and a token row does not;
      clicking that link calls `NS.GeneralSpells.Select` with the row's key and lands the player on
      General → Spell Categories; both the Categories and Overrides tabs state the priority order;
      the `onlyShown` toggle is drawn at the top of the tab; `hidePermanentEnchants` renders as a
      CheckBox under the enchant row and still writes a boolean.
- [ ] **Step 2: Run them and confirm they fail.**
- [ ] **Step 3: Implement** `F-1`, `F-2`, `F-3`, `F-5`, `F-6`, `F-7` and `R-10`.
- [ ] **Step 4: The priority blurb** — the five ranks of spec section 6, in order, on both tabs.
      Rank 1 is the Overrides whitelist, rank 2 the blacklist. Do not restate the superseded order.
- [ ] **Step 5: `R-10`** — while `onlyShown` is on, the tab's text must explain that Hide means
      "not shown" rather than "removed". Do NOT dim the Hide column: Hide is the only way to
      un-Show a row.
- [ ] **Step 6: Gate, commit, push, ledger.**

---

### Task B6: `FC.ExplainSpell` and the Overrides notes

**Files:**
- Modify: `modules/FilterCompiler.lua`, `settings/Filters.lua`, `locales/enUS.lua`
- Test: `tests/test_filtercompiler.lua`, `tests/test_pages_filters.lua`

**Interfaces:**
- Consumes: the compiled priority (B11) and the `note` field on an `H.IdList` entry (B4's re-vendor).
- Produces: `FC.ExplainSpell(cfg, id, ctx)`.

**Requirements revised 2026-09-15.** Spec sections 6 and 6c are binding — five ranks, not four, and
the whitelist outranks the blacklist. Anything describing a different order is stale.

- [ ] **Step 1: Write the failing tests** — every rank is reachable and reported: whitelist (1,
      shown) beats blacklist (2, hidden); a spell in one Show and one Hide category is shown at 3;
      a spell whose categories all say Hide is hidden at 4; a spell nothing claims is shown at 5
      with no categories listed. Plus: with `onlyShown` on, a spell that would be rank 5 is reported
      HIDDEN, because the catch-all group is gone.
- [ ] **Step 2: Run them and confirm they fail.**
- [ ] **Step 3: Implement `FC.ExplainSpell(cfg, id, ctx)`** returning
      `{ verdict = "shown" | "hidden", rank = 1..5, categories = { { key, label, state } } }`.
      Pure, in the file's existing sense: no frames, no database, `cfg` and `ctx` in, a table out.
      It reasons about `spells`-kind categories ONLY — a token, flag or dispel category matches
      auras the addon cannot enumerate by id, and a confident guess there is worse than silence.
      Say that in the doc comment.
- [ ] **Step 4: The Overrides entry notes** — each entry carries its verdict as the `note` the
      library draws under the name. A spell nothing claims and nothing contradicts gets NO note;
      the lists are long and a note on every line is noise.
- [ ] **Step 5: Gate, commit, push, ledger.**

---

### Task B8: Max duration

**Files:**
- Modify: `settings/Filters.lua`, `locales/enUS.lua`, `docs/scope.md`
- Test: `tests/test_pages_filters.lua`

**Interfaces:**
- Consumes: nothing.
- Produces: nothing other tasks read.

- [ ] **Step 1: Write the failing test**

```lua
-- red under: the preset not writing the slider's path, which would make it decorative.
test("filters: a max-duration preset writes the same path as the slider", function()
    local ctx = T.RenderTab("filters", "What to show")
    T.ChooseDropdown(ctx, L["Max duration"], 300)
    assertEqual(T.Container().filter.maxDuration, 300)
end)

-- red under: the description promising a lower bound the engine cannot honor.
test("filters: the max-duration description says there is no minimum", function()
    local row = T.SchemaRow("container.filter.maxDuration")
    assertTrue(row.desc:find("no minimum", 1, true) ~= nil)
end)
```

- [ ] **Step 2: Run them and confirm they fail**

Run: `lua tests/run.lua 2>&1 | grep -E "max-duration"`
Expected: FAIL.

- [ ] **Step 3: Implement**

Relabel the row and add the presets beside it:

```lua
    {
        path = "container.filter.maxDuration", page = PAGE, group = G_SHOW, auraTypes = BUFFS_DEBUFFS,
        type = "number", min = 0, max = 3600, step = 5, label = L["Max duration"],
        desc = L["Hide auras whose full duration is longer than this — a 60 keeps short cooldowns and drops hour-long buffs. 0 is no limit, and permanent auras are hidden while a limit is set. There is no minimum: the engine can cap a duration but cannot require one."],
    },
```

```lua
-- Presets for the slider beside it. Not a separate setting: the dropdown writes the slider's own
-- path, so there is one stored value and no way for the two to disagree. A stored value matching no
-- preset leaves the dropdown blank rather than snapping the slider to the nearest one.
local MAX_DURATION_PRESETS = { 0, 30, 60, 300, 600, 1800 }
local MAX_DURATION_LABELS = {
    [0] = "No limit", [30] = "30 seconds", [60] = "1 minute",
    [300] = "5 minutes", [600] = "10 minutes", [1800] = "30 minutes",
}
```

drawn as a dropdown in the What-to-show tab's bespoke render (add one if the tab has none, in the
shape `renderCategories` uses), writing through `NS.SetByPath("container.filter.maxDuration", v)`.

- [ ] **Step 4: Record the engine limit**

`docs/scope.md`, under *Out of reach on this client (12.1)*, after the no-duration entry:

```markdown
- **A minimum duration.** The engine's candidate filters cap a duration (`maxDuration`) but cannot
  require one to be at least N seconds, and an aura's duration is unreadable while auras are secret,
  so it cannot be filtered after the fact either. Requested 2026-09-14; declined with the rule.
```

- [ ] **Step 5: File the issue**

```bash
gh issue create --title "Minimum duration filter (not possible on 12.1)" \
  --label "state:will-not-do" --label "severity:low" \
  --body "Requested 2026-09-14. Blizzard's aura candidate filters expose maxDuration only; there is no minimum, and durations are unreadable while auras are secret. Recorded in docs/scope.md."
```

- [ ] **Step 6: Run the gate and commit**

```bash
lua tests/run.lua && luacheck .
git add settings/Filters.lua locales/enUS.lua docs/scope.md tests/test_pages_filters.lua
git commit -m "Filters: max duration presets and an honest description; no minimum exists (D-1..D-4)"
```

---

### Task B9: The container mouse blocker

**Files:**
- Modify: `modules/Container.lua`, `modules/Style.lua`, `docs/smoke-tests.md`
- Test: `tests/test_container.lua`

**Interfaces:**
- Consumes: the existing `Style.TakesHover(cfg)`.
- Produces: `Style.ApplyBlockerBehavior(frame, cfg)`; `container.blocker`.

- [ ] **Step 1: Write the failing tests**

```lua
-- red under: no blocker, so the gaps between bars leave the world unit moused over (the 2026-09-14
-- report: an aura tooltip and a unit tooltip drawn side by side).
test("container: a container has a mouse blocker covering it, below its buttons", function()
    local c = T.NewContainer({ style = "bars" })
    assertTrue(c.blocker ~= nil)
    assertTrue(c.blocker.__allPoints)
    assertTrue(c.blocker:GetFrameLevel() < c.engine:GetFrameLevel())
end)

-- red under: the blocker ignoring the container's own mouse settings, which would swallow clicks a
-- click-through container exists to pass on.
test("container: the blocker follows TakesHover and never takes clicks", function()
    local on = T.NewContainer({ behavior = { tooltips = true, clickThrough = false } })
    assertEqual(on.blocker.__mouseMotion, true)
    assertEqual(on.blocker.__mouseClick, false)

    local through = T.NewContainer({ behavior = { clickThrough = true } })
    assertEqual(through.blocker.__mouseMotion, false)

    local quiet = T.NewContainer({ behavior = { tooltips = false } })
    assertEqual(quiet.blocker.__mouseMotion, false)
end)
```

- [ ] **Step 2: Run them and confirm they fail**

Run: `lua tests/run.lua 2>&1 | grep -E "^container: (a container has|the blocker)"`
Expected: FAIL — `c.blocker` is nil.

- [ ] **Step 3: Implement the rule in `modules/Style.lua`**

```lua
--- The container-wide mouse blocker's behavior. A container's BUTTONS hold the hover
--- (ApplyBehavior), but the gaps between them and the container's own padding hold nothing, so the
--- world unit behind is moused over there and draws its GameTooltip beside the aura's separate
--- AuraButtonTooltip (the owner's 2026-09-14 report). One frame under the buttons, covering the
--- container, closes those gaps.
---
--- It takes MOTION only, never clicks: right-click cancel belongs to the buttons, and a container
--- that swallowed clicks in its gaps would break everything behind it.
function Style.ApplyBlockerBehavior(frame, cfg)
    if frame.SetMouseMotionEnabled then frame:SetMouseMotionEnabled(Style.TakesHover(cfg)) end
    if frame.SetMouseClickEnabled then frame:SetMouseClickEnabled(false) end
end
```

- [ ] **Step 4: Build it in `modules/Container.lua`**

In the container's build path, beside the engine frame:

```lua
    -- Under the engine's buttons: it must never sit between the mouse and an aura, only behind it.
    self.blocker = self.blocker or CreateFrame("Frame", nil, frame)
    self.blocker:SetAllPoints(frame)
    self.blocker:SetFrameLevel(math.max((frame:GetFrameLevel() or 1) - 1, 0))
    NS.Style.ApplyBlockerBehavior(self.blocker, cfg)
    self.blocker:Show()
```

Re-gate it wherever `Style.ApplyBehavior` is re-applied, and hide it with the container in `Retire`.

- [ ] **Step 5: Add the smoke step**

`docs/smoke-tests.md`, in the mouse section:

```markdown
- [ ] **Tooltip does not bleed through a container.** Stand so a bars container is drawn over a
      world unit (a player or an NPC). Hover a bar: only Aura Master's aura tooltip is drawn. Move
      the cursor into the gap between two bars, and into the container's padding: still no unit
      tooltip. Then set the container to Click-through on Layout -> Mouse and confirm the unit
      tooltip comes back, which is what click-through is for.
```

- [ ] **Step 6: Run the gate and commit**

```bash
lua tests/run.lua && luacheck .
git add modules/Container.lua modules/Style.lua docs/smoke-tests.md tests/test_container.lua
git commit -m "Containers: a mouse blocker closes the gaps that leaked the world tooltip (T-1..T-5)"
```

---

### Task B10: Docs — **CP-C**

**Files:**
- Modify: `docs/ARCHITECTURE.md`, `docs/settings-panel.md`, `docs/schema.md`, `docs/common-tasks.md`,
  `docs/data-flow.md`, `docs/module-map.md`, `docs/test-cases.md`, `docs/smoke-tests.md`, `README.md`
- Test: `tests/test_docs.lua` (existing gates must stay green)

This task's scope GREW during the batch. Everything below is owed.

- [x] **Step 1: The filter priority** (`P-2`). Add a *Filter priority* section to
      `docs/ARCHITECTURE.md` carrying spec section 6's five-rank table verbatim, and name
      `FC.ExplainSpell` as what the panel reads it from. Mirror the order in
      `docs/settings-panel.md`.
- [x] **Step 2: The ownerless tri-state prose** (`P-5`, ruled 2026-09-15). `docs/schema.md` and
      `docs/common-tasks.md` still describe the three-state model and tell a future author to add a
      branch to `applyCategory`, which no longer exists. No other task owned these two files.
- [x] **Step 3: The migration's visible side effect.** Document that a container which used the old
      Whitelist gains that category's spell ids on its Overrides whitelist — a player will see them
      appear and should find the reason where they look.
- [x] **Step 4: `onlyShown`** appears in no doc. Add it to `docs/settings-panel.md` and
      `docs/schema.md`, including that the max-aura cap is per group and what that means.
- [x] **Step 5: The smoke-test checks this batch could not settle headlessly.** Add each, phrased so
      the owner can falsify it, not merely confirm it:
      - the ~15 aura groups a container compiles to once anything is Hidden — what that costs in
        frame time, and whether the client caps groups per container;
      - the Hide column reading as live rather than dimmed in the real Ace3 skin;
      - the *See spells* link landing on the right category;
      - the five-clause priority blurb wrapping readably at panel width;
      - the yellow fill's size and placement on a grid cell;
      - an Overrides entry's note wrapping readably under the entry;
      - that a debuff aura always carries `isFromPlayerOrPlayerPet` — the debuff catch-all group is
        dropped as a contradiction whenever anything is hidden, which is only correct while that
        flag pair partitions every aura.
- [x] **Step 6: Counts and citations.** Regenerate `docs/test-cases.md` and the README `[tests]`
      badge from `lua tests/run.lua --list`. Every count claim must match the tree.
- [x] **Step 7: File an issue on the docs gate's blind spot.** `tests/test_docs.lua` checks only
      that a cited line EXISTS and is non-blank, so a citation that has drifted onto unrelated code
      passes. Nine rotted in this batch and were caught by a human reading, not by the gate. File it
      with `gh` (`state:untriaged`, `severity:low`); if `gh` fails, do not retry with credentials —
      report it.
- [x] **Step 8: Gate, commit, push, ledger.**

---

## Phase C — the rest of the collection

### Task C1: Re-vendor v1.36.0 into the other eight addons

**Repos — confirmed 2026-09-15 against `../WowAddonStandards/standards/ADDONS.md` and by checking
`libs/LibKa0s/` on disk, not guessed.** Nine siblings vendor the library: AbsorbTracker, BankLedger,
ConsumableMaster, KickCD, LootHistory, MultiMeters, PanelMaster, PrettyChat, WhatGroup. With Aura
Master (task B4) that is the roster's ten addons.

**BuffTextNotifications, SimplePartyTargets and WhoGotLoots do NOT vendor LibKa0s** — an earlier
draft of this task listed them in error. Do not touch them.

For each repo, in its own branch `chore/2026-09-14-revendor-v1.36.0`:

- [ ] **Step 1:** `rm -rf libs/LibKa0s && cp -r ../LibKa0s/LibKa0s libs/LibKa0s` and the same for
  `tests/_kit` ← `../LibKa0s/testkit`.
- [ ] **Step 2:** Repair line endings per the Global Constraints rule.
- [ ] **Step 3:** Roll the CLAUDE.md / DEPENDENCIES.md / README.md provenance from v1.35.0 to
  v1.36.0.
- [ ] **Step 4:** `lua tests/run.lua && luacheck .` — both green, `test_vendor_sync` running for
  real.
- [ ] **Step 5:** Commit:
  `git commit -m "Re-vendor LibKa0s v1.36.0"`.

No addon adopts the new surfaces in this task. A re-vendor that changes behavior is a separate
decision, and `ChoiceGrid`'s new cell art is the only visible change — if any repo other than Aura
Master draws a `ChoiceGrid`, say so in the report rather than restyling it silently.

---

### Task C2: Final battery and report — **CP-D**

- [ ] **Step 1:** In each touched repo: `lua tests/run.lua`, `luacheck .`,
  `lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .`. Record the numbers.
- [ ] **Step 2:** Confirm every tree is clean, the LibKa0s local tag `v1.36.0` is on HEAD of its
  branch, and nothing has been pushed.
- [ ] **Step 3:** Update this plan's ledger with every commit.
- [ ] **Step 4:** Report to the owner: what shipped per requirement ID, the suite counts before and
  after, the smoke-test steps owed in the client (the tooltip step from B9, plus a pass over the
  rebuilt Filters → Categories tab), and the one behavior change to call out — **weapon enchants
  are ON by default for a new player buff container**, where existing containers keep what they
  draw via the v3 migration.

---

## Self-review notes

- **Spec coverage:** `K-1`→A1, `K-2`→A2, `K-3`→A3, `K-4`→A4; `C-1`…`C-6`+`F-6`→B1; `E-8`,`E-5`→B2;
  `E-1`…`E-4`,`E-7`→B3; `F-1`,`F-2`,`F-4`,`F-5`,`F-7`→B5; `F-3`→B5+B7; `P-1`,`P-3`,`P-4`→B6;
  `E-6`→B7; `D-1`…`D-4`→B8; `T-1`…`T-5`→B9; `P-2`→B10.
- **Naming consistency:** `excludeCategory` (not `applyCategory`) from B1 onward;
  `addCategoryGroup` singular; `FC.ExplainSpell` returns `rank`, never `rule`, and the panel's
  user-facing text says "rule N" — that asymmetry is deliberate and stated in B6.
- **The test helpers** named in the AM tests (`T.RenderTab`, `T.AllText`, `T.ChoiceGridRows`,
  `T.ClickChoiceGridExtra`, `T.SelectedCategory`, `T.ClickToggle`, `T.ChooseDropdown`,
  `T.SchemaRow`, `T.NewContainer`) must be checked against `tests/page_helpers.lua` at the start of
  each task; where one does not exist, add it there rather than inlining the poke, and say so in the
  task's commit.
