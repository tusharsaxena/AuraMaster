# Report — 20260927-013510

What the client printed, copied from the debug console by the player on 2026-09-27. The
`HH:MM:SS | [Tag]` prefixes are kept: they are the capture's timestamps. The player's note with the
paste: "a second reading on another character, same dungeon, same pull".

## The report

The `/am perf report` summary. This capture declared no nested bucket that fired, so the report
printed no `(buckets nest: … — do not sum)` footer.

```
01:35:10 | [Perf] capture: 2026-09-27 01:32  (AuraMaster, schema 2, v0.1.0)
01:35:10 | [Perf] who:       Trâxex-Frostmourne, level 90 Beast Mastery Hunter
01:35:10 | [Perf] where:     Murder Row
01:35:10 | [Perf] group:     party (5) / party
01:35:10 | [Perf] active:       34.8s    1999 frames    57.4 fps   17.41 ms/frame
01:35:10 | [Perf] suspended:    36.9s    2198 frames    59.6 fps   16.78 ms/frame
01:35:10 | [Perf] delta:                                                   +0.63 ms/frame
01:35:10 | [Perf] 
01:35:10 | [Perf] bucket            calls   total ms       ms/s    max ms
01:35:10 | [Perf] unitSwap             19       1.38      0.040     0.097
01:35:10 | [Perf] visibilityPass        1       0.25      0.007     0.245
01:35:10 | [Perf] styleElement         30      10.05      0.289     0.568
```

## The dump

The same line as [`dump.json`](dump.json), as it appeared in the console.

```
01:35:10 | [Perf] {"addon":"AuraMaster","buckets":{"styleElement":{"calls":30,"maxMs":0.5680,"totalMs":10.0511},"unitSwap":{"calls":19,"maxMs":0.0971,"totalMs":1.3817},"visibilityPass":{"calls":1,"maxMs":0.2450,"totalMs":0.2450}},"context":{"character":"Trâxex","class":"Hunter","group":"party (5) / party","level":90,"realm":"Frostmourne","spec":"Beast Mastery","subZone":"","zone":"Murder Row"},"fps":{"active":{"avgFps":57.4425,"frames":1999,"msPerFrame":17.4087,"seconds":34.8000},"deltaMsPerFrame":0.6321,"suspended":{"avgFps":59.6068,"frames":2198,"msPerFrame":16.7766,"seconds":36.8750}},"interface":120100,"label":"2026-09-27 01:32","schema":2,"source":"ingame","timestamp":1790453110,"version":"0.1.0"}
```

## Run log

The run's lifecycle lines, in order. They show both arms were combat-gated, that arm B ran with the
addon suspended, and that no `/reload` landed between the arms.

```
01:32:50 | [Perf] run started — 2026-09-27 01:32
01:32:50 | [Perf] who:       Trâxex-Frostmourne, level 90 Beast Mastery Hunter
01:32:50 | [Perf] where:     Murder Row
01:32:50 | [Perf] group:     party (5) / party
01:32:50 | [Perf] perf run STARTED — 2026-09-27 01:32
01:32:51 | [Perf] experiment A armed (addon active) — waiting for combat
01:33:06 | [Perf] Experiment A RECORDING — combat started
01:33:41 | [Perf] Experiment A ENDED — 34.8s, 1999 frames, 57.4 fps
01:34:24 | [Perf] addon SUSPENDED — inert
01:34:24 | [Perf] experiment B armed (addon SUSPENDED) — waiting for combat
01:34:30 | [Perf] Experiment B RECORDING — combat started
01:35:07 | [Perf] Experiment B ENDED — 36.9s, 2198 frames, 59.6 fps
01:35:09 | [Perf] run finished — A 34.8s / 1999 frames, B 36.9s / 2198 frames
01:35:09 | [Perf] addon RESUMED — events and frames restored
01:35:09 | [Perf] perf run FINISHED — saved; `Report` or `Dump` in the panel to read it, `/reload` to flush it to SavedVariables
```
