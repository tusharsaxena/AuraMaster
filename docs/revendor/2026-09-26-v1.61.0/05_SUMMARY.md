# 05 - Summary: LibKa0s v1.60.0 -> v1.61.0

## The move

Tag `v1.60.0` -> `v1.61.0` (`c6183bd`, a local tag), base taken from the `CLAUDE.md` provenance line.
Re-vendored in the `SR-AM-01` commit on `feat/2026-09-26-settings-redesign`, with the provenance line
and the two other places that name the vendored tag (`DEPENDENCIES.md`'s vendor-sync paragraph,
`docs/module-map.md`'s library row). Two files moved a LibStub minor and one is new:

| File | Minor |
|---|---|
| `Options.lua` | 24 -> 25 |
| `OptionsTabs.lua` | 4 -> 5 |
| `OptionsNav.lua` | new, 1 (`LibKa0s-Options-1.0` key 24.31.4.7.4 -> 25.31.5.7.4.1) |

No file was removed, no `NEEDS_*` floor rose, no major was added. The test kit stays at revision 27
and `tests/_kit/` is unchanged.

## Delivered for free (class A)

- The rail inset the strip, the content panel and the scroll read. It is 0 on every page that draws no
  rail, which is every AuraMaster page until `SR-AM-03`.

## Contract blockers

None (`01_DELTA.md` 3g).

## Carried in the re-vendor commit to keep the suite green

- `settings/OptionsSetup.lua`'s library-absent stub gains a `NavRail` no-op, for
  `tests/test_surface_parity.lua`'s Options case. Before it, that case failed naming `NavRail` as
  missing from the stub, and it was the only failure.

## Adopted

Nothing in this run. `O.NavRail` is adopted in `SR-AM-03` (`03_DECISIONS.md`).

## Declined

None. No issue filed.

## Skipped or unreached

None.

## Suite results

Run through `ka0s-bounded` from the repo root: `lua tests/run.lua`, `luacheck .`,
`lizard -l lua -x "./libs/*" -x "./tests/_kit/*" -C 15 -w .`.

| Gate | Headless tests | Lint | Complexity |
|---|---|---|---|
| Before the copy (v1.60.0) | 1637 passed / 0 failed / 0 skipped | 0 / 0 in 138 files | 0 above CCN 15 |
| After the copy, before the stub | 1636 passed / 1 failed (the Options parity case, `NavRail`) | not run | not run |
| After the re-vendor commit (v1.61.0) | 1637 passed / 0 failed / 0 skipped | 0 / 0 in 138 files | 0 above CCN 15 |

`tests/test_vendor_sync.lua` compared both payloads against `v1.61.0` and passed.
