# 05 — Summary: LibKa0s v1.70.0 -> v1.71.0

Run 2026-10-07, item `RV-AM` of the 2026-10-07 review and standards-audit remediation, on branch
`feat/2026-10-07-review-audit-remediation`, non-interactive under the owner's scope ruling. The addon
version was not bumped, no issue was filed, and `libs/` and `tests/_kit/` were not touched after the
copy.

## The move

The vendored LibKa0s moved from **v1.70.0** to **v1.71.0** (local tag object `3bf1b97`, commit
`cb274a4`). The base came from the `CLAUDE.md` provenance line and agrees with the last payload commit
(`c070393`). Six files move a minor: Env 2, Slash 20 and SlashParse 2 (key 20.2), WidgetsLineChart 3
and WidgetsAutocomplete 2 (Widgets key 12.1.4.3.2), OptionsIdList 4 (Options key
28.2.34.2.4.8.1.7.4.2). The kit moves from revision **37 to 38** and gains `secrets.lua`. Nothing is
deleted.

## Span bundle

`docs/revendor/2026-10-07-v1.69.0-v1.70.0/` records the two tags (v1.69.0 in `3656914`, v1.70.0 in
`c070393`) that were vendored without a bundle, finding `AM-A-01`. Both: carried by sweep, nothing
adopted.

## Delivered for free (class A)

`/am set` refuses `nan` and the infinities on number rows; `docs/test-cases.md` counts the declared
skip on its own row, so its Total (2049) now equals the README badge; Env and OptionsIdList drop dead
bare-global fallbacks.

## Contract blockers (3g)

None. The ParseValue refusal closes a hole no AuraMaster path relies on; Env's change is invisible to
`core/EnvSetup.lua`; the Widgets and Options moves are on surfaces AuraMaster does not call.

## Also in the copy commit

- The `CLAUDE.md` provenance line, `DEPENDENCIES.md:85` and `:92`, and `docs/module-map.md:293` move
  to v1.71.0.
- `docs/test-cases.md` regenerated with `lua tests/run.lua --list`. The README badge stays at
  2049/2049, which now equals Total.

## Adopted, declined, unreached

- **Adopted**: none.
- **Not adopted in this run**: `Kit.secret` (plausible fit), `ChartMath.ClipSegment`, the chart's
  hover re-sync, the autocomplete re-hook (no fit). See `03_DECISIONS.md`.
- **Declined**: none.

## Gates on the copy commit

All run through `dev-copilot/bin/ka0s-bounded`.

| Gate | Result |
|---|---|
| `lua tests/run.lua` | 2049 passed, 0 failed, 1 skipped, 2050 total (16 shards) |
| `luacheck .` | 0 warnings / 0 errors |
| `bash tests/_kit/run-automated-tests.sh --suite complexity --no-bundle` | verdict green; sighted, **1 warning**, max CCN 18, 5443 functions. The warning is `logCandidates` (`modules/Anchors_Snap.lua`), older than this run and owned by item `AM-05` of the same remediation; this commit changes no Lua the addon owns |
| vendor parity | `diff -r` against the tag is empty for both payloads |

In-game smoke (owner's): `/reload` with AuraMaster enabled, no Lua errors; `/am help`,
`/am containers` and the settings panel open as before.
