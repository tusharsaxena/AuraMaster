# Performance

How much Ka0s Aura Master costs, how to measure it, and what the measurements can and cannot see
(performance). The harness is wired; this is the addon's own page. The shared protocol, the record
schema and the step panel belong to `LibKa0s-Perf-1.0` and are documented with the library.

## Where the cost is — and where it is not

Most of the work of showing auras is **not this addon's code**. Every container is a Blizzard aura
engine that handles `UNIT_AURA` for its unit, gathers and sorts auras, lays out buttons and animates
every bar, countdown and swipe in Blizzard's own code. The addon has **no per-aura Lua path while
auras are secret**: no ticker and no `OnUpdate` driving a display. Its one aura-driven path is the
readable-state timed-spell scan, bracketed `timedScan` (below). What remains is configuration work,
and one path that runs on ordinary play (a target, focus or pet change).

Other timers and frames of the addon's own: a next-frame `C_Timer.After(0)` that coalesces applies
(`modules/ContainerManager.lua:149`), the half-second timed-spell scan timer, armed by a player or pet
`UNIT_AURA` only while a container uses "only auras without a duration" and auras are readable, and
the frame picker's `OnUpdate`, which runs only while a pick is in progress.

### The timed-spell listener's cost

`modules/TimedSpells.lua` hears `UNIT_AURA` through AceEvent on its own target (events-frames-taint-§1).
The vendored AceEvent has no `RegisterUnitEvent`, so the event arrives bare, for every unit, raid
members and nameplates included, where a private frame's unit-filtered registration would have let
the client drop them.

- **The gate bounds it.** `UNIT_AURA` is registered only while a container needs the scan, the addon
  is not suspended, there is no combat lockdown and auras are not secret. `PLAYER_REGEN_DISABLED`
  drops it on the event itself, because the client fires it before its lockdown begins and
  `InCombatLockdown()` still reads false in the handler. In combat and in every
  secret stretch (encounters, keys, PvP matches, restricted maps) it is not registered at all, so the
  cost there is **zero**.
- **Registered and readable, each event costs** one AceEvent dispatch, one `Secrets.IsSafeKey` and
  one string compare, with no allocation. Only a player or pet event arms the 0.5 s scan.
- **The volume is not bounded.** In a city, or a raid group between pulls, out-of-combat `UNIT_AURA`
  can exceed the ~1000 events/min guide figure (events-frames-taint-§1). The work per event is small
  and fixed; the in-game figure is recorded below.

| Where | Out-of-combat `UNIT_AURA`/min (`/etrace`) | Recorded |
|---|---|---|
| City, or a raid group between pulls, with a "without a duration" container enabled | _not yet measured_ | — |

## Buckets

Declared in report order in `core/PerfSetup.lua:47`, each bracketed with the inline gated form
(`local t0 = Perf.on and debugprofilestop()`, performance-§2) at a load-time `local Perf = NS.Perf`.

| Bucket | Declared parent | Bracket | Why it is bracketed |
|---|---|---|---|
| `unitSwap` | — | `core/AuraMaster.lua:90`, `:98` | The one path driven by play: target, focus or pet changed, so every container on that unit calls the engine's `UpdateAllAuras`. The bracket spans that call, so whatever the engine does synchronously inside it lands here |
| `applyPass` | — | `modules/ContainerManager.lua:257` | The coalesced pass applying pending configuration to every dirty container, plus re-placing container-attached ones |
| `applyContainer` | `applyPass` | `modules/Container.lua:309` | One container: compile, place, build or update the engine, restyle, visibility. The call site passes `"applyPass"`, so the record carries observed containment |
| `visibilityPass` | — | `modules/ContainerManager.lua:270` | The show ladder over every container, on combat transitions, world entry and the master rows |
| `styleElement` | — | `modules/Style.lua:304` | Dressing one bar or icon: called by the engine's `initializeFrame` as it creates buttons, by a restyle, and by the preview |
| `timedScan` | — | `modules/TimedSpells.lua` `scanTick` | One readable-state scan of the player's and pet's buffs, 0.5 s after their auras changed or the readable gate reopened. The addon's only aura-driven Lua path; absent from a capture with no "without a duration" container |

**Never sum `applyPass` and `applyContainer`**: the parent already contains its children
(performance-§3). **`styleElement` is declared at the root because its callers differ**, and it
overlaps two other buckets without saying so: a restyle runs it inside `applyContainer`, and the
preview runs it inside `visibilityPass` or `applyContainer`. Only the calls the engine makes from its
own button creation sit outside every other bracket. Read `styleElement` as the dressing cost wherever
it happened, not as a disjoint slice.

The preview is dressed only when it changed: after an apply of its container's settings, or when it
was hidden and is shown again. A visibility pass alone (a combat transition, the master alpha) leaves
the placeholders as they are, so `visibilityPass` carries preview dressing only on the pass that
first shows it. Dressing itself allocates little. The duration text's formatter and expiring-color
curve, and a bar's dispel color map, are built once for each distinct format, threshold or set of
colors and handed to every button of that look (`modules/Style.lua`), not built again per button per
dress.

## Taking a capture

`/am perf` with no sub-verb prints the current phase and opens the library's step panel, which only
offers the next legal step. The sub-verbs, as the library lists them:

| Command | Effect |
|---|---|
| `/am perf start [label]` | Begin a run out of combat; records who and where you are |
| `/am perf measure a` | Arm experiment A — the addon active; records only while combat lasts |
| `/am perf measure b` | Arm experiment B — the same, with the addon suspended first |
| `/am perf finish` | End the run and save it to `AuraMasterPerfDB`; prints nothing |
| `/am perf cancel` | Abandon a run in flight, unsaved, and restore the addon |
| `/am perf report` | Print the summary and the JSON line to copy; opens the log window |
| `/am perf show` / `hide` / `toggle` | Drive the step panel without touching the run |

**Protocol** (performance-§7): disable every other addon, pick a repeatable fight (a training dummy,
same spec, same rotation), run arm A then arm B back to back in the same session with no `/reload`
between them. Keep the capture: copy the report and the JSON out of the debug console and record it
as described in `docs/perf-analysis/README.md`.

### Suspend

Arm B suspends the addon without a reload (performance-§6). `suspend` (`core/PerfSetup.lua:70`)
calls `addon:UnregisterLifecycleEvents()` — the eight events `core/AuraMaster.lua` registers — then
`NS.TimedSpells.Stop()`, which drops TimedSpells' own `UNIT_AURA` and its three gate events, and
runs a visibility pass; `Container:ShouldShow` checks `NS.Perf.suspended` as **step 0**, so every engine is disabled and
nothing — a combat transition, a target swap, a settings change — can enable one behind suspend's
back, and a queued apply waits for resume: `ContainerManager.FlushPending` returns early while
suspended and keeps the pending set. `resume` re-registers the events, calls `NS.TimedSpells.Sync()`, runs a visibility pass and re-applies every container from the
current settings. The suspended flag is session-only.

## Reading the report

- **The buckets are the addon's cost.** Each is `calls`, `totalMs` and `maxMs` of Lua time under the
  bracket.
- **The frame-time delta is unresolved below roughly 0.5 ms/frame** on a 60–80 s arm; below that it
  is noise, not a null result (performance-§8).
- **Expect the engine's cost in the delta, not in the buckets.** The difference between arm A and arm
  B includes Blizzard's own per-aura work for every enabled container, because suspending disables
  the engines. The buckets hold only what the addon's own Lua did.
- A bucket that is absent never fired. `unitSwap` will be absent from a capture on a dummy you never
  retarget; `applyPass` from one where nothing was changed.

## The offline runner

```sh
lua tests/perf.lua
```

A headless scenario runner over the real addon code on the test mock, **outside the green gate**
(testing-§7). It asserts only deterministic quantities — engine and API calls and bytes allocated per
iteration — never wall-clock time, and its timings are for comparing scenarios within one run only.
The vendored runner drives it as the `perf` suite and keeps its output in the run's bundle under
`docs/automated-tests/` (automated-tests-§7).

Every measured loop runs with the garbage collector stopped (a full collect on either side), so
bytes/iter is what the loop allocated and is never negative. The mock engine switches to count-only
while a loop runs: it counts calls by name and does not log them, so its own bookkeeping is not
charged to the addon. Figures from bundles recorded before this change are not comparable.

| Scenario | What it exercises |
|---|---|
| `compile` | `FilterCompiler.Compile` over a representative container |
| `applyPass` | One coalesced apply over the registry (`ContainerManager.FlushPending`) |
| `restyle` | Re-dressing every button of a live engine (`Container:Restyle`) |
| `visibilityPass` | The show ladder over every container (`ContainerManager.ApplyVisibility`) |
| `unitSwap` | A target change refreshing the containers on that unit |
| `probeOverheadOff` | The hottest bracketed path with capture off |
| `probeOverheadOn` | The same path with capture on, for orientation; must make the same engine calls |
| `probeAbsent` | The same bodies with no brackets at all. `probeOverheadOff` must match its engine calls and allocate no more, which is the evidence that a dormant bracket costs nothing (performance-§9) |
| `unitAuraOther` | TimedSpells' `UNIT_AURA` handler for a unit it never scans (`nameplate1`); must allocate 0 B/iter and arm no scan |

**What the offline runner cannot see.** The mock engine is a recorder: it logs the calls this addon
makes and does none of Blizzard's work. So the runner measures this addon's Lua and the calls it
makes, and nothing about gathering, sorting, drawing or animating auras. That half is only visible in
game, in the frame-time arms.

## Complexity

The static half of "what does it cost" — where the code is getting hard to change — is the `lizard`
run in every automated-test bundle (performance-§10), tracked in `docs/automated-tests/RESULTS.md`'s
watch list. The release tag requires zero functions above CCN 15 (automated-tests-§3).
