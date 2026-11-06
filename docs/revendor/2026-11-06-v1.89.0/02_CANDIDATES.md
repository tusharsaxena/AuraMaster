# Candidates

Sources: `git -C ../LibKa0s log --oneline v1.85.0..v1.89.0`, the CHANGELOG blocks v1.86.0..v1.89.0 and the
`docs/api/` documents of every major whose minor moved (`01_DELTA.md` 3c, 3g).

## A. Delivered on the re-vendor

- **Kit 50 -> 51** (v1.89.0): the CallbackHandler unregister guard, a flake fix in the test kit.
- **DebugLogDiagnostics 6 -> 7** (v1.86.0): the report's `LibKa0s running:` line names IconBrowser when it
  runs. No member change (`docs/api/DebugLog/version-22.7.1.4-docs.md`, "No member change"); no AuraMaster
  suite pins the minor.
- **Widgets 22 -> 23** (v1.87.0): flat menus and dropdowns draw what 22 drew
  (`docs/api/Widgets/version-23.5.12.6.7.5-docs.md`, "What a consumer owes: nothing for a flat menu").
  `WidgetsDragHandle.lua` stays at 12, so the anchor strip (`modules/Anchors.lua:464`) is unchanged.
- **Toast 3 -> 4** (v1.88.0): carried; AuraMaster does not look Toast up and has no Toast stub.

## B. Host change required

- **Widgets 23 cascading-menu fields** (`submenu`, `radio`, `selected`, `opts.check`): AuraMaster has no
  `W.ContextMenu` use site (`grep -rnE 'ContextMenu'` outside `libs/` and `tests/_kit/` is empty; the
  launcher menu is `LibKa0s-Launcher-1.0`'s, drawn through the client's `MenuUtil`). Not applicable.
- **Toast 4 stack** (`SetStack`, `Visible`, `FrameFor`): no Toast consumer. Not applicable.

## C. Whole-module adoption

- **`LibKa0s-IconBrowser-1.0`** (v1.86.0, `docs/api/IconBrowser/version-1.1.1-docs.md`): an icon chooser.
  AuraMaster's UI offers the player no choice among catalog icons (`grep -rniE 'icon ?(picker|chooser|browser)'`
  outside `libs/` is empty), so there is no host surface for it. Additive if ever adopted.

No genuine candidate outside the run plan's decisions table.
