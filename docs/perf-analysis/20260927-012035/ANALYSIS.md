# Analysis — 20260927-012035

- **Addon:** Aura Master 0.1.0 (record schema 2, client interface 120100)
- **Captured:** 2026-09-27 01:20 local, label `2026-09-27 01:17`
- **Who / where:** Sacrìlege-Frostmourne, level 90 Protection Paladin · Murder Row (no subZone) · party (5) / party
- **Delta:** +0.38 ms/frame — unresolved below the floor
- **Previous capture:** none — this is the first

## Headline

Two combat-gated arms of about 52 s each, in a five-player party in Murder Row. The addon's own Lua
cost **6.28 ms over the 52.3 s active arm, 0.120 ms per second of combat** ([`dump.json`](dump.json)),
almost all of it `styleElement`: the engine creating 20 buttons mid-combat. The frame-time delta,
+0.38 ms/frame, is inside the instrument's resolution floor and says nothing either way about the
addon. Nothing here needs acting on.

## The arms

Both figures come from [`dump.json`](dump.json)'s `fps` block; the rounded forms are in
[`report.md`](report.md).

| Arm | Seconds | Frames | Avg fps | ms/frame |
|---|---|---|---|---|
| active (addon running) | 52.3240 | 2928 | 55.9590 | 17.8702 |
| suspended (addon inert) | 51.8150 | 2962 | 57.1649 | 17.4932 |
| **delta** | | | | **+0.3770** |

The delta is unresolved. It sits under the roughly 0.5 ms/frame line below which the harness cannot
tell the addon from run-to-run noise, and these arms are shorter (about 52 s) than the 60–80 s the
±0.3 ms/frame floor assumes, so the floor is if anything wider here. The sign runs the expected way
(the active arm slower), which rules out the backwards-delta tell but does not make the figure a
cost. The arms are close in length: 52.3 s against 51.8 s. The addon's bucketed Lua accounts for
0.0021 ms/frame (6.2808 ms over 2928 frames), under 1% of the delta, so if any of the delta is real
it is the Blizzard aura engine drawing the containers (which the addon hands its auras to by design,
`core/PerfSetup.lua`) or the environment, not the addon's own code.

## The buckets — what the addon actually cost

Every figure from [`dump.json`](dump.json)'s `buckets`; `ms/s` is `totalMs` over the **active** arm's
seconds, as [`report.md`](report.md) computes it. Buckets nest — **do not sum the column**.

| Bucket | Calls | Total ms | ms/s | Max ms | Parent |
|---|---|---|---|---|---|
| `styleElement` | 20 | 5.7856 | 0.111 | 0.6603 | none declared |
| `unitSwap` | 16 | 0.4159 | 0.008 | 0.0348 | none declared |
| `visibilityPass` | 1 | 0.0793 | 0.002 | 0.0793 | none declared |

None of the three that fired declares a parent, so they do not overlap, and their sum is the
addon's accounted cost: **6.2808 ms, 0.120 ms per second of combat**.

- `styleElement` is 92% of it: 20 dresses at 0.289 ms each on average, the slowest 0.660 ms. The
  engine calls it for each button it creates (`core/PerfSetup.lua`), and by a restyle after a settings
  change. No settings pass ran (`applyPass` never fired), so these are button creations: the
  containers' button pools grew by 20 during combat. That is a one-time cost per button per session, not a per-frame
  one.
- `unitSwap`: 16 target, focus or pet changes, 0.026 ms each. Cheap, and the only path that runs on
  ordinary combat activity.
- `visibilityPass`: one show-ladder pass, 0.079 ms. It runs on combat and settings changes
  (`core/PerfSetup.lua`); the capture does not say which triggered this one.

Four declared buckets are **absent**, so they never fired, and that is what the run exercised rather
than a gap:

- `applyPass` and its child `applyContainer`: no setting changed during the arm.
- `timedScan`: it scans the player's buffs only while they are readable (`core/PerfSetup.lua`), and
  aura data is secret in combat.
- `emptyPass`: it runs only while unlocked, out of test mode and out of combat.

## What the capture did not hold constant

The arms were not the same fight. Arm A ran 01:18:06–01:18:59 and arm B 01:19:41–01:20:33
([`report.md`](report.md), run log), two separate pulls 42 seconds apart, in a five-player party
rather than solo at one target, which is what `performance-§7` recommends for a repeatable pair. So
the mobs, the other four players' actions and whatever else was on screen differed between the arms.
Both arms were combat-gated, arm B ran with the addon suspended, and no `/reload` came between them
(the run log shows `addon SUSPENDED` before arm B and `addon RESUMED` only after it). The zone and the
group size did not change.

## What moved

First capture — nothing to diff against; every figure above is a baseline reading.

## Actions

None needed for cost: 0.120 ms per second of combat is small, and none of it is per-frame work.

1. Optional, for a resolved frame-time reading: a future capture with arms of 60–80 s, solo, at one
   target dummy, would bring the delta within reach of the floor and measure the aura engine's
   drawing cost for this profile. New here; not tracked anywhere.
