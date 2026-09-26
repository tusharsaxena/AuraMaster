# Settings redesign: one Containers page, pinned nav, pinned tabs (#6)

- **Date:** 2026-09-26
- **Status:** design frozen by the owner ("Lock it in!", 2026-09-26). Implementation is sequenced
  **after** the diagnostics rollout's M3/M4 (`Ka0sAddonsCommonTasks/docs/2026-09-25-DIAGNOSTICS_COMMAND/`)
  and gets its own plan under `docs/superpowers/plans/`.
- **Issue:** AuraMaster#6.
- **Reference implementation:** `settings/LayoutLab.lua` on the local branch
  `lab/2026-09-26-settings-layout` (commit `d0d0196`), page **Test10: Pinned nav**. It is a lab —
  dummy controls, and it moves the library's page body from outside — and is never merged. The other
  nine Test pages are the rejected explorations.

## 1. What the owner asked for

- The Filters, Layout, Bars, Icons and Text sub-pages fold into the **Containers** page. No more
  sub-pages for them.
- **One config page per container**: the container selector at the top, then everything that
  configures that container, **built dynamically from the container's type**.
- **Two levels of navigation**, visually distinct: first level General · Filters · Layout ·
  Bars/Icons/Text (General first); second level the tabs that already exist inside each of those.
- The same pattern later goes to MultiMeters, KickCD and PanelMaster (a GitHub issue each; §9).

## 2. The chosen design (Test10)

```
 Ka0s Aura Master > Containers                                     [Defaults]
 ────────────────────────────────────────────────────────────────────────────
 Container [ Player Bar Buffs (buffs, bars)          v ]   [ New container ]   <- band, pinned
 ────────────────────────────────────────────────────────────────────────────
 ┌──────────┐ ┌General┐┌Categories┐┌Overrides┐┌Sorting┐                        <- tab strip, pinned
 │ General  │ ┌─────────────────────────────────────────────────────┐ ▲
 │▌Filters  │ │ [x] Cast by me          [ Duration      v ]           │ █     <- ONLY this scrolls,
 │ Layout   │ │ ...                                                   │ │        on the page's own
 │ Bars     │ │                                                       │ ▼        scrollbar
 └──────────┘ └─────────────────────────────────────────────────────┘
   nav, pinned
```

- **Band (pinned, full width):** the Container picker and New container — today's
  `Helpers.ContainerBanner` with its create action, unchanged (options-ui-§14).
- **Nav rail (pinned, left, 120px):** the first level. Entries in order: **General**, **Filters**,
  **Layout**, and one style entry named by the selected container's style — **Bars**, **Icons** or
  **Text**. Drawn in the AceGUI TreeGroup tree-pane look (tooltip-border backdrop, 0.1/0.1/0.1/0.5
  fill, 0.4 border; gold `GameFontNormal` entries; the selected entry white on the blue
  `UI-QuestLogTitleHighlight` bar). This is what makes the two levels obviously different: a list
  on the left for the first, gold tabs on top for the second.
- **Tab strip (pinned, right column only):** the second level, drawn by the library's own primary
  `TabStrip` with its `Options_InnerFrame` content panel, exactly as every page draws it today. It
  starts at the rail's right edge, not the panel's.
- **Scroll (right column, under the strip):** the page's own AceGUI scroll. **Only this moves.** No
  height cap; every library widget (flow rows, ChoiceGrid, IdList, IdInput, Section) draws as it
  does now, two controls per line.
- **Alignment:** the rail's top edge sits level with the **top of the tab art**, not the top of
  the tab button — the art is bottom-anchored in a 37px button. Measured at draw time from the
  drawn tab's textures (Test10's `alignNav`), never hard-coded, so it holds at any UI scale.

### Why Test10 over the others

Test4 (sidebar + tabs inside one AceGUI TreeGroup in the scroll) looked right but capped the pane at
a fixed height and could not host the library's widgets — `RenderRows`, `ChoiceGrid`, `IdList`,
`Section` and `TextRow` draw only into `EnsureScroll(ctx)`. Test10 keeps the page's own scroll, so
both problems disappear. Measured on the owner's client (panel 665px): the right column's content
is **473px**, a half-width control **236px** — above AceGUI's 200px control width.

## 3. What changes, and what does not

| | Before | After |
|---|---|---|
| Settings tree | General · Containers · - Filters · - Layout · - Bars · - Icons · - Text · Profiles | General · Containers · Profiles |
| Containers page | band + one tab (General: identity, Duplicate, Delete, Copy settings from) | band + nav rail + the selected section's tab strip |
| Nav: General | — | today's Containers **General** tab, unchanged content |
| Nav: Filters / Layout | sub-pages | sections; their tabs (Filters: General · Categories · Overrides · Sorting, by aura type; Layout: Frame · Anchor · Growth · Mouse) become the strip |
| Nav: Bars / Icons / Text | three sub-pages, two of them disabled-with-notice for any one container | **one** entry, for the container's own style only. The disabled-for-this-style notice has nothing left to say and goes |
| Schema | rows carry `page = "filters"`, `"layout"`, `"bars"`, … | **unchanged.** A nav section *is* a former page key; the section renders `RenderTabbedSchema(ctx, sectionKey, …)` with that page's spec, so `/am set`, `/am get`, `/am list`, defaults and every row path are untouched |
| Selected container | `NS.State.activeContainerId`, shared | unchanged |
| Session state | `ctx.activeTab` per page | `ctx.activeSection` plus `ctx.activeTab` **per section** (a table), session-only, never persisted (options-ui-§13), so returning to Filters returns to the tab you left |
| Defaults button | page-wide, for the selected container | restores the **active section's** rows for the selected container — the same set the old sub-page's button restored. On General, Enabled/Unit/Aura type/Style as today; `noReset` on the name still holds |
| General (addon page) | its own page | unchanged; not part of this redesign |

A container's style change (General → Style) re-renders the page (`NS.RequestPanelRefresh`, as now);
if the active section was the old style's entry, it heals to the new style's entry.

## 4. Library change (LibKa0s-Options, new minor)

The lab moved `ctx.body` from outside. The real build adds a library seam instead, so the three
follow-up addons get it too:

- **`O.NavRail(ctx, spec)`** — `spec = { entries = { { key, label, tooltip } }, value, onSelect, width }`
  (`width` default 120). Draws the pinned rail described in §2 into the page body, left of the
  chrome's tab area; records `ctx.railWidth`. **Draw order:** `PageBanner` → `NavRail` →
  `TabStrip`. Selection is the host's state, like `SubTabStrip`'s (`spec.value` / `spec.onSelect`).
  Its buttons are pooled per ctx like the primary strip's (W14), released on the next render.
- **The rail's width is honored by the three things anchored to the chrome/body:** `TabStrip`'s
  placement starts at `railWidth + gap`; `drawContentPanel`'s left edge moves by the same; the
  scroll's `anchorScroll` left inset adds it. One number (`__railInset(ctx)`), read by all three,
  the way `__scrollTopInset` is today, so they cannot disagree. `railWidth` 0 (no rail) is
  byte-identical to today.
- **The rail's top aligns to the tab art top**, measured after the strip is drawn (§2).
- **The combat cover** covers the rail (it lives in the body). A rail click only redraws inside an
  open panel, so like a tab click it carries no combat guard of its own (options-ui-§13).
- Test-pinned: the inset arithmetic as pure seams (like `__tabPlacement`), zero-rail parity, the
  alignment measurement with a stub texture set, pool reuse across renders.
- Degradation stub (options-ui-§1): hosts' library-absent stubs gain a `NavRail` no-op
  (AuraMaster's `tests/test_surface_parity.lua` will demand it).

## 5. Standard change (WowAddonStandards, options-ui)

- **§13** today permits a secondary strip only for "a list of like subjects" and forbids a third
  level. Add the **nav rail** as a sanctioned first level for a page that edits one instance of
  many: rail (first level) + the primary strip (second level) is still two levels, and the
  "no third level" rule stands. The secondary-strip wording is untouched (this design does not use
  `SubTabStrip`).
- **§14**: the band stays above both the rail and the strip; the rail is not a picker.
- The **sub-page nesting mark (D6, `NS.SubPageLabel`)** loses its AuraMaster callers. MultiMeters
  still uses it until its own migration; the standard keeps it until the last caller goes.
- Bump, changelog, context pack per the standard's own ripple.

## 6. AuraMaster changes

- `settings/OptionsSetup.lua`: `NS.RegisterContainerPage` stops registering Blizzard subcategories;
  it registers a **section** (key, label, spec, frame-less). `Helpers.RenderContainerPage` becomes
  the Containers page renderer: banner → `NavRail` (sections filtered by the container's style) →
  `RenderTabbedSchema(ctx, activeSection, …)` with that section's spec. `NS.SubPageLabel` and its D6
  comment block go.
- `settings/Containers.lua`: its one tab becomes the **General** section's content.
- `settings/Filters.lua`, `Layout.lua`, `Bars.lua`, `Icons.lua`, `Text.lua`: register sections instead
  of pages; specs otherwise unchanged. Bars/Icons/Text lose `disabledFor`/`disabledNotice` (never
  shown for a mismatched style any more) — but `NS.ContainerPageDisabledFor` is read by
  `modules/Diagnostics.lua` to tell unused stored values; keep that predicate as data.
- **Deep links:** `NS.OpenOptionsPage(pageKey)` keeps its signature. A former sub-page key
  (`"layout"`, `"filters"`, …) opens Containers and selects that section (and, for a style key,
  only if it is the container's style). Callers: `modules/Anchors.lua:750` (`"containers"`),
  `settings/Layout.lua:501` (the frame picker's return, `"layout"`). `Helpers.SelectTab` gains a
  section-aware path for `settings/Filters.lua:278-279`'s jump to General → Spell Categories
  (addon page — unchanged).
- Tests: `tests/page_helpers.lua` and `test_pages_{filters,layout,bars,icons,containers}.lua`,
  `test_optionssetup.lua`, `test_options_descriptor.lua`, `test_anchors.lua` move from per-page ctx
  to the Containers ctx plus a section. `Helpers.__pageCtx` gains the section seam.
- Docs: `docs/settings-panel.md` (pages table, "Four pages edit one container", the D6 paragraph),
  `docs/ARCHITECTURE.md`, `docs/smoke-tests.md` (new in-client checks, §8), `README.md` screenshots
  section if any.
- Green gate per CLAUDE.md; 1500-line cap (`OptionsSetup.lua` is 554 lines now).

## 7. Out of scope

- The General (addon-wide) page and Profiles.
- Any change to what a setting does, its path, default or label.
- Collapsing the style entries' own tabs (Bars' seven tabs wrap to two rows at 473px; acceptable —
  the owner saw the wrap budget in the lab).
- IdList's two-column spell lists (Filters → Overrides): at 473px they **drop to one column**
  (two need 584px). The library already falls back on its own; accepted, not fixed here.

## 8. Smoke checks (owner runs them in-client; never marked passed by Claude)

1. The tree shows General · Containers · Profiles; no Filters/Layout/Bars/Icons/Text entries.
2. Containers: band on top; rail on the left with General · Filters · Layout · <style>; the rail's
   top is level with the top of the tabs.
3. Scroll a long section (Bars → General): only the controls move; band, rail and strip stay.
4. Switch container to one of another style: the style entry renames (Bars → Icons) and its tabs
   follow; an active style section heals to the new one.
5. Filters → Categories, switch to Layout, back to Filters: returns to Categories.
6. Defaults on Layout restores only Layout rows for the selected container.
7. Layout → Anchor → frame picker: after picking, the panel returns to Containers → Layout.
8. In combat the whole page, rail included, is under the combat cover.

## 9. Follow-ups filed

The pattern is parked for two more addons, one GitHub issue each, citing this spec. Both depend on
the §4 library minor and the §5 standard change landing first.

- **MultiMeters#55**: scope to be set when it is picked up.
- **KickCD#33** (owner, 2026-09-26): a new **Grid** page replaces the Icons, Cast bar and Text
  Label pages. Its rail entries are Icons · Cast bar · Text Label, under one pinned **Unit** band
  (today's `PageBanner`) shared by all three. General, Spells and Profiles are unchanged.
- **PanelMaster#55**: filed, then closed as `state:will-not-do`. The owner ruled it not needed
  (2026-09-26).
