# Report — 20260927-214132

What the client printed, copied from the debug console by the player on 2026-09-27. The
`HH:MM:SS | [Tag]` prefixes are kept: they are the capture's timestamps.

## The report

The `/am perf report` summary. None of the buckets that fired declares a parent, so the report
printed no `(buckets nest: … — do not sum)` footer.

```
21:41:32 | [Perf] capture: 2026-09-27 21:38  (AuraMaster, schema 2, v1.0.0)
21:41:32 | [Perf] who:       Sacrìlege-Frostmourne, level 90 Protection Paladin
21:41:32 | [Perf] where:     Murder Row
21:41:32 | [Perf] group:     party (5) / party
21:41:32 | [Perf] active:       54.5s    2677 frames    49.1 fps   20.36 ms/frame
21:41:32 | [Perf] suspended:    46.1s    2174 frames    47.2 fps   21.21 ms/frame
21:41:32 | [Perf] delta:                                                   -0.85 ms/frame
21:41:32 | [Perf] 
21:41:32 | [Perf] bucket            calls   total ms       ms/s    max ms
21:41:32 | [Perf] unitSwap              9       0.70      0.013     0.099
21:41:32 | [Perf] visibilityPass        1       0.21      0.004     0.206
21:41:32 | [Perf] styleElement         30      13.36      0.245     0.684
```

## The dump

The same line as [`dump.json`](dump.json), as it appeared in the console.

```
21:41:32 | [Perf] {"addon":"AuraMaster","buckets":{"styleElement":{"calls":30,"maxMs":0.6843,"totalMs":13.3616},"unitSwap":{"calls":9,"maxMs":0.0992,"totalMs":0.7029},"visibilityPass":{"calls":1,"maxMs":0.2064,"totalMs":0.2064}},"context":{"character":"Sacrìlege","class":"Paladin","group":"party (5) / party","level":90,"realm":"Frostmourne","spec":"Protection","subZone":"","zone":"Murder Row"},"fps":{"active":{"avgFps":49.1238,"frames":2677,"msPerFrame":20.3567,"seconds":54.4950},"deltaMsPerFrame":-0.8516,"suspended":{"avgFps":47.1512,"frames":2174,"msPerFrame":21.2084,"seconds":46.1070}},"interface":120100,"label":"2026-09-27 21:38","schema":2,"source":"ingame","timestamp":1790525492,"version":"1.0.0"}
```

## Run log

Every other line in the buffer, in order. The `[Perf]` lines show both arms were combat-gated and
that arm B ran with the addon suspended. The `[World]` and `[Fonts]` lines record **two loading
screens between the arms** (21:39:56 and 21:40:24). They were not a `/reload`: the run's state is
held in memory only, and a reload would have cleared it, so `run finished` could not have reported
arm A.

```
21:38:29 | [Debug] logging enabled
21:38:29 | [Init] AuraMaster v1.0.0, schema v11, profile 'Default', 16 container(s)
21:38:34 | [Perf] run started — 2026-09-27 21:38
21:38:34 | [Perf] who:       Sacrìlege-Frostmourne, level 90 Protection Paladin
21:38:34 | [Perf] where:     Murder Row
21:38:34 | [Perf] group:     party (5) / party
21:38:34 | [Perf] perf run STARTED — 2026-09-27 21:38
21:38:40 | [Perf] experiment A armed (addon active) — waiting for combat
21:38:48 | [Perf] Experiment A RECORDING — combat started
21:39:42 | [Perf] Experiment A ENDED — 54.5s, 2677 frames, 49.1 fps
21:39:56 | [World] entering world
21:39:56 | [Fonts] PLAYER_ENTERING_WORLD at 36685.06, loading screen ended at 36685.06 (0.00 s later)
21:40:24 | [World] entering world
21:40:24 | [Fonts] PLAYER_ENTERING_WORLD at 36713.34, loading screen ended at 36713.34 (0.00 s later)
21:40:35 | [Perf] addon SUSPENDED — inert
21:40:35 | [Perf] experiment B armed (addon SUSPENDED) — waiting for combat
21:40:42 | [Perf] Experiment B RECORDING — combat started
21:41:28 | [Perf] Experiment B ENDED — 46.1s, 2174 frames, 47.2 fps
21:41:31 | [Perf] run finished — A 54.5s / 2677 frames, B 46.1s / 2174 frames
21:41:31 | [Perf] addon RESUMED — events and frames restored
21:41:31 | [Perf] perf run FINISHED — saved; `Report` or `Dump` in the panel to read it, `/reload` to flush it to SavedVariables
21:41:31 | [Apply] applied 16 container(s)
```
