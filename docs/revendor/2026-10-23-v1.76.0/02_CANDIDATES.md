# 02 — Candidates

Sources, all at the local tag `v1.76.0` in `../LibKa0s`: the `CHANGELOG.md` v1.76.0 block (line 13),
and the API documents named per row. 3g found no blocker.

## A. Delivered on the copy

Nothing AuraMaster draws changes. Widgets 14 leaves `DragHandle` as it was; SimTimeline 3 and
SimPanel 5 change a simulator this addon does not host.

## B. New surfaces (host change required)

| Surface | Evidence | Fit for AuraMaster |
|---|---|---|
| `W.TestStrip(parent, { kind = "sim" })`, `strip.kind` (Widgets 14) | `docs/api/Widgets/version-14.1.4.3.2-docs.md:27`, `:33` | None: AuraMaster builds no `TestStrip` at all (its locked test mode marks the display itself, AM-01 `ffe08ae`) and runs no simulation. The run's OWNER_SCOPE names BankLedger, DropWatcher, LootHistory, MultiMeters and KickCD as the adopters. Additive. |

## C. Whole-module adoption

| Major | Evidence | Fit for AuraMaster |
|---|---|---|
| `LibKa0s-Sim-1.0` | `docs/api/Sim/version-2.3.5-docs.md` | None: settled at v1.75.0 (`docs/revendor/2026-10-22-v1.75.0/02_CANDIDATES.md`). Auto-run changes how a simulation plays, not whether AuraMaster has one; the premise is unmoved. |
| `LibKa0s-Glow-1.0`, `LibKa0s-Item-1.0` | unchanged since v1.75.0 | None: settled at v1.75.0. |

One class-B row and the settled class-C majors.
