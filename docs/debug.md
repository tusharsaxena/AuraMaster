# Debug surfaces

The debug console is LibKa0s-DebugLog-1.0's (`core/DebugLogSetup.lua` supplies the title, the face
and the `[Init]` summary). `/am debug` toggles the window and `/am debug on|off` switches session
logging. This page covers the one debug surface the addon adds: **the diagnostic report**,
which exactly two forms run: **`/am diagnostics`** and **`/am debug diagnostics`**. There is no
`diag` alias (owner, 2026-09-25): `/am debug diag` toggles the window like any other unknown word.

## What the report does

It writes a one-shot report of what the addon sees and what it drew into the debug console, opens
the console, and prints one chat line with the line count. Press **Copy** in the console and paste
the text into a bug report.

- `diagnostics` is its own verb in `NS.COMMANDS` (23 verbs) and a sub-verb of `debug`. Both answer
  while the addon is disabled: `diagnostics` is named in `liveVerbs()` next to `debug`.
- It writes through the **ungated** `NS.DebugLog:Add`, as debug-logging-§12 requires for an
  explicit diagnostic run. The logging flag is not read and not changed.
- It **appends**. The console keeps the newest 1500 lines, so a long report can push older trace
  lines out. Because it appends after the trace, one Copy carries both: turn logging on with
  `/am debug on`, reproduce the bug, run `/am diagnostics`, then Copy the whole console (the
  README's *Reporting a bug*).
- It is read-only. It writes no setting, requests no apply, and never calls a setter on an engine
  button.
- The body lines are diagnostic English and do not go through `NS.L`, like every trace line. The
  chat line does go through it.
- Without LibKa0s there is no console, so it prints one line saying the report is unavailable.

The code is `modules/Diagnostics.lua`. `NS.Diagnostics.Build()` returns the lines and
`NS.Diagnostics.Run()` writes them.

## Reading the report

Every line is `HH:MM:SS | [Tag] message`. The tags:

| Tag | What it holds |
|---|---|
| `Diag` | Begin and end markers, the version and schema, the state flags, a plain line when the addon is disabled or stood down (below), the apply queue, counts, and any `truncated` or `section ... failed` line |
| `Cfg` | Non-default settings: the profile's own rows, then each container's (`#id non-default:`), filter rows left out because `Filt` prints them in full. A non-default value that does nothing for that container goes on its own `#id inert:` line instead (see below) |
| `Unit` | One header per unit and filter with the aura count, or `none` / `unreadable` / `read failed` |
| `Aura` | One aura: `player+` is a buff, `player-` a debuff; `inst`, `id`, name, `dispel`, `src`, `mine`, `dur`, `left`, `stacks`, `boss`, `steal` |
| `Cont` | One container: id, name, unit, aura type, style, enabled, attach, then its live flags (engine, shows, parked, staleData, classStale, retired engines, enchant frames, dormant, retiring) |
| `Filt` | The container's filters in full: cast by, duration, sort, max, the hidden categories, and the whitelist and blacklist by id and name |
| `Plan` | The plan verdict, then one line per applied engine group (filter, candidate filters, sort, max, `frames=` and `shown=`), then the plan's warnings |
| `Shown` | The shown buttons one by one, then a `predicted:` line per readable aura on the container's unit |

Example (shortened):

```
[Diag] ==== Aura Master diagnostic begin ====
[Diag] Aura Master v0.1.0, schema v11, profile 'Default', client 12.1.0 build 12345 (120100)
[Diag] state: enabled=true stoodDown=false disabledHold=false locked=true testMode=false ...
[Diag] apply queue: all=false ids=[] scheduled=false notice=- mustDefer=false
[Unit] player HELPFUL: 7 aura(s)
[Aura] player+ #1 inst=1234 id=1459 "Arcane Intellect" dispel=nil src=player mine=true dur=3600 left=3412.5 stacks=0 boss=false steal=false
[Unit] focus: none
[Cont] #1 "Player buffs" unit=player HELPFUL style=bars enabled=true attach=screen | engine=yes shows=yes ...
[Cont] #2 "Player debuffs" unit=player HARMFUL style=icons enabled=true attach=container#1 point=TOPLEFT(auto) relPoint=BOTTOMLEFT(auto) join=after-start | engine=yes ...
[Filt] #1 whitelist(1)=[1459 Arcane Intellect]
[Plan] #1 plan in sync
[Plan] #1 g1 "Always shown" filter=HELPFUL cand={includeSpellIDs:1} sort=expirationOnly/normal max=inf frames=3 shown=2
[Shown] #1 g1 btn1 name="Arcane Intellect"
[Shown] #1 predicted: 1459 Arcane Intellect -> shown (rank 1 whitelist)
[Diag] ==== end: 143 line(s) ====
```

A container attached to another container prints its join after the target (batch 11 G7): the two
points in effect, this container's (`point`) and its parent's (`relPoint`), each `(auto)` while
Automatic or `(picked)`, and `join=`, the batch 9 side the pair is under the parent's growth
(`after-start` and the like, `Anchors.AttachEdge`) or `free` for any other pair.

### The plan verdict

The verdict compares the plan the container is running with the plan its settings compile to now,
and checks the apply queue:

- **`plan in sync`**: the running plan is what the settings say. This covers filters only. A
  deferred look or layout change shows up in the apply queue line instead.
- **`PENDING (combat|secret|scheduled|deferred)`**: the settings changed and the apply is queued. It
  runs when combat or aura secrecy ends, or on the next frame.
- **`DRIFT: settings changed but no apply was requested`**: the settings changed and nothing is
  queued. This is a bug in the apply path. Report it.
- **`not built (<reason>)`**: the container has no engine plan, and the reason says why (batch 10
  F8): `addon disabled` (`/am disable`, or a login with the addon switched off), `addon stood down:
  <holds>` (a hold other than the player's switch, such as a perf capture's `perf`), `no aura
  container API` (the client has no aura engine), `no instance` (the manager holds none for it:
  parked or retired), or `not applied yet` (its first apply has not run).

### A disabled or stood-down addon

While the addon is not running, the header adds one plain line after the state flags, so
`enabled=false stoodDown=true` does not read as a fault (batch 10 F8):

- `[Diag] addon disabled: containers are not built; predictions only`: a login made while the
  addon was off built no container, so every `Plan` verdict is `not built (addon disabled)` and
  the `Shown` section holds only the `predicted:` lines.
- `[Diag] addon disabled: containers are hidden and not updated; the plan lines are from the last
  apply`: the addon was switched off after it had built them.
- A stand-down that is not the player's switch names its holds instead: `addon stood down (holds:
  perf): ...`.

### `frames=`, `shown=`, `id=?` and `predicted`

- `frames=` is how many buttons the engine made for the group and `shown=` is how many of them are
  showing. `?` means the value could not be read. Out of combat an engine button can still answer
  its shown state as a secret (docs/midnight-quirks.md), so `shown=2+1?` means two buttons are
  showing and one could not be judged; `shown=?` means none could. A button that cannot be judged
  is still listed in `Shown`, as `btn<n> shown=? ...`.
- A shown button is named by the aura instance the engine exposes, if it does. Otherwise it is named
  by the name or icon our own regions display, and `id=?` when neither can be read (an Icons
  container shows no name).
- `id=? (probe failed: ...)` means reading the button raised; the report goes on.
- `predicted` runs `FilterCompiler.ExplainSpell` over each readable aura. It is approximate: it
  reasons only about spell-list categories and the whitelist and blacklist. Cast by, duration,
  token, flag and dispel categories, and the friend or foe id rule, are decided by the engine.

### `non-default:` and `inert:`

A container's `Cfg` lines list only the settings that differ from the defaults. A value that does
nothing for that container right now is kept off the `non-default:` line and printed on an `inert:`
line of its own, which is left out when there is none:

- a setting in a Layout > Anchor subsection that is not the one in use: the screen position of a
  container attached to another, or the attach target and offsets of a container on the screen;
- a setting on a style page that is not the container's style: the Text page's Size to fit on a bars
  or icons container.

Inert values are listed rather than dropped because some come back into use: a stale attach offset
applies again once the container is attached.

## Combat and secret auras

While auras are secret (any combat, an encounter, a keystone, a PvP match), every aura read raises
and so does touching an engine button. Out of combat, with auras readable, an engine button's shown
state can still be secret; the report tests every value it reads off a button before comparing it,
and prints `?` for one it cannot read. So while auras are secret:

- no aura API is called: each unit that exists prints `unreadable`;
- no button is touched: `shown=?`, and the `Shown` section prints one `skipped` line;
- only the engine's per-group frame count is read.

Every field is stringified through `NS.SafeToString`, `left` is computed only from readable
numbers, and each section runs under `pcall`, as does each plan group, each group's button listing
and the predictions, so one failure prints `section ... failed` and the report goes on. For the full picture, run it out of combat.

## Caps

The report stops short of the console's 1500-line buffer, so Copy always starts at the begin
marker:

- at most 1200 lines in all;
- at most 100 auras per unit and filter;
- at most 40 ids per list, whitelist, blacklist, shown buttons and predictions each.

When a cap cuts something, the report ends with `[Diag] truncated: N line(s) omitted`.
