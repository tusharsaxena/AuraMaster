# Common tasks

Recipes for the changes this addon actually gets. Each ends with the green gate: `lua tests/run.lua`
and `luacheck .` at 0/0 (testing-§4), and test-first — the failing case before the code.

## Add a setting to a container page

Example: a bar option.

1. **The default.** Add the key to `NS.CONTAINER_TEMPLATE` in `defaults/Profile.lua` (under `bars`).
   This is the only place the default is written. Existing containers get it through
   `Database.PrepareProfile`'s backfill; no migration step is needed for an added key.
2. **The row.** In `settings/Bars.lua`, add it to an `NS.RegisterSchemaRows` list with `path`
   (`"container.bars.<key>"`), `page = "bars"`, a `group` (the tab) and optionally a `subgroup`,
   `type`, and `label`/`desc` wrapped in `L[…]`. Do not write a `default`: `RegisterSchemaRows` stamps
   it from the template. A font, border, bar or color control comes from the composer
   (`H.FontGroup`, `H.BorderGroup`, `H.BarGroup`, `H.ColorPair`) — extra rows go *after* the block,
   and a color row gets its class-color companion unless it is a palette swatch (options-ui-§16/§17).
3. **The strings.** Add the label and desc to `locales/enUS.lua` as `L["…"] = "…"`, in US English.
4. **The behavior.** Read the key in `modules/Style_Bars.lua` (`Bars.Apply` for the look,
   `Bars.Bind` for an engine binding). Nothing else: the write seam already sends `CONFIG_CHANGED`,
   which re-applies that container and restyles its buttons once auras are readable.
5. **Structural?** If the row changes which rows other pages offer, give it
   `onChange = function() NS.RequestPanelRefresh() end`. If it changes the engine's shape, add it to
   the structure key in `Container:Apply` (`modules/Container.lua:311`).
6. `NS.ValidateSchema` fails the load if the path does not resolve against the template. Update the
   row lists in `docs/settings-panel.md` and the defaults in `docs/schema.md`.

## Add an addon-wide setting

1. Add the key and default to `NS.defaults.profile` in `defaults/Profile.lua`.
2. Add the row to `settings/General.lua` with an absolute `path` and `page = "general"`. Put it on the
   **Display** tab, or on a new tab after it; never inside **Master controls**, whose rows are the
   composer's canonical set (options-ui-§15).
3. Give it an `onChange` if its effect is not a container re-apply — a visibility row calls
   `NS.ContainerManager.ApplyVisibility()`, which is legal in combat.
4. Strings in `locales/enUS.lua`; rows in `docs/settings-panel.md`; key in `docs/schema.md`.

## Add a filter category

1. Add an entry to `NS.Categories.HELPFUL` or `.HARMFUL` in `defaults/Categories.lua` with a `key`
   unique across **both** lists (a container's category states are one map), a `kind` — `token`
   (with `token`), `flag` (with `field` and `value`), `dispel` (with `types`) or `spells` (with
   `spells = spells({ CLASS = { ids } })`) — and `label`/`desc`.
2. That is the whole wiring: `NeutralStates()` backfills the key as neutral into every stored
   container, `settings/Filters.lua` generates its row, and `modules/FilterCompiler.lua` applies it by
   kind. A new `kind` needs a branch in `applyCategory` and a subgroup in `SUBGROUP_BY_KIND`.
3. A `spells` category on a debuff list will not work on friendly units — the engine's identity gate
   (`docs/midnight-quirks.md`). Keep spell lists on buffs.
4. Add the label and desc to `locales/enUS.lua`, and a compiler case to `tests/test_filtercompiler.lua`.

## Add a slash verb

1. Add a positional triple `{ "verb", L["Description"], function(rest) runVerb(rest) end }` to
   `NS.COMMANDS` in `settings/Slash.lua`, in the position you want it listed. Never named fields.
2. Write `runVerb` as a local host function below (declare it in the forward `local` line). Print with
   the file's `print` (`NS.Print`, the cyan `[AM]` tag). A verb that changes a setting goes through
   `NS.SetByPath`, never a direct write.
3. The reserved verbs — `help get set list reset resetall config version debug perf` — keep their
   meaning (slash-commands-§2).
4. The help block and the landing page's command list are generated from `NS.COMMANDS`; nothing else
   to register. Add the description to `locales/enUS.lua`, the row to the Slash Commands table in
   `docs/ARCHITECTURE.md`, and the verb to `docs/slash-dispatch.md`.

## Add a locale string

1. Route the string through `NS.L` at the call site: `local L = NS.L` then `L["Your text"]`. The key
   *is* the English text (localization-§2).
2. Add `L["Your text"] = "Your text"` to `locales/enUS.lua`.
3. US spelling (localization-§5): `color`, `gray`, `canceled`. A spelling fix changes the key — update
   every `locales/*.lua` and every call site in the same change.
4. A label routed by value (a `core/Constants.lua` `*_LABELS` table, a category label) still needs its
   `enUS` key; `NS.Choices` and the category rows look them up with `L[…]`.

## Add a container field that changes shape (a migration)

An **added** key needs nothing but the template (above). A **renamed, removed or retyped** key needs a
step, in the same change:

1. Change the template in `defaults/Profile.lua`.
2. Append `{ to = 2, apply = function(db) … end }` to `SCHEMA_STEPS` in `core/Database.lua:208`. The
   ladder is account-wide (`global.schemaVersion`), but containers live in **every** profile: walk
   `db.sv.profiles` (AceDB's raw store, guarded — the no-AceDB fallback has no `sv`) and transform
   `profile.containers[*]` in each, not only `db.profile`. Test the stored value with `== nil`, never
   `or` (savedvariables-§5).
3. `RunMigrations` calls the step, stamps `schemaVersion = 2`, logs one `[Migrate]` line, and then
   `PrepareProfile` backfills whatever the step did not set.
4. A case in `tests/test_database.lua` with a v1-shaped profile (and a second, inactive profile), and
   the migration in `docs/schema.md`.

## Add a Compat shim

Put the wrapper in `core/Compat.lua` as `function Compat.Name(…)`, degrading to a plain answer when
the client lacks the API, and call `NS.Compat.Name` from the feature module — never the global. Add a
row to `docs/compat-layer.md` and update the shim count in `docs/ARCHITECTURE.md`'s Documentation map.

## Add a perf bucket

Declare it in `core/PerfSetup.lua`'s `buckets`, with `within` when it runs inside another; bracket
the entry point with `local t0 = Perf.on and debugprofilestop()` … `if t0 then Perf.Note("key",
debugprofilestop() - t0[, "parent"]) end` (performance-§2), using a load-time `local Perf = NS.Perf`;
add a case proving a real bracket reaches it; add the row to `docs/performance.md`.

## Add a settings page

1. Add the page key to `VALID_PAGES` in `settings/Schema.lua`.
2. Create `settings/<Page>.lua` registering its rows and calling `NS.RegisterContainerPage(key,
   L["Title"], "AuraMaster<Page>Panel", spec)` (or `NS.RegisterOptionsPage` for an addon-wide page).
3. Add it to `AuraMaster.toc` after `settings/OptionsSetup.lua`, in the order the subcategory should
   appear.
4. Every row needs a `group` (options-ui-§13). Add the page to the table in `docs/settings-panel.md`.
