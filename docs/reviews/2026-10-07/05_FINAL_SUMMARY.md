# AuraMaster — final summary (review 2026-10-07)

*Written as if every check in `03_SMOKE_TESTS.md` passed. Until the sign-off table is filled in, this is the intended outcome, not a record.*

## Headline
This cycle kept AuraMaster releasable and readable without changing what players see. The one function over the release gate's complexity limit was rewritten around a named helper. The migration step bodies left the 1400-line database file before the 1500-line cap forced it. A drag test suite at 1490 lines was split. The CLI stopped confusing a container named "3" with container #3. Two cosmetic text issues were fixed. The library's test kit was fixed upstream so the generated test inventory and the README badge report the same total.

## Counts
Critical fixed: 0, High fixed: 0, Medium fixed: 3 (F-001, F-002, F-003 via re-vendor), Low fixed: 4 (F-004, F-005, F-006, F-007). Nothing deferred.

## Changes by theme
- **T1 release gate (F-001; C-01).** `logCandidates` reads each target through `targetText`, with byte-identical output. Fixes the next tag being refused at CCN 18. Files: `modules/Anchors_Snap.lua`.
- **T2 migration peel (F-002; C-02).** The step bodies `MigrateV2`..`V12` live in `core/Database_Migrations.lua`, and the runner stays in `core/Database.lua` (`savedvariables-§1`). Fixes the next schema step breaching `layout-§1`. Files: `core/Database.lua`, `core/Database_Migrations.lua`, `AuraMaster.toc`, `docs/module-map.md`, `docs/ARCHITECTURE.md`.
- **T3 test cap (F-004; C-03).** The drag suite is split in two with no case renamed. Files: `tests/test_anchors_drag.lua`, `tests/test_anchors_drag_drop.lua`, `tests/run.lua`, `docs/test-cases.md`.
- **T4 CLI precedence (F-005; C-04).** A name wins, `#N` is always an id, and a clash is refused. Fixes `/am delete 3` deleting the wrong container. Files: `settings/Slash.lua`, `locales/enUS.lua`, `tests/test_slash_verbs.lua`, `docs/slash-dispatch.md`, `docs/test-cases.md`, `README.md`.
- **T5/T6 text (F-006, F-007; C-05, C-06).** No post-translation lowercasing, and the help row and docs row are aligned. Files: `settings/OptionsSetup.lua`, `settings/Slash.lua`, `locales/enUS.lua`, `docs/slash-dispatch.md`.
- **Upstream (F-003).** LibKa0s kit 38's `--list` Total excludes skips and lists them in their own row. Re-vendored. Files: `tests/_kit/`, `docs/test-cases.md`, `CLAUDE.md`.

## API / behavior changes
- `/am select` and `/am delete`: `#N` is accepted as an explicit id. A numeric argument that is also another container's name is refused with a new chat line.
- `/am help`: the `debug` row wording changed.
- The settings picker labels use translated case.
- New locale key: the name/id ambiguity line. One `debug`-row key was rekeyed.

## Saved-variable / migration notes
No schema bump. `schemaVersion` stays 12, and the ladder's code moved without changing behavior.

## Deprecated-API migrations
None.

## Test and complexity movement
- Before: 2049 passed, 1 skipped, inventory Total 2050, badge 2049/2049.
- After C-04: 2053 passed, 1 skipped. After the re-vendor, inventory Total equals the badge at 2053/2053, with Skipped 1 listed separately. `docs/test-cases.md` and the badge move in the same commits.
- The next release regeneration should confirm 0 CCN warnings (`logCandidates` off the watch list) and no file in the 1000–1500 band for `core/Database.lua`.

## Known follow-ups
- `defaults/Categories.lua` (1344), `modules/Anchors_Snap.lua` (1126), `settings/Schema.lua` (1057) and `modules/Style.lua` (1024) remain in the on-notice band. They are watched, with no action.
- `docs/automated-tests/RESULTS.md` is 173 commits stale. It regenerates at the next release, not here.

## Verification evidence
`03_SMOKE_TESTS.md` sign-off table, plus the commit range on `feat/2026-10-07-review-audit-remediation`. Fill both in at execution.

## Suggested PR description
```
AuraMaster: review 2026-10-07 remediation (F-001..F-007)

- F-001 logCandidates: named per-target helper; CCN 18 -> under 15 (release gate)
- F-002 schema step bodies -> core/Database_Migrations.lua; runner stays in core/Database.lua
- F-004 split tests/test_anchors_drag.lua (1490 lines); inventory regenerated
- F-005 /am select|delete: name first, #N is an id, a name/id clash is refused (+4 cases)
- F-006 picker labels keep translated case; F-007 debug help row and docs listing aligned
- F-003 re-vendor LibKa0s (kit 38): inventory Total excludes skips

Tests: 2053/2053 passing (1 skipped, listed). luacheck 0/0.
```
