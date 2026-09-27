# Blank bar names: implementation plan

> Run as Workflow orchestration (ultracode): each task has one implementer and then one
> independent reviewer, and each milestone ends with a checkpoint. Tasks run in order, because they
> share files.

**Goal:** a spell name that the aura engine wrote blank on first sighting appears within a few
seconds, in combat too, with no `/reload`.

**Spec:** `docs/superpowers/specs/2026-09-27-blank-bar-names-design.md` (binding).
**Findings:** `docs/superpowers/research/2026-09-27-blank-bar-names-findings.md`.
**Branch:** `fix/2026-09-27-blank-bar-names`, from master `8ef48d2`.

## Rules for every task

- Test-first. Write the failing case, see it fail, then write the code. Each new case carries a
  `-- red under: <mutation>` note.
- The green gate before every commit: `lua tests/run.lua` (all passing), and
  `/home/tushar/.claude/wow-addon/bin/ka0s-bounded luacheck .` with 0 warnings and 0 errors. Run
  lizard, bounded, on the files you touched: no function above CCN 15.
- Any case added or removed: regenerate `lua tests/run.lua --list > docs/test-cases.md` and update
  the README `Tests-N%2FN_passing` badge in the same commit.
- Any line moved under a documented `file:line` citation: fix the citation in the same commit
  (`tests/test_docs.lua` finds them).
- Mock changes go in `tests/wow_mock.lua`, never in `tests/_kit/`, which is vendored.
- US spelling everywhere. Comment citations use the `filename-§N` form.
- Git is the only state. A task is done when a commit whose subject starts `<ID>: ` is on the branch.
  One commit may carry two ids (`NR-03 + NR-04: ...`). Commit messages end with the session's
  attribution trailers.
- Never merge to master, bump the version or tag. Push the branch only at a milestone checkpoint.

## Items

| ID | Milestone | Title | Depends | Done when |
|---|---|---|---|---|
| NR-00 | M0 | Spec, findings and plan committed; GitHub issue filed | - | commit `NR-00:`; issue open with `bug`, `state:triaged`, `severity:high` |
| NR-01 | M1 | `Style.ShowsEngineName(cfg)` predicate, at the end of `modules/Style.lua` | NR-00 | predicate cases green (spec, Testing) |
| NR-02 | M1 | `modules/NameRepaint.lua`: frames, Sync, two-stage timers, Repaint, Stop, OnEnterWorld; TOC entry and load-order note; new suite `tests/test_namerepaint.lua` declared in `tests/run.lua` | NR-01 | Sync, timer, repaint, combat and secrecy cases green |
| NR-03 | M1 | Wiring: Sync at the end of `CM.FlushPending` and `CM.ApplyVisibility`, gated off while stood down; the `OnEnterWorld` hook; `NameRepaint.Arm(unit)` after `CM.RefreshUnit` in `OnUnitSwap` and `OnUnitPet`; stand-down Stop (`standUp` stays unchanged); the `nameRepaint` perf bucket and bracket; a `tests/perf.lua` scenario, with Sync adding 0 B in the `probeOverhead` loop; the `test_disabled` counts, and `test_perf`'s count, `BUCKET_ORDER` string and `exercise()`, each updated with a comment | NR-02 | stand-down, re-enable, PEW, swap and perf cases green; perf.lua assertions pass |
| NR-04 | M2 | Diagnostics: remove the cee5bb6 width fields and `Style.MeasuredTimeWidths`; add the `name repaint:` header line; update tests | NR-03 | diagnostics suite green |
| NR-05 | M2 | Docs: debug.md, midnight-quirks.md, ARCHITECTURE.md, data-flow.md, module-map.md, performance.md, known-limitations.md, smoke-tests.md (281+); `test-cases.md` and the badge | NR-04 | `test_docs` green; no stale claim of "no aura path in combat" |
| NR-06 | M3 | Independent multi-lens review of the branch diff, then adversarial verification; fix what is confirmed | NR-05 | review note on HEAD (`refs/notes/ka0s-review`); fixes committed as `NR-06:` |
| NR-07 | M3 | Full battery: tests (`-j 1` matches the sharded run), luacheck, lizard (whole repo), `lua tests/perf.lua`; checkpoint row; push the branch | NR-06 | checkpoint row below; `origin/fix/2026-09-27-blank-bar-names` equals HEAD |

## Milestone checkpoints

At the end of each milestone, run the full gate (tests sharded and `-j 1`, luacheck, lizard on the
whole repo, `lua tests/perf.lua`). Append a row to
`docs/superpowers/plans/2026-09-27-blank-bar-names.checkpoints.tsv`
(`when  milestone  head_before_log  evidence`), commit it as `NR-CP-M<n>:`, and push the branch.

## Resume

A fresh session picks up from any point like this:

1. Work in `../AuraMaster` on `fix/2026-09-27-blank-bar-names`. Run `git status`. If the tree is
   dirty, read the diff: continue that item's work, or stash it. Never `reset --hard` work you have
   not read.
2. Find what is done: `git log --format=%s master..HEAD | grep -oE '^NR-[0-9A-Z-]+( \+ NR-[0-9]+)*'`.
   The next item is the first id in the table with no commit.
3. Check the last checkpoint in the `.checkpoints.tsv` file, run the green gate, and continue.
4. Smoke checks are the owner's. Never mark one passed.
