# 05 — Summary

**Tag moved v1.29.0 (`8054bd4`) → v1.30.0 (`e369e0f`).** Every file's minor is unchanged. The ship
payload is byte-identical to the one it replaces. The kit moved from revision 15 to 16
(`README.md`, `framework.lua`, `mock_base.lua`, `vendor_sync.lua`). The per-file table is in
`01_DELTA.md`.

**Reached the addon for free (class A).** The kit's `AceGUI:Release` is now shaped like the client's:
it raises on nil or a double release and fires `OnRelease` before the wipe. The chrome band's release
path in `settings/OptionsSetup.lua` now runs against it headlessly. `RegisterEvent` validates as
CallbackHandler does, and `modules/TimedSpells.lua`'s registrations pass. The runner-mode (100755)
check now comes from the kit.

**Adopted** (all in the re-vendor commit on `chore/libka0s-1.30.0-arch5`): the `tests/wow_mock.lua`
shims for `AceGUI:Release` (#27), `Printf` (#30) and AceEvent's embed events (#29), and the local
100755 case in `tests/test_vendor_sync.lua` (#28).

**Declined:** none. No candidate needs a harness migration, because `tests/wow_mock.lua` builds on
the kit's `mock_base.lua` and does not replace it. **Skipped or unreached:** none.

**Gates.**

| Point | `lua tests/run.lua` | `luacheck .` |
|---|---|---|
| Before the copy | 251 passed, 0 failed, 0 skipped, 251 total | 0 / 0 in 62 files |
| After the copy and the shim deletions | 250 passed, 1 failed: `DEPENDENCIES.md:45` cited the deleted local case | 0 / 0 in 62 files |
| After the citation fix and inventory regeneration | 251 passed, 0 failed, 0 skipped, 251 total | 0 / 0 in 62 files |

The total is unchanged at 251: the local case left (−1) and the kit's case arrived (+1). The one
renamed entry is in the regenerated `docs/test-cases.md`. `.luacheckrc` excludes `libs/` and
`tests/_kit/`, but the files the shims lived in (`tests/wow_mock.lua`, `tests/test_vendor_sync.lua`)
are inside the checked set.

Nothing was pushed.
