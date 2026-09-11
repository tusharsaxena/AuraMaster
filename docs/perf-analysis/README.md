# Perf analysis — the in-game capture store

**In-game captures only.** A person runs `/am perf` in a live client and copies the result out; no
script can produce one (performance-§8). Offline scenario runs of `tests/perf.lua` are a different
measurement: the vendored runner writes them into that run's bundle under
[`../automated-tests/`](../automated-tests/README.md) (automated-tests-§7). An offline figure says
nothing about frame time and an in-game capture says nothing about allocation, so never read one as
the other.

The store is standing and cumulative, not tied to one investigation, so captures compare across
addon versions. How to read the numbers: [`../performance.md`](../performance.md).

## Bundle naming

```
docs/perf-analysis/<YYYYMMDD-HHMMSS>/
```

One directory per capture, stamped in **local time from the record's own timestamp** — when the
capture happened, not when it was written up. Bundles are **frozen once written** and never pruned;
this README is the one file in the store that is rewritten. If a reading turns out wrong, the next
capture's analysis says so.

## The three artifacts

| File | What it is |
|---|---|
| `report.md` | What the client printed: the `/am perf report` summary and the run's lifecycle lines |
| `dump.json` | The record, **byte for byte as the client emitted it** — one line, keys as sorted, figures as encoded. Never pretty-printed or edited |
| `ANALYSIS.md` | The write-up, following the uniform prompt in the standards repo's `PERF_ANALYSIS.md` playbook, every claim citing a file in the same bundle |

## Schema summary

The record shape belongs to `LibKa0s-Perf-1.0`, versioned in the library; the record carries its own
`schema` field and the canonical field-by-field contract lives in the LibKa0s repo
([docs/record-schema.md](https://github.com/tusharsaxena/LibKa0s/blob/master/docs/record-schema.md)).
In outline: the emitting addon (`AuraMaster`) and its version, the client interface, a timestamp and
label, a `context` block (character, class, spec, level, zone, group), a `buckets` map — per bucket
`calls`, `totalMs`, `maxMs`, the declared `within` and, where a call site passed one, the observed
parent — and an `fps` block with the active arm, the suspended arm and their per-frame delta.

This addon's buckets are `unitSwap`, `applyPass`, `applyContainer` (within `applyPass`),
`visibilityPass`, `styleElement` and `timedScan` (`core/PerfSetup.lua`). Never sum a parent and its children; a
bucket that never fired is absent, not zero.

## Taking a capture

```
/am perf                    status, and the step panel
/am perf start [label]      out of combat: begins the run, records character, spec, zone, group
/am perf measure a          arm A — addon active; pull, the arm records while combat lasts
/am perf measure b          arm B — addon suspended for you; reset and pull again
/am perf finish             end the run and save it to the ring (prints nothing)
/am perf report             print the summary and the JSON line
```

Then use the debug console's **Copy** button to lift the report and the JSON out. The same record is
on disk after a `/reload`, in the capture ring `AuraMasterPerfDB` inside
`_retail_/WTF/Account/ACCOUNT/SavedVariables/AuraMaster.lua`. The ring is a separate top-level global
from `AuraMasterDB`, so a profile copy, reset or switch never touches it (performance-§5).

## Capture index

| Stamp | Addon version | Label | What it measured | Bundle |
|---|---|---|---|---|

No capture has been taken yet. The first one is a later, separate run of `/wow-addon:perf-analysis`
against a real client paste; this store is not seeded from the offline scenarios or from the source.
