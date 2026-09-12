# 02 — Candidates

Sources: `git -C ../LibKa0s log --oneline v1.29.0..v1.30.0` (`7aaf1fe`, `aaef20a`, `e5f6906`,
`e369e0f`), the v1.30.0 block of `CHANGELOG.md` (`git -C ../LibKa0s show v1.30.0:CHANGELOG.md`,
lines 13-131), and `tests/_kit/README.md`'s new section "The Ace fakes, and the shims they replace"
(kit revision 16). No major's minor moved, so there is no `docs/api/<Major>/` delta to read.

## Class A: reached the addon on the re-vendor alone

- **The kit's `AceGUI:Release` is the client's shape.** It fires `OnRelease`, wipes the widget, and
  raises on `Release(nil)` and on a double release. `settings/OptionsSetup.lua:327-333`
  (`releaseStaleChromeWidgets`) now runs against that contract headlessly rather than against a
  forgiving shim. Every `test_optionssetup.lua` case passes, so no render releases a widget twice or
  releases nil.
- **`RegisterEvent` validates like CallbackHandler.** `modules/TimedSpells.lua:121,140-142` pass
  function handlers, so they pass the checks.
- **The runner-mode case runs from the kit.** It is `the automated-test runner is recorded
  executable (100755)`, registered by `VendorSync.register` (`tests/_kit/vendor_sync.lua:339-377`).

## Class B: host change required (each one deletes a local shim)

| # | What | Evidence | Files touched | Recommendation | Blast radius |
|---|---|---|---|---|---|
| B1 | Delete the local `AceGUI:Release` shim and its header bullet | CHANGELOG v1.30.0 "Kit revision 16, `mock_base.lua` — `AceGUI:Release` (#27)" | `tests/wow_mock.lua` (old :14, :167-178) | **Adopt.** The kit carries the same recorder fields (`w.__released`, `AceGUI.__released`), and no test reads them | Replaces test-only code; no production code |
| B2 | Delete the local `Printf` shim over `NewAddon` | CHANGELOG "`Printf` beside `Print` (#30)" | `tests/wow_mock.lua` (old :180-197) | **Adopt.** `tests/test_setups.lua:27-39` keeps its red-under because the kit stamps `Printf` as a plain field that `core/AuraMaster.lua` reclaims | Replaces test-only code |
| B3 | Delete the local AceEvent Embed events shim | CHANGELOG "AceEvent's event half on an embed (#29)" | `tests/wow_mock.lua` (old :199-224) | **Adopt.** Same `__events` field; handlers stored as passed; `UnregisterAllEvents` clears in place. These are what `tests/test_timedspells.lua`, `tests/test_perf.lua:60,67` and `tests/perf.lua:178` read | Replaces test-only code |
| B4 | Delete the local 100755 case | CHANGELOG "the runner's recorded mode, in every consumer (#28)" | `tests/test_vendor_sync.lua` (old :20-41) | **Adopt**, in the re-vendor commit: the kit's case has nearly the same name, and nothing de-duplicates it, so both would run | Replaces test-only code; total 251 − 1 + 1 = 251 |

## Class C: whole-module adoption

None new. `LibKa0s-Item-1.0` and `LibKa0s-Widgets-1.0` stay unbound by name, and the reason recorded
in `docs/ARCHITECTURE.md` (no items; Widgets is reached through the library) is unchanged, because no
file in `LibKa0s/` moved.

## Harness-migration check (the decline criterion)

`tests/wow_mock.lua` builds on the kit's mock (`local base = dofile("tests/_kit/mock_base.lua")`,
`local M = base()`). It does not replace `NewAddon`, AceEvent or LibStub wholesale. Every kit fix
reaches it directly, so no candidate needs a harness migration and none is declined.
