# Smoke-Test Feedback Batch 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Ship the owner's second 2026-09-19 smoke pass: the combat lock on every settings page
(standard v2.60.0 → LibKa0s v1.46.0 → 11 consumers), and Aura Master items 1–8.

**Spec (binding, and the per-task detail):** `docs/superpowers/specs/2026-09-19-smoke-feedback-2-design.md`.
Each task below names its spec section; the spec's Cause / Fix / Tests are the task's contract. A task
works TDD: the spec's tests first (red), then the fix (green), then docs and citations.

**Owner approval (2026-09-19):** spec approved ("go ahead"); commits per task by the controller.
Tag, push, merge and version bumps of addons still wait for the owner.

## Global Constraints

- **Branches and commits.** Aura Master work is on branch `feat/smoke-feedback-2` (from `master`,
  which carries the unpushed 799ddda merge). **One commit per task**, made by the controller after the
  task's review, carrying the plan file's ledger update. Never merge, push, tag or bump an addon
  version without the owner's explicit go-ahead (CLAUDE.md; the spec's "Order and risk").
- **Other repos.** WowAddonStandards work follows its own CLAUDE.md / process on its `master` and
  **stops before any push** (Task 1). LibKa0s follows its `docs/releasing.md` and CLAUDE.md on its
  `master` and **STOPS before the tag and before any push** (Task 2). A consumer's re-vendor goes on
  `chore/libka0s-v1.46.0` from its default branch (Aura Master's lands on `feat/smoke-feedback-2`).
- **Heavy runs go through the bounded runner, from the repo root, always:**
  `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua`,
  `/home/tushar/.claude/wow-addon/bin/ka0s-bounded luacheck .`,
  `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lizard -l lua -x "./libs/*" -x "./tests/_kit/*" -C 15 -w .`,
  `/home/tushar/.claude/wow-addon/bin/ka0s-bounded lua tests/perf.lua`.
  A bare `luacheck`, `lizard` or `run-automated-tests.sh` is **blocked by a hook, even as text inside a
  heredoc**: write files with the Write/Edit tools (or a quoted heredoc that names none of the three).
- **Green gate after every task:** `lua tests/run.lua` → `… 0 failed …` and `luacheck .` →
  `0 warnings / 0 errors`, both bounded. The harness has no filter flag, so one case is run as
  `… lua tests/run.lua 2>&1 | grep -A3 "<case name fragment>"`.
- **Complexity:** no function above CCN 15. Run the bounded lizard line above whenever a task adds a
  branchy function; `-w` prints only the offenders, so it must print nothing.
- **Lizard's `#` rule** (`tests/test_lintconfig.lua`): no keyword (`end`, `then`, `do`, `and`, `or`, …)
  and no unbalanced `{`/`}` after a length operator on the same line. Take the length into a local
  first (`local n = #t` then `t[n + 1] = v`).
- **CRLF everywhere** (`.gitattributes`; `tests/_kit/test_eol.lua` fails an LF file). A tool that
  writes LF is followed by
  `python3 -c "import sys;p=sys.argv[1];s=open(p,newline='').read().replace('\r\n','\n');open(p,'w',newline='').write(s.replace('\n','\r\n'))" <path>`.
- **Strings:** every user-visible string goes through `NS.L`, with its key in `locales/enUS.lua` as
  `L["x"] = "x"` (key == value), ASCII except the em dash, **US English** (`tests/test_locale.lua`,
  `tests/test_docs.lua`; anti-pattern #46). A retired key is removed from `locales/enUS.lua` in the
  same task (the locale suite fails an unused key).
- **Citations:** a `file:line` citation in `docs/*.md`, `README.md` or `DEPENDENCIES.md` that a code
  change moves is re-pointed **in the same task** (`tests/test_docs.lua`). Use the helper below; a
  `BY HAND` line is re-pointed with `grep -n '<the symbol the sentence names>' <file>`.
- **The Ka0s WoW Addon Standard binds** (local copy
  `/mnt/d/Profile/Users/Tushar/Documents/GIT/WowAddonStandards/standards/standards/*.md`, v2.59.1). The
  two places the spec says "stop and flag" are resolved below (Decisions, D-4 and D-7). Any deviation a
  task finds that this plan did not foresee STOPS the task and is reported, never taken (CLAUDE.md).
- **Defaults** live only in `defaults/Profile.lua` (savedvariables-§2); every settings write goes
  through `NS.SetByPath`; a stored-shape change bumps `schemaVersion` through a `SCHEMA_STEPS` row
  (toc-file-§2, savedvariables).
- **Never** edit `libs/LibKa0s/` or `tests/_kit/` by hand in any consumer: they change only by a
  whole-folder copy from a LibKa0s tag (library-stack-§7).


---

## Status ledger (update after every task)

Resume at the first row that is not `done`. `blocked` rows wait on the owner (the Notes say for what).
Dependencies: 1 → 2 → owner tag → 11 → 12. Tasks 3–10 are independent of 1–2 but share Aura Master's
tree, so they run one at a time. 13 is last.

| # | Task (spec section) | Repo | Status | Notes |
|---|---|---|---|---|
| 1 | Standard v2.60.0 — options-ui-§2 combat lock, §13 tab rule, anti-pattern, ripple ("⚔ Standard") | WowAddonStandards | todo | stops before push |
| 2 | LibKa0s v1.46.0 — the combat cover, refused writes, regen handling, tests, docs/api, CHANGELOG, release bundle ("⚔ Design") | LibKa0s | todo | stops before tag/push |
| 3 | Item 1 — growth corner in the structure key; Point rows reworded; facing-growth hint | AuraMaster | done | T3 commit: corner in Container:Apply structure key; Point rows = first aura; hint Named frame only; +9 tests (1123/1123), inventory + badge regenerated |
| 4 | Item 4 — dispel-colored bar background / fill honour opacity | AuraMaster | done | T4 commit: dispel map entries opaque; dispel-mode region SetAlpha(opacity x color alpha), static unchanged; smoke 126 gains the in-combat alpha check (child-frame fallback not built); +3 tests (1126/1126) |
| 5 | Item 7 — report swallowed re-dress errors; anchor text before the icon; guard the icon/border block | AuraMaster | done | T5 commit: Style.ReportError (a [Style] debug line each time, geterrorhandler once per session per first line) from Container:Restyle and the Text icon block; text area anchored before any icon call; icon block pcall-guarded, a refusal hides the icon; smoke 99 gains the debug re-run; +4 tests (1130/1130) |
| 6 | Item 6 — Icon rows dim while Icon position is None; border drawn test | AuraMaster | todo | |
| 7 | Item 8 — piece justify and measured padding; brackets advice in Rules and docs | AuraMaster | todo | |
| 8 | Item 5 — Dispel type subsection moves to Text → Font | AuraMaster | todo | |
| 9 | Item 3 — the Justify Center note | AuraMaster | todo | |
| 10 | Item 2 — typeless-debuff wording; probe recorded in docs | AuraMaster | todo | probe output owed by owner |
| 11 | Re-vendor LibKa0s v1.46.0 into Aura Master | AuraMaster | todo | after owner tags |
| 12 | Re-vendor LibKa0s v1.46.0 into the other ten consumers (`chore/libka0s-v1.46.0`) | 10 repos | todo | after owner tags |
| 13 | Final gate (tests, lint, lizard, perf), smoke section U, test-case inventory | AuraMaster | todo | |
