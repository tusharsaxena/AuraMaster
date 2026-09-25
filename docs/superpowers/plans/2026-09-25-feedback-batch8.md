# Feedback batch 8 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. The owner asked
> for this to run as Workflow orchestration (ultracode): one implementer and one independent reviewer
> per task.

**Goal:** the owner's 2026-09-25 feedback (#1, #3, #4, #7–#11, #13, #16). #5 is filed as AuraMaster#22.
#6 comes later, on its own branch.

**Spec:** `docs/superpowers/specs/2026-09-25-feedback-batch8-design.md`. It is binding.
**Evidence:** `docs/superpowers/research/2026-09-25-feedback-batch8-findings.md`. Each task reads its
item's section there for the file:line root cause, the sketch, the tests and the smoke checks.

## Global constraints

- Green gate before every commit: `lua tests/run.lua`, `luacheck .` (0/0),
  `lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .` with no function above CCN 15, and the 1500-line
  cap. LibKa0s uses its own gate (see its `CLAUDE.md`).
- **Authorized** (owner, 2026-09-25): commit incrementally, and push the **feature branches** to origin
  at each milestone.
- **Not authorized:** merging into master, pushing any tag (v1.59.0 stays local), bumping an addon
  version, and re-vendoring other addons.
- Every commit subject starts `B8-<task>: `, for example `B8-P3: dispel border keeps the Solid shape`.
  Commits end with the session's attribution trailers.
- The standard is binding: a deviation stops the task and is reported. Strings go through `NS.L` and
  are ASCII. CRLF. For uncommitted content, repair by editing, never with `git checkout`.
- Test-first: write the failing test and see it go red for the reported reason, then fix it.

## Resume

Git is the state. A task is **done** when a commit whose subject starts `B8-<task>: ` exists on the
branch of the repo it belongs to. Find them with:

    git -C ../AuraMaster log --format=%s master..feat/2026-09-25-feedback-batch8 | grep -o '^B8-P[0-9]*' | sort -u
    git -C ../LibKa0s    log --format=%s master..feat/2026-09-25-draghandle-close  | grep -o '^B8-P[0-9]*' | sort -u

Trust git over the ledger below. Resume at the first task in dependency order that has no commit. A
dirty tree is that task's partial work: read it, then continue it or stash it, and never throw it away.
A task has been **reviewed** when a later commit `B8-<task>R: ` exists, or when the ledger notes
"review clean".

## Status ledger (update in each task's own commit)

| Task | Req | Repo | Depends | Status | Commit | Notes |
|---|---|---|---|---|---|---|
| P1 spark neutral ADD | SP-1 SP-2 | AM | — | done | this commit | spark ADD + desaturated per dress in applySurfaces; SP-1 BLEND tests replaced; KL + check 85 rewritten |
| P2 test-mode debuffs | TD-1…4 | AM | — | done | 055a04f | PREVIEW_AURAS keyed HELPFUL/HARMFUL, names/icons by spell id, preview icon ring via Compat.SetAuraBorderAtlas (P3 must move it to its strips), bars repaint per type; review (B8-P2R): untyped bar keeps the class snapshot |
| P3 dispel border shape | DB-1 DB-2 | AM | — | done | this commit | dispel edge = 4 white strips in the Solid shape (Style.TintEdge), PreserveAsset with no map; 1 px when border hidden/None/0; preview tints via Compat.SetAuraBorderColor (replaces SetAuraBorderAtlas) |
| P4 icon attach points | IA-1 IA-2 | AM | — | done | this commit | DerivedPoints ignores the axis: child stacks TOP{H}->BOTTOM{H} (up: BOTTOM{H}->TOP{H}); DERIVED rows + label test flipped, axis-independence + icon-row Place tests; smoke 67 row case |
| P5 seam spacing + v8 (offsets) | SS-1…3 | AM | P4 | done | c9caf26 | Anchors.SeamOffset (child spacing, lineSpacing for rows, growth-signed) + x/y nudge; attached strip beside first element; v8 MigrateV8 resets 0/-4 on container mode; template attach.y 0; review (B8-P5R): seam suite length operators moved off lizard-visible lines (lintconfig was red) |
| P6 empty-container overlap | EO-1 EO-2 | AM | P5 | done | 3c23d2e | Anchors.HangMode preview/slot/engine (ApplyVisibility records hangMode); unlocked followers hang from the parent anchor; PlaceAttached memo on mode + strip room; EO-2 as shortfall-only room past a follower parent's beside strip (seam unchanged otherwise, SS-3); test_anchors_hang suite; smoke 191-196; review (B8-P6R): hang suite length operators moved off loop headers (lintconfig was red) |
| P7 Text size to fit + v8 (autosize) | AS-1…3 | AM | P6 | done | this commit | text.autoSize (template true) + Size to fit row dims Width/Height under a note; Style.ElementSize -> Text.AutoSize (font/icon/stack/bounce height, WidestLine over placeholders + client names + sample + TIME_SAMPLES worst cases, clamp 40-600, memo, failures not cached); MigrateV8 also stamps autoSize=false (one log line); test_style_text_autosize suite; review (B8-P7R): worst case takes the longest dispel word of every type, perf runner measures on a readable string + memo assert |
| P8 LibKa0s DragHandle close, v1.59.0 | CX-1 CX-2 | LK | — | todo | | local tag only |
| P9 re-vendor v1.59.0 + X button | CX-3 | AM | P8, P7 | done | 2abe552 + 5826f75 | re-vendor v1.59.0 (WidgetsDragHandle 3, bundle docs/revendor/2026-09-25-v1.59.0); BuildHandle passes closeIcon/onClose/closeTooltip, X disables via NS.SetByPath + one chat line; test_anchors_close suite; RESERVE2 58->94; review (B8-P9R): the new suite hid code from lizard behind two `#` lines, split out |
| P10 name label | NL-1…4 | AM | P9 | done | a945c09 | container.label (template, no schema step) + Anchors.StripPoints/PlaceLabel; label shows locked and unlocked, strip pushed out by STRIP_H+GAP (D6), beside the first element for followers; stripRoom/clamp count it; Name label Layout tab (swatch never dimmed, AP #74); rename refresh, Copy section; test_anchors_label suite; doc citations re-pointed; review (B8-P10R): label suite length operators moved off lizard-visible lines (lintconfig was red) |
| P11 /am debug diag | DG-1…4 | AM | P10 | done | this commit | modules/Diagnostics.lua (Build/Run, ungated DebugLog:Add + one L chat line; header/queue, non-default cfg via Slash.FormatValue stripped, auras per unit/filter, per container Cont/Filt/Plan verdict in sync/PENDING/DRIFT/not built/Cfg/Shown + predicted; no aura or button call while secret; caps 1200/100/40 + truncated line); runDebug diag branch first; CM.QueueSnapshot, NS.RowApplies; docs/debug.md; test_diagnostics suite; doc citations re-pointed |
| P12 docs sync + full battery | all | AM | P11 | todo | | |

AuraMaster tasks run one at a time, because they share `Anchors.lua`, `Style*.lua` and their tests.
P8 is in another repo and runs alongside P1–P7.

## Milestones (a checkpoint and a branch push after each)

| M | After | Checkpoint |
|---|---|---|
| M1 | P1–P3 | green gate; push the AuraMaster branch |
| M2 | P4–P7 | green gate; migration tests cover v8 from v7; push |
| M3 | P8–P10 | the LibKa0s gate is green and the tag is local; AuraMaster is green; push both branches (not the tag) |
| M4 | P11–P12 | the full battery; smoke checklist entries are written for the owner; push. Stop there: merging waits for the owner. |

Record each checkpoint as a row in the checkpoint log below, in the same commit as the push.

## Checkpoint log

| When | Milestone | Evidence |
|---|---|---|
| 2026-09-25 | M2 | tests 1422 passed / 0 failed / 0 skipped (16 shards); luacheck 0 warnings / 0 errors in 126 files; lizard 3703 functions, 0 above CCN 15; migrations cover v7->v8 and v1 (stamped and unstamped) through v8; head 90922b9 |
| 2026-09-25 | M3 | tests 1448 passed / 0 failed / 0 skipped (16 shards); luacheck 0 warnings / 0 errors in 128 files; lizard 3768 functions, 0 above CCN 15; LibKa0s local tag v1.59.0 (53c141a, not pushed), libs/LibKa0s byte-identical to it, feat/2026-09-25-draghandle-close pushed; head 3a40323 |

## Task notes

- **P1** Findings item 1. Replace the SP-1 BLEND tests. Add a test that the blend is always ADD across
  sparkTimeless × engine.
- **P2** Findings item 4. Resolve names and icons through `NS.Compat.GetSpellInfo`, with a fallback.
  Every style's preview must read the HARMFUL set for a HARMFUL container.
- **P3** Findings item 10. The dispel texture becomes white strips that reuse `BORDER_STRIPS` geometry,
  and the engine recolors them with PreserveAsset. Delete `DISPEL_ART_DIVISOR` and the outset.
- **P4** Findings item 11. Change `DerivedPoints` and update the tests that pinned TOPLEFT to TOPRIGHT.
- **P5** Findings item 13. The seam uses the child's gap per SS-1, and x/y add on top. Create
  migration step v8 with the 0/-4 → 0/0 reset (SS-2), with tests from v7.
- **P6** Findings item 9. The hang mode is `preview` / `slot` / `engine`, and `PlaceAttached` memoizes
  on the mode. Add a chain test with three empty containers, where no two handles overlap.
- **P7** Findings item 7. Add `autoSize` to the template and extend v8 to stamp false on existing text
  containers. `Style.ElementSize` consults `Text.AutoSize`. Add the Size to fit row and disable
  Width/Height when it is on.
- **P8** Findings item 3, run in `../LibKa0s` on `feat/2026-09-25-draghandle-close`. Follow that repo's
  release rules for v1.59.0 and the docs/api 10.3. Tag locally.
- **P9** Run the `/wow-addon:revendor-libka0s` procedure for v1.59.0: copy both payloads whole, roll the
  provenance line and write `docs/revendor/2026-09-25-v1.59.0`. Then wire `onClose` in
  `Anchors.BuildHandle`.
- **P10** Findings item 8, but with D6: both show while unlocked, and the handle is pushed out past the
  label.
- **P11** Findings item 16. Put the new module in the TOC, add the test suite, and write
  `docs/debug.md`.
- **P12** `/wow-addon:sync-docs`-grade doc pass: ARCHITECTURE counts, schema.md (v8, the new keys),
  settings-panel.md, module-map.md, slash-dispatch.md and test-cases.md. Add a smoke-tests.md entry for
  each item, marked for the owner to run. Then run the full battery.
