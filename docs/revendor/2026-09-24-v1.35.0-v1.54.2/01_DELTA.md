Delta: LibKa0s v1.35.0 -> v1.54.2 (span: v1.35.0 v1.36.0 v1.36.1 v1.36.2 v1.37.0 v1.38.0 v1.39.0 v1.42.0 v1.43.0 v1.44.0 v1.45.0 v1.46.1 v1.47.0 v1.48.0 v1.48.1 v1.49.0 v1.49.1 v1.50.0 v1.51.0 v1.52.0 v1.53.0 v1.54.2)

# 01 - Delta: the lapsed span, LibKa0s v1.35.0 through v1.54.2

A consolidated span bundle (`audit-review-history`), written 2026-09-24 as remediation item AM-02
(finding `AuraMaster-A-01`). Between the store's `2026-09-13-v1.34.0` bundle and its
`2026-09-23-v1.55.0` bundle, this repo vendored 22 LibKa0s tags and wrote no bundle for any of
them. This folder records all 22 at once. It holds `01_DELTA.md` and `05_SUMMARY.md` only: the
tags were carried by sweeps and feature work, and nothing about them is decided in retrospect.

**The true previous base is v1.34.0**, vendored in `0c6f99f` (2026-09-13) and recorded in
`docs/revendor/2026-09-13-v1.34.0/`. The span runs from the first unrecorded tag, v1.35.0, to the
last, v1.54.2. The span's last tag is the base the frozen `docs/revendor/2026-09-23-v1.55.0/`
bundle names (`v1.54.2 -> v1.55.0`), and that base is correct: see v1.54.2 below.

## How the tag list was derived

From the provenance history, not from a listing of `libs/LibKa0s` alone:

```
git log --format=%h -p 0c6f99f..329e1a3 -- CLAUDE.md | grep '^+Bundles'
git log --format='%h %ad %s' --date=short 0c6f99f..329e1a3 -- libs/LibKa0s tests/_kit
```

A `libs/`-only listing misses three tags. v1.43.0 (`76224d7`) is kit-only apart from its
provenance roll; v1.45.0's payload landed in `4ebdb4a` while the provenance line was rolled in
`8923a1a`; and v1.54.2 (`329e1a3`) touches `tests/_kit/` only, because the library bytes are
identical to v1.53.0 (`git -C ../LibKa0s diff --quiet v1.53.0 v1.54.2 -- LibKa0s` exits 0).
LibKa0s tags this repo never vendored (v1.40.0, v1.41.0, v1.46.0, v1.54.0, v1.54.1) are not on
the span line: the addon never carried them, so there is nothing to record.

## The library across the span

Tags: v1.34.0 is commit `33bae81`, v1.54.2 is commit `85d32f2`.

```
git -C ../LibKa0s log --oneline v1.34.0..v1.54.2
  85d32f2 Release v1.54.2
  ff2faba Release v1.54.1
  8081886 Release v1.54.0
  1040f3d Ship the prose gate in the kit, so the twelfth repo does not write a thirteenth copy
  ca19373 Sync the docs to what the code actually does
  44758ed Release v1.53.0
  8f85c64 Merge fix/add-button-matches-the-box: the Add button matches the box's height
  976119c Options widgets minor 30: the Add button is the height of the box beside it
  0beb76c Say where the help level actually lives
  c10d0ce Merge feat/help-mark-severity: the help mark's reserve, glyph and severity
  610aee1 Release v1.52.0
  2df8347 Options widgets minor 29: fix the reserve, ship the glyph, tint by severity
  1da039f Merge feat/idlist-help-mark: O.IdList's help mark, suggestion tag and lit rows
  f5e3a1d Release v1.51.0
  5d8875c Options widgets minor 28: the help mark, the tag, and the lit row
  f538d3f O.IdList: a per-entry help mark, and light every row
  c45833c Release v1.50.0
  61cf04f Merge fix/idlist-followups-34: the five O.IdList follow-ups from LibKa0s #34
  a6c115f Options widgets minor 27: the four O.IdList follow-ups
  de5791f Record why the tooltip is not anchored under the hovered entry
  18e2f0c Say where the consumers actually stand, in both paragraphs
  d237433 Draw the column count the canvas can pay for, not the one asked for
  09bdd92 Light the whole of the X, not just the art inside it
  38a3e36 Clear an entry label's markers when AceGUI pools it
  2dc288b Stop quoting a pixel figure the file calls unknowable
  b0627ec Release record for v1.49.1
  be3e7a6 Options widgets minor 26: a based host kind inherits its base's client source
  6185caf Release record for v1.49.0
  822d64c Options widgets minor 25: an id-list entry can carry a short suffix
  854b4c2 Release record for v1.48.1
  473f2f0 WidgetsDragHandle minor 2: brighten the mark only where a click is wired
  de7e37e Release record for v1.48.0
  813abf5 Widgets minor 10: lib.DragHandle, the unlock anchor both addons hand-built
  a8feebe Release record for v1.47.0
  88de993 Options widgets minor 24: O.IdList draws multiple columns
  d5c4061 docs: sync README and DEPENDENCIES with v1.46.1
  6504429 The v1.46.1 release record
  3c95cf0 LibKa0s v1.46.1: the combat lock stands down with the page (Options minor 23, OptionsTabs 3)
  048edd1 The v1.46.0 release record
  7ae1763 LibKa0s v1.46.0: the combat lock (Options minor 22, OptionsWidgets 23, OptionsTabs 2)
  2b32ee8 docs: v1.45.0's step 8 and 9 — consumers re-vendored on branches; shownWhen adopters
  a7053ca The v1.45.0 release record
  6dbfc74 LibKa0s v1.45.0: switched sections — shownWhen (OptionsWidgets minor 22)
  30ed9c2 The Consumers table's line citations follow the sources
  d68aeab The Consumers table after the v1.44.0 re-vendor
  7ae5b3b The v1.44.0 release record
  04221d5 IdList can draw an X on the left of each entry (removeStyle = "icon")
  807b284 DEPENDENCIES.md cites the kit's ls -A where revision 23 moved it
  c091705 The v1.43.0 release record
  b2a5266 Kit 23: a headless run is bounded, and the mock lets go of what a case built
  d0751cb The v1.42.0 release record
  8512fa1 Slash 14: an unshipped reserved verb answers the same in both states
  05ec134 The v1.41.0 release record
  37a180f Slash 13: the disabled surface is the twelve reserved verbs again
  b050a03 The v1.40.0 release record
  a08e6f1 Release v1.40.0: move every version-bearing line to the version being shipped
  22be971 LibKa0s-Lifecycle-1.0: one latch, two holds, no second teardown path
  515ba70 Record the four-suite run of 2026-09-16
  62040f3 Cover the half-vendored pair, and correct one census figure
  209f3f0 The v1.39.0 record, and the census figures corrected to it
  c9c0e5f README: the live MODULES snapshot is v1.39.0
  40594ef v1.39.0: move every version-bearing line and re-derive the counts
  b3e161c Peel the page's chrome out to OptionsTabs.lua (#16, #8)
  c8096ea A new major: LibKa0s-Launcher-1.0, one object registered twice
  4057a25 MasterControls grows a minimap seam; Test mode moves beside it
  5d9833b The consumer count is eleven, and one census had inverted
  4cc54de Record the 20260916-093057 run and re-measure what the docs quote from it
  5fceda5 releasing.md: where v1.38.0 stands
  efcb4ba Automated-test bundle for v1.38.0 (20260916-033929)
  3475a4a import json, sys, subprocess m = json.load(open(sys.argv[1])) head = subprocess.check_output(["git", "rev-parse", "HEAD"]).decode().strip() suites = {k: v.get("status") for k, v in m["suites"].items()} warn = m["suites"]["complexity"].get("warnings") print("release", m.get("release"), "dirty", m["git"].get("dirty"), "sha", m["git"].get("sha")[:7], "head", head[:7], suites, "complexity.warnings", warn) ok = (m.get("release") == "1.38.0" and m["git"].get("dirty") is False and m["git"].get("sha") == head       and suites.get("lint") == "pass" and suites.get("tests") == "pass" and suites.get("complexity") == "pass" and warn == 0) sys.exit(0 if ok else 1) PY Release v1.38.0: bare /<slash> runs the host's config verb
  4f8c344 releasing.md: record v1.37.0's step 8 and 9; add PartyFrameEnhanced
  a7409f8 Automated-test bundle for v1.37.0 (20260916-015507)
  6f8e00c Release v1.37.0: MasterControls composes the Test mode row
  3cb6a1f Merge branch 'feat/2026-09-14-v1.36.0': release LibKa0s v1.36.0 -> v1.36.2
  a5b6be9 README: point the Options module row at the current API doc
  6acc177 Automated-test bundle for amended v1.36.2 (20260915-140452)
  d39e4b4 Fix round: rewrite the ASCII guard to decode bytes, not match escape text
  9e01f02 Automated-test bundle for amended v1.36.2 (20260915-135323)
  ed87935 Amend v1.36.2: fix the one player-facing non-ASCII byte this library ships
  df0be76 Automated-test bundle for v1.36.2 (20260915-133630)
  331416d Release v1.36.2: withdraw ChoiceGrid's yellow fill on owner feedback
  e43142d Fix: ChoiceGrid's gold checkbox fill leaking into every recycled CheckBox (v1.36.1)
  3dcf3a8 Release v1.36.0: ChoiceGrid checkbox cells + extra column, IdList note, O.SelectTab
  6dcbd80 Fix: Options.SelectTab scopes its refresh to the target page (K-4 fix 1)
  f5d34c3 Options: O.SelectTab moves a rendered page to one tab (K-4)
  1b3936d Options: an IdList entry may carry a note line (K-3)
  4f0960a Options: choiceExtraCell checks onClick is callable, not truthy (K-2 hardening)
  2f2f299 Options: ChoiceGrid takes an optional extra link column (K-2)
  5845429 Options: ChoiceGrid cells are checkboxes with a yellow fill, not radios (K-1)
  1dc3337 Merge branch 'chore/2026-09-14-last-nits': the .luacheckrc LK_TEST comment cites tests/run.lua:37
  b07f504 Lint: the LK_TEST comment cites tests/run.lua:37, where the write is
  1a1604a Merge branch 'docs/2026-09-14-followups': v1.35.0 follow-ups - releasing state, cap census and layout-cap comment re-measured, kit README counts
  8a81528 Tests: the layout-cap comment carries the 2026-09-14 line counts
  e83e740 Docs: v1.35.0 follow-ups (releasing state, cap census re-measured, kit README counts)
  48c9050 Merge branch 'feat/2026-09-13-v1.35.0': v1.35.0 - disabledIf everywhere, ChoiceGrid, IdInput/IdList with name suggestions (Options 18.16.5.3, kit 20), sync-docs
  ee86c36 Docs: sync-docs pass for v1.35.0 (ten consumers, 57 lint files, Options' id and choice surfaces)
  6036c26 v1.35.0: release test record 20260914-010923 (re-cut)
  ebd51a8 Options: a based kind's view cache no longer leaks on Lua 5.1; pin its contracts (#31)
  45e035e Options: a host kind's `base` wears a library kind's decorations (#31)
  80b8d15 v1.35.0: release test record 20260914-001514 (re-cut)
  d48e7ea Docs: a shared name the bags or spellbook carry is ambiguous; typing drops the highlight (#31)
  4ec7040 Options: IdInput refuses a shared name the bags or spellbook carry; typing drops the highlight (#31)
  48b486d v1.35.0: release test record 20260913-233500 (re-cut)
  7f1a8fd v1.35.0: re-cut docs for the suggestions and the name lookup (closes #31 in CHANGELOG)
  8c000d3 Docs: IdInput's refused-name list, closing rules, host limits and in-game checks (#31)
  17b114a Options: a refused shared name lists its ranks, and no list goes up under a box the player left (#31)
  b078225 Docs: IdInput's suggestions in the Options 18.16.5.3 API doc, kit 20's second opt-in, CHANGELOG
  86c3cab Options: IdInput suggests matching names as the player types, every rank its own row (#31)
  6dc1af6 Options: IdInput never adds one rank of a shared name, and a host kind can be looked up
  c00edce Options: IdInput looks a name up among uncached item candidates, and says where names work
  5385cf3 v1.35.0: release test record 20260913-180115 (re-cut)
  3c68fc3 v1.35.0: regenerate docs/test-cases.md at the re-cut head (972 cases)
  abd87e6 Options: IdList draws an item's name in its quality color
  90e34d6 CHANGELOG: v1.35.0 pins disabledIf / opts.disabled with eight cases, not seven
  8461bd0 Options: IdInput clears its box and status line before onAdd
  be51d6c Options: IdList batches uncached item loads and re-asks a slow one
  98eddd3 v1.35.0: release test record 20260913-094012
  07e55cd LibKa0s v1.35.0: disabledIf everywhere, ChoiceGrid, IdInput/IdList (Options 18.16.5.3, kit 20)
  a833a4c Options: IdInput/IdList/ResolveId — add by id, link or name (spell/item/currency); kit 20 opt-in id lookups
  07704ad Tests: ChoiceGrid lit-cell click mirrors AceGUI's toggle; label re-enable asserted
  54ac640 Options: ChoiceGrid - a matrix of radio cells over rows sharing one value list
  c64e5ee Options: disabledIf on every maker (path or predicate) + RenderRows opts.disabled
  7103710 docs(releasing): v1.34.0 is merged in all ten consumers
  d7e41db Merge branch 'feat/2026-09-13-v1.34.0': LibKa0s v1.34.0 (Slash free text keeps every word, Reset-all tooltip + profilesPage, kit 19)
  59178b7 Merge branch 'feat/2026-09-12-v1.33.0': LibKa0s v1.33.0 (font preload on first panel show, Slash 9 docstrings, kit 18)
  db83b1d docs: sync-docs pass (v1.34.0 module links, lint scope, four-file Options, consumer facts)
  eec5e9c docs(v1.34.0): MultiMeters is not a one-line profilesPage adopter

git -C ../LibKa0s diff --stat v1.34.0 v1.54.2 -- LibKa0s testkit
  LibKa0s/Launcher.lua           |  295 ++++
  LibKa0s/LibKa0s.xml            |    4 +
  LibKa0s/Lifecycle.lua          |  208 +++
  LibKa0s/Options.lua            |  272 ++-
  LibKa0s/OptionsCompose.lua     |   56 +-
  LibKa0s/OptionsTabs.lua        | 1197 +++++++++++++
  LibKa0s/OptionsWidgets.lua     | 3723 ++++++++++++++++++++++++++++++----------
  LibKa0s/Perf.lua               |  119 +-
  LibKa0s/Slash.lua              |  177 +-
  LibKa0s/WidgetsDragHandle.lua  |  520 ++++++
  testkit/README.md              |  143 +-
  testkit/framework.lua          |  320 +++-
  testkit/mock_base.lua          |  322 ++--
  testkit/mock_ids.lua           |  204 +++
  testkit/mock_record.lua        |  618 +++++++
  testkit/run-automated-tests.sh |  110 +-
  testkit/test_prose.lua         |  335 ++++
  17 files changed, 7449 insertions(+), 1174 deletions(-)
```

## The repo commits that carried each tag

| Tag | Repo commit | Date | What arrived |
|---|---|---|---|
| v1.35.0 | `9ba3d01` | 2026-09-13 | OptionsWidgets minor 16: `disabledIf`, ChoiceGrid, IdInput/IdList; kit revision 20 adds the opt-in `mock_ids.lua`. |
| v1.35.0 (re-cut) | `7b18a4b` | 2026-09-13 | Tag re-cut at LibKa0s `5385cf3`: IdList quality color, load batching, input cleared before `onAdd`; `mock_ids.lua` gains a quality argument. Minor 16, kit 20. |
| v1.35.0 (re-cut) | `1dc5c61` | 2026-09-14 | Tag re-cut at `48b486d`: IdList autocomplete and name lookup beyond the bags (`UnnamedCandidates`, `ID_NAME_HINT`); `mock_ids.lua` gains the suggestion sources. |
| v1.35.0 (re-cut) | `abc3a5f` | 2026-09-14 | Tag re-cut at `80b8d15`: a name the bags or spellbook carry under another id is ambiguous. OptionsWidgets only. |
| v1.35.0 (re-cut) | `2a3f63e` | 2026-09-14 | Tag re-cut at `6036c26`: a host kind may set `base` and inherit the base kind's decorations. OptionsWidgets only. |
| v1.36.0 | `f4e09a4` | 2026-09-15 | ChoiceGrid checkbox cells and an extra column, IdList `note`, `SelectTab`. |
| v1.36.1 | `9aa2483` | 2026-09-15 | ChoiceGrid restores the pooled CheckBox vertex color on release; kit revision 20 -> 21. |
| v1.36.2 | `bd4fa80` | 2026-09-15 | ChoiceGrid's yellow fill withdrawn; library player-facing strings made ASCII. Kit unchanged. |
| v1.37.0 | `fec3784` | 2026-09-16 | The composed Master controls Test mode row (standard v2.46.0, options-ui-§15). |
| v1.38.0 | `e4cfa04` | 2026-09-16 | Slash minor 11: a bare slash goes to the host's config verb. |
| v1.39.0 | `5d2520c` | 2026-09-16 | New `Launcher.lua` (LibKa0s-Launcher-1.0) and `OptionsTabs.lua` (the tab strip peeled out of Options). Kit unchanged at 21. |
| v1.42.0 | `42bdff6` | 2026-09-17 | New `Lifecycle.lua` (LibKa0s-Lifecycle-1.0, minor 1), Perf minor 12, Slash minor 14 (`isEnabled`, `brandName`, `liveVerbs`). |
| v1.43.0 | `76224d7` | 2026-09-17 | Kit revision 23: bounded runs, heap budget, leak gate, CPU ceiling. Library bytes identical. |
| v1.44.0 | `b66b21b` | 2026-09-19 | OptionsWidgets minor 21: opt-in `removeStyle = "icon"` on IdList. Kit 23. |
| v1.45.0 | `4ebdb4a` (payload), `8923a1a` (provenance) | 2026-09-19 | OptionsWidgets minor 22: `shownWhen`. The payload was staged into a feature commit; the line rolled in the next. |
| v1.46.1 | `1acb2db` | 2026-09-19 | Options minor 23, OptionsWidgets minor 23, OptionsTabs minor 3: the settings combat lock (`__combatCover`, `COMBAT_LOCKED_NOTICE`). Kit unchanged. |
| v1.47.0 | `c0552a5` | 2026-09-20 | IdList `columns`. |
| v1.48.0 | `6462e06` | 2026-09-21 | New `WidgetsDragHandle.lua` (the drag strip widget). Kit unchanged. |
| v1.48.1 | `29aef45` | 2026-09-21 | WidgetsDragHandle minor 2: the help mark's over-tint only when `onRightClick` is set. |
| v1.49.0 | `7787b0f` | 2026-09-21 | OptionsWidgets minor 25: optional `entry.suffix`. |
| v1.49.1 | `d1d2f3b` | 2026-09-21 | A host kind table with `base = "spell"` gets the spellbook suggestions back. OptionsWidgets only. |
| v1.50.0 | `5c3a093` | 2026-09-21 | IdList `columns` becomes a maximum measured against the content width at draw time. |
| v1.51.0 | `482000f` | 2026-09-22 | IdList per-entry help mark and `kind.suggestTag`. |
| v1.52.0 | `f434521` | 2026-09-22 | The help mark's row reserve fixed; `help.level` for the mark's severity. |
| v1.53.0 | `f6f61d3` | 2026-09-22 | OptionsWidgets minor 30: IdInput's Add button matches the edit box height. Kit 23. |
| v1.54.2 | `329e1a3` | 2026-09-22 | kit-only: library bytes identical to v1.53.0. Kit revision 24 brings `test_prose.lua`, the US-English gate. |
