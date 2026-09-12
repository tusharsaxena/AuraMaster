# 02 — Candidates: LibKa0s v1.33.0

Sources: `git -C ../LibKa0s log --oneline v1.32.0..v1.33.0`, the v1.33.0 block of
`../LibKa0s/CHANGELOG.md`, `../LibKa0s/docs/api/Options/version-17.15.4.3-docs.md`,
`../LibKa0s/docs/api/Slash/version-9-docs.md` and `../LibKa0s/docs/api/testkit/version-18-docs.md`.

## Class A: reached the addon on the re-vendor alone

- **The font preload (Options minor 17).** **Live here.** The Options descriptor supplies `getLSM` (`settings/OptionsSetup.lua:59`) and two pages hold `LSM30_Font` rows through `H.FontGroup` (`settings/Icons.lua:58`, `settings/Bars.lua:100`). The first show of any AuraMaster settings page outside combat now loads every LSM face before a font dropdown can open, so its rows no longer draw blank on the first open. Nothing in the addon changes to get this.
- **The `count` docstrings (Options 17, Slash 9).** Comments only; nothing to adopt.
- **Kit revision 18, the `OnProfileCopied` key.** **Reached.** AuraMaster's harness uses the kit's AceDB. `tests/test_bulklog.lua:146` copies through `db:CopyProfile("Raid")`; its pattern `'.-' → 'Default'` (`:148`) matched `'Default'` at revision 17 and matches `'Raid'` at 18, so the outcome does not move. `tests/test_containermanager.lua:446` copies too and asserts no key.
- **No surface change.** No member is added to either instance, so no surface-parity exclusion moves.

## Class B: host change required

None. v1.33.0 adds no descriptor field and no member to adopt.

## Class C: whole-module adoption

None. No module is new at this tag.

## Noted, not taken

- `tests/test_bulklog.lua:148` could now assert the full line `[Set] copied profile 'Raid' → 'Default'`. Not taken: this run corrects comments only, and the tightening is the owner's call.
