# 05 — Summary: LibKa0s v1.75.2 -> v1.76.0

Run 2026-10-23, item `AM-RV` of the 2026-10-23 run "sim auto-run, QC preview selector, mode strips,
MM/KCD simulators" (M2), on branch `feat/2026-10-23-sim-preview-mode-strips`, non-interactive under
the run's rulings. The addon version was not bumped, no issue was filed or closed, and `libs/` and
`tests/_kit/` were not touched after the copy and the prune.

## The move

The vendored LibKa0s moved from **v1.75.2** to **v1.76.0** (local tag object `546e284`, commit
`9949368`). The base came from the `CLAUDE.md` provenance line and agrees with the last payload
commit (`34772b4`). Three files move a minor: Widgets 13 -> 14, SimTimeline 2 -> 3, SimPanel 4 -> 5.
The kit stays at revision **41**, bytes unchanged. Seventeen majors across forty files.

A consolidated span bundle, `docs/revendor/2026-10-23-v1.75.1-v1.75.2/`, records the two tags
(v1.75.1, v1.75.2) that plain re-vendor commits carried without a bundle. No base correction.

## Delivered for free (class A)

Nothing visible: the only consumed major that moved, Widgets, changed `TestStrip` alone, which
AuraMaster does not call.

## Contract blockers (3g)

None. No `__Attach*` site; Widgets 14 is additive; Sim is not consumed and no host string or suite
names Run all.

## Icons

`LibKa0s icons: clear, close, copy, help, info.` kept (`CLAUDE.md:37`). The prune removed 5,834
files, leaving five `.tga` and `LICENSE-open-iconic.txt`. README credits unchanged. No dead stub
mirror.

## Also in the copy commit

- `CLAUDE.md:36` provenance -> v1.76.0; `DEPENDENCIES.md:85` and `:92` and `docs/module-map.md:309`
  -> v1.76.0 (they still named v1.75.0, since the v1.75.1 and v1.75.2 sweeps rolled only `CLAUDE.md`).

## Adopted, declined, unreached

- **Adopted**: none.
- **Not adopted in this run**: `W.TestStrip` `kind = "sim"`, `LibKa0s-Sim-1.0` (settled), Glow and
  Item (settled). See `03_DECISIONS.md`.
- **Declined**: none; no issue filed (run rule).

## Gates on the copy commit

All run through `dev-copilot/bin/ka0s-bounded`.

| Gate | Result |
|---|---|
| `lua tests/run.lua` | 2127 passed, 0 failed, 1 skipped (the declared diagnostics opt-out), 2128 total (16 shards); both vendor-sync payload cases and the runner-mode case PASS, not SKIP |
| `luacheck .` | 0 warnings / 0 errors in 178 files |
| `bash tests/_kit/run-automated-tests.sh --suite complexity --no-bundle` | pass, 0 warnings, max CCN 15, 5617 functions; verdict green |
| 1500-line cap | largest authored `.lua` is `defaults/Categories.lua`, 1344 lines |
| vendor parity | `diff -r` against the tag empty for both payloads before the prune |

No in-game smoke is added: nothing AuraMaster draws changed.
