# Feedback batch 5 — design spec

- **Date:** 2026-09-13
- **Branch:** `feat/2026-09-13-feedback-batch5` (AuraMaster); sibling branches of the same name in
  LibKa0s, ConsumableMaster, BankLedger, LootHistory
- **Source:** the owner's in-game feedback of 2026-09-13 (General, Containers, Filters, Layout, Bars,
  Icons pages), plus four decisions taken in the brainstorm (section 2)
- **Plan:** `docs/superpowers/plans/2026-09-13-feedback-batch5.md` (checkpointed, resumable)

Every requirement below has an ID (`C-3`, `B-4`, …) that the plan, the commits and the tests cite.

## 1. Goals

1. Restructure the panel: the Containers page goes away. Its identity controls move to
   **General → Containers**, the spell lists to **General → Spell Categories**, and dispel colors
   to **General → Dispel Colors**.
2. Replace the dropdown-heavy **Filters → Categories** tab with a Default / Whitelist / Blacklist grid.
3. Add a shared **ID list** widget (by id or by name, spells or items) to LibKa0s. Adopt it in AM,
   ConsumableMaster, BankLedger and LootHistory.
4. Make **Layout** honest about anchoring. Controls that do not apply to the current attach mode are
   dimmed and disabled. An attached container inherits its parent's flow.
5. Fix every reported defect at its root cause, each one pinned by a failing-first test.

## 2. Decisions (taken 2026-09-13; do not re-litigate)

| # | Decision |
|---|---|
| D1 | **General → Containers carries its own Container picker and New container inside the tab body.** This is an accepted deviation from options-ui-§14, recorded as a row in `docs/ARCHITECTURE.md` → Documented deviations (text in section 9) |
| D2 | **Spell lists become profile-wide.** They are shared by every container and edited on General → Spell Categories. A schema-v2 migration merges today's per-container edits (section 7) |
| D3 | **An attached container inherits its parent's flow.** Fill, horizontal growth and vertical growth come from the parent container, and point and relative point are derived so the child continues the parent's flow. Only the X and Y offsets stay editable |
| D4 | **The ID list widget ships in LibKa0s and is adopted in AM, ConsumableMaster, BankLedger and LootHistory in this effort.** It resolves spells and items |
| D5 | **The category grid is a LibKa0s widget (`ChoiceGrid`), not host layout code.** options-ui-§6 forbids per-panel layout code in a host, and a library widget keeps AM conformant with no deviation |

## 3. The panel after this change

| Page | Tabs (in order) |
|---|---|
| General | Master controls · Display · Containers · Spell Categories · Dispel Colors |
| ~~Containers~~ | *removed* |
| Filters | What to show · Categories · Sorting · Overrides |
| Layout | Frame · Anchor · Growth · Mouse |
| Bars | Size · Bar · Icon · Background & border · Name text · Time text · Stack text · Highlights |
| Icons | Size · Border · Cooldown · Time text · Stack text · Highlights |
| Profiles | unchanged |

Every string that points at "the Containers page" is rewritten to point at General → Containers:
the Bars and Icons notices, the empty-registry lines in `settings/OptionsSetup.lua` and
`settings/Schema.lua`, and the locale keys. `NS.OpenOptionsPage` keys and every test that names
the `containers` page move with it.

## 4. Requirements

### General page

**G-1 General → Containers tab** (feedback Containers #1, #2)
- The tab body opens with a Container picker and a **New container** button on one row, followed by
  Name, Enabled, Unit, Aura type and Style (the five `container.*` identity rows, now with
  `page = "general"`, `group = "Containers"`). After those come **Duplicate** and **Delete**, then
  **Copy settings from** (source, what, copy), as today.
- The Overview tab is deleted with its renderer and strings.
- The Containers page registration (`settings/Containers.lua`) is removed. The file becomes the
  Containers tab's builder, or its content moves into `settings/General.lua`. The plan picks
  whichever keeps each file under the complexity gate.
- `General`'s renderer gains bespoke-tab support (Containers, Spell Categories and Dispel Colors
  mix schema rows with bespoke content). If `RenderTabbedSchema` cannot take bespoke tabs, General
  renders through the same tab-collect / active-tab path the container pages use
  (`Helpers.RenderContainerPage`'s `collectTabs` / `renderActiveTab`), generalized for a page
  without a banner.
- The General **Defaults** button stays page-wide (options-ui-§13). It now also restores the
  selected container's Enabled, Unit, Aura type and Style, and its tooltip says so.
  **`container.name` is never reset** (owner, 2026-09-13): a name has no meaningful default. The
  row is excluded from both the page's Defaults and Reset all through a row flag the restore walk
  honors (`noDefault = true`, or the library's existing equivalent if one exists). The name row
  keeps its template default only for the backfill.
- **Acceptance:** the tab draws the picker and New; selecting a container re-points every page;
  the Containers page no longer registers; `/am` verbs are unchanged.

**G-2 General → Spell Categories tab** (feedback Filters #1)
- One category at a time, chosen from a dropdown of the spell categories, then that category's ID
  list (X-1) showing starter spells (checkbox: on = included, off = removed) and added spells
  (Remove), plus **Restore this category's starter list**.
- Storage is profile-wide: `profile.categorySpells[categoryKey] = { [spellId] = true | false }`
  (D2), written whole through the seam at the absolute path `categorySpells` (a carve-out, as
  `container.filter.categorySpells` is today).
- `FilterCompiler.Compile` reads spell edits from the profile, no longer from the container.
- **Healing merge:** `coreHealing` and `lesserHealing` become one spell category, **`healing`**
  ("Healing", "Heal-over-time effects, shields and beacons."), holding the union of both starter
  lists. The migration is in section 7.
- **Acceptance:** an edit made on General → Spell Categories changes what every container using
  that category shows; the Filters page has no Spell lists tab.

**G-3 General → Dispel Colors tab** (feedback Bars #6)
- Six palette swatches (`dispelColors.Magic` … `.None`), profile-wide at
  `profile.dispelColors`, with no class-color companion (the options-ui-§17 palette exemption, as
  today).
- Both styles read them. A bar colored by dispel type uses them, and so does the icon's dispel
  border when the engine's `Border` dispel style accepts a `customDispelColorMap` (verify in
  `Blizzard_CustomAuraContainer`; if it does not, icons keep Blizzard's art and the tab says the
  colors apply to bars).
  Amended 2026-09-13 (owner): icons show Blizzard's own dispel border art, with no
  `customDispelColorMap` (the engine only tints its colored atlas). The colors drive bars only, and
  the tab text and each row's desc say so.
- Writing a dispel color re-applies every container (a global row, `effect` absent).
- `container.bars.dispelColors` is removed from the template and from stored containers by the v2
  migration (section 7).

### Containers (bugs)

**C-3 Deleting a container loses the picker and New container** (feedback Containers #3)
- Reproduce headlessly first: render the page, run the Delete popup's `OnAccept`, and flush the
  coalesced refresh. Then assert that the picker and button widgets are alive and parented, and
  that the chrome ledger is correct across the two renders (the popup's immediate
  `RefreshAllPanels` plus `CONTAINERS_CHANGED`'s next-frame refresh).
- Moving the controls into the General tab body (G-1) removes the chrome-block path. The test still
  runs against the new home, and passes only if both the picker and New survive a delete.

**C-4 Duplicate a bar container, switch it to icons → `Style_Icons.lua:80` nil `cd`** (feedback
Containers #4)
- **Root cause (confirmed by reading):** preview frames are pooled per container
  (`modules/Preview.lua:65`). A frame dressed as a bar keeps `frame.__am` built by
  `Style_Bars.build`, which has no `cd`. After the style switch, `Icons.Apply` reuses the stale
  `__am` (`frame.__am or build(frame)`), so `applyCooldown(am.cd)` raises. The error escapes
  through `Preview.Show` → `Container:ApplyVisibility` → `Container:Apply`, which stops that apply
  pass partway. That is one path behind B-5. A new container does not hit it because it has no
  pooled preview frames until it is unlocked.
- **Fix:** tag `__am` with the style that built it. A styler that finds a foreign `__am` hides that
  style's regions and builds its own. Keep one preview pool per style as a second guard, so a
  switch never reuses a frame across styles.
- **Acceptance:** a test that dresses a bar preview, switches `style` to icons and re-applies,
  written first and failing, then passing. The same test in the icons → bars direction.

### Filters page

**F-1 Categories tab redesign** (feedback Filters #2)
- Two sections. **Blizzard Categories** (renamed from "Blizzard flags") comes first. **Custom
  Categories** (renamed from "Spell lists", buff containers only) comes second. Today each shows up
  twice because the category rows interleave kinds; the new form draws each section once. On a
  debuff container, **Dispel Types** and **Who Cast It** stay as their own sections below Blizzard
  Categories.
- Each section is one `ChoiceGrid` (X-2): a header line `Default · Whitelist · Blacklist ·
  Category`, then one line per category with three radio cells and the label. The label's tooltip
  is the category's description.
- Stored values are unchanged (`""` / `"show"` / `"hide"`). Only the labels change:
  `CATEGORY_STATE_LABELS` becomes `"" = Default`, `show = Whitelist`, `hide = Blacklist`, and
  `/am get|list` print the new words.
- The category rows stay in the schema, so `/am set`, Defaults and resets still see them. They
  carry `skipRender` (options-ui-§6), and the Categories tab draws them through the grid.
- **Acceptance:** one heading per section; clicking a radio writes through `NS.SetByPath` and
  re-syncs; the rows still appear in `/am list`.

**F-3 Overrides tab** (feedback Filters #3)
- The tab "Always / never" is renamed **Overrides**, and its subsections become **Whitelist** and
  **Blacklist**.
- Each list is an ID list (X-1) in spell mode, adding by spell id or spell name, over
  `container.filter.whitelist` / `.blacklist` (storage and carve-outs unchanged).
- **Acceptance:** adding by a known spell name stores its id; an unknown name adds nothing and
  says why inline.

### Layout page

**L-1** The **Frame** tab comes first. Tab order: Frame · Anchor · Growth · Mouse.

**L-2** The **Position** tab is renamed **Anchor**.

**L-3 Strata and the world-tooltip bleed** (feedback Layout #3)
- The per-container Strata row already exists (Layout → Frame). The template default rises from
  `MEDIUM` to **`HIGH`**, and v2 moves stored `MEDIUM` values to `HIGH` (section 7).
- **Investigate the bleed at its root, because strata cannot stop it.** The world is not a frame,
  and a unit's mouseover tooltip appears only when no mouse-enabled frame is under the cursor. The
  suspects are these:
  - preview frames are created with `EnableMouse(false)` (`modules/Preview.lua:53`);
  - `SetMouseMotionEnabled` on an engine button whose hit rect differs from the size we set;
  - `clickThrough`.
- The fix follows the finding, and the finding is written into the commit and the plan.
- **Acceptance:** in game, hovering a bar or icon (live or preview) shows only the aura's tooltip.

**L-4 Show the handle of an attached container while unlocked** (feedback Layout #4)
- Suspected cause (to confirm first): while previewing, the target's engine is disabled and keeps
  a stale or 1×1 rect. The child anchors to it (`modules/Anchors.lua:74`), so the child's
  placeholders and handle stack on top of the parent's and are hidden under them.
- **Fix:** while previewing, attach a container-attached child to its target's **preview extent**,
  a frame of ours sized by `Preview.Offset` arithmetic to the target's placeholder block. That way
  the child sits where it would with real auras, and its handle's frame level is raised above every
  placeholder. Out of combat only: re-placing the anchor of a frame that parents an engine is
  layout work (events-frames-taint-§2). Under lockdown the last placement stands, as the handle
  rules already say.
- The Known Limitations entry "An attached container's handle can lie over the container it is
  attached to" is rewritten or retired accordingly.

**L-5 Anchor tab subsections** (feedback Layout #5, #6, #7)
- **Attach to** is `Screen` / `Another container` / `Named frame` (labels shortened; "The screen"
  and "On the screen" become **Screen**).
- Subsections, in order:
  - **Screen**: point, relative point, X, Y of `container.position`.
  - **Another container**: the Container dropdown, plus a read-only line naming the derived points
    (D3).
  - **Named frame**: frame name, **Pick a frame…**, point, relative point.
  - **Offset**: X and Y of `container.attach`, used by both attached modes.
- The redundant **Attach to the screen** button is removed; the dropdown does the same thing.
- **Dimming:** every row in a subsection that does not apply to the current mode is disabled and
  dimmed through `disabledIf` (X-3):
  - `screen`: Another container, Named frame and Offset are disabled.
  - `container`: Screen and Named frame are disabled.
  - `frame`: Screen and Another container are disabled.
- Changing the mode re-syncs every widget on the same frame, because the rows re-read their
  disabled state on `RefreshScalars`.

**L-6 Anchor-mode interactions** (feedback Layout #8)
- In `container` mode the child's *effective* layout axis, growH and growV are its root parent's,
  resolved up the chain; the resolver stays cycle-safe through `Anchors.WouldCycle`.
  - `Container.FlowSettings`, `Preview.Offset`, `Anchors.placeHandle` and `clampToHandle` all read
    the effective values.
  - The child's own stored values are untouched and take effect again when it detaches.
- The derived points continue the parent's flow:

  | Parent axis / growth | Child point → parent relative point |
  |---|---|
  | columns, down | `TOP{H}` → `BOTTOM{H}` (H = LEFT if growing right, else RIGHT) |
  | columns, up | `BOTTOM{H}` → `TOP{H}` |
  | rows, right | `{V}LEFT` → `{V}RIGHT` (V = TOP if growing down, else BOTTOM) |
  | rows, left | `{V}RIGHT` → `{V}LEFT` |

  `container.attach.point` / `.relativePoint` are ignored in `container` mode (still used by
  `frame` mode), and `attach.x` / `.y` still apply.
- On the Growth tab in `container` mode, Fill, Grow horizontally and Grow vertically are disabled
  and show the effective (inherited) values, under a line "Fill and growth follow 'Parent name'".
  Per row, spacing and line spacing stay the child's own.
- Frame and Mouse tabs: no inheritance. That is audited and stated in `docs/settings-panel.md`
  rather than assumed.
- **Acceptance:** tests over the derived-point table (all 8 combinations), the chain
  (A→B→C inherits A's), and a detach restoring the child's own stored flow.

### Bars page

**B-1 Icon tab** (feedback Bars #1)
- Size → Icon's four rows (`icon`, `iconSize`, `iconGap`, `iconZoom`) move to a new **Icon** tab.
- The new icon-border block is composed with `H.BorderGroup` (options-ui-§16) on keys
  `iconBorderShow`, `iconBorderStyle`, `iconBorderSize`, `iconBorderColor`,
  `useClassColorIconBorder` (template defaults `false`, `"Solid"`, `1`, black, `false`: additive,
  backfilled).
- `Style_Bars` draws a BackdropTemplate border around the icon and insets the icon art inside it,
  the same way `Style_Icons.layoutIcon` does.

**B-2 The wrong-style state** (feedback Bars #2; Icons page likewise)
- When the selected container is not drawn in this page's style, every row on every tab is drawn
  **disabled and dimmed**, through a page-level disable in the flow engine (X-3).
- The notice is drawn larger and more prominent (`TextRow` with a larger font object, e.g.
  `GameFontNormalLarge`, in the orange it has today), followed by a spacer before the first control.
- It names the new home: "…once its style is Bars (General → Containers)."

**B-3 Spark on auras without a duration** (feedback Bars #3)
- A new row, `bars.sparkTimeless` ("Show the spark on auras without a duration", default
  `true`, which keeps today's look).
- Auras are secret, so the check must happen in the engine or in geometry, never in Lua reading a
  duration. Options in order of preference, and the first that works in the client wins:
  1. an engine binding that shows or hides a region by whether the aura has a duration (search
     `Blizzard_CustomAuraContainer` / `CustomAuraButtonMixin` in wow-ui-source `live`);
  2. geometry: the spark lives in a clip frame bounded by the elapsed region
     (`SetClipsChildren`), so a zero-elapsed (timeless) bar clips it away. Check that a timed
     bar's spark still reads as centered on the edge;
  3. if neither holds in the client, stop and report to the owner rather than ship half a feature.
- The preview honors it: a placeholder with `duration == 0` hides the spark when the option is off.

**B-4 Color by → dispel type never lets go** (feedback Bars #4)
- Suspected cause (to confirm against `Blizzard_CustomAuraContainer`): `Bars.Bind` calls
  `ClearDispelTypeTextures` *after* `applySurfaces` has painted the fill. Clearing a
  `PreserveAsset` dispel texture may reset the region the engine last tinted (vertex color, or
  hide). The static color is then painted over before the clear, and the clear wins.
  - The preview has a sibling fault: `FillPreview` tints the fill Magic in dispel mode and never
    resets it. A later static dress repaints the color, so check that ordering too.
- **Fix:** clear the dispel textures before painting the surfaces (or re-paint after clearing), in
  both styles, and make the preview's tint part of the dress rather than of the fill step.
- **Acceptance:** a recorder test that toggles `colorMode` static → dispel → static on a live
  (engine) button and a preview element. It asserts that the final vertex color is `barColor` and
  that `ClearDispelTypeTextures` precedes the last `SetVertexColor`.

**B-5 Settings that silently do not apply** (feedback Bars #5)
Two causes are known from reading, and both get fixed:
- **An error in an apply stops the pass** (C-4 is one such error). `CM.FlushPending` resets
  `pending` before `applyDirty`. An error raised in one container's `Apply` therefore drops every
  later container in the batch, and skips `replaceAttached`. The fix:
  - each `inst:Apply()` in `applyDirty` is guarded;
  - the error is reported once, with its stack, through the same path `Style.Element` uses;
  - the loop continues.

  A regression test raises in container 1 and asserts that container 2 still applied.
- **Justify cannot show on a single-anchor FontString.** `Style.ApplyText` anchors each text at
  one point, so the string sizes to its text and `SetJustifyH` has no visible effect. Only the name
  text, with its second anchor, ever justified. The fix gives every text box a width: the host's
  width minus the absolute X offset, so justify aligns within it. The name text keeps stopping short
  of the time text.

  A recorder test asserts `SetWidth` / two-point anchoring for every text element.

Then a **coverage test**: for every schema row on the Bars and Icons pages, write a non-default
value, flush, and assert that the dressed regions (live and preview) recorded a change. A row that
reaches no region fails the suite by name. This catches the "random" class of the report
generically; any row it finds is fixed in the same phase.

**B-6** Dispel type colors move to General (G-3). The Highlights tab loses its Dispel type colors
subsection.

### Icons page

**I-1 Border color not applying** (feedback Icons #1)
- Suspects, in order:
  1. with `dispelBorder` on (the default), the engine's dispel-border texture (`am.dispel`, OVERLAY,
     full frame) covers our border on every harmful aura, including the player-debuff starter;
  2. frame-level order between `am.border` and `am.cd`;
  3. B-5's error path.
- Confirm in game with `/fstack` and in the recorder before fixing.
- **Target behavior:** our border color shows on every icon. Where the dispel border is on and the
  aura has a dispel type, the dispel-colored border replaces ours (documented in the row's
  tooltip).

**I-2 Time text about a second off the cooldown numbers** (feedback Icons #2; bars too)
- Cause: our formatter truncates (`core/Compat.lua` `SetRounding(Truncate)`), and the "Blizzard"
  format hands the engine no formatter at all. The cooldown frame's own countdown rounds up.
- **Fix:** round up in every format, and back the "Blizzard" format with a formatter built to
  match the cooldown countdown. Verify the enum members (`SecondsFormatterRounding`) in
  wow-ui-source before relying on them.
- **Acceptance:** a unit test on the formatter setup (rounding mode recorded), plus an in-game
  smoke check with Blizzard countdown numbers on: the two numbers agree.

### Cross-cutting (LibKa0s v1.35.0)

**X-1 `IdList` widget** — `LibKa0s-Options-1.0` minor 19, `O.IdList(ctx, spec)`, drawn inside the
page scroll. It is split into two exports: `O.IdInput(ctx, spec)` (the input line alone) and
`O.IdList` (the input line plus the entry rows). ConsumableMaster's priority list keeps its own
rows (drag, score, pick star) and adopts only the input.
- **`spec` fields:**
  - `kind`: `"spell"` | `"item"` | `"currency"`, or `resolver` for anything else. A resolver
    returns `id, name, icon` for a number, a link or a name.
  - `entries()`: an ordered list of `{ id, toggle = bool?, on = bool? }`.
  - `onAdd(id)` and `onRemove(id)`.
  - `onToggle(id, on)`, for toggle entries (starters).
  - `candidates()`: optional; ids to search by name.
  - `label` and `tooltip`.
- **Input:** one edit box takes a number, a name, or a shift-clicked spell or item link (parse
  `|Hspell:`/`|Hitem:`). Name resolution tries the client first (`C_Spell.GetSpellInfo(name)` /
  `C_Item.GetItemInfoInstant(name)`), then the host's `candidates()` by case-insensitive name. An
  input that resolves to nothing, or to more than one, adds nothing and shows an inline message.
- **Display:** each entry shows icon, name and id (an unknown id as "Unknown spell 12345"), then
  Remove, or a checkbox for a toggle entry.
- **Behavior:**
  - The host owns storage. The widget calls back and never writes a path.
  - Degrades to id-only input when the resolver APIs are absent.
  - Kit support ships in the same release (mock `C_Spell` / `C_Item` name lookup).

**X-2 `ChoiceGrid` widget** — `O.ChoiceGrid(ctx, spec)`, where `spec` is
`{ rows = <schema rows sharing one values list>, columns = <ordered values with labels>,
heading = string? }`.
- It draws a header line, then one line per row: one radio cell per column, then the row label with
  its tooltip. It reads and writes through the descriptor's `get` / `set`, like every maker, and
  re-syncs on `RefreshScalars`.
- Rows it draws carry `skipRender` for the flow engine.

**X-3 Generic `disabledIf` and a page-level disable**
- **Per row:** every row maker (checkbox, slider, dropdown, edit box, LSM media, color) honors
  `row.disabledIf`. Today only the color picker does (`OptionsWidgets.lua:1683`). The value is
  either a settings path (today's form) or a function `(row) → bool`, and it is re-evaluated on
  `RefreshScalars`. A disabled widget is dimmed by AceGUI's own disabled state.
  - The class-color companion rule stays: the swatch is never `disabledIf`
    (`OptionsCompose.lua:228`).
- **Per page:** `RenderRows(ctx, rows, afterGroup, pairWith, opts)` gains `opts.disabled`, which
  disables every widget it draws. `Helpers.RenderContainerPage`'s `intro` can set it for the
  wrong-style state (B-2).

**X-4 Release and adoption**
- LibKa0s follows `docs/releasing.md`: branch, tests (a new characterization test for each of X-1…X-3
  written first), `docs/api/Options` member snapshot for minor 19, CHANGELOG, tag `v1.35.0`, kit
  bump if the mock changes.
- It is re-vendored (`/wow-addon:revendor-libka0s` procedure) into the four adopters: AM, CM, BL,
  LH. The other six addons pick up v1.35.0 at their next routine re-vendor; nothing in this effort
  forces them.
- **Per adopter (CM, BL, LH):** replace each list editor with the widget, and keep each list's
  stored shape. All three bundle v1.34.0 and draw their panels with LibKa0s-Options; none resolves
  names today. The survey found:

  | Addon | Editor today | Stored shape (kept) | Adopts |
  |---|---|---|---|
  | ConsumableMaster | `settings/Category.lua:546` `renderAddByID`: a Type dropdown (item/spell) plus an id-or-link edit box. Rows are custom `KCMItemRow` + `ReorderList` | `profile.categories[K].added/blocked` `[id]=true`; spells stored as negative ids (`KCM.ID.AsSpell`) | `IdInput` only, with a resolver that maps a spell to `-id`. Rows unchanged |
  | BankLedger | `settings/Panel.lua:281` `makeFilterSection` / `:241` `rebuildFilterList`: an edit box, Add, Clear all, and Label + Remove rows | `db.global.blacklist/whitelist` `[itemID]=true`; `Filters:_move` keeps the two lists exclusive | `IdList` (`kind = "item"`); Add/Remove call the existing `Filters` writers; Clear all stays host-side |
  | LootHistory | `settings/Panel.lua:268` / `:219`, a near copy of BankLedger's | `db.global.blacklist/whitelist/currencyBlacklist` `[id]=true` | `IdList` for items and currencies (`kind = "currency"`) |

  - Item names resolve only once cached, so the widget uses `lib.LoadItem` (`Item.lua:121`) and
    re-renders its rows when the load arrives. It does that through `ctx.rebuilders`, as
    LootHistory does today.
  - `IdList` is not a schema row type, so no Slash or CLI change follows.
  - Each adopter keeps its own green gate and commits on its own branch.

## 5. Out of scope

- Party units, a text style (issues #1, #2).
- Forcing v1.35.0 into the six non-adopting addons.
- Any change to `/am` verbs beyond the words they print.

## 6. Testing strategy

- **TDD throughout** (superpowers:test-driven-development): every bug gets a failing test first,
  and every feature a characterization or behavior test first.
- The harness is `lua tests/run.lua`; lint is `luacheck .` (0/0); lizard shows no function above
  CCN 15. That is the green gate before every commit (CLAUDE.md).
- **New or extended suites:**
  - `test_pages_general` (the three new tabs, the picker and New inside the tab, Delete survival:
    C-3);
  - `test_preview` (style switch: C-4);
  - `test_containermanager` (error isolation: B-5);
  - `test_style_bars` / `test_style_icons` (dispel order B-4, justify width B-5, icon border B-1,
    spark B-3, border I-1);
  - a new `test_render_coverage` (every Bars/Icons row reaches a region: B-5);
  - `test_anchors` (derived points, inheritance, preview extent: L-4 and L-6);
  - `test_pages_layout` (dimming matrix: L-5);
  - `test_pages_filters` (grid, overrides: F-1 and F-3);
  - `test_database` (v2 migration: section 7);
  - `test_compat` (formatter rounding: I-2).
- `test_pages_containers.lua` is retired, and its still-valid cases move to `test_pages_general`.
- **In-game smoke checks** go into `docs/smoke-tests.md` for everything the harness cannot see: the
  tooltip bleed, the countdown match, the spark, dimming, and handle visibility.

## 7. Data model and migration (schema v2)

This is the first step on the ladder (`core/Database.lua` `SCHEMA_STEPS`, `to = 2`). It runs over
**every profile** in `AuraMasterDB.profiles`, not only the active one (`docs/common-tasks.md`
recipe), and logs one `[Migrate]` line per profile.

| Change | Rule |
|---|---|
| `profile.categorySpells` (new) | **Additions:** the union of every container's `filter.categorySpells[k][id] == true`. **Removals** (`false`): a starter id is removed only if **every** container that has any edit for `k` removed it. `container.filter.categorySpells` is then deleted from each container |
| `coreHealing` + `lesserHealing` → `healing` | **Spell edits:** merged under `healing` by the rule above. **Category state per container:** `show` if either was `show`, else `hide` if either was `hide`, else `""`. Both old keys are deleted from `filter.categories`, and the template's `NeutralStates()` backfills `healing` |
| `profile.dispelColors` (new) | Copied from the first container in `containerOrder` whose `bars.colorMode == "dispel"`, else from the first container, else the defaults. `bars.dispelColors` is deleted from every container |
| `layout.strata` | Stored `"MEDIUM"` becomes `"HIGH"` (the new default). Any other value is kept |
| Additive keys | `bars.sparkTimeless` and the five `bars.iconBorder*` keys arrive through the ordinary template backfill, with no step |

- `NS.defaults.profile` gains `categorySpells = {}` and `dispelColors` (from
  `C.DEFAULT_DISPEL_COLORS`).
- The schema validator must resolve `categorySpells` and `dispelColors.*` as absolute paths.
- `docs/schema.md` → Migration path records v2, and `Database.CurrentSchemaVersion()` answers `2`.
- **Tests** cover every rule above, including a profile never loaded (not active) and a profile
  with no containers.

## 8. Risks

- **The General page grows to five tabs and to mixed content.** Keep each renderer small (the CCN
  15 gate).
- **B-3 may not be possible in the client.** Its option 3 is an explicit stop-and-report, not a
  silent drop.
- **Four repos plus a library release.** Every repo keeps its own branch and its own green gate,
  and a repo is never merged, pushed or tagged without the owner's instruction (CLAUDE.md).
- **v2 is irreversible for a profile once it has loaded.** The migration is covered by tests before
  it ships, and the old keys are deleted only after their values are written to the new home.

## 9. Documentation changes

- `docs/ARCHITECTURE.md`:
  - schema row counts and page list;
  - the Documented deviations row below;
  - Known Limitations (the attached handle, and the spark if option 3 applies).
- `docs/settings-panel.md` (the page table, and every page → tab → row table), `docs/schema.md`
  (the v2 shape), `docs/smoke-tests.md` (new checks), `docs/module-map.md` (files moved or
  retired), `docs/test-cases.md` (regenerated), README features.

**The deviation row (D1):**

| Rule | What differs | Why | Decided | Re-check trigger |
|---|---|---|---|---|
| `options-ui-§14` | The General page's `Containers` tab edits one selected container, but carries its Container picker and New container inside the tab body rather than in a band above the strip. The General page draws no banner, and its first tab stays `Master controls` (options-ui-§15). Filters, Layout, Bars and Icons keep the banner picker | The owner keeps a container's identity (create, name, enable, unit, aura type, style, duplicate, delete, copy) with the addon-wide settings on General instead of on a page of its own. Ratified by the owner 2026-09-13 | 2026-09-13 | The standard gains a registry-tab form for a General page, or a Containers page returns; the row is retired then |
