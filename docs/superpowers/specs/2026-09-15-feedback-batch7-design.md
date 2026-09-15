# Feedback batch 7 — design spec

- **Date:** 2026-09-15
- **Branch:** `feat/2026-09-14-feedback-batch6` (continued — see D1); LibKa0s `feat/2026-09-14-v1.36.0`
- **Source:** the owner's in-game feedback of 2026-09-15, nine items, after playing with batch 6
- **Plan:** `docs/superpowers/plans/2026-09-15-feedback-batch7.md`

Requirement IDs are `G-n` (grid), `N-n` (navigation/pages), `U-n` (uncategorized), `T-n` (text),
`S-n` (style pages), `X-n` (misc).

## 1. Decisions

| # | Decision |
|---|---|
| D1 | **Batch 7 continues on batch 6's branch.** Batch 6 is unmerged, and batch 7 edits batch 6's own output (the grid cells, the Categories tab, the priority model). Two unmerged branches with one depending on the other buys nothing. |
| D2 | **The yellow fill goes; grid cells become ordinary checkboxes** (`G-1`). This reverts batch 6's `K-1` fill. It needs LibKa0s v1.36.2 and a re-vendor across ten addons — the third library release of this effort. |
| D3 | **`Uncategorized` means "in none of the profile's SPELL-LIST categories"** (owner, 2026-09-15). Blizzard token, flag and dispel categories do NOT count toward being categorized. Default **Show**. |
| D4 | **The `Only these categories` toggle STAYS.** The owner declined the variant that replaced it with `Uncategorized = Hide`. The two coexist and compose (`U-4`). |
| D5 | **The default container strata becomes `MEDIUM`** (`X-3`). This REVERSES batch 5's `L-3`, which deliberately set `HIGH` so containers drew above the default UI's Medium layer. Recorded as a reversal, not a gap; `tests/test_defaults.lua:225` pins the old value and moves with it. |
| D6 | **Sub-pages are a label prefix, not Blizzard nesting** (`N-2`). MultiMeters marks a nested page by prefixing its tree label with `"  - "` (`MultiMeters/settings/OptionsSetup.lua:91`). Aura Master copies that established pattern rather than inventing hierarchy. |

## 2. The grid cell (`G-1`)

| ID | Requirement |
|---|---|
| `G-1` | `O.ChoiceGrid`'s lit cell is a plain AceGUI CheckBox check, as the `Only these categories` checkbox beside it already is. `choiceFill` and its constants go. The exclusive one-choice-per-row behavior is untouched — it never lived in the widget |
| `G-2` | The `OnRelease` vertex-color restore added in v1.36.1 goes with it: with no color written, there is nothing to restore. **The kit's pooled CheckBox texture and the regression test around it STAY** — they closed a real blind spot, and a future fill would need them again. Re-point the test at what still holds, or retire it with a comment saying why; do not silently delete the coverage |
| `G-3` | Released as **v1.36.2**, local tag only, re-vendored into all ten addons |

## 3. Pages and navigation (`N-1`…`N-5`)

| ID | Requirement |
|---|---|
| `N-1` | A new top-level **Containers** page whose single tab is **Containers**. General's current Containers tab moves to it wholesale — the picker, New container, name/unit/aura type/style, Duplicate/Delete and Copy settings from |
| `N-2` | **Filters, Layout, Bars and Icons become sub-pages of Containers**, marked by the `"  - "` label prefix (`D6`). Tree order: General · Containers · - Filters · - Layout · - Bars · - Icons · Profiles |
| `N-3` | **`See spells` currently lands on the addon's landing page, not General → Spell Categories** (owner report). `NS.OpenOptionsPage` falls back to `Helpers.OpenOptionsPanel()` when `categories[pageKey]` is nil; `categories` is filled only by `NS.RegisterContainerPage` (`settings/OptionsSetup.lua:525`), and **General is registered through `NS.RegisterOptionsPage`, which never records its category**. Fix the seam so every registered page records its category, not just container pages |
| `N-4` | `See spells` reads as a control, not as text: drawn as a button or a hyperlink-styled interactive label, with a tooltip saying where it goes |
| `N-5` | Every **Blizzard category** row gains an **info icon** in the same column, whose tooltip explains what that Blizzard category is and names a few auras that fall in it. The sample auras are illustrative and must be described as such — the engine owns these sets and the addon cannot enumerate them |

## 4. Uncategorized (`U-1`…`U-5`)

| ID | Requirement |
|---|---|
| `U-1` | New category `uncategorized`, kind **`uncategorized`**, offered for buffs and debuffs, default **Show**, drawn **last in the Spell Categories grid** |
| `U-2` | It has **no** General → Spell Categories entry — there is no list to edit (owner) |
| `U-3` | **Semantics (`D3`):** it matches an aura in none of the profile's spell-list categories. Set to **Show** it compiles to its own group: the base plus `excludeSpellIDs` of the union of every `spells`-kind category's effective ids, and — like every other Show group — it carries NO hidden-category exclusions. That is what rescues a cancelable-but-unlisted buff from `Cancelable = Hide`, which is the defect that prompted this |
| `U-4` | It composes with `onlyShown` rather than replacing it (`D4`): with `Only these categories` on, the catch-all is still dropped, and the `Uncategorized` group survives if and only if it is set to Show. "Only what I chose" plus "keep what I have not classified" is a coherent pair |
| `U-5` | Set to **Hide** it contributes its id-complement as an exclusion on the catch-all, the same shape every other hidden category uses |

**The cost, which the owner accepted and which the panel must state:** while `Uncategorized` is Show,
hiding a Blizzard category does little, because most auras are unlisted and `Uncategorized` keeps
rescuing them under rank 3. To actually hide cancelable buffs, set both `Cancelable` and
`Uncategorized` to Hide. The Categories tab says so.

## 5. Text and readability (`T-1`…`T-3`)

| ID | Requirement |
|---|---|
| `T-1` | **ASCII only in user-facing strings.** `→` renders as a box in the owner's font (screenshot). Sweep `locales/enUS.lua` and every routed literal: `→` (14) → `->`, `…` (7) → `...`, `·` (14) → `-` or a word, `§` (2) → spelled out. **`—` (101) renders correctly in the owner's screenshots and stays.** Add a test that fails on a non-ASCII byte in any locale VALUE, so this cannot return |
| `T-2` | The Categories tab's priority blurb is hard to read as one dense paragraph. Break it so each rank is its own line, and reduce the blank space under `Only these categories` |
| `T-3` | `Hide enchants without a duration` moves up beside `Only these categories` rather than sitting alone under the Spell Categories grid |

## 6. Style pages (`S-1`)

| ID | Requirement |
|---|---|
| `S-1` | On **Bars**, the `Size` tab's contents become the FIRST subsection of the `Bar` tab, and `Bar` is renamed **General**. The `Size` tab goes. Apply the same shape to **Icons** if its tab set matches; if it does not, say so rather than forcing it |

## 7. Misc (`X-1`…`X-3`)

| ID | Requirement |
|---|---|
| `X-1` | File a GitHub issue: maintain a cache of auras the addon has seen, as an autocomplete suggestion source, with a time-bound cleanup that drops auras unseen for X days. Issue only — no implementation this batch |
| `X-2` | The v3 migration and `DefaultStates()` must account for `uncategorized` so existing containers get it at Show |
| `X-3` | `defaults/Profile.lua`'s container template strata becomes `MEDIUM` (`D5`), and `tests/test_defaults.lua:225` moves with it |

## 7a. The spark's appearance in clip mode (`SP-1`, owner report 2026-09-15)

**Diagnosis, established before any code.** The spark is Blizzard's casting-bar texture, which is
gold, drawn with `SetBlendMode("ADD")` (`modules/Style_Bars.lua:54-55`). It is not changing color.
What changes is WHERE it sits:

- `sparkTimeless` **on** (default): the spark is centered on the fill's moving edge
  (`wireSpark`'s else branch), so it lies mostly over the bright fill. ADD blending against a bright
  backdrop washes it toward white.
- `sparkTimeless` **off**: the spark is anchored by its own side to the elapsed region's side and
  clipped to that region, so it sits over the DARK unfilled part. ADD blending against black leaves
  the texture's own gold showing.

The clip is not arbitrary: an addon cannot ask an aura whether it has a duration (secret), so the
only available signal is that a permanent aura's elapsed region has zero width and therefore clips
the spark away. That is why the geometry differs, and why padding the clip outward to re-center a
timed spark would break the feature — the region would stop being zero-width for permanent auras.

| ID | Requirement |
|---|---|
| `SP-1` | With `sparkTimeless` off, a TIMED aura's spark must read the same as it does with the option on. Keep the clip (it is load-bearing) and neutralize the appearance change — match the color in clip mode, or drop the ADD blend there so the backdrop stops deciding it. Whichever is chosen, say in the code comment WHY the two modes need different treatment, or the next reader will "simplify" it back |
| `SP-2` | The owner must confirm it in-client: this is geometry and blending the headless harness cannot see. A smoke check compares a timed bar's spark with the option on and off, and separately confirms a permanent aura still has none with it off |

## 8. Out of scope

- Implementing the aura cache (`X-1` files it only).
- Revisiting rank 3 or the group count — issue #7 owns that.
- Merging any branch.
