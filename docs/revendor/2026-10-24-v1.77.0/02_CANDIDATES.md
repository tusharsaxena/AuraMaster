# 02 — Candidates

Sources, all at the local tag `v1.77.0` in `../LibKa0s`: the `CHANGELOG.md` v1.77.0 block (line 13)
and the API documents named per row. The one 3g blocker (four Options stub members) is not a
candidate: it was fixed in the copy commit.

## A. Delivered on the copy

- **Toplevel tool windows that keep a shown confirmation on top** (Core 12, DebugLog 21, PerfPanel
  9): AuraMaster's debug console (`/am debug`) and its `/am perf` panel are DIALOG, clamped and now
  toplevel. On show they raise any shown StaticPopup, so a *Reset all settings* confirmation is
  not buried (`docs/api/Core/version-12-docs.md:24`).
- **Clamped popups** (Widgets 15, WidgetsAutocomplete 3): every library dropdown menu and the ID
  boxes' suggestion list on the settings pages stay on screen near an edge
  (`docs/api/Widgets/version-15.1.5.3.3-docs.md:14`).
- **The suggestion list closes at combat start** (OptionsIds 3, OptionsCombat 2): an ID box's
  suggestion list on the Spells and Filters pages no longer stays up over the combat cover.

## B. New surfaces (host change required)

| Surface | Evidence | Fit for AuraMaster |
|---|---|---|
| DragHandle `spec.level`, `handle:ApplyLevel()`, `spec.ignoreParentAlpha` (WidgetsDragHandle 5) | `docs/api/Widgets/version-15.1.5.3.3-docs.md:39`, `:45` | Good: replaces the L+50 re-level done by hand after construction (`modules/Anchors.lua`, `HANDLE_LEVEL`). LibKa0s CHANGELOG v1.77.0 names AuraMaster as an M2 adopter. The run's AM-ZS item. Replaces host code. |
| `O.StrataTooltip(values[, strings])` (OptionsCompose 8) | `docs/api/Options/version-30.2.34.3.5.9.2.8.4.2.1.3-docs.md:86` | Good: the container's Strata row is owed one (frame-layering-§1, options-ui-§16). The run's AM-ZS item. Additive. |
| `O.KeybindingsTab`, `O.KeybindRows`, `O.KEYBINDS_UNCHANGED` (OptionsKeybinds 2-3) | same document, `:61-63`, `:1539` | None today: AuraMaster has no window and no `Bindings.xml`, so options-ui-§20 does not apply. The run has no AM-KB item. |
| `Core.RaiseStaticPopups()` (Core 12) | `docs/api/Core/version-12-docs.md:24` | None: AuraMaster opens no tool window of its own that could cover a confirmation. |
| Kit revision 42: `mock_layers.lua`, `mock_bindings.lua`, `Kit.assertBindingsXml`, `Kit.keybindThroughTab` | `docs/api/testkit/version-42-docs.md:26` | `mock_layers.lua` is the tool AM-ZS's layering suites use. The binding mock and both binding checks do not apply (no `Bindings.xml`). |

## C. Whole-module adoption

| Major | Evidence | Fit for AuraMaster |
|---|---|---|
| `LibKa0s-Sim-1.0` | `docs/api/Sim/version-2.3.6-docs.md` | None: settled at v1.75.0 (`docs/revendor/2026-10-22-v1.75.0/02_CANDIDATES.md`). SimPanel 6 only makes the panel toplevel, so the premise has not moved. |
| `LibKa0s-Glow-1.0`, `LibKa0s-Item-1.0` | unchanged since v1.75.0 | None: settled at v1.75.0. |
