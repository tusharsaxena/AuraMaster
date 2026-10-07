# AuraMaster — proposed changes (review 2026-10-07)

**Standard resolved:** Ka0s WoW Addon Standard **v2.76.1 (2026-10-07)**. The index came from `raw.githubusercontent.com/.../master`, and the section files from the local `../WowAddonStandards` checkout at master-equivalent HEAD (the remote fetch of the section files stalled partway). Every change below is checked against it. Finding IDs refer to `01_FINDINGS.md`.

## HLD — themes

### T1. Keep the release gate passable (F-001)
`logCandidates` holds the only CCN above 15 in the tree. It is debug-only code, so the fix is purely about readability and the gate.
- **Chosen:** extract the per-target decision into a **named helper**, `targetText(dragged, t)`, which returns `"<why>"` or the target's parent-rect text. Also hoist the outcome suffix into a local. Each is a block a reader can name (`performance-§11`'s permitted shape: "a named helper for a nameable block").
- **Rejected:** moving the body into a `logCandidatesPart2`, or turning `and`/`or` into `if` ladders. Both are `anti-patterns` #52: they lower the number without simplifying anything.
- **Rejected:** adding a CCN gate on commits. A commit-time gate is an anti-pattern (`performance-§10`/`automated-tests-§3`), and the release gate already exists.
- **Trade-off:** one more local function in a file that is already 1126 lines. That is acceptable at about 10 lines net.

### T2. Peel the migration step bodies off `core/Database.lua` before the cap forces it (F-002)
- **Chosen:** move `MigrateV2`..`MigrateV12`, their private helpers and their frozen id tables (`HEALING_V1`, `V12_ROOT_IDS`, `V12_SNARE_IDS`, …) into a sibling file, `core/Database_Migrations.lua`. The **runner** (`SCHEMA_STEPS`, `climbLadder`, `NS.RunMigrations`), `EachProfile`, AceDB init and the registry helpers stay in `core/Database.lua`. `savedvariables-§1` requires the runner in `core/Database.lua`, and `layout-§1` explicitly allows peeling into sibling files in the same folder (its example is `settings/Schema.lua` → `settings/Schema_Core.lua`).
- **Load order:** `SCHEMA_STEPS` closures call `Database.MigrateVn` at call time, and both files use `NS.Database = NS.Database or {}`, so either order works. Put `core\Database_Migrations.lua` directly after `core\Database.lua` with a `Conventional:` note (`toc-file-§5`). `tests/test_loadorder.lua` requires every file to have a note.
- **Rejected:** moving the runner as well. That conflicts with `savedvariables-§1`.
- **Rejected:** `modules/Migrations.lua`. The ladder runs from `OnInitialize` before modules matter, and it belongs to the `core/` load pass (`savedvariables-§1` "load pass", `architecture-§5`).
- **Trade-off:** `docs/module-map.md`, `docs/ARCHITECTURE.md` (module map) and `docs/schema.md`, if it names the file, must change in the same commit. Step bodies that use the local `copy`/`merge` need `Database.DeepCopy` re-bound in the new file. `Database.Merge` is already published.

### T3. Keep the drag suite under the cap (F-004)
- **Chosen:** split `tests/test_anchors_drag.lua` along an existing seam into two suites, for example the drag lifecycle (start, stranded, cancel) and the drop/attach outcomes. The cases move verbatim, with **no renames**, so `docs/test-cases.md` changes only by suite grouping and per-suite counts, and the total stays at 2050. `tests/run.lua` declares suites by hand (`:82` `suites = {`, with `"test_anchors_drag",` at `:127`), so add the new suite name beside it. A declared suite missing from disk is a hard error in kit 37 (`tests/_kit/framework.lua:290`).
- **Rejected:** trimming comments or helpers to save lines. That loses the "why" record and fixes nothing.

### T4. CLI argument precedence (F-005)
- **Chosen:** resolve an exact **name** match before treating the argument as an id. If the argument is numeric, matches a container's name, **and** matches a different container's id, refuse with the existing ambiguity line pattern ("use its number from /am containers"), extended to name both. `#3` (a leading `#`) always means an id, which matches the `#id` form `/am containers` prints. Document the precedence in `docs/slash-dispatch.md` rows 12 and 14.
- **Rejected:** forbidding numeric names in the name row's `validate`. That retroactively invalidates stored names and adds a validation rule for a CLI parsing problem.
- **Locale:** one new key (the two-way ambiguity line) in `locales/enUS.lua`, via `L[...]`.

### T5. No case transforms on translated text (F-006)
- **Chosen:** use whole-phrase locale keys for the picker's lowercase forms (for example `L["buffs (lowercase, picker)"]`), or more simply drop `:lower()` and show the labels in their translated case. Prefer the second: it needs no new keys, and `localization` keeps grammar inside the translation.

### T6. Help and listing punctuation (F-007)
- **Chosen:** change the `debug` row's text to the standard's wording, "Toggle the debug console — `on`/`off` enable/disable logging", without backticks if the chat renderer shows them literally (match the other Ka0s addons). Change `docs/slash-dispatch.md:51` to describe the real `#id - unit - type - style` output. Keep the code's separators: changing a locale key's literal to `·` would be a bigger churn than the doc fix.

## Upstream change-set (separate; nothing here edits `libs/` or `tests/_kit/`)

| Finding | Owning repo / file | Fix | Version bump | Re-vendor |
|---|---|---|---|---|
| F-003 | LibKa0s, `testkit/framework.lua`, `renderTotals` (`:557`–`:570` in the vendored copy) | Count only **registered, non-skipped** cases in `**Total**`, and add a `**Skipped**` row naming the count when it is above 0, so the Total equals the badge's `<Y>`. Reword the header (`:576`–`:577`) to say the badge's X/Y equals Total, with skips listed separately (`testing-§5`). Add a kit self-test that renders a registry with one `Kit.skip` and asserts Total = registered minus skipped. | `Kit.VERSION` 37 → 38. LibKa0s minor release (CHANGELOG). | One commit per consumer: whole-folder copy of `testkit/` → `tests/_kit/`, regenerate `docs/test-cases.md` in the same commit (AuraMaster's Total goes 2050 → 2049 and the badge stays 2049/2049), and bump the `CLAUDE.md` provenance line. |

## LLD — change-set per finding

### C-01 (F-001) — `modules/Anchors_Snap.lua` `logCandidates`
Before (`:892`–`:913`, abridged):
```lua
for i, id in ipairs(ids) do
    local t = instances[id]
    local why = ineligibleWhy(dragged, t)
    if not why then
        local growH, growV = flowGrowth(t:Cfg())
        why = Snap.ParentRect(t, logRect, growH, growV) and rectText(logRect) or "no rect"
    end
    parts[i] = id .. " " .. why
end
debug("container %s: %s%s: own %s; targets %s", dragged.id, when, what and (" " .. what) or "", own,
    #parts > 0 and table.concat(parts, "; ") or "none")
```
After:
```lua
--- What the snap sees in live container `t` as a target of `dragged`: why it is none, or its rect
--- as a parent ("no rect" when neither its strip nor its block reads).
local function targetText(dragged, t)
    local why = ineligibleWhy(dragged, t)
    if why then return why end
    local growH, growV = flowGrowth(t:Cfg())
    return Snap.ParentRect(t, logRect, growH, growV) and rectText(logRect) or "no rect"
end
-- in logCandidates:
for i, id in ipairs(ids) do parts[i] = id .. " " .. targetText(dragged, instances[id]) end
local outcome = what and (" " .. what) or ""
local targets = #parts > 0 and table.concat(parts, "; ") or "none"
debug("container %s: %s%s: own %s; targets %s", dragged.id, when, outcome, own, targets)
```
- **Behavior:** the same output, byte for byte. Keep the existing docblock (the 2026-10-03 rationale).
- **Tests:** existing DD-21 cases in `tests/test_anchors_drag.lua` pin the line. Add none, so the count is unchanged.
- **Expected movement:** the next release regeneration should show 0 warnings, with `logCandidates` at or below 12 and `targetText` at about 5. This is a note for the release run, not something to run now.
- **Risk:** `logRect` is shared scratch, and `ParentRect` writes it before `rectText` reads it, the same order as before.

### C-02 (F-002) — `core/Database.lua` → `core/Database.lua` + `core/Database_Migrations.lua`
- Move lines from the `-- Schema v2` banner (`:296`) through the end of `MigrateV12` (`:1209`) into the new file, verbatim, comments included. Exclude `Database.EachProfile` and everything from `SCHEMA_STEPS` down, which stay.
- The new file's header is `local _, NS = ...` / `NS.Database = NS.Database or {}` / `local Database = NS.Database` / `local copy = Database.DeepCopy`, plus `normalizeKeys`, which `MigrateV2` calls (`:467`, `if type(p.containers) == "table" then normalizeKeys(p) end`). Publish it as `Database.NormalizeKeys` in `core/Database.lua`. It is a load-pass helper, so `architecture-§5`'s writer surface is unchanged.
- TOC: add `core\Database_Migrations.lua` after `core\Database.lua` with the note `# Conventional: the schema ladder's step bodies; called by core/Database.lua's runner at OnInitialize.`
- Docs in the same commit: `docs/module-map.md`, `docs/ARCHITECTURE.md` module map, and any `core/Database.lua:<line>` citation under `docs/` (check with `grep -rn 'core/Database.lua:' docs --include=*.md | grep -v -E 'docs/(audits|reviews|automated-tests)/'`).
- **Expected size:** about 480 lines remain in `core/Database.lua` and about 920 go to the new file, both outside the band.
- **Tests:** none added. `tests/test_loadorder.lua` will check the note, and `tests/test_migrations.lua` and `tests/test_database*.lua` must stay green unchanged. The pass count is unchanged.
- **Risk:** a moved local that is used on both sides of the split. `luacheck` flags any undefined global, and the suite catches a nil call.

### C-03 (F-004) — split `tests/test_anchors_drag.lua`
- Move whole `test(...)` blocks with their file-local helpers. Shared helpers go to the existing `tests/page_helpers.lua`-style helper module pattern, or are duplicated if they have fewer than two real consumers (`anti-patterns` #55).
- Regenerate `docs/test-cases.md` with `lua tests/run.lua --list > docs/test-cases.md` **in the same commit**. Suite headings change and Total stays 2050. The README badge does not move.

### C-04 (F-005) — `settings/Slash.lua` `findContainer`
```lua
local function findContainer(arg)
    arg = (arg or ""):match("^%s*(.-)%s*$")
    if arg == "" then return nil end
    local hashId = tonumber(arg:match("^#(%d+)$"))
    if hashId then return NS.Database.FindContainer(hashId) end
    local byName, ambiguous = nameMatch(arg)          -- the existing loop, extracted
    if ambiguous then return nil, ambiguous, arg end
    local byId = tonumber(arg) and NS.Database.FindContainer(tonumber(arg))
    if byName and byId and byName ~= byId then
        return nil, L["'%s' is both a container's name and another container's number — use #%s for the number."], arg
    end
    return byName or byId
end
```
- One new enUS key. Update `docs/slash-dispatch.md` rows 12 and 14.
- **Tests:** add to `tests/test_slash_verbs.lua` cases for: a name that is a number and no id collision (selects by name); a collision (refused, prints the new line, writes nothing); `#3` (by id); and a plain id with no name match (unchanged). That is 4 new cases, so the README badge goes from 2049/2049 to 2053/2053 and `docs/test-cases.md` is regenerated in the same commit. No other change here moves the count.

### C-05 (F-006) — `settings/OptionsSetup.lua:419`–`:420`
- Drop both `:lower()` calls. **Tests:** if a picker-label case pins lowercase text (check `tests/test_pages_*.lua` for `"buffs,"`), update its expected string, which is a spec change rather than a weakened assertion. No count change.

### C-06 (F-007) — `settings/Slash.lua:87`, `locales/enUS.lua:464`, `docs/slash-dispatch.md:51`
- Rekey the `debug` description to the standard's wording, and remove the old key from `enUS.lua` in the same change. `tests/test_locale.lua` guards unused and missing keys. Fix the docs row text. No count change.

## Standards conformance (per change)

| Change | Conforms | Rule that shaped it |
|---|---|---|
| C-01 | yes | `performance-§11` (named helper), `anti-patterns` #52 (rejected the meaningless extraction), `automated-tests-§3` (release gate; no commit gate added) |
| C-02 | yes | `layout-§1` (sibling peel, same folder), `savedvariables-§1` (runner stays in `core/Database.lua`), `toc-file-§5` (per-line note) |
| C-03 | yes | `layout-§1` (tests are capped), `testing-§5` (inventory regenerated in the same change), `anti-patterns` #55 (don't share a helper with one consumer) |
| C-04 | yes | `localization` (new string via `L[...]`), `testing-§5` (badge and inventory move with the count) |
| C-05 | yes | `localization` (no post-translation transforms) |
| C-06 | yes | `slash-commands` reserved-verb row wording |
| Upstream F-003 | yes | `testing-§5` (skip excluded from total), `library-stack-§5` / `testing-§1` (fix upstream, re-vendor whole folder) |
