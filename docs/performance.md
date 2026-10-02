# Performance

How much Ka0s Aura Master costs, how to measure it, and what the measurements can and cannot see
(performance). The harness is wired; this is the addon's own page. The shared protocol, the record
schema and the step panel belong to `LibKa0s-Perf-1.0` and are documented with the library.

## Where the cost is — and where it is not

Most of the work of showing auras is **not this addon's code**. Every container is a Blizzard aura
engine that handles `UNIT_AURA` for its unit, gathers and sorts auras, lays out buttons and animates
every bar, countdown and swipe in Blizzard's own code. The addon has **no per-aura Lua path while
auras are secret**: no ticker and no `OnUpdate` driving a display. Its one aura-driven path while locked is the
readable-state timed-spell scan, bracketed `timedScan` (below). A second runs only while containers
are unlocked out of combat: the empty-container prediction, bracketed `emptyPass`. What remains is
configuration work, and one path that runs on ordinary play (a target, focus or pet change).

Other timers and frames of the addon's own: a next-frame `C_Timer.NewTimer(0)` that coalesces applies
(`modules/ContainerManager.lua:191`), the half-second timed-spell scan timer, armed by a player or pet
`UNIT_AURA` only while a container uses "only auras without a duration" and auras are readable, and
the frame picker's `OnUpdate`, which runs only while a pick is in progress. While containers are
unlocked out of combat and test mode, `modules/EmptyWatch.lua` adds a 0.2 s pass timer, armed by a
`UNIT_AURA` on a watched container's units, and one timer at the soonest weapon enchant's expiry.
The font primer arms two one-shot timers only when it has drawn a new font (below). The weapon-enchant
reset keeps one debounced timer, armed 1.75 s after each loading screen and 0.5 s after an equipped
weapon's item data arrives; when it fires it sends two `SetEnabled` calls to each live engine with
enchant slots. Its item events fire for every item the client loads and cost two
`GetInventoryItemID` reads each. Every timer keeps its handle, and a stand-down cancels it rather
than leaving it armed.

### The font primer's cost

`modules/FontPrimer.lua` hears no event and runs no aura-driven path. It runs at login and stand-up,
on a settings write and on a profile or registry change, and then only walks the containers' seven
text blocks and resolves each font (`Style.FontKey`), which allocates nothing for a triple already
primed. A triple it has not drawn this session costs one font string on its own frame, one `SetFont`
and one `SetText`; they are kept, so each triple is paid for once per session, and a profile drawing
only in the client's own fonts pays nothing at all. A priming that drew something shows the frame
for 1 s and 0.5 s later runs one `UpdateAllAuras` per shown container (the same call a target swap
makes), then one system apply of every container (`CM.RequestApply(nil, true)`, counted in
`applyPass`) for the text the addon writes itself. A priming under the loading screen pays the same once, counted from the loading screen's end
(`LOADING_SCREEN_DISABLED`) instead (the refresh at 1.5 s, the hide at 2 s);
`FontPrimer.OnEnterWorld` reads the clock and scans the short rejected-events list, and
`FontPrimer.OnLoadingScreenEnd` otherwise runs one priming pass (the walk above) and reads two flags, so a loading screen with nothing newly primed costs one walk more.
A font the client refuses at `SetFont` (FP-07) keeps the one font string it was first tried on and
costs one `SetFont` per later priming until the client accepts it; a triple refused again allocates
nothing. The mark it reads is
cleared only by a loading screen, so the first loading screen after a font change in play runs the
refresh once more. It has no bucket: it runs a handful of times a session and never in response to play, so
there is nothing a capture's arms could compare.

### The empty-container watcher's cost

`modules/EmptyWatch.lua` hears `UNIT_AURA` on two private frames (player and pet, target and focus),
through `RegisterUnitEvent`, only while unlocked, out of test mode, out of combat and while auras are
readable, and only for the units of a shown container. Locked, which is how the addon is played, it
registers nothing, so its cost is **zero**. Registered, each event costs one `OnEvent` call that marks
a pass due, with no allocation; the first arms the 0.2 s pass and the rest fall on its latch. A
target or focus switch runs the pass at once instead, one per switch. Offline
(`emptyWatchAura`): 0 B/iter. The pass itself (`emptyPass`) reads each watched container's auras
through `C_UnitAuras`, which allocates the client's `AuraData` tables for a group with candidate
filters, and re-runs the visibility pass of a container whose answer changed.

### The view frame's cost

`modules/ContainerManager.lua` hears `UNIT_FACTION` and `UNIT_FLAGS` on one private frame,
`CM.viewFrame`, registered with `RegisterUnitEvent` for `target` and `focus` only, and on a second,
`CM.viewPlayerFrame`, for `player` only (mind control moves the player's side), whenever the
manager is listening: locked too, unlike EmptyWatch, because a view must follow a duel or a mind
control in combat. `UNIT_FLAGS` fires often in play (a combat flag changing is enough). Each event
costs one walk over `CM.instances` (two for a `player` event, one per unit) and, per container on
that unit, the `pcall`'d
`UnitIsPlayerControlledOrGroupMember` and `UnitCanAssist` reads that resolve its view. When the view
holds, nothing is sent to the engine and nothing is allocated; when it moves, each group whose view
values differ gets its setters, and EmptyWatch re-predicts (its own gates apply).

### The timed-spell listener's cost

`modules/TimedSpells.lua` hears `UNIT_AURA` on the module's one private frame, `TS.unitFrame`,
registered with `RegisterUnitEvent` for `player` and `pet` only (events-frames-taint-§1's carve-out;
the vendored AceEvent has no `RegisterUnitEvent`). The client drops every other unit's event, raid
members and nameplates included, before any Lua runs.

- **The gate bounds it.** `UNIT_AURA` is registered only while a container needs the scan, the addon
  is not suspended, there is no combat lockdown and auras are not secret. `PLAYER_REGEN_DISABLED`
  drops it on the event itself, because the client fires it before its lockdown begins and
  `InCombatLockdown()` still reads false in the handler. In combat and in every
  secret stretch (encounters, keys, PvP matches, restricted maps) it is not registered at all, so the
  cost there is **zero**.
- **Registered and readable, each event costs** one `OnEvent` call, one `Secrets.IsSafeKey` and one
  string compare (kept as defense in depth), with no allocation, and only for the player's and pet's
  own aura changes. The first arms the 0.5 s scan; the rest fall on its latch. Offline
  (`unitAuraFiltered`): 0.00027 ms/iter, 0 B/iter on the development machine.
- **The volume is now the player's and pet's.** Before this frame (AuraMaster-R-03) the listener
  heard every unit's `UNIT_AURA`, which in a city or a raid group between pulls can exceed the ~1000
  events/min guide figure (events-frames-taint-§1). The in-game figure is recorded below.

| Where | Out-of-combat `UNIT_AURA`/min (`/etrace`) | Recorded |
|---|---|---|
| City, or a raid group between pulls, with a "without a duration" container enabled | _not yet measured_ | — |

## Buckets

Declared in report order in `buckets` (`core/PerfSetup.lua:48`), each bracketed with the inline gated form
(`local t0 = Perf.on and debugprofilestop()`, performance-§2) at a load-time `local Perf = NS.Perf`.

| Bucket | Declared parent | Bracket | Why it is bracketed |
|---|---|---|---|
| `unitSwap` | — | `core/AuraMaster.lua:169`, `:176` | The one path driven by play: target, focus or pet changed, so every container on that unit calls the engine's `UpdateAllAuras`. On a target or focus swap the bracket first spans `CM.ApplyViews` (`modules/ContainerManager.lua:429`): each container whose view moved calls the engine's `SetAuraGroupFilterString` and `SetAuraGroupCandidateFilters` per group, each ending in its own `UpdateAllAuras`. It switches quietly: no `emptyPass` runs inside the bracket, because EmptyWatch re-predicts from its own swap handler (see that row). Whatever the engine does synchronously inside these calls lands here |
| `applyPass` | — | `modules/ContainerManager.lua:358-366` | The coalesced pass applying pending configuration to every dirty container, plus re-placing container-attached ones |
| `applyContainer` | `applyPass` | `modules/Container.lua:474-520` | One container: compile, place, build or update the engine, restyle, visibility. The call site passes `"applyPass"`, so the record carries observed containment |
| `visibilityPass` | — | `modules/ContainerManager.lua:385` | The show ladder over every container, on combat transitions, world entry and the master rows |
| `styleElement` | — | `modules/Style.lua:844-854` | Dressing one bar, icon or line of text: called by the engine's `initializeFrame` as it creates buttons, by a restyle, and by the preview |
| `timedScan` | — | `modules/TimedSpells.lua` `scanTick` | One readable-state scan of the player's and pet's buffs, 0.5 s after their auras changed or the readable gate reopened. The addon's only aura-driven Lua path while locked; absent from a capture with no "without a duration" container |
| `emptyPass` | — | `modules/EmptyWatch.lua` `runPass` | One re-prediction of every unlocked container, and the visibility pass of any whose answer changed: 0.2 s after its units' auras changed, or at once on a target or focus swap or when a container's view moved (`EW.OnViewsMoved`). Declared at the root because its callers differ (the timer, EmptyWatch's swap handler, a reaction-change view switch). It never runs inside `unitSwap`: `OnUnitSwap` moves the view quietly, and EmptyWatch's own swap handler runs the one pass for the swap, whichever handler AceEvent calls first. Only while unlocked, out of test mode and out of combat; absent from a capture taken locked |

**Never sum `applyPass` and `applyContainer`**: the parent already contains its children
(performance-§3). `unitSwap` and `emptyPass` are disjoint: a swap costs one
`emptyPass`, outside the `unitSwap` bracket, whichever of the two swap handlers AceEvent calls first
(it walks them in no set order). When EmptyWatch's runs first it moves the view itself, and
`unitSwap` then finds the view already right. A view switch on a reaction change (`UNIT_FACTION` or `UNIT_FLAGS` for `target` or
`focus`, `modules/ContainerManager.lua:771`, or for the player, on `CM.viewPlayerFrame`) runs **unbracketed**: its setter calls land in no bucket,
and only the `emptyPass` it triggers is recorded, at the root. **`styleElement` is declared at the root because its callers differ**, and it
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

Arm B suspends the addon without a reload (performance-§6), and **it is not a mechanism of the perf
module's own**: the probe takes the `perf` hold on the addon's one latch, and the addon goes down the
same way it goes down when a player unticks *Enable Aura Master* (slash-commands-§7,
`docs/data-flow.md` → *The disabled state*). A second teardown path beside this one is
anti-pattern #85's last clause — two mechanisms that must agree about what inert means and diverge
on the first module added after the second was written.

So `standDown` (`core/LifecycleSetup.lua:116`) calls `addon:UnregisterLifecycleEvents()` — the eleven
events `core/AuraMaster.lua` registers — then `NS.TimedSpells.StandDown()`, which drops TimedSpells'
own `UNIT_AURA`, its three gate events and its two bus subscriptions, `NS.EmptyWatch.Stop()`,
`CM.StopListening()` (which also stops the font primer, `FontPrimer.Stop`), `FramePicker.Stop()`,
then the combat-restricted half (Blizzard frames handed back and a visibility pass), held for
`PLAYER_REGEN_ENABLED` when combat refuses it. `Container:ShouldShow` checks **the latch** as step 0, so
every engine is disabled and nothing — a combat transition, a target swap, a settings change — can
enable one behind it, and `CM.RequestApply` arms no timer. `standUp`
(`core/LifecycleSetup.lua:151`) re-registers the events, subscribes again, builds any container
the addon never built while down, moves target and focus containers to the view their unit's reaction
picks now (before any engine is re-enabled), and re-applies every container from the settings **as they are
then**, never a snapshot. `NS.Perf.suspended` still reads true through the whole of arm B — the
field is now the latch's answer to `IsHeld("perf")` rather than a boolean beside it — and the hold is session-only.

**Releasing the `perf` hold does not stand up an addon the player also disabled**, and that is the
whole reason the latch exists: `/am disable` is live during a capture, so without it a resume at the
end of the run would bring the addon back under a player who had switched it off.

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
| `restyleText` | A same-shape re-dress of the Text starter with ten live buttons: it must build no frame, and its Size to fit (batch 8, AS-2) must answer from the memo, measuring no string. The runner's hidden measuring string answers a readable width, as the client's does, so the loops measure the steady path rather than a failed measure that is never remembered |
| `visibilityPass` | The show ladder over every container (`ContainerManager.ApplyVisibility`) |
| `unitSwap` | A target change refreshing the containers on that unit |
| `probeOverheadOff` | The hottest bracketed path with capture off |
| `probeOverheadOn` | The same path with capture on, for orientation; must make the same engine calls |
| `probeAbsent` | The same bodies with no brackets at all. `probeOverheadOff` must match its engine calls and allocate no more, which is the evidence that a dormant bracket costs nothing (performance-§9) |
| `unitAuraFiltered` | TimedSpells' unit frame, dispatched as the client does from its `RegisterUnitEvent` unit list: a `nameplate1` `UNIT_AURA` must never reach the handler, which must be registered for exactly `player,pet`; the measured loop is a player `UNIT_AURA` with its scan already queued, which must allocate 0 B/iter and arm no further timer |
| `emptyWatchAura` | EmptyWatch's player frame: nothing registered while locked; unlocked, a player `UNIT_AURA` with the pass already queued must allocate 0 B/iter and arm no further timer |

**The `compile` figure tracks the size of the spell lists wherever the categorized union is built.**
`categorizedUnion` copies every `spells`-kind category's ids, so each list the curation adds costs
bytes on every compile that builds it. SID-16 (`d0c01f1`, the schema v7 category restructure) took
`compile` from 22200 to 42744 B/iter and `applyPass` from 118147 to 163616, because its lists grew while the
union was built on every compile, whether or not anything read it. AM-ATS-01 builds it only where the `hasUnion` gate can read it (a container
with a Hide, on a unit whose ids are certain), and that brought the figures to 3576 and 104403. The
change left every plan identical. If `compile` climbs again, look first for a per-compile copy of a
spell list.

**What the offline runner cannot see.** The mock engine is a recorder: it logs the calls this addon
makes and does none of Blizzard's work. So the runner measures this addon's Lua and the calls it
makes, and nothing about gathering, sorting, drawing or animating auras. That half is only visible in
game, in the frame-time arms.

## Complexity

The static half of "what does it cost" — where the code is getting hard to change — is the `lizard`
run in every automated-test bundle (performance-§10), tracked in `docs/automated-tests/RESULTS.md`'s
watch list. The release tag requires zero functions above CCN 15 (automated-tests-§3).
