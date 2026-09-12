# 05 — Summary: LibKa0s v1.33.0 → v1.34.0

**Tag moved v1.33.0 → v1.34.0 (`9165044` → `33bae81`).** Three library files moved: `Options.lua`
(minor 17 → 18), `OptionsCompose.lua` (minor 4 → 5) and `Slash.lua` (minor 9 → 10). The kit moved
revision 18 → 19. Every other file keeps its minor. The per-file table is in `01_DELTA.md`. Nothing
was deleted inside either payload.

**Reached the addon for free (class A).** Whole free-text values on every `string` row, which fixes
`/am set container.name My Raid Buffs`; the Reset-all tooltip's `resetProfile` wording; and the kit's
key-less `OnProfileReset`, which nothing here reads. See `02_CANDIDATES.md` for what each means here.

**References rolled.**

- `CLAUDE.md:35`, the provenance line.
- `DEPENDENCIES.md:85` and `:92`, the vendored-payload tag and its verify command.
- `docs/ARCHITECTURE.md:51`, the library row.

**Comments corrected:** none. No suite or comment pinned the truncation, called it a library bug, or
read a reset key.

**Adopted:** `profilesPage = true` (class B), in the commit after this one. **Declined:** none.
**Skipped or unreached:** none.

**Gates at the re-vendor commit.**

| Point | `lua tests/run.lua` | `luacheck .` | `lizard -C 15` |
|---|---|---|---|
| Before the copy | 680 passed, 0 failed, 0 skipped, 680 total | 0 / 0 in 90 files | clean, no function above CCN 15 |
| After the copy and the roll | 680 passed, 0 failed, 0 skipped, 680 total | 0 / 0 in 90 files | no production file changed |

The vendored-payload pair ran rather than skipped, against `../LibKa0s` at `v1.34.0`, and passed.
No suite printed an error line. Nothing was pushed, and no issue was filed.
