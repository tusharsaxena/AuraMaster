# Aura Master Presets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship four container presets (Simple, Intermediate, Advanced, Healer) in Bars and Icons, placed by screen size, previewed on the real screen in test mode, with a first-run picker and a Presets tab on the Containers page.

**Architecture:** Presets are data (`defaults/Presets.lua`, `NS.PresetData`) that a pure builder turns into container overrides for a given screen size and style. One writer module (`modules/Presets.lua`, `NS.Presets`) applies them through the container registry writer (`NS.ContainerManager`) and the custom-category writer (`NS.Categories.CreateUserCategory`), and owns preview (snapshot in the profile, exact restore). Two UI surfaces call it: an Aura Master first-run window (`settings/PresetPicker.lua`) and a Presets tab (`settings/ContainersPresets.lua`).

**Tech Stack:** Lua 5.1 (WoW), Ace3 (AceDB), LibKa0s v1.98.0 (vendored), the headless harness `tests/run.lua` with the kit under `tests/_kit/`.

**Spec:** `docs/superpowers/specs/2026-11-14-auramaster-presets-design.md` (owner-approved 2026-11-14). Source data: `docs/superpowers/specs/2026-11-14-presets/advanced-source.md`. Mockup: https://claude.ai/artifact/9KAkkmWekBLZcxTAQ1kK8A.

## Global Constraints

- Branch `feat/2026-11-14-presets` (cut from `feat/2026-11-14-forever-port`). Never switch branches, push, merge, tag or bump the version from a task; the lead session pushes at milestones.
- Green gate before every commit: `lua tests/run.lua`, `KA0S_KIT_CLIENT=forever lua tests/run.lua`, `~/.claude/dev-copilot/bin/ka0s-bounded luacheck .` (0 warnings / 0 errors).
- Commit subjects open `<ID>: ` (for example `AM-PR02: …`); a review fix is `<ID>: Review fixes: …`. End every commit message with the two trailer lines `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` and `Claude-Session: https://claude.ai/code/session_01JV4dmMmczj1LVoM5UGRHRi`. Stage explicit paths only.
- `.lua`, `.md`, `.tsv` files are CRLF (`.gitattributes`; the kit's eol test is strict); `.sh` is LF.
- Ka0s WoW Addon Standard: every player-facing string in `locales/enUS.lua`; client checks only through `NS.Compat`; registry writes only through the registry writers (architecture-§5); every file ≤ 1500 lines; every function CCN ≤ 15; a new file is listed in `AuraMaster.toc` with a load-order note and pinned in `tests/test_loadorder.lua` when its position is load-bearing. A rule a task cannot meet: stop and report it, never deviate silently.
- No in-game smoke is marked passed by any task; smoke is the owner's.
- Presets carry no appearance media and no spell ids (spec §3). Every category key a preset names must exist on both kit profiles.

## Review Focus

1. **A `/reload` or crash mid-preview** must give the player their own containers back at the next login, with the same ids and attachments: AM-PR03 adds `test_presets_preview.lua` "stale snapshot restores at login".
2. **A profile switch mid-preview** must restore the snapshot into the profile it came from, never the new one: AM-PR03 "profile change restores the old profile first".
3. **Combat starting mid-preview** turns test mode off and must end the preview by restoring, never by keeping a half-applied preset: AM-PR03 "combat ends preview with restore".
4. **Add mode over containers with the same names** gets unique names, and each new stack member attaches to the new container above it, never to a player's container with the old id: AM-PR02 "add mode chains to new ids".
5. **Applying Advanced twice** must not create a second pair of special categories, and the spell list the player filled stays attached: AM-PR02 "advanced re-apply reuses categories".

---

### Task AM-PR01: Preset data and the builder

**Files:**
- Create: `defaults/Presets.lua` (data + pure builder, loads after `defaults/UserCategories.lua` and `defaults/Profile.lua`)
- Modify: `AuraMaster.toc`, `tests/test_loadorder.lua`, `tests/run.lua` (suite list)
- Test: `tests/test_presets_data.lua`

**Interfaces:**
- Produces `NS.PresetData` with:
  - `NAMES = { "empty", "simple", "intermediate", "advanced", "healer" }`; `LOOKS = { "bars", "icons" }`
  - `REF_H = 1080`; `Scale(parentH) -> number` (`parentH / 1080`, or `1` when `parentH` is nil, 0 or not a number)
  - `Count(name) -> number` (0, 3, 8, 20, 9)
  - `CUSTOM = { SPECIAL_PLAYER = { nameKey = "Special player buffs", auraType = "HELPFUL" }, SPECIAL_TARGET = { nameKey = "Special target debuffs", auraType = "HARMFUL" } }`
  - `Build(name, look, parentW, parentH) -> specs` where `specs` is an array in creation order of `{ overrides = <table for ContainerManager.Create>, attachTo = <index into specs> | nil, customKeys = { "SPECIAL_PLAYER", … } | nil }`. A head has `overrides.position = { point, relativePoint, x, y }` and `overrides.attach.mode = "screen"`; a member has `attachTo` and `overrides.attach = { mode = "container", point = "TOPLEFT", relativePoint = "BOTTOMLEFT", x = 0, y = -<gap> }` (the writer fills `attach.container`). Unknown name or look: `{}`.
- Data shape inside the file: `STACKS = { cornerRight = { anchor = "TOPRIGHT", x = -175, y = -6, width = 175 }, cornerLeft = { anchor = "TOPRIGHT", x = -395, y = -6, width = 215 }, middle = { anchor = "TOP", x = -240, y = -200, width = 480 }, left = { anchor = "TOP", x = -520, y = -330, width = 240 }, right = { anchor = "TOP", x = 280, y = -330, width = 240 }, far = { anchor = "TOP", x = 570, y = -330, width = 220 } }` (reference units; x of a TOP anchor is the column's LEFT edge from the center line, so the head's `point = "TOPLEFT"`, `relativePoint = "TOP"`; TOPRIGHT stacks use `point = "TOPLEFT"`, `relativePoint = "TOPRIGHT"` with the negative x). One `CONTAINERS` table keyed by role (`pbuffs`, `wpn`, `pdebuffs`, `txtOff`, …) holding name, unit, auraType, style, enabled, filter, layout, behavior, transcribed from `advanced-source.md` with the spec §3 changes (names, `growV = "down"`, no attach/position, empty white/blacklists, custom keys renamed to `SPECIAL_PLAYER`/`SPECIAL_TARGET`), plus Healer's four new roles and Intermediate's merged `tcd` (spec §3, §3.1). One `TIERS` table: name → list of `{ stack, role }` in creation order (spec §3 table; Advanced's stacks per the mockup: cornerRight pbuffs, wpn; cornerLeft pdebuffs; middle txtOff, txtDef, txtRaid; left pshort, pcd, pspec; right tdeb, tbuff, tcc, tcdp, tcdn, tspec, tsteal; far ticoD, ticoB, fdeb, fbuff).
- Icons: `Build(…, "icons", …)` turns each `style = "bars"` role into `style = "icons"` with `layout.axis = "horizontal"`, `growH = "right"` (stacks left of center: `"left"`… use `"right"` for every stack but cornerRight/cornerLeft, which use `"left"`); text and icon roles unchanged. Bar `bars.width` (bars) or the icon row is set from the stack width × k.

- [ ] **Step 1: Write the failing tests** in `tests/test_presets_data.lua`:
  - `presets: counts` → `Count("empty")==0, simple 3, intermediate 8, advanced 20, healer 9`, and `#Build(n,"bars",1920,1080)==Count(n)` for each.
  - `presets: advanced matches its source` → for each of the 20 roles, `filter` (except `whitelist`, `blacklist`, renamed custom keys), `layout` (except `growV`) and `behavior` equal the values in `advanced-source.md` (transcribe the expected values into the test as a table; `enabled` false only for Target stealable).
  - `presets: every category key exists on this client` → for every spec, every key in `overrides.filter.categories` is `SPECIAL_PLAYER`, `SPECIAL_TARGET`, or found by `NS.Categories.Find("HELPFUL"|"HARMFUL", key)`; runs under both profiles.
  - `presets: placement at 768/1080/1440 × 16:9, 16:10, 21:9` → every head's left edge ≥ 0 and right edge ≤ width, every head's top ≥ −0.6 × height, the six stacks' column spans do not overlap, cornerRight's right edge equals the parent's right edge within 1 unit.
  - `presets: members chain` → every non-head spec has `attachTo` equal to the index of the previous spec in the same stack; no spec has `attach.mode == "frame"` or a non-empty `attach.frame`.
  - `presets: scale fallback` → `Scale(nil)==1`, `Scale(0)==1`, `Scale(1080)==1`, `Scale(768)` ≈ 0.711.
  - `presets: icons variant` → in `Build("advanced","icons",…)` every role that is bars in the bars build is icons with `layout.axis=="horizontal"`; the three text roles and `ticoD`/`ticoB` are identical across the two builds.
  - `presets: names follow the data` → every spec whose name contains "(mine)" has `filter.castBy=="mine"`.
- [ ] **Step 2:** Run `lua tests/run.lua`; expect the new cases to fail (`NS.PresetData` nil).
- [ ] **Step 3:** Implement `defaults/Presets.lua` per the Interfaces block; add it to the TOC after `defaults\UserCategories.lua` with a load-order note, pin the pair in `tests/test_loadorder.lua`, add the suite to `tests/run.lua`. Names go through `L[...]`.
- [ ] **Step 4:** Gate green (both profiles, luacheck).
- [ ] **Step 5:** Commit `AM-PR01: Preset data and the placement builder`.

### Task AM-PR02: Applying a preset (the writer)

**Files:**
- Create: `modules/Presets.lua`
- Modify: `AuraMaster.toc`, `tests/test_loadorder.lua`, `tests/run.lua`, `locales/enUS.lua`
- Test: `tests/test_presets_apply.lua`

**Interfaces:**
- Consumes: `NS.PresetData.Build`, `NS.ContainerManager.Create(overrides) -> id | nil, msg, gray`, `NS.ContainerManager.Delete(id)`, `NS.Database.GetContainers()`, `NS.Categories.CreateUserCategory(name, auraType)`, `UIParent:GetWidth()/GetHeight()`.
- Produces `NS.Presets` with:
  - `Apply(name, look, mode) -> true | nil, message` — `mode` is `"replace"` or `"add"`; refuses in combat (`InCombatLockdown()`) with the locale line used by `ContainerManager.Create`; `"empty"` + `"replace"` deletes every container; `"empty"` + `"add"` is refused.
  - `ResolveCustom(customKey) -> userKey` — finds a custom category with the localized name and aura type, else creates it (spec §3: reuse).
  - Replace deletes every existing container via `ContainerManager.Delete`, then creates the specs in order; each member's `overrides.attach.container` is the id the writer got for `specs[attachTo]`. Custom placeholder keys in `filter.categories` are rewritten to the resolved user keys before `Create`. Add mode lets `ContainerManager.UniqueName` suffix names.
  - Debug lines through `NS.Debug("Presets", …)`.
- [ ] **Step 1: Failing tests** (`tests/test_presets_apply.lua`, each in a `tests/fresh_env.lua` environment): `apply: replace simple` (3 containers, names, the corner chain attaches wpn to pbuffs' new id); `apply: replace empty` (0 containers); `apply: add empty refused`; `apply: add mode chains to new ids` (seed a container named "Player buffs (all)", Add simple → names get " (2)", wpn's `attach.container` is the new pbuffs id); `apply: advanced creates two categories`; `apply: advanced re-apply reuses categories` (fill SPECIAL_PLAYER's list, apply again → still two user categories, the list kept, containers point at the same keys); `apply: refused in combat` (mock `InCombatLockdown` true → nil, message, nothing changed); `apply: only the registry writers write` (spy `p.containers` writes outside `ContainerManager`, expect none).
- [ ] **Step 2:** Run; expect failures.
- [ ] **Step 3:** Implement `modules/Presets.lua`; TOC after `modules/ContainerManager.lua` with a note; pin the order; suite listed.
- [ ] **Step 4:** Gate green.
- [ ] **Step 5:** Commit `AM-PR02: Apply a preset through the registry writers`.

### Task AM-PR03: Preview on the real screen

**Files:**
- Modify: `modules/Presets.lua`, `modules/ContainerManager.lua` (a restore writer), `core/AuraMaster.lua` (profile callbacks and login restore), `defaults/Profile.lua` (`presets` defaults)
- Test: `tests/test_presets_preview.lua`

**Interfaces:**
- Produces in `NS.Presets`: `BeginPreview(name, look) -> true | nil, msg` (snapshot once into `profile.presets.previewSnapshot`, then `Apply(name, look, "replace")`, then `NS.Preview.SetTestMode(true, "preset preview")`; a second call swaps the preset and keeps the first snapshot), `EndPreview(keep, mode) -> true | nil, msg` (keep + `"replace"`: drop the snapshot; keep + `"add"`: restore then `Apply(name, look, "add")`; not keep: restore; every branch turns test mode off and clears the snapshot), `IsPreviewing() -> boolean`, `RestoreStaleSnapshot()` (called before containers are built at login and on every profile event: a snapshot present means a preview was interrupted).
- Produces `NS.ContainerManager.RestoreSnapshot(snap)` — replaces `containers`, `containerOrder`, `nextContainerId` with deep copies from `snap` (ids kept), `userCategories`/`userCategoryOrder`/`categorySpells` likewise (then `NS.Categories.SyncUserCategories(profile)`), then `Announce(true)`. The snapshot shape: `{ containers, containerOrder, nextContainerId, userCategories, userCategoryOrder, categorySpells }`.
- `defaults/Profile.lua`: `presets = { pickerSeen = false }` (no `previewSnapshot` default).
- Combat: `PLAYER_REGEN_DISABLED` already turns test mode off (`core/AuraMaster.lua:166`); in the same branch, when `NS.Presets.IsPreviewing()`, call `EndPreview(false)` deferred to `PLAYER_REGEN_ENABLED` if the restore itself would be refused, and print one line.
- [ ] **Step 1: Failing tests:** `preview: snapshot and restore exact` (ids, attach targets, categories, categorySpells equal after Begin+End(false)); `preview: swap keeps the first snapshot`; `preview: keep replace drops snapshot and test mode off`; `preview: keep add restores then adds`; `preview: stale snapshot restores at login` (seed a profile with `presets.previewSnapshot` → fresh env → own containers back, snapshot cleared); `preview: profile change restores the old profile first`; `preview: combat ends preview with restore`; `preview: categories the preview created are removed`.
- [ ] **Step 2–4:** Run (fail), implement, gate green.
- [ ] **Step 5:** Commit `AM-PR03: Preview a preset on the real screen with an exact restore`.

### Task AM-PR04: New profiles start from Simple; schema v19

**Files:**
- Modify: `core/Database.lua` (seeding and a `{ to = 19 }` step), `defaults/Profile.lua` (retire `NS.STARTER_CONTAINERS`), every test that assumes the four starters (`grep -rln "STARTER_CONTAINERS\|Player cooldowns\"\|Target debuffs (mine)\"" tests`)
- Test: `tests/test_presets_seed.lua`, plus the updated suites

**Interfaces:**
- Seeding: an unseeded profile with no containers gets `NS.PresetData.Build("simple", "bars", W, H)` created in order (heads and member attaches resolved by the same code path as `Presets.Apply`, called as a writer helper, not through `ContainerManager.Create`'s combat guard, since seeding runs at load). `seeded` set as today.
- v19 step: for each profile with `p.seeded == true`, set `p.presets = p.presets or {}` and `p.presets.pickerSeen = true`. Keyed on `seeded` (spec §9).
- [ ] **Step 1: Failing tests:** `seed: new profile gets simple` (3 containers, names); `seed: migrated profile marked seen` (a v18 profile with `seeded=true` → `presets.pickerSeen==true`, its containers unchanged); `seed: fresh install not marked seen` (no stored data → after load `pickerSeen==false`).
- [ ] **Step 2:** Run (fail). Then update every existing test that counted or named the four starters to the Simple set; record each changed expectation in the commit body.
- [ ] **Step 3:** Implement; gate green on both profiles.
- [ ] **Step 4:** Commit `AM-PR04: New profiles start from the Simple preset; schema v19 marks existing profiles seen`.

### Task AM-PR05: The first-run picker and `/am preset`

**Files:**
- Create: `settings/PresetPicker.lua`
- Modify: `core/AuraMaster.lua` (show order: preset picker before the skin picker), `core/SkinSetup.lua` (only if a hook is needed to hold the skin picker while the preset picker is due), `settings/Slash.lua` (verb `preset`), `locales/enUS.lua`, `AuraMaster.toc`, `tests/test_loadorder.lua`, `tests/run.lua`, `docs/known-limitations.md` (other addons' skin pickers, spec §7)
- Test: `tests/test_presetpicker.lua`, `tests/test_slash_verbs.lua`

**Interfaces:**
- Produces: `NS.PresetPickerDue() -> boolean` (profile `presets.pickerSeen` false and the addon stands up), `NS.MaybeShowPresetPicker()` (shows when due; in combat holds for `PLAYER_REGEN_ENABLED`), `NS.ShowPresetPicker()` (on demand, ignores the latch), `NS.HidePresetPicker()` (ends any preview with restore, no latch write).
- Window: DIALOG strata, toplevel, clamped, movable, anchored `LEFT` of `UIParent` at x = 24, painted through `NS.SkinPaintAce`/the skin seams; controls from LibKa0s Options (dropdown, two-button switch, primary and secondary buttons) and copy from spec §7. A pick calls `NS.Presets.BeginPreview`; Empty calls `EndPreview(false)` and shows no test mode; Apply calls `EndPreview(true, "replace")` (Empty: `Apply("empty","replace")`); Not now, close and Escape call `EndPreview(false)`. Every close sets `presets.pickerSeen = true` and then calls `NS.MaybeShowSkinPicker()`.
- Login: `addon:OnEnterWorld` shows the preset picker (no delay) when due and arms the skin picker only after it closes; a profile event calls `NS.HidePresetPicker()` first, then `NS.MaybeShowPresetPicker()`.
- Slash: `/am preset` → `NS.ShowPresetPicker()`; `/am preset <name> [icons] [add]` → `NS.Presets.Apply` behind the same Replace confirm the tab uses (a StaticPopup), listed in help.
- [ ] **Step 1: Failing tests:** `picker: due on new profile only`; `picker: shows before skin picker` (spy order); `picker: pick previews, close restores, latch set`; `picker: apply keeps`; `picker: empty applies no containers`; `picker: refused in combat holds`; slash `preset` opens; `preset simple icons add` applies; unknown name prints the usage line.
- [ ] **Step 2–4:** Run (fail), implement, gate green.
- [ ] **Step 5:** Commit `AM-PR05: First-run preset picker and /am preset`.

### Task AM-PR06: The Presets tab

**Files:**
- Create: `settings/ContainersPresets.lua` (render function and rows)
- Modify: `settings/Containers.lua` (second tab in the General section's `tabs`), `settings/OptionsSetup.lua` (only to end a preview when the panel hides or the tab changes), `locales/enUS.lua`, `AuraMaster.toc`, `tests/run.lua`
- Test: `tests/test_pages_presets.lua`

**Interfaces:**
- `NS.RegisterContainerSection(PAGE, L["General"], { tabs = { { key = GROUP, … }, { key = "Presets", label = L["Presets"], render = NS.RenderPresetsTab } } })`.
- `NS.RenderPresetsTab(container, ctx)`: the copy and controls of spec §8 (no Empty); picking a preset or style calls `NS.Presets.BeginPreview`; Apply preset… shows a confirm naming the count it replaces (Replace) or adds (Add), then `EndPreview(true, mode)`; Stop preview calls `EndPreview(false)`. Leaving the tab, closing the panel (`OnHide`) or a profile change calls `EndPreview(false)` when previewing.
- [ ] **Step 1: Failing tests:** `presets tab: listed after General`; `presets tab: pick previews`; `presets tab: apply replace confirms and keeps`; `presets tab: add keeps player containers`; `presets tab: leaving the tab restores`; `presets tab: panel hide restores`; `presets tab: no empty option`.
- [ ] **Step 2–4:** Run (fail), implement, gate green.
- [ ] **Step 5:** Commit `AM-PR06: Presets tab on the Containers page`.

### Task AM-PR07: Docs, smoke and inventory

**Files:** `docs/ARCHITECTURE.md` (module map, message/state notes, the `presets` profile key), `docs/schema.md` (v19, `presets`), `docs/settings-panel.md` (Presets tab), `docs/smoke-tests.md` (a PRESETS theme: each preset in each style on Retail and Forever, picker on a new profile, Apply, Not now, `/reload` mid-preview, combat mid-preview, other Ka0s skin picker queue), `docs/known-limitations.md`, `README.md` (feature line, slash row, test badge), `docs/test-cases.md` (regenerate with `lua tests/run.lua --list`), `CLAUDE.md` only if a command changes.
- [ ] Update each, regenerate the inventory, gate green, commit `AM-PR07: Docs, smoke checks and inventory for presets`.

### Task AM-PR08: Whole-branch review fixes and the automated-test record

- [ ] A whole-branch review against the spec, plan and standard; fix each real finding in commits `AM-PR08: Review fixes: …`.
- [ ] Run the automated-test battery for both kit profiles per the AUTOMATED_TESTS.md playbook (`docs/automated-tests/<YYYYMMDD-HHMMSS>/`, `RESULTS.md`, `ANALYSIS.md`), append the checkpoint row and the RESUME log line, commit `AM-PR08: Automated-test record for presets`.
