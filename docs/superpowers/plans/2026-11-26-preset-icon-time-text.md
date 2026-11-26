# Preset icon rows without time text: plan of record

**Goal:** the owner's 2026-11-26 request (spec
`docs/superpowers/specs/2026-11-26-preset-icon-time-text-design.md`): every icon container a preset
creates ships with its time text hidden, and schema v25 hides it on the ones an older preset made where
the player has not changed it.

**Branch:** `feat/2026-11-26-preset-icon-time-text`. No push, merge, tag or version bump without the
owner's go-ahead.

**Gate before every commit:** `ka0s-bounded lua tests/run.lua`, `KA0S_KIT_CLIENT=forever ka0s-bounded
lua tests/run.lua`, `ka0s-bounded luacheck .` (0/0), `python3 -m pytest -q tools/spell-research`; files
under 1500 lines; CCN 15 or less for every new or changed function.

**How to resume:** an item is done when a commit whose subject opens with `<ID>: ` exists on the branch
(`git log --oneline master..HEAD`).

| ID | Item |
| --- | --- |
| PIT-PLAN | This plan and the spec |
| PIT-1 | Tests first (`tests/test_preset_icon_time.lua`), then the builder's `icons.time.show = false` (`defaults/Presets.lua`, `sizeTo`) and schema v25 (`Database.HidePresetIconTime` in `core/Database_PresetRestack.lua`, the step in `core/Database.lua`) |
| PIT-2 | Docs: README, `docs/schema.md`, `docs/ARCHITECTURE.md`, `docs/smoke-tests.md` (checks written unrun), `docs/test-cases.md` (the inventory and totals) |
| PIT-REV | Fixes from the self-review of `git diff master..HEAD` (no commit when it finds nothing) |
