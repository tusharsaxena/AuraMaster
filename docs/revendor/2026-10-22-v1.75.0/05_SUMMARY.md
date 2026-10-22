# 05 — Summary: LibKa0s v1.71.0 -> v1.75.0

Run 2026-10-22, item `AM-RV` of the 2026-10-22 run "LibKa0s issues #45-#58" (M2), on branch
`feat/2026-10-22-libka0s-issues-45-58`, non-interactive under the run's rulings. The addon version
was not bumped, no issue was filed or closed, and `libs/` and `tests/_kit/` were not touched after
the copy and the prune.

## The move

The vendored LibKa0s moved from **v1.71.0** to **v1.75.0** (local tag object `eae0ee5`, commit
`265a89e`), spanning v1.72.0, v1.73.0 and v1.74.0, which this addon never vendored on their own. The
base came from the `CLAUDE.md` provenance line and agrees with the last payload commit (`b4c29ab`).
Thirteen files move a minor (Core 11, Item 3, Media 5, Widgets 13, DebugLog 20, DebugLogDiagnostics
3, Options 29, OptionsIdList 5, OptionsTabs 9, Perf 15, PerfPanel 7) and six arrive (Glow 1,
MediaIcons 1, OptionsDrawer 1, Sim 1, SimTimeline 1, SimPanel 1). The kit moves from revision **38
to 41** and gains `latch.lua`. Seventeen majors across forty files. No span bundle (`01_DELTA.md`
3h).

## Delivered for free (class A)

Settings pages keep their scroll position on a structural refresh; `/am diagnostics` names Glow and
Sim when present; the complexity suite reports a lizard crash instead of passing blind; the vendor
gate holds the icon folder to the declaration.

## Contract blockers (3g), fixed in the copy commit

- `settings/OptionsSetup.lua`: the Options stub gains `Drawer` (v1.73.0 surface parity,
  `tests/test_surface_parity.lua:46`). No `__releaseChrome` mirror existed to delete.
- `tests/test_optionssetup.lua`: the info-art case now reads the `LibKa0s icons:` line through the
  kit's `iconDeclaration` before checking `info.tga` on disk.
- `tests/test_setups.lua`: a new case holds the declaration equal to the `NS.Icon` literals plus the
  library-drawn close, copy, clear and info.

## Icons

`LibKa0s icons: clear, close, copy, help, info.` written under the provenance line (`CLAUDE.md:37`);
no provenance split was needed. The prune removed 5,834 files: 219 Open Iconic, 1,435 Phosphor
(license included), 4,180 Game-icons (license and `AUTHORS.txt` included). `media/icons/` ships five
`.tga` and `LICENSE-open-iconic.txt`.

README `## Credits`: the Open Iconic line now covers the handle's ? and X, the debug console's close,
copy and clear buttons and the settings' help marks, credited to Waybury (MIT); the sentence that
named the bundled LibKa0s payload is gone (credit goes to sets). No Phosphor or Game-icons line,
since neither set ships.

## Also in the copy commit

- `CLAUDE.md:36` provenance -> v1.75.0; `DEPENDENCIES.md:85` and `:92`, `docs/module-map.md:309`
  -> v1.75.0, and the module map's note on the unbound Glow and Sim majors and the five icons.
- `DEPENDENCIES.md`'s `tests/_kit/vendor_sync.lua` citations moved to kit 41's lines, and its
  `tests/test_setups.lua` citation names the new icon-declaration scan (`:72`) and the moved metadata
  scan (`:106`).
- `core/MediaSetup.lua` comments (comment-only): the icons ship pruned to the declaration, so a new
  `NS.Icon` name is declared first.
- `tests/test_vendor_sync.lua` header: one sentence on kit 40's declared-icons gate.
- `docs/test-cases.md` regenerated (`lua tests/run.lua --list`); README Tests badge 2123 -> 2124.

## Adopted, declined, unreached

- **Adopted**: none.
- **Not adopted in this run**: `W.SearchBox`, `W.TestStrip`, `W.StepPanel` (not public), `O.Drawer`,
  `Item.BonusIDsFromLink`, `Kit.assertLatchHoldOrder`, `LibKa0s-Glow-1.0`, `LibKa0s-Sim-1.0`. See
  `03_DECISIONS.md`.
- **Declined**: none; no issue filed (M2 rule).

## Gates on the copy commit

All run through `dev-copilot/bin/ka0s-bounded`.

| Gate | Result |
|---|---|
| `lua tests/run.lua` | 2124 passed, 0 failed, 1 skipped (the declared diagnostics opt-out), 2125 total (16 shards); both vendor-sync payload cases and the runner-mode case PASS, not SKIP |
| `luacheck .` | 0 warnings / 0 errors in 178 files |
| `bash tests/_kit/run-automated-tests.sh --suite complexity --no-bundle` | pass, 0 warnings, max CCN 15, 5610 functions, 0 crashed files; verdict green |
| vendor parity | `diff -r` against the tag empty for both payloads before the prune |

In-game smoke is the owner's: SM-AM-1 to SM-AM-6 are `docs/smoke-tests.md` INSTALL-10 (SM-AM-1, SM-AM-6), DIAG-21 (SM-AM-2), CONT-26 (SM-AM-3), FILT-64 (SM-AM-4) and DIAG-22 (SM-AM-5), all pending.
