# Feedback batch 8 — design spec

- **Date:** 2026-09-25
- **Branch:** AuraMaster `feat/2026-09-25-feedback-batch8`; LibKa0s `feat/2026-09-25-draghandle-close`
- **Source:** the owner's in-game feedback of 2026-09-25: sixteen numbered notes, of which eleven are
  requests (#1, #3–#11, #13, #16) and #6 is deferred (D1)
- **Plan:** `docs/superpowers/plans/2026-09-25-feedback-batch8.md`
- **Evidence:** `docs/superpowers/research/2026-09-25-feedback-batch8-findings.md`. This is the
  investigation record, with one investigator per item, each checked by an adversarial critic. It has the
  root causes with file:line evidence, the implementation sketches, the test lists and the smoke checks.
  **Where this spec and the findings disagree, this spec wins.**

Requirement IDs: `SP` spark (#1), `CX` close button (#3), `TD` test-mode debuffs (#4), `AS` text
autosize (#7), `NL` name label (#8), `EO` empty-container overlap (#9), `DB` dispel border (#10), `IA`
icon attach (#11), `SS` seam spacing (#13), `DG` diagnostics (#16).

## 1. Decisions

| # | Decision |
|---|---|
| D1 | **#6 (the settings layout redesign) is out of this batch.** It gets its own design, spec and branch once this batch is merged (owner). |
| D2 | **#5 is filed, not built:** AuraMaster#22 (drag to attach and detach, and richer anchor points). |
| D3 | **#3 goes through LibKa0s** (owner). `WidgetsDragHandle` gains an opt-in close button (`DRAG_MINOR` 2 → 3). The library is released as **v1.59.0 with a local tag only** and re-vendored into AuraMaster only. The other DragHandle hosts (ConsumableMaster, KickCD, AbsorbTracker) are unaffected until they opt in, and their re-vendor is not in this batch. |
| D4 | **#1: the spark is neutral in both modes** (owner). It is always ADD with desaturated art, and its color comes only from Spark color. This reverts batch 7 SP-1's BLEND. |
| D5 | **#13: the seam gap comes from the child's own spacing, and X/Y stay as a nudge on top** (owner). The v8 migration zeroes the old default offset (0/-4) on containers attached to another container. |
| D6 | **#8: the label and the drag handle both show while unlocked** (owner). As in KickCD, the handle is pushed out past the label. |
| D7 | **#7: Size to fit is ON for new profiles and new containers, and OFF for existing containers** (set by v8), so hand-sized layouts do not move. |
| D8 | **One schema step, v8,** carries both D5's offset reset and D7's autosize stamp. It is unreleased, so later tasks in this batch extend the same step. |

## 2. Requirements

### SP — spark (#1)

| ID | Requirement |
|---|---|
| `SP-1` | The spark texture always uses blend mode ADD and `SetDesaturated(true)`, set on every dress in `applySurfaces`, not in `build()`, so the recorder tests can see it. `wireSpark` handles geometry and clipping only. |
| `SP-2` | Rewrite the SP-1 comment in `Style_Bars.lua` and replace "do not simplify back to one blend mode" with "do not reintroduce BLEND". Update `known-limitations.md` and smoke check 85. |

### TD — test-mode debuffs (#4)

| ID | Requirement |
|---|---|
| `TD-1` | `C.PREVIEW_AURAS` is keyed by aura type. A HARMFUL container previews debuffs, and a HELPFUL container previews buffs. |
| `TD-2` | The debuff set covers every entry in `C.DISPEL_TYPES` plus one debuff with no type: Shadow Word: Pain (Magic), Hex (Curse), Frost Fever (Disease), Deadly Poison (Poison), Rupture (Bleed) and Mortal Wounds (none, no timer). One of them has stacks. |
| `TD-3` | Names and icons resolve from the client by spell id once per session, falling back to the fixed values. Enrage stays out. |
| `TD-4` | The dispel border, bar tint and Text dispel word all render from the preview's `dispel` field on every style. |

### DB — dispel border (#10)

| ID | Requirement |
|---|---|
| `DB-1` | The dispel-colored icon border has **the same shape** as the Solid border: four flat strips at the stored Border thickness, inside the frame, square corners. Blizzard's beveled `ui-debuff-border-*` atlas is no longer used. The engine only recolors white strips (style PreserveAsset, no custom color map). |
| `DB-2` | Colors stay Blizzard's fixed dispel colors, as today. When the border is hidden or its thickness is 0, the dispel edge draws at 1 px. With a non-Solid border style, the dispel edge is still flat strips. |

### IA — icon attach (#11)

| ID | Requirement |
|---|---|
| `IA-1` | `Anchors.DerivedPoints` ignores the axis. A child always stacks on the parent's vertical growth side: growing down it attaches TOP{H} to BOTTOM{H}, growing up BOTTOM{H} to TOP{H}, and H is LEFT unless the growth is left. Bar and text parents are unchanged. An icon child sits below a wrapped parent's last line. |
| `IA-2` | The read-only "Attached by its … to the …" label follows automatically. No migration is needed, because container-mode points are derived, not stored. |

### SS — seam spacing (#13)

| ID | Requirement |
|---|---|
| `SS-1` | In container-attach mode, the gap across the seam equals the gap the **child** uses between its own consecutive elements in the stacking direction. For a column child that is `layout.spacing`, and for a row child (icons, stacked vertically per IA-1) it is its line spacing. The gap applies in the chain's growth direction, so a growing-up chain no longer overlaps. |
| `SS-2` | `attach.x` and `attach.y` add on top as a nudge. v8 sets them to 0/0 on containers in container-attach mode whose stored values are still the old default 0/-4. Other values are the user's own and are kept. |
| `SS-3` | The seam must be identical locked, unlocked and in test mode. When unlocked, an attached column child's drag strip must not cover the parent's last aura (move it beside or off the seam, per the findings). |

### EO — empty-container overlap (#9)

| ID | Requirement |
|---|---|
| `EO-1` | When a parent is unlocked and not previewing, its followers hang from the parent's **anchor**, which is exactly one element, the white outline placeholder, instead of its 1x1 engine. The hang mode is three-state per container (`preview` / `slot` / `engine`), and the attach memo re-targets on lock and unlock as well as on preview. |
| `EO-2` | Test mode also leaves room for the handle, for consistency (the findings' L-4 note). Chains of any length never stack their strips. |

### AS — Text size to fit (#7)

| ID | Requirement |
|---|---|
| `AS-1` | Text containers get `autoSize` (template `true`) and a "Size to fit" checkbox on the Text page. When it is on, Width and Height are disabled with a tooltip explaining why. |
| `AS-2` | When it is on, the element size comes from the content: the widest line from the preview and sample names plus the worst-case duration, using the font, icon, gap and bounce. It is memoized per style signature, secret-safe, and falls back to the stored size when unmeasurable. The width is clamped to `C.TEXT_WIDTH_MIN`–`MAX`. |
| `AS-3` | v8 stamps `autoSize = false` on every existing text container. A new container in an existing profile gets the template's `true`. |

### CX — close button (#3)

| ID | Requirement |
|---|---|
| `CX-1` | LibKa0s: the DragHandle spec takes `onClose`, `closeIcon` and `closeTooltip`. With no `onClose`, geometry is byte-for-byte unchanged, and a test pins that. The X is the same size and hit box as the "?", sits immediately left of it, uses the same tint and hover, and passes drag through. The label stays centered: the reserve grows on both sides. |
| `CX-2` | LibKa0s v1.59.0: CHANGELOG, README, `docs/api` 10.3 docs and the members JSON. Tag it locally only. |
| `CX-3` | AuraMaster re-vendors v1.59.0 (`libs/LibKa0s` and `tests/_kit` together, with the provenance line). `closeIcon = NS.Icon("close")`, the LibKa0s standard glyph. A left click sets `container.enabled = false` through `NS.SetByPath`, with no confirmation, and prints one chat line naming the container and how to turn it back on. The tooltip says the same. |

### NL — name label (#8)

| ID | Requirement |
|---|---|
| `NL-1` | A per-container `label = { show = false, x, y, font }`. The text is always `cfg.name`. The default look is gold Friz 12 OUTLINE, the same as the handle. |
| `NL-2` | The label sits where the handle sits (the strip's "away" side), locked or unlocked, and is shown whatever the aura count, because engine contents are secret. |
| `NL-3` | **While unlocked, both show** (D6). The handle moves out past the label by the label's height plus the strip gap, on the same side. |
| `NL-4` | Settings live on the Layout page (a "Name label" group: Show, Font, X/Y). Every string goes through `NS.L`, in ASCII. |

### DG — `/am diagnostics` (#16)

| ID | Requirement |
|---|---|
| `DG-1` | *(Amended 2026-09-25 by the owner; see the note below.)* The report runs from exactly two forms: `/am diagnostics`, a new top-level verb, and `/am debug diagnostics`, a sub-verb of the existing `debug` verb. There is no `diag` alias: `/am debug diag` toggles the window like any other unknown word. Both forms work while the addon is disabled (`diagnostics` joins `liveVerbs()`), and `NS.COMMANDS` goes from 22 to 23. The output goes to the ungated `NS.DebugLog:Add`, which reveals the console, plus one `NS.L` chat line. |
| `DG-2` | Sections: the header (version, schema, profile, client build, state flags, queue), non-default profile config, and the auras on player, target and focus (plus pet) for HELPFUL and HARMFUL: auraInstanceID, spellId, name, dispel type, source, duration, left and stacks. Then every container (id, name, unit, type, style, enabled, attach), its compiled filters in full, its non-default config, and what it shows: the aura ids when they can be read, otherwise the per-group frame count or `?`. |
| `DG-3` | It is secret-safe: while `Compat.AurasAreSecret()`, no aura API calls are made and no per-button calls either. Every field goes through `NS.SafeToString`, and each section is wrapped in `pcall`. |
| `DG-4` | It is capped below the console buffer: at most 1200 lines, 100 auras per unit and filter, and 40 ids per list, with a closing `truncated` line when a cap is hit. Body lines are unrouted English (diagnostic output, like `[Init]`). It appends and does not clear. A new `modules/Diagnostics.lua` holds it, and `docs/debug.md` documents it. |

> **Amendment, 2026-09-25 (owner, after the plan was written).** DG-1 first read: "`diag` is a
> sub-verb of the existing `debug` verb. It works while the addon is disabled, and `NS.COMMANDS` stays
> at 22." The owner replaced it with the two forms above, `/am debug diagnostics` and `/am diagnostics`,
> and dropped `diag` as an alias. The README gains a *Reporting a bug* section built on them: turn on
> `/am debug on`, reproduce, run `/am diagnostics`, then Copy the whole console, which carries the
> trace and the report together. Implemented as plan task P13.

## 3. Constraints

- The Ka0s WoW Addon Standard is binding. A deviation stops the task and is reported.
- Green gate before every commit: `lua tests/run.lua`, `luacheck .` (0/0), and
  `lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .` with no function above CCN 15, plus the 1500-line cap.
- Every user-visible string goes through `NS.L`, with its key in `locales/enUS.lua`, in US spelling and **ASCII**.
- CRLF line endings, as the repo already uses.
