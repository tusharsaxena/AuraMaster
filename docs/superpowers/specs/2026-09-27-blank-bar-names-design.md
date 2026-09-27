# Blank bar names: design

- **Date:** 2026-09-27
- **Branch:** `fix/2026-09-27-blank-bar-names`
- **Findings:** `docs/superpowers/research/2026-09-27-blank-bar-names-findings.md` (read it first)
- **Plan:** `docs/superpowers/plans/2026-09-27-blank-bar-names.md`
- **Owner mandate (2026-09-27):** build it on my own judgment and ask only when I have to. Commit
  incrementally, push the feature branch at milestones, and never merge without the owner.

## Problem

Blizzard's aura engine writes a bar's spell name from `auraData.name` when an aura is assigned to a
button or updated, and at no other time. On a first sighting that name can still be nil, and the
engine writes an empty string. An aura that never updates again keeps the blank for its whole life.
A permanent buff present at login is the worst case: it stays blank until `/reload`. AuraMaster
already repaints target, focus and pet containers on a unit swap. It never repaints anything else.

## Goal

A name that was blank on first sighting appears within a few seconds, in combat too, with no
`/reload`. The fix must not change a correct name, must not touch a container that shows no name,
and must cost nothing while stood down.

## Non-goals

- Reading the aura payload, the aura's spell id or the name. All three are secret in combat.
- Asking the client to load spell data (`C_Spell.RequestLoadSpellData`). It needs the spell id, which
  combat withholds, and its load event is the wrong signal (see the findings).
- Weapon-enchant names. The engine already retries an item name asynchronously
  (`Blizzard_AuraContainerUtil.lua:241-260`), and `UpdateAllAuras` refreshes enchant frames anyway.
- The icons style. It binds no name.

## Design

### D1. The repaint is `UpdateAllAuras`, through `ContainerClass:Refresh`

`UpdateAllAuras` marks a full rebuild. The engine rereads every aura and rewrites every button,
names included (findings, Mechanism 4). AuraMaster already sends it in combat and under secrecy on
unit swaps. It is not a protected call. The fix sends nothing else: no apply, no restyle, no button
access. Those stay held by `CM.MustDefer`.

The repaint does not go through `CM.RefreshUnit`. That function also rechecks class colors and may
request an apply. Both belong to a change of who the unit is, not to aura churn.

### D2. Which containers are repainted

A new pure predicate, `Style.ShowsEngineName(cfg)`, is added at the end of `modules/Style.lua` so
that no documented line citation moves. It mirrors the two places that bind `SetSpellName`:

- The bars style (the `Style.StyleKey(cfg)` answer, so an unknown style counts as bars) shows a name
  unless `cfg.bars.name.show == false` (`modules/Style_Bars.lua:320`).
- The text style shows a name when the compiled template for drawing has a piece of kind `name`
  (`modules/Style_Text.lua:521-541`). It uses `Style.Text.Compiled`, never a string search: tokens
  are case-insensitive, `$$` escapes, and a refused template falls back to the default, which has a
  name.
- Icons: never.

A live instance is repainted only when all of these hold:

- it has an engine, is not `parked`, and has no `staleData`;
- `ShouldShow()` answers shown and not previewing, which is exactly when `ApplyLive` has the engine
  enabled. An engine that is disabled would clear its auras on `UpdateAllAuras` (findings,
  Mechanism 4);
- its cfg's unit is the unit being repainted, and `ShowsEngineName(cfg)` is true.

The predicate is computed at repaint time. The compiled template is memoized, so this allocates
nothing and needs no per-apply cache that could go stale.

### D3. What triggers a repaint

A new module, `modules/NameRepaint.lua` (`NS.NameRepaint`), owns the listening and the timers.

**Listening.** There are two unit-filter frames (events-frames-taint-§1), one for player and pet and
one for target and focus, the same split EmptyWatch uses. Each carries `UNIT_AURA` and one `OnEvent`,
is registered through `NS.SafeRegisterUnitEvent(frame, "UNIT_AURA", NS.RejectedEvents, ...)`, is held
on the module, and is reused. A frame registers only the units that have at least one enabled
container with `ShowsEngineName`. A frame with no wanted unit is closed with `UnregisterAllEvents`.
`NameRepaint.Sync()` rederives the set. It runs wherever `EmptyWatch.Sync()` runs today (the end of
`CM.FlushPending` and of `CM.ApplyVisibility`). Rules for Sync:

- **While `NS.IsStoodDown()`, Sync calls `Stop()` and returns**, as EmptyWatch's `wanted()` does.
  The stand-down path itself runs `CM.ApplyVisibility` after its Stop calls
  (`core/LifecycleSetup.lua` `applySecure`, and again on a pending `PLAYER_REGEN_ENABLED`). Without
  this gate it would reopen the frames it just closed.
- **Sync is idempotent and allocates nothing.** It runs inside the measured `CM.ApplyVisibility`
  loop (`tests/perf.lua` `probeOverhead` against `probeAbsent`). It works out the wanted units into
  locals or booleans, not a table. It keeps the pair each frame currently holds, and it calls
  `SafeRegisterUnitEvent` or `UnregisterAllEvents` only when that pair changes.
- A unit that stops being wanted has its timer canceled and its dirty mark cleared.
- **Each frame is created hidden** (`f:Hide()` right after `CreateFrame`). A hidden frame still gets
  its events, and the kit counts a shown parentless frame as on screen (`tests/test_disabled.lua`
  `onScreen`).

**The listener stays open in combat and while auras are secret.** This is the deliberate difference
from EmptyWatch and TimedSpells, which close in combat because they read aura data. First sightings
happen mostly in combat, and this handler reads nothing. It takes the unit argument only after
`NS.Secrets.IsSafeKey(unit)` proves it readable. A readable unit counts only when it is one of that
frame's registered units, and anything else is ignored: the client filters by unit, but the kit's
`__fire` does not, so the handler bounds the unit itself. If the argument is unreadable, the handler
schedules the units that frame has registered. It never touches the payload.

**A unit swap is a first sighting too.** `OnUnitSwap` and `OnUnitPet` already rebuild the swapped
unit's containers through `CM.RefreshUnit`. That rebuild is where the new unit's auras are first
assigned, and a static aura, such as an NPC's permanent buff, would never send a `UNIT_AURA` to
repaint it. So after `CM.RefreshUnit`, both handlers call `NameRepaint.Arm(unit)`, the same entry
the `UNIT_AURA` handler uses. Only a timer is armed there. The swap's own engine calls are
unchanged, so the `tests/perf.lua` `unitSwap` count of one `UpdateAllAuras` per container still
holds.

**Timing, per unit, with two stages.** The delays are module constants.

| Constant | Value | Meaning |
|---|---|---|
| `QUICK` | 0.5 s | from the first `UNIT_AURA` of a quiet unit to its first repaint |
| `SETTLE` | 2.0 s | from a repaint to the follow-up that catches data which arrived late |
| `ENTER` | 3.0 s | from `PLAYER_ENTERING_WORLD` to the first repaint of every listened unit |

- `UNIT_AURA` for a unit with no timer armed arms `QUICK`. A unit that already has a timer armed
  only marks itself dirty, which allocates nothing.
- When `QUICK` fires, the unit is repainted and `SETTLE` is always armed. When `SETTLE` fires, the
  unit is repainted, and `SETTLE` is armed again only if the unit went dirty in the meantime.
- Under constant churn, a unit is therefore repainted at most once every 2 s. A single new aura gets
  two repaints, at +0.5 s and +2.5 s, and then its unit goes quiet.
- `PLAYER_ENTERING_WORLD` (`addon:OnEnterWorld`) arms every listened unit at `ENTER`, replacing any
  armed timer. Those units then follow the same `SETTLE` path. The login case therefore repaints at
  +3 s and +5 s, which covers the owner's login screenshot (buffs present at login). It runs on every
  loading screen, and that is fine: new zones bring new spells.
- Timers are `C_Timer.NewTimer` handles held per unit. The callbacks are built once at load (one per
  unit and stage), so the event path allocates no closures. Nothing arms while `NS.IsStoodDown()`.

### D4. Stand-down and stand-up (slash-commands-§7, anti-pattern #85)

`NameRepaint.Stop()` closes both frames with `UnregisterAllEvents`, cancels every timer and clears
the dirty marks. The stand-down path calls it next to `EmptyWatch.Stop()`. `standUp` does not change: it already calls
`CM.ApplyVisibility`, which ends in `NameRepaint.Sync()` once the latch is back up. A re-enable test
pins that the frames' registrations come back. Perf suspend follows whatever the existing modules
do (`tests/test_perf.lua`).

### D5. Cost and tracing

- There is a new perf bucket, `nameRepaint`, declared in `core/PerfSetup.lua` and bracketed Shape A
  around one repaint pass. The descriptor comment and `docs/performance.md` say that this is the
  addon's first aura-driven path that runs in combat. It is bounded by D3's timing, and each pass is
  one `UpdateAllAuras` per eligible container on one unit.
- Trace: one gated `NS.Debug("Names", ...)` line per repaint pass (unit, container count, stage),
  and none per event.
- `tests/perf.lua` gains a scenario: a `UNIT_AURA` burst arms exactly one timer per unit and
  allocates 0 B per event once armed. A pass sends one `UpdateAllAuras` per eligible container.

### D6. Diagnostics

The cee5bb6 fields were built on a refuted hypothesis and read `?` on every live bar. They are
removed: the `nameW=` / `timeW=` / `barW=` suffix, the `time-text widths cached` header line, and
`Style.MeasuredTimeWidths`. In their place, one header line from state the module already keeps:

`name repaint: listening=<units|none> armed=<unit:stage,...|none> passes=<n> last=<unit>@<GetTime()>|never`

It reads state only. It registers nothing and arms nothing, and it works while stood down
(debug-logging-§14).

### D7. Documentation

- `docs/debug.md`: rewrite "Bar names that do not show" around the real cause, and update the `Diag`
  row, the `Shown` row and the example block.
- `docs/midnight-quirks.md`: a new measured section: the name is written from `auraData.name` on
  assign or update only, and a blank first sighting persists. Cross-reference it from the unit-swap
  section.
- `docs/ARCHITECTURE.md`: add an event-table row for the new frames and update the registration
  counts and prose. `docs/data-flow.md`: update the lifecycle rows. `docs/module-map.md`: add the new
  module and suite. `docs/performance.md`: the bucket, a cost section, and correct the "no per-aura
  Lua path in combat" claims.
- `docs/known-limitations.md`: a name can show blank for up to about 2.5 s after a first sighting,
  and for about 3 s after a loading screen.
- `docs/smoke-tests.md`: a new section, checks numbered from 281, with results left for the owner.
- Every doc citation that moves is re-cited in the same commit (`tests/test_docs.lua`).
  `docs/test-cases.md` is regenerated and the README badge updated with every case added or removed.
- No version bump and no README Version History row. Those wait for the owner.

## Testing

The mock engine has no concept of a spell name, so the headless suite proves the plumbing, and the
owner's smoke checks prove the name. A new suite, `tests/test_namerepaint.lua`, is test-first, and
each case carries a `-- red under:` note. It covers:

- the predicate: bars default, bars with `name.show = false`, an unknown style, icons, a text
  template with and without a name token, `$$spellname$$`, a mixed-case token, and a refused
  template;
- Sync: which units each frame registers; nothing registered for an icons-only unit or a disabled
  container; a frame closed when its units go away;
- the timers: one `QUICK` per burst; `QUICK` → repaint → `SETTLE`; a quiet `SETTLE` stops; a dirty
  `SETTLE` rearms; an unreadable unit argument schedules both units;
- the repaint: `UpdateAllAuras` reaches exactly the eligible instances and never icons, a
  no-name bars container, a disabled, parked, stale or previewing container, or an instance with no
  engine;
- combat and secrecy: the repaint still runs under `__lockdown` and `__aurasSecret`;
- `PLAYER_ENTERING_WORLD` arms `ENTER` for every listened unit;
- stand-down: no registration and no timer survives (`tests/test_disabled.lua`), and nothing arms
  while stood down;
- the perf bucket is reached, and the diagnostics line is present.

Cases added after the spec review:

- a stand-down followed by `CM.ApplyVisibility` leaves both frames unregistered, and so does a
  pending `PLAYER_REGEN_ENABLED` that completes while down;
- after disable, no NameRepaint frame is on screen;
- `UNIT_AURA` for `nameplate1`, or for `target` delivered to the player frame, arms nothing;
- a target swap arms the `target` unit, and its pass reaches only target containers;
- disable followed by enable: the registrations come back;
- the timer cases assert each queued timer's `delay` (`QUICK`, `SETTLE`, `ENTER`), because the mock
  ignores delays. Real timing is a smoke check.

The existing tests that pin counts are updated deliberately, each with a comment:

- `tests/test_disabled.lua`: the timers after a player `UNIT_AURA`, and the registration census.
- `tests/test_perf.lua`: three edits. The declared count goes from 7 to 8. `nameRepaint` joins the
  pinned `BUCKET_ORDER` string at its declared place. `exercise()` drives a real pass, by firing
  `UNIT_AURA` through the NameRepaint frame and then `mocks.__fireTimers()`, before test mode is
  turned on.
- `tests/test_diagnostics.lua`: the removed cee5bb6 cases.

**Smoke checks must not toggle lock, test mode or visibility** between the first sighting and the
check. Each of those flips the engine's enabled state, and that repaints on its own (findings,
"What AuraMaster did before the fix").

## Risks

- **Real engine cost.** `UpdateAllAuras` rebuilds the whole container. Offline, only call counts can
  be measured. The rate bound in D3 keeps it well under SetisBuffBars, which rebuilds on every
  player `UNIT_AURA`. An owner perf capture in a busy fight is a smoke check.
- **Visible flicker on rebuild.** The engine releases and reacquires buttons within one dirty pass.
  SetisBuffBars does this constantly with no report of flicker. Smoke check.
- **Data later than 2.5 s.** A name that still has not arrived stays blank until the next `UNIT_AURA`
  on that unit, which rearms the cycle. That is accepted and listed in known limitations.
