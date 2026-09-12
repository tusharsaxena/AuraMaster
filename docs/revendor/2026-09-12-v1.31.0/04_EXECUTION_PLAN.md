# 04 — Execution plan

No candidate was adopted, so the plan is the re-vendor commit alone.

1. **Copy.** `libs/LibKa0s/` and `tests/_kit/` come whole from `git archive v1.31.0`. Afterwards
   both diffs are empty in content and in bytes.
2. **Ripple.** Roll the provenance line in `CLAUDE.md` to v1.31.0. In `DEPENDENCIES.md`, update the
   tag named in the vendored-payload check and in its verify command. Update the library table in
   `docs/ARCHITECTURE.md`. The test total is unchanged, so `docs/test-cases.md` and the README
   `Tests` badge do not move in this commit.
3. **Gate.** `lua tests/run.lua` and `luacheck .`, both green. `tests/test_vendor_sync.lua` compares
   both payloads against the tag the new line names, and the eol case passes after the CRLF repair.
4. **Commit.** One commit carrying both payloads, the provenance line, its references and this
   bundle.
