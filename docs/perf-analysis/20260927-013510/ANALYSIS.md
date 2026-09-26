# Analysis — 20260927-013510

- **Addon:** Aura Master 0.1.0 (record schema 2, client interface 120100)
- **Captured:** 2026-09-27 01:35 local, label `2026-09-27 01:32`
- **Who / where:** Trâxex-Frostmourne, level 90 Beast Mastery Hunter · Murder Row (no subZone) · party (5) / party
- **Delta:** +0.63 ms/frame — above the 0.5 line, but not resolved on arms this short and this different (see The arms)
- **Previous capture:** [20260927-012035](../20260927-012035/ANALYSIS.md)

## Headline

A second reading on another character, a Beast Mastery Hunter, in the same dungeon and party as the
first. The addon's own Lua cost **11.68 ms over the 34.8 s active arm, 0.336 ms per second of combat**
([`dump.json`](dump.json)), 86% of it `styleElement` as the engine created 30 buttons mid-combat.
The frame-time delta, +0.63 ms/frame, clears the 0.5 ms/frame line only narrowly, on 35–37 s arms
from two different pulls, so it is not a resolved cost. Even if all of it were real, the addon's
own code accounts for under 1% of it. Nothing here needs acting on.

## The arms

Both figures come from [`dump.json`](dump.json)'s `fps` block; the rounded forms are in
[`report.md`](report.md).

| Arm | Seconds | Frames | Avg fps | ms/frame |
|---|---|---|---|---|
| active (addon running) | 34.8000 | 1999 | 57.4425 | 17.4087 |
| suspended (addon inert) | 36.8750 | 2198 | 59.6068 | 16.7766 |
| **delta** | | | | **+0.6321** |

The delta is above the roughly 0.5 ms/frame line, and its sign runs the expected way (the active arm
slower). It still does not count as resolved. The ±0.3 ms/frame floor assumes arms of 60–80 s, and
these are 34.8 s and 36.9 s, half that, which widens the floor. The arms also differ in length by
2.1 s and come from two separate fights (see below), so the environment moved between them. Read
together with the first capture's +0.38 ms/frame, both readings point the same way and neither
resolves. The addon's bucketed Lua is 0.0058 ms/frame (11.6778 ms over 1999 frames), under 1% of
this delta, so whatever part of it is real belongs to the Blizzard aura engine drawing the containers
(the addon hands its auras to it by design, `core/PerfSetup.lua`) or to the environment.

## The buckets — what the addon actually cost

Every figure from [`dump.json`](dump.json)'s `buckets`; `ms/s` is `totalMs` over the **active** arm's
seconds, as [`report.md`](report.md) computes it. Buckets nest — **do not sum the column**.

| Bucket | Calls | Total ms | ms/s | Max ms | Parent |
|---|---|---|---|---|---|
| `styleElement` | 30 | 10.0511 | 0.289 | 0.5680 | none declared |
| `unitSwap` | 19 | 1.3817 | 0.040 | 0.0971 | none declared |
| `visibilityPass` | 1 | 0.2450 | 0.007 | 0.2450 | none declared |

None of the three that fired declares a parent, so they do not overlap, and their sum is the
addon's accounted cost: **11.6778 ms, 0.336 ms per second of combat**.

- `styleElement` is 86% of it: 30 dresses at 0.335 ms each on average, the slowest 0.568 ms. The
  engine calls it for each button it creates, and a restyle after a settings change calls it too
  (`core/PerfSetup.lua`). No settings pass ran (`applyPass` never fired), so these are button
  creations: the containers' button pools grew by 30 during combat. A one-time cost per button per
  session, not per-frame work.
- `unitSwap`: 19 target, focus or pet changes at 0.073 ms each.
- `visibilityPass`: one show-ladder pass at 0.245 ms. It runs on combat and settings changes
  (`core/PerfSetup.lua`); the capture does not say which triggered this one.

The same four declared buckets are **absent** as in the first capture, so they never fired:
`applyPass` and `applyContainer` (no setting changed), `timedScan` (it reads buffs only while they
are readable, and aura data is secret in combat) and `emptyPass` (only while unlocked and out of
combat).

## What the capture did not hold constant

The arms were two separate fights. Arm A ran 01:33:06–01:33:41 and arm B 01:34:30–01:35:07
([`report.md`](report.md), run log), 49 seconds apart, in a five-player party rather than solo at one
target. The player's note says "same pull"; the run log shows two separate combat windows, so each arm
was its own fight, the other four players' actions differed between them, and the arms differ in
length by 2.1 s. Both arms were combat-gated, arm B ran with the addon suspended, and no `/reload`
came between them. The zone and group size did not change.

## What moved

Against [20260927-012035](../20260927-012035/ANALYSIS.md), compared on per-second and per-call
figures because the arms differ in length (52.3 s there, 34.8 s here). **The two captures are on
different characters**: a Protection Paladin there, a Beast Mastery Hunter here. Each character can
carry a different profile, and a Hunter has a pet, so this is two readings of the same build in the
same place rather than a like-for-like repeat, and the differences below are not attributable to a
change in the addon.

| Figure | Previous | This capture |
|---|---|---|
| Accounted cost, ms/s | 0.120 | 0.336 |
| `styleElement` calls per minute of combat | 22.9 | 51.7 |
| `styleElement` ms per call | 0.289 | 0.335 |
| `unitSwap` calls per minute of combat | 18.3 | 32.8 |
| `unitSwap` ms per call | 0.026 | 0.073 |
| `visibilityPass` ms per call | 0.079 | 0.245 |
| Frame-time delta, ms/frame | +0.38 | +0.63 |

Most of the rise in accounted cost is `styleElement` running more often: the engine created 30
buttons in 35 s here against 20 in 52 s there. Its cost per button barely moved (0.289 to 0.335 ms).
`unitSwap` and `visibilityPass` cost about three times as much per call here; with 19 calls and one
call respectively, on a different character, that is a reading to watch, not a trend. Which buckets
fired did not change.

## Actions

None needed for cost: 0.336 ms per second of combat is small, and none of it is per-frame work.

1. Optional, carried from the first capture: a capture with arms of 60–80 s, solo, at one target
   dummy, on one character for both arms, would give the frame-time delta a chance to resolve and
   would give a like-for-like baseline for the next build. Not tracked anywhere yet.
