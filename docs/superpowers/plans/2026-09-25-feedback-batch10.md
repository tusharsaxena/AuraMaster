# Feedback batch 10 Implementation Plan

> Run as Workflow orchestration (ultracode): one implementer and one independent reviewer per task.

**Spec:** `docs/superpowers/specs/2026-09-25-feedback-batch10-design.md` (binding). The batch 9 plan's
global constraints and resume rules apply unchanged, with commit prefix `B10-`.

**Lesson (F7):** a migration step already pushed to the branch is never extended again. Add a new step.

## Status ledger

| Task | Req | Status | Commit | Notes |
|---|---|---|---|---|
| R1 in-column strips, spread chain, label order | F1-F5 | done | this commit (subject `B10-R1: `; a commit cannot hold its own hash) | batch 9's StripSide/stripSides/hasFollowerOn/clearStrip/stripRoom/parentRows removed: every strip and label sit before their own block (StripPoints before only; a behind follower's lined up with H1, LabelJustify mirrors only for it); an after follower's seam moves on along the chain by furnitureRoom (its own strip row while stripShown, its label row while labelShown) recorded as `placedRoom`, and `Anchors.RefreshSeam` (called in ApplyVisibility after UpdateHandle, never under lockdown, allocation-free) re-places it when that changes; an ahead follower is pushed along the growth by sideRoom (the parent's furniture while its strip shows and `stripOverhang` > 0, whatever the align), PlaceAttached keyed on it; behind never pushed; join pin and test outline kept; test mode spreads only while unlocked (strips show only unlocked); new suite test_anchors_column (19), old strip/seam/label/hang/anchors cases rewritten; KL, data-flow, settings-panel, module-map, schema, README, smoke 14/41/192/204/215/223/225, test-cases + badge 1583 |
| R2 inherited-growth note | F6 | todo | | |
| R3 v10 migration + diagnostics disabled header | F7 F8 | todo | | |
| R4 docs sync, smoke section AB, full battery | all | todo | | |

## Checkpoint log

| When | Milestone | Evidence |
|---|---|---|
