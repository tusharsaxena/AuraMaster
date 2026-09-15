# Feedback batch 7 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development.

**Goal:** the owner's 2026-09-15 in-game feedback, nine items, after playing with batch 6.

**Spec:** `docs/superpowers/specs/2026-09-15-feedback-batch7-design.md` — binding; read it with this.

**Architecture:** continues on batch 6's branch (spec D1). LibKa0s drops the grid's yellow fill and
ships v1.36.2. Aura Master gains an `Uncategorized` category that rescues unlisted auras from a
broad Blizzard category's Hide, a new Containers page with Filters/Layout/Bars/Icons nested under
it, a fixed page-navigation seam, and an ASCII-only guarantee on user-facing strings.

## Global Constraints

- Green gate before every commit: `lua tests/run.lua`, `luacheck .` (0/0),
  `lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .` (no function above CCN 15).
- Checkpoint commits and branch pushes ARE authorized (owner, 2026-09-14). Merging, tag pushes and
  addon version bumps are NOT.
- Branches: AuraMaster `feat/2026-09-14-feedback-batch6`; LibKa0s `feat/2026-09-14-v1.36.0`.
- Commit trailers: the session's two attribution lines.
- The Ka0s WoW Addon Standard is binding; a deviation STOPS the task and is reported.
- Every user-visible string through `NS.L`, key in `locales/enUS.lua`, US spelling, **ASCII only**.
- CRLF. For uncommitted content repair by EDITING, never `git checkout`.

---

## Status ledger (UPDATE AFTER EVERY TASK)

Resume as `docs/superpowers/plans/2026-09-14-feedback-batch6.md` describes: read this table, verify
it against `git log`, trust git over the table, continue at the first row that is not `done`.

| Task | Req | Repo | Status | Commit | Notes |
|---|---|---|---|---|---|
| P1 ASCII sweep + guard, strata, issue | T-1 X-1 X-3 | AM | done | 0f31609 | guard allowlists ASCII + em dash, proven red on a pasted glyph |
| P2 Uncategorized category | U-1…U-5 X-2 | AM | done | 5105b93 f00123d eb52b27 64c25e4 2111e40 0e2b79a | 5 rounds; toggle removed; debuff row restored; FINAL REVIEW CRITICAL: migration widened a narrowed container |
| P3 LibKa0s v1.36.2 plain checkbox | G-1…G-3 | LibKa0s | done | 331416d d39e4b4 6acc177 | fill withdrawn; ASCII guard rewritten to decode bytes |
| P4 re-vendor v1.36.2 (10 repos) | G-3 | all | done | P4a nine + P4b bd4fa80 | all eleven byte-identical to the tag |
| P5 Containers page + sub-pages | N-1 N-2 | AM | done | 0c39032 | label-prefix nesting, copied from MultiMeters |
| P6 navigation fix + See spells + info icons | N-3 N-4 N-5 | AM | done | 4087784 | every page now records its category, not just container pages |
| P7 Categories tab readability | T-2 T-3 | AM | done | 6b2981e | blurb one rank per line; T-3 overtaken, enchant row re-homed |
| P8 Bars/Icons tab restructure | S-1 | AM | done | 2880b6e | Size folded into a renamed General; Icons deliberately unchanged, reason documented |
| P10 spark appearance in clip mode | SP-1 SP-2 | AM | done | 0b4b0c9 | backdrop is half-opaque, so BLEND not colour-match |
| P9 docs + final battery | all | all | done | 1821ca8 | 10 false statements fixed, six of them unpassable smoke checks |

**Dependency order:** P1, P2, P3, P8, P10 are independent. P4 needs P3. P6 needs P5. P7 needs P2.
P9 is last.

## File structure

| File | Change |
|---|---|
| `../LibKa0s/LibKa0s/OptionsWidgets.lua` | drop `choiceFill` and its release restore |
| `core/Constants.lua`, `defaults/Profile.lua` | strata MEDIUM; template stamps `uncategorized` |
| `defaults/Categories.lua` | + `uncategorized`, kind `uncategorized`; `DefaultStates()` covers it |
| `modules/FilterCompiler.lua` | the `uncategorized` group and its exclusion shape |
| `core/Database.lua` | v3 migration stamps the new row |
| `settings/Containers.lua` (new) | the Containers page |
| `settings/General.lua` | Containers tab moves out |
| `settings/OptionsSetup.lua` | record every page's category (`N-3`); sub-page label prefix |
| `settings/Filters.lua` | Uncategorized row, blurb layout, See spells control, info icons |
| `settings/Bars.lua`, `settings/Icons.lua` | Size folded into a renamed General tab |
| `locales/enUS.lua` | ASCII-only values |
| `tests/…` | a non-ASCII guard; coverage for each change |
