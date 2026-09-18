# Schema — what is persisted

Two SavedVariables globals (`AuraMasterDB`, `AuraMasterPerfDB`, `AuraMaster.toc:7`) and nothing else
(savedvariables-§4). Every default is hardcoded in exactly one file, `defaults/Profile.lua`
(savedvariables-§2); the settings schema reads its defaults from there rather than repeating them.

## `AuraMasterDB` — the AceDB database

Created by `NS.InitDB` (`core/Database.lua:233`) as `AceDB:New("AuraMasterDB", NS.defaults, true)`:
the third argument puts every character on the shared `Default` profile until the player chooses
otherwise (`docs/profiles.md`).

### `profile` — per profile

| Key | Type | Default | Meaning |
|---|---|---|---|
| `enabled` | bool | `true` | Enable Aura Master — gates every container |
| `visibility` | string | `"always"` | General visibility: `always` / `inCombat` / `outOfCombat` / `never` |
| `scale` | number | `1.0` | Master scale, multiplied into each container's own |
| `alpha` | number | `1.0` | Master alpha, multiplied into each container's own |
| `locked` | bool | `true` | Lock frame; unlocked shows the drag handles and the preview |
| `hideBlizzardBuffs` | bool | `false` | Reparent `BuffFrame` away (out of combat) |
| `hideBlizzardDebuffs` | bool | `false` | Reparent `DebuffFrame` away (out of combat) |
| `categorySpells` | map | `{}` | `[categoryKey] = { [spellId] = true (added) \| false (removed) }`, layered over `defaults/Categories.lua`'s starter lists and shared by every container (schema v2) and edited on General → Spell Categories. Written whole through the `categorySpells` carve-out |
| `dispelColors` | map | the palette below | One color per dispel type (`Magic`, `Curse`, `Disease`, `Poison`, `Bleed`, `None`) for a bar colored by dispel type (an icon's dispel border keeps Blizzard's own colors); shared by every container (schema v2) and edited on General → Dispel Colors |
| `enchantSlots` | map | `{ mainHand = true, offHand = true, ranged = true }` | Which weapon slots the `weaponEnchants` category draws (schema v3, B3); shared by every container, like `categorySpells`. A container showing enchants with every slot off falls back to all three |
| `containers` | map | `{}` | `[id] = container` (the template below); written at runtime only by `modules/ContainerManager.lua`, and on load by `Database.PrepareProfile` (repair and first-run seeding) |
| `containerOrder` | array | `{}` | Container ids in display order |
| `nextContainerId` | number | `1` | The next id to hand out |
| `seeded` | bool | `false` | The starter containers have been created once; deleting them all does not bring them back |

### `global` — account-wide

| Key | Type | Default | Meaning |
|---|---|---|---|
| `schemaVersion` | number | `1` | The migration stamp (savedvariables-§1). Defaults to 1, not the current version: AceDB fills an absent key before `RunMigrations` reads it |
| `minimap` | table | `{ hide = false }` | **LibDBIcon-1.0's own table**, handed straight to `:Register` (launcher-§3). `hide` is the Minimap button row's storage; `minimapPos` is written by LibDBIcon when the player drags the button. Global, not profile, on purpose: a profile switch must not move the player's buttons. Surviving a reset is a separate guarantee and a property of the setting rather than of the store (launcher-§3): neither `Reset all settings` nor General's **Defaults** button may un-hide a button the player hid, and the second of those would have, so the options descriptor vetoes the row. Nothing seeds it but this declaration (architecture-§5) |
| `timedSpells` | map | `{}` | `[spellId] = true` for every buff `modules/TimedSpells.lua` has seen carry a duration; account-wide because it is a fact about the game. Learned data, not a setting: written at runtime only by its owner, `modules/TimedSpells.lua` (`TS.Scan` learns, `TS.Forget` behind `/am forgettimed` empties it), and backfilled on load by `NS.RunMigrations`. Named in `docs/ARCHITECTURE.md` → Settings Schema (architecture-§5) |

## The container template

A container is created at runtime, so it cannot be an AceDB default. `NS.CONTAINER_TEMPLATE`
(`defaults/Profile.lua:112`) is deep-copied for every new container (`Database.NewContainerData`), and
every stored container is backfilled from it on load (`Database.PrepareProfile`, below). Each stored
container also carries its own `id`. The render path reads its fallbacks from the template too: a leaf
that is missing or garbage when a container is drawn falls back to the template's value for that same
path, never to a number restated in `modules/`.

### Identity

| Key | Default | Values |
|---|---|---|
| `name` | `"Container"` (a new one becomes `"Container N"`) | any non-blank string, unique across the registry |
| `enabled` | `true` | bool |
| `unit` | `"player"` | `player`, `target`, `focus`, `pet` |
| `auraType` | `"HELPFUL"` | `HELPFUL`, `HARMFUL`, `ENCHANT` |
| `style` | `"bars"` | `bars`, `icons` |

### `filter`

| Key | Default | Meaning |
|---|---|---|
| `categories` | every category key → `"show"` | `[categoryKey] = "show" \| "hide"` (schema v3); built from `NS.Categories.DefaultStates()`, so a key added later backfills as Show. Show is a positive claim, not merely "not excluded" — see `docs/ARCHITECTURE.md` → Filter priority. Since v2 one `healing` key stands where `coreHealing` and `lesserHealing` were |
| `whitelist` | `{}` | `[spellId] = true` — always shown; beats the blacklist (owner's 2026-09-15 filter-priority revision, `modules/FilterCompiler.lua` rank 1) |
| `blacklist` | `{}` | `[spellId] = true` — never shown, unless the whitelist also names it |
| `castBy` | `"any"` | `any`, `mine`, `others` |
| `durationMode` | `"any"` | `any`, `timed`, `timeless` |
| `maxDuration` | `0` | seconds; `0` is no limit |
| `hidePermanentEnchants` | `true` | skip enchants that never expire; lives on the Categories group since schema v3 (B3) |
| `sortMethod` | `"expirationOnly"` | `default`, `expiration`, `expirationOnly`, `name`, `nameOnly`, `bigDefensive`, `important`, `unitFrameDebuff`, `applied` |
| `sortDirection` | `"normal"` | `normal`, `reverse` |
| `maxAuras` | `0` | per group; `0` is no limit |

### `position` and `attach`

| Key | Default | Meaning |
|---|---|---|
| `position.point` / `.relativePoint` | `"CENTER"` / `"CENTER"` | Screen placement, used in `screen` mode; set by dragging |
| `position.x` / `.y` | `0` / `0` | Pixels; a new container is staggered down by `(id - 1) % 8 × 30` |
| `attach.mode` | `"screen"` | `screen`, `container`, `frame` |
| `attach.container` | `0` | target container id (`0` = none) |
| `attach.frame` | `""` | target global frame name |
| `attach.point` / `.relativePoint` | `"TOPLEFT"` / `"BOTTOMLEFT"` | corners for the `container` and `frame` modes |
| `attach.x` / `.y` | `0` / `-4` | offsets for the `container` and `frame` modes |

### `layout` and `behavior`

| Key | Default | | Key | Default |
|---|---|---|---|---|
| `layout.axis` | `"vertical"` | | `behavior.tooltips` | `true` |
| `layout.growH` | `"right"` | | `behavior.tooltipAnchor` | `"ANCHOR_BOTTOMLEFT"` |
| `layout.growV` | `"down"` | | `behavior.tooltipInCombat` | `true` |
| `layout.spacing` | `2` | | `behavior.clickThrough` | `false` |
| `layout.lineSpacing` | `2` | | `behavior.cancelOnRightClick` | `true` |
| `layout.perLine` | `0` (one line) | | | |
| `layout.scale` | `1.0` | | | |
| `layout.alpha` | `1.0` | | | |
| `layout.strata` | `"MEDIUM"` | | | |
| `layout.level` | `5` | | | |

### `bars`

| Key | Default | Key | Default |
|---|---|---|---|
| `width` | `220` | `height` | `18` |
| `barTexture` | `"Blizzard"` | `barAlpha` | `1.0` |
| `barColor` | `{ r=0.20, g=0.55, b=0.95, a=1 }` | `useClassColorBar` | `false` |
| `colorMode` | `"static"` (`static`, `dispel`: tinted by the profile's `dispelColors`) | | |
| `drain` | `"left"` (`left`, `right`) | `smooth` | `false` |
| `bgTexture` | `"Blizzard"` | `bgAlpha` | `1.0` |
| `bgColor` | `{ 0, 0, 0, 0.5 }` | `useClassColorBg` | `false` |
| `borderShow` | `false` | `borderStyle` | `"Solid"` |
| `borderSize` | `1` | `borderColor` | `{ 0, 0, 0, 1 }` |
| `useClassColorBorder` | `false` | `icon` | `"LEFT"` (`LEFT`, `RIGHT`, `NONE`) |
| `iconSize` | `0` (= bar height) | `iconGap` | `1` |
| `iconZoom` | `0.08` | `iconBorderShow` | `false` |
| `iconBorderStyle` | `"Solid"` | `iconBorderSize` | `1` |
| `iconBorderColor` | `{ 0, 0, 0, 1 }` | `useClassColorIconBorder` | `false` |
| `spark` | `true` | `sparkWidth` | `8` |
| `sparkColor` | `{ 1, 1, 1, 0.9 }` | `useClassColorSpark` | `false` |
| `sparkTimeless` | `true` (`false`: no spark on an aura without a duration) | `name` | text block: size 11, `LEFT`, x 4, y 0, justify `LEFT` |
| `time` | text block: size 11, `RIGHT`, x −4, y 0, justify `RIGHT` | `stacks` | text block: size 10, `BOTTOMRIGHT`, x −1, y 1, justify `RIGHT` |
| `timeFormat` | `"blizzard"` (`blizzard`, `short`, `long`) | `expiringColorOn` | `false` |
| `expiringThreshold` | `5` | `expiringColor` | `{ 1, 0.25, 0.25, 1 }` |
| `pandemic` | `false` | `pandemicColor` | `{ 1, 0.85, 0.10, 1 }` |

The profile's `dispelColors` defaults (`C.DEFAULT_DISPEL_COLORS`, `core/Constants.lua:163`): Magic `{0.20, 0.60, 1.00}`, Curse `{0.60, 0.00, 1.00}`, Disease
`{0.60, 0.40, 0.00}`, Poison `{0.00, 0.60, 0.00}`, Bleed `{0.80, 0.10, 0.10}`, None
`{0.80, 0.00, 0.00}`, all alpha 1.

### `icons`

| Key | Default | Key | Default |
|---|---|---|---|
| `width` | `32` | `height` | `32` |
| `zoom` | `0.08` | `dispelBorder` | `true` |
| `borderShow` | `true` | `borderStyle` | `"Solid"` |
| `borderSize` | `1` | `borderColor` | `{ 0, 0, 0, 1 }` |
| `useClassColorBorder` | `false` | `cooldown` | `true` |
| `cooldownReverse` | `false` | `cooldownEdge` | `true` |
| `swipeAlpha` | `0.6` | `blizzardNumbers` | `false` |
| `time` | text block: size 11, `BOTTOM`, x 0, y −12, justify `CENTER` | `stacks` | text block: size 11, `BOTTOMRIGHT`, x −1, y 1, justify `RIGHT` |
| `timeFormat` | `"blizzard"` | `expiringColorOn` | `false` |
| `expiringThreshold` | `5` | `expiringColor` | `{ 1, 0.25, 0.25, 1 }` |
| `pandemic` | `false` | `pandemicColor` | `{ 1, 0.85, 0.10, 1 }` |

### The text block

Every text element (`bars.name`, `bars.time`, `bars.stacks`, `icons.time`, `icons.stacks`) has the
six canonical font leaves (options-ui-§16) and then its placement: `show` (`true`), `font`
(`"Friz Quadrata TT"`), `fontSize`, `fontColor` (`{ 1, 1, 1, 1 }`), `useClassColorFont` (`false`),
`fontFlags` (`"OUTLINE"`), `fontShadow` (`false`), `point`, `x`, `y`, `justify`.

## The starter containers

`NS.STARTER_CONTAINERS` (`defaults/Profile.lua:213`) seeds a brand-new profile once, each spec merged
over the template:

| Name | Unit | Type | Style | Differs from the template |
|---|---|---|---|---|
| Player buffs | player | HELPFUL | bars | `TOPRIGHT` −240, −220; enchants draw by the `weaponEnchants` category's default (Show) |
| Player debuffs | player | HARMFUL | icons | `TOPRIGHT` −240, −160; horizontal, grows left |
| Target debuffs (mine) | target | HARMFUL | icons | `castBy = "mine"`; `CENTER` 0, −160; horizontal, grows right |

## Session state (not persisted)

`NS.State` (`core/State.lua`): `debug` (the console's logging flag) and `activeContainerId` (which
container every `container.` path resolves against). Both reset at every `/reload`. There is no
preview flag: the placeholders show while the addon is unlocked, and only then.
The schema reaches the session state through one `sessionOnly` row, `state.debugConsole`, which
writes nothing to the database.

## `AuraMasterPerfDB` — the capture ring

A second top-level global, owned by `LibKa0s-Perf-1.0` and named in `core/PerfSetup.lua:37`. It
holds the most recent in-game perf captures in the library's record schema, outside the AceDB tree
so a profile copy, reset or switch never touches it (performance-§5). This addon writes nothing to
it directly. Recorded data a vendored library writes, not a setting: its owner (`core/PerfSetup.lua`)
and its one writer (the library's `P.Save`, behind `/am perf finish`) are named in
`docs/ARCHITECTURE.md` → Settings Schema (architecture-§5).

## How the schema paths map onto this shape

A schema row's `path` is absolute into `profile` (`enabled`, `hideBlizzardBuffs`), absolute into
`global` — which **one** row is, `global.minimap.hide` — or
**container-relative**: `container.bars.width` means `profile.containers[activeId].bars.width`,
where `activeId` is `NS.State.activeContainerId` or, when nothing is selected, the first container in
`containerOrder` (`NS.ActiveContainer`, `settings/Schema.lua:132`). `NS.DefaultFor(path)` reads the
same path out of the template (for `container.` paths) or `NS.defaults.profile` (the rest), and
`NS.ValidateSchema` fails any row whose path resolves against neither. The panel tree and the row
list per page are in `docs/settings-panel.md`.

`global.minimap.hide` is the exception, and it is one branch in each seam rather than a second
resolver: `NS.GetSetting` answers `not hide`, `NS.SetByPath` stores `not value` and calls
`NS.Launcher:SetShown`, and `NS.DefaultFor` inverts `NS.defaults.global.minimap.hide` so the
shipped default still comes from the one declaration. The path is spelled verbatim and carries no
profile prefix, because the table is LibDBIcon's and lives outside any profile. Its `effect` is
`"none"`: the button is not a container, and the seam already moved it.

A row may also declare `effect`, which tells `modules/ContainerManager.lua` what a write needs beyond
the stored value. `"visibility"` (the master `enabled`, `visibility`, `locked` and `alpha`, and
`container.enabled`) runs the combat-legal visibility pass and queues no apply. Only the show ladder
reads a container's `enabled`; `Container:Apply` never does. `"none"` (`hideBlizzardBuffs`,
`hideBlizzardDebuffs`, `container.name`) queues nothing, because the row's `onChange` is its whole
effect. A Blizzard-frame toggle made under lockdown still waits: `BlizzardFrames.Apply` catches it
up on `PLAYER_REGEN_ENABLED`, and the row's `onChange` prints the combat deferral line through
`ContainerManager.NoteDeferred`, under the same once-per-stretch rule a held apply follows. Absent,
the write re-applies its container, or every container for a global row. A `sessionOnly` row
announces nothing at all. Master `scale` is deliberately unmarked: `SetScale` runs in
`Container:Apply`.

A few row fields are this addon's own, beyond the library's row shape. Each has one named reader:

- `noReset`, with `noResetReason`: the restore walk skips the row, and `NS.ApplyDefault` refuses it
  and returns that reason (`container.name`; `/am reset container.name` prints it).
- `printLabel`: `/am get` and `/am list` print the value's label before the stored value
  (`formatValue` in `settings/Slash.lua`; the Filters category rows).
- `grid`: the `ChoiceGrid` on Filters → Categories that draws the row (`blizzard`, `custom`, `dispel`
  or `who`). Those rows also carry the library's `skipRender`, so the flow engine draws nothing for
  them.
- `panelGet`: the value the panel shows instead of the stored one (`panelRead` in
  `settings/OptionsSetup.lua`). Fill and both growth rows use it to show the inherited flow of a
  container attached to another. `/am get` and every module read the stored value.
- `coverage = "engine-only" | "preview-only"`: exempts a Bars or Icons row from one half of
  `tests/test_render_coverage.lua`'s walk. Each use carries a comment saying why: `bars.smooth`,
  `bars.pandemic` and `icons.pandemic` act only through the engine.

A row's `validate(value, id)` and its optional `normalize(value, id)` hook are both handed the id of
the container the write targets: the one a caller names, else the selected one. `NS.SetByPath`
resolves that id first and then validates, so a bad value is still refused before a missing container
is. `normalize` runs after both, just before the write. Whatever it returns is what gets stored, and
it is also the value `onChange` and the announcement see. A row's `onChange(value, id, old)` receives
the value the write replaced. The `container.name` row uses it to store the
trimmed name made unique by `ContainerManager.UniqueName`, and that comparison ignores case (`buffs`
next to `Buffs` becomes `buffs (2)`). The rule covers every writer, whether that is the panel,
`/am set`, `ContainerManager.Rename` or a reset.

The write seam also takes six **whole sections**: `container.filter`, `.layout`, `.behavior`,
`.position`, `.bars` and `.icons` (`NS.IsSection`). `NS.SetByPath("container.position", tbl, id)`
stores a deep copy of `tbl` in place of the section. First it backfills the copy from the template, so
no key can be dropped. Then it runs the spell-set carve-outs under that section, and then every row
`validate` under it. A single rejection refuses the whole write, and nothing gets stored. Once the
section is written, `onChange` fires for each row whose leaf actually changed, compared by
`FilterCompiler.Signature`. The write logs one `[Set]` line that renders the stored table (for example
`container.position = {point=TOP, relativePoint=CENTER, x=5, y=0}`), built only while debug is on, and
sends one `CONFIG_CHANGED` whose `path` is the section path. `container.attach` is not a section: no
caller writes it whole.

**A bulk copy or reset is one line** (debug-logging-§10). `NS.Bulk` brackets every act that
rewrites a set of rows wholesale. That covers a page's Defaults and Reset all (the library's
`bulkBegin`/`bulkEnd`, LibKa0s-Options minor 16), `CliResetAll` (Slash minor 8), and
`ContainerManager.CopyFrom` and `ContainerManager.ResetPositions` (`NS.Bulk.Run`). While a bracket
is open, the seam's two log sites, the per-write `[Set]` line and the section line, are muted. Each
write instead tallies the rows it changed at the moment it stores them, before any `onChange` runs,
so the count is what was stored even when an `onChange` raises. Numbers compare by `==`, so a `-0`
over a `0` is no change; anything else compares by `FilterCompiler.Signature`. A section write
counts each row and carve-out under it that changed. The act then logs one
`[Set] <act> <scope>: N rows` line, such as `[Set] reset bars: 2 rows`,
`[Set] copy container 2→1 (all): 14 rows` or `[Set] reset positions: 3 rows`. N is the rows actually
changed, not the library's `count`, so a Defaults press on a page already at its defaults logs
`0 rows`. Validation, `onChange` and `CONFIG_CHANGED` still run per write. The mute is a depth
counter, so a bracket inside another sums into it and the act logs once. An act that an error stops
(`bulkEnd` handed an `err`) still logs its line exactly once, with ` (stopped by an error)` on the
end, such as `[Set] reset bars: 1 rows (stopped by an error)`. The mute is then released and the
error re-raised unchanged. When any level reports `info.profileReset`, the bracket logs nothing and
`NS.OnProfileReset` logs the reset as `[Set] reset profile '<name>' to defaults`, with no count
(`docs/profiles.md` says why).

`NS.CheckWrite(path, value, id)` answers whether `NS.SetByPath` would store a value. It runs the same
checks on a copy (a row's `validate`, a carve-out's normalizer, or a section's backfill, carve-outs
and row validation) and stores and announces nothing, so it is not a second write seam.
`ContainerManager.CopyFrom` uses it to stay all or nothing: it checks every section it copies (and,
for a whole copy, the unit, aura type and style) before writing any of them, so one corrupt source
section refuses the whole copy and leaves the target untouched, with no `CONFIG_CHANGED` sent.

## Migration path

The account-wide ladder is `SCHEMA_STEPS` in `core/Database.lua:727`: one `{ to = N, apply = fn }`
row per stored-shape change, applied in order by `NS.RunMigrations` while
`global.schemaVersion < to`, each logging one `[Migrate]` debug line.

- **Schema v1** is the shape the addon shipped with at 0.1.0.
- **Schema v2** (`Database.MigrateV2`) runs over **every** stored profile: AceDB's raw
  `sv.profiles`, the inactive ones included, or the no-AceDB fallback's one profile. It logs one
  `[Migrate] v2 profile '<name>'` line each, and stamps `global.schemaVersion` to `2`.
  - The container key rules `PrepareProfile` applies (below) run first, so a string twin of a
    numeric id and a non-numeric key are dropped before any merge and never supply a palette or an
    editor.
  - `profile.categorySpells` (new): the union of every container's added ids. A starter id stays
    removed (`false`) only if every container that had an edit for that category removed it; a
    container with no edit for the category has no say. `container.filter.categorySpells` is deleted.
  - `coreHealing` + `lesserHealing` → `healing`: their spell edits merge by the rule above (a
    container's two lists count as one editor). A container's state becomes `show` if either was
    `show`, else `hide` if either was `hide`, else `""`. Both old keys leave `filter.categories`.
  - `profile.dispelColors` (new): copied from the first container in `containerOrder` colored by
    dispel type, else the first container that carries a palette, else the defaults, and completed
    from the defaults. `bars.dispelColors` is deleted from every container.
  - `layout.strata`: a stored `"MEDIUM"` (the v1 default) becomes `"HIGH"`; any other value is kept.
  - Additive keys ride the ordinary backfill with no step.
- **Schema v3** (`Database.MigrateV3`, `core/Database.lua:639`) runs over **every** stored profile,
  same reach as v2. It logs one `[Migrate] v3 profile '<name>'` line each, and
  stamps `global.schemaVersion` to `3`. Only a container whose `auraType` is a known one
  (`HELPFUL`/`HARMFUL`/`ENCHANT`) is converted; a missing or corrupt `auraType` is left completely
  alone rather than half-converted, does not count toward the step's "over N container(s)" total,
  and logs its own `[Migrate] v3 container '<id>' skipped: unrecognized auraType <value>` line — a
  silently skipped container is the kind of thing only its player would ever notice.
  - The old three-state category model (`""` no effect / `"show"` whitelist / `"hide"` exclude)
    became two states, Show / Hide (defaults/Categories.lua documents what each does today). The
    old `"show"` state meant "draw ONLY the categories set to show" — a state the new model has no
    room for, so mapping `""` → `"show"` verbatim would silently WIDEN what an already-stored
    container draws. The old intent is written out longhand instead, per container, over
    `NS.Categories.For(container.auraType)`'s FILTERABLE keys (below): if ANY of them was `"show"`,
    every one NOT `"show"` (an unset `""` or an explicit `"hide"`) becomes `"hide"` — the longhand of
    the old whitelist. With no `"show"` present, only the unset `""` rows become `"show"`; an explicit
    `"hide"` is left exactly as it was, since the old model already excluded it with no whitelist
    active. `ENCHANT` containers have no categories and are skipped entirely. This runs only while at
    least one filterable category of the container's type is still unset (`""` or missing) — an
    already-fully-decided container (every filterable key `"show"` or `"hide"`) is the fixed point and
    is left untouched, which is what makes a second run a no-op.
  - **Filterable keys exclude `kind == "enchant"` categorically**, not merely because none existed in
    `NS.Categories.For`'s lists when the step was written. An enchant row (`weaponEnchants`, added by task B3) is a
    container capability — "does this container have weapon-enchant slots" — not a filter over auras:
    it matches no aura and joins no aura group, the same reason `modules/FilterCompiler.lua`'s own
    `splitCategories` skips that kind. So it never counts toward "was this container narrowed", is
    never swept to `"hide"` by that decision, and contributes no ids (already true via the
    `kind == "spells"` check below). Without this exclusion, a container with no `filter.categories`
    table at all is the sharpest failure: the whitelist lift has nothing to act on yet, so
    `filter.includeEnchants`'s lift (below) is the one that creates the table, holding only
    `weaponEnchants` — and the next run over that container would see exactly one category at
    `"show"`, read it as narrowed, and sweep every other category to `"hide"`, a near-total blackout
    of a container the player never touched. The exclusion holds whether `kind == "enchant"` exists in
    `def` or not, so it needed no revisiting when B3 landed.
  - Categories are not a partition of the aura space, so "hide everything not whitelisted" cannot
    fully reproduce the old exclusive whitelist purely by category state: an aura that also matched a
    category the sweep above just turned to `"hide"` would need rescuing. Originally (schema v3's
    first cut) that rescue was done here, by copying the ids of every `"show"` **spells** category
    onto `filter.whitelist`. The owner's 2026-09-15 filter-priority revision made that unnecessary:
    a Show now beats a Hide on the same aura for every category kind, not only `spells`
    (`modules/FilterCompiler.lua` rank 3 — "in at least one Show category" rescues an aura even if it
    is also in a Hide category), so the compiler itself does this rescue on every compile, and this
    migration step copies no ids at all. (An aura in no category at all now drawing, when the old
    exclusive whitelist excluded it, is still inherent to the new model and is not fixed by anything
    here. Schema v3 shipped a per-container "only these categories" toggle for that — RETIRED by
    schema v4, below, in favor of `categories.uncategorized`.)
  - `filter.includeEnchants` (the old weapon-enchant boolean) becomes the `weaponEnchants` category
    row (`"show"` when the flag was true, `"hide"` otherwise, including when the key was never set),
    and the old key is deleted; `ENCHANT` containers never read the old flag and are left alone. Runs
    AFTER the category-whitelist lift above, and only when `categories.weaponEnchants` is not already
    set (idempotency: `includeEnchants` is nil by the second run, so an unconditional write would
    re-stamp `"hide"` and silently drop a container already migrated to `"show"` on any re-run — a
    restored backup, a copied profile, a re-applied step). When this step was written, `weaponEnchants` was not yet
    one of `NS.Categories.For`'s keys (task B3 then added the category definition and wired the
    compiler and UI to it; this step only wrote the stored key ahead of that); the categorical
    `kind == "enchant"` exclusion above is what keeps this order safe now that B3 has added it.
- **Schema v4** (`Database.MigrateV4`, `core/Database.lua`, batch 7 fix rounds 2 and 3) runs over
  **every** stored profile, same reach as v2/v3. It logs one `[Migrate] v4 profile '<name>'` line
  each naming how many containers converted and how many lost the capability, and
  `Database.CurrentSchemaVersion()` answers `4`. The owner retired the per-container "Only these
  categories" toggle (`filter.onlyShown`) entirely: `categories.uncategorized = "hide"` (buffs) or
  `categories.uncategorizedDebuffs = "hide"` (debuffs, batch 7 `U-1`..`U-5`, restored fix round 3;
  `docs/ARCHITECTURE.md` → Filter priority) means what the toggle used to mean, on either aura type —
  Hide always reproduces it exactly, whether or not the category's union is empty (fix round 3's
  `hasUnion` gate only changes what SHOW does, not what Hide does). For a container with
  `filter.onlyShown == true`:
  - **HELPFUL or HARMFUL**: the matching `categories.<key>` is set `"hide"`, preserving the toggle's
    old effect — the container keeps drawing only what it categorized rather than silently widening
    the moment the toggle's own catch-all suppression disappears with the key.
  - **ENCHANT**: neither converted nor counted as lost. An ENCHANT container compiles to no aura
    groups at all (`FC.Compile`'s `compileEnchant`), so its `onlyShown` — however it got set — never
    did anything; the dead key is still cleared, just not narrated as a loss.
  - **Any other, unrecognized `auraType`**: there is no `uncategorized` category to migrate onto for
    a shape this migration does not know, so nothing can be invented to stand in for it. The
    container LOSES the "only these categories" narrowing — an unclaimed aura reaches the ordinary
    catch-all again, same as any container that never had the toggle on. This is counted (`lost`),
    named (`{ id, name, auraType }`), and told to the player directly with an ungated `NS.Print` line
    naming every such container — not left to `NS.Debug`, which a player may never have enabled, and
    not done silently.
  Either way `filter.onlyShown` is cleared — the key means nothing any more and
  `NS.CONTAINER_TEMPLATE` no longer carries it. A container where the toggle was already off or
  absent is untouched entirely, not even the dead-key clear (idempotent: nothing at `true` to act on
  on a second run either).
- **An additive change needs no step.** `Database.PrepareProfile` (`core/Database.lua:213`) runs after
  the ladder on every `InitDB` and on every profile change: it backfills every stored container from
  the template with `== nil` tests (a stored `false` survives, savedvariables-§5), normalizes string
  ids to numbers, rebuilds `containerOrder` to exactly the ids that exist, raises `nextContainerId`
  past the highest id, and seeds the starter containers on a profile whose `seeded` flag is unset.
  A container key that is neither a number nor a numeric string (a hand-edited file) is dropped,
  with one `[Migrate] dropped container key` debug line each, so the profile still loads. So is a
  numeric string whose id is already stored as a number: the numeric key is the form the addon
  writes, so the string twin is the stale copy and never overwrites it. The load path's backfill
  also repairs: a stored value that is not a table where the template holds a section (a
  hand-edited `position = "junk"`) is replaced by the template's section. A whole-section write
  through `NS.SetByPath` backfills without that repair, so a malformed section is refused, not
  silently fixed.
  A new category key reaches every container the same way, through `DefaultStates()`.
- **A rename, removal or type change needs a step** in the same change that makes it: append the
  next rung (`to = 5`), transform the stored value, and remember that containers live in every
  profile, not only the active one (`docs/common-tasks.md` has the recipe).
