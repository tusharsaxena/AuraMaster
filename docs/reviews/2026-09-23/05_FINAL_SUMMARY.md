# Ka0s Aura Master — final summary (2026-09-23 review cycle)

*Written assuming every check in `03_SMOKE_TESTS.md` has passed.*

## Headline

This cycle fixed a frame leak that rebuilt a container's whole frame set every time an id came back
(profile round trips, resets), moved the "timeless buff" scanner's `UNIT_AURA` listen from an
every-unit firehose to a client-side player/pet filter, brought the two functions blocking the next
release's complexity gate back under CCN 15, and tightened the disabled contract (no frames built
while off, a Test mode checkbox that honors the off switch, event registration that survives a
retired event name). The library's tabbed-page renderer gained the fields this addon needed, and the
host's private copy was retired.

## Counts

Critical fixed: 0 · High fixed: 0 · Medium fixed: 4 (F-001, F-002, F-003, F-004) · Low fixed: 10
(F-005 – F-014). Deferred: none — F-004 is conditional on the upstream U-1; if declined, it closes as a
documented deviation instead of an adoption.

## Changes by theme

### T1 — Container instances are reused per id
- **What changed:** a container removed out of combat is kept dormant and revived if its id returns.
- **Why:** each round trip leaked an anchor, an engine and its buttons and overwrote a global name.
- **Findings / changes:** F-001 / C-01.
- **Files:** `modules/ContainerManager.lua`, `tests/test_containermanager.lua`.

### T2 — `UNIT_AURA` filtered in the client
- **What changed:** a dedicated unit-filter frame (`events-frames-taint-§1` carve-out) replaces the
  AceEvent registration.
- **Why:** every nameplate/raid-member aura change entered Lua to be discarded.
- **Findings / changes:** F-002 / C-02.
- **Files:** `modules/TimedSpells.lua`, `tests/test_timedspells.lua`, `tests/test_disabled.lua`,
  `tests/perf.lua`, `docs/performance.md`.

### T3 — Complexity back under the release gate
- **What changed:** `Cat.SyncUserCategories` split into four named phases; the Filters custom grid
  extracted.
- **Why:** `automated-tests-§3` refuses a tag with any function above CCN 15.
- **Findings / changes:** F-003 / C-03.
- **Files:** `defaults/Categories.lua`, `settings/Filters.lua`.

### T4 — Library tabbed render adopted
- **What changed:** host `RenderTabbedPage` / container header replaced by the library's extended
  `RenderTabbedSchema` / `PageBanner`.
- **Why:** a forked renderer misses every library fix.
- **Findings / changes:** F-004 / U-1, U-2, C-04b.
- **Files:** `libs/LibKa0s/` (re-vendor only), `settings/OptionsSetup.lua`, page builders, tests.

### T5 — Robustness and the disabled contract
- **Findings / changes:** F-005 – F-007, F-009 / C-05 – C-07, C-09.
- **Files:** `core/AuraMaster.lua`, `core/LifecycleSetup.lua`, `core/DebugLogSetup.lua`,
  `modules/ContainerManager.lua`, `modules/TimedSpells.lua`, `settings/General.lua`, tests.

### T6 — Stubs, lint, comments, docs, de-duplication
- **Findings / changes:** F-008, F-010 – F-014 / C-08, C-10 – C-13.
- **Files:** `settings/Slash.lua`, `settings/OptionsSetup.lua`, `core/PoolSetup.lua`, `.luacheckrc`,
  `core/Database.lua`, `modules/Container.lua`, `docs/performance.md`, `README.md`,
  `settings/Layout.lua`, `modules/FramePicker.lua`, `core/Compat.lua`, `settings/Schema.lua`.

## API / behavior changes

- Test mode can no longer be turned **on** from the panel while the addon is disabled (one refusal
  line, as `/am test` and the launcher already did).
- A disabled addon creates no container frames until it is enabled.
- The `[Init]` debug summary names any event the client rejected.
- No slash verbs added, renamed or removed. No SavedVariables shape change, no schema bump, no new or
  removed defaults. No locale keys renamed.

## Saved-variable / migration notes

None. Schema stays at v6.

## Deprecated-API migrations

| Old | New | Files |
|---|---|---|
| `_G.GetMouseFocus` fallback (removed in 11.0) | removed; `GetMouseFoci` only | `core/Compat.lua` |

## Performance impact

Only measured numbers belong here; fill from the records named:
- Offline: `tests/perf.lua` post-change run (the `unitAuraOther` scenario is replaced — see C-02).
- In-client: the two `docs/perf-analysis/<stamp>/` bundles from Checkpoint A (pre/post C-02), bucket
  `timedScan` and the capture's event counts.

## Test and complexity movement

- Pass count: **1296 → 1296 + N** (N = cases added by C-01, C-02, C-05, C-06, C-07, C-08, C-09);
  `docs/test-cases.md` and the README badge moved in each of those commits.
- Watch list: `Cat.SyncUserCategories` (CCN 25) and `renderCategories` (CCN 16) are expected to leave
  the warning list — to be confirmed by the next release's `docs/automated-tests/` regeneration.

## Known follow-ups

- The four `layout-§1` over-cap files (issues #16–#19) — peels tracked there, out of this cycle's scope.
- `docs/automated-tests/RESULTS.md` is stale (last run 2026-09-16, 943 cases) — regenerated at the next
  release by `/wow-addon:bump-version`.
- If U-1 was declined: the host tab renderer stays as a documented deviation with its re-check trigger.

## Verification evidence

- `docs/reviews/2026-09-23/03_SMOKE_TESTS.md` with its sign-off table filled in.
- Commit range: `<first>..<last>` on `feat/2026-09-23-review-audit-remediation`; PR `<link>`.

## Suggested commit / PR description

```
AuraMaster: 2026-09-23 review remediation

- Revive a destroyed container id instead of building a second AuraMasterAnchor<id> (F-001)
- Filter UNIT_AURA to player/pet in the client via the events-frames-taint-§1 unit frame (F-002)
- Split Cat.SyncUserCategories and renderCategories under CCN 15 (F-003)
- Adopt LibKa0s RenderTabbedSchema/PageBanner extensions after re-vendor (F-004)
- Isolated event registration; nothing built while stood down; edge-triggered degraded latch;
  Test mode honors the disabled gate (F-005..F-007, F-009)
- Stub, lint, comment, doc and duplication cleanup (F-008, F-010..F-014)

Review: docs/reviews/2026-09-23/
```
