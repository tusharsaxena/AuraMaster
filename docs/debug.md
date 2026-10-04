# Debug surfaces

The debug console is LibKa0s-DebugLog-1.0's (`core/DebugLogSetup.lua` supplies the title, the face
and the `[Init]` summary). `/am debug` toggles the window and `/am debug on|off` switches session
logging. This page covers the one debug surface the addon adds: **the diagnostic report**,
which exactly two forms run: **`/am diagnostics`** and **`/am debug diagnostics`**. There is no
`diag` alias (owner, 2026-09-25): `/am debug diag` toggles the window like any other unknown word.
The console's title bar also carries the library's orange **Diagnostics** link, just right of the
Debug On/Off label (DebugLog 16); a click runs the same report, `NS.DebugLog:RunDiagnostics()`.
Running the report, by either form or the link, also **turns debug logging on for the session**
(debug-logging-§14, DebugLogDiagnostics 2), as `/am debug on` would; a `/reload` turns it off again.

## What the report does

It turns logging on when it is off, writes a one-shot report of what the addon sees and what it drew
into the debug console, opens the console, and prints one chat line with the line count. Press **Copy** in the console and paste
the text into a bug report.

- `diagnostics` is its own verb in `NS.COMMANDS` (25 verbs) and a sub-verb of `debug`. Both answer
  while the addon is disabled: `diagnostics` is named in `liveVerbs()` next to `debug`.
- It turns logging on for the session first, through the one seam (`NS.DebugLog:SetEnabled(true)`),
  when logging is off, so the `[Debug] logging enabled` line, its chat line and the `[Init]` summary
  land just ahead of the report and the header reads `debug logging: on`. It never turns logging off,
  and with logging already on it writes no second enable line. This addon keeps the library's default
  (its descriptor does not set `diagnosticsEnablesLogging = false`). The sections themselves read
  state only and never touch the flag.
- It writes through the **ungated** append, as debug-logging-§12 requires for an explicit
  diagnostic run.
- It **appends**. The console keeps the newest 3000 lines, so a long report can push older trace
  lines out. Because it appends after the trace, one Copy carries both: turn logging on with
  `/am debug on`, reproduce the bug, run `/am diagnostics`, then Copy the whole console (the
  README's *Reporting a bug*). A report run first leaves logging on, so what follows it is traced
  too.
- It is read-only. It writes no setting, requests no apply, and never calls a setter on an engine
  button.
- The body lines are diagnostic English and do not go through `NS.L`, like every trace line. The
  chat line does go through it.
- Without LibKa0s there is no console, so it prints one line saying the report is unavailable.

The report is built by LibKa0s's diagnostics helper (DebugLog 14.1, debug-logging-§14). The helper
writes the markers, the identity header, the cap and its `truncated` line, runs each section under
its own pcall, and appends the lines. This addon writes only the sections, in `modules/Diagnostics.lua`
(`NS.Diagnostics.Sections()`, handed to the console through the descriptor's `diagnostics` field in
`core/DebugLogSetup.lua`). `NS.DebugLog:BuildDiagnostics()` returns the lines and
`NS.DebugLog:RunDiagnostics()` writes them.

## Reading the report

Every line is `HH:MM:SS | [Tag] message`. The tags:

| Tag | What it holds |
|---|---|
| `Diag` | Begin and end markers, the identity header (version, schema, profile and container count, then the client, locale, debug flag, combat reads and the running LibKa0s minors), the state flags and lifecycle holds, a plain line when the addon is disabled or stood down (below), the apply queue, counts, the fonts the font primer has drawn and any it was refused, and the loading-screen timing line (below), and any `truncated` or `section ... failed` line |
| `Cfg` | Non-default settings: the profile's own rows, then each container's (`#id non-default:`), filter rows left out because `Filt` prints them in full. A non-default value that does nothing for that container goes on its own `#id inert:` line instead (see below) |
| `Unit` | One header per unit and filter with the aura count, or `none` / `unreadable` / `read failed` |
| `Aura` | One aura: `player+` is a buff, `player-` a debuff; `inst`, `id`, name, `dispel`, `src`, `mine`, `dur`, `left`, `stacks`, `boss`, `steal` |
| `Cont` | One container: id, name, unit, aura type, style, enabled, attach, then its live flags (engine, shows, parked, staleData, classStale, retired engines, enchant frames, dormant, retiring) |
| `Filt` | The container's filters in full: cast by, duration, sort, max, the hidden categories, and the whitelist and blacklist by id and name |
| `Plan` | The plan verdict, then one line per applied engine group (filter, candidate filters, sort, max, `frames=` and `shown=`), then the plan's warnings |
| `Shown` | The shown buttons one by one, then a `predicted:` line per readable aura on the container's unit |

Example (shortened):

```
[Diag] ==== Ka0s Aura Master diagnostics begin ====
[Diag] AuraMaster v1.0.1, schema v12, profile 'Default', 4 container(s)
[Diag] client: version=12.1.0 build=12345 date=Sep 1 2026 interface=120100
[Diag] locale: enUS
[Diag] debug logging: on
[Diag] combat: InCombatLockdown=false UnitAffectingCombat=false
[Diag] LibKa0s running: Core 8, Env 1, Compat 1, Lifecycle 2, ...
[Diag] state: enabled=true stoodDown=false disabledHold=false holds=- locked=true testMode=false ...
[Diag] apply queue: all=false ids=[] scheduled=false notice=- mustDefer=false
[Diag] timed spells learned=0, category spell edits in 0 list(s), user categories=0, enchant slots=mainHand
[Diag] fonts primed: 2 [Ka0s Prototype.ttf 10 OUTLINE, Ka0s Kait.ttf 36 THICKOUTLINE] refresh=idle refused=0
[Diag] loading screen: world entered 12.40, ended 17.85 (5.45 s later)
[Unit] player HELPFUL: 7 aura(s)
[Aura] player+ #1 inst=1234 id=1459 "Arcane Intellect" dispel=nil src=player mine=true dur=3600 left=3412.5 stacks=0 boss=false steal=false
[Unit] focus: none
[Cont] #1 "Player buffs" unit=player HELPFUL style=bars enabled=true attach=screen | engine=yes shows=yes ...
[Cont] #2 "Player debuffs" unit=player HARMFUL style=icons enabled=true attach=container#1 point=TOPLEFT(auto) relPoint=BOTTOMLEFT(auto) join=after-start | engine=yes ...
[Filt] #1 whitelist(1)=[1459 Arcane Intellect]
[Plan] #1 plan in sync
[Plan] #1 spell lists: mode=always view=ids situation=-
[Plan] #1 g1 "Always shown" filter=HELPFUL cand={includeSpellIDs:1} sort=expirationOnly/normal max=inf frames=3 shown=2
[Shown] #1 g1 btn1 name="Arcane Intellect"
[Shown] #1 predicted: 1459 Arcane Intellect -> shown (rank 1 whitelist)
[Diag] ==== Ka0s Aura Master diagnostics end: 143 line(s) ====
```

A container attached to another container prints its join after the target (batch 11 G7): the two
points in effect, this container's (`point`) and its parent's (`relPoint`), each `(auto)` while
Automatic or `(picked)`, and `join=`, the batch 9 side the pair is under the parent's growth
(`after-start` and the like, `Anchors.AttachEdge`) or `free` for any other pair.

Each built container's `[Plan] #N spell lists:` line says where Blizzard applies its spell ids
(`mode=`: `always` for buffs on the player and the pet, `never` for their debuffs, `dynamic` for any
other unit, where the unit's reaction decides, `FC.IdsMode`), which view of the plan the engine
holds now (`view=ids`; `view=every`, every aura once through the remainder slot; or `view=blizzard`,
where spell categories and Overrides are not applied and only Blizzard categories set to Show draw),
and the Situations setting that picked a no-ids view (`situation=npcs`, `players`, `unknown` when
the unit's player-ness is not knowable and the stricter setting was taken, or `-` on the ids view).
A trailing `stale=yes` means the engine refused one of the switch's setters (an `[Engine]` line says
which): the view named is the one asked for, and the next switch resends every group in full. Each
group line after it prints that view's filter string and candidate filters, not always the ids view's.
The setting is the container's Filters → Situations tab (On NPCs, On players, or Your own and your
pet's debuffs), and a write there moves the view at once when it changes what the container's current
unit draws, logging one `[Filter]` line (none when the view holds).
See the `[Filter]` tag below for each switch.

### Bar names that do not show

A bar, icon or Text line that draws with no spell name, and often no time or stack count either, is
issue #24. The cause is the font, not the aura data. WoW loads an addon-supplied font file (one a
media pack registers with LibSharedMedia, such as Ka0s Prototype) lazily, and text first drawn in it
before the load completes comes out empty and stays empty until it is written again. The engine writes
a bar's name once, when the aura is assigned or updated, so a name drawn in a font that has not loaded
yet stays blank. A font built into the client (any path under `Fonts\`, such as Friz Quadrata) is
always loaded and never blanks. Drawing the font on a hidden frame does not load it; drawing it on a
shown one does. The measurements are in `docs/midnight-quirks.md` (*An addon font loads lazily, and
the engine writes a name once*) and
`docs/superpowers/research/2026-09-27-blank-bar-names-findings.md` (section *Correction: the real
cause is the font*).

The font primer (`modules/FontPrimer.lua`) is the fix. At login and at every stand-up, before the
first build, it draws every (file, size, flags) triple any container in the active profile uses, on
one shown 1x1 frame above the top edge of the screen, and hides the frame a second later. It does the
same for a new triple before a settings change or a profile switch is applied. When it drew something
new, it asks each shown container to read its auras again half a second later, so text already drawn
in that font before it loaded is written again. The login's priming runs under the loading screen,
where nothing is drawn, so it arms neither: the frame stays shown through the loading screen, and
the re-read runs 1.5 s and the hide 2 s after the loading screen ends (`LOADING_SCREEN_DISABLED`,
which the client fires after `PLAYER_ENTERING_WORLD`, seconds later on a slow or cold-cache login; a
`/reload` likewise). A later loading screen with nothing newly primed does nothing. The header's
`fonts primed:` line shows its state, and the `loading screen:` line under it the timing:

```
[Diag] fonts primed: 2 [Ka0s Prototype.ttf 10 OUTLINE, Ka0s Kait.ttf 36 THICKOUTLINE] refresh=idle refused=0
[Diag] loading screen: world entered 12.40, ended 17.85 (5.45 s later)
```

- The count is every triple drawn this session, and the list gives each by its file's name, size and
  outline flags (`-` for none), in the order drawn, up to 40 (the per-list cap).
- `refresh=` is the follow-up re-read: `armed` (due, after a change in play), `armed-world` (due,
  after the loading screen), `awaiting-world` (fonts primed under the loading screen, the re-read not
  armed until it ends) or `idle` (it ran, or none was needed). `awaiting-world` seen after the loading
  screen has ended means `LOADING_SCREEN_DISABLED` never reached the primer.
- `loading screen:` gives the `GetTime()` of the last `PLAYER_ENTERING_WORLD` and of the loading
  screen's end after it, and the gap between them; `-` for one not seen. `ended -` after the loading
  screen is gone means the end was never heard (a client that refused `LOADING_SCREEN_DISABLED` times
  the world from `PLAYER_ENTERING_WORLD` instead, and the `[Init]` line names the refused event). With
  logging on, each loading screen's end also writes a `[Fonts]` line with both timestamps.
- `refused=` counts the triples whose `SetFont` the client refused and no retry has accepted yet, and
  lists each the same way (`refused=0` for none). A refused triple is not counted as primed: every
  later priming tries it again, and so does the end of every loading screen, on the one font string
  it was first tried on; once the client accepts it, it moves to the primed list and the usual hide
  and refresh follow. `refused=0` with every container font in the primed list is the healthy
  reading. A font that stays on `refused=` after the loading screen has ended and a settings change
  has been made is one the client will not load (`docs/known-limitations.md`). Before FP-07 a refused
  triple was dropped silently and never tried again: the owner's run of 6994c46 read
  `fonts primed: 1 [Ka0s Kait.ttf 36 THICKOUTLINE]` with every Ka0s Prototype triple missing.
- `fonts primed: 0 []` on a profile that uses only built-in fonts is correct: those need no priming.
- The line reads state only, so it prints while auras are secret and while the addon is stood down.

With the trace on (`/am debug on`), each priming that drew anything writes one
`[Fonts] primed N new font(s)` line, and a priming whose refused count differs from the last one
traced writes one `[Fonts] N font(s) refused, retried at the next priming` line (counts only; the
report names them). A priming runs on every settings write, so the same refusal retried through a
slider drag writes nothing more (debug-logging-§9). The trace is off after a login, so the login's
own priming is seen only in the report.

If a blank still shows, run `/am diagnostics` and check that the container's font is in the list. A
font missing from it was registered with LibSharedMedia after login (a media addon loaded on demand),
so it resolved to the fallback when the primer ran (`docs/known-limitations.md`). The next
settings change of any kind primes it, and so does a `/reload`.

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
- `predicted` first checks each readable aura against the container's cast-by and duration
  settings (`hidden (cast by others)`, `hidden (cast by you)`, `hidden (permanent, duration
  filter)`, `hidden (duration 3600s > max 30s)`); an aura that passes both gets
  `FilterCompiler.ExplainSpell`'s spell-list category verdict. A secret source or duration passes
  its check rather than guess, and Timeless mode is left to the category verdict. It stays
  approximate: token, flag and dispel categories, the friend or foe id rule, sorting and the aura
  cap are decided by the engine.

### `non-default:` and `inert:`

A container's `Cfg` lines list only the settings that differ from the defaults. A value that does
nothing for that container right now is kept off the `non-default:` line and printed on an `inert:`
line of its own, which is left out when there is none:

- a setting in a Layout > Anchor subsection that is not the one in use: the screen position of a
  container attached to another, or the attach target and offsets of a container on the screen;
- a setting in a style section that is not the container's style: the Text section's Size to fit on a bars
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

## The event trace

With `/am debug on`, every event that changes what the addon may do leaves one `[Event]` line,
written before the handler acts, so `queued=` is the queue the event found. Each line ends in the
three reads every apply decision turns on: `secret=` (`Compat.AurasAreSecret`), `lockdown=`
(`InCombatLockdown`) and `queued=` (`all`, a container count, or `-`). The `[Apply]` line after it
says what the flush did: `applied N container(s)`, or `deferred: …` when the hold is new or has
changed. A hold that lasts through a key writes its `deferred:` line once, however many combat ends
and restriction flips flush it, and the `applied` line after it is the flush that ended it.

| Event | Line |
|---|---|
| `ADDON_RESTRICTION_STATE_CHANGED` | `[Event] ADDON_RESTRICTION_STATE_CHANGED secret=… lockdown=… queued=… type=<n> active=<0|1|2>` (Enum.AddOnRestrictionState: 0 inactive, 1 active, 2 activating) |
| `PLAYER_ENTERING_WORLD` | `[Event] PLAYER_ENTERING_WORLD secret=… lockdown=… queued=… login=<bool> reload=<bool>` |
| `LOADING_SCREEN_DISABLED` | `[Event] LOADING_SCREEN_DISABLED secret=… lockdown=… queued=…` |
| `PLAYER_REGEN_DISABLED` / `_ENABLED` | `[Event] PLAYER_REGEN_… secret=… lockdown=… queued=…` |

Logging is session-only and off after every `/reload` (debug-logging-§5), so the login itself is
never in the trace. After a mid-key `/reload`, run `/am diagnostics`, which turns it back on as
well: `apply queue: all=false` and `engine=yes` on every `[Cont]` line mean the login
build ran; `all=true` with `mustDefer=true` means it is still waiting.

Target, focus and pet swaps and `ADDON_LOADED` are left out on purpose (owner, 2026-09-29): they
fire too often in a key to read around. So is `ZONE_CHANGED_NEW_AREA`, a border crossing that fires on
every zone border. So are `ITEM_DATA_LOAD_RESULT` and `GET_ITEM_INFO_RECEIVED`,
which fire for every item the client loads. What they can start, the weapon-enchant reset, writes
its own line when it fires: `[Apply] enchants reset on N container(s) after the loading screen` (or
`after item data`), N counting the live containers with enchant slots it turned off and on again
(`docs/midnight-quirks.md` → *Weapon enchants*). A blank enchant name with no such line after the
loading screen means the reset never ran; a line with `0` means no container qualified.
`/am redraw` writes one `[Apply]` line per run as well: `redraw light: N container(s) flipped`, or
`redraw full: N container(s) flipped, re-apply queued` (`deferred` when combat or aura secrecy holds
the re-apply, followed by the queue's own `deferred:` line). A full redraw skipped because a perf
capture stands the addon down writes no line.

## Coverage

What the trace (`/am debug on`) writes, by tag, and when (debug-logging-§8, §9). Every line is gated
and built behind the gate. A path that repeats (a timer, an event that fires through a fight, a
priming on every settings write) writes only when what it reports has changed. The diagnostic
report's own tags (`Diag`, `Cfg`, `Unit`, `Aura`, `Cont`, `Filt`, `Plan`, `Shown`) are above.

**Whose line it is.** The *Writer* column says who writes each tag. A **library** line is written by
a LibKa0s module through the gated sink this addon hands its descriptor as `debug` (LibKa0s v1.65.0,
debug-logging-§4): the Slash dispatcher's refusals (`Cmd`), the Lifecycle latch's edges
(`Lifecycle`), the Options combat lock's refusals (`Cfg`), the Launcher's lines and the console's
own (`Debug`, `Init`). This addon writes no second copy of any of them: its own stand-down and
stand-up lines were retired when the library began writing the edge. The **host** lines are this
addon's.

**The change gates are the console's.** "Once" and "when it changes" (the `Anchor` fallback and
lockdown skip, the `Fonts` refused count, a caught error, a refused Text template) are
`NS.DebugLog.DebugOnce` / `DebugChanged` (DebugLog 18), so a **Clear** of the console, or turning
logging on, re-arms them and the next pass says its line again. The one gate kept here, the apply
queue's hold trace (it compares the hold, not the line, because the edge is in the line), is re-armed
on Clear through the console descriptor's `onClear`. The Launcher's state lines, written at
`OnEnable` while logging is off, are held by the console's at-enable queue and land just after the
`[Init]` summary the first time logging is turned on.

| Tag | Writer | What writes it | When |
|---|---|---|---|
| `Debug`, `Init` | library | LibKa0s-DebugLog-1.0 (`core/DebugLogSetup.lua` supplies the summary) | Logging switched on or off. `[Init]` names the version, schema, profile and container count, then anything a healthy session lacks: rejected events, `LibSharedMedia-3.0 missing`, `no aura container API`, `stood down (holds: …)`. `[Init] event X rejected by this client` when a registration is refused |
| `Event` | host | `core/AuraMaster.lua` | One line per `PLAYER_ENTERING_WORLD`, `LOADING_SCREEN_DISABLED`, `PLAYER_REGEN_DISABLED` / `_ENABLED` and `ADDON_RESTRICTION_STATE_CHANGED`, before the handler acts (the event trace above) |
| `Apply` | host | `modules/ContainerManager.lua`, `modules/BlizzardFrames.lua` | `applied N container(s)` per apply pass that ran; `deferred: secret=… lockdown=… edge=… queued=…` when a hold starts or changes (a Blizzard-frame toggle made in combat included); `Blizzard frames applied after combat` when that held toggle lands; `container #id failed: <error>` once per distinct error an apply raised; the enchant reset and `/am redraw` lines |
| `Lifecycle` | library | LibKa0s-Lifecycle-1.0 (Lifecycle 3), through `core/LifecycleSetup.lua`'s descriptor | Each stand-down and stand-up edge (`/am disable`, `/am enable`, a perf capture), before the callback runs: `stood down: added <hold> (holds: <set>)`, `stood up: released <hold> (holds: none)`. A call that moves no edge writes nothing |
| `State` | host | `core/LifecycleSetup.lua` | The stand-down's secure half only: `stand-down: hiding held until combat ends` when combat refuses it, and `stand-down finished after combat` when it completes (the edge itself is the `Lifecycle` line) |
| `Cmd` | library | LibKa0s-Slash-1.0 (Slash 18), through `settings/Slash.lua`'s descriptor | Every refusal the dispatcher decides, after its chat line: `refused <verb>[ <arg>]: <guard>` for the disabled gate, an unknown verb, `get` / `set` / `reset` usage and not-found, a parse or write refusal, a reset with no default, and the `profile` verb's refusals (in combat among them). A verb's own refusal (`delete refused (in combat)`) is the host's line under its own tag |
| `Set` | host | `settings/Schema.lua` (the write seam), the bulk bracket, the profile callbacks, the user-category writes, `ContainerManager.CopyFrom` | Every stored setting (`<path> = <value>`), every refused one (`<path> refused: <reason>`), one line per bulk copy or reset, a refused copy (`copy … refused at <key>: <reason>`), profile reset and copy |
| `Profile` | host | `core/AuraMaster.lua` | A profile switch |
| `Containers` | host | `modules/ContainerManager.lua`, `settings/Slash.lua`, `settings/Containers.lua` | A container created or deleted; `create refused (in combat)`, `delete refused (in combat)` |
| `Preview` | host | `modules/Preview.lua`, `settings/General.lua` | Test mode switched by `/am test` (or the launcher) or ended by combat, naming who; `test mode refused (in combat)`; `test mode refused (addon disabled)` when the Master controls checkbox asks while the addon is disabled (the seam's `[Set]` line after it records the request, not a stored value). The checkbox is a session row, so its `[Set]` line covers a switch it makes |
| `Anchor` | host | `modules/Anchors.lua`, `modules/Anchors_Snap.lua`, `modules/FramePicker.lua`, `settings/Layout.lua` | A container falling back to the screen, once until it lands again (or the console is cleared); the pending-frame resolve skipped under lockdown, once per fight while one waits; `resolved N pending frame target(s)`; a drag whose position read secret; `attach refused (in combat)`, `attach refused (the target is gone)`, `frame pick refused (in combat)`; a drag lifting an attached container off its parent (`read` or `cursor`), a drag canceled because its strip hid mid-drag, and each drop's outcome (`drop: attach to <id> <point>><relPoint> (<side token, or free>)`, `drop asks first (its flow changes)`, `drop: held (leeway)`, `drop: detach`, `drop: moved`, `drop: held (combat)`, and `drop: N container(s) held by combat re-placed` when combat ends, issue #22); and at each drag's start and drop, what the snap sees: `drag starts: own <l,b,r,t>; targets <id> <l,b,r,t or why not>; …` and `drop <outcome>: …` (the outcome `attach on <id>`, `hold`, `detach` or `nothing in range`; why not: `disabled`, `hidden`, `follows it`, `no rect`), built only while logging is on; and `drag re-placed N container(s) whose rect did not read` when a drag's start re-anchors stale ones |
| `Cfg` | library, host | LibKa0s-Options-1.0 (Options 28, OptionsIdList 3); `settings/OptionsSetup.lua` | The library's: the settings window opened, `open refused (in combat)`, and each act the combat lock refuses on an open panel, once per combat (`write <path>`, `defaults <page>`, `tab <key>`, `button <text>` … `refused (in combat)`), `register parked (in combat)` and `register flushed (combat ended)`; once per id list whose help mark falls back to the client glyph, `help art: no addonName on the Options descriptor; drawing the client glyph` or `help art: addonName "<name>" is not a loaded addon; drawing the client glyph`. The host's: a page open refused in combat (`open <page> refused (in combat)`) |
| `Engine` | host | `modules/Container.lua` | An engine call that raised, once per distinct method and error |
| `Filter` | host | `modules/Container.lua` | A container whose spell lists switched on or off, once per change of view; nothing when the view holds. "on" means Blizzard applies the spell ids, and the reason names the unit's assistability; "off" names the view and the situation that picked it: a target or focus buff container logs `<container>: spell lists on (unit can be assisted)` or `... off, every aura (NPC; unit cannot be assisted)` (`only Blizzard categories set to Show` for the blizzard view; `player`, or `NPC or player not knowable`, for the situation), a target or focus debuff container `... on (unit cannot be assisted)` or `... off, every aura (NPC; unit can be assisted)`, and a player or pet debuff container `... off, every aura (your own and your pet's debuffs)` |
| `Style` | host | `modules/Style.lua`, `modules/Style_Text.lua` | A binding or a guarded dress that raised, once per distinct error; a Text template refused, once per template |
| `Fonts` | host | `modules/FontPrimer.lua` | `primed N new font(s)`; `N font(s) refused` when the refused count changes; each loading screen's end with its timing |
| `Timed` | host | `modules/TimedSpells.lua` | A scan that learned something (`learned N timed spell(s)`); `/am forgettimed` |
| `Migrate` | host | `core/Database.lua`, `defaults/UserCategories.lua` | A schema migration step that ran, a seeded starter set, a stored user category skipped |
| `Launcher` | library | LibKa0s-Launcher-1.0 (Launcher 5), through `core/LauncherSetup.lua`'s descriptor | Its state lines (`LibDataBroker-1.1 absent`, `LibDBIcon-1.0 absent`, no minimap table, `registered`) through the at-enable queue, so they land after `[Init]` the first time logging is turned on; its events at once |
| `Perf` | host | `core/PerfSetup.lua` | A perf capture's report, written ungated because the player asked for it |

Left out on purpose: target, focus and pet swaps, `ADDON_LOADED`, `ZONE_CHANGED_NEW_AREA` (a border
crossing, which fires on every zone border), the item-data events (above), each
`UNIT_AURA` pass of the empty prediction and the timed-spell scan (quiet unless a scan learns
something), and the frame picker's `OnUpdate`. Their effects that matter write their own line.

## Caps

The report stops short of the console's 3000-line buffer, so Copy always starts at the begin
marker. The report always arrives whole; the trace above it keeps whatever the buffer still has
room for.

- at most 1200 lines in all, markers included. The cap is the library's (`DIAG_MAX_LINES`), and it
  always sits at least 100 lines below the buffer;
- at most 100 auras per unit and filter;
- at most 40 ids per list, whitelist, blacklist, shown buttons and predictions each.

When a cap cuts something, the line just before the end marker reads
`[Diag] truncated: N line(s) omitted, per-list caps hit=yes|no`.
