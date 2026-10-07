# Slash dispatch

`/am` and its long form `/auramaster`. Required because `NS.COMMANDS` carries 25 commands, over the
eight-or-more trigger (documentation-§3).

## Registration and dispatch

- **Registration** is AceConsole's `RegisterChatCommand`, twice, in `Slash.Register`
  (`settings/Slash.lua:650`), called from `OnInitialize`. There is no `SLASH_*` global. It is
  **never torn down**, which is what makes `enable` and `disable` a pair rather than a one-way
  door: every verb still answers while the addon is disabled (slash-commands-§2). The chat command,
  the dispatcher and `NS.COMMANDS` are **setup, not features**, so the stand-down does not reach
  them (slash-commands-§7).
- **Dispatch** is `LibKa0s-Slash-1.0` (slash-commands-§1), built from a descriptor at the bottom of
  `settings/Slash.lua`. The library trims the message, lowercases only the verb (paths are
  case-sensitive, and a color is several tokens), maps aliases, finds the verb in `NS.COMMANDS` and
  calls its handler with the rest of the line. A bare `/am` (empty, or only spaces) runs the
  `config` verb with an empty rest, so it opens the settings panel on its landing page, or prints the
  same combat refusal `config` does (slash-commands-§4, LibKa0s Slash minor 11). `/am help` prints
  the list. An unknown verb prints the library's unknown-command line and then help.
- **Aliases:** `options` → `config`.
- **Three verbs have a second caller.** `enable`/`disable`, `lock`/`unlock` and a bare `test` run
  through `Sl.SetEnabled`, `Sl.ToggleLock` and `Sl.ToggleTestMode`, published for the launcher's
  right-click menu (`core/LauncherSetup.lua`, launcher-§2), so the menu's *Enabled*, *Locked* and
  *Test mode* entries run the verb's own handler and print the verb's own line; the *Test mode*
  checkbox, the verb and the menu entry are three doors onto one `Preview.SetTestMode`.
- **One path is not the profile's.** The Minimap button row's CLI path is `global.minimap.shown`,
  which reads in the row's sense: `/am get global.minimap.shown` answers true while the button
  shows, and `/am set global.minimap.shown false` hides it. The storage is LibDBIcon's own
  `global.minimap.hide`, inverted once in `settings/Schema.lua` (launcher-§3); the storage key is
  not a path, so `/am get global.minimap.hide` answers `Setting not found`.
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
| 7 | `set path value` | library | `cli:CliSet` → type-aware parse (a string row takes the whole rest of the line, trimmed; the descriptor's `parse` hook, `parseValue`, first hands the text to a row's own `cliParse`, which the two anchor-point rows use to take the nine point names in any case or `auto`, batch 11 G7) → `NS.SetByPath(path, value)`; a refusal (`false, err, why`) is returned whole and the library prints it as `Invalid value for <path>` with the reason indented under it, no echo (LibKa0s-Slash minor 15) |
| 8 | `reset path` | library | `cli:CliReset` → `NS.ApplyDefault(row)`; takes a path, never a page. A `noReset` row (`container.name`) answers false, and the library prints `<path> has no default to restore` instead of an echo. Only that row does: a seam refusal (no container yet) prints the seam's reason from the descriptor, then the library's echo |
| 9 | `resetall` | host | `NS.Helpers.RestoreAllDefaults()` — the profile reset (options-ui-§12); not refused in combat, where it takes the parked teardown like Profiles → Reset Profile |
| 10 | `profile [name]` | library | `cli:CliProfile(rest)` over the descriptor's `profiles` (`NS.db`): bare lists the profiles, current marked; a name (one pair of quotes stripped, case and spaces kept) switches to that existing profile through `NS.db:SetProfile`, whose `OnProfileChanged` runs `NS.OnProfileChanged` and its one `[Profile]` line; the current name answers `Already on profile`, an unknown name is refused with a did-you-mean and the list and never created, and a switch in combat is refused (LibKa0s-Slash minor 17; `docs/profiles.md`) |
| 11 | `containers` | host | Under a `Containers` heading, one line per container: `name  #id - unit - type - style` (the `#id …` fields gray, ` - disabled` appended for a disabled container), the selected one marked `>` |
| 12 | `select id-or-name` | host | `NS.State.SetActiveContainer(id)`; `#N` is always the id, otherwise an exact name (case-insensitive) wins over a bare number's id, and a shared name or a bare number that is one container's name and another's id is refused (below) |
| 13 | `new [words]` | host | `ContainerManager.Create(overrides)` then selects it; `Create` refuses in combat and the refusal prints gray |
| 14 | `delete id-or-name` | host | `ContainerManager.Delete(id)`; refused in combat with a gray notice; resolves like `select`: `#N` is always the id, a name wins over a bare number's id, and a shared name or a name/id cross-match is refused (below) |
| 15 | `lock` | host | `NS.SetByPath("locked", true)` — hides the handles and outlines |
| 16 | `unlock` | host | `NS.SetByPath("locked", false)` — each container's handle and a faint outline; live auras keep drawing |
| 17 | `test [on\|off]` | host | Bare toggles test mode, `on`/`off` set it, through `Preview.SetTestMode`: placeholder auras on every container; a start in combat is refused on one gray line, and any other word prints `Usage: /am test [on\|off]` |
| 18 | `pick` | host | Starts `FramePicker` for the selected container; refused in combat |
| 19 | `resetposition` | host | `ContainerManager.ResetPositions()` |
| 20 | `forgettimed` | host | `TimedSpells.Forget()` |
| 21 | `redraw [light\|full]` | host | `runRedraw`: `light` → `ContainerManager.RedrawLight()`, every live engine turned off and on again now (`ContainerClass:Flip`), in combat and while auras are secret too; `full` → `ContainerManager.RedrawFull()`, `FontPrimer.PrimeAll()`, the same flip, then `RequestApply(nil, true)`, whose apply re-dresses every button in place; when `CM.MustDefer()` holds, the line says the re-dress waits and `CM.NoteDeferred()` prints the usual deferral notice once per blocked stretch. Bare runs `full` unless `CM.MustDefer()` holds, then `light` plus a line saying a full one waits. While the addon is stood down (a perf capture's `perf` hold), `RedrawFull` answers nil and the line says the full redraw was skipped; `light` flips nothing and reports 0. Any other word prints `Usage: /am redraw [light\|full]`. No engine is retired or built (SP-AMX-02) |
| 22 | `debug [on\|off\|diagnostics]` | host | Bare toggles the console window; `on`/`off` go through `NS.DebugLog:SetEnabled`; `diagnostics` runs `NS.DebugLog:RunDiagnostics` (`docs/debug.md`). Any other word, `diag` included, toggles the window: there is no `diag` alias (owner, 2026-09-25) |
| 23 | `diagnostics` | host | `NS.DebugLog:RunDiagnostics()`, the one-shot diagnostic report in the debug console (`docs/debug.md`); the same report as `/am debug diagnostics` |
| 24 | `perf …` | host | Prints the lines `NS.Perf.OnCommand(rest)` returns (performance-§4); `docs/performance.md` |
| 25 | `version` | host | `v` + `NS.Version()` |

The **Kind** column says who implements the verb, not who gates it — see below.

## While the addon is disabled

`/am disable` makes the addon **inert** — every registration gone, every timer canceled, every frame
hidden, nothing written from a game event (slash-commands-§7, `docs/ARCHITECTURE.md` → *The disabled
state*). It does **not** take the command surface with it. A verb that **drives the addon's
features** answers on one tagged line naming `/am enable` and does nothing else:

    [AM] Ka0s Aura Master is disabled — enable it with /am enable

That wording is the **collection's**, not this addon's: `LibKa0s-Slash-1.0` builds it from the
descriptor's `brandName` and `slash`, so eleven addons say it the same way and none of it is an
`L[]` key here.

Refusing: `new`, `delete`, `lock`, `unlock`, `test`, `pick`, `resetposition`, `forgettimed`, `redraw`.

Still answering, always: `help`, `config`, `version`, `enable`, `disable`, `debug`, `perf` and the
schema CLI (`get`, `set`, `list`, `reset`, `resetall`) — **and the bare `/am`, which opens the
settings panel**, in either state. A player must be able to read and repair settings, and to reach
the panel, while the addon is off, and `enable` above all or the pair is one-way. `help` prints its
index in full with the refusal line under the header, because the player has to be able to SEE
`enable` to type it. `containers` and `select` stay live too, and that is this addon's own addition:
almost every schema path here is container-relative, so those two are how a player aims `get`, `set`
and `reset` at the container they mean. Neither draws, creates or deletes anything. `diagnostics` is
the third addition: like `debug` it is a diagnostic, not a feature, and the report is most wanted
when something is misbehaving. `profile` is the fourth: the library does not reserve it, so the host
names it, and a switch to a profile where the addon is on is how a disabled player brings it back
(`NS.OnProfileChanged` re-reads the latch).

**The gate is the library's**, closed by the descriptor's `isEnabled` (`NS.EnabledStored`, the one enabled predicate `core/LifecycleSetup.lua` publishes) at the bottom of
`settings/Slash.lua`, with `liveVerbs` naming the live set as data. There is no wrapper around the
verb table and no per-verb guard: a verb added to `NS.COMMANDS` refuses by default until
`liveVerbs()` names it. The degraded stub in the same file carries the same gate over the same
descriptor fields, so a library-less build answers identically.

**Its refusals are logged by the library.** The descriptor's `debug` is the gated sink (LibKa0s-Slash
minor 18): every refusal the dispatcher decides (this gate, an unknown verb, `get` / `set` / `reset`
usage and not-found, a parse or write refusal, the `profile` verb's) writes one
`[Cmd] refused <verb>: <guard>` line to the debug console after its chat line. No host verb logs a
second one, and nothing here matches the gate's chat line to find it (`docs/debug.md` → *Coverage*).

**A green surface is not a stand-down.** Everything in this section is about what `/am` *says*; that
the addon is actually inert is `tests/test_disabled.lua` steps 1–6.

### `/am new` words

Any order, any subset, case-insensitive; each word sets one field of the new container
(`NEW_WORDS`, `settings/Slash.lua:285`):

| Words | Field |
|---|---|
| `player`, `target`, `focus`, `pet` | `unit` |
| `buff`, `buffs` / `debuff`, `debuffs` | `auraType` (`HELPFUL` / `HARMFUL`) |
| `enchant`, `enchants` | a player buff container showing only the Weapon enchants category: `auraType = HELPFUL`, `unit = player`, `filter.categories = Cat.EnchantOnlyStates()` (schema v5; a unit or aura-type word is overridden, so `/am new debuffs enchants` still makes a player buff container: enchants are only ever the player's buffs) |
| `bar`, `bars` / `icon`, `icons` / `text` | `style` |

An unknown word prints `Unknown word 'x' — try /am new target debuffs icons` and creates nothing.

### Names on `select` and `delete`

A name is matched without regard to case. Every write of `container.name` stores a name that is
unique regardless of case, so a match normally finds one container. A profile saved before that rule
can still hold two containers named, say, `Dup` and `dup`. When a name matches more than one
container, the command guesses neither. It acts on nothing and prints
`More than one container is called 'dup' — use its number from /am containers.` Nothing is renamed or
migrated. Addressing the container by its number works as before.

A name may be a bare number, such as `3`, so `findContainer` (`settings/Slash.lua`) resolves the
argument in this order:

1. `#N` (digits after a `#`) is always container number N and is never read as a name, so every
   container can be reached by number.
2. Otherwise an exact name match, without regard to case, wins. A name two containers share is
   refused as above.
3. A bare number that is one container's name and a different container's number is refused, and
   nothing is selected or deleted: `'3' is the name of container #1 and the number of container #3 —
   type #3 for the number.` `delete` cannot be undone, so it never guesses which one was meant.
4. A bare number that no container is named is the container with that number. When the container
   named `3` is also container #3, that container answers.

## Container-relative paths on the CLI

A path beginning `container.` resolves against the **selected** container — the one the settings
banner last chose, or `/am select`, or the first container when nothing has been chosen this session
(`NS.ActiveContainer`, `settings/Schema.lua:199`). So `/am set container.bars.width 300` means the
same thing on the CLI as the Width slider does in the panel. Every `container.` line `/am list` and
`/am get` print is annotated in gray with the container's name (`cli:SetRowAnnotator`,
`settings/Slash.lua:611`), so a value never reads as the only one. `/am containers` then `/am select`
changes the target.

A Filters category row (`printLabel`) prints the label the Categories grid shows, Show or Hide
(schema v3), with the stored value `/am set` takes after it in gray: `Hide (hide)`. The descriptor's
`format` hook (`formatValue`, `settings/Slash.lua:524`) does it; every other row prints as the
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
through the seam but have no row, so `/am list` does not print them; the Filters section is their editor.

## Degraded path

With `LibKa0s-Slash-1.0` absent, `settings/Slash.lua:444` builds a stub dispatcher: the host verbs keep
working (they never went to the library), a bare `/am` runs `config` as the library's does (the panel's
own stub then says the library is missing), `help` prints a plain command list, and `list`, `get`, `set`
and `reset` each print the one library-absent line (`/am set is unavailable: the LibKa0s library did not
load.`). The stub's `CliProfile` and `ProfileSwitch` (the live instance has both from Slash minor 17)
print that line for `/am profile` and switch nothing. The stub copies none of the library's formatting
or parsing; its refusal line for a disabled addon is formatted from `STUB_DISABLED_LINE_FORMAT`, the
library's `DISABLED_LINE_FORMAT` byte for byte, published as `Sl.__stubDisabledLineFormat` in both
builds so `tests/test_surface_parity.lua` pins it to the live major. `/am enable`, `/am disable`,
`/am lock` and `/am unlock` still store their paths in that build through `NS.WRITE_THROUGH`
(`docs/settings-panel.md`, *The degraded panel*). `tests/degraded_env.lua` loads the addon that way.

## Adding a verb

The recipe is in `docs/common-tasks.md` → *Add a slash verb*.
