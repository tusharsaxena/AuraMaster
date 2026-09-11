# 05 — Final summary (written as if every item in 03_SMOKE_TESTS.md has passed)

## Headline
This cycle fixed two bugs players could hit and tightened the evidence the addon keeps about itself.

- **Enchant options:** weapon-enchant options changed on a live container ("Hide enchants without a duration" and sort direction) now take effect immediately instead of waiting for a `/reload`.
- **Combat teardown:** deleting a container, resetting, or switching profile during combat no longer hides aura-engine frames while combat lockdown is active. The teardown now waits for combat to end.
- **Smaller UX fixes:**
  - Session toggles (preview, debug console) no longer re-apply every container or print a false "after combat" notice.
  - The frame picker no longer errors when the cursor passes over a forbidden frame.
  - A corrupt SavedVariables key no longer stops the addon from loading.
  - Container names stay unique on every rename path.
- **Perf evidence:** the offline runner now measures the addon rather than its mock. The required zero-overhead comparison (capture off against no instrumentation) exists. The timed-spell scan has its own perf bucket.

## Counts
- **Critical fixed:** 0 of 0.
- **High fixed:** 2 of 2 (F-001, F-002).
- **Medium fixed:** 9 of 9 (F-003 through F-011).
- **Low fixed:** 9 of 11.
  - F-019 was deferred: four writes per drag coalesce into one apply, and the only extra cost is log lines.
  - U-001 was handed off to the LibKa0s repo; the re-vendor commit lands after its release.

## Changes by theme

### T1 — Engine update completeness
- **What changed:** Enchant settings now reach a live aura container. Hiding permanent enchants rebuilds the container once, and the sort direction is re-sent in place.
- **Why it mattered:** The setting looked saved but the display ignored it.
- **Covers:** F-001, change C-01.
- **Files:** `modules/FilterCompiler.lua`, `modules/Container.lua`, `tests/test_filtercompiler.lua`, `tests/test_container.lua`.

### T2 — Combat-safe teardown
- **What changed:** A container removed during combat is disabled at once and torn down after combat. It is reused if the id comes back first.
- **Why it mattered:** Hiding a Blizzard aura container's parent during combat lockdown risks a blocked action and taint.
- **Covers:** F-002, change C-02.
- **Files:** `modules/ContainerManager.lua`, `modules/Container.lua`, tests.

### T3 — Announce only what applies
- **What changed:** Session-only toggles no longer queue an apply. The deferral notice now says whether combat or aura secrecy is holding the change.
- **Why it mattered:** It removes a wasted full apply pass and a misleading chat line.
- **Covers:** F-003, F-012; change C-03.
- **Files:** `settings/Schema.lua`, `modules/ContainerManager.lua`, `locales/enUS.lua`, tests.

### T4 / T5 — Robustness
- **What changed:** The picker checks `IsForbidden` before touching a frame. Profile preparation drops container keys it cannot normalize.
- **Why it mattered:** One path raised an error on every frame while the cursor rested on a forbidden frame; the other stopped the addon from loading.
- **Covers:** F-004, F-005; changes C-04, C-05.
- **Files:** `modules/FramePicker.lua`, `core/Database.lua`, tests.

### T6 — Write-path discipline
- **What changed:**
  - Names are normalized to unique values at the single write seam.
  - Registry-wide operations are ratified in `## Documented deviations`, per decision D-1.
  - The preview flag is reset through the seam.
- **Why it mattered:** Keeps architecture-§5 true, or honestly recorded where it is not.
- **Covers:** F-006, F-007; change C-06.
- **Files:** `settings/Schema.lua`, `settings/Containers.lua`, `settings/General.lua`, `modules/ContainerManager.lua`, `docs/ARCHITECTURE.md`.

### T7 — Evidence fidelity
- **What changed:**
  - The GC is stopped inside measured loops, and the engine recorder has a count-only mode.
  - There is a new `probeAbsent` arm.
  - There is a new `timedScan` bucket.
  - Negative test assertions carry their `-- red under:` notes.
- **Why it mattered:** Committed perf figures must describe the addon (performance-§9), and cases must be able to fail (testing-§12).
- **Covers:** F-008, F-009, F-010, F-021; change C-07.
- **Files:** `tests/perf.lua`, `tests/wow_mock.lua`, `modules/TimedSpells.lua`, `core/PerfSetup.lua`, `tests/test_perf.lua`, `docs/performance.md`, three test files.

### T8 — Allocation
- **What changed:** Formatter, color curve and dispel color map are built once per look, not per button. Preview keeps one factory per container.
- **Covers:** F-011, F-020; change C-08.
- **Files:** `core/Compat.lua`, `modules/Style.lua`, `modules/Preview.lua`.

### T9 / T10 — Hygiene
- **What changed:**
  - Whole-sentence CLI strings, and one key per reset message.
  - Resolved doc citations.
  - No layout-cache position for anchors.
  - Pending frame anchors retry after combat.
  - Stub comments that match what the stubs do.
- **Covers:** F-013 through F-018; changes C-09, C-10.

## API / behavior changes
- **No** slash verbs added or renamed. No saved-variable schema bump (`schemaVersion` stays 1; C-05 is a repair in `PrepareProfile`, not a migration).
- **Behavior:**
  - A `hidePermanentEnchants` toggle rebuilds that container's engine once.
  - Delete, profile switch and reset in combat now complete after combat.
  - The deferral notice has two wordings.
- **Locale keys:**
  - Added: the secrecy deferral sentence; whole-sentence CLI keys (`"Deleted '%s'"`, `"Selected %s"`, `"Created %s"`, `"Unknown word '%s' — try /am new target debuffs icons"`, `"%s (copy)"`, `"Container %d"`).
  - Removed: the fragment keys and the period variants of the two reset messages.
- **Perf:** new bucket `timedScan` (root). Bucket count goes from 5 to 6.

## Saved-variable / migration notes
No shape change. Existing profiles load unchanged. A profile carrying a non-numeric container key loses that one malformed entry, logged under `[Migrate]`. No `/am reset` is needed.

## Deprecated-API migrations
None. The sweep found no deprecated call outside `core/Compat.lua`'s version-guarded fallbacks (`GetSpellInfo`, `GetMouseFocus`, `GetAddOnMetadata`, each used behind a check for its modern replacement).

| Old API | New API | Files |
|---|---|---|
| — | — | — |

## Performance impact
- **Before**, measured 2026-09-11 with `lua5.1 tests/perf.lua`: compile 675.2 B/iter; applyPass 15243.3 B/iter at 22.0 engine calls; restyle −1920.1 B/iter (invalid, F-009); visibilityPass 625.2 B/iter at 3.0 calls; unitSwap 96.4 B/iter at 1.0 call; probeOverheadOff 721.6; probeOverheadOn 722.1.
- **After:** to be filled from the post-change `tests/perf.lua` run and from capture S-07 (`docs/perf-analysis/<stamp>/`). No estimate is given here. The before-figures above include mock-recorder and GC artifacts, so they are not comparable one-for-one with the after-figures.

## Test and complexity movement
- **Pass count:** 154 → about 163. The exact count is taken from the regenerated `docs/test-cases.md`, which moved in the same commits as the cases, together with the README `[tests]` badge.
- **Complexity:** no watch-list entry exists today (max CCN 15, 0 warnings). Expected: `ContainerClass:Update` about 14, `NS.SetByPath` about 13, and `TS.Scan` unchanged at 15. The next release run's lizard regeneration confirms this; nothing is regenerated here.

## Known follow-ups
- **F-019:** batch the four drag writes if the seam ever gains a multi-leaf write.
- **U-001:** re-vendor once LibKa0s publishes the `mock_base.lua` fix, then delete the local shim.
- **Retired-engine reuse:** pool retired engines by structure key. This is listed as a Known Limitation, not a finding.
- **Frame-time capture:** the first real `/am perf` capture (S-07) seeds `docs/perf-analysis/`. Every frame-time claim waits on it.

## Verification evidence
- The completed `03_SMOKE_TESTS.md`, with its sign-off table filled in.
- Commit range: `83c559e..<HEAD after M5>` on `fix/review-audit-2026-09-11`. The PR link goes here.

## Suggested PR description
```
Review fixes 2026-09-11 (docs/reviews/2026-09-11/)

High
- F-001 Enchant hide-permanent and sort direction now reach a live engine
- F-002 Container teardown under combat lockdown is parked until combat ends

Medium
- F-003/F-012 Session rows queue no apply; deferral notice names combat vs. secrecy
- F-004 Frame picker checks IsForbidden first
- F-005 PrepareProfile drops unnormalizable keys instead of failing to load
- F-006/F-007 Names normalized at the write seam; registry deviation ratified
- F-008/F-009/F-010 perf: GC-stopped, count-only recorder, instrumentation-absent arm, timedScan bucket
- F-011 Formatter / curve / dispel map built once per look

Low: F-013..F-018, F-020, F-021. Deferred: F-019. Upstream: U-001 (LibKa0s testkit).

Tests: 154 -> ~163 (docs/test-cases.md and badge moved in-change). luacheck 0/0.
```
