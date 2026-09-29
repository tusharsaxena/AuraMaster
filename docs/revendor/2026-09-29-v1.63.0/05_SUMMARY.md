# 05 - Summary: LibKa0s v1.62.0 -> v1.63.0

## The move

Tag `v1.62.0` -> `v1.63.0` (`dd7a774`, a local tag), base taken from the `CLAUDE.md` provenance line.
Re-vendored in the `SP-AM-02: re-vendor LibKa0s v1.63.0` commit on
`feat/2026-09-29-smoke-and-profile`, with the provenance line and the two other places that name the
vendored tag (`DEPENDENCIES.md`'s vendor-sync paragraph, `docs/module-map.md`'s library row). One
file moved a LibStub minor:

| File | Minor |
|---|---|
| `Slash.lua` | 16 -> 17 |

No file was added or removed, no `NEEDS_*` floor rose, no major was added. The test kit stays at
revision 31, byte for byte.

## Delivered for free (class A)

None.

## Contract blockers

None (`01_DELTA.md` 3g).

## Carried in the re-vendor commit

- The provenance line, `DEPENDENCIES.md` and `docs/module-map.md`, rolled to `v1.63.0`.
- The library-absent Slash stub (`settings/Slash.lua`) gains `CliProfile` and `ProfileSwitch`, each
  printing `/am profile is unavailable: the LibKa0s library did not load.` and switching nothing,
  because the by-name surface-parity case compares it against the live instance, which has both
  from minor 17. A new case in `tests/test_slash_verbs.lua` pins what they print.
- `docs/slash-dispatch.md` (*Degraded path*) names the two stub members. Four `settings/Slash.lua`
  citations the stub's new lines shifted are re-pointed (`docs/slash-dispatch.md` three,
  `docs/module-map.md` one).
- `docs/test-cases.md` regenerated and the README badge rolled: 1706 -> 1707 cases.

## Adopted

Only the Slash minor 17 profile surface, and by the same item's second commit (`SP-AM-02: /am
profile via CliProfile`): a `profile` row in `NS.COMMANDS` routed to `cli:CliProfile(rest)`, the
descriptor's `profiles` field, and `profile` live while disabled. Nothing else in this release is
adopted.

## Declined

None. No issue filed.

## Skipped or unreached

None.

## Suite results

Run through `ka0s-bounded` from the repo root: `lua tests/run.lua`, `luacheck .`,
`lizard -l lua -x "./libs/*" -x "./tests/_kit/*" -C 15 -w .`.

| Gate | Headless tests | Lint | Complexity |
|---|---|---|---|
| Before the copy (v1.62.0) | 1706 passed / 0 failed / 0 skipped | 0 / 0 in 146 files | not run |
| The copy alone | 1705 passed / 1 failed (Slash surface parity) | not run | not run |
| After the re-vendor commit (v1.63.0) | 1707 passed / 0 failed / 0 skipped | 0 / 0 in 146 files | 0 above CCN 15 |

`tests/test_vendor_sync.lua` compared both payloads against `v1.63.0` and passed.
