# Drag-and-drop container attachment: implementation plan

> Run as Workflow orchestration (ultracode): each task has one implementer and then one independent
> reviewer (up to two fix rounds), a final multi-lens review with adversarial verification, and then a
> checkpoint. Tasks run in order, because they share files.

**Goal:** issue #22: drop a container on another to attach it, drag an attached one away to detach it.

**Spec:** `docs/superpowers/specs/2026-10-02-drag-attach-design.md` (binding).
**Branch:** `feat/2026-10-02-drag-attach`, from `master` at `6432798`, in the main AuraMaster tree, so
every pushed milestone can be tested in game.

## Rules for every task

- test-first, with a true `-- red under:` note on each case;
- the green gate before every commit: `lua tests/run.lua`, and luacheck at 0/0 through `ka0s-bounded`;
- no function above CCN 15 (the kit's sighted complexity suite, its bundle deleted after);
- no authored Lua file past 1500 lines; new logic goes in `modules/Anchors_Snap.lua`, not `Anchors.lua`;
- `docs/test-cases.md` regenerated, and the README badge updated, with any case change;
- doc citations fixed in the same commit that moves the lines they point at;
- CRLF line endings kept; US spelling; mock changes only in `tests/wow_mock.lua`;
- a commit subject starts with `<ID>: ` and the message ends with the session trailers;
- no merge, no version bump and no tag; push the branch at milestone checkpoints only.

## Items

| ID | Milestone | Title | Done when |
|---|---|---|---|
| DD-00 | M0 | This design and plan | commit `DD-00:` |
| DD-01 | M1 | Snap core: `modules/Anchors_Snap.lua` (TOC after Anchors.lua), `PointAt`, `Nearest`, eligibility, rect reads, Automatic folding, `C.SNAP_RADIUS`/`C.SNAP_COLOR` (D1, D2, D5, D7 points) | snap cases green |
| DD-02 | M1 | Drag lifecycle: `beginDrag` (D9, re-anchor), `dragging` guard in `Place`, the driver, the highlight and marker, Shift and combat (D3, D4, D11) | lifecycle cases green |
| DD-03 | M1 | Drop: `Snap.Drop`, `container.attach` in SECTIONS, `NS.AttachByDrop` with the GC-1 popup, detach (D6, D7, D8, D10, D11) | drop and schema cases green |
| DD-04 | M2 | Strings and docs: tooltip lines, comments on the attached color, ARCHITECTURE, module-map, known-limitations, README, smoke cases `DRAG-NN`, test-cases, badge | test_docs, test_locale, prose green |
| DD-05 | M3 | Whole-branch review (lenses: WoW frame/secret/taint and combat legality, settings write path and GC-1, tests, docs and UI), adversarial verification, fixes | review note on HEAD |
| DD-06 | M3 | Full battery (sharded and `-j 1`, luacheck, complexity, perf.lua, file caps, inventory), checkpoint row, push | row in `2026-10-02-drag-attach.checkpoints.tsv`; origin equals HEAD |

Checkpoints: M1 and M2 end with the gate, a checkpoint row and a push of the branch.

## Resume

1. Work in `../AuraMaster` on `feat/2026-10-02-drag-attach`. If the tree is dirty, read it before doing
   anything else.
2. Done items: `git log --format=%s master..HEAD | grep -oE '^DD-[0-9]+'`. Reviewed items carry a
   `refs/notes/ka0s-review` note starting `OK DD-NN`. The next item is the first id with no commit.
3. Smoke checks are the owner's. Never mark one passed.
4. After the owner's merge go-ahead and the merge: close #22 with a comment (the anchor-point bullet was
   batch 11 G1/G2), delete the branch (local and origin), and any stash or worktree this run made.
