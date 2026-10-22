# 06 — Refresh from the moved local tag

Item AM-RV2 of the 2026-10-22 run "LibKa0s issues #45-#58" (OWNER_SCOPE B). The files before this
one are frozen and record the AM-RV copy from the local tag v1.75.0 at `265a89e`. That tag has moved
twice since: to `6bf5f3e` (LK-26, `Sim` minor 2 and `SimTimeline` minor 2), then to `9e5c4e2` (LK-27,
`SimPanel` minor 2), its final position. This file records the refresh from it.

## The move

| | Commit |
|---|---|
| Old tag position (AM-RV) | `265a89e` |
| New tag position (this refresh) | `9e5c4e2` |

The provenance line in `CLAUDE.md` stays `v1.75.0`, and the `LibKa0s icons:` declaration under it is
unchanged.

## What changed in the payload

The copy was the same as AM-RV's: both payloads taken whole from
`git -C ../LibKa0s archive v1.75.0 LibKa0s testkit`, with the tag's `tools/prune-icons.lua` holding
`media/icons/` to the unchanged declaration. Against the vendored copy, only three files differ:

| File | Major | Minor |
|---|---|---|
| `libs/LibKa0s/Sim.lua` | `LibKa0s-Sim-1.0` | 1 -> 2 |
| `libs/LibKa0s/SimTimeline.lua` | `LibKa0s-Sim-1.0` (timeline) | 1 -> 2 |
| `libs/LibKa0s/SimPanel.lua` | `LibKa0s-Sim-1.0` (panel) | 1 -> 2 |

`tests/_kit/` is byte-identical to the tag, so the kit revision does not move. Nothing under
`media/icons/` changed.

## Ripple in this addon

None. AuraMaster does not bind `LibKa0s-Sim-1.0` (03_DECISIONS.md: not adopted in this run), and no
test or document here pins a Sim, SimTimeline or SimPanel minor or the Sim docs key.

## Gates

All run through `dev-copilot/bin/ka0s-bounded`.

| Gate | Result |
|---|---|
| `lua tests/run.lua` | 2127 passed, 0 failed, 1 skipped (the declared diagnostics opt-out), 2128 total (16 shards); both vendor-sync payload cases PASS against the moved tag |
| `luacheck .` | 0 warnings / 0 errors in 178 files |
| 1500-line cap | largest authored file 1344 lines (`defaults/Categories.lua`) |

No in-game smoke check is added: the addon never binds the Sim major, so nothing it draws changes.
