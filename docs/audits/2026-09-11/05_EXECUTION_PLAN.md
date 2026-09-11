# 05 — Execution plan (2026-09-11)

This is the hand-off to the remediation engagement. The steps are ordered, and each carries its
deviation IDs (see `02_DEVIATIONS.md` for grades and `04_TECHNICAL_DESIGN.md` for the shape of each
change).

**Commit rules:**

- Every step ends green: `lua tests/run.lua` passing, and `luacheck .` at 0 warnings / 0 errors.
- Commit only on green, to trunk, and only when the user asks.
- No version bump unless it is instructed.

**Scope.** The plan covers **17 root deviations**: 3 Medium and 14 Low. Counting the 3 dependents,
there are **20** entries, all Low beyond the three Mediums. The plan does not re-grade them.

---

## Sprint 0 — Decisions (user, before any code)

- [ ] **AM-03.** Pick the `options-ui-§17` class-color approach. Option A records a register row;
      option B resolves the unit's class and restyles on swap.
- [ ] **AM-04.** Pick the `events-frames-taint-§1` TimedSpells approach. Option A records a register
      row; option B moves to AceEvent with an in-handler unit filter.

## Sprint 1 — Reachable combat and display edges (Medium)

- [ ] **AM-02** — defer structural teardown under lockdown.
  - [ ] Write failing cases in `tests/test_containermanager.lua` and `tests/test_slash.lua`:
        delete in combat, then flush after combat.
  - [ ] Add `Container:Park()`, a `pendingDestroy` set drained by `CM.FlushPending`, and the
        `MustDefer` branch in `CM.Sync`.
  - [ ] Add combat refusals to `/am delete` (`settings/Slash.lua`) and to the Containers page Delete
        (`settings/Containers.lua`).
  - [ ] Green gate.
- [ ] **AM-01** — replay pending anchors on `PLAYER_REGEN_ENABLED`.
  - [ ] Write a failing case in `tests/test_anchors.lua`.
  - [ ] Call `NS.Anchors.ResolvePending()` in `core/AuraMaster.lua`'s regen branch.
  - [ ] Green gate.
- [ ] **AM-03** — implement the Sprint 0 choice.
  - Option A: add the register row to `docs/ARCHITECTURE.md` and point Known Limitations and
    `docs/scope.md:81-82` at it.
  - Option B: take the unit source path with its tests.
  - [ ] Green gate.

## Sprint 2 — Latent code gaps (Low)

- [ ] **AM-11** — make `CM.FlushPending` return while `NS.Perf.suspended`, and extend the suspend
      case in `tests/test_perf.lua`.
- [ ] **AM-17** — add the `TIMED_SPELLS_CHANGED` message in `core/Bus.lua`; switch TimedSpells to
      send it; subscribe ContainerManager; move master-row visibility into the `CONFIG_CHANGED`
      receiver; add the two-receiver case. This step depends on AM-11.
- [ ] **AM-04** — implement the Sprint 0 choice: either the register row, or the AceEvent move with a
      perf scenario.
- [ ] **AM-10** — add `Compat.GetAddOnMetadata`; route `core/EnvSetup.lua` through it; add the
      degraded-arm test.
- [ ] **AM-12** — first a characterization case for `Style.ElementSize` and `Container.FlowSettings`;
      then replace the 12 re-typed defaults (E-18) with `NS.CONTAINER_TEMPLATE` reads or drop them.
- [ ] **AM-05** — compose the Background block with `H.BarGroup` (confirm the live `keys` remap
      first); add `bgAlpha`; apply it in `modules/Style_Bars.lua`; update the pinned row counts (192
      → 193) and the degraded delta. This step comes after AM-03.
- [ ] **AM-19** — replace the refusal text with the canonical wording, keyed through `L`.
- [ ] **AM-13** (with **AM-14**) — rewrite the seven `settings/Slash.lua` concatenations as keyed
      sentences with placeholders, wrapping each value in `NS.SafeToString`; route
      `"Container %d"` and `"%s (copy)"`. `tests/test_locale.lua` stays green.
- [ ] **AM-16** — add the three gated `NS.Debug` lines: apply deferred, anchor fallback, and resolve
      skipped.
- [ ] Green gate after each item.

## Sprint 3 — Tests and gates (Low)

- [ ] **AM-06** — extend the tab mock to answer a different selected-art height; add the wrap-invariant
      case to `tests/test_optionssetup.lua` with the mutation named in its comment.
- [ ] **AM-18** — file the LibKa0s issue for a `100755` assertion in `testkit/vendor_sync.lua`; add
      the interim local case in `tests/test_vendor_sync.lua`.
- [ ] Regenerate `docs/test-cases.md` (`lua tests/run.lua --list > docs/test-cases.md`) and the
      README `[tests]` badge in the same change (testing-§5).

## Sprint 4 — Docs and config (Low), last because code moves lines

- [ ] **AM-07** (with **AM-08**, **AM-09**) — re-run the E-15 citation script over `docs/*.md` and
      `DEPENDENCIES.md` and fix all 35, plus the 2 unverified ones. Fix the `Compat.IsAddOnLoaded`
      sentence. Correct the `core/PoolSetup.lua:5-9` and `core/CoreSetup.lua:80-81` comments, or
      remove the unused `NS.SKIN`/`NS.ApplySkin` exports on both arms.
- [ ] **AM-15** — add the per-group `# Conventional:` comments to `AuraMaster.toc`.
- [ ] **AM-20** — capture screenshots into `media/screenshots/` and add a captioned `## Screenshots`
      section. De-AI pass on the README edit.
- [ ] Update `docs/ARCHITECTURE.md` for anything sprints 1–3 changed: the message count, the schema
      row count, the Compat shim count, and any register rows.
- [ ] Final green gate.

## Exit criteria

- [ ] All 17 roots closed or ratified by a register row (AM-03 and AM-04 only).
- [ ] The E-15 citation script resolves every citation.
- [ ] `lua tests/run.lua` and `luacheck .` are green.
- [ ] A fresh `/wow-addon:standards-audit` files no reopened `AM-` ID.
