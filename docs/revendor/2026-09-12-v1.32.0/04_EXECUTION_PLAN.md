# 04 — Execution plan

1. **Copy.** `libs/LibKa0s/` and `tests/_kit/` come whole from `git archive v1.32.0`. Afterwards
   both diffs are empty in content and in bytes.
2. **Ripple.** Roll the provenance line in `CLAUDE.md` to v1.32.0. In `DEPENDENCIES.md`, update the
   tag named in the vendored-payload check and in its verify command. Update the library row in
   `docs/ARCHITECTURE.md`. The test total is unchanged, so `docs/test-cases.md` and the README
   `Tests` badge do not move in this commit.
3. **Gate.** `lua tests/run.lua` and `luacheck .`, both green; CR == LF on every edited file.
4. **Commit.** One commit carrying both payloads, the provenance line, its references and this
   bundle.
5. **Adopt B1–B3, tests first.** New cases fail on the pre-adoption code, then pass:
   - a container page's Defaults and General's Defaults each log exactly one
     `[Set] reset <page>: N rows`, N the rows the reset changed, and no per-row `[Set]`;
   - Reset all (live, and the degradation stub) logs exactly one line in total, the profile handler's
     `[Set] reset profile '<name>' to defaults (N rows)`;
   - a profile copy logs `[Set] copied profile 'A' → 'B'`, once;
   - `CopyFrom` logs one `[Set] copy container <src>→<dst> (<section>): N rows` and no
     `[Containers]` summary;
   - `ResetPositions` logs one `[Set] reset positions: N rows`.
   Then the seam's mute and tally, the descriptors' pair, the profile handlers and the two host
   acts. Docs in step: `ARCHITECTURE.md`, `schema.md`, `profiles.md`, `settings-panel.md`,
   `smoke-tests.md`, `test-cases.md` and the README badge.
