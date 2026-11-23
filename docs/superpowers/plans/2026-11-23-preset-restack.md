# Preset restack, role colors, fixed bar width: plan of record

**Goal:** the owner's 2026-11-23 preset feedback (spec
`docs/superpowers/specs/2026-11-23-preset-restack-design.md`): restack and renumber the player and target
towers, the new role colors, bars 240 wide on every screen, and schema v23 carrying the change into
existing profiles where the player has not edited it.

**Branch:** `feat/2026-11-23-auramaster-preset-restack`. No push, merge, tag or version bump without the
owner's go-ahead.

**Gate before every commit:** `ka0s-bounded lua tests/run.lua`, `KA0S_KIT_CLIENT=forever ka0s-bounded
lua tests/run.lua`, `ka0s-bounded luacheck .` (0/0); files under 1500 lines; CCN 15 or less.

**How to resume:** an item is done when a commit whose subject opens with `<ID>: ` exists on the branch
(`git log --oneline master..HEAD`).

| ID | Item |
| --- | --- |
| APR-00 | This plan and the spec |
| APR-01 | Presets data: the new tier orders (Advanced, Intermediate) and colors; tests first |
| APR-02 | Fixed column widths (240 bars) and the exact cluster edge; tests first |
| APR-03 | Schema v23, `Database.RestackPresets`, in `core/Database_PresetRestack.lua`; tests first |
| APR-04 | Docs: ARCHITECTURE, README, schema, known limitations; smoke checks |
| APR-05 | The SavedVariables replay; the spec's Appendix A |
| APR-REV | Fixes from the self-review of `git diff master..HEAD` |
