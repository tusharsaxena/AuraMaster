# 04 — Execution plan

All four adoptions remove test-only code, and the re-vendor itself makes them necessary: B4 has to
land with the copy, or the check runs twice. So they ship in **one commit** with both payloads and
the provenance line. That is the atomic re-vendor commit, with the shims it retires.

1. **Characterization.** The tests that exercise each shim already exist. `test_optionssetup.lua`
   covers B1 (the chrome band's release path), `test_setups.lua:27-39` covers B2,
   `test_timedspells.lua`, `test_perf.lua:60-68` and `tests/perf.lua:178` cover B3, and the kit's
   runner-mode case covers B4. The assertion that proves each change is that these same cases pass
   unmodified once the shim is gone and the kit's version answers.
2. **Copy.** `libs/LibKa0s/` and `tests/_kit/` come whole from `git archive v1.30.0`. Both diffs
   are empty afterwards.
3. **Delete** the three `tests/wow_mock.lua` blocks and the header bullet (B1-B3), and the local
   case in `tests/test_vendor_sync.lua` (B4).
4. **Ripple.** Roll the provenance line in `CLAUDE.md` to v1.30.0. In `DEPENDENCIES.md`, update the
   tag it names (:85, :92) and the git row's citations (:45, which pointed at the deleted local case
   and at a kit line that moved). Update the library table in `docs/ARCHITECTURE.md` (:51).
   Regenerate `docs/test-cases.md` with `lua tests/run.lua --list`: one case is renamed and the total
   is unchanged at 251, so the README `Tests` badge (251/251) does not move.
5. **Gate.** `lua tests/run.lua` and `luacheck .`, both green, with the eol case passing after the
   CRLF repair.
