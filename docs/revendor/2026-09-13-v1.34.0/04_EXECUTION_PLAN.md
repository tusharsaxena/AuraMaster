# 04 — Execution plan

1. **Copy.** `libs/LibKa0s/` and `tests/_kit/` come whole from `git archive v1.34.0`. Afterwards both
   diffs are empty in content and in bytes.
2. **Ripple.** Roll every live reference to the bundled version:
   - `CLAUDE.md:35`, the provenance line;
   - `DEPENDENCIES.md:85` and `:92`, the vendored-payload tag and its verify command;
   - `docs/ARCHITECTURE.md:51`, the library row.

   Dated records (reviews, audits, earlier revendor bundles) stay as they are. The test total does
   not move, so `docs/test-cases.md` and the README test badge do not move either.
3. **Gate.** `lua tests/run.lua`, `luacheck .` and `lizard -C 15`, all green; CR == LF on every
   edited and new file.
4. **Commit A.** One commit carrying both payloads, the provenance line, its references and this
   bundle.
5. **Commit B, the adoption.** `profilesPage = true` on the descriptor in
   `settings/OptionsSetup.lua`; a test that the Reset-all tooltip names the equivalence, red before
   the field; a test that `/am set container.name My Raid Buffs` stores the whole name; the docs that
   describe the Reset-all tooltip or a free-text limit; the test inventory and the badge. Gate as in 3.
