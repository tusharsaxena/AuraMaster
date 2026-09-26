# Report — 20260927-012035

What the client printed, copied from the debug console by the player on 2026-09-27. The
`HH:MM:SS | [Tag]` prefixes are kept: they are the capture's timestamps.

## The report

The `/am perf report` summary. This capture declared no nested bucket that fired, so the report
printed no `(buckets nest: … — do not sum)` footer.

```
01:20:35 | [Perf] capture: 2026-09-27 01:17  (AuraMaster, schema 2, v0.1.0)
01:20:35 | [Perf] who:       Sacrìlege-Frostmourne, level 90 Protection Paladin
01:20:35 | [Perf] where:     Murder Row
01:20:35 | [Perf] group:     party (5) / party
01:20:35 | [Perf] active:       52.3s    2928 frames    56.0 fps   17.87 ms/frame
01:20:35 | [Perf] suspended:    51.8s    2962 frames    57.2 fps   17.49 ms/frame
01:20:35 | [Perf] delta:                                                   +0.38 ms/frame
01:20:35 | [Perf] 
01:20:35 | [Perf] bucket            calls   total ms       ms/s    max ms
01:20:35 | [Perf] unitSwap             16       0.42      0.008     0.035
01:20:35 | [Perf] visibilityPass        1       0.08      0.002     0.079
01:20:35 | [Perf] styleElement         20       5.79      0.111     0.660
```

## The dump

The same line as [`dump.json`](dump.json), as it appeared in the console.

```
01:20:35 | [Perf] {"addon":"AuraMaster","buckets":{"styleElement":{"calls":20,"maxMs":0.6603,"totalMs":5.7856},"unitSwap":{"calls":16,"maxMs":0.0348,"totalMs":0.4159},"visibilityPass":{"calls":1,"maxMs":0.0793,"totalMs":0.0793}},"context":{"character":"Sacrìlege","class":"Paladin","group":"party (5) / party","level":90,"realm":"Frostmourne","spec":"Protection","subZone":"","zone":"Murder Row"},"fps":{"active":{"avgFps":55.9590,"frames":2928,"msPerFrame":17.8702,"seconds":52.3240},"deltaMsPerFrame":0.3770,"suspended":{"avgFps":57.1649,"frames":2962,"msPerFrame":17.4932,"seconds":51.8150}},"interface":120100,"label":"2026-09-27 01:17","schema":2,"source":"ingame","timestamp":1790452235,"version":"0.1.0"}
```

## Run log

The run's lifecycle lines, in order. They show both arms were combat-gated, that arm B ran with the
addon suspended, and that no `/reload` landed between the arms.

```
01:17:41 | [Perf] run started — 2026-09-27 01:17
01:17:41 | [Perf] who:       Sacrìlege-Frostmourne, level 90 Protection Paladin
01:17:41 | [Perf] where:     Murder Row
01:17:41 | [Perf] group:     party (5) / party
01:17:41 | [Perf] perf run STARTED — 2026-09-27 01:17
01:17:45 | [Perf] experiment A armed (addon active) — waiting for combat
01:18:06 | [Perf] Experiment A RECORDING — combat started
01:18:59 | [Perf] Experiment A ENDED — 52.3s, 2928 frames, 56.0 fps
01:19:35 | [Perf] addon SUSPENDED — inert
01:19:35 | [Perf] experiment B armed (addon SUSPENDED) — waiting for combat
01:19:41 | [Perf] Experiment B RECORDING — combat started
01:20:33 | [Perf] Experiment B ENDED — 51.8s, 2962 frames, 57.2 fps
01:20:34 | [Perf] run finished — A 52.3s / 2928 frames, B 51.8s / 2962 frames
01:20:34 | [Perf] addon RESUMED — events and frames restored
01:20:34 | [Perf] perf run FINISHED — saved; `Report` or `Dump` in the panel to read it, `/reload` to flush it to SavedVariables
```
