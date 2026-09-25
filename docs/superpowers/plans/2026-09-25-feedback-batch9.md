# Feedback batch 9 Implementation Plan

> Run as Workflow orchestration (ultracode): one implementer and one independent reviewer per task.

**Goal:** fix what the owner's batch 8 smoke run failed, and rework container attachment so its points
can be chosen. **Spec:** `docs/superpowers/specs/2026-09-25-feedback-batch9-design.md` (binding).
**Evidence:** `docs/superpowers/research/2026-09-25-feedback-batch9-findings.md`.

## Global constraints

Batch 8's constraints apply unchanged (`docs/superpowers/plans/2026-09-25-feedback-batch8.md`, "Global
constraints"): the green gate runs before EVERY commit through the bounded runner; commits and branch
pushes are authorized; merging, tags and version bumps are not. The branch is still
`feat/2026-09-25-feedback-batch8`. Commit subjects start `B9-<task>: `. Never evade a hook or the
auto-mode classifier: if a hook blocks a command because of a tool name in its text, write the message
to a file and run `git commit -F`.

## Resume

Git is the state. A task is done when a `B9-<task>: ` commit exists on the branch:
`git log --format=%s master..HEAD | grep -o '^B9-Q[0-9]*' | sort -u`. Trust git over the ledger.
Resume at the first task, in order, that has no commit. A dirty tree is that task's partial work.

## Status ledger (update in each task's own commit)

| Task | Req | Depends | Status | Commit | Notes |
|---|---|---|---|---|---|
| P0 tab rename, smoke record | E7 | — | done | 73e44b5 515474b 73c72e4 | |
| Q1 diagnostics secret-safe + inert rows | DX-1 DX-2 | — | todo | | |
| Q2 Size to fit Text-only; creates v9 | E6 MG-1 (autoSize half) | Q1 | todo | | |
| Q3 live Size to fit never clips | TX-1 E8 | Q2 | todo | | |
| Q4 label Justify | LJ-1 E7 | Q3 | todo | | |
| Q5 drop the slot hang | HG-1 E1 | Q4 | todo | | |
| Q6 attach edge model + Side dropdown + v9 edge/seam | AP-1..AP-4 E2 E5 MG-1 | Q5 | todo | | |
| Q7 growth-conflict popup | GC-1 E3 | Q6 | todo | | |
| Q8 strip side, join pin, test outline, enchant preview | SEP-1..SEP-4 E4 | Q7 | todo | | |
| Q9 docs sync, smoke section AA, full battery | all | Q8 | todo | | |

Tasks run one at a time: they share `Anchors.lua`, `Container.lua` and the migration ladder.

## Milestones (checkpoint and branch push after each)

| M | After | Checkpoint |
|---|---|---|
| N1 | Q1–Q4 | green gate; push |
| N2 | Q5–Q7 | green gate; the v9 migration tests pass; push |
| N3 | Q8–Q9 | full battery; smoke section AA written for the owner; push; stop, since the merge waits for the owner |

## Checkpoint log

| When | Milestone | Evidence |
|---|---|---|
