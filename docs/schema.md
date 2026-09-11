# Schema — what is persisted

Two SavedVariables globals (`AuraMasterDB`, `AuraMasterPerfDB`, `AuraMaster.toc:7`) and nothing else
(savedvariables-§4). Every default is hardcoded in exactly one file, `defaults/Profile.lua`
(savedvariables-§2); the settings schema reads its defaults from there rather than repeating them.

## `AuraMasterDB` — the AceDB database

Created by `NS.InitDB` (`core/Database.lua:165`) as `AceDB:New("AuraMasterDB", NS.defaults, true)`:
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
| `containers` | map | `{}` | `[id] = container` (the template below); written only by `modules/ContainerManager.lua` |
| `containerOrder` | array | `{}` | Container ids in display order |
| `nextContainerId` | number | `1` | The next id to hand out |
| `seeded` | bool | `false` | The starter containers have been created once; deleting them all does not bring them back |

### `global` — account-wide

| Key | Type | Default | Meaning |
|---|---|---|---|
| `schemaVersion` | number | `1` | The migration stamp (savedvariables-§1). Defaults to 1, not the current version: AceDB fills an absent key before `RunMigrations` reads it |
| `timedSpells` | map | `{}` | `[spellId] = true` for every buff `modules/TimedSpells.lua` has seen carry a duration; account-wide because it is a fact about the game |

## The container template

A container is created at runtime, so it cannot be an AceDB default. `NS.CONTAINER_TEMPLATE`
(`defaults/Profile.lua:85`) is deep-copied for every new container (`Database.NewContainerData`), and
every stored container is backfilled from it on load (`Database.PrepareProfile`, below). Each stored
container also carries its own `id`.

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
| `categories` | every category key → `""` | `[categoryKey] = "" \| "show" \| "hide"`; built from `NS.Categories.NeutralStates()`, so a key added later backfills as neutral |
| `categorySpells` | `{}` | `[categoryKey] = { [spellId] = true (added) \| false (removed) }`, layered over the starter lists |
| `whitelist` | `{}` | `[spellId] = true` — always shown |
| `blacklist` | `{}` | `[spellId] = true` — never shown; beats the whitelist |
| `castBy` | `"any"` | `any`, `mine`, `others` |
| `durationMode` | `"any"` | `any`, `timed`, `timeless` |
| `maxDuration` | `0` | seconds; `0` is no limit |
| `includeEnchants` | `false` | a player buff container also shows weapon enchants |
| `hidePermanentEnchants` | `true` | skip enchants that never expire |
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
| `colorMode` | `"static"` (`static`, `dispel`) | `dispelColors` | per dispel type, from `core/Constants.lua:143` |
| `drain` | `"left"` (`left`, `right`) | `smooth` | `false` |
| `bgTexture` | `"Blizzard"` | `bgColor` | `{ 0, 0, 0, 0.5 }` |
| `useClassColorBg` | `false` | `borderShow` | `false` |
| `borderStyle` | `"Solid"` | `borderSize` | `1` |
| `borderColor` | `{ 0, 0, 0, 1 }` | `useClassColorBorder` | `false` |
| `icon` | `"LEFT"` (`LEFT`, `RIGHT`, `NONE`) | `iconSize` | `0` (= bar height) |
| `iconGap` | `1` | `iconZoom` | `0.08` |
| `spark` | `true` | `sparkWidth` | `8` |
| `sparkColor` | `{ 1, 1, 1, 0.9 }` | `useClassColorSpark` | `false` |
| `name` | text block: size 11, `LEFT`, x 4, y 0, justify `LEFT` | `time` | text block: size 11, `RIGHT`, x −4, y 0, justify `RIGHT` |
| `stacks` | text block: size 10, `BOTTOMRIGHT`, x −1, y 1, justify `RIGHT` | `timeFormat` | `"blizzard"` (`blizzard`, `short`, `long`) |
| `expiringColorOn` | `false` | `expiringThreshold` | `5` |
| `expiringColor` | `{ 1, 0.25, 0.25, 1 }` | `pandemic` | `false` |
| `pandemicColor` | `{ 1, 0.85, 0.10, 1 }` | | |

`dispelColors` defaults: Magic `{0.20, 0.60, 1.00}`, Curse `{0.60, 0.00, 1.00}`, Disease
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

`NS.STARTER_CONTAINERS` (`defaults/Profile.lua:187`) seeds a brand-new profile once, each spec merged
over the template:

| Name | Unit | Type | Style | Differs from the template |
|---|---|---|---|---|
| Player buffs | player | HELPFUL | bars | `includeEnchants = true`; `TOPRIGHT` −240, −220 |
| Player debuffs | player | HARMFUL | icons | `TOPRIGHT` −240, −160; horizontal, grows left |
| Target debuffs (mine) | target | HARMFUL | icons | `castBy = "mine"`; `CENTER` 0, −160; horizontal, grows right |

## Session state (not persisted)

`NS.State` (`core/State.lua`): `debug` (the console's logging flag), `activeContainerId` (which
container every `container.` path resolves against) and `preview`. All three reset at every `/reload`.
The schema reaches the session state through two `sessionOnly` rows, `state.debugConsole` and
`state.preview`, which write nothing to the database.

## `AuraMasterPerfDB` — the capture ring

A second top-level global, owned by `LibKa0s-Perf-1.0` and named in `core/PerfSetup.lua:36`. It
holds the most recent in-game perf captures in the library's record schema, outside the AceDB tree
so a profile copy, reset or switch never touches it (performance-§5). This addon writes nothing to
it directly.

## How the schema paths map onto this shape

A schema row's `path` is either absolute into `profile` (`enabled`, `hideBlizzardBuffs`) or
**container-relative**: `container.bars.width` means `profile.containers[activeId].bars.width`,
where `activeId` is `NS.State.activeContainerId` or, when nothing is selected, the first container in
`containerOrder` (`NS.ActiveContainer`, `settings/Schema.lua:89`). `NS.DefaultFor(path)` reads the
same path out of the template (for `container.` paths) or `NS.defaults.profile` (the rest), and
`NS.ValidateSchema` fails any row whose path resolves against neither. The panel tree and the row
list per page are in `docs/settings-panel.md`.

## Migration path

The account-wide ladder is `SCHEMA_STEPS` in `core/Database.lua:192`: one `{ to = N, apply = fn }`
row per stored-shape change, applied in order by `NS.RunMigrations` while
`global.schemaVersion < to`, each logging one `[Migrate]` debug line.

- **Schema v1** is the shape the addon shipped with at 0.1.0. **The ladder is empty**, and
  `Database.CurrentSchemaVersion()` answers `1`.
- **An additive change needs no step.** `Database.PrepareProfile` (`core/Database.lua:100`) runs after
  the ladder on every `InitDB` and on every profile change: it backfills every stored container from
  the template with `== nil` tests (a stored `false` survives, savedvariables-§5), normalizes string
  ids to numbers, rebuilds `containerOrder` to exactly the ids that exist, raises `nextContainerId`
  past the highest id, and seeds the starter containers on a profile whose `seeded` flag is unset.
  A new category key reaches every container the same way, through `NeutralStates()`.
- **A rename, removal or type change needs a step** in the same change that makes it: bump to
  `to = 2`, transform the stored value, and remember that containers live in every profile, not only
  the active one (`docs/common-tasks.md` has the recipe).
