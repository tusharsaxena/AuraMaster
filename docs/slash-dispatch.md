# Slash dispatch

`/am` and its long form `/auramaster`. Required because `NS.COMMANDS` carries 20 commands, over the
eight-or-more trigger (documentation-§3).

## Registration and dispatch

- **Registration** is AceConsole's `RegisterChatCommand`, twice, in `Slash.Register`
  (`settings/Slash.lua:359`), called from `OnInitialize`. There is no `SLASH_*` global.
- **Dispatch** is `LibKa0s-Slash-1.0` (slash-commands-§1), built from a descriptor at the bottom of
  `settings/Slash.lua`. The library trims the message, lowercases only the verb (paths are
  case-sensitive, and a color is several tokens), maps aliases, finds the verb in `NS.COMMANDS` and
  calls its handler with the rest of the line. A bare `/am` prints help; an unknown verb prints the
  library's unknown-command line and then help.
- **Aliases:** `options` → `config`.
- **`NS.COMMANDS` is the addon's own**, an ordered array of positional triples `{name, desc, fn}`,
  passed *into* the library. The landing page renders the same table through `Slash.LandingRows`
  (`settings/About.lua`), so the page and `/am help` cannot drift.
- Every line the addon prints carries the cyan `[AM]` tag (`NS.PREFIX`, slash-commands-§4).

## The verbs

| # | Verb | Kind | Handler |
|---|---|---|---|
| 1 | `help` | library | `cli:PrintHelp()` — version line plus one row per command |
| 2 | `config` | host | `NS.OpenOptionsPanel()`; refused in combat with a gray notice (options-ui-§2) |
| 3 | `list` | library | `cli:CliList()` over `NS.Schema`, grouped by page |
| 4 | `get path` | library | `cli:CliGet` → `NS.GetSetting(path)`; also answers sub-tables such as `container.filter.whitelist` |
| 5 | `set path value` | library | `cli:CliSet` → type-aware parse → `NS.SetByPath(path, value)`; an error from the seam is printed |
| 6 | `reset path` | library | `cli:CliReset` → `NS.ApplyDefault(row)`; takes a path, never a page |
| 7 | `resetall` | host | `NS.Helpers.RestoreAllDefaults()` — the profile reset (options-ui-§12); not refused in combat, where it takes the parked teardown like Profiles → Reset Profile |
| 8 | `containers` | host | Lists every container: `name #id · unit · type · style`, the selected one marked `>` |
| 9 | `select id-or-name` | host | `NS.State.SetActiveContainer(id)`; name match is case-insensitive, and a name more than one container shares is refused (below) |
| 10 | `new [words]` | host | `ContainerManager.Create(overrides)` then selects it; `Create` refuses in combat and the refusal prints gray |
| 11 | `delete id-or-name` | host | `ContainerManager.Delete(id)`; refused in combat with a gray notice; a shared name is refused (below) |
| 12 | `lock` | host | `NS.SetByPath("locked", true)` — also ends preview |
| 13 | `unlock` | host | `NS.SetByPath("locked", false)` — handles and placeholders |
| 14 | `preview [on\|off]` | host | `NS.SetByPath("state.preview", on)`; bare toggles |
| 15 | `pick` | host | Starts `FramePicker` for the selected container; refused in combat |
| 16 | `resetposition` | host | `ContainerManager.ResetPositions()` |
| 17 | `forgettimed` | host | `TimedSpells.Forget()` |
| 18 | `debug [on\|off]` | host | Bare toggles the console window; `on`/`off` go through `NS.DebugLog:SetEnabled` |
| 19 | `perf …` | host | Prints the lines `NS.Perf.OnCommand(rest)` returns (performance-§4); `docs/performance.md` |
| 20 | `version` | host | `v` + `NS.Version()` |

### `/am new` words

Any order, any subset, case-insensitive; each word sets one field of the new container
(`NEW_WORDS`, `settings/Slash.lua:163`):

| Words | Field |
|---|---|
| `player`, `target`, `focus`, `pet` | `unit` |
| `buff`, `buffs` / `debuff`, `debuffs` / `enchant`, `enchants` | `auraType` (`HELPFUL` / `HARMFUL` / `ENCHANT`) |
| `bar`, `bars` / `icon`, `icons` | `style` |

An unknown word prints `Unknown word 'x' — try /am new target debuffs icons` and creates nothing.

### Names on `select` and `delete`

A name is matched without regard to case. Every write of `container.name` stores a name that is
unique regardless of case, so a match normally finds one container. A profile saved before that rule
can still hold two containers named, say, `Dup` and `dup`. When a name matches more than one
container, the command guesses neither. It acts on nothing and prints
`More than one container is called 'dup' — use its number from /am containers.` Nothing is renamed or
migrated. Addressing the container by its number works as before.

## Container-relative paths on the CLI

A path beginning `container.` resolves against the **selected** container — the one the settings
banner last chose, or `/am select`, or the first container when nothing has been chosen this session
(`NS.ActiveContainer`, `settings/Schema.lua:98`). So `/am set container.bars.width 300` means the
same thing on the CLI as the Width slider does in the panel. Every `container.` line `/am list` and
`/am get` print is annotated in gray with the container's name (`cli:SetRowAnnotator`,
`settings/Slash.lua:342`), so a value never reads as the only one. `/am containers` then `/am select`
changes the target.

Examples:

```
/am new target debuffs icons
/am select Player buffs
/am set container.filter.castBy mine
/am set container.layout.perLine 8
/am get container.filter.categories.crowdControl
/am reset container.bars.height
```

The whole-set carve-outs (`container.filter.whitelist`, `.blacklist`, `.categorySpells`) are settable
through the seam but have no row, so `/am list` does not print them; the Filters page is their editor.

## Degraded path

With `LibKa0s-Slash-1.0` absent, `settings/Slash.lua:272` builds a stub dispatcher: the host verbs
keep working (they never went to the library), `help` prints a plain command list, and `list`, `get`,
`set` and `reset` each print that they are unavailable and why. The stub copies none of the library's
formatting or parsing. `tests/degraded_env.lua` loads the addon that way.

## Adding a verb

The recipe is in `docs/common-tasks.md` → *Add a slash verb*.
