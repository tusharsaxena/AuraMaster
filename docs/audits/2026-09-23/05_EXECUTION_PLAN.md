# 05 — Execution plan: Ka0s Aura Master (2026-09-23)

This is the hand-off to the remediation engagement. Each step is one checkable change tied to a
deviation ID. The design for each is in `04_TECHNICAL_DESIGN.md`.

**Gate for every step.** Each step lands on green:

```
~/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua
~/.claude/wow-addon/bin/ka0s-bounded luacheck .
```

"Green" means 0 failures and 0/0 lint. Whenever the case count moves, regenerate
`docs/test-cases.md` and update the README `[tests]` badge in the same commit (testing-§5).

**Coverage.** This plan covers all 20 entries in `02_DEVIATIONS.md`: the 19 roots and the derived
AM-08. The recorded deviation AM-03 needs nothing. The owner re-reads its trigger at the next audit.

## Sprint 0 — Upstream (runs before any local step that depends on it)

These are optional. Only step 3.1 waits on U-1; nothing else here blocks the local work.

- [ ] **U-1 (AM-23).** Nominate `SafeRegisterEvent` to `LibKa0s-Core-1.0` (library-stack-§7's promotion
  bars), plus a rejected-names line in the DebugLog `[Init]` summary.
  - If it ships, re-vendor the whole folder to that tag. Move the `CLAUDE.md` provenance line in the same
    commit, and write the `docs/revendor/<date>-v<tag>/` bundle in the same change.
  - If it is declined, step 3.1 implements the host helper.
- [ ] **U-2 (AM-30).** LibKa0s testkit: add a `test_eol` case flagging a tracked path classified
  `-text` under `text=auto`. Adopted on the next re-vendor. It does not block step 1.5.
- [ ] **U-3 (AM-26).** WowAddonStandards: propose `docs/spell-research/` for documentation-§3's list of
  frozen stores. It does not block step 1.3; the Tier 3 row is compliant either way.

## Sprint 1 — Record and docs (docs only, no behavior change)

- [ ] **1.1 (AM-21).** Write the consolidated `docs/revendor/` bundle covering v1.34.0 → v1.53.0.
  - Include the base correction: the v1.55.0 re-vendor came from v1.53.0.
  - Include the v1.53.0 → v1.54.2 delta.
  - **Check:** `AUDIT.md`'s re-vendor listing prints nothing under "unrecorded" (E-7's commands).
- [ ] **1.2 (AM-07, AM-08).** Fix the five `docs/ARCHITECTURE.md` citations and the three
  `DEPENDENCIES.md` citations in E-15.
  - **Check:** re-run the E-15 resolver loop; every line holds its claimed symbol.
- [ ] **1.3 (AM-26).** Add the `spell-research/` Tier 3 row and drop it from the out-of-scope prose.
  - **Check:** every `.md` from E-4's listing is in exactly one table.
- [ ] **1.4 (AM-32).** Delete the four `layout-§1` register rows, or have the owner ratify them with a
  real ending condition. Reword the census preamble and cells.
  - **Check:** `test_layout_cap` stays green, since the issue terminal states still hold.
- [ ] **1.5 (AM-30).** Remove the stray `\r` at `tests/page_helpers.lua:80`, then run
  `git add --renormalize tests/page_helpers.lua`.
  - **Check:** `git ls-files --eol tests/page_helpers.lua` shows `i/lf w/crlf`, and the AUDIT.md (e)
    one-liner prints `0`.
- [ ] **1.6 (AM-33).** Name `global.minimap.minimapPos` as the third piece of named non-setting state.
  Owner `core/LauncherSetup.lua`; writer LibDBIcon.
- [ ] **1.7 (AM-34).** Re-group `DEPENDENCIES.md`: Python 3 and Pillow go under *Release / assets*, with
  the Pillow install and check commands.
- [ ] **1.8 (AM-35).** Drop `.claude` from `.pkgmeta`.
  - **Check:** the packaging check (c) prints nothing.
- [ ] **1.9 (AM-36).** `gh issue edit 10 --remove-label state:triaged --add-label state:done`.
- [ ] **1.10 (AM-28).** Remove the four unused `read_globals` entries.
  - **Check:** `luacheck .` still reports 0/0.
  - Optional: add a lint-config case that every declared name is referenced.

## Sprint 2 — Hub reshape (docs only)

- [ ] **2.1 (AM-25).** Spill the hub:

  | Content | Destination |
  |---|---|
  | Settings Schema detail | `docs/schema.md` |
  | Filter priority | `docs/data-flow.md` |
  | The disabled state | Tier 3 `lifecycle.md` (a new row in the map) |
  | Locale routing | `common-tasks.md` or Tier 3 `locale-routing.md` |
  | Overview's library tables | `module-map.md` |

  Then trim Known Limitations and Taint Notes to one line per item.
  - **Check:** `wc -l docs/ARCHITECTURE.md` is about 400 or less, the E-23 awk shows no mandated section
    over about 60 lines, and the map stays complete.
- [ ] **2.2 (AM-27, doc half).** Correct `docs/testing.md:16-19` once step 3.4 lands.

## Sprint 3 — Code (behavior-preserving or narrowly scoped, each test-first)

- [ ] **3.1 (AM-23).** Add `RegisterEventSafe` (from Core per U-1, or the host helper) and route
  `RegisterLifecycleEvents`, `TS.Sync`, `syncAuraListen` and the `LifecycleSetup` pending hold through it.
  Record the rejected names and surface them in `[Init]`.
  - **Test:** `M.__badEvents` with one lifecycle name. The other seven stay registered and the name is
    recorded. Mark it `-- red under:`.
- [ ] **3.2 (AM-24).** Switch the two `C_Timer.After` calls to `C_Timer.NewTimer` handles, canceled in
  `CM.StopListening` and `TS.Stop`. Reset `scheduled` and `scanScheduled` on cancel.
  - **Test:** `tests/test_disabled.lua` step 4 arms both before disabling and asserts `__timers()` is
    empty. Step 9, re-enabling, still passes.
- [ ] **3.3 (AM-22).** Make the Options stub hollow: its composers answer `{}`. Replace the equal-count
  assertion with the full count, the degraded count and the named composer delta. Add the fall-together
  case, `/am set <composed path>` on the degraded load.
  - Update `docs/settings-panel.md` → *The degraded panel*.
- [ ] **3.4 (AM-27).** Measure the gate (testing-§14) and compare `-j auto` with the serial run.
  - When totals and exit code agree, set `jobs = "auto"` in `tests/run.lua`.
  - Fix any suite that only passes when run serially.
  - Record the figures.
- [ ] **3.5 (AM-13).** Change the four library-missing lines to `%s` placeholder keys, and update
  `locales/enUS.lua`.
  - **Check:** `tests/test_locale.lua` shows no dead keys.
- [ ] **3.6 (AM-29).** Make the `enable`/`disable`/`lock`/`unlock` confirmations echo the stored value in
  §5's `set` shape.
  - **Test:** update the `test_slash_verbs` and `test_disabled` step-7 expectations.
- [ ] **3.7 (AM-31).** Characterization pins first. Then split `Cat.SyncUserCategories` into four named
  phase helpers, and turn `renderCategories` into a module-level per-grid table.
  - **Check:** `lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .` reports 0 warnings.

## Sprint 4 — Owner and release

- [ ] **4.1 (AM-20).** Capture real screenshots (issue #3), add the captioned `## Screenshots`, and run the
  README de-AI pass. Retire the `documentation-§1` register row. Remove "Unpublished" from Known
  Limitations. Until the images exist, the owner re-ratifies the row (item 4, a new date, a real
  trigger) or accepts that the finding stays open.
- [ ] **4.2 (AM-31, release half).** At the next release, run the four-suite runner and write `ANALYSIS.md`.
  - The release gate needs all four suites at `pass` and zero functions above CCN 15.
  - Its first row carries the commit SHA and the clean mark (revision 25).
  - Set a `Disposition` for every new watch-list entry.

## Ordering notes

- Land sprint 1 first. It is docs-only and unblocks nothing else, but it stops AM-21 from compounding at
  the next re-vendor.
- Steps 3.2 and 3.3 each change assertions in shared suites (`test_disabled`, `test_optionssetup`). Land
  each as its own commit, with its tests.
- Do not switch on `jobs = "auto"` (3.4) in the same commit as any other test change. A sharding
  failure must stay attributable to one cause.
- Every re-vendor from here on writes its bundle in the same change (AM-21's recurrence guard).
