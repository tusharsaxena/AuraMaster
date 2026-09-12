# 02 — Candidates

Sources: `git -C ../LibKa0s log --oneline v1.30.0..v1.31.0` (`5193ebe`, `853c62e`, `09099b1`,
`3162e53`, `f355fdc`, `2b312db`, `30db4ed`), the v1.31.0 block of `CHANGELOG.md`, the Options API
document `../LibKa0s/docs/api/Options/version-15.15.4.3-docs.md` (the only major whose file minors
moved) and `../LibKa0s/docs/api/testkit/version-17-docs.md`.

## Class A: reached the addon on the re-vendor alone

- **`OptionsWidgets.lua` minor 15.** The `path == nil` gate adds a bound-row branch to every maker and
  refresher. Every AuraMaster row carries a `path` (absolute or `container.`-relative), so each one
  is read and written through the descriptor exactly as before. The whole `test_optionssetup.lua`
  suite passes unmodified on the new file.
- **`OptionsCompose.lua` minor 4.** Path-keyed composer output is byte-for-byte unchanged (pinned
  upstream by `tests/fixture_compose_golden.lua`). The composers AuraMaster calls
  (`settings/Bars.lua:50,78,91,100`, `settings/Icons.lua:35,58` through `NS.Helpers`) pass no `bind`,
  so they take the unchanged path.
- **Kit revision 17.** AuraMaster reaches the new named `NewAddon` path (testkit doc
  `version-17-docs.md:294-301`): the addon object now carries AceEvent's message half,
  `UnregisterAllMessages`, a cancellable AceTimer and the object model, with the same three mixins
  `core/AuraMaster.lua:17` lists. The suite total is unchanged at 251, as upstream measured
  (`version-17-docs.md:282`).

## Class B: host change required

| # | What | Evidence | Files touched | Recommendation | Blast radius |
|---|---|---|---|---|---|
| B1 | Compose record-backed groups through `spec.bind` | CHANGELOG v1.31.0 "`OptionsCompose.lua` minor 4"; `docs/api/Options/version-15.15.4.3-docs.md` | would touch `settings/Bars.lua`, `settings/Icons.lua` | **Decline (never).** AuraMaster's per-container rows already reach registry records through `container.`-relative paths, which `NS.SetByPath` resolves against the selected container (`settings/Schema.lua`). No group is hand-typed for want of the arm, and no register row cites it. Binding would move rows out of the schema, and a bound row is rendered but never put in a schema, so it would lose `/am get|set`. | Replaces owned code; would drop schema rows |
| B2 | Retire a local `tests/wow_mock.lua` layer onto a kit 17 surface | testkit `version-17-docs.md:309-368` | `tests/wow_mock.lua` | **Nothing to retire.** The last Ace shims left in v1.30.0 (`02_CANDIDATES` of `docs/revendor/2026-09-12/`). What remains local is the aura engine recorder, `C_Secrets`, the settable `InCombatLockdown`, `C_Spell`, the frame picker's cursor and foci, `RAID_CLASS_COLORS`, the `_G` proxy, opt-in geometry, frame level and `SetDontSavePosition`. None of them has a kit counterpart in revision 17 (the kit's `InCombatLockdown` still answers false forever, `tests/_kit/mock_base.lua:972`). | n/a |

## Class C: whole-module adoption

None new. `LibKa0s-Item-1.0` and `LibKa0s-Widgets-1.0` stay unbound by name. The reason recorded in
`docs/ARCHITECTURE.md` (no items; Widgets is reached through the library) is settled, and neither
file moved in v1.31.0.
