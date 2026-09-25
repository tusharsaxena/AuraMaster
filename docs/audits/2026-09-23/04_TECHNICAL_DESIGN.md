# 04 — Technical design: Ka0s Aura Master (2026-09-23)

This is the remediation design for every deviation in `02_DEVIATIONS.md`, all 20 entries including the
derived AM-08. Nothing here has been implemented: the audit is read-only.

The collection-wide remediation plan puts upstream work first. So each item below is marked as
**Upstream**, meaning LibKa0s or WowAddonStandards changes before this repo does, or **Local**, meaning
this repo only.

## Upstream first

Three items have an optional upstream half. Two of them ought to land upstream before this repo changes,
because this repo would then adopt a library member instead of hand-writing one.

| ID | Upstream option | If upstream declines |
|---|---|---|
| **AM-23** | Nominate a `SafeRegisterEvent(target, event, handler, record)` helper to `LibKa0s-Core-1.0`. It would pair a `C_EventUtils.IsEventValid` front-gate with a `pcall`, and append refused names to a caller-owned list. `events-frames-taint-§1` binds every addon, the semantics are identical, and no per-consumer flag is needed, so it clears library-stack-§7's three promotion bars. `LibKa0s-DebugLog-1.0` could also render the refused-name list inside `[Init]`. | A host helper in `core/CoreSetup.lua`, which is equally compliant. |
| **AM-30** | A second `test_eol` case in the testkit: fail when a tracked path's index classification is `-text` while `.gitattributes` gives it `text=auto`. That is the lone-CR blind spot line-endings-§7 names. | Nothing. The local fix below stands alone. |
| **AM-26** | Propose `docs/spell-research/` for documentation-§3's list of frozen stores in WowAddonStandards. | Register it as one Tier 3 row. This is the default, and it needs no upstream change. |

The rest of the plan does not depend on any upstream change.

The repo is on LibKa0s **v1.55.0** (test-kit revision 25). That is the floor for every rule applied here:

- the Lifecycle floor v1.42.0, the layout gate and the body gate are all met;
- there is no re-vendor prerequisite.

If AM-23's Core helper ships, re-vendor to the tag that carries it. Write its `docs/revendor/` bundle in
the same change, so AM-21 does not recur.

---

## A. Re-vendor record (AM-21) — Local, docs only

- **Where.** Write one new bundle folder, `docs/revendor/<date>-v1.34.0-v1.53.0/`, or a date-plus-span
  name the command accepts. It gets `01_DELTA.md` and `05_SUMMARY.md` only; audit-review-history says
  the middle three are written only when there is something to write.
- **`01_DELTA.md`.** The span v1.34.0 → v1.53.0, built from
  `git -C ../LibKa0s log --oneline v1.34.0..v1.53.0 -- LibKa0s testkit` and the matching
  `diff --stat`, over all 19 unrecorded tags. It should list each repo commit that carried a tag, from
  `git log -- libs/LibKa0s`: `f6f61d3` (v1.53.0), `f434521`, `482000f`, `5c3a093`, `d1d2f3b`,
  `29aef45` and the rest back to v1.35.0.
- **The base correction.** Add a *Correction* paragraph. The v1.55.0 re-vendor (`f6f3ffb`) came from
  **v1.53.0**, not v1.54.2, so record the v1.53.0 → v1.54.2 delta here as well. The frozen
  `2026-09-23-v1.55.0` bundle is **not** edited.
- **`05_SUMMARY.md`.** Say that sweeps carried these tags, and that most adoption was folded into feature
  commits. Name the ones the store would have recorded had it been kept: DragHandle (v1.48.0), the entry
  `suffix` (v1.49.0), and the Lifecycle and Slash minor 14 floor (v1.42.0).
- **Check.** Re-run `AUDIT.md`'s re-vendor listing. The unrecorded set must be empty. That needs the
  consolidated bundle's first line to carry the span's final tag v1.53.0, or each tag named in the
  folder or first line; follow the check's parsing rule.

## B. Screenshots and the publish contradiction (AM-20) — Local, needs the owner

- **Images.** Capture real in-client screenshots into `media/screenshots/` (issue #3's list). Add
  `## Screenshots` with captions between the description and `## Usage`, and put the README through the
  de-AI writing pass (documentation-§1). Decide what `.pkgmeta` does with `media/screenshots/`: ignore
  it, since store screenshots are uploaded separately. **This step cannot be automated**, because the
  images must be real.
- **The register row.** Either retire `docs/ARCHITECTURE.md:826`, or, if the images slip, re-ratify it
  with the owner. A re-ratified row cites *item 4*, uses a new Decided date, and has a trigger that ends
  the deviation, such as "captioned images land in the section". Its Why cell must no longer say its
  own trigger has fired.
- **Make three docs agree.** `docs/ARCHITECTURE.md:744-745` says "Unpublished"; delete that Known
  Limitations bullet, or restate it as the published fact. `README.md:28` says "before the first
  release"; drop it with the section rewrite.
- **Guard.** The docs gate can assert that `## Screenshots` contains at least one `![` whenever the TOC
  carries `X-Curse-Project-ID`.

## C. The Options stub goes hollow (AM-22) — Local

- **The stub.** In `settings/OptionsSetup.lua:193-280`, replace `composeBlock` and the five composer
  bodies with members that answer `{}`. `MasterControls` answers `{}, function() end`. Keep the members,
  so the load-completing property holds. Delete `composeBlock`, and update the header comment
  (`:175-192`) to cite options-ui-§1's composed-content ruling.
- **Profile defaults.** No change. They come from `NS.defaults`, merged at `InitDB`, never from the
  schema, so a composed setting the player already changed stays honoured on a degraded load
  (options-ui-§1).
- **The fall-together property.** The degraded environment (`tests/degraded_env.lua`) loads the addon
  with **no** LibKa0s files, so Slash is absent alongside Options. Add a case asserting that
  `/am set <a composed path>` answers the stub's "unavailable" line. That proves no composed row can be
  addressed.
- **The test.** Replace `tests/test_optionssetup.lua:369` with three pins:
  - the full-load count (currently 242 plus runtime category rows);
  - the library-absent count;
  - a named delta attributed to the composers (`FontGroup ×N`, `BorderGroup ×N`, `BarGroup ×N`,
    `ColorPair ×N`, `MasterControls 10`).

  Mark the case `-- red under: give a stub composer a non-empty row list`.
- **Knock-on.** `NS.ValidateSchema` and the test that validates every path on the degraded load must
  tolerate the smaller schema. `tests/test_surface_parity.lua` compares **member sets** and is
  unaffected.
- **Docs.** Update `docs/settings-panel.md` → *The degraded panel*.

## D. Event registration survives a bad name (AM-23) — Upstream option, then Local

- **The helper,** whether it comes from Core or is local:

  ```lua
  -- core/CoreSetup.lua (or LibKa0s-Core-1.0)
  NS.RejectedEvents = NS.RejectedEvents or {}
  function NS.RegisterEventSafe(target, event, handler)
      local valid = _G.C_EventUtils and _G.C_EventUtils.IsEventValid
      if valid and not valid(event) then NS.RejectedEvents[event] = "invalid"; return false end
      local ok, err = pcall(target.RegisterEvent, target, event, handler)
      if not ok then NS.RejectedEvents[event] = tostring(err); return false end
      return true
  end
  ```

- **The call sites.** `addon:RegisterLifecycleEvents` becomes a loop over a module-level list, calling
  the helper once per event. Unregistering stays symmetric, since unregistering an unknown event is
  harmless. `TS.Sync` (`:140-142`) and `syncAuraListen` (`:121`) go through the helper too.
  `core/LifecycleSetup.lua:71` registers `PLAYER_REGEN_ENABLED`, which always exists; route it through
  the helper anyway for one shape.
- **Making it visible.** Add the rejected names to the `[Init]` summary, for example
  `…, 0 rejected events` or `rejected: X,Y`. Optionally add a `/am debug events` word to `runDebug` that
  prints the list.
- **Tests.** Set `M.__badEvents = { ADDON_RESTRICTION_STATE_CHANGED = true }`. Assert that the other
  seven lifecycle events still register, that the name is recorded, and that `[Init]` names it. Mark the
  case `-- red under: replace the helper with a bare self:RegisterEvent`.

## E. Cancelable one-shot timers (AM-24) — Local

- **ContainerManager.** `modules/ContainerManager.lua:155` becomes
  `flushTimer = C_Timer.NewTimer(0, function() flushTimer = nil; CM.FlushPending() end)`. In
  `CM.StopListening` (`:557-563`), cancel it: `if flushTimer then flushTimer:Cancel(); flushTimer = nil end`,
  then `scheduled = false`.
- **TimedSpells.** `modules/TimedSpells.lua:106` becomes `scanTimer = C_Timer.NewTimer(0.5, scanTick)`.
  In `TS.Stop` (`:131-134`), cancel it and reset `scanScheduled`. Keep the `listening` guard as defence
  in depth, and rewrite the comment at `:162-164`.
- **Mock support.** Check that `tests/wow_mock.lua` or `mock_base` exposes `C_Timer.NewTimer` with a
  handle whose `:Cancel()` removes it from `__timers()`. If the kit lacks it, that is an upstream testkit
  item. Timer cancellation is already modelled for AceTimer, so the kit most likely has it.
- **Test.** In `tests/test_disabled.lua` step 4, arm both callbacks (request an apply, and schedule a
  scan through `UNIT_AURA` on a readable state) **before** writing `enabled = false`. Assert
  `__timers()` is empty afterwards. Mark it `-- red under: go back to C_Timer.After`.

## F. Docs sweep (AM-07, AM-08, AM-25, AM-26, AM-32, AM-33, AM-34) — Local, docs only

- **AM-07 and AM-08.** Fix the eight citations (E-15). Then strengthen the docs gate (issue #6's
  successor): for each `` `path:N` `` citation that names a symbol in the same sentence, assert the
  symbol appears within ±0 lines. At minimum, report every citation whose line is a comment or blank.
- **AM-25, spilling the hub.**

  | Content | Destination |
  |---|---|
  | Settings Schema's surfaces table and named-state detail, `:167-241` | `docs/schema.md` → *Registries and named state*. Leave a 10–15 line summary: registry names, writer names, and one link |
  | Filter priority | `docs/data-flow.md` → Step 4, which already has the detail |
  | Locale routing | `common-tasks.md` or a Tier 3 `locale-routing.md` |
  | The disabled state | a Tier 3 `lifecycle.md`, with a 5-line summary kept |
  | Known Limitations and Taint Notes items | one line each, linking `midnight-quirks.md` |
  | Overview's library tables | `module-map.md` |

  Target under about 400 lines, with no mandated section over about 60.
- **AM-26.** Add a row to `### Addon-specific`:
  `| spell-research/ | Frozen per-build derivation bundles from tools/spell-research/research.py (one row for the store; dated bundles are not enumerated) |`.
  Remove `docs/spell-research/<date>/` from the prose at `:781`.
- **AM-32.** Delete the four `layout-§1` rows at `:827-830`; issues #16 to #19 are each file's terminal
  state. Reword the census preamble (`:834`) and each census cell to drop "The `layout-§1` row above…".
  Alternatively the owner ratifies them, with the trigger reading "the peel lands and the file is back
  under 1500 lines".
- **AM-33.** Add a third named-state bullet under Settings Schema. Storage key:
  `global.minimap.minimapPos`. Owner: `core/LauncherSetup.lua`. Writer: LibDBIcon-1.0, reached when the
  player drags the button, with no addon writer. Change "two pieces" to "three".
- **AM-34.** Restructure `DEPENDENCIES.md`:
  - Summary-table Release/assets row: "Python 3.8+ (spell-research generator); Pillow (the 128 icon).
    Not needed to build, run or test."
  - Move the python3 and internet rows from Development into the Release/assets section.
  - Add `sudo apt-get install -y python3-pil` (or `pipx`-free, since Pillow is a library), plus the
    check `python3 -c "import PIL; print(PIL.__version__)"`.

## G. Tests and toolchain (AM-27, AM-28, AM-30, AM-31) — Local

- **AM-27.**
  1. Measure per testing-§14: wall time, CPU time, and whether `loadfile` or git spawns dominate. The
     kit's cache and batch are already in revision 25.
  2. Run `lua tests/run.lua -j auto` and compare its totals and exit code with the serial run.
  3. Set `jobs = "auto"` in `tests/run.lua`'s `Kit.run{}`.
  4. Record the before and after figures in the next `RESULTS.md` run.
  5. Fix `docs/testing.md:16-19`.
  6. Any suite that fails only when sharded is a bug to fix, not a reason to stay serial.
- **AM-28.** Delete `"GameTooltip"`, `"C_Spell"`, `"GetAddOnMetadata"` and `"GetSpellInfo"` from
  `.luacheckrc:14-15`. Optionally extend `tests/test_lintconfig.lua` with a case asserting every
  `read_globals` name is referenced by some authored file. That makes the file's own comment
  enforceable.
- **AM-30.** Remove the extra `\r` at `tests/page_helpers.lua:80`. Run
  `git add --renormalize tests/page_helpers.lua`, then confirm
  `git ls-files --eol tests/page_helpers.lua` reports `i/lf w/crlf`.
- **AM-31.**
  - Write characterization tests first (testing-§13). `Cat.SyncUserCategories` already has broad
    coverage in `tests/test_defaults.lua` and `tests/test_database.lua`; confirm the four phases are
    each pinned. `renderCategories` is covered by `tests/test_pages_filters.lua`.
  - Split `Cat.SyncUserCategories` into `teardownUserDefs()`, `insertionAnchors()`,
    `materializeRecords(order, recs, template)` and `registerUserRows(built, before)`. These are named
    file-local helpers (performance-§11 shapes 2 and 4) with no per-call allocation beyond what exists
    today.
  - Replace `renderCategories`' `if g.key ==` chain with a module-level `GRID_RENDER = { custom = …,
    blizzard = …, default = … }` table (shape 1).
  - Then run the vendored runner and commit the bundle: `lint` and `tests` gate, `complexity` records.

## H. Wording and label hygiene (AM-13, AM-29, AM-35, AM-36) — Local

- **AM-13.** In `core/CoreSetup.lua:72`, `core/DebugLogSetup.lua:19`, `core/LauncherSetup.lua:50` and
  `core/PerfSetup.lua:24`, format through placeholder keys such as
  `L["%s, so the debug console window is unavailable."]` and `L["%s; running on reduced built-in fallbacks."]`.
  Add the keys to `locales/enUS.lua` and remove the old fragment keys; `tests/test_locale.lua` enforces
  that no dead key is left.
- **AM-29.** In `runEnabled` and `runLock` (`settings/Slash.lua:191-195`, `:282-285`), print the stored
  value through the dispatcher's key/value formatter. That is `cli:CliGet("enabled")` or the library's
  exported `FormatKV`, whichever `LibKa0s-Slash-1.0` v1.55.0 publishes. The echo then reads
  `enabled = true` and `locked = false` in the house colours. The disable echo when already disabled
  shows `enabled = false`, which the playbook expects.
- **AM-35.** Delete `.pkgmeta:12`, or comment it out as `#   - .claude  # only in a repo that has one`.
- **AM-36.** Run `gh issue edit 10 --remove-label state:triaged --add-label state:done`. Space the call
  out from any bulk label work.

## Risks and ordering constraints

- **AM-22 changes the degraded schema row count.** Any case that assumes degraded and live counts are
  equal must move with it. Land it in one change with its tests.
- **AM-24 changes timer semantics.** `NewTimer(0)` still fires next frame. The coalescing flag
  (`scheduled`) must reset on cancel, or the stand-up's `RequestApply(nil, true)` would be swallowed.
  Test the re-enable path (`tests/test_disabled.lua` step 9).
- **AM-25 moves content only.** It must not change the `## Documentation map` scope, and it must add any
  new Tier 3 file (`lifecycle.md`, `locale-routing.md`) to the map in the same change.
- **AM-21 must be written before any further re-vendor.** Otherwise the next bundle's delta base is
  ambiguous again.
- **AM-27 needs the suite shard-safe.** Any cross-suite coupling found while sharding is fixed before
  `jobs` is switched on.
