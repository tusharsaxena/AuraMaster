# Slash dispatch

`/am` and its long form `/auramaster`. Required because `NS.COMMANDS` carries 21 commands, over the
eight-or-more trigger (documentation-§3).

## Registration and dispatch

- **Registration** is AceConsole's `RegisterChatCommand`, twice, in `Slash.Register`
  (`settings/Slash.lua:462`), called from `OnInitialize`. There is no `SLASH_*` global. It is
  **never torn down**, which is what makes `enable` and `disable` a pair rather than a one-way
  door: every verb still answers while the addon is disabled (slash-commands-§2). Disabling runs
  the visibility pass and hides containers; it touches nothing about dispatch.
- **Dispatch** is `LibKa0s-Slash-1.0` (slash-commands-§1), built from a descriptor at the bottom of
  `settings/Slash.lua`. The library trims the message, lowercases only the verb (paths are
  case-sensitive, and a color is several tokens), maps aliases, finds the verb in `NS.COMMANDS` and
  calls its handler with the rest of the line. A bare `/am` (empty, or only spaces) runs the
  `config` verb with an empty rest, so it opens the settings panel on its landing page, or prints the
  same combat refusal `config` does (slash-commands-§4, LibKa0s Slash minor 11). `/am help` prints
  the list. An unknown verb prints the library's unknown-command line and then help.
- **Aliases:** `options` → `config`.
- **`lock` and `unlock` have a second caller.** Both run through `Sl.SetLocked`, published for
  the launcher's left click (`core/LauncherSetup.lua`, rung (b), launcher-§2), so the minimap
  button, the two verbs and the General → Master controls *Lock frame* checkbox are three doors
  onto one `NS.SetByPath("locked", …)` and print the same line.
- **`NS.COMMANDS` is the addon's own**, an ordered array of positional triples `{name, desc, fn}`,
  passed *into* the library. The landing page renders the same table through `Slash.LandingRows`
  (`settings/About.lua`), so the page and `/am help` cannot drift.
- Every line the addon prints carries the cyan `[AM]` tag (`NS.PREFIX`, slash-commands-§4).

## The verbs

| # | Verb | Kind | Handler |
|---|---|---|---|
| 1 | `help` | library | `cli:PrintHelp()` — version line plus one row per command |
| 2 | `config` | host | `NS.OpenOptionsPanel()`, which opens the top-level landing category; refused in combat with a gray notice (options-ui-§2). A bare `/am` runs it too |
| 3 | `enable` | host | `NS.SetByPath("enabled", true)`, the path the General → Master controls "Enable Aura Master" checkbox takes; not refused in combat, and a seam error is printed |
| 4 | `disable` | host | `NS.SetByPath("enabled", false)`; the visibility pass disables every engine through its own `SetEnabled`, combat included |
| 5 | `list` | library | `cli:CliList()` over `NS.Schema`, grouped by page |
| 6 | `get path` | library | `cli:CliGet` → `NS.GetSetting(path)`; also answers sub-tables such as `container.filter.whitelist` |
| 7 | `set path value` | library | `cli:CliSet` → type-aware parse (a string row takes the whole rest of the line, trimmed) → `NS.SetByPath(path, value)`; an error from the seam is printed |
| 8 | `reset path` | library | `cli:CliReset` → `NS.ApplyDefault(row)`; takes a path, never a page |
| 9 | `resetall` | host | `NS.Helpers.RestoreAllDefaults()` — the profile reset (options-ui-§12); not refused in combat, where it takes the parked teardown like Profiles → Reset Profile |
| 10 | `containers` | host | Lists every container: `name #id · unit · type · style`, the selected one marked `>` |
| 11 | `select id-or-name` | host | `NS.State.SetActiveContainer(id)`; name match is case-insensitive, and a name more than one container shares is refused (below) |
| 12 | `new [words]` | host | `ContainerManager.Create(overrides)` then selects it; `Create` refuses in combat and the refusal prints gray |
| 13 | `delete id-or-name` | host | `ContainerManager.Delete(id)`; refused in combat with a gray notice; a shared name is refused (below) |
| 14 | `lock` | host | `NS.SetByPath("locked", true)` — also ends preview |
| 15 | `unlock` | host | `NS.SetByPath("locked", false)` — handles and placeholders; the unlocked view is the addon's test mode (no `test` verb, preview-mode's exception, standard v2.49.0) |
| 16 | `pick` | host | Starts `FramePicker` for the selected container; refused in combat |
| 17 | `resetposition` | host | `ContainerManager.ResetPositions()` |
| 18 | `forgettimed` | host | `TimedSpells.Forget()` |
| 19 | `debug [on\|off]` | host | Bare toggles the console window; `on`/`off` go through `NS.DebugLog:SetEnabled` |
| 20 | `perf …` | host | Prints the lines `NS.Perf.OnCommand(rest)` returns (performance-§4); `docs/performance.md` |
| 21 | `version` | host | `v` + `NS.Version()` |

The **Kind** column says who implements the verb, not who gates it — see below.

## While the addon is disabled

`/am disable` stands the addon's **features** down; it does not take the command surface with it
(slash-commands-§2). A verb that **drives those features** answers on one tagged line naming
`/am enable` and does nothing else:

    [AM] Aura Master is off — /am enable turns it back on

Refusing: `new`, `delete`, `lock`, `unlock`, `pick`, `resetposition`, `forgettimed`.

Still answering, always: `help`, `config`, `version`, `enable`, `disable`, `debug`, `perf` and the
schema CLI (`get`, `set`, `list`, `reset`, `resetall`) — a player must be able to read and repair
settings, and reach the panel, while the addon is off, and `enable` above all or the pair is
one-way. `containers` and `select` stay live too, and that is this addon's own addition: almost every
schema path here is container-relative, so those two are how a player aims `get`, `set` and `reset`
at the container they mean. Neither draws, creates or deletes anything.

**The gate is in one place**, `LIVE_WHILE_DISABLED` plus the loop beneath it in `settings/Slash.lua`,
which wraps the handlers in `NS.COMMANDS` once. Both dispatchers — the library's and the degraded
stub's — call `entry[3]`, so one wrap covers both, and a verb added to the table is gated by default
until the live set names it.

### `/am new` words

Any order, any subset, case-insensitive; each word sets one field of the new container
(`NEW_WORDS`, `settings/Slash.lua:228`):

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
(`NS.ActiveContainer`, `settings/Schema.lua:132`). So `/am set container.bars.width 300` means the
same thing on the CLI as the Width slider does in the panel. Every `container.` line `/am list` and
`/am get` print is annotated in gray with the container's name (`cli:SetRowAnnotator`,
`settings/Slash.lua:439`), so a value never reads as the only one. `/am containers` then `/am select`
changes the target.

A Filters category row (`printLabel`) prints the label the Categories grid shows, Show or Hide
(schema v3), with the stored value `/am set` takes after it in gray: `Hide (hide)`. The descriptor's
`format` hook (`formatValue`, `settings/Slash.lua:388`) does it; every other row prints as the
library formats it.

Examples:

```
/am new target debuffs icons
/am select Player buffs
/am set container.filter.castBy mine
/am set container.layout.perLine 8
/am get container.filter.categories.crowdControl
/am reset container.bars.height
```

The whole-set carve-outs (`container.filter.whitelist`, `.blacklist`, and the profile-wide
`categorySpells`) are settable
through the seam but have no row, so `/am list` does not print them; the Filters page is their editor.

## Degraded path

With `LibKa0s-Slash-1.0` absent, `settings/Slash.lua:325` builds a stub dispatcher: the host verbs
keep working (they never went to the library), a bare `/am` runs `config` as the library's does (the
panel's own stub then says the library is missing), `help` prints a plain command list, and `list`, `get`,
`set` and `reset` each print that they are unavailable and why. The stub copies none of the library's
formatting or parsing. `tests/degraded_env.lua` loads the addon that way.

## Adding a verb

The recipe is in `docs/common-tasks.md` → *Add a slash verb*.
