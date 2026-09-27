# Analysis — 20260927-214132

- **Addon:** Aura Master 1.0.0 (record schema 2, client interface 120100)
- **Captured:** 2026-09-27 21:41 local, label `2026-09-27 21:38`
- **Who / where:** Sacrìlege-Frostmourne, level 90 Protection Paladin · Murder Row (no subZone) · party (5) / party
- **Delta:** −0.85 ms/frame, **backwards** (the suspended arm was slower). This is the environment moving between the arms, not a result about the addon
- **Previous capture:** [20260927-013510](../20260927-013510/ANALYSIS.md)

## Headline

This is the first capture on 1.0.0, from the same Protection Paladin, dungeon and party size as the
first capture ([20260927-012035](../20260927-012035/ANALYSIS.md)). The addon's own Lua cost
**14.27 ms over the 54.5 s active arm, which is 0.262 ms per second of combat**
([`dump.json`](dump.json)). Of that, 94% was `styleElement`, dressing 30 buttons the engine created
mid-combat. The frame-time delta has the wrong sign. The suspended arm ran 0.85 ms/frame *slower*,
and two loading screens separate the arms, so the delta measured a change of environment. Nothing
here needs acting on.

## The arms

Both figures come from [`dump.json`](dump.json)'s `fps` block; the rounded forms are in
[`report.md`](report.md).

| Arm | Seconds | Frames | Avg fps | ms/frame |
|---|---|---|---|---|
| active (addon running) | 54.4950 | 2677 | 49.1238 | 20.3567 |
| suspended (addon inert) | 46.1070 | 2174 | 47.1512 | 21.2084 |
| **delta** | | | | **−0.8516** |

The delta's magnitude is past the roughly 0.5 ms/frame line, but its sign is backwards: removing the
addon made frames slower. The addon cannot cost negative time, so the delta measures the environment,
and the backwards sign is how that shows (performance-§7). It is not a speed-up and says nothing about
the addon's frame cost in either direction. Three things moved between the arms (see below): a pair
of loading screens, the fight itself, and the arm length, which differs by 8.4 s (54.5 s against
46.1 s). Arm B is also shorter than the 60–80 s the ±0.3 ms/frame floor assumes. By comparison, the
addon's bucketed Lua is 0.0053 ms/frame (14.2709 ms over 2677 active frames), two orders of magnitude
below either the delta or the floor.

Both arms ran well below the frame rate of the two earlier captures (about 49 and 47 fps here, against
56–60 fps in [20260927-012035](../20260927-012035/dump.json) and
[20260927-013510](../20260927-013510/dump.json)). The client was under more load throughout this
session, and that load was there with the addon active and with it suspended.

## The buckets — what the addon actually cost

Every figure from [`dump.json`](dump.json)'s `buckets`; `ms/s` is `totalMs` over the **active** arm's
seconds, as [`report.md`](report.md) computes it. Buckets nest — **do not sum the column**.

| Bucket | Calls | Total ms | ms/s | Max ms | Parent |
|---|---|---|---|---|---|
| `styleElement` | 30 | 13.3616 | 0.245 | 0.6843 | none declared |
| `unitSwap` | 9 | 0.7029 | 0.013 | 0.0992 | none declared |
| `visibilityPass` | 1 | 0.2064 | 0.004 | 0.2064 | none declared |

None of the three buckets that fired declares a parent, so they do not overlap and can be added up.
The addon's accounted cost is **14.2709 ms, or 0.262 ms per second of combat**.

- `styleElement` is 94% of it. It ran 30 times at an average of 0.445 ms and a maximum of 0.684 ms.
  No settings pass ran (`applyPass` never fired), so all 30 calls were the engine creating buttons
  (`core/PerfSetup.lua`), which works out to 33.0 per minute of combat. This is a one-time cost for
  each button in a session. It is not per-frame work.
- `unitSwap` ran 9 times (target, focus or pet changes) at 0.078 ms each, 9.9 per minute of combat.
- `visibilityPass` ran once and took 0.206 ms.

The same four declared buckets are **absent** as in both earlier captures, so they never fired:
`applyPass` and `applyContainer` (no setting changed during an arm), `timedScan` (it reads buffs only
while they are readable, and aura data is secret in combat) and `emptyPass` (it runs only while
unlocked and out of combat). The `[Apply] applied 16 container(s)` line in the run log came at
21:41:31, after `run finished`, when the resume stood the addon back up. That was outside both arms,
so no bucket counted it.

## What the capture did not hold constant

From [`report.md`](report.md)'s context block and run log:

- **Two loading screens between the arms.** Arm A ended at 21:39:42. `[World] entering world` fired
  at 21:39:56 and again at 21:40:24, and arm B started recording at 21:40:42. The capture does not say
  why. A zone-out and zone-in, for example to reset the instance, fits the pattern. The `where:` line
  is recorded once, at `run started`, so the record cannot confirm that arm B was in Murder Row or in
  the same instance copy.
- **No `/reload`.** The run's state lives in memory only (`P.run` in `libs/LibKa0s/Perf.lua`), and
  `run finished — A 54.5s / 2677 frames, B …` could not have reported arm A across a reload.
- **Two separate fights**, in a five-player party rather than solo at one target, so the other four
  players' actions differed between the arms.
- **Unequal arm lengths:** 54.5 s against 46.1 s.
- Held constant: the character, the addon set (no reload), the group size, and both arms being
  combat-gated, with arm B suspended.

**Build identity.** The record's `version` is `1.0.0`, and it matches the TOC's `## Version`. The
repo's `master` is, however, past the `1.0.0-release` tag: the font primer (#24) and the dead-export
cleanup landed after it without a version bump. The `[Fonts]` lines in the run log come from the
primer's code, so the client was running a post-release build, not the tagged 1.0.0. The version
string cannot tell those two builds apart.

## What moved

This section compares against the previous capture, [20260927-013510](../20260927-013510/ANALYSIS.md),
and also against [20260927-012035](../20260927-012035/ANALYSIS.md), which is the like-for-like reading
on this same character. The figures are per second and per call, because the arm lengths differ. Both
earlier captures ran on 0.1.0.

| Figure | 012035 (Paladin, 0.1.0) | 013510 (Hunter, 0.1.0) | This capture (Paladin, 1.0.0+) |
|---|---|---|---|
| Accounted cost, ms/s | 0.120 | 0.336 | 0.262 |
| `styleElement` calls per minute of combat | 22.9 | 51.7 | 33.0 |
| `styleElement` ms per call | 0.289 | 0.335 | 0.445 |
| `unitSwap` calls per minute of combat | 18.3 | 32.8 | 9.9 |
| `unitSwap` ms per call | 0.026 | 0.073 | 0.078 |
| `visibilityPass` ms per call | 0.079 | 0.245 | 0.206 |
| Frame-time delta, ms/frame | +0.38 | +0.63 | −0.85 |

- **Against the same character (012035):** the accounted cost roughly doubled, from 0.120 to 0.262
  ms/s. Two things drove it: `styleElement` ran more often (22.9 to 33.0 creations per minute) and cost
  more per call (0.289 to 0.445 ms). The frame rates were also 12% (active) and 18% (suspended) lower in this session, and a
  more loaded client stretches every measured interval, so part of the per-call rise may be the
  session rather than the code. With 20 and 30 calls, the capture cannot separate those causes. The
  build changed between the two captures (0.1.0 to post-1.0.0), so this is the first reading to set
  against later 1.0.x captures. It is not a regression finding.
- **Against the previous capture (013510):** the cost fell, from 0.336 to 0.262 ms/s. That capture was
  a Hunter with a pet on another profile, so the difference is a difference of character, not of
  build.
- **Did not move:** which buckets fired (the same three in all three captures) and which stayed absent
  (the same four). `styleElement`'s maximum stayed under 0.7 ms in all three.
- **Delta:** the first two captures had a positive delta that did not resolve. This one is negative,
  so across three captures the frame-time instrument has not resolved the addon.

## Actions

None needed for cost. 0.262 ms per second of combat is small, and none of it is per-frame work.

1. Watch `styleElement` ms per call, now 0.445 ms against 0.289 ms on the same character under 0.1.0.
   The next capture on this character will show whether that rise is the build or the session's lower
   frame rate. No tracking issue exists; this is new here.
2. Carried from both earlier captures: a capture with 60–80 s arms, solo at one target dummy, with
   **no zoning between the arms**, would give the frame-time delta a chance to resolve. It is still
   not tracked anywhere.
