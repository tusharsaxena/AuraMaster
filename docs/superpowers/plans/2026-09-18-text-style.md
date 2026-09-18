# Text Container Style Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship issue #2's third container style, **Text** (each aura one line built from a
player-written template, with an optional icon, a loop animation and a running-out blink), with the
fourth starter container "Player cooldowns" (spec §7.1), and the owner's Part B backlog: B1 a real
session-only test mode (unlock no longer hides live auras), B2 an X remove icon on every spell list
(LibKa0s v1.44.0 `removeStyle = "icon"`), B3 the muted-gold "Not in use" notice, B4 a measured bar
time-text box, B5 Style resets Fill.

**Architecture:** A pure parser (`modules/TextTemplate.lua`) compiles a template into ordered
PIECES; `modules/Style_Text.lua` draws each piece as one single-anchored, auto-sized font string in a
chain inside clip → animation → text-area frames, binds each engine field once (`SetSpellName`,
`SetApplicationCount` with a rule formatter, `SetDispelTypeText` with a text map, `SetDurationText`
with a `textFormat` and a prebuilt binding), and builds its three loops once, playing one at dress
time. `modules/Style.lua` gains the shared icon helpers (moved from Bars), the style dispatch and the
duration-run helpers; `core/Compat.lua` gains four guarded wrappers; `settings/Text.lua` is a new
Containers sub-page; the write seam passes a row's refusal reason (third return) and the replaced
value (`onChange`'s third argument). Part B rides the same seams: `NS.State.testMode` +
`H.MasterControls` `testModePath`, a LibKa0s minor, one color constant, a measuring helper.

**Tech Stack:** Lua 5.1 (WoW Retail 12.1, interface 120100), Ace3, LibKa0s v1.43.0 → v1.44.0, the
headless harness `lua tests/run.lua` (LibKa0s testkit revision 23), `luacheck`, `lizard`.

**Spec:** docs/superpowers/specs/2026-09-18-text-style-design.md (Part A §1–15, Part B B1–B5 and
smoke 11–16). Read it with this plan; it is binding.

## Global Constraints

- **Never stage, commit, push, tag or bump a version.** Every "commit" step of the house template is a **Checkpoint: run the green gate** here; the last task hands back to the owner (CLAUDE.md).
- Green gate after every task, from the repo root: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua` (0 failed) and `/home/tushar/.claude/wow-addon/bin/ka0s-bounded luacheck .` (`0 warnings / 0 errors`).
- One case at a time: the harness has no filter flag (`tests/_kit/framework.lua` parses only `--list`, `--jobs`, `--shard`), so a single case is run as `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua 2>&1 | grep -A3 "<case name fragment>"`.
- Complexity (final task, and whenever a task adds a branchy function): `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .` — **no function above CCN 15**.
- Lizard's `#` rule (`tests/test_lintconfig.lua`, last case): no keyword (`end`, `then`, `do`, `and`, `or`, …) and no unbalanced `{`/`}` after a length operator on the same line. Take the length into a local first (`local n = #t` then `t[n + 1] = v`).
- The Ka0s WoW Addon Standard (`../WowAddonStandards/standards/standards/*.md`) is binding; spec §15 finds **no deviation**. A deviation found mid-task STOPS the task and is reported, never taken (CLAUDE.md).
- Every user-visible string goes through `NS.L`, with its key added to `locales/enUS.lua` as `L["x"] = "x"` (key == value), ASCII only except the em dash, US spelling (`tests/test_locale.lua`, `tests/test_docs.lua`). A `*_LABELS` value in `core/Constants.lua` needs its key too.
- Line endings: every file is **CRLF** (`.gitattributes`); `tests/_kit/test_eol.lua` fails an LF file. After writing a file with a tool that writes LF, convert it: `python3 -c "import sys;p=sys.argv[1];s=open(p,newline='').read().replace('\r\n','\n');open(p,'w',newline='').write(s.replace('\n','\r\n'))" <path>`.
- `docs/midnight-quirks.md` carries an **uncommitted owner edit** (the 2026-09-18 "Measured in-game" block). Edit around it; never `git checkout` it.
- A `file:line` citation in `docs/*.md`, `README.md` or `DEPENDENCIES.md` that a code change moves is re-pointed **in the same task** (`tests/test_docs.lua`'s citation cases name each one). Find the new line with `grep -n '<the symbol the sentence names>' <file>`.
- Defaults live only in `defaults/Profile.lua` (savedvariables-§2); every settings write goes through `NS.SetByPath`.
- LibKa0s work (B2) happens in `/mnt/d/Profile/Users/Tushar/Documents/GIT/LibKa0s` under its own CLAUDE.md, and **stops before any tag or push** for the owner's go-ahead.

---

## Status ledger (update after every task)

**How to resume after an interruption.** Work runs on branch `feat/text-style` (never merge, push or
tag without the owner's approval; incremental commits are allowed). One commit per task, made by the
controller after the task's review; README.md carries owner edits that ride along with the task
that touches it (13 or 18). The live execution ledger, with every ruling, deferred minor and review
package, is `.superpowers/sdd/2026-09-18-text-style/progress.md` (git-ignored; the table below is the
committed copy). To resume: `git log --oneline master..feat/text-style`, read that ledger, then
continue at the first row below that is not `done`. A row `in review` has its commit(s) and needs its
review or fix round finished; a row `in progress` may have uncommitted work in the tree, so check
`git status` before re-dispatching. Task 15 STOPS for the owner to commit and tag LibKa0s v1.44.0.

| # | Task | Status | Notes |
|---|---|---|---|
| 1 | B3 muted-gold notice | done | 61b411c; review clean |
| 2 | B4 measured bar time box | done | 294bfe7; review clean |
| 3 | B5 Style resets Fill (+ seam passes the replaced value) | done | 07f8016; review clean |
| 4 | Text-style client APIs: fixture + four Compat wrappers | done | ecf5855; review clean |
| 5 | Constants + the template parser | in review | 11f86ab + fix 3d8ebbb; fix round 2 (one missing test) in progress |
| 6 | The Text settings surface (data block, page, refusal reasons, notices, sections, slash) | todo | |
| 7 | Style.lua shared helpers; Bars on the shared icon helpers | todo | |
| 8 | Style_Text: the chain, bindings, loops, icon, preview fill | todo | |
| 9 | Preview dispatch + the text shape in the engine's structure key | todo | |
| 10 | The fourth starter "Player cooldowns" + Cat.StatesShowing + test fallout | todo | |
| 11 | Render coverage walks the Text page | todo | |
| 12 | perf: a text restyle scenario | todo | |
| 13 | Part A docs | todo | |
| 14 | B1 unlock keeps live auras; a standard session-only test mode | todo | |
| 15 | B2a LibKa0s v1.44.0 `removeStyle = "icon"` (STOP before tag/push) | todo | |
| 16 | B2b re-vendor LibKa0s v1.44.0 into Aura Master | todo | needs the owner's go-ahead on 15 |
| 17 | B2c spell lists adopt the X icon; Restore moves to the top | todo | needs 16 |
| 18 | Final gate, inventory, lizard; hand back to the owner | todo | |

**Dependency order:** 1–3 are independent of everything and of each other. 4 → 5 → 6 → 7 → 8 → 9 →
10 → 11 → 12 → 13 are sequential. 14 needs 9 (both change `modules/Container.lua` and
`modules/Preview.lua`) and 3 (the `onChange` seam). 15 → 16 → 17; 16 and 17 also wait for the owner
to release LibKa0s v1.44.0 after 15. 18 is last.

---

## File structure

| File | Change | Responsibility after |
|---|---|---|
| `core/Constants.lua` | modify | `NOTICE_COLOR` (B3); `STYLE_FILL_AXIS` (B5); `"text"` style; `TEXT_JUSTIFY_H/V`, `TEXT_ICON_POSITIONS`, `TEXT_ANIMS`, `TEXT_TOKENS`, `TEXT_TOKEN_LABELS`, `TEXT_DISPEL_TYPES/LABELS`, `TEXT_TEMPLATE_MAX` (+ labels); Bloodlust placeholder gains `dispel = "Magic"` |
| `core/Compat.lua` | modify | + `DurationProperty`, `CreateRuleFormatter`, `CreateDurationBinding`, `BlinkTextColor` (17 → 21 shims) |
| `core/State.lua` | modify | + session-only `testMode` and `State.SetTestMode` (B1) |
| `core/AuraMaster.lua` | modify | `PLAYER_REGEN_DISABLED` ends test mode (B1) |
| `core/LauncherSetup.lua` | modify | left-click toggles test mode (B1) |
| `defaults/Profile.lua` | modify | `font()` helper; `CONTAINER_TEMPLATE.text`; fourth starter |
| `defaults/Categories.lua` | modify | + `Cat.StatesShowing(keys)` |
| `modules/TextTemplate.lua` | **create** | the pure template parser/compiler: `TT.Compile`, `TT.Validate`, `TT.ForDraw`, `TT.TOKENS` |
| `modules/Style.lua` | modify | `StyleKey`/`Styler`/`StructureKey` dispatch; `ElementSize` and `UsesClassColor` for every style; `ApplyFont`; `IconSizeFor`/`IconInset`/`LayoutIcon` (moved from Bars); `DurationTextFormat`, `BindDurationFormat`, blink curve memo; `PreviewSeconds`; `TimeTextWidth` (B4) |
| `modules/Style_Bars.lua` | modify | uses the shared icon helpers; `timeBoxWidth` measures (B4) |
| `modules/Style_Text.lua` | **create** | the Text styler: regions, chain per shape, layout, fonts, loops, bindings, preview fill |
| `modules/Preview.lua` | modify | dispatch through `Style.StyleKey`/`Style.Styler` |
| `modules/Container.lua` | modify | structure key through `Style.StructureKey`; B1 visibility (live engine while unlocked, outline) |
| `modules/ContainerManager.lua` | modify | `COPY_SECTIONS` + `"text"`; copy writes identity before sections (B5) |
| `settings/Schema.lua` | modify | `onChange(value, id, old)` (B5); a row's refusal reason as the seam's third return; `text` page and section |
| `settings/OptionsSetup.lua` | modify | notice color (B3); `disabledNotice` may be a function; panel prints a reasoned refusal |
| `settings/Slash.lua` | modify | `set` prints the reason; `new … text`; `test` verb (B1) |
| `settings/Containers.lua` | modify | Style row `onChange` resets Fill (B5); text in the copy sections; wording |
| `settings/Bars.lua`, `settings/Icons.lua` | modify | style-aware `disabledNotice` |
| `settings/Text.lua` | **create** | the Text page |
| `settings/General.lua` | modify | `testModePath` on Master controls (B1) |
| `settings/GeneralSpells.lua`, `settings/Filters.lua` | modify | `removeStyle = "icon"`, Restore at the top (B2) |
| `locales/enUS.lua` | modify | every new key; three retired keys removed |
| `AuraMaster.toc` | modify | `modules\TextTemplate.lua`, `modules\Style_Text.lua`, `settings\Text.lua`, their notes; Notes line |
| `tests/text_apis.lua` | **create** | recording stand-ins for the Text style's client APIs |
| `tests/region_builder.lua` | **create** | a recorder that builds recorders (distinct font strings) |
| `tests/test_texttemplate.lua`, `tests/test_style_text.lua`, `tests/test_pages_text.lua` | **create** | the new suites |
| `tests/run.lua` | modify | the three suites declared |
| `tests/test_*.lua` (compat, style, preview, container, schema, pages_*, defaults, database, filtercompiler, render_coverage, loadorder, optionssetup, slash*, bus, debuglogsetup, launcher, general, …) | modify | per task |
| `tests/perf.lua` | modify | `restyleText` scenario |
| `docs/*.md`, `README.md` | modify | Task 13 and each Part B task |
| `../LibKa0s/LibKa0s/OptionsWidgets.lua` + its tests/docs/CHANGELOG | modify | B2a |
| `libs/LibKa0s/`, `tests/_kit/`, `CLAUDE.md` | re-vendor | B2b |

## Decisions this plan pins down (the spec left them to the implementation)

- **Piece shape** (`modules/TextTemplate.lua`): `{ kind = "literal", text }`, `{ kind = "name" }`,
  `{ kind = "stacks", pre, post, format }` (`format` = `pre .. "%d" .. post` with `%` doubled in both),
  `{ kind = "dispel", pre, post }`, `{ kind = "duration", pre, post, format, components }` where
  `format` is `pre .. run .. post` with each token as `{}` and `components = { { prop =
  "RemainingDuration"|"TotalDuration"|"ElapsedDuration"|"RemainingPercent"|"ElapsedPercent", fmt =
  "time"|"percent" }, … }`. `TT.Compile` returns `{ ok = true, pieces, single, shape, hasDuration }` or
  `{ ok = false, err }`, memoized per template string (shared; never edited by a caller). `shape` is
  the kinds joined by `|` (`"name|stacks|duration"`).
- **Token lexing:** `$name$` is a token only when `name` matches `[%w_]+`; any other `$` is literal,
  so `costs $5` is text. The first broken rule in spec order (1 → 8) is reported.
- **Rebuild keying:** a chain of font strings is kept per **shape**, on its own chain frame inside the
  text area (`frame.__amChains[shape]`). A same-shape edit re-dresses the same strings; a new shape
  hides the current chain frame (and with it every string the engine may still write into) and takes
  or builds the one for the new shape. Live buttons additionally get a **new engine** on a shape
  change: `Style.StructureKey(cfg)` returns `"text:" .. shape`, folded into `modules/Container.lua`'s
  structure key, so no engine binding outlives its shape. Preview frames rely on the chain swap.
- **Frames:** `clip` (the element, `SetClipsChildren(true)`) → `anim` (fills clip; the loops) → the
  icon + `area` (the text box, element less icon and gap, `SetClipsChildren(true)` again, so a long
  line never runs under the icon) → `chain` → pieces. A bounce is clipped by `clip`.
- **Loops:** all three AnimationGroups (pulse Alpha BOUNCE, blink Alpha REPEAT with start/end delays,
  bounce Translation BOUNCE) are built once in `build`; every dress sets their timing, `Stop`s all
  three and `Play`s the chosen one, each call through `Style.Bind` (guarded). Building all three is
  what lets every Animation row reach a region (render coverage) and costs three groups per button.
- **Blink curve:** `Compat.BlinkTextColor(threshold, blink, normal)`: a Step color curve over
  `RemainingDuration`, a point every 0.25 s from 0 up to the threshold alternating `blink`'s alpha
  and 0.1, then `normal` at the threshold. With blink on and recolor off it blinks the font color.
  Memoized like the expiring curve. The binding with `SetUpdateInterval(0.1)` is a second per-button
  binding (`am.blinkBinding`), built only when blink is on.
- **Center fallback:** `Style.Text.JustifyFor(s, compiled)` answers `"LEFT"` for `CENTER` unless
  `compiled.single`; the Text page draws the note under Placement when the stored justify is Center
  and the template is not single.
- **Cheat sheet:** the General tab is a bespoke tab (`spec.tabs` keyed by the General group) that
  renders its schema rows in two `H.RenderRows` calls with the cheat sheet (`H.TextRow` per token,
  small font) between the Template box and Placement, then the centering note.
- **Refusal text:** a row's `validate` may answer `false, reason`. `settings/Schema.lua` passes the
  reason as the third return of `NS.SetByPath` / `NS.CheckWrite`; `/am set` prints it indented under
  `Invalid value for <path>` (slash-commands-§6's shape), and the panel prints the same two lines for a
  reasoned refusal only (a bare refusal stays silent as today). `/am set` takes the remainder
  verbatim, so a template is typed **without** quotes.
- **Stored template invalid:** `TT.ForDraw(template)` falls back to the default template's compile;
  `Style.Text.Compiled` logs one `[Style]` debug line per bad template string.
- **Mock:** the kit's mock already records any PascalCase call; no kit change. Two new non-suite
  helpers: `tests/text_apis.lua` (the client APIs as recorders) and `tests/region_builder.lua`
  (distinct font strings, animation groups and frames).
- **Notices:** `disabledNotice` may be a function of the container, so Bars says "drawn as text" to
  a text container rather than claiming icons.
- **B5 mechanism:** `onChange` gets the replaced value as a third argument (read before the write);
  the Style row writes `container.layout.axis` through `NS.SetByPath` only when `old ~= new`. A nested
  `SetByPath` inside `onChange` is an ordinary second write (its own validate, store, CONFIG_CHANGED);
  both CONFIG_CHANGEDs coalesce into one apply pass and `structural()` into one panel rebuild. A
  copy-from now writes the identity keys first, so the copied layout lands after the Style row's
  reset.
- **Where the spec's words and the repo differ** (each resolved here, none a deviation from the standard):
  - Spec §11 puts the text-style cases in `tests/test_style.lua`; they go to a new
    `tests/test_style_text.lua`, as Bars and Icons have `test_style_bars.lua` / `test_style_icons.lua`
    (only the shared-helper cases go to `test_style.lua`).
  - Spec §7.1 says the starter-count assertions "need no edits"; measured, the fourth starter turns
    35 cases red (Task 10 Step 4b lists every one).
  - Spec B1's `testModePath = "testMode"` is `state.testMode` here (the addon's session rows live under
    `state.`); its "the launcher tooltip text follows" is moot (no `onTooltipShow` is passed).
  - Spec B4 says the mock "returns a size-proportional width"; the kit's does not (its
    `GetStringWidth` answers the frame), so `Style.__measurer` is a test seam a case replaces with a
    recorder that does, and the shared environment exercises the ems fallback.
  - Spec B2's LibKa0s cases go to a new `tests/test_options_idlist_remove.lua`, because
    `tests/test_options_widgets.lua` is over layout-§1's cap (LibKa0s issue #33).
  - The Bars and Icons pages' "Not in use" notice said "drawn as icons" / "drawn as bars" for every
    other container; with a third style it names the actual one (`disabledNotice` as a function).

## The citation re-point helper (used by every task that moves cited lines)

Nothing is committed while this plan runs, so `HEAD` stays the pre-plan commit and still holds every
cited line's original text. This helper reads the docs suite's drift report and moves each
`file:line` citation to the line that now holds the same text. Save it once as
`/tmp/citefix.py` (outside the repo) and run it from the repo root after a failing docs case:

```python
# /tmp/citefix.py — re-point drifted file:line citations by the cited line's original text (HEAD).
import re, subprocess, sys
out = sys.stdin.read()
drift = (re.findall(r'  (\S+\.md) cites (\S+?):(\d+)(?:-(\d+))? \(none of', out)
         + re.findall(r'(\S+\.md):\d+ cites (\S+?):(\d+)(?:-(\d+))? \(a blank line\)', out))
for doc, f, a, b in drift:
    old = subprocess.run(['git', 'show', 'HEAD:' + f], capture_output=True, text=True).stdout.split('\n')
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
then run the suite again. A `BY HAND` line is a citation whose own line was edited: open the doc,
find the symbol its sentence names with `grep -n`, and set the number yourself.

---

### Task 1: B3 — the "Not in use" notice in muted gold

**Files:**
- Modify: `core/Constants.lua` (insert before line 143, `-- Time text. Each is a SecondsFormatter setup; …`)
- Modify: `settings/OptionsSetup.lua:511-525` (`drawDisabledNotice` and its doc comment)
- Modify: `docs/settings-panel.md:346` and `:387` ("small gray note" → "small muted-gold note")
- Test: `tests/test_optionssetup.lua` (append), `tests/test_pages_bars.lua:17-24,28,73`, `tests/test_pages_icons.lua:18-25,29,70`

**Interfaces:**
- Consumes: nothing new.
- Produces: `NS.Constants.NOTICE_COLOR = "ffc8a85a"` (the AARRGGBB body of a `|c` escape). Every page
  that declares `disabledNotice` (Bars, Icons, and Task 6's Text) draws `"|c" .. C.NOTICE_COLOR .. text .. "|r"`.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_optionssetup.lua`:

```lua
test("options: a page drawn for another style heads its tabs with the notice in muted gold (B3)", function()
    local NS2, m2 = fresh()
    local P = dofile("tests/page_helpers.lua")(NS2, m2)
    NS2.State.SetActiveContainer(2)   -- the starter icon row
    local ws = P.show("Bars")
    local want = "|c" .. NS2.Constants.NOTICE_COLOR
    assertEqual(NS2.Constants.NOTICE_COLOR, "ffc8a85a")
    local hit
    for _, t in ipairs(P.texts(ws)) do
        if t:find("Not in use:", 1, true) then hit = t end
    end
    -- red under: drawDisabledNotice keeping the old gray |cff808080
    assertTrue(hit ~= nil and hit:sub(1, #want) == want, tostring(hit))
end)
```

In `tests/test_pages_bars.lua` and `tests/test_pages_icons.lua`, replace the line
`local GRAY = "|cff808080"` with:

```lua
local GOLD = "|c" .. T.NS.Constants.NOTICE_COLOR
```

and every `GRAY ..` in those two files with `GOLD ..` (two uses each: the `notice` locals of the
"carry the … note" and "drawn small and gray" cases). In the comment block above `NOTICE` in both
files, change "in the addon's report-not-warn gray" to "in the addon's muted notice gold (B3)".

- [ ] **Step 2: Run it and see it fail**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua 2>&1 | grep -A3 -E "muted gold|carry the gray note|carries the gray note|drawn small and gray"`
Expected: FAIL — the new case fails `assertEqual(NS2.Constants.NOTICE_COLOR, "ffc8a85a")` (expected ffc8a85a, got nil), and the Bars/Icons notice cases fail on `P.hasText(ws, notice)` (the page still draws `|cff808080`).

- [ ] **Step 3: Implement**

`core/Constants.lua`, immediately before `-- Time text. Each is a SecondsFormatter setup; …`:

```lua
-- The "Not in use" notice over a container page drawn for another style (settings/OptionsSetup.lua's
-- drawDisabledNotice): a muted gold, about (0.78, 0.66, 0.35), readable on the dark panel and quieter
-- than the title gold. The AARRGGBB body of a "|c" escape.
C.NOTICE_COLOR = "ffc8a85a"

```

`settings/OptionsSetup.lua`: replace the doc comment's first two lines

```lua
--- The notice over a page drawn disabled: a quiet gray note in the small font, then the ordinary
--- row gap before the first control.
```

with

```lua
--- The notice over a page drawn disabled: a quiet muted-gold note (C.NOTICE_COLOR) in the small
--- font, then the ordinary row gap before the first control.
```

and replace the comment's last line plus the function's first body line

```lua
--- sit on the very same page and must still be the loudest thing on it.
local function drawDisabledNotice(ctx, text)
    Helpers.TextRow(ctx, "|cff808080" .. text .. "|r", { fontObject = "GameFontHighlightSmall" })
```

with

```lua
--- sit on the very same page and must still be the loudest thing on it. The owner then asked for it
--- in a muted gold (2026-09-19, B3): the gray read as disabled text rather than as a note, and a gold
--- quieter than the title's is still no warning. The combat refusals keep their gray.
local function drawDisabledNotice(ctx, text)
    Helpers.TextRow(ctx, "|c" .. C.NOTICE_COLOR .. text .. "|r", { fontObject = "GameFontHighlightSmall" })
```

(`C` is the file's `local C = NS.Constants`, line 390, declared above this function.)

`docs/settings-panel.md`: line 346 "a small gray note heads every tab" → "a small muted-gold note
heads every tab"; line 387 "the same small gray note heads every tab" → "the same small muted-gold
note heads every tab".

- [ ] **Step 4: Run it and see it pass**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua 2>&1 | grep -A3 -E "muted gold|note|FAIL"`
Expected: PASS for the new case and every Bars/Icons notice case. If the docs citation case fails,
pipe the run into `/tmp/citefix.py` (a `core/Constants.lua:154` citation in `docs/schema.md` moves
down five lines) and re-run.

- [ ] **Step 5: Checkpoint — run the green gate**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua && /home/tushar/.claude/wow-addon/bin/ka0s-bounded luacheck .`
Expected: `… passed, 0 failed, 2 skipped …` and `0 warnings / 0 errors`. Update the ledger row. Do not commit.

---

### Task 2: B4 — the bar time text is boxed to its measured width

**Files:**
- Modify: `modules/Style.lua` (insert before line 124, `--- Dress a BackdropTemplate frame as an element border.`)
- Modify: `modules/Style_Bars.lua:245-253` (`timeBoxWidth`)
- Test: `tests/test_style_bars.lua` (insert before `-- ── engine bindings ─…`, line 458)

**Interfaces:**
- Consumes: `Style.PreviewSeconds(seconds, timeFormat)` — **does not exist yet at HEAD**; this task
  adds it (Step 3) by splitting it out of `Style.PreviewTime`, and Task 7 reuses it.
- Produces: `Style.TimeTextWidth(t, tdef, fmt) -> number|nil` (widest sample + 2 px; nil when the
  measuring string answers no number); `Style.__measurer() -> FontString` (a test seam, replaced by
  tests); Bars' `timeBoxWidth(b, area)` uses the measurement and falls back to `C.TIME_TEXT_EMS`.
  `grep -rn TIME_TEXT_EMS modules core settings` finds only `modules/Style_Bars.lua` and its
  definition, so this is the one use to convert.

- [ ] **Step 1: Write the failing test**

Insert into `tests/test_style_bars.lua` immediately before the line `-- ── engine bindings ───…`:

```lua
-- ── the measured time box (B4) ──────────────────────────────────────────────────────────────────

--- A fresh environment whose time texts are measured on a recorder answering half the font size per
--- character of the last string set, so a longer string or a bigger font measures wider.
local function measuring()
    local ns = dofile("tests/fresh_env.lua")()
    local fs = R()
    fs.__answer.GetStringWidth = function(self)
        local font, text = self:__last("SetFont"), self:__last("SetText")
        return #text[1] * font[2] * 0.5
    end
    ns.Style.__measurer = function() return fs end
    return ns, fs
end

test("bars: beside the name the time is boxed to the measured width of its format's widest string (B4)", function()
    local ns, fs = measuring()
    -- No formatter headlessly: the samples are written as whole seconds, the widest "863999s".
    local _, am = dressed(cfg(), false, nil, ns)
    -- red under: timeBoxWidth keeping the ems budget (2.5 ems of 11pt, 28px: "59 m" cut to "59...")
    assertEqual(am.time:__last("SetWidth")[1], math.ceil(7 * 11 * 0.5 + 2))
    _, am = dressed(cfg({ bars = { time = { fontSize = 20 } } }), false, nil, ns)
    assertEqual(am.time:__last("SetWidth")[1], 7 * 20 * 0.5 + 2, "a bigger font, a wider box")
    -- red under: the offset taken out of the box (moving the text would clip it)
    _, am = dressed(cfg({ bars = { time = { x = -15 } } }), false, nil, ns)
    assertEqual(am.time:__last("SetWidth")[1], math.ceil(7 * 11 * 0.5 + 2), "the offset moves the box, never narrows it")
    local measured = fs:__count("SetText")
    dressed(cfg(), false, nil, ns)
    -- red under: TimeTextWidth measuring on every dress
    assertEqual(fs:__count("SetText"), measured, "cached per font and format")
    dressed(cfg({ bars = { time = { fontFlags = "NONE" } } }), false, nil, ns)
    assertTrue(fs:__count("SetText") > measured, "a new font measures again")
end)

test("bars: where nothing can be measured the time keeps its ems budget", function()
    -- The shared environment's measuring string is the kit's, whose GetStringWidth answers no number.
    local _, am = dressed(cfg())
    assertEqual(am.time:__last("SetWidth")[1], 28, "2.5 ems of 11pt")
end)

```

- [ ] **Step 2: Run it and see it fail**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua 2>&1 | grep -A3 "(B4)"`
Expected: FAIL — `expected 41, got 28` (the ems budget still boxes the time).

- [ ] **Step 3: Implement**

In `modules/Style.lua`, split the formatter call out of `Style.PreviewTime` (end of file). Replace

```lua
    local f = formatterFor(s.timeFormat)
    local ok, text = false, nil
    if f and f.Format then ok, text = pcall(f.Format, f, aura.remaining) end
    fs:SetText((ok and type(text) == "string") and text or ("%ds"):format(aura.remaining))
```

with

```lua
    fs:SetText(Style.PreviewSeconds(aura.remaining, s.timeFormat))
```

and insert, directly above the `--- A placeholder's time text, written as a live button's reads (B-5):` comment:

```lua
--- `seconds` written as a live button's time text reads (B-5), for a placeholder: through the
--- formatter the engine is handed for the same format (formatterFor). A placeholder's seconds are a
--- plain number, so the formatter's own Format answers here (research notes Q7); a client without
--- the formatter, or one that refuses, writes whole seconds.
function Style.PreviewSeconds(seconds, timeFormat)
    local f = formatterFor(timeFormat)
    local ok, text = false, nil
    if f and f.Format then ok, text = pcall(f.Format, f, seconds) end
    return (ok and type(text) == "string") and text or ("%ds"):format(seconds)
end

```

Then insert before `--- Dress a BackdropTemplate frame as an element border.`:

```lua
-- ---------------------------------------------------------------------------
-- Measuring a time text (B4)
-- ---------------------------------------------------------------------------
-- A bar's time text beside the name needs a box of its own, and the engine writes it secret, so its
-- width cannot be read back. It CAN be measured beforehand: the formatter the engine is handed writes
-- plain numbers too, so the widest strings a format produces are set on one hidden FontString of ours
-- (never secret) and measured. The ems budget (C.TIME_TEXT_EMS) guessed, and guessed short: 2.5 ems
-- of an 11pt font cut a Blizzard-format "59 m" to "59...".

-- The seconds sampled: the largest value before each unit or digit count changes.
local TIME_SAMPLES = { 59, 599, 3599, 35999, 86399, 863999 }
local measureFS             -- the hidden FontString, built on first use
local measuredWidths = {}   -- ["path|size|flags|format"] = width, or false when it cannot be measured

--- The FontString time texts are measured on: one hidden, addon-owned string, built on first use. A
--- test replaces this function to measure on a recorder.
function Style.__measurer()
    if measureFS == nil then
        local host = CreateFrame("Frame", nil, UIParent)
        host:Hide()
        measureFS = host:CreateFontString(nil, "OVERLAY")
    end
    return measureFS
end

--- The widest of the sample strings `fmt` writes, in one font; nil when the string cannot be measured.
local function widestSample(path, size, flags, fmt)
    local fs = Style.__measurer()
    if not fs then return nil end
    fs:SetFont(path, size, flags)
    local most
    for _, seconds in ipairs(TIME_SAMPLES) do
        fs:SetText(Style.PreviewSeconds(seconds, fmt))
        local w = fs:GetStringWidth()
        if type(w) ~= "number" then return nil end
        if not most or w > most then most = w end
    end
    return most
end

--- The width, in pixels, a time text in font block `t` needs for the widest string format `fmt`
--- writes, plus 2 for the outline and shadow; nil when it cannot be measured (the caller keeps its
--- ems budget then). Cached per font path, size, flags and format.
function Style.TimeTextWidth(t, tdef, fmt)
    local size = tonumber(t.fontSize) or tdef.fontSize
    local flags = FLAG_MAP[t.fontFlags or "NONE"] or (t.fontFlags or "")
    local path = Style.Fetch("font", t.font, C.FALLBACK_FONT)
    local key = ("%s|%s|%s|%s"):format(path, size, flags, tostring(fmt))
    local w = measuredWidths[key]
    if w == nil then
        local most = widestSample(path, size, flags, fmt)
        w = most and (most + 2) or false
        measuredWidths[key] = w
    end
    return w or nil
end

```

In `modules/Style_Bars.lua`, replace the whole `timeBoxWidth` (its three-line doc comment and body,
lines 245–253) with:

```lua
--- The box a time text takes beside the name: the measured width of the widest string its format
--- writes in its font (Style.TimeTextWidth, B4), or, where nothing can be measured, the ems budget
--- (C.TIME_TEXT_EMS; a format this build does not know gets the widest). Plus its offset, which
--- Style.ApplyText takes back off, so an offset moves the text and never narrows its box; never wider
--- than the bar area.
local function timeBoxWidth(b, area)
    local t = b.time or {}
    local width = Style.TimeTextWidth(t, D.bars.time, b.timeFormat)
    if not width then
        local size = tonumber(t.fontSize) or D.bars.time.fontSize
        width = size * (C.TIME_TEXT_EMS[b.timeFormat] or C.TIME_TEXT_EMS.long)
    end
    return math.min(area, math.ceil(width) + math.abs(tonumber(t.x) or 0))
end
```

In `core/Constants.lua`, update the comment above `C.TIME_TEXT_EMS` (lines 147–149) to:

```lua
-- The width a Bars time text is boxed to beside the name, in ems of its font size, used only where
-- the widest string cannot be MEASURED (modules/Style.lua's Style.TimeTextWidth, B4): the headless
-- harness. The engine writes the live text secret, so its width is never read back.
```

- [ ] **Step 4: Run it and see it pass**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua 2>&1 | grep -A3 -E "\(B4\)|ems budget|boxed to its format|FAIL"`
Expected: both new cases PASS, and the existing "beside the name the time is boxed to its format's
widest string" case still PASSES unchanged (the shared environment cannot measure, so the ems
fallback answers). Re-point any drifted citation with `/tmp/citefix.py` (docs/midnight-quirks.md and
docs/settings-panel.md cite `modules/Style_Bars.lua` and `modules/Style.lua` lines below the insertions).

- [ ] **Step 5: Checkpoint — run the green gate**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua && /home/tushar/.claude/wow-addon/bin/ka0s-bounded luacheck .`
Expected: 0 failed; `0 warnings / 0 errors`. Update the ledger. Do not commit.

---

### Task 3: B5 — changing Style resets Fill (and `onChange` learns the replaced value)

**Files:**
- Modify: `settings/Schema.lua:489-498` (`fireSectionChanges`), `:584-605` (`writeRow` + a new `previousValue` above it), `:625-628` (`NS.SetByPath`)
- Modify: `settings/Containers.lua:81-86` (the `container.style` row)
- Modify: `modules/ContainerManager.lua:445-450` (`COPY_ALL`)
- Modify: `core/Constants.lua` (insert before `-- Who applied the aura.`, line 52)
- Test: `tests/test_pages_containers.lua` (insert before the case "containers: New and Duplicate in combat refuse in gray and create nothing", line 327)

**Interfaces:**
- Consumes: `NS.SetByPath(path, value, containerId)`.
- Produces: every row `onChange(value, id, old)` — `old` is what the row held before the write (a
  session row: its `get()`); a section write hands each changed row its old leaf. `C.STYLE_FILL_AXIS
  = { bars = "vertical", text = "vertical", icons = "horizontal" }`. `COPY_ALL` order becomes
  `unit, auraType, style, filter, layout, behavior, bars, icons` (Task 6 appends `text`).

**Mechanism (verified in `settings/Schema.lua`):** `writeRow` never compares old and new, and
`NS.SetByPath` calls `row.onChange(stored, id)` on every accepted write — re-selecting the same style
DOES fire `onChange`. So the seam now reads the old leaf before storing and passes it on; the Style
row resets Fill only when `old ~= v`. A `NS.SetByPath` from inside `onChange` is a complete, ordinary
second write (validate, store, its own `CONFIG_CHANGED`); the seam holds no per-call state except the
bulk counter, which simply tallies both writes inside a Defaults bracket. The two `CONFIG_CHANGED`s
are coalesced by `ContainerManager.RequestApply` into one apply pass, and `structural()` →
`NS.RequestPanelRefresh` coalesces to one rebuild. `container.layout.axis` has no `onChange`, so
there is no recursion.

- [ ] **Step 1: Write the failing test**

Insert into `tests/test_pages_containers.lua` before `test("containers: New and Duplicate in combat refuse in gray and create nothing", …`:

```lua
-- ── B5: changing Style resets Fill ─────────────────────────────────────────────────────────

test("containers: a new Style resets Fill to the one it suits and leaves the grow directions (B5)", function()
    local NS, _, P, ws = containers()
    local c1 = NS.Database.FindContainer(1)
    c1.layout.growH, c1.layout.growV = "left", "up"
    local dd = P.row(ws, "container.style")
    dd:__fire("OnValueChanged", "icons")
    -- red under: the Style row without its onChange (Fill stays Columns under an icon row)
    assertEqual(c1.layout.axis, "horizontal", "bars -> icons: Rows")
    dd:__fire("OnValueChanged", "bars")
    assertEqual(c1.layout.axis, "vertical", "icons -> bars: Columns")
    -- red under: a reset table that also rewrites the grow directions
    assertEqual(c1.layout.growH, "left")
    assertEqual(c1.layout.growV, "up")
end)

test("containers: re-choosing the same Style keeps a Fill set by hand (B5)", function()
    local NS = containers()
    NS.SetByPath("container.layout.axis", "horizontal", 1)
    NS.SetByPath("container.style", "bars", 1)
    -- red under: onChange resetting Fill without comparing the replaced value
    assertEqual(NS.Database.FindContainer(1).layout.axis, "horizontal")
end)

test("containers: /am set container.style resets Fill the same way, one apply and one rebuild (B5)", function()
    local NS, m = containers()
    local refreshes, applies = 0, 0
    local refresh = NS.RequestPanelRefresh
    NS.RequestPanelRefresh = function(...) refreshes = refreshes + 1; return refresh(...) end
    local inst = NS.ContainerManager.instances[1]
    local apply = inst.Apply
    inst.Apply = function(...) applies = applies + 1; return apply(...) end
    NS.Slash:OnSlash("set container.style icons")
    m.__fireTimers()
    assertEqual(NS.Database.FindContainer(1).layout.axis, "horizontal")
    -- red under: the Fill write re-running the structural handler, or not coalescing with the style's
    assertEqual(refreshes, 1, "one structural rebuild")
    assertEqual(applies, 1, "one apply pass for both writes")
    NS.RequestPanelRefresh = refresh
end)

test("containers: a duplicate and a copy-from keep the source's Fill (B5)", function()
    local NS = containers()
    local CM = NS.ContainerManager
    NS.Database.FindContainer(2).layout.axis = "vertical"   -- an icon row set to Columns by hand
    local dup = NS.Database.FindContainer(CM.Duplicate(2))
    -- red under: Duplicate writing the style through the seam (its onChange would reset Fill)
    assertEqual(dup.layout.axis, "vertical")
    assertTrue(CM.CopyFrom(2, 1))
    -- red under: COPY_ALL writing the layout before the style (the reset lands over the copy)
    assertEqual(NS.Database.FindContainer(1).style, "icons")
    assertEqual(NS.Database.FindContainer(1).layout.axis, "vertical")
end)

```

(The "icons → text sets Columns" check is added to the first case in Task 6, when `text` becomes a
style the row accepts.)

- [ ] **Step 2: Run it and see it fail**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua 2>&1 | grep -A3 "(B5)"`
Expected: FAIL — "bars -> icons: Rows (expected horizontal, got vertical)"; the copy case fails
"expected vertical, got horizontal" only after Step 3's onChange lands and before COPY_ALL is
reordered (it passes at HEAD, since nothing resets Fill yet).

- [ ] **Step 3: Implement**

`core/Constants.lua`, before `-- Who applied the aura.`:

```lua
-- The Fill (layout.axis) each style suits, written when a container's Style changes (B5,
-- settings/Containers.lua): bars and text stack in a column, icons in a row.
C.STYLE_FILL_AXIS = { bars = "vertical", text = "vertical", icons = "horizontal" }

```

`settings/Schema.lua` — in `fireSectionChanges`, replace

```lua
            if Sig(readFrom(old, parts, depth + 1)) ~= Sig(leaf) then row.onChange(leaf, id) end
```

with

```lua
            local was = readFrom(old, parts, depth + 1)
            if Sig(was) ~= Sig(leaf) then row.onChange(leaf, id, was) end
```

Insert directly above the `--- A schema row's storage step: …` comment of `writeRow`:

```lua
--- What `row` holds before a write: the stored leaf, or a session row's own get(). Handed to the
--- row's `onChange` as its third argument, so a reaction can tell a real change from a re-write of
--- the same value (the Style row's Fill reset, B5).
local function previousValue(row, root, parts, first)
    if row.sessionOnly then return row.get and row.get() end
    return readFrom(root, parts, first)
end

```

In `writeRow`, replace

```lua
    local changed = bulk.depth > 0 and rowChanges(row, root, parts, first, value)
    if row.sessionOnly then
```

with

```lua
    local changed = bulk.depth > 0 and rowChanges(row, root, parts, first, value)
    local old = previousValue(row, root, parts, first)
    if row.sessionOnly then
```

and its last line `    return true, nil, id, value` with `    return true, nil, id, value, old`; add
to its doc comment's last sentence ", and the value it replaced". In `NS.SetByPath`, replace

```lua
    local ok, err, id, stored = writeRow(row, path, value, containerId)
    if not ok then return false, err end

    if row.onChange then row.onChange(stored, id) end
```

with

```lua
    local ok, err, id, stored, old = writeRow(row, path, value, containerId)
    if not ok then return false, err end

    if row.onChange then row.onChange(stored, id, old) end
```

`settings/Containers.lua`, the `container.style` row: replace `        onChange = structural,` (the
third occurrence, line 85, inside the `container.style` row) with:

```lua
        -- B5: a new style resets Fill (Layout -> Growth) to the one it suits, through the one write
        -- seam and for the same container, then the panel rebuilds once. Only on a real change: the
        -- seam hands onChange the value it replaced. A duplicate, a copy-from's own layout, a profile
        -- switch and the starter seeding never come through here, so their stored Fill stands.
        onChange = function(v, id, old)
            local axis = C.STYLE_FILL_AXIS[v]
            if axis and old ~= v then NS.SetByPath("container.layout.axis", axis, id) end
            structural()
        end,
```

`modules/ContainerManager.lua`, replace lines 445–450

```lua
-- What "everything" copies: every section, then what the container IS.
local COPY_ALL = { "unit", "auraType", "style" }
local sectionCount = #CM.COPY_SECTIONS
for i = sectionCount, 1, -1 do
    table.insert(COPY_ALL, 1, CM.COPY_SECTIONS[i])
end
```

with

```lua
-- What "everything" copies: what the container IS, then every section. Identity first, because the
-- Style row's onChange resets Fill (B5, settings/Containers.lua): the copied layout lands after that
-- reset, so the copy keeps the source's Fill.
local COPY_ALL = { "unit", "auraType", "style" }
for _, key in ipairs(CM.COPY_SECTIONS) do
    local n = #COPY_ALL
    COPY_ALL[n + 1] = key
end
```

Docs: in `docs/schema.md`, where the write seam's order is described, add one sentence: "A row's
`onChange(value, id, old)` receives the value the write replaced." In `docs/settings-panel.md`'s
Containers section, after the Style row's description, add: "Changing Style resets Fill (Layout →
Growth) to Columns for Bars and Text and to Rows for Icons; re-choosing the same style keeps a Fill
set by hand (B5)."

- [ ] **Step 4: Run it and see it pass**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua 2>&1 | grep -A3 -E "\(B5\)|FAIL"`
Expected: all four B5 cases PASS; nothing else fails (re-point drifted citations with
`/tmp/citefix.py` — `settings/Schema.lua:616` in docs/ARCHITECTURE.md and
`modules/ContainerManager.lua:514/539` move).

- [ ] **Step 5: Checkpoint — run the green gate**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua && /home/tushar/.claude/wow-addon/bin/ka0s-bounded luacheck .`
Expected: 0 failed; `0 warnings / 0 errors`. Update the ledger. Do not commit.

---

### Task 4: The Text style's client APIs — a recording fixture and four Compat wrappers

**Files:**
- Create: `tests/text_apis.lua`
- Modify: `core/Compat.lua` (insert before the `-- Everything else` banner, line 212)
- Modify: `docs/compat-layer.md` (count 17 → 21, four rows), `docs/module-map.md:46` ("The 17 client-API shims" → 21), `docs/ARCHITECTURE.md` (its Documentation-map count of shims, 17 → 21)
- Test: `tests/test_compat.lua` (insert before `-- ── everything else ─…`, line 376)

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `Compat.DurationProperty(member) -> number|nil` — `Enum.DurationTextBindingProperty[member]`.
  - `Compat.CreateRuleFormatter(breakpoints) -> formatter|nil` — `C_StringUtil.CreateNumericRuleFormatter()` then `:SetBreakpoints(breakpoints)` (both pcall'd); `breakpoints = { { threshold = number, format = string }, … }`.
  - `Compat.CreateDurationBinding(interval|nil) -> binding|nil` — `C_DurationUtil.CreateDurationTextBinding()`, `:SetZeroDurationText("")`, `:SetExpiredText("")`, and `:SetUpdateInterval(interval)` only when `interval` is given.
  - `Compat.BlinkTextColor(threshold, blink, normal) -> { curve, property } | nil` — a Step color curve over `RemainingDuration`: `blink` at its alpha and at 0.1 in turn every 0.25 s from 0, then `normal` at `threshold`.
  - `tests/text_apis.lua` returns `install(m)`, for `fresh({ before = dofile("tests/text_apis.lua") })`. It plants recording `C_StringUtil` (`CreateSecondsFormatter` whose `Format(n)` writes `"<n>s"`, `CreateNumericRuleFormatter`), `C_DurationUtil.CreateDurationTextBinding`, `C_CurveUtil.CreateCurve/CreateColorCurve`, and `Enum.DurationTextBindingProperty` (`RemainingDuration = 101 … EndTime = 107`), `Enum.LuaCurveType`, `Enum.SecondsFormatter*`. Every stand-in has `kind`, `calls` (`{ name, n, ... }` in order), `:__last(name)`, `:__count(name)`.

- [ ] **Step 1: Write the fixture and the failing tests**

Create `tests/text_apis.lua`:

```lua
-- tests/text_apis.lua — the client APIs the Text style reaches, as RECORDING stand-ins: the duration
-- property enum, the seconds and numeric-rule formatters, the prebuilt duration text binding and the
-- color curves. The kit's mock has none of them, so without this every Compat wrapper answers nil
-- headlessly and a binding's options could never be seen.
--
-- Not a suite (tests/run.lua does not list it) and not part of the vendored kit. Install it from a
-- fresh environment's `before`, which runs after the mock is built and before anything loads:
--
--     local NS, m = dofile("tests/fresh_env.lua")({ before = dofile("tests/text_apis.lua") })
--
-- Every stand-in records each PascalCase call on `calls`, in order, as { name = ..., n = ..., ... },
-- and answers itself (fidelity rule 3: recorded, never no-opped). `obj:__last(name)` is the last
-- call's argument list, `obj:__count(name)` how many there were; `kind` names what it stands in for.
-- A seconds formatter's Format writes whole seconds ("12s"), so a placeholder's text is predictable.

--- The enum's members, each its own number so a swapped property cannot pass.
local PROPS = { RemainingDuration = 101, RemainingPercent = 102, ElapsedDuration = 103,
    ElapsedPercent = 104, TotalDuration = 105, StartTime = 106, EndTime = 107 }

local helpers = {}

function helpers.__last(self, name)
    local hit
    for _, c in ipairs(self.calls) do
        if c.name == name then hit = c end
    end
    return hit
end

function helpers.__count(self, name)
    local n = 0
    for _, c in ipairs(self.calls) do
        if c.name == name then n = n + 1 end
    end
    return n
end

--- A recording stand-in for one client object.
local function recording(kind)
    return setmetatable({ kind = kind, calls = {} }, { __index = function(_, k)
        if helpers[k] then return helpers[k] end
        if type(k) ~= "string" or not k:match("^%u") then return nil end
        return function(self, ...)
            local n = #self.calls
            self.calls[n + 1] = { name = k, n = select("#", ...), ... }
            return self
        end
    end })
end

local function secondsFormatter()
    local f = recording("seconds")
    f.Format = function(_, seconds) return ("%ds"):format(seconds) end
    return f
end

return function(m)
    m.Enum = m.Enum or {}
    local E = m.Enum
    E.DurationTextBindingProperty = PROPS
    E.LuaCurveType = { Step = 1, Linear = 2 }
    E.SecondsFormatterInterval = { Seconds = 1, Minutes = 2, Hours = 3, Days = 4 }
    E.SecondsFormatterAbbreviation = { OneLetter = 1 }
    E.SecondsFormatterRounding = { RoundUp = 0, Truncate = 1 }
    m.C_StringUtil = {
        CreateSecondsFormatter = secondsFormatter,
        CreateNumericRuleFormatter = function() return recording("rule") end,
    }
    m.C_DurationUtil = { CreateDurationTextBinding = function() return recording("binding") end }
    m.C_CurveUtil = {
        CreateCurve = function() return recording("curve") end,
        CreateColorCurve = function() return recording("colorCurve") end,
    }
end
```

Insert into `tests/test_compat.lua` immediately before `-- ── everything else ───…`:

```lua
-- ── the text style (issue #2) ────────────────────────────────────────────────────────────────

--- The Text style's client APIs as recording stand-ins (tests/text_apis.lua), planted on a scratch
--- table and handed to `with` key by key.
local function textApis()
    local t = {}
    dofile("tests/text_apis.lua")(t)
    return t
end

test("compat: a duration property reads the engine enum by member, and nil without it", function()
    local apis = textApis()
    with({ { "Enum", apis.Enum } }, function(NS)
        -- red under: DurationProperty answering the member name instead of the enum's value
        assertEqual(NS.Compat.DurationProperty("TotalDuration"), apis.Enum.DurationTextBindingProperty.TotalDuration)
        assertNil(NS.Compat.DurationProperty("NoSuchProperty"))
    end)
    with({ { "Enum", nil } }, function(NS)
        assertNil(NS.Compat.DurationProperty("RemainingDuration"))
    end)
end)

test("compat: a rule formatter is built with its breakpoints, and nil without the API or when refused", function()
    local apis = textApis()
    local breakpoints = { { threshold = 0, format = "" }, { threshold = 2, format = " x%d" } }
    with({ { "C_StringUtil", apis.C_StringUtil } }, function(NS)
        local f = NS.Compat.CreateRuleFormatter(breakpoints)
        -- red under: CreateRuleFormatter never calling SetBreakpoints
        assertTrue(f ~= nil and f.kind == "rule", "the client's formatter")
        assertTrue(f:__last("SetBreakpoints")[1] == breakpoints)
    end)
    with({ { "C_StringUtil", nil } }, function(NS)
        assertNil(NS.Compat.CreateRuleFormatter(breakpoints))
    end)
    local refusing = { CreateNumericRuleFormatter = function()
        return { SetBreakpoints = function() error("bad breakpoints") end }
    end }
    with({ { "C_StringUtil", refusing } }, function(NS)
        -- red under: SetBreakpoints called without pcall
        assertNil(NS.Compat.CreateRuleFormatter(breakpoints))
    end)
end)

test("compat: a duration binding writes nothing for a timeless or expired aura, and refreshes only when asked", function()
    local apis = textApis()
    with({ { "C_DurationUtil", apis.C_DurationUtil } }, function(NS)
        local b = NS.Compat.CreateDurationBinding(nil)
        assertEqual(b.kind, "binding")
        -- red under: a timeless aura writing the engine's own zero text
        assertEqual(b:__last("SetZeroDurationText")[1], "")
        assertEqual(b:__last("SetExpiredText")[1], "")
        -- red under: every binding paying a 0.1 s refresh, blink or not
        assertEqual(b:__count("SetUpdateInterval"), 0)
        local blink = NS.Compat.CreateDurationBinding(0.1)
        assertEqual(blink:__last("SetUpdateInterval")[1], 0.1)
    end)
    with({ { "C_DurationUtil", nil } }, function(NS)
        assertNil(NS.Compat.CreateDurationBinding(nil))
    end)
    local refusing = { CreateDurationTextBinding = function()
        return { SetZeroDurationText = function() error("refused") end }
    end }
    with({ { "C_DurationUtil", refusing } }, function(NS)
        assertNil(NS.Compat.CreateDurationBinding(nil))
    end)
end)

test("compat: the blink curve alternates the running-out color's alpha every quarter second, then the normal color", function()
    local apis = textApis()
    with({ { "C_CurveUtil", apis.C_CurveUtil }, { "Enum", apis.Enum } }, function(NS)
        local tc = NS.Compat.BlinkTextColor(1, { r = 1, g = 0.2, b = 0, a = 0.8 }, { r = 0.9, g = 0.9, b = 0.9, a = 1 })
        assertEqual(tc.property, apis.Enum.DurationTextBindingProperty.RemainingDuration)
        local curve = tc.curve
        assertEqual(curve:__last("SetType")[1], apis.Enum.LuaCurveType.Step, "a step, not a blend")
        local points = {}
        for _, c in ipairs(curve.calls) do
            if c.name == "AddPoint" then
                local n = #points
                points[n + 1] = c[1] .. "=" .. c[2].a
            end
        end
        -- red under: a curve that dims from the threshold down instead of alternating
        assertEqual(table.concat(points, ","), "0=0.8,0.25=0.1,0.5=0.8,0.75=0.1,1=1")
    end)
    with({ { "C_CurveUtil", nil }, { "Enum", apis.Enum } }, function(NS)
        assertNil(NS.Compat.BlinkTextColor(5, {}, {}))
    end)
end)
```

- [ ] **Step 2: Run them and see them fail**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua 2>&1 | grep -A3 -E "compat: (a duration property|a rule formatter|a duration binding|the blink curve)"`
Expected: FAIL — `attempt to call field 'DurationProperty' (a nil value)` (and the same for the other three).

- [ ] **Step 3: Implement**

Insert into `core/Compat.lua` immediately before the banner `-- ---…` / `-- Everything else`:

```lua
-- ---------------------------------------------------------------------------
-- The text style (issue #2)
-- ---------------------------------------------------------------------------

--- Enum.DurationTextBindingProperty[member] ("RemainingDuration", "TotalDuration", ...), or nil on a
--- client without it. Each {} of a duration text's format reads the property its component names.
--- @param member string
--- @return number|nil
function Compat.DurationProperty(member)
    local e = _G.Enum and _G.Enum.DurationTextBindingProperty
    if e and e[member] ~= nil then return e[member] end
    return nil
end

--- A numeric rule formatter for CustomAuraButton:SetApplicationCount's `formatter` and a duration
--- component's: a count is written through the format of the highest breakpoint it reaches, so
--- `{ { threshold = 0, format = "" }, { threshold = 2, format = " x%d" } }` hides a single stack.
--- Nil on a client without C_StringUtil.CreateNumericRuleFormatter, or when it refuses the list.
--- @param breakpoints table  { { threshold = number, format = string }, ... }
--- @return table|nil
function Compat.CreateRuleFormatter(breakpoints)
    local su = _G.C_StringUtil
    if not (su and su.CreateNumericRuleFormatter) then return nil end
    local ok, f = pcall(su.CreateNumericRuleFormatter)
    if not ok or not f then return nil end
    if not pcall(f.SetBreakpoints, f, breakpoints) then return nil end
    return f
end

--- A prebuilt duration text binding for SetDurationText's `binding` option, the only way to reach
--- its setters. A timeless or expired aura writes nothing (SetZeroDurationText and SetExpiredText
--- ""), so a Text style's whole duration piece, its bracket text included, is empty. `interval`, when
--- given, is SetUpdateInterval's refresh in seconds, which a blinking run needs to blink smoothly;
--- without it the engine keeps its own cadence. Nil on a client without C_DurationUtil, or when a
--- setter refuses.
--- @param interval number|nil
--- @return table|nil
function Compat.CreateDurationBinding(interval)
    local du = _G.C_DurationUtil
    if not (du and du.CreateDurationTextBinding) then return nil end
    local ok, b = pcall(du.CreateDurationTextBinding)
    if not ok or not b then return nil end
    local built = pcall(function()
        b:SetZeroDurationText("")
        b:SetExpiredText("")
        if interval then b:SetUpdateInterval(interval) end
    end)
    return built and b or nil
end

-- The blink: below the threshold the running-out color alternates between its own alpha and
-- BLINK_LOW every BLINK_STEP seconds (the stepped curve the 2026-09-18 probe measured).
local BLINK_STEP, BLINK_LOW = 0.25, 0.1

--- The blink's points on `curve`: `blink` at full and low alpha in turn from 0 up to `threshold`,
--- then `normal` from the threshold up.
local function addBlinkPoints(curve, E, threshold, blink, normal)
    if curve.SetType and E.LuaCurveType then curve:SetType(E.LuaCurveType.Step) end
    local r, g, b, a = blink.r or 1, blink.g or 0, blink.b or 0, blink.a or 1
    local steps = math.floor(threshold / BLINK_STEP)
    for i = 0, steps - 1 do
        curve:AddPoint(i * BLINK_STEP, _G.CreateColor(r, g, b, (i % 2 == 0) and a or BLINK_LOW))
    end
    curve:AddPoint(threshold, _G.CreateColor(normal.r or 1, normal.g or 1, normal.b or 1, normal.a or 1))
end

--- The `textColor` option for a BLINKING running-out text: a step color curve over REMAINING time
--- that alternates `blink` between its own alpha and a tenth of it every quarter second below
--- `threshold` seconds, and is `normal` above it. Nil without the curve API, or when the curve
--- refuses a point, which leaves the text its font color, as ExpiringTextColor does.
--- @param threshold number  seconds
--- @param blink table       {r,g,b,a}
--- @param normal table      {r,g,b,a}
--- @return table|nil  { curve = …, property = … }
function Compat.BlinkTextColor(threshold, blink, normal)
    local cu = _G.C_CurveUtil
    local prop = Compat.DurationProperty("RemainingDuration")
    if not (cu and cu.CreateColorCurve and prop and _G.CreateColor) then return nil end
    local ok, curve = pcall(cu.CreateColorCurve)
    if not ok or not curve then return nil end
    if not pcall(addBlinkPoints, curve, _G.Enum, threshold, blink, normal) then return nil end
    return { curve = curve, property = prop }
end
```

`docs/compat-layer.md`: change both `17`s in the opening paragraph and the grep comment to `21`, and
append four rows to the shims table:

```markdown
| 18 | `DurationProperty(member)` | `Enum.DurationTextBindingProperty[member]` | `nil` | Each `{}` of a Text-style duration run names the property it reads | `modules/Style.lua` |
| 19 | `CreateRuleFormatter(breakpoints)` | `C_StringUtil.CreateNumericRuleFormatter` + `SetBreakpoints` (pcall) | `nil` | The Text style's stack count (hidden below 2) and its percent components (`%d%%`) | `modules/Style.lua`, `modules/Style_Text.lua` |
| 20 | `CreateDurationBinding(interval)` | `C_DurationUtil.CreateDurationTextBinding` + `SetZeroDurationText("")`, `SetExpiredText("")`, `SetUpdateInterval` only for a blink (pcall) | `nil` | A timeless or expired aura writes no duration text, bracket text included | `modules/Style_Text.lua` |
| 21 | `BlinkTextColor(threshold, blink, normal)` | `C_CurveUtil.CreateColorCurve` step curve over `RemainingDuration`, alternating alpha every 0.25 s | `nil` | Blink the Text style's duration run in the last seconds without reading a secret | `modules/Style.lua` |
```

`docs/module-map.md`: in the `core/Compat.lua` row, "The 17 client-API shims (aura engine enums,
secrecy, formatter, color curve, mouse focus, spell info)" → "The 21 client-API shims (aura engine
enums, secrecy, formatters, color curves, the duration text binding, mouse focus, spell info)".
`docs/ARCHITECTURE.md:571`: "17 shims in `core/Compat.lua`" → "21 shims in `core/Compat.lua`".

- [ ] **Step 4: Run them and see them pass**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua 2>&1 | grep -A3 -E "compat:|FAIL"`
Expected: every `compat:` case PASSES (the four new ones included).

- [ ] **Step 5: Checkpoint — run the green gate**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua && /home/tushar/.claude/wow-addon/bin/ka0s-bounded luacheck .`
Expected: 0 failed; `0 warnings / 0 errors`. Update the ledger. Do not commit.

---

### Task 5: The template language — constants and the pure parser

**Files:**
- Modify: `core/Constants.lua` (insert before the `-- Placeholder auras for preview mode …` comment, line 163 at HEAD; the Bloodlust line under it, 166 at HEAD, gains `dispel = "Magic"`)
- Create: `modules/TextTemplate.lua`
- Modify: `AuraMaster.toc:84-89` (the `# Modules` group)
- Modify: `locales/enUS.lua` (append)
- Modify: `tests/run.lua` (declare `test_texttemplate` before `test_style`)
- Test: create `tests/test_texttemplate.lua`

**Interfaces:**
- Consumes: `NS.Constants`, `NS.L` (both loaded before `modules/`).
- Produces (read by Tasks 6–10):
  - `C.TEXT_JUSTIFY_H = { "LEFT", "CENTER", "RIGHT" }`, `C.TEXT_JUSTIFY_V = { "TOP", "MIDDLE", "BOTTOM" }` + `C.TEXT_JUSTIFY_V_LABELS`, `C.TEXT_ICON_POSITIONS = { "NONE", "LEFT", "RIGHT" }` + `C.TEXT_ICON_POSITION_LABELS`, `C.TEXT_ANIMS = { "none", "pulse", "blink", "bounce" }` + `C.TEXT_ANIM_LABELS`, `C.TEXT_TOKENS` (ordered `{ key, kind, prop, fmt }`), `C.TEXT_TOKEN_LABELS`, `C.TEXT_DISPEL_TYPES` + `C.TEXT_DISPEL_LABELS`, `C.TEXT_TEMPLATE_MAX = 200`.
  - `NS.TextTemplate` (`TT`): `TT.TOKENS[key] -> def`; `TT.Compile(template) -> { ok = true, pieces, single, shape, hasDuration } | { ok = false, err }` (memoized, shared); `TT.Validate(template) -> true | false, reason`. Piece shapes: see "Decisions this plan pins down".
  - `C.PREVIEW_AURAS[2]` (Bloodlust) carries `dispel = "Magic"` for the dispel placeholder (Task 8).

- [ ] **Step 1: Write the failing test**

Create `tests/test_texttemplate.lua`:

```lua
-- tests/test_texttemplate.lua — modules/TextTemplate.lua: the Text style's template language. Every
-- refusal rule with its exact message, the escapes, case, and the pieces a template compiles to.
-- The parser is pure, so the shared environment is read and never written.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local NS = T.NS
local TT = NS.TextTemplate
local L = NS.L

--- The refusal `template` compiles to; fails the case when it compiles.
local function refusal(template)
    local r = TT.Compile(template)
    assertFalse(r.ok, "refused: " .. tostring(template))
    return r.err
end

--- The pieces `template` compiles to, as one line: kind, then each field that kind carries.
local function shape(template)
    local r = TT.Compile(template)
    assertTrue(r.ok, tostring(template) .. ": " .. tostring(r.err))
    local out = {}
    for i, p in ipairs(r.pieces) do
        local parts = { p.kind }
        if p.kind == "literal" then parts[2] = "<" .. p.text .. ">" end
        if p.kind == "stacks" or p.kind == "dispel" or p.kind == "duration" then
            parts[2] = "<" .. p.pre .. ">"
            parts[3] = "<" .. p.post .. ">"
        end
        if p.format then
            local n = #parts
            parts[n + 1] = "<" .. p.format .. ">"
        end
        out[i] = table.concat(parts, " ")
    end
    return table.concat(out, " | ")
end

-- ── the rules, each with its message (spec 3.2) ──────────────────────────────────────────────

test("template: an unknown token is refused, naming it and every known token (rule 1)", function()
    -- red under: lexToken treating an unknown name as literal text
    assertEqual(refusal("$spellname$ $foo$"), L["Unknown token $%s$. Known: %s"]:format("foo",
        "$spellname$, $stacks$, $dispeltype$, $remainingduration$, $maxduration$, $elapsedduration$, "
        .. "$remainingpercent$, $elapsedpercent$"))
end)

test("template: a lone $ with no closing $ is literal text (rule 1)", function()
    -- red under: lexOne refusing a $ that opens no token
    assertEqual(shape("$spellname$ costs $5"), "name | literal < costs $5>")
    assertEqual(shape("$ $spellname$"), "literal <$ > | name")
end)

test("template: a token used twice is refused (rule 2)", function()
    -- red under: checkOnce keyed on the typed spelling rather than the lower-case key
    assertEqual(refusal("$stacks$ $SPELLNAME$ $Stacks$"),
        L["$%s$ appears twice — each token can be used once."]:format("stacks"))
end)

test("template: a token between two duration tokens is refused, naming it (rule 3)", function()
    -- red under: checkRun scanning only the first duration token's neighbors
    assertEqual(refusal("$remainingduration$ $spellname$ $maxduration$"),
        L["Duration tokens must sit together — $%s$ splits them."]:format("spellname"))
end)

test("template: nested and unmatched brackets are refused (rule 4)", function()
    assertEqual(refusal("$spellname$[ [x$stacks$]]"), L["Brackets can't be nested."])
    -- red under: groupItems accepting a close with nothing open
    assertEqual(refusal("$spellname$ x$stacks$]"), L["Unmatched [ or ]."])
    -- red under: groupItems forgetting a group left open at the end
    assertEqual(refusal("$spellname$[ x$stacks$"), L["Unmatched [ or ]."])
end)

test("template: a [ ] group holds exactly one of stacks, dispel type or the duration run (rule 4)", function()
    local msg = L["A [ ] group must hold exactly one of $stacks$, $dispeltype$ or the duration tokens."]
    assertEqual(refusal("[$spellname$]"), msg, "the name alone")
    assertEqual(refusal("$spellname$[ text]"), msg, "text alone")
    -- red under: unitsIn counting the duration run once per token instead of once
    assertEqual(refusal("$spellname$[$stacks$ $dispeltype$]"), msg, "two units")
    assertEqual(refusal("[$spellname$ x$stacks$]"), msg, "the name beside a unit")
end)

test("template: a bracket around the duration run must hold all of it (rule 5)", function()
    -- red under: checkGroups accepting a duration group that holds part of the run
    assertEqual(refusal("$spellname$[ $remainingduration$] / $maxduration$"),
        L["Put all the duration tokens inside the same [ ]."])
end)

test("template: { and } are refused inside the duration run and its bracket, allowed elsewhere (rule 6)", function()
    local msg = L["{ and } can't be used next to duration tokens."]
    assertEqual(refusal("$remainingduration$ {of} $maxduration$"), msg, "between two duration tokens")
    -- red under: checkBraces reading only the flat run and not the group around it
    assertEqual(refusal("$spellname$[ {$remainingduration$}]"), msg, "inside the duration's group")
    assertEqual(shape("{$spellname$}"), "literal <{> | name | literal <}>")
end)

test("template: an empty template, or one with no token, is refused (rule 7)", function()
    local msg = L["Use at least one $token$."]
    assertEqual(refusal(""), msg)
    assertEqual(refusal("just text"), msg)
    -- red under: TT.Compile indexing a stored value that is not a string
    assertEqual(refusal(nil), msg)
    assertEqual(refusal(42), msg)
end)

test("template: longer than 200 characters is refused (rule 8)", function()
    local long = "$spellname$" .. ("x"):rep(189)
    assertTrue(TT.Compile(long).ok, "200 characters")
    -- red under: validate skipping the length check
    assertEqual(refusal(long .. "y"), L["A template can be at most %d characters."]:format(200))
end)

test("template: the first broken rule is the one reported", function()
    -- rule 1 before rule 2, rule 2 before rule 4
    assertEqual(refusal("$stacks$ $stacks$ $foo$"):sub(1, 14), "Unknown token ")
    assertEqual(refusal("[$stacks$ $stacks$"),
        L["$%s$ appears twice — each token can be used once."]:format("stacks"))
end)

-- ── escapes and case ───────────────────────────────────────────────────────────────────────────

test("template: [[, ]] and $$ write a literal [, ] and $", function()
    -- red under: ESCAPES missing a pair (the [ would open a group)
    assertEqual(shape("[[$spellname$]] $$"), "literal <[> | name | literal <] $>")
end)

test("template: tokens are case-insensitive", function()
    assertEqual(shape("$SpellName$ $STACKS$"), "name | literal < > | stacks <> <> <%d>")
end)

-- ── pieces (spec 3.3) ──────────────────────────────────────────────────────────────────────────

test("template: the default template folds its bracket text into the stacks and duration pieces", function()
    -- The template default (defaults/Profile.lua, Task 6) is this string.
    local DEFAULT = "$spellname$[ x$stacks$][ - $remainingduration$]"
    local r = TT.Compile(DEFAULT)
    assertTrue(r.ok)
    -- red under: groupPiece leaving the bracket text as literal pieces of their own
    assertEqual(shape(DEFAULT),
        "name | stacks < x> <> < x%d> | duration < - > <> < - {}>")
    assertEqual(r.shape, "name|stacks|duration")
    assertTrue(r.hasDuration)
    assertFalse(r.single)
end)

test("template: the name alone is one piece, and single", function()
    local r = TT.Compile("$spellname$")
    assertEqual(#r.pieces, 1)
    assertTrue(r.single, "a one-piece template may be centered")
    assertFalse(r.hasDuration)
end)

test("template: a duration run keeps its inner text in the format, one component per token", function()
    local r = TT.Compile("$spellname$ $remainingduration$ / $maxduration$ ($remainingpercent$)")
    assertEqual(shape("$spellname$ $remainingduration$ / $maxduration$ ($remainingpercent$)"),
        "name | literal < > | duration <> <> <{} / {} ({}> | literal <)>")
    local comps = r.pieces[3].components
    -- red under: addComponent recording the key instead of the engine property
    assertEqual(comps[1].prop, "RemainingDuration"); assertEqual(comps[1].fmt, "time")
    assertEqual(comps[2].prop, "TotalDuration"); assertEqual(comps[2].fmt, "time")
    assertEqual(comps[3].prop, "RemainingPercent"); assertEqual(comps[3].fmt, "percent")
end)

test("template: a bracketed duration run carries the bracket text in its format", function()
    assertEqual(shape("$spellname$[ ($elapsedduration$ of $maxduration$)]"),
        "name | duration < (> <)> < ({} of {})>")
end)

test("template: a % in a stacks bracket is doubled in the rule format and kept in pre/post", function()
    -- red under: groupPiece writing the stacks format without escapePercent
    assertEqual(shape("$spellname$[ %$stacks$%]"), "name | stacks < %> <%> < %%%d%%>")
end)

test("template: a dispel type keeps its bracket text as pre and post", function()
    assertEqual(shape("$spellname$[ ($dispeltype$)]"), "name | dispel < (> <)>")
end)

test("template: adjacent literals merge into one piece, and none is empty", function()
    -- red under: flush pushing an empty literal, or not merging an escape into its neighbors
    assertEqual(shape("(( $$ )) $spellname$"), "literal <(( $ )) > | name")
end)

test("template: compiled results are memoized per template string", function()
    -- red under: TT.Compile rebuilding on every dress (every button, every restyle)
    assertTrue(TT.Compile("$spellname$ x") == TT.Compile("$spellname$ x"))
end)

test("template: Validate answers true, or false and the refusal", function()
    assertTrue(TT.Validate("$spellname$"))
    local ok, why = TT.Validate("$nope$")
    assertFalse(ok)
    assertEqual(why:sub(1, 14), "Unknown token ")
end)
```

In `tests/run.lua`, add `"test_texttemplate",` on the line before `"test_style",`.

- [ ] **Step 2: Run it and see it fail**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua 2>&1 | grep -A3 "template:" | head -20`
Expected: FAIL — `tests/test_texttemplate.lua:…: attempt to index local 'TT' (a nil value)` on every case (NS.TextTemplate does not exist).

- [ ] **Step 3: Implement**

`core/Constants.lua`, before `-- Placeholder auras for preview mode (preview-mode): real render path, invented data.`:

```lua
-- ---------------------------------------------------------------------------
-- The text style (issue #2): each aura one line of text, built from a template
-- ---------------------------------------------------------------------------

-- Where the line sits in its box. Center is honored only for a one-piece template: the chain's width
-- is never readable, so nothing longer can be centered (modules/Style_Text.lua).
C.TEXT_JUSTIFY_H = { "LEFT", "CENTER", "RIGHT" }
C.TEXT_JUSTIFY_V = { "TOP", "MIDDLE", "BOTTOM" }
C.TEXT_JUSTIFY_V_LABELS = { TOP = "Top", MIDDLE = "Middle", BOTTOM = "Bottom" }

C.TEXT_ICON_POSITIONS = { "NONE", "LEFT", "RIGHT" }
C.TEXT_ICON_POSITION_LABELS = { NONE = "Hidden", LEFT = "Left of the text", RIGHT = "Right of the text" }

-- The looping effect. No scale effect, on purpose: a Scale animation grows the glyphs past the boxes
-- the chain is anchored to, and the pieces overlap (docs/midnight-quirks.md).
C.TEXT_ANIMS = { "none", "pulse", "blink", "bounce" }
C.TEXT_ANIM_LABELS = { none = "None", pulse = "Pulse", blink = "Blink", bounce = "Bounce" }

-- The template's tokens, in cheat-sheet order. modules/TextTemplate.lua parses with this list and
-- settings/Text.lua prints it. `kind` is the engine field that draws a token; a duration token also
-- names the Enum.DurationTextBindingProperty member it reads, and whether it is a time or a percent.
C.TEXT_TOKENS = {
    { key = "spellname",         kind = "name" },
    { key = "stacks",            kind = "stacks" },
    { key = "dispeltype",        kind = "dispel" },
    { key = "remainingduration", kind = "duration", prop = "RemainingDuration", fmt = "time" },
    { key = "maxduration",       kind = "duration", prop = "TotalDuration",     fmt = "time" },
    { key = "elapsedduration",   kind = "duration", prop = "ElapsedDuration",   fmt = "time" },
    { key = "remainingpercent",  kind = "duration", prop = "RemainingPercent",  fmt = "percent" },
    { key = "elapsedpercent",    kind = "duration", prop = "ElapsedPercent",    fmt = "percent" },
}
-- What each token shows, one cheat-sheet line each.
C.TEXT_TOKEN_LABELS = {
    spellname         = "The aura's name",
    stacks            = "Its stack count, hidden below 2",
    dispeltype        = "Its dispel type (Magic, Curse, ...); nothing when it has none",
    remainingduration = "The time left",
    maxduration       = "Its full duration",
    elapsedduration   = "The time since it was applied",
    remainingpercent  = "How much of it is left, in percent",
    elapsedpercent    = "How much of it has run, in percent",
}

-- The types $dispeltype$ names, keyed as the aura's `dispelName`: every C.DISPEL_TYPES entry but
-- None, plus Enrage. A type this list lacks shows the engine's own text.
C.TEXT_DISPEL_TYPES = { "Magic", "Curse", "Disease", "Poison", "Bleed", "Enrage" }
C.TEXT_DISPEL_LABELS = { Magic = "Magic", Curse = "Curse", Disease = "Disease", Poison = "Poison",
    Bleed = "Bleed", Enrage = "Enrage" }

-- The longest template the parser accepts (modules/TextTemplate.lua, rule 8).
C.TEXT_TEMPLATE_MAX = 200
```

and in `C.PREVIEW_AURAS` replace the Bloodlust line with

```lua
    { name = "Bloodlust",             icon = 136012, remaining = 28,   duration = 40,   stacks = 0, dispel = "Magic" },
```

Create `modules/TextTemplate.lua`:

```lua
local _, NS = ...

-- modules/TextTemplate.lua — the Text style's template language (issue #2): a player-written line
-- such as `$spellname$[ x$stacks$][ - $remainingduration$]` in, an ordered list of PIECES out.
--
-- WHY PIECES. While auras are secret no addon code can read an aura's name, stacks or time, so no
-- addon code can build the line as one string. The engine writes each field into a font string of
-- ours instead, and a line is a CHAIN of font strings: one per engine field, plus static ones for
-- plain text (docs/midnight-quirks.md, "Text chains and animations on engine buttons"). The engine
-- has ONE binding per field, so a token can be used once, and every duration token shares one
-- duration binding, so they must sit together as one run.
--
-- PURE. No frames and no client API: a string in, a table out, so every rule is proven headlessly
-- (tests/test_texttemplate.lua). It reads core/Constants.lua's token list and routes its refusals
-- through NS.L, both loaded long before this file.
--
-- A piece is one of:
--   { kind = "literal",  text }                          static text, merged with its neighbors
--   { kind = "name" }                                    SetSpellName
--   { kind = "stacks",   pre, post, format }             SetApplicationCount; `format` is
--                                                        pre .. "%d" .. post with every % doubled
--   { kind = "dispel",   pre, post }                     SetDispelTypeText; the map adds pre/post
--   { kind = "duration", pre, post, format, components } SetDurationText; `format` is the whole run
--                                                        with each token as {} and the bracket's
--                                                        text around it; `components` holds one
--                                                        { prop, fmt } per {} in order
-- `pre` and `post` are the text inside the token's [ ] group before and after it ("" unbracketed).
--
-- Results are memoized per template string and SHARED: a caller must never edit one.

NS.TextTemplate = NS.TextTemplate or {}
local TT = NS.TextTemplate

local C = NS.Constants
local L = NS.L

--- Every token by its lower-case key: { key, kind, prop, fmt } (core/Constants.lua's TEXT_TOKENS).
TT.TOKENS = {}
for _, def in ipairs(C.TEXT_TOKENS) do TT.TOKENS[def.key] = def end

--- "$spellname$, $stacks$, ..." for the unknown-token refusal, in cheat-sheet order.
local function knownList()
    local out = {}
    for i, def in ipairs(C.TEXT_TOKENS) do out[i] = "$" .. def.key .. "$" end
    return table.concat(out, ", ")
end

local function append(list, v)
    local n = #list
    list[n + 1] = v
end

-- ---------------------------------------------------------------------------
-- 1. Lexing: characters to literals, tokens and bracket marks
-- ---------------------------------------------------------------------------

-- `[[`, `]]` and `$$` are the escapes for a literal `[`, `]` and `$`.
local ESCAPES = { ["[["] = "[", ["]]"] = "]", ["$$"] = "$" }
local MARKS = { ["["] = "open", ["]"] = "close" }

--- One `$name$` at `i`: the item and the index after it, or nil when `$` opens no token here (a lone
--- `$` is literal text). An unknown name is refused (rule 1).
local function lexToken(s, i)
    local name, after = s:match("^%$([%w_]+)%$()", i)
    if not name then return nil end
    local def = TT.TOKENS[name:lower()]
    if not def then
        return nil, nil, L["Unknown token $%s$. Known: %s"]:format(name, knownList())
    end
    return { t = "tok", def = def }, after
end

--- The item starting at `i` and the index after it, or nil plus a refusal.
local function lexOne(s, i)
    local two = s:sub(i, i + 1)
    if ESCAPES[two] then return { t = "lit", s = ESCAPES[two] }, i + 2 end
    local c = s:sub(i, i)
    if MARKS[c] then return { t = MARKS[c] }, i + 1 end
    if c == "$" then
        local item, after, err = lexToken(s, i)
        if err then return nil, nil, err end
        if item then return item, after end
        return { t = "lit", s = "$" }, i + 1
    end
    local run, stop = s:match("^([^%$%[%]]+)()", i)
    return { t = "lit", s = run }, stop
end

--- The template as a flat list of items, or nil plus the rule-1 refusal.
local function lex(s)
    local items, i, last = {}, 1, #s
    while i <= last do
        local item, after, err = lexOne(s, i)
        if err then return nil, err end
        append(items, item)
        i = after
    end
    return items
end

-- ---------------------------------------------------------------------------
-- 2. The rules, in the order they are reported
-- ---------------------------------------------------------------------------

--- Rule 2: each token at most once.
local function checkOnce(items)
    local seen = {}
    for _, it in ipairs(items) do
        if it.t == "tok" then
            local key = it.def.key
            if seen[key] then return L["$%s$ appears twice — each token can be used once."]:format(key) end
            seen[key] = true
        end
    end
    return nil
end

local function isDuration(it) return it.t == "tok" and it.def.kind == "duration" end

--- The index of the first and the last duration token, or nil when there is none.
local function durationSpan(items)
    local first, last
    for i, it in ipairs(items) do
        if isDuration(it) then
            first = first or i
            last = i
        end
    end
    return first, last
end

--- Rule 3: between the first and the last duration token, only text and duration tokens.
local function checkRun(items)
    local first, last = durationSpan(items)
    if not first then return nil end
    for i = first, last do
        local it = items[i]
        if it.t == "tok" and not isDuration(it) then
            return L["Duration tokens must sit together — $%s$ splits them."]:format(it.def.key)
        end
    end
    return nil
end

--- Rules 4a/4b: the flat items as top-level nodes, each [ ] group one node holding its items.
local function groupItems(items)
    local nodes, open = {}, nil
    for _, it in ipairs(items) do
        if it.t == "open" then
            if open then return nil, L["Brackets can't be nested."] end
            open = { t = "group", items = {} }
            append(nodes, open)
        elseif it.t == "close" then
            if not open then return nil, L["Unmatched [ or ]."] end
            open = nil
        else
            append(open and open.items or nodes, it)
        end
    end
    if open then return nil, L["Unmatched [ or ]."] end
    return nodes
end

--- How many foldable units a group holds ($stacks$, $dispeltype$, the duration run as one), how
--- many of its tokens are durations, and whether it holds the name.
local function unitsIn(group)
    local units, durations, hasName = 0, 0, false
    for _, it in ipairs(group.items) do
        if it.t == "tok" then
            local kind = it.def.kind
            if kind == "duration" then
                durations = durations + 1
            elseif kind == "name" then
                hasName = true
            else
                units = units + 1
            end
        end
    end
    if durations > 0 then units = units + 1 end
    return units, durations, hasName
end

--- The number of duration tokens in the whole template.
local function countDurations(items)
    local n = 0
    for _, it in ipairs(items) do
        if isDuration(it) then n = n + 1 end
    end
    return n
end

--- Rules 4c and 5 over every group: exactly one unit, and a duration group holds the whole run.
local function checkGroups(nodes, totalDurations)
    for _, node in ipairs(nodes) do
        if node.t == "group" then
            local units, durations, hasName = unitsIn(node)
            if units ~= 1 or hasName then
                return L["A [ ] group must hold exactly one of $stacks$, $dispeltype$ or the duration tokens."]
            end
            if durations > 0 and durations ~= totalDurations then
                return L["Put all the duration tokens inside the same [ ]."]
            end
        end
    end
    return nil
end

local BRACES = "[{}]"

--- Whether any literal of `list` from `first` to `last` holds a { or }.
local function bracesIn(list, first, last)
    for i = first, last do
        local it = list[i]
        if it.t == "lit" and it.s:find(BRACES) then return true end
    end
    return false
end

--- Rule 6: no { or } inside the duration run, or inside the group that holds it.
local function checkBraces(items, nodes)
    local first, last = durationSpan(items)
    if not first then return nil end
    local bad = bracesIn(items, first, last)
    for _, node in ipairs(nodes) do
        if node.t == "group" and select(2, unitsIn(node)) > 0 then
            local count = #node.items
            bad = bad or bracesIn(node.items, 1, count)
        end
    end
    if bad then return L["{ and } can't be used next to duration tokens."] end
    return nil
end

--- Rule 7: at least one token.
local function checkAnyToken(items)
    for _, it in ipairs(items) do
        if it.t == "tok" then return nil end
    end
    return L["Use at least one $token$."]
end

--- Rules 2 to 8 over lexed `items`: the top-level nodes, or nil plus the first refusal.
local function validate(s, items)
    local err = checkOnce(items) or checkRun(items)
    if err then return nil, err end
    local nodes, groupErr = groupItems(items)
    if not nodes then return nil, groupErr end
    err = checkGroups(nodes, countDurations(items)) or checkBraces(items, nodes) or checkAnyToken(items)
    if err then return nil, err end
    local length = #s
    if length > C.TEXT_TEMPLATE_MAX then
        return nil, L["A template can be at most %d characters."]:format(C.TEXT_TEMPLATE_MAX)
    end
    return nodes
end

-- ---------------------------------------------------------------------------
-- 3. Compiling: nodes to pieces
-- ---------------------------------------------------------------------------

--- A stack or format text with every % doubled, so string.format writes it as it reads.
local function escapePercent(text) return (text:gsub("%%", "%%%%")) end

--- The piece for one token outside any group (pre and post empty), or the start of a duration run.
local function tokenPiece(def)
    if def.kind == "name" then return { kind = "name" } end
    if def.kind == "stacks" then return { kind = "stacks", pre = "", post = "", format = "%d" } end
    if def.kind == "dispel" then return { kind = "dispel", pre = "", post = "" } end
    return { kind = "duration", pre = "", post = "", format = "", components = {} }
end

--- Add one duration token to a run: its {} in the format, its component in order.
local function addComponent(run, def)
    run.format = run.format .. "{}"
    append(run.components, { prop = def.prop, fmt = def.fmt })
end

--- One token inside a [ ] group: the group's piece (built on its first token) with a duration
--- token's {} and component added after the text since the previous token.
local function groupToken(piece, def, pending)
    piece = piece or tokenPiece(def)
    if piece.kind == "duration" then
        piece.format = piece.format .. pending
        addComponent(piece, def)
    end
    return piece
end

--- The piece one [ ] group folds into: its token, with the group's text before and after it. A
--- group holds exactly one unit (rule 4), so every token in it belongs to the one piece.
local function groupPiece(group)
    local pre, pending, piece = "", "", nil
    for _, it in ipairs(group.items) do
        if it.t == "tok" then
            piece, pending = groupToken(piece, it.def, pending), ""
        elseif piece then
            pending = pending .. it.s
        else
            pre = pre .. it.s
        end
    end
    piece.pre, piece.post = pre, pending
    if piece.kind == "stacks" then piece.format = escapePercent(pre) .. "%d" .. escapePercent(pending) end
    if piece.kind == "duration" then piece.format = pre .. piece.format .. pending end
    return piece
end

-- The compile in progress, shared by the helpers below rather than threaded through each call.
local out, buffer, run, durationsLeft

--- Close the pending literal text into a piece of its own; an empty one is dropped.
local function flush()
    if buffer ~= "" then append(out, { kind = "literal", text = buffer }) end
    buffer = ""
end

--- One top-level literal: inside an unfinished duration run it is part of the run's format.
local function addLiteral(text)
    if run and durationsLeft > 0 then
        run.format = run.format .. text
    else
        buffer = buffer .. text
    end
end

--- One top-level token.
local function addToken(def)
    if def.kind ~= "duration" then
        flush()
        append(out, tokenPiece(def))
        return
    end
    if not run then
        flush()
        run = tokenPiece(def)
        append(out, run)
    end
    addComponent(run, def)
    durationsLeft = durationsLeft - 1
end

--- The pieces for validated `nodes`.
local function compile(nodes, totalDurations)
    out, buffer, run, durationsLeft = {}, "", nil, totalDurations
    for _, node in ipairs(nodes) do
        if node.t == "lit" then
            addLiteral(node.s)
        elseif node.t == "tok" then
            addToken(node.def)
        else
            flush()
            append(out, groupPiece(node))
        end
    end
    flush()
    local pieces = out
    out, run = nil, nil
    return pieces
end

--- "name|stacks|duration": the piece kinds in order. modules/Style_Text.lua keeps one chain of font
--- strings per shape, so a template edit that keeps the shape re-dresses the same strings.
local function shapeOf(pieces)
    local kinds = {}
    for i, p in ipairs(pieces) do kinds[i] = p.kind end
    return table.concat(kinds, "|")
end

local function hasKind(pieces, kind)
    for _, p in ipairs(pieces) do
        if p.kind == kind then return true end
    end
    return false
end

local cache = {}

--- Compile one template.
--- @param template any  the stored or typed template
--- @return table  { ok = true, pieces, single, shape, hasDuration } or { ok = false, err }
function TT.Compile(template)
    if type(template) ~= "string" then return { ok = false, err = L["Use at least one $token$."] } end
    local hit = cache[template]
    if hit then return hit end
    local result
    local items, lexErr = lex(template)
    local nodes, err = nil, lexErr
    if items then nodes, err = validate(template, items) end
    if nodes then
        local pieces = compile(nodes, countDurations(items))
        local n = #pieces
        result = { ok = true, pieces = pieces, single = n == 1, shape = shapeOf(pieces),
            hasDuration = hasKind(pieces, "duration") }
    else
        result = { ok = false, err = err }
    end
    cache[template] = result
    return result
end

--- Whether `template` compiles: the Text page's `validate` (settings/Text.lua). A refusal answers
--- false and the localized reason, which the write seam hands on to the panel and to `/am set`.
function TT.Validate(template)
    local r = TT.Compile(template)
    if r.ok then return true end
    return false, r.err
end
```

`AuraMaster.toc`: in the `# Modules` group, insert between `modules\FilterCompiler.lua` and the
`# LOAD-BEARING: Style before Style_Bars …` note:

```text
# LOAD-BEARING: TextTemplate before Style_Text, which takes NS.TextTemplate as a file-scope upvalue.
modules\TextTemplate.lua
```

Append to `locales/enUS.lua` (each value is its key):

```lua
L["Unknown token $%s$. Known: %s"] = "Unknown token $%s$. Known: %s"
L["$%s$ appears twice — each token can be used once."] = "$%s$ appears twice — each token can be used once."
L["Duration tokens must sit together — $%s$ splits them."] = "Duration tokens must sit together — $%s$ splits them."
L["Brackets can't be nested."] = "Brackets can't be nested."
L["Unmatched [ or ]."] = "Unmatched [ or ]."
L["A [ ] group must hold exactly one of $stacks$, $dispeltype$ or the duration tokens."] = "A [ ] group must hold exactly one of $stacks$, $dispeltype$ or the duration tokens."
L["Put all the duration tokens inside the same [ ]."] = "Put all the duration tokens inside the same [ ]."
L["{ and } can't be used next to duration tokens."] = "{ and } can't be used next to duration tokens."
L["Use at least one $token$."] = "Use at least one $token$."
L["A template can be at most %d characters."] = "A template can be at most %d characters."
L["Middle"] = "Middle"
L["Left of the text"] = "Left of the text"
L["Right of the text"] = "Right of the text"
L["Pulse"] = "Pulse"
L["Blink"] = "Blink"
L["Bounce"] = "Bounce"
L["The aura's name"] = "The aura's name"
L["Its stack count, hidden below 2"] = "Its stack count, hidden below 2"
L["Its dispel type (Magic, Curse, ...); nothing when it has none"] = "Its dispel type (Magic, Curse, ...); nothing when it has none"
L["The time left"] = "The time left"
L["Its full duration"] = "Its full duration"
L["The time since it was applied"] = "The time since it was applied"
L["How much of it is left, in percent"] = "How much of it is left, in percent"
L["How much of it has run, in percent"] = "How much of it has run, in percent"
L["Enrage"] = "Enrage"
```

- [ ] **Step 4: Run it and see it pass**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua 2>&1 | grep -A3 -E "template:|locale:|loadorder:|FAIL"`
Expected: every `template:` case PASSES; `locale:` and `loadorder:` stay green (the TOC note covers
the new line; every new key is used as a literal in `modules/TextTemplate.lua` or `core/Constants.lua`).

- [ ] **Step 5: Checkpoint — run the green gate**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua && /home/tushar/.claude/wow-addon/bin/ka0s-bounded luacheck .`
Expected: 0 failed; `0 warnings / 0 errors`. Re-point a drifted `core/Constants.lua` citation with
`/tmp/citefix.py` if the docs case names one. Update the ledger. Do not commit.

---

### Task 6: The Text settings surface — the data block, the page, refusal reasons, notices, sections, slash

**Files:**
- Modify: `defaults/Profile.lua:91-107` (the `text()` helper → `font()` + `text()`), and the template's `icons` block end (line 204: append `text = {…}`)
- Modify: `core/Constants.lua:48-50` (`C.STYLES`, `C.STYLE_LABELS`)
- Modify: `modules/TextTemplate.lua` (append `TT.ForDraw`)
- Modify: `settings/Schema.lua` (`SECTIONS` + `container.text`; `writeRow`, `NS.SetByPath`, `checkRow` rewritten; `VALID_PAGES` + `text`)
- Modify: `settings/OptionsSetup.lua` (descriptor `set`, line 121; the picker tooltip, line 449; `renderActiveTab`'s notice, lines 547–549; the `RenderTabbedPage` and `NS.RegisterContainerPage` doc comments)
- Modify: `settings/Slash.lua:56` (`new` help), `:229-237` (`NEW_WORDS`), `:437-440` (descriptor `set`)
- Modify: `settings/Containers.lua:84` (Style desc), `:141-145` (copy sections)
- Modify: `settings/Bars.lua:180-183`, `settings/Icons.lua:112-115` (`disabledNotice` as a function)
- Modify: `modules/ContainerManager.lua:444` (`COPY_SECTIONS` + `"text"`)
- Create: `settings/Text.lua`
- Modify: `AuraMaster.toc` (the `## Notes:` line; the settings group: `settings\Text.lua` after `settings\Icons.lua`, and its note)
- Modify: `locales/enUS.lua` (append 38 keys; delete 3 retired ones)
- Modify: `tests/run.lua` (declare `test_pages_text` after `test_pages_icons`)
- Test: create `tests/test_pages_text.lua`; modify `tests/test_schema.lua`, `tests/test_texttemplate.lua`, `tests/test_pages_containers.lua` (the Style dropdown case, line 318; the copy-block case, line 382; Task 3's first B5 case), `tests/test_slash_verbs.lua:308`, `tests/test_optionssetup.lua:12-22`, `tests/test_loadorder.lua:48-54`

**Interfaces:**
- Consumes: Task 5's constants and `TT`; Task 1's `C.NOTICE_COLOR`; Task 3's `onChange(v, id, old)`.
- Produces:
  - `NS.CONTAINER_TEMPLATE.text` (spec §7, reproduced below) and `C.STYLES = { "bars", "icons", "text" }`.
  - `TT.ForDraw(template) -> compiled, fellBack` (the default template's compile for a refused one).
  - `NS.SetByPath(path, value, id) -> ok, err, why` and `NS.CheckWrite(...) -> ok, err, why`: `why` is a row `validate`'s second return (only the Template row gives one).
  - The panel descriptor's `set` and the Slash descriptor's `set` print `err` then `"  " .. why`.
  - `spec.disabledNotice` may be `function(cfg) -> string`.
  - Schema rows `container.text.*` on page `"text"`; page registered as `"text"` / frame `AuraMasterTextPanel`, tree label `NS.SubPageLabel("Text")`; section `container.text` announces as `"text"`; `/am new … text`; the Containers copy offers "Text style".
  - The Text page's General tab is bespoke (`spec.tabs = { { key = L["General"], render = renderGeneral } }`) and the Animation tab has an `afterGroup` note; Task 11 walks every row it registers.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_pages_text.lua`:

```lua
-- tests/test_pages_text.lua — settings/Text.lua, driven through its widgets: the four tabs, the
-- notice and disabled rows on a container not drawn as text, the Template box and its refusals
-- (panel and /am set), the token cheat sheet, the centering note and the rows the loop effect and
-- the template dim. How the stored look is drawn is tests/test_style_text.lua's.
-- Every case builds a fresh environment, because every case writes something.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse
local fresh = dofile("tests/fresh_env.lua")
local pages = dofile("tests/page_helpers.lua")

local P_ = "container.text."
local GOLD = "|c" .. T.NS.Constants.NOTICE_COLOR

--- The Animation tab as the current settings draw it: a structural re-render, then a click on the
--- tab unless it is already the active one (a click on the active tab draws nothing).
local function animationTab(NS, P)
    local ws = P.rerender("Text")
    if NS.Helpers.__pageCtx.text.activeTab == NS.L["Animation"] then return ws end
    return P.tab("text", NS.L["Animation"])
end

--- The Text page drawn for container 1, switched to the text style first.
local function textPage(opts)
    local NS, m = fresh(opts)
    local P = pages(NS, m)
    NS.SetByPath("container.style", "text", 1)
    NS.State.SetActiveContainer(1)
    return NS, m, P, P.show("Text")
end

test("text page: the four tabs are drawn in order", function()
    local NS, _, P = textPage()
    local L = NS.L
    -- red under: a row registered in a group of its own (a stray fifth tab), or the tabs reordered
    assertEqual(table.concat(P.tabKeys("text"), ","),
        table.concat({ L["General"], L["Font"], L["Icon"], L["Animation"] }, ","))
end)

test("text page: a bars or icons container sees every row disabled under the note naming its style", function()
    local NS, _, P = textPage()
    local L = NS.L
    NS.Helpers.SelectContainer(2)
    local notice = GOLD .. L["Not in use: this container is drawn as icons. Set its Style to Text on the Containers page to use these settings."]
    P.eachTab("Text", "text", function(key, tabWs)
        -- red under: the Text spec's disabledNotice answering the bars wording for an icons container
        assertTrue(P.hasText(tabWs, notice), key .. " carries the note")
        local rows = P.rowWidgets(tabWs, "text", key)
        assertTrue(rows[1] ~= nil, key .. " drew its rows")
        for _, w in ipairs(rows) do
            -- red under: the Text spec without disabledFor, or the bespoke General tab dropping the
            -- page's disable (renderBespoke's ctx.__renderDisabled)
            assertTrue(w.disabled, key .. ": " .. w.labelText)
        end
    end)
    NS.SetByPath("container.style", "bars", 2)
    local ws = P.rerender("Text")
    assertTrue(P.hasText(ws, GOLD .. L["Not in use: this container is drawn as bars. Set its Style to Text on the Containers page to use these settings."]))
end)

test("text page: the Bars and Icons pages name the text style on a text container", function()
    local NS, _, P = textPage()
    local L = NS.L
    -- red under: the Bars notice still claiming every other container is drawn as icons
    assertTrue(P.hasText(P.show("Bars"), GOLD .. L["Not in use: this container is drawn as text. Set its Style to Bars on the Containers page to use these settings."]))
    assertTrue(P.hasText(P.show("Icons"), GOLD .. L["Not in use: this container is drawn as text. Set its Style to Icons on the Containers page to use these settings."]))
end)

test("text page: General holds Size, the Template box, the cheat sheet, then Placement", function()
    local NS, _, P, ws = textPage()
    local L = NS.L
    local box = P.row(ws, P_ .. "template")
    -- red under: the template row without dialogControl = "EditBox" (a dropdown that opens on nothing)
    assertEqual(box.type, "EditBox")
    assertEqual(box.text, NS.CONTAINER_TEMPLATE.text.template)
    local texts = P.texts(ws)
    local joined = table.concat(texts, "\n")
    for _, def in ipairs(NS.Constants.TEXT_TOKENS) do
        -- red under: cheatSheet skipping a token
        assertTrue(joined:find("$" .. def.key .. "$", 1, true) ~= nil, "cheat sheet names $" .. def.key .. "$")
    end
    assertTrue(P.hasText(ws, L["To write a literal [, ] or $, type it twice: [[, ]] or $$."]))
    -- The cheat sheet sits between the Template box and the Placement rows.
    local at = {}
    for i, w in ipairs(ws) do
        if w == box then at.box = i end
        if w.type == "Label" and w.text and w.text:find("$spellname$", 1, true) and not at.sheet then at.sheet = i end
        if w.labelText == NS.FindSchemaRow(P_ .. "justifyH").label then at.justify = i end
    end
    assertTrue(at.box < at.sheet and at.sheet < at.justify, "box, then cheat sheet, then Placement")
end)

test("text page: a valid template is stored; a refused one is not, and the panel prints why", function()
    local NS, _, P, ws = textPage()
    local lines = P.chat()
    local box = P.row(ws, P_ .. "template")
    box:__fire("OnEnterPressed", "$spellname$ $remainingduration$")
    assertEqual(NS.Database.FindContainer(1).text.template, "$spellname$ $remainingduration$")
    box:__fire("OnEnterPressed", "$spellname$ $bogus$")
    -- red under: the template row without validate (a template the parser refuses is stored)
    assertEqual(NS.Database.FindContainer(1).text.template, "$spellname$ $remainingduration$")
    local said = table.concat(lines, "\n")
    -- red under: the Options descriptor's set dropping SetByPath's third return
    assertTrue(said:find("Invalid value for container.text.template", 1, true) ~= nil, said)
    assertTrue(said:find("  Unknown token $bogus$.", 1, true) ~= nil, said)
end)

test("text page: /am set refuses a bad template with the parser's reason, indented under the refusal", function()
    local NS, _, P = textPage()
    local lines = P.chat()
    NS.Slash:OnSlash("set container.text.template $spellname$[ $spellname$]")
    local said = table.concat(lines, "\n")
    -- red under: the Slash descriptor's set printing only the bare refusal
    assertTrue(said:find("Invalid value for container.text.template", 1, true) ~= nil, said)
    assertTrue(said:find("  " .. NS.L["$%s$ appears twice — each token can be used once."]:format("spellname"), 1, true) ~= nil, said)
    assertEqual(NS.Database.FindContainer(1).text.template, NS.CONTAINER_TEMPLATE.text.template)
    NS.Slash:OnSlash("set container.text.template $spellname$ ($stacks$)")
    assertEqual(NS.Database.FindContainer(1).text.template, "$spellname$ ($stacks$)")
end)

test("text page: Center on a multi-piece template draws the note naming the piece count", function()
    local NS, _, P = textPage()
    local note = NS.L["Center needs a one-piece template; this one has %d pieces, so it lines up Left."]
    NS.SetByPath(P_ .. "justifyH", "CENTER", 1)
    local ws = P.rerender("Text")
    -- red under: centerNote reading the stored template's piece count wrong, or not drawn
    assertTrue(P.hasText(ws, note:format(3)), "the default template has three pieces")
    NS.SetByPath(P_ .. "template", "$spellname$", 1)
    ws = P.rerender("Text")
    assertFalse(P.hasText(ws, note:sub(1, 30)), "a one-piece template centers, so no note")
    NS.SetByPath(P_ .. "justifyH", "LEFT", 1)
    NS.SetByPath(P_ .. "template", "$spellname$ $stacks$", 1)
    ws = P.rerender("Text")
    assertFalse(P.hasText(ws, note:sub(1, 30)), "Left needs no note")
end)

test("text page: each loop row is live only for the effects that use it", function()
    local NS, _, P = textPage()
    local function states(anim)
        NS.SetByPath(P_ .. "anim", anim, 1)
        local ws = animationTab(NS, P)
        local out = {}
        for _, key in ipairs({ "animSpeed", "animIntensity", "animBounce" }) do
            local n = #out
            out[n + 1] = key .. "=" .. tostring(P.row(ws, P_ .. key).disabled and true or false)
        end
        return table.concat(out, " ")
    end
    -- red under: a loop row's disabledIf naming the wrong effect
    assertEqual(states("none"), "animSpeed=true animIntensity=true animBounce=true")
    assertEqual(states("pulse"), "animSpeed=false animIntensity=false animBounce=true")
    assertEqual(states("blink"), "animSpeed=false animIntensity=false animBounce=true")
    assertEqual(states("bounce"), "animSpeed=false animIntensity=true animBounce=false")
end)

test("text page: without a duration token the running-out rows dim, except the swatch, under a note", function()
    local NS, _, P = textPage()
    local L = NS.L
    local note = L["Running out needs a duration token, such as $remainingduration$, in the template."]
    local ws = animationTab(NS, P)
    assertFalse(P.hasText(ws, note), "the default template has one")
    assertFalse(P.row(ws, P_ .. "expiringBlink").disabled and true or false)
    NS.SetByPath(P_ .. "template", "$spellname$[ x$stacks$]", 1)
    ws = animationTab(NS, P)
    -- red under: the Animation tab's afterGroup note not drawn
    assertTrue(P.hasText(ws, note))
    for _, key in ipairs({ "expiringColorOn", "expiringThreshold", "expiringBlink" }) do
        -- red under: a running-out row without the noDuration predicate
        assertTrue(P.row(ws, P_ .. key).disabled, key)
    end
    -- anti-pattern #74: a color swatch is never grayed
    assertFalse(P.row(ws, P_ .. "expiringColor").disabled and true or false, "the swatch stays live")
end)

test("text page: the blink row is engine-only, and the Font tab carries the composed font block and time format", function()
    local NS = textPage()
    local L = NS.L
    assertEqual(NS.FindSchemaRow(P_ .. "expiringBlink").coverage, "engine-only")
    local paths = {}
    for _, row in ipairs(NS.SchemaForPage("text")) do
        if row.group == L["Font"] then
            local n = #paths
            paths[n + 1] = row.path
        end
    end
    -- red under: the font block on a prefix other than text.font., or the time format elsewhere
    assertEqual(table.concat(paths, ","), table.concat({ P_ .. "font.font", P_ .. "font.fontSize",
        P_ .. "font.fontColor", P_ .. "font.useClassColorFont", P_ .. "font.fontFlags",
        P_ .. "font.fontShadow", P_ .. "timeFormat" }, ","))
    assertEqual(NS.FindSchemaRow(P_ .. "font.fontColor").classColorSource, "unit")
end)

test("text page: Defaults restores the selected container's text look and nothing else", function()
    local NS = textPage()
    NS.SetByPath(P_ .. "width", 300, 1)
    NS.SetByPath(P_ .. "template", "$spellname$", 1)
    NS.SetByPath("container.bars.width", 111, 1)
    NS.Helpers.__pageCtx.text.panel.defaultsOnClick()
    local c1 = NS.Database.FindContainer(1)
    -- red under: the Text Defaults reaching the Bars page's rows
    assertEqual(c1.text.width, NS.CONTAINER_TEMPLATE.text.width)
    assertEqual(c1.text.template, NS.CONTAINER_TEMPLATE.text.template)
    assertEqual(c1.bars.width, 111)
end)
```

Append to `tests/test_schema.lua`:

```lua
test("schema: a row's own refusal reason travels as the third return of SetByPath and CheckWrite", function()
    local NS2 = fresh()
    local path = "container.text.template"
    local ok, err, why = NS2.SetByPath(path, "$nope$", 1)
    assertFalse(ok)
    assertEqual(err, NS2.L["Invalid value for %s"]:format(path))
    -- red under: writeRow calling validate for its first return only (the parser's reason dropped)
    assertEqual(why:sub(1, 14), "Unknown token ")
    local okCheck, _, whyCheck = NS2.CheckWrite(path, "$nope$", 1)
    assertFalse(okCheck)
    assertEqual(whyCheck:sub(1, 14), "Unknown token ")
    -- A bare refusal carries no reason: the name row's validate answers false alone.
    local okName, _, whyName = NS2.SetByPath("container.name", "   ", 1)
    assertFalse(okName)
    assertNil(whyName)
end)
```

Append to `tests/test_texttemplate.lua`:

```lua
test("template: ForDraw draws a refused stored template as the default one, and says it fell back", function()
    local r, fell = TT.ForDraw("$spellname$")
    assertTrue(r.ok); assertFalse(fell)
    -- red under: ForDraw handing a refused result to the dresser (an element with no pieces)
    r, fell = TT.ForDraw("$nope$")
    assertTrue(fell, "fell back")
    assertTrue(r == TT.Compile(NS.CONTAINER_TEMPLATE.text.template), "the default template's pieces")
end)
```

`tests/test_pages_containers.lua` — replace the case "containers: the Style dropdown offers bars and icons and writes the selected container" with:

```lua
test("containers: the Style dropdown offers bars, icons and text and writes the selected container", function()
    local NS, _, P, ws = containers()
    local dd = P.row(ws, "container.style")
    -- red under: C.STYLES without "text" (the Text page would be unreachable)
    assertEqual(table.concat(dd.order, ","), "bars,icons,text")
    dd:__fire("OnValueChanged", "icons")
    -- red under: the style row writing the wrong path
    assertEqual(NS.Database.FindContainer(1).style, "icons")
    dd:__fire("OnValueChanged", "text")
    assertEqual(NS.Database.FindContainer(1).style, "text")
end)
```

in "containers: the copy block offers every other container and copies only the chosen section"
change `"all,filter,layout,behavior,bars,icons"` to `"all,filter,layout,behavior,bars,icons,text"`,
and in Task 3's first B5 case insert, right after `assertEqual(c1.layout.axis, "vertical", "icons -> bars: Columns")`:

```lua
    dd:__fire("OnValueChanged", "icons")
    dd:__fire("OnValueChanged", "text")
    assertEqual(c1.layout.axis, "vertical", "icons -> text: Columns")
```

`tests/test_slash_verbs.lua:308`: `"general,containers,filters,layout,bars,icons"` → `"general,containers,filters,layout,bars,icons,text"`.

`tests/test_optionssetup.lua`: in the comment above `PAGES` write "Filters, Layout, Bars, Icons and
Text are sub-pages of Containers (N-2)", and add after the `icons` entry of `PAGES`:

```lua
    { key = "text",       label = NS.SubPageLabel("Text") },
```

`tests/test_loadorder.lua`, in `pairs_`, replace `{ "settings/Icons.lua", "settings/Profiles.lua" },` with:

```lua
        { "settings/Icons.lua", "settings/Text.lua" },
        { "settings/Text.lua", "settings/Profiles.lua" },
```

`tests/run.lua`: add `"test_pages_text",` after `"test_pages_icons",`.

- [ ] **Step 2: Run them and see them fail**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua 2>&1 | grep -A3 -E "text page|third return|ForDraw|bars, icons and text|FAIL" | head -40`
Expected: FAIL — the `text page:` cases raise in `tests/page_helpers.lua`'s `P.show` (no "Text"
subcategory: `attempt to index local 'sub' (a nil value)`), `ForDraw` is a nil value, the Style
dropdown reads `bars,icons`, and the schema case gets `Setting not found: container.text.template`.

- [ ] **Step 3: Implement**

`defaults/Profile.lua` — replace the `text()` helper (its doc comment and body, lines 91–107) with:

```lua
--- The six canonical font leaves (options-ui-§16): white, outlined, no shadow, at `size`.
local function font(size)
    return {
        font              = "Friz Quadrata TT",
        fontSize          = size,
        fontColor         = color(1, 1, 1, 1),
        useClassColorFont = false,
        fontFlags         = "OUTLINE",
        fontShadow        = false,
    }
end

--- The font block every Bars and Icons text element carries: the six font leaves, then where the
--- text sits.
local function text(show, size, point, x, y, justify)
    local t = font(size)
    t.show, t.point, t.x, t.y, t.justify = show, point, x, y, justify
    return t
end
```

and add after the template's `icons = { … },` block, before the template's closing `}`:

```lua
    -- The text style (issue #2): each aura one line, built from `template` by
    -- modules/TextTemplate.lua and drawn as a chain of font strings (modules/Style_Text.lua).
    text = {
        width = 220, height = 16,
        template = "$spellname$[ x$stacks$][ - $remainingduration$]",
        justifyH = "LEFT", justifyV = "MIDDLE", x = 2, y = 0,
        font = font(12),
        timeFormat = "blizzard",

        icon = "NONE", iconSize = 0, iconGap = 2, iconZoom = 0.08,
        iconBorderShow = false, iconBorderStyle = "Solid", iconBorderSize = 1,
        iconBorderColor = color(0, 0, 0, 1), useClassColorIconBorder = false,

        anim = "none", animSpeed = 1.0, animIntensity = 0.3, animBounce = 3,

        expiringColorOn = false, expiringThreshold = 5, expiringColor = color(1, 0.25, 0.25, 1),
        expiringBlink = false,
    },
```

`core/Constants.lua` — replace `-- Container styles. Text is a tracked enhancement.` and the two
lines under it with:

```lua
-- Container styles.
C.STYLES = { "bars", "icons", "text" }
C.STYLE_LABELS = { bars = "Bars", icons = "Icons", text = "Text" }
```

Append to `modules/TextTemplate.lua`:

```lua
--- What a STORED template draws: its own compile, or the default template's when the stored one is
--- refused (a hand-edited SavedVariables file, a token a later version removed), and whether it fell
--- back. modules/Style_Text.lua draws with it and settings/Text.lua explains with it, so the page
--- and the element never disagree about the pieces.
--- @return table compiled, boolean fellBack
function TT.ForDraw(template)
    local r = TT.Compile(template)
    if r.ok then return r, false end
    return TT.Compile(NS.CONTAINER_TEMPLATE.text.template), true
end
```

`settings/Schema.lua`:

1. In `SECTIONS`, add `    ["container.text"]     = "text",` after the `container.icons` entry.
2. Replace everything from `--- What \`row\` holds before a write:` (added in Task 3) down to, but not including, `--- Write one setting. THE single write seam` with:

```lua
--- What `row` holds before a write: the stored leaf, or a session row's own get(). Handed to the
--- row's `onChange` as its third argument, so a reaction can tell a real change from a re-write of
--- the same value (the Style row's Fill reset, B5).
local function previousValue(row, root, parts, first)
    if row.sessionOnly then return row.get and row.get() end
    return readFrom(root, parts, first)
end

--- A schema row's storage step: resolve the container, validate the raw value, normalize, store.
--- `row.validate(value, id)` and the optional `row.normalize(value, id)` are both handed the id the
--- write targets (nil for a global or session row, or when no container resolves), so a row can
--- check or rewrite a value against ITS container: the attach row refuses a loop from the container
--- written, the name row makes a name unique. A bad value is refused before a missing container, so
--- the refusal names the value. A `validate` may answer false AND a reason (the Text template's
--- parser does); the reason travels on as the refusal's third return. It returns ok, err|nil, the
--- container id or the reason, and the value as stored (what onChange and the announcement see).
--- Inside a bulk bracket it tallies the row here, once stored, so an onChange that raises
--- afterwards cannot drop a stored write from the count.
local function writeRow(row, path, value, containerId)
    local parts, root, first, id
    if not row.sessionOnly then
        parts = splitPath(path)
        root, first, id = resolveRoot(parts, containerId)
    end
    if row.validate then
        local ok, why = row.validate(value, id)
        if not ok then return false, L["Invalid value for %s"]:format(path), why end
    end
    if parts and not root then return false, NO_CONTAINER end
    if row.normalize then value = row.normalize(value, id) end
    local changed = bulk.depth > 0 and rowChanges(row, root, parts, first, value)
    local old = previousValue(row, root, parts, first)
    if row.sessionOnly then
        -- No database write by definition; the row's own set() IS its storage.
        if row.set then row.set(value) end
    else
        -- copy() on the way in: a color table handed straight from a widget or from a row's
        -- default would otherwise be shared, and editing one container would edit another.
        writeInto(root, parts, first, copy(value))
    end
    if changed then tally(1) end
    return true, nil, id, value, old
end
```

3. Replace `NS.SetByPath` and its doc comment (down to, not including, `--- Whether a spell set would be stored`) with:

```lua
--- Write one setting. THE single write seam: the panel's widgets, `/am set`, `/am reset`, the
--- Defaults buttons and a drag handle all land here. `containerId` targets a specific container
--- instead of the active one.
---
--- Order is load-bearing: resolve, validate against the resolved container, normalize, write, react,
--- log once, announce. A bad value is refused before a missing container. Reacting before the write
--- would hand a reactor the old value; logging in the reactor would log it once per subscriber.
--- A refused row write may carry a third return, the row's own reason (the Text template's parser
--- message), which the panel and `/am set` print under `err` (settings/OptionsSetup.lua,
--- settings/Slash.lua).
--- @return boolean ok, string|nil err, string|nil why
function NS.SetByPath(path, value, containerId)
    if type(path) ~= "string" then return false, L["Setting not found: %s"]:format(tostring(path)) end
    if path == MINIMAP_PATH then return writeMinimap(value) end
    if CARVE_OUTS[path] then return writeCarveOut(path, value, containerId) end
    local sec = SECTIONS[path]
    if sec then return writeSection(path, value, containerId, sec) end

    local row = index[path]
    if not row then return false, L["Setting not found: %s"]:format(path) end
    local ok, err, id, stored, old = writeRow(row, path, value, containerId)
    if not ok then return false, err, id end

    if row.onChange then row.onChange(stored, id, old) end
    announceWrite(row.page, id, path, stored, row.sessionOnly, false)
    return true
end
```

4. Replace `checkRow` and its doc comment with:

```lua
--- Whether a row write would be stored: the row exists, its validate accepts the value (handed the id
--- the write targets, as writeRow hands it), and (for a stored row) the container exists. A row's
--- normalize never refuses, so it is not run.
local function checkRow(path, value, containerId)
    local row = index[path]
    if not row then return false, L["Setting not found: %s"]:format(path) end
    local root, id
    if not row.sessionOnly then
        local _
        root, _, id = resolveRoot(splitPath(path), containerId)
    end
    if row.validate then
        local ok, why = row.validate(value, id)
        if not ok then return false, L["Invalid value for %s"]:format(path), why end
    end
    if not row.sessionOnly and not root then return false, NO_CONTAINER end
    return true
end
```

5. `VALID_PAGES`: the line `    profiles = true,` becomes `    text = true, profiles = true,`.

`settings/OptionsSetup.lua`:

- Replace the descriptor line `    set          = function(path, value) NS.SetByPath(path, value) end,` with:

```lua
    -- A refusal that carries its row's own reason (the Text template's parser) is printed, the same
    -- two lines `/am set` prints: the panel's EditBox re-reads the stored value on refresh, so the
    -- reason is the only trace of why the typed one did not stick. A bare refusal stays silent, as it
    -- always has.
    set          = function(path, value)
        local ok, err, why = NS.SetByPath(path, value)
        if not ok and why then
            print(err)
            print("  " .. why)
        end
    end,
```

- In `Helpers.ContainerPickerCell`, the tooltip key becomes `L["Which container this tab, and the Filters, Layout, Bars, Icons and Text pages, edit. The choice is shared by every page."]`.
- In `renderActiveTab`, replace `    if disabled and spec.disabledNotice then drawDisabledNotice(ctx, spec.disabledNotice) end` with:

```lua
    local notice = spec.disabledNotice
    if type(notice) == "function" then notice = notice(cfg) end
    if disabled and notice then drawDisabledNotice(ctx, notice) end
```

- In the `Helpers.RenderTabbedPage` doc comment, the `disabledFor(cfg)` entry's second line becomes
  "`ctx.__renderDisabled`), under `disabledNotice` (a string, or a function of cfg answering one),
  drawn as a small note".
- In `NS.RegisterContainerPage`'s doc comment "(Filters, Layout, Bars, Icons)" → "(Filters, Layout,
  Bars, Icons, Text)", and in its body comment "(true for all four callers today)" → "(true for all
  five callers today)".

`settings/Slash.lua`:

- The `new` entry of `NS.COMMANDS`: `L["Create a container — /am new [player|target|focus|pet] [buffs|debuffs|enchants] [bars|icons|text]"]`.
- `NEW_WORDS`: add `    text = { style = "text" },` after the `icons = …, icon = …` line.
- Replace the descriptor's `set` (the three lines `set = function(path, v)` … `end,`) with:

```lua
    -- A refusal with its row's reason (the Text template's parser) prints the reason indented
    -- under it, the shape slash-commands-§6 gives a failed parse.
    set          = function(path, v)
        local ok, err, why = NS.SetByPath(path, v)
        if not ok and err then print(err) end
        if not ok and why then print("  " .. why) end
    end,
```

`settings/Containers.lua`: the Style row's `desc` becomes
`L["Draw each aura as a bar, an icon or a line of text. Bars, Icons and Text each have their own settings page."]`;
`SECTION_KEYS` gains `"text"` last and `SECTION_LABELS` gains `text = "Text style"`.

`settings/Bars.lua` — the `disabledNotice` of `NS.RegisterContainerPage`:

```lua
    disabledNotice = function(cfg)
        if cfg.style == "text" then
            return L["Not in use: this container is drawn as text. Set its Style to Bars on the Containers page to use these settings."]
        end
        return L["Not in use: this container is drawn as icons. Set its Style to Bars on the Containers page to use these settings."]
    end,
```

`settings/Icons.lua` — likewise:

```lua
    disabledNotice = function(cfg)
        if cfg.style == "text" then
            return L["Not in use: this container is drawn as text. Set its Style to Icons on the Containers page to use these settings."]
        end
        return L["Not in use: this container is drawn as bars. Set its Style to Icons on the Containers page to use these settings."]
    end,
```

`modules/ContainerManager.lua:444`: `CM.COPY_SECTIONS = { "filter", "layout", "behavior", "bars", "icons", "text" }`.

Create `settings/Text.lua`:

```lua
local _, NS = ...

-- settings/Text.lua — how a container drawn as TEXT looks (modules/Style_Text.lua draws it; the
-- template language is modules/TextTemplate.lua's).
--
--     band   [Container ▾]
--     [ General ][ Font ][ Icon ][ Animation ]
--
-- General is drawn bespoke (its `tabs` entry below) only to put two read-only blocks between its
-- rows: the token cheat sheet under the Template box, and the centering note under Placement. Its
-- rows are still ordinary schema rows, drawn by the flow engine, so the panel, `/am set`, the
-- Defaults button and the resets all reach them through the one write seam.
--
-- The Template row's `validate` is the parser (TT.Validate): a refused template is never stored, and
-- the refusal's reason reaches the player through the write seam's third return (settings/Schema.lua)
-- -- printed under "Invalid value for container.text.template" by the panel and by `/am set` alike.
--
-- A container drawn as bars or icons sees every row here disabled, under a note naming where its
-- style is changed (settings/OptionsSetup.lua's drawDisabledNotice). The font and icon-border blocks
-- are composed (options-ui-§16) with class-color companions (§17) resolved to the tracked unit's
-- class, as on the Bars page; the running-out swatch is a palette color and carries none.

local L = NS.L
local H = NS.Helpers
local C = NS.Constants
local TT = NS.TextTemplate
local D = NS.CONTAINER_TEMPLATE.text

local PAGE = "text"
local P = "container.text."
local UNIT = { source = "unit" }

local G_GENERAL, G_FONT, G_ICON, G_ANIM = L["General"], L["Font"], L["Icon"], L["Animation"]
local S_PLACEMENT = L["Placement"]
local SMALL = { fontObject = "GameFontHighlightSmall" }
local GRAY = "|cff808080%s|r"

--- The selected container's text block (empty with no container).
local function textBlock()
    local c = NS.ActiveContainer()
    return c and c.text or {}
end

--- A `disabledIf` predicate: the row is dimmed unless the selected container's loop effect is one
--- of `...`.
local function unlessAnim(...)
    local wanted = {}
    for _, v in ipairs({ ... }) do wanted[v] = true end
    return function() return not wanted[textBlock().anim or D.anim] end
end

--- A `disabledIf` predicate: the running-out rows need a duration token in the template (the blink
--- and the color ride the duration run's text).
local function noDuration()
    return not TT.ForDraw(textBlock().template).hasDuration
end

-- ── General ───────────────────────────────────────────────────────────────────────────────────

NS.RegisterSchemaRows({
    { path = P .. "width", page = PAGE, group = G_GENERAL, subgroup = L["Size"], type = "number", min = 40, max = 600, step = 1,
      label = L["Width (px)"], desc = L["The width of one line, icon included. Text past the edge is cut off."] },
    { path = P .. "height", page = PAGE, group = G_GENERAL, subgroup = L["Size"], type = "number", min = 8, max = 80, step = 1,
      label = L["Height (px)"], desc = L["The height of one line."] },
    { path = P .. "template", page = PAGE, group = G_GENERAL, subgroup = L["What each line says"], type = "string",
      dialogControl = "EditBox", maxLetters = C.TEXT_TEMPLATE_MAX, wide = true, label = L["Template"],
      desc = L["What each line says, built from the tokens listed below. Press Enter to apply."],
      validate = TT.Validate },
    { path = P .. "justifyH", page = PAGE, group = G_GENERAL, subgroup = S_PLACEMENT, type = "string",
      values = NS.Choices(C.TEXT_JUSTIFY_H, C.JUSTIFY_LABELS), label = L["Justify"],
      desc = L["How the line sits in its box. Center needs a template that is one piece (one token and no text around it); any other lines up Left."] },
    { path = P .. "justifyV", page = PAGE, group = G_GENERAL, subgroup = S_PLACEMENT, type = "string",
      values = NS.Choices(C.TEXT_JUSTIFY_V, C.TEXT_JUSTIFY_V_LABELS), label = L["Vertical justify"],
      desc = L["Whether the line sits at the top, middle or bottom of its box."] },
    { path = P .. "x", page = PAGE, group = G_GENERAL, subgroup = S_PLACEMENT, type = "number",
      min = -100, max = 100, step = 1, startsLine = true, label = L["X offset"], desc = L["Horizontal nudge, in pixels."] },
    { path = P .. "y", page = PAGE, group = G_GENERAL, subgroup = S_PLACEMENT, type = "number",
      min = -100, max = 100, step = 1, label = L["Y offset"], desc = L["Vertical nudge, in pixels."] },
})

--- The token cheat sheet, under the Template box: one line per token, then the bracket rule and the
--- escapes. Read-only text, drawn small.
local function cheatSheet(ctx)
    for _, def in ipairs(C.TEXT_TOKENS) do
        H.TextRow(ctx, ("|cffffd100$%s$|r  %s"):format(def.key, L[C.TEXT_TOKEN_LABELS[def.key]]), SMALL)
    end
    H.TextRow(ctx, L["[ ] hides its text along with the token inside it: $spellname$[ x$stacks$] shows ' x3' only at 2 or more stacks."], SMALL)
    H.TextRow(ctx, L["To write a literal [, ] or $, type it twice: [[, ]] or $$."], SMALL)
end

--- Under Placement: why Center is not honored, when it is chosen and the template has more than one
--- piece (modules/Style_Text.lua lines it up Left).
local function centerNote(ctx, cfg)
    local s = cfg.text or {}
    if (s.justifyH or D.justifyH) ~= "CENTER" then return end
    local compiled = TT.ForDraw(s.template)
    if compiled.single then return end
    local count = #compiled.pieces
    H.TextRow(ctx, GRAY:format(L["Center needs a one-piece template; this one has %d pieces, so it lines up Left."]:format(count)), SMALL)
end

--- The General tab: its rows, with the cheat sheet after the Template box and the centering note
--- after Placement.
local function renderGeneral(ctx, cfg, rows)
    local head, tail = {}, {}
    for _, row in ipairs(rows or {}) do
        local list = (row.subgroup == S_PLACEMENT) and tail or head
        local n = #list
        list[n + 1] = row
    end
    H.RenderRows(ctx, head, nil, nil, { noHeadings = true })
    cheatSheet(ctx)
    H.RenderRows(ctx, tail, nil, nil, { noHeadings = true })
    centerNote(ctx, cfg)
end

-- ── Font ──────────────────────────────────────────────────────────────────────────────────────

NS.RegisterSchemaRows(H.FontGroup({
    prefix = P .. "font.", page = PAGE, group = G_FONT, subgroup = L["Font"], classColor = UNIT,
}))
NS.RegisterSchemaRows({
    { path = P .. "timeFormat", page = PAGE, group = G_FONT, subgroup = L["Countdown"], type = "string",
      values = NS.Choices(C.TIME_FORMATS, C.TIME_FORMAT_LABELS), label = L["Time format"],
      desc = L["How the duration tokens write a time."] },
})

-- ── Icon ──────────────────────────────────────────────────────────────────────────────────────

NS.RegisterSchemaRows({
    { path = P .. "icon", page = PAGE, group = G_ICON, subgroup = L["Icon"], type = "string",
      values = NS.Choices(C.TEXT_ICON_POSITIONS, C.TEXT_ICON_POSITION_LABELS), label = L["Icon position"],
      desc = L["Where the aura's icon sits beside the text, or hide it."] },
    { path = P .. "iconSize", page = PAGE, group = G_ICON, subgroup = L["Icon"], type = "number", min = 0, max = 80, step = 1,
      label = L["Icon size (0 = line height)"], desc = L["A square icon this many pixels wide."] },
    { path = P .. "iconGap", page = PAGE, group = G_ICON, subgroup = L["Icon"], type = "number", min = 0, max = 20, step = 1,
      label = L["Icon gap (px)"], desc = L["Space between the icon and the text."] },
    { path = P .. "iconZoom", page = PAGE, group = G_ICON, subgroup = L["Icon"], type = "number", min = 0, max = 0.3, step = 0.01,
      label = L["Icon zoom"], desc = L["Crop the icon's border art."] },
})
local iconBorder = H.BorderGroup({
    prefix = P, page = PAGE, group = G_ICON, subgroup = L["Icon border"], show = true, classColor = UNIT,
    keys = { borderShow = "iconBorderShow", borderStyle = "iconBorderStyle", borderSize = "iconBorderSize",
             borderColor = "iconBorderColor", useClassColorBorder = "useClassColorIconBorder" },
})
for _, row in ipairs(iconBorder) do
    if row.path == P .. "iconBorderShow" then row.tooltip = L["Draw a border around the icon; its art sits inside it."] end
end
NS.RegisterSchemaRows(iconBorder)

-- ── Animation ─────────────────────────────────────────────────────────────────────────────────

NS.RegisterSchemaRows({
    { path = P .. "anim", page = PAGE, group = G_ANIM, subgroup = L["Loop"], type = "string",
      values = NS.Choices(C.TEXT_ANIMS, C.TEXT_ANIM_LABELS), label = L["Effect"],
      desc = L["A looping effect on the whole line. Pulse fades it down and back, Blink switches it off and on, Bounce moves it up and down (give the box a few pixels of headroom). A change made in combat starts when combat ends."] },
    { path = P .. "animSpeed", page = PAGE, group = G_ANIM, subgroup = L["Loop"], type = "number",
      min = 0.2, max = 3, step = 0.1, disabledIf = unlessAnim("pulse", "blink", "bounce"),
      label = L["Seconds per cycle"], desc = L["How long one pulse, blink or bounce takes."] },
    { path = P .. "animIntensity", page = PAGE, group = G_ANIM, subgroup = L["Loop"], type = "number",
      min = 0, max = 0.9, step = 0.05, isPercent = true, disabledIf = unlessAnim("pulse", "blink"),
      label = L["Faded to"], desc = L["How visible the line stays at the low point of a pulse or blink."] },
    { path = P .. "animBounce", page = PAGE, group = G_ANIM, subgroup = L["Loop"], type = "number",
      min = 1, max = 10, step = 1, disabledIf = unlessAnim("bounce"),
      label = L["Bounce height (px)"], desc = L["How far the line moves up. The box clips it, so leave headroom."] },
    { path = P .. "expiringColorOn", page = PAGE, group = G_ANIM, subgroup = L["Running out"], type = "bool",
      startsLine = true, disabledIf = noDuration,
      label = L["Recolor the time when running out"], desc = L["Turn the duration tokens another color in the last seconds. The rest of the line keeps the font color."] },
    { path = P .. "expiringThreshold", page = PAGE, group = G_ANIM, subgroup = L["Running out"], type = "number",
      min = 1, max = 60, step = 1, disabledIf = noDuration,
      label = L["Running out below (sec)"], desc = L["When the time text changes color."] },
    -- Palette definition (options-ui-§17 exemption): identifies a state, not a player.
    -- Never dimmed, even without a duration token: a swatch is read for its alpha (anti-pattern #74,
    -- tests/test_schema.lua).
    { path = P .. "expiringColor", page = PAGE, group = G_ANIM, subgroup = L["Running out"], type = "color",
      startsLine = true,
      label = L["Running-out color"], desc = L["The time text's color in the last seconds."] },
    -- engine-only: the blink is a curve the engine steps on its own clock; a placeholder's time is a
    -- fixed number, so the preview shows the running-out color and never the blink
    -- (tests/test_render_coverage.lua).
    { path = P .. "expiringBlink", page = PAGE, group = G_ANIM, subgroup = L["Running out"], type = "bool",
      disabledIf = noDuration, coverage = "engine-only",
      label = L["Blink when running out"],
      desc = L["Blink the duration tokens in the last seconds, in the running-out color when that is on. Only the duration tokens blink. The preview shows the color, not the blink."] },
})

--- After the Animation tab's rows: why Running out is dimmed, when the template has no duration.
local function animationNote(ctx)
    if not noDuration() then return end
    H.TextRow(ctx, GRAY:format(L["Running out needs a duration token, such as $remainingduration$, in the template."]), SMALL)
end

NS.RegisterContainerPage(PAGE, L["Text"], "AuraMasterTextPanel", {
    tabs = { { key = G_GENERAL, label = G_GENERAL, render = renderGeneral } },
    afterGroup = { [G_ANIM] = animationNote },
    disabledFor = function(cfg) return cfg.style ~= "text" end,
    disabledNotice = function(cfg)
        if cfg.style == "icons" then
            return L["Not in use: this container is drawn as icons. Set its Style to Text on the Containers page to use these settings."]
        end
        return L["Not in use: this container is drawn as bars. Set its Style to Text on the Containers page to use these settings."]
    end,
})
```

`AuraMaster.toc` — the settings page group becomes:

```text
# Conventional: the page files, each registering its rows and page at load. Filters, Layout,
# Bars, Icons and Text are sub-pages of Containers (N-2, D6): their tree label carries
# NS.SubPageLabel's mark, and this load position -- after Containers, before Profiles -- is
# what fixes their place in the tree.
settings\Filters.lua
settings\Layout.lua
settings\Bars.lua
settings\Icons.lua
settings\Text.lua
settings\Profiles.lua
```

and the `## Notes:` line ends "…for player, target, focus and pet, as bars, icons or lines of text."

`locales/enUS.lua`: delete the three retired lines

```lua
L["Draw each aura as a bar or as an icon. Bars and Icons each have their own settings page."] = "Draw each aura as a bar or as an icon. Bars and Icons each have their own settings page."
L["Which container this tab, and the Filters, Layout, Bars and Icons pages, edit. The choice is shared by every page."] = "Which container this tab, and the Filters, Layout, Bars and Icons pages, edit. The choice is shared by every page."
L["Create a container — /am new [player|target|focus|pet] [buffs|debuffs|enchants] [bars|icons]"] = "Create a container — /am new [player|target|focus|pet] [buffs|debuffs|enchants] [bars|icons]"
```

and append:

```lua
L["Text"] = "Text"
L["Not in use: this container is drawn as text. Set its Style to Bars on the Containers page to use these settings."] = "Not in use: this container is drawn as text. Set its Style to Bars on the Containers page to use these settings."
L["Not in use: this container is drawn as text. Set its Style to Icons on the Containers page to use these settings."] = "Not in use: this container is drawn as text. Set its Style to Icons on the Containers page to use these settings."
L["Draw each aura as a bar, an icon or a line of text. Bars, Icons and Text each have their own settings page."] = "Draw each aura as a bar, an icon or a line of text. Bars, Icons and Text each have their own settings page."
L["Which container this tab, and the Filters, Layout, Bars, Icons and Text pages, edit. The choice is shared by every page."] = "Which container this tab, and the Filters, Layout, Bars, Icons and Text pages, edit. The choice is shared by every page."
L["Create a container — /am new [player|target|focus|pet] [buffs|debuffs|enchants] [bars|icons|text]"] = "Create a container — /am new [player|target|focus|pet] [buffs|debuffs|enchants] [bars|icons|text]"
L["Text style"] = "Text style"
L["Animation"] = "Animation"
L["The width of one line, icon included. Text past the edge is cut off."] = "The width of one line, icon included. Text past the edge is cut off."
L["The height of one line."] = "The height of one line."
L["Template"] = "Template"
L["What each line says"] = "What each line says"
L["What each line says, built from the tokens listed below. Press Enter to apply."] = "What each line says, built from the tokens listed below. Press Enter to apply."
L["How the line sits in its box. Center needs a template that is one piece (one token and no text around it); any other lines up Left."] = "How the line sits in its box. Center needs a template that is one piece (one token and no text around it); any other lines up Left."
L["Vertical justify"] = "Vertical justify"
L["Whether the line sits at the top, middle or bottom of its box."] = "Whether the line sits at the top, middle or bottom of its box."
L["[ ] hides its text along with the token inside it: $spellname$[ x$stacks$] shows ' x3' only at 2 or more stacks."] = "[ ] hides its text along with the token inside it: $spellname$[ x$stacks$] shows ' x3' only at 2 or more stacks."
L["To write a literal [, ] or $, type it twice: [[, ]] or $$."] = "To write a literal [, ] or $, type it twice: [[, ]] or $$."
L["Center needs a one-piece template; this one has %d pieces, so it lines up Left."] = "Center needs a one-piece template; this one has %d pieces, so it lines up Left."
L["How the duration tokens write a time."] = "How the duration tokens write a time."
L["Where the aura's icon sits beside the text, or hide it."] = "Where the aura's icon sits beside the text, or hide it."
L["Icon size (0 = line height)"] = "Icon size (0 = line height)"
L["Space between the icon and the text."] = "Space between the icon and the text."
L["Loop"] = "Loop"
L["Effect"] = "Effect"
L["A looping effect on the whole line. Pulse fades it down and back, Blink switches it off and on, Bounce moves it up and down (give the box a few pixels of headroom). A change made in combat starts when combat ends."] = "A looping effect on the whole line. Pulse fades it down and back, Blink switches it off and on, Bounce moves it up and down (give the box a few pixels of headroom). A change made in combat starts when combat ends."
L["Seconds per cycle"] = "Seconds per cycle"
L["How long one pulse, blink or bounce takes."] = "How long one pulse, blink or bounce takes."
L["Faded to"] = "Faded to"
L["How visible the line stays at the low point of a pulse or blink."] = "How visible the line stays at the low point of a pulse or blink."
L["Bounce height (px)"] = "Bounce height (px)"
L["How far the line moves up. The box clips it, so leave headroom."] = "How far the line moves up. The box clips it, so leave headroom."
L["Turn the duration tokens another color in the last seconds. The rest of the line keeps the font color."] = "Turn the duration tokens another color in the last seconds. The rest of the line keeps the font color."
L["Blink when running out"] = "Blink when running out"
L["Blink the duration tokens in the last seconds, in the running-out color when that is on. Only the duration tokens blink. The preview shows the color, not the blink."] = "Blink the duration tokens in the last seconds, in the running-out color when that is on. Only the duration tokens blink. The preview shows the color, not the blink."
L["Running out needs a duration token, such as $remainingduration$, in the template."] = "Running out needs a duration token, such as $remainingduration$, in the template."
L["Not in use: this container is drawn as icons. Set its Style to Text on the Containers page to use these settings."] = "Not in use: this container is drawn as icons. Set its Style to Text on the Containers page to use these settings."
L["Not in use: this container is drawn as bars. Set its Style to Text on the Containers page to use these settings."] = "Not in use: this container is drawn as bars. Set its Style to Text on the Containers page to use these settings."
```

- [ ] **Step 4: Run them and see them pass**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua 2>&1 | grep -A3 -E "text page|third return|ForDraw|Style dropdown|defaults:|locale:|loadorder:|FAIL"`
Expected: PASS throughout — including `defaults: every leaf of the container template is edited by
a settings row` (every `text.*` leaf now has its row) and `schema: every color row has its
class-color companion … or is a palette swatch` (the running-out swatch carries no `disabledIf`,
anti-pattern #74). Until Task 8 a text container still draws as bars (`Style.Element` has no text
styler yet); nothing here tests the drawing. Re-point drifted citations with `/tmp/citefix.py`
(`defaults/Profile.lua:213`, the `NS.STARTER_CONTAINERS = {` line; `settings/OptionsSetup.lua:353`
and `:370`; `settings/Slash.lua:493-494`).

- [ ] **Step 5: Checkpoint — run the green gate**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua && /home/tushar/.claude/wow-addon/bin/ka0s-bounded luacheck .`
Expected: 0 failed; `0 warnings / 0 errors`. Update the ledger. Do not commit.

---

### Task 7: `modules/Style.lua` shared helpers; Bars on the shared icon helpers

**Files:**
- Modify: `modules/Style.lua` — `UsesClassColor` (lines 75–85), `ApplyText` (97–122), a new icon section before `Style.ApplyBorder`, the curve memos (171–206), `ElementSize` (241–251), the `RegionsFor` comment (276), `Style.Element`'s styler (333), and a new duration-run section before `Style.PreviewSeconds` (Task 2)
- Modify: `modules/Style_Bars.lua:81-117` (the three local icon helpers and `layout`'s two `layoutIcon` calls)
- Test: `tests/test_style.lua` (append)

**Interfaces:**
- Consumes: Task 4's `Compat.DurationProperty`, `Compat.CreateRuleFormatter`, `Compat.BlinkTextColor`; Task 2's `Style.PreviewSeconds`; Task 5's compiled duration pieces; Task 6's `D.text`.
- Produces (Task 8 builds on every one):
  - `Style.StyleKey(cfg) -> "bars"|"icons"|"text"` (an unknown style is `"bars"`); `Style.Styler(cfg) -> Style.Bars|Style.Icons|Style.Text` (looked up at call time; `Style.Text` is nil until Task 8, and `Style.Element` then dresses nothing).
  - `Style.ElementSize(cfg)` reads `cfg[StyleKey].width/height`, falling back to `D[StyleKey]`.
  - `Style.UsesClassColor(cfg)` reads the active block, `cfg.text` included.
  - `Style.ApplyFont(fs, t, tdef)` — the six font leaves only; `Style.ApplyText` calls it.
  - `Style.IconSizeFor(s, sdef, h)`, `Style.IconInset(s, sdef)`, `Style.LayoutIcon(host, am, s, sdef, side, size)` (anchors `am.iconBorder`/`am.icon` to `host`; Bars passes the button, Text its animation frame).
  - `Style.DurationTextFormat(piece, timeFormat) -> { formatString, components = { { property, formatter } } }` (memoized per piece and format); `Style.BindDurationFormat(frame, fs, textFormat, binding, s, sdef, normal)` binds `SetDurationText(fs, { textFormat, binding, textColor })`, where `textColor` is the blink curve (`s.expiringBlink`), the running-out step (`s.expiringColorOn`), or nil.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_style.lua`:

```lua

-- ── the text style's shared helpers (issue #2) ──────────────────────────────────────────────────

test("style: a text element takes its size from its own block, and a missing leaf from the template", function()
    local w, h = NS.Style.ElementSize(cfg({ style = "text", text = { width = 300, height = 20 } }))
    -- red under: ElementSize answering the bar's size for every style but icons
    assertEqual(w, 300)
    assertEqual(h, 20)
    local c = cfg({ style = "text" })
    c.text.width = nil
    w = NS.Style.ElementSize(c)
    assertEqual(w, D.text.width)
    assertEqual(NS.Style.StyleKey(cfg({ style = "text" })), "text")
    assertEqual(NS.Style.StyleKey(cfg({ style = "nonsense" })), "bars", "an unknown style draws as bars")
end)

test("style: a text container's class color is looked for in its text block, the font included", function()
    local U = NS.Style.UsesClassColor
    assertFalse(U(cfg({ style = "text" })), "the template turns none on")
    -- red under: UsesClassColor still reading the bar block for every style but icons
    assertTrue(U(cfg({ style = "text", text = { font = { useClassColorFont = true } } })), "the line's font")
    assertTrue(U(cfg({ style = "text", text = { useClassColorIconBorder = true } })), "the icon border")
    assertFalse(U(cfg({ style = "text", bars = { useClassColorBar = true } })), "the inactive block")
end)

test("style: a duration run's text format has its format string and one component per token, built once", function()
    local NS2 = fresh({ before = dofile("tests/text_apis.lua") })
    local piece = NS2.TextTemplate.Compile("$spellname$ $remainingduration$ / $maxduration$ ($remainingpercent$)").pieces[3]
    local tf = NS2.Style.DurationTextFormat(piece, "short")
    assertEqual(tf.formatString, "{} / {} ({}")
    local P = NS2.Compat
    -- red under: a component naming the token's key instead of the engine property
    assertEqual(tf.components[1].property, P.DurationProperty("RemainingDuration"))
    assertEqual(tf.components[2].property, P.DurationProperty("TotalDuration"))
    assertEqual(tf.components[3].property, P.DurationProperty("RemainingPercent"))
    assertEqual(tf.components[1].formatter.kind, "seconds")
    assertTrue(tf.components[1].formatter == tf.components[2].formatter, "one seconds formatter per format")
    -- red under: a percent written through the seconds formatter ("40s" for 40 %)
    local pf = tf.components[3].formatter
    assertEqual(pf.kind, "rule")
    local bp = pf:__last("SetBreakpoints")[1]
    assertEqual(bp[1].threshold, 0)
    assertEqual(bp[1].format, "%d%%")
    -- red under: DurationTextFormat rebuilding on every dress
    assertTrue(NS2.Style.DurationTextFormat(piece, "short") == tf, "memoized per piece and format")
    assertTrue(NS2.Style.DurationTextFormat(piece, "long") ~= tf, "a new format builds its own")
end)

test("style: a duration run binds its format and binding, recolored only when asked, blinking only when asked", function()
    local NS2 = fresh({ before = dofile("tests/text_apis.lua") })
    local S = NS2.Style
    local D2 = NS2.CONTAINER_TEMPLATE.text
    local piece = NS2.TextTemplate.Compile("$remainingduration$").pieces[1]
    local tf = S.DurationTextFormat(piece, "blizzard")
    local white = { r = 1, g = 1, b = 1, a = 1 }
    local function bind(s)
        local b = R()
        S.BindDurationFormat(b, "fs", tf, "binding", s, D2, white)
        return b:__last("SetDurationText")[2]
    end
    local opts = bind({})
    assertTrue(opts.textFormat == tf)
    assertEqual(opts.binding, "binding")
    assertNil(opts.textColor, "no curve unless turned on")
    local red = { r = 1, g = 0, b = 0, a = 1 }
    opts = bind({ expiringColorOn = true, expiringThreshold = 3, expiringColor = red })
    local points = opts.textColor.curve:__count("AddPoint")
    -- red under: runTextColor building the blink curve for the plain recolor
    assertEqual(points, 2, "the plain step: the running-out color, then the font color")
    opts = bind({ expiringColorOn = true, expiringBlink = true, expiringThreshold = 3, expiringColor = red })
    -- red under: runTextColor ignoring expiringBlink
    assertEqual(opts.textColor.curve:__count("AddPoint"), 3 / 0.25 + 1, "a point every quarter second, then the font color")
    assertEqual(opts.textColor.curve:__last("AddPoint")[2].g, 1, "the font color from the threshold up")
    assertEqual(opts.textColor.curve.calls[1].name, "SetType")
    assertEqual(opts.textColor.curve.calls[2][2].r, 1, "the blink is in the running-out color")
    opts = bind({ expiringBlink = true, expiringThreshold = 3, expiringColor = red })
    assertEqual(opts.textColor.curve.calls[2][2].g, 1, "blink without the recolor blinks the font color")
end)

test("style: a placeholder's seconds are written by the format's formatter, else as whole seconds", function()
    local NS2 = fresh({ before = dofile("tests/text_apis.lua") })
    -- tests/text_apis.lua's formatter writes "<n>s"
    assertEqual(NS2.Style.PreviewSeconds(28, "short"), "28s")
    -- red under: PreviewSeconds not falling back when the client has no formatter
    assertEqual(NS.Style.PreviewSeconds(28, "short"), "28s", "the shared environment has none")
end)
```

- [ ] **Step 2: Run it and see it fail**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua 2>&1 | grep -A3 -E "style: (a text element|a text container's class|a duration run|a placeholder's seconds)"`
Expected: FAIL — `expected 300, got 220` (ElementSize answers the bar's width), `attempt to call field 'StyleKey' (a nil value)`, `attempt to call field 'DurationTextFormat' (a nil value)`, `attempt to call field 'BindDurationFormat' (a nil value)`.

- [ ] **Step 3: Implement**

In `modules/Style.lua`:

1. Replace the `UsesClassColor` doc comment's lead-in and its first line
   (`--- Whether the container's active style block …` through `    local s = (cfg.style == "icons") and cfg.icons or cfg.bars`) so the block reads:

```lua
--- The key of the style `cfg` is drawn in: "icons", "text", or "bars" for anything else (a style a
--- later version removed draws as bars, the template's own style).
function Style.StyleKey(cfg)
    local style = cfg.style
    if style == "icons" or style == "text" then return style end
    return "bars"
end

--- The container's active style block: cfg.icons, cfg.text or cfg.bars.
local function styleBlock(cfg)
    return cfg[Style.StyleKey(cfg)]
end

--- Whether the container's active style block (or one of its text blocks) turns a class color on.
--- Allocation-free: it runs on every unit swap for each container tracking the swapped unit.
function Style.UsesClassColor(cfg)
    local s = styleBlock(cfg)
    if type(s) ~= "table" then return false end
    if anyClassFlag(s) then return true end
    for _, sub in pairs(s) do
        if type(sub) == "table" and anyClassFlag(sub) then return true end
    end
    return false
end
```

2. Replace `Style.ApplyText`'s doc comment and its body down to `    fs:ClearAllPoints()` with the font
   helper plus the slimmer `ApplyText` head (the rest of `ApplyText` — `local point = …` onward — is unchanged):

```lua
--- Apply the six canonical font leaves of `t` (options-ui-§16) to a FontString: face, size, flags,
--- color (with its class-color companion) and shadow. `tdef` is the template's block for the same
--- text, which the size falls back to.
function Style.ApplyFont(fs, t, tdef)
    local size = tonumber(t.fontSize) or tdef.fontSize
    local flags = FLAG_MAP[t.fontFlags or "NONE"] or (t.fontFlags or "")
    local path = Style.Fetch("font", t.font, C.FALLBACK_FONT)
    if not fs:SetFont(path, size, flags) then fs:SetFont(C.FALLBACK_FONT, size, flags) end
    fs:SetTextColor(Style.Color(t.fontColor, t.useClassColorFont))
    if t.fontShadow then
        fs:SetShadowColor(0, 0, 0, 1)
        fs:SetShadowOffset(1, -1)
    else
        fs:SetShadowOffset(0, 0)
    end
end

--- Apply one text block (the six canonical font leaves plus point / x / y / justify / show) to a
--- FontString parented under `anchorTo`. `tdef` is the template's block for the same element, which
--- the size, point and justify fall back to. `boxWidth` is the width the text may take (its host's):
--- a single-anchor font string sized to its own string has nothing to justify within, so a text given
--- a box is as wide as the box less its offset. A second anchor, set after this, overrides the width.
function Style.ApplyText(fs, t, anchorTo, tdef, boxWidth)
    if not (fs and t) then return end
    Style.ApplyFont(fs, t, tdef)
    fs:ClearAllPoints()
    local point = t.point or tdef.point
    local x = tonumber(t.x) or 0
    fs:SetPoint(point, anchorTo, point, x, tonumber(t.y) or 0)
    fs:SetWidth(textWidth(boxWidth, x))
    fs:SetJustifyH(t.justify or tdef.justify)
    fs:SetWordWrap(false)
end
```

   then insert directly after the end of `ApplyText` (before Task 2's "Measuring a time text" banner):

```lua
-- ---------------------------------------------------------------------------
-- The icon beside a bar or a line of text
-- ---------------------------------------------------------------------------
-- Shared by modules/Style_Bars.lua and modules/Style_Text.lua. `s` is the stored style block and
-- `sdef` the template's block it was copied from (D.bars, D.text); both carry the same icon leaves:
-- iconSize, iconZoom and the composed icon-border block.

--- The icon's side: its stored size, or the template's when that is missing; zero means `h`, the
--- element's height.
function Style.IconSizeFor(s, sdef, h)
    local size = tonumber(s.iconSize) or sdef.iconSize
    return size > 0 and size or h
end

--- The icon border's thickness when it draws, else 0: how far the art is inset inside the icon's box.
function Style.IconInset(s, sdef)
    if not Style.OrTemplate(s.iconBorderShow, sdef.iconBorderShow) then return 0 end
    if Style.OrTemplate(s.iconBorderStyle, sdef.iconBorderStyle) == "None" then return 0 end
    return tonumber(s.iconBorderSize) or sdef.iconBorderSize
end

--- Place the icon's `size` box at `side` ("LEFT" | "RIGHT") of `host`: the icon border (am.iconBorder)
--- takes the whole box and the art (am.icon) sits inside it, inset by the border's thickness, as
--- modules/Style_Icons.lua's layoutIcon does, so a thick border never hides the art.
function Style.LayoutIcon(host, am, s, sdef, side, size)
    local inset = Style.IconInset(s, sdef)
    am.iconBorder:ClearAllPoints()
    am.iconBorder:SetSize(size, size)
    am.iconBorder:SetPoint(side, host, side, 0, 0)
    Style.ApplyBorder(am.iconBorder, inset > 0, Style.OrTemplate(s.iconBorderStyle, sdef.iconBorderStyle), inset,
        s.iconBorderColor or sdef.iconBorderColor, s.useClassColorIconBorder)

    local art = math.max(0, size - 2 * inset)
    am.icon:Show()
    am.icon:SetSize(art, art)
    am.icon:SetPoint(side, host, side, side == "RIGHT" and -inset or inset, 0)
    local z = tonumber(s.iconZoom) or sdef.iconZoom
    am.icon:SetTexCoord(z, 1 - z, z, 1 - z)
end
```

3. Replace `curveFor` and its doc comment with the shared slot, `curveFor` on it, and the blink memo
   (and add `local blinkCurves = setmetatable({}, WEAK_KEYS)` under `local curves = …`):

```lua
--- The memo slot for one color pair under `root`: `root[expiring][normal]`, a table keyed by
--- threshold, each level built on demand. Weak on both colors, so a replaced color takes its entries.
local function curveSlot(root, expiring, normal)
    local byNormal = root[expiring]
    if not byNormal then
        byNormal = setmetatable({}, WEAK_KEYS)
        root[expiring] = byNormal
    end
    local byThreshold = byNormal[normal]
    if not byThreshold then
        byThreshold = {}
        byNormal[normal] = byThreshold
    end
    return byThreshold
end

--- The expiring-text color curve for one threshold and color pair: `curves[expiring][normal][threshold]`.
local function curveFor(threshold, expiring, normal)
    local slot = curveSlot(curves, expiring, normal)
    local tc = slot[threshold]
    if tc == nil then
        tc = NS.Compat.ExpiringTextColor(threshold, expiring, normal)
        slot[threshold] = tc
    end
    return tc
end

--- The blinking running-out curve for one threshold and color pair, memoized as curveFor is.
local function blinkCurveFor(threshold, blink, normal)
    local slot = curveSlot(blinkCurves, blink, normal)
    local tc = slot[threshold]
    if tc == nil then
        tc = NS.Compat.BlinkTextColor(threshold, blink, normal)
        slot[threshold] = tc
    end
    return tc
end
```

4. Replace `Style.ElementSize` and its doc comment with:

```lua
--- The size one element occupies, from the container's style settings — what the engine's flow layout
--- is told (elementWidth / elementHeight), and what the drag handle and the preview are sized to.
--- Every style block carries its own width and height, the template's standing in for a missing one.
--- @return number width, number height
function Style.ElementSize(cfg)
    local key = Style.StyleKey(cfg)
    local s, sdef = cfg[key] or {}, D[key]
    return tonumber(s.width) or sdef.width, tonumber(s.height) or sdef.height
end
```

5. In the `Style.RegionsFor` doc comment: `for \`style\` ("bars" | "icons")` → `for \`style\` ("bars" | "icons" | "text")`.
6. Insert directly above the comment `-- The dress in progress, handed to runDress through upvalues:`:

```lua
--- The styler that dresses `cfg`'s elements: Style.Bars, Style.Icons or Style.Text (each decorates
--- NS.Style at file scope in its own file, so it is looked up here, at call time).
function Style.Styler(cfg)
    local key = Style.StyleKey(cfg)
    if key == "icons" then return Style.Icons end
    if key == "text" then return Style.Text end
    return Style.Bars
end
```

   and in `Style.Element` replace `    local styler = (cfg.style == "icons") and Style.Icons or Style.Bars` with `    local styler = Style.Styler(cfg)`.
7. Insert directly above Task 2's `--- \`seconds\` written as a live button's time text reads (B-5), …` comment:

```lua
-- ---------------------------------------------------------------------------
-- A Text style's duration run (modules/Style_Text.lua)
-- ---------------------------------------------------------------------------

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

--- The `textFormat` option for one compiled duration piece (modules/TextTemplate.lua) in one time
--- format: the piece's format string, and one { property, formatter } component per {} in order, a
--- time through the look's seconds formatter (formatterFor) and a percent through "%d%%". Built once
--- per piece and time format; the parser memoizes its pieces, so a hit allocates nothing.
function Style.DurationTextFormat(piece, timeFormat)
    local byFormat = textFormats[piece]
    if not byFormat then
        byFormat = {}
        textFormats[piece] = byFormat
    end
    local key = timeFormat or false
    local tf = byFormat[key]
    if tf then return tf end
    local components = {}
    for i, c in ipairs(piece.components) do
        components[i] = { property = NS.Compat.DurationProperty(c.prop),
            formatter = (c.fmt == "percent") and percentFor() or formatterFor(timeFormat) }
    end
    tf = { formatString = piece.format, components = components }
    byFormat[key] = tf
    return tf
end

--- The `textColor` of a Text style's duration run: the blinking curve when `expiringBlink` is on (in
--- the running-out color when the recolor is on too, else in `normal`), the plain running-out curve
--- when only the recolor is on, else nil, and the font color stands.
local function runTextColor(s, sdef, normal)
    local threshold = tonumber(s.expiringThreshold) or sdef.expiringThreshold
    local expiring = s.expiringColor or NO_COLOR
    if s.expiringBlink then
        return blinkCurveFor(threshold, s.expiringColorOn and expiring or normal, normal)
    end
    if s.expiringColorOn then return curveFor(threshold, expiring, normal) end
    return nil
end

--- Bind a Text style's duration run: `textFormat` (Style.DurationTextFormat) through the prebuilt
--- `binding` (Compat.CreateDurationBinding, nil on a client without one), recolored by the
--- running-out curve or the blinking one (runTextColor). `normal` is the line's font color, which a
--- curve returns to above the threshold. `sdef` is the template's block the threshold falls back to.
function Style.BindDurationFormat(frame, fs, textFormat, binding, s, sdef, normal)
    Style.Bind(frame, "SetDurationText", fs, {
        textFormat = textFormat, binding = binding, textColor = runTextColor(s, sdef, normal or NO_COLOR),
    })
end
```

In `modules/Style_Bars.lua`, replace the three local helpers `iconSizeFor`, `iconInset`, `layoutIcon`
and the head of `layout` (from `--- The icon's side: …` down to `    am.icon:ClearAllPoints()`, exclusive) with:

```lua
--- The icon's side: its stored size, or the template's when that is missing; zero means the bar's
--- height (the shared helper in modules/Style.lua, on the bar's own leaves).
local function iconSizeFor(b, h)
    return Style.IconSizeFor(b, D.bars, h)
end

--- Lay the icon and the bar area out inside the element. The icon's box and its border are placed by
--- modules/Style.lua's Style.LayoutIcon, which the Text style shares.
local function layout(frame, am, b, h)
    local iconPos = b.icon or D.bars.icon
    local iconSize = iconSizeFor(b, h)
    local gap = tonumber(b.iconGap) or D.bars.iconGap
```

and in `layout` replace `layoutIcon(frame, am, b, "RIGHT", iconSize)` with
`Style.LayoutIcon(frame, am, b, D.bars, "RIGHT", iconSize)` and `layoutIcon(frame, am, b, "LEFT", iconSize)` with
`Style.LayoutIcon(frame, am, b, D.bars, "LEFT", iconSize)`. `iconSizeFor` keeps its other callers
(`barAreaWidth`, `applyTexts`).

- [ ] **Step 4: Run it and see it pass**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua 2>&1 | grep -A3 -E "^  (PASS|FAIL)  (style|bars|icons):|FAIL"`
Expected: the five new `style:` cases PASS, and **every existing `bars:` and `icons:` case passes
unchanged** (spec §4: Bars' behavior is unchanged and its tests are not edited). Re-point drifted
citations with `/tmp/citefix.py` (`modules/Style.lua:156`, `:331`, `:332-340`, `:382-384`;
`modules/Style_Bars.lua:170`, `:183`, `:186`, `:299` move up by the removed helpers).

- [ ] **Step 5: Checkpoint — run the green gate**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua && /home/tushar/.claude/wow-addon/bin/ka0s-bounded luacheck .`
Expected: 0 failed; `0 warnings / 0 errors`. Update the ledger. Do not commit.

---

### Task 8: `modules/Style_Text.lua` — the chain, the bindings, the loops, the icon, the preview fill

**Files:**
- Create: `modules/Style_Text.lua`
- Create: `tests/region_builder.lua`
- Modify: `modules/Style.lua` (insert `Style.StructureKey` above `Style.Styler`)
- Modify: `AuraMaster.toc` (the `Style` note and `modules\Style_Text.lua` after `modules\Style_Icons.lua`)
- Modify: `tests/run.lua` (declare `test_style_text` after `test_style_icons`), `tests/test_loadorder.lua:46` (two pairs)
- Test: create `tests/test_style_text.lua`

**Interfaces:**
- Consumes: Task 7's `Style.ApplyFont`, `Style.IconSizeFor`, `Style.LayoutIcon`, `Style.DurationTextFormat`, `Style.BindDurationFormat`, `Style.PreviewSeconds`, `Style.RegionsFor`, `Style.ClearAdditiveBindings`, `Style.ApplyBehavior`, `Style.Bind`, `Style.Color`; Task 6's `TT.ForDraw`, `D.text`; Task 5's `C.TEXT_DISPEL_TYPES/LABELS`; Task 4's `Compat.CreateRuleFormatter`, `Compat.CreateDurationBinding`.
- Produces:
  - `NS.Style.Text` with `Text.Apply(frame, cfg, engine)`, `Text.Bind(frame, am, cfg, s, compiled)`, `Text.FillPreview(frame, aura, cfg)`, `Text.Compiled(s) -> compiled` (the stored template, or the default one, logged once), `Text.JustifyFor(s, compiled) -> "LEFT"|"CENTER"|"RIGHT"`.
  - `frame.__am` for a text element: `style = "text"`, `clip`, `anim`, `icon`, `iconBorder`, `area`, `chain`, `piece1..pieceN`, `pieceCount`, `shape`, `pulseGroup`/`pulse`, `blinkGroup`/`blink`, `bounceGroup`/`bounce`, and, once bound, `binding` / `blinkBinding`. `frame.__amChains[shape]` holds the chains put away.
  - `Style.StructureKey(cfg) -> "bars"|"icons"|"text:<shape>"` (Task 9 folds it into the engine's structure key).
  - `tests/region_builder.lua`: `B.new(made)`, `B.during(mocks, made, fn)`, `B.children(made, kind, parent)`.

- [ ] **Step 1: Write the helper and the failing test**

Create `tests/region_builder.lua`:

```lua
-- tests/region_builder.lua — a recorder (tests/region_recorder.lua) that BUILDS recorders: every
-- font string, texture, animation group and animation asked of it is a recorder of its own, and so
-- is every frame CreateFrame builds while `B.during` runs. The kit's CreateFontString answers the
-- frame itself (mock_base's known divergence), which would make every piece of a Text style's chain
-- one table; built this way each piece, and the frames around it, record their own calls from the
-- first dress on.
--
-- Not a suite (tests/run.lua does not list it) and not part of the vendored kit.
--
--     local B = dofile("tests/region_builder.lua")
--     local made = {}
--     local frame = B.new(made)
--     B.during(mocks, made, function() NS.Style.Element(frame, cfg, true) end)
--
-- Every recorder built is appended to `made` in creation order, stamped `kind` (FontString, Texture,
-- AnimationGroup, Animation, or the frame type), `parent` (who created it) and `args` (the create
-- call's arguments).

local R = dofile("tests/region_recorder.lua")

local B = {}

--- Append `v` to `list`; the length sits on a line of its own (tests/test_lintconfig.lua).
local function push(list, v)
    local n = #list
    list[n + 1] = v
end

local CHILDREN = { CreateFontString = "FontString", CreateTexture = "Texture",
    CreateAnimationGroup = "AnimationGroup", CreateAnimation = "Animation" }

--- A recorder whose Create* methods answer new builders, each recorded on `made`.
function B.new(made)
    local r = R()
    for method, kind in pairs(CHILDREN) do
        r.__answer[method] = function(self, ...)
            local c = B.new(made)
            c.kind, c.parent, c.args = kind, self, { ... }
            push(made, c)
            return c
        end
    end
    return r
end

--- Run `fn` with the mock's CreateFrame answering builders (each recorded on `made`), then put the
--- mock's own back, a raise included.
function B.during(m, made, fn)
    local real = m.CreateFrame
    m.CreateFrame = function(frameType, _, parent, template)
        local f = B.new(made)
        f.kind, f.parent, f.args = frameType, parent, { template }
        push(made, f)
        return f
    end
    local ok, err = pcall(fn)
    m.CreateFrame = real
    if not ok then error(err, 0) end
end

--- The recorders on `made` of `kind` whose parent is `parent` (any parent when nil), in order.
function B.children(made, kind, parent)
    local out = {}
    for _, r in ipairs(made) do
        if r.kind == kind and (parent == nil or r.parent == parent) then push(out, r) end
    end
    return out
end

return B
```

Create `tests/test_style_text.lua`:

```lua
-- tests/test_style_text.lua — modules/Style_Text.lua: how one aura is dressed as a LINE OF TEXT. The
-- nested clip, animation and text-area frames, the chain's anchors for every justify, each piece's
-- engine binding and its options, the blink, the loops, the icon, a refused stored template, the
-- chain kept per template shape, and the preview fill.
--
-- One environment with the client's text APIs as recording stand-ins (tests/text_apis.lua), built
-- once: every element is built on tests/region_builder.lua's recorders, so each piece records its
-- own calls, and nothing below writes to the environment.

local T = _G.AM_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local B = dofile("tests/region_builder.lua")

local env
local function E()
    if not env then
        local NS, m = dofile("tests/fresh_env.lua")({ before = dofile("tests/text_apis.lua") })
        env = { NS = NS, m = m }
    end
    return env.NS, env.m
end

local function cfg(over)
    local NS = E()
    return NS.Database.Merge(NS.Database.DeepCopy(NS.CONTAINER_TEMPLATE), over or {})
end

--- A text element dressed for `c`: the button, its regions, and every recorder the dress built.
local function dressed(c, engine, frame, made)
    local NS, m = E()
    made = made or {}
    frame = frame or B.new(made)
    B.during(m, made, function() NS.Style.Element(frame, c, engine) end)
    return frame, frame.__am, made
end

--- The pieces of `am`'s current chain, in order.
local function pieces(am)
    local out = {}
    for i = 1, am.pieceCount do out[i] = am["piece" .. i] end
    return out
end

local function text(over)
    local t = { style = "text", text = over or {} }
    return cfg(t)
end

-- ── the frames ─────────────────────────────────────────────────────────────────────────────────

test("text style: the element takes its size; clip, animation and text-area frames nest inside it", function()
    local frame, am = dressed(text({ width = 250, height = 18 }))
    assertEqual(frame:__joined("SetSize"), "250,18")
    -- red under: build without the clip frame (a bounce or a long line drawn over a neighbor)
    assertTrue(am.clip.parent == frame)
    assertEqual(am.clip:__joined("SetClipsChildren"), "true")
    assertTrue(am.clip:__last("SetAllPoints")[1] == frame)
    assertTrue(am.anim.parent == am.clip, "the animated frame inside the clip")
    assertTrue(am.area.parent == am.anim and am.icon.parent == am.anim, "the icon and the text move together")
    -- red under: the text area left unclipped (a long line runs under the icon)
    assertEqual(am.area:__joined("SetClipsChildren"), "true")
    assertTrue(am.chain.parent == am.area)
end)

-- ── the chain ──────────────────────────────────────────────────────────────────────────────────

test("text style: Left lays the first piece at the area's left and each next piece against the previous one", function()
    local _, am = dressed(text({ template = "$spellname$ - $stacks$", justifyH = "LEFT", justifyV = "MIDDLE", x = 3, y = -1 }))
    local p = pieces(am)
    assertEqual(#p, 3)
    local first = p[1]:__last("SetPoint")
    assertEqual(first[1], "LEFT"); assertTrue(first[2] == am.area); assertEqual(first[3], "LEFT")
    assertEqual(first[4], 3); assertEqual(first[5], -1)
    for i = 2, 3 do
        local pt = p[i]:__last("SetPoint")
        -- red under: a piece anchored to the area instead of the previous piece (pieces overlap)
        assertEqual(pt[1], "LEFT"); assertTrue(pt[2] == p[i - 1]); assertEqual(pt[3], "RIGHT")
        assertEqual(pt[4], 0); assertEqual(pt[5], 0)
    end
    for _, fs in ipairs(p) do
        -- red under: a piece given a width (the client auto-sizes an engine-written string)
        assertEqual(fs:__count("SetWidth"), 0)
        assertEqual(fs:__count("SetPoint"), 1, "single-anchored")
        assertEqual(fs:__joined("SetWordWrap"), "false")
    end
end)

test("text style: Right lays the last piece at the area's right and each earlier piece against the next", function()
    local _, am = dressed(text({ template = "$spellname$ - $stacks$", justifyH = "RIGHT", x = -2, y = 0 }))
    local p = pieces(am)
    local last = p[3]:__last("SetPoint")
    -- red under: layoutChain ignoring the justify (a Right line laid from the left)
    assertEqual(last[1], "RIGHT"); assertTrue(last[2] == am.area); assertEqual(last[3], "RIGHT"); assertEqual(last[4], -2)
    for i = 1, 2 do
        local pt = p[i]:__last("SetPoint")
        assertEqual(pt[1], "RIGHT"); assertTrue(pt[2] == p[i + 1]); assertEqual(pt[3], "LEFT")
    end
end)

test("text style: the vertical justify picks the top, middle or bottom anchor points", function()
    for v, want in pairs({ TOP = "TOPLEFT", MIDDLE = "LEFT", BOTTOM = "BOTTOMLEFT" }) do
        local _, am = dressed(text({ template = "$spellname$ $stacks$", justifyV = v }))
        local p = pieces(am)
        -- red under: V_PREFIX missing a justify, or the links anchored at the middle whatever it says
        assertEqual(p[1]:__last("SetPoint")[1], want, v)
        assertEqual(p[2]:__last("SetPoint")[3], want:gsub("LEFT", "RIGHT"), v .. " link")
    end
    local _, am = dressed(text({ template = "$spellname$ $stacks$", justifyH = "RIGHT", justifyV = "TOP" }))
    assertEqual(pieces(am)[2]:__last("SetPoint")[1], "TOPRIGHT")
end)

test("text style: Center centers a one-piece template and lines a longer one up Left", function()
    local _, am = dressed(text({ template = "$spellname$", justifyH = "CENTER", justifyV = "MIDDLE" }))
    local pt = pieces(am)[1]:__last("SetPoint")
    assertEqual(pt[1], "CENTER"); assertEqual(pt[3], "CENTER")
    _, am = dressed(text({ template = "$spellname$", justifyH = "CENTER", justifyV = "TOP" }))
    assertEqual(pieces(am)[1]:__last("SetPoint")[1], "TOP")
    _, am = dressed(text({ template = "$spellname$ $stacks$", justifyH = "CENTER" }))
    -- red under: JustifyFor honoring Center on a multi-piece chain (its width is never readable)
    assertEqual(pieces(am)[1]:__last("SetPoint")[1], "LEFT")
    local NS = E()
    assertEqual(NS.Style.Text.JustifyFor({ justifyH = "CENTER" }, { single = false }), "LEFT")
end)

test("text style: every piece takes the line's font; a literal takes its text", function()
    local _, am = dressed(text({ template = "$spellname$ :: $stacks$", font = { fontSize = 15, fontFlags = "NONE",
        fontColor = { r = 0.5, g = 0.6, b = 0.7, a = 1 } } }))
    local p = pieces(am)
    for i, fs in ipairs(p) do
        -- red under: dressPieces skipping the literal pieces (plain text in the default font)
        assertEqual(fs:__last("SetFont")[2], 15, "piece " .. i)
        assertEqual(fs:__joined("SetTextColor"), "0.5,0.6,0.7,1", "piece " .. i)
        assertTrue(fs:IsShown())
    end
    assertEqual(p[2]:__last("SetText")[1], " :: ")
    assertNil(p[1]:__last("SetText"), "the engine writes the name, never the dress")
end)

-- ── the engine ─────────────────────────────────────────────────────────────────────────────────

test("text style: each engine piece is bound to its own field, a literal to none", function()
    local frame, am = dressed(text({ template = "$spellname$ :: [ x$stacks$][ ($dispeltype$)][ - $remainingduration$]" }), true)
    local p = pieces(am)
    -- red under: BINDERS missing a kind, or binding the wrong string
    assertTrue(frame:__last("SetSpellName")[1] == p[1])
    assertTrue(frame:__last("SetApplicationCount")[1] == p[3])
    assertTrue(frame:__last("SetDispelTypeText")[1] == p[4])
    assertTrue(frame:__last("SetDurationText")[1] == p[5])
    assertEqual(frame:__count("SetSpellName") + frame:__count("SetApplicationCount")
        + frame:__count("SetDispelTypeText") + frame:__count("SetDurationText"), 4, "one binding per field")
end)

test("text style: stacks bind a rule formatter that hides one stack and folds the bracket text", function()
    local frame = dressed(text({ template = "$spellname$[ x$stacks$%]" }), true)
    local opts = frame:__last("SetApplicationCount")[2]
    local bp = opts.formatter:__last("SetBreakpoints")[1]
    -- red under: stackOptionsFor without the zero breakpoint (a single stack reads " x1%")
    assertEqual(bp[1].threshold, 0); assertEqual(bp[1].format, "")
    assertEqual(bp[2].threshold, 2); assertEqual(bp[2].format, " x%d%%")
    local again = dressed(text({ template = "$spellname$[ x$stacks$%]" }), true)
    assertTrue(again:__last("SetApplicationCount")[2] == opts, "built once per format")
end)

test("text style: dispel type binds a text map of every type in the bracket text, nothing without a type", function()
    local NS = E()
    local frame = dressed(text({ template = "$spellname$[ <$dispeltype$>]" }), true)
    local opts = frame:__last("SetDispelTypeText")[2]
    assertTrue(opts.showWhenHarmful and opts.showWhenHelpful, "buffs and debuffs")
    -- red under: showWithoutDispelType left on (a typeless aura shows the engine's own text)
    assertFalse(opts.showWithoutDispelType)
    for _, t in ipairs(NS.Constants.TEXT_DISPEL_TYPES) do
        assertEqual(opts.customDispelTextMap[t], " <" .. NS.L[NS.Constants.TEXT_DISPEL_LABELS[t]] .. ">", t)
    end
    assertNil(opts.customDispelTextMap.None)
end)

test("text style: the duration run binds its format, components and a prebuilt binding that writes nothing when timeless", function()
    local NS = E()
    local frame, am = dressed(text({ template = "$spellname$[ - $remainingduration$ / $maxduration$]", timeFormat = "short" }), true)
    local call = frame:__last("SetDurationText")
    local opts = call[2]
    assertEqual(opts.textFormat.formatString, " - {} / {}")
    assertEqual(#opts.textFormat.components, 2)
    -- red under: the binding left off (a timeless aura shows the engine's zero text and the " - ")
    assertTrue(opts.binding ~= nil and opts.binding == am.binding)
    assertEqual(opts.binding:__last("SetZeroDurationText")[1], "")
    assertEqual(opts.binding:__last("SetExpiredText")[1], "")
    assertEqual(opts.binding:__count("SetUpdateInterval"), 0, "no fast refresh without the blink")
    assertNil(opts.textColor)
    assertTrue(opts.textFormat == NS.Style.DurationTextFormat(NS.TextTemplate.Compile(
        "$spellname$[ - $remainingduration$ / $maxduration$]").pieces[2], "short"))
end)

test("text style: blink binds the blinking curve and a 0.1 s refresh; off, neither", function()
    local frame, am = dressed(text({ expiringColorOn = true, expiringBlink = true, expiringThreshold = 2 }), true)
    local opts = frame:__last("SetDurationText")[2]
    -- red under: bindingFor ignoring the blink (the curve steps between the engine's slow updates)
    assertTrue(opts.binding == am.blinkBinding)
    assertEqual(opts.binding:__last("SetUpdateInterval")[1], 0.1)
    assertEqual(opts.textColor.curve:__count("AddPoint"), 2 / 0.25 + 1)
    frame = dressed(text({ expiringColorOn = true, expiringBlink = false, expiringThreshold = 2 }), true)
    opts = frame:__last("SetDurationText")[2]
    assertEqual(opts.binding:__count("SetUpdateInterval"), 0)
    assertEqual(opts.textColor.curve:__count("AddPoint"), 2, "the plain running-out step")
end)

test("text style: a template without a duration token binds no duration text", function()
    local frame = dressed(text({ template = "$spellname$[ x$stacks$]" }), true)
    -- red under: Bind binding a duration text the template does not use
    assertEqual(frame:__count("SetDurationText"), 0)
end)

test("text style: a preview dress binds nothing", function()
    local frame = dressed(text({}), false)
    assertEqual(frame:__count("SetSpellName") + frame:__count("SetDurationText") + frame:__count("SetIcon"), 0)
end)

-- ── the loops ──────────────────────────────────────────────────────────────────────────────────

test("text style: the three loops are built once, looping as each effect needs, and None plays none", function()
    local _, am, made = dressed(text({ anim = "none" }))
    local groups = B.children(made, "AnimationGroup", am.anim)
    assertEqual(#groups, 3)
    assertEqual(am.pulseGroup:__joined("SetLooping"), "BOUNCE")
    assertEqual(am.blinkGroup:__joined("SetLooping"), "REPEAT")
    assertEqual(am.bounceGroup:__joined("SetLooping"), "BOUNCE")
    assertEqual(am.pulse.args[1], "Alpha"); assertEqual(am.blink.args[1], "Alpha")
    -- red under: a Scale loop (glyphs scaled past their boxes overlap the next piece)
    assertEqual(am.bounce.args[1], "Translation")
    for _, g in ipairs(groups) do
        assertTrue(g:__count("Stop") >= 1, "every loop stopped")
        -- red under: applyLoops playing a loop for None
        assertEqual(g:__count("Play"), 0)
    end
end)

test("text style: each effect plays its own loop with the speed, fade and height set", function()
    local frame = B.new({})
    local _, am = dressed(text({ anim = "pulse", animSpeed = 2, animIntensity = 0.4, animBounce = 5 }), false, frame)
    assertEqual(am.pulseGroup:__count("Play"), 1)
    assertEqual(am.blinkGroup:__count("Play") + am.bounceGroup:__count("Play"), 0)
    assertEqual(am.pulse:__last("SetToAlpha")[1], 0.4)
    assertEqual(am.pulse:__last("SetDuration")[1], 1, "half a cycle each way")
    _, am = dressed(text({ anim = "blink", animSpeed = 2, animIntensity = 0.4 }), false, frame)
    -- red under: the loop keyed to the wrong group
    assertEqual(am.blinkGroup:__count("Play"), 1)
    assertEqual(am.blink:__last("SetStartDelay")[1], 1)
    assertEqual(am.blink:__last("SetEndDelay")[1], 1)
    assertTrue(am.pulseGroup:__lastSeq("Stop") > am.pulseGroup:__lastSeq("Play"), "the old loop stopped")
    _, am = dressed(text({ anim = "bounce", animSpeed = 2, animBounce = 5 }), false, frame)
    assertEqual(am.bounceGroup:__count("Play"), 1)
    assertEqual(am.bounce:__joined("SetOffset"), "0,5")
end)

-- ── the icon ───────────────────────────────────────────────────────────────────────────────────

test("text style: an icon on the left sits on the animated frame and the text area starts after it and its gap", function()
    local frame, am = dressed(text({ height = 16, icon = "LEFT", iconSize = 0, iconGap = 3 }), true)
    assertEqual(am.icon:__joined("SetSize"), "16,16", "size 0 is the line's height")
    local p = am.icon:__last("SetPoint")
    assertEqual(p[1], "LEFT"); assertTrue(p[2] == am.anim)
    local a = am.area:__calls("SetPoint")
    -- red under: the text area ignoring the icon (the line drawn under it)
    assertEqual(a[1][1], "TOPLEFT"); assertEqual(a[1][4], 16 + 3)
    assertEqual(a[2][1], "BOTTOMRIGHT"); assertEqual(a[2][4], 0)
    assertTrue(frame:__last("SetIcon")[1] == am.icon)
end)

test("text style: an icon on the right insets the area's right edge; none hides it and binds nothing", function()
    local _, am = dressed(text({ icon = "RIGHT", iconSize = 12, iconGap = 2 }), true)
    local a = am.area:__calls("SetPoint")
    assertEqual(a[1][4], 0); assertEqual(a[2][4], -(12 + 2))
    local frame
    frame, am = dressed(text({ icon = "NONE" }), true)
    assertFalse(am.icon:IsShown())
    assertFalse(am.iconBorder:IsShown())
    assertTrue(am.area:__last("SetAllPoints")[1] == am.anim)
    -- red under: Bind binding the icon whatever its setting
    assertEqual(frame:__count("SetIcon"), 0)
end)

-- ── the template ───────────────────────────────────────────────────────────────────────────────

test("text style: a refused stored template draws the default one and logs it once", function()
    local NS = E()
    local lines = {}
    local debug = NS.Debug
    NS.Debug = function(tag, fmt, ...)
        local n = #lines
        lines[n + 1] = tag .. ":" .. fmt:format(...)
    end
    local _, am = dressed(text({ template = "$broken$" }))
    dressed(text({ template = "$broken$" }))
    NS.Debug = debug
    -- red under: Compiled handing the refusal to the dresser (a raise, or an element with no pieces)
    assertEqual(am.shape, NS.TextTemplate.Compile(NS.CONTAINER_TEMPLATE.text.template).shape)
    assertEqual(#lines, 1, "said once: " .. table.concat(lines, " | "))
end)

test("text style: a template edit that keeps the shape re-dresses the same strings; a new shape swaps chains", function()
    local made = {}
    local frame = B.new(made)
    local _, am = dressed(text({ template = "$spellname$ - $stacks$" }), false, frame, made)
    local chain1, first = am.chain, am.piece1
    dressed(text({ template = "$spellname$ ~ $stacks$" }), false, frame, made)
    -- red under: useChain rebuilding on every template change (a string per dress, never freed)
    assertTrue(am.chain == chain1 and am.piece1 == first, "same shape, same strings")
    assertEqual(am.piece2:__last("SetText")[1], " ~ ")
    dressed(text({ template = "$spellname$" }), false, frame, made)
    -- red under: useChain re-dressing old strings for a new shape (a stale binding writes into one)
    assertTrue(am.chain ~= chain1, "a new shape, a new chain")
    assertFalse(chain1:IsShown(), "the old chain is hidden")
    assertEqual(am.pieceCount, 1)
    assertNil(am.piece2, "the old shape's keys are gone")
    dressed(text({ template = "$spellname$ - $stacks$" }), false, frame, made)
    assertTrue(am.chain == chain1 and chain1:IsShown(), "back to the first shape: its chain again")
end)

test("text style: the structure key carries the template's shape, so a live shape change gets new buttons", function()
    local NS = E()
    local S = NS.Style
    assertEqual(S.StructureKey(cfg({ style = "bars" })), "bars")
    assertEqual(S.StructureKey(text({ template = "$spellname$" })), "text:name")
    -- red under: StructureKey leaving the shape out (Container:Apply would restyle, not rebuild)
    assertEqual(S.StructureKey(text({ template = "$spellname$[ x$stacks$]" })), "text:name|stacks")
    assertEqual(S.StructureKey(text({ template = "$spellname$[ y$stacks$]" })), "text:name|stacks", "same shape")
end)

test("text style: bars, then text, then bars again keeps each style's regions, hidden while the other draws", function()
    -- A kit frame, not a builder: the bar's build does frame-level arithmetic a recorder cannot answer.
    local NS, m = E()
    local frame = m.__stubFrame()
    local c = cfg({ style = "bars" })
    NS.Style.Element(frame, c, false)
    local bars = frame.__am
    bars.bar:Show()
    c.style = "text"
    NS.Style.Element(frame, c, false)
    local am = frame.__am
    assertEqual(am.style, "text")
    assertFalse(bars.bar:IsShown(), "the bar is hidden")
    am.clip:Show()
    c.style = "bars"
    NS.Style.Element(frame, c, false)
    assertTrue(frame.__am == bars)
    -- red under: RegionsFor not hiding the text regions under the bar
    assertFalse(am.clip:IsShown())
end)

-- ── the preview ────────────────────────────────────────────────────────────────────────────────

--- Fill a dressed placeholder with `aura` and answer each piece's text.
local function filled(over, aura)
    local NS = E()
    local c = text(over)
    local frame, am = dressed(c, false)
    NS.Style.Text.FillPreview(frame, aura, c)
    local out = {}
    for i, fs in ipairs(pieces(am)) do out[i] = (fs:__last("SetText") or {})[1] end
    return out, am
end

local AURA = { name = "Bloodlust", icon = 1, remaining = 28, duration = 40, stacks = 3, dispel = "Magic" }

test("text style: a placeholder fills each piece as the engine would", function()
    local NS = E()
    local out = filled({ template = "$spellname$[ x$stacks$][ ($dispeltype$)][ - $remainingduration$ / $maxduration$ ($remainingpercent$)]" }, AURA)
    assertEqual(out[1], "Bloodlust")
    -- red under: the stacks piece filled without its bracket text
    assertEqual(out[2], " x3")
    assertEqual(out[3], " (" .. NS.L["Magic"] .. ")")
    -- tests/text_apis.lua's formatter writes whole seconds as "<n>s"
    assertEqual(out[4], " - 28s / 40s (70%)")
end)

test("text style: a placeholder hides a single stack, a missing dispel type and a timeless duration with their bracket text", function()
    local aura = { name = "Well Fed", icon = 1, remaining = 0, duration = 0, stacks = 1 }
    local out = filled({ template = "$spellname$[ x$stacks$][ ($dispeltype$)][ - $remainingduration$]" }, aura)
    -- red under: PREVIEW.stacks writing "1" (the engine's rule formatter writes nothing below 2)
    assertEqual(out[2], "")
    assertEqual(out[3], "")
    assertEqual(out[4], "", "a timeless aura writes nothing, bracket text included")
end)

test("text style: a placeholder running out takes the running-out color on its duration piece only", function()
    local red = { r = 1, g = 0, b = 0, a = 1 }
    local _, am = filled({ template = "$spellname$[ - $remainingduration$]", expiringColorOn = true,
        expiringThreshold = 30, expiringColor = red }, AURA)
    -- red under: previewDuration ignoring the threshold
    assertEqual(am.piece2:__joined("SetTextColor"), "1,0,0,1")
    assertEqual(am.piece1:__count("SetTextColor"), 1, "the name keeps the font color the dress set")
end)
```

In `tests/run.lua` add `"test_style_text",` after `"test_style_icons",`. In `tests/test_loadorder.lua`'s
`pairs_`, after `{ "modules/Style.lua", "modules/Style_Bars.lua" },` add:

```lua
        { "modules/Style.lua", "modules/Style_Text.lua" },
        { "modules/TextTemplate.lua", "modules/Style_Text.lua" },
```

- [ ] **Step 2: Run it and see it fail**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua 2>&1 | grep -A3 -E "text style:|loadorder:" | head -30`
Expected: FAIL — `attempt to index field '__am' (a nil value)` on the first `text style:` cases
(`Style.Styler` answers nil, so nothing dresses a text element), and the load-order case
`modules/Style.lua must load before modules/Style_Text.lua`.

- [ ] **Step 3: Implement**

Create `modules/Style_Text.lua`:

```lua
local _, NS = ...

-- modules/Style_Text.lua — dressing one aura as a LINE OF TEXT (issue #2).
--
--     clip ─ anim ─┬─ [icon]      the element, clipped: a bounce never draws over a neighbor
--                  └─ area ─ chain ─ [Power Word: Fortitude][ x3][ - 12s]
--                                     one font string per template piece
--
-- A LINE IS A CHAIN. No addon code can read a secret aura value, so none can build the line as one
-- string: the engine writes each field into a font string of ours, one per template piece
-- (modules/TextTemplate.lua), and plain text between fields is a static font string. Every piece is
-- single-anchored and auto-sized, so the client sizes an engine-written piece to its secret text and
-- the next piece anchors to its edge (the 2026-09-18 probes, docs/midnight-quirks.md). Their widths
-- are never readable, which is why a multi-piece line cannot be centered.
--
-- THREE NESTED FRAMES. `clip` covers the element and clips its children; `anim` fills it and carries
-- the looping animations, so the icon and the text move and fade together; `area` is the text's box
-- (the element less the icon and its gap), clipped again, so a long line is cut at its box and never
-- runs under the icon. No Scale animation: glyphs scaled past the boxes they are anchored by overlap.
--
-- ONE CHAIN PER SHAPE. A chain frame holds the font strings of one piece-kind sequence
-- ("name|stacks|duration", TT's `shape`). A template edit that keeps the shape re-dresses the same
-- strings, each still bound to its own engine field; a new shape hides the current chain (with it
-- every string the engine may still write into) and builds or re-shows the one for the new shape.
-- Live buttons also get a fresh engine when the shape changes (modules/Container.lua's structure key,
-- Style.StructureKey), so no stale binding outlives it; the chains are what a PREVIEW frame, reused
-- across templates, relies on.
--
-- ANIMATIONS ARE SET UP AT DRESS TIME ONLY. In combat every call on a button's objects is refused
-- (AnimationGroup:Play/Stop included), but an animation started at dress time keeps running through
-- combat. All three loops are built once with the regions; a dress configures them, stops them all
-- and plays the chosen one. A change made in combat waits for the deferred restyle
-- (ContainerManager.MustDefer), like every other setting.
--
-- LOAD-BEARING POSITION: after modules/Style.lua, whose NS.Style this decorates at file scope, and
-- after modules/TextTemplate.lua, taken below as a file-scope upvalue.

local Style = NS.Style
local C = NS.Constants
local D = NS.CONTAINER_TEMPLATE.text
local TT = NS.TextTemplate
local L = NS.L

Style.Text = Style.Text or {}
local Text = Style.Text

-- The refresh a blinking run needs (Compat.CreateDurationBinding): four updates per blink step.
local BLINK_INTERVAL = 0.1

--- "piece1", "piece2", ...: the keys a chain's font strings sit under on `frame.__am`, built once
--- each, so a dress indexes them without building a string.
local PIECE = setmetatable({}, { __index = function(t, i)
    local key = "piece" .. i
    t[i] = key
    return key
end })

local function number(v, default)
    return tonumber(v) or default
end

-- ---------------------------------------------------------------------------
-- Regions
-- ---------------------------------------------------------------------------

--- The three loops, built once on `anim`: a pulse (alpha down and back), a blink (alpha off, a hold,
--- on) and a bounce (up and back). A dress sets their timing and plays at most one (applyLoops).
local function buildLoops(am)
    am.pulseGroup = am.anim:CreateAnimationGroup()
    am.pulseGroup:SetLooping("BOUNCE")
    am.pulse = am.pulseGroup:CreateAnimation("Alpha")
    am.pulse:SetFromAlpha(1)
    am.pulse:SetSmoothing("IN_OUT")

    am.blinkGroup = am.anim:CreateAnimationGroup()
    am.blinkGroup:SetLooping("REPEAT")
    am.blink = am.blinkGroup:CreateAnimation("Alpha")
    am.blink:SetFromAlpha(1)
    am.blink:SetDuration(0.01)

    am.bounceGroup = am.anim:CreateAnimationGroup()
    am.bounceGroup:SetLooping("BOUNCE")
    am.bounce = am.bounceGroup:CreateAnimation("Translation")
    am.bounce:SetSmoothing("IN_OUT")
end

--- Build the regions once (Style.RegionsFor). Every region is a descendant of the button, tagged
--- "text"; the font strings are built per shape (useChain).
local function build(frame)
    local am = {}
    frame.__am = am
    am.style = "text"
    frame.__amChains = frame.__amChains or {}

    am.clip = CreateFrame("Frame", nil, frame)
    am.clip:SetAllPoints(frame)
    am.clip:SetClipsChildren(true)
    am.anim = CreateFrame("Frame", nil, am.clip)
    am.anim:SetAllPoints(am.clip)

    am.icon = am.anim:CreateTexture(nil, "ARTWORK")
    am.iconBorder = CreateFrame("Frame", nil, am.anim, "BackdropTemplate")
    am.area = CreateFrame("Frame", nil, am.anim)
    am.area:SetClipsChildren(true)

    buildLoops(am)
    am.pieceCount = 0
    return am
end

--- Put the current chain away: hidden, with its font strings, under its shape.
local function stashChain(frame, am)
    if not am.chain then return end
    local saved = { chain = am.chain, count = am.pieceCount }
    for i = 1, am.pieceCount do
        saved[i] = am[PIECE[i]]
        am[PIECE[i]] = nil
    end
    am.chain:Hide()
    frame.__amChains[am.shape] = saved
end

--- A new chain frame in the text area with `count` single-line font strings.
local function newChain(am, count)
    local chain = CreateFrame("Frame", nil, am.area)
    chain:SetAllPoints(am.area)
    local saved = { chain = chain, count = count }
    for i = 1, count do
        local fs = chain:CreateFontString(nil, "OVERLAY")
        fs:SetWordWrap(false)
        saved[i] = fs
    end
    return saved
end

--- Make `compiled`'s shape the element's chain: unchanged when it already is, else the current chain
--- is put away and the one for the new shape is taken back, or built.
local function useChain(frame, am, compiled)
    if am.chain and am.shape == compiled.shape then return end
    stashChain(frame, am)
    local pieces = compiled.pieces
    local count = #pieces
    local saved = frame.__amChains[compiled.shape] or newChain(am, count)
    frame.__amChains[compiled.shape] = nil
    am.chain, am.pieceCount, am.shape = saved.chain, saved.count, compiled.shape
    for i = 1, saved.count do am[PIECE[i]] = saved[i] end
    am.chain:Show()
end

-- ---------------------------------------------------------------------------
-- Layout
-- ---------------------------------------------------------------------------

--- The icon at `pos` ("LEFT" | "RIGHT") of the animated frame, and the text area beside it; with no
--- icon the area is the whole element.
local function layoutIconAndArea(am, s, h)
    local pos = s.icon or D.icon
    am.icon:ClearAllPoints()
    am.area:ClearAllPoints()
    if pos ~= "LEFT" and pos ~= "RIGHT" then
        am.icon:Hide()
        am.iconBorder:Hide()
        am.area:SetAllPoints(am.anim)
        return
    end
    local size = Style.IconSizeFor(s, D, h)
    Style.LayoutIcon(am.anim, am, s, D, pos, size)
    local inset = size + number(s.iconGap, D.iconGap)
    am.area:SetPoint("TOPLEFT", am.anim, "TOPLEFT", pos == "LEFT" and inset or 0, 0)
    am.area:SetPoint("BOTTOMRIGHT", am.anim, "BOTTOMRIGHT", pos == "RIGHT" and -inset or 0, 0)
end

-- The anchor-point prefix for each vertical justify: TOPLEFT / LEFT / BOTTOMLEFT and the right-hand
-- equivalents.
local V_PREFIX = { TOP = "TOP", MIDDLE = "", BOTTOM = "BOTTOM" }

--- The horizontal justify the chain is laid out with: CENTER only for a one-piece template, whose
--- width the client sizes and centers itself; any longer chain lines up Left (its width is never
--- readable, so nothing can center it).
function Text.JustifyFor(s, compiled)
    local j = s.justifyH or D.justifyH
    if j == "CENTER" and not compiled.single then return "LEFT" end
    return j
end

--- The anchor point `side` ("LEFT" | "CENTER" | "RIGHT") names at vertical prefix `v`.
local function pointAt(v, side)
    if side == "CENTER" then return v ~= "" and v or "CENTER" end
    return v .. side
end

--- Anchor the chain in the text area: the head piece at the justified edge, nudged by x/y, and each
--- next piece against the previous one's far edge (LEFT to the previous RIGHT, or the mirror for a
--- Right-justified line, laid from the last piece back).
local function layoutChain(am, s, compiled)
    local side = Text.JustifyFor(s, compiled)
    local v = V_PREFIX[s.justifyV or D.justifyV] or ""
    local x, y = number(s.x, D.x), number(s.y, D.y)
    local n = am.pieceCount
    local first, last, step, near, far = 1, n, 1, "LEFT", "RIGHT"
    if side == "RIGHT" then first, last, step, near, far = n, 1, -1, "RIGHT", "LEFT" end
    local head = am[PIECE[first]]
    head:ClearAllPoints()
    head:SetPoint(pointAt(v, side), am.area, pointAt(v, side), x, y)
    for i = first + step, last, step do
        local fs = am[PIECE[i]]
        fs:ClearAllPoints()
        fs:SetPoint(pointAt(v, near), am[PIECE[i - step]], pointAt(v, far), 0, 0)
    end
end

--- Every piece in the line's font; a literal also takes its text now, since nothing else writes it.
local function dressPieces(am, s, compiled)
    local font = s.font or D.font
    for i, piece in ipairs(compiled.pieces) do
        local fs = am[PIECE[i]]
        Style.ApplyFont(fs, font, D.font)
        if piece.kind == "literal" then fs:SetText(piece.text) end
        fs:Show()
    end
end

-- The loops, each the group a dress plays for its `anim` value.
local LOOPS = { { "pulse", "pulseGroup" }, { "blink", "blinkGroup" }, { "bounce", "bounceGroup" } }

--- Time the three loops from the settings, stop them all, and play the chosen one. Calls on a live
--- button's objects go through Style.Bind, so a refusal costs the call and is logged, never the dress.
local function applyLoops(am, s)
    local half = number(s.animSpeed, D.animSpeed) / 2
    local low = number(s.animIntensity, D.animIntensity)
    am.pulse:SetToAlpha(low)
    am.pulse:SetDuration(half)
    am.blink:SetToAlpha(low)
    am.blink:SetStartDelay(half)
    am.blink:SetEndDelay(half)
    am.bounce:SetOffset(0, number(s.animBounce, D.animBounce))
    am.bounce:SetDuration(half)
    local want = s.anim or D.anim
    for _, loop in ipairs(LOOPS) do
        local group = am[loop[2]]
        Style.Bind(group, "Stop")
        if loop[1] == want then Style.Bind(group, "Play") end
    end
end

-- ---------------------------------------------------------------------------
-- The engine
-- ---------------------------------------------------------------------------

local stackOptions, dispelOptions = {}, {}

--- SetApplicationCount's options for a stacks piece: a rule formatter that writes nothing below two
--- stacks and the piece's format from two up. Built once per format string.
local function stackOptionsFor(piece)
    local opts = stackOptions[piece.format]
    if not opts then
        opts = { formatter = NS.Compat.CreateRuleFormatter({
            { threshold = 0, format = "" }, { threshold = 2, format = piece.format } }) }
        stackOptions[piece.format] = opts
    end
    return opts
end

--- SetDispelTypeText's options for a dispel piece: every type in C.TEXT_DISPEL_TYPES mapped to its
--- localized name inside the piece's bracket text, on harmful and helpful auras alike, nothing for an
--- aura with no type. Built once per bracket text.
local function dispelOptionsFor(piece)
    local key = piece.pre .. "\0" .. piece.post
    local opts = dispelOptions[key]
    if not opts then
        local map = {}
        for _, t in ipairs(C.TEXT_DISPEL_TYPES) do map[t] = piece.pre .. L[C.TEXT_DISPEL_LABELS[t]] .. piece.post end
        opts = { showWhenHarmful = true, showWhenHelpful = true, showWithoutDispelType = false,
            customDispelTextMap = map }
        dispelOptions[key] = opts
    end
    return opts
end

--- The button's prebuilt duration binding, plain or with the blink's refresh, built on first use and
--- kept on the element (a binding is the button's own, never shared).
local function bindingFor(am, blink)
    local key = blink and "blinkBinding" or "binding"
    if am[key] == nil then am[key] = NS.Compat.CreateDurationBinding(blink and BLINK_INTERVAL or nil) end
    return am[key]
end

-- How each kind of piece is handed to the engine. A literal is bound to nothing.
local BINDERS = {
    name = function(frame, fs) Style.Bind(frame, "SetSpellName", fs) end,
    stacks = function(frame, fs, piece) Style.Bind(frame, "SetApplicationCount", fs, stackOptionsFor(piece)) end,
    dispel = function(frame, fs, piece) Style.Bind(frame, "SetDispelTypeText", fs, dispelOptionsFor(piece)) end,
    duration = function(frame, fs, piece, s, am)
        local font = s.font or D.font
        Style.BindDurationFormat(frame, fs, Style.DurationTextFormat(piece, s.timeFormat),
            bindingFor(am, s.expiringBlink and true or false), s, D, font.fontColor)
    end,
}

--- Hand the pieces and the icon to the engine, each through its own binding (Style.Bind).
function Text.Bind(frame, am, cfg, s, compiled)
    if (s.icon or D.icon) ~= "NONE" then Style.Bind(frame, "SetIcon", am.icon) end
    for i, piece in ipairs(compiled.pieces) do
        local bind = BINDERS[piece.kind]
        if bind then bind(frame, am[PIECE[i]], piece, s, am) end
    end
    Style.ApplyBehavior(frame, cfg)
end

-- ---------------------------------------------------------------------------
-- The dress
-- ---------------------------------------------------------------------------

local warned = {}

--- The compiled template this element draws: the stored one, or the default when the stored one is
--- refused, which is said once per template in the debug log and never raised.
function Text.Compiled(s)
    local compiled, fellBack = TT.ForDraw(s.template)
    if fellBack and not warned[tostring(s.template)] then
        warned[tostring(s.template)] = true
        if NS.Debug then NS.Debug("Style", "text template refused, drawing the default: %s", s.template) end
    end
    return compiled
end

function Text.Apply(frame, cfg, engine)
    local s = cfg.text or {}
    local w, h = Style.ElementSize(cfg)
    local am = Style.RegionsFor(frame, "text", build)
    if engine then Style.ClearAdditiveBindings(frame) end

    frame:SetSize(w, h)
    local compiled = Text.Compiled(s)
    useChain(frame, am, compiled)
    layoutIconAndArea(am, s, h)
    dressPieces(am, s, compiled)
    layoutChain(am, s, compiled)
    applyLoops(am, s)

    if engine then Text.Bind(frame, am, cfg, s, compiled) end
end

-- ---------------------------------------------------------------------------
-- The preview
-- ---------------------------------------------------------------------------

-- The placeholder being filled, handed to componentText through upvalues (gsub passes it only the
-- match).
local fillAura, fillSettings, fillPiece, fillIndex

--- One duration component of a placeholder, as the engine would write it: a time through the look's
--- formatter (Style.PreviewSeconds), a percent as "NN%".
local VALUES = {
    RemainingDuration = function(a) return a.remaining end,
    TotalDuration = function(a) return a.duration end,
    ElapsedDuration = function(a) return a.duration - a.remaining end,
    RemainingPercent = function(a) return math.floor(a.remaining / a.duration * 100) end,
    ElapsedPercent = function(a) return math.floor((a.duration - a.remaining) / a.duration * 100) end,
}
local function componentText()
    fillIndex = fillIndex + 1
    local c = fillPiece.components[fillIndex]
    local value = VALUES[c.prop](fillAura)
    if c.fmt == "percent" then return ("%d%%"):format(value) end
    return Style.PreviewSeconds(value, fillSettings.timeFormat)
end

--- A placeholder's duration run: the format with each {} filled, nothing for a timeless aura (the
--- prebuilt binding's zero-duration text), and the running-out color below the threshold.
local function previewDuration(fs, piece, aura, s)
    if aura.duration <= 0 then
        fs:SetText("")
        return
    end
    fillAura, fillSettings, fillPiece, fillIndex = aura, s, piece, 0
    fs:SetText((piece.format:gsub("{}", componentText)))
    fillAura, fillSettings, fillPiece = nil, nil, nil
    if (s.expiringColorOn or s.expiringBlink) and aura.remaining < number(s.expiringThreshold, D.expiringThreshold) then
        fs:SetTextColor(Style.Color(s.expiringColorOn and s.expiringColor or (s.font or D.font).fontColor, false))
    end
end

-- How each kind of piece is filled from a placeholder aura, as the engine would fill it.
local PREVIEW = {
    name = function(fs, _, aura) fs:SetText(aura.name) end,
    stacks = function(fs, piece, aura)
        fs:SetText(aura.stacks >= 2 and piece.format:format(aura.stacks) or "")
    end,
    dispel = function(fs, piece, aura)
        local label = aura.dispel and C.TEXT_DISPEL_LABELS[aura.dispel]
        fs:SetText(label and (piece.pre .. L[label] .. piece.post) or "")
    end,
    duration = previewDuration,
}

--- Fill a PREVIEW element with placeholder values (modules/Preview.lua), from the same compiled
--- pieces the live dress binds, so the preview and a live button cannot differ in structure.
function Text.FillPreview(frame, aura, cfg)
    local am = frame.__am
    if not (am and am.style == "text") then return end
    local s = (cfg and cfg.text) or {}
    local compiled = Text.Compiled(s)
    am.icon:SetTexture(aura.icon)
    for i, piece in ipairs(compiled.pieces) do
        local fill = PREVIEW[piece.kind]
        if fill then fill(am[PIECE[i]], piece, aura, s) end
    end
end
```

In `modules/Style.lua`, insert directly above `--- The styler that dresses \`cfg\`'s elements:`:

```lua
--- What a live engine is rebuilt for when it changes (modules/Container.lua's structure key): the
--- style, and for the text style the template's shape (modules/Style_Text.lua). A new shape then
--- gets new buttons, so no engine binding is left pointing into the old shape's font strings.
function Style.StructureKey(cfg)
    local key = Style.StyleKey(cfg)
    if key ~= "text" or not Style.Text then return key end
    return "text:" .. Style.Text.Compiled(cfg.text or {}).shape
end
```

`AuraMaster.toc` — the Style group becomes:

```text
# LOAD-BEARING: Style before Style_Bars, Style_Icons and Style_Text, which decorate NS.Style at file
# scope.
modules\Style.lua
modules\Style_Bars.lua
modules\Style_Icons.lua
modules\Style_Text.lua
```

- [ ] **Step 4: Run it and see it pass**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua 2>&1 | grep -A3 -E "text style:|loadorder:|FAIL"`
Expected: every `text style:` case PASSES (24), and `loadorder: every addon file in the TOC is
covered …` stays green (`Style_Text` is named in the two-line LOAD-BEARING note).
Run lizard on the new file: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lizard -l lua modules/Style_Text.lua modules/TextTemplate.lua modules/Style.lua` — every function at CCN ≤ 15.

- [ ] **Step 5: Checkpoint — run the green gate**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua && /home/tushar/.claude/wow-addon/bin/ka0s-bounded luacheck .`
Expected: 0 failed; `0 warnings / 0 errors`. Update the ledger. Do not commit.

---

### Task 9: Preview dispatch, and the text shape in the engine's structure key

**Files:**
- Modify: `modules/Preview.lua:7-9` (header), `:109-112` (`Preview.Show`'s style and styler)
- Modify: `modules/Container.lua:359` (the structure key)
- Test: `tests/test_preview.lua` (append), `tests/test_container.lua` (insert before `-- ── weapon enchants and engine refusals`, line 360)

**Interfaces:**
- Consumes: Task 7's `Style.StyleKey`, `Style.Styler`; Task 8's `Style.StructureKey`, `Style.Text.FillPreview`.
- Produces: `Preview.Show` keeps one pool per `Style.StyleKey(cfg)` (`container.previewPools.text` for a text container) and fills through `Style.Styler(cfg).FillPreview`; a live container's structure key is `FilterCompiler.StructureKey(plan) .. ":" .. Style.StructureKey(cfg)`, so a new template shape rebuilds the engine and a same-shape edit restyles it.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_preview.lua`:

```lua
test("preview: a text container's placeholders read its template, each bracket's text hidden with its value", function()
    local B = dofile("tests/region_builder.lua")
    local NS2, m2 = fresh({ before = dofile("tests/text_apis.lua") })
    local c = cfg({ style = "text", text = { template = "$spellname$[ x$stacks$][ - $remainingduration$]" } }, NS2)
    local made = {}
    local k = container(c)
    k.previewFactory = function() return B.new(made) end
    B.during(m2, made, function() NS2.Preview.Show(k) end)
    local lines = {}
    -- red under: Preview.Show handing a text container the bars styler and pool
    for i, f in ipairs(k.previewPools.text.active) do
        local am = f.__am
        local parts = {}
        for j = 1, am.pieceCount do parts[j] = (am["piece" .. j]:__last("SetText") or {})[1] or "" end
        lines[i] = table.concat(parts)
    end
    -- tests/text_apis.lua's formatter writes whole seconds as "<n>s"
    assertEqual(lines[1], "Power Word: Fortitude - 3540s")
    assertEqual(lines[4], "Ignore Pain x3 - 11s", "stacks from two up, with their bracket text")
    -- red under: the duration piece writing " - " for a timeless placeholder
    assertEqual(lines[5], "Well Fed", "a timeless aura: the name alone")
end)
```

Insert into `tests/test_container.lua` before `-- ── weapon enchants and engine refusals ───…`:

```lua
test("container: a text template of a new shape rebuilds the engine; one of the same shape restyles it", function()
    local NS, mocks = fresh()
    local inst = NS.ContainerManager.instances[1]
    assertTrue(NS.SetByPath("container.style", "text", 1))
    mocks.__fireTimers()
    local e = inst.engine
    assertTrue(NS.SetByPath("container.text.template", "$spellname$[ y$stacks$][ ~ $remainingduration$]", 1))
    mocks.__fireTimers()
    assertTrue(inst.engine == e, "the same shape: the same engine, restyled")
    assertTrue(NS.SetByPath("container.text.template", "$spellname$", 1))
    mocks.__fireTimers()
    -- red under: the structure key without Style.StructureKey (a stale binding writes into a hidden string)
    assertTrue(inst.engine ~= e, "a new shape gets new buttons")
    assertFalse(e.__enabled)
end)
```

- [ ] **Step 2: Run them and see them fail**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua 2>&1 | grep -A3 -E "a text container's placeholders|a text template of a new shape"`
Expected: FAIL — `attempt to index field 'text' (a nil value)` (Preview.Show pooled the text
container under `bars` and dressed it with the bar styler), and "a new shape gets new buttons"
(`inst.engine == e`: the structure key still reads only `cfg.style`).

- [ ] **Step 3: Implement**

`modules/Preview.lua` — in `Preview.Show` replace

```lua
    local style = (cfg.style == "icons") and "icons" or "bars"
    local pool = poolFor(container, style)
    local count = placeholderCount(cfg)
    local styler = (style == "icons") and NS.Style.Icons or NS.Style.Bars
```

with

```lua
    local style = NS.Style.StyleKey(cfg)
    local pool = poolFor(container, style)
    local count = placeholderCount(cfg)
    local styler = NS.Style.Styler(cfg)
```

and in the file header "Everything a player changes on the Bars or Icons page" → "Everything a
player changes on the Bars, Icons or Text page".

`modules/Container.lua` — in `ContainerClass:Apply` replace

```lua
        local structure = NS.FilterCompiler.StructureKey(plan) .. ":" .. tostring(cfg.style)
```

with

```lua
        -- The style, and for a text container its template's shape (Style.StructureKey): a new
        -- shape gets new buttons, so no engine binding is left in the old shape's font strings.
        local structure = NS.FilterCompiler.StructureKey(plan) .. ":" .. NS.Style.StructureKey(cfg)
```

- [ ] **Step 4: Run them and see them pass**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua 2>&1 | grep -A3 -E "preview:|container:|FAIL"`
Expected: every `preview:` and `container:` case PASSES, the existing "switching style rebuilds the
engine even when the filter plan keeps its shape" included. Re-point drifted citations with
`/tmp/citefix.py` (`modules/Preview.lua:104` in docs/data-flow.md).

- [ ] **Step 5: Checkpoint — run the green gate**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua && /home/tushar/.claude/wow-addon/bin/ka0s-bounded luacheck .`
Expected: 0 failed; `0 warnings / 0 errors`. Update the ledger. Do not commit.

---

### Task 10: The fourth starter, "Player cooldowns", and `Cat.StatesShowing` (spec §7.1)

**Files:**
- Modify: `defaults/Categories.lua` (append `Cat.StatesShowing`)
- Modify: `defaults/Profile.lua` (the starter comment, lines 209–211; a fourth entry in `NS.STARTER_CONTAINERS`)
- Test: `tests/test_defaults.lua`, `tests/test_database.lua`, `tests/test_filtercompiler.lua` (append one case each); the fallout edits listed in Step 4b

**Interfaces:**
- Consumes: `Cat.DefaultStates()`, `Cat.HELPFUL`; Task 8's text styler (the starter draws as text).
- Produces: `Cat.StatesShowing(keys) -> { [categoryKey] = "show"|"hide" }` (every `Cat.HELPFUL` key `"hide"` but `keys`, every `Cat.HARMFUL` key `"show"`); a fresh profile seeds **four** containers, ids 1–4, the fourth `{ name = "Player cooldowns", style = "text", unit = "player", auraType = "HELPFUL" }`. A new container on a fresh profile is therefore id **5**, "Container 5", staggered four steps (−120) down. Task 11's render coverage finds this container as its text rig.

**Spec correction:** spec §7.1 says the starter-count assertions "need no edits, only re-checking".
Measured: adding the fourth starter turns **35 cases red** across 11 suites — each hard-codes 3
starters, the next id 4, or an order `1,2,3`. Step 4b is that fallout, case by case.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_defaults.lua`:

```lua
test("defaults: StatesShowing hides every buff category but the ones named, and leaves the debuff ones at Show", function()
    local states = Cat.StatesShowing({ "offensiveCDs", "defensives" })
    for _, def in ipairs(Cat.HELPFUL) do
        local want = (def.key == "offensiveCDs" or def.key == "defensives") and "show" or "hide"
        -- red under: StatesShowing leaving a token or flag category (or Uncategorized) at Show
        assertEqual(states[def.key], want, def.key)
    end
    for _, def in ipairs(Cat.HARMFUL) do
        -- red under: StatesShowing hiding the debuff categories (a switch to debuffs starts all-hidden)
        assertEqual(states[def.key], "show", def.key)
    end
    assertTrue(Cat.StatesShowing({}) ~= Cat.StatesShowing({}), "a fresh table each call")
end)
```

Append to `tests/test_database.lua`:

```lua
test("database: a fresh profile seeds the Player cooldowns text container last, showing only two buff lists", function()
    local NS = fresh()
    local list = NS.Database.GetContainers()
    local n = #NS.STARTER_CONTAINERS
    assertEqual(#list, n)
    local c = list[n]
    -- red under: the starter list without its fourth entry, or seeded in another style
    assertEqual(c.name, "Player cooldowns")
    assertEqual(c.style, "text")
    assertEqual(c.unit, "player"); assertEqual(c.auraType, "HELPFUL")
    assertEqual(c.filter.categories.offensiveCDs, "show")
    assertEqual(c.filter.categories.defensives, "show")
    assertEqual(c.filter.categories.uncategorized, "hide")
    assertEqual(c.filter.categories.bigDefensive, "hide")
    assertEqual(c.text.template, NS.CONTAINER_TEMPLATE.text.template, "the rest is the template's")
end)
```

Append to `tests/test_filtercompiler.lua`:

```lua
-- ── the Player cooldowns starter (text style, spec 7.1) ───────────────────────────────────────

test("filter: the Player cooldowns starter draws one group per list it shows and no catch-all", function()
    local c = cfg({ filter = { categories = NS.Categories.StatesShowing({ "offensiveCDs", "defensives" }) } })
    local plan = FC.Compile(c)
    local labels = {}
    for i, g in ipairs(plan.groups) do labels[i] = g.label end
    -- red under: StatesShowing leaving Uncategorized at Show (its group draws every unlisted buff)
    assertEqual(#plan.groups, 2, table.concat(labels, ","))
    local ids = 0
    for _, g in ipairs(plan.groups) do
        assertTrue(g.candidateFilters and g.candidateFilters.includeSpellIDs ~= nil, g.label .. " is an id list")
        ids = ids + 1
    end
    assertEqual(ids, 2)
    -- A buff on neither list has no Show to draw it.
    assertEqual(FC.ExplainSpell(c, 999999).verdict, "hidden")
end)
```

- [ ] **Step 2: Run them and see them fail**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua 2>&1 | grep -A3 -E "StatesShowing|Player cooldowns"`
Expected: FAIL — `attempt to call field 'StatesShowing' (a nil value)` (all three), and the
database case `expected Player cooldowns, got Target debuffs (mine)`.

- [ ] **Step 3: Implement**

Append to `defaults/Categories.lua`:

```lua
--- The default states with every BUFF category Hidden except `keys`, which stay Show: a container
--- that draws only the buffs those categories claim (the "Player cooldowns" starter,
--- defaults/Profile.lua). That hides every Blizzard token and flag category, Weapon enchants and
--- Uncategorized too, so an unlisted buff has no Show left to draw it. The debuff categories keep
--- Show: inert on a buff container, and a later switch to debuffs does not start all-hidden.
--- @param keys table  category keys of Cat.HELPFUL
--- @return table
function Cat.StatesShowing(keys)
    local out = Cat.DefaultStates()
    for _, def in ipairs(Cat.HELPFUL) do out[def.key] = "hide" end
    for _, key in ipairs(keys) do out[key] = "show" end
    return out
end
```

`defaults/Profile.lua` — replace the comment above `NS.STARTER_CONTAINERS` with:

```lua
-- The starter containers a fresh profile is seeded with (core/Database.lua): a player-buff bar
-- stack, a player-debuff icon row, a target-debuff icon row, and a text list of the player's
-- offensive and defensive cooldowns — enough to show what the addon does without the player having
-- to build anything first. New profiles only: a profile already `seeded` gets none of them again.
```

and add, after the "Target debuffs (mine)" entry, before the list's closing `}`:

```lua
    {
        -- Only the Offensive cooldowns and Defensives lists draw: every other buff category is
        -- Hidden, Uncategorized included (defaults/Categories.lua's StatesShowing).
        name = "Player cooldowns", unit = "player", auraType = "HELPFUL", style = "text",
        filter = { castBy = "any", categories = NS.Categories.StatesShowing({ "offensiveCDs", "defensives" }) },
        position = { point = "CENTER", relativePoint = "CENTER", x = -260, y = -40 },
        layout = { axis = "vertical", growH = "right", growV = "down" },
    },
```

- [ ] **Step 4a: Run the three new cases and see them pass**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua 2>&1 | grep -A3 -E "StatesShowing|Player cooldowns"`
Expected: PASS.

- [ ] **Step 4b: Repair the fallout the fourth starter causes**

Run the suite; exactly these cases fail, each on a starter literal. Make these edits (every "old"
string occurs once inside the named case):

| File | Case (prefix) | Old | New |
|---|---|---|---|
| `tests/test_database.lua` | "string ids, dangling order entries and orphans" | `"3,1,7",` | `"3,1,4,7",` |
| `tests/test_database.lua` | "a string id in the stored order keeps its place" | `"2,1,3")` | `"2,1,3,4")` |
| `tests/test_database.lua` | "a deleted id is never handed out again" | `CM.Delete(3)` / `CM.Create({}), 4,` / `CM.Delete(4)` / `CM.Create({}), 5)` | `CM.Delete(4)` / `CM.Create({}), 5,` / `CM.Delete(5)` / `CM.Create({}), 6)` |
| `tests/test_bus.lua` | "a CONFIG_CHANGED the receiver cannot read" | `assertEqual(total(by), 3,` | `assertEqual(total(by), #NS.STARTER_CONTAINERS,` |
| `tests/test_slash.lua` | "/am new creates the described container" | `GetContainers(), 4)` | `GetContainers(), #NS2.STARTER_CONTAINERS + 1)` |
| `tests/test_slash.lua` | "/am new with a word it does not know" | `GetContainers(), 3)` | `GetContainers(), #NS2.STARTER_CONTAINERS)` |
| `tests/test_slash.lua` | "/am delete removes a container by id" | `GetContainers(), 2)` | `GetContainers(), #NS2.STARTER_CONTAINERS - 1)` |
| `tests/test_slash.lua` | "a name two containers share is refused" | `GetContainers(), 3, "both containers remain")` | `GetContainers(), #NS2.STARTER_CONTAINERS, "both containers remain")` |
| `tests/test_slash.lua` | "/am delete in combat refuses in gray" | `GetContainers(), 3)` | `GetContainers(), #NS2.STARTER_CONTAINERS)` |
| `tests/test_slash.lua` | `local function resetsUnderLockdown` | `GetContainers(), 3, "the shipped set is back")` | `GetContainers(), #NS2.STARTER_CONTAINERS, "the shipped set is back")` |
| `tests/test_slash.lua` | "/am new in combat refuses in gray" | `GetContainers(), 3)` | `GetContainers(), #NS2.STARTER_CONTAINERS)` |
| `tests/test_slash_verbs.lua` | "/am delete matches a name in any case" | `GetContainers(), 2)` | `GetContainers(), #NS2.STARTER_CONTAINERS - 1)` |
| `tests/test_optionssetup.lua` | "the Containers page's New button creates" | `GetContainers(), 4)` / `containerOrder[4])` | `GetContainers(), #NS2.STARTER_CONTAINERS + 1)` / `containerOrder[#NS2.STARTER_CONTAINERS + 1])` |
| `tests/test_optionssetup.lua` | "Reset all settings resets the active profile whole" | `"Player buffs\|Player debuffs\|Target debuffs (mine)",` | `"Player buffs\|Player debuffs\|Target debuffs (mine)\|Player cooldowns",` |
| `tests/test_optionssetup.lua` | "the Delete popup refuses in combat" | `GetContainers(), 3)` | `GetContainers(), #NS2.STARTER_CONTAINERS)` |
| `tests/test_options_descriptor.lua` | "Containers' picker is a plain dropdown" | `"1,2,3")` | `"1,2,3,4")` |
| `tests/test_pages_general.lua` | "Reset all settings asks first" | `GetContainers(), 4, "nothing reset yet")` | `GetContainers(), #NS.STARTER_CONTAINERS + 1, "nothing reset yet")` |
| `tests/test_pages_general.lua` | "Defaults restores the General rows" | `GetContainers(), 3, "and the registry is untouched")` | `GetContainers(), #NS.STARTER_CONTAINERS, "and the registry is untouched")` |
| `tests/test_pages_containers.lua` | "the tab body opens with the Container picker" | `"1,2,3")` | `"1,2,3,4")` |
| `tests/test_pages_containers.lua` | "New container creates a container and selects it" | `GetContainers(), 4)` / `containerOrder[4])` | `GetContainers(), #NS.STARTER_CONTAINERS + 1)` / `containerOrder[#NS.STARTER_CONTAINERS + 1])` |
| `tests/test_pages_containers.lua` | "Delete keeps the picker and New through both" | `ids(NS), "1,3")` / `"1,3", "the picker lists` | `ids(NS), "1,3,4")` / `"1,3,4", "the picker lists` |
| `tests/test_pages_containers.lua` | "New and Duplicate in combat refuse" | `GetContainers(), 3)` | `GetContainers(), #NS.STARTER_CONTAINERS)` |
| `tests/test_pages_containers.lua` | "Duplicate copies the selected container" | `GetContainers(), 4)` / `containerOrder[4], "the copy is selected")` | `GetContainers(), #NS.STARTER_CONTAINERS + 1)` / `containerOrder[#NS.STARTER_CONTAINERS + 1], "the copy is selected")` |
| `tests/test_pages_containers.lua` | "Delete asks first, naming the container" | `GetContainers(), 3, "nothing deleted` / `ids(NS), "1,3")` | `GetContainers(), #NS.STARTER_CONTAINERS, "nothing deleted` / `ids(NS), "1,3,4")` |
| `tests/test_pages_containers.lua` | "the copy block offers every other container" | `"2,3")` | `"2,3,4")` |
| `tests/test_pages_containers.lua` | "with one container the page offers" | `    NS.ContainerManager.Delete(3)` | `    NS.ContainerManager.Delete(3)` + a new line `    NS.ContainerManager.Delete(4)` |
| `tests/test_pages_layout.lua` | "the Container dropdown offers None" | `"0,1,3")` | `"0,1,3,4")` |
| `tests/test_debuglogsetup.lua` | "enabling logging writes the [Init] summary" | `", profile 'Default', 3 container(s)")` / `", profile 'Raid', 4 container(s)")` | `", profile 'Default', " .. #NS2.STARTER_CONTAINERS .. " container(s)")` / `", profile 'Raid', " .. #NS2.STARTER_CONTAINERS + 1 .. " container(s)")` |
| `tests/test_containermanager.lua` | "deleting a container leaves every other attachment" | `containerOrder, ","), "1,3")` | `containerOrder, ","), "1,3,4")` |

And in `tests/test_containermanager.lua`, a new container is id 5 in five more places. Run from the
repo root (CRLF-safe; each range is one helper or one case):

```bash
sed -i \
  -e '/^--- Create container 4 out of lockdown/,/^end\r\?$/{s/inst4/inst5/g;s/\[4\]/[5]/g;s/(id, 4)/(id, 5)/g;s/container 4/container 5/g;s/id 4 departs/id 5 departs/;s/seeds only 1-3/seeds only 1-4/}' \
  -e '/^test("manager: a parked id revived by a profile change in combat/,/^end)/{s/inst4/inst5/g;s/\[4\]/[5]/g;s/container 4/container 5/g;s/Anchor4/Anchor5/g}' \
  -e '/^test("manager: an id a later Create reuses after a profile reset/,/^end)/{s/inst4/inst5/g;s/\[4\]/[5]/g;s/(id, 4)/(id, 5)/g;s/Create({}), 4,/Create({}), 5,/;s/container 4/container 5/g;s/Anchor4/Anchor5/g;s/id 4 out/id 5 out/;s/FindContainer(4)/FindContainer(5)/g}' \
  -e '/^test("manager: a new container is named and staggered by its id/,/^end)/{s/assertEqual(id, 4)/assertEqual(id, 5)/;s/FindContainer(4)/FindContainer(5)/;s/"Container 4"/"Container 5"/;s/position.y, -90, "three steps down"/position.y, -120, "four steps down"/}' \
  tests/test_containermanager.lua
```

(The first range is the `departsUnderLockdown` helper, whose comment and body say "4"; the two
cases that call it need no edit.)

- [ ] **Step 4c: Run the whole suite and see it pass**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua 2>&1 | grep -A3 FAIL; /home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua 2>&1 | tail -1`
Expected: no FAIL; `… passed, 0 failed, 2 skipped …`. Re-point `defaults/Profile.lua` citations
(`NS.STARTER_CONTAINERS`) with `/tmp/citefix.py` if the docs case names one.

- [ ] **Step 5: Checkpoint — run the green gate**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua && /home/tushar/.claude/wow-addon/bin/ka0s-bounded luacheck .`
Expected: 0 failed; `0 warnings / 0 errors`. Update the ledger. Do not commit.

---

### Task 11: Render coverage walks the Text page

**Files:**
- Test: `tests/test_render_coverage.lua` — `env()` (lines 49–86), `recordersOf` (133–144), `signature` (164–183), `differing` (259–270), `GATES` (273–276), and one new case at the end

**Interfaces:**
- Consumes: the Text page's rows (Task 6), the text styler (Task 8), the "Player cooldowns" starter as the suite's text rig (Task 10: `rig("text")` takes the first container whose style is `"text"`), and `coverage = "engine-only"` on `container.text.expiringBlink`.
- Produces: the render-coverage gate over every Text row: each write must move what a live button records AND what the placeholders record, `expiringBlink` excepted (engine-only, and proven not to reach the preview).

- [ ] **Step 1: Write the failing test**

Append to `tests/test_render_coverage.lua`:

```lua
-- red under: any Style* path that reads a text leaf without drawing it, e.g. applyLoops dropping
-- the bounce's SetOffset, or dressPieces skipping the literal pieces' font
test("coverage: every Text row reaches a drawn region, on a live button and on the preview", function()
    local out, n = gaps("text")
    assertTrue(n >= 30, "the whole Text page was walked")
    assertEqual(table.concat(out, "; "), "", "rows that reach no region")
end)
```

- [ ] **Step 2: Run it and see it fail**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua 2>&1 | grep -A3 "every Text row"`
Expected: FAIL — `container.text.template: a value to write` (a free-text row offers no choice to
walk), and once that is given, `bad argument #1 to 'ipairs' (table expected, got nil)` from
`serLog` (a text element keeps its prebuilt duration binding, a plain client object, on `__am`).

- [ ] **Step 3: Implement (in the suite: the rig learns the text style)**

In `env()`, replace `        E.DurationTextBindingProperty = { RemainingDuration = 1 }` with:

```lua
        E.DurationTextBindingProperty = { RemainingDuration = 1, TotalDuration = 2, ElapsedDuration = 3,
            RemainingPercent = 4, ElapsedPercent = 5 }
```

and insert after the `m.C_StringUtil = { CreateSecondsFormatter = function() … end }` block (before
`local function curve()`):

```lua
        -- The Text style's rule formatters and prebuilt duration bindings record what they were
        -- built with, like the seconds formatter above.
        m.C_StringUtil.CreateNumericRuleFormatter = function() return recordingObject({ "SetBreakpoints" }) end
        m.C_DurationUtil = { CreateDurationTextBinding = function()
            return recordingObject({ "SetZeroDurationText", "SetExpiredText", "SetUpdateInterval" })
        end }
```

Replace `recordersOf`'s doc comment and head

```lua
--- Every recorder that belongs to one dressed element: the element, its regions, a bar's edge.
local function recordersOf(frame)
    local list = { frame }
    for _, r in pairs(frame.__am or {}) do
        if type(r) == "table" then
```

with

```lua
--- Whether `v` is one of this suite's recorders. A text element also keeps plain client objects on
--- `__am` (its prebuilt duration bindings); only what records is read.
local function isRecorder(v)
    return type(v) == "table" and rawget(v, "__log") ~= nil
end

--- Every recorder that belongs to one dressed element: the element, its regions, a bar's edge.
local function recordersOf(frame)
    local list = { frame }
    for _, r in pairs(frame.__am or {}) do
        if isRecorder(r) then
```

In `signature`, the key loop's `        if type(v) == "table" then` becomes `        if isRecorder(v) then`.

Replace `differing`'s doc comment and first line

```lua
--- A legal value for `row` that differs from `cur`.
local function differing(row, cur)
    if row.type == "bool" then return not cur end
```

with

```lua
-- A free-text row has no list to pick from, so it names the value it is walked with: the Text
-- template's default, with its bracket text changed and its shape kept (a new shape builds a new
-- chain of font strings, which a recorder swapped in by `adopt` would never see).
local SAMPLES = { ["container.text.template"] = "$spellname$[ y$stacks$][ ~ $remainingduration$]" }

--- A legal value for `row` that differs from `cur`.
local function differing(row, cur)
    if SAMPLES[row.path] then return SAMPLES[row.path] end
    if row.type == "bool" then return not cur end
```

and add a `text` entry to `GATES`:

```lua
    -- Right, so Center (a multi-piece template lines up Left) still moves the chain; an icon, so
    -- its rows reach one.
    text = { icon = "LEFT", iconBorderShow = true, expiringColorOn = true, justifyH = "RIGHT" },
```

In the file header's first line, "every Bars and Icons setting" → "every Bars, Icons and Text setting".

- [ ] **Step 4: Run it and see it pass**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua 2>&1 | grep -A3 "coverage:"`
Expected: all three `coverage:` cases PASS (Bars and Icons unchanged). If a Text row is named, it
is a real gap in Task 8's styler: fix the styler, not the suite.

- [ ] **Step 5: Checkpoint — run the green gate**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua && /home/tushar/.claude/wow-addon/bin/ka0s-bounded luacheck .`
Expected: 0 failed; `0 warnings / 0 errors`. Update the ledger. Do not commit.

---

### Task 12: perf — a text restyle scenario

**Files:**
- Modify: `tests/perf.lua` (insert before `-- 5. The visibility pass every combat transition runs.`, line 138)

**Interfaces:**
- Consumes: the "Player cooldowns" starter (Task 10), `ContainerClass:Restyle`, the perf runner's `measure` and `assert_`.
- Produces: a `restyleText` row in the offline perf table and one deterministic assertion: a same-shape re-dress builds no frame (the chain, its strings and the loops are built once).

- [ ] **Step 1: Write the failing scenario**

Insert into `tests/perf.lua` before `-- 5. The visibility pass every combat transition runs.`:

```lua
-- 4b. A restyle of the text starter with ten live buttons: a same-shape re-dress, which builds no font
--     string, no frame and no animation group, and re-binds each field once per button.
local textCfg
for _, c in ipairs(NS.Database.GetContainers()) do
    if c.style == "text" then textCfg = c end
end
assert_(textCfg ~= nil, "restyleText: no text container among the starters")
if textCfg then
    local instText = CM.instances[textCfg.id]
    local key = instText.plan.groups[1].key
    instText.engine.__frames[key] = {}
    for i = 1, 10 do instText.engine.__frames[key][i] = mocks.__stubFrame() end
    instText:Restyle(textCfg)   -- the first dress builds the regions; the loop measures the re-dress
    local frames = 0
    local create = mocks.CreateFrame
    mocks.CreateFrame = function(...) frames = frames + 1; return create(...) end
    measure("restyleText", 200, function() instText:Restyle(textCfg) end)
    mocks.CreateFrame = create
    -- red under: useChain rebuilding the chain on every dress
    assert_(frames == 0, ("restyleText: a same-shape re-dress built %d frame(s)"):format(frames))
end
```

- [ ] **Step 2: See it fail against a broken chain cache**

Temporarily break the chain cache in `modules/Style_Text.lua`'s `useChain`: change its first line to
`    if false then return end` and `    local saved = frame.__amChains[compiled.shape] or newChain(am, count)`
to `    local saved = newChain(am, count)`. Run
`/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/perf.lua 2>&1 | tail -3` and expect
`1 assertion FAILED:` / `- restyleText: a same-shape re-dress built 2000 frame(s)` (the runner's
exit code is 1 when run bare). Restore both lines.

- [ ] **Step 3: Run it and see it pass**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/perf.lua 2>&1 | tail -20`
Expected: a `restyleText` row (`api/iter 0.0`), no assertion failures, exit 0. `tests/perf.lua`
is outside the commit gate (performance-§9); record the figures in the ledger's Notes.

- [ ] **Step 4: Checkpoint — run the green gate**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua && /home/tushar/.claude/wow-addon/bin/ka0s-bounded luacheck .`
Expected: 0 failed (`test_loadorder`'s "the offline perf runner … derive from the TOC" still passes); `0 warnings / 0 errors`. Update the ledger. Do not commit.

---

### Task 13: Part A docs (spec §12)

**Files:**
- Modify: `docs/ARCHITECTURE.md` (Overview lines 8–12 and 84–89; Slash table line 264; Known Limitations lines 453–454 and two new bullets; Taint Notes one bullet)
- Modify: `docs/module-map.md` (load-order items 5–6; the `modules/`, `settings/` and `tests/` tables)
- Modify: `docs/schema.md` (a `### text` subsection after `### icons`; "The text block" names `text.font`; the starter table gains a row; "seeds … three" wording)
- Modify: `docs/settings-panel.md` (a `### Text` section after `### Icons`; the Containers Style row)
- Modify: `docs/midnight-quirks.md` (a new section before `## Additive bindings stack`, line 155; keep the owner's uncommitted block untouched)
- Modify: `docs/smoke-tests.md` (a new `## S.` section after section R, items 94–103)
- Modify: `README.md` (the intro sentence, `## Usage`, `## How the containers work`, the Tests badge)
- Regenerate: `docs/test-cases.md`

**Interfaces:**
- Consumes: everything Tasks 4–12 built.
- Produces: documentation only; `tests/test_docs.lua` (Documentation map both ways, US spelling, citations) and `tests/test_locale.lua` stay green.

- [ ] **Step 1: See the docs gate as it stands**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua 2>&1 | grep -A6 "^  FAIL  docs"`
Expected: no FAIL (every task re-pointed its own citations). Anything listed is fixed with
`/tmp/citefix.py` before going on.

- [ ] **Step 2: `docs/ARCHITECTURE.md`**

- Overview, lines 10–12: "one style (`bars` or `icons` — `:43`)" → "one style (`bars`, `icons` or
  `text` — `:48`)"; "a fresh profile is seeded with three (`NS.STARTER_CONTAINERS`, …)" → "a fresh
  profile is seeded with four (`NS.STARTER_CONTAINERS`, …)" (keep the citation `/tmp/citefix.py` set).
- Overview, line 88: "and `modules/Style.lua` with its two style files (dressing a button)" →
  "and `modules/Style.lua` with its three style files (`Style_Bars.lua`, `Style_Icons.lua` and
  `Style_Text.lua`, chosen per container by `Style.Styler`), plus the pure template parser the Text
  style draws from (`modules/TextTemplate.lua`)".
- Slash table, line 264: "`bars`/`icons`)" → "`bars`/`icons`/`text`)".
- Known Limitations, lines 453–454: "Party units 1–5 are deferred and tracked as a GitHub issue; so is
  a text-only container style." → "Party units 1–5 are deferred and tracked as a GitHub issue." and add
  after that bullet:

```markdown
- **A Text line centers only when its template is one piece.** A line is a chain of font strings the
  engine writes secret, so the chain's width is never readable; a multi-piece template set to Center
  lines up Left, and the Text page says so (`Style.Text.JustifyFor`).
- **A Text token can be used once, the duration tokens must sit together, and there is no caster
  token.** The engine has one binding per field (one spell name, one stack count, one dispel type, one
  duration text whose format holds every duration value); it has none for the caster
  (`modules/TextTemplate.lua`).
- **A Text animation cannot start, stop or change in combat.** Every call on an engine button's
  objects is refused in combat; loops are built and played at dress time and keep running, and a
  change made in combat applies with the deferred restyle (`docs/midnight-quirks.md`).
```

- Taint Notes: add a bullet

```markdown
- **Animations on engine buttons are set up at dress time only.** `modules/Style_Text.lua` builds its
  three AnimationGroups with the regions and calls `Stop`/`Play` only in a dress (initializeFrame or a
  restyle while auras are readable), each through `Style.Bind`, so a refusal costs one call and is
  logged. There is no Scale loop: glyphs scaled past their anchored boxes overlap the next piece.
```

- [ ] **Step 3: `docs/module-map.md`**

- Load order item 5: "`Style.lua` before `Style_Bars.lua` and `Style_Icons.lua`, which decorate
  `NS.Style` at file scope." → "`TextTemplate.lua` before `Style_Text.lua` (a file-scope upvalue), and
  `Style.lua` before `Style_Bars.lua`, `Style_Icons.lua` and `Style_Text.lua`, which decorate
  `NS.Style` at file scope."
- Item 6: "its four sub-pages `Filters.lua`, `Layout.lua`, `Bars.lua`, `Icons.lua`" → "its five
  sub-pages `Filters.lua`, `Layout.lua`, `Bars.lua`, `Icons.lua`, `Text.lua`".
- `modules/` table: after the `FilterCompiler.lua` row add

```markdown
| `modules/TextTemplate.lua` | Pure: the Text style's template language. `TT.Compile` turns a template into ordered pieces (literal, name, stacks, dispel, duration run), memoized; `TT.Validate` is the Template row's `validate`; `TT.ForDraw` draws a refused stored template as the default |
```

  after the `Style_Icons.lua` row add

```markdown
| `modules/Style_Text.lua` | Builds and dresses a text button: clip, animation and text-area frames, one chain of font strings per template shape, the Left/Right/Center chain anchors, the line's font, the three loops (played at dress time), each piece's engine binding (rule formatter, dispel text map, duration `textFormat` with a prebuilt binding and the blink curve), the optional icon; preview fill |
```

  and extend the `modules/Style.lua` row's list with "the style dispatch (`StyleKey`, `Styler`,
  `StructureKey`), the shared icon helpers (`IconSizeFor`, `IconInset`, `LayoutIcon`), a Text
  duration run's `textFormat` and binding, the measured time-text width (`TimeTextWidth`)".
- `settings/` table: after the `settings/Icons.lua` row add

```markdown
| `settings/Text.lua` | The Text page, a sub-page of Containers (`N-2`, D6): size, the Template box with its token cheat sheet (a bespoke General tab), placement and the centering note, the composed font block and time format, the icon and its composed border, the loop and the running-out rows; disabled for a bars or icons container |
```

  and in the `settings/Bars.lua` / `settings/Icons.lua` rows "disabled for an icons container" /
  "disabled for a bars container" → "disabled for any other style".
- `tests/` table: after `test_style_icons.lua` add

```markdown
| `test_style_text.lua` | `modules/Style_Text.lua`: the nested frames, the chain's anchors per justify, the Center fallback, each piece's binding and options, the blink, the loops, the icon, a refused stored template, the chain per shape, the preview fill |
| `test_texttemplate.lua` | `modules/TextTemplate.lua`: every template rule with its message, the escapes, case, the compiled pieces, `ForDraw` |
```

  after `test_pages_icons.lua` add

```markdown
| `test_pages_text.lua` | `settings/Text.lua` through its widgets: the tabs, the notice and disabled rows for another style, the Template box and its refusal text (panel and `/am set`), the cheat sheet, the centering note, the rows the effect and the template dim, Defaults |
```

  and change the `test_render_coverage.lua` row's "Every Bars and Icons schema row" → "Every Bars,
  Icons and Text schema row". Under the table's helpers (next to `tests/region_recorder.lua` if it is
  listed there; otherwise at the end of the tests table) add:

```markdown
| `text_apis.lua` | Not a suite: the Text style's client APIs as recording stand-ins, installed from a fresh environment's `before` |
| `region_builder.lua` | Not a suite: a recorder that builds recorders, so each piece of a chain records its own calls |
```

- [ ] **Step 4: `docs/schema.md` and `docs/settings-panel.md`**

`docs/schema.md`, after the `### icons` subsection add:

```markdown
### `text`

The Text style (issue #2). `width` (220), `height` (16); `template`
(`"$spellname$[ x$stacks$][ - $remainingduration$]"`, validated by `modules/TextTemplate.lua`; a
refused stored template draws the default); `justifyH` (`"LEFT"`; `"CENTER"` only for a one-piece
template), `justifyV` (`"MIDDLE"`), `x` (2), `y` (0); `font` (the six canonical font leaves, size
12); `timeFormat` (`"blizzard"`); the icon — `icon` (`"NONE"`), `iconSize` (0 = the line's height),
`iconGap` (2), `iconZoom` (0.08) and the composed icon-border block (`iconBorderShow` false,
`iconBorderStyle` `"Solid"`, `iconBorderSize` 1, `iconBorderColor` black, `useClassColorIconBorder`
false); the loop — `anim` (`"none"`, `"pulse"`, `"blink"`, `"bounce"`), `animSpeed` (1.0 s per cycle),
`animIntensity` (0.3, the lowest alpha), `animBounce` (3 px); running out — `expiringColorOn`
(false), `expiringThreshold` (5), `expiringColor`, `expiringBlink` (false). An existing container
gains the block by the ordinary backfill; there is no schema-version bump.
```

In "### The text block", "Every text element (`bars.name`, …, `icons.stacks`) has the six canonical
font leaves" → "Every Bars and Icons text element (`bars.name`, …, `icons.stacks`) has the six
canonical font leaves … (the Text style's `text.font` carries the six font leaves only)". In "## The
starter containers" add the row

```markdown
| Player cooldowns | player | HELPFUL | text | `CENTER` −260, −40; vertical, grows right and down; `filter.categories` from `Cat.StatesShowing({ "offensiveCDs", "defensives" })`: every other buff category Hidden, Uncategorized included |
```

`docs/settings-panel.md`: after the `### Icons …` section add a `### Text (… rows, \`settings/Text.lua\`) — sub-page of Containers (\`N-2\`, \`D6\`)`
section (count the rows with `grep -c 'path = P' settings/Text.lua` plus the composed font block's 6
and border block's 5) describing, in the Icons section's shape: the four tabs; General drawn bespoke
to put the token cheat sheet under the Template box and the centering note under Placement; the
Template box's refusal printed in chat as `Invalid value for container.text.template` and the
parser's reason under it; Running out dimmed (the swatch excepted) with a note when the template has
no duration token; the loop rows dimmed per effect; the muted-gold note and every control disabled
for a bars or icons container. Then a tab/rows table like the Icons one:

```markdown
| Tab | Rows (all under `container.text.`) |
|---|---|
| General | Size: `width`, `height`. What each line says: `template` (+ the cheat sheet). Placement: `justifyH`, `justifyV`, `x`, `y` (+ the centering note) |
| Font | the composed font block under `font.`; Countdown: `timeFormat` |
| Icon | `icon`, `iconSize`, `iconGap`, `iconZoom`; the composed icon-border block |
| Animation | Loop: `anim`, `animSpeed`, `animIntensity`, `animBounce`. Running out: `expiringColorOn`, `expiringThreshold`, `expiringColor`, `expiringBlink` (engine-only) |
```

- [ ] **Step 5: `docs/midnight-quirks.md`**

Insert before `## Additive bindings stack` (do not touch the owner's uncommitted "Measured in-game,
client 12.1.0 (120100), 2026-09-18" block higher up):

```markdown
## Text chains and animations on engine buttons

**Measured in-game, client 12.1.0 (120100), 2026-09-18** (two throwaway probes, 40 player-buff
buttons each, for issue #2):
- Every binding the Text style uses was accepted: `SetSpellName`; `SetApplicationCount` with a
  `C_StringUtil.CreateNumericRuleFormatter` whose breakpoints `{0: ""}, {2: " x%d"}` hide a single
  stack; `SetDurationText` with `textFormat = { formatString, components }` (several `{}` in one
  string) and a prebuilt `C_DurationUtil.CreateDurationTextBinding()` carrying
  `SetZeroDurationText("")`, `SetExpiredText("")` and `SetUpdateInterval(0.1)`; a stepped
  `C_CurveUtil` color curve on `RemainingDuration`. `RemainingPercent` arrives on a 0–100 scale.
- A timeless aura writes nothing through that binding, so text folded into the duration's format
  disappears with it.
- A stepped curve with alternating alpha blinks the duration text in the last seconds, in and out of
  combat.
- AnimationGroups started at dress time keep playing through combat and after it. In combat every
  call on the button's objects raises "Attempt to access forbidden object from code tainted by an
  AddOn" (`AnimationGroup:IsPlaying/Play/Stop`, `Region:IsShown`, `IsAnchoringSecret`), so an
  animation is set up at dress time only.
- `FontString:IsAnchoringSecret()` answers true even out of combat for an engine-written name: no
  width in a chain can be read, so a multi-piece line cannot be centered.
- A **Scale** animation broke a left-justified chain (the glyphs grew about 8 % past their boxes and
  overlapped the next piece); an Alpha animation did not. Round 2, four chains each piece boxed and
  tinted, laid out cleanly in and out of combat: the client sizes an engine-written, single-anchored,
  auto-sized font string to its secret text, and a chain anchored to it lays out right.

So a Text line is a chain of single-anchored, auto-sized font strings (`modules/Style_Text.lua`),
its loops are Alpha and Translation only, built and played at dress time.
```

- [ ] **Step 6: `docs/smoke-tests.md`**

After section R, add:

```markdown
## S. The Text style (issue #2)

94. **The default template on player buffs.** Style a player-buff container as Text: names, ` x3`
    stacks and ` - 12s`, all live in combat; a timeless buff shows its name only.
95. **Several durations.** Template `$spellname$ $remainingduration$ / $maxduration$ ($remainingpercent$)`,
    justified Left, then Right: the line reads and lines up both ways.
96. **Dispel type.** `$spellname$[ ($dispeltype$)]` on a target-debuff Text container: correct type
    names; nothing (brackets included) on a typeless debuff.
97. **Loops.** Pulse, Blink and Bounce, each through a pull: no piece overlaps another while it
    animates; a change made in combat starts when combat ends.
98. **Running out.** Recolor on, then Blink on: the duration run turns the color, then blinks, in the
    last N seconds; the rest of the line keeps the font color.
99. **The icon.** Icon Left, then Right, with a border: the text starts after the icon and its gap,
    and a long line is cut at its box rather than drawn under the icon.
100. **Refusals.** In the Template box and with `/am set container.text.template $spellname$ $bogus$`
     (no quotes): chat prints `Invalid value for container.text.template` and, indented, the rule
     that broke; the stored template does not change. Try each rule of spec §3.2 once.
101. **Style switching.** A container Bars → Text → Icons → Text, out of combat: each redraws cleanly,
     and Layout → Growth → Fill follows (Columns, Rows, Columns).
102. **Weapon enchants.** A weapon-enchant container styled Text shows the enchant's name and time.
103. **The Player cooldowns starter.** On a NEW profile, the "Player cooldowns" Text container shows
     an offensive and a defensive cooldown when popped, and nothing else (no food, flask, mount or
     raid buffs).
```

- [ ] **Step 7: `README.md` and the case inventory**

- The intro sentence (line 11) "whether they draw as timer bars or as icons" → "whether they draw as
  timer bars, as icons or as lines of text".
- `## Usage`: after the paragraph that mentions `/am new target debuffs icons`, add:

```markdown
A **Text** container draws each aura as one line, from a template you write on its Text page, such
as `$spellname$[ x$stacks$][ - $remainingduration$]`. The tokens are `$spellname$`, `$stacks$`,
`$dispeltype$`, `$remainingduration$`, `$maxduration$`, `$elapsedduration$`, `$remainingpercent$` and
`$elapsedpercent$`; text inside `[ ]` hides along with the token it holds (so ` x3` shows only at two
or more stacks, and ` - 12s` only on an aura with a duration). The page lists them all, and a line
can carry the aura's icon, pulse, blink or bounce, and blink its time in the last seconds. A new
profile starts with one: **Player cooldowns**, which shows only your offensive and defensive
cooldowns.
```

- `## How the containers work`: wherever it says a container draws as bars or icons, add "or text".
- Regenerate the inventory and the badge:
  `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua --list > docs/test-cases.md`,
  convert it to CRLF (the Global Constraints' one-liner is not needed: `--list` writes CRLF itself),
  read its `| **Total** | **N** |`, and set README line 7 to
  `![Tests](https://img.shields.io/badge/Tests-N%2FN_passing-green)` with that N.

- [ ] **Step 8: Checkpoint — run the green gate**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua && /home/tushar/.claude/wow-addon/bin/ka0s-bounded luacheck .`
Expected: 0 failed (the docs, locale and spelling cases included); `0 warnings / 0 errors`. Update
the ledger. Do not commit.

---

### Task 14: B1 — unlocking keeps live auras; a standard session-only test mode

**Files:**
- Modify: `core/State.lua:12-20` (the header's state list and "no preview flag" note; `State.testMode = false`)
- Modify: `modules/Preview.lua:11-13` (header), + `Preview.SetTestMode` above `Preview.Offset`
- Modify: `modules/Container.lua` — top locals (lines 22–24), `ContainerClass:ShouldShow` and `ApplyVisibility` (lines 393–446), `Park` (461–467), `Destroy` (472–478)
- Modify: `core/AuraMaster.lua:85` (`addon:OnCombatChanged`)
- Modify: `settings/General.lua` (header lines 5–31, the `MasterControls` spec, the row loop)
- Modify: `settings/Slash.lua` (the `run*` forward declaration, line 31; `unlock` and a new `test` in `NS.COMMANDS`; `runTest`; `Sl.SetLocked` → `Sl.ToggleTestMode`)
- Modify: `core/LauncherSetup.lua` (header lines 16–25; `onClick`)
- Modify: `settings/OptionsSetup.lua` (the degradation stub's `MasterControls`, lines 253–276)
- Modify: `locales/enUS.lua`
- Modify: `docs/ARCHITECTURE.md`, `docs/slash-dispatch.md:22-25`, `docs/module-map.md`, `docs/smoke-tests.md` (section C, item 88, and new items), `README.md` (`## Usage`)
- Test: `tests/test_container.lua`, `tests/test_state.lua`, `tests/test_slash.lua`, `tests/test_slash_verbs.lua`, `tests/test_optionssetup.lua`, `tests/test_pages_general.lua`, `tests/test_launcher.lua`, `tests/test_disabled.lua`, `tests/test_anchors.lua`, `tests/test_preview.lua`

**Interfaces:**
- Consumes: `H.MasterControls`'s `testModePath` (LibKa0s Options compose minor ≥ 6; the vendored v1.43.0 has it: `libs/LibKa0s/OptionsCompose.lua:526-535`), the bus's `VISIBILITY_CHANGED`, `NS.Anchors.UpdateHandle`, `NS.Preview.Offset`, `NS.Style.ElementSize`.
- Produces:
  - `NS.State.testMode` (session-only boolean, false at login) and `NS.Preview.SetTestMode(on) -> ok` — the one writer: refuses a start under `InCombatLockdown()` with one gray line `Test mode can't start in combat.`, else sets the flag, sends `VISIBILITY_CHANGED` on a change and calls `H.RefreshScalars()`.
  - `ContainerClass:ShouldShow() -> show, previewing` with `previewing = NS.State.testMode` and `show = (not locked) or visibilityAllows(...)`; new `ApplyAnchorShown`, `ApplyLive(on)`, `ApplyAlpha(cfg, p)`, `ApplyOutline(cfg, on)` (the outline is `container.outline`, a `BackdropTemplate` frame under the anchor, one element's size at `Preview.Offset(cfg, 1)`'s corner, 1 px white at alpha 0.35, no mouse). Splitting `ApplyVisibility` also brings it from CCN 19 (at HEAD) to ≤ 15.
  - The session row `state.testMode` (label "Test mode", composed beside Minimap button, `default = false`), `/am test [on|off]`, `NS.Slash.ToggleTestMode()` (the launcher's left click); `NS.Slash.SetLocked` is removed.
- The spec's `testModePath = "testMode"` is written `state.testMode` here: this addon's session rows live under `state.` (`state.debugConsole`), and the path names no stored leaf either way.
- The spec's "the launcher tooltip text follows" is moot: `core/LauncherSetup.lua` passes no `onTooltipShow`, so there is no tooltip text to change.

- [ ] **Step 1: Write the failing tests**

Replace these cases whole (each `test(…)` through its `end)`), matching on the name shown:

`tests/test_state.lua`, "state: there is no preview flag and no preview toggle; unlocking is the preview":

```lua
test("state: test mode is session-only and off at login; unlocking keeps real auras drawing (B1)", function()
    local NS = fresh()
    assertFalse(NS.State.testMode, "off at login")
    -- red under: modules/ContainerManager.lua growing a second preview switch
    assertNil(NS.ContainerManager.SetPreview, "one switch: Preview.SetTestMode")
    local e = NS.ContainerManager.instances[1].engine
    assertTrue(e.__enabled, "locked by default: real auras draw")
    assertTrue(NS.SetByPath("locked", false))
    -- red under: ShouldShow still reading the lock as the preview
    assertTrue(e.__enabled, "unlocked: real auras keep drawing")
    NS.Preview.SetTestMode(true)
    assertFalse(e.__enabled, "test mode: the placeholders take the engine's place")
    NS.Preview.SetTestMode(false)
    assertTrue(e.__enabled, "test mode off: real auras are back")
    assertNil(rawget(NS.db.profile, "testMode"), "never saved")
end)
```

`tests/test_slash.lua`, "slash: /am test and /am preview are unknown verbs; …":

```lua
test("slash: /am preview is an unknown verb; /am test switches test mode and leaves the lock alone (B1)", function()
    local NS2, mocks = fresh()
    local lines = capture(mocks)
    NS2.Slash:OnSlash("preview on")
    assertTrue(said(lines, "command 'preview'"), lastLine(lines))
    NS2.Slash:OnSlash("test")
    -- red under: NS.COMMANDS without its {"test", ...} entry
    assertTrue(NS2.State.testMode, "/am test toggles it on")
    assertTrue(said(lines, "Test mode on"), lastLine(lines))
    NS2.Slash:OnSlash("test off")
    assertFalse(NS2.State.testMode)
    NS2.Slash:OnSlash("test on")
    assertTrue(NS2.State.testMode)
    assertTrue(NS2.db.profile.locked, "the lock is untouched")
    NS2.Slash:OnSlash("test sideways")
    assertTrue(said(lines, "Usage: /am test [on|off]"), lastLine(lines))
end)
```

`tests/test_slash.lua`, "slash: /am help and the landing page list neither test nor preview":

```lua
test("slash: /am help and the landing page list test, and not preview (B1)", function()
    local NS2, mocks = fresh()
    local lines = capture(mocks)
    NS2.Slash:OnSlash("help")
    local help, rows = table.concat(lines, "\n"), table.concat(NS2.Slash.LandingRows(), "\n")
    -- The verb, then anything but a letter: a help row closes the verb's color code right after it.
    local function listed(text, verb) return text:find("/am " .. verb .. "[^%w]") ~= nil end
    -- red under: NS.COMMANDS without its {"test", ...} row
    assertTrue(listed(help, "test") and listed(rows, "test"), "test is listed")
    assertFalse(listed(help, "preview") or listed(rows, "preview"), "no preview verb")
    -- red under: the unlock row still promising placeholder auras
    assertFalse(help:find("shows placeholder auras", 1, true) ~= nil, "unlock no longer previews")
end)
```

`tests/test_slash_verbs.lua`, "slash verbs: /am lock and /am unlock go through the seam, so the placeholders follow; …" (the second case is new):

```lua
test("slash verbs: /am lock and /am unlock go through the seam: unlocked shows the handle, and live auras keep drawing (B1)", function()
    local NS2, mocks = fresh()
    local lines = capture(mocks)
    local inst = NS2.ContainerManager.instances[1]
    assertEqual(dump(slash(NS2, lines, "unlock")), "{Containers unlocked — drag a container by its handle}")
    assertFalse(NS2.db.profile.locked)
    assertTrue(inst.handle:IsShown(), "unlocked: the handle shows")
    -- red under: ShouldShow still reading the lock as the preview
    assertFalse(inst.previewShown, "unlocked: no placeholders")
    assertTrue(inst.engine.__enabled, "unlocked: real auras draw")
    assertEqual(dump(slash(NS2, lines, "lock")), "{Containers locked}")
    assertTrue(NS2.db.profile.locked)
    -- red under: runLock writing profile.locked around the seam (no CONFIG_CHANGED, no visibility pass)
    assertFalse(inst.handle:IsShown(), "locked: the handle goes")
end)

test("slash verbs: /am test in combat refuses on one gray line and starts nothing (B1)", function()
    local NS2, mocks = fresh()
    local lines = capture(mocks)
    mocks.__lockdown = true
    NS2.Slash:OnSlash("test")
    -- red under: Preview.SetTestMode starting under lockdown
    assertFalse(NS2.State.testMode)
    assertEqual(#lines, 1, "one line")
    assertTrue(lines[1]:find("|cff808080", 1, true) and lines[1]:find("Test mode can't start in combat.", 1, true) ~= nil, lines[1])
end)
```

`tests/test_optionssetup.lua`, "options: the General page leads with Master controls, in canonical order":

```lua
test("options: the General page leads with Master controls, in canonical order", function()
    local rows = NS.SchemaForPage("general")
    local want = { "enabled", "visibility", "scale", "alpha", "locked", "state.debugConsole",
                   "global.minimap.hide", "state.testMode" }
    for i, path in ipairs(want) do
        assertEqual(rows[i].path, path)
        assertEqual(rows[i].group, NS.Helpers.MASTER_GROUP)
    end
    -- red under: settings/General.lua without its testModePath (B1: unlocking no longer previews,
    -- so the test mode has a row of its own, beside Minimap button: options-ui-§15, anti-pattern #80)
    assertTrue(rows[9] == nil or rows[9].group ~= NS.Helpers.MASTER_GROUP, "Master controls has eight rows")
    assertTrue(rows[8].sessionOnly, "Test mode is session state")
    assertNil(rows[8].startsLine, "it pairs beside Minimap button")
    assertEqual(NS.Helpers.MASTER_GROUP, "Master controls")
end)
```

`tests/test_pages_general.lua`, "general: Master controls has no Test mode row; Lock frame is the preview's switch" (two more cases follow it):

```lua
test("general: the Test mode checkbox shows the placeholders without unlocking, and reads the mode back (B1)", function()
    local NS, _, P, ws = general()
    local box = P.row(ws, "state.testMode")
    assertEqual(box.type, "CheckBox")
    box:__fire("OnValueChanged", true)
    for id, inst in pairs(NS.ContainerManager.instances) do
        -- red under: the row's set not reaching Preview.SetTestMode
        assertTrue(inst.previewShown, "container " .. id .. " shows its placeholders")
    end
    assertTrue(NS.db.profile.locked, "without unlocking")
    box:__fire("OnValueChanged", false)
    for id, inst in pairs(NS.ContainerManager.instances) do
        assertFalse(inst.previewShown, "container " .. id .. " drops them")
    end
end)

test("general: a Test mode start in combat is refused and the checkbox reads false again (B1)", function()
    local NS, m, P, ws = general()
    local box = P.row(ws, "state.testMode")
    m.__lockdown = true
    box:__fire("OnValueChanged", true)
    -- red under: the row storing the value past Preview.SetTestMode's refusal
    assertFalse(NS.State.testMode)
    assertFalse(box.value and true or false, "the checkbox follows the refusal")
end)

test("general: combat starting ends test mode, and Reset all settings ends it too (B1)", function()
    local NS, m, P, ws = general()
    NS.Preview.SetTestMode(true)
    NS.addon:OnCombatChanged("PLAYER_REGEN_DISABLED")
    -- red under: OnCombatChanged not ending test mode (a placeholder covering real auras in a fight)
    assertFalse(NS.State.testMode)
    assertFalse(P.row(P.rerender("General"), "state.testMode").value and true or false)
    m.__lockdown = false
    NS.Preview.SetTestMode(true)
    NS.Helpers.RestoreAllDefaults()
    -- red under: the Test mode row without its default (options-ui-§12's reset leaves it on)
    assertFalse(NS.State.testMode)
    assertTrue(ws ~= nil)
end)
```

`tests/test_launcher.lua`, "launcher: rung (b) — the LEFT click toggles the lock, through the addon's own write seam":

```lua
test("launcher: rung (b) — the LEFT click toggles test mode, and the lock is left alone (B1)",
function()
    local NS2, rec = withBroker()
    local click = rec.objects.AuraMaster.OnClick
    assertTrue(type(click) == "function", "the object carries the one click implementation")
    click(rec.objects.AuraMaster, "LeftButton")
    -- red under: an onClick still toggling the lock (unlocking no longer previews)
    assertTrue(NS2.State.testMode, "test mode on: the preview")
    assertTrue(NS2.db.profile.locked, "the lock is untouched")
    click(rec.objects.AuraMaster, "LeftButton")
    assertFalse(NS2.State.testMode)
end)
```

`tests/test_launcher.lua`, "launcher: the left click holds no copy of the lock — it writes the path the checkbox writes":

```lua
test("launcher: the left click holds no copy of the test mode — it goes through the switch the checkbox uses",
function()
    local NS2, rec = withBroker()
    local asked = {}
    local set = NS2.Preview.SetTestMode
    NS2.Preview.SetTestMode = function(on)
        local n = #asked
        asked[n + 1] = tostring(on)
        return set(on)
    end
    rec.objects.AuraMaster.OnClick(rec.objects.AuraMaster, "LeftButton")
    NS2.Preview.SetTestMode = set
    -- red under: core/LauncherSetup.lua writing NS.State.testMode itself
    assertEqual(table.concat(asked, ","), "true", "one call to the switch")
    assertNil(rawget(NS2.db.profile, "testMode"), "nothing stored")
end)
```

`tests/test_launcher.lua`, "verbs: the launcher's click, the two verbs and the checkbox are three doors onto one write":

```lua
test("verbs: the launcher's click, /am test and the Test mode checkbox are three doors onto one switch",
function()
    local NS2, rec = withBroker()
    rec.objects.AuraMaster.OnClick(rec.objects.AuraMaster, "LeftButton")
    assertTrue(NS2.State.testMode)
    NS2.Slash:OnSlash("test off")
    assertFalse(NS2.State.testMode)
    NS2.SetByPath("state.testMode", true)
    assertTrue(NS2.State.testMode)
    -- red under: core/LauncherSetup.lua reaching past NS.Slash.ToggleTestMode
    assertTrue(type(NS2.Slash.ToggleTestMode) == "function", "published for exactly one caller")
    assertNil(NS2.Slash.SetLocked, "the lock is no longer the launcher's")
end)
```

`tests/test_container.lua`, insert before "container: a visibility pass re-dresses no preview element unless the settings changed":

```lua
test("container: unlocked, a container shows whatever its visibility rule, its engine drawing, under an outline (B1)", function()
    local NS = fresh()
    local inst = NS.ContainerManager.instances[1]
    NS.SetByPath("visibility", "never")
    assertFalse(inst.engine.__enabled, "locked and set to never: nothing draws")
    NS.SetByPath("locked", false)
    -- red under: ShouldShow applying the visibility rule while unlocked (an in-combat-only
    -- container could never be found and moved out of combat)
    assertTrue(inst.engine.__enabled, "unlocked: shown, its live auras drawing")
    assertTrue(inst.handle:IsShown(), "and its handle")
    -- red under: ApplyVisibility without the outline (an empty container has nothing to grab)
    assertTrue(inst.outline ~= nil and inst.outline:IsShown(), "an outline marks even an empty container")
    NS.Preview.SetTestMode(true)
    assertFalse(inst.outline:IsShown(), "test mode: the placeholders are there instead")
    NS.Preview.SetTestMode(false)
    NS.SetByPath("locked", true)
    assertFalse(inst.outline:IsShown(), "locked: no outline")
end)
```

`tests/test_disabled.lua`, in "disabled: every reserved verb answers, and the bare /am opens the panel":
`"new,delete,lock,unlock,pick,resetposition,forgettimed"` → `"new,delete,lock,unlock,test,pick,resetposition,forgettimed"`
(the dispatcher refuses every non-live verb while disabled, so `test` joins the feature verbs).

Every case that used the lock as the preview switch now uses the test mode. Run from the repo root
(CRLF-safe ranges; `ON`/`OFF` below are the two substitutions):

```bash
ON='s/SetByPath("locked", false)/Preview.SetTestMode(true)/g'
OFF='s/SetByPath("locked", true)/Preview.SetTestMode(false)/g'
sed -i -e "/^test(\"container: unlocking previews placeholders through the style code/,/^end)/{$ON;$OFF;s/container: unlocking previews placeholders/container: test mode previews placeholders/}" \
       -e "/^test(\"container: a visibility pass re-dresses no preview element/,/^end)/{$ON}" \
       -e "/^test(\"container: on a client without the aura engine nothing is built/,/^end)/{$ON}" tests/test_container.lua
sed -i -e "/^test(\"preview: switching a previewed container from bars to icons/,/^end)/{$ON}" \
       -e "/^test(\"preview: switching a previewed container from icons to bars/,/^end)/{$ON}" \
       -e "/^test(\"preview: a bar container duplicated while unlocked/,/^end)/{$ON;s/duplicated while unlocked/duplicated in test mode/}" \
       -e "/^test(\"preview: a real container's extent is a frame of ours/,/^end)/{$ON;$OFF}" tests/test_preview.lua
sed -i -e "/^test(\"anchors: locking re-anchors an attached container/,/^end)/{$ON;$OFF;s/anchors: locking re-anchors an attached container to its parent's engine, and unlocking back to the extent/anchors: ending test mode re-anchors an attached container to its parent's engine, and starting it back to the extent/;s/\"locked: the engine/\"test mode off: the engine/;s/\"unlocked: the extent again/\"test mode on: the extent again/}" \
       -e "/^test(\"anchors: under lockdown a preview toggle leaves/,/^end)/{$OFF;s/under lockdown a preview toggle leaves/under lockdown ending test mode leaves/}" tests/test_anchors.lua
```

and in `tests/test_anchors.lua`'s `previewPair` helper, replace its doc comment and the
`NS.SetByPath("locked", false)` line with:

```lua
--- Container 2 attached to container 1, unlocked (the handles show), in test mode and flushed: 1
--- previews, its engine off.
```

and

```lua
    NS.SetByPath("locked", false)
    NS.Preview.SetTestMode(true)
```

- [ ] **Step 2: Run them and see them fail**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua 2>&1 | grep -A3 -E "\(B1\)|test mode|FAIL" | head -60`
Expected: FAIL across the list — `attempt to call field 'SetTestMode' (a nil value)`, "unlocked:
real auras keep drawing (expected true, got false)", "no schema row state.testMode", "Master
controls has eight rows", "exactly the feature verbs refuse".

- [ ] **Step 3: Implement**

`core/State.lua` — in the header list add, after the `activeContainerId` entry, and delete the two-line
"There is no preview flag…" note:

```lua
--   testMode           the test mode (preview-mode, options-ui-§15): every container shows its
--                      placeholder auras. Off at login, ended when combat starts, refused in combat;
--                      written only by modules/Preview.lua's Preview.SetTestMode. Unlocking no
--                      longer previews: it makes containers draggable while live auras keep drawing
--                      (B1, 2026-09-19).
```

and add `State.testMode = false` after `State.activeContainerId = nil`.

`modules/Preview.lua` — the header's last paragraph becomes:

```lua
-- Preview is on while TEST MODE is (NS.State.testMode, switched only by Preview.SetTestMode below);
-- while it is, each container's engine is disabled so real auras do not draw on top of the
-- placeholders. Unlocking is separate: it makes containers draggable and leaves live auras drawing
-- (B1, 2026-09-19).
```

and insert above `--- Where preview element \`index\` (1-based) sits relative to the anchor, …`:

```lua
--- Turn test mode on or off: every container shows its placeholder auras while it is on
--- (preview-mode, options-ui-§15). Session-only, never saved. A START in combat is refused with one
--- gray line and changes nothing (the checkbox then reads false again); combat ending it is
--- core/AuraMaster.lua's PLAYER_REGEN_DISABLED, which calls this with false. The Master controls
--- checkbox, `/am test` and the launcher's left-click all come through here.
--- @return boolean  whether test mode is now what was asked for
function Preview.SetTestMode(on)
    on = on and true or false
    if on and InCombatLockdown() then
        NS.Printf("|cff808080%s|r", NS.L["Test mode can't start in combat."])
        return false
    end
    if NS.State.testMode ~= on then
        NS.State.testMode = on
        NS.bus:SendMessage(NS.MSG.VISIBILITY_CHANGED)
    end
    if NS.Helpers and NS.Helpers.RefreshScalars then NS.Helpers.RefreshScalars() end
    return true
end
```

`modules/Container.lua` — after `local HUGE = math.huge` add:

```lua
local C = NS.Constants
-- The unlocked outline's opacity: faint enough to read as a guide, never as a border (B1).
local OUTLINE_ALPHA = 0.35
```

Replace everything from the `--- The show ladder, in order. …` comment through the end of
`ContainerClass:ApplyVisibility` (keeping the "Enable or disable the engine …" doc comment that sits
between them) with:

```lua
--- The show ladder, in order. STEP 0 IS THE LATCH (slash-commands-§7, core/LifecycleSetup.lua):
--- whether the addon is running at all, for either reason it might not be -- the player switched it
--- off, or a perf capture is measuring its suspended arm. Nothing below it can re-show a container
--- behind the latch's back, which is why the stand-down refuses AT THE SOURCE rather than hiding
--- frames imperatively: a hidden frame comes back on the next combat transition or target swap.
--- The stored `enabled` path is NOT read again here: on a build with no LibKa0s the degraded
--- NS.IsStoodDown answers from that path itself, so step 0 is the one question. A parked container (Park) shows nothing either: its engine may still be
--- built for a container that no longer lives under its id.
---
--- PREVIEWING IS THE TEST MODE (NS.State.testMode), not the lock (B1): unlocking makes a container
--- draggable and its live auras keep drawing. An UNLOCKED container shows whatever its visibility
--- rule says, so one set to "in combat only" can still be found and moved out of combat.
--- @return boolean show, boolean previewing
function ContainerClass:ShouldShow()
    if NS.IsStoodDown() or self.parked then return false, false end
    local p = NS.db and NS.db.profile
    local cfg = self:Cfg()
    if not (p and cfg and cfg.enabled) then return false, false end
    local previewing = NS.State.testMode and true or false
    return (not p.locked) or visibilityAllows(p.visibility), previewing
end

--- The anchor's own half of a stand-down (see ApplyVisibility). Returns whether combat deferred it.
function ContainerClass:ApplyAnchorShown()
    if NS.IsStoodDown() then
        if InCombatLockdown() then return true end
        self.anchor:Hide()
    elseif not self.anchor:IsShown() and not InCombatLockdown() then
        self.anchor:Show()
    end
    return false
end

--- The engine's enable and the mouse blocker, which follow one rule: shown and not previewing.
function ContainerClass:ApplyLive(on)
    if self.engine then callEngine(self.engine, "SetEnabled", on) end
    if self.blocker then self.blocker:SetShown(on) end
end

--- The anchor's alpha: the container's own times Master alpha.
function ContainerClass:ApplyAlpha(cfg, p)
    local L = cfg and cfg.layout or {}
    self.anchor:SetAlpha((tonumber(L.alpha) or 1) * (tonumber(p and p.alpha) or 1))
end

--- The unlocked container's OUTLINE (B1): a faint one-pixel box, one element's size, at the corner
--- its flow starts from, so an EMPTY container can still be seen and grabbed while unlocked. A frame
--- of ours under the anchor, never the engine's; hidden when locked, and in test mode (the
--- placeholders are there then). It takes no mouse: the drag handle does the grabbing.
function ContainerClass:ApplyOutline(cfg, on)
    local o = self.outline
    if not on then
        if o then o:Hide() end
        return
    end
    if not o then
        o = CreateFrame("Frame", nil, self.anchor, "BackdropTemplate")
        o:SetBackdrop({ edgeFile = C.WHITE_TEXTURE, edgeSize = 1 })
        o:SetBackdropBorderColor(1, 1, 1, OUTLINE_ALPHA)
        o:EnableMouse(false)
        self.outline = o
    end
    local w, h = NS.Style.ElementSize(cfg)
    local point = NS.Preview.Offset(cfg, 1)
    o:ClearAllPoints()
    o:SetPoint(point, self.anchor, point, 0, 0)
    o:SetSize(w, h)
    o:Show()
end
```

(the "Enable or disable the engine and show or hide the preview …" doc comment stays here, unchanged)

```lua
function ContainerClass:ApplyVisibility()
    local show, previewing = self:ShouldShow()
    local p = NS.db and NS.db.profile
    local cfg = self:Cfg()
    -- THE ANCHOR ITSELF, and only while the addon is stood down. A stood-down addon draws NOTHING,
    -- and an anchor left shown is a frame of ours still on screen. It is the aura engine's ancestry,
    -- though, so it must not be shown or hidden under combat lockdown (events-frames-taint-§2):
    -- that half waits for PLAYER_REGEN_ENABLED and is reported here as `deferred`.
    local deferred = self:ApplyAnchorShown()
    self:ApplyLive(show and not previewing)
    self:ApplyAlpha(cfg, p)
    if show and previewing and cfg then
        NS.Preview.Show(self)
    else
        NS.Preview.Hide(self)
    end
    local unlocked = (show and p and not p.locked) and true or false
    self:ApplyOutline(cfg, unlocked and not previewing)
    NS.Anchors.UpdateHandle(self, unlocked)
    -- Containers attached to this one hang from its preview extent while it previews (L-4).
    NS.Anchors.PlaceAttached(self)
    return show, previewing, deferred
end
```

In `ContainerClass:Park`, after `if self.blocker then self.blocker:Hide() end` add
`    if self.outline then self.outline:Hide() end`; in `ContainerClass:Destroy`, after
`NS.Preview.Hide(self)` add the same line.

`core/AuraMaster.lua` — `addon:OnCombatChanged` begins:

```lua
function addon:OnCombatChanged(event)
    -- Test mode ends when combat starts, while secure writes are still allowed (preview-mode): no
    -- placeholder covers real auras in a fight.
    if event == "PLAYER_REGEN_DISABLED" and NS.State.testMode then NS.Preview.SetTestMode(false) end
    NS.bus:SendMessage(NS.MSG.VISIBILITY_CHANGED)
```

`settings/General.lua` — in the header sketch, `--                      [Minimap button]` becomes
`--                      [Minimap button]      [Test mode]`; replace the whole "NO TEST MODE ROW. …"
paragraph with:

```lua
-- THE TEST MODE ROW (preview-mode, options-ui-§15, anti-pattern #80). Unlocking makes containers
-- draggable and leaves their live auras drawing (B1, 2026-09-19), so the unlocked view is no longer a
-- test mode and preview-mode's exception no longer applies: the placeholders have a switch of their
-- own. The composer emits it from `testModePath` beside Minimap button; it is a SESSION row bound to
-- NS.State.testMode through modules/Preview.lua's Preview.SetTestMode, the one writer `/am test` and
-- the launcher's left-click also use. Off after a reload, ended when combat starts, refused in
-- combat, and ended by Reset all settings (the row's default is false).
--
```

after `local DEBUG_CONSOLE_PATH = "state.debugConsole"` add

```lua
-- Session state, like the console row: the path names no stored leaf.
local TEST_MODE_PATH = "state.testMode"
```

add `    testModePath     = TEST_MODE_PATH,` after `minimapPath = MINIMAP_PATH,` in the
`H.MasterControls` spec; in the comment above `masterEffect`, "so its visibility pass alone shows or
drops the placeholders" → "so its visibility pass alone shows or drops the handles and outlines";
and inside the `for _, row in ipairs(masterRows) do` loop, after the `DEBUG_CONSOLE_PATH` block:

```lua
    if row.path == TEST_MODE_PATH then
        -- Bound to the one switch, which refuses a start in combat, sends the visibility pass
        -- itself and re-syncs this checkbox (a refused start reads false again).
        row.get = function() return NS.State.testMode end
        row.set = function(v) NS.Preview.SetTestMode(v) end
        row.default = false
        row.onChange = function() end
    end
```

`settings/Slash.lua` — the forward declaration line `local runResetPosition, runForgetTimed, runDebug, runPerf`
gains `, runTest`; in `NS.COMMANDS` the `unlock` entry and a new entry after it:

```lua
    {"unlock",        L["Unlock containers so they can be dragged"],
        function() runLock(false) end},
    {"test",          L["Toggle test mode: placeholder auras on every container — /am test [on|off]"],
        function(rest) runTest(rest) end},
```

insert above `function runPick()`:

```lua
-- `/am test` toggles; `on` / `off` set. Through Preview.SetTestMode, the switch the Master controls
-- checkbox and the launcher use, which refuses a start in combat with its own line.
local TEST_WORDS = { on = true, off = false }

function runTest(rest)
    local word = (rest or ""):match("^%s*(%S*)"):lower()
    local want = TEST_WORDS[word]
    if want == nil then
        if word ~= "" then return print(L["Usage: /am test [on|off]"]) end
        want = not NS.State.testMode
    end
    if NS.Preview.SetTestMode(want) then
        print(want and L["Test mode on — every container shows placeholder auras"] or L["Test mode off"])
    end
end
```

and replace `Sl.SetLocked` (its doc comment and the one-line function) with:

```lua
--- Toggle test mode -- what a bare `/am test` runs, published so the launcher's left click
--- (core/LauncherSetup.lua, rung (b)) drives the SAME switch and prints the same line. The mode lives
--- once, in NS.State.testMode, written only by Preview.SetTestMode.
function Sl.ToggleTestMode() runTest("") end
```

`core/LauncherSetup.lua` — replace the "RUNG (b) — THE PREVIEW SWITCH IS THE LOCK" paragraph and the
"RIGHT-CLICK ALWAYS OPENS THE PANEL" paragraph's first sentence pair with:

```lua
-- RUNG (b) — THE PREVIEW SWITCH IS THE TEST MODE (launcher-§2). This addon has no primary window;
-- its preview has a switch of its own since unlocking stopped previewing (B1, 2026-09-19): the
-- Master controls Test mode checkbox (settings/General.lua). Left-click therefore toggles test mode,
-- and it does so by calling the SAME host verb a bare `/am test` calls, which switches it through
-- modules/Preview.lua's Preview.SetTestMode — the one writer of NS.State.testMode. No copy of the
-- mode lives here; a second copy is the state that drifts on the next change.
--
-- RIGHT-CLICK ALWAYS OPENS THE PANEL, on every addon in the collection, which is what lets the left
-- button be spent on the test mode. Neither button is reassignable and there is no setting for either.
--
```

in `onClick`, the comment's first two lines become

```lua
    -- LEFT-CLICK, AND ITS PRESENCE IS THE RUNG. The same host verb a bare `/am test` runs, so the
    -- launcher, the verb and the Test mode checkbox are three doors onto one switch.
```

and its last three lines (`if NS.Slash and NS.Slash.SetLocked then` … `end`) become

```lua
        if NS.Slash and NS.Slash.ToggleTestMode then NS.Slash.ToggleTestMode() end
```

`settings/OptionsSetup.lua` — in the degradation stub's `Helpers.MasterControls`, replace the
four-line comment "No Test mode leaf: …" with

```lua
        -- The minimap leaf is emitted STORED rather than session-only, and the Test mode leaf
        -- session-only, because the live composer emits them that way: a row this build left out is
        -- a row `/am set` and the profile defaults would not know about, on the build whose panel
        -- will not open.
```

and add after the `if spec.minimapPath then … end` block:

```lua
        if spec.testModePath then
            leaves[#leaves + 1] = { leaf = "testMode", type = "bool", sessionOnly = true, path = spec.testModePath }
        end
```

(`tests/test_optionssetup.lua`'s "the degraded schema has every row the live one has" pins this.)

`locales/enUS.lua` — delete
`L["Unlock containers so they can be dragged (shows placeholder auras)"] = "Unlock containers so they can be dragged (shows placeholder auras)"`
and append:

```lua
L["Test mode can't start in combat."] = "Test mode can't start in combat."
L["Unlock containers so they can be dragged"] = "Unlock containers so they can be dragged"
L["Toggle test mode: placeholder auras on every container — /am test [on|off]"] = "Toggle test mode: placeholder auras on every container — /am test [on|off]"
L["Usage: /am test [on|off]"] = "Usage: /am test [on|off]"
L["Test mode on — every container shows placeholder auras"] = "Test mode on — every container shows placeholder auras"
L["Test mode off"] = "Test mode off"
```

- [ ] **Step 4: Run them and see them pass**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua 2>&1 | grep -A3 -E "\(B1\)|test mode|FAIL"`
Expected: every listed case PASSES, and nothing else fails but the docs citation cases. Re-point
with `/tmp/citefix.py`; two are `BY HAND`: `modules/Container.lua:434` in `docs/ARCHITECTURE.md:414`
and `docs/midnight-quirks.md:198` now point at the `callEngine(self.engine, "SetEnabled", on)` line
inside `ContainerClass:ApplyLive` (`grep -n 'SetEnabled", on)' modules/Container.lua`), and
`settings/Slash.lua:493` in `docs/slash-dispatch.md:9` points at the `RegisterChatCommand("am"` line.
Lizard: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lizard -l lua modules/Container.lua` — no
function above CCN 15 (ApplyVisibility was 19 at HEAD).

- [ ] **Step 5: Docs**

- `docs/ARCHITECTURE.md`: the Launcher table's Left click row (line 304) → "**Rung (b)**: toggles test
  mode, by calling `NS.Slash.ToggleTestMode` — the same host verb a bare `/am test` runs, which switches
  it through `Preview.SetTestMode`. The launcher holds no copy of the mode"; the Slash table gains a
  row `| /am test [on\|off] | Toggle test mode: placeholder auras on every container; refused in combat |`
  and the `/am unlock` row drops "(shows placeholder auras)"; wherever the Overview or Taint Notes say
  unlocking shows placeholders, say test mode does, and that unlocking keeps the live engine drawing
  under a drag handle and a faint outline.
- `docs/slash-dispatch.md:22-25`: the bullet becomes "**`test` has a second caller.** A bare `/am test`
  runs through `Sl.ToggleTestMode`, published for the launcher's left click (`core/LauncherSetup.lua`,
  rung (b), launcher-§2), so the minimap button, the verb and the General → Master controls *Test
  mode* checkbox are three doors onto one `Preview.SetTestMode` and print the same line."
- `docs/module-map.md`: the `core/State.lua` row lists `testMode`; the `modules/Preview.lua` row adds
  "the test mode switch (`Preview.SetTestMode`)"; the `core/LauncherSetup.lua` row: "Left-click toggles
  test mode (rung (b))".
- `docs/smoke-tests.md`: section C's steps that unlock to see placeholders now use `/am test`; item 88
  becomes "**Left-click = test mode.** Left-click the button → every container shows its placeholder
  auras without unlocking, and General → Master controls → **Test mode** ticks. Left-click again →
  they go and the checkbox unticks." Append to section S:

```markdown
104. **Unlock keeps live auras.** `/am unlock`: live auras keep drawing, and each container shows an
     outline and its handle; an EMPTY container can still be dragged by its handle.
105. **Test mode.** The Master controls checkbox and `/am test` show placeholders without unlocking.
     Pull a mob: test mode ends and the checkbox unticks. `/am test` in combat prints one gray line
     and starts nothing. The minimap left-click toggles it.
```

- `README.md` `## Usage`: "Type `/am unlock` and each one shows placeholder auras …" → "Type `/am unlock`
  to drag them (your live auras keep drawing, and an empty container shows a faint outline); `/am test`,
  or the Test mode box on General, shows placeholder auras on every container so you can see a style
  without waiting for real buffs."

- [ ] **Step 6: Checkpoint — run the green gate**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua && /home/tushar/.claude/wow-addon/bin/ka0s-bounded luacheck .`
Expected: 0 failed; `0 warnings / 0 errors`. Regenerate `docs/test-cases.md` and the README badge as in
Task 13 Step 7. Update the ledger. Do not commit.

---

### Task 15: B2a — LibKa0s v1.44.0: `O.IdList` `removeStyle = "icon"` (STOP before tag and push)

**Repo:** `/mnt/d/Profile/Users/Tushar/Documents/GIT/LibKa0s` — its own CLAUDE.md and
`docs/releasing.md` govern this task (library-stack-§7). Its gate, from **that** repo's root:
`/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua` (Lua 5.1) and
`/home/tushar/.claude/wow-addon/bin/ka0s-bounded luacheck .`. Nothing is committed, tagged or pushed here.

**Files (all under the LibKa0s repo):**
- Modify: `LibKa0s/OptionsWidgets.lua` — `WIDGETS_MINOR` (line 35) 20 → 21; after `ID_ICON_SIZE` (line 1802) three constants; a new `entryRemoveIcon` above `idLine` (line 2563); `idLine`; the `O.IdList` doc comment (line 2643)
- Create: `tests/test_options_idlist_remove.lua` — its own suite, because `tests/test_options_widgets.lua` is over layout-§1's 1500-line cap and tracked by issue #33 (CLAUDE.md, "Files over the 1500-line cap"); new cases on a seam of their own go to a file of their own, as v1.32.0's bulk cases did
- Modify: `tests/run.lua:68` (declare the suite after `test_options_idsuggest`)
- Create: `docs/api/Options/version-21.21.1.7.3-docs.md`; modify `docs/api/Options/version-21.20.1.7.3-docs.md` (Superseded) and `docs/api/README.md` (a row); generate `docs/api/Options/members-21.21.1.7.3.json`
- Modify: `CHANGELOG.md` (a `## v1.44.0` block), `docs/releasing.md` (the semver in the top table, line 7; the provenance template, line 201; a "Where v1.44.0 stands" paragraph after the v1.43.0 one, line 395), `README.md` (the `As of **v1.43.0**` MODULES paragraph, lines 202–207), `docs/test-cases.md` (regenerated)

**Interfaces:**
- Consumes: `O.IdList`'s existing internals — `callHost`, `rebuildIdList`, `idText`, `disableIfRender`, `O.AttachTooltip`, `entryAction`.
- Produces: `O.IdList(ctx, spec)` accepts `spec.removeStyle = "icon"`: every entry line is `[Icon X (0.06)] [InteractiveLabel (0.92)] [note?]`, the X wearing atlas `transmog-icon-remove` at 16px (also recorded on the widget as `x.__removeAtlas`, for a host's suite: a fake draws no art), tooltip `idText(spec, "remove")`, `OnClick` → `spec.onRemove(id)` then a rebuild; no right-hand action. Absent, byte-for-byte the v1.43.0 line. `LibStub("LibKa0s-Options-1.0").MODULES.OptionsWidgets == 21`; the Options version key is `21.21.1.7.3`.

- [ ] **Step 1: Write the failing suite**

Create `tests/test_options_idlist_remove.lua`:

```lua
-- tests/test_options_idlist_remove.lua — LibKa0s-Options-1.0's O.IdList `removeStyle = "icon"`
-- (OptionsWidgets minor 21): a small X at the LEFT of every entry in place of the right-hand Remove
-- button or checkbox, and a list drawn exactly as before when the key is absent.
--
-- Its own suite rather than more cases in tests/test_options_widgets.lua, which is over layout-§1's
-- cap and tracked by issue #33 (CLAUDE.md, "Files over the 1500-line cap"): new cases on a seam of
-- their own go to a file of their own, as v1.32.0's bulk cases did.

local T = _G.LK_TEST
local test, assertEqual, assertTrue, assertNil =
  T.test, T.assertEqual, T.assertTrue, T.assertNil
local Fixture = dofile("tests/fixture_options.lua")
local mocks = T.mocks

local panelSeq = 0

--- One IdList on a throwaway page, its spells known to the kit's id records; every callback logged.
local function listBench(entries, spec)
  local O = Fixture.new()
  panelSeq = panelSeq + 1
  local ctx = O.CreatePanel("IdListRemoveBench" .. panelSeq, "Bench " .. panelSeq, {})
  mocks.clearIdRecords()
  mocks.addIdRecord("spell", 21562, "Power Word: Fortitude", 135987)
  mocks.addIdRecord("spell", 774, "Rejuvenation", 136081)
  local log = { removed = {}, rebuilt = 0 }
  ctx.rebuild = function() log.rebuilt = log.rebuilt + 1 end
  spec = spec or {}
  spec.kind = "spell"
  spec.entries = function() return entries end
  spec.onAdd = function() end
  spec.onRemove = function(id)
    local n = #log.removed
    log.removed[n + 1] = id
  end
  return O, ctx, O.IdList(ctx, spec), log
end

test("IdList removeStyle icon: an X leads every line, then the name; no Remove button and no checkbox", function()
  local _, _, lines = listBench({ { id = 21562 }, { id = 774, toggle = true, on = true } }, { removeStyle = "icon" })
  for i, line in ipairs(lines) do
    local x, label = line.children[1], line.children[2]
    -- red under: idLine drawing the X after the name, or not at all
    assertEqual(x.type, "Icon", "line " .. i .. ": the X is first")
    assertEqual(x.__removeAtlas, "transmog-icon-remove")
    assertEqual(x.imageSize[1], 16)
    assertEqual(label.type, "InteractiveLabel")
    -- red under: entryAction still drawn under the icon style
    assertEqual(#line.children, 2, "line " .. i .. ": nothing on the right")
  end
  assertEqual(lines[1].children[2].text, "Power Word: Fortitude |cff808080(21562)|r")
end)

test("IdList removeStyle icon: a click on the X calls onRemove and rebuilds the list", function()
  local _, _, lines, log = listBench({ { id = 21562 }, { id = 774 } }, { removeStyle = "icon" })
  lines[2].children[1]:__fire("OnClick")
  -- red under: the X not wired to onRemove
  assertEqual(log.removed[1], 774)
  assertEqual(log.rebuilt, 1, "the list's shape changed, so it is drawn again")
end)

test("IdList removeStyle icon: the X's tooltip is the remove string, a host's override honored", function()
  local _, _, lines = listBench({ { id = 21562 } }, { removeStyle = "icon", strings = { remove = "Forget" } })
  local x = lines[1].children[1]
  -- red under: the X drawn with no tooltip (a bare icon says nothing about what it does)
  assertTrue(x.callbacks.OnEnter ~= nil, "a tooltip is attached")
  local shown = {}
  local tip = mocks.GameTooltip
  local setText = tip.SetText
  tip.SetText = function(_, text)
    local n = #shown
    shown[n + 1] = text
  end
  x:__fire("OnEnter")
  tip.SetText = setText
  assertEqual(shown[1], "Forget")
end)

test("IdList without removeStyle draws exactly as before: the name, then Remove or a checkbox", function()
  local _, _, lines = listBench({ { id = 21562 }, { id = 774, toggle = true, on = true } })
  -- red under: the icon style leaking into a list that did not ask for it
  assertEqual(lines[1].children[1].type, "InteractiveLabel")
  assertEqual(lines[1].children[1].relativeWidth, 0.78)
  assertEqual(lines[1].children[2].type, "Button")
  assertEqual(lines[2].children[2].type, "CheckBox")
  assertNil(lines[1].children[3])
end)
```

In `tests/run.lua`, `"test_options_idsuggest", "test_options_compose",` becomes
`"test_options_idsuggest", "test_options_idlist_remove", "test_options_compose",`.

- [ ] **Step 2: Run it and see it fail**

Run (in the LibKa0s repo): `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua 2>&1 | grep -A3 -E "IdList removeStyle|IdList without"`
Expected: the three `removeStyle icon` cases FAIL (`expected Icon, got InteractiveLabel`, and
`attempt to index … callbacks` on the tooltip case); "IdList without removeStyle draws exactly as
before" PASSES — it pins today's shape.

- [ ] **Step 3: Implement**

`LibKa0s/OptionsWidgets.lua`:

1. `local WIDGETS_MINOR = 20` → `local WIDGETS_MINOR = 21`.
2. After `  local ID_ICON_SIZE  = 16` add:

```lua
  -- `removeStyle = "icon"` (minor 21): an X at the LEFT of each entry, the atlas ConsumableMaster's
  -- delete button wears, about the size of the entry's own icon; the name takes the rest of the line.
  local ID_REMOVE_REL    = 0.06
  local ID_REMOVE_ATLAS  = "transmog-icon-remove"
  local ID_REMOVE_SIZE   = 16
```

3. Insert directly above `  local function idLine(ctx, spec, k, entry, line)`:

```lua
  --- The entry's X (`removeStyle = "icon"`, minor 21): a small Icon widget at the LEFT of the line,
  --- wearing ID_REMOVE_ATLAS, whose click calls onRemove and rebuilds the list once the host has
  --- removed the entry. Its tooltip is the `remove` string, so a host's `strings.remove` names it. A
  --- toggle entry is drawn no differently: under this style the host sends none.
  local function entryRemoveIcon(ctx, spec, entry, line)
    local x = O.AceGUI:Create("Icon")
    x:SetImageSize(ID_REMOVE_SIZE, ID_REMOVE_SIZE)
    local tex = x.image
    if type(tex) == "table" and tex.SetAtlas then tex:SetAtlas(ID_REMOVE_ATLAS) end
    x.__removeAtlas = ID_REMOVE_ATLAS   -- the art it wears, for a host's suite (a fake draws none)
    x:SetRelativeWidth(ID_REMOVE_REL)
    x:SetCallback("OnClick", function()
      if callHost(spec.onRemove, entry.id) then rebuildIdList(ctx) end
    end)
    O.AttachTooltip(x, idText(spec, "remove"), nil)
    disableIfRender(ctx, x)
    line:AddChild(x)
  end
```

4. Replace `idLine` whole with:

```lua
  local function idLine(ctx, spec, k, entry, line)
    local name, icon
    local iconStyle = spec.removeStyle == "icon"
    if type(k.info) == "function" then name, icon = k.info(entry.id) end
    if name == nil then loadEntry(ctx, k, entry.id) end
    if iconStyle then entryRemoveIcon(ctx, spec, entry, line) end
    local lbl = O.AceGUI:Create("InteractiveLabel")
    lbl:SetText(entryLabel(spec, k, entry.id, name))
    if icon then
      lbl:SetImage(icon)
      lbl:SetImageSize(ID_ICON_SIZE, ID_ICON_SIZE)
    end
    lbl:SetRelativeWidth(iconStyle and (ID_MAIN_REL + ID_ACTION_REL - ID_REMOVE_REL) or ID_MAIN_REL)
    entryTooltip(lbl, k, entry.id)
    line:AddChild(lbl)
    -- The note: a second line under the name, in the gray the id already uses, for a host that has
    -- something to say about this entry (why it is or is not drawn, say). Its own line rather than
    -- a suffix, because a note is a sentence and a name is a name.
    if type(entry.note) == "string" and entry.note ~= "" then
      local n = O.AceGUI:Create("Label")
      n:SetText(ID_GRAY .. entry.note .. "|r")
      n:SetRelativeWidth(ID_MAIN_REL)
      line:AddChild(n)
    end
    if not iconStyle then entryAction(ctx, spec, entry, line) end
  end
```

5. In the `O.IdList` doc comment, after the `toggleLabel` line add:

```lua
  ---   removeStyle = optional, minor 21: "icon" draws a small X at the LEFT of every entry (the
  ---                 `transmog-icon-remove` atlas, tooltip `remove`) in place of the right-hand
  ---                 Remove button or checkbox; a click calls onRemove and rebuilds. Absent, the list
  ---                 is drawn exactly as before;
```

- [ ] **Step 4: Run it — the suite passes, and the versioning gates fail as they must**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua 2>&1 | grep -A3 -E "IdList removeStyle|IdList without|FAIL"`
Expected: the four new cases PASS; three `versioning:` cases FAIL — "the changelog accounts for …
(got OptionsWidgets minor 21)", "every major's live version has its API document on disk (…
version-21.21.1.7.3-docs.md)", "… members-21.21.1.7.3.json is not on disk". Steps 5–6 are what turn
them green (docs/releasing.md steps 4–6).

- [ ] **Step 5: The API document (docs/releasing.md step 5)**

Copy `docs/api/Options/version-21.20.1.7.3-docs.md` to `docs/api/Options/version-21.21.1.7.3-docs.md`. In the **new** file:
- the title: `# \`LibKa0s-Options-1.0\` — version 21.21.1.7.3`;
- the header table: `Files and minors` shows `OptionsWidgets.lua` **21**; `Version key` drops its "The key gained a component at this version" sentence; `Shipped in` v1.44.0; `Status` **Current**; `Supersedes` `[version 21.20.1.7.3](./version-21.20.1.7.3-docs.md)`; `Superseded by` —; `Confirm in-game` reads `OptionsWidgets = 21`;
- rename the old `## What changed at this version` heading to `## Previously, at 21.20.1.7.3`, and put above it:

```markdown
## What changed at this version

**`O.IdList` gains one optional spec field, `removeStyle`, and nothing else moves.**
`OptionsWidgets.lua` 20 → **21**; every other file of the major is unchanged.

- **`removeStyle = "icon"` (W21)** draws a small **X** at the LEFT of every entry, before the entry's
  icon and name, in place of the right-hand *Remove* button or toggle checkbox. The X is an AceGUI
  `Icon` widget at `0.06` of the line wearing the client atlas `transmog-icon-remove` at 16px;
  the name takes `0.92`. A click calls `spec.onRemove(id)` and redraws the list exactly as *Remove*
  does. Its tooltip is the `remove` string, so a host's `strings.remove` names it. A toggle entry is
  drawn no differently under this style: a host that opts in sends no toggle entries.
- **Absent, the list is byte-for-byte what 21.20.1.7.3 drew**: the name at `0.78`, then *Remove* or
  a checkbox at `0.20`. No host sees a change until it opts in.

The previous version's "What changed" section follows unchanged under
[Previously, at 21.20.1.7.3](#previously-at-21201173).
```

- in the `### \`O.IdList(ctx, spec)\` → lines or \`nil\`` field table, after the `toggleLabel` row add:

```markdown
| `removeStyle` | **W21**. Optional. `"icon"` draws a 16px X (`transmog-icon-remove`) at the LEFT of every entry in place of the right-hand Remove button or checkbox; a click calls `onRemove` and rebuilds; its tooltip is the `remove` string. Absent, the list is drawn as before. |
```

In the **old** file: `Status` → Superseded; `Superseded by` → `[version 21.21.1.7.3](./version-21.21.1.7.3-docs.md)`; append:

```markdown
## Moving to version 21.21.1.7.3

One optional `O.IdList` spec field, `removeStyle` (**W21**), in LibKa0s v1.44.0: `"icon"` draws a
small X at the left of each entry in place of the right-hand Remove button or checkbox. A host that
does not pass it draws exactly what it drew here. See
[version 21.21.1.7.3](./version-21.21.1.7.3-docs.md).
```

In `docs/api/README.md`, replace the 21.20.1.7.3 row with the two rows:

```markdown
| [21.21.1.7.3](./Options/version-21.21.1.7.3-docs.md) | `Options.lua` 21 · `OptionsWidgets.lua` 21 · `OptionsTabs.lua` 1 · `OptionsCompose.lua` 7 · `OptionsScroll.lua` 3 | v1.44.0 | **Current** |
| [21.20.1.7.3](./Options/version-21.20.1.7.3-docs.md) | `Options.lua` 21 · `OptionsWidgets.lua` 20 · `OptionsTabs.lua` 1 · `OptionsCompose.lua` 7 · `OptionsScroll.lua` 3 | v1.39.0 – v1.43.0 | Superseded |
```

Then regenerate the manifests: `lua tools/gen-api-members.lua` (writes `docs/api/Options/members-21.21.1.7.3.json`; never hand-edit it).

- [ ] **Step 6: CHANGELOG, the version-bearing lines, the case list (docs/releasing.md steps 4, 6, 7)**

`CHANGELOG.md` — insert above `## v1.43.0 — 2026-09-17`:

```markdown
## v1.44.0 — 2026-09-19

Versions in this release: **OptionsWidgets minor 21** (`LibKa0s-Options-1.0` 21.21.1.7.3). Every
other major is unchanged from v1.43.0, and the kit stays at revision 23.

**`O.IdList` can draw its remove control as an X on the left.** A new optional spec field,
`removeStyle = "icon"`, draws a small X (the client's `transmog-icon-remove` atlas, 16px) at the LEFT
of every entry, before its icon and name, in place of the right-hand *Remove* button or toggle
checkbox. A click calls `onRemove` and redraws the list; the tooltip is the `remove` string, so a
host's `strings.remove` names it. Opt-in: a list that does not pass the field is drawn exactly as at
v1.43.0, so no consumer's look changes until it adopts. Aura Master's spell lists are the first
adopter. Cases: `tests/test_options_idlist_remove.lua` (its own suite: `tests/test_options_widgets.lua`
is over the layout-§1 cap, issue #33).
```

`docs/releasing.md`: the top table's `Repo semver (\`v1.43.0\`)` → `v1.44.0`; the provenance
template `> Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.43.0 (MIT).` → `v1.44.0`;
after the "**Where v1.43.0 stands (2026-09-17).**" paragraph add:

```markdown
**Where v1.44.0 stands (2026-09-19).** One LibStub minor moves — `OptionsWidgets.lua` 21
(`LibKa0s-Options-1.0` 21.21.1.7.3) — and the kit stays at revision 23. What a consumer owes: the
copy of both payloads and the provenance line; nothing more unless it adopts `removeStyle`, which
Aura Master does on its spell lists.
```

`README.md`: `As of **v1.43.0**` → `As of **v1.44.0**`, and in that paragraph `OptionsWidgets = 20` →
`OptionsWidgets = 21`. Check the standards pointer as step 7 says (`head -1 ../WowAddonStandards/standards/STANDARDS.md`
against `grep -n 'v2\.' CLAUDE.md README.md`); move it only if they disagree, reading the standard's
changelog between the two when they do.
Regenerate the case list: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua --list > docs/test-cases.md`.

- [ ] **Step 7: Checkpoint — the LibKa0s green gate**

Run (LibKa0s root): `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua && /home/tushar/.claude/wow-addon/bin/ka0s-bounded luacheck .`
Expected: `… passed, 0 failed, 0 skipped …` (the three versioning cases green; `test_prose`'s US
spelling and `test_layout_cap`'s census unchanged) and `0 warnings / 0 errors`. `git status --short`
lists exactly `CHANGELOG.md`, `LibKa0s/OptionsWidgets.lua`, `README.md`,
`docs/api/Options/version-21.20.1.7.3-docs.md`, `docs/api/README.md`, `docs/releasing.md`,
`docs/test-cases.md`, `tests/run.lua`, and the new `docs/api/Options/members-21.21.1.7.3.json`,
`docs/api/Options/version-21.21.1.7.3-docs.md`, `tests/test_options_idlist_remove.lua`.

- [ ] **Step 8: STOP — owner go-ahead required**

Do **not** commit, run `tests/_kit/run-automated-tests.sh --release 1.44.0`, tag or push. Hand the
owner the file list, the gate result, and the remaining release steps from `docs/releasing.md` step 7
on (commit the release; `--release 1.44.0` on a clean tree; commit the bundle; tag `v1.44.0` on that
commit; push when they choose). Tasks 16 and 17 wait until `git -C /mnt/d/Profile/Users/Tushar/Documents/GIT/LibKa0s tag -l v1.44.0`
prints `v1.44.0`. Ledger: "15 — done, awaiting the owner's release".

---

### Task 16: B2b — re-vendor LibKa0s v1.44.0 into Aura Master

**Precondition:** Task 15 released by the owner — `git -C /mnt/d/Profile/Users/Tushar/Documents/GIT/LibKa0s tag -l v1.44.0`
prints `v1.44.0`, and `git -C /mnt/d/Profile/Users/Tushar/Documents/GIT/LibKa0s status --porcelain` prints nothing.

**Files:**
- Replace whole: `libs/LibKa0s/` (from the LibKa0s repo's `LibKa0s/` at `v1.44.0`), `tests/_kit/` (from its `testkit/` at `v1.44.0`)
- Modify: `CLAUDE.md` — the provenance line `Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.43.0 (MIT).` → `v1.44.0`, **in the same step as the copy**
- Modify: `DEPENDENCIES.md` / `README.md` only where they quote the bundled version (`grep -rn 'v1\.43\.0' --include=*.md . | grep -v '^./docs/\(audits\|reviews\|automated-tests\)/'`)

**Interfaces:**
- Consumes: the tag `v1.44.0`.
- Produces: `NS.Helpers.IdList` honors `removeStyle = "icon"` (Task 17). No other surface moves: every major but Options is byte-identical, and the kit stays at revision 23.
- What `tests/test_vendor_sync.lua` asserts (`tests/_kit/vendor_sync.lua`): `libs/LibKa0s/` and `tests/_kit/` are byte-identical (after stripping CR from the working tree) to `git show v1.44.0:LibKa0s/…` / `git show v1.44.0:testkit/…` in the sibling `../LibKa0s`, with the tag read from **this repo's CLAUDE.md provenance line**; and that `tests/_kit/run-automated-tests.sh` is recorded `100755` in this repo's git index. With the sibling present it runs for real (no SKIP).

- [ ] **Step 1: See the gate red on the provenance line first**

Change only `CLAUDE.md`'s provenance line to `v1.44.0` and run
`/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua 2>&1 | grep -A3 "LibKa0s release CLAUDE.md says"`.
Expected: FAIL — `OptionsWidgets.lua matches the library repo at v1.44.0 — re-vendor from the tag, do not edit ./libs/LibKa0s`.

- [ ] **Step 2: Copy both payloads whole, from the tag's clean checkout**

```bash
LK=/mnt/d/Profile/Users/Tushar/Documents/GIT/LibKa0s
test "$(git -C "$LK" describe --tags --exact-match)" = v1.44.0 || { echo "LibKa0s is not at v1.44.0"; exit 1; }
test -z "$(git -C "$LK" status --porcelain)" || { echo "LibKa0s tree is dirty"; exit 1; }
rm -rf libs/LibKa0s tests/_kit
mkdir -p libs/LibKa0s tests/_kit
cp -r "$LK/LibKa0s/." libs/LibKa0s/
cp -r "$LK/testkit/." tests/_kit/
```

The LibKa0s working tree is CRLF-pinned like this one (and `*.sh` LF in both), so the copy lands with
the terminators this repo's `.gitattributes` declares. Never copy single files (library-stack-§7:
whole folders, every time). The index's `100755` on `tests/_kit/run-automated-tests.sh` is untouched
by a copy; do not stage anything.

- [ ] **Step 3: Run the gate and see it pass**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua 2>&1 | grep -A3 -E "vendor|runner is recorded|eol:|FAIL"`
Expected: both vendor-sync cases PASS (not SKIP), "the automated-test runner is recorded executable
(100755)" PASSES, `eol:` PASSES, no FAIL. The Filters and General spell-list cases still pass: nothing
here opts in yet.

- [ ] **Step 4: Checkpoint — run the green gate**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua && /home/tushar/.claude/wow-addon/bin/ka0s-bounded luacheck .`
Expected: 0 failed; `0 warnings / 0 errors`. Update the ledger. Do not commit (the owner commits the
copy and the provenance line together).

---

### Task 17: B2c — every spell list draws an X on the left; Restore moves to the top

**Files:**
- Modify: `settings/GeneralSpells.lua` — header sketch and paragraph (lines 6–22), `entriesFor` (lines 117–130), `renderSpells` (lines 262–304)
- Modify: `settings/Filters.lua:558-575` (`overrideList`'s `H.IdList` spec)
- Modify: `locales/enUS.lua` (two keys replaced)
- Modify: `docs/settings-panel.md` (the General → Spell Categories and Filters → Overrides descriptions), `docs/smoke-tests.md` (section S)
- Test: `tests/test_pages_general.lua` (the `entry` helper, lines 265–279, and five cases), `tests/test_pages_filters.lua` (the `entry` helper, lines 58–70, and one case)

**Interfaces:**
- Consumes: LibKa0s v1.44.0's `removeStyle = "icon"` (Task 16).
- Produces: General → Spell Categories: `entriesFor(def)` lists the starters not stored `false`, then the added spells, none a toggle; `onRemove(id)` stores `false` for a starter and `nil` for an added spell; `onToggle` is gone; the Restore button is drawn under the Category dropdown, above the Add line. Filters → Overrides lists pass `removeStyle = "icon"`; their behavior is unchanged.

- [ ] **Step 1: Write the failing tests**

`tests/test_pages_general.lua` — replace the `entry` helper with:

```lua
--- The line an IdList drew for spell `id`: its label, and the X at the line's left
--- (`removeStyle = "icon"`, B2).
local function entry(ws, id)
    for _, w in ipairs(ws) do
        local lbl = w.children and w.children[2]
        if lbl and lbl.type == "InteractiveLabel" then
            local t = lbl.text or ""
            if t:find("(" .. id .. ")|r", 1, true) or t == "Unknown spell " .. id then
                return lbl, w.children[1]
            end
        end
    end
    return nil
end
```

and replace these cases whole (matched by name): "general → spell categories: every starter is a
toggle entry, ticked; nothing is removable yet":

```lua
test("general → spell categories: every starter is listed with an X on its left, and no checkbox (B2)", function()
    local NS, _, P, ws = spells()
    local want = starterIds(NS, "defensives")
    for _, id in ipairs(want) do
        local _, x = entry(ws, id)
        -- red under: the list without removeStyle = "icon", or starters sent as toggle entries
        assertTrue(x ~= nil and x.type == "Icon", "an X beside starter " .. id)
    end
    assertEqual(#P.all(ws, "CheckBox"), 0, "no checkboxes")
    assertEqual(#P.all(ws, "Button", NS.L["Remove"]), 0, "no Remove buttons")
    assertTrue(P.find(ws, "EditBox", NS.L["Add a spell"]) ~= nil, "the add line is drawn")
end)
```

"general → spell categories: adding by id writes categorySpells whole through the seam, and Remove takes it off":

```lua
test("general → spell categories: adding by id writes categorySpells whole through the seam, and its X takes it off", function()
    local NS, _, P, ws = spells()
    NS.SetByPath("categorySpells", { raidCDs = { [99] = true } })
    local paths = spyPaths(NS)
    P.find(ws, "EditBox", NS.L["Add a spell"]):__fire("OnEnterPressed", "424242")
    local edits = NS.db.profile.categorySpells
    -- red under: onAdd writing anything but the whole profile set at `categorySpells`
    assertEqual(table.concat(paths, ","), "categorySpells")
    assertEqual(edits.defensives[424242], true)
    assertEqual(edits.raidCDs[99], true, "another category's edits are kept")
    assertNil(NS.Database.FindContainer(1).filter.categorySpells, "no container keeps its own copy")
    ws = P.rerender("General")
    local lbl, x = entry(ws, 424242)
    assertTrue(lbl ~= nil, "the added spell is listed")
    assertEqual(lbl.text, "Unknown spell 424242", "by id where the client cannot name it")
    x:__fire("OnClick")
    -- red under: onRemove storing false for an added spell (it would linger as an edit)
    assertNil(NS.db.profile.categorySpells.defensives, "no edit left to store")
end)
```

"general → spell categories: unticking a starter stores false; ticking it or adding it again drops the edit":

```lua
test("general → spell categories: a starter's X stores false and drops it from the list; adding it again drops the edit (B2)", function()
    local NS, _, P, ws = spells()
    local id = starterIds(NS, "defensives")[1]
    local _, x = entry(ws, id)
    x:__fire("OnClick")
    -- red under: a starter's X storing nil (the starter list would put it straight back)
    assertEqual(NS.db.profile.categorySpells.defensives[id], false)
    ws = P.rerender("General")
    -- red under: entriesFor still listing a removed starter
    assertNil(entry(ws, id), "a removed starter is off the list")
    P.find(ws, "EditBox", NS.L["Add a spell"]):__fire("OnEnterPressed", tostring(id))
    -- red under: onAdd storing `true` for a starter (an addition that duplicates the shipped spell)
    assertNil(NS.db.profile.categorySpells.defensives, "adding a removed starter back includes it again")
end)
```

"general → spell categories: Restore this category's starter list clears that category's edits and no other's":

```lua
test("general → spell categories: Restore sits above the Add line and clears that category's edits and no other's (B2)", function()
    local NS, _, P = spells()
    NS.SetByPath("categorySpells", { defensives = { [118038] = false, [424242] = true }, raidCDs = { [99] = true } })
    local ws = P.rerender("General")
    local restore = P.find(ws, "Button", NS.L["Restore this category's starter list"])
    local at = {}
    for i, w in ipairs(ws) do
        if w == restore then at.restore = i end
        if w.type == "EditBox" and w.labelText == NS.L["Add a spell"] then at.add = i end
    end
    -- red under: the restore still drawn under the list (a removed starter has no way back in view)
    assertTrue(at.restore < at.add, "Restore above Add a spell")
    restore:__fire("OnClick")
    local edits = NS.db.profile.categorySpells
    -- red under: the restore writing an empty set for every category
    assertNil(edits.defensives)
    assertEqual(edits.raidCDs[99], true)
end)
```

(the case "choosing another category lists its starters, by name where the client knows them" needs
no edit beyond the new `entry` helper.)

`tests/test_pages_filters.lua` — replace the `entry` helper with:

```lua
--- The line an IdList drew for spell `id`: its label, and the X at the line's left
--- (`removeStyle = "icon"`, B2).
local function entry(ws, id)
    for _, w in ipairs(ws) do
        local lbl = w.children and w.children[2]
        if lbl and lbl.type == "InteractiveLabel" then
            local t = lbl.text or ""
            if t:find("(" .. id .. ")|r", 1, true) or t == "Unknown spell " .. id then
                return lbl, w.children[1]
            end
        end
    end
    return nil
end
```

and in "filters: Overrides adds to one list at a time by id or by name, and Remove takes an id off"
replace `    assertEqual(remove.text, NS.L["Remove"])` with:

```lua
    -- red under: the Overrides list without removeStyle = "icon" (a Remove button on the right)
    assertEqual(remove.type, "Icon")
```

- [ ] **Step 2: Run them and see them fail**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua 2>&1 | grep -A3 -E "spell categories|Overrides adds" | head -40`
Expected: FAIL — "an X beside starter 498", "the added spell is listed", "a removed starter is off the
list", "Restore above Add a spell", and the Overrides case `expected Icon, got nil` (the lists still
draw the label first and Remove on the right).

- [ ] **Step 3: Implement**

`settings/GeneralSpells.lua`: the header sketch becomes

```lua
--     Spell Categories  [Category ▾]  -- one of the nine spell-list categories, or Weapon enchants
--                       [Restore this category's starter list]
--                       [Add a spell ____________________________][ Add ]
--                       (X) <icon> Ironbark (102342)             <- a starter, until its X hides it
--                       (X) <icon> A spell you added (424242)
```

and the paragraph under it:

```lua
-- SPELL CATEGORIES is bespoke: the category dropdown, the restore, then the library's IdList over that
-- category's edits, drawn with an X at the left of every entry (`removeStyle = "icon"`, LibKa0s
-- v1.44.0; B2, 2026-09-19). The edits live at the ABSOLUTE path `categorySpells`
-- ({ [categoryKey] = { [spellId] = true | false } }), a carve-out written whole through the seam
-- (settings/Schema.lua), so an edit here re-applies every container. A starter the player removes is
-- stored `false` (nil would let the shipped list bring it back) and drops out of the list until
-- Restore (or typing it back in) returns it; a spell the player adds is stored `true`, and
-- the carve-out's normalizer stores no category left with no edits. The lists are not schema rows, so
-- the page's Defaults leaves them alone, as the Filters page's leaves its Overrides lists; each
-- category has its own restore.
```

Replace `entriesFor` and its doc comment with:

```lua
--- The list's entries: the starters the player has not removed, in id order, then the spells the
--- player added. Every one carries the X (removeStyle = "icon"); none is a toggle.
local function entriesFor(def)
    local mine, starters, out = editsOf(def.key), def.spells or {}, {}
    for _, id in ipairs(sortedIds(starters)) do
        if mine[id] ~= false then
            local n = #out
            out[n + 1] = { id = id }
        end
    end
    for _, id in ipairs(sortedIds(mine)) do
        if mine[id] == true and not starters[id] then
            out[#out + 1] = { id = id }
        end
    end
    return out
end
```

In `renderSpells`, replace from the `H.TextRow(ctx, L["The spells each category matches, …` line to the
end of the function with:

```lua
    H.TextRow(ctx, L["The spells each category matches, shared by every container. Click X to leave one out, or add your own; Restore brings the starter list back. Blizzard only honors spell lists for buffs on friendly units."])
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
    H.IdList(ctx, {
        kind       = "spell",
        removeStyle = "icon",
        label      = L["Add a spell"],
        tooltip    = ID_TOOLTIP,
        strings    = ID_STRINGS,
        candidates = candidates,
        entries    = function() return entriesFor(def) end,
        -- Adding a starter back includes it again (drops its `false`); anything else is an addition.
        onAdd = function(id)
            editCategory(key, function(mine)
                if def.spells and def.spells[id] then mine[id] = nil else mine[id] = true end
            end)
        end,
        -- A starter is hidden (`false`, so the shipped list does not bring it back); an added spell
        -- is forgotten.
        onRemove = function(id)
            editCategory(key, function(mine)
                if def.spells and def.spells[id] then mine[id] = false else mine[id] = nil end
            end)
        end,
    })
end
```

`settings/Filters.lua` — in `overrideList`'s `H.IdList` spec, after `kind = "spell",` add:

```lua
        -- Every spell list in the addon draws its remove control the same way (B2).
        removeStyle = "icon",
```

`locales/enUS.lua` — replace the two keys (delete the old lines, add the new ones):

```lua
L["The spells each category matches, shared by every container. Click X to leave one out, or add your own; Restore brings the starter list back. Blizzard only honors spell lists for buffs on friendly units."] = "The spells each category matches, shared by every container. Click X to leave one out, or add your own; Restore brings the starter list back. Blizzard only honors spell lists for buffs on friendly units."
L["Forget every edit to this category: its removed starter spells come back and the spells you added are removed. Other categories keep theirs."] = "Forget every edit to this category: its removed starter spells come back and the spells you added are removed. Other categories keep theirs."
```

(the old keys: "…Untick one to leave it out, or add your own. Blizzard only honors…" and "…its
starter spells are ticked again and the spells you added are removed…").

- [ ] **Step 4: Run them and see them pass**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua 2>&1 | grep -A3 -E "spell categories|Overrides|locale:|FAIL"`
Expected: PASS throughout; `locale:` green (the two old keys are gone from the source and the file).

- [ ] **Step 5: Docs**

`docs/settings-panel.md`: in the General → Spell Categories description, "a checkbox beside each
starter … Remove beside an added spell … Restore under the list" becomes "an X at the left of every
entry (a starter's X hides it, stored `false`; an added spell's X forgets it), and **Restore this
category's starter list** at the top, under the Category dropdown and above Add a spell"; in the
Filters → Overrides description, "Remove" → "an X at the left of each entry". `docs/smoke-tests.md`
section S, append:

```markdown
106. **Spell lists.** General → Spell Categories: an X on the left of every row and no checkboxes.
     X on a starter hides it; Restore, at the top, brings it back. Filters → Overrides lists show
     the X too, and it removes the spell.
```

- [ ] **Step 6: Checkpoint — run the green gate**

Run: `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua && /home/tushar/.claude/wow-addon/bin/ka0s-bounded luacheck .`
Expected: 0 failed; `0 warnings / 0 errors`. Update the ledger. Do not commit.

---

### Task 18: The final gate, the inventory, lizard — and hand back to the owner

**Files:**
- Modify: `docs/smoke-tests.md` (section S: items 107–108, the B3 and B4 checks)
- Regenerate: `docs/test-cases.md`; modify `README.md` line 7 (the Tests badge)
- Nothing else: this task changes no code

**Interfaces:**
- Consumes: Tasks 1–17 (Task 16–17 only once the owner released LibKa0s v1.44.0; if they have not, run this task with 16–17 still `todo` and say so in the hand-back).
- Produces: a verified working tree and a hand-back report. **No commit, no tag, no push, no version bump.**

- [ ] **Step 1: The last two smoke checks**

Append to `docs/smoke-tests.md` section S:

```markdown
107. **The "Not in use" note** heads every tab of Bars, Icons and Text in muted gold, not gray, on a
     container drawn in another style.
108. **A long buff's time on a bar.** A 59-minute Power Word: Fortitude on a default bar reads
     `59 m` in full, not `59...`, and still does with the time text's X offset at -15.
```

- [ ] **Step 2: The whole battery, bounded**

Run each from the repo root and read every result:

```bash
/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua
/home/tushar/.claude/wow-addon/bin/ka0s-bounded luacheck .
/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/perf.lua
/home/tushar/.claude/wow-addon/bin/ka0s-bounded lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .
```

Expected: `… passed, 0 failed …` (with LibKa0s v1.44.0 tagged beside this repo, `2 skipped` becomes
0: the vendor-sync cases run for real); `0 warnings / 0 errors`; perf exits 0 with a `restyleText`
row; and lizard lists **no function above CCN 15** — check with
`/home/tushar/.claude/wow-addon/bin/ka0s-bounded lizard -l lua -x "./libs/*" -x "./tests/_kit/*" . | awk '$2+0 > 15 && NF > 5'`,
which must print nothing (the HEAD offender, `ContainerClass:ApplyVisibility` at CCN 19, was split in
Task 14).

- [ ] **Step 3: The inventory and the badge**

`/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua --list > docs/test-cases.md`, then set
README line 7 to `![Tests](https://img.shields.io/badge/Tests-N%2FN_passing-green)` with N the
`| **Total** | **N** |` the regenerated file ends with. Run the suite once more (the docs cases read
both).

- [ ] **Step 4: The working tree, as the owner will see it**

`git status --short` and `git diff --stat`. Expected: only the files this plan names, plus
`docs/midnight-quirks.md` (it carried the owner's own uncommitted block before this plan started — confirm
that block is intact: `git diff docs/midnight-quirks.md | grep -c 'Measured in-game, client 12.1.0 (120100), 2026-09-18'`
prints 1) and `docs/superpowers/specs/2026-09-18-text-style-design.md` (untracked before this plan).
Nothing staged: `git diff --cached --stat` prints nothing.

- [ ] **Step 5: Hand back to the owner**

Report, in this order, and stop:
1. The four suite results from Step 2 (counts, lint, the perf table's `restyleText` row, lizard's top CCN).
2. The files changed, grouped as Part A (Tasks 4–13) and Part B (Tasks 1–3, 14, 16–17), and the LibKa0s state (Task 15: released and tagged by the owner, or still awaiting).
3. The in-game checks owed: `docs/smoke-tests.md` section S, items 94–108.
4. The owner's decisions: whether and how to commit (this plan never commits — CLAUDE.md), when to close issue #2, and whether to cut a release (the version is **not** bumped).

---
