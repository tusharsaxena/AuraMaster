# 02 — Candidates: LibKa0s v1.34.0

Sources: `git -C ../LibKa0s log --oneline v1.33.0..v1.34.0`, the v1.34.0 block of
`../LibKa0s/CHANGELOG.md`, `../LibKa0s/docs/api/Slash/version-10-docs.md`,
`../LibKa0s/docs/api/Options/version-18.15.5.3-docs.md` and
`../LibKa0s/docs/api/testkit/version-19-docs.md`.

## Class A: reached the addon on the re-vendor alone

- **Whole free-text values (Slash minor 10).** **Live here.** `settings/Slash.lua` supplies no
  `parse` of its own (the value parser is the library's, `settings/Slash.lua:8`), so every `string`
  row now takes the whole value after the path: `container.name`, `container.attach.frame`, and
  every LSM font, texture or border name with a space. The reported bug, `/am set container.name My
  Raid Buffs` storing `"My"`, is fixed by the copy. No suite pinned the truncation or called it a
  library bug; the only multi-word `set` in the suites is a `color` row
  (`tests/test_slash_verbs.lua:203`), which parses as before.
- **The Reset-all tooltip's second wording (Options 18, OptionsCompose 5).** **Reached.** The Options
  descriptor supplies `resetProfile` (`settings/OptionsSetup.lua:48`), so without any host change
  the General page's *Reset all settings* tooltip moves from "Restore every setting in this addon to
  its default." to "Reset the current profile to its defaults. Your other profiles are not
  affected." No suite asserted the old text.
- **Kit revision 19, `OnProfileReset` with no key.** **Reached, nothing moves.** The addon's handler
  ignores its arguments (`core/Database.lua:240`, `function() NS.OnProfileReset() end`), and no suite
  asserts a reset key: `tests/test_bus.lua:92` and `tests/test_lifecycle.lua:191` name the callback in
  comments only.
- **No surface change.** No member is added to either instance, so no surface-parity exclusion moves.

## Class B: host change required

- **`profilesPage = true` on the Options descriptor.** AuraMaster ships an AceDBOptions Profiles
  sub-page (`settings/Profiles.lua`) and supplies `resetProfile`, which is exactly the shape the field
  serves. With it the tooltip names the equivalence options-ui-§12 says it **SHOULD**: "Reset the
  current profile to its defaults — the same thing Profiles → Reset Profile does. Your other profiles
  are not affected." One line in `settings/OptionsSetup.lua`. **Recommended: adopt.**

## Class C: whole-module adoption

None. No module is new at this tag.
