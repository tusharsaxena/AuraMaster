# 05 — Summary: LibKa0s v1.76.0 -> v1.77.0

Run 2026-10-24, item `AM-RV` of the 2026-10-24 run "keybindings (015), settings layout (020), frame
strata (030)" (M2), on branch `feat/2026-10-24-keybinds-layout-strata`, non-interactive under the
run's rulings. The addon version was not bumped and no issue was filed or closed. `libs/` and
`tests/_kit/` were not touched after the copy and the prune.

## The move

The vendored LibKa0s moved from **v1.76.0** to **v1.77.0** (local tag object `7380d36`, commit
`78240f7`). The base came from the `CLAUDE.md` provenance line and agrees with the last payload
commit. Twelve files move a minor and one is new (`OptionsKeybinds.lua` at 3); see `01_DELTA.md`
3c. The kit moves from revision **41** to **42**. Seventeen majors across forty-one files.

No span bundle (3h printed nothing) and no base correction.

## Delivered for free (class A)

The debug console and the perf panel are toplevel and keep a shown confirmation on top. Library
dropdown menus and the ID suggestion list are clamped to the screen, and the suggestion list closes
when combat starts.

## Contract blockers (3g)

One, fixed in the copy commit. The Options degradation stub in `settings/OptionsSetup.lua` gains
`KeybindingsTab`, `KeybindRows` and `StrataTooltip` as no-ops and `KEYBINDS_UNCHANGED = ""`, which
`Kit.assertSurfaceParity` (`tests/test_surface_parity.lua`) required once the live instance had them.
Three line citations of `settings/OptionsSetup.lua` moved +5 with it, and seven comment citations
into the payload were re-pointed (`01_DELTA.md`, *Citations into the payload*).

## Icons

`LibKa0s icons: clear, close, copy, help, info.` kept (`CLAUDE.md:37`). The prune removed 5,834
files, leaving five `.tga` and `LICENSE-open-iconic.txt`. README credits unchanged. No dead stub
mirror.

## Also in the copy commit

- `CLAUDE.md:36` provenance -> v1.77.0; `DEPENDENCIES.md:85` and `:92` and `docs/module-map.md:309`
  -> v1.77.0.
- The standards reference was checked against standard v2.88.0, read from the WowAddonStandards run
  branch (`feat/2026-10-24-keybinds-layout-strata` @ `897fbd3`), which is not pushed yet. All three
  places were already correct: TOC `## X-Standard:` URL, the bare README badge, and the `CLAUDE.md`
  *Standards compliance* section with the stop-and-flag rule. No version is written into them, per
  the procedure's no-version-stamp rule. The sweep found no `filename-§N` citation that fails to
  resolve against v2.88.0's section files, and no retired notation in the swept tree. The
  `docs/testing.md` and `docs/automated-tests/README.md` gate statements already name their
  checkpoints, and `.gitattributes` carries the CRLF pin and both carve-outs. No quirks block
  is vendored: the addon has none and the procedure creates none here.

## Adopted, declined, unreached

- **Adopted by this item**: none. DragHandle `level` / `ApplyLevel` / `ignoreParentAlpha`,
  `O.StrataTooltip` and the kit's `mock_layers.lua` go to the run's AM-ZS item.
- **Deferred (run 2026-10-24)**: the Keybindings tab, `Core.RaiseStaticPopups`, and the kit's
  binding mock and binding checks. See `03_DECISIONS.md`.
- **Declined**: none. No issue was filed (run rule).

## Gates on the copy commit

All run through `dev-copilot/bin/ka0s-bounded`.

| Gate | Result |
|---|---|
| `lua tests/run.lua` | 2127 passed, 0 failed, 1 skipped (the declared diagnostics opt-out), 2128 total (16 shards). Both vendor-sync payload cases pass against v1.77.0 |
| `luacheck .` | 0 warnings / 0 errors in 178 files |
| `bash tests/_kit/run-automated-tests.sh --suite complexity --no-bundle` | pass, 0 warnings, max CCN 15, 5617 functions; verdict green |
| 1500-line cap | largest authored `.lua` is `defaults/Categories.lua`, 1344 lines |
| vendor parity | `diff -r` against the tag empty for both payloads before the prune |

No in-game smoke is added. What reaches AuraMaster for free is library behaviour, and the library's
own smoke list covers it (SM-LK-*).
